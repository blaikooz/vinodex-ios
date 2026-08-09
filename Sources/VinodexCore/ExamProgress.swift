import Foundation
import Observation

/// One category's running score inside a single paper.
public struct ExamCategoryTally: Codable, Sendable, Equatable, Hashable {
    public let right: Int
    public let asked: Int

    public init(right: Int, asked: Int) {
        self.right = right
        self.asked = asked
    }

    public var accuracy: Double { asked == 0 ? 0 : Double(right) / Double(asked) }
}

/// One completed paper.
///
/// Deliberately small and flat: this is what gets written to `UserDefaults` on
/// every completion, and a record that carried the questions would grow the
/// stored blob by two orders of magnitude for a statistic nobody asked for.
/// Category keys are `ExamCategory` raw values rather than the enum, so a
/// category retired in a later batch degrades to a row the stats screen skips
/// instead of failing the whole history's decode.
public struct ExamResult: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let tier: ExamTier
    public let correct: Int
    public let length: Int
    public let passed: Bool
    /// `DailyPick.dayIndex` at the moment the paper finished.
    public let day: Int
    public let categories: [String: ExamCategoryTally]

    public var id: String { "\(day):\(tier.rawValue):\(correct)/\(length)" }
    public var accuracy: Double { length == 0 ? 0 : Double(correct) / Double(length) }
    public var isPerfect: Bool { length > 0 && correct == length }

    public init(
        tier: ExamTier,
        correct: Int,
        length: Int,
        passed: Bool,
        day: Int,
        categories: [String: ExamCategoryTally] = [:]
    ) {
        self.tier = tier
        self.correct = correct
        self.length = length
        self.passed = passed
        self.day = day
        self.categories = categories
    }
}

/// The statistics D6 asks for, all derived from the history rather than
/// separately maintained.
///
/// Derived rather than incremented on purpose. A stored counter and a stored
/// list are two things that can disagree, and the one that disagrees is always
/// the counter — see `CustomDeviceStore`'s "no stored active build id" note for
/// the same argument one feature over. The history is a few hundred bytes.
public struct ExamStats: Sendable, Equatable {
    public let papers: Int
    public let passes: Int
    public let questionsAnswered: Int
    public let questionsRight: Int
    /// Papers passed in a row, counting back from the most recent sitting. **Not
    /// a calendar streak** — see `ExamRecordStore.passStreak`.
    public let passStreak: Int
    public let bestPassStreak: Int
    public let perfectPapers: Int
    /// Best score at each tier, as a fraction. Absent means never sat.
    public let bestByTier: [ExamTier: Double]
    /// Per-category accuracy across every paper, for the study readout.
    public let byCategory: [ExamCategory: ExamCategoryTally]

    public static let empty = ExamStats(
        papers: 0, passes: 0, questionsAnswered: 0, questionsRight: 0,
        passStreak: 0, bestPassStreak: 0, perfectPapers: 0,
        bestByTier: [:], byCategory: [:]
    )

    public var accuracy: Double {
        questionsAnswered == 0 ? 0 : Double(questionsRight) / Double(questionsAnswered)
    }

    /// The category with the worst accuracy over a meaningful sample — what a
    /// study tool exists to tell you.
    ///
    /// `minimumAsked` is why this is a function and not a property: one wrong
    /// answer in one FORTIFIED question is 0% and would sit at the top of a
    /// weakness list forever, ahead of a category genuinely being failed half
    /// the time. Three is the floor at which the number starts meaning
    /// something; ties break on the category order so the readout does not
    /// flicker between two equal cells.
    public func weakest(minimumAsked: Int = 3) -> (category: ExamCategory, tally: ExamCategoryTally)? {
        ExamCategory.allCases
            .compactMap { category -> (ExamCategory, ExamCategoryTally)? in
                guard let tally = byCategory[category], tally.asked >= minimumAsked else { return nil }
                return (category, tally)
            }
            .min { $0.1.accuracy < $1.1.accuracy }
            .map { (category: $0.0, tally: $0.1) }
    }

    public func strongest(minimumAsked: Int = 3) -> (category: ExamCategory, tally: ExamCategoryTally)? {
        ExamCategory.allCases
            .compactMap { category -> (ExamCategory, ExamCategoryTally)? in
                guard let tally = byCategory[category], tally.asked >= minimumAsked else { return nil }
                return (category, tally)
            }
            .max { $0.1.accuracy < $1.1.accuracy }
            .map { (category: $0.0, tally: $0.1) }
    }
}

/// The Wine Exam's performance history (0.7.5, D6).
///
/// ## What this does *not* do, and why
///
/// It does not hold the tier ladder. `QuizProgress` already does — it is the
/// store behind `quizTierUnlocked` and `quizTiersCompleted`, it already gates
/// which papers may be started and which wear a completion star, and its unlock
/// already feeds the passport's SOMMELIER badge. A second ladder store would
/// have to be kept in step with it forever. `ExamRecordStore.record(_:)` calls
/// `QuizProgress.recordPass` and returns what it returns.
///
/// It does not hold a calendar streak either. `StreakStore` is the daily
/// challenge's, and it counts *days*, keyed to one sitting per local day. A
/// streak of consecutive passed papers is a different measurement of a different
/// thing — you can sit four papers in an evening — so it lives here, is derived
/// from the history rather than stored, and is named `passStreak` so nothing in
/// the codebase reads as though the two are interchangeable.
///
/// ## Bounded history
///
/// `UserDefaults` is not a database. `historyLimit` papers is enough for every
/// statistic on the screen (per-category accuracy converges long before it) and
/// caps the blob at a few kilobytes on a device somebody has used for years.
/// Trimming is oldest-first, so the streak — which reads from the newest end —
/// is never truncated out from under itself.
@MainActor
@Observable
public final class ExamRecordStore {
    public static let shared = ExamRecordStore()

    /// JSON-encoded `[ExamResult]`, oldest first.
    public static let storageKey = "examResults"
    /// The high-water mark, kept separately for the one reason a derived value
    /// cannot survive: it must outlive the papers it was set by. A user 200
    /// papers past their best run should still see it.
    public static let bestStreakKey = "examBestPassStreak"

    public static let historyLimit = 100

    private let defaults: UserDefaults

    private(set) public var history: [ExamResult]
    private(set) public var bestPassStreak: Int

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // A corrupt or partly-unknown blob degrades to empty rather than
        // crashing, matching how the bookmark shelves treat a stale id: losing
        // the stats is an inconvenience, refusing to open the exam is not.
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([ExamResult].self, from: data) {
            history = decoded
        } else {
            history = []
        }
        bestPassStreak = defaults.integer(forKey: Self.bestStreakKey)
    }

    /// Papers passed in a row, counting back from the most recent.
    ///
    /// **Bounded by `historyLimit`, and deliberately.** It is derived from the
    /// retained history, so a run of 120 consecutive passes reads as 100 — the
    /// oldest 20 are no longer on file to be counted. The alternative is a
    /// stored counter, which is the thing this type is built to avoid: a counter
    /// and a list are two facts that can disagree, and it is always the counter
    /// that is wrong. A hundred papers in a row without a single fail is a
    /// number nobody will reach and nobody would dispute if they did.
    public var passStreak: Int {
        var run = 0
        for result in history.reversed() {
            guard result.passed else { break }
            run += 1
        }
        return run
    }

    public var stats: ExamStats {
        var passes = 0
        var answered = 0
        var right = 0
        var perfect = 0
        var best: [ExamTier: Double] = [:]
        var byCategory: [ExamCategory: ExamCategoryTally] = [:]

        for result in history {
            if result.passed { passes += 1 }
            if result.isPerfect { perfect += 1 }
            answered += result.length
            right += result.correct
            best[result.tier] = max(best[result.tier] ?? 0, result.accuracy)
            for (key, tally) in result.categories {
                guard let category = ExamCategory(rawValue: key) else { continue }
                let held = byCategory[category] ?? ExamCategoryTally(right: 0, asked: 0)
                byCategory[category] = ExamCategoryTally(
                    right: held.right + tally.right,
                    asked: held.asked + tally.asked
                )
            }
        }

        return ExamStats(
            papers: history.count,
            passes: passes,
            questionsAnswered: answered,
            questionsRight: right,
            passStreak: passStreak,
            bestPassStreak: bestPassStreak,
            perfectPapers: perfect,
            bestByTier: best,
            byCategory: byCategory
        )
    }

    /// Records a completed paper and returns the tier it unlocked, if any.
    ///
    /// **Call this exactly once per completion, from the handler that completes
    /// it** — never from a view body, where a re-render would record the same
    /// paper twice. That is `QuizProgress.recordPass`'s rule and it now covers
    /// the history and the streak as well.
    @discardableResult
    public func record(_ run: ExamRun, day: Int = DailyPick.dayIndex()) -> QuizTier? {
        history.append(run.result(day: day))
        if history.count > Self.historyLimit {
            history.removeFirst(history.count - Self.historyLimit)
        }
        persist()

        let streak = passStreak
        if streak > bestPassStreak {
            bestPassStreak = streak
            defaults.set(streak, forKey: Self.bestStreakKey)
        }

        guard run.passed else { return nil }
        return QuizProgress.shared.recordPass(tier: run.tier.ladder)
    }

    public func reset() {
        history = []
        bestPassStreak = 0
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.bestStreakKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
