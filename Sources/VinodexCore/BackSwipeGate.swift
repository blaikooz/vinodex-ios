import Foundation
import Observation

/// Whether the LCD's app-wide back swipe is currently listening (0.6.8, I1/I2).
///
/// I1 puts one back gesture on the display and I3 retires the per-page ones, so
/// the gesture is mounted once, in `DeviceChassis`, over whatever screen is
/// showing. That is the right shape for nine screens out of ten — but a screen
/// that *itself* owns horizontal dragging would have both readings of the same
/// finger movement fire at once, because the chassis has to run its recogniser
/// `simultaneously` (a parent `.gesture` loses outright to a child's, and nearly
/// every screen is a `ScrollView`).
///
/// So the exception is registered rather than negotiated. A screen that owns the
/// drag suspends the gate while it is mounted; the chassis reads
/// `isEnabled` and stands down. Exactly one screen does this today — the globe,
/// where dragging *is* how you turn the world — and the point of putting the
/// switch here rather than offering `DeviceChassis` a parameter is that the
/// conflict belongs to the screen: the chassis cannot know which of its
/// arbitrary contents happens to want the gesture, and a screen that grows a
/// drag later can opt out without the chassis changing.
///
/// **A count, not a flag.** The globe is mounted in two places — its own route
/// and, embedded, as the scanner's origin step — and a nested pair of
/// appear/disappear cycles can interleave, so a boolean gets stuck off when the
/// inner one disappears first. Balanced `suspend()`/`resume()` calls cannot.
/// Clamped at zero so an unmatched `resume()` (a view whose `onAppear` never
/// ran) cannot drive the count negative and latch the gate open.
@MainActor
@Observable
public final class BackSwipeGate {
    public static let shared = BackSwipeGate()

    private var suspensions = 0

    private init() {}

    /// True when no mounted screen has claimed horizontal dragging.
    public var isEnabled: Bool { suspensions == 0 }

    public func suspend() { suspensions += 1 }

    public func resume() { suspensions = max(suspensions - 1, 0) }
}
