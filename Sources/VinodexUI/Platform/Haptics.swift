#if canImport(SwiftUI) && canImport(UIKit)
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

    /// **The chassis's own buttons, and nothing else** (0.6.8, J2).
    ///
    /// Call slightly before the visual response so the tap feels causal.
    ///
    /// The sound rides along here — before this system's own guard, because
    /// the two toggles are independent and muting the buzz must not mute the
    /// click.
    ///
    /// J2 makes the *scope* the point: Button Tap is the noise a moulded cap
    /// makes, so it belongs to the four caps in the footer, the orb, and the
    /// engraved arrow on the back plate — the parts you would hear if the
    /// device were real. Roughly twenty on-LCD call sites were using it too,
    /// which meant a tile on a glass screen clicked like a physical switch;
    /// those are `screenTap()` now.
    public static func tap() {
        Sounds.tap()
        guard enabled else { return }
        impact.prepare()
        impact.impactOccurred()
    }

    /// A firm press on the **LCD** (0.6.8, J1): the warm ping's voice with the
    /// rigid impact `tap()` gives.
    ///
    /// Two systems, not one. J1 is about sound — everything the finger does to
    /// the display gets Warm Ping — and the ~20 sites this replaces were on
    /// `tap()` because they wanted the *feel* of a decisive press (a menu tile,
    /// a primary action, a quiz answer) rather than the softer selection tick.
    /// Collapsing them into `select()` would have satisfied J1 by quietly
    /// throwing that distinction away, so the haptic stays and only the voice
    /// changes.
    public static func screenTap() {
        Sounds.select()
        guard enabled else { return }
        impact.prepare()
        impact.impactOccurred()
    }

    /// **An exam answer** (0.6.9, G1): the result sting, and nothing else.
    ///
    /// G1 is a conflict 0.6.8 created. J1 moved ~21 on-LCD sites onto Warm
    /// Ping, and the quiz's answer taps were among them — so from 0.6.8
    /// answering played Warm Ping *and* Correct Answer (or Warm Ping and
    /// Incorrect Answer), two authored stings a few milliseconds apart on the
    /// one moment in the app that most needs a single unambiguous voice.
    ///
    /// The fix is a third entry point rather than a `silent:` flag on the two
    /// existing ones, because the rule this states is not "sometimes skip the
    /// ping" — it is that an answer *has* its own sound, so the generic
    /// touch sound does not apply. J1's rule is unchanged everywhere else: the
    /// rest of the quiz screen (BEGIN, NEXT, RETRY) still pings, because those
    /// are ordinary presses on the LCD.
    ///
    /// **The buzz is the outcome too, since AUDIT L38.** G1 split the haptic a
    /// rigid impact for right and a selection tick for wrong, which keeps the
    /// two answers apart but says the wrong thing about both: the impact is the
    /// same tap ~78 other call sites fire, so it reads as "you pressed
    /// something" on the one moment in the app where the *outcome* is the
    /// message. `UINotificationFeedbackGenerator` is the pattern a hand already
    /// reads without being taught, and every caller of this method — a quiz
    /// answer, an exam answer, a stamp coming loose — is an outcome. G1's rule
    /// is untouched: one authored sound per answer, still exactly two voices.
    ///
    /// Muting sounds must not mute the buzz, so the sting is played ahead of
    /// this system's own guard, exactly as `tap()` does.
    public static func answer(correct: Bool) {
        if correct { Sounds.correct() } else { Sounds.wrong() }
        guard enabled else { return }
        if correct { success() } else { warning() }
    }

    /// The lighter on-LCD touch: selection tick, warm ping.
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
