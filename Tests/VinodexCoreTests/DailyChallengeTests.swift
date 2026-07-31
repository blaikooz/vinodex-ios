import Testing
import Foundation
@testable import VinodexCore

@Suite("Daily challenge")
struct DailyChallengeTests {
    /// A fixed calendar so the suite passes regardless of the machine's zone —
    /// the same convention as `DailyPickTests`.
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "GMT")!
        return calendar
    }

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: iso)!
    }

    @Test("the same day gets the same paper")
    func stableWithinADay() {
        let morning = date("2026-07-30")
        let evening = morning.addingTimeInterval(9 * 3600)
        #expect(DailyChallenge.seed(for: morning, calendar: utc) == DailyChallenge.seed(for: evening, calendar: utc))
    }

    @Test("consecutive days get different papers")
    func changesDaily() {
        let today = date("2026-07-30")
        let tomorrow = date("2026-07-31")
        #expect(DailyChallenge.seed(for: today, calendar: utc) != DailyChallenge.seed(for: tomorrow, calendar: utc))
    }

    @Test("the daily paper is five questions, four to pass, mid tier")
    func paperShape() {
        let session = DailyChallenge.session(for: date("2026-07-30"), calendar: utc)
        #expect(session.length == 5)
        #expect(session.passMark == 4)
        #expect(session.tier == .enthusiast)
        #expect(!session.isComplete)
    }

    /// The seed must index safely for dates before 1970 — the same trap
    /// `DailyPick` documents.
    @Test("a pre-epoch date still yields a full paper")
    func preEpoch() {
        let session = DailyChallenge.session(for: date("1962-03-04"), calendar: utc)
        let db = WineDatabase.shared
        for number in 0..<session.length {
            #expect(
                TastingQuiz.question(number: number, sessionSeed: session.seed, tier: session.tier, in: db) != nil,
                "pre-epoch q\(number) produced nothing"
            )
        }
    }
}

@Suite("Daily streak")
struct StreakStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @MainActor
    @Test("a fresh store has no history")
    func fresh() {
        let store = StreakStore(defaults: makeDefaults())
        #expect(store.current == 0)
        #expect(store.best == 0)
        #expect(store.lastDay == nil)
        #expect(!store.isTodayDone(day: 100))
    }

    @MainActor
    @Test("passes chain on consecutive days and restart after a gap")
    func passesChain() {
        let store = StreakStore(defaults: makeDefaults())
        #expect(store.record(day: 100, passed: true) == 1)
        #expect(store.record(day: 101, passed: true) == 2)
        #expect(store.record(day: 102, passed: true) == 3)
        // Two days missed: the chain restarts at one, it does not resume.
        #expect(store.record(day: 105, passed: true) == 1)
        #expect(store.best == 3)
    }

    @MainActor
    @Test("a fail consumes the day and zeroes the streak")
    func failZeroes() {
        let store = StreakStore(defaults: makeDefaults())
        store.record(day: 100, passed: true)
        store.record(day: 101, passed: false)
        #expect(store.current == 0)
        #expect(store.isTodayDone(day: 101))
        // The day after a fail starts a fresh streak of one.
        #expect(store.record(day: 102, passed: true) == 1)
    }

    @MainActor
    @Test("the same day twice is a no-op")
    func sameDayOnce() {
        let store = StreakStore(defaults: makeDefaults())
        store.record(day: 100, passed: true)
        // Neither a repeat pass nor a repeat fail moves anything.
        #expect(store.record(day: 100, passed: true) == 1)
        #expect(store.record(day: 100, passed: false) == 1)
        #expect(store.current == 1)
    }

    @MainActor
    @Test("pre-epoch day indices round-trip")
    func preEpochDays() {
        let defaults = makeDefaults()
        let store = StreakStore(defaults: defaults)
        store.record(day: -3000, passed: true)
        #expect(store.record(day: -2999, passed: true) == 2)

        let reloaded = StreakStore(defaults: defaults)
        #expect(reloaded.lastDay == -2999)
        #expect(reloaded.current == 2)
    }

    @MainActor
    @Test("state survives a reload and reset clears it")
    func persistsAndResets() {
        let defaults = makeDefaults()
        let first = StreakStore(defaults: defaults)
        first.record(day: 200, passed: true)
        first.record(day: 201, passed: true)

        let reloaded = StreakStore(defaults: defaults)
        #expect(reloaded.current == 2)
        #expect(reloaded.best == 2)
        #expect(reloaded.isTodayDone(day: 201))

        reloaded.reset()
        let fresh = StreakStore(defaults: defaults)
        #expect(fresh.current == 0)
        #expect(fresh.best == 0)
        #expect(fresh.lastDay == nil)
    }
}
