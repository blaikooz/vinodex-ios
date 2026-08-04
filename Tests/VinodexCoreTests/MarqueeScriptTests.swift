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
        // **The greeting rides the shared schedule, whatever shape it is in**
        // (0.7.6, A4). This was pinned at the literal 10 through 0.7.5, which
        // was B3's figure; A4 folds the pre-idle toast into the screensaver, so
        // the number is 30 today. Pinned against `IdleSchedule.cheers` rather
        // than against a fresh literal, because what must never drift is that
        // the panel and the screensaver agree — the exact reconciliation
        // 0.7.3's F2 was written for. `IdleTimerTests` pins the value itself.
        #expect(MarqueeStage.menu.timeout?.after == IdleSchedule.cheers)
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

/// The marquee's two lamp buttons (0.7.1 B5; rebuilt 0.7.6, A1).
///
/// The store is the one piece of A1 a Linux gate can see: the lamps themselves,
/// the hold gesture and the chooser are all `VinodexUI`. What is here is what
/// would be silently wrong — the migration off the old two-of-five pin set, the
/// invariant that a lamp is never empty, and the swap rule.
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

    /// **The migration assertion, and the most important one here.** A lamp
    /// cannot be empty — it is a moulded part of the shell — so a fresh install
    /// resolves to the pair the lamps were hardwired to before A1 made them
    /// assignable. Anyone upgrading from 0.7.5 gets exactly the device they had.
    @MainActor
    @Test("a fresh install has the factory pair")
    func startsAtDefaults() {
        let store = QuickPinStore(defaults: makeDefaults())
        #expect(store.pins == QuickPinStore.defaults)
        #expect(store.pins == [.tools, .customization])
        #expect(store.pins.count == QuickPinStore.capacity)
    }

    /// The other half of the migration: the vocabulary widened, and every raw
    /// value that could previously be on disk still means what it meant. `DEV`
    /// is the one `SettingsSection` with no counterpart, and it is the one the
    /// chooser has never offered.
    @MainActor
    @Test("every storable settings section is still a pin")
    func vocabularyIsASuperset() {
        for section in SettingsSection.allCases where section != .dev {
            #expect(
                MarqueePin(rawValue: section.rawValue) != nil,
                "\(section.rawValue) was storable and no longer decodes"
            )
        }
        #expect(MarqueePin(rawValue: SettingsSection.dev.rawValue) == nil)
        // And the widening itself: TOOLS is the entry `SettingsSection` cannot
        // express, which is why the type exists at all.
        #expect(MarqueePin.tools.section == nil)
        #expect(MarqueePin.tools.route == .minigames)
    }

    @MainActor
    @Test("assignments survive a relaunch, in slot order")
    func pinsPersist() {
        let defaults = makeDefaults()
        let store = QuickPinStore(defaults: defaults)
        #expect(store.assign(.data, to: 0))
        #expect(store.assign(.access, to: 1))

        let reloaded = QuickPinStore(defaults: defaults)
        #expect(reloaded.pins == [.data, .access])
        #expect(reloaded.pin(at: 0) == .data)
        #expect(reloaded.pin(at: 1) == .access)
    }

    /// **The swap rule.** Assigning a destination the other lamp holds trades
    /// the two rather than duplicating it — a device with two identical buttons
    /// is not a choice anybody made, and refusing would make the user clear the
    /// other lamp first and come back.
    @MainActor
    @Test("assigning a pin the other lamp holds swaps them")
    func assigningSwaps() {
        let store = QuickPinStore(defaults: makeDefaults())
        #expect(store.pins == [.tools, .customization])
        store.assign(.customization, to: 0)
        #expect(store.pins == [.customization, .tools])
        // Repeating it puts them back, which is what makes the rule reversible.
        store.assign(.tools, to: 0)
        #expect(store.pins == [.tools, .customization])
    }

    @MainActor
    @Test("assigning what a lamp already holds changes nothing")
    func assigningIsIdempotent() {
        let store = QuickPinStore(defaults: makeDefaults())
        #expect(!store.assign(.tools, to: 0))
        #expect(store.pins == [.tools, .customization])
        // And a slot that does not exist is refused rather than trapped.
        #expect(!store.assign(.data, to: 7))
        #expect(store.pins.count == QuickPinStore.capacity)
    }

    /// The factory pair is stored as *absence*, so "as it ships" and "never
    /// touched" are one state — the rule `DeviceBuild` and `StampLayoutStore`
    /// follow, and what keeps `SavedDataReset` from having to know about two.
    @MainActor
    @Test("the default pair leaves no key behind")
    func defaultsAreStoredAsAbsence() {
        let defaults = makeDefaults()
        let store = QuickPinStore(defaults: defaults)
        #expect(defaults.string(forKey: QuickPinStore.storageKey) == nil)
        store.assign(.data, to: 0)
        #expect(defaults.string(forKey: QuickPinStore.storageKey) != nil)
        store.reset()
        #expect(store.pins == QuickPinStore.defaults)
        #expect(defaults.string(forKey: QuickPinStore.storageKey) == nil)
    }

    /// Everything a stored string can be wrong about, in one case. None of
    /// these may produce a list that is short, long or repeated — the lamps are
    /// drawn from it by index.
    @MainActor
    @Test("a hostile stored value cannot break the invariant")
    func decodeIsDefensive() {
        // Nothing stored, or nothing recognisable: the factory pair.
        #expect(QuickPinStore.decode("") == QuickPinStore.defaults)
        #expect(QuickPinStore.decode("NOPE,ALSO NOPE") == QuickPinStore.defaults)
        // One real pin from an older install keeps its slot; the other fills
        // from the first unused default.
        #expect(QuickPinStore.decode("SETTINGS") == [.settings, .tools])
        #expect(QuickPinStore.decode("CUSTOMIZE") == [.customization, .tools])
        // Two real pins are untouched — nobody's choice is reset by A1.
        #expect(QuickPinStore.decode("DATA,ACCESS") == [.data, .access])
        // Duplicates collapse and then pad, so the two lamps are never the same.
        #expect(QuickPinStore.decode("DATA,DATA") == [.data, .tools])
        // The retired 0.7.5 section drops out, exactly as it did before.
        #expect(QuickPinStore.decode("PACKS,DATA") == [.data, .tools])
        // Over the cap: truncated, not rejected.
        #expect(QuickPinStore.decode("DATA,ACCESS,SETTINGS") == [.data, .access])

        // The invariant itself, over everything above and then some.
        for raw in ["", "  ", ",,,", "DEV", "TOOLS,TOOLS,TOOLS", "ACCESS,DEV"] {
            let pins = QuickPinStore.decode(raw)
            #expect(pins.count == QuickPinStore.capacity, "\(raw) gave \(pins)")
            #expect(Set(pins).count == pins.count, "\(raw) repeated a pin")
        }
    }

    /// A pin's label, glyph and destination all come from the thing it names,
    /// so a lamp can never wear one destination's mark and land on another —
    /// the rule `DexRoute.marqueeSymbol`'s K2 audit wrote for the whole app.
    @MainActor
    @Test("every pin is labelled, glyphed and routed")
    func pinsAreWellFormed() {
        var glyphs: Set<String> = []
        for pin in MarqueePin.allCases {
            #expect(!pin.displayName.isEmpty)
            #expect(!pin.symbol.isEmpty)
            #expect(pin.symbol == pin.route.marqueeSymbol, "\(pin) wears a glyph its route does not")
            #expect(pin.displayName == pin.route.title, "\(pin) is labelled unlike its route")
            glyphs.insert(pin.symbol)
        }
        #expect(glyphs.count == MarqueePin.allCases.count, "two lamps could look identical")
        // ACCESS reads as SHOP without this type knowing about the 0.7.5 rename.
        #expect(MarqueePin.access.displayName == "SHOP")
    }
}
