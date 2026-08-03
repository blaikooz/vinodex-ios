import Testing
import Foundation
@testable import VinodexCore

/// The passport's rank ladder (0.7.1, D4).
@Suite("Passport tiers")
struct PassportTierTests {

    /// D4's headline requirement, pinned by name. The spec names one tier and
    /// says it is the first; if a later batch inserts something below it, this
    /// is what says the batch was wrong.
    @Test("D4: the ladder begins with VINODEX MASTER")
    func masterIsFirst() {
        #expect(PassportTier.allCases.first == .master)
        #expect(PassportTier.master.displayName == "VINODEX MASTER")
        #expect(PassportTier.master.rank == 0)
    }

    @Test("thresholds ascend with rank")
    func thresholdsAscend() {
        let tiers = PassportTier.allCases
        for (lower, higher) in zip(tiers, tiers.dropFirst()) {
            #expect(
                lower.threshold < higher.threshold,
                "\(higher.rawValue) must cost more than \(lower.rawValue)"
            )
            #expect(lower.rank < higher.rank)
            #expect(lower.next == higher)
        }
        #expect(tiers.last?.next == nil)
    }

    @Test("every tier is labelled")
    func tiersAreLabelled() {
        for tier in PassportTier.allCases {
            #expect(!tier.displayName.isEmpty)
            #expect(!tier.blurb.isEmpty)
            #expect(tier.threshold > 0)
        }
    }

    /// The boundaries, both sides. Off-by-one on a rank threshold is the
    /// classic way to hand out a rank a step early or hold it a step late.
    @Test("earned(by:) is inclusive at the threshold and nil below the first")
    func earnedAtBoundaries() {
        #expect(PassportTier.earned(by: 0) == nil)
        #expect(PassportTier.earned(by: PassportTier.master.threshold - 1) == nil)
        #expect(PassportTier.earned(by: PassportTier.master.threshold) == .master)
        #expect(PassportTier.earned(by: PassportTier.grandmaster.threshold - 1) == .master)
        #expect(PassportTier.earned(by: PassportTier.grandmaster.threshold) == .grandmaster)
        // Past the top rung it stays at the top rather than wrapping or
        // vanishing.
        #expect(PassportTier.earned(by: 10_000) == PassportTier.allCases.last)
    }

    /// The rawValue is the display copy here, so it is safe to rename — but it
    /// is also `Codable`, and nothing persists it today. This pins that: the
    /// moment a tier is written to defaults, the rename freedom is gone and
    /// this test should be the thing that forces the conversation.
    @Test("no tier is persisted, so the labels stay renameable")
    func tiersAreNotStorage() {
        for tier in PassportTier.allCases {
            #expect(tier.rawValue == tier.displayName)
        }
    }
}

/// The passport's per-day activity series (0.7.1, D1).
@Suite("Passport activity")
struct PassportActivityTests {

    @Test("the window is a fixed span ending today, gaps included")
    func spanIsContiguous() {
        let days = Passport.activity(from: [:], today: 500, span: 30)
        #expect(days.count == 30)
        #expect(days.first?.day == 471)
        #expect(days.last?.day == 500)
        // Every column present, in order, all empty.
        #expect(days.map(\.day) == Array(471...500))
        #expect(days.allSatisfy { $0.count == 0 })
    }

    @Test("entries land on their own day and stack")
    func countsStack() {
        let log = ["a": 500, "b": 500, "c": 499, "d": 480]
        let days = Passport.activity(from: log, today: 500, span: 30)
        #expect(days.last?.count == 2)
        #expect(days.first { $0.day == 499 }?.count == 1)
        #expect(days.first { $0.day == 480 }?.count == 1)
        #expect(days.reduce(0) { $0 + $1.count } == 4)
    }

    /// Neither out-of-window case may be clamped into an edge column: doing so
    /// puts a spike on the chart that no day earned.
    @Test("days outside the window are dropped, not clamped")
    func outOfWindowIsDropped() {
        let log = ["old": 100, "future": 900, "today": 500]
        let days = Passport.activity(from: log, today: 500, span: 30)
        #expect(days.reduce(0) { $0 + $1.count } == 1)
        #expect(days.first?.count == 0)
        #expect(days.last?.count == 1)
    }

    @Test("a zero span is empty rather than a crash")
    func zeroSpanIsEmpty() {
        #expect(Passport.activity(from: ["a": 1], today: 1, span: 0).isEmpty)
    }
}

/// The tried-day log the activity graph is built on (0.7.1, D1).
@Suite("Tried day log")
struct TriedDayLogTests {

    /// `@MainActor` because `BookmarkStore` is: the helper has to be isolated
    /// too or the initialiser is a cross-actor call from a synchronous context.
    @MainActor
    private func makeStore() -> BookmarkStore {
        let suite = UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("could not make a test suite")
        }
        return BookmarkStore(defaults: defaults)
    }

    @MainActor
    @Test("marking tried dates the entry; un-marking forgets it")
    func toggleRecordsAndClears() {
        let store = makeStore()
        store.toggle("G001", on: .tried)
        #expect(store.triedDay(for: "G001") == DailyPick.dayIndex())
        #expect(store.triedDayCounts[DailyPick.dayIndex()] == 1)

        store.toggle("G001", on: .tried)
        #expect(store.triedDay(for: "G001") == nil)
        #expect(store.triedDayCounts.isEmpty)
    }

    /// The other two removal paths must forget the date too, or the histogram
    /// counts entries that are no longer on the shelf.
    @MainActor
    @Test("remove and removeAll clear the log with the shelf")
    func removalsClearTheLog() {
        let store = makeStore()
        store.toggle("G001", on: .tried)
        store.toggle("G002", on: .tried)
        store.remove("G001", on: .tried)
        #expect(store.triedDay(for: "G001") == nil)
        #expect(store.triedDay(for: "G002") != nil)

        store.removeAll(on: .tried)
        #expect(store.triedDayLog.isEmpty)
    }

    @MainActor
    @Test("the log survives a relaunch")
    func logPersists() {
        let suite = UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("could not make a test suite")
        }
        let store = BookmarkStore(defaults: defaults)
        store.toggle("G001", on: .tried)

        let reloaded = BookmarkStore(defaults: defaults)
        #expect(reloaded.triedDay(for: "G001") == DailyPick.dayIndex())
    }

    /// The other shelves have no journal — dating a bookmark would be a
    /// different feature, and the coupling rules in `toggle` are tried-only.
    @MainActor
    @Test("only the tried shelf is dated")
    func otherShelvesAreNotDated() {
        let store = makeStore()
        store.toggle("G001", on: .saved)
        store.toggle("G002", on: .wantToTry)
        #expect(store.triedDayLog.isEmpty)
    }
}

/// The stamp-unlock ledger (0.7.1, D2).
@Suite("Passport progress")
struct PassportProgressTests {

    private func makeDefaults() -> UserDefaults {
        let suite = UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("could not make a test suite")
        }
        return defaults
    }

    /// A passport with a chosen set of badges earned, without needing a real
    /// database state that produces them.
    private func passport(earning ids: Set<String>) -> Passport {
        let badges = StampCatalog.all.map {
            Passport.Badge(
                id: $0.id,
                title: $0.title,
                blurb: $0.info,
                earned: ids.contains($0.id)
            )
        }
        return Passport(
            triedGrapes: 0, totalGrapes: 0, triedStyles: 0, totalStyles: 0,
            byColor: [:], colorTotals: [:], byRarity: [:], rarityTotals: [:],
            countries: 0, continents: [], badges: badges,
            triedTotal: 0, tier: nil, nextTier: .master, towardNext: 0,
            activity: []
        )
    }

    @MainActor
    @Test("a newly earned badge is announced exactly once")
    func announcesOnce() {
        let store = PassportProgress(defaults: makeDefaults())
        let first = store.announce(passport(earning: ["firstSip"]))
        #expect(first.map(\.id) == ["firstSip"])

        // The whole safety property: `announce` records what it returns, so a
        // re-render cannot fire the celebration twice.
        let again = store.announce(passport(earning: ["firstSip"]))
        #expect(again.isEmpty)
    }

    @MainActor
    @Test("several badges arriving together all come back, in catalog order")
    func announcesInOrder() {
        let store = PassportProgress(defaults: makeDefaults())
        let stamps = store.announce(passport(earning: ["tenBottles", "firstSip"]))
        #expect(stamps.map(\.id) == ["firstSip", "tenBottles"])
    }

    @MainActor
    @Test("the ledger survives a relaunch")
    func ledgerPersists() {
        let defaults = makeDefaults()
        let store = PassportProgress(defaults: defaults)
        store.announce(passport(earning: ["firstSip"]))

        let reloaded = PassportProgress(defaults: defaults)
        #expect(reloaded.seen.contains("firstSip"))
        #expect(reloaded.announce(passport(earning: ["firstSip"])).isEmpty)
    }

    /// The upgrade path. An existing user arrives with badges already earned
    /// and nothing recorded; seeding is what stops them being handed six
    /// celebrations for things they did weeks ago.
    @MainActor
    @Test("D2: seeding suppresses the backlog, once")
    func seedingSuppressesBacklog() {
        let defaults = makeDefaults()
        let store = PassportProgress(defaults: defaults)
        store.seed(with: passport(earning: ["firstSip", "tenBottles"]))
        #expect(store.announce(passport(earning: ["firstSip", "tenBottles"])).isEmpty)

        // But a badge earned *after* the seed is still news.
        let fresh = store.announce(passport(earning: ["firstSip", "tenBottles", "allNoble"]))
        #expect(fresh.map(\.id) == ["allNoble"])
    }

    /// A new user's seed is empty, and emptiness must not be mistaken for
    /// "never seeded" — otherwise their first badge gets seeded away instead of
    /// celebrated.
    @MainActor
    @Test("a fresh install seeds empty and still celebrates its first badge")
    func freshInstallStillCelebrates() {
        let defaults = makeDefaults()
        let store = PassportProgress(defaults: defaults)
        store.seed(with: passport(earning: []))
        #expect(store.isEmpty)

        store.seed(with: passport(earning: ["firstSip"]))   // second seed: a no-op
        #expect(store.announce(passport(earning: ["firstSip"])).map(\.id) == ["firstSip"])
    }

    @MainActor
    @Test("reset clears the ledger and the seeded flag")
    func resetClears() {
        let defaults = makeDefaults()
        let store = PassportProgress(defaults: defaults)
        store.seed(with: passport(earning: ["firstSip"]))
        store.reset()
        #expect(store.seen.isEmpty)
        // Seeded again after a wipe, so a fresh start does not immediately
        // re-announce the badges the wipe was supposed to have removed.
        store.seed(with: passport(earning: []))
        #expect(store.announce(passport(earning: ["firstSip"])).map(\.id) == ["firstSip"])
    }
}
