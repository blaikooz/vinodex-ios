import Foundation

/// Turns the strings off a wine label into a `LabelReading` (0.7.2, LR1).
///
/// **This is the whole matcher, and it is Foundation-only on purpose.** OCR
/// needs Vision, a camera and a device, none of which the Linux CI has; the
/// searching, scoring and inference need none of them, and they are the half
/// where a regression would be invisible on a phone. So the pipeline is cut at
/// `LabelRecognitionProvider`: everything upstream of `[RecognizedString]` lives
/// in `VinodexUI`, everything downstream lives here and is covered by
/// `LabelReaderTests`.
///
/// The service holds no state beyond the index it builds at init, so it is
/// `Sendable` and `read(_:providerName:)` can run off the main actor — which is
/// what the view model does, because a fuzzy pass over the whole catalog is not
/// work to do while a progress bar is trying to animate.
public final class LabelRecognitionService: Sendable {
    public static let shared = LabelRecognitionService()

    private let db: WineDatabase
    private let index: LabelIndex

    public init(db: WineDatabase = .shared) {
        self.db = db
        self.index = LabelIndex(db: db)
    }

    // MARK: - The read

    /// Matches in the spec's priority order — producer, wine name, appellation,
    /// region, country, grape — then infers everything the data can reach from
    /// what stuck.
    ///
    /// Fields do **not** consume each other's phrases. `Champagne` is both a
    /// style entry and a region entry in this catalog, and a label carrying the
    /// word is truthfully saying both things; letting the higher-priority field
    /// eat the phrase would throw away a region the inference walk wants.
    /// Priority orders the *table*, it does not ration the *evidence*.
    public func read(_ strings: [RecognizedString], providerName: String = "") -> LabelReading {
        let phrases = LabelTextScan.phrases(in: strings)
        var matches: [LabelMatch] = []
        var claimedLines = Set<Int>()

        // The four fields resolved directly against the catalog. `.grape` is
        // handled separately below because a label may name a blend, and
        // `.producer` and `.vintage` are not catalog lookups at all.
        for field in [LabelField.wineName, .appellation, .region, .country] {
            guard let hit = resolve(field, in: phrases, strings: strings) else { continue }
            matches.append(hit.match)
            claimedLines.formUnion(hit.lines)
        }

        let grapeHits = resolveGrapes(in: phrases, strings: strings)
        if let first = grapeHits.first {
            matches.append(first.match)
            for hit in grapeHits { claimedLines.formUnion(hit.lines) }
        }

        // Producer last of the text passes, because it is defined by what the
        // others did *not* claim. See `LabelTextScan.producerGuess`.
        if let producer = LabelTextScan.producerGuess(in: strings, claimedLines: claimedLines) {
            matches.append(
                LabelMatch(field: .producer, name: producer, readAs: producer, entryID: nil)
            )
        }

        if let year = LabelTextScan.vintage(in: strings) {
            matches.append(
                LabelMatch(field: .vintage, name: String(year), readAs: String(year))
            )
        }

        let place = resolvePlace(matches)

        // The walked fields, filled in where the label did not state them.
        //
        // A bottle saying only BAROLO does not print the word ITALIA, and a
        // results screen that therefore shows no country would be hiding
        // something the catalog knows for certain. These are marked
        // `isInferred`, so they are shown and are worth nothing — see
        // `LabelMatch.isInferred`.
        if let region = place.region, !matches.contains(where: { $0.field == .region }) {
            matches.append(
                LabelMatch(
                    field: .region,
                    name: region.common.name,
                    readAs: matches.first { $0.field == .appellation }?.readAs ?? region.common.name,
                    entryID: region.id,
                    isInferred: true
                )
            )
        }
        if let country = place.country, !matches.contains(where: { $0.field == .country }) {
            matches.append(
                LabelMatch(
                    field: .country,
                    name: country,
                    readAs: place.region?.common.name ?? country,
                    isInferred: true
                )
            )
        }

        // Sorted into the priority order so the results screen can render the
        // list straight through without a second opinion about ordering.
        matches.sort { a, b in
            let order = LabelField.allCases
            return (order.firstIndex(of: a.field) ?? 0) < (order.firstIndex(of: b.field) ?? 0)
        }

        let grapes = inferredGrapes(directHits: grapeHits, region: place.region)
        let styles = inferredStyles(
            named: matches.first { $0.field == .wineName }?.entryID,
            grapes: grapes,
            region: place.region
        )

        let reading = LabelReading(
            recognizedText: strings.map { LabelTextScan.tidy($0.text) }.filter { !$0.isEmpty },
            matches: matches,
            grapeIDs: grapes.map(\.id),
            styleIDs: styles.map(\.id),
            providerName: providerName
        )

        guard !reading.isConfident else { return reading }

        // The no-match state still owes the user something to act on: what was
        // read, which countries and regions were nearly hit, and the vintage.
        let (countries, regionIDs) = suggestions(phrases: phrases, matches: matches)
        return LabelReading(
            recognizedText: reading.recognizedText,
            matches: matches,
            grapeIDs: reading.grapeIDs,
            styleIDs: reading.styleIDs,
            suggestedCountries: countries,
            suggestedRegionIDs: regionIDs,
            providerName: providerName
        )
    }

    // MARK: - Field resolution

    private struct Hit {
        let match: LabelMatch
        /// Every recognised line the winning phrase drew words from. Plural
        /// since 0.7.9 (D-a) — a phrase set across a line break claims all of
        /// the lines it consumed, or `producerGuess` offers the leftovers as an
        /// estate name.
        let lines: [Int]
    }

    /// How big the phrase was on the bottle, 0–1.
    ///
    /// The largest of its lines rather than the average: a phrase that begins in
    /// the label's headline type is headline text, whatever size the runover was
    /// set in. Missing geometry reads as 0, which is what a provider that cannot
    /// report it already sends (`RecognizedString.prominence`).
    private static func prominence(
        of phrase: LabelTextScan.Phrase,
        in strings: [RecognizedString]
    ) -> Double {
        phrase.lines.compactMap { strings.indices.contains($0) ? strings[$0].prominence : nil }
            .max() ?? 0
    }

    /// Exact first over every phrase, longest phrase first; fuzzy only if
    /// nothing landed.
    ///
    /// The two passes are separate rather than interleaved because an exact
    /// match on a short phrase must still beat a fuzzy match on a long one — a
    /// label that plainly says `RIOJA` is in Rioja, whatever else on it is two
    /// edits away from Ribera del Duero.
    ///
    /// **Prominence ranks within each pass since 0.7.9 (D-a).** The exact pass
    /// used to take the *first* hit in phrase order, which is longest-first and
    /// then top-of-label — so a second-rank hit on a big line lost to a
    /// same-length hit on a back-label line. `RecognizedString.prominence` is
    /// signal the matcher already had and was spending only on the producer
    /// guess, and how big a word is set is the strongest statement a label
    /// makes about what it is: the estate is the biggest text and the
    /// appellation is usually second. It is applied strictly **after** word
    /// count, so it is a tie-break and never a reason to prefer a shorter
    /// phrase — the longest-window rule is what stops `Cabernet Sauvignon`
    /// resolving to `Cabernet` and it is not for sale.
    ///
    /// An unbroken phrase also outranks a joined one of the same length and
    /// prominence, for the reason `Phrase.isJoined` records: running type is one
    /// phrase, broken type only might be.
    private func resolve(
        _ field: LabelField,
        in phrases: [LabelTextScan.Phrase],
        strings: [RecognizedString]
    ) -> Hit? {
        guard let targets = index.targets[field] else { return nil }

        /// Descending goodness: more words, then bigger type, then unbroken,
        /// then earlier on the label. The last is a stability key rather than a
        /// judgement — `sorted` and `max(by:)` are not stable in Swift, and two
        /// runs over one photograph listing different answers reads as the
        /// reader changing its mind.
        func outranks(_ a: LabelTextScan.Phrase, _ b: LabelTextScan.Phrase) -> Bool {
            if a.words != b.words { return a.words > b.words }
            let pa = Self.prominence(of: a, in: strings)
            let pb = Self.prominence(of: b, in: strings)
            if pa != pb { return pa > pb }
            if a.isJoined != b.isJoined { return !a.isJoined }
            return a.line < b.line
        }

        var exact: (target: LabelIndex.Target, phrase: LabelTextScan.Phrase)?
        for phrase in phrases where phrase.key.count >= LabelIndex.minExactLength {
            guard let target = index.exact[field]?[phrase.key] else { continue }
            if exact == nil || outranks(phrase, exact!.phrase) {
                exact = (target, phrase)
            }
        }
        if let exact {
            return Hit(
                match: LabelMatch(
                    field: field,
                    name: exact.target.name,
                    readAs: exact.phrase.text,
                    entryID: exact.target.entryID,
                    isExact: true
                ),
                lines: exact.phrase.lines
            )
        }

        var best: (target: LabelIndex.Target, phrase: LabelTextScan.Phrase, distance: Int)?
        for phrase in phrases where phrase.key.count >= LabelIndex.minFuzzyLength {
            let limit = LabelTextScan.allowedDistance(forLength: phrase.key.count)
            guard limit > 0 else { continue }
            for target in targets {
                guard abs(target.key.count - phrase.key.count) <= limit else { continue }
                guard let distance = LabelTextScan.editDistance(phrase.key, target.key, limit: limit),
                      distance > 0
                else { continue }
                // Fewer edits wins; a tie goes to the phrase `outranks` prefers,
                // which is the longer one and then the more prominent.
                if best == nil || distance < best!.distance
                    || (distance == best!.distance && outranks(phrase, best!.phrase)) {
                    best = (target, phrase, distance)
                }
            }
        }

        guard let best else { return nil }
        return Hit(
            match: LabelMatch(
                field: field,
                name: best.target.name,
                readAs: best.phrase.text,
                entryID: best.target.entryID,
                isExact: false
            ),
            lines: best.phrase.lines
        )
    }

    /// Grapes, plural.
    ///
    /// The one field where a label routinely names several — a GSM says so on
    /// the front — so every exact hit is collected rather than the first. Falls
    /// back to the shared single-hit path when nothing matched exactly, because
    /// a *fuzzy* blend is three guesses stacked on each other.
    private func resolveGrapes(
        in phrases: [LabelTextScan.Phrase],
        strings: [RecognizedString]
    ) -> [Hit] {
        var hits: [Hit] = []
        var seen = Set<String>()
        for phrase in phrases where phrase.key.count >= LabelIndex.minExactLength {
            guard let target = index.exact[.grape]?[phrase.key], let id = target.entryID else { continue }
            guard seen.insert(id).inserted else { continue }
            hits.append(
                Hit(
                    match: LabelMatch(
                        field: .grape,
                        name: target.name,
                        readAs: phrase.text,
                        entryID: id,
                        isExact: true
                    ),
                    lines: phrase.lines
                )
            )
            if hits.count >= Self.blendLimit { break }
        }
        if hits.isEmpty, let single = resolve(.grape, in: phrases, strings: strings) {
            hits.append(single)
        }
        return hits
    }

    /// A blend of more than three named grapes is a back-label ingredient list,
    /// not an identification.
    private static let blendLimit = 3

    // MARK: - Inference (§8)

    /// The region and country a reading landed on.
    ///
    /// An appellation outranks a region name because it is the more specific
    /// statement: a label carrying both `BAROLO` and `PIEMONTE` is a Barolo, and
    /// Barolo's owning region is Piedmont anyway, so the two agree. The country
    /// is read off the region rather than off the label wherever a region is
    /// known — `RegionDetails.origin` is the catalog's own answer and cannot
    /// disagree with itself.
    private func resolvePlace(_ matches: [LabelMatch]) -> (region: RegionEntry?, country: String?) {
        var region: RegionEntry?

        if let appellation = matches.first(where: { $0.field == .appellation }),
           let ownerID = index.appellationOwner[TextNormalize.key(appellation.name)],
           case .region(let r)? = db.entry(id: ownerID) {
            region = r
        }
        if region == nil,
           let match = matches.first(where: { $0.field == .region }),
           let id = match.entryID,
           case .region(let r)? = db.entry(id: id) {
            region = r
        }

        let country = region?.details.origin
            ?? matches.first { $0.field == .country }?.name
        return (region, country)
    }

    /// Grapes read off the label, or — failing that — the ones the region is
    /// known for.
    ///
    /// This is the §8 walk and it is entirely data: `RegionDetails.notableGrapes`
    /// resolved through `WineDatabase.entry(named:category:)`. Nothing here
    /// knows that Barolo is Nebbiolo; Piedmont's entry does.
    private func inferredGrapes(directHits: [Hit], region: RegionEntry?) -> [WineEntry] {
        let direct = directHits.compactMap { $0.match.entryID }.compactMap { db.entry(id: $0) }
        if !direct.isEmpty { return direct }
        guard let region else { return [] }
        return region.details.notableGrapes
            .compactMap { db.entry(named: $0, category: .grapes) }
            .prefix(Self.inferredGrapeLimit)
            .map { $0 }
    }

    private static let inferredGrapeLimit = 4
    private static let inferredStyleLimit = 5

    /// Styles, in descending order of how directly the data implies them.
    ///
    /// 1. The style the label named outright, if it named one.
    /// 2. Each grape's own `grapeStyle` / `wineType` — the catalog's statement
    ///    of what that grape makes. This is what turns Nebbiolo into
    ///    Full-Body Red without anyone writing that down twice.
    /// 3. Styles that list one of the grapes as notable.
    /// 4. Styles that list the region among their key regions.
    ///
    /// Rules 3 and 4 are looser than rules 1 and 2 and that is why they are
    /// last: `Noble Grapes` names Nebbiolo, which is true and is not what the
    /// bottle is. Capped, so the ordering is what decides what a user sees.
    private func inferredStyles(
        named styleID: String?,
        grapes: [WineEntry],
        region: RegionEntry?
    ) -> [WineEntry] {
        var out: [WineEntry] = []
        var seen = Set<String>()

        func add(_ entry: WineEntry?) {
            guard let entry, seen.insert(entry.id).inserted else { return }
            out.append(entry)
        }

        if let styleID { add(db.entry(id: styleID)) }

        for case .grape(let g) in grapes {
            add(db.entry(named: g.grapeStyle, category: .styles))
            if let wineType = g.wineType {
                add(db.entry(named: wineType, category: .styles))
            }
        }

        let grapeKeys = Set(grapes.map { TextNormalize.label($0.name) })
        if !grapeKeys.isEmpty {
            for entry in db.entries(in: .styles) {
                guard entry.notableGrapes.contains(where: { grapeKeys.contains(TextNormalize.label($0)) })
                else { continue }
                add(entry)
            }
        }

        if let region {
            for entry in db.entries(in: .styles) {
                guard entry.keyRegions.contains(where: {
                    TextNormalize.matchesWholeTerm($0, region.common.name)
                }) else { continue }
                add(entry)
            }
        }

        return Array(out.prefix(Self.inferredStyleLimit))
    }

    // MARK: - The no-match state

    /// Near-misses worth showing when nothing landed confidently.
    ///
    /// Two sources, in order. Loose fuzzy candidates come first — they are what
    /// the reader *nearly* saw. Then, if a country is known at all, its regions,
    /// because "we are fairly sure this is Italian" plus a list of Italian
    /// regions is a usable answer where "no confident match" alone is not.
    private func suggestions(
        phrases: [LabelTextScan.Phrase],
        matches: [LabelMatch]
    ) -> (countries: [String], regionIDs: [String]) {
        var countries: [String] = []
        var regionIDs: [String] = []

        for field in [LabelField.country, .region] {
            guard let targets = index.targets[field] else { continue }
            var scored: [(name: String, id: String?, distance: Int)] = []
            for phrase in phrases where phrase.key.count >= LabelIndex.minFuzzyLength {
                // One edit looser than a match would need: these are explicitly
                // "did you mean", not claims.
                let limit = LabelTextScan.allowedDistance(forLength: phrase.key.count) + 1
                for target in targets {
                    guard abs(target.key.count - phrase.key.count) <= limit else { continue }
                    guard let distance = LabelTextScan.editDistance(phrase.key, target.key, limit: limit)
                    else { continue }
                    scored.append((target.name, target.entryID, distance))
                }
            }
            // Name breaks the tie. Swift's sort is not stable, so distance
            // alone would let two runs over the same photograph list the
            // suggestions in different orders — which on a screen the user is
            // reading twice looks like the reader changing its mind.
            let ranked = scored.sorted {
                $0.distance == $1.distance ? $0.name < $1.name : $0.distance < $1.distance
            }
            for candidate in ranked {
                if field == .country {
                    guard !countries.contains(candidate.name) else { continue }
                    countries.append(candidate.name)
                    if countries.count >= Self.suggestionLimit { break }
                } else if let id = candidate.id {
                    guard !regionIDs.contains(id) else { continue }
                    regionIDs.append(id)
                    if regionIDs.count >= Self.suggestionLimit { break }
                }
            }
        }

        // A matched country is not a *suggestion*, it is a result — but if the
        // reading is not confident it is the most useful thing on the screen, so
        // it leads the list and brings its regions with it.
        if let country = matches.first(where: { $0.field == .country })?.name {
            countries.removeAll { $0 == country }
            countries.insert(country, at: 0)
            let regions = db.entries(in: .regions)
                .filter { TextNormalize.label($0.origin ?? "") == TextNormalize.label(country) }
                .prefix(Self.suggestionLimit)
                .map(\.id)
            regionIDs = regions + regionIDs.filter { !regions.contains($0) }
        }

        return (
            Array(countries.prefix(Self.suggestionLimit)),
            Array(regionIDs.prefix(Self.suggestionLimit))
        )
    }

    private static let suggestionLimit = 5
}

// MARK: - The index

/// Folded lookup tables for the five catalog-backed label fields, built once.
///
/// The same trick `WineDatabase.byName` plays and for the same reason: the fuzzy
/// pass walks every target for every phrase, and folding names inside that loop
/// would be tens of thousands of `String.folding` calls per photograph. Keys go
/// through `TextNormalize.key` — the app's one normaliser — so a target here and
/// a phrase from `LabelTextScan` are directly comparable.
struct LabelIndex: Sendable {
    /// Below this many characters a phrase is not allowed to match at all. Two-
    /// and three-letter fragments of a label match something in a 400-entry
    /// catalog almost every time.
    static let minExactLength = 4
    /// Fuzzy needs more to go on than exact does.
    static let minFuzzyLength = 6

    struct Target: Sendable, Hashable {
        let key: String
        let name: String
        let entryID: String?
    }

    let targets: [LabelField: [Target]]
    let exact: [LabelField: [String: Target]]
    /// Normalised appellation -> the id of the region entry that lists it.
    /// Appellations are not entries, so this is how `Barolo` reaches Piedmont.
    let appellationOwner: [String: String]

    init(db: WineDatabase) {
        var targets: [LabelField: [Target]] = [:]
        var owner: [String: String] = [:]

        func add(_ field: LabelField, key: String, name: String, entryID: String?) {
            let folded = TextNormalize.key(key)
            guard folded.count >= Self.minExactLength else { return }
            targets[field, default: []].append(Target(key: folded, name: name, entryID: entryID))
        }

        for entry in db.entries {
            switch entry {
            case .grape(let g):
                add(.grape, key: g.common.name, name: g.common.name, entryID: g.id)
                for synonym in g.details.synonyms + g.grapeAlternateNames {
                    add(.grape, key: synonym, name: g.common.name, entryID: g.id)
                }

            case .region(let r):
                add(.region, key: r.common.name, name: r.common.name, entryID: r.id)
                for synonym in r.details.synonyms ?? [] {
                    add(.region, key: synonym, name: r.common.name, entryID: r.id)
                }
                for appellation in r.details.appellations ?? [] {
                    add(.appellation, key: appellation, name: appellation, entryID: r.id)
                    let folded = TextNormalize.key(appellation)
                    // First region wins, matching `WineDatabase.byName`'s rule.
                    // No appellation in the catalog is shared, and if one ever
                    // is, the earlier region is the arbitrary-but-stable answer.
                    if owner[folded] == nil { owner[folded] = r.id }
                }

            case .style(let s):
                add(.wineName, key: s.common.name, name: s.common.name, entryID: s.id)

            case .flavor, .continent:
                // Neither is ever printed on a label as an identification.
                continue
            }
        }

        for country in db.searchableCountries {
            add(.country, key: country, name: country, entryID: nil)
        }

        var exact: [LabelField: [String: Target]] = [:]
        for (field, list) in targets {
            var table: [String: Target] = [:]
            table.reserveCapacity(list.count)
            for target in list where table[target.key] == nil {
                table[target.key] = target
            }
            exact[field] = table
        }

        self.targets = targets
        self.exact = exact
        self.appellationOwner = owner
    }
}
