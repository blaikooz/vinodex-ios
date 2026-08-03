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
/// data batch. IMMORTAL at 400 was the whole database at 0.7.1's 405 and will
/// be less of it later, which is the right direction for that to move.
public enum PassportTier: String, CaseIterable, Codable, Sendable, Identifiable {
    case master = "VINODEX MASTER"
    case grandmaster = "VINODEX GRANDMASTER"
    case legend = "VINODEX LEGEND"
    case immortal = "VINODEX IMMORTAL"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    /// Tried entries needed. Ascending, and asserted so in the tests.
    public var threshold: Int {
        switch self {
        case .master: 25
        case .grandmaster: 100
        case .legend: 250
        case .immortal: 400
        }
    }

    /// One line on the passport, in the second person like every badge blurb.
    public var blurb: String {
        switch self {
        case .master: "Twenty-five entries tried. The ladder starts here."
        case .grandmaster: "A hundred. You are no longer guessing."
        case .legend: "Two hundred and fifty. Most of the book."
        case .immortal: "Four hundred. There is very little left to pour."
        }
    }

    /// Order for comparisons: master < grandmaster < legend < immortal.
    public var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// The rung above, or nil at the top.
    public var next: PassportTier? {
        let all = Self.allCases
        let i = rank + 1
        return i < all.count ? all[i] : nil
    }

    /// The highest tier `count` tried entries earns, or nil below MASTER.
    public static func earned(by count: Int) -> PassportTier? {
        allCases.last { count >= $0.threshold }
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
    /// Four weeks and change. Long enough that a weekly rhythm is visible,
    /// short enough that thirty bars still have width on the LCD — at 60 the
    /// columns are under two points wide and the chart stops being readable
    /// before it stops being drawable.
    public static let activitySpan = 30

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
        let entries = tried.compactMap { db.entry(id: $0) }
        let grapes = entries.compactMap { if case .grape(let g) = $0 { g } else { nil } }
        let styles = entries.filter { $0.category == .styles }

        let allGrapes = db.entries(in: .grapes)
            .compactMap { if case .grape(let g) = $0 { g } else { nil } }

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

        // A region is complete when every notable grape of it that resolves
        // to a real entry has been tried. Regions naming nothing resolvable
        // cannot be completed — an empty requirement is not an achievement.
        let triedGrapeKeys = Set(grapes.map { TextNormalize.label($0.common.name) })
        let allGrapeKeys = Set(allGrapes.map { TextNormalize.label($0.common.name) })
        let regionComplete = db.entries(in: .regions).contains { region in
            let resolvable = region.notableGrapes
                .map { TextNormalize.label($0) }
                .filter { allGrapeKeys.contains($0) }
            return !resolvable.isEmpty && resolvable.allSatisfy { triedGrapeKeys.contains($0) }
        }

        let nobleGrapes = allGrapes.filter { $0.rarity == .noble }
        let allNoble = !nobleGrapes.isEmpty && nobleGrapes.allSatisfy {
            triedGrapeKeys.contains(TextNormalize.label($0.common.name))
        }

        let triedCount = grapes.count + styles.count
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
        ]

        let tier = PassportTier.earned(by: triedCount)
        let nextTier = tier?.next ?? (tier == nil ? PassportTier.master : nil)
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
