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
    /// The haptics keep the split J1 was careful to preserve: a rigid impact
    /// for right — the decisive press — and the lighter selection tick for
    /// wrong. Muting sounds must not mute the buzz, so the sting is played
    /// ahead of this system's own guard, exactly as `tap()` does.
    public static func answer(correct: Bool) {
        if correct { Sounds.correct() } else { Sounds.wrong() }
        guard enabled else { return }
        if correct {
            impact.prepare()
            impact.impactOccurred()
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
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
