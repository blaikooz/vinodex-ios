#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import Observation
import UserNotifications
import VinodexCore

/// Delivers `NotificationPlan` through `UNUserNotificationCenter` (0.7.8, D1).
///
/// The iOS-only half of the split: `NotificationPlan` decides *what* should be
/// pending and is tested on Linux; this schedules it and is not. Same shape as
/// the label reader, where `LabelReading` matches and `OCRService` sees.
///
/// ## The toggle tells the truth
///
/// A stored `Bool` is not permission. Authorization can be **denied** at the
/// prompt, **revoked later** in iOS Settings without the app running, or granted
/// **provisionally** (quiet delivery, no prompt). A switch that reads ON from
/// its own defaults key while the system is dropping every request is the bug
/// this class is arranged to avoid, so `isOn` is the conjunction of the stored
/// preference *and* a freshly-read `UNAuthorizationStatus` — `refresh()` re-reads
/// it on every foreground, and `SettingsSectionPanel` renders from `isOn` rather
/// than from `wants`.
///
/// ## Authorization is requested on opt-in
///
/// Never at launch. The prompt is fired by `enable()`, from the toggle's own
/// tap, which is the only moment a user has said they want this. A denial is
/// then handled rather than retried: iOS shows the system prompt exactly once
/// ever, so a second `requestAuthorization` returns the old answer silently, and
/// the honest move is to leave the switch off and point at Settings.
@MainActor
@Observable
public final class NotificationScheduler {
    public static let shared = NotificationScheduler()

    /// The user's preference. Not the same fact as permission — see `isOn`.
    public static let enabledKey = "dailyRemindersEnabled"

    private let defaults: UserDefaults
    private let center: UNUserNotificationCenter?

    /// Last-read system authorization. `notDetermined` until `refresh()` runs.
    private(set) public var status: UNAuthorizationStatus = .notDetermined
    /// The stored preference.
    private(set) public var wants: Bool

    public init(defaults: UserDefaults = .standard, center: UNUserNotificationCenter? = .current()) {
        self.defaults = defaults
        self.center = center
        wants = defaults.bool(forKey: Self.enabledKey)
    }

    /// Whether reminders are genuinely going to arrive.
    ///
    /// `.provisional` counts: those notifications *are* delivered, quietly, to
    /// the notification centre. `.ephemeral` is an App Clip state this app
    /// cannot be in, and is excluded rather than guessed at.
    public var isOn: Bool {
        wants && (status == .authorized || status == .provisional)
    }

    /// The user asked for reminders but the system is refusing — the state the
    /// settings row explains, rather than showing a switch that does nothing.
    public var isBlocked: Bool {
        wants && (status == .denied)
    }

    // MARK: Status

    /// Re-reads the real authorization status. Call on foreground and before
    /// rendering the toggle; permission can change while the app is not running.
    public func refresh() async {
        guard let center else { return }
        status = await center.notificationSettings().authorizationStatus
        // Permission revoked out from under a stored yes: drop the pending
        // requests rather than leaving orphans the system will never deliver.
        if wants && !isOn { center.removeAllPendingNotificationRequests() }
    }

    // MARK: Opting in and out

    /// Requests authorization if it has never been asked for, then schedules.
    /// Returns whether reminders are now actually on.
    @discardableResult
    public func enable(todayDone: Bool, streak: Int) async -> Bool {
        guard let center else { return false }
        if status == .notDetermined {
            // `.alert` and `.sound` only. No `.badge`: a red dot on the icon
            // is a nag the user cannot clear without opening the app, and
            // nothing here is a count.
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        // Re-read rather than believe the grant's return value. It reports what
        // *this* call decided, and the truthful answer can differ — a
        // provisional grant returns true but is not `.authorized`, and an
        // already-settled permission returns the old verdict. The system's own
        // answer is the one the toggle renders, so it is the one taken here.
        await refresh()

        wants = true
        defaults.set(true, forKey: Self.enabledKey)

        guard isOn else { return false }
        await reschedule(todayDone: todayDone, streak: streak)
        return true
    }

    /// Turns reminders off and clears everything pending.
    public func disable() {
        wants = false
        defaults.set(false, forKey: Self.enabledKey)
        center?.removeAllPendingNotificationRequests()
    }

    // MARK: Scheduling

    /// Replaces the pending set with what `NotificationPlan` says it should be.
    ///
    /// Clears first. Request identifiers are stable per kind and day, so adding
    /// alone would replace matching ids — but a day that has *dropped out* of
    /// the plan (today's paper just got sat) has no replacement to overwrite it,
    /// and would linger. Removing everything first makes the pending set equal
    /// the plan rather than a union with its history.
    public func reschedule(
        todayDone: Bool,
        streak: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        guard let center, isOn else { return }
        center.removeAllPendingNotificationRequests()

        let today = DailyPick.dayIndex(for: now, calendar: calendar)
        let plan = NotificationPlan.requests(
            today: today,
            todayDone: todayDone,
            streak: streak,
            hourNow: calendar.component(.hour, from: now)
        )

        let midnight = calendar.startOfDay(for: now)
        for request in plan {
            guard
                let day = calendar.date(byAdding: .day, value: request.day - today, to: midnight)
            else { continue }

            var parts = calendar.dateComponents([.year, .month, .day], from: day)
            parts.hour = request.hour
            parts.minute = 0

            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default

            let system = UNNotificationRequest(
                identifier: request.id,
                // Non-repeating: the plan is re-cut whenever the app can see
                // whether today's paper is done, which a repeating trigger
                // could never account for.
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            )
            try? await center.add(system)
        }
    }

    /// Convenience for the call sites that have the stores to hand.
    public func syncFromStores() async {
        await refresh()
        guard isOn else { return }
        await reschedule(
            todayDone: StreakStore.shared.isTodayDone(),
            streak: StreakStore.shared.current
        )
    }
}
#endif
