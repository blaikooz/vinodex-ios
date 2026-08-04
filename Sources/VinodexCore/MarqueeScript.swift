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
    public var text: String {
        switch self {
        case .welcome: "WELCOME!"
        case .menu: "MENU"
        case .cheers: "CHEERS!"
        }
    }

    /// The stage this one becomes when its dwell expires, and how long that
    /// dwell is. `nil` means a resting state that nothing but an interaction
    /// leaves.
    ///
    /// The two numbers are the two the spec gives, and they are very different
    /// on purpose. WELCOME! is a *beat* — long enough to read eight characters
    /// and no longer, because everything behind it is waiting. The 10 seconds
    /// before CHEERS! is B3's own figure and is an idle threshold: it has to
    /// outlast someone reading the four menu tiles and deciding, or the panel
    /// changes under a user who never stopped using the device.
    public var timeout: (after: TimeInterval, then: MarqueeStage)? {
        switch self {
        case .welcome: (2.4, .menu)
        case .menu: (10, .cheers)
        case .cheers: nil
        }
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

    public init(stage: MarqueeStage = .welcome, greeted: Bool = false) {
        self.stage = stage
        self.greeted = greeted
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
        stage = .menu
    }
}
