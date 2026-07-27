#if canImport(UIKit)
import UIKit

/// Chassis button feedback.
///
/// One of the two things the plan calls out as worth adding natively: the web
/// app draws physical-looking buttons but cannot make them feel physical.
@MainActor
public enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .rigid)

    /// Call slightly before the visual response so the tap feels causal.
    public static func tap() {
        impact.prepare()
        impact.impactOccurred()
    }

    public static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

/// Keeps the display awake while browsing — a reference app gets consulted with
/// wet hands and a bottle in the other one.
@MainActor
public enum ScreenWake {
    public static func keepAwake(_ enabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enabled
    }
}
#endif
