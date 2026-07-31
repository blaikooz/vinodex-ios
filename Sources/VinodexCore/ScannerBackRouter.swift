import Foundation

/// Lets the chassis Back button step *backward through the scanner's
/// questions* instead of abandoning the whole flow (0.6.4, B2).
///
/// The scanner is one route holding a five-question cursor, and until now the
/// chassis Back popped that route wholesale. Because the questionnaire
/// persists itself (`ScreenStateStore.scanner`), popping and re-entering
/// landed you on the very step you left — so from the device's face the main
/// Back button on a scanner page appeared to do nothing at all. That is the
/// bug this exists to fix.
///
/// A registration seam rather than shared state: the scanner owns its `Step`
/// cursor as view-local `@State`, and the app's `goBack()` is the only place
/// that knows a Back press is about to pop the scanner route. The screen
/// registers a handler on appear; `goBack()` offers the press to it first and
/// only pops when the handler declines (already on question one) or when no
/// scanner is mounted. Cleared on disappear so a stale handler can never
/// swallow Back presses meant for other screens.
@MainActor
public final class ScannerBackRouter {
    public static let shared = ScannerBackRouter()

    /// Returns true when the scanner consumed the press by stepping back a
    /// question; false means "nothing to unwind — pop the route".
    public var handler: (() -> Bool)?

    private init() {}

    /// The app-side entry point: true when the press was consumed in-screen.
    public func handleBack() -> Bool {
        handler?() ?? false
    }
}
