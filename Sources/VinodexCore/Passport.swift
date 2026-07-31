import Foundation

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

    /// Everything above, from the tried shelf plus the two progression facts
    /// the badges need.
    public static func compute(
        tried: [String],
        in db: WineDatabase,
        bestStreak: Int,
        highestTier: QuizTier
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
            badges: badges
        )
    }
}
