import Foundation
import Observation

/// **The guided run through the discovery loop** (0.8.9d, F1/G1/G2).
///
/// ## What this is, and what the twelve-step tour is
///
/// The app already has a tutorial. 0.7.6's F1 moved it into SETTINGS > DEVICE
/// and 0.8.8's D2 rebuilt it, and spec §G2 asks for a skippable, resumable,
/// re-runnable-from-SETTINGS-`>`-DEVICE walkthrough — the same slot, the same
/// entry point, and on the face of it the same subject. Shipping two tutorials
/// in one menu would have passed every gate in this repo.
///
/// The line between them was already drawn, in `WalkthroughScreen`'s own note.
/// It rejected live spotlights, in these words: the tour "would have to drive
/// the navigation stack to reach each screen it wants to talk about, every step
/// would depend on the exact geometry of a control that moves between screens
/// ... and a user who tapped something mid-tour would end up somewhere the
/// script did not expect."
///
/// Every one of those objections is about a tour that **drives**. This one does
/// not drive anything: spec §G1's rule is that it "advances only when the user
/// performs the action", so the user navigates and the engine follows. It cannot
/// desynchronise because it has no state of its own to desynchronise *from* —
/// `report(_:)` is the only way forward, and it is called by the thing
/// happening. The geometry objection is answered the same way: the spotlight is
/// a live anchor, so a control that is not on screen simply has no cut-out.
///
/// So the two are not two tutorials. They are the two halves that note split
/// apart, and each carries exactly the material the other cannot:
///
/// - **The diagram tour** explains the *device* — the furniture, the controls
///   that change meaning between screens (Back **is** the user button on the
///   main menu), the shop, the workshop. None of that can be taught by following
///   a user, because reaching it means driving.
/// - **This** teaches the *loop* — six things the user does with their own
///   thumb. Three of the tour's twelve steps (`screen`, `entry`, `passport`) are
///   about exactly this material, and they are the three that most want doing
///   rather than reading.
///
/// **One entry point, therefore.** SETTINGS > DEVICE keeps one TUTORIAL row and
/// gains no second one. The diagram tour's last step is the hand-off: it has
/// always ended by telling you to go and press something, and now it offers to
/// come with you. The stated cost, in 0.7.6 F1's manner rather than hidden: a
/// player who wants only the live half has to press NEXT to the end of the tour
/// to reach the offer. That is the price of not putting a second tutorial in the
/// menu, and the tour is twelve short pages.
///
/// ## Where §F1 and §G2 disagree, and which wins
///
/// §F1 asks for the first guided action to open LABEL SCAN; §G2's sequence goes
/// through the catalog. They are otherwise the same walkthrough described twice
/// — §F1 by what it achieves, §G1/§G2 by how it looks — so the disagreement has
/// to be settled rather than built twice.
///
/// The catalog path wins, for four reasons:
///
/// 1. LABEL SCAN opens with an **iOS camera-permission dialog** on a fresh
///    install. A guided first action that hands the player a system modal is a
///    guided path into somebody else's UI.
/// 2. It needs a **bottle**. §F1 concedes this itself with its sample-entry
///    fallback; a fallback that fires for most first-launches is the main path.
/// 3. **0.8.9b's A2 made the scan results ask before marking**, on purpose: the
///    results screen heads its lists POSSIBLE GRAPES / POSSIBLE STYLES and means
///    it. So the scan path completes only through a confirm the player has no
///    context for yet.
/// 4. §G2's sequence is the one the spec asks to be *built*, and it reaches the
///    same tried mark with none of the above.
///
/// **§F1's ask is not dropped, and A2's ask is not routed around**, because of
/// how the tried step is written: it advances on `CoachmarkAction.markedTried`,
/// which is *the write landing*, not a particular screen. A player who does have
/// a bottle, opens LABEL SCAN mid-walkthrough and taps the confirm advances the
/// same step by the same rule. The ask is one of two doors onto one action
/// rather than an obstacle in front of one of them — which is the whole of the
/// reconciliation, and it needs no branch in the sequence to express.
///
/// The scanner keeps its billing as the star path by being what the closing line
/// hands you: it is the way you record the *second* wine, once the loop means
/// something.
///
/// ## The sample entry is whichever one they pick
///
/// §F1 asks for "a sample entry" when there is no bottle. There is deliberately
/// no hardcoded id: step two spotlights the **first row of the listing**, so the
/// entry is one the player chose off a screen they navigated to. A pinned id
/// would be a data coupling (`CoverageTests` would have to hold it, and a
/// retired grape would break onboarding), and a wine the player picked is a
/// better first tasting than a wine we picked for them.
public struct CoachmarkStep: Sendable, Hashable, Identifiable {
    public let id: String
    /// What the spotlight cuts out, or nil for a step with nothing to point at.
    public let target: CoachmarkTarget?
    /// What the player must do to move on. See `CoachmarkAction`.
    public let advancesOn: CoachmarkAction
    /// Professor Vino's line. Same rules as `VinoDialogue` — see `problems()`.
    public let line: String
    public let expression: VinoExpression

    /// Whether the sequence can be *restarted* here.
    ///
    /// **This is what makes §G2's "resumable" mean something more than "not
    /// marked complete".** A step is an anchor when its target is reachable from
    /// the main menu without having navigated anywhere first — the menu tile and
    /// the chassis user button qualify; a row inside a listing and a control on
    /// an entry page do not, because resuming onto them would spotlight a
    /// control that is not on screen.
    ///
    /// So quitting at the entry step resumes at the menu step (two taps lost),
    /// and quitting at the passport step resumes exactly there. See
    /// `CoachmarkWalkthrough.resumeIndex(reached:)`.
    public let isAnchor: Bool

    public init(
        id: String,
        target: CoachmarkTarget?,
        advancesOn: CoachmarkAction,
        line: String,
        expression: VinoExpression,
        isAnchor: Bool = false
    ) {
        self.id = id
        self.target = target
        self.advancesOn = advancesOn
        self.line = line
        self.expression = expression
        self.isAnchor = isAnchor
    }

    /// True when the line interpolates the player's name.
    public var usesName: Bool { line.contains(VinoName.placeholder) }

    /// The sentence with the name substituted. One resolution point, as in
    /// `VinoLine.rendered(name:)`.
    public func rendered(name: String? = nil) -> String {
        VinoName.substitute(into: line, name: name)
    }

    public var wordCount: Int {
        line.split(whereSeparator: \.isWhitespace).count
    }
}

// MARK: - Targets

/// What a step can put the spotlight on (0.8.9d, G1).
///
/// **A closed vocabulary rather than a view identity**, because the spotlight is
/// resolved from a SwiftUI anchor preference and the two ends of that have to
/// agree on a name they cannot share a type for: `VinodexUI` applies
/// `.coachmarkTarget(_:)` and `VinodexApp` reads the collected anchors, while
/// the step that asks for it lives here where the tests are.
///
/// A target may be published by **more than one view**, and `passportButton` is
/// the case that needs it: the passport is behind the chassis user button on one
/// screen and behind a row on the next. One id, two providers, at most one of
/// them on screen at a time — which is also why a missing anchor has to be a
/// legal state rather than a failure.
public enum CoachmarkTarget: String, Sendable, CaseIterable, Hashable {
    /// The GRAPES tile on the main menu.
    case menuTile
    /// The first row of a category listing.
    case listingRow
    /// The TRIED pill on an entry page.
    case triedControl
    /// The INSIGHT panel on an entry page.
    case insightPanel
    /// Whatever leads to the passport from where you are standing.
    case passportButton
}

// MARK: - Actions

/// The things that move the walkthrough on (0.8.9d, G1).
///
/// Spec §G1: "advances only when the user performs the action (learn by doing),
/// not a passive slideshow." So these are all things the *player* did, and the
/// engine has no timer, no NEXT and no auto-advance.
public enum CoachmarkAction: String, Sendable, CaseIterable, Hashable {
    case openedCategory
    case openedEntry
    case markedTried
    case openedPassport
    /// Read something and tapped to go on.
    ///
    /// **The one honest exception, and it is declared rather than disguised.**
    /// §G2's sequence contains "watch INSIGHT update", which is not an action —
    /// the thing it asks you to notice has already happened, on the screen, as a
    /// result of the previous step. Dressing that up as a tap on a read-only
    /// panel would be a slideshow step wearing a costume. Two steps use this:
    /// the one that points at the changed panel, and the closing line.
    case acknowledged

    /// How this action reaches `CoachmarkEngine.report(_:)`.
    ///
    /// Declared, not inferred, for `FirstTimeTrigger.Source`'s reason: half the
    /// call sites are in `VinodexUI`, which Linux cannot see, so a route-driven
    /// action is checkable here and an event-driven one is an explicit claim
    /// instead of an omission. `routeActionsAreReachable` walks the route arm.
    public enum Source: Sendable, Equatable {
        /// Produced by arriving somewhere. Verified against `action(for:)`.
        case route
        /// Produced by something happening. The string names the site.
        case event(String)
    }

    public var source: Source {
        switch self {
        case .openedCategory, .openedEntry, .openedPassport: .route
        // Two sites, deliberately: the entry page's TRIED pill and the label
        // reader's confirm. See the type note on why the *write* is the trigger
        // rather than either screen.
        case .markedTried: .event("EntryDetailScreen TRIED pill, LabelReaderView confirm")
        case .acknowledged: .event("CoachmarkOverlay - the bubble's CONTINUE")
        }
    }

    /// What arriving at `route` is worth, if anything.
    ///
    /// **Strict on purpose.** Only the grape listing counts, not any listing,
    /// because the spotlight names GRAPES and the overlay's dim is a hit-test
    /// barrier — nothing else on that screen is pressable while the step is up,
    /// so a permissive arm would only ever fire for a route the player could not
    /// reach. It would also let them into REGIONS or FLAVORS, whose entries have
    /// no TRIED control, and strand the next step.
    ///
    /// The table lives here rather than in `RootView` for the reason
    /// `FirstTimeTrigger.triggers(for:entry:)` gives: that module is the one no
    /// test can see.
    public static func action(for route: DexRoute) -> CoachmarkAction? {
        switch route {
        case .list(let category, _): category == .grapes ? .openedCategory : nil
        case .detail: .openedEntry
        case .passport: .openedPassport
        default: nil
        }
    }
}

// MARK: - The sequence

/// The six steps, and the copy rules they inherit (0.8.9d, G2).
public enum CoachmarkWalkthrough {
    /// §G2's sequence, verbatim: menu, a category, an entry, mark tried, watch
    /// INSIGHT update, open the passport — plus the closing line that hands the
    /// player the scanner.
    public static let steps: [CoachmarkStep] = [
        CoachmarkStep(
            id: "menu",
            target: .menuTile,
            advancesOn: .openedCategory,
            line: "Start here, {name}. Four shelves; press GRAPES and we will go and find you a wine.",
            expression: .smiling,
            // Reachable from the main menu, which is where a resumed run
            // begins. See `CoachmarkStep.isAnchor`.
            isAnchor: true
        ),
        CoachmarkStep(
            id: "listing",
            target: .listingRow,
            advancesOn: .openedEntry,
            line: "Every grape I hold, {name}. Start with Pinot Noir: temperamental, famous, and honest about both.",
            expression: .neutral
        ),
        CoachmarkStep(
            id: "tried",
            target: .triedControl,
            advancesOn: .markedTried,
            // The step §F1 exists for. Also satisfiable from the label reader's
            // confirm - see the file note on why the write is the trigger.
            line: "This is the one that matters. Press TRIED, {name}, and I start paying attention.",
            expression: .thinking
        ),
        CoachmarkStep(
            id: "insight",
            target: .insightPanel,
            advancesOn: .acknowledged,
            // INSIGHT in the panel's own casing, the rule `VinoDialogue` set
            // when `firstInsight` was written against the shipped header.
            line: "There, {name}. INSIGHT reads your shelf back to you, and it deepens with every tasting.",
            expression: .goodjob
        ),
        CoachmarkStep(
            id: "passport",
            target: .passportButton,
            advancesOn: .openedPassport,
            line: "Last one, {name}. Your Passport counts every tasting and hands out stamps for them.",
            expression: .raiseaglass,
            // The chassis user button is on every screen, so a run resumed here
            // has its target under the spotlight immediately.
            isAnchor: true
        ),
        CoachmarkStep(
            id: "done",
            target: nil,
            advancesOn: .acknowledged,
            // Where the scanner gets its billing back. See the file note on
            // §F1: it is the way you record the *second* wine.
            line: "That is the whole loop, {name}. Next bottle, hand me the label and I will read it.",
            expression: .raiseaglass
        ),
    ]

    public static var count: Int { steps.count }

    /// Where a resumed run picks up, given how far it got.
    ///
    /// The last anchor at or before `reached` — see `CoachmarkStep.isAnchor`.
    /// Pure, so the rule is testable without standing up a store.
    public static func resumeIndex(reached: Int) -> Int {
        let clamped = min(max(reached, 0), steps.count - 1)
        for i in stride(from: clamped, through: 0, by: -1) where steps[i].isAnchor {
            return i
        }
        return 0
    }

    // MARK: The gate

    /// Everything wrong with the sequence, or an empty array.
    ///
    /// **The copy rules are `VinoDialogue.problems()`'s**, and they are applied
    /// here rather than inherited by accident: this is Professor Vino talking,
    /// drawn in the same bubble, in the same two fonts with the same partial
    /// Latin-1 coverage, and `RetiredTerms`' own note says widening it to
    /// another authored set "is adding a call to `problems`". Six more strings
    /// with no gate is how the next "the written paper" happens.
    ///
    /// The rules the seventeen have that these do not: the gag budget (a
    /// tutorial is not where the character spends jokes) and the exactly-one
    /// `{name}` rule, relaxed to at-most-one because a step is allowed to be a
    /// pure instruction. The sentence-initial ban is kept in full, because it is
    /// what keeps the lowercase `explorer` fallback grammatical.
    public static func problems() -> [String] {
        var problems: [String] = []

        let ids = Set(steps.map(\.id))
        if ids.count != steps.count { problems.append("two steps share an id") }
        if steps.isEmpty { problems.append("the sequence is empty") }

        for step in steps {
            let where_ = "CoachmarkWalkthrough.\(step.id)"

            if let bad = VinoDialogue.firstNonASCII(in: step.line) {
                problems.append("\(where_): line is not printable ASCII - found \(bad)")
            }
            if step.line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                problems.append("\(where_): line is empty")
            }
            if step.wordCount > VinoDialogue.maxWords {
                problems.append("\(where_): \(step.wordCount) words; the bubble takes \(VinoDialogue.maxWords)")
            }

            let occurrences = step.line.components(separatedBy: VinoName.placeholder).count - 1
            if occurrences > 1 {
                problems.append("\(where_): uses \(VinoName.placeholder) \(occurrences) times; at most once")
            }
            if step.line.hasPrefix(VinoName.placeholder) {
                problems.append(
                    "\(where_): starts with \(VinoName.placeholder); the fallback"
                        + " \"\(VinoName.fallback)\" is lowercase and would open a sentence"
                )
            }

            problems.append(contentsOf: RetiredTerms.problems(in: step.line, where: where_))
        }

        // The sequence has to *end*. A last step waiting on a route action would
        // be unfinishable, because there is nowhere left to navigate to.
        if let last = steps.last, last.advancesOn != .acknowledged {
            problems.append("the last step advances on \(last.advancesOn.rawValue); it can only be acknowledged")
        }
        // And it has to be startable from a cold resume.
        if let first = steps.first, !first.isAnchor {
            problems.append("the first step is not an anchor, so a resumed run has nowhere to land")
        }

        return problems
    }
}

// MARK: - The engine

/// Which step of the walkthrough is up, and what is remembered about it
/// (0.8.9d, G1/G2).
///
/// ## Why the whole of this is in Core
///
/// A coachmark is mostly a hole cut in a grey rectangle, which is `VinodexUI`'s
/// and invisible to Linux. What can be *wrong* is not the hole: it is whether
/// the right action advances the right step, whether skipping loses your place,
/// whether an existing player is ambushed on the launch after updating, and
/// where a resumed run lands. Those live here, where `swift test` can see them.
/// `CoachmarkOverlay` draws `current`, calls `report(_:)` and `skip()`, and
/// decides nothing.
///
/// ## Three flags, and the one that is not here
///
/// - `reached` is the high-water mark, and `resumeIndex` reads it.
/// - `hasBeenOffered` is what stops the sequence auto-starting twice. Skipping
///   sets it and does *not* set completion, which is exactly §G2's "skippable +
///   resumable": the run is put down, not thrown away.
/// - `isComplete` is §G2's persisted completion flag, and it also decides that a
///   re-run of a finished walkthrough starts at the beginning rather than
///   resuming onto its own last step.
///
/// There is deliberately **no seeded flag**, which is the opposite of
/// `FirstTimeTriggerStore`'s decision one sub-batch ago, so the contrast is
/// worth stating. That store needed one because "seeded to empty" and "never
/// seeded" are different states that would otherwise decode identically. Here
/// `seed(hasHistory:)` only ever sets a flag, and only when the answer is yes,
/// so it is idempotent and monotonic: running it on every launch is free and
/// a new player's seed is genuinely a no-op rather than a recorded empty one.
@MainActor
@Observable
public final class CoachmarkEngine {
    public static let shared = CoachmarkEngine()

    public nonisolated static let reachedKey = "coachmarkReached"
    public nonisolated static let offeredKey = "coachmarkOffered"
    public nonisolated static let completedKey = "coachmarkCompleted"

    private let defaults: UserDefaults

    /// The step on screen, or nil when the walkthrough is not running.
    private(set) public var index: Int?
    /// The furthest step ever reached, persisted.
    private(set) public var reached: Int
    /// Whether the sequence has ever been started. See the type note.
    private(set) public var hasBeenOffered: Bool
    /// §G2's completion flag.
    private(set) public var isComplete: Bool

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reached = defaults.integer(forKey: Self.reachedKey)
        hasBeenOffered = defaults.bool(forKey: Self.offeredKey)
        isComplete = defaults.bool(forKey: Self.completedKey)
    }

    // MARK: Reading

    public var isRunning: Bool { index != nil }

    public var current: CoachmarkStep? {
        guard let index, CoachmarkWalkthrough.steps.indices.contains(index) else { return nil }
        return CoachmarkWalkthrough.steps[index]
    }

    /// How far through, for a progress readout: 1-based, or nil when idle.
    public var position: Int? { index.map { $0 + 1 } }

    /// Whether a fresh launch should run this unasked — §F1's "after BIOS".
    ///
    /// The one thing in this batch that happens to a player who did not ask for
    /// it, which is why it is gated on never having been offered *and* on
    /// `seed(hasHistory:)` having had its say first.
    public var shouldAutoStart: Bool { !hasBeenOffered }

    // MARK: Writing

    /// Suppress the auto-start for somebody who is plainly not a new player.
    ///
    /// **The first-run trap, fourth batch running.** 0.8.7's D1, 0.8.8's D1/D2
    /// and 0.8.9c's E1 all shipped a one-shot that fired for things an existing
    /// user had already done; this is the same shape with a bigger blast radius,
    /// because what would fire is not a bubble but a six-step spotlight taking
    /// over the whole screen on the first launch after an update.
    ///
    /// Takes a plain answer rather than the stores, so the decision is testable
    /// on Linux without a database. A genuinely new install passes false, and
    /// nothing is written at all.
    public func seed(hasHistory: Bool) {
        guard hasHistory, !hasBeenOffered else { return }
        hasBeenOffered = true
        persist()
    }

    /// Begin, or pick up where a skipped run left off.
    ///
    /// A finished walkthrough restarts from the top: somebody who has completed
    /// it and asks for it again wants the whole thing, not its last step.
    public func start() {
        hasBeenOffered = true
        index = isComplete ? 0 : CoachmarkWalkthrough.resumeIndex(reached: reached)
        persist()
    }

    /// The player did something. Advances only if it is what this step was
    /// waiting for; anything else is ignored rather than skipped past.
    public func report(_ action: CoachmarkAction) {
        guard let step = current, step.advancesOn == action else { return }
        advance()
    }

    /// Move on unconditionally — the overlay's NEXT button (maintainer ruling,
    /// 0.9.45 test pass). The original design advanced action steps only by
    /// their action, but a step whose target the player cannot reach wedges
    /// the whole run with no exit short of quitting; NEXT trades the purity
    /// for a walkthrough that can always be walked. The step's action is not
    /// reported, so nothing is claimed that did not happen.
    public func advance() {
        guard let index else { return }
        let next = index + 1
        if next >= CoachmarkWalkthrough.count {
            finish()
        } else {
            self.index = next
            reached = max(reached, next)
            persist()
        }
    }

    /// Put it down. Keeps the high-water mark and does **not** complete, which
    /// is what makes §G2's "skippable" and "resumable" the same feature.
    public func skip() {
        index = nil
        persist()
    }

    /// Reached the end.
    public func finish() {
        index = nil
        isComplete = true
        reached = CoachmarkWalkthrough.count - 1
        persist()
    }

    /// Back to a fresh install — CLEAR SAVED DATA's, for the reason every other
    /// one-shot ledger is in `SavedDataReset`: a wipe that left this standing
    /// would open a fresh start with the walkthrough already spent, on the one
    /// run where meeting it is the point.
    public func reset() {
        index = nil
        reached = 0
        hasBeenOffered = false
        isComplete = false
        defaults.removeObject(forKey: Self.reachedKey)
        defaults.removeObject(forKey: Self.offeredKey)
        defaults.removeObject(forKey: Self.completedKey)
    }

    private func persist() {
        defaults.set(reached, forKey: Self.reachedKey)
        defaults.set(hasBeenOffered, forKey: Self.offeredKey)
        defaults.set(isComplete, forKey: Self.completedKey)
    }
}
