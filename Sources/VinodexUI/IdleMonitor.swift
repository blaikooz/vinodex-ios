#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

/// The app's one inactivity tracker (0.7.3, F2).
///
/// **What this replaces.** Through 0.7.2 the marquee kept its own clock — a
/// `Task.sleep` inside `.task(id:)` on the chassis — and it was reset by exactly
/// one thing in the whole app: tapping the marquee itself. Tapping a menu tile,
/// scrolling a list, dragging a stamp, answering a quiz question: none of it
/// counted as activity, because none of it had anywhere to report to. That was
/// survivable for a panel that changes a word. It is not survivable for a
/// screensaver, which would have covered the screen of somebody actively reading
/// a list. F2 asks for one tracker, staged, reset on any interaction, and this
/// is it: the marquee's dwell and the screensaver both hang off `stage`.
///
/// **The policy is in `IdleClock`, in Core, where a Linux gate can see it.** All
/// that is here is the part that genuinely cannot be: a wall clock, and a way to
/// hear about touches.
@MainActor
@Observable
public final class IdleMonitor {
    public static let shared = IdleMonitor()

    /// How far into the idle schedule the device is.
    public private(set) var stage: IdleStage = .active

    /// Bumped on every interaction.
    ///
    /// A counter rather than a `Date` or a callback list: `@Observable` makes
    /// `onChange(of:)` the natural way for a view to hear about this, and
    /// `onChange` needs a value that *differs* each time. A `Date` would work
    /// and would invite somebody to do arithmetic on it; a counter is only good
    /// for noticing, which is all any of its readers want.
    public private(set) var activityTick: Int = 0

    /// While true the clock is frozen and no stage advances.
    ///
    /// Two callers, both cases where the device is busy without being touched:
    /// the boot POST (A1), where a screensaver over the boot screen would be
    /// absurd, and demo mode (A2), which drives itself and would otherwise be
    /// covered by the screensaver half a minute in.
    public var isPaused = false {
        didSet {
            guard isPaused != oldValue else { return }
            // Resuming starts a fresh period rather than continuing the one that
            // was running when the pause began. A demo that ran for a minute has
            // not been ignored for a minute.
            if !isPaused { reset() }
        }
    }

    private var clock = IdleClock()
    private var startedAt = ContinuousClock.now
    private var ticker: Task<Void, Never>?

    /// How often the clock is re-read.
    ///
    /// Half a second. The schedule is one threshold since 0.7.6 (A3/A4) — sixty
    /// seconds since 0.8.0's H, thirty before that, ten and fifteen before
    /// that — so this is at worst sixty times finer
    /// than the thing it has to resolve and the worst-case lateness is
    /// invisible. Deliberately not slackened to match: the tick also has to be
    /// fine enough for a threshold somebody puts *back*, and `IdleSchedule.toast`
    /// is a knob that would restore a ten-second one in a line. Fast enough to be
    /// exact, slow enough that an idle device is doing nothing thirty times a
    /// minute rather than sixty times a second.
    private static let tick: Duration = .milliseconds(500)

    private init() {}

    /// Begin ticking. Idempotent — a second call keeps the running task.
    public func start() {
        guard ticker == nil else { return }
        reset()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tick)
                guard let self, !Task.isCancelled else { return }
                self.advance()
            }
        }
    }

    public func stop() {
        ticker?.cancel()
        ticker = nil
    }

    /// The user did something.
    ///
    /// Cheap on the common path by construction: `IdleClock.noteActivity`
    /// reports whether anything actually moved, and this is called on *every
    /// touch in the app*, almost all of which land while already active.
    public func noteActivity() {
        activityTick &+= 1
        startedAt = .now
        guard clock.noteActivity() else { return }
        stage = clock.stage
    }

    /// Drop the clock without counting an interaction.
    ///
    /// The difference from `noteActivity()` matters: this is "start the period
    /// again", used when a pause lifts, and it must not tell the marquee that a
    /// finger landed.
    public func reset() {
        startedAt = .now
        clock = IdleClock()
        stage = .active
    }

    private func advance() {
        guard !isPaused else { return }
        let elapsed = ContinuousClock.now - startedAt
        // `components` rather than a `Double` conversion helper: `Duration` has
        // no lossless `timeInterval`, and seconds plus attoseconds is exact.
        let seconds = Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) * 1e-18
        guard clock.advance(to: seconds) != nil else { return }
        stage = clock.stage
    }
}

// MARK: - App-wide activity

/// Reports every touch in the app to `IdleMonitor` (0.7.3, F2).
///
/// **Why a `UIGestureRecognizer` and not a SwiftUI gesture.** F2 wants *any*
/// interaction to reset the timer, and SwiftUI has no non-intrusive way to
/// observe one: a `simultaneousGesture` on the LCD is exactly what 0.6.9's A1
/// removed, for the good reason that every recogniser mounted on the display had
/// to be negotiated with whatever screen was mounted in it. Adding one back
/// would risk the stamp drag, the globe's pan and the quiz's taps in one move.
///
/// This recogniser cannot do that, because it never competes. It fails itself in
/// `touchesBegan`, before the gesture system has anything to arbitrate, and it
/// carries `cancelsTouchesInView = false` and `delaysTouchesBegan = false` — so
/// the touch reaches the view hierarchy unchanged and unmodified. It is a tap on
/// the shoulder, not a gate.
///
/// **It is on the window, not on any view**, so it sees touches on the chassis
/// furniture and the LCD alike without either knowing it exists.
///
/// Installed through `IdleTouchWatcher.install()`, which is the only part of
/// this the app module needs; the recogniser itself is an implementation detail
/// and exports nothing else.
@MainActor
public final class IdleTouchWatcher: UIGestureRecognizer {
    /// Installed once. A second call is a no-op, which matters because
    /// `RootView.onAppear` can run again after a scene reconnects.
    private static var installed = false

    public static func install() {
        guard !installed else { return }
        guard let window = keyWindow() else {
            // The window is normally up by the time `onAppear` runs, but a scene
            // that is still connecting has none. Retry once on the next runloop
            // turn rather than polling: if it is not there then, it is not a
            // timing problem.
            Task { @MainActor in
                guard !installed, let window = keyWindow() else { return }
                attach(to: window)
            }
            return
        }
        attach(to: window)
    }

    private static func attach(to window: UIWindow) {
        let watcher = IdleTouchWatcher()
        watcher.cancelsTouchesInView = false
        watcher.delaysTouchesBegan = false
        watcher.delaysTouchesEnded = false
        window.addGestureRecognizer(watcher)
        installed = true
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        IdleMonitor.shared.noteActivity()
        // Fail immediately. A recogniser in `.failed` is out of the arbitration
        // for the rest of the touch, which is the whole reason this is safe to
        // put on the window at all.
        state = .failed
    }
}
#endif
