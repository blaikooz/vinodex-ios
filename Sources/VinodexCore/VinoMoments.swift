import Foundation

/// **Vinobot beyond first-times** (rework V4, 2026-09-01): the daily line
/// and the streak milestones — the "chattier" the maintainer dialled in,
/// with the volume knobs the dial deserves.
///
/// ## The two rules that keep chatty from becoming needy
///
/// 1. **One ambient moment per day.** The daily line fires on the first
///    foreground of a calendar day and never again until tomorrow;
///    milestone lines ride the same evaluation, so a big day says its
///    biggest thing and saves the rest.
/// 2. **A milestone speaks once, ever.** Crossing a streak of seven is one
///    sentence for life, keyed and persisted like the first-time tips —
///    the same once-only covenant, one shelf over.
///
/// Moments are bubbles, so they obey the bubble bible: <= 20 words,
/// printable ASCII, no dash construction, `{name}` never sentence-initial
/// (moments resolve the name at composition, like the scenes). QUIET
/// silences them entirely — they are volunteered speech, exactly what the
/// switch governs. `problems()` is the gate; `VinoMomentsTests` runs it.
public struct VinoMomentLine: Sendable, Hashable {
    /// Identity: dedupe in the queue, once-ever for milestones, and the
    /// bubble's change animation all key on it.
    public let key: String
    /// Resolved text — no `{name}` placeholders survive composition.
    public let text: String
    public let expression: VinoExpression

    public init(key: String, text: String, expression: VinoExpression) {
        self.key = key
        self.text = text
        self.expression = expression
    }
}

public enum VinoMoments {
    /// The streak marks that have earned a sentence. Ordered; each key is
    /// persisted by `VinoMomentStore` after it speaks.
    public static let streakMarks = [3, 7, 14, 30]

    /// Everything today has earned, mildest first — the daily line, then
    /// any newly crossed streak marks. Pure: stores stay outside.
    public static func compose(
        name rawName: String?,
        moonDay: MoonDay,
        goodDay: Bool,
        bestStreak: Int,
        alreadySpokenMarks: Set<Int>
    ) -> [VinoMomentLine] {
        let name = VinoName.clean(rawName) ?? VinoName.fallback
        var out: [VinoMomentLine] = []

        let dayWord = moonDay.rawValue.lowercased()
        out.append(VinoMomentLine(
            key: "daily",
            text: goodDay
                ? "A \(dayWord) day, \(name). The moon approves of tonight's homework."
                : "A \(dayWord) day. The old calendar counsels patience; pour something anyway.",
            expression: goodDay ? .smiling : .thinking
        ))

        for mark in streakMarks where bestStreak >= mark && !alreadySpokenMarks.contains(mark) {
            out.append(VinoMomentLine(
                key: "streak.\(mark)",
                text: streakLine(mark, name: name),
                expression: .goodjob
            ))
        }
        return out
    }

    private static func streakLine(_ mark: Int, name: String) -> String {
        switch mark {
        case 3: return "Three papers in a row, \(name). Habits start smaller than this."
        case 7: return "A full week's streak. My records show no sign of you stopping."
        case 14: return "Fourteen days straight. At this point the streak is studying you."
        default: return "Thirty days, \(name). I have known vintages with less commitment."
        }
    }

    /// The bubble rules, run over every composition — the bible's gate for
    /// the lines this file authors.
    public static func problems(in lines: [VinoMomentLine]) -> [String] {
        var out: [String] = []
        for line in lines {
            let words = line.text.split(separator: " ").count
            if words > 20 { out.append("\(line.key): \(words) words, over the bubble cap") }
            if line.text.contains(" - ") { out.append("\(line.key): dash construction") }
            if line.text.contains("{name}") { out.append("\(line.key): unresolved placeholder") }
        }
        return out
    }
}

/// What has already been said, persisted — the moments' own once-ledger.
@MainActor
@Observable
public final class VinoMomentStore {
    public static let shared = VinoMomentStore()

    public nonisolated static let dayKey = "vinoMomentLastDay"
    public nonisolated static let marksKey = "vinoMomentStreakMarks"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The day stamp: yyyy-MM-dd in the player's calendar, so "a new day"
    /// means their midnight, not UTC's.
    public func dayStamp(for date: Date = Date()) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    public func hasSpokenToday(_ date: Date = Date()) -> Bool {
        defaults.string(forKey: Self.dayKey) == dayStamp(for: date)
    }

    public func markSpokenToday(_ date: Date = Date()) {
        defaults.set(dayStamp(for: date), forKey: Self.dayKey)
    }

    public var spokenMarks: Set<Int> {
        Set(defaults.array(forKey: Self.marksKey) as? [Int] ?? [])
    }

    public func markStreakSpoken(_ mark: Int) {
        defaults.set(Array(spokenMarks.union([mark])).sorted(), forKey: Self.marksKey)
    }
}
