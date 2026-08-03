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
    // **No app-wide back swipe (0.6.9, A1).** 0.6.8's I1 mounted a
    // `simultaneousGesture` on the LCD so every screen got a swipe-back for
    // free, with `BackSwipeGate` as the opt-out for the one screen that owns
    // horizontal dragging. A1 removes the feature outright, so the gate, its
    // suspend/resume calls in `RetroGlobeScreen`, its tests and the two
    // threshold metrics go with it — a gesture nobody can trigger is worse
    // than no gesture, but a *gate* for a gesture that no longer exists is
    // worse still.
    //
    // Back navigation is unaffected: the footer's Back cap is mounted on every
    // screen and enabled whenever `showsBack` is true (see `navBundle`), which
    // the app sets from a non-empty route stack. The back plate keeps its own
    // engraved arrow (0.6.8, B3) for turning the device back over.
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

    /// The main screen's toasts — five ways of saying one thing.
    ///
    /// **Shown one at a time since 0.6.9 (D3).** They used to be five words in
    /// a single scrolling run, separated by the same gap the strip gave its
    /// wrap seam; the panel holds still now, so it cycles them instead, dwell
    /// and cross-fade. See `MarqueeBanner.cycle()`.
    ///
    /// ASCII, deliberately: SANTE and GRUNER BOY are spelled the same way and
    /// for the same reason — the bundled Press Start 2P is a display face with
    /// a partial Latin-1 range, and a missing glyph on the device's most
    /// prominent panel is a worse outcome than a missing accent.
    private var footerSegments: [String] {
        isMainScreen ? ["CHEERS!", "SANTE!", "SALUTE!", "PROST!", "KANPAI!"] : [title]
    }

    /// **No glyph on the main screen** (0.7.0, K1).
    ///
    /// 0.6.9's D2 put a large glyph above the marquee title on every screen and
    /// hardcoded a wine glass for the main one. That was the wrong shape twice
    /// over: `VinodexApp` already resolves `nil` for an empty navigation path —
    /// the main screen is the one page with no route and therefore no page to be
    /// accurate to (K2) — and this ternary then put the glyph back. K1 removes
    /// it, so the panel there is the cycling greeting on its own, at the full
    /// height 0.6.9's D2 note says a nil symbol gives it.
    ///
    /// `isMainScreen` stays: `footerSegments` still needs it for the toasts.
    private var footerSymbol: String? { marqueeSymbol }

    public var body: some View {
        // The whole chassis is laid out in physical-screen coordinates so the
        // top safe-area strip — the band containing the Dynamic Island — can be
        // used rather than wasted. Insets are then reserved explicitly.
        GeometryReader { geo in
            let topStrip = max(geo.safeAreaInsets.top, DexMetrics.islandStripMinHeight)
            // What the *layout* pays for that strip (0.6.9, B1) — capped at
            // the cutout's own footprint rather than at whatever inset the OS
            // reports. See `DexMetrics.islandStripReserve`; the flank is drawn
            // at `topStrip` regardless, since it is an overlay rather than a
            // member of the stack below.
            let housingTop = min(topStrip, DexMetrics.islandStripReserve)

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
                frontFace(topStrip: topStrip, housingTop: housingTop)
                    .opacity(showsBackFace ? 0 : 1)
                    .accessibilityHidden(isFlipped)

                // **No swipe on the plate (0.6.8, B2/I2).** Returning used to
                // be a drag anywhere on this surface, advertised by an engraved
                // SWIPE TO RETURN line. Two things killed it: it fired on the
                // plain touches that were meant to pick a stamp up, and I1 puts
                // a swipe-back on the LCD app-wide — a *second* swipe on the
                // one surface that is not the LCD would mean the same movement
                // meaning two different things depending on which face is up.
                // I2 says explicitly not here, so the plate gets a button
                // instead (B3) and this face has no gesture of its own at all.
                DeviceBackPlate(onReturn: { isFlipped = false })
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

    private func frontFace(topStrip: CGFloat, housingTop: CGFloat) -> some View {
        ZStack(alignment: .top) {
            // The mock electronics sit behind the translucent shell and flip
            // with the front face — the back plate is its own opaque part.
            if skin.isTranslucent {
                InternalsView()
            }
            ChassisShell(skin: skin)

            VStack(spacing: 0) {
                // `housingTop`, not `topStrip` (0.6.9, B1): the screen starts
                // where the cutout ends, not where iOS's status inset does.
                Color.clear.frame(height: housingTop)
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
    // off the LCD's border. They are anchored to the screen housing now (see
    // `screenHousing`), and the 10pt band they needed down here goes with them.
    //
    // **Both clusters moved on their own axes in 0.6.8 (F).** The orb goes
    // inboard and slightly smaller (F1/F2), the trio goes outboard and slightly
    // up (F3), and the row is levelled on the cutout's own centre line rather
    // than on a hand-tuned inset. The strip's floor (~54pt) stays under the
    // 59pt a Dynamic Island already reserves, so none of it is charged to the
    // LCD — F4 is satisfied by the strip having stopped being the binding
    // constraint in 0.6.7 and staying that way here.
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
                    // Inboard of the corner (0.6.8, F2), applied outside the
                    // slot so the 44pt touch target moves with the bead rather
                    // than being eaten by the inset.
                    .padding(.leading, DexMetrics.islandOrbInsetLeading)

                // The cutout's clearance — whatever is left between the two
                // clusters (0.6.8, F2/F3). It was a fixed 158pt spacer, which
                // had to be re-tuned every time either side moved; a `Spacer`
                // states the actual rule, which is that nothing is drawn under
                // the island and the two clusters simply keep out of its way.
                // On a 393pt phone this leaves ~45pt of margin to the island's
                // left edge and ~43 to its right.
                Spacer(minLength: 0)

                // The three skin-tinted lamps (0.6.5, C1), **trailing-aligned**
                // since 0.6.8 (F3): the trio's outer edge sits on the same
                // inset the orb's used to, so the two clusters read as a
                // mirrored pair of blocks. 0.6.7 centred them in the whole
                // right-hand corner instead, which put them ~70pt further left
                // and left an obvious empty run outboard of them.
                statusDots(size: DexMetrics.islandStatusDot)
                    // Decoration only, and never a touch target sitting next
                    // to one.
                    .allowsHitTesting(false)
                    // **Level with the orb** (0.6.9, E1). 0.6.8's F3 rode 6pt
                    // high on `islandStatusRise`; the row's own `.center`
                    // alignment now puts both clusters on the cutout's centre
                    // line with nothing correcting it. See the retired metric.
                    .frame(height: slot, alignment: .center)
                    .padding(.trailing, DexMetrics.islandStatusInsetTrailing)
            }
            .frame(height: slot)
            .padding(.top, DexMetrics.islandTopInset)

            // Any extra strip height — a device reporting a deeper inset than
            // we ask for — lands here rather than reopening the gap to the
            // screen housing.
            Spacer(minLength: 0)
        }
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
                        cap.edge.opacity(skin.sketch == nil ? 1 : 0),
                        lineWidth: 2
                    )
                )
                // Inked by hand on the drawn skin (0.6.9, M1) — the geometric
                // rim goes to zero rather than being conditionally omitted, so
                // the cap's layout is identical either way. Seeded off the
                // button so the cog's circle is not the same wobble as the
                // three caps beside it.
                .overlay {
                    if let sketch = skin.sketch {
                        SketchStroke(
                            shape: { SketchCircle(seed: $0) },
                            ink: sketch.ink,
                            lineWidth: 2,
                            seed: 41
                        )
                    }
                }
                .shadow(
                    color: .black.opacity(skin.sketch == nil ? DexMetrics.bandShadowOpacity : 0),
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
        // The moulded housing, top to bottom: the **white top bezel** carrying
        // the two red status lamps, the LCD in its dark grey band, and the
        // white bottom strip carrying the vent lamp, the wordmark and the
        // grille.
        //
        // **The lamps are up here again (0.6.8, D).** They have moved four
        // times now — this white strip (0.6.5), bare chassis (0.6.6), the grey
        // band's thickened top edge (0.6.7), and back here — so the layers are
        // named in `DexMetrics.bezelTopMargin` and the two that matter are
        // spelled out plainly:
        //
        //   *white bezel*  = this housing's own plate, `skin.panel`
        //   *grey band*    = the `Dex.stone800` frame the LCD is set into,
        //                    `bezelFrame` thick — see `innerBezel`
        //
        // 0.6.7 put the lamps on the grey band, which is what the device
        // reported and what D2 asks to undo. D1 keeps that band at exactly the
        // width it has; D3 grows this strip from 2pt to 20 so the lamps have
        // white moulding around them instead of a seam.
        VStack(spacing: 0) {
            Color.clear
                .frame(height: DexMetrics.bezelTopMargin)
                // Centred in the white strip, which is where a handheld's
                // power/link pair belongs and where 0.6.5 had them — and, since
                // 0.6.9 (B2), in the part of it the housing rim does not cross.
                // See `DexMetrics.housingRimGuard`; the padding shifts the
                // pair's centre down by half the rim, which is exactly the
                // amount of this strip the rim covers.
                .overlay {
                    HStack(spacing: DexMetrics.bandPillSpacing) {
                        ventDot(size: DexMetrics.ventDot)
                        ventDot(size: DexMetrics.ventDot)
                    }
                    .padding(.top, DexMetrics.housingRimGuard)
                    .allowsHitTesting(false)
                }
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
            // The rim. On the drawn skin (0.6.9, M1) the geometric stroke drops
            // to a ghost and the hand line does the work — both are kept rather
            // than swapped, because the wobble means the ink does not sit
            // exactly on the chamfered silhouette, and a faint true edge under
            // it is what stops the housing's fill showing a hard boundary the
            // pen has strayed inside of.
            //
            // `SketchRoundedRect` and not a chamfered sketch shape: at 1.5pt of
            // wobble the keyed corner is inside the pen's own error, so a
            // second hand-drawn silhouette would be four times the code for a
            // difference nobody could see.
            screenPanelShape
                .strokeBorder(
                    skin.panelEdge.opacity(skin.sketch == nil ? 1 : 0.25),
                    lineWidth: DexMetrics.screenPanelBorder
                )
            if let sketch = skin.sketch {
                SketchStroke(
                    shape: { SketchRoundedRect(cornerRadius: DexMetrics.screenPanelCorner, seed: $0) },
                    ink: sketch.ink,
                    lineWidth: 2.4,
                    seed: 11
                )
            }
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

    /// One red housing lamp. Takes its diameter since 0.6.8 (G3): the pair on
    /// the white top bezel and the lone one in the bottom strip are the same
    /// bulb at two sizes, not two parts.
    private func ventDot(size: CGFloat) -> some View {
        Circle()
            .fill(Dex.red500)
            .frame(width: size, height: size)
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
        // No gesture of any kind rides on the display since 0.6.9 (A1) — see
        // the note beside `orbHeld`. The LCD is a surface screens are mounted
        // in, and every recogniser it carried had to be negotiated with
        // whatever was mounted.
        //
        // The monochrome modes: desaturate everything on the LCD, then tint
        // the lot — grey-green for VINTAGE, amber phosphor for AMBER. Done
        // here, over the whole display, because it is the only way entry art,
        // chips and glyph tints — none of which read LcdMode — go monochrome
        // too. Identity (grayscale 0, multiply white) in the colour modes.
        .grayscale(lcd.monochromeTint == nil ? 0 : 1)
        .colorMultiply(lcd.monochromeTint ?? .white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DexMetrics.bezelCorner))
        // The dark grey band: a thin stone frame, **equal on every side**
        // (0.6.8, D1). 0.6.7 thickened its top edge to 12pt to seat the two red
        // lamps, which is what put them "inside the dark gray band"; D1 keeps
        // the band at this width and D2 moves the lamps out to the white bezel
        // above, so there is one thickness again. Deliberately small either
        // way: padding here costs LCD height, and a uniform `bezelInsetH`
        // (12pt) took 24pt of vertical space away.
        .padding(DexMetrics.bezelFrame)
        .background(
            RoundedRectangle(cornerRadius: DexMetrics.bezelCorner + DexMetrics.bezelFrame)
                .fill(Dex.stone800)
        )
        // Horizontal only — this insets the housing without costing height.
        .padding(.horizontal, DexMetrics.bezelInsetH - DexMetrics.bezelFrame)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The white strip below the LCD: the lone red lamp, the wordmark, the
    /// grille.
    ///
    /// **All three centred on the strip's own line since 0.6.9 (F1).**
    /// Horizontally they were already spread along it — the lamp is held off
    /// the chamfer, the wordmark takes the whole run between lamp and grille,
    /// and the grille is pinned to the trailing corner — so what F1 is asking
    /// for is the other axis. `.center` is stated explicitly rather than left
    /// to the `HStack`'s default, because the one thing that *was* off the line
    /// (the grille's 5pt optical rise, 0.6.8 G1) was off it deliberately, and
    /// an implicit default is a poor place to record that a decision was
    /// reversed.
    private var bottomVents: some View {
        HStack(alignment: .center, spacing: 0) {
            // The lamp moves to the left end of the strip (0.6.5), where the
            // mockup has it — it was centred, which put it under the wordmark's
            // old slot. Held off the edge by the chamfer's run: at the lamp's
            // height the diagonal has eaten roughly `chamfer - ventStrip/2` of
            // the left edge, and a lamp inside that is a lamp cut in half.
            //
            // Nudged a further ~0.3 chamfers right in 0.6.6 (E2): it was
            // clearing the diagonal by the width of the lamp itself, which reads
            // as crowding the cut rather than as sitting beside it.
            // Half again its old diameter (0.6.8, G3) — see `bottomVentDot`.
            ventDot(size: DexMetrics.bottomVentDot)
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
        // The strip is `ventStripHeight` tall overall, but its bottom
        // `housingRimGuard` points are under the housing's rim (0.6.9, B2), so
        // the three parts are centred in what is left. Written as a shortened
        // frame plus the padding rather than as an offset, so the strip still
        // measures its full height in the housing's stack — an offset would
        // have moved the contents *and* left the LCD believing it had more
        // room than it does.
        .frame(height: DexMetrics.ventStripHeight - DexMetrics.housingRimGuard)
        .padding(.bottom, DexMetrics.housingRimGuard)
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
    // 0.6.7, G; resized 0.6.8, E; re-paired and re-sized 0.6.9, C): **two
    // matching vertical bundles** — Back over User on the left, Home over
    // Settings on the right — with the marquee panel and its two indicator
    // lamps between them.
    //
    // 0.6.9's C is three clauses and they pull the same way: the caps come down
    // a quarter to 60pt (C1), the pairing re-cuts so the top row is the two
    // controls that *move* you and the bottom row the two that *open* something
    // (C2), and the caps in each well stop being tangent (C3). C1 hands 34pt of
    // band height straight back to the LCD, which with B1's 9 is the batch's
    // answer to 0.6.8 having spent 68 of it.
    //
    // 0.6.8's E is one instruction with five clauses, and they are all the same
    // trade: the caps go to 1.74× (E1), which only fits if the pairs stand
    // upright and the band's edge inset comes in to 10pt (E2), which together
    // hand the marquee ~25pt of extra width and its lamps with it (E3), paid
    // for out of ~68pt of screen housing (E4) — and the height that buys is
    // then all spent rather than left as air (E5): the wells are 68% cap by
    // area, the marquee column fills the band, and the glyphs on it grew to
    // match. See `DexMetrics.bandControl` for the arithmetic.
    //
    // There is deliberately **no** primary action button. Select and OK are
    // screen taps, and a fifth circle down here would be a control with nothing
    // to do that still had to be reached around.

    private func footer() -> some View {
        HStack(alignment: .top, spacing: DexMetrics.bandSpacing) {
            backBundle

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

            homeBundle
        }
        .frame(height: DexMetrics.bandHeight, alignment: .top)
        // The buttons out to the edges (0.6.8, E2) — `bandPaddingH`, not the
        // island strip's `cornerGuardH`, which the two rows no longer share.
        .padding(.horizontal, DexMetrics.bandPaddingH)
        // Asymmetric on purpose, and built from the two insets rather than
        // centred in a fixed height: tight to the screen housing above, full
        // `chassisEdgeInset` below so the home indicator has bare chassis to
        // land on. See `DexMetrics.footerHeight`.
        .padding(.top, DexMetrics.footerTopInset)
        .padding(.bottom, DexMetrics.chassisEdgeInset)
        .frame(maxWidth: .infinity)
        .background(skin.footerWash)
    }

    /// **Back over User, in the left-hand well** (0.6.9, C2).
    ///
    /// The pairing is re-cut in this batch. 0.6.7's G2 gave the left well
    /// User-over-Settings and the right well Home-over-Back, which grouped the
    /// two *personal* controls on one side and the two *navigation* controls on
    /// the other. C2 re-pairs by row instead: Back and Home are the top row —
    /// the two things that move you — and User and Settings the bottom row, the
    /// two things that open a place. Back sits leading because that is the
    /// direction it means, and Home trailing for the same reason.
    ///
    /// Back is always mounted and greyed where there is nowhere to go, rather
    /// than vanishing: a control that disappears moves the ones around it, and
    /// having the bundle re-form itself between screens is worse than a dim
    /// button. With 0.6.9's A1 removing the LCD swipe, this cap is also the
    /// **only** app-level back affordance, which is a second reason it may not
    /// move or disappear.
    private var backBundle: some View {
        buttonBundle {
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
        } bottom: {
            // User. It no longer shares a slot with Back — the band has had
            // room for both since 0.6.5, so the old "Back where there is
            // somewhere to go, saved entries otherwise" swap is gone and each
            // button is always where you left it.
            ChassisButton(kind: .bookmarks, size: DexMetrics.bandControl, enabled: onBookmarks != nil) {
                onBookmarks?()
            }
        }
    }

    /// **Home over Settings, in the right-hand well** (0.6.9, C2) — the mirror
    /// of `backBundle`. See its note for why the pairing changed.
    private var homeBundle: some View {
        buttonBundle {
            ChassisButton(kind: .home, size: DexMetrics.bandControl, enabled: onHome != nil) {
                isFlipped = false
                onHome?()
            }
        } bottom: {
            // Settings, at Home's own diameter (0.6.7, G2) rather than the
            // small cap it wore in the triangle.
            settingsButton(size: DexMetrics.bandControl)
        }
    }

    /// Two controls stacked in one capsule recess (0.6.7, G1/G2; stood upright
    /// 0.6.8, E1) — the SNES face recess that groups X and Y.
    ///
    /// **A plain `VStack` since 0.6.8.** The diagonal form had to be laid out by
    /// absolute offset against an explicitly sized transparent plate, because
    /// two staggered circles have overlapping bounding boxes and no stack
    /// arrangement describes them. With `bandBundleDX` at zero there is no
    /// stagger, the two caps are tangent, and a stack says all of that in three
    /// lines — including giving the footer's `HStack` a real width to measure,
    /// which the offset children never did.
    ///
    /// The well is a `Capsule` as long as the pair's centre separation plus one
    /// padded diameter, which makes it the exact convex hull of the two padded
    /// caps, and it is drawn behind them at the bundle's own size.
    private func buttonBundle<Top: View, Bottom: View>(
        @ViewBuilder top: () -> Top,
        @ViewBuilder bottom: () -> Bottom
    ) -> some View {
        // The caps are `bandCapGap` apart since 0.6.9 (C3) rather than tangent,
        // so this resolves to that gap rather than to zero. Stated as the
        // separation minus a diameter — not as `bandCapGap` directly — so the
        // stack's spacing cannot drift from the height the bundle is framed at.
        VStack(spacing: DexMetrics.bandBundleDY - DexMetrics.bandControl) {
            top()
            bottom()
        }
        .padding(DexMetrics.bandWellPad)
        .background {
            ButtonWell()
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

/// The recess a button bundle sits in (0.6.7, G1; upright since 0.6.8, E1).
///
/// An SNES face recess: a stadium milled into the deck, the two caps sitting in
/// it. Drawn as shading rather than in any skin colour — a dark floor, a soft
/// dark wall along the top edge where no light reaches, and a bright lip along
/// the bottom where it does — so it works over every one of the eighteen shells
/// without a per-skin table. That is the same reasoning the chassis already
/// applies to the caps' own drop shadows and specular highlights: shading is a
/// property of the light, not of the plastic.
///
/// The `angle` parameter is gone with the diagonal: the capsule is drawn at the
/// bundle's own upright bounds, so there is nothing to rotate and no
/// hand-computed convex hull to keep in step with the caps.
private struct ButtonWell: View {
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
                // Tracking is the stretch's control surface, not a spacing
                // tweak: it is applied *before* the run is measured, so it is
                // most of the natural width the fixed slot is divided by.
                // Loosening it brings the horizontal scale down toward the
                // vertical; tightening it drives the glyphs wider.
                //
                // 2 since 0.6.8 (G2), from 5 — one move that does both halves
                // of "reduce character spacing, increase character width",
                // because the gaps shrink with the tracking while the glyphs
                // grow with the scale it releases. See
                // `DexMetrics.wordmarkTracking`.
                .tracking(DexMetrics.wordmarkTracking)
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
            // The paper's tooth (0.6.9, M1). Drawn rather than tiled from an
            // asset, unlike the three patterns above: a stipple is cheaper to
            // generate than to ship, it scales to any device without a seam,
            // and PÉT-NAT therefore needs nothing from `art/icons/`.
            if let sketch = skin.sketch {
                PaperGrain(color: sketch.grain)
            }
        }
    }
}

/// Loads bundled chassis patterns, cached — mirrors `FlagLoader`, misses
/// recorded so an absent asset is not re-probed every render.
@MainActor
// Internal rather than file-private since 0.7.0 (F1): the *back* plate mounts
// the same tiled patterns as the front now, and a second loader with a second
// cache over the same PNGs would be two answers to one question.
final class ChassisPatternLoader {
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
                // Hidden rather than skipped on the drawn skin (0.6.9, M1), so
                // the cap is the same stack of layers on every shell; the hand
                // line below replaces it. Same treatment as the cog's rim.
                Circle().strokeBorder(borderColor.opacity(skin.sketch == nil ? 1 : 0), lineWidth: 3)
                if let sketch = skin.sketch {
                    SketchStroke(
                        shape: { SketchCircle(seed: $0) },
                        ink: sketch.ink,
                        lineWidth: 2.2,
                        // Per-kind, so Back, Home and User are three different
                        // circles rather than the same wonky one stamped out
                        // three times — which is the tell that would give away
                        // that nobody drew them.
                        seed: sketchSeed
                    )
                }
                icon
            }
            .frame(width: size, height: size)
            // Softened in 0.6.6 (B3) — see `DexMetrics.bandShadowOpacity`. The
            // old 0.6/6/8 cast a near-black plate roughly a quarter of a
            // diameter below each circle, which is a sticker's shadow, not a
            // moulded cap's. Dropped entirely on the drawn skin: a cast shadow
            // is the one thing a pen cannot do.
            .shadow(
                color: .black.opacity(skin.sketch == nil ? DexMetrics.bandShadowOpacity : 0),
                radius: DexMetrics.bandShadowRadius,
                y: DexMetrics.bandShadowY
            )
        }
        .buttonStyle(DexPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(accessibilityLabel)
    }

    /// One wobble per kind — see the note at the call site (0.6.9, M1).
    private var sketchSeed: UInt64 {
        switch kind {
        case .back: 7
        case .home: 19
        case .bookmarks: 29
        }
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
        // The one control whose glyph a skin may replace (0.7.0, B2) —
        // HALLOWEEN's user button is a drawn pumpkin. `SkinMarkView` resolves
        // "the skin's mark, or the house symbol if it has none", so twenty of
        // twenty-one skins render exactly the `person.crop.circle` they always
        // did. See `ChassisSkin.userMark` for why this is not the console
        // liveries' colours-only caveat being reopened.
        case .bookmarks:
            SkinMarkView(
                mark: skin.userMark,
                fallback: "person.crop.circle",
                size: size * 0.44,
                tint: cap.glyph
            )
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
            // **Back to one backdrop for every mode** (0.7.0, C1).
            //
            // 0.6.9's M1 branched here on `LcdMode.isSketchPaper` to mount
            // `RuledPaper` for NOTEBOOK. C1 removes that mode, so the branch has
            // nothing left to select and the grid is unconditional again. The
            // *shell* half of M1 is untouched — `ChassisSkin.sketch` still draws
            // PÉT-NAT by hand — which is the documented design: the shell and
            // the screen are independent choices.
            //
            // See the retirement note on `LcdMode` for what happens to
            // `RuledPaper`, which is kept and unmounted rather than deleted.
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

/// The title panel — the centrepiece of the button band.
///
/// **It does not scroll (0.6.9, D1).** From 0.5.1 through 0.6.8 this ported the
/// web app's `terminal-marquee`: two copies of the label offset by one measured
/// cycle, animated off a `TimelineView` clock, with a gradient mask at each end
/// so the letters read as passing behind the housing rather than being
/// guillotined by the clip. D1 retires the whole mechanism. What is left is the
/// form PR #11's M18 already built for Reduce Motion — a still, centred,
/// fitted label — promoted from the accessibility branch to the only branch.
///
/// Deleting rather than disabling the scroll is the point. Keeping both alive
/// behind a flag would leave the measured `copyWidth`, the two-copy `HStack`,
/// the end fade and the timeline clock as code nothing reaches, and every one of
/// those is a thing this file has previously lost a round to (audit M8, M9, and
/// the 0.6.6 C2 fade). Gone with it: `pointsPerSecond`, `copyWidth`, `gap`,
/// `label`, `endFade` and `DexMetrics.marqueeFade`.
///
/// What the still form gains is room. A scrolling strip could only ever be one
/// line of one size, because the scroll was what revealed the tail; a fixed
/// label can wrap, can be set much larger (D4), and has space above it for the
/// page's own glyph at a size worth looking at (D2). And a panel that is not
/// moving can say something *else* on the main screen — see the greeting cycle
/// below (D3).
///
/// **Lit, not backlit, since 0.6.5 (B1).** It used to be a black strip with the
/// skin's phosphor glowing on it, which is a VFD; the mockup's centrepiece is a
/// green *panel* with its letters dark — a segment LCD, where the ground is what
/// lights and the glyphs are what the liquid crystal blocks. So the two colours
/// swap: `marqueeText` fills the panel and `marqueeShadow` cuts the letters out
/// of it. Every skin follows, since both were already per-skin — CLASSIC's green
/// phosphor is what makes the panel green, and NOCTURNE's or BLUSH's panel is
/// its own colour rather than a green one bolted onto the wrong shell.
public struct MarqueeBanner: View {
    /// The words the panel shows. Most screens pass one — their title; the main
    /// screen passes its five toasts, which the panel now cycles through rather
    /// than running past in a single line (0.6.9, D3).
    let segments: [String]
    /// SF Symbol for the page, drawn **above** the title since 0.6.9 (D2) at
    /// `DexMetrics.marqueeGlyph`. It used to be stamped inline after the words
    /// (v0.5.7, E2), which was the only place a scrolling single line had for
    /// it. Nil runs text-only and the label takes the whole panel.
    let symbol: String?
    let fontSize: CGFloat
    /// Stops the greeting cycle (AUDIT M8, kept through D3). The panel is inside
    /// the front face, which the flip merely hides at `opacity 0` — a cycle left
    /// running behind an opaque metal back plate is a timer nobody can see.
    ///
    /// It used to stop the scroll clock as well; there is no longer a clock to
    /// stop, and on a single-segment screen this now gates nothing at all.
    var paused: Bool = false

    /// Which greeting is showing (0.6.9, D3). Always 0 on the ~ten screens that
    /// pass a single segment, where the cycle never starts.
    @State private var index = 0

    /// Resolved in `init`, not per access (AUDIT M8): `DexFont.retro` reads
    /// `TextScale.current`, which is a `UserDefaults` lookup, and `body` is
    /// rebuilt on every skin or cycle change. `DeviceChassis` is `.id`-keyed on
    /// the text scale, so a change rebuilds this view rather than needing it
    /// re-read.
    private let segmentFont: Font

    /// The strip's phosphor follows the shell — see `ChassisSkin.marqueeText`.
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    /// Read here rather than passed in by `DeviceChassis` so the banner keeps
    /// working wherever else it is mounted. (AUDIT M18)
    ///
    /// Its job changed in 0.6.9. It used to choose between the scrolling and
    /// still forms; the still form is now the only one, so what is left for it
    /// to gate is the greeting cycle — see `cycle()`.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }

    /// The lit ground: the skin's phosphor, filling the panel rather than the
    /// letters (0.6.5, B1).
    private var ground: Color { skin.marqueeText }

    /// The letters and the panel's rim — the very dark form of the phosphor,
    /// which is what a segment LCD's glyphs actually look like.
    private var ink: Color { skin.marqueeShadow }

    /// The word on the panel right now, clamped rather than subscripted: the
    /// cycle and the segment list are separate pieces of state, and a screen
    /// change can swap a five-segment list for a one-segment list between the
    /// `index` advancing and the body running.
    private var current: String {
        guard !segments.isEmpty else { return "" }
        return segments[min(index, segments.count - 1)]
    }

    public init(
        segments: [String],
        symbol: String? = nil,
        fontSize: CGFloat,
        paused: Bool = false
    ) {
        self.segments = segments
        self.symbol = symbol
        self.fontSize = fontSize
        self.paused = paused
        self.segmentFont = DexFont.retro(fontSize)
    }

    public var body: some View {
        ZStack {
            panel
            content
        }
        .frame(height: DexMetrics.marqueeHeight)
        // Keyed on both, so the loop restarts when the screen changes under it
        // and stops dead when the device is turned over. `task(id:)` cancels
        // the previous run, which is what makes the sleep below safe to write
        // as an open loop.
        .task(id: cycleKey) { await cycle() }
    }

    /// What a cycle run belongs to. The joined segments rather than the count:
    /// two different five-toast lists would otherwise share a run and the new
    /// one would inherit the old one's phase.
    private var cycleKey: String {
        (paused ? "paused|" : "") + segments.joined(separator: "\u{1F}")
    }

    /// The greeting cycle (0.6.9, D3): dwell, cross-fade, next word, forever.
    ///
    /// A `Task` loop rather than a `Timer` or a `TimelineView`, because
    /// `task(id:)` already owns its lifetime — leaving the screen, turning the
    /// device over or switching to a single-segment title all cancel it, and
    /// none of those need a matching teardown call to be remembered.
    ///
    /// **Held still under Reduce Motion.** A cross-fade is the transition
    /// Apple's own guidance offers as the substitute for a movement, so the
    /// fade itself would be defensible — but the change is *unprompted*, and
    /// Reduce Motion asks for none of that. `PulseGlow` in this same file
    /// settles on the most informative still state rather than simply stopping,
    /// and the same reasoning applies here: the panel holds on the first
    /// greeting, which is a toast rather than a blank.
    private func cycle() async {
        guard segments.count > 1, !paused, !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(DexMetrics.marqueeGreetingDwell))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: DexMetrics.marqueeGreetingFade)) {
                index = (index + 1) % segments.count
            }
        }
    }

    /// The lit plate itself: fill, segment grid, lamp gradient, rim, glow.
    private var panel: some View {
        RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner)
            .fill(ground)
            // The pixel grid sits on the lit ground rather than over black, so
            // it reads as the panel's own segment structure — `marqueeGrid` is
            // a register off the phosphor either way, so it still separates
            // from the fill.
            .overlay(
                DexGridBackground(spacing: 12, color: skin.marqueeGrid, opacity: 0.22)
                    .clipShape(RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner))
            )
            // A lit panel is brightest where the lamp behind it is: a touch of
            // ink settling toward the bottom is what stops the fill reading as
            // flat paint.
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
            // The panel's own glow, spilling onto the chassis around it — the
            // one thing that says this is a display and not a green sticker.
            .shadow(color: ground.opacity(0.45), radius: 6)
    }

    /// The glyph over the title (0.6.9, D2/D4).
    ///
    /// The glyph is sized off the **panel**, not off the type: it is chrome,
    /// and a symbol that grew with SETTINGS > TEXT SIZE would push the words it
    /// is supposed to introduce off a panel whose height does not move. The
    /// words take whatever is left, and shrink into it.
    private var content: some View {
        VStack(spacing: DexMetrics.marqueeGlyphGap) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: DexMetrics.marqueeGlyph, weight: .bold))
                    .foregroundStyle(ink)
                    .shadow(color: ground.opacity(0.7), radius: 0, x: 1, y: 1)
            }
            title
        }
        .padding(.horizontal, DexMetrics.marqueeTextInset)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A guard rather than a mechanism: the label is fitted, so nothing
        // should reach this. If a future title does, it is cut at the panel's
        // rim like a display clipping an oversized image, not spilled onto the
        // moulding.
        .clipShape(RoundedRectangle(cornerRadius: DexMetrics.marqueeInnerCorner))
    }

    /// The title, wrapped and fitted (0.6.9, D2).
    ///
    /// Three fallbacks in order, which is what "wrap or adjust the text to fit"
    /// costs at 28pt in a pixel face on a ~225pt panel:
    ///
    /// 1. **Soft hyphens** (`EntryDisplay.hyphenated`) so a single long word
    ///    can break at all — SwiftUI's `Text` exposes no hyphenation setting,
    ///    so CONTINENTS or SAUVIGNON would otherwise be one unbreakable run.
    ///    Already proven in this typeface: the entry chips have used it since
    ///    v0.5.7.
    /// 2. **Two lines**, which is what the panel's height affords once the
    ///    glyph is out of it. DAILY CHALLENGE breaks at its space and reads
    ///    better stacked than it ever did scrolling past.
    /// 3. **`minimumScaleFactor`**, down to 0.4 — deep, because the worst case
    ///    is a long entry name at the HUGE text step, and a title that shrinks
    ///    is better than one that truncates. The ellipsis behind it is the
    ///    floor, so anything longer still degrades to a visible truncation mark
    ///    rather than to a word chopped mid-glyph.
    ///
    /// `.id(index)` is what makes D3's cross-fade actually fade: SwiftUI does
    /// not animate a `Text`'s *contents* changing, so the identity has to
    /// change for the transition to have an insertion and a removal to run.
    private var title: some View {
        Text(EntryDisplay.hyphenated(current))
            .font(segmentFont)
            .foregroundStyle(ink)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.4)
            .truncationMode(.tail)
            // A hard catch of the lit ground below-right, where a black drop
            // shadow would be. Same one-pixel trick, inverted with the panel:
            // it is what makes the letters read as cut into the display rather
            // than printed on it.
            .shadow(color: ground.opacity(0.7), radius: 0, x: 1, y: 1)
            .id(index)
            .transition(.opacity)
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
