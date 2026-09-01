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
            // Added on integration: upstream's `.collection` arrived with the
            // shop, workshop and passport steps, which light the same settings
            // grid as `.tools` without being the tools step. Without an arm
            // here the switch stops being exhaustive and M48's whole point —
            // that every drawn state has words — would go with it.
            case .collection:
                base = "Diagram of the handheld with the cog at the top right lit, and the screen showing the settings grid of four tiles."
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
        /// The shop, the workshop and the passport all live behind the cog and
        /// all want the settings grid lit — but they are not "the settings
        /// step", so they get their own name rather than three steps claiming
        /// `.settings` and tripping `idsAreUnique`'s sibling assertion.
        case collection
    }

    public let id: String
    public let title: String
    public let body: String
    public let highlight: Highlight
    /// Which face says it (0.8.91, I2).
    ///
    /// **The tour had no narrator and that was the finding.** §I2 asks for
    /// Professor Vino to be the one telling a new user what to do rather than
    /// "anonymous chrome", and the live half of the tutorial
    /// (`CoachmarkWalkthrough`) already carried an expression per step while this
    /// half — the map, the part you meet first — was a title over a paragraph in
    /// a plain surface panel. One tutorial reading as two voices is worse than
    /// either voice alone.
    ///
    /// A field rather than a constant portrait for the reason `CoachmarkStep` has
    /// one: a tour whose presenter never changes expression is a portrait, not a
    /// character. `WalkthroughVoiceTests` holds every face in use, the same
    /// assertion `CoachmarkWalkthrough.problems()` makes.
    public let expression: VinoExpression

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

    public init(
        id: String,
        title: String,
        body: String,
        highlight: Highlight,
        expression: VinoExpression = .neutral,
        isolated: Bool = false
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.highlight = highlight
        self.expression = expression
        self.isolated = isolated
    }
}

public enum Walkthrough {
    /// The tour opens on the main screen — the whole app is up there — then
    /// search, an entry, and the controls. Rewritten terse in v0.5.4: the old
    /// copy read well aloud but nobody reads a tour aloud; two sentences a page
    /// is the budget. The orb step is gone — an easter egg you are told about is
    /// not an easter egg.
    ///
    /// The marquee's two lamp buttons arrived in 0.7.6 (A1) — see the note
    /// beside it for why a tour step is the right home for a hold gesture.
    ///
    /// ## What 0.8.8's D2 added, and what it found
    ///
    /// The tour was written at v0.5.4 and last touched for content in 0.7.2.
    /// Twelve releases shipped features it never mentions, and the item's brief
    /// — "work out what it now fails to mention" — is most of the work. What it
    /// omitted entirely: the **shop** and the packs, the **passport** and its
    /// stamps, the **device workshop**, the **globe**, and **grape lineage**.
    /// Three steps cover the first three; the globe is reachable from the main
    /// menu the opening step already describes, and lineage is a row on an entry
    /// page, which step three's "a row with an arrow opens the next entry"
    /// already covers. A tour that names everything is a manual.
    ///
    /// **And one thing it said was wrong.** The tools step listed six tools, one
    /// of which — master search — is not on that shelf and never has been (it is
    /// the main menu's middle button, which step two describes), while WHAT'S
    /// THAT…? was missing. That is exactly the drift the step's own 0.7.2 note
    /// was written to fix, recurring because prose and a grid of literals cannot
    /// be compared. The sentence is now built from `ToolRoster`, so it cannot say
    /// six when the shelf holds six different ones.
    public static let steps: [WalkthroughStep] = [
        WalkthroughStep(
            id: "screen",
            title: "START HERE",
            body: """
            A wine encyclopedia on a handheld. Four tiles — grapes, regions, \
            styles, flavours — and everything links to everything.
            """,
            highlight: .screen,
            expression: .smiling
        ),
        WalkthroughStep(
            id: "search",
            title: "SEARCH ANYTHING",
            body: """
            The middle button searches all of it at once. A grape, a place, \
            a flavour — a few letters is enough.
            """,
            highlight: .search,
            expression: .thinking
        ),
        WalkthroughStep(
            id: "entry",
            title: "WHAT AN ENTRY LOOKS LIKE",
            body: """
            Every entry has the same shape: picture and name, three tiles \
            that link onward, then the readouts. A row with an arrow opens \
            the next entry.
            """,
            highlight: .entry,
            expression: .neutral
        ),
        WalkthroughStep(
            id: "back",
            title: "GOING BACK",
            body: """
            Back steps one screen at a time and remembers where you were — \
            scroll position, open sections, all of it.
            """,
            highlight: .back,
            expression: .neutral
        ),
        WalkthroughStep(
            id: "home",
            title: "STARTING OVER",
            body: """
            Home returns to the main menu and clears the trail. Feeling \
            lost? This one resets everything you didn't save.
            """,
            highlight: .home,
            expression: .surprised
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
        // Said "customise" against a button that reads CUSTOMIZE, until 0.8.9b.
        // Player-facing copy in this app is US-spelled; the doc comments are
        // not, and do not need to be.
        WalkthroughStep(
            id: "marquee",
            title: "THE TWO LIGHTS",
            body: """
            The lights above the panel are buttons: tools and customize. \
            Hold either one to point it somewhere else.
            """,
            highlight: .marquee,
            expression: .thinking
        ),
        WalkthroughStep(
            id: "settings",
            title: "MAKING IT YOURS",
            body: """
            The cog: screen modes, chassis skins, text size, haptics, sound. \
            The person button beside Back keeps your shelf and profile.
            """,
            highlight: .settings,
            expression: .neutral
        ),
        WalkthroughStep(
            id: "tools",
            title: "TOOLS",
            // Rewritten in 0.7.2 (LR1), and **derived rather than written in
            // 0.8.8 (D2)** — see the roster note above. The 0.7.2 rewrite fixed
            // two renamed tiles by hand and the copy went wrong again within two
            // releases, which is the argument for building the sentence.
            // `ToolRoster.sentence` is the six titles the shelf actually draws,
            // and each of them now also has a card of its own the first time you
            // open it.
            body: """
            Also behind the cog: the wrench tile. \
            \(ToolRoster.sentence.prefix(1).uppercased())\(ToolRoster.sentence.dropFirst()). \
            Each one explains itself the first time you open it.
            """,
            highlight: .tools,
            expression: .goodjob
        ),
        // **Three steps for twelve releases of features the tour never
        // mentioned** (0.8.8, D2). See the roster note above for what was
        // considered and left out.
        WalkthroughStep(
            id: "passport",
            title: "WHAT YOU'VE TASTED",
            body: """
            Mark an entry tried and it lands in your passport — counts, a rank, \
            and stamps you earn along the way. The stamps stick to the back of \
            the device, and you can move them about.
            """,
            highlight: .collection,
            expression: .goodjob
        ),
        // The WORKSHOP and SHOP steps left in the onboarding pass
        // (2026-09-01): both toured doors the first version build removed —
        // a walkthrough pointing at surfaces that do not exist is the worst
        // kind of coming soon. Their slot goes to the device's actual new
        // headliner. Both old steps are recoverable in git for the StoreKit
        // era, when their doors return.
        WalkthroughStep(
            id: "vinobot",
            title: "ASK THE ROBOT",
            body: """
            Vinobot lives on the tools shelf. Ask him about today, your \
            picks, what to study next, or this device itself. Press the \
            speaker on any entry and he reads his notes out loud.
            """,
            highlight: .collection,
            expression: .smiling
        ),
        // **The hand-off to the live half** (0.8.9d, G2). See
        // `CoachmarkWalkthrough` for the argument in full; the short version is
        // that this step has always ended by telling you to go and press
        // something, and it can now come with you.
        //
        // It goes here rather than becoming a second row in SETTINGS > DEVICE
        // because a menu with TUTORIAL and a second tutorial beside it is the
        // failure this batch was written to avoid. The diagram is the map and
        // the guided run is the first errand; a picker offering both would ask a
        // brand-new user to choose between two things they cannot yet tell
        // apart, which is 0.7.5 D1's shape exactly.
        WalkthroughStep(
            id: "done",
            title: "THAT'S IT.",
            body: """
            That was the map. SHOW ME and Vinobot walks you through a \
            first tasting on the real screens; DONE and you're on your own. \
            Both live under TUTORIAL in settings.
            """,
            highlight: .device,
            expression: .raiseaglass
        ),
    ]

    public static var count: Int { steps.count }
}
