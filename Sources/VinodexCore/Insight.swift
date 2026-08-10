import Foundation

// MARK: - The palate profile (0.8.9b, C1)

/// What the tried set says about the drinker.
///
/// **Derived, never authored.** The v9.0 spec offered a choice between
/// hand-written per-entry lore and a profile computed from the catalog plus the
/// tried set, and adopted the second. This is that: a weighted bag of tasting
/// notes, a red/white lean, the mean of the four characteristic bars, and a
/// country lean — all of it recomputed from the shelf, none of it stored.
///
/// **Why nothing here is persisted.** A profile is a *function* of the tried
/// set, and the tried set already persists. Caching it would mean a second
/// thing to invalidate on every tasting and a migration hazard the moment a
/// field is added — the exact shape of the three near-misses `DeviceBuild` and
/// `QuizSession` recorded. Building it is a few hundred dictionary inserts over
/// an array already in memory.
///
/// **Ties break by name, everywhere.** Swift's dictionary iteration order is not
/// stable between runs, so every "the top note", "the closest tried grape" and
/// "the best recommendation" in this file sorts by score and then by name. A
/// panel that reordered itself on a re-render would read as a bug, and a test
/// that passed nine times in ten is worse than no test.
public struct PalateProfile: Sendable, Equatable {
    /// Folded note key to weight, 0...1 with the most-drunk note at 1.
    public let noteWeights: [String: Double]
    /// The most-drunk notes as the catalog spells them, strongest first.
    public let topNotes: [String]
    /// Share of tried grapes that are red, 0...1. Meaningless at zero grapes,
    /// which is why `sampleSize` is published alongside it.
    public let redShare: Double
    /// Means of the tried grapes' four stat bars, on the same 0...5 scale.
    public let meanBody: Double
    public let meanAcid: Double
    public let meanTannin: Double
    public let meanAromatics: Double
    /// Folded country to weight, 0...1 with the most-drunk country at 1.
    public let countryWeights: [String: Double]
    /// The most-drunk countries as the catalog spells them, strongest first.
    public let topCountries: [String]
    /// Tastings the profile was built from — grapes plus styles.
    public let sampleSize: Int

    /// Below this the profile exists but says nothing worth printing. Used only
    /// by callers deciding whether to *show* a derived figure; the arithmetic
    /// itself is defined at any size.
    public static let meaningfulSample = 3

    public init(index: DiscoveryIndex) {
        // Sorted by id so the display spellings picked below are the same on
        // every run — see the type note on ties.
        let grapes = index.triedGrapes.sorted { $0.id < $1.id }
        let styles = index.triedStyles.sorted { $0.id < $1.id }
        sampleSize = grapes.count + styles.count

        var noteCounts: [String: Int] = [:]
        var noteNames: [String: String] = [:]
        for note in grapes.flatMap({ $0.tastingProfile ?? [] }) + styles.flatMap(\.tastingProfile) {
            let key = TextNormalize.label(note.note)
            guard !key.isEmpty else { continue }
            noteCounts[key, default: 0] += 1
            if noteNames[key] == nil { noteNames[key] = note.note }
        }
        noteWeights = Self.normalized(noteCounts)
        topNotes = Self.ranked(noteWeights, names: noteNames)

        var countryCounts: [String: Int] = [:]
        var countryNames: [String: String] = [:]
        for grape in grapes {
            let key = TextNormalize.label(grape.grapeCountryOfOrigin)
            guard !key.isEmpty else { continue }
            countryCounts[key, default: 0] += 1
            if countryNames[key] == nil { countryNames[key] = grape.grapeCountryOfOrigin }
        }
        countryWeights = Self.normalized(countryCounts)
        topCountries = Self.ranked(countryWeights, names: countryNames)

        if grapes.isEmpty {
            redShare = 0
            meanBody = 0
            meanAcid = 0
            meanTannin = 0
            meanAromatics = 0
        } else {
            let n = Double(grapes.count)
            redShare = Double(grapes.filter { $0.grapeType == .red }.count) / n
            meanBody = grapes.reduce(0) { $0 + $1.grapeCharacteristics.body } / n
            meanAcid = grapes.reduce(0) { $0 + $1.grapeCharacteristics.acid } / n
            meanTannin = grapes.reduce(0) { $0 + $1.grapeCharacteristics.tannin } / n
            meanAromatics = grapes.reduce(0) { $0 + $1.grapeCharacteristics.aromatics } / n
        }
    }

    private static func normalized(_ counts: [String: Int]) -> [String: Double] {
        guard let peak = counts.values.max(), peak > 0 else { return [:] }
        return counts.mapValues { Double($0) / Double(peak) }
    }

    private static func ranked(_ weights: [String: Double], names: [String: String]) -> [String] {
        weights
            .sorted { a, b in
                a.value == b.value ? a.key < b.key : a.value > b.value
            }
            .compactMap { names[$0.key] }
    }

    // MARK: Matching

    /// How much this entry looks like what you drink, 0...100 — or nil when the
    /// question does not apply.
    ///
    /// **Nil is a real answer and there are three of them.** An empty profile
    /// (nothing tried) has nothing to compare against; regions, flavours and
    /// continents are not things you drink, so a "palate match" on one would be
    /// a category error; and an entry the catalog gave no tasting notes cannot
    /// be scored on the axis that carries most of the weight. Returning 0 in any
    /// of those cases would print "Palate match 0%" — a confident statement that
    /// you would hate it — for what is actually an absence of data.
    ///
    /// **The weights are a product decision and this is the only place they
    /// appear**, on `LabelConfidence`'s precedent: tuning the mix is an edit
    /// here rather than a hunt through the panel.
    ///
    /// Grapes score on notes, then on how close the four stat bars sit to your
    /// means, then on colour. Styles have no stat bars and no colour of their
    /// own, so the third of the score that grapes spend on those goes to
    /// something a style does have: how many of its notable grapes you have
    /// already tried.
    public func match(for entry: WineEntry, index: DiscoveryIndex) -> Int? {
        guard sampleSize > 0 else { return nil }
        let notes = entry.tastingProfile
        guard !notes.isEmpty else { return nil }

        let noteScore = notes.reduce(0.0) { $0 + (noteWeights[TextNormalize.label($1.note)] ?? 0) }
            / Double(notes.count)

        switch entry {
        case .grape(let g):
            let c = g.grapeCharacteristics
            // Mean absolute distance across the four authored bars, over the
            // 0...5 range they are authored on. COLOR INTENSITY is left out:
            // it is a description of the liquid, not of a preference.
            // One `abs` per line, each annotated: four of them summed and then
            // divided by an integer literal is the shape the type checker gives
            // up on, and it did. The arithmetic is unchanged.
            let bodyGap: Double = abs(c.body - meanBody)
            let acidGap: Double = abs(c.acid - meanAcid)
            let tanninGap: Double = abs(c.tannin - meanTannin)
            let aromaticsGap: Double = abs(c.aromatics - meanAromatics)
            let distance: Double = (bodyGap + acidGap + tanninGap + aromaticsGap) / 4
            let statScore = max(0, 1 - distance / 5)
            let colorScore = g.grapeType == .red ? redShare : 1 - redShare
            return Self.percent(0.55 * noteScore + 0.25 * statScore + 0.20 * colorScore)

        case .style:
            let roster = entry.notableGrapes
                .map { TextNormalize.label($0) }
                .filter { index.allGrapeKeys.contains($0) }
            let overlap = roster.isEmpty
                ? 0
                : Double(roster.filter { index.triedGrapeKeys.contains($0) }.count) / Double(roster.count)
            return Self.percent(0.70 * noteScore + 0.30 * overlap)

        case .region, .flavor, .continent:
            return nil
        }
    }

    private static func percent(_ value: Double) -> Int {
        min(100, max(0, Int((value * 100).rounded())))
    }

    // MARK: "You might like…" (C1)

    /// A recommendation is only worth printing above this. Set so the list is
    /// short and defensible rather than a ranked dump of the whole catalog:
    /// below a coin-flip's worth of agreement, "you might like this" is a guess
    /// wearing a number.
    public static let recommendationFloor = 55

    /// Untried grapes and styles that score well against the profile, best
    /// first, ties broken by name.
    ///
    /// Returns empty rather than filler when the profile is thin — a
    /// recommendation drawn from two tastings is a coincidence, and an empty
    /// shelf is an honest answer the panel can render as a nudge to try more.
    public func recommendations(index: DiscoveryIndex, limit: Int = 6) -> [WineEntry] {
        guard sampleSize >= Self.meaningfulSample, limit > 0 else { return [] }
        let triedIDs = Set(index.triedGrapes.map(\.id)).union(index.triedStyleIDs)
        return index.catalog.allTastable
            .filter { !triedIDs.contains($0.id) }
            .compactMap { entry -> (entry: WineEntry, score: Int)? in
                guard let score = match(for: entry, index: index),
                      score >= Self.recommendationFloor else { return nil }
                return (entry, score)
            }
            .sorted { a, b in
                a.score == b.score ? a.entry.name < b.entry.name : a.score > b.score
            }
            .prefix(limit)
            .map(\.entry)
    }
}

// MARK: - Depth (0.8.9b, B2)

/// How much of the insight panel has been unlocked.
///
/// **The panel deepens with the tried count, and the thresholds are here rather
/// than in the view** for the reason every other rule in Core is: `VinodexUI`
/// has no test target, and "the palate match appeared after two tastings" is a
/// product bug that a Linux test can catch and a screenshot cannot.
///
/// The ordering is by *reliability*, not by how impressive the line sounds. A
/// palate match computed from four grapes is arithmetic performed on noise, so
/// it waits; a region roster is a true statement at one tastings and shows
/// immediately.
public enum InsightDepth: Int, CaseIterable, Sendable, Comparable {
    /// Nothing tried. The panel is a teaser and shows no derived lines at all.
    case teaser
    case first
    case shallow
    case deep
    case complete

    /// Tried entries needed. Ascending, asserted in the tests.
    public var threshold: Int {
        switch self {
        case .teaser: 0
        case .first: 1
        case .shallow: 5
        case .deep: 15
        case .complete: 40
        }
    }

    public static func earned(by count: Int) -> InsightDepth {
        allCases.last { count >= $0.threshold } ?? .teaser
    }

    /// The depth above, or nil at the top.
    public var deeper: InsightDepth? {
        let all = Self.allCases
        let i = rawValue + 1
        return i < all.count ? all[i] : nil
    }

    public static func < (lhs: InsightDepth, rhs: InsightDepth) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// One derived sentence in the panel.
public struct InsightLine: Sendable, Equatable, Identifiable {
    /// **At most one line per kind**, which is what makes `id` safe to derive
    /// from the kind alone and what stops the panel printing two region rosters
    /// for a grape that names four regions.
    public enum Kind: String, Sendable, CaseIterable {
        /// You have tried this, and when.
        case tried
        /// How much of some region's grape roster you have tried.
        case regionProgress
        /// How much of this style's or region's own grape roster you have tried.
        case grapeRoster
        /// How much of this entry's country you have tried.
        case countryProgress
        /// The tried entry this one most resembles.
        case similarTried
        /// The derived percentage.
        case palateMatch
        /// How much of this grape's rarity band you have tried.
        case rarityProgress

        /// The depth at which this line unlocks. See `InsightDepth`.
        public var depth: InsightDepth {
            switch self {
            case .tried, .regionProgress, .grapeRoster: .first
            case .countryProgress, .similarTried: .shallow
            case .palateMatch: .deep
            case .rarityProgress: .complete
            }
        }
    }

    public let kind: Kind
    public let text: String

    public var id: String { kind.rawValue }

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// Everything the INSIGHT panel needs to draw itself.
public struct InsightPanel: Sendable, Equatable {
    public let depth: InsightDepth
    /// In `InsightLine.Kind.allCases` order, which is the order they are drawn.
    public let lines: [InsightLine]
    /// The pre-first-tasting copy, and nil once anything has been tried.
    public let teaser: String?
    /// The next depth and how many more tastings reach it — nil at the top.
    public let nextDepth: InsightDepth?
    public let toNextDepth: Int

    public var isEmpty: Bool { lines.isEmpty && teaser == nil }

    public init(
        depth: InsightDepth,
        lines: [InsightLine],
        teaser: String?,
        nextDepth: InsightDepth?,
        toNextDepth: Int
    ) {
        self.depth = depth
        self.lines = lines
        self.teaser = teaser
        self.nextDepth = nextDepth
        self.toNextDepth = toNextDepth
    }
}

// MARK: - The service (0.8.9b, B1)

/// Turns an entry plus a tried set into the sentences the INSIGHT panel prints.
///
/// **INSIGHT is the player-facing word, and it is the same word as the type.**
/// This batch had a free choice — the concept did not exist anywhere in the tree
/// — and it also had to fix `ToolIntro`'s "the written paper", which is a string
/// that drifted away from the identifier beside it and survived a whole rename.
/// Picking a prettier synonym for the screen while the code said `Insight` would
/// be starting that same fault deliberately. Phase 2's first-insight-unlocked
/// line, and every piece of copy after it, says INSIGHT.
///
/// **Pure, static, and takes everything it needs.** No store reference, no
/// clock: `triedDays` and `today` arrive as parameters exactly as they do on
/// `Passport.compute`, so a test can put a tasting three days in the past
/// without freezing time.
public enum InsightService {

    /// The panel for one entry.
    ///
    /// **What is not here, and why.** The spec's fourth example line was
    /// "pairings weighted to your history". The catalog carries no food-pairing
    /// data of any kind — `Exam.Subject.foodPairing` is a quiz category, not a
    /// per-entry field — so under the adopted "derived only, no hand-written
    /// lore" default there is nothing to derive one from. Inventing pairings
    /// from flavour notes would be exactly the plausible-but-wrong output
    /// `GrapeCharacteristics` already refuses to produce. It needs authored
    /// data before it can be a line.
    public static func panel(
        for entry: WineEntry,
        index: DiscoveryIndex,
        profile: PalateProfile,
        in db: WineDatabase,
        triedDays: [String: Int] = [:],
        today: Int = DailyPick.dayIndex()
    ) -> InsightPanel {
        let count = index.triedTotal
        let depth = InsightDepth.earned(by: count)
        let next = depth.deeper

        guard depth > .teaser else {
            return InsightPanel(
                depth: depth,
                lines: [],
                teaser: "Mark a grape or style TRIED and this panel starts reading your palate back to you.",
                nextDepth: next,
                toNextDepth: max(0, (next?.threshold ?? 0) - count)
            )
        }

        var lines: [InsightLine] = []
        func add(_ kind: InsightLine.Kind, _ text: @autoclosure () -> String?) {
            guard depth >= kind.depth, let text = text() else { return }
            lines.append(InsightLine(kind: kind, text: text))
        }

        add(.tried, triedLine(for: entry, index: index, triedDays: triedDays, today: today))
        add(.regionProgress, regionLine(for: entry, index: index, in: db))
        add(.grapeRoster, rosterLine(for: entry, index: index))
        add(.countryProgress, countryLine(for: entry, index: index))
        add(.similarTried, similarLine(for: entry, index: index))
        add(.palateMatch, matchLine(for: entry, index: index, profile: profile))
        add(.rarityProgress, rarityLine(for: entry, index: index))

        // Drawn in enum order rather than in the order they were appended, so a
        // line added later in this function cannot silently reorder the panel.
        let order = InsightLine.Kind.allCases
        lines.sort {
            (order.firstIndex(of: $0.kind) ?? 0) < (order.firstIndex(of: $1.kind) ?? 0)
        }

        return InsightPanel(
            depth: depth,
            lines: lines,
            teaser: nil,
            nextDepth: next,
            toNextDepth: max(0, (next?.threshold ?? 0) - count)
        )
    }

    // MARK: Individual lines

    private static func triedLine(
        for entry: WineEntry,
        index: DiscoveryIndex,
        triedDays: [String: Int],
        today: Int
    ) -> String? {
        let isTried = entry.category == .grapes
            ? index.hasTriedGrape(named: entry.name)
            : index.triedStyleIDs.contains(entry.id)
        guard isTried else { return nil }
        // A day in the future is a clock that moved, not a negative age.
        guard let day = triedDays[entry.id], day <= today else {
            return "On your tried shelf."
        }
        switch today - day {
        case 0: return "Tried today."
        case 1: return "Tried yesterday."
        case let days: return "Tried \(days) days ago."
        }
    }

    /// "You've tried 3 of 6 Piedmont grapes."
    ///
    /// For a region that is its own roster; for a grape or a style it is the
    /// first key region that resolves to an entry the catalog holds. First
    /// rather than best: a grape names its regions in authored order and the
    /// leading one is the one it is known for, which is also the one a reader
    /// expects to see named.
    private static func regionLine(
        for entry: WineEntry,
        index: DiscoveryIndex,
        in db: WineDatabase
    ) -> String? {
        let region: WineEntry?
        switch entry {
        case .region: region = entry
        case .grape(let g):
            region = (g.grapeNotableRegions + g.details.keyRegions)
                .lazy
                .compactMap { db.entry(named: $0, category: .regions) }
                .first
        case .style:
            region = entry.keyRegions
                .lazy
                .compactMap { db.entry(named: $0, category: .regions) }
                .first
        case .flavor, .continent:
            region = nil
        }
        guard let region else { return nil }
        guard let (tried, total) = roster(of: region, index: index) else { return nil }
        return "You've tried \(tried) of \(total) \(region.name) grapes."
    }

    /// A style's own grape roster. Regions are covered by `regionLine`, which
    /// names them; printing both for a region would be the same sentence twice.
    private static func rosterLine(for entry: WineEntry, index: DiscoveryIndex) -> String? {
        guard case .style = entry else { return nil }
        guard let (tried, total) = roster(of: entry, index: index) else { return nil }
        return "You've tried \(tried) of \(total) grapes behind \(entry.name)."
    }

    /// Tried and total over an entry's `notableGrapes`, counting only the ones
    /// that resolve to a grape the catalog holds — an unresolvable name is not a
    /// grape anybody can go and try, and counting it would make the roster
    /// permanently incompletable. Nil when nothing resolves.
    private static func roster(of entry: WineEntry, index: DiscoveryIndex) -> (Int, Int)? {
        let resolvable = Set(
            entry.notableGrapes
                .map { TextNormalize.label($0) }
                .filter { index.allGrapeKeys.contains($0) }
        )
        guard !resolvable.isEmpty else { return nil }
        return (resolvable.filter { index.triedGrapeKeys.contains($0) }.count, resolvable.count)
    }

    /// "You've tried 12 of 34 grapes from Italy."
    ///
    /// Named with a preposition rather than an adjective on purpose: the catalog
    /// stores country names, and "Italy" to "Italian" is a lookup table nobody
    /// has written and that gets New Zealand wrong.
    private static func countryLine(for entry: WineEntry, index: DiscoveryIndex) -> String? {
        let country: String?
        switch entry {
        case .grape(let g): country = g.grapeCountryOfOrigin
        case .region, .style: country = entry.origin
        case .flavor, .continent: country = nil
        }
        guard let country, !country.isEmpty else { return nil }
        // Pre-bucketed at load — see `DiscoveryCatalog`. Filtering 180 grapes
        // and folding each one's origin string, here, would be a fold per grape
        // per draw of a panel that redraws on scroll.
        let pool = index.catalog.grapesByCountry[TextNormalize.label(country)] ?? []
        guard pool.count > 1 else { return nil }
        let tried = pool.filter { index.triedGrapeKeys.contains(TextNormalize.label($0.common.name)) }
        return "You've tried \(tried.count) of \(pool.count) grapes from \(country)."
    }

    /// "Similar to Nebbiolo, which you've tried."
    ///
    /// Nearest tried grape by tasting-note overlap, as a Jaccard ratio so a
    /// grape with fifteen notes does not beat a grape with four purely by having
    /// more of them. Requires real overlap — two entries sharing nothing are not
    /// similar, and the honest output is silence.
    private static func similarLine(for entry: WineEntry, index: DiscoveryIndex) -> String? {
        let mine = Set(entry.tastingProfile.map { TextNormalize.label($0.note) })
        guard !mine.isEmpty else { return nil }

        var best: (name: String, score: Double)?
        for grape in index.triedGrapes where grape.id != entry.id {
            let theirs = Set((grape.tastingProfile ?? []).map { TextNormalize.label($0.note) })
            guard !theirs.isEmpty else { continue }
            let shared = mine.intersection(theirs).count
            guard shared > 0 else { continue }
            let score = Double(shared) / Double(mine.union(theirs).count)
            // Ties by name, per the determinism rule on `PalateProfile`.
            if let current = best,
               score < current.score || (score == current.score && grape.common.name >= current.name) {
                continue
            }
            best = (grape.common.name, score)
        }
        guard let best else { return nil }
        return "Similar to \(best.name), which you've tried."
    }

    private static func matchLine(
        for entry: WineEntry,
        index: DiscoveryIndex,
        profile: PalateProfile
    ) -> String? {
        guard let percent = profile.match(for: entry, index: index) else { return nil }
        return "Palate match \(percent)%."
    }

    /// "You've tried 4 of 12 NOBLE grapes." Grapes only — a style's rarity is
    /// optional in the data and absent on most of them.
    private static func rarityLine(for entry: WineEntry, index: DiscoveryIndex) -> String? {
        guard case .grape(let g) = entry else { return nil }
        let band = index.catalog.grapesByRarity[g.rarity] ?? []
        guard band.count > 1 else { return nil }
        let tried = band.filter { index.triedGrapeKeys.contains(TextNormalize.label($0.common.name)) }
        return "You've tried \(tried.count) of \(band.count) \(g.rarity.rawValue) grapes."
    }
}
