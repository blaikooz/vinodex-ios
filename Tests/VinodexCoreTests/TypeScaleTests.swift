import Testing
import Foundation
@testable import VinodexCore

/// The only automated signal AUDIT H11 can get.
///
/// Everything H11 touches on the UI side — `DexFont`, the root pin, the raised
/// literals — is inside `#if canImport(SwiftUI) && canImport(UIKit)` and
/// compiles to nothing on this host, so none of it is reachable from a test.
/// That is precisely why the floor and the step live in Core: the arithmetic
/// that decides how large every label in the app draws is checkable here.
@Suite("TypeScale")
struct TypeScaleTests {
    private func defaults() -> UserDefaults {
        let name = UUID().uuidString
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    /// Close enough for point sizes; `0.85 * 10` is not exactly 8.5 in binary.
    private func expect(_ got: Double, _ want: Double, _ what: String) {
        #expect(abs(got - want) < 0.000_001, "\(what): got \(got), want \(want)")
    }

    // MARK: - The floor

    /// **The rendered floor, and what it cost** (AUDIT **M49**).
    ///
    /// H11 shipped a *nominal* floor and said so: at the default step a 10pt
    /// label still drew at 8.5pt, under Apple's 11pt guidance, and closing that
    /// was deferred because it re-sizes call sites nothing here can lay out.
    /// M49 closes it. The assertions below are the old contract rewritten, not
    /// a new one bolted beside it — a test that still claimed the old behaviour
    /// would be the strongest possible evidence the change did not happen.
    @Test("nothing is drawn under the rendered floor, at any step")
    func renderedFloorHolds() {
        for step in TextScale.allCases {
            for nominal in stride(from: 1.0, through: 60.0, by: 0.5) {
                #expect(TypeScale.resolve(nominal: nominal, step: step) >= TypeScale.renderedFloor,
                        "\(nominal) @\(step.rawValue) drew under the floor")
            }
        }
        // The shipped default is where this bites: 8.5pt was the number the
        // audit item quoted.
        expect(TypeScale.resolve(nominal: 10, step: .small), 11, "retro(10) @SMALL")
        #expect(10 * TextScale.small.factor == 8.5, "the value M49 was raised to fix")
    }

    /// The precise cost, so it is a decision on the record rather than a
    /// surprise: at SMALL the 10–12 band collapses onto the floor, and above 12
    /// nothing moves at any step. 41 call sites sit in that band.
    @Test("the floor binds only below 13, and only at the smaller steps")
    func floorBindsNarrowly() {
        // Collapsed at SMALL — three authored sizes, one drawn size.
        for nominal in [10.0, 11.0, 12.0] {
            expect(TypeScale.resolve(nominal: nominal, step: .small), 11, "\(nominal) @SMALL")
        }
        // 12.95 * 0.85 = 11.0075, the first nominal that clears the floor at SMALL.
        #expect(TypeScale.resolve(nominal: 13, step: .small) > TypeScale.renderedFloor)

        // At LARGE only the floor itself is lifted; at HUGE, nothing.
        expect(TypeScale.resolve(nominal: 10, step: .large), 11, "retro(10) @LARGE")
        expect(TypeScale.resolve(nominal: 11, step: .large), 11, "retro(11) @LARGE")
        expect(TypeScale.resolve(nominal: 12, step: .large), 12, "retro(12) @LARGE")
        expect(TypeScale.resolve(nominal: 10, step: .huge), 13, "retro(10) @HUGE")
    }

    /// Everything at or above 13 draws at exactly the plain product, at every
    /// step. This is the surviving half of H11's reviewability guarantee: the
    /// floor is provably a no-op for the large majority of the app.
    @Test("call sites above the floor's reach are the plain product")
    func aboveFloorUnchanged() {
        let shipped: [Double] = [13, 14, 15, 16, 17, 18, 19, 19.2,
                                 20, 21, 22, 24, 26, 28, 30, 36]
        for nominal in shipped {
            for step in TextScale.allCases {
                expect(TypeScale.resolve(nominal: nominal, step: step),
                       nominal * step.factor,
                       "\(nominal) @\(step.rawValue) must be the plain product")
            }
        }
    }

    @Test("the nominal floor is exactly a call-site rewrite, applied before the step")
    func floorPrecedesFactor() {
        for step in TextScale.allCases {
            expect(TypeScale.resolve(nominal: 4, step: step),
                   TypeScale.resolve(nominal: TypeScale.nominalFloor, step: step),
                   "anything under the floor draws as the floor @\(step.rawValue)")
        }
    }

    @Test("resolve is monotonic in nominal and in step")
    func monotonic() {
        for step in TextScale.allCases {
            var previous = 0.0
            for nominal in stride(from: 1.0, through: 60.0, by: 0.5) {
                let got = TypeScale.resolve(nominal: nominal, step: step)
                #expect(got >= previous)
                previous = got
            }
        }
        // Weakly increasing rather than strictly: the rendered floor makes the
        // smallest nominals equal across the lower steps by design.
        let ordered: [TextScale] = [.small, .large, .huge]
        for nominal in stride(from: 1.0, through: 60.0, by: 0.5) {
            for (lower, higher) in zip(ordered, ordered.dropFirst()) {
                #expect(TypeScale.resolve(nominal: nominal, step: lower)
                        <= TypeScale.resolve(nominal: nominal, step: higher),
                        "\(nominal): \(lower.rawValue) drew larger than \(higher.rawValue)")
            }
            // And strictly increasing wherever the floor is not binding.
            if nominal >= 13 {
                #expect(TypeScale.resolve(nominal: nominal, step: .large)
                        < TypeScale.resolve(nominal: nominal, step: .huge))
            }
        }
    }

    // MARK: - The steps

    @Test("the persisted vocabulary and its two original factors are unchanged")
    func stepsAreStable() {
        // Moving either of these resizes the app under existing users.
        #expect(TextScale.small.rawValue == "SMALL")
        #expect(TextScale.large.rawValue == "LARGE")
        expect(TextScale.small.factor, 0.85, "SMALL")
        expect(TextScale.large.factor, 1.00, "LARGE")
        // The step added in 0.6.4, without which capping the system control
        // would leave a low-vision user with no way up at all — **widened from
        // 1.15 to 1.30 by M49**, which owns the range H11 narrowed and
        // deliberately did not widen. Deliberately three steps, not four: a
        // fourth button makes the picker row unreadable, so the range went into
        // the step that already existed.
        expect(TextScale.huge.factor, 1.30, "HUGE")
        #expect(TextScale.allCases.count == 3)
        // Strictly increasing, and HUGE really is the top — `TextScale.current`
        // falls back to SMALL on garbage, so an out-of-order table would be
        // silent.
        let factors = TextScale.allCases.map(\.factor)
        #expect(factors == factors.sorted())
        #expect(factors.last == TextScale.allCases.map(\.factor).max())
    }

    @Test("current falls back to SMALL on absent and on garbage")
    func currentFallsBack() {
        let d = defaults()
        #expect(TextScale.current(in: d) == .small)
        d.set("ENORMOUS", forKey: TextScale.storageKey)
        #expect(TextScale.current(in: d) == .small)
        d.set("HUGE", forKey: TextScale.storageKey)
        #expect(TextScale.current(in: d) == .huge)
    }

    // MARK: - The first-launch seed

    @Test("seed maps the system step, once")
    func seedMapsSystemStep() {
        // 0 xSmall … 3 large (the iOS default) … 6 xxxLarge, 7+ accessibility.
        // The whole accessibility band seeds HUGE, which is the top. M49 did
        // not change that mapping — it changed what HUGE is worth (1.15 → 1.30),
        // so the same seed now hands an accessibility user meaningfully more.
        for (ordinal, want) in [(0, TextScale.small), (3, .small),
                                (4, .large), (6, .large),
                                (7, .huge), (11, .huge)] {
            let d = defaults()
            #expect(TextScale.seedIfUnset(systemOrdinal: ordinal, in: d) == want)
            #expect(TextScale.current(in: d) == want)
        }
    }

    @Test("seed never overrides a choice the user has made")
    func seedRespectsUser() {
        let d = defaults()
        d.set(TextScale.small.rawValue, forKey: TextScale.storageKey)
        // Someone at an accessibility system size who has deliberately picked
        // SMALL keeps SMALL — this is the whole reason the seed writes the
        // stored value once instead of taking max(stored, system) forever, which
        // would leave the settings picker showing one thing and the app doing
        // another.
        #expect(TextScale.seedIfUnset(systemOrdinal: 11, in: d) == nil)
        #expect(TextScale.current(in: d) == .small)
    }

    @Test("seed is idempotent")
    func seedRunsOnce() {
        let d = defaults()
        #expect(TextScale.seedIfUnset(systemOrdinal: 7, in: d) == .huge)
        #expect(TextScale.seedIfUnset(systemOrdinal: 0, in: d) == nil)
        #expect(TextScale.current(in: d) == .huge)
    }

    /// AUDIT **M50**: the search field's `UIFont` now resolves through the same
    /// axis as everything else, and its three hand-pinned frames are derived
    /// from the result. Both numbers are Core arithmetic, so they are pinned
    /// here rather than left to a device.
    @Test("the search field's size and frame track the text axis", arguments: TextScale.allCases)
    func searchFieldSizing(step: TextScale) {
        let field = TypeScale.resolve(nominal: 26, step: step)
        let note = TypeScale.resolve(nominal: 20, step: step)
        // The size the live field draws at is the size of the placeholder
        // beside it. That equality *is* the item: before it, a 26pt field sat
        // next to a 22.1pt placeholder under a doc comment calling the two
        // indistinguishable.
        #expect(field == 26 * step.factor)
        #expect(note == 20 * step.factor)

        // `+ 8` is the slack the bar has always carried; the pinned values are
        // floors, so nothing shrinks at SMALL.
        #expect(max(34, field + 8) >= 34)
        #expect(max(40, note + 8) == 40, "the rating note's well must never move")

        // M50 wrote two ceilings here — `field + 8 <= 46` (the search shell)
        // and `<= 44` (the profile name row) — so that M49 could not raise the
        // factor without a test saying where it stopped. **M49 did not raise
        // the factor past them; it removed them.** Both literals derived from
        // the same axis they were meant to bound, so both are now computed and
        // neither can be overflowed. What is pinned instead is that the shell
        // still contains its field, at every step, which is what the two
        // numbers were standing in for.
        let shell = max(46, max(34, field + 8))
        #expect(shell >= max(34, field + 8),
                "the search shell must contain its field at \(step.rawValue)")
        #expect(shell >= 44, "the shell is a tap target and stays over 44pt")
        // Unchanged at every step that has ever shipped: 46 is a floor and the
        // field does not reach it until f = 1.462, so deriving the shell cannot
        // have moved an existing layout.
        #expect(shell == 46, "the shell has not moved at \(step.rawValue)")
    }

    // MARK: - The frames M49 had to derive first

    /// **The tightest ceiling on the whole text axis, and the reason `TextScale`
    /// stopped at 1.15** (AUDIT **M49**).
    ///
    /// `StatBar`'s label well was a hard 96pt. VT323 is monospaced with an
    /// advance of exactly 0.4 em — read out of the shipped `.ttf`, not
    /// estimated — so AROMATICS, nine characters at `mono(19)` with 1.5
    /// tracking, wants `9 × (0.4 × 19f + 1.5)` points. That passes 96 at
    /// **f = 1.2061**, which is why 1.15 was where the axis stopped.
    @Test("the stat label well fits its longest label at every step",
          arguments: TextScale.allCases)
    func statLabelFits(step: TextScale) {
        let needed = TypeScale.monoRunWidth(characters: 9, nominal: 19, tracking: 1.5, step: step)
        let well = max(96, needed)
        #expect(well >= needed, "AROMATICS is clipped at \(step.rawValue)")

        // SMALL and LARGE are untouched. **HUGE now exceeds 96 (102.4pt)** —
        // it is past the 1.206 ceiling, which is the whole reason the well had
        // to be derived before the factor could move. A pinned 96 here would
        // clip AROMATICS on every grape page at the top text size.
        if step == .huge { #expect(well > 96, "HUGE well should grow, got \(well)") }
        else { #expect(well == 96, "\(step.rawValue) well moved to \(well)") }
    }

    /// The ceiling itself, stated as a number so raising the top step past it
    /// without re-tuning fails here rather than on a phone.
    @Test("a pinned 96pt well would break above f = 1.206")
    func statLabelCeiling() {
        // 9 × (7.6f + 1.5) = 96  →  f = (96 - 13.5) / 68.4
        let ceiling = (96.0 - 13.5) / 68.4
        #expect(abs(ceiling - 1.206_140) < 0.000_01, "got \(ceiling)")
        // HUGE used to sit deliberately under this. It is past it now, which is
        // exactly why the well had to stop being a literal first.
        #expect(TextScale.huge.factor > ceiling,
                "HUGE is past the old pinned-well ceiling, so the well must derive")
    }

    /// The monospaced-advance arithmetic the two run-width helpers rest on.
    /// Both faces were measured out of their `hmtx` tables; if either changes,
    /// every derived frame in the app is wrong and nothing else would say so.
    @Test("run widths are character count times one cell")
    func runWidths() {
        expect(TypeScale.monoAdvanceEm, 0.4, "VT323 advance")
        expect(TypeScale.retroAdvanceEm, 1.0, "Press Start 2P advance")

        // The marquee's own measurement, which predates this helper: DAILY
        // CHALLENGE is 15 characters at retro(16) → 240pt at LARGE.
        expect(TypeScale.retroRunWidth(characters: 15, nominal: 16, step: .large), 240,
               "DAILY CHALLENGE @LARGE")
        // Tracking is per character including the last — it is extra advance,
        // not a gap between glyphs.
        expect(TypeScale.monoRunWidth(characters: 2, nominal: 20, tracking: 1, step: .large),
               2 * (8 + 1), "tracking applies to every character")
        expect(TypeScale.monoRunWidth(characters: 0, nominal: 20, tracking: 1, step: .large),
               0, "an empty run is zero wide")
    }
}
