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
    /// **The fold, and the two numbers it leaves** (0.7.6, A3/A4).
    ///
    /// A3 took the screensaver off 15; A4 folds the marquee's pre-idle
    /// toast into it, so `toast` is `nil` and the greeting is due at the one
    /// threshold. What is pinned here is the *shape* as much as the value: a
    /// schedule that is ascending, that ends at the screensaver, and whose
    /// greeting time is always something a consumer can ask for.
    ///
    /// **The value pin lives here and nowhere else** — every other assertion in
    /// this suite is written against `IdleSchedule.screensaver` rather than
    /// against a literal, so moving the threshold is one line here. 60 since
    /// 0.8.0 (H), 30 from 0.7.6 (A3), 15 from 0.7.3 (A5).
    @Test("the schedule is one threshold, with the toast folded into it")
    func scheduleOrder() {
        #expect(IdleSchedule.screensaver == 60)
        #expect(IdleSchedule.toast == nil, "A4 folds the toast into the screensaver")
        // The accessor every consumer reads, whichever shape the schedule is in.
        #expect(IdleSchedule.cheers == IdleSchedule.screensaver)
        #expect(IdleSchedule.stages.map(\.stage) == [.screensaver])
        // Ascending, which `stage(after:)` relies on to let the last match win.
        // Vacuous today and deliberately kept: the day `toast` is given a number
        // back, this is what catches it being given one above `screensaver`.
        for pair in zip(IdleSchedule.stages, IdleSchedule.stages.dropFirst()) {
            #expect(pair.0.after < pair.1.after)
        }
        // Reverting is a threshold change, not a rewrite — so the table has to
        // rebuild itself from the knob rather than being written out. Checked by
        // construction: whatever `toast` holds, the stages end at the screensaver
        // and carry one entry per non-nil threshold.
        #expect(IdleSchedule.stages.count == (IdleSchedule.toast == nil ? 1 : 2))
        #expect(IdleSchedule.stages.last?.stage == .screensaver)
    }

    @Test("a duration resolves to the stage it has reached")
    func stageForDuration() {
        let t = IdleSchedule.screensaver
        #expect(IdleSchedule.stage(after: 0) == .active)
        #expect(IdleSchedule.stage(after: t - 0.01) == .active)
        // Inclusive at the boundary: at exactly the threshold it has been the
        // threshold.
        #expect(IdleSchedule.stage(after: t) == .screensaver)
        #expect(IdleSchedule.stage(after: t * 200) == .screensaver)
        // `.toast` is not separately reachable while the fold is in force — but
        // it is still *passed*, which is what every `stage >= .toast` consumer
        // relies on and what makes the fold a threshold change. See `IdleStage`.
        #expect(IdleStage.screensaver >= IdleStage.toast)
        #expect(!IdleSchedule.stages.contains { $0.stage == .toast })
    }

    /// **The reason `advance` returns an optional.** A consumer that starts an
    /// animation needs "we just crossed", not "we are past" — the difference
    /// between a dissolve playing once and playing on every tick forever.
    @Test("advancing reports crossings, not the current stage")
    func advanceReportsCrossings() {
        let t = IdleSchedule.screensaver
        var clock = IdleClock()
        #expect(clock.advance(to: 3) == nil)
        #expect(clock.advance(to: t - 0.1) == nil)
        #expect(clock.advance(to: t + 0.1) == .screensaver)
        #expect(clock.advance(to: t + 1) == nil, "already there; nothing was crossed")
        #expect(clock.advance(to: t * 10) == nil)
    }

    /// A tick that arrives very late — a busy main actor, a returning app —
    /// lands on the furthest stage rather than replaying the ones it slept
    /// through.
    @Test("a late tick reports the furthest stage reached")
    func lateTickSkips() {
        var clock = IdleClock()
        #expect(clock.advance(to: 900) == .screensaver)
        #expect(clock.stage == .screensaver)
    }

    /// The clock never walks itself backwards. Only activity lowers a stage —
    /// otherwise a reading that came in slightly low would flicker the
    /// screensaver off and straight back on.
    @Test("the stage never falls without activity")
    func neverRegresses() {
        var clock = IdleClock()
        clock.advance(to: IdleSchedule.screensaver + 2)
        #expect(clock.stage == .screensaver)
        #expect(clock.advance(to: 2) == nil)
        #expect(clock.stage == .screensaver, "a low reading must not lower the stage")
    }

    @Test("activity resets to active and reports whether it mattered")
    func activityResets() {
        var clock = IdleClock()
        #expect(clock.noteActivity() == false, "already active and at zero — nothing to do")

        clock.advance(to: IdleSchedule.screensaver + 2)
        #expect(clock.stage == .screensaver)
        #expect(clock.noteActivity() == true)
        #expect(clock.stage == .active)
        #expect(clock.idle == 0)

        // And the stages are reachable again afterwards, which is what makes it
        // a loop rather than a one-shot.
        #expect(clock.advance(to: IdleSchedule.screensaver) == .screensaver)
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
        #expect(dwell.after == IdleSchedule.cheers)
        #expect(dwell.then == .cheers)
        #expect(MarqueeStage.menu.awaitsIdleTimer)
        // WELCOME! is a beat, not an idle threshold, and stays the banner's own
        // sleep — see the note on `MarqueeStage.timeout`.
        #expect(!MarqueeStage.welcome.awaitsIdleTimer)
        #expect(!MarqueeStage.cheers.awaitsIdleTimer)
        let beat = try #require(MarqueeStage.welcome.timeout)
        #expect(beat.after < IdleSchedule.cheers)
    }

    /// **The greeting and the screensaver arrive together** (0.7.6, A4), which
    /// is the fold. Before it the toast led by twenty seconds and this test
    /// asserted the gap; what has to hold now is that the panel's dwell and the
    /// screensaver's threshold are one number, or the device is idling on two
    /// reckonings again — the fault 0.7.3's F2 was written to end.
    @Test("the greeting is due exactly when the screensaver is")
    func greetingRidesTheScreensaver() {
        var clock = IdleClock()
        #expect(clock.advance(to: IdleSchedule.cheers) == .screensaver)
        // The chassis raises the toast on `stage >= .toast`, so the crossing
        // that raises the screensaver raises the greeting with it.
        #expect(clock.stage >= .toast)
        #expect(IdleSchedule.cheers == IdleSchedule.screensaver)
    }
}
