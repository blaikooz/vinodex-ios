#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// MARK: - Ink

/// The BIOS palette, unchanged from 0.7.7's `BootScreen` (0.8.91, G3).
///
/// **The one screen in this app that does not take its colours from `LcdMode`,
/// and the reason is in the fiction.** Every themed surface reads an `lcd.*`
/// token — the house rule since 0.6.2. This screen breaks it deliberately: a
/// BIOS runs *before* the system that knows what the user chose. Twenty-four
/// colourways are a preference the firmware has not loaded yet, and a boot
/// screen that already knew your phosphor would be the one part of the metaphor
/// that gave the game away.
///
/// The roles are load-bearing and carried over verbatim: **cream is the system
/// talking about itself**, **gold is telemetry** — the things the screen
/// measures rather than asserts — and **magenta is the frame and the prompts**,
/// the machine addressing the user. A fourth colour would mean the roles had
/// stopped meaning anything, which is why the sheen below is a *gradient over*
/// cream and gold rather than a new ink.
private enum BiosInk {
    /// Near-black, warm. Not `.black`: a true black next to cream reads as a
    /// hole rather than as an unlit phosphor.
    static let background = Color(dexHex: "#0E0A0E")
    /// Rules, prompts, the sweep's ground.
    static let magenta = Color(dexHex: "#B0417A")
    /// The mark's drop shadow — the same ink in shadow, exactly as
    /// `ScreensaverMark`'s dimmed layer is.
    static let magentaDeep = Color(dexHex: "#7A2E52")
    /// The logo and everything the system says about itself.
    static let cream = Color(dexHex: "#F2E8D5")
    /// Telemetry: the copyright, the tagline, the check results.
    static let gold = Color(dexHex: "#E6A93A")
}

/// The wordmark's chrome ramp — white through cream through gold and back.
/// Three stops of two existing inks plus specular white, so it is a *finish* on
/// the palette rather than a fourth colour in it.
private let chromeRamp = LinearGradient(
    colors: [.white, BiosInk.cream, BiosInk.gold, BiosInk.cream, .white],
    startPoint: .top,
    endPoint: .bottom
)

// MARK: - Bloom

/// A blurred screen-blended copy of the content under itself, plus two coloured
/// shadows.
///
/// The CRT phosphor smear, and the reason it is a modifier rather than a
/// `.shadow` pair at each call site: the blurred copy has to sit *behind* the
/// crisp one, and a `.blur` applied inline replaces the thing it is blurring.
private struct BiosBloom: ViewModifier {
    var color: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        ZStack {
            content.blur(radius: radius).opacity(0.9).blendMode(.screen)
            content
        }
        .shadow(color: color.opacity(0.9), radius: radius * 0.8)
        .shadow(color: color.opacity(0.6), radius: radius * 1.6)
    }
}

private extension View {
    func bioBloom(_ color: Color, _ radius: CGFloat) -> some View {
        modifier(BiosBloom(color: color, radius: radius))
    }
}

// MARK: - Screen

/// **The startup screen** (0.8.91, G3) — a CRT power-on, the POST, and the
/// identity splash it resolves into.
///
/// ## It replaces `BootScreen` rather than joining it
///
/// §G3 says "don't leave two boot paths running", and the reconciliation is
/// asymmetric on purpose: the *composition* here is new and the *content* is
/// not. `BootScreen`'s three zones, drawn frame, hex badge and grape cluster are
/// gone with the file. `BootSequence` and `BiosChrome` — the lines, their
/// order, their timing, the tagline, the prompt and the copyright — are
/// untouched, because those were always the half worth keeping: they live in
/// Core where `swift test` can hold them, and every one of their tests still
/// passes against this screen.
///
/// So nothing below invents a string or a duration. In particular the FIRMWARE
/// line reads `AppVersion.current`, not the mockup's `v1.0.0` — that literal is
/// on `AppVersion.placeholders` precisely so a build that failed to resolve its
/// version says so instead of printing a plausible number. Printing it would
/// have hidden the failure it signals, which is the same judgement 0.7.7 made.
///
/// ## The clock is absolute, not a sum of sleeps
///
/// Every beat is scheduled against one `start` instant rather than by adding
/// pauses, so the animation cannot accumulate drift and — the part that matters
/// — the whole screen is bounded by `BootSequence.longestUntouched`. That is
/// `duration + autoAdvance`, 5.4 seconds, and it is the number
/// `BootSequenceTests.neverTraps` already asserts. A boot animation is a tax on
/// every single launch forever; the delivered timing ran roughly twice that with
/// `slowMotion` on, which is why the flag defaults off here.
///
/// ## Inside the LCD, framed by the chassis
///
/// Unchanged from 0.7.8's A4 and stated again because it is easy to lose: this
/// renders to fill its container, and its container is the display. The device
/// around it stays lit and normal. A handheld with a boot screen on its screen
/// is a handheld booting; a translucent sheet dimming the bezel and the footer
/// is a handheld losing power, which is the reading 0.7.3a rejected.
///
/// ## It cannot trap anyone
///
/// Any touch anywhere advances — this view's own tap, and `BootAdvanceCatcher`
/// over the whole window for the touches that land on the chassis furniture
/// around it. If none arrives the screen answers its own prompt. `finish()` is
/// idempotent, so the two paths racing is not a bug.
public struct VinodexBootView: View {
    /// The loaded catalog's entry count, for the DATABASE line. Zero is a
    /// legitimate answer — see `BootSequence.lines`.
    let entries: Int
    /// The MAINFRAME cheat (0.7.3a, A4): two more check lines.
    let verbose: Bool
    /// A debug knob, **off by default**. Multiplies every offset, so the
    /// sequence can be watched frame by frame without editing the schedule. See
    /// the type note for why shipping it on was not an option.
    let slowMotion: Bool
    let onFinish: () -> Void

    public init(
        entries: Int,
        verbose: Bool = false,
        slowMotion: Bool = false,
        onFinish: @escaping () -> Void = {}
    ) {
        self.entries = entries
        self.verbose = verbose
        self.slowMotion = slowMotion
        self.onFinish = onFinish
    }

    // MARK: Sequence state

    @State private var crtOpen = false
    @State private var flash = 0.0
    @State private var showChrome = false
    @State private var showPost = false
    @State private var postShown = 0
    @State private var showSplash = false
    @State private var logoIn = false
    @State private var wordIn = false
    @State private var dividerIn = false
    @State private var tagIn = false
    @State private var glassIn = false
    @State private var sysIn = false
    @State private var promptIn = false
    @State private var promptBlink = false
    @State private var sweepX: CGFloat = 0
    @State private var finished = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rate: Double { slowMotion ? 2.2 : 1.0 }

    private var lines: [BootLine] {
        BootSequence.lines(entries: entries, version: AppVersion.current, verbose: verbose)
    }

    // MARK: Schedule
    //
    // Offsets from the power-on instant, in seconds. The three that matter are
    // `BootSequence`'s and are read rather than written: the checks land at
    // their own `at`, the phase turns at `duration`, and the screen gives up at
    // `longestUntouched`. The rest is the dressing between them.

    /// When the terminal chrome resolves — before the first check line, so the
    /// line arrives *on* a screen rather than with it.
    private static let chromeAt: TimeInterval = 0.20
    /// When the POST clears and the identity stack begins.
    private var splashAt: TimeInterval { BootSequence.duration + BootSequence.settle * 0.5 }

    // MARK: Body

    public var body: some View {
        GeometryReader { geo in
            // One scale factor for the whole composition, taken from the width
            // the mockup was drawn at. The display is a fixed portrait region
            // (see `DexMetrics`), so this varies only with the device — which is
            // exactly what it should track.
            let s = geo.size.width / 380.0

            ZStack {
                BiosInk.background

                content(width: geo.size.width, s: s)
                    // The CRT opening: a horizontal line that becomes a picture.
                    .scaleEffect(x: 1, y: crtOpen ? 1 : 0.015, anchor: .center)
                    .opacity(crtOpen ? 1 : 0)

                Group {
                    BiosScanlines().opacity(showChrome ? 0.8 : 0)
                    BiosVignette().opacity(showChrome ? 1 : 0)
                    // Phosphor tint, always on — the glass is never neutral.
                    BiosInk.magenta.opacity(0.04)
                    Color.white.opacity(flash)
                }
                .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(BiosInk.background)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { finish() }
            .task { await run() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(BootSequence.header(version: AppVersion.current))
            .accessibilityHint(BiosChrome.prompt)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { finish() }
        }
    }

    // MARK: Composition

    @ViewBuilder
    private func content(width: CGFloat, s: CGFloat) -> some View {
        ZStack {
            terminalChrome(s: s)
            cornerBadge(s: s)

            postTerminal(s: s)
                .opacity(showPost ? 1 : 0)

            splash(width: width, s: s)
                .opacity(showSplash ? 1 : 0)
        }
    }

    /// The banner, the two rules, and nothing else.
    ///
    /// **No bottom pill.** The delivered mockup carried a `VINODEX HANDHELD
    /// SYSTEM` capsule down there; that exact string was `BiosChrome.system` and
    /// 0.8.0's B2 retired it along with the pill it sat in. Re-typing a retired
    /// string as a literal would put it back without the constant that recorded
    /// the decision, so the bottom bar is the rule's mirror instead.
    private func terminalChrome(s: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8 * s) {
                Text(BootSequence.header(version: AppVersion.current))
                    .foregroundStyle(BiosInk.cream)
                Spacer(minLength: 0)
                Text(BiosChrome.copyright(releaseDate: FirmwareCatalog.shared.current?.date))
                    .foregroundStyle(BiosInk.gold)
            }
            .font(.system(size: 9 * s, weight: .heavy, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            rule(s: s)
            Spacer(minLength: 0)
            rule(s: s)
        }
        .padding(.horizontal, 16 * s)
        .padding(.vertical, 12 * s)
        .opacity(showChrome ? 1 : 0)
    }

    private func rule(s: CGFloat) -> some View {
        Rectangle()
            .fill(BiosInk.magenta)
            .frame(height: max(2 * s, 1))
            .shadow(color: BiosInk.magenta, radius: 4 * s)
            .padding(.vertical, 4 * s)
    }

    /// The old-timey mark, top-right — `Logo/vinodex-logo.png`, the square badge
    /// version of the wordmark that has been in the tree since 0.7.5's A5 drop
    /// and has never had a call site.
    ///
    /// Desaturated a little, because the badge ships in full colour and this
    /// screen has three inks. Falls back to a lozenge rather than to nothing:
    /// `assertAssetsExist` does not walk loose `Logo/` PNGs, so a missing file
    /// here would be silent.
    private func cornerBadge(s: CGFloat) -> some View {
        Group {
            if let badge = BootBadgeArt.badge {
                Image(uiImage: badge)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .saturation(0.7)
            } else {
                Image(systemName: "seal.fill")
                    .font(.system(size: 22 * s))
                    .foregroundStyle(BiosInk.gold)
            }
        }
        .frame(width: 34 * s, height: 34 * s)
        .bioBloom(BiosInk.gold, 6 * s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 30 * s)
        .padding(.trailing, 18 * s)
        .opacity(showChrome ? 0.9 : 0)
    }

    // MARK: Phase one — the POST

    /// `BootSequence`'s table, one row at a time.
    ///
    /// Dot leaders are drawn rather than baked into the label, so the two
    /// columns stay a label and a result — which is what `BootLine` models and
    /// what makes the verbose cheat's two extra rows line up with the three
    /// ordinary ones without anybody counting periods.
    private func postTerminal(s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6 * s) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                HStack(spacing: 0) {
                    Text(line.label)
                        .foregroundStyle(BiosInk.cream)
                    Text(" " + String(repeating: ".", count: max(2, 22 - line.label.count)) + " ")
                        .foregroundStyle(BiosInk.magenta)
                    Text(line.result)
                        .foregroundStyle(BiosInk.gold)
                }
                .font(.system(size: 12 * s, weight: .heavy, design: .monospaced))
                .shadow(color: BiosInk.cream.opacity(0.5), radius: 4 * s)
                .opacity(index < postShown ? 1 : 0)
            }

            Text("STARTING VINODEX...")
                .font(.system(size: 12 * s, weight: .heavy, design: .monospaced))
                .foregroundStyle(BiosInk.magenta)
                .shadow(color: BiosInk.magenta.opacity(0.6), radius: 4 * s)
                .padding(.top, 10 * s)
                .opacity(postShown >= lines.count ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 34 * s)
        .padding(.top, 58 * s)
    }

    // MARK: Phase two — the identity splash

    private func splash(width: CGFloat, s: CGFloat) -> some View {
        VStack(spacing: 3 * s) {
            BootMark()
                .frame(height: 118 * s)
                .bioBloom(BiosInk.magenta, 14 * s)
                .scaleEffect(logoIn ? 1 : 0.4)
                .opacity(logoIn ? 1 : 0)

            wordmark(width: width, s: s)
                .opacity(wordIn ? 1 : 0)

            Rectangle()
                .fill(BiosInk.magenta)
                .frame(width: width * 0.55, height: max(2 * s, 1))
                .shadow(color: BiosInk.magenta, radius: 6 * s)
                .opacity(dividerIn ? 0.9 : 0)
                .padding(.vertical, 6 * s)

            Text(BiosChrome.tagline)
                .font(DexFont.retroFixed(9 * s))
                .tracking(2 * s)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(BiosInk.gold)
                .shadow(color: BiosInk.gold.opacity(0.6), radius: 6 * s)
                .opacity(tagIn ? 1 : 0)

            // The same glyph 0.7.7's identity stack ended on, and the same
            // reason `outlined` is off: `PixelOutline`'s eight black shadows are
            // a smear on a near-black ground.
            DexIcon(
                iconID: "game-icons:wine-glass",
                size: 26 * s,
                color: BiosInk.cream,
                outlined: false
            )
            .opacity(glassIn ? 0.9 : 0)
            .padding(.top, 4 * s)

            (Text(BiosChrome.checkLabel + " ").foregroundColor(BiosInk.cream)
                + Text(BiosChrome.checkResult).foregroundColor(BiosInk.gold))
                .font(.system(size: 12 * s, weight: .heavy, design: .monospaced))
                .opacity(sysIn ? 1 : 0)

            Text(BiosChrome.prompt)
                .font(DexFont.retroFixed(8 * s))
                .tracking(1.5 * s)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(BiosInk.magenta)
                .shadow(color: BiosInk.magenta.opacity(0.7), radius: 5 * s)
                .opacity(promptIn ? (promptBlink ? 0.15 : 1) : 0)
                .padding(.top, 8 * s)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 16 * s)
    }

    /// The wordmark, with a specular sweep masked to its own letterforms.
    ///
    /// The mask is a second copy of the same view, which is why `mark` is bound
    /// once and used twice rather than called twice — the sheen has to be
    /// clipped by the exact glyph shapes, and two independently laid-out copies
    /// would drift by a subpixel and fringe.
    @ViewBuilder
    private func wordmark(width: CGFloat, s: CGFloat) -> some View {
        let mark = Text("VINODEX")
            .font(DexFont.retroFixed(28 * s))
            .tracking(2 * s)
            .foregroundStyle(chromeRamp)
            .shadow(color: BiosInk.magentaDeep, radius: 0, x: 2 * s, y: 2 * s)

        mark
            .overlay(
                GeometryReader { g in
                    LinearGradient(
                        colors: [
                            .clear, .white.opacity(0.95), .white, .white.opacity(0.95), .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: g.size.width * 0.30)
                    .rotationEffect(.degrees(16))
                    .offset(x: -g.size.width * 0.7 + sweepX * g.size.width * 1.6)
                    .frame(width: g.size.width, height: g.size.height, alignment: .leading)
                    .mask(mark.frame(width: g.size.width, height: g.size.height))
                    .blendMode(.screen)
                }
            )
            .bioBloom(BiosInk.gold, 10 * s)
    }

    // MARK: Behaviour

    /// Sleep until `offset` seconds after `start`, or return immediately if that
    /// moment has already passed. See the type note on why the schedule is
    /// absolute.
    private func hold(until offset: TimeInterval, from start: Date) async {
        let remaining = offset * rate - Date().timeIntervalSince(start)
        guard remaining > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
    }

    /// Reduce Motion gets the resting composition and the same timeout.
    ///
    /// Not "no boot screen": the screen still says what version is installed and
    /// how many entries loaded, and skipping it would mean the accessibility
    /// setting changed what the device reports about itself. What it loses is
    /// the CRT open, the staggered reveal and the sheen.
    private func settleImmediately() {
        crtOpen = true
        showChrome = true
        showSplash = true
        logoIn = true
        wordIn = true
        dividerIn = true
        tagIn = true
        glassIn = true
        sysIn = true
        promptIn = true
    }

    private func run() async {
        let start = Date()

        guard !reduceMotion else {
            settleImmediately()
            await hold(until: BootSequence.longestUntouched, from: start)
            finish()
            return
        }

        // Power-on: a flash, then the raster opens.
        withAnimation(.easeOut(duration: 0.10)) { flash = 0.7 }
        withAnimation(.easeOut(duration: 0.45)) { crtOpen = true }
        await hold(until: 0.12, from: start)
        withAnimation(.easeIn(duration: 0.28)) { flash = 0 }

        await hold(until: Self.chromeAt, from: start)
        withAnimation(.easeOut(duration: 0.30)) { showChrome = true }
        withAnimation(.easeOut(duration: 0.18)) { showPost = true }

        // The checks, each at the moment Core says it lands.
        for (index, line) in lines.enumerated() {
            await hold(until: line.at, from: start)
            withAnimation(.easeOut(duration: 0.12)) { postShown = index + 1 }
        }

        await hold(until: BootSequence.duration, from: start)
        withAnimation(.easeInOut(duration: 0.25)) { showPost = false }

        await hold(until: splashAt, from: start)
        withAnimation(.easeOut(duration: 0.10)) { showSplash = true }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.58)) { logoIn = true }
        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) { sweepX = 1 }

        await hold(until: splashAt + 0.24, from: start)
        withAnimation(.easeOut(duration: 0.30)) { wordIn = true }
        await hold(until: splashAt + 0.48, from: start)
        withAnimation(.easeOut(duration: 0.25)) { dividerIn = true }
        await hold(until: splashAt + 0.62, from: start)
        withAnimation(.easeOut(duration: 0.30)) { tagIn = true }
        await hold(until: splashAt + 0.76, from: start)
        withAnimation(.easeOut(duration: 0.30)) { glassIn = true }
        await hold(until: splashAt + 0.90, from: start)
        withAnimation(.easeOut(duration: 0.30)) { sysIn = true }
        await hold(until: splashAt + 1.08, from: start)
        withAnimation(.easeOut(duration: 0.30)) { promptIn = true }
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            promptBlink = true
        }

        // The ceiling. `BootSequence.longestUntouched` is the number
        // `neverTraps` pins, and this is the call site that makes it true.
        await hold(until: BootSequence.longestUntouched, from: start)
        finish()
    }

    /// Idempotent, because two things can reach it: a tap on this view, and
    /// `BootAdvanceCatcher` over the window. No haptic — the timeout arm would
    /// then buzz a device nobody has touched, which reads as a notification
    /// rather than as a screen ending.
    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

// MARK: - The mark

/// The shipped pixel "V", in two tinted layers.
///
/// Lifted from 0.7.7's `BiosMark` with the file it lived in. The two PNGs are
/// the master's lit face and its extruded edge, split on luminance at import
/// time (`scripts/import-logo-art.py`) and shipped as white-on-alpha templates —
/// so the colours are this screen's, applied here, exactly as the screensaver
/// applies the LCD's.
///
/// Falls back to a drawn glyph rather than to nothing: `IconLoader` and
/// `PixelArtLoader` both return nil silently, and `LogoLayerTests` is what makes
/// the fallback theoretical rather than what makes it unnecessary.
struct BootMark: View {
    var body: some View {
        if let face = ScreensaverMarkArt.face, let shade = ScreensaverMarkArt.shade {
            ZStack {
                layer(shade).foregroundStyle(BiosInk.magentaDeep)
                layer(face).foregroundStyle(
                    // A gradient on the ink rather than a second overlay: the
                    // scanline canvas is already drawing a raster over the top,
                    // and two scanline treatments on one element read as moire.
                    LinearGradient(
                        colors: [BiosInk.cream, BiosInk.cream.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .aspectRatio(ScreensaverMarkArt.aspect, contentMode: .fit)
        } else {
            // 0.7.3a's drawn letterform, kept as the fallback for the reason
            // `ScreensaverMark` keeps it: a mark that failed to load must not be
            // an empty gap in the middle of the first screen of the app. It
            // needs no asset and takes the same two inks.
            ZStack {
                VinodexV().fill(BiosInk.magentaDeep).offset(x: 4, y: 4)
                VinodexV().fill(BiosInk.cream)
            }
            .aspectRatio(1 / 1.05, contentMode: .fit)
        }
    }

    private func layer(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .interpolation(.none)
            .aspectRatio(contentMode: .fit)
    }
}

/// The square badge mark, loaded once.
///
/// A `static let` rather than a load per frame: the file is 650x650 and the boot
/// screen redraws it on every animation tick.
@MainActor
enum BootBadgeArt {
    static let badge: UIImage? = {
        guard let url = DexResources.url(named: "vinodex-logo", ext: "png", in: .logo),
              let image = UIImage(contentsOfFile: url.path)
        else { return nil }
        return image
    }()
}

// MARK: - CRT treatment

/// Horizontal scanlines at a fixed 3pt pitch.
///
/// A `Canvas` rather than a stack of `Divider`s or a repeating gradient: at this
/// pitch a gradient resamples into a moire against the display's own pixel grid,
/// and the canvas draws exactly the rows asked for.
private struct BiosScanlines: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(.black.opacity(0.28))
                )
                y += 3
            }
        }
        .blendMode(.multiply)
    }
}

/// The tube's falloff. Radii in points against a display region this app fixes
/// by construction, so they do not need to be derived.
private struct BiosVignette: View {
    var body: some View {
        RadialGradient(
            colors: [.clear, .black.opacity(0.55)],
            center: .center,
            startRadius: 10,
            endRadius: 520
        )
    }
}

// MARK: - Advancing

/// **The picture is in the display; the input is the window's** (0.7.8, A4).
///
/// Everything on the chassis is live and visible around the booting screen — the
/// footer buttons, the marquee lamps, and the island orb, which flips the device
/// on a one-second hold. A touch during boot must advance the BIOS rather than
/// press any of them, so this capture layer stays over the whole window even
/// though the composition does not.
///
/// A zero-distance `DragGesture` rather than `onTapGesture`, because §C2's
/// promise is that *any* input advances: a tap that turns into a drag is not a
/// tap, and a boot screen that ignored it would be a boot screen somebody could
/// get stuck on by swiping.
public struct BootAdvanceCatcher: View {
    let onAdvance: () -> Void

    public init(onAdvance: @escaping () -> Void) {
        self.onAdvance = onAdvance
    }

    public var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in onAdvance() }
            )
            .accessibilityHidden(true)
    }
}
#endif
