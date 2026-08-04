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
    /// Nine steps. The tour opens on the main screen — the whole app is up
    /// there — then search, an entry, and the
    /// controls. Rewritten terse in v0.5.4: the old copy read well aloud but
    /// nobody reads a tour aloud; two sentences a page is the budget. The orb
    /// step is gone — an easter egg you are told about is not an easter egg.
    ///
    /// The ninth is the marquee's two lamp buttons (0.7.6, A1) — see the note
    /// beside it for why a tour step is the right home for a hold gesture.
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
        // **The marquee step (0.7.6, A1/F1)**, and the first to use the
        // `.marquee` highlight — it has been on the diagram and in the enum
        // since v0.5.4 with no step ever selecting it.
        //
        // It earns a step now because A1 put a customisation behind a hold, and a
        // hidden gesture with no affordance is exactly what 0.6.9's A1 complained
        // about when it removed the app-wide swipe. The retired drawer carried
        // the line "HOLD A SHORTCUT TO PIN IT" on its own surface; with the
        // drawer gone the tour is where that sentence lives, which is also why
        // F1 moving the tour into SETTINGS > DEVICE and A1 needing somewhere to
        // teach a gesture are the same batch.
        WalkthroughStep(
            id: "marquee",
            title: "THE TWO LIGHTS",
            body: """
            The lights above the panel are buttons: tools and customise. \
            Hold either one to point it somewhere else.
            """,
            highlight: .marquee
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
            // Rewritten in 0.7.2 (LR1). Two of the five names here had been
            // renamed out from under this copy — SCANNER became BLIND TASTING
            // (0.7.1, E3) and FILTER SEARCH became MASTER SEARCH (0.7.1, A1) —
            // so the tour was naming tiles that no longer exist, which on a
            // *tour* is worse than saying nothing. LABEL SCAN joins as the
            // sixth.
            body: """
            Also behind the cog: the wrench tile. Blind tasting, label scan, \
            master search, the wine exam, the daily challenge, and the moon \
            dial.
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
