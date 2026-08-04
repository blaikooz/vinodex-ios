import Testing
import Foundation
@testable import VinodexCore

/// The one idle timer (0.7.3, F2).
///
/// The clock in `IdleMonitor` is a `Task.sleep` loop in `VinodexUI` and Linux
/// cannot see it. What it drives is all here: which stage an elapsed time is,
/// which crossings a tick just passed, and what an interaction does to the stage
/// you were in.
@Suite("Idle timer")
struct IdleTimerTests {
    /// The two thresholds F2 names, and their order. The marquee toast has to
    /// come *first* — the screensaver arriving before the panel had drifted
    /// would make the toast unreachable.
    @Test("the schedule is toast then screensaver")
    func scheduleOrder() {
        #expect(IdleSchedule.toast == 10)
        #expect(IdleSchedule.screensaver == 15)
        #expect(IdleSchedule.toast < IdleSchedule.screensaver)
        #expect(IdleSchedule.stages.map(\.stage) == [.toast, .screensaver])
        // Ascending, which `stage(after:)` relies on to let the last match win.
        for pair in zip(IdleSchedule.stages, IdleSchedule.stages.dropFirst()) {
            #expect(pair.0.after < pair.1.after)
        }
    }

    @Test("a duration resolves to the stage it has reached")
    func stageForDuration() {
        #expect(IdleSchedule.stage(after: 0) == .active)
        #expect(IdleSchedule.stage(after: 9.99) == .active)
        // Inclusive at the boundary: at exactly ten seconds it has been ten
        // seconds.
        #expect(IdleSchedule.stage(after: 10) == .toast)
        #expect(IdleSchedule.stage(after: 14.99) == .toast)
        #expect(IdleSchedule.stage(after: 15) == .screensaver)
        #expect(IdleSchedule.stage(after: 6000) == .screensaver)
    }

    /// **The reason `advance` returns an optional.** A consumer that starts an
    /// animation needs "we just crossed", not "we are past" — the difference
    /// between a dissolve playing once and playing on every tick forever.
    @Test("advancing reports crossings, not the current stage")
    func advanceReportsCrossings() {
        var clock = IdleClock()
        #expect(clock.advance(to: 3) == nil)
        #expect(clock.advance(to: 9.9) == nil)
        #expect(clock.advance(to: 10.1) == .toast)
        #expect(clock.advance(to: 11) == nil, "still in the toast stage; nothing was crossed")
        #expect(clock.advance(to: 14.9) == nil)
        #expect(clock.advance(to: 15.2) == .screensaver)
        #expect(clock.advance(to: 400) == nil)
    }

    /// A tick that arrives very late — a busy main actor, a returning app —
    /// lands on the furthest stage rather than replaying the ones it slept
    /// through.
    @Test("a late tick reports the furthest stage reached")
    func lateTickSkips() {
        var clock = IdleClock()
        #expect(clock.advance(to: 90) == .screensaver)
        #expect(clock.stage == .screensaver)
    }

    /// The clock never walks itself backwards. Only activity lowers a stage —
    /// otherwise a reading that came in slightly low would flicker the
    /// screensaver off and straight back on.
    @Test("the stage never falls without activity")
    func neverRegresses() {
        var clock = IdleClock()
        clock.advance(to: 16)
        #expect(clock.stage == .screensaver)
        #expect(clock.advance(to: 2) == nil)
        #expect(clock.stage == .screensaver, "a low reading must not lower the stage")
    }

    @Test("activity resets to active and reports whether it mattered")
    func activityResets() {
        var clock = IdleClock()
        #expect(clock.noteActivity() == false, "already active and at zero — nothing to do")

        clock.advance(to: 12)
        #expect(clock.stage == .toast)
        #expect(clock.noteActivity() == true)
        #expect(clock.stage == .active)
        #expect(clock.idle == 0)

        // And the stages are reachable again afterwards, which is what makes it
        // a loop rather than a one-shot.
        #expect(clock.advance(to: 10) == .toast)
    }

    /// Negative durations are clamped rather than trusted: a monotonic clock
    /// should never produce one, and if one arrives it must not become a
    /// negative idle time that the schedule then reads as `.active` forever.
    @Test("negative input is clamped")
    func clampsNegatives() {
        var clock = IdleClock(idle: -5)
        #expect(clock.idle == 0)
        clock.advance(to: -1)
        #expect(clock.idle == 0)
        #expect(clock.stage == .active)
    }

    /// `Comparable` is what lets a consumer ask "at least this far" and keep
    /// working when a stage is inserted between two others.
    @Test("stages compare in order")
    func stagesCompare() {
        #expect(IdleStage.active < .toast)
        #expect(IdleStage.toast < .screensaver)
        #expect(IdleStage.allCases == [.active, .toast, .screensaver])
    }

    /// **The reconciliation F2 asks for.** Through 0.7.2 the marquee counted its
    /// own ten seconds in a tuple on an enum case. If these two ever disagree,
    /// the device is idling on two reckonings again and the panel changes at a
    /// different moment from everything else that cares.
    @Test("the marquee's idle dwell is the shared threshold")
    func marqueeSharesTheSchedule() throws {
        let dwell = try #require(MarqueeStage.menu.timeout)
        #expect(dwell.after == IdleSchedule.toast)
        #expect(dwell.then == .cheers)
        #expect(MarqueeStage.menu.awaitsIdleTimer)
        // WELCOME! is a beat, not an idle threshold, and stays the banner's own
        // sleep — see the note on `MarqueeStage.timeout`.
        #expect(!MarqueeStage.welcome.awaitsIdleTimer)
        #expect(!MarqueeStage.cheers.awaitsIdleTimer)
        let beat = try #require(MarqueeStage.welcome.timeout)
        #expect(beat.after < IdleSchedule.toast)
    }

    /// The screensaver has to arrive *after* the panel has drifted, or the
    /// toast is a state nobody ever sees.
    @Test("the toast is reachable before the screensaver covers it")
    func toastIsReachable() {
        var clock = IdleClock()
        #expect(clock.advance(to: IdleSchedule.toast) == .toast)
        #expect(clock.stage == .toast)
        #expect(IdleSchedule.screensaver > IdleSchedule.toast)
    }
}
