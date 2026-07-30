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
        case back
        case saved
        case home
        case marquee
    }

    public let id: String
    public let title: String
    public let body: String
    public let highlight: Highlight

    public init(id: String, title: String, body: String, highlight: Highlight) {
        self.id = id
        self.title = title
        self.body = body
        self.highlight = highlight
    }
}

public enum Walkthrough {
    /// Ten steps, in the order someone actually meets the device: what it is,
    /// what the screen does, then each control, then where to go first.
    ///
    /// Written to be read aloud — short sentences, second person, no jargon that
    /// the app has not already introduced. The one piece of vocabulary it does
    /// teach is "chassis", because the settings panel uses that word.
    public static let steps: [WalkthroughStep] = [
        WalkthroughStep(
            id: "welcome",
            title: "WELCOME",
            body: """
            This is a wine encyclopedia dressed as a handheld console. \
            Everything lives inside the device — the screen shows what you look \
            up, and the buttons around it get you there. It takes about a minute \
            to learn. Let's walk round it.
            """,
            highlight: .device
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
            id: "saved",
            title: "YOUR SHELF",
            body: """
            The person button opens your saved entries. Tap SAVE on anything \
            worth coming back to and it lands there. That screen is also where \
            you set your name and add a photo, so it feels like yours.
            """,
            highlight: .saved
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
            eight of them, from paper-white to green terminal phosphor — and \
            swaps the chassis: ten colourways, each with its own lights and \
            buttons. SETTINGS holds text size, haptics and sound. DATA shows \
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
