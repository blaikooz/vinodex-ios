import Foundation
import Testing
@testable import VinodexCore

/// The ambient lane (rework V4): every composition through the bubble
/// rules, the once-ledgers honest, the milestones crossing exactly once.
@Suite("Vino moments")
struct VinoMomentsTests {
    /// Every day type, both verdicts, every streak state, named and not —
    /// all through the bubble gate (20 words, ASCII, no dash, resolved).
    @Test("every composition passes the bubble rules")
    func compositionsClean() {
        for day in MoonDay.allCases {
            for good in [true, false] {
                for streak in [0, 3, 7, 14, 30, 45] {
                    for name in [nil, "Harrison"] as [String?] {
                        let lines = VinoMoments.compose(
                            name: name, moonDay: day, goodDay: good,
                            bestStreak: streak, alreadySpokenMarks: [])
                        let problems = VinoMoments.problems(in: lines)
                        #expect(problems.isEmpty, "\(problems)")
                    }
                }
            }
        }
    }

    /// A streak of 30 crossing fresh earns all four marks at once — a big
    /// day says its biggest things — and a mark already spoken never
    /// repeats, which is the once-ever covenant.
    @Test("streak marks fire once each, all crossed marks together")
    func marksOnce() {
        let fresh = VinoMoments.compose(
            name: nil, moonDay: .fruit, goodDay: true,
            bestStreak: 30, alreadySpokenMarks: [])
        #expect(fresh.filter { $0.key.hasPrefix("streak.") }.count == 4)

        let spoken = VinoMoments.compose(
            name: nil, moonDay: .fruit, goodDay: true,
            bestStreak: 30, alreadySpokenMarks: [3, 7, 14, 30])
        #expect(spoken.filter { $0.key.hasPrefix("streak.") }.isEmpty)
        #expect(spoken.count == 1, "the daily line still speaks")
    }

    /// The day ledger: spoken-today flips with the stamp and survives a
    /// fresh store over the same defaults.
    @MainActor
    @Test("the day ledger holds for the calendar day")
    func dayLedger() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let store = VinoMomentStore(defaults: defaults)
        #expect(!store.hasSpokenToday())
        store.markSpokenToday()
        #expect(store.hasSpokenToday())
        #expect(VinoMomentStore(defaults: defaults).hasSpokenToday())
    }

    /// The marks ledger unions and persists.
    @MainActor
    @Test("the marks ledger accumulates")
    func marksLedger() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let store = VinoMomentStore(defaults: defaults)
        store.markStreakSpoken(3)
        store.markStreakSpoken(7)
        #expect(store.spokenMarks == [3, 7])
        #expect(VinoMomentStore(defaults: defaults).spokenMarks == [3, 7])
    }
}
