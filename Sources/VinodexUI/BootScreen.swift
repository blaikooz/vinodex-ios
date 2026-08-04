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
/// **Full-screen, which reverses a decision 0.7.3a argued at length.** That
/// release kept the POST inside the LCD on the reasoning that a BIOS is
/// something a *screen* does, and that dimming the bezel, island and footer
/// reads as the device losing power at the one moment it is doing the opposite.
/// B1 asks for full-screen and safe-area aware, and the composition it describes
/// — its own terminal border, side rails, corner brackets and two status bars —
/// is a frame, so drawing it inside a second frame would have nested one bezel
/// in another.
///
/// The old argument does not survive the change of shape, and it is worth saying
/// why rather than just overruling it: what read as power *loss* was a
/// **translucent overlay dimming** the chassis. This is opaque and total. A
/// handheld whose entire face is a boot screen is not a handheld with a dimmed
/// bezel; it is a handheld booting, which is what the bottom bar says in so many
/// words. So the chassis is covered rather than dimmed, and it is not visible
/// around the edges — an inset BIOS with a plastic border showing would be the
/// dimmed-chassis reading all over again.
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
    // bars. `(c)2026 VINODEX SOFTWARE` is 24 characters, so at 8pt it is 192 of
    // the ~357 a 393pt phone offers inside the rails, and the title opposite it
    // is another 152. They fit at the default step and ride the scale factor at
    // the top of it, which is the right trade for a line nobody reads twice.

    /// The two top-bar labels, and the bottom bar's pill.
    private static let barSize: CGFloat = 8
    /// The wordmark. The largest type in the app, and the reason the identity
    /// stack reads as a logo rather than as a heading.
    private static let wordmarkSize: CGFloat = 28
    /// The tagline, 26 characters wide.
    private static let taglineSize: CGFloat = 8
    /// The prompt, 28 characters wide — the widest retro string on the screen,
    /// and the one that hits its scale factor first.
    private static let promptSize: CGFloat = 9
    /// The terminal voice: the check lines and the status line they resolve
    /// into. `VT323` advances about 0.4em, so 22pt buys a 40-character line in
    /// the width available.
    private static let terminalSize: CGFloat = 22
    /// The mark's drawn height. Its width follows the art's own aspect.
    private static let markHeight: CGFloat = 92

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
        ZStack {
            // The ground and the CRT treatment run edge to edge, under the
            // safe area — a boot screen with a black bar above it is a boot
            // screen in a window.
            BiosInk.background.ignoresSafeArea()
            BiosVignette().ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 12)
                identity
                Spacer(minLength: 12)
                bottomBar
            }
            .padding(.horizontal, BiosMetrics.contentInset)
            .padding(.vertical, BiosMetrics.contentInset)

            // Over the content, inside the safe area: the frame is the terminal's
            // own border and has to enclose what the terminal prints.
            BiosFrame()

            // Over everything including the frame — a scanline that stopped at
            // the border would read as a texture on the background rather than
            // as the display's own raster.
            BiosScanlines().ignoresSafeArea()

            // **Any input advances (C2), and this is a layer rather than a
            // modifier on the stack for a reason.** The composition is
            // safe-area aware, so the stack's own bounds stop at the insets —
            // a `.gesture` there would leave the notch strip and the home
            // indicator strip untouchable, and those touches would fall
            // *through* to the chassis underneath, where the island orb is a
            // control. A tap above the notch during boot would have pressed it.
            // This layer ignores the safe area, so the whole display advances.
            //
            // A zero-distance drag rather than `onTapGesture`: it catches taps,
            // swipes and touches that land mid-check alike, where a slow press
            // that moves a few points is not a tap and would have been ignored
            // on the one screen where being ignored is the failure.
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { _ in onFinish() })
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

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(DexFont.retro(Self.barSize))
                    .foregroundStyle(BiosInk.cream)
                Spacer(minLength: 4)
                Text(BiosChrome.copyright(releaseDate: FirmwareCatalog.shared.current?.date))
                    .font(DexFont.retro(Self.barSize))
                    .foregroundStyle(BiosInk.gold)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.4)

            BiosRule { BiosHexBadge() }
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                BiosBatteryGlyph(fill: battery.fill)
                    .frame(width: 22, height: 11)
                Text(battery.text)
                    .font(DexFont.retro(Self.barSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(BiosInk.gold)
                Spacer(minLength: 8)
                BiosSignalBars()
                    .frame(width: 22, height: 12)
            }

            BiosRule {
                Text(BiosChrome.system)
                    .font(DexFont.retro(Self.barSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(BiosInk.magenta)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(BiosInk.magenta, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 7).fill(BiosInk.background)
                            )
                    )
            }
        }
    }

    // MARK: Centre stack

    private var identity: some View {
        VStack(spacing: 14) {
            BiosMark()
                .frame(height: Self.markHeight)

            wordmark

            BiosDivider()
                .frame(height: 12)

            Text(BiosChrome.tagline)
                .font(DexFont.retro(Self.taglineSize))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(BiosInk.gold)

            DexIcon(
                iconID: "game-icons:wine-glass",
                size: 26,
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
    private var statusSlot: some View {
        ZStack {
            checkLines.opacity(settled ? 0 : 1)
            resting.opacity(settled ? 1 : 0)
        }
        .frame(height: CGFloat(max(lines.count, 2)) * terminalLineHeight)
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
/// Named together because they are relative to each other: the frame is inset
/// by `frameInset`, the content by `contentInset`, and the gap between them is
/// what the corner brackets and rail ticks are drawn in. Changing one alone is
/// how a bracket ends up under a label.
private enum BiosMetrics {
    /// The terminal border, in from the safe area.
    static let frameInset: CGFloat = 6
    /// The content, in from the safe area — far enough inside the border that
    /// the rail ticks have somewhere to be.
    static let contentInset: CGFloat = 20
    /// The wordmark's shear, as a fraction of its point size. About 10°, which
    /// is the slant of the mark's own extrusion.
    static let shear: CGFloat = 0.18
}

// MARK: - Frame

/// The terminal border, side rails and corner brackets (B1).
///
/// One `Canvas` rather than a stack of shapes: this is six elements that all
/// derive from the same inset rectangle, and drawing them together is both the
/// cheapest way to do it and the only way to guarantee they agree about where
/// the corner is.
private struct BiosFrame: View {
    /// Pitch of the rail ticks.
    private let tickPitch: CGFloat = 12
    private let tickLength: CGFloat = 5
    private let bracket: CGFloat = 18

    var body: some View {
        Canvas { context, size in
            let inset = BiosMetrics.frameInset
            let rect = CGRect(
                x: inset,
                y: inset,
                width: max(size.width - inset * 2, 0),
                height: max(size.height - inset * 2, 0)
            )
            guard rect.width > 0, rect.height > 0 else { return }

            // The border itself, thin and dim — it frames the screen rather
            // than competing with the rules in the two status bars.
            context.stroke(
                Path(rect),
                with: .color(BiosInk.magenta.opacity(0.45)),
                lineWidth: 1
            )

            // The ticked side rails. Drawn inward from each edge, skipping the
            // span the corner brackets occupy so the two never overprint.
            var ticks = Path()
            var y = rect.minY + bracket + tickPitch
            while y < rect.maxY - bracket {
                ticks.move(to: CGPoint(x: rect.minX, y: y))
                ticks.addLine(to: CGPoint(x: rect.minX + tickLength, y: y))
                ticks.move(to: CGPoint(x: rect.maxX, y: y))
                ticks.addLine(to: CGPoint(x: rect.maxX - tickLength, y: y))
                y += tickPitch
            }
            context.stroke(ticks, with: .color(BiosInk.magenta.opacity(0.35)), lineWidth: 1)

            // Corner brackets, at full strength: they are what makes the frame
            // read as a terminal's rather than as a box someone drew.
            var corners = Path()
            for (x, sx) in [(rect.minX, CGFloat(1)), (rect.maxX, CGFloat(-1))] {
                for (y, sy) in [(rect.minY, CGFloat(1)), (rect.maxY, CGFloat(-1))] {
                    corners.move(to: CGPoint(x: x + sx * bracket, y: y))
                    corners.addLine(to: CGPoint(x: x, y: y))
                    corners.addLine(to: CGPoint(x: x, y: y + sy * bracket))
                }
            }
            context.stroke(corners, with: .color(BiosInk.magenta), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }
}

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
            line
            centre()
            line
        }
    }

    private var line: some View {
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
            var y: CGFloat = 0
            while y < size.height {
                path.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
                y += 3
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
private struct BiosVignette: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [BiosInk.magentaDeep.opacity(0.30), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            RadialGradient(
                colors: [.clear, .black.opacity(0.55)],
                center: .center,
                startRadius: 180,
                endRadius: 560
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - The mark

/// The pixel "V", cream over a magenta drop shadow (B4).
///
/// **The asset B4 names is not where B4 says it is any more.** The spec asks for
/// `art/icons/dvd/`, which is the artist's master; 0.7.5's A5 established that
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
                .padding(6)
        }
        .frame(width: 26, height: 30)
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
