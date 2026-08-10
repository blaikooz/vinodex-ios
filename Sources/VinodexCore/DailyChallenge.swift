import Foundation
import Observation

/// The daily paper: one short quiz per local day, the same paper for everyone.
///
/// Derives from `DailyPick.dayIndex` for the same reasons the daily reveal
/// does — local midnight turnover, injectable date and calendar so the tests
/// can exist, and determinism so "did you get today's?" means something. The
/// multiplier decorrelates the daily seed from practice sessions, whose seeds
/// also start from the day index.
public enum DailyChallenge {
    /// Five questions — bite-sized on purpose. The practice paper is the
    /// sitting; this is the espresso.
    public static let length = 5
    /// Four of five to pass: the same 80% bar as the practice paper.
    public static let passMark = 4
    /// Middle difficulty, fixed. A daily that inherited your unlocked tier
    /// would make the streak harder for exactly the people most likely to
    /// keep it.
    public static let tier: QuizTier = .enthusiast

    public static func seed(for date: Date = Date(), calendar: Calendar = .current) -> Int {
        DailyPick.dayIndex(for: date, calendar: calendar) &* 8093
    }

    public static func session(for date: Date = Date(), calendar: Calendar = .current) -> QuizSession {
        QuizSession(
            seed: seed(for: date, calendar: calendar),
            length: length,
            passMark: passMark,
            tier: tier
        )
    }
}

/// The daily streak: consecutive days with a passed paper.
///
/// Stateful *and* dated — the first thing in the app that is both.
/// `RevealCursor` counts without caring what day it is; `DailyPick` knows the
/// day but stores nothing. A streak is precisely the join: the last day
/// played, and how many in a row were passed.
///
/// One paper per day, win or lose: a fail records the day too, because the
/// seed is the day's — a "retry" would be the identical paper with the
/// answers fresh in hand.
@MainActor
@Observable
public final class StreakStore {
    public static let shared = StreakStore()

    public static let streakKey = SavedDataKey.dailyStreak.rawValue
    public static let lastDayKey = SavedDataKey.dailyLastDay.rawValue
    public static let bestKey = SavedDataKey.dailyBestStreak.rawValue

    private let defaults: UserDefaults

    /// Consecutive passed days ending at the last played day.
    private(set) public var current: Int
    /// High-water mark, for the passport.
    private(set) public var best: Int
    /// Last day *played* (win or lose); nil = never. Stored via
    /// `object(forKey:)` so day zero — 1970-01-01 — and the negative indices
    /// before it survive the round trip; `integer(forKey:)` would fold
    /// "never played" and "played on the epoch" together.
    private(set) public var lastDay: Int?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        current = 0
        best = 0
        lastDay = nil
        reload()
    }

    /// Re-reads from `defaults` after a restore wrote the keys behind this
    /// store's back — see `BookmarkStore.reload()` for the full reasoning.
    /// `lastDay` comes back through `object(forKey:)` for the same reason it
    /// is written that way.
    public func reload() {
        current = defaults.integer(forKey: Self.streakKey)
        best = defaults.integer(forKey: Self.bestKey)
        lastDay = defaults.object(forKey: Self.lastDayKey) as? Int
    }

    /// Whether today's paper has been sat, pass or fail.
    public func isTodayDone(day: Int = DailyPick.dayIndex()) -> Bool {
        lastDay == day
    }

    /// Records a sitting. Same day twice is a no-op; otherwise the day is
    /// consumed, and the streak moves: a pass on the day after the last
    /// sitting extends it, a pass after a gap starts it at one, and a fail
    /// zeroes it.
    @discardableResult
    public func record(day: Int = DailyPick.dayIndex(), passed: Bool) -> Int {
        guard lastDay != day else { return current }
        let previous = lastDay
        lastDay = day

        if passed {
            current = (previous == day - 1) ? current + 1 : 1
        } else {
            current = 0
        }
        best = max(best, current)

        defaults.set(current, forKey: Self.streakKey)
        defaults.set(best, forKey: Self.bestKey)
        defaults.set(day, forKey: Self.lastDayKey)
        return current
    }

    public func reset() {
        current = 0
        best = 0
        lastDay = nil
        defaults.removeObject(forKey: Self.streakKey)
        defaults.removeObject(forKey: Self.bestKey)
        defaults.removeObject(forKey: Self.lastDayKey)
    }
}
