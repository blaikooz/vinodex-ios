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
    ///
    /// **Not separately reachable since 0.7.6 (A4)** — see `IdleSchedule.toast`.
    /// The case is kept rather than deleted precisely because consumers ask
    /// `stage >= .toast` rather than `stage == .toast`: the greeting is still due
    /// at the moment this rank is passed, and it is now passed on the way into
    /// `.screensaver`. Deleting it would have turned a threshold change back into
    /// a rewrite, which is the thing A4 was asked not to do.
    case toast = 1
    /// Long enough for the screensaver (0.7.3, A5; 60 seconds since 0.8.0, H).
    /// The last stage: nothing happens after this but activity.
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
/// one coat. `MarqueeStage` reads its dwell from here now.
///
/// **0.7.6 (A3/A4) finishes that job by removing one of the two numbers.** The
/// screensaver moves off 15 and the marquee's greeting arrives with it rather
/// than twenty seconds ahead of it, so there is one authored threshold and one
/// optional knob that would bring the second back. See `toast`. 0.8.0's H moves
/// that single threshold to 60, which is the proof the fold was worth doing: one
/// edit, both behaviours.
public enum IdleSchedule: Sendable {
    /// The pre-idle marquee toast — **folded into the screensaver in 0.7.6 (A4),
    /// and this optional is the fold.**
    ///
    /// It was 10 seconds, from 0.7.1's B3: long enough to outlast someone reading
    /// the four menu tiles and deciding, and the moment the panel drifted from
    /// MENU to CHEERS! on the main screen. A4 asks for the toast to arrive *with*
    /// the screensaver instead, on any screen, and the argument is the same one
    /// the Decision makes about the drawer: two idle stages that both show a
    /// greeting are two answers to one question, and the earlier one exists only
    /// because the later one used to be main-menu-only.
    ///
    /// **`nil` means "no separate toast stage" — not "no toast".** `IdleStage`
    /// keeps `.toast` and every consumer keeps asking `stage >= .toast`, which is
    /// still true the instant `.screensaver` is entered because the stages are
    /// `Comparable` and ordered. So the greeting still happens; it just happens at
    /// the one threshold rather than at a threshold of its own.
    ///
    /// **Reverting is this line.** Give it a number below `screensaver` and the
    /// two-stage behaviour comes back whole: `stages` grows its entry again,
    /// `stage(after:)` starts returning `.toast`, and `MarqueeStage.menu`'s dwell
    /// follows it through `cheers` below. Nothing else in the app names either
    /// number.
    public static let toast: TimeInterval? = nil

    /// When the marquee's greeting is due, whichever shape the schedule is in.
    ///
    /// The one thing `MarqueeStage` should read, so a stage moving between the
    /// two clocks never has to know whether the fold is in force.
    public static var cheers: TimeInterval { toast ?? screensaver }

    /// 60 seconds — **0.8.0's figure (H), up from 0.7.6's A3 30 and A5's 15.**
    ///
    /// **This is the third value and the second time the same argument has been
    /// pushed in the same direction, so the reasoning is extended rather than
    /// replaced.** A5 chose 15. A3 raised it to 30 and wrote down why: this
    /// device never dims (`ScreenWake` pins `isIdleTimerDisabled`), so the
    /// screensaver is the only thing that ever changes what a forgotten screen is
    /// showing, and a reference app gets *read from* — fifteen seconds is inside
    /// the time it takes to read a region's soil block and look back up.
    ///
    /// A3 then declined a minute in one line: "a burn-in guard that waits a
    /// minute is a burn-in guard for a phone in a pocket." H says that line was
    /// wrong, and it is worth saying which half. The premise is right — nothing
    /// dims this screen — but the conclusion treats the screensaver as a burn-in
    /// guard, and on a modern OLED phone held by a person it is not one; iOS
    /// dims and locks the *device* on its own schedule regardless of what this
    /// app pins, so the real burn-in guard was never this constant. What the
    /// screensaver actually is, is the device going idle in character, and the
    /// cost of it arriving early is a page changing under someone who is still
    /// reading it. Thirty turned out to be inside that window too — the same
    /// complaint A3 fixed at fifteen, one register quieter.
    ///
    /// Sixty is also where the two clocks stop fighting. A4 folded the marquee's
    /// greeting into this threshold (see `toast`), so this number is *both* "when
    /// the screensaver starts" and "when the panel says CHEERS!" — and a greeting
    /// that replaces the page title while the page is being read is the exact
    /// fault B3's ten seconds was chosen to avoid. Raising the one number raises
    /// both, which is the whole point of there being one number.
    public static let screensaver: TimeInterval = 60

    /// Thresholds paired with the stage they open, ascending.
    ///
    /// The table rather than a chain of `if`s, so `stage(after:)` and any future
    /// consumer that wants to draw a progress bar read the same source. Computed
    /// rather than a `static let` since 0.7.6, because `toast` may be absent —
    /// and a table with a `nil` hole in it would have to be filtered by every
    /// reader instead of once, here.
    public static var stages: [(after: TimeInterval, stage: IdleStage)] {
        var out: [(after: TimeInterval, stage: IdleStage)] = []
        if let toast { out.append((toast, .toast)) }
        out.append((screensaver, .screensaver))
        return out
    }

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
