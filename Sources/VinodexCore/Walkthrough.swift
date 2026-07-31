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
/// remember. It is reached by choosing TUTORIAL in settings, which means everyone
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
    /// Eight steps. The tour opens on the main screen — the whole app is up
    /// there — then search, an entry, and the
    /// controls. Rewritten terse in v0.5.4: the old copy read well aloud but
    /// nobody reads a tour aloud; two sentences a page is the budget. The orb
    /// step is gone — an easter egg you are told about is not an easter egg.
    public static let steps: [WalkthroughStep] = [
        WalkthroughStep(
            id: "screen",
            title: "START HERE",
            body: """
            A wine encyclopedia on a handheld. Four tiles — grapes, regions, \
            styles, flavours — and everything links to everything.
            """,
            highlight: .screen
        ),
        WalkthroughStep(
            id: "search",
            title: "SEARCH ANYTHING",
            body: """
            The middle button searches all of it at once. A grape, a place, \
            a flavour — a few letters is enough.
            """,
            highlight: .search
        ),
        WalkthroughStep(
            id: "entry",
            title: "WHAT AN ENTRY LOOKS LIKE",
            body: """
            Every entry has the same shape: picture and name, three tiles \
            that link onward, then the readouts. A row with an arrow opens \
            the next entry.
            """,
            highlight: .entry
        ),
        WalkthroughStep(
            id: "back",
            title: "GOING BACK",
            body: """
            Back steps one screen at a time and remembers where you were — \
            scroll position, open sections, all of it.
            """,
            highlight: .back
        ),
        WalkthroughStep(
            id: "home",
            title: "STARTING OVER",
            body: """
            Home returns to the main menu and clears the trail. Feeling \
            lost? This one resets everything you didn't save.
            """,
            highlight: .home
        ),
        WalkthroughStep(
            id: "settings",
            title: "MAKING IT YOURS",
            body: """
            The cog: screen modes, chassis skins, text size, haptics, sound. \
            The person button beside Back keeps your shelf and profile.
            """,
            highlight: .settings
        ),
        WalkthroughStep(
            id: "tools",
            title: "TOOLS",
            body: """
            Also behind the cog: the wrench tile. Scanner, filter search, \
            wine exam, the daily challenge, and the moon dial.
            """,
            highlight: .tools
        ),
        WalkthroughStep(
            id: "done",
            title: "THAT'S IT.",
            body: """
            Press Home and pick a tile. Rerun this tour any time from \
            TUTORIAL in settings.
            """,
            highlight: .device
        ),
    ]

    public static var count: Int { steps.count }
}
