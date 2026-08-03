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
    ///
    /// `CaseIterable` so a test can prove every case has a spoken equivalent —
    /// see `diagramDescription(isolated:)`. A highlight the diagram can draw and
    /// nothing can describe is the defect **M48** names.
    public enum Highlight: String, Sendable, Hashable, CaseIterable {
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

        /// What `DeviceDiagram` actually draws for this case, in words (AUDIT
        /// **M48**).
        ///
        /// The tour's whole instructional payload is a picture with one part
        /// glowing and the rest at 38% opacity — "this part lights up", conveyed
        /// by opacity alone. Anyone who cannot see it gets eight paragraphs
        /// pointing at nothing.
        ///
        /// Here rather than in the view for the same reason the prose is: it is
        /// the part a test can reach, and a label that disagrees with the
        /// picture is worse than no label. Each string is written against the
        /// *drawing*, not against the step's body — the settings step's body
        /// mentions the person button, and the diagram does not light it, so
        /// this does not claim it does.
        ///
        /// A `switch` with no `default`, so a thirteenth highlight cannot be
        /// drawn without someone deciding what it sounds like.
        public func diagramDescription(isolated: Bool) -> String {
            let base: String
            switch self {
            case .device:
                base = "Diagram of the handheld with every part lit: the screen showing the main menu, the cog above it, and the Back, Saved and Home buttons below."
            case .screen:
                base = "Diagram of the handheld with its screen lit. The screen shows the main menu: four category tiles around a round search button."
            case .search:
                base = "Diagram of the main menu with the round search button at its centre lit."
            case .orb:
                base = "Diagram of the handheld with the round indicator light at the top left lit."
            case .lights:
                base = "Diagram of the handheld with the three small status lights at the top left lit."
            case .settings:
                base = "Diagram of the handheld with the cog at the top right lit."
            case .tools:
                base = "Diagram of the handheld with the cog at the top right lit, and the screen showing the settings grid of four tiles, the wrench tile outlined and lit."
            case .entry:
                base = "Diagram of the screen showing one entry: a picture and a name at the top, a row of three linked tiles below it, then a section of rows, each with an arrow."
            case .back:
                base = "Diagram of the handheld with the Back button, the left arrow at the bottom left, lit."
            case .saved:
                base = "Diagram of the handheld with the Saved button, the person at the bottom, lit."
            case .home:
                base = "Diagram of the handheld with the Home button, the house at the bottom right, lit."
            case .marquee:
                base = "Diagram of the handheld with the scrolling banner along the bottom lit."
            }
            return isolated ? base + " Nothing else is drawn." : base
        }
    }

    public let id: String
    public let title: String
    public let body: String
    public let highlight: Highlight
    /// When set, the diagram *hides* everything that is not the subject rather
    /// than dimming it, so there is exactly one thing to look at.
    ///
    /// **No shipped step sets it.** The comment here used to say "the opening
    /// step shows one button and nothing else", and that has not been true
    /// since the tour was rewritten in v0.5.4 — every step below dims. Kept
    /// because the diagram still implements it (`WalkthroughScreen.dim(_:)`)
    /// and it is one argument away from being used again; corrected because
    /// **M48** needed a text equivalent per step, and a description written
    /// from a stale comment would have told a VoiceOver user the screen was
    /// blank.
    public let isolated: Bool

    /// The diagram's text equivalent for this step (AUDIT **M48**), so a test
    /// can walk `Walkthrough.steps` directly rather than reassembling it.
    public var diagramDescription: String { highlight.diagramDescription(isolated: isolated) }

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
