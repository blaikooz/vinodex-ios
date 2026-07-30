#if canImport(UIKit)
import UIKit

/// Chassis button feedback.
///
/// One of the two things the plan calls out as worth adding natively: the web
/// app draws physical-looking buttons but cannot make them feel physical.
///
/// The settings toggle gates here, at the choke point, rather than at the
/// ~55 call sites — a call site that checked the setting itself would be the
/// one that forgets to.
@MainActor
public enum Haptics {
    /// Missing key = on: haptics are part of the device's character, so only
    /// an explicit opt-out disables them.
    public static let storageKey = "hapticsEnabled"

    private static let impact = UIImpactFeedbackGenerator(style: .rigid)

    private static var enabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: storageKey) == nil || defaults.bool(forKey: storageKey)
    }

    /// Call slightly before the visual response so the tap feels causal.
    ///
    /// The sound rides along here — before this system's own guard, because
    /// the two toggles are independent and muting the buzz must not mute the
    /// click. This is also what gives every one of the ~55 call sites a
    /// voice without any of them changing.
    public static func tap() {
        Sounds.tap()
        guard enabled else { return }
        impact.prepare()
        impact.impactOccurred()
    }

    public static func select() {
        Sounds.select()
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// The orb pressing in: the selection haptic with the orb's own voice
    /// (v0.5.6) instead of the generic ping — one gesture, one sound.
    public static func orbPress() {
        Sounds.orb()
        guard enabled else { return }
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
