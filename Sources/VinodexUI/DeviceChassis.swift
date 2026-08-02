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
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
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
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.45
            )
            .animation(.easeInOut(duration: DexMetrics.flipDuration), value: isFlipped)
            // Hard cut at the halfway point: no duration, so the faces swap in
            // one frame rather than fading, and it lands while the plate is
            // edge-on so nothing is visibly on screen to pop.
            .onChange(of: isFlipped) { _, flipped in
                flipSwapTask?.cancel()
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
    // Orb in the left corner, the status-lamp cluster in the right corner, both
    // level with the hardware cutout — and the two red housing lamps on the bare
    // chassis below it. This band is otherwise dead chassis, so using it costs
    // the LCD nothing; what *did* cost the LCD was sizing the band itself.
    //
    // **The top branding is gone (0.6.6, D1).** The pixel wordmark and the
    // trapezoidal lip it sat in — 0.6.5's item 4, itself the redo of a redo —
    // are deleted. One device carries one wordmark and it belongs in the grille
    // (D2), which is where the mockup always had it; the lip existed only
    // because there was nothing else to seat the letters in up here. Deleting
    // it is also what frees the slot the two red lamps needed: they had been
    // squatting in the screen housing's top margin for want of anywhere else.
    //
    // **The row moved up into the notch band (0.6.6, E3).** The orb and lamps
    // used to hang from the *bottom* of the strip at full control diameter,
    // which forced `islandStripMinHeight` to 84pt on a device that only reserves
    // 59 — 25pt of LCD spent on clearance nobody asked for. They sit level with
    // the cutout now, the orb shrunk to a bead and the lamps grown to something
    // legible, and the strip is sized to that instead.
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

                // The cutout's clearance. Nothing is drawn under it any more,
                // so this is simply the gap the two corners are held apart by.
                Spacer(minLength: DexMetrics.islandClearance)

                // The three skin-tinted lamps in the right corner (0.6.5, C1),
                // centred on the same line as the orb so the pair reads as
                // flanking the cutout rather than as two unrelated details.
                statusDots(size: DexMetrics.islandStatusDot)
                    // Decoration only, and never a touch target sitting next
                    // to one.
                    .allowsHitTesting(false)
                    .frame(height: slot, alignment: .center)
            }
            .frame(height: slot)
            .padding(.top, DexMetrics.islandTopInset)

            // Any extra strip height — a device reporting a deeper inset than
            // we ask for — lands here, between the cutout row and the lamps,
            // rather than reopening the gap to the screen housing.
            Spacer(minLength: 0)

            // The two red housing lamps (0.6.5), on the bare chassis between
            // the cutout and the bezel where the mockup draws them. They only
            // reach it in 0.6.6 (D1): the title lip used to occupy exactly
            // this slot, so they had been living in the housing's own top
            // margin — which is 6pt thinner now that they have left it.
            HStack(spacing: DexMetrics.bandPillSpacing) {
                ventDot
                ventDot
            }
            .allowsHitTesting(false)
            .frame(height: DexMetrics.islandLampRow)
            .padding(.bottom, DexMetrics.islandBottomInset)
        }
        .padding(.horizontal, DexMetrics.islandFlankPaddingH)
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
    /// Lives in the button band since 0.6.5 (A3), at `bandControlSmall` —
    /// the one control the mockup draws smaller than its neighbours. Still
    /// takes its diameter as an argument rather than reading the metric, so
    /// the size stays the caller's decision.
    private func settingsButton(size: CGFloat) -> some View {
        Button {
            Haptics.tap()
            onSettings?()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(skin.control.glyph)
                .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 1)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [skin.control.top, skin.control.bottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .overlay(
                    Circle().strokeBorder(
                        skin.control.edge,
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
            content()

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
        .background(
            RoundedRectangle(cornerRadius: DexMetrics.bezelCorner + DexMetrics.bezelFrame)
                .fill(Dex.stone800)
        )
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

            Spacer(minLength: 0)

            // The grille, with the wordmark stamped into it (0.6.6, D2).
            //
            // This is where the mockup always put it, between the slats at the
            // bottom-right of the housing; 0.6.5 sent it to a lip at the top of
            // the chassis instead, and 0.6.6's D1 deletes that lip. So the
            // device carries exactly one wordmark again and it is in the vent —
            // moulded into the grille the way a real one is, rather than
            // floating on its own plate.
            //
            // In `skin.grill` rather than the old brushed-metal gradient: the
            // slats around it are that colour, and a wordmark that does not
            // match the grille it is cut into reads as a sticker. Carried at
            // more opacity than the slats so it stays legible where they are
            // deliberately faint.
            VStack(spacing: 2) {
                ventSlat
                ventSlat
                Text("VINODEX")
                    .font(DexFont.retro(7))
                    .tracking(2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(skin.grill)
                    .opacity(0.9)
                    .frame(width: 64)
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

    /// One grille slat. Faint on purpose — the vent is texture, not a feature;
    /// the wordmark between them is the only thing here meant to be read.
    private var ventSlat: some View {
        Capsule()
            .fill(skin.grill)
            .frame(width: 64, height: 2)
            .opacity(0.5)
    }

    // MARK: Footer — the button band
    //
    // Four physical controls around one display (0.6.5, A/B): User alone on the
    // left, the marquee panel centred with its two indicator lamps above it, and
    // Settings/Home/Back as one staggered cluster on the right.
    //
    // There is deliberately **no** primary action button. Select and OK are
    // screen taps, and a fifth circle down here would be a control with nothing
    // to do that still had to be reached around.

    private func footer() -> some View {
        HStack(alignment: .top, spacing: DexMetrics.bandSpacing) {
            // User, standalone on the left (0.6.5, A1). It no longer shares a
            // slot with Back — the band has room for both now, so the old
            // "Back where there is somewhere to go, saved entries otherwise"
            // swap is gone and each button is always where you left it.
            ChassisButton(kind: .bookmarks, size: DexMetrics.bandControl, enabled: onBookmarks != nil) {
                onBookmarks?()
            }

            // The centre: two lamps stacked over the marquee panel (B1, B2).
            // Stacking them is what drops the panel's centre line below the
            // buttons either side of it, which is the offset the mockup shows —
            // the panel is not nudged down, it is pushed down by its own lamps.
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

            navCluster
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

    /// Settings, Home and Back as one staggered triangle (0.6.6, B1/F3).
    ///
    /// **This reverses 0.6.5's A2**, which put Home directly over Back in a
    /// vertical column, and reversing it is worth the churn: the column is the
    /// most expensive shape two buttons can take. It charged the band two full
    /// diameters plus a gap — 110pt at SMALL — and every point of that came off
    /// the LCD. The same two buttons staggered diagonally need one diameter plus
    /// the vertical *component* of their separation, which is 95pt here even
    /// after 0.6.6's B2 grew all four controls.
    ///
    /// Home takes the top-right; Back is offset down-and-inward from it, which
    /// is both the mockup's diagonal and the corner nearest the thumb; Settings
    /// closes the triangle beneath them. The three are packed to near-tangency —
    /// see the geometry note on `DexMetrics.bandClusterHomeX` — so the cluster
    /// reads as one group of parts rather than three loose circles, which is
    /// F3's complaint answered: the cog is *inside* the group now, not floating
    /// above the row's midline on its own centring padding.
    ///
    /// Laid out by offset against an explicitly sized transparent plate rather
    /// than by stacks. Overlapping bounding boxes have no stack arrangement, and
    /// the plate is what gives the `HStack` above a width to measure — the
    /// offset children contribute none.
    private var navCluster: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: DexMetrics.bandClusterWidth, height: DexMetrics.bandClusterHeight)

            // Home, the cluster's apex.
            ChassisButton(kind: .home, size: DexMetrics.bandControl, enabled: onHome != nil) {
                isFlipped = false
                onHome?()
            }
            .offset(x: DexMetrics.bandClusterHomeX)

            // Back, down and inward. Always mounted, and greyed where there is
            // nowhere to go rather than vanishing: a control that disappears
            // moves the ones around it, and having the cluster re-form itself
            // between screens is worse than a dim button.
            //
            // It acts on whatever is in front of you — with the device flipped
            // it turns it back over first, rather than navigating underneath and
            // appearing to do nothing.
            ChassisButton(kind: .back, size: DexMetrics.bandControl, enabled: showsBack || isFlipped) {
                if isFlipped {
                    isFlipped = false
                } else {
                    onBack?()
                }
            }
            .offset(y: DexMetrics.bandClusterBackY)

            // Settings, the small one (0.6.5, A3), closing the triangle.
            settingsButton(size: DexMetrics.bandControlSmall)
                .offset(x: DexMetrics.bandClusterSettingsX, y: DexMetrics.bandClusterSettingsY)
        }
        .frame(width: DexMetrics.bandClusterWidth, height: DexMetrics.bandClusterHeight)
    }

    /// The marquee's two indicator lamps (0.6.5, B2): a red and a blue pill,
    /// centred over the panel they belong to.
    ///
    /// Fixed red and blue rather than skin-tinted, unlike the trio in the top
    /// corner: these are the same bulbs as the vent lamp — the chassis's plain
    /// power/link indicators — and the skin's own colours are already spoken for
    /// by the lamps upstairs. Pills, not circles, so they cannot be mistaken at
    /// a glance for very small buttons.
    private var indicatorPills: some View {
        HStack(spacing: DexMetrics.bandPillSpacing) {
            indicatorPill(Dex.red500, border: Dex.red800)
            indicatorPill(Dex.blue, border: Color(dexHex: "#0B6FA8"))
        }
        // Decoration sitting directly above a live control: never a target.
        .allowsHitTesting(false)
    }

    private func indicatorPill(_ fill: Color, border: Color) -> some View {
        Capsule()
            .fill(fill)
            .frame(width: DexMetrics.bandPillWidth, height: DexMetrics.bandPillHeight)
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
// gone, and the only wordmark on the device is stamped into the grille instead
// — see `bottomVents`.

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

    private var gradient: LinearGradient {
        switch kind {
        case .back, .bookmarks:
            LinearGradient(colors: [skin.control.top, skin.control.bottom], startPoint: .top, endPoint: .bottom)
        case .home:
            LinearGradient(colors: [skin.accent.light, skin.accent.mid], startPoint: .top, endPoint: .bottom)
        }
    }

    private var borderColor: Color {
        switch kind {
        case .back, .bookmarks: skin.control.edge
        case .home: skin.accent.edge
        }
    }

    // Glyphs scale with the button's own diameter rather than carrying fixed
    // points, so resizing the band does not leave the same small icon floating
    // in a bigger circle.
    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .back:
            Image(systemName: "chevron.left")
                .font(.system(size: size * 0.47, weight: .heavy))
                .foregroundStyle(skin.control.glyph)
        case .bookmarks:
            Image(systemName: "person.crop.circle")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(skin.control.glyph)
        case .home:
            Circle()
                .fill(LinearGradient(colors: [skin.accent.pale, skin.accent.bright], startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(skin.accent.mid, lineWidth: 1))
                .padding(2)
                .overlay {
                    Image(systemName: "house.fill")
                        .font(.system(size: size * 0.41, weight: .bold))
                        .foregroundStyle(skin.accent.ink)
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

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(on ? 0.8 : 0.25), radius: on ? maxRadius : minRadius)
            .animation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
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
            TimelineView(.animation(paused: paused)) { context in
                let cycle = copyWidth + gap
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let shift = copyWidth > 0
                    ? CGFloat((elapsed * pointsPerSecond).truncatingRemainder(dividingBy: Double(cycle)))
                    : 0

                // The GeometryReader is load-bearing, not decoration: the
                // `.fixedSize()` label pair is ~1500pt wide for the main-menu
                // text, and without a *definite* width to clip against it
                // ignores `maxWidth` entirely, renders full-bleed across the
                // footer and squeezes the Back/user button out of the row.
                GeometryReader { strip in
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
                    .frame(
                        width: max(strip.size.width, 0),
                        height: max(strip.size.height, 0),
                        alignment: .leading
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
    private func endFade(width: CGFloat) -> some View {
        let fade = min(DexMetrics.marqueeFade, max(width, 0) / 3)
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
