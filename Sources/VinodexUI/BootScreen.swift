#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// MARK: - Ink

/// The BIOS screen's palette (0.7.7, A).
///
/// **The one screen in this app that does not take its colours from `LcdMode`,
/// and the reason is in the fiction.** Every themed surface here reads an
/// `lcd.*` token — the house rule since 0.6.2, and why `GrapeSpriteLoader`
/// recolours the rarity leaf in code rather than shipping twenty variants. This
/// screen breaks it deliberately: a BIOS runs *before* the system that knows
/// what the user chose. Twenty-one colourways are a preference the firmware has
/// not loaded yet, and a boot screen that already knew your phosphor would be
/// the one part of the metaphor that gave the game away. It is also what the
/// spec asks for — three fixed colours, named by role.
///
/// The roles are load-bearing and B2 states them: **cream is the system talking
/// about itself**, **gold is telemetry** — the things the screen measures rather
/// than asserts — and **magenta is the frame and the prompts**, the machine
/// addressing the user. Every colour choice below is one of those three, and a
/// fourth would mean the roles had stopped meaning anything.
private enum BiosInk {
    /// Near-black, warm. Not `.black`: a true black next to cream reads as a
    /// hole rather than as an unlit phosphor, and the warmth is what makes the
    /// magenta sit on it rather than glow off it.
    static let background = Color(dexHex: "#0E0A0E")
    /// Rules, side rails, brackets, prompts.
    static let magenta = Color(dexHex: "#B0417A")
    /// The mark's drop shadow, and the only place a second magenta is allowed —
    /// it is the same ink in shadow, exactly as `ScreensaverMark`'s dimmed
    /// layer is.
    static let magentaDeep = Color(dexHex: "#7A2E52")
    /// The logo and everything the system says about itself.
    static let cream = Color(dexHex: "#F2E8D5")
    /// Telemetry: the copyright, the tagline, the battery, the signal, and the
    /// `OK`.
    static let gold = Color(dexHex: "#E6A93A")
}

// MARK: - Screen

/// The BIOS screen (0.7.7) — the app's power-on self test, redesigned.
///
/// **Supersedes 0.7.3a's A1 and 0.7.5's A6 wholesale.** Those built a POST as a
/// left-aligned table of check lines inside the LCD, and 0.7.7's spec is
/// explicit that it replaces them rather than extending them. Almost nothing
/// below survives from either; what survives is `BootSequence`, which was always
/// the half worth keeping — the lines, their order and their timing are modelled
/// in Core where a test can hold them, and that is exactly as true of the new
/// two-phase shape as it was of the old one.
///
/// **Inside the LCD, framed by the chassis (0.7.8, A4)** — which puts back what
/// 0.7.3a had and 0.7.7 took away one batch ago.
///
/// The argument 0.7.7 made was sound and it is the reason this composition
/// changed rather than moved: an inset BIOS carrying *its own* terminal border,
/// side rails and corner brackets, sitting inside the plastic one, is a bezel
/// inside a bezel. A4 agrees with that diagnosis and reverses the prescription.
/// The device already owns a frame — a chamfered panel, a stone band, a white
/// bezel and a vent strip, all of it drawn to look like a screen surround — so
/// the right thing to delete was the drawn one. `BiosFrame` is gone entirely:
/// no border, no rails, no brackets. What encloses the terminal is the machine
/// the terminal is running on.
///
/// That also settles 0.7.3a's original objection, which 0.7.7 answered by
/// covering the chassis. The objection was that a **translucent overlay dimming**
/// the bezel, island and footer reads as the device losing power at the one
/// moment it is doing the opposite. This screen is opaque and it is not an
/// overlay: it is what the display is showing, so the chassis around it is lit
/// and normal rather than dimmed. A handheld with a boot screen on its screen is
/// a handheld booting.
///
/// Everything else 0.7.7 built is untouched — the three zones, the palette, the
/// scanlines, the tinted logo masks, the derived title. The type scale is
/// re-derived for the narrower region (see the block below), the scanlines are
/// pitch-locked to the display's own, and the advance gesture is reasoned out
/// again from scratch in `BootAdvanceCatcher` rather than carried over.
///
/// **Two phases, one composition** (C1). The frame, both status bars and the
/// identity stack are on screen from the first frame. What changes is one slot
/// under the wine glass: it runs `BootSequence`'s check lines, and when they
/// resolve it becomes `SYSTEM CHECK... OK` and the prompt. The slot is a `ZStack`
/// of fixed height with the two states cross-fading inside it, so *nothing
/// moves* — the mockup is the resting state of this screen rather than a second
/// screen it cuts to, which is what C1 asks for and what a layout that reflowed
/// on completion would not have delivered.
///
/// **It cannot trap anyone** (C2). Any touch anywhere advances — a tap, a drag,
/// a touch that lands during the checks — and if none arrives the screen answers
/// its own prompt after `BootSequence.autoAdvance`. `BootSequenceTests.neverTraps`
/// pins both ends.
public struct BootScreen: View {
    /// Called when the BIOS finishes or is skipped.
    let onFinish: () -> Void

    /// How many check lines have been revealed.
    @State private var shown = 0
    /// True once the checks have resolved and the screen is at rest.
    @State private var settled = false
    /// The prompt's slow pulse.
    @State private var pulsing = false
    /// The battery, read once when the screen appears (D1). Seeded through the
    /// unavailable path rather than with a literal `100%`, so the state before
    /// the first reading is the same state a device that cannot report one ends
    /// in, and there is one definition of "unknown".
    @State private var battery = BiosChrome.battery(level: -1)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lines: [BootLine]
    private let title: String

    // MARK: Type scale
    //
    // Nominal sizes — `DexFont` puts every one of them through `TextScale`, so
    // these are the numbers at SETTINGS > TEXT SIZE = default and all of them
    // can be a third larger on a real device. That is why every label below
    // carries `lineLimit(1)` and a `minimumScaleFactor`: this screen is a fixed
    // composition, and the failure at the top of the text range has to be a
    // slightly smaller line rather than a wrapped one that breaks the frame.
    //
    // `PressStart2P` (the `retro` face) advances a full em, so a string's width
    // is its character count times its size — which is what sets the two status
    // bars.
    //
    // **Re-derived for the LCD (0.7.8, A4), and the first thing the re-derivation
    // found was an error in the numbers it replaces.** The block here used to
    // read "at 8pt it is 192 of the ~357 a 393pt phone offers inside the rails".
    // Both halves were wrong. `DexFont.retro` routes through
    // `TypeScale.resolve`, which applies `nominalFloor` (10) *before* the step
    // factor, so `retro(8)` has never rendered at 8pt — it renders at
    // `max(10, 8) x factor`, i.e. **8.5pt at the shipped default** and 11.5 at
    // HUGE. This is the same trap `BackPlateStampView`'s title note records.
    //
    // So the real 0.7.7 top bar was 24 x 8.5 = 204 for the copyright plus
    // 19 x 8.5 = 161.5 for the title plus 14 of gap — **379.5pt against 353**
    // (393 less two 20pt content insets; "~357" double-counted the rule). It has
    // been riding `minimumScaleFactor` at the default text step since it
    // shipped, which is exactly what 0.7.5's A6 note forbids: "the scale factor
    // is there for the narrower phones and the larger steps, not to absorb a
    // size that never fitted."
    //
    // **The budget inside the LCD.** On a 393pt phone the display's content box
    // is 393 less `screenPanelInset` (8) each side, less
    // `bezelInsetH - bezelFrame` (8) each side, less `bezelFrame` (4) each side
    // = **353pt** — the same number the full-viewport version had, because the
    // chassis's own surround costs what that version spent on `contentInset`.
    // A 12pt content inset inside it leaves **329pt**, and 12 is enough that
    // nothing lands under the display's 28pt corner clip (at 12pt in, the clip
    // has already reached within 5pt of the top edge).
    //
    // Everything on the screen clears 329 at the default step except the top
    // bar, which cannot: 43 characters of retro face need 7.65pt each and the
    // nominal floor is 10. So **the top bar is two lines now** — the title over
    // the copyright, same strings, same colours, same roles. Each is then 204
    // and 161.5 at the default and 276 and 218.5 at HUGE, both comfortably
    // inside 329 at every step. That is the one change the smaller region
    // forced, and it is a layout change rather than a smaller size, per A6.
    //
    // ---
    //
    // **B5 (0.8.0) takes the composition up a register, and the budget above is
    // what decides how far.** "Slightly larger" is a request about points, and on
    // this screen points are bounded by a width nobody may exceed: 329pt at the
    // *worst* text step, which is HUGE (1.15). `PressStart2P` advances a full em,
    // so a retro string's ceiling is `329 / characters / 1.15` and there is no
    // arguing with it — `minimumScaleFactor` absorbing the overflow is exactly
    // what 0.7.5's A6 forbids ("the scale factor is there for the narrower phones
    // and the larger steps, not to absorb a size that never fitted").
    //
    // Worked through, longest string first:
    //
    //   prompt      28 chars   ceiling 10.2  — **already there**, see below
    //   tagline     26 chars   ceiling 11.0  — 8 -> 11
    //   copyright   21 chars   ceiling 13.6  — 8 -> 11 (shares `barSize`)
    //   title       19 chars   ceiling 15.0  — 8 -> 11 (shares `barSize`)
    //   wordmark     7 chars   ceiling 38.9  — 28 -> 32 (7.36 em with the shear)
    //   terminal    40 chars   VT323, 0.4 em — 22 -> 25
    //
    // Everything without words in it moves with them, at the same ~15%: the mark,
    // the stack's spacing, the divider, the glass, the hex badge and the two
    // corner glyphs. Those are in `BiosMetrics` and beside their own drawings.
    //
    // **The prompt is the one member that cannot grow, and it is worth stating
    // rather than leaving as an oversight.** PRESS ANY BUTTON TO CONTINUE is 28
    // characters, which puts its ceiling at 10.2 nominal — and `promptSize` is 9,
    // which `TypeScale.nominalFloor` already lifts to 10 before the step factor.
    // It is *rendering* at its ceiling today. Any larger number here would be a
    // string that overflows at HUGE and rides its scale factor to fit, which is
    // the fault A6 names. So B5 reaches every element on this screen except the
    // one that was already as large as it can legally be.

    /// The two top-bar labels, and the bottom bar's readouts.
    ///
    /// 11 since 0.8.0 (B5), from 8 — and the jump is larger than it looks
    /// because `TypeScale.nominalFloor` is 10, so 8 and 10 render identically and
    /// 11 is the first number above `barSize` that changes anything at all. It
    /// resolves to 9.35pt at the shipped default and 12.65 at HUGE, where the
    /// 21-character copyright is 265.7 of the 329 available.
    private static let barSize: CGFloat = 11
    /// The wordmark. The largest type in the app, and the reason the identity
    /// stack reads as a logo rather than as a heading.
    private static let wordmarkSize: CGFloat = 32
    /// The tagline, 26 characters wide — **the tightest string on the screen**
    /// after the prompt. At 11 it is 26 x 12.65 = 328.9 of 329 at HUGE: inside
    /// the budget without touching its scale factor, and 12 would not be.
    private static let taglineSize: CGFloat = 11
    /// The prompt, 28 characters wide — the widest retro string on the screen,
    /// and the one that hits its scale factor first. **Deliberately not moved by
    /// B5**; see the ceiling arithmetic above.
    private static let promptSize: CGFloat = 9
    /// The terminal voice: the check lines and the status line they resolve
    /// into. `VT323` advances about 0.4em, so 25pt buys a 40-character line in
    /// 460pt of nominal width — far past what the slot holds, which is why this
    /// is the one string B5 could raise freely. 22 through 0.7.9.
    private static let terminalSize: CGFloat = 25
    /// The mark's drawn height, as a ceiling. Its width follows the art's own
    /// aspect.
    ///
    /// **A ceiling rather than a fixed height since 0.7.8 (A4).** Horizontally
    /// the LCD turned out to offer what the viewport did; vertically it plainly
    /// does not — the display is the window less the island strip, less the
    /// whole footer, less four bands of bezel — and unlike the width there is no
    /// single number to derive it from, because the footer's height follows
    /// `UIScale` and the device. So the mark is the member that gives: it is the
    /// one element here with no text in it, so shrinking it costs legibility
    /// nothing, and it is the element a shorter screen should spend first.
    /// `markFloor` is where it stops being a logo and starts being a bullet.
    ///
    /// 106/46 since 0.8.0 (B5), from 92/40 — the same ~15% the type took, so the
    /// mark keeps its share of the composition rather than becoming the one
    /// element that stayed still. `markCeiling` clamps to the first and floors at
    /// the second, so a short display still gives this up before it gives up a
    /// word, which is the order 0.7.8's A4 chose and B5 does not change.
    private static let markHeight: CGFloat = 106
    private static let markFloor: CGFloat = 46
    /// The gap between members of the identity stack.
    private static let identitySpacing: CGFloat = 16
    /// The drawn divider's band, and the wine glass's.
    private static let dividerHeight: CGFloat = 14
    private static let glassSize: CGFloat = 30

    public init(entries: Int, verbose: Bool, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        self.lines = BootSequence.lines(
            entries: entries,
            version: AppVersion.current,
            verbose: verbose
        )
        // C3 over the mockup. See `BiosChrome`'s doc comment for why this is the
        // one string in the spec that had to be disobeyed.
        self.title = BootSequence.header(version: AppVersion.current)
    }

    public var body: some View {
        // **No `ignoresSafeArea` anywhere in this view any more** (0.7.8, A4).
        // It is mounted as the display's content, so its bounds are the LCD's
        // and the display is already wholly inside the safe area — the chassis
        // reserves the island strip above it and the home indicator sits on
        // bare chassis below. An escape hatch out of an inset that no longer
        // applies would just have pushed the composition under the clip.
        GeometryReader { geo in
            ZStack {
                BiosInk.background
                BiosVignette(diagonal: hypot(geo.size.width, geo.size.height))

                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 8)
                    identity(markCeiling: markCeiling(in: geo.size.height))
                    Spacer(minLength: 8)
                    bottomBar
                }
                .padding(BiosMetrics.contentInset)

                // Over the content — a scanline that stopped short would read as
                // a texture on the background rather than as the raster.
                BiosScanlines()
            }
        }
        .task { await run() }
        .onAppear(perform: readBattery)
        // The screen is one thing. Announcing it as a unit stops VoiceOver
        // reading a half-drawn table line by line as it fills, and the label
        // changes when the screen is waiting for the user, because at that point
        // "starting up" is no longer what is happening.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(settled ? "Vinodex. \(BiosChrome.prompt)" : "Starting up")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onFinish() }
    }

    // MARK: Top bar

    /// **Two lines since 0.7.8 (A4)**, for the arithmetic in the type-scale
    /// block above: 43 characters of a full-em face do not fit in 329pt at any
    /// step, and the nominal floor means there is no smaller size to ask for.
    ///
    /// The pair keeps everything that carried meaning — the title is cream
    /// because it is the system naming itself, the copyright is gold because it
    /// is telemetry, and the version in it is still `BootSequence.header`'s
    /// rather than the mockup's `1.0.0` (C3, and `BiosChromeTests`). Only the
    /// axis they are separated on changed, from horizontal to vertical.
    ///
    /// **Both lines are centred since 0.8.0 (B3/B4), and that is a consequence of
    /// A4 rather than a fresh preference.** Leading/trailing was the memory of a
    /// horizontal bar: two labels at opposite ends of one rule, which is a real
    /// composition. Stacked vertically it stopped being one — a left-flush line
    /// over a right-flush line reads as two fragments of a table, and there is no
    /// column edge anywhere else on this screen for either of them to align to.
    /// Everything below them — the mark, the wordmark, the divider, the tagline,
    /// the glass, the prompt — is centred on the same axis, so this is the top bar
    /// joining the composition it sits on top of.
    ///
    /// The roles are untouched: still cream over gold, still two claims rather
    /// than one, and B1's HORIZON/GODOT is what makes them genuinely different
    /// claims (see `BiosChrome.publisher`).
    private var topBar: some View {
        VStack(spacing: 6) {
            VStack(spacing: 3) {
                Text(title)
                    .font(DexFont.retro(Self.barSize))
                    .foregroundStyle(BiosInk.cream)
                Text(BiosChrome.copyright(releaseDate: FirmwareCatalog.shared.current?.date))
                    .font(DexFont.retro(Self.barSize))
                    .foregroundStyle(BiosInk.gold)
            }
            .frame(maxWidth: .infinity)
            .lineLimit(1)
            .minimumScaleFactor(0.4)

            // **The rule stays.** A4 drops the *frame* — border, side rails,
            // corner brackets — and this is not it: `BiosRule` divides the
            // composition's zones from each other, which is the job the chassis
            // cannot do for it. B2 makes the same distinction one floor down.
            BiosRule { BiosHexBadge() }
        }
    }

    /// The height the top bar costs, so the identity stack can be derived
    /// against it rather than guessed at. Two label lines, their gap, the stack
    /// spacing, and the rule's own centre piece.
    private var topBarHeight: CGFloat {
        DexFont.resolvedSize(Self.barSize) * 2 + 3 + 6 + BiosMetrics.badgeHeight
    }

    /// And the bottom bar's, on the same terms: the battery row, the gap, and the
    /// rule.
    ///
    /// **The pill's height is gone from this sum (0.8.0, B2)** — it was the
    /// label's resolved size plus its two 5pt paddings and border, and there is
    /// no label. What is left is a 1pt rule, so the term is the rule rather than
    /// the 12 the pill cost. The identity stack gets the difference, via
    /// `markCeiling`, which is where a shorter bottom bar should go.
    private var bottomBarHeight: CGFloat {
        max(DexFont.resolvedSize(Self.barSize), 14) + 8 + 1
    }

    // MARK: Bottom bar

    /// **The pill is gone (0.8.0, B2) and the rule it interrupted is not.**
    ///
    /// B2 asks for the VINODEX HANDHELD SYSTEM line removed. Read as "delete the
    /// bottom bar" that would also take the rule, and the rule is not the line —
    /// it is the member that closes the composition, the answer to the hex badge
    /// on the top rule, and the thing that keeps the identity stack bracketed
    /// rather than trailing off into the bezel. A4 already established the
    /// distinction when it deleted `BiosFrame` and kept `BiosRule`: what the
    /// chassis cannot do for this screen is divide its own zones.
    ///
    /// So the rule survives uninterrupted, as `BiosSolidRule` — which is the two
    /// halves `BiosRule` was already drawing, minus the gap it left for a centre
    /// piece. The bottom bar is now the battery, the signal and a line under
    /// them, which is what a status bar is.
    private var bottomBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                BiosBatteryGlyph(fill: battery.fill)
                    .frame(width: 25, height: 13)
                Text(battery.text)
                    .font(DexFont.retro(Self.barSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(BiosInk.gold)
                Spacer(minLength: 8)
                BiosSignalBars()
                    .frame(width: 25, height: 14)
            }

            BiosSolidRule()
        }
    }

    // MARK: Centre stack

    /// Everything in the identity stack except the mark, measured rather than
    /// written down — each term is the resolved size of the thing it names, so
    /// the sum follows `TextScale` and the MAINFRAME cheat's two extra check
    /// lines on its own.
    private var identityFixedHeight: CGFloat {
        DexFont.resolvedSize(Self.wordmarkSize)
            + Self.dividerHeight
            + DexFont.resolvedSize(Self.taglineSize)
            + Self.glassSize
            + statusSlotHeight
            + Self.identitySpacing * 5
    }

    /// How tall the mark may be in a display of `available` points.
    ///
    /// **The vertical derivation A4 needs, and the reason it is a function.**
    /// The width came out to a number (353, less the content inset); the height
    /// cannot, because the display is the window less the island strip, less the
    /// footer, less four bands of bezel, and the footer follows `UIScale` and the
    /// device. So this measures what is left after everything with words in it
    /// has been paid for, and gives the difference to the mark — clamped to
    /// `markHeight` so a tall display does not inflate the logo past the size
    /// 0.7.7 chose, and to `markFloor` so a short one clips rather than
    /// dissolving the composition. A device short enough to hit the floor is
    /// showing a mark at 40pt with everything else intact, which is the right
    /// order to lose things in.
    private func markCeiling(in available: CGFloat) -> CGFloat {
        let spent = BiosMetrics.contentInset * 2
            + topBarHeight
            + bottomBarHeight
            + 16                      // the two inter-zone spacers at their minimum
            + identityFixedHeight
        return min(Self.markHeight, max(Self.markFloor, available - spent))
    }

    private func identity(markCeiling: CGFloat) -> some View {
        VStack(spacing: Self.identitySpacing) {
            // `maxHeight`, not `height`: `BiosMark` fits its art to an aspect
            // ratio, so a ceiling lets it shrink and a fixed height would not.
            BiosMark()
                .frame(maxHeight: markCeiling)

            wordmark

            BiosDivider()
                .frame(height: Self.dividerHeight)

            Text(BiosChrome.tagline)
                .font(DexFont.retro(Self.taglineSize))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(BiosInk.gold)

            DexIcon(
                iconID: "game-icons:wine-glass",
                size: Self.glassSize,
                color: BiosInk.cream,
                // `PixelOutline` stacks eight black shadows to reproduce the web
                // app's outline. On a near-black ground that is invisible at
                // best and a smear at worst, and this glyph is not sitting in an
                // entry well — it is part of the composition.
                outlined: false
            )
            .opacity(0.9)

            statusSlot
        }
    }

    /// The wordmark: cream, with the magenta drop shadow the mark itself has.
    ///
    /// **Italic by transform rather than by typeface.** `PressStart2P` ships one
    /// face and no oblique; `.italic()` on a custom font is a request the system
    /// may satisfy by synthesis or may silently ignore, and "silently ignore" is
    /// how a described detail goes missing without anything failing. A shear is
    /// deterministic. `.padding` reserves the width the shear throws sideways,
    /// so the skewed glyphs do not overrun the rails they are centred between.
    private var wordmark: some View {
        Text("VINODEX")
            .font(DexFont.retro(Self.wordmarkSize))
            .tracking(2)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .foregroundStyle(BiosInk.cream)
            .shadow(color: BiosInk.magentaDeep, radius: 0, x: 3, y: 3)
            .padding(.horizontal, DexFont.resolvedSize(Self.wordmarkSize) * BiosMetrics.shear)
            .transformEffect(
                CGAffineTransform(a: 1, b: 0, c: -BiosMetrics.shear, d: 1, tx: 0, ty: 0)
            )
    }

    /// One row of the terminal voice.
    ///
    /// **Derived from the resolved size, not written down.** A fixed row height
    /// would be correct at the default text step and wrong at every other one:
    /// `TextScale` can take `terminalSize` from 22 to about 29, and rows on a
    /// 26pt pitch would then overlap each other. `DexFont.resolvedSize` is the
    /// size the text is actually drawn at — the same number the marquee derives
    /// its glyph gap from — and the four points are the leading.
    private var terminalLineHeight: CGFloat {
        DexFont.resolvedSize(Self.terminalSize) + 4
    }

    /// The one slot that changes (C1).
    ///
    /// Fixed height with both states stacked inside it, so the resolve is a
    /// cross-fade in place and the composition around it never reflows — the
    /// difference between a screen that settles and a screen that jumps.
    ///
    /// The height is however many check lines there are, floored at two so the
    /// resting pair always fits. It is a count rather than the constant 3
    /// because of the MAINFRAME cheat (0.7.3a, A4): verbose boot adds two lines,
    /// and a slot sized for the plain sequence would have let the cheat print
    /// through the wine glass above it and the status bar below.
    private var statusSlotHeight: CGFloat {
        CGFloat(max(lines.count, 2)) * terminalLineHeight
    }

    private var statusSlot: some View {
        ZStack {
            checkLines.opacity(settled ? 0 : 1)
            resting.opacity(settled ? 1 : 0)
        }
        .frame(height: statusSlotHeight)
        // 320 was chosen against the full viewport's 353 and it still clears the
        // LCD's 329 (0.7.8, A4), so it is left alone: a 40-character VT323 line
        // at the default step is 40 x 18.7 x 0.4 = 299, inside it either way.
        .frame(maxWidth: 320)
    }

    private var checkLines: some View {
        VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                HStack(spacing: 8) {
                    Text(line.label)
                        .foregroundStyle(BiosInk.cream)
                    // The dot leader a POST screen has: a repeated glyph in a
                    // flexible frame rather than a computed run of periods, so
                    // the width is whatever is left and nothing has to measure a
                    // font to know it.
                    Text(String(repeating: ".", count: 40))
                        .foregroundStyle(BiosInk.magenta.opacity(0.55))
                        .truncationMode(.tail)
                        .layoutPriority(-1)
                    Text(line.result)
                        .foregroundStyle(BiosInk.gold)
                }
                .font(DexFont.mono(Self.terminalSize))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: terminalLineHeight)
                .opacity(index < shown ? 1 : 0)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var resting: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(BiosChrome.checkLabel)
                    .foregroundStyle(BiosInk.cream)
                Text(BiosChrome.checkResult)
                    .foregroundStyle(BiosInk.gold)
            }
            .font(DexFont.mono(Self.terminalSize))
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            Text(BiosChrome.prompt)
                .font(DexFont.retro(Self.promptSize))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(BiosInk.magenta)
                // Slow, and never off — a prompt that blinks to zero is
                // unreadable half the time it is up, and Reduce Motion turns the
                // pulse off entirely rather than speeding it up.
                .opacity(pulsing ? 1 : 0.45)
        }
    }

    // MARK: Behaviour

    /// The device battery, read once (D1).
    ///
    /// **Monitoring has to be switched on first**, or `batteryLevel` is -1 —
    /// which is D1's own fallback case and would make the flag look optional
    /// while quietly printing `100%` on every device forever. This is the app's
    /// only reader of it, and it is left enabled rather than switched back off
    /// on the next line: the level is populated *as a result of* monitoring
    /// being on, and disabling it in the same breath is the one thing that could
    /// make this read race. The cost of leaving it on is a notification
    /// subscription the app never observes.
    ///
    /// Read once rather than observed. The screen is up for at most five and a
    /// half seconds and a charge level does not move in five and a half seconds;
    /// if the very first read still comes back -1, `BiosChrome.battery` prints
    /// the fallback, which is the same answer a device that cannot report one
    /// gets.
    private func readBattery() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        battery = BiosChrome.battery(level: UIDevice.current.batteryLevel)
    }

    private func run() async {
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        } else {
            pulsing = true
        }

        // Reduce Motion skips the reveal but not the screen: the boot state is
        // information, not decoration, and the version is genuinely the answer
        // to "what am I running". It arrives whole and rests immediately.
        if reduceMotion {
            shown = lines.count
            settled = true
        } else {
            var elapsed: TimeInterval = 0
            for (index, line) in lines.enumerated() {
                let wait = max(line.at - elapsed, 0)
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
                elapsed = line.at
                withAnimation(.easeOut(duration: 0.12)) { shown = index + 1 }
                Sounds.tap()
            }
            try? await Task.sleep(for: .seconds(BootSequence.settle))
            guard !Task.isCancelled else { return }
            withAnimation(DexMotion.crossfade) { settled = true }
        }

        // The prompt's own clock (C2). The screen is now waiting for the user
        // and this is the promise that it will not wait forever.
        try? await Task.sleep(for: .seconds(BootSequence.autoAdvance))
        guard !Task.isCancelled else { return }
        onFinish()
    }
}

// MARK: - Metrics

/// The composition's fixed geometry.
///
/// `frameInset` retired in 0.7.8 (A4): there is no drawn frame to inset. It was
/// 6, and the pair of numbers only ever meant anything relative to each other —
/// the gap between them was where the brackets and rail ticks lived. With the
/// border gone, `contentInset` is measured against the display's own edge.
private enum BiosMetrics {
    /// The content, in from the LCD's edge.
    ///
    /// **20 -> 12 in 0.7.8 (A4).** 20 was buying room for the rail ticks
    /// between the border and the content; the chassis's surround is the border
    /// now and it is outside this view entirely, so paying for it twice would
    /// have been the "bezel inside a bezel" cost by another route. 12 is set by
    /// the display's clip rather than by taste: `bezelCorner` is 28, so at 12pt
    /// in from the side the corner curve has already risen to within 5pt of the
    /// top edge and nothing in the top bar is under it.
    static let contentInset: CGFloat = 12
    /// The hex badge's drawn height, named here because the top bar's height
    /// derivation has to include it. 34 since 0.8.0 (B5), from 30 — see
    /// `BiosHexBadge`, which is the one place its width goes with it.
    static let badgeHeight: CGFloat = 34
    /// The wordmark's shear, as a fraction of its point size. About 10°, which
    /// is the slant of the mark's own extrusion.
    static let shear: CGFloat = 0.18
}

// MARK: - Advancing

/// The layer that lets any touch anywhere finish the BIOS (C2), mounted over the
/// whole window while `BootScreen` is mounted inside the display.
///
/// **A4 required re-deriving this rather than keeping or deleting it, and the
/// answer came back the same with a different reason.** 0.7.7's version was a
/// `Color.clear.ignoresSafeArea()` inside `BootScreen` itself, and its note
/// explained why: the composition was safe-area aware, so a gesture on the stack
/// would have left the notch strip and the home-indicator strip untouchable, and
/// touches there would have fallen *through* to the chassis, where the island
/// orb is a live control. A tap above the notch during boot would have pressed
/// it.
///
/// **Every clause of that is now false.** The screen is mounted inside the LCD,
/// which is bounded by the chassis and never overlaps either strip; and the
/// display's `clipShape` would have confined an `ignoresSafeArea` layer to the
/// display regardless, so keeping it would have been a modifier that did
/// nothing. The literal reading — delete it, let the screen take its own taps —
/// is worse than either: the chassis is *visible* now, which is the whole point
/// of A4, and everything on it is live. A tap on the footer buttons, the marquee
/// lamps or the orb during boot would press them instead of advancing, and a
/// one-second hold on the orb would flip a device that has not finished starting
/// up. 0.7.7 found that hazard by accident; A4 hands it back on purpose.
///
/// So the capture layer survives its own justification: **the picture belongs
/// inside the display, the input belongs to the window.** It is over the chassis
/// rather than inside the LCD for exactly the reason 0.7.7 put it over the
/// composition — what is underneath must not be pressed — and it is a separate
/// view rather than a modifier so that reason is written where it applies.
///
/// A zero-distance drag rather than `onTapGesture`: it catches taps, swipes and
/// touches that land mid-check alike, where a slow press that moves a few points
/// is not a tap and would have been ignored on the one screen where being
/// ignored is the failure.
public struct BootAdvanceCatcher: View {
    let onAdvance: () -> Void

    public init(onAdvance: @escaping () -> Void) {
        self.onAdvance = onAdvance
    }

    public var body: some View {
        Color.clear
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { _ in onAdvance() })
            .accessibilityHidden(true)
    }
}

// MARK: - Rules

// `BiosFrame` was here and is deleted (0.7.8, A4). It drew the terminal's own
// border, its two side rails of inward ticks and its four corner brackets, off
// one inset rectangle in a single `Canvas`. All of it is what the spec means by
// "the drawn frame": the device already surrounds this display with a chamfered
// panel, a stone band, a white bezel and a vent strip, and a second frame inside
// that one is the bezel-inside-a-bezel 0.7.7 correctly refused — which is why
// A4 removes the frame rather than the composition. `tickPitch`, `tickLength`,
// `bracket` and `BiosMetrics.frameInset` went with it; none of them describes
// anything now.

/// A thin magenta rule interrupted at its centre by `centre` (B1).
///
/// Both status bars are one of these. The interruption is a real gap rather than
/// the badge being drawn over a continuous line: the badge and the pill are both
/// filled with the background, and a rule passing behind them would show through
/// the hexagon's flats at the two points where the fill is thinnest.
private struct BiosRule<Centre: View>: View {
    @ViewBuilder var centre: () -> Centre

    var body: some View {
        HStack(spacing: 10) {
            BiosSolidRule()
            centre()
            BiosSolidRule()
        }
    }
}

/// One unbroken magenta hairline — the segment `BiosRule` is made of, and the
/// bottom bar's whole rule since 0.8.0 (B2).
///
/// Split out rather than given to `BiosRule` as an empty-centre case: a
/// `ViewBuilder` handed `EmptyView` still gets its `HStack` spacing on both
/// sides, so "a rule with nothing in the middle" would have drawn a 20pt gap in
/// the middle of a line. This is the same ink at the same opacity, in one place,
/// so the two rules on the screen cannot drift apart.
private struct BiosSolidRule: View {
    var body: some View {
        Rectangle()
            .fill(BiosInk.magenta.opacity(0.7))
            .frame(height: 1)
    }
}

// MARK: - CRT treatment

/// The scanlines (B3).
///
/// Every third point, one point tall, at an opacity low enough that the effect
/// is felt rather than seen. Any denser and the pixel type below it starts to
/// lose rows; any darker and the screen reads as damaged rather than as a CRT.
private struct BiosScanlines: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            // **Pitch-locked to the display's own raster (0.7.8, A4).** This
            // used to be a 1pt line every 3pt over the whole window, where
            // nothing else was drawing lines. Inside the LCD there already is a
            // raster: `ScanlineOverlay` fills 2pt every `scanlineSpacing` (4) in
            // the same coordinate space, one `ZStack` layer above. Two grids at
            // 3 and 4 beat against each other with a 12pt period — 30-odd
            // visible bands down the display, which is a moiré rather than a
            // CRT.
            //
            // So this rides the same 4pt pitch and lands in the gap the
            // display's own lines leave, which is what makes the BIOS's raster
            // *finer* than the rest of the app's rather than merely different
            // from it. The half-point keeps the line off the boundary at 3x.
            var y: CGFloat = DexMetrics.scanlineThickness + 0.5
            while y < size.height {
                path.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
                y += DexMetrics.scanlineSpacing
            }
            context.fill(path, with: .color(.black.opacity(0.22)))
        }
        .allowsHitTesting(false)
    }
}

/// The faint glow behind the mark, and the darkening at the corners (B3).
///
/// Two radials rather than one: a screen that is only vignetted looks dirty, and
/// a screen that only glows looks flat. The warm centre is what gives the cream
/// mark something to sit in.
/// **Radii are fractions of the diagonal since 0.7.8 (A4).** They were 0/260 and
/// 180/560 in points, chosen against a 393x852 window whose diagonal is ~938 —
/// i.e. 0.277, and 0.192 to 0.597. Left as points they would have been drawn at
/// full window scale inside a display roughly half that size, which puts the
/// whole vignette outside the LCD and leaves a flat magenta wash where the
/// corner darkening should be. The fractions reproduce 0.7.7's look at whatever
/// size the display turns out to be, which is the same argument
/// `terminalLineHeight` makes about deriving rather than writing down.
private struct BiosVignette: View {
    let diagonal: CGFloat

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [BiosInk.magentaDeep.opacity(0.30), .clear],
                center: .center,
                startRadius: 0,
                endRadius: diagonal * 0.277
            )
            RadialGradient(
                colors: [.clear, .black.opacity(0.55)],
                center: .center,
                startRadius: diagonal * 0.192,
                endRadius: diagonal * 0.597
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - The mark

/// The pixel "V", cream over a magenta drop shadow (B4).
///
/// **The asset B4 names is not where B4 says it is any more.** The spec asks for
/// `art/icons/chrome/logo/`, which is the artist's master; 0.7.5's A5 established that
/// `Resources/Icons` is the wrong home for a hand-made asset — `rasterize-icons.sh`
/// deletes any PNG there that the generated manifest does not list — so the mark
/// ships in `Resources/Logo` as two masks split on luminance by
/// `scripts/import-logo-art.py`. That split is exactly what this composition
/// wants: the master's lit face and its extruded edge arrive as separate
/// silhouettes, so the face can be cream and the edge magenta without either
/// colour ever having been baked into a PNG.
///
/// The face carries a vertical gradient rather than a flat cream — the "faint
/// scanline gradient" of the description, done as a gradient on the ink instead
/// of as a second overlay, because `BiosScanlines` is already drawing the raster
/// over the top and two scanline treatments on one element read as moiré.
private struct BiosMark: View {
    var body: some View {
        if let face = ScreensaverMarkArt.face, let shade = ScreensaverMarkArt.shade {
            ZStack {
                Image(uiImage: shade)
                    .resizable()
                    .interpolation(.none)
                    .foregroundStyle(BiosInk.magentaDeep)
                Image(uiImage: face)
                    .resizable()
                    .interpolation(.none)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [BiosInk.cream, BiosInk.cream.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .aspectRatio(ScreensaverMarkArt.aspect, contentMode: .fit)
        } else {
            // Visible on purpose, exactly as `DexIcon`'s missing-glyph branch is
            // and for the same reason `ScreensaverMark` keeps this fallback: a
            // mark that failed to load must not be an empty gap in the middle of
            // the first screen of the app. 0.7.3a's drawn letterform needs no
            // asset and cannot fail, and it takes the same two inks.
            ZStack {
                VinodexV()
                    .fill(BiosInk.magentaDeep)
                    .offset(x: 4, y: 4)
                VinodexV()
                    .fill(BiosInk.cream)
            }
            .aspectRatio(1 / 1.05, contentMode: .fit)
        }
    }
}

// MARK: - Small glyphs (B4)

// **None of the four is a new art asset, and that is a decision rather than a
// shortcut.** B4 offers "build them in `art/icons/`" *or* "reuse existing
// equivalents", and since 0.7.5 (A026-A028) a new asset is no longer a file
// dropped in a directory: `assertAssetsExist` refuses to generate if an emitted
// id has no file, `ArtPipelineRosterTests` fails until an importer is in all
// four rosters, and `verify-art.py` has to diff its output. That machinery is
// right for drawn art and wrong for these:
//
// - The **wine glass** already exists. `game-icons:wine-glass` has been in the
//   manifest since the flavour taxonomy shipped, it rasterises to a tintable
//   white mask, and drawing it is one `DexIcon`.
// - The **battery** cannot be a sprite at all — D1 makes its fill a function of
//   `UIDevice.batteryLevel`, so a static PNG would have to be eleven PNGs.
// - The **signal bars** are four rectangles.
// - The **grape cluster** is six squares and a stem at 14pt. Its master would be
//   larger than the thing it draws, and an importer would exist to downscale a
//   shape that is defined by being on the pixel grid.
//
// Drawn in code they are also tintable by role and sharp at any `TextScale`
// step, which is the same argument 0.6.2 settled when it moved the rarity leaf's
// recolour into `GrapeSpriteLoader` rather than shipping variants.

/// The badge interrupting the top rule: a hexagon holding a grape cluster.
private struct BiosHexBadge: View {
    var body: some View {
        ZStack {
            BiosHexagon()
                .fill(BiosInk.background)
            BiosHexagon()
                .stroke(BiosInk.magenta, lineWidth: 1.5)
            BiosGrapeCluster()
                .fill(BiosInk.gold)
                .padding(7)
        }
        // 30 x 34 since 0.8.0 (B5), from 26 x 30, keeping the badge's own
        // proportion. The height is `BiosMetrics.badgeHeight` because the top
        // bar's derivation reads it; the width is only ever drawn here.
        .frame(width: BiosMetrics.badgeHeight * 30 / 34, height: BiosMetrics.badgeHeight)
    }
}

/// A pointy-top hexagon — vertices at top and bottom, flat sides left and right.
///
/// Flat-topped would have sat on the rule as a slab; the point is what makes it
/// a badge hung on the line rather than a box interrupting it.
private struct BiosHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let h = rect.height
        // Quarter-height shoulders: the classic honeycomb proportion.
        let points = [
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY + h * 0.25),
            CGPoint(x: rect.maxX, y: rect.minY + h * 0.75),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.minY + h * 0.75),
            CGPoint(x: rect.minX, y: rect.minY + h * 0.25),
        ]
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

/// A grape cluster in six square berries, a stem and a leaf.
///
/// Squares, not circles: at the size this is drawn a circle is an antialiased
/// smudge and a square is a pixel. The 3-2-1 taper is what makes six shapes read
/// as a bunch — it is the silhouette doing the work, not the detail.
private struct BiosGrapeCluster: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height

        func block(_ x: CGFloat, _ y: CGFloat, _ bw: CGFloat, _ bh: CGFloat) {
            path.addRect(
                CGRect(
                    x: rect.minX + x * w,
                    y: rect.minY + y * h,
                    width: bw * w,
                    height: bh * h
                )
            )
        }

        // Stem, then the leaf beside it.
        block(0.465, 0.02, 0.07, 0.24)
        block(0.60, 0.06, 0.17, 0.13)

        // Three rows tapering to a point. `pitch` is the berry plus its gutter,
        // and each row is inset half a pitch from the one above so the berries
        // nest.
        let berry: CGFloat = 0.26
        let pitch: CGFloat = 0.30
        for (row, count) in [(0, 3), (1, 2), (2, 1)] {
            let y = 0.27 + CGFloat(row) * 0.245
            let width = CGFloat(count - 1) * pitch + berry
            var x = 0.5 - width / 2
            for _ in 0..<count {
                block(x, y, berry, 0.22)
                x += pitch
            }
        }
        return path
    }
}

/// The divider under the wordmark: a magenta rule with a gold pixel sparkle at
/// its centre (B1).
private struct BiosDivider: View {
    var body: some View {
        BiosRule {
            BiosSparkle()
                .fill(BiosInk.gold)
                .frame(width: 11, height: 11)
        }
    }
}

/// A four-point pixel star: a centre square with one arm on each side.
///
/// Five squares. An SF Symbol would have been one line and would also have been
/// the only vector-smooth thing on a screen made of squares.
private struct BiosSparkle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let unit = min(rect.width, rect.height) / 5
        let cx = rect.midX - unit / 2
        let cy = rect.midY - unit / 2
        for (dx, dy) in [(0.0, 0.0), (0.0, -2.0), (0.0, 2.0), (-2.0, 0.0), (2.0, 0.0)] {
            path.addRect(
                CGRect(x: cx + CGFloat(dx) * unit, y: cy + CGFloat(dy) * unit,
                       width: unit, height: unit)
            )
        }
        return path
    }
}

/// The battery in the bottom-left, filled to `fill` (D1).
///
/// Four bars rather than a continuous fill: a bar meter is what a device of this
/// vintage had, and it also means the readout degrades honestly — a battery at
/// 12% shows one bar rather than a sliver of gold nobody can judge.
private struct BiosBatteryGlyph: View {
    /// 0...1.
    let fill: Double

    private static let bars = 4

    /// Round up, so any charge at all shows a bar and only a genuinely empty
    /// battery shows none.
    private var lit: Int {
        min(Self.bars, max(0, Int((fill * Double(Self.bars)).rounded(.up))))
    }

    var body: some View {
        GeometryReader { geo in
            let bodyWidth = geo.size.width - 3
            let inset: CGFloat = 2.5
            let cell = (bodyWidth - inset * 2) / CGFloat(Self.bars)
            ZStack(alignment: .leading) {
                Rectangle()
                    .strokeBorder(BiosInk.gold, lineWidth: 1)
                    .frame(width: bodyWidth)
                // The terminal cap.
                Rectangle()
                    .fill(BiosInk.gold)
                    .frame(width: 2, height: geo.size.height * 0.45)
                    .offset(x: bodyWidth + 1)
                HStack(spacing: 1) {
                    ForEach(0..<Self.bars, id: \.self) { index in
                        Rectangle()
                            .fill(index < lit ? BiosInk.gold : .clear)
                            .frame(width: max(cell - 1, 1))
                    }
                }
                .padding(.vertical, inset)
                .padding(.leading, inset)
            }
        }
    }
}

/// Ascending signal bars in the bottom-right.
///
/// **Decorative, and D2 says so** — "fine to keep static". Deliberately drawn
/// full rather than at some invented strength: a meter that reported a number
/// the app never measured would be the quiet lie `AppVersion` spends forty lines
/// on, whereas four full bars are plainly a piece of the chrome. The one honest
/// reading on this screen is the battery, and it is honest because D1 asked for
/// it and `BiosChrome.battery` handles the case where it is not available.
private struct BiosSignalBars: View {
    private static let bars = 4

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<Self.bars, id: \.self) { index in
                Rectangle()
                    .fill(BiosInk.gold)
                    .frame(height: 3 + CGFloat(index) * 3)
            }
        }
    }
}
#endif
