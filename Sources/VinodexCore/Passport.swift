import Foundation

/// The passport's rank ladder (0.7.1, D4).
///
/// **On the name.** D4 asks for progression tiers "beginning with Vinodex
/// Master", and the obvious objection is that *master* is a summit word — in
/// wine it is the top of two of the hardest qualifications there are. But
/// there is a well-known ladder where Master is a real rung with higher ones
/// above it, and it is the one a player of this kind of device already knows:
/// chess. So MASTER is the first rank the passport hands out, exactly as
/// specified, and the three above it climb from there. Nothing below it is
/// named, which is the other half of "beginning with": before your
/// twenty-fifth entry the passport shows how far you are from MASTER rather
/// than inventing a NOVICE tier to fill the space. There is already a NOVICE
/// in this app — `QuizTier`'s — and it means something else.
///
/// Deliberately *not* the real credentials. Master Sommelier and Master of
/// Wine are protected titles belonging to two specific institutes, and handing
/// one out for tasting a hundred grapes in a game is both a trademark problem
/// and a slightly insulting joke at the expense of people who spent a decade
/// on them.
///
/// **How you rank up: tried entries, and only tried entries.** One axis, on
/// purpose. The passport already reports six other things — colours, rarities,
/// countries, continents, streak, quiz tier — and the six *badges* are what
/// reward those; a rank that weighted all of them would be a number nobody
/// could predict the next move of. The tried count is the one figure on this
/// screen a user can see going up and knows how to raise.
///
/// Absolute thresholds rather than fractions of the catalog, because the
/// catalog grows: a rank you had already earned must not be taken back by a
/// data batch. WINE MONK at 400 was the whole database at 0.7.1's 405 and will
/// be less of it later, which is the right direction for that to move.
///
/// **Five rungs since 0.8.9b, and the fifth went on the bottom** — the user's
/// ladder is APPRENTICE, MASTER, GRANDMASTER, LEGENDARY, WINE MONK. The two top
/// rungs are renames of VINODEX LEGEND and VINODEX IMMORTAL, and the `VINODEX `
/// prefix is gone from all of them: the rawValue is display copy
/// (`tiersAreNotStorage`), the user wrote all five bare, and VINODEX WINE MONK
/// reads badly where WINE MONK does not.
///
/// **`apprentice` is declared last and it is not a mistake.** This is the one
/// decision in the file worth reading before changing anything.
///
/// 0.8.7's D1 persists `storageIndex` — the *declaration* index — under
/// `passportSeenTierRank`, and `rankIndicesAreStable` pinned the enum
/// append-only precisely so that a rung could not be inserted underneath a
/// saved player and silently shift what their stored number meant. A literal
/// prepend of APPRENTICE would do exactly that: everyone stored at 0 (announced
/// MASTER) would decode as APPRENTICE, be found to hold MASTER, and be handed a
/// second "you reached MASTER" card. The doc comment that used to sit here said
/// "adding the fifth rung is an append", and it was written before anyone asked
/// for a rung at the *bottom*; it was wrong and this replaces it.
///
/// Three ways out were on the table — migrate every stored index by one, store
/// something other than the index, or stop making declaration order carry two
/// jobs. The first is a one-shot write against real user state that has to be
/// right forever and needs doing again on the next insert; the second reopens
/// the rename freedom `tiersAreNotStorage` exists to guarantee. The third costs
/// nothing on device, because it changes no stored number's meaning: MASTER is
/// still 0, GRANDMASTER 1, LEGENDARY 2, WINE MONK 3, and APPRENTICE takes the
/// unused 4.
///
/// So **declaration order is storage, and `threshold` order is the ladder**, and
/// the two no longer agree. Everything that means "which rung is higher" —
/// `ladder`, `next`, `earned(by:)`, `PassportProgress.announceTier` — compares
/// thresholds, never indices. `storageIndex` is named for its only job so that
/// the next reader cannot mistake it for a rank, and `rankIndicesAreStable`
/// now asserts both halves: that the four pre-existing indices are frozen at the
/// values already on disk, and that `ladder` is threshold-ascending and holds
/// every case.
public enum PassportTier: String, CaseIterable, Codable, Sendable, Identifiable {
    case master = "MASTER"
    case grandmaster = "GRANDMASTER"
    case legendary = "LEGENDARY"
    case wineMonk = "WINE MONK"
    /// **Appended, though it is the lowest rung.** See the type note.
    case apprentice = "APPRENTICE"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    /// Tried entries needed. `ladder` is sorted on this, and the tests assert
    /// the thresholds are distinct — two rungs at one count would make "the
    /// rung above" ambiguous.
    ///
    /// The upper four are untouched at 25/100/250/400: moving one would demote
    /// somebody who had already earned it, which is the invariant this whole
    /// ladder is built around. APPRENTICE at 5 is the new number — low enough
    /// to land in a first sitting, which is what a bottom rung is for.
    public var threshold: Int {
        switch self {
        case .apprentice: 5
        case .master: 25
        case .grandmaster: 100
        case .legendary: 250
        case .wineMonk: 400
        }
    }

    /// One line on the passport, in the second person like every badge blurb.
    public var blurb: String {
        switch self {
        case .apprentice: "Five entries tried. You have started, which is the part most people skip."
        // Reworded for 0.8.9b: this rung stopped being the first one the
        // moment APPRENTICE existed, and the old line said it was.
        case .master: "Twenty-five. The ladder proper begins here."
        case .grandmaster: "A hundred. You are no longer guessing."
        case .legendary: "Two hundred and fifty. Most of the book."
        case .wineMonk: "Four hundred. There is very little left to pour."
        }
    }

    /// **The persisted token, and nothing else.** `PassportProgress` writes this
    /// integer to `passportSeenTierRank`; the key keeps its 0.8.7 spelling
    /// because renaming a defaults key is a migration and this is not one.
    ///
    /// Deliberately *not* called `rank`, and deliberately not an ordering: since
    /// 0.8.9b the declaration order is frozen storage and the ladder is sorted on
    /// `threshold`. Comparing two of these tells you which was declared first,
    /// which is a fact about this file and not about the player.
    public var storageIndex: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// Resolves a stored index back to its rung, or nil for an index written by
    /// a build that had more rungs than this one.
    ///
    /// Nil rather than a clamp: an unrecognised index means the ledger is from
    /// the future, and treating it as the top rung we know about would announce
    /// a demotion. `announceTier` reads nil as "nothing announced", which at
    /// worst repeats one card.
    public static func fromStorage(_ index: Int) -> PassportTier? {
        let all = allCases
        return index >= 0 && index < all.count ? all[index] : nil
    }

    /// The rungs in climbing order, lowest first. **This, not `allCases`, is
    /// what a screen listing the ladder should draw.**
    public static let ladder: [PassportTier] = allCases.sorted { $0.threshold < $1.threshold }

    /// The drawn tier badge (0.8.9a, A4) — a numbered shield, I through V.
    ///
    /// **A switch rather than `UIGlyph(rawValue: "level\(n)")`.** The arithmetic
    /// version reads better and fails worse: a sixth rung would resolve to nil
    /// at runtime with nothing to catch it. Exhaustive here means adding a rung
    /// is a compile error in the one file that has to decide what it looks like.
    ///
    /// **The shields are ladder positions, so four of them moved** (0.8.9b).
    /// `level5` came out of `UIGlyph.unwired` and went to WINE MONK, and each
    /// rung below it shifted up one picture — a player holding MASTER sees
    /// shield II where they saw shield I. That is the correct reading of a
    /// numbered shield on a five-rung ladder, and it is a visible change to
    /// four existing tiers rather than a silent one.
    public var glyph: UIGlyph {
        switch self {
        case .apprentice: .level1
        case .master: .level2
        case .grandmaster: .level3
        case .legendary: .level4
        case .wineMonk: .level5
        }
    }

    /// The rung above, or nil at the top. By threshold, not by declaration.
    public var next: PassportTier? {
        let all = Self.ladder
        guard let i = all.firstIndex(of: self), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    /// The highest tier `count` tried entries earns, or nil below APPRENTICE.
    public static func earned(by count: Int) -> PassportTier? {
        ladder.last { count >= $0.threshold }
    }
}

/// One column of the activity graph (0.7.1, D1).
public struct PassportActivityDay: Sendable, Equatable, Identifiable {
    /// A `DailyPick.dayIndex`.
    public let day: Int
    public let count: Int

    public var id: Int { day }

    public init(day: Int, count: Int) {
        self.day = day
        self.count = count
    }
}

/// The passport: what the tried shelf adds up to.
///
/// Pure arithmetic over the tried ids and the database, computed on demand —
/// no store, no persistence, nothing to migrate. In Core rather than the
/// screen that draws it for the usual reason: `VinodexUI` has no test target,
/// and "34 of 80 grapes" being wrong is a data bug, not a layout bug.
public struct Passport: Sendable, Equatable {
    /// A milestone, earned or not. The full list always comes back — a
    /// passport with the unearned stamps hidden would give no sense of what
    /// the journey still holds.
    public struct Badge: Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        public let blurb: String
        public let earned: Bool

        public init(id: String, title: String, blurb: String, earned: Bool) {
            self.id = id
            self.title = title
            self.blurb = blurb
            self.earned = earned
        }
    }

    public let triedGrapes: Int
    public let totalGrapes: Int
    public let triedStyles: Int
    public let totalStyles: Int
    /// Tried grape counts by colour, against the database's totals.
    public let byColor: [GrapeColor: Int]
    public let colorTotals: [GrapeColor: Int]
    /// Tried grape counts by rarity, against the database's totals.
    public let byRarity: [RarityLabel: Int]
    public let rarityTotals: [RarityLabel: Int]
    /// Distinct origin countries across everything tried.
    public let countries: Int
    /// Continents with at least one tried entry, by raw value.
    public let continents: [String]
    public let badges: [Badge]

    /// Everything tried, grapes and styles together — the figure the rank
    /// ladder reads, surfaced because three places were deriving it.
    public let triedTotal: Int
    /// The rank held, or nil before the first rung (0.7.1, D4).
    public let tier: PassportTier?
    /// The rung being climbed toward, or nil at the top of the ladder.
    public let nextTier: PassportTier?
    /// Progress toward `nextTier` in 0...1, measured from the *current* rung's
    /// threshold rather than from zero — a progress bar that never empties
    /// after MASTER would report 96% of the way to GRANDMASTER at 96 entries
    /// and also 24% of it at 25.
    public let towardNext: Double
    /// Entries collected per day, oldest first, one column per day including
    /// the empty ones (0.7.1, D1). A gap is information — a bar chart with the
    /// quiet days squeezed out is a chart of *when you were active*, drawn as
    /// though you were always active.
    public let activity: [PassportActivityDay]

    /// How many days the activity graph shows.
    ///
    /// **One week** (0.8.91, E1), down from thirty.
    ///
    /// The old note argued for four weeks and change so "a weekly rhythm is
    /// visible", and the upper bound it worried about was legibility — at 60 the
    /// columns are under two points wide. Thirty cleared that bound and still
    /// missed the point: this graph sits on a 225-point LCD next to a rank and
    /// three counters, and at thirty columns a single day is a 5pt sliver you
    /// cannot pick out, so what it actually showed was a texture rather than a
    /// week. Seven columns are wide enough to read *individually*, which is what
    /// makes the difference between "did I taste anything yesterday" and "the
    /// month looks busy-ish".
    ///
    /// The rhythm argument survives, inverted: a week is the rhythm. Nothing
    /// downstream depends on the number — `activity(from:today:span:)` takes it
    /// as a parameter and the `Canvas` lays itself out from `days.count` — so
    /// this constant is the whole change.
    public static let activitySpan = 7

    /// Everything above, from the tried shelf plus the two progression facts
    /// the badges need.
    ///
    /// `triedDays` and `today` are defaulted (0.7.1, D1) so the twenty-odd
    /// existing call sites and tests kept compiling unchanged: a passport
    /// computed without a log simply has a flat activity graph, which is
    /// exactly what a user who has never marked anything should see.
    public static func compute(
        tried: [String],
        in db: WineDatabase,
        bestStreak: Int,
        highestTier: QuizTier,
        triedDays: [String: Int] = [:],
        today: Int = DailyPick.dayIndex()
    ) -> Passport {
        // **One definition of "tried grapes", since 0.8.9b's C2.** This function
        // used to do the split itself, and so did two other places; the badge
        // conditions below and the discovery counters and the insight panel now
        // all read `DiscoveryIndex`, which is where the folding rules and the
        // non-empty guards moved verbatim. Nothing here changed behaviour.
        let index = DiscoveryIndex(tried: tried, in: db)
        let entries = tried.compactMap { db.entry(id: $0) }
        let grapes = index.triedGrapes
        let styles = index.triedStyles
        let allGrapes = index.allGrapes

        var byColor: [GrapeColor: Int] = [:]
        var colorTotals: [GrapeColor: Int] = [:]
        var byRarity: [RarityLabel: Int] = [:]
        var rarityTotals: [RarityLabel: Int] = [:]
        for grape in allGrapes {
            colorTotals[grape.grapeType, default: 0] += 1
            rarityTotals[grape.rarity, default: 0] += 1
        }
        for grape in grapes {
            byColor[grape.grapeType, default: 0] += 1
            byRarity[grape.rarity, default: 0] += 1
        }

        // Folded exactly like `WineDatabase.countryCount`: origins are
        // hand-authored strings that disagree on case.
        let originKeys = Set(
            entries
                .compactMap(\.origin)
                .map { TextNormalize.label($0) }
                .filter { !$0.isEmpty }
        )

        let continents = Continent.allCases.filter { continent in
            db.countries(in: continent)
                .contains { originKeys.contains(TextNormalize.label($0)) }
        }.map(\.rawValue)

        // **The four completion conditions now live on `DiscoveryIndex`**
        // (0.8.9b, C2), with their folding rules and their non-empty guards
        // unchanged — see that type for the argument. They moved because the
        // insight panel and the X/N counters ask the same questions, and three
        // separate answers to "have you tried this grape" is how a badge and a
        // counter come to disagree on one screen.
        let regionComplete = index.regionComplete(in: db)
        let allNoble = index.allNobleTried
        let allGrapesTried = index.allGrapesTried
        let allStylesTried = index.allStylesTried

        let triedCount = index.triedTotal
        let badges: [Badge] = [
            Badge(
                id: "firstSip", title: "FIRST SIP",
                blurb: "Mark your first grape or style as tried.",
                earned: triedCount >= 1
            ),
            Badge(
                id: "tenBottles", title: "TEN BOTTLES",
                blurb: "Ten tastings on the shelf.",
                earned: triedCount >= 10
            ),
            Badge(
                id: "allNoble", title: "ALL NOBLE",
                blurb: "Every noble grape, tried.",
                earned: allNoble
            ),
            Badge(
                id: "regionComplete", title: "REGION COMPLETE",
                blurb: "Every notable grape of one region, tried.",
                earned: regionComplete
            ),
            Badge(
                id: "streakWeek", title: "STREAK WEEK",
                blurb: "A seven-day daily challenge streak.",
                earned: bestStreak >= 7
            ),
            Badge(
                id: "sommelier", title: "SOMMELIER",
                blurb: "The quiz's top tier, unlocked.",
                earned: highestTier == .sommelier
            ),
            // **Appended, not inserted (0.8.6, C6).** The array's order is the
            // order the passport grid draws, the order `StampCatalog.all` mirrors
            // and the order the unlock queue announces in; the two hardest badges
            // in the set belong at the end of all three, and appending is also
            // what keeps `PassportProgress`'s seeded ids stable for anyone
            // holding a 0.8.5 passport.
            Badge(
                id: "allGrapes", title: "TRIED ALL GRAPES",
                blurb: "Every grape in the catalog, tried.",
                earned: allGrapesTried
            ),
            Badge(
                id: "allStyles", title: "TRIED ALL STYLES",
                blurb: "Every style in the catalog, tried.",
                earned: allStylesTried
            ),
        ]

        let tier = PassportTier.earned(by: triedCount)
        // Unranked climbs toward the *bottom* of the ladder, which is no longer
        // spelled `.master` (0.8.9b). `ladder.first` cannot be nil for a
        // non-empty enum, but the fallback keeps this total rather than trapping.
        let nextTier = tier?.next ?? (tier == nil ? PassportTier.ladder.first : nil)
        // The floor of the bar: zero before the first rung, the held rung's
        // threshold after it.
        let floor = tier?.threshold ?? 0
        let toward: Double
        if let nextTier {
            let span = Double(nextTier.threshold - floor)
            toward = span > 0 ? min(max(Double(triedCount - floor) / span, 0), 1) : 1
        } else {
            // Top of the ladder: full, and it stays full.
            toward = 1
        }

        return Passport(
            triedGrapes: grapes.count,
            totalGrapes: db.databaseStats.grapes,
            triedStyles: styles.count,
            totalStyles: db.databaseStats.styles,
            byColor: byColor,
            colorTotals: colorTotals,
            byRarity: byRarity,
            rarityTotals: rarityTotals,
            countries: originKeys.count,
            continents: continents,
            badges: badges,
            triedTotal: triedCount,
            tier: tier,
            nextTier: nextTier,
            towardNext: toward,
            activity: activity(from: triedDays, today: today)
        )
    }

    /// The last `span` days as one column each, oldest first (0.7.1, D1).
    ///
    /// Static and pure, taking `today` rather than reading the clock, so the
    /// series is testable without freezing time — the same reason
    /// `DailyPick.dayIndex(for:calendar:)` takes a date.
    ///
    /// Days *after* today are impossible and days before the window are simply
    /// off the left edge; both are dropped rather than clamped into the first
    /// or last column, which would put a spike on the chart's edge that no day
    /// actually earned.
    public static func activity(
        from log: [String: Int],
        today: Int,
        span: Int = activitySpan
    ) -> [PassportActivityDay] {
        guard span > 0 else { return [] }
        let first = today - span + 1
        var counts: [Int: Int] = [:]
        for day in log.values where day >= first && day <= today {
            counts[day, default: 0] += 1
        }
        return (first...today).map { PassportActivityDay(day: $0, count: counts[$0] ?? 0) }
    }
}
