#if canImport(UIKit)
import UIKit
import VinodexCore

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
    /// an explicit opt-out disables them. The default itself lives in
    /// `SettingsDefault`, shared with the toggle that writes it (arch **A17**).
    public static let storageKey = SavedDataKey.hapticsEnabled.rawValue

    private static let impact = UIImpactFeedbackGenerator(style: .rigid)

    /// Via `SettingsCache` (AUDIT **L16**), which keeps "never written" as its
    /// own answer — flattening it to `false` here would turn the opt-out into
    /// an opt-in.
    private static var enabled: Bool {
        SettingsCache.bool(forKey: storageKey) ?? SettingsDefault.hapticsEnabled
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

    /// It worked: a save landed, a quiz answer was right. (AUDIT **L38**)
    ///
    /// `UINotificationFeedbackGenerator` rather than another `impact`, because
    /// the distinction is the whole point — every one of the ~78 feedback call
    /// sites got the same rigid tap, so the buzz said "you pressed something"
    /// and never "and here is how it went". Success and warning are the two
    /// system patterns a hand already reads without being taught.
    ///
    /// The sound stays with the call site rather than riding along as `tap()`
    /// and `select()` do: `correct()` has an authored sting and its failure
    /// counterpart does not, so pairing them here would promise a voice that
    /// does not exist. See **L43**.
    public static func success() {
        guard enabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// It did not: a wrong answer, or a destructive confirm about to be taken.
    public static func warning() {
        guard enabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}

/// Keeps the display awake while browsing — a reference app gets consulted with
/// wet hands and a bottle in the other one.
///
/// Behind a setting since AUDIT **L40**. `isIdleTimerDisabled` used to be set
/// once, on launch, and left on for the whole life of the process: the phone
/// simply never auto-locked while Vinodex was open, which is a battery and a
/// pocket-unlock problem the user was never told about, let alone asked. The
/// key defaults **on**, so the behaviour is unchanged for anyone who does not
/// go looking — the point is that there is now somewhere to look.
@MainActor
public enum ScreenWake {
    /// Missing key = on, like `Haptics`: this is part of how the device
    /// behaves, so only an explicit opt-out turns it off.
    public static let storageKey = SavedDataKey.keepAwakeEnabled.rawValue

    static var enabled: Bool {
        SettingsCache.bool(forKey: storageKey) ?? SettingsDefault.keepAwakeEnabled
    }

    /// Applies the setting. `enabled: false` always releases the timer — the
    /// caller is saying "the app is going away", which the preference does not
    /// get a vote on.
    public static func keepAwake(_ wanted: Bool) {
        UIApplication.shared.isIdleTimerDisabled = wanted && enabled
    }

    /// Re-applies after the toggle moves, so turning it off releases the timer
    /// there and then rather than at the next launch.
    public static func settingChanged() {
        keepAwake(true)
    }
}
#endif
