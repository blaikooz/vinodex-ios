import Testing
import Foundation
@testable import VinodexCore

/// The boot POST (0.7.3, A1).
@Suite("Boot sequence")
struct BootSequenceTests {
    /// **"Keep it brief" as an assertion rather than a promise.** A boot
    /// animation is a tax on every launch forever, and the moment somebody adds
    /// a fourth line "since we are here" is the moment it stops being brief.
    @Test("the whole POST is under two seconds")
    func brief() {
        #expect(BootSequence.duration < 2.0)
        let lines = BootSequence.lines(entries: 405, version: "0.7.3")
        for line in lines {
            #expect(line.at < BootSequence.duration, "\(line.id) lands after the sequence ends")
        }
        let last = lines.map(\.at).max() ?? 0
        #expect(
            last + BootSequence.settle <= BootSequence.duration,
            "the last line has no time to be read before the cut"
        )
    }

    /// A1 names three things the POST must show.
    @Test("the POST checks memory, the database and the firmware")
    func spec() {
        let lines = BootSequence.lines(entries: 405, version: "0.7.3")
        let ids = lines.map(\.id)
        #expect(ids.contains("mem"))
        #expect(ids.contains("db"))
        #expect(ids.contains("fw"))
    }

    /// The database line reports the catalog's real size — a boot screen that
    /// invented one would be the quiet lie `AppVersion` spends forty lines on.
    @Test("the database line reports the real entry count")
    func realCount() throws {
        let lines = BootSequence.lines(entries: 405, version: "0.7.3")
        let db = try #require(lines.first { $0.id == "db" })
        #expect(db.result.contains("405"))

        // Zero is a legitimate answer: a build whose data failed to decode still
        // boots, and saying so on the way in is better diagnostics than the app
        // has anywhere else.
        let empty = BootSequence.lines(entries: 0, version: "0.7.3")
        let emptyDB = try #require(empty.first { $0.id == "db" })
        #expect(emptyDB.result == "NO DATA")
    }

    /// A1 reads F3 — the version on the boot screen is the catalog's, not a
    /// literal typed into a view.
    @Test("the firmware line and header carry the version given")
    func versionFromF3() throws {
        let lines = BootSequence.lines(entries: 405, version: AppVersion.current)
        let fw = try #require(lines.first { $0.id == "fw" })
        #expect(fw.result == "v" + AppVersion.current)
        #expect(fw.result == AppVersion.display)
        #expect(BootSequence.header(version: AppVersion.current).contains(AppVersion.current))
    }

    /// Lines arrive in time order, whether or not the verbose egg is on — the
    /// view reveals them by index and would otherwise print them out of order.
    @Test("lines are ordered by time in both modes")
    func ordered() {
        for verbose in [false, true] {
            let lines = BootSequence.lines(entries: 405, version: "0.7.3", verbose: verbose)
            let times = lines.map(\.at)
            #expect(times == times.sorted(), "verbose=\(verbose): lines are out of order")
            #expect(Set(lines.map(\.id)).count == lines.count, "verbose=\(verbose): duplicate line id")
        }
    }

    /// The MAINFRAME code has to actually change something — a cheat that
    /// reports success and does nothing is the one failure a cheat console
    /// cannot survive.
    @Test("the verbose egg adds lines and still fits")
    func verboseEgg() {
        let plain = BootSequence.lines(entries: 405, version: "0.7.3")
        let verbose = BootSequence.lines(entries: 405, version: "0.7.3", verbose: true)
        #expect(verbose.count > plain.count)
        for line in verbose {
            #expect(line.at < BootSequence.duration, "\(line.id) overruns the sequence")
        }
    }

    /// Uppercase ASCII: the boot screen is set in the retro face, which has a
    /// partial Latin-1 range.
    @Test("every line is uppercase ASCII")
    func printable() {
        for line in BootSequence.lines(entries: 405, version: "0.7.3", verbose: true) {
            for text in [line.label, line.result] {
                // Hoisted out of `#expect`: `allSatisfy` is `rethrows`, and the
                // macro expands a `rethrows` call into something the compiler
                // treats as throwing — see the same note in `AppVersionTests`.
                let ascii = text.allSatisfy(\.isASCII)
                #expect(ascii, "\(line.id): \(text) is not ASCII")
                // The version carries a lowercase `v` by design — that is
                // `AppVersion.display`'s prefix and it is lowercase everywhere
                // in the app.
                let body = text.replacingOccurrences(of: "v", with: "")
                #expect(body == body.uppercased(), "\(line.id): \(text) is not uppercase")
            }
        }
    }
}

/// The unattended tour (0.7.3, A2).
@Suite("Demo mode")
struct DemoModeTests {
    /// A2 names four screens explicitly. They lead, in its order.
    @Test("the four named screens lead the tour")
    func namedScreensLead() {
        let leading = DemoTour.stops.prefix(4).map(\.route)
        #expect(leading[0] == .scanner)
        #expect(leading[1] == .globe)
        #expect(leading[2] == .list(category: .grapes, filter: nil))
        #expect(leading[3] == .passport)
    }

    /// "And the other tools" — every tool route the app has should be on the
    /// loop, or the demo is showing a subset of the device for no stated reason.
    @Test("every tool is on the loop")
    func everyToolAppears() {
        let tools: [DexRoute] = [
            .scanner, .labelReader, .wsetQuiz, .dailyChallenge,
            .dailyGrape, .moonDial, .chipFilter,
        ]
        let visited = Set(DemoTour.stops.map(\.route))
        for tool in tools {
            #expect(visited.contains(tool), "\(tool.title) is not on the demo loop")
        }
    }

    /// No stop appears twice: a loop that shows the globe at position two and
    /// again at position seven reads as a stuck cycle rather than a tour.
    @Test("no stop repeats")
    func noRepeats() {
        let routes = DemoTour.stops.map(\.route)
        #expect(Set(routes).count == routes.count)
    }

    /// Every dwell is long enough to read and short enough to hold attention.
    /// A stop under two seconds is a flash; one over ten is a stall.
    @Test("dwells are legible from arm's length")
    func dwellsAreSane() {
        #expect(!DemoTour.stops.isEmpty)
        for stop in DemoTour.stops {
            #expect(stop.dwell >= 2.0, "\(stop.caption) is a flash at \(stop.dwell)s")
            #expect(stop.dwell <= 10.0, "\(stop.caption) stalls at \(stop.dwell)s")
        }
    }

    /// A full pass has to be short enough that a passer-by sees the loop repeat
    /// rather than assuming the device is stuck on one screen.
    @Test("one cycle is about a minute")
    func cycleLength() {
        #expect(DemoTour.cycle > 30)
        #expect(DemoTour.cycle < 90)
    }

    /// The index wraps forever and floors at zero — the driver is a counter that
    /// only goes up.
    @Test("stops wrap")
    func wrapping() {
        let count = DemoTour.stops.count
        #expect(DemoTour.stop(at: 0) == DemoTour.stops[0])
        #expect(DemoTour.stop(at: count) == DemoTour.stops[0])
        #expect(DemoTour.stop(at: count * 3 + 2) == DemoTour.stops[2])
        #expect(DemoTour.stop(at: -7) == DemoTour.stops[0])
    }

    /// A stop is captioned by the route's own title, so the marquee and the
    /// screen can never disagree about where the demo is.
    @Test("captions come from the routes")
    func captionsFollowRoutes() {
        for stop in DemoTour.stops {
            #expect(stop.caption == stop.route.title)
            #expect(!stop.caption.isEmpty)
        }
    }
}

/// The unlock console (0.7.3, A4).
@MainActor
@Suite("Cheat codes")
struct CheatCodeTests {
    private func makeStore() -> AccessStore {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AccessStore(defaults: defaults)
    }

    @Test("an exact code matches")
    func exactMatch() throws {
        let code = try #require(CheatCodes.match("CELLARDOOR"))
        #expect(code.grants == .skins)
    }

    /// **Forgiving on purpose.** Someone typing a code on a phone keyboard gets
    /// autocapitalisation and a trailing space from the space bar; rejecting
    /// that makes the console feel broken rather than strict.
    @Test("matching survives a phone keyboard")
    func forgivingMatch() {
        for typed in ["cellardoor", " CELLARDOOR ", "Cellar Door", "cellar-door", "CELLAR  DOOR"] {
            #expect(CheatCodes.match(typed)?.code == "CELLARDOOR", "\(typed) did not match")
        }
    }

    /// What is *not* forgiven is a wrong word. There is no fuzzy matching:
    /// "did you mean" on a secret is not a secret.
    @Test("a wrong code does not match")
    func rejectsWrongCodes() {
        for typed in ["", "   ", "CELLAR", "CELLARDOORS", "GRANDCRUX", "hunter2"] {
            #expect(CheatCodes.match(typed) == nil, "\(typed) should not have matched")
        }
    }

    /// Codes have to be distinct after normalisation, or one of them is
    /// unreachable and nothing says which.
    @Test("codes are unique and well-formed")
    func codesAreDistinct() {
        let normalized = CheatCodes.all.map { CheatCodes.normalize($0.code) }
        #expect(Set(normalized).count == CheatCodes.all.count)
        for code in CheatCodes.all {
            #expect(code.code == code.code.uppercased())
            // Hoisted for the `rethrows` reason above.
            let plainLetters = code.code.allSatisfy { $0.isASCII && $0.isLetter }
            #expect(plainLetters)
            #expect(code.code.count >= 6, "\(code.code) is short enough to be typed by accident")
            #expect(!code.reveal.isEmpty)
            #expect(code.reveal == code.reveal.uppercased())
        }
    }

    /// **F1's whole point.** A cheat writes to the same store a purchase does,
    /// so the skin picker cannot end up with two notions of whether the bundle
    /// is owned.
    @Test("a code grants through the entitlement store")
    func grantsThroughTheStore() throws {
        let store = makeStore()
        store.starterOnly = true
        #expect(!store.isUnlocked(.skins))

        let code = try #require(CheatCodes.match("cellardoor"))
        store.grant(code.grants)

        #expect(store.isUnlocked(.skins))
        #expect(store.granted.contains(.skins))
    }

    /// And it survives a relaunch, because it went through the persisted set
    /// rather than a session flag.
    @Test("an unlocked code persists")
    func persists() throws {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let first = AccessStore(defaults: defaults)
        let code = try #require(CheatCodes.match("MAINFRAME"))
        first.grant(code.grants)

        let second = AccessStore(defaults: defaults)
        #expect(second.hasFound(CheatCodes.verboseBoot))
    }

    /// An easter egg is *found*, not owned: `isUnlocked` answers true for
    /// everything when the paywall is off, which would mean every hidden feature
    /// is on by default and the console has nothing to reveal.
    @Test("eggs ignore the free-tier switch")
    func eggsBypassThePaywall() {
        let store = makeStore()
        #expect(store.starterOnly == false)
        #expect(store.isUnlocked(.easterEgg(CheatCodes.verboseBoot)), "the paywall is off, so nothing is gated")
        #expect(!store.hasFound(CheatCodes.verboseBoot), "but it has not been found")

        store.grant(.easterEgg(CheatCodes.verboseBoot))
        #expect(store.hasFound(CheatCodes.verboseBoot))
    }

    /// The MAINFRAME code names the egg the boot screen checks for. Two string
    /// literals at opposite ends of that would be granted, persisted, and
    /// silently inert.
    @Test("the verbose egg id is shared with the boot screen")
    func verboseEggIsWired() throws {
        let code = try #require(CheatCodes.all.first { $0.code == "MAINFRAME" })
        #expect(code.grants == .easterEgg(CheatCodes.verboseBoot))
    }
}

/// The bouncing mark (0.7.3, A5).
@Suite("Screensaver bounce")
struct ScreensaverBounceTests {
    let bounds = (width: 320.0, height: 480.0)
    let mark = (width: 64.0, height: 64.0)

    /// **The property that matters.** A simulation drifts; this is a closed
    /// form, so the mark is inside its box at t = 0 and still inside it two
    /// hours later.
    @Test("the mark never leaves the LCD")
    func staysInside() {
        for step in stride(from: 0.0, through: 7200.0, by: 0.37) {
            let p = ScreensaverBounce.origin(at: step, bounds: bounds, mark: mark)
            #expect(p.x >= 0 && p.x <= bounds.width - mark.width, "x=\(p.x) at t=\(step)")
            #expect(p.y >= 0 && p.y <= bounds.height - mark.height, "y=\(p.y) at t=\(step)")
        }
    }

    /// It starts in the corner and moves off it — a screensaver that appears
    /// already mid-flight has no beginning.
    @Test("it starts at the origin and moves")
    func startsAndMoves() {
        let start = ScreensaverBounce.origin(at: 0, bounds: bounds, mark: mark)
        #expect(start.x == 0)
        #expect(start.y == 0)
        let later = ScreensaverBounce.origin(at: 1, bounds: bounds, mark: mark)
        #expect(later.x > 0)
        #expect(later.y > 0)
    }

    /// The fold is a triangle wave: up to the span, back to zero, forever.
    @Test("the fold reflects")
    func foldReflects() {
        let span = 100.0
        #expect(ScreensaverBounce.fold(0, span: span) == 0)
        #expect(ScreensaverBounce.fold(50, span: span) == 50)
        #expect(ScreensaverBounce.fold(100, span: span) == 100)
        #expect(ScreensaverBounce.fold(150, span: span) == 50)
        #expect(ScreensaverBounce.fold(200, span: span) == 0)
        #expect(ScreensaverBounce.fold(250, span: span) == 50)
    }

    /// A box with no travel — a mark as large as its container — must not divide
    /// by zero. This is not hypothetical: the LCD is measured at runtime and is
    /// zero-sized on the first layout pass.
    @Test("a degenerate box is survivable")
    func degenerateBox() {
        let p = ScreensaverBounce.origin(at: 12, bounds: (width: 64, height: 64), mark: mark)
        #expect(p.x == 0)
        #expect(p.y == 0)
        let zero = ScreensaverBounce.origin(at: 12, bounds: (width: 0, height: 0), mark: mark)
        #expect(zero.x == 0)
        #expect(zero.y == 0)
        #expect(ScreensaverBounce.bounces(by: 12, bounds: (width: 0, height: 0), mark: mark) == 0)
    }

    /// The axes move at different speeds, so the path does not collapse into a
    /// short diagonal loop that repeats every few seconds.
    @Test("the axes are not in lockstep")
    func axesDiffer() {
        #expect(ScreensaverBounce.velocity.x != ScreensaverBounce.velocity.y)
    }

    /// The bounce count only ever grows — it drives the colour, and a colour
    /// that went backwards would flicker.
    @Test("bounces accumulate monotonically")
    func bouncesGrow() {
        var last = 0
        for step in stride(from: 0.0, through: 600.0, by: 0.5) {
            let count = ScreensaverBounce.bounces(by: step, bounds: bounds, mark: mark)
            #expect(count >= last, "bounce count fell at t=\(step)")
            last = count
        }
        #expect(last > 0, "nothing ever bounced")
    }

    /// Negative time is clamped rather than trusted.
    @Test("negative time is clamped to the start")
    func clampsNegativeTime() {
        let p = ScreensaverBounce.origin(at: -30, bounds: bounds, mark: mark)
        #expect(p.x == 0)
        #expect(p.y == 0)
    }
}
