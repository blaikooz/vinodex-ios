#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

/// The retro handheld chassis that wraps every screen.
///
/// Re-proportions to fill the display rather than preserving the desktop
/// 522x850 box: bezel, vent and footer thicknesses stay fixed and the LCD
/// absorbs the remaining height. That matches what the CSS already does below
/// the `md:` breakpoint, so a phone sees the same layout the web app gives it.
public struct DeviceChassis<Content: View>: View {
    let title: String
    /// The page's marquee glyph, stamped between the banner's repetitions —
    /// see `MarqueeBanner.symbol`. Routed from `DexRoute.marqueeSymbol`.
    var marqueeSymbol: String?
    var showsBack: Bool = false
    var onBack: (() -> Void)?
    var onHome: (() -> Void)?
    /// Opens saved entries. On the main screen this takes the Back button's
    /// slot, which would otherwise be a permanently greyed-out control.
    var onBookmarks: (() -> Void)?
    /// Opens the settings screen.
    var onSettings: (() -> Void)?
    @ViewBuilder var content: () -> Content

    /// The system panel lives here rather than in the app module so it can be
    /// confined to the LCD — see `SettingsPanel`.
    /// Whether the device is showing its underside — see `DeviceBackPlate`.
    @State private var isFlipped = false
    /// Which face is *drawn*, stepped at the midpoint of the turn rather than
    /// following `isFlipped` directly — see the flip in `body`.
    @State private var showsBackFace = false
    /// The pending midpoint swap, cancelled if the flip is reversed before it
    /// lands. Without this, flipping back within the half-second leaves a stale
    /// task to fire afterwards and show the wrong face.
    @State private var flipSwapTask: Task<Void, Never>?

    /// Drives the orb's depress animation while the flip gesture is held.
    @State private var orbHeld = false
    /// Shared with `SettingsPanel` through `@AppStorage`, so toggling it there
    /// repaints the chassis without any state being threaded between them.
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    /// Read for VINTAGE mode's monochrome pass over the LCD — see `innerBezel`.
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue

    /// The chassis owns the app's two largest movements — the 0.7s 3D flip and
    /// the footer marquee — so this is where Reduce Motion has to be read.
    /// (AUDIT M18)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(
        title: String,
        marqueeSymbol: String? = nil,
        showsBack: Bool = false,
        onBack: (() -> Void)? = nil,
        onHome: (() -> Void)? = nil,
        onBookmarks: (() -> Void)? = nil,
        onSettings: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.marqueeSymbol = marqueeSymbol
        self.showsBack = showsBack
        self.onBack = onBack
        self.onHome = onHome
        self.onBookmarks = onBookmarks
        self.onSettings = onSettings
        self.content = content
    }

    private var isMainScreen: Bool { title == "VINODEX" }

    /// The main screen cycles its toasts as separate words — the banner gives
    /// every boundary between them the same gap it gives the wrap seam.
    private var footerSegments: [String] {
        isMainScreen ? ["CHEERS!", "SANTE!", "SALUTE!", "PROST!", "KANPAI!"] : [title]
    }

    private var footerSymbol: String? {
        isMainScreen ? "wineglass.fill" : marqueeSymbol
    }

    public var body: some View {
        // The whole chassis is laid out in physical-screen coordinates so the
        // top safe-area strip — the band containing the Dynamic Island — can be
        // used rather than wasted. Insets are then reserved explicitly.
        GeometryReader { geo in
            let topStrip = max(geo.safeAreaInsets.top, DexMetrics.islandStripMinHeight)

            ZStack {
                // Front and back are both mounted, each hidden when facing
                // away, and the pair is rotated together — the same structure
                // as the web app's preserve-3d flip container.
                //
                // The opacity swap is deliberately **not** animated with the
                // rotation. Sharing the 0.7s easing cross-faded the two faces
                // through each other, so for most of the turn you saw a ghost of
                // the LCD lying over the metal — which reads as a dissolve, not
                // as a panel being turned over. `flipSwap` steps at the midpoint
                // instead, when the plate is edge-on and the cut is invisible,
                // so the flip is purely physical.
                frontFace(topStrip: topStrip)
                    .opacity(showsBackFace ? 0 : 1)
                    .accessibilityHidden(isFlipped)

                DeviceBackPlate()
                    // Pre-rotated so it reads the right way round once the
                    // container has turned; without this it arrives mirrored.
                    //
                    // Which is exactly why it is conditional: under Reduce
                    // Motion the container does not turn, so a fixed 180° here
                    // would leave the back plate permanently mirrored — the
                    // engraved VINODEX wordmark reading backwards. The two
                    // rotations are one mechanism and have to be dropped
                    // together. (AUDIT M18)
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                    .opacity(showsBackFace ? 1 : 0)
                    .accessibilityHidden(!isFlipped)
                    // Swipe rather than tap, so returning is the same gesture
                    // in reverse. A tap gave no sense of the panel turning.
                    .gesture(
                        DragGesture(minimumDistance: 24)
                            .onEnded { value in
                                if abs(value.translation.width) > 60 {
                                    isFlipped = false
                                }
                            }
                    )
            }
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : (isFlipped ? 180 : 0)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.45
            )
            .animation(
                reduceMotion ? nil : Animation.easeInOut(duration: DexMetrics.flipDuration),
                value: isFlipped
            )
            // Hard cut at the halfway point: no duration, so the faces swap in
            // one frame rather than fading, and it lands while the plate is
            // edge-on so nothing is visibly on screen to pop.
            //
            // Under Reduce Motion there is no turn to hide the cut behind, so
            // the midpoint delay would just be half a second of nothing
            // happening. A short cross-fade replaces it — the one transition
            // Apple's guidance explicitly offers as the substitute for a
            // rotation. (AUDIT M18)
            .onChange(of: isFlipped) { _, flipped in
                flipSwapTask?.cancel()
                flipSwapTask = nil
                guard !reduceMotion else {
                    withAnimation(.easeInOut(duration: 0.2)) { showsBackFace = flipped }
                    return
                }
                flipSwapTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(DexMetrics.flipDuration / 2))
                    guard !Task.isCancelled else { return }
                    showsBackFace = flipped
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
        // The underlay, not the body: this layer never rotates with the flip,
        // so it must not show internals — under a translucent skin it is the
        // dark ground the smoke plastic needs, and elsewhere it is the body.
        .background(skin.underlay.ignoresSafeArea())
    }

    private func frontFace(topStrip: CGFloat) -> some View {
        ZStack(alignment: .top) {
            // The mock electronics sit behind the translucent shell and flip
            // with the front face — the back plate is its own opaque part.
            if skin.isTranslucent {
                InternalsView()
            }
            ChassisShell(skin: skin)

            VStack(spacing: 0) {
                Color.clear.frame(height: topStrip)
                screenHousing
                    // Minimal, equal gap to both bands.
                    .padding(.vertical, DexMetrics.housingGap)
                footer()
            }

            islandFlank(height: topStrip)
        }
    }

    // MARK: Island flank
    //
    // Orb in the left corner, the status-lamp trio in the right corner, both
    // level with the hardware cutout. This band is otherwise dead chassis, so
    // using it costs the LCD nothing; what *did* cost the LCD was sizing the
    // band itself.
    //
    // **The top branding is gone (0.6.6, D1).** The pixel wordmark and the
    // trapezoidal lip it sat in — 0.6.5's item 4, itself the redo of a redo —
    // are deleted. One device carries one wordmark; it is in the bottom strip
    // of the screen housing since 0.6.7 (H1).
    //
    // **The row moved up into the notch band (0.6.6, E3).** The orb and lamps
    // used to hang from the *bottom* of the strip at full control diameter,
    // which forced `islandStripMinHeight` to 84pt on a device that only reserves
    // 59 — 25pt of LCD spent on clearance nobody asked for. They sit level with
    // the cutout now and the strip is sized to that instead.
    //
    // **The two red housing lamps have left (0.6.7, F1).** 0.6.6 put them on
    // bare chassis below the cutout, and bare chassis is *outside* the screen
    // housing — which is exactly what the device reported: two lamps floating
    // off the LCD's border. They are anchored to the bezel plate now (see
    // `innerBezel`), and the 10pt band they needed down here goes with them.
    // That 10pt is what pays for F2's larger orb, with change: the strip's
    // floor drops below the 59pt a Dynamic Island already reserves, so it stops
    // being the binding constraint at all.
    //
    // Rendering *in* the cutout is not an option, for the record: the island is
    // hardware, the OS masks anything drawn under it, and putting content there
    // means a Live Activity — ActivityKit plus a widget-extension target, which
    // a SwiftPM/xtool project has no way to add. Flanking it is the whole
    // available move.

    private func islandFlank(height: CGFloat) -> some View {
        // The notch-level row. Clamped only for a device that reports a
        // shorter inset than `islandStripMinHeight` asks for.
        let slot = min(DexMetrics.islandSlot, max(height - DexMetrics.islandBottomInset, 0))

        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                lcdOrb(size: DexMetrics.islandOrb)
                    .scaleEffect(orbHeld ? 0.88 : 1)
                    .brightness(orbHeld ? -0.18 : 0)
                    .animation(.easeOut(duration: 0.12), value: orbHeld)
                    // The bead is smaller than the slot on purpose: shrinking a
                    // control's art is not a licence to shrink its touch area,
                    // so the hit shape stays a full 44pt circle around it.
                    .frame(width: slot, height: slot)
                    .contentShape(Circle())
                    // Hold to flip. A hidden gesture on a decorative-looking
                    // part is a poor primary affordance, but this one is a
                    // deliberate easter egg: the orb depresses under the finger
                    // so the feedback arrives before the flip does.
                    //
                    // One second, down from two. Two is long enough that someone
                    // who already knows the gesture assumes it has stopped
                    // working and lets go early — the orb depressing gives
                    // immediate feedback, so the hold only has to be long enough
                    // not to fire on a tap.
                    .onLongPressGesture(minimumDuration: 1.0) {
                        Haptics.tap()
                        orbHeld = false
                        isFlipped = true
                    } onPressingChanged: { pressing in
                        orbHeld = pressing
                        if pressing { Haptics.orbPress() }
                    }

                // The cutout's clearance. Nothing is drawn under it, so this is
                // simply the gap the corner is held clear by — a fixed width
                // rather than a `Spacer`, which is what makes the trio's slot
                // below a measurable region instead of whatever is left after
                // the spacer has pushed it against the trailing padding.
                Color.clear
                    .frame(width: DexMetrics.islandClearance, height: 1)

                // The three skin-tinted lamps (0.6.5, C1), **centred in the
                // top-right corner** since 0.6.7 (F3) rather than hung off the
                // trailing padding. The corner is everything to the right of
                // the cutout's clearance; giving the trio that whole region and
                // centring it in it is what stops the cluster reading as three
                // lamps shoved into the edge of the display. Vertically they
                // stay on the orb's line, so the two corners still read as a
                // pair flanking the cutout.
                statusDots(size: DexMetrics.islandStatusDot)
                    // Decoration only, and never a touch target sitting next
                    // to one.
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity)
                    .frame(height: slot, alignment: .center)
            }
            .frame(height: slot)
            .padding(.top, DexMetrics.islandTopInset)

            // Any extra strip height — a device reporting a deeper inset than
            // we ask for — lands here rather than reopening the gap to the
            // screen housing.
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DexMetrics.islandFlankPaddingH)
        .padding(.bottom, DexMetrics.islandBottomInset)
        .frame(height: height)
    }

    /// The settings cog.
    ///
    /// Was the pixel-V wordmark, which looked like branding and so read as
    /// decoration — nobody expects a logo to be tappable. A cog states what it
    /// does.
    /// On the skin's caps (v0.5.4, reversing 0.5.3's mode livery) — see the
    /// note on `ChassisButton`.
    ///
    /// **The glyph follows the skin too since 0.6.6 (F1).** It used to carry a
    /// hardcoded brushed-silver gradient, on the argument that a cog is a
    /// machined part whatever the shell. The cap underneath was always the
    /// skin's — `ChassisControl` gives BLUSH a pink one — but at
    /// `bandControlSmall` the glyph is most of what you see, so a fixed silver
    /// gear on a pink cap read as an unskinned grey button. It takes
    /// `control.glyph` now, exactly like Back and User, which is what makes the
    /// four caps read as one set of parts.
    ///
    /// **Full size since 0.6.7 (G2).** It lived in the band at
    /// `bandControlSmall` from 0.6.5 (A3) — the one control the mockup drew
    /// smaller than its neighbours — and G2 moves it under User at User's own
    /// diameter, which retires the exception and puts every physical control in
    /// the footer back on one size. Still takes its diameter as an argument
    /// rather than reading the metric, so the size stays the caller's decision.
    ///
    /// The cap takes the skin's per-button colour where the skin defines one
    /// (0.6.7, K2/K3) and the shared moulded cap otherwise.
    private func settingsButton(size: CGFloat) -> some View {
        let cap = skin.buttonSet?.settings ?? skin.control

        return Button {
            Haptics.tap()
            onSettings?()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(cap.glyph)
                .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 1)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [cap.top, cap.bottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .overlay(
                    Circle().strokeBorder(
                        cap.edge,
                        lineWidth: 2
                    )
                )
                .shadow(
                    color: .black.opacity(DexMetrics.bandShadowOpacity),
                    radius: DexMetrics.bandShadowRadius,
                    y: DexMetrics.bandShadowY
                )
                .contentShape(Circle())
        }
        .buttonStyle(DexPressStyle(scale: 0.9))
        .accessibilityLabel("Settings")
    }

    private func lcdOrb(size: CGFloat) -> some View {
        Circle()
            .fill(skin.orb)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.white, lineWidth: max(size * 0.07, 2)))
            .overlay(alignment: .top) {
                // Specular highlight, kept proportional to the orb.
                Circle()
                    .fill(.white.opacity(0.8))
                    .frame(width: size * 0.26, height: size * 0.26)
                    .blur(radius: 1)
                    .padding(.top, size * 0.1)
            }
            .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
            .modifier(PulseGlow(color: skin.orbGlow, period: 5.3, minRadius: 2, maxRadius: size * 0.3))
    }

    private func statusDots(size: CGFloat) -> some View {
        // Every skin runs its own lamp trio — see `ChassisSkin.statusLights`.
        let lights = skin.statusLights

        return HStack(spacing: DexMetrics.statusDotSpacing) {
            statusDot(lights[0].fill, border: lights[0].border, period: 6.1, size: size)
            statusDot(lights[1].fill, border: lights[1].border, period: 7.4, size: size)
            statusDot(lights[2].fill, border: lights[2].border, period: 4.8, size: size)
        }
    }

    private func statusDot(_ fill: Color, border: Color, period: Double, size: CGFloat) -> some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(border, lineWidth: 1))
            .modifier(PulseGlow(color: fill, period: period, minRadius: 1, maxRadius: size * 0.7))
    }

    // MARK: Screen

    private var screenHousing: some View {
        // The moulded housing: a thin top margin, the LCD, and the vent strip.
        // The two red lamps that used to squat in the top margin moved up onto
        // bare chassis in 0.6.6 (D1) — see `islandFlank` — which is why that
        // margin is now the thinnest thing that still reads as moulding.
        VStack(spacing: 0) {
            Color.clear
                .frame(height: DexMetrics.bezelTopMargin)
            innerBezel
            bottomVents
        }
        // **The fill is the chamfered shape, not a rectangle behind one
        // (0.6.6, E1).** `.background(skin.panel)` painted a full rect and left
        // `clipShape` to cut the diagonal off it; a clip and a stroke antialias
        // independently, so on the one edge that is neither horizontal nor
        // vertical their two soft edges did not coincide and the white fill
        // showed through as a sliver outside the cut. Filling the shape itself
        // means there is no white out there to leak in the first place, and the
        // `compositingGroup` flattens fill, contents and rim into one layer so
        // the clip cuts them together rather than one at a time.
        .background { screenPanelShape.fill(skin.panel) }
        .overlay {
            screenPanelShape
                .strokeBorder(skin.panelEdge, lineWidth: DexMetrics.screenPanelBorder)
        }
        .compositingGroup()
        .clipShape(screenPanelShape)
        // NOCTURNE's charge: the housing rim glows softly. Two stacked shadows
        // — a tight one and a wide one — read as phosphor rather than as a drop
        // shadow. Cast from *behind* the housing since 0.6.6, because the clip
        // above would otherwise eat the halo it is supposed to spill onto the
        // chassis; the opaque housing hides the plate it is cast from.
        .background {
            screenPanelShape
                .fill(skin.rimGlow ?? .clear)
                .shadow(color: skin.rimGlow?.opacity(0.9) ?? .clear, radius: 6)
                .shadow(color: skin.rimGlow?.opacity(0.5) ?? .clear, radius: 16)
        }
        .padding(.horizontal, DexMetrics.screenPanelInset)
        .frame(maxHeight: .infinity)
    }

    /// The housing's outline: rounded on three corners, chamfered on the
    /// bottom-left (0.6.5, C2). One value so the fill, the clip and the stroked
    /// rim cannot drift apart — the previous pass shrank the bottom-left
    /// *radius* to 2, which is a tighter arc, not the diagonal cut the mockup
    /// shows.
    private var screenPanelShape: ChamferedPanel {
        ChamferedPanel(
            corner: DexMetrics.screenPanelCorner,
            chamfer: DexMetrics.screenPanelChamfer
        )
    }

    private var ventDot: some View {
        Circle()
            .fill(Dex.red500)
            .frame(width: DexMetrics.ventDot, height: DexMetrics.ventDot)
            .overlay(Circle().strokeBorder(Dex.red800, lineWidth: 1))
            .shadow(color: Dex.red500.opacity(0.8), radius: 3)
    }

    private var innerBezel: some View {
        ZStack {
            // The panel ground rather than a fixed near-black: the themed
            // modes (BLUE SCREEN especially) must not flash grey behind a
            // screen that has not painted yet.
            lcd.panelGround

            // **The LCD's size is the housing's, never the content's**
            // (0.6.7, I1).
            //
            // `content()` used to sit in this `ZStack` directly, which made the
            // display exactly as tall as whatever screen was mounted in it.
            // Almost every screen is a `ScrollView` and reports back whatever
            // height it is offered, so this went unnoticed for a year — but the
            // DATA panel is a fixed page (0.6.4, C2), and a fixed page is a
            // stack of subviews with real minimum heights. When their sum
            // exceeded the display the `ZStack` reported the larger number, the
            // `.frame(maxHeight: .infinity)` below passed it straight through
            // (a flexible frame clamps its child's *proposal*, not its
            // *result*), and the screen housing grew to fit. Opening SETTINGS >
            // DATA visibly resized the LCD, and every other page inherited the
            // new size until you left it.
            //
            // A `Color` is the one thing that always reports exactly the size it
            // was proposed, and `.overlay` sizes itself to its base — so the
            // content is proposed the display's real bounds and cannot report
            // anything else back. Anything that still overflows is clipped by
            // the `clipShape` below, which is what a physical display does to
            // an image too large for it. Fixing it here rather than pinning a
            // height on the data page is the point: the next fixed page cannot
            // reintroduce this.
            Color.clear.overlay { content() }

            // Confined to the LCD, so the bezel, footer and island stay put and
            // the panel reads as the device's own menu rather than an iOS modal.
            ScanlineOverlay()
                .opacity(DexMetrics.scanlineOpacity)
                .allowsHitTesting(false)
        }
        // The monochrome modes: desaturate everything on the LCD, then tint
        // the lot — grey-green for VINTAGE, amber phosphor for AMBER. Done
        // here, over the whole display, because it is the only way entry art,
        // chips and glyph tints — none of which read LcdMode — go monochrome
        // too. Identity (grayscale 0, multiply white) in the colour modes.
        .grayscale(lcd.monochromeTint == nil ? 0 : 1)
        .colorMultiply(lcd.monochromeTint ?? .white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DexMetrics.bezelCorner))
        // A thin stone frame, equal on every side so the LCD sits centred.
        // Note this is deliberately small: padding here costs LCD height, and
        // a uniform `bezelInsetH` (12pt) took 24pt of vertical space away.
        .padding(DexMetrics.bezelFrame)
        // …except along the top, where the plate thickens into the strip that
        // seats the two red housing lamps (0.6.7, F1). Paid for out of
        // `bezelTopMargin` point for point, so the housing is the same height
        // it was and the LCD loses nothing. See `bezelLampStrip`.
        .padding(.top, DexMetrics.bezelLampStrip - DexMetrics.bezelFrame)
        .background(
            RoundedRectangle(cornerRadius: DexMetrics.bezelCorner + DexMetrics.bezelFrame)
                .fill(Dex.stone800)
        )
        // The lamps themselves, **on the border** — anchored to the bezel plate
        // rather than to the chassis, which is the whole of F1. They have now
        // lived in three places (the housing's white margin, bare chassis under
        // the cutout, here); this is the only one of the three that is actually
        // part of the LCD's frame, so it is the only one where "outside the
        // border" cannot happen again by construction. Centred, which is where
        // 0.6.5 had them and where a handheld's power/link pair belongs.
        .overlay(alignment: .top) {
            HStack(spacing: DexMetrics.bandPillSpacing) {
                ventDot
                ventDot
            }
            .allowsHitTesting(false)
            .frame(height: DexMetrics.bezelLampStrip)
        }
        // Horizontal only — this insets the housing without costing height.
        .padding(.horizontal, DexMetrics.bezelInsetH - DexMetrics.bezelFrame)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomVents: some View {
        HStack(spacing: 0) {
            // The lamp moves to the left end of the strip (0.6.5), where the
            // mockup has it — it was centred, which put it under the wordmark's
            // old slot. Held off the edge by the chamfer's run: at the lamp's
            // height the diagonal has eaten roughly `chamfer - ventStrip/2` of
            // the left edge, and a lamp inside that is a lamp cut in half.
            //
            // Nudged a further ~0.3 chamfers right in 0.6.6 (E2): it was
            // clearing the diagonal by the width of the lamp itself, which reads
            // as crowding the cut rather than as sitting beside it.
            ventDot
                .padding(.leading, DexMetrics.screenPanelChamfer * 1.2)

            // **The wordmark, third home (0.6.7, H1).**
            //
            // Title lip (0.6.5) → grille (0.6.6, D2) → here. The grille was the
            // right *idea* — the mockup does stamp it into the vent — and the
            // wrong slot: a 64pt gap between two slats is room for `retro(7)`
            // and nothing larger, and seven glyphs at seven points on a moulded
            // grey strip is a watermark, not a maker's mark. This slot is the
            // whole run of bottom strip between the red lamp and the grille,
            // which is four or five times the width, so the letters can be the
            // size the name deserves.
            //
            // Stretched rather than merely scaled: `StretchedWordmark` measures
            // the run and fills the slot independently in x and y, which on a
            // phone lands around 1.3× wider than tall. That is the pixel-type
            // look the brief asks for — a display face condensed the other way
            // — and it is also the only way one wordmark fits every screen
            // width without a per-device size table.
            StretchedWordmark(ink: skin.grill)
                .padding(.horizontal, DexMetrics.wordmarkInsetH)
                .padding(.vertical, DexMetrics.wordmarkInsetV)
                .allowsHitTesting(false)

            // The grille — plain slats again, now that the letters have their
            // own room.
            VStack(spacing: 3) {
                ventSlat
                ventSlat
                ventSlat
                ventSlat
            }
            .allowsHitTesting(false)
            // Pulled in off the panel's rounded corner, which the slats
            // were running into at their right end.
            .padding(.trailing, DexMetrics.headerPaddingH + DexMetrics.screenPanelCorner * 0.5)
        }
        .frame(height: DexMetrics.ventStripHeight)
    }

    /// One grille slat. Faint on purpose — the vent is texture, not a feature.
    private var ventSlat: some View {
        Capsule()
            .fill(skin.grill)
            .frame(width: 64, height: 2)
            .opacity(0.5)
    }

    // MARK: Footer — the button band
    //
    // Four physical controls around one display (0.6.5, A/B; restructured
    // 0.6.7, G): **two matching diagonal bundles** — User over Settings on the
    // left, Home over Back on the right — with the marquee panel and its two
    // indicator lamps between them.
    //
    // There is deliberately **no** primary action button. Select and OK are
    // screen taps, and a fifth circle down here would be a control with nothing
    // to do that still had to be reached around.

    private func footer() -> some View {
        HStack(alignment: .top, spacing: DexMetrics.bandSpacing) {
            userBundle

            // The centre: two lamps stacked over the marquee panel (B1, B2).
            // Stacking them is what drops the panel's centre line below the
            // buttons either side of it, which is the offset the mockup shows —
            // the panel is not nudged down, it is pushed down by its own lamps.
            //
            // **Centred in the chassis since 0.6.7 (F5)** — and by construction
            // rather than by an offset. The flanks used to be a lone 54pt
            // circle and a 105pt cluster, so this column's centre sat ~25pt
            // right of the device's. Two congruent bundles put the same width
            // on either side of it, so "centred in the row" and "centred in the
            // chassis" are now the same place. Nothing here does the centring;
            // the geometry stopped fighting it.
            VStack(spacing: DexMetrics.bandPillGap) {
                indicatorPills
                // The existing banner, restyled into the lit panel it now is —
                // one view, not a copy. See `MarqueeBanner`.
                MarqueeBanner(
                    segments: footerSegments,
                    symbol: footerSymbol,
                    fontSize: DexMetrics.marqueeTextSize,
                    // `showsBackFace`, not `isFlipped`: the front face stays
                    // fully visible through the first half of the turn, and
                    // freezing a marquee that is still on screen reads as a
                    // hang. This is the exact instant the face goes to
                    // `opacity 0`. (AUDIT M8)
                    paused: showsBackFace
                )
            }
            .frame(maxWidth: DexMetrics.marqueeMaxWidth)
            .frame(maxWidth: .infinity)

            navBundle
        }
        .frame(height: DexMetrics.bandHeight, alignment: .top)
        .padding(.horizontal, DexMetrics.footerPaddingH)
        // Asymmetric on purpose, and built from the two insets rather than
        // centred in a fixed height: tight to the screen housing above, full
        // `chassisEdgeInset` below so the home indicator has bare chassis to
        // land on. See `DexMetrics.footerHeight`.
        .padding(.top, DexMetrics.footerTopInset)
        .padding(.bottom, DexMetrics.chassisEdgeInset)
        .frame(maxWidth: .infinity)
        .background(skin.footerWash)
    }

    /// User over Settings, sunk into the left-hand well (0.6.7, G2).
    ///
    /// User keeps the top-leading corner it has held since 0.6.5's A1; Settings
    /// arrives from the right-hand cluster and takes the position below and
    /// *inboard* of it, so this bundle's diagonal leans toward the marquee.
    /// Its mirror image is `navBundle`.
    private var userBundle: some View {
        buttonBundle(side: .leading) {
            // User. It no longer shares a slot with Back — the band has had
            // room for both since 0.6.5, so the old "Back where there is
            // somewhere to go, saved entries otherwise" swap is gone and each
            // button is always where you left it.
            ChassisButton(kind: .bookmarks, size: DexMetrics.bandControl, enabled: onBookmarks != nil) {
                onBookmarks?()
            }
        } bottom: {
            // Settings, at User's own diameter (G2) rather than the small cap
            // it wore in the triangle.
            settingsButton(size: DexMetrics.bandControl)
        }
    }

    /// Home over Back, sunk into the right-hand well (0.6.7, G1).
    ///
    /// **This is 0.6.6's B1 triangle less its third member.** That pass packed
    /// Settings, Home and Back to mutual near-tangency; G2 takes Settings away
    /// to pair with User, which leaves the diagonal the mockup actually draws —
    /// Home at the top-trailing, Back below and inward from it, in the corner
    /// nearest the thumb. G1's well is what keeps the pair reading as one part
    /// now that there is no third circle holding the group together.
    ///
    /// Back is always mounted and greyed where there is nowhere to go, rather
    /// than vanishing: a control that disappears moves the ones around it, and
    /// having the bundle re-form itself between screens is worse than a dim
    /// button.
    private var navBundle: some View {
        buttonBundle(side: .trailing) {
            ChassisButton(kind: .home, size: DexMetrics.bandControl, enabled: onHome != nil) {
                isFlipped = false
                onHome?()
            }
        } bottom: {
            // Back acts on whatever is in front of you — with the device
            // flipped it turns it back over first, rather than navigating
            // underneath and appearing to do nothing.
            ChassisButton(kind: .back, size: DexMetrics.bandControl, enabled: showsBack || isFlipped) {
                if isFlipped {
                    isFlipped = false
                } else {
                    onBack?()
                }
            }
        }
    }

    /// Which way a bundle's diagonal leans. Both lean *inward* at the bottom,
    /// so the two wells point at each other across the marquee.
    private enum BundleSide {
        /// Top button at the leading edge, bottom button below-and-right.
        case leading
        /// Top button at the trailing edge, bottom button below-and-left.
        case trailing
    }

    /// Two controls on a diagonal in one elongated pill-shaped recess
    /// (0.6.7, G1/G2) — the SNES face recess that groups X and Y.
    ///
    /// Laid out by offset against an explicitly sized transparent plate rather
    /// than by stacks. Overlapping bounding boxes have no stack arrangement, and
    /// the plate is what gives the footer's `HStack` a width to measure — the
    /// offset children contribute none.
    ///
    /// The well is a `Capsule` as long as the pair's centre separation plus one
    /// padded diameter, which makes it the exact convex hull of the two padded
    /// caps: its bounding box *is* the bundle's, so rotating it to the diagonal
    /// costs the band no extra room. Its centre is the midpoint of the two
    /// button centres, which by that construction is the plate's centre — so it
    /// needs no offset of its own, only the rotation.
    private func buttonBundle<Top: View, Bottom: View>(
        side: BundleSide,
        @ViewBuilder top: () -> Top,
        @ViewBuilder bottom: () -> Bottom
    ) -> some View {
        let pad = DexMetrics.bandWellPad
        let dx = DexMetrics.bandBundleDX
        let dy = DexMetrics.bandBundleDY
        // Down-and-right for the leading bundle, down-and-left for the trailing
        // one. Sign is the only difference between the two mirror images.
        let lean: CGFloat = side == .leading ? 1 : -1
        let topX = side == .leading ? pad : pad + dx
        let bottomX = topX + lean * dx

        return ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: DexMetrics.bandBundleWidth, height: DexMetrics.bandBundleHeight)

            // Sized to the plate so the rotated capsule centres on it — the
            // well's own layout box is its unrotated length × thickness, and
            // `rotationEffect` turns it about that box's centre.
            ButtonWell(angle: .radians(atan2(Double(dy), Double(lean * dx))))
                .frame(width: DexMetrics.bandBundleWidth, height: DexMetrics.bandBundleHeight)

            top()
                .offset(x: topX, y: pad)

            bottom()
                .offset(x: bottomX, y: pad + dy)
        }
        .frame(width: DexMetrics.bandBundleWidth, height: DexMetrics.bandBundleHeight)
    }

    /// The marquee's two indicator lamps (0.6.5, B2): a red and a blue pill,
    /// centred over the panel they belong to.
    ///
    /// Fixed red and blue rather than skin-tinted, unlike the trio in the top
    /// corner: these are the same bulbs as the vent lamp — the chassis's plain
    /// power/link indicators — and the skin's own colours are already spoken for
    /// by the lamps upstairs. Pills, not circles, so they cannot be mistaken at
    /// a glance for very small buttons.
    ///
    /// **As wide as the marquee since 0.6.7 (F4)**, and measured off it rather
    /// than given a width: the pair sits in the marquee's own column, so two
    /// pills each taking half of it less the gap span the panel exactly at any
    /// screen width and any `UIScale`. The two fixed widths this replaces (18pt,
    /// then 30) were each only ever right on one phone.
    private var indicatorPills: some View {
        HStack(spacing: DexMetrics.bandPillSpacing) {
            indicatorPill(Dex.red500, border: Dex.red800)
            indicatorPill(Dex.blue, border: Color(dexHex: "#0B6FA8"))
        }
        .frame(maxWidth: .infinity)
        // Decoration sitting directly above a live control: never a target.
        .allowsHitTesting(false)
    }

    private func indicatorPill(_ fill: Color, border: Color) -> some View {
        Capsule()
            .fill(fill)
            .frame(maxWidth: .infinity)
            .frame(height: DexMetrics.bandPillHeight)
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
            .modifier(
                PulseGlow(
                    color: fill,
                    period: 5.7,
                    minRadius: 1,
                    maxRadius: DexMetrics.bandPillHeight
                )
            )
    }
}

/// The recess a button bundle sits in (0.6.7, G1).
///
/// An SNES face recess: a stadium milled into the deck, the two caps sitting in
/// it on a diagonal. Drawn as shading rather than in any skin colour — a dark
/// floor, a soft dark wall along the top edge where no light reaches, and a
/// bright lip along the bottom where it does — so it works over every one of the
/// eighteen shells without a per-skin table. That is the same reasoning the
/// chassis already applies to the caps' own drop shadows and specular
/// highlights: shading is a property of the light, not of the plastic.
private struct ButtonWell: View {
    let angle: Angle

    var body: some View {
        Capsule()
            .fill(.black.opacity(0.20))
            .overlay(
                // The wall. Blurred because a recess has a radius; a crisp
                // stroke reads as a printed outline.
                Capsule()
                    .strokeBorder(.black.opacity(0.30), lineWidth: 2.5)
                    .blur(radius: 1.2)
            )
            .overlay(
                // The lip catching the same light the caps do.
                Capsule()
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                    .offset(y: 1.5)
            )
            .frame(width: DexMetrics.bandWellLength, height: DexMetrics.bandWellThickness)
            .rotationEffect(angle)
            .allowsHitTesting(false)
    }
}

/// The screen housing's silhouette (0.6.5, C2): rounded on three corners, with
/// a straight diagonal cut across the bottom-left.
///
/// A keyed corner, the way a moulded part is cut so it only seats one way
/// round — and the one asymmetry in an otherwise mirror-symmetric chassis,
/// which is what makes the device read as a manufactured object rather than a
/// drawn rectangle.
///
/// `InsettableShape` because the housing's rim is a `strokeBorder`, which needs
/// to inset the shape rather than stroke it centred — a centred stroke would
/// spill half its width past the clip and leave the chamfer's edge ragged.
private struct ChamferedPanel: InsettableShape {
    var corner: CGFloat
    var chamfer: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        guard r.width > 0, r.height > 0 else { return Path() }

        let limit = min(r.width, r.height) / 2
        let c = min(corner, limit)
        let ch = min(chamfer, limit)

        var p = Path()
        // Anticlockwise from the chamfer's foot on the bottom edge; the closing
        // segment back to it *is* the diagonal.
        p.move(to: CGPoint(x: r.minX + ch, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        p.addArc(
            tangent1End: CGPoint(x: r.maxX, y: r.maxY),
            tangent2End: CGPoint(x: r.maxX, y: r.maxY - c),
            radius: c
        )
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
        p.addArc(
            tangent1End: CGPoint(x: r.maxX, y: r.minY),
            tangent2End: CGPoint(x: r.maxX - c, y: r.minY),
            radius: c
        )
        p.addLine(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addArc(
            tangent1End: CGPoint(x: r.minX, y: r.minY),
            tangent2End: CGPoint(x: r.minX, y: r.minY + c),
            radius: c
        )
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - ch))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> ChamferedPanel {
        var copy = self
        copy.inset += amount
        return copy
    }
}

// `TitleLip` retired in 0.6.6 (D1): the top wordmark it was built to seat is
// gone, and the only wordmark on the device is in the housing's bottom strip
// instead — see `bottomVents` and `StretchedWordmark`.

/// The bottom strip's VINODEX wordmark (0.6.7, H1): the run measured, then
/// stretched to fill whatever slot the strip leaves it.
///
/// **Measured rather than predicted**, for the reason `MarqueeBanner` documents
/// at length: `UIFont` metrics and SwiftUI's own `Text` layout do not agree, the
/// error scales with the string's length, and this file has already lost several
/// rounds to that disagreement. A `Text` reporting its own laid-out size cannot
/// disagree with itself.
///
/// The two axes are scaled **independently** on purpose. A uniform fit would
/// leave the wordmark as tall as a seven-glyph run allows and no wider, which on
/// a wide strip is a small label floating in a lot of moulding; scaling x and y
/// to their own slots fills the space and produces the condensed-the-other-way
/// letterform the brief asks for. The stretch factor is a consequence of the
/// geometry rather than a number to tune — on a 393pt phone it lands near 1.3.
///
/// `scaleEffect` and not a larger font: a geometry effect does not change the
/// view's layout size, so the strip's `HStack` still measures the natural run
/// and the lamp and grille either side of it cannot be pushed around by the
/// scale. Sizing the font to fit would need a solve; this needs one division.
private struct StretchedWordmark: View {
    let ink: Color

    /// The run's own laid-out size, from its own geometry.
    @State private var natural: CGSize = .zero

    var body: some View {
        GeometryReader { slot in
            let sx = natural.width > 0 ? slot.size.width / natural.width : 1
            let sy = natural.height > 0 ? slot.size.height / natural.height : 1

            Text("VINODEX")
                .font(DexFont.retro(DexMetrics.wordmarkSize))
                // Tracking is what keeps the stretch civilised. It is applied
                // before the run is measured, so widening the natural letter
                // spacing is what brings the horizontal scale down toward the
                // vertical one — at 5 the two land about 1.3 apart, which is a
                // wordmark. Set solid, the same slot forces nearer 1.7, which
                // is a smear.
                .tracking(5)
                .lineLimit(1)
                .fixedSize()
                // The grille's own colour, at more opacity than the slats: the
                // wordmark is moulded into the same plate as the vent beside
                // it, and a wordmark that does not match the part it is cut
                // into reads as a sticker. The slats are deliberately faint;
                // this is the one thing in the strip meant to be read.
                .foregroundStyle(ink)
                .opacity(0.85)
                .background {
                    GeometryReader { run in
                        Color.clear
                            .onAppear { natural = run.size }
                            .onChange(of: run.size) { _, new in natural = new }
                    }
                }
                .scaleEffect(x: sx, y: sy, anchor: .center)
                .frame(width: max(slot.size.width, 0), height: max(slot.size.height, 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Chassis shell

/// The moulding itself: the skin's colour, plus its tileable pixel-art
/// pattern when it carries one (WINE XMAS's wrapping paper). The colour stays
/// underneath so a missing asset degrades to a plain shell, not a hole.
private struct ChassisShell: View {
    let skin: ChassisSkin

    var body: some View {
        ZStack {
            skin.body
            if let asset = skin.bodyPatternAsset,
               let image = ChassisPatternLoader.shared.image(asset) {
                Image(uiImage: image)
                    .resizable(resizingMode: .tile)
                    // Pixel art — filtering would smear the pattern.
                    .interpolation(.none)
            }
        }
    }
}

/// Loads bundled chassis patterns, cached — mirrors `FlagLoader`, misses
/// recorded so an absent asset is not re-probed every render.
@MainActor
private final class ChassisPatternLoader {
    static let shared = ChassisPatternLoader()

    private var cache: [String: UIImage?] = [:]

    private init() {}

    func image(_ name: String) -> UIImage? {
        if let hit = cache[name] { return hit }
        let loaded = DexResources.url(named: name, ext: "png", subdirectory: "Resources/Chassis")
            .flatMap { UIImage(contentsOfFile: $0.path) }
        cache[name] = loaded
        return loaded
    }
}

// MARK: - Chassis buttons

/// The physical-looking User, Home and Back buttons.
///
/// Haptics fire here rather than at call sites so every chassis button feels the
/// same — the main thing a native build can offer that the web app cannot.
public struct ChassisButton: View {
    /// `bookmarks` is the band's User button (0.6.5, A1). It used to take
    /// Back's slot on the main screen, where there was nowhere to go back to;
    /// the band gives it a slot of its own, so the two no longer trade places.
    public enum Kind { case back, home, bookmarks }

    let kind: Kind
    /// Diameter, passed rather than read from `DexMetrics`: the band sizes its
    /// controls itself (0.6.5), and the glyphs scale off whatever it asks for.
    let size: CGFloat
    let enabled: Bool
    let action: () -> Void

    /// Read here rather than passed down, the same way `DexToggle` reads the
    /// screen mode: the footer builds these, and threading it through would
    /// mean every future caller had to remember to.
    ///
    /// The *skin*, deliberately (v0.5.4, reversing 0.5.3): these are physical
    /// parts of the chassis, and physical parts belong to the colourway. A
    /// screen mode re-dressing the moulded buttons made every skin look like
    /// the same device the moment the LCD changed. On-LCD chrome (the search
    /// button, the settings tiles) still follows the mode — pixels on the
    /// screen are the screen's business.
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue

    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }

    public init(
        kind: Kind,
        size: CGFloat = DexMetrics.bandControl,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.kind = kind
        self.size = size
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            ZStack {
                Circle().fill(gradient)
                Circle().strokeBorder(borderColor, lineWidth: 3)
                icon
            }
            .frame(width: size, height: size)
            // Softened in 0.6.6 (B3) — see `DexMetrics.bandShadowOpacity`. The
            // old 0.6/6/8 cast a near-black plate roughly a quarter of a
            // diameter below each circle, which is a sticker's shadow, not a
            // moulded cap's.
            .shadow(
                color: .black.opacity(DexMetrics.bandShadowOpacity),
                radius: DexMetrics.bandShadowRadius,
                y: DexMetrics.bandShadowY
            )
        }
        .buttonStyle(DexPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(accessibilityLabel)
    }

    /// VoiceOver reads the SF Symbol otherwise — Saved announces as "person",
    /// and Back/Home are unlabeled. (audit H10)
    private var accessibilityLabel: String {
        switch kind {
        case .back: "Back"
        case .home: "Home"
        case .bookmarks: "Saved entries"
        }
    }

    /// This button's cap, taking the skin's per-button colour where the skin
    /// defines one (0.6.7, K2/K3) and the shared moulded cap otherwise. Home
    /// resolves through `accent` instead — see below.
    private var cap: ChassisControl {
        switch kind {
        case .back: skin.buttonSet?.back ?? skin.control
        case .bookmarks: skin.buttonSet?.bookmarks ?? skin.control
        // Never read for Home, which is built from a six-stop ramp; present so
        // the switch is exhaustive rather than optional-returning.
        case .home: skin.control
        }
    }

    /// Home's ramp: the console liveries give it its own, everything else uses
    /// the skin's single accent.
    private var homeAccent: ChassisAccent {
        skin.buttonSet?.home ?? skin.accent
    }

    private var gradient: LinearGradient {
        switch kind {
        case .back, .bookmarks:
            LinearGradient(colors: [cap.top, cap.bottom], startPoint: .top, endPoint: .bottom)
        case .home:
            LinearGradient(colors: [homeAccent.light, homeAccent.mid], startPoint: .top, endPoint: .bottom)
        }
    }

    private var borderColor: Color {
        switch kind {
        case .back, .bookmarks: cap.edge
        case .home: homeAccent.edge
        }
    }

    // Glyphs scale with the button's own diameter rather than carrying fixed
    // points, so resizing the band does not leave the same small icon floating
    // in a bigger circle.
    @ViewBuilder
    private var icon: some View {
        switch kind {
        // The glyphs are Vinodex's own and stay that way (0.6.7, K2/K3): the
        // console liveries take the four *colours* and nothing else. No
        // reference shape is reproduced here.
        case .back:
            Image(systemName: "chevron.left")
                .font(.system(size: size * 0.47, weight: .heavy))
                .foregroundStyle(cap.glyph)
        case .bookmarks:
            Image(systemName: "person.crop.circle")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(cap.glyph)
        case .home:
            Circle()
                .fill(LinearGradient(colors: [homeAccent.pale, homeAccent.bright], startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(homeAccent.mid, lineWidth: 1))
                .padding(2)
                .overlay {
                    Image(systemName: "house.fill")
                        .font(.system(size: size * 0.41, weight: .bold))
                        .foregroundStyle(homeAccent.ink)
                }
        }
    }
}

/// Chunky press feedback mirroring the web app's `active:scale` / `active:translate-y`.
public struct DexPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    public init(scale: CGFloat = 0.96) { self.scale = scale }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Effects

/// Repeating horizontal scanlines — the LCD's CRT texture.
public struct ScanlineOverlay: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: DexMetrics.scanlineThickness)),
                    with: .color(.black.opacity(0.5))
                )
                y += DexMetrics.scanlineSpacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// The LCD backdrop shared by every screen.
///
/// Exists as one view rather than per-screen copies so the main menu cannot
/// drift from the list and detail screens — they looked different because each
/// had its own colour and grid settings.
public struct DexScreenBackground: View {
    /// Read here rather than passed down: every screen uses this one view for
    /// its ground, so honouring the setting in one place covers all of them.
    @AppStorage(LcdMode.storageKey) private var modeRaw = LcdMode.dark.rawValue

    private var mode: LcdMode { LcdMode(rawValue: modeRaw) ?? .dark }

    public init() {}

    public var body: some View {
        ZStack {
            mode.ground
            DexGridBackground(
                spacing: 10,
                color: mode.gridLine,
                opacity: 0.35
            )
        }
        .ignoresSafeArea()
    }
}

/// Faint square grid used as an atmospheric LCD backdrop.
public struct DexGridBackground: View {
    var spacing: CGFloat
    var color: Color
    var opacity: Double

    public init(spacing: CGFloat = 30, color: Color = Dex.green, opacity: Double = 0.1) {
        self.spacing = spacing
        self.color = color
        self.opacity = opacity
    }

    public var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Replaces the CSS `lcd-pulse` / `dot-pulse-*` keyframes. The web versions use
/// irregular multi-stop timings; a symmetric ease here reads the same in motion.
struct PulseGlow: ViewModifier {
    let color: Color
    let period: Double
    let minRadius: CGFloat
    let maxRadius: CGFloat

    @State private var on = false
    /// The instances of this modifier are the *only* `repeatForever` animations
    /// in the app, so this one check is the whole of its perpetual motion.
    /// Frozen lit rather than frozen dark: the orb, the three status lamps and
    /// the button band's two indicator pills are meant to read as powered, and
    /// a dead-looking indicator lamp is a different message, not a calmer one.
    /// (AUDIT M18; overlaps L11)
    ///
    /// The audit counted four of these; 0.6.5's button band added the two pills
    /// (`indicatorPill`), which inherit the behaviour by construction — the
    /// check lives in the modifier, not at its call sites, which is the reason
    /// to keep it here. Everything else that animates in the chassis is a
    /// response to a touch (the orb's press, `DexPressStyle`'s spring) and
    /// stays: Reduce Motion asks for no *unprompted* movement.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .shadow(color: color.opacity(0.5), radius: (minRadius + maxRadius) / 2)
                // Un-latch. `on` is `@State` on the modifier itself, so it
                // survives this branch swap — without the reset, turning Reduce
                // Motion off again re-mounts the branch below, its `.onAppear`
                // writes `true` over `true`, and `.animation(_:value:)` sees no
                // change to animate. The lamps would come back stuck at full
                // glow, permanently, for someone who just asked for motion
                // *back*. Invisible here: this branch never reads `on`.
                .onAppear { on = false }
        } else {
            content
                .shadow(color: color.opacity(on ? 0.8 : 0.25), radius: on ? maxRadius : minRadius)
                .animation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true), value: on)
                .onAppear { on = true }
        }
    }
}

/// The scrolling marquee panel — the centrepiece of the button band. Ports
/// `terminal-marquee`: two copies of the label offset by one cycle, which loops
/// seamlessly.
///
/// **Lit, not backlit, since 0.6.5 (B1).** It used to be a black strip with the
/// skin's phosphor glowing on it, which is a VFD; the mockup's centrepiece is a
/// green *panel* with its letters dark — a segment LCD, where the ground is what
/// lights and the glyphs are what the liquid crystal blocks. So the two colours
/// swap: `marqueeText` fills the panel and `marqueeShadow` cuts the letters out
/// of it. Every skin follows, since both were already per-skin — CLASSIC's green
/// phosphor is what makes the panel green, and NOCTURNE's or BLUSH's panel is
/// its own colour rather than a green one bolted onto the wrong shell.
///
/// The animation is started from `onChange(of:)` rather than `onAppear` —
/// the label is measured by a background reader, so at `onAppear` the width is
/// still zero and the animation would never run.
public struct MarqueeBanner: View {
    /// The words the strip cycles. Most screens pass one segment — their
    /// title; the main screen passes its five toasts. Segments, not a single
    /// string, so every word boundary gets the same `gap` the wrap seam does
    /// (v0.5.7, E1) instead of whatever spacing was baked into the text.
    let segments: [String]
    /// SF Symbol stamped between repetitions — `SYSTEM ⟨gear⟩ SYSTEM ⟨gear⟩`
    /// (v0.5.7, E2). Nil runs text-only.
    let symbol: String?
    let fontSize: CGFloat
    var pointsPerSecond: Double = 34
    /// Stops the clock (AUDIT M8). The strip is inside the front face, which
    /// the flip merely hides at `opacity 0` — without this it kept redrawing at
    /// the display's refresh rate, forever, behind an opaque metal back plate.
    var paused: Bool = false

    /// The first copy's width, measured from its own laid-out geometry.
    ///
    /// Every previous version *predicted* this number — character count
    /// times a `UIFont`-measured cell (0.5.1), then the same corrected for
    /// the text-scale factor (0.5.4, audit M9) — and every prediction
    /// disagreed with SwiftUI's actual layout by a point or two: `NSString`
    /// metrics and SwiftUI `Text` rounding are not the same machinery, the
    /// error scaled with the label's length, and the seam skipped by exactly
    /// that error every lap. Measuring the rendered label itself cannot
    /// disagree with the rendered label. Until the first measurement lands
    /// the strip holds still (shift 0) rather than popping.
    @State private var copyWidth: CGFloat = 0

    /// Spacing between the two copies — part of the cycle geometry, scaled
    /// like the glyphs.
    ///
    /// Resolved in `init`, not per access (AUDIT M8). It was a computed
    /// property reading `TextScale.current`, which is a `UserDefaults` lookup,
    /// and the `TimelineView` closure touches it four times per frame — so a
    /// banner nobody is looking at was hitting the defaults store ~500×/s.
    /// `DeviceChassis` is `.id`-keyed on the text scale, so a change rebuilds
    /// this view rather than needing it re-read.
    private let gap: CGFloat
    /// Likewise: `DexFont.retro` reads `TextScale.current` on every call, and
    /// `label` is rebuilt inside the timeline closure on every frame.
    private let segmentFont: Font
    private let symbolSize: CGFloat

    /// The strip's phosphor follows the shell — see `ChassisSkin.marqueeText`.
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    /// A strip of text sliding sideways under the screen, on every screen, for
    /// as long as the app is open — the single most continuous movement in the
    /// app. Read here rather than passed in by `DeviceChassis` so the banner
    /// keeps working wherever else it is mounted. (AUDIT M18)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }

    /// The lit ground: the skin's phosphor, filling the panel rather than the
    /// letters (0.6.5, B1).
    private var ground: Color { skin.marqueeText }

    /// The letters and the panel's rim — the very dark form of the phosphor,
    /// which is what a segment LCD's glyphs actually look like.
    private var ink: Color { skin.marqueeShadow }

    public init(
        segments: [String],
        symbol: String? = nil,
        fontSize: CGFloat,
        pointsPerSecond: Double = 34,
        paused: Bool = false
    ) {
        self.segments = segments
        self.symbol = symbol
        self.fontSize = fontSize
        self.pointsPerSecond = pointsPerSecond
        self.paused = paused

        // Through the resolver, not `fontSize * TextScale.current.factor`:
        // since 0.6.4 a size floor sits between the two, so the hand-rolled
        // form can disagree with what `DexFont.retro` actually drew. The gap
        // and the symbol are laid out against the glyphs, and this file has
        // already lost three rounds to a marquee seam that skipped by exactly
        // such a disagreement (audit M8, M9).
        let pt = DexFont.resolvedSize(fontSize)
        self.gap = pt * 1.5
        self.segmentFont = DexFont.retro(fontSize)
        self.symbolSize = pt * 0.8
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner)
                .fill(ground)
                // The pixel grid now sits on the lit ground rather than over
                // black, so it reads as the panel's own segment structure —
                // `marqueeGrid` is a register off the phosphor either way, so
                // it still separates from the fill.
                .overlay(
                    DexGridBackground(spacing: 12, color: skin.marqueeGrid, opacity: 0.22)
                        .clipShape(RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner))
                )
                // A lit panel is brightest where the lamp behind it is: a touch
                // of ink settling toward the bottom is what stops the fill
                // reading as flat paint.
                .overlay(
                    LinearGradient(
                        colors: [.clear, ink.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner)
                        .strokeBorder(ink.opacity(0.8), lineWidth: 2)
                )
                // The panel's own glow, spilling onto the chassis around it —
                // the one thing that says this is a display and not a green
                // sticker.
                .shadow(color: ground.opacity(0.45), radius: 6)

            // Offset is a pure function of the clock, so it cannot drift and
            // cannot be restarted mid-run by a re-render. The cycle is one
            // measured copy plus the gap: the second copy starts exactly
            // there, so a wrap lands on identical pixels.
            // `paused:` and not simply unmounting the strip: the measured
            // `copyWidth` has to survive, or the flip back holds still at
            // shift 0 until the geometry reader lands again. Because of the
            // above, resuming needs no stored phase. (AUDIT M8)
            //
            // Reduce Motion stops the clock the same way the flip does, but it
            // cannot simply *pause* the strip: pinning a scrolling label at
            // shift 0 is only safe if the label fits, and these do not. A
            // scrolling label is allowed to overflow because the scroll is what
            // reveals its tail. Measured against the bundled Press Start 2P in
            // the strip's 256pt of usable width, DAILY CHALLENGE is 288pt at
            // the default text step, and at HUGE six of the app's ten page
            // titles overflow. So the still form is a different view — see
            // `staticLabel`. Taking the motion away must not take the words
            // with it. (AUDIT M18)
            TimelineView(.animation(paused: paused || reduceMotion)) { context in
                let cycle = copyWidth + gap
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let shift = (copyWidth > 0 && !reduceMotion)
                    ? CGFloat((elapsed * pointsPerSecond).truncatingRemainder(dividingBy: Double(cycle)))
                    : 0

                // The GeometryReader is load-bearing, not decoration: the
                // `.fixedSize()` label pair is ~1500pt wide for the main-menu
                // text, and without a *definite* width to clip against it
                // ignores `maxWidth` entirely, renders full-bleed across the
                // footer and squeezes the Back/user button out of the row.
                GeometryReader { strip in
                    Group {
                        if reduceMotion {
                            staticLabel
                        } else {
                            HStack(spacing: gap) {
                                label
                                    .background(
                                        GeometryReader { copy in
                                            Color.clear
                                                .onAppear { copyWidth = copy.size.width }
                                                .onChange(of: copy.size.width) { _, new in
                                                    copyWidth = new
                                                }
                                        }
                                    )
                                label
                            }
                            .offset(x: -shift)
                        }
                    }
                    .frame(
                        width: max(strip.size.width, 0),
                        height: max(strip.size.height, 0),
                        alignment: reduceMotion ? .center : .leading
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DexMetrics.marqueeInnerCorner))
                    // The end fade (0.6.6, C2). The strip is a window onto a
                    // loop longer than itself, so text *has* to leave it — the
                    // complaint was never that it scrolled but that the clip
                    // guillotined it, parking half a glyph hard against each
                    // edge. Masking the same clip with a gradient turns that
                    // into letters passing behind the housing, which is what a
                    // real segment panel with a bezel over it looks like.
                    //
                    // Masks the scrolling copies only, not the panel: the fill,
                    // its grid and its rim are a separate layer of the ZStack
                    // and must stay solid to their own edges.
                    .mask(alignment: .leading) { endFade(width: strip.size.width) }
                }
                .padding(4)
            }
        }
        .frame(height: DexMetrics.marqueeHeight)
    }

    /// The mask that softens both ends of the strip (0.6.6, C2).
    ///
    /// Built from the measured strip width rather than from relative stops:
    /// `marqueeFade` is one glyph cell, so the ramp has to be that many
    /// *points* long whatever the panel's width, or a narrow screen gets a fade
    /// that eats half the readable text and a wide one gets no fade at all.
    /// Degrades to a plain opaque mask if the strip is too narrow to hold two
    /// ramps, which is the only case where fading would hide everything.
    ///
    /// Zero ramp under Reduce Motion, which is the same degenerate case for a
    /// different reason: the fade exists to sell text *passing behind* the
    /// housing, and nothing passes. `staticLabel` is scaled to fit the strip
    /// exactly, so at the worst case (DAILY CHALLENGE at HUGE) it reaches both
    /// edges and a ramp would dim the first and last glyph of a label whose
    /// whole purpose is to be readable at a standstill. Kept as a width of 0
    /// rather than dropping the `.mask` so the still and moving forms are the
    /// same view with the same identity. (AUDIT M18)
    private func endFade(width: CGFloat) -> some View {
        let fade = reduceMotion ? 0 : min(DexMetrics.marqueeFade, max(width, 0) / 3)
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: fade / max(width, 1)),
                .init(color: .black, location: 1 - fade / max(width, 1)),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: max(width, 0))
    }

    /// The Reduce Motion form: one label, centred, still, and sized to fit.
    ///
    /// `minimumScaleFactor` rather than `.fixedSize()` — the whole point is
    /// that this one has to fit the strip rather than run past its edge, and
    /// the worst case (DAILY CHALLENGE at HUGE) needs about 0.7. Ellipsis
    /// behind that as a floor, so a longer title added later degrades to a
    /// visible truncation mark rather than to a word chopped mid-glyph.
    ///
    /// One segment, not all of them joined: the only multi-segment caller is
    /// the main screen's five toasts, and CHEERS/SANTE/SALUTE/PROST/KANPAI are
    /// five ways of saying one thing. Shrinking the strip to a fifth of its
    /// size to fit four synonyms would trade legibility for nothing.
    /// `ink` on `ground`, exactly as `label` does — **not** `skin.marqueeText`
    /// on `skin.marqueeShadow`. Those two swapped roles in 0.6.5 (B1) when the
    /// strip became a lit panel with its letters cut out of it: `marqueeText`
    /// is now the *panel fill*. Written against the pre-0.6.5 strip this drew
    /// the words in the colour of the surface behind them. The two forms have
    /// to read from the same two properties or they will drift again.
    private var staticLabel: some View {
        HStack(spacing: gap * 0.4) {
            Text(segments.first ?? "")
                .font(segmentFont)
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .truncationMode(.tail)
                .shadow(color: ground.opacity(0.7), radius: 0, x: 1, y: 1)

            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: symbolSize, weight: .bold))
                    .foregroundStyle(ink)
                    .shadow(color: ground.opacity(0.7), radius: 0, x: 1, y: 1)
            }
        }
        .padding(.horizontal, 6)
    }

    /// One full cycle of content: every segment, `gap` apart, with the page
    /// glyph closing it. Two copies of this sit `gap` apart in the strip, so
    /// the seam between them is indistinguishable from any internal boundary
    /// — which is what makes the loop read as endless.
    private var label: some View {
        HStack(spacing: gap) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Text(segment)
                    .font(segmentFont)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .fixedSize()
                    // A hard catch of the lit ground below-right, where the
                    // black drop shadow used to be. Same one-pixel trick,
                    // inverted with the panel: it is what makes the letters read
                    // as cut into the display rather than printed on it.
                    .shadow(color: ground.opacity(0.7), radius: 0, x: 1, y: 1)
            }
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: symbolSize, weight: .bold))
                    .foregroundStyle(ink)
                    .shadow(color: ground.opacity(0.7), radius: 0, x: 1, y: 1)
            }
        }
    }
}

/// The pixel-V wordmark, bundled from the web app's logo.
public struct LogoMark: View {
    public init() {}

    public var body: some View {
        if let url = DexResources.url(named: "vinodex-logo", ext: "png", subdirectory: "Resources/Logo"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Text("V")
                .font(DexFont.retro(16))
                .foregroundStyle(.white)
        }
    }
}
#endif
