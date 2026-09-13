import Foundation

/// **What the device is, said once, before anyone is asked to do anything.**
///
/// ## The gap this fills
///
/// Until 0.9.57 a new player met the BIOS, gave Professor Vino a name, and was
/// then put straight into the six-step coachmark — a *guided run*, which will
/// not advance until you press GRAPES, then press TRIED, then open the
/// Passport. That is a good second experience and a demanding first one, and it
/// left three things unsaid that a first session has no business omitting: the
/// label reader (mentioned once, at the end, as a promise about *later*), the
/// globe, and the exam.
///
/// So the guided run moves to where it was always reachable anyway —
/// SETTINGS ▸ DEVICE ▸ TUTORIAL, which already offers it through
/// `WalkthroughScreen.onGuidedRun` — and this takes the first-launch slot.
/// Four cards, one per pillar, read in well under a minute, and nothing here
/// waits on the player doing anything.
///
/// ## Why the scanner is second and not last
///
/// It is the thing nothing else does: a camera pointed at a bottle, matched
/// against 185,000 wines carried on the device with no network at all. The old
/// sequence saved it for a closing line, which meant a player could finish
/// onboarding without ever learning the app could do it. Cards are read in
/// order and attention decays, so the strongest claim goes early — first place
/// belongs to what the app *is*, and second to what only it can do.
///
/// ## No new one-shot key, deliberately
///
/// This runs where `CoachmarkEngine.shouldAutoStart` already said the coachmark
/// would, so it inherits that gate — `hasBeenOffered`, seeded by
/// `seed(hasHistory:)` against a real install's history. That matters: the
/// coachmark's own notes record a first-run one-shot misfiring in four
/// consecutive batches, each time ambushing an existing player after an update.
/// Adding a second flag with the same job would be a fifth chance to get it
/// wrong, and a new `SavedDataKey` that BACK UP would have to learn about
/// (0.9.54's B1 found the archive silently dropping 25 unregistered keys).
///
/// Copy lives here rather than in the view for the reason `Walkthrough`'s does:
/// a card with no body, or two cards claiming the same pillar, is a bug you
/// would otherwise only find by tapping through.
public struct OrientationCard: Sendable, Equatable, Identifiable {
    /// Stable, and storage-shaped even though nothing persists it yet — the
    /// house rule every other id in this app carries is *once shipped, never
    /// renamed*, and an analytics or resume feature would key on these.
    public let id: String
    /// The pillar's name, as the screen shows it.
    public let title: String
    /// What it is, then why it is worth knowing. Two sentences, no more: this
    /// is the screen a player is most likely to skip, and length is what makes
    /// them.
    public let body: String
    /// The expression Vino wears while the card is up.
    ///
    /// The type, not its `artStem` string — a raw stem here shipped once as
    /// "neutral" where `DexChromeGlyph` wanted "vino-neutral", and every card
    /// drew the fallback chip instead of his face. The enum cannot be given a
    /// stem that does not exist.
    public let expression: VinoExpression

    public init(id: String, title: String, body: String, expression: VinoExpression) {
        self.id = id
        self.title = title
        self.body = body
        self.expression = expression
    }
}

public enum Orientation {
    /// The four pillars, in reading order.
    public static let cards: [OrientationCard] = [
        OrientationCard(
            id: "encyclopedia",
            title: "THE ENCYCLOPEDIA",
            body: """
            Five hundred and forty entries: grapes, regions, styles and the \
            flavours they carry. All of it is on this device — no account, no \
            signal, nothing to load.
            """,
            expression: .neutral
        ),
        OrientationCard(
            id: "reader",
            title: "THE LABEL READER",
            body: """
            Point the camera at a bottle and I will tell you what is in it, \
            matched against a hundred and eighty-five thousand wines. That one \
            works on a mountain with no signal too.
            """,
            expression: .goodjob
        ),
        OrientationCard(
            id: "practice",
            title: "PRACTICE",
            body: """
            An exam in three tiers, a question a day, and a Passport that \
            counts every wine you mark as tried. Study properly and it keeps \
            the score for you.
            """,
            expression: .thinking
        ),
        OrientationCard(
            id: "world",
            title: "THE WORLD",
            body: """
            A globe of every country that makes wine. Tap one to go to it, tap \
            again and its regions are painted onto the sphere where they \
            belong.
            """,
            expression: .raiseaglass
        ),
    ]

    public static var count: Int { cards.count }

    /// The closing line, which hands the player the menu and gets out of the
    /// way. Not a card: it carries no pillar and needs no portrait beat.
    public static let closing = "That is the whole device, {name}. Press MENU and start anywhere."
}
