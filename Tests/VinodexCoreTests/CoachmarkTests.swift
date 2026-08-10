import Testing
import Foundation
@testable import VinodexCore

/// **The onboarding walkthrough** (0.8.9d, F1/G1/G2).
///
/// A coachmark is mostly a hole cut in a grey rectangle, which Linux cannot see.
/// Everything here is the half that can be *wrong*: which action advances which
/// step, whether skipping loses your place, where a resumed run lands, and
/// whether an existing player is ambushed on the launch after updating.
@MainActor
@Suite("Coachmark walkthrough")
struct CoachmarkTests {
    private func makeEngine() -> CoachmarkEngine {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return CoachmarkEngine(defaults: defaults)
    }

    // MARK: The copy

    @Test("the walkthrough copy satisfies the same rules his bubbles do")
    func copyIsClean() {
        let problems = CoachmarkWalkthrough.problems()
        #expect(problems.isEmpty, "\n  \(problems.joined(separator: "\n  "))")
    }

    /// §G2 names the sequence: "menu -> open a category -> open an entry ->
    /// mark tried / scan -> watch insight update -> open Passport". Pinned as
    /// ids, because the *order* is the feature — an entry step before a listing
    /// step would spotlight a control on a screen the player has not reached.
    @Test("the sequence is the one the spec asks for, in order")
    func sequenceIsSpecOrder() {
        #expect(
            CoachmarkWalkthrough.steps.map(\.id)
                == ["menu", "listing", "tried", "insight", "passport", "done"]
        )
    }

    /// The mirror of `VinoDialogueTests.routeTriggersAreReachable`, and here for
    /// the same reason: `VinodexApp` is invisible to these tests, so a step
    /// waiting on a route action nothing produces would be a walkthrough that
    /// stops dead with no failure anywhere.
    @Test("every route-driven action is produced by some route")
    func routeActionsAreReachable() {
        let routes: [DexRoute] = [
            .list(category: .grapes, filter: nil),
            .list(category: .styles, filter: nil),
            .detail(entryID: "GRAPE_TEST"),
            .passport,
            .bookmarks,
            .settings,
        ]
        let produced = Set(routes.compactMap { CoachmarkAction.action(for: $0) })

        for action in CoachmarkAction.allCases where action.source == .route {
            #expect(produced.contains(action), "\(action.rawValue) claims to be route-driven but no route produces it")
        }
        // And every step's action has to be reachable *somehow* — either from a
        // route above, or by an event whose site is named.
        for step in CoachmarkWalkthrough.steps {
            let reachable = produced.contains(step.advancesOn) || step.advancesOn.source != .route
            #expect(reachable, "step \(step.id) waits on \(step.advancesOn.rawValue), which nothing produces")
        }
    }

    /// Strict on purpose — see `CoachmarkAction.action(for:)`. A permissive arm
    /// would let the player into REGIONS or FLAVORS, whose entries carry no
    /// TRIED control, and strand the next step.
    @Test("only the grape listing counts as opening a category")
    func onlyGrapesAdvanceTheMenuStep() {
        #expect(CoachmarkAction.action(for: .list(category: .grapes, filter: nil)) == .openedCategory)
        #expect(CoachmarkAction.action(for: .list(category: .regions, filter: nil)) == nil)
        #expect(CoachmarkAction.action(for: .list(category: .flavors, filter: nil)) == nil)
        #expect(CoachmarkAction.action(for: .list(category: .styles, filter: nil)) == nil)
    }

    // MARK: Advancement

    @Test("a step advances on its own action and ignores every other")
    func advancesOnlyOnItsOwnAction() {
        let engine = makeEngine()
        engine.start()
        #expect(engine.current?.id == "menu")

        // Everything the sequence *will* ask for later, arriving early.
        engine.report(.markedTried)
        engine.report(.openedPassport)
        engine.report(.acknowledged)
        #expect(engine.current?.id == "menu", "an unrelated action moved the walkthrough on")

        engine.report(.openedCategory)
        #expect(engine.current?.id == "listing")
    }

    @Test("running the whole sequence finishes it")
    func fullRunCompletes() {
        let engine = makeEngine()
        engine.start()
        for step in CoachmarkWalkthrough.steps {
            #expect(engine.current?.id == step.id)
            engine.report(step.advancesOn)
        }
        #expect(engine.isRunning == false)
        #expect(engine.isComplete)
    }

    /// §G1: "advances only when the user performs the action (learn by doing),
    /// not a passive slideshow." Which means every step must be satisfiable by
    /// something the player can actually do — and the last one must be
    /// satisfiable without navigating, because there is nowhere left to go.
    @Test("the sequence can be finished, and only the last step ends it")
    func onlyTheEndEnds() {
        #expect(CoachmarkWalkthrough.steps.last?.advancesOn == .acknowledged)
        #expect(CoachmarkWalkthrough.steps.first?.isAnchor == true)
        // Two acknowledged steps: the INSIGHT readout and the closing line. Any
        // more and the thing is drifting back towards a slideshow.
        let passive = CoachmarkWalkthrough.steps.filter { $0.advancesOn == .acknowledged }
        #expect(passive.count == 2, "\(passive.count) steps advance on a button; \(passive.map(\.id))")
    }

    // MARK: Skip and resume

    /// §G2's "skippable + resumable" are one feature: skipping puts the run
    /// down rather than throwing it away.
    @Test("skipping keeps the place and does not complete")
    func skipIsResumable() {
        let engine = makeEngine()
        engine.start()
        engine.report(.openedCategory)
        engine.report(.openedEntry)
        #expect(engine.current?.id == "tried")

        engine.skip()
        #expect(engine.isRunning == false)
        #expect(engine.isComplete == false)
        #expect(engine.reached == 2)

        // Resumes at the last anchor at or before where it stopped. The tried
        // step's control is on an entry page the player is no longer on, so
        // landing there would spotlight nothing.
        engine.start()
        #expect(engine.current?.id == "menu")
    }

    @Test("a run stopped on an anchor resumes exactly there")
    func anchorResumesInPlace() {
        let engine = makeEngine()
        engine.start()
        for action in [CoachmarkAction.openedCategory, .openedEntry, .markedTried, .acknowledged] {
            engine.report(action)
        }
        #expect(engine.current?.id == "passport")
        engine.skip()
        engine.start()
        #expect(engine.current?.id == "passport")
    }

    @Test("resumeIndex never lands on a step whose target needs navigating to")
    func resumeAlwaysLandsOnAnAnchor() {
        for reached in 0..<CoachmarkWalkthrough.count {
            let index = CoachmarkWalkthrough.resumeIndex(reached: reached)
            #expect(index <= reached)
            #expect(CoachmarkWalkthrough.steps[index].isAnchor, "resumed onto \(CoachmarkWalkthrough.steps[index].id)")
        }
        // Out-of-range input is clamped rather than trapped: `reached` is read
        // off disk and a downgrade could hand this a larger number than the
        // sequence has steps.
        #expect(CoachmarkWalkthrough.resumeIndex(reached: 99) < CoachmarkWalkthrough.count)
        #expect(CoachmarkWalkthrough.resumeIndex(reached: -3) == 0)
    }

    @Test("a completed walkthrough re-runs from the beginning")
    func rerunStartsOver() {
        let engine = makeEngine()
        engine.start()
        for step in CoachmarkWalkthrough.steps { engine.report(step.advancesOn) }
        #expect(engine.isComplete)

        engine.start()
        #expect(engine.current?.id == "menu", "a re-run resumed onto its own last step")
    }

    @Test("the flags survive a relaunch")
    func flagsPersist() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let first = CoachmarkEngine(defaults: defaults)
        first.start()
        first.report(.openedCategory)
        first.skip()

        let second = CoachmarkEngine(defaults: defaults)
        #expect(second.reached == 1)
        #expect(second.hasBeenOffered)
        #expect(second.isComplete == false)
        #expect(second.shouldAutoStart == false, "a skipped run would be forced on the player again next launch")
    }

    // MARK: The first-run trap, fourth batch running

    @Test("a fresh install runs the guided first find unasked")
    func newInstallAutoStarts() {
        let engine = makeEngine()
        engine.seed(hasHistory: false)
        #expect(engine.shouldAutoStart, "spec F1's after-BIOS walkthrough never fires on a new device")
    }

    /// 0.8.7 D1, 0.8.8 D1/D2 and 0.8.9c E1 all shipped a one-shot that fired for
    /// things an existing player had already done. This is the same shape with a
    /// bigger blast radius — a six-step spotlight over the whole screen on the
    /// first launch after an update.
    @Test("somebody with history is not ambushed on the launch after updating")
    func historySuppressesTheAutoStart() {
        let engine = makeEngine()
        engine.seed(hasHistory: true)
        #expect(engine.shouldAutoStart == false)
        // And it does not pretend they completed it: asking for the tutorial
        // still gives them the whole thing.
        #expect(engine.isComplete == false)
        engine.start()
        #expect(engine.current?.id == "menu")
    }

    /// The contrast with `FirstTimeTriggerStore`, which needed a seeded flag
    /// because "seeded to empty" and "never seeded" decode identically. This
    /// seed only ever sets, and only on a yes, so it is safe to run every launch
    /// — including after the player has already been through the walkthrough.
    @Test("seeding is idempotent and never un-offers")
    func seedIsMonotonic() {
        let engine = makeEngine()
        engine.start()
        engine.report(.openedCategory)
        engine.seed(hasHistory: false)
        #expect(engine.hasBeenOffered)
        #expect(engine.reached == 1)
        engine.seed(hasHistory: true)
        #expect(engine.reached == 1)
    }

    @Test("CLEAR SAVED DATA gives the walkthrough back")
    func resetRestoresIt() {
        let engine = makeEngine()
        engine.start()
        for step in CoachmarkWalkthrough.steps { engine.report(step.advancesOn) }
        engine.reset()
        #expect(engine.shouldAutoStart)
        #expect(engine.isComplete == false)
        #expect(engine.reached == 0)
    }
}

/// **What Phase 3 changed about Professor Vino himself** (0.8.9d).
@MainActor
@Suite("Professor Vino, phase 3")
struct VinoPhaseThreeTests {
    private func makeStore() -> FirstTimeTriggerStore {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return FirstTimeTriggerStore(defaults: defaults)
    }

    /// 0.8.9c shipped both launch lines gated on "Phase 3 owns the capture
    /// field". `VinoIntroCard` is that field, so the gate comes off — and the
    /// deferral field being a declared reason rather than a comment is what
    /// makes this checkable at all.
    @Test("the two launch lines are live now that there is a field to answer in")
    func launchLinesAreLive() {
        #expect(VinoDialogue.line(for: .firstLaunch)?.isDeferred == false)
        #expect(VinoDialogue.line(for: .firstLaunchNamed)?.isDeferred == false)

        let store = makeStore()
        #expect(store.fireOnce(.firstLaunch) != nil)
        #expect(store.fireOnce(.firstLaunchNamed) != nil)
    }

    /// The skipped-name path, which `firstLaunchNamed` was written to survive:
    /// its line carries the division of labour every later line assumes, so it
    /// fires on skip too, with the fallback substituted.
    @Test("a skipped name still reads as a sentence")
    func skippedNameReads() {
        let line = VinoDialogue.line(for: .firstLaunchNamed)
        #expect(line?.usesName == true)
        let rendered = line?.rendered(name: nil) ?? ""
        #expect(rendered.contains(VinoName.fallback))
        #expect(!rendered.contains(VinoName.placeholder))
        // Whitespace-only is a skip, not a name.
        #expect(line?.rendered(name: "   ").contains(VinoName.fallback) == true)
    }

    /// The switch 0.8.9c declined to ship without a call site. It is a filter,
    /// not a consumption: silencing him must not spend the keys, or turning him
    /// back on would leave a player with a character who has nothing left to say.
    @Test("silence withholds the line without burning the key")
    func silenceIsAFilter() {
        let store = makeStore()
        store.setSilenced(true)
        #expect(store.fireOnce(.firstGrapeViewed) == nil)
        #expect(store.hasFired(.firstGrapeViewed) == false)

        store.setSilenced(false)
        #expect(store.fireOnce(.firstGrapeViewed) != nil)
        #expect(store.hasFired(.firstGrapeViewed))
    }

    @Test("the silence preference survives a relaunch and a wipe undoes it")
    func silencePersists() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        FirstTimeTriggerStore(defaults: defaults).setSilenced(true)
        let reloaded = FirstTimeTriggerStore(defaults: defaults)
        #expect(reloaded.isSilenced)
        reloaded.reset()
        #expect(reloaded.isSilenced == false)
        #expect(FirstTimeTriggerStore(defaults: defaults).isSilenced == false)
    }

    /// The spotlight is the third writer to the suspension set and the first
    /// that also reads it — it holds the queue while it runs, and must itself
    /// stand down for the rating prompt its own spotlit TRIED tap raises.
    @Test("a host can tell its own hold from everybody else's")
    func suspensionReadsBothWays() {
        let presenter = VinoPresenter()
        presenter.setSuspended(true, by: "coachmark")
        #expect(presenter.isSuspended)
        #expect(presenter.isSuspended(otherThan: "coachmark") == false)

        presenter.setSuspended(true, by: "entry")
        #expect(presenter.isSuspended(otherThan: "coachmark"))

        presenter.setSuspended(false, by: "entry")
        #expect(presenter.isSuspended(otherThan: "coachmark") == false)
        #expect(presenter.isSuspended, "clearing one host's hold released another's")
    }
}

/// The tour, now that it hands off to the walkthrough (0.8.9d, G2).
@Suite("The guided tour after the hand-off")
struct WalkthroughHandoffTests {
    /// `RetiredTerms`' own note says widening it to another authored set "is
    /// adding a call to `problems`". The tour is the third set, and it is the
    /// one with form: 0.8.8's D2 found it naming a tool that is not on the shelf
    /// while omitting one that is, which is the same class of drift by a
    /// different route.
    @Test("no tour step uses a word the app has retired")
    func tourAvoidsRetiredTerms() {
        for step in Walkthrough.steps {
            let problems = RetiredTerms.problems(in: step.body, where: "Walkthrough.\(step.id)")
                + RetiredTerms.problems(in: step.title, where: "Walkthrough.\(step.id) title")
            #expect(problems.isEmpty, "\n  \(problems.joined(separator: "\n  "))")
        }
    }

    /// The last step is the only hand-off, so it has to *be* the last step and
    /// it has to mention the thing it is offering. A tour that silently stopped
    /// naming SHOW ME would leave the button unexplained and the guided run
    /// unreachable for anyone who had already skipped it once.
    @Test("the last step offers the guided run")
    func lastStepOffersTheGuidedRun() {
        let last = Walkthrough.steps.last
        #expect(last?.id == "done")
        #expect(last?.body.contains("SHOW ME") == true)
    }
}
