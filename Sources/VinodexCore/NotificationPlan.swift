import Foundation

/// What the daily reminders should be, given the day and the streak (0.7.8, D1).
///
/// **Why the decision is here and the delivery is not.** `UNUserNotificationCenter`
/// is iOS-only and untestable on Linux, which is exactly the split the label
/// reader already uses: `LabelReading` decides, `OCRService` sees. So this
/// answers "what should be pending right now" as a pure function, and
/// `NotificationScheduler` in `VinodexUI` is the part that talks to the system.
/// The interesting bugs — nagging somebody who already played, warning about a
/// streak that does not exist — are all in the decision, and all pinned below.
///
/// ## Why a horizon of one-shots rather than one repeating trigger
///
/// A repeating calendar trigger is the obvious way to say "every day at 10" and
/// it cannot express the one thing D1 asks for: *don't nag someone who already
/// played*. Whether today's paper is done is known only while the app runs, and
/// a repeating trigger fires whether or not it is.
///
/// So the plan is a short horizon of individually-identified one-shots, re-cut
/// whenever the app can see the truth — on foreground, on opting in, and the
/// moment a paper completes. `identifier` is derived from the kind and the day
/// index, so re-planning replaces rather than duplicates, and today's reminder
/// can be withdrawn by name the instant the paper is sat.
///
/// The horizon exists because the app may not be opened for a while, and the
/// streak warning matters most precisely then. `horizon` days of pending
/// requests keeps the reminders alive across a week of silence, well inside
/// iOS's 64-pending-request limit at two a day.
public enum NotificationPlan {
    /// Days of reminders scheduled ahead. Two kinds a day, so 14 pending
    /// requests at most — iOS keeps the 64 soonest and silently drops the rest,
    /// and this stays far enough under that the cap is never the thing that
    /// decides which reminder a user gets.
    public static let horizon = 7

    /// Late morning: past the commute, well before the day gets away.
    public static let dailyHour = 10
    /// Evening, with enough of the day left to actually sit five questions.
    /// A "last chance" at 23:50 is a notification you can only feel bad about.
    public static let riskHour = 20

    public enum Kind: String, Sendable, CaseIterable {
        /// "Today's challenge is live."
        case daily
        /// "Your streak is at risk."
        case streakAtRisk

        public var title: String {
            switch self {
            case .daily: "TODAY'S CHALLENGE IS LIVE"
            case .streakAtRisk: "YOUR STREAK IS AT RISK"
            }
        }

        public var hour: Int {
            switch self {
            case .daily: NotificationPlan.dailyHour
            case .streakAtRisk: NotificationPlan.riskHour
            }
        }
    }

    /// One pending reminder.
    public struct Request: Sendable, Equatable, Identifiable {
        public let kind: Kind
        /// The `DailyPick.dayIndex` this fires on.
        public let day: Int
        public let hour: Int
        public let title: String
        public let body: String

        /// Stable per kind and day, so re-planning overwrites the same request
        /// rather than stacking a second copy of it.
        public var id: String { "vinodex.\(kind.rawValue).\(day)" }

        public init(kind: Kind, day: Int, hour: Int, title: String, body: String) {
            self.kind = kind
            self.day = day
            self.hour = hour
            self.title = title
            self.body = body
        }
    }

    /// The reminders that should be pending.
    ///
    /// - Parameters:
    ///   - today: the current `DailyPick.dayIndex`.
    ///   - todayDone: whether today's paper has been sat, win or lose.
    ///   - streak: `StreakStore.current`.
    ///   - hourNow: the current hour, so a reminder whose time has already
    ///     passed today is not scheduled into the past.
    ///
    /// Two rules do the work. **A day already sat gets nothing** — neither
    /// reminder, because both would be wrong. And **the streak warning needs a
    /// streak**: at zero there is nothing at risk, and telling somebody their
    /// streak of nothing is in danger is the kind of invented urgency that gets
    /// notifications turned off for good.
    ///
    /// Future days in the horizon are planned optimistically: they cannot be
    /// known to be done, and the streak they would be defending is today's plus
    /// the days between, which is a guess. So they carry today's streak, and
    /// the re-plan on next launch corrects them.
    public static func requests(
        today: Int,
        todayDone: Bool,
        streak: Int,
        hourNow: Int
    ) -> [Request] {
        var out: [Request] = []
        for offset in 0..<horizon {
            let day = today + offset
            let isToday = offset == 0
            // Today's paper is sat: nothing more to say today.
            if isToday && todayDone { continue }

            for kind in Kind.allCases {
                // Its moment has passed; scheduling it would fire immediately
                // or not at all, depending on the trigger's mood.
                if isToday && kind.hour <= hourNow { continue }
                // Nothing at risk without a run to lose. Future days inherit
                // today's streak, corrected on the next re-plan.
                if kind == .streakAtRisk && streak <= 0 { continue }
                out.append(
                    Request(
                        kind: kind,
                        day: day,
                        hour: kind.hour,
                        title: kind.title,
                        body: body(for: kind, streak: streak)
                    )
                )
            }
        }
        return out
    }

    /// The line under the title. Kept here rather than in the view so the
    /// wording is testable and so a streak count in a notification cannot
    /// disagree with the one on the passport — both read `StreakStore`.
    ///
    /// "exam" rather than "paper" since 0.8.0 (F) — the identifiers around it are
    /// unchanged, and `firmware.ts`'s 0.7.8 entry still records the wording that
    /// release actually shipped.
    public static func body(for kind: Kind, streak: Int) -> String {
        switch kind {
        case .daily:
            "Five questions, one exam, the same for everyone."
        case .streakAtRisk:
            streak == 1
                ? "Your one-day streak ends tonight. Today's exam is still open."
                : "\(streak) days on the run. Today's exam is still open."
        }
    }
}
