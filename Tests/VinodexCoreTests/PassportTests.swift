import Testing
import Foundation
@testable import VinodexCore

@Suite("Passport")
struct PassportTests {
    private let db = WineDatabase.shared

    private var allGrapes: [GrapeEntry] {
        db.entries(in: .grapes).compactMap { if case .grape(let g) = $0 { g } else { nil } }
    }

    private func compute(
        tried: [String],
        bestStreak: Int = 0,
        highestTier: QuizTier = .novice
    ) -> Passport {
        Passport.compute(tried: tried, in: db, bestStreak: bestStreak, highestTier: highestTier)
    }

    @Test("an empty shelf is an empty passport with every stamp waiting")
    func emptyShelf() {
        let passport = compute(tried: [])
        #expect(passport.triedGrapes == 0)
        #expect(passport.triedStyles == 0)
        #expect(passport.countries == 0)
        #expect(passport.continents.isEmpty)
        // 8 since 0.8.6 (C6): TRIED ALL GRAPES and TRIED ALL STYLES.
        #expect(passport.badges.count == 8)
        #expect(passport.badges.allSatisfy { !$0.earned })
    }

    @Test("totals come from the database, not the shelf")
    func totalsMatchDatabase() {
        let stats = db.databaseStats
        let passport = compute(tried: [])
        #expect(passport.totalGrapes == stats.grapes)
        #expect(passport.totalStyles == stats.styles)
        #expect(passport.colorTotals.values.reduce(0, +) == stats.grapes)
        #expect(passport.rarityTotals.values.reduce(0, +) == stats.grapes)
    }

    @Test("counts split by colour and rarity and add back up")
    func countsAddUp() {
        let tried = allGrapes.prefix(12).map(\.id)
        let passport = compute(tried: Array(tried))
        #expect(passport.triedGrapes == 12)
        #expect(passport.byColor.values.reduce(0, +) == 12)
        #expect(passport.byRarity.values.reduce(0, +) == 12)
        for (color, count) in passport.byColor {
            #expect(count <= passport.colorTotals[color] ?? 0, "\(color)")
        }
    }

    /// Stale ids must not count — the shelf keeps ids, the passport keeps score.
    @Test("unresolvable ids are ignored")
    func staleIDsIgnored() {
        let passport = compute(tried: ["NOT_REAL", allGrapes[0].id])
        #expect(passport.triedGrapes == 1)
    }

    @Test("countries fold case-insensitively")
    func countryFolding() {
        let grape = allGrapes.first { !$0.grapeCountryOfOrigin.isEmpty }!
        let passport = compute(tried: [grape.id, grape.id])
        // One origin, however many entries carry it.
        #expect(passport.countries >= 1)

        // A second grape from the same country adds no new stamp.
        let key = TextNormalize.label(grape.grapeCountryOfOrigin)
        if let sibling = allGrapes.first(where: {
            $0.id != grape.id && TextNormalize.label($0.grapeCountryOfOrigin) == key
        }) {
            let both = compute(tried: [grape.id, sibling.id])
            let one = compute(tried: [grape.id])
            #expect(both.countries == one.countries)
        }
    }

    @Test("the first sip and ten bottles stamps track the count")
    func countBadges() {
        func badge(_ id: String, in passport: Passport) -> Bool {
            passport.badges.first { $0.id == id }?.earned ?? false
        }
        let one = compute(tried: [allGrapes[0].id])
        #expect(badge("firstSip", in: one))
        #expect(!badge("tenBottles", in: one))

        let ten = compute(tried: allGrapes.prefix(10).map(\.id))
        #expect(badge("tenBottles", in: ten))
    }

    @Test("all noble is earned by exactly the noble set")
    func allNobleBadge() {
        let nobles = allGrapes.filter { $0.rarity == .noble }
        #expect(!nobles.isEmpty)

        let almost = compute(tried: nobles.dropLast().map(\.id))
        #expect(!(almost.badges.first { $0.id == "allNoble" }?.earned ?? true))

        let all = compute(tried: nobles.map(\.id))
        #expect(all.badges.first { $0.id == "allNoble" }?.earned == true)
    }

    @Test("completing one region's notable grapes earns the stamp")
    func regionCompleteBadge() {
        // Find a real region whose notable grapes resolve, and try exactly those.
        let grapesByKey = Dictionary(
            allGrapes.map { (TextNormalize.label($0.common.name), $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
        let region = db.entries(in: .regions).first { region in
            let resolvable = region.notableGrapes.compactMap { grapesByKey[TextNormalize.label($0)] }
            return !resolvable.isEmpty
        }
        guard let region else {
            Issue.record("no region with resolvable notable grapes in the dataset")
            return
        }
        let tried = region.notableGrapes.compactMap { grapesByKey[TextNormalize.label($0)] }
        let passport = compute(tried: tried)
        #expect(passport.badges.first { $0.id == "regionComplete" }?.earned == true)
    }

    @Test("the streak and tier stamps read their inputs")
    func progressionBadges() {
        let week = compute(tried: [], bestStreak: 7)
        #expect(week.badges.first { $0.id == "streakWeek" }?.earned == true)
        let six = compute(tried: [], bestStreak: 6)
        #expect(six.badges.first { $0.id == "streakWeek" }?.earned == false)

        let top = compute(tried: [], highestTier: .sommelier)
        #expect(top.badges.first { $0.id == "sommelier" }?.earned == true)
        let mid = compute(tried: [], highestTier: .enthusiast)
        #expect(mid.badges.first { $0.id == "sommelier" }?.earned == false)
    }
}
