import Foundation

/// How long the device has been ignored, in stages (0.7.3, F2).
///
/// Ordered and `Comparable` on purpose: every consumer wants "have we reached at
/// least this far", not "are we exactly here". A view that asks `stage >= .toast`
/// keeps working when a stage is inserted between them, which a `switch` over
/// equal cases would not.
public enum IdleStage: Int, Comparable, CaseIterable, Sendable {
    /// Someone is using it. The state the device is in almost all the time.
    case active = 0
    /// Long enough that the marquee drifts from MENU to a toast (0.7.1, B3).
    case toast = 1
    /// Long enough for the screensaver (0.7.3, A5). The last stage: nothing
    /// happens after this but activity.
    case screensaver = 2

    public static func < (lhs: IdleStage, rhs: IdleStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The thresholds, in one place (0.7.3, F2).
///
/// **These two numbers used to live apart**, and one of them lived in a tuple on
/// an enum case (`MarqueeStage.menu` returned `(10, .cheers)`) where nothing
/// could find it. F2 asks for one inactivity tracker firing staged events, and a
/// single tracker with two separately-authored constants is two trackers wearing
/// one coat. `MarqueeStage` reads `toast` from here now.
public enum IdleSchedule: Sendable {
    /// 10 seconds — 0.7.1's B3 figure, unchanged. It has to outlast someone
    /// reading the four menu tiles and deciding, or the panel changes under a
    /// user who never stopped using the device.
    public static let toast: TimeInterval = 10

    /// 15 seconds — A5's figure. Deliberately close behind the toast rather than
    /// a minute out: this device never dims (`ScreenWake` pins
    /// `isIdleTimerDisabled`), so the screensaver is the only thing that ever
    /// changes what a forgotten screen is showing, and a burn-in guard that
    /// waits a minute is a burn-in guard for a phone in a pocket.
    public static let screensaver: TimeInterval = 15

    /// Thresholds paired with the stage they open, ascending.
    ///
    /// The table rather than a chain of `if`s, so `stage(after:)` and any future
    /// consumer that wants to draw a progress bar read the same source.
    public static let stages: [(after: TimeInterval, stage: IdleStage)] = [
        (toast, .toast),
        (screensaver, .screensaver),
    ]

    /// The stage a given idle duration has reached.
    public static func stage(after idle: TimeInterval) -> IdleStage {
        var reached = IdleStage.active
        for step in stages where idle >= step.after {
            reached = step.stage
        }
        return reached
    }
}

/// The inactivity tracker itself (0.7.3, F2).
///
/// **Why the policy is here and the clock is not** — the same argument
/// `MarqueeScript` makes, and for the same reason it is worth repeating: a
/// `Task.sleep` loop in a SwiftUI view is invisible to `swift test`, because
/// `VinodexUI` does not compile on Linux at all. What is interesting about an
/// idle timer is not the sleeping. It is *which stage a given elapsed time is,
/// which crossings a tick just passed, and what an interaction does to the stage
/// you were in* — arithmetic over an enum, and it belongs where a gate can see
/// it. `IdleMonitor` in `VinodexUI` owns the clock and drives this.
///
/// A value type with `mutating` transitions, exactly like `MarqueeScript`: there
/// is one of these, it lives inside the monitor, and making it a class would buy
/// a second identity to keep in step for nothing.
public struct IdleClock: Sendable, Equatable {
    /// Seconds since the last interaction.
    public private(set) var idle: TimeInterval

    /// The stage `idle` has reached. Stored rather than computed so `advance`
    /// can report a *crossing* — the difference between "we are past ten
    /// seconds" and "we just went past ten seconds", which is what a consumer
    /// that starts an animation needs and what a computed property cannot say.
    public private(set) var stage: IdleStage

    public init(idle: TimeInterval = 0) {
        self.idle = max(idle, 0)
        self.stage = IdleSchedule.stage(after: self.idle)
    }

    /// Move the clock to an absolute idle duration.
    ///
    /// **Absolute, not a delta.** The monitor computes this from a monotonic
    /// clock reading rather than accumulating tick intervals, so a tick that
    /// arrives late — a busy main actor, an app returning from the background —
    /// lands on the right stage instead of drifting a little further behind on
    /// every one.
    ///
    /// - Returns: the stage newly entered by this move, or `nil` if it did not
    ///   cross a threshold. Skipping several at once (a tick that arrives twenty
    ///   seconds late) reports the furthest, which is the only one still true.
    @discardableResult
    public mutating func advance(to elapsed: TimeInterval) -> IdleStage? {
        idle = max(elapsed, 0)
        let reached = IdleSchedule.stage(after: idle)
        guard reached > stage else {
            // Never walks backwards on its own — only `noteActivity` can lower
            // the stage. A clock that went backwards because a reading came in
            // slightly low would flicker the screensaver off and on.
            return nil
        }
        stage = reached
        return reached
    }

    /// The user did something.
    ///
    /// - Returns: whether this actually changed anything, so a caller can skip
    ///   the work of leaving a stage it was never in. Activity while already
    ///   active is the overwhelmingly common case — every touch, on every
    ///   screen — and must cost nothing.
    @discardableResult
    public mutating func noteActivity() -> Bool {
        let moved = stage != .active || idle != 0
        idle = 0
        stage = .active
        return moved
    }
}
