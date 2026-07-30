import Foundation

/// The guided tour's content.
///
/// Copy lives in Core rather than being inlined in the view for two reasons: it
/// is the one part of this feature worth testing (a step with no body, or two
/// steps claiming the same highlight, is a bug you would otherwise only find by
/// tapping through), and it keeps the walkthrough screen to layout.
///
/// **Opt-in, always.** Nothing here runs unasked — there is no first-launch
/// flag, no "3 of 7" dots ambushing a new user, and no dismissal state to
/// remember. It is reached by choosing BEGIN in settings, which means everyone
/// who sees it asked for it, and it can be replayed as often as you like.
public struct WalkthroughStep: Sendable, Hashable, Identifiable {
    /// Which part of the device the diagram lights up for this step.
    public enum Highlight: String, Sendable, Hashable {
        /// No single part — the whole device.
        case device
        case screen
        /// The master-search button drawn on the diagram's little menu.
        case search
        case orb
        case lights
        case settings
        /// The TOOLS tile on the diagram's little settings grid — the tools
        /// step swaps the mini LCD to a mock of the settings panel so it can
        /// point at where TOOLS and the settings groups actually live.
        case tools
        /// A mocked-up entry page on the diagram's little LCD, so the step
        /// about entries has an actual entry to point at.
        case entry
        case back
        case saved
        case home
        case marquee
    }

    public let id: String
    public let title: String
    public let body: String
    public let highlight: Highlight
    /// When set, the diagram *hides* everything that is not the subject
    /// rather than dimming it — the opening step shows one button and
    /// nothing else, so there is exactly one thing to look at.
    public let isolated: Bool

    public init(id: String, title: String, body: String, highlight: Highlight, isolated: Bool = false) {
        self.id = id
        self.title = title
        self.body = body
        self.highlight = highlight
        self.isolated = isolated
    }
}

public enum Walkthrough {
    /// Ten steps. The order changed in v0.5.3: the tour now opens on a single
    /// control — the person button, alone on the diagram — then Back, then a
    /// mocked-up entry, and only then widens out to the screen and the rest
    /// of the chassis. Starting with the whole device gave a new user nine
    /// things to look at and no first move.
    ///
    /// Written to be read aloud — short sentences, second person, no jargon that
    /// the app has not already introduced. The one piece of vocabulary it does
    /// teach is "chassis", because the settings panel uses that word.
    public static let steps: [WalkthroughStep] = [
        WalkthroughStep(
            id: "saved",
            title: "START HERE",
            body: """
            This is a wine encyclopedia dressed as a handheld console, and \
            this is the one button to remember: the person. It opens your \
            shelf — everything you save, want to try, or have tried lands \
            there — and it is where you set your name and photo, so the \
            device feels like yours.
            """,
            highlight: .saved,
            isolated: true
        ),
        WalkthroughStep(
            id: "back",
            title: "GOING BACK",
            body: """
            Back steps you one screen at a time, and it remembers where you \
            were — the same scroll position, the same sections open. Nothing \
            you were reading gets lost because you followed a link.
            """,
            highlight: .back
        ),
        WalkthroughStep(
            id: "entry",
            title: "WHAT AN ENTRY LOOKS LIKE",
            body: """
            Everything you look up is an entry, and they all share one shape: \
            the picture and name up top, three tiles that link onward — to a \
            colour, a place, a family — then the readouts underneath. Anything \
            in a row with an arrow is a link; tap it and you are reading the \
            next entry.
            """,
            highlight: .entry
        ),
        WalkthroughStep(
            id: "screen",
            title: "THE SCREEN",
            body: """
            Grapes, regions, styles and flavours all appear here. Four tiles on \
            the main menu open the four tables, and every entry links to the \
            others — open a grape and it names its regions; open one of those \
            and it names its grapes right back.
            """,
            highlight: .screen
        ),
        WalkthroughStep(
            id: "search",
            title: "SEARCH ANYTHING",
            body: """
            The button in the middle of the main menu searches all of it at \
            once. Type a few letters of a grape, a place, or even a flavour \
            you tasted, and it will find the entries that mention it.
            """,
            highlight: .search
        ),
        WalkthroughStep(
            id: "home",
            title: "STARTING OVER",
            body: """
            Home returns to the main menu and clears the trail behind you: \
            searches, scroll positions, half-finished games. If you ever feel \
            lost, this is the button that resets everything without losing \
            anything you saved.
            """,
            highlight: .home
        ),
        WalkthroughStep(
            id: "settings",
            title: "MAKING IT YOURS",
            body: """
            The cog opens the system panel. CUSTOMIZE picks the screen mode — \
            ten of them, from paper-white to green dot-matrix — and swaps the \
            chassis: fourteen colourways, each with its own moulding and \
            lights. SETTINGS holds text size, haptics and sound. DATA shows \
            you what is in the database.
            """,
            highlight: .settings
        ),
        WalkthroughStep(
            id: "tools",
            title: "TOOLS",
            body: """
            Also behind the cog: the screen shows where. Tap the cog, then the \
            wrench tile. Inside is a scanner that identifies a grape from \
            what's in your glass, filter search for narrowing the whole \
            database, a tasting quiz with three levels, a daily challenge with \
            a streak to keep, a daily guessing game, and the moon dial.
            """,
            highlight: .tools
        ),
        WalkthroughStep(
            id: "orb",
            title: "ONE LAST THING",
            body: """
            Press and hold the blue orb for a second, and keep holding. We're \
            not going to tell you what happens — it's nothing you need, and \
            it's better found than explained.
            """,
            highlight: .orb
        ),
        WalkthroughStep(
            id: "done",
            title: "THAT'S IT",
            body: """
            Press Home and pick a tile. If you only do one thing, open GRAPES \
            and read something you have drunk before — it is much more \
            interesting than reading about one you haven't. You can run this \
            tour again any time from BEGIN in settings.
            """,
            highlight: .device
        ),
    ]

    public static var count: Int { steps.count }
}
