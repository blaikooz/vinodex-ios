import Foundation

/// What the marquee panel says on the main screen, and when it changes
/// (0.7.1, B1–B3).
///
/// **What this replaces.** Through 0.6.9 the main screen handed the panel five
/// greetings — CHEERS!, SANTE!, SALUTE!, PROST!, KANPAI! — and the banner
/// cycled them forever on a 2.6-second dwell. B1–B3 replace the loop with a
/// script: the device greets you once, settles into naming the screen you are
/// on, and only goes back to a toast when you have stopped using it. Three
/// states, two transitions, and an end.
///
/// **Why the policy is here and the clock is not.** A `Task.sleep` loop in a
/// SwiftUI view is invisible to `swift test` — VinodexUI does not compile on
/// Linux at all — and the interesting half of B1–B3 is not the sleeping, it is
/// *which state follows which, after how long, and what an interaction does to
/// the one you are in.* That is arithmetic over an enum and it belongs where a
/// gate can see it. `MarqueeBanner` owns the clock and reads the table.
public enum MarqueeStage: String, CaseIterable, Sendable, Equatable {
    /// B1: what the device says the first time you look at it after launch.
    case welcome
    /// The resting state. Names the screen, which on the main screen is the
    /// menu itself.
    case menu
    /// B3: the idle state. The greeting the five toasts were, kept as the one
    /// the device drifts into rather than the one it opens with — a toast is
    /// what you say when the drinking has started, not when the machine boots.
    case cheers

    /// The panel's text.
    ///
    /// ASCII and uppercase, deliberately, as every marquee string has been
    /// since 0.6.9: the bundled Press Start 2P is a display face with a partial
    /// Latin-1 range, and a missing glyph on the device's most prominent panel
    /// is a worse outcome than a missing accent. All three of these are inside
    /// its range with room to spare — WELCOME! is the longest at eight
    /// characters, against the fourteen the panel fits before it scales.
    ///
    /// For `.cheers` this is the *first* toast only. Since 0.7.2 (A8) the idle
    /// greeting rotates through `MarqueeCheers.all`, which the stage alone
    /// cannot know — the rotation belongs to the script that has run, not to
    /// the enum case. Read `MarqueeScript.text` for what the panel actually
    /// says; this stays as the stage's canonical label so the enum keeps a
    /// total, testable `text` and `.cheers` still means CHEERS!.
    public var text: String {
        switch self {
        case .welcome: "WELCOME!"
        case .menu: "MENU"
        case .cheers: MarqueeCheers.all[0]
        }
    }

    /// The stage this one becomes when its dwell expires, and how long that
    /// dwell is. `nil` means a resting state that nothing but an interaction
    /// leaves.
    ///
    /// The two numbers are the two the spec gives, and they are very different
    /// on purpose. WELCOME! is a *beat* — long enough to read eight characters
    /// and no longer, because everything behind it is waiting. The 10 seconds
    /// before CHEERS! is an *idle threshold*: it has to outlast someone reading
    /// the four menu tiles and deciding, or the panel changes under a user who
    /// never stopped using the device.
    ///
    /// **That difference is now structural (0.7.3, F2).** The two dwells are
    /// still both described here — this stays the whole state machine, and a
    /// table with a hole in it would be worse than one with a footnote — but
    /// only the beat is still *timed* here. `MarqueeBanner` runs the 2.4-second
    /// sleep; the 10-second one is `IdleSchedule.toast`, driven by the app's one
    /// idle timer, which is also what raises the screensaver five seconds later.
    /// Two clocks counting the same silence was how the marquee could be idling
    /// on a different reckoning from everything else that cares.
    public var timeout: (after: TimeInterval, then: MarqueeStage)? {
        switch self {
        case .welcome: (2.4, .menu)
        case .menu: (IdleSchedule.toast, .cheers)
        case .cheers: nil
        }
    }

    /// Whether this stage's dwell is the shared idle timer's to fire rather than
    /// the banner's own (0.7.3, F2).
    ///
    /// The banner asks this instead of hardcoding "run a sleep for `.welcome`
    /// and not for `.menu`", so the day a stage moves from one clock to the
    /// other, it moves here and the view does not change.
    public var awaitsIdleTimer: Bool { self == .menu }
}

/// The toasts the idle panel rotates through (0.7.2, A8).
///
/// **This is the 0.6.9 list coming back, with a job.** Through 0.6.9 the panel
/// cycled CHEERS!, SANTE!, SALUTE!, PROST!, KANPAI! forever on a 2.6-second
/// dwell, and 0.7.1's B1–B3 retired the loop because a device that never stops
/// talking never says anything. A8 asks for the languages back — and the script
/// is what makes that affordable now. A toast is no longer something the panel
/// does *instead of* being useful; it is where it lands after ten seconds of
/// being ignored, so a different one each time is a small reward for coming
/// back rather than a carousel demanding attention.
///
/// **ASCII, uppercase, and 14 characters or fewer**, the rule every marquee
/// string has followed since 0.6.9 and the reason SANTE and SAUDE are spelled
/// without their accents: the bundled Press Start 2P has a partial Latin-1
/// range, and a missing glyph on the device's most prominent panel is worse
/// than a missing accent. `MarqueeScriptTests` gates all three.
///
/// One language per entry, and the wine world is why the list looks like this:
/// seven of the nine are the languages of countries in the catalog. KANPAI is
/// in the spec's own list and stays for the same reason it did in 0.6.9 — it is
/// the toast most people who do not speak the language still recognise. CIN CIN
/// takes Italy's slot in place of 0.6.9's SALUTE because A8 names it.
public enum MarqueeCheers {
    /// In rotation order. Index 0 is CHEERS! because the first idle of a launch
    /// should be the one in the user's own interface language — the rotation is
    /// a flourish on a familiar thing, not a guessing game on first sight.
    public static let all: [String] = [
        "CHEERS!",    // English
        "SANTE!",     // French
        "SALUD!",     // Spanish
        "CIN CIN!",   // Italian
        "PROST!",     // German
        "SAUDE!",     // Portuguese
        "YAMAS!",     // Greek
        "SKAL!",      // Danish, Norwegian, Swedish
        "KANPAI!",    // Japanese
    ]

    /// The toast for a given rotation count, wrapping forever.
    ///
    /// Takes any `Int` and floors it at zero rather than taking a `UInt`: the
    /// caller is a counter that only ever goes up, and a modulo on a negative
    /// would be a silent crash rather than a compile error if that ever stopped
    /// being true.
    public static func toast(at index: Int) -> String {
        all[max(index, 0) % all.count]
    }
}

/// The main screen's marquee state machine (0.7.1, B1–B3).
///
/// A value type with `mutating` transitions rather than an observable object:
/// there is exactly one of these, it lives in `@State` on the chassis, and
/// making it a class would buy a second identity to keep in step for nothing.
public struct MarqueeScript: Sendable, Equatable {
    public private(set) var stage: MarqueeStage

    /// Whether WELCOME! has already had its turn this launch.
    ///
    /// Once, per launch, is the whole of B1 — the greeting is for arriving at
    /// the device, not for arriving at the main menu, and a user who taps into
    /// GRAPES and comes straight back has not re-launched anything. Without
    /// this the script would re-greet on every return to the menu, which is the
    /// cycling loop B1 replaced wearing a different hat.
    public private(set) var greeted: Bool

    /// How many idle periods this launch has already spent (0.7.2, A8), which
    /// is the index into `MarqueeCheers.all`.
    ///
    /// Advanced on *leaving* CHEERS!, not on arriving: the panel that is on
    /// screen must not change under the user, and "each idle fade" is one fade
    /// per idle period. Arriving shows `toast(at: idleCount)`; the increment
    /// happens when activity or a navigation ends that period, so the next fade
    /// brings the next language.
    ///
    /// Not persisted. A rotation that survived a relaunch would mean the app
    /// opening on YAMAS! for someone who has no idea why, and the greeting
    /// ladder is a per-launch story throughout — `greeted` above works the same
    /// way.
    public private(set) var idleCount: Int

    public init(stage: MarqueeStage = .welcome, greeted: Bool = false, idleCount: Int = 0) {
        self.stage = stage
        self.greeted = greeted
        self.idleCount = idleCount
    }

    /// What the panel says right now — the stage's label, except at rest, where
    /// it is this launch's current toast (0.7.2, A8).
    public var text: String {
        stage == .cheers ? MarqueeCheers.toast(at: idleCount) : stage.text
    }

    /// The dwell the current stage is waiting out, if any.
    public var pendingTimeout: (after: TimeInterval, then: MarqueeStage)? {
        stage.timeout
    }

    /// A dwell expired. Returns whether the stage actually moved, so a caller
    /// can skip the transition animation when it did not.
    @discardableResult
    public mutating func timedOut() -> Bool {
        guard let next = stage.timeout?.then else { return false }
        stage = next
        if next != .welcome { greeted = true }
        return true
    }

    /// The user did something — a tap, a navigation, a return to the menu.
    ///
    /// Sends the panel back to MENU, which restarts the 10-second idle dwell
    /// because the timeout is read off the stage. It also *consumes* WELCOME!:
    /// someone who taps within the first two seconds has been greeted whether
    /// or not they read it, and re-showing the greeting after their first
    /// interaction would be the device introducing itself to someone already
    /// using it.
    ///
    /// Returns whether the stage moved, for the same reason `timedOut` does —
    /// activity on an already-resting MENU is the common case and must not
    /// re-trigger a 1.4-second dissolve every time a finger lands.
    @discardableResult
    public mutating func noteActivity() -> Bool {
        greeted = true
        guard stage != .menu else { return false }
        // That idle period is over, so the next one gets the next language
        // (0.7.2, A8). Guarded on the stage rather than done unconditionally:
        // activity while WELCOME! is up has not consumed a toast.
        if stage == .cheers { idleCount += 1 }
        stage = .menu
        return true
    }

    /// The user left the main screen.
    ///
    /// The script only runs on the main menu — B3 says "on the Main Menu" and
    /// every other screen's panel is its own title — so leaving both consumes
    /// the greeting and parks the script at MENU, which is where returning
    /// should find it.
    public mutating func leftMainScreen() {
        greeted = true
        // Same rule as `noteActivity` (0.7.2, A8): navigating away ends the idle
        // period, so coming back and idling again brings the next toast.
        if stage == .cheers { idleCount += 1 }
        stage = .menu
    }
}
