import Foundation

/// The "WHAT'S THAT…?" guessing game (0.7.9, B).
///
/// **What replaced what.** The tile at `ToolsScreen` opened `DailyGrapeScreen`
/// from 0.6.x to 0.7.8: a silhouette, a REVEAL button, an answer. The door is
/// unchanged — same tile, same `DexRoute.dailyGrape`, same marquee — and what is
/// behind it is now a round you can lose. The old screen's own doc comment had
/// already worked out why the reveal was thin ("a shuffled entry shown outright
/// is just a list of one"); holding the name back for a beat was as far as a
/// reveal could go. Clues make the beat into a decision.
///
/// **All of it lives here rather than in the view**, which is the rule
/// `OCRService` writes down: anything that is a claim about *wine* belongs in
/// `VinodexCore` where `swift test` on Linux can see it, and `VinodexUI` only
/// gets the drawing. So clue generation, ordering, sufficiency, scoring and
/// answer-matching are all in this file and all covered by `WhatsThatTests`.
/// `WhatsThatScreen` chooses fonts.
///
/// **The answer matcher is `LabelRecognitionService` and is not reimplemented.**
/// Free text against a 446-entry catalog needs accent folding, synonym
/// resolution and near-miss tolerance, and that is precisely the job the label
/// reader already does — `chateau neuf`, `Steen`, `Albarino` for `Albariño`. A
/// second fuzzy matcher here would be a second set of thresholds to keep in step
/// with the index it is comparing against, which is the exact failure
/// `LabelTextScan`'s normalisation note exists to prevent. See `judge(_:in:)`.
public enum WhatsThat {

    // MARK: - Clues

    /// One revealed fact about the hidden entry.
    ///
    /// `value` is the comparable form and `text` is what the chip prints. They
    /// are separate because the *set* of clues has to be checkable against the
    /// whole catalog — see `candidates(for:in:)` — and "IT'S A RED GRAPE" is not
    /// a predicate.
    public struct Clue: Sendable, Hashable, Codable, Identifiable {
        /// **`allCases` order is reveal order: vague first, specific last.**
        ///
        /// This is the game's only real design decision. A first chip reading
        /// "GROWN IN BAROLO" ends the round before it starts; a last chip
        /// reading "IT'S RED" is a round nobody can finish. So the kinds are
        /// sorted by how much of the catalog they eliminate — category, then
        /// colour, then country, then the structural facts, then the ones that
        /// name another entry outright.
        public enum Kind: String, Codable, Sendable, CaseIterable {
            /// Grape or region. Always first, because every other clue reads
            /// differently depending on the answer.
            case category
            case color
            case country
            case climate
            case body
            case tannin
            case rarity
            case flavor
            /// A region this grape is grown in.
            case region
            /// A grape this region is planted with.
            case grape
            /// A style this region is known for.
            case style
            /// A village or cru inside this region. The giveaway, and last.
            case appellation
        }

        public let kind: Kind
        /// Normalised, for `satisfies`. Never shown.
        public let value: String
        /// The chip's copy.
        public let text: String

        public var id: String { "\(kind.rawValue):\(value)" }

        public init(kind: Kind, value: String, text: String) {
            self.kind = kind
            self.value = value
            self.text = text
        }
    }

    /// One playable round.
    ///
    /// `Codable` so `ScreenStateStore` can hold it while the screen is torn
    /// down — the same contract `LabelReading` and `GrapeScanCriteria` have, and
    /// for the same reason: opening the answer's entry and pressing Back must
    /// not deal a new hand.
    public struct Round: Sendable, Hashable, Codable {
        public let answerID: String
        public let answerName: String
        /// Vague to specific. Between `minClues` and `maxClues` of them, and the
        /// full set identifies the answer uniquely — see `isSolvable(_:in:)`.
        public let clues: [Clue]

        public init(answerID: String, answerName: String, clues: [Clue]) {
            self.answerID = answerID
            self.answerName = answerName
            self.clues = clues
        }

        /// Points for guessing right with `revealed` chips showing.
        ///
        /// Full marks for a first-chip guess, sliding to a fifth of that on the
        /// last. It is a fraction of the round's own length rather than a table,
        /// so a five-clue round and a six-clue round are worth the same to
        /// someone who solves them at the same *proportion* of the way through —
        /// otherwise the game would quietly reward drawing an easy entry.
        public func score(revealed: Int) -> Int {
            guard !clues.isEmpty else { return 0 }
            let used = min(max(revealed, 1), clues.count)
            let remaining = Double(clues.count - used + 1) / Double(clues.count)
            return max(20, Int((100 * remaining).rounded()))
        }
    }

    /// Fewer than this and a round is a coin toss; more and it is a reading
    /// exercise. The catalog reliably supports five for a grape and five for a
    /// region; the sixth is the discriminator `pick` adds when five leave two
    /// entries standing.
    public static let minClues = 4
    public static let maxClues = 6

    // MARK: - Does an entry fit a clue

    /// Whether `entry` is consistent with one revealed clue.
    ///
    /// This is what makes "the clues must identify the answer" a property rather
    /// than a hope: the same predicate that generated a clue is run back over
    /// the whole catalog. A clue whose predicate did not match its own subject
    /// would be a lie the game tells, and `WhatsThatTests` checks every clue of
    /// every round against its own answer.
    public static func entry(_ entry: WineEntry, satisfies clue: Clue, in db: WineDatabase) -> Bool {
        switch clue.kind {
        case .category:
            return entry.category.rawValue == clue.value
        case .color:
            guard case .grape(let g) = entry else { return false }
            return g.grapeType.rawValue == clue.value
        case .country:
            return TextNormalize.label(entry.origin ?? "") == clue.value
        case .climate:
            return entry.climate?.rawValue == clue.value
        case .body:
            guard case .grape(let g) = entry else { return false }
            return String(Int(g.grapeCharacteristics.body.rounded())) == clue.value
        case .tannin:
            guard case .grape(let g) = entry else { return false }
            return String(Int(g.grapeCharacteristics.tannin.rounded())) == clue.value
        case .rarity:
            return entry.rarity?.rawValue == clue.value
        case .flavor:
            return entry.tastingProfile.contains { TextNormalize.label($0.note) == clue.value }
        case .region:
            guard case .grape(let g) = entry else { return false }
            return g.details.keyRegions.contains { TextNormalize.label($0) == clue.value }
        case .grape:
            guard case .region(let r) = entry else { return false }
            return r.details.notableGrapes.contains { TextNormalize.label($0) == clue.value }
        case .style:
            guard case .region(let r) = entry else { return false }
            return styles(of: r, in: db).contains(clue.value)
        case .appellation:
            guard case .region(let r) = entry else { return false }
            return (r.details.appellations ?? []).contains { TextNormalize.label($0) == clue.value }
        }
    }

    /// The styles a region is named by, normalised.
    ///
    /// Derived by inverting `style.keyRegions` rather than stored: regions do not
    /// carry styles, and adding a mirror field for a game to read would be a
    /// second source of truth for a fact the styles already state. Matches on the
    /// whole term through `TextNormalize`, so `Rioja` does not answer to
    /// `Rioja Alavesa`.
    static func styles(of region: RegionEntry, in db: WineDatabase) -> Set<String> {
        var out: Set<String> = []
        for entry in db.entries(in: .styles) {
            guard entry.keyRegions.contains(where: {
                TextNormalize.matchesWholeTerm($0, region.common.name)
            }) else { continue }
            out.insert(TextNormalize.label(entry.name))
        }
        return out
    }

    /// Everything in the catalog that every clue is true of.
    ///
    /// Grapes and regions only, which is the pool `pick` draws from — a style or
    /// a flavour cannot satisfy a `category` clue and would only ever pad the
    /// count.
    public static func candidates(for clues: [Clue], in db: WineDatabase) -> [WineEntry] {
        let pool = db.entries(in: .grapes) + db.entries(in: .regions)
        return pool.filter { entry in
            clues.allSatisfy { self.entry(entry, satisfies: $0, in: db) }
        }
    }

    /// **The property the spec names: a round must be winnable on its full set.**
    ///
    /// Not "the player could reasonably deduce it" — that is not checkable — but
    /// the strictly weaker and entirely checkable thing: no *other* entry in the
    /// catalog is consistent with every clue. A round failing this is a round
    /// whose answer cannot be argued for, and `pick` refuses to deal one.
    public static func isSolvable(_ round: Round, in db: WineDatabase) -> Bool {
        candidates(for: round.clues, in: db).map(\.id) == [round.answerID]
    }

    // MARK: - Dealing a round

    /// The round at a given position in the shuffle.
    ///
    /// `cursor` is `RevealCursor`'s, exactly as the reveal used it — one new
    /// round per open, with the calendar day setting the starting point so two
    /// players opening it cold get the same hand. That is the one piece of the
    /// old feature kept verbatim, and it is why "grape of the day" did not
    /// disappear so much as acquire a question: the day still deals.
    ///
    /// Walks forward from the cursor's position until it finds an entry whose
    /// clues come out solvable, so a variety the catalog cannot distinguish
    /// costs one step rather than an unwinnable round. The walk is bounded; a
    /// catalog that could not produce a single solvable round returns nil and
    /// the screen says so rather than dealing something broken.
    public static func round(
        cursor: Int,
        for date: Date = Date(),
        in db: WineDatabase,
        calendar: Calendar = .current
    ) -> Round? {
        let pool = (db.entries(in: .grapes) + db.entries(in: .regions))
            .sorted { $0.id < $1.id }
        guard !pool.isEmpty else { return nil }

        // The same coprime stride `DailyPick.entry(cursor:)` uses, for the same
        // reason: adjacent ids are often the same family, and stepping by one
        // makes every new round look like a variant of the last.
        let stride = 37
        let start = DailyPick.dayIndex(for: date, calendar: calendar) &+ cursor &* stride

        for step in 0..<pool.count {
            let raw = start &+ step
            let entry = pool[((raw % pool.count) + pool.count) % pool.count]
            if let round = round(for: entry, in: db) { return round }
        }
        return nil
    }

    /// The round for one specific entry, or nil if the catalog cannot single it
    /// out.
    ///
    /// Builds the full ordered clue list the entry can support, takes the first
    /// `minClues` — the vague end — and then adds discriminators until the
    /// candidate set is down to the answer alone.
    ///
    /// **The extras are taken from the *specific* end, not the next one along**,
    /// and that is the whole of what makes a round finishable. Appending in
    /// reveal order fills the two spare chips with the next-vaguest facts —
    /// tannin, rarity — and hits the six-clue cap before reaching the flavour
    /// and the region, which are the only clues that actually isolate a grape.
    /// Cabernet Sauvignon was the proof: eight clues available, six spent, still
    /// ambiguous, round refused.
    ///
    /// The chosen set is re-sorted into reveal order at the end, so the round
    /// still comes out vague to specific — the *selection* is greedy from the
    /// specific end, the *presentation* is not.
    public static func round(for entry: WineEntry, in db: WineDatabase) -> Round? {
        let available = clues(for: entry, in: db)
        guard available.count >= minClues else { return nil }

        var chosen = Array(available.prefix(minClues))
        var extras = Array(available.dropFirst(minClues).reversed())
        while candidates(for: chosen, in: db).count > 1,
              chosen.count < maxClues,
              let next = extras.first {
            chosen.append(next)
            extras.removeFirst()
        }

        let rank = Dictionary(
            uniqueKeysWithValues: Clue.Kind.allCases.enumerated().map { ($1, $0) }
        )
        chosen.sort { (rank[$0.kind] ?? 0) < (rank[$1.kind] ?? 0) }

        let round = Round(answerID: entry.id, answerName: entry.name, clues: chosen)
        return isSolvable(round, in: db) ? round : nil
    }

    /// Every clue this entry can support, vague to specific.
    ///
    /// One clue per `Kind` at most: two flavours would read as one fact stated
    /// twice and would spend a chip for very little. Ties inside a kind are
    /// broken by taking the **last** listed value — `keyRegions` and
    /// `notableGrapes` lead with the famous one, and the famous one is the
    /// giveaway, so the game keeps it back rather than opening with it.
    public static func clues(for entry: WineEntry, in db: WineDatabase) -> [Clue] {
        var byKind: [Clue.Kind: Clue] = [:]

        func add(_ kind: Clue.Kind, _ value: String?, _ text: @autoclosure () -> String) {
            guard let value, !value.isEmpty, byKind[kind] == nil else { return }
            byKind[kind] = Clue(kind: kind, value: value, text: text())
        }

        add(.category, entry.category.rawValue, entry.category == .grapes
            ? "IT'S A GRAPE" : "IT'S A WINE REGION")

        if let origin = entry.origin, !origin.isEmpty {
            add(.country, TextNormalize.label(origin), "IT COMES FROM \(origin.uppercased())")
        }

        switch entry {
        case .grape(let g):
            add(.color, g.grapeType.rawValue,
                g.grapeType == .red ? "IT MAKES RED WINE" : "IT MAKES WHITE WINE")
            add(.body, String(Int(g.grapeCharacteristics.body.rounded())),
                "THE WINE IS \(Self.bodyWord(g.grapeCharacteristics.body))-BODIED")
            add(.tannin, String(Int(g.grapeCharacteristics.tannin.rounded())),
                "\(Self.levelWord(g.grapeCharacteristics.tannin)) TANNIN")
            add(.rarity, g.rarity.rawValue, "A \(g.rarity.rawValue) VARIETY")
            if let note = g.tastingProfile?.last {
                add(.flavor, TextNormalize.label(note.note), "YOU MIGHT TASTE \(note.note.uppercased())")
            }
            if let region = g.details.keyRegions.last {
                add(.region, TextNormalize.label(region), "IT'S GROWN IN \(region.uppercased())")
            }

        case .region(let r):
            if let climate = r.climate {
                add(.climate, climate.rawValue, "A \(climate.rawValue.uppercased()) CLIMATE")
            }
            if let style = Self.styles(of: r, in: db).sorted().last,
               let named = db.entry(named: style, category: .styles) {
                add(.style, style, "IT'S KNOWN FOR \(named.name.uppercased())")
            }
            if let grape = r.details.notableGrapes.last {
                add(.grape, TextNormalize.label(grape), "THEY PLANT \(grape.uppercased()) HERE")
            }
            if let appellation = (r.details.appellations ?? []).last {
                add(.appellation, TextNormalize.label(appellation),
                    "\(appellation.uppercased()) IS INSIDE IT")
            }

        case .style, .flavor, .continent:
            return []
        }

        // `Kind.allCases` order is the reveal order — see the enum's note.
        return Clue.Kind.allCases.compactMap { byKind[$0] }
    }

    /// The five-point body bar as a word. Deliberately coarse: the chip is a
    /// clue, and "3.0 BODY" is a stat readout.
    static func bodyWord(_ value: Double) -> String {
        switch Int(value.rounded()) {
        case ...2: "LIGHT"
        case 3: "MEDIUM"
        case 4: "MEDIUM-FULL"
        default: "FULL"
        }
    }

    static func levelWord(_ value: Double) -> String {
        switch Int(value.rounded()) {
        case ...1: "BARELY ANY"
        case 2: "LOW"
        case 3: "MODERATE"
        case 4: "HIGH"
        default: "VERY HIGH"
        }
    }

    // MARK: - Judging a guess

    /// What the player's typing came to.
    public enum Verdict: Sendable, Hashable {
        case correct
        /// They named something real, and it was not the answer. Carries the
        /// catalog's spelling so the screen can say *which* — "that's Merlot"
        /// is a better answer than "no".
        case wrong(named: String)
        /// Nothing in the catalog came close enough to name.
        case unrecognized
    }

    /// Judges free text against the round's answer.
    ///
    /// **Delegated to `LabelRecognitionService` in full.** The guess is handed
    /// over as a single `RecognizedString` — which is exactly what a provider
    /// returns for a one-line label — and the resulting `LabelReading` is read
    /// for what it *named*. That buys accent folding, synonyms and alternate
    /// names (`Steen` is Chenin Blanc), the length-scaled edit tolerance, and the
    /// appellation-to-region link, all of which are already tested by
    /// `LabelReaderTests` and none of which is written twice.
    ///
    /// Only **non-inferred** matches count, and that restriction is the whole
    /// correctness argument. The reading also walks the catalog: typing `BAROLO`
    /// produces an inferred region *and* an inferred country, and typing a
    /// region name produces that region's notable grapes in `grapeIDs`. Counting
    /// those would mean a player could win a grape round by naming any region
    /// that grows it, which is not a guess at the answer — it is a guess near it.
    public static func judge(
        _ guess: String,
        in round: Round,
        using service: LabelRecognitionService = .shared
    ) -> Verdict {
        let trimmed = guess.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unrecognized }

        let reading = service.read([RecognizedString(text: trimmed, confidence: 1, prominence: 1)])
        let named = reading.matches.filter { !$0.isInferred && $0.entryID != nil }

        if named.contains(where: { $0.entryID == round.answerID }) { return .correct }
        guard let first = named.first else { return .unrecognized }
        return .wrong(named: first.name)
    }

    // MARK: - Type-ahead

    /// The shortest query that produces suggestions at all (0.8.0, E2).
    ///
    /// One character must never produce a list. That is the hard requirement the
    /// spec states, and it is the requirement because a list from one letter is a
    /// *menu*: the player stops recalling a name and starts reading one, which is
    /// the round over. Two is the smallest number that cannot be reached by
    /// pressing a key at random and still narrows a shelf.
    public static let minimumSuggestionQuery = 2

    /// How many names the field will ever offer.
    ///
    /// Short on purpose and not merely for layout. The value of a type-ahead here
    /// is confirming a spelling the player already has in mind; the *cost* is
    /// every extra row, because a long list is a browsable index of the catalog
    /// with the query as its filter.
    public static let suggestionLimit = 5

    /// Names to offer as the player types.
    ///
    /// **This is E2-a, and the decision it encodes is `discovered`.** The judge
    /// counts only non-inferred matches precisely so that naming something *near*
    /// the answer cannot win a round (see `judge(_:in:)`), and a type-ahead over
    /// the whole catalog gives away by autocompletion exactly what that
    /// restriction protects: type `NEB`, read *Nebbiolo*, press GUESS. So the
    /// pool is not the catalog. It is the entries the player has already met —
    /// bookmarked, wishlisted, marked tried, or opened recently — assembled by
    /// the caller and passed in as ids.
    ///
    /// What that buys is the convenience without the give-away: a name in this
    /// list is one the player has already seen in this app, so completing it
    /// spares them the spelling of `Gewurztraminer` without telling them a wine
    /// exists. What it costs is honest and worth stating: a player who has met
    /// the answer before *can* be shown it, from two characters. That is the
    /// trade E2-a is, and it is the right way round — the alternative leaks to
    /// everyone rather than to the person who already knew.
    ///
    /// **Two clauses of the recommendation are deliberately not implemented, and
    /// the batch log carries the argument.** "Never from the answer's own
    /// category" would disable the feature outright: the first clue of every
    /// round says IT'S A GRAPE or IT'S A WINE REGION, and those are the only two
    /// categories a guess can usefully be in. And excluding the *answer itself*
    /// would be worse than the leak it prevents — a player who has met Nebbiolo,
    /// types `NEBB`, and gets nothing back has been told which entry is being
    /// withheld. Silence is information. Nothing here is filtered on the answer.
    ///
    /// - Parameters:
    ///   - typed: the raw contents of the guess field.
    ///   - discovered: entry ids the player has demonstrably encountered. Order
    ///     is respected for ties, so a caller may pass its most-recent first.
    /// - Returns: catalog spellings, prefix matches first, at most
    ///   `suggestionLimit`.
    public static func suggestions(
        for typed: String,
        among discovered: [String],
        in db: WineDatabase,
        limit: Int = suggestionLimit
    ) -> [String] {
        let query = TextNormalize.label(typed)
        guard query.count >= minimumSuggestionQuery else { return [] }

        var seen: Set<String> = []
        var prefixed: [String] = []
        var contained: [String] = []

        for id in discovered {
            guard let entry = db.entry(id: id) else { continue }
            // Grapes and regions only — the pool `round(cursor:...)` deals from,
            // so the list holds exactly the things that could be an answer. A
            // flavour or a style completing in this field is noise in a round it
            // cannot win, and noise is what makes a short list long.
            guard entry.category == .grapes || entry.category == .regions else { continue }
            guard seen.insert(entry.id).inserted else { continue }

            let folded = TextNormalize.label(entry.name)
            if folded.hasPrefix(query) {
                prefixed.append(entry.name)
            } else if folded.contains(query) {
                contained.append(entry.name)
            }
        }

        return Array((prefixed + contained).prefix(limit))
    }
}
