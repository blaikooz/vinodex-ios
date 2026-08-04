import Testing
import Foundation
@testable import VinodexCore

/// The marquee's launch/idle script (0.7.1, B1–B3).
///
/// The reason this suite exists at all is that the thing it covers used to be
/// untestable. The greeting was a `Task.sleep` loop inside a SwiftUI view, in a
/// module that does not compile on Linux — so "does the panel say the right
/// thing at the right time" could only ever be answered by looking at a phone.
/// B1–B3 add two dwells, a once-per-launch rule and an activity reset on top of
/// that, which is four rules too many to check by eye. The policy moved to Core
/// so this file could exist; the view keeps only the clock.
@Suite("Marquee script")
struct MarqueeScriptTests {

    @Test("B1: a fresh launch opens on the greeting")
    func launchesOnWelcome() {
        let script = MarqueeScript()
        #expect(script.stage == .welcome)
        #expect(script.stage.text == "WELCOME!")
        #expect(!script.greeted)
    }

    @Test("B2/B3: the ladder is welcome, then menu, then rest at cheers")
    func theLadderRunsOnce() {
        var script = MarqueeScript()

        // Hoisted out of `#expect`: the macro captures its operand in a
        // closure, so a `mutating` call cannot go inside one.
        let toMenu = script.timedOut()
        #expect(toMenu)
        #expect(script.stage == .menu)
        #expect(script.stage.text == "MENU")

        let toCheers = script.timedOut()
        #expect(toCheers)
        #expect(script.stage == .cheers)
        #expect(script.stage.text == "CHEERS!")

        // CHEERS! is a resting state: nothing but activity leaves it, so a
        // spurious timeout must be a no-op rather than wrapping round to
        // WELCOME! and re-greeting a user mid-session.
        let atRest = script.timedOut()
        #expect(!atRest)
        #expect(script.stage == .cheers)
    }

    @Test("the dwells are the two the spec gives")
    func dwellsAreSpecified() {
        #expect(MarqueeStage.welcome.timeout?.then == .menu)
        #expect(MarqueeStage.menu.timeout?.then == .cheers)
        #expect(MarqueeStage.cheers.timeout == nil)
        // B3 names ten seconds. Pinned because it is a number a later tidy-up
        // could plausibly "round" — it is an idle threshold, and shortening it
        // changes the panel under a user who is still reading the menu.
        #expect(MarqueeStage.menu.timeout?.after == 10)
        // The greeting is a beat, not a dwell: everything behind it is waiting.
        #expect((MarqueeStage.welcome.timeout?.after ?? 0) < 4)
    }

    @Test("activity sends the idle greeting back to MENU and restarts the dwell")
    func activityResets() {
        var script = MarqueeScript(stage: .cheers, greeted: true)

        let woke = script.noteActivity()
        #expect(woke)
        #expect(script.stage == .menu)
        // The dwell is read off the stage, so returning to MENU *is* restarting
        // the ten seconds. Asserted rather than assumed: it is the whole reason
        // the timeout lives on the enum instead of in a stored deadline.
        #expect(script.pendingTimeout?.then == .cheers)
    }

    /// The common case, and the one that would be most annoying if it were
    /// wrong: a finger landing on an already-resting MENU must not report a
    /// change, or every tap kicks off a 1.4-second dissolve of MENU into MENU.
    @Test("activity on MENU reports no change")
    func activityOnMenuIsQuiet() {
        var script = MarqueeScript(stage: .menu, greeted: true)
        let moved = script.noteActivity()
        #expect(!moved)
        #expect(script.stage == .menu)
    }

    @Test("B1: the greeting is once per launch, not once per visit")
    func welcomeIsConsumed() {
        // Tapped during the greeting.
        var tapped = MarqueeScript()
        tapped.noteActivity()
        #expect(tapped.greeted)
        #expect(tapped.stage == .menu)

        // Navigated away during the greeting.
        var left = MarqueeScript()
        left.leftMainScreen()
        #expect(left.greeted)
        #expect(left.stage == .menu)

        // And it stays consumed: neither route back to the main screen can
        // return the script to WELCOME!, because nothing sets it.
        left.noteActivity()
        #expect(left.stage == .menu)
    }

    // MARK: A8 — the idle toast rotates through languages (0.7.2)

    @Test("A8: the first idle of a launch is still CHEERS!")
    func firstIdleIsCheers() {
        var script = MarqueeScript()
        script.timedOut()   // welcome -> menu
        script.timedOut()   // menu -> cheers
        #expect(script.stage == .cheers)
        #expect(script.text == "CHEERS!")
        #expect(script.idleCount == 0)
    }

    @Test("A8: each idle period brings the next language")
    func idlesRotate() {
        var script = MarqueeScript()
        var seen: [String] = []

        // Five idle periods, each ended by a tap, which is the shape of the
        // interaction A8 describes: drift into a toast, come back, drift again.
        for _ in 0..<5 {
            script.timedOut()          // -> menu (or a no-op once already there)
            while script.stage != .cheers { script.timedOut() }
            seen.append(script.text)
            script.noteActivity()      // ends the idle period
        }

        #expect(seen == ["CHEERS!", "SANTE!", "SALUD!", "CIN CIN!", "PROST!"])
        // Every one different is the whole point — a rotation that repeated
        // itself would be indistinguishable from the bug it replaces.
        #expect(Set(seen).count == seen.count)
    }

    @Test("A8: navigating away also ends the idle period")
    func leavingRotates() {
        var script = MarqueeScript(stage: .cheers, greeted: true)
        script.leftMainScreen()
        #expect(script.idleCount == 1)
        #expect(script.stage == .menu)

        // ...but only from CHEERS!. Leaving the main screen while the panel is
        // naming the menu has not consumed a toast, and counting it would burn
        // through the languages during ordinary navigation.
        var browsing = MarqueeScript(stage: .menu, greeted: true)
        browsing.leftMainScreen()
        #expect(browsing.idleCount == 0)
    }

    @Test("A8: activity during the greeting does not consume a toast")
    func welcomeDoesNotRotate() {
        var script = MarqueeScript()
        #expect(script.stage == .welcome)
        script.noteActivity()
        #expect(script.idleCount == 0)
    }

    @Test("A8: the rotation wraps forever")
    func rotationWraps() {
        let all = MarqueeCheers.all
        #expect(MarqueeCheers.toast(at: 0) == all[0])
        #expect(MarqueeCheers.toast(at: all.count) == all[0])
        #expect(MarqueeCheers.toast(at: all.count * 7 + 2) == all[2])
        // Floored rather than trapped: `toast` takes an Int because its caller
        // is a counter, and a negative must not be a crash.
        #expect(MarqueeCheers.toast(at: -3) == all[0])
    }

    @Test("A8: every toast is panel-safe")
    func toastsArePanelSafe() {
        // The same three rules `stagesAreLabelled` applies to the stage labels,
        // and the reason SANTE and SAUDE are spelled without their accents:
        // Press Start 2P has a partial Latin-1 range, so an accented character
        // would be a blank box on the device's most prominent panel.
        for toast in MarqueeCheers.all {
            #expect(!toast.isEmpty)
            let isASCII = toast.allSatisfy(\.isASCII)
            #expect(isASCII, "\(toast)")
            #expect(toast == toast.uppercased(), "\(toast)")
            #expect(toast.count <= 14, "\(toast)")
        }
        // No duplicates, or an idle period would silently repeat its neighbour.
        #expect(Set(MarqueeCheers.all).count == MarqueeCheers.all.count)
        // The stage's own label and the first toast are the same string by
        // construction. Pinned because they are read from two different places
        // — `MarqueeStage.text` and `MarqueeScript.text` — and a panel that
        // said one thing on arrival and another a frame later would be a
        // flicker nobody could explain.
        #expect(MarqueeStage.cheers.text == MarqueeCheers.all[0])
    }

    @Test("every stage has text, and it is panel-safe")
    func stagesAreLabelled() {
        for stage in MarqueeStage.allCases {
            #expect(!stage.text.isEmpty)
            // ASCII only. The bundled Press Start 2P has a partial Latin-1
            // range and a missing glyph on the device's most prominent panel is
            // worse than a missing accent — the same rule the retired toasts
            // followed by spelling SANTE without its accent.
            // Hoisted: `#expect` rewrites a call it can see into
            // `__checkFunctionCall`, which loses the `rethrows` proof that
            // `allSatisfy(\.isASCII)` cannot throw.
            let isASCII = stage.text.allSatisfy(\.isASCII)
            #expect(isASCII, "\(stage.rawValue)")
            #expect(stage.text == stage.text.uppercased(), "\(stage.rawValue)")
            // Fits the panel without leaning on `minimumScaleFactor`.
            #expect(stage.text.count <= 14, "\(stage.rawValue)")
        }
    }
}

/// The marquee drawer's pinned shortcuts (0.7.1, B5).
@Suite("Quick pins")
struct QuickPinTests {

    /// Suite-scoped defaults, so the cases cannot see each other's writes —
    /// the pattern `ToolsTests`' stamp-layout suite already uses.
    private func makeDefaults() -> UserDefaults {
        let suite = UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("could not make a test suite")
        }
        return defaults
    }

    @MainActor
    @Test("a fresh install has no pins")
    func startsEmpty() {
        let store = QuickPinStore(defaults: makeDefaults())
        #expect(store.pins.isEmpty)
        #expect(!store.isFull)
        for section in SettingsSection.allCases {
            #expect(!store.isPinned(section))
        }
    }

    @MainActor
    @Test("pins survive a relaunch, in order")
    func pinsPersist() {
        let defaults = makeDefaults()
        let store = QuickPinStore(defaults: defaults)
        #expect(store.toggle(.data))
        #expect(store.toggle(.access))

        let reloaded = QuickPinStore(defaults: defaults)
        #expect(reloaded.pins == [.data, .access])
        #expect(reloaded.isFull)
    }

    @MainActor
    @Test("toggling a pinned section unpins it")
    func toggleIsSymmetric() {
        let defaults = makeDefaults()
        let store = QuickPinStore(defaults: defaults)
        store.toggle(.settings)
        #expect(store.isPinned(.settings))
        #expect(!store.toggle(.settings))
        #expect(store.pins.isEmpty)
        // The key goes with the last pin, so "empty" and "never set" are one
        // state — see the note on `persist()`.
        #expect(defaults.string(forKey: QuickPinStore.storageKey) == nil)
    }

    /// B5's cap. A third pin evicts the oldest rather than being refused —
    /// see `toggle(_:)` on why.
    @MainActor
    @Test("a third pin pushes the oldest out")
    func capacityIsTwo() {
        let store = QuickPinStore(defaults: makeDefaults())
        store.toggle(.customization)
        store.toggle(.settings)
        store.toggle(.data)
        #expect(store.pins == [.settings, .data])
        #expect(store.pins.count == QuickPinStore.capacity)
    }

    /// Everything a stored string can be wrong about, in one case. None of
    /// these should be able to produce a `pins` that breaks the invariant.
    @MainActor
    @Test("a hostile stored value cannot break the invariant")
    func decodeIsDefensive() {
        #expect(QuickPinStore.decode("") == [])
        #expect(QuickPinStore.decode("NOPE,ALSO NOPE") == [])
        #expect(QuickPinStore.decode("DATA,DATA") == [.data])
        #expect(QuickPinStore.decode("DATA,NOPE,ACCESS") == [.data, .access])
        // Over the cap: truncated, not rejected — a user with three stored
        // pins should lose the extra, not all of them.
        #expect(QuickPinStore.decode("DATA,ACCESS,SETTINGS").count == QuickPinStore.capacity)
    }

    @MainActor
    @Test("reset clears everything")
    func resetClears() {
        let defaults = makeDefaults()
        let store = QuickPinStore(defaults: defaults)
        store.toggle(.data)
        store.reset()
        #expect(store.pins.isEmpty)
        #expect(QuickPinStore(defaults: defaults).pins.isEmpty)
    }
}
