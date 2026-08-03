import Foundation

/// Lets a screen inside the LCD turn the whole device over (AUDIT M21).
///
/// Turning the device over is the only way to reach the back plate — the
/// version, the maker's mark, the serial and the collector stamps all live
/// there — and until now the only way to *ask* for it was a one-second press
/// on the orb: undocumented, unhinted, and invisible to VoiceOver, which does
/// not deliver long presses to a non-button element at all. So the back of the
/// device was unreachable for anyone navigating by voice, and undiscoverable
/// for everyone else.
///
/// A registration seam rather than shared state, exactly like
/// `ScannerBackRouter`: `isFlipped` is view-local `@State` on `DeviceChassis`,
/// which drives a 0.7s rotation and a midpoint face swap, and lifting that
/// into an observable store would mean two owners for one animation. The
/// chassis registers a handler while it is mounted; the settings panel calls
/// `flip()` and does not need to know who answers. Cleared on disappear so a
/// stale closure cannot outlive its chassis.
///
/// The easter egg is untouched — this adds a signposted route to the same
/// place, it does not replace the hidden one.
@MainActor
public final class ChassisFlipRouter {
    public static let shared = ChassisFlipRouter()

    /// Set by the mounted chassis. Nil means nothing can be turned over, in
    /// which case `flip()` is a no-op rather than an error: a caller asking to
    /// see the back of a device that is not on screen has simply asked early.
    public var handler: (() -> Void)?

    private init() {}

    /// Turn the device over, if there is one.
    public func flip() {
        handler?()
    }
}
