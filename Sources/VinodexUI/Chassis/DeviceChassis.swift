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
    /// Whether this is the root screen — the one with no route pushed.
    ///
    /// Declared by the caller rather than inferred from `title == "VINODEX"`
    /// (AUDIT **L2**). The footer's toast cycle and its wineglass glyph are the
    /// two behaviours keyed off it, and both used to hang on a string the app
    /// module happens to produce for an empty path. Renaming the home screen
    /// would have silently demoted it to an ordinary page.
    var isRoot: Bool = false
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
    /// The eight stored settings, as one model (arch **A17**). Shared with
    /// `SettingsPanel` through the same instance, so toggling a skin there
    /// repaints the chassis without any state being threaded between them —
    /// and `lcdMode` is read here for VINTAGE's monochrome pass over the LCD,
    /// see `innerBezel`.
    var settings: AppSettings = .shared

    /// The chassis owns the app's two largest movements — the 0.7s 3D flip and
    /// the footer marquee — so this is where Reduce Motion has to be read.
    /// (AUDIT M18)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var skin: ChassisSkin { settings.chassisSkin }
    private var lcd: LcdMode { settings.lcdMode }

    public init(
        title: String,
        isRoot: Bool = false,
        marqueeSymbol: String? = nil,
        showsBack: Bool = false,
        onBack: (() -> Void)? = nil,
        onHome: (() -> Void)? = nil,
        onBookmarks: (() -> Void)? = nil,
        onSettings: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.isRoot = isRoot
        self.marqueeSymbol = marqueeSymbol
        self.showsBack = showsBack
        self.onBack = onBack
        self.onHome = onHome
        self.onBookmarks = onBookmarks
        self.onSettings = onSettings
        self.content = content
    }

    /// The main screen cycles its toasts as separate words — the banner gives
    /// every boundary between them the same gap it gives the wrap seam.
    private var footerSegments: [String] {
        isRoot ? ["CHEERS!", "SANTE!", "SALUTE!", "PROST!", "KANPAI!"] : [title]
    }

    private var footerSymbol: String? {
        isRoot ? "wineglass.fill" : marqueeSymbol
    }

    public var body: some View {
        // The whole chassis is laid out in physical-screen coordinates so the
        // top safe-area strip — the band containing the Dynamic Island — can be
        // used rather than wasted. Insets are then reserved explicitly.
        GeometryReader { geo in
            let topStrip = max(geo.safeAreaInsets.top, DexMetrics.islandStripMinHeight)
            let hasCutout = DexMetrics.hasDisplayCutout(bottomSafeArea: geo.safeAreaInsets.bottom)

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
                frontFace(topStrip: topStrip, hasCutout: hasCutout)
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
                    // The way back, for the same reason as the orb above: the
                    // plate's own label already says "swipe to return", and a
                    // swipe is precisely what VoiceOver reserves for its own
                    // navigation. `.escape` is the two-finger scrub, which is
                    // what a user reaching for "get me out of here" already
                    // does; the named action makes it discoverable in the
                    // rotor rather than only known. (AUDIT **M21**)
                    .accessibilityAction(.escape) { isFlipped = false }
                    .accessibilityAction(named: "Turn the device back over") {
                        isFlipped = false
                    }
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
            // The signposted way in, for screens inside the LCD — the settings
            // panel's ABOUT row. Registered while mounted and cleared after, so
            // the closure can never outlive the chassis holding the state it
            // writes. See `ChassisFlipRouter`. (AUDIT **M21**)
            .onAppear { ChassisFlipRouter.shared.handler = { isFlipped = true } }
            .onDisappear { ChassisFlipRouter.shared.handler = nil }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
        // The underlay, not the body: this layer never rotates with the flip,
        // so it must not show internals — under a translucent skin it is the
        // dark ground the smoke plastic needs, and elsewhere it is the body.
        .background(skin.underlay.ignoresSafeArea())
    }

    private func frontFace(topStrip: CGFloat, hasCutout: Bool) -> some View {
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

            islandFlank(height: topStrip, hasCutout: hasCutout)
        }
    }

    // MARK: Chassis title

    /// The wordmark's brushed-metal letters (0.6.4, A1) — the cog's own
    /// gradient, no plate behind them. Housed in `titleLip` since 0.6.5
    /// (item 4): floating bare in the strip read as unfinished.
    private var chassisTitle: some View {
        Text("VINODEX")
            .font(DexFont.retro(16))
            .tracking(4)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(dexHex: "#f4f5f6"),
                        Color(dexHex: "#c3c6ca"),
                        Color(dexHex: "#8b8f95"),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // Seated, not floating: a light catch above and a dark cut below,
            // the same two-shadow trick the back plate engraves with.
            .shadow(color: .black.opacity(0.55), radius: 0, x: 0, y: 1)
            .shadow(color: .white.opacity(0.18), radius: 0, x: 0, y: -1)
            .allowsHitTesting(false)
    }

    /// The trapezoidal lip the title sits in (0.6.5, item 4 — the redo of the
    /// redo). A moulded piece protruding from the chassis top: wide where it
    /// meets the top edge, shoulders curving in to a narrower foot, hanging
    /// down through the island strip with the metal letters seated in its
    /// lower band — below the hardware cutout, which punches through the
    /// lip's upper half the way it punches through everything else up here.
    /// Drawn in the strip's centre slot, so layout (not a fixed width) keeps
    /// it clear of the orb and the cog; unlike 0.6.2's bump it lives entirely
    /// on dead chassis and costs the LCD nothing.
    private func titleLip(control: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            TitleLip()
                .fill(skin.body)
            // A dark seat line and a light catch — what makes a flat fill
            // read as a raised piece, verbatim from the 0.6.2 bump.
            TitleLip()
                .stroke(.black.opacity(0.28), lineWidth: 1.5)
            TitleLip()
                .stroke(.white.opacity(0.14), lineWidth: 1)
                .offset(y: 1)
                .clipShape(TitleLip())

            chassisTitle
                .padding(.bottom, 9)
                .padding(.horizontal, 18)
        }
        // Taller than the control row it sits in, bottom-aligned, so the lip
        // runs from the row's foot up to the display's top edge.
        .frame(height: DexMetrics.islandStripMinHeight)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
        .allowsHitTesting(false)
    }

    // MARK: Island flank
    //
    // Orb + status lights to the left of the Dynamic Island, cog to the
    // right. This band is otherwise dead chassis, so using it costs the LCD
    // nothing — the bezel keeps none of it.

    private func islandFlank(height: CGFloat, hasCutout: Bool) -> some View {
        // One control size across the whole chassis. The strip is sized to seat
        // it (`islandStripMinHeight`); the clamp only matters on a device that
        // reports a shorter inset than we ask for.
        let control = min(DexMetrics.controlButton, height - DexMetrics.islandBottomInset)

        let dot = max(control * 0.17, 8)

        return HStack(alignment: .center, spacing: 0) {
            // Orb pinned left, directly above the Back button.
            //
            // Rendering *in* the cutout is not an option, for the record: the
            // island is hardware, the OS masks anything drawn under it, and
            // putting content there means a Live Activity — ActivityKit plus a
            // widget-extension target, which a SwiftPM/xtool project has no way
            // to add.
            lcdOrb(size: control)
                .scaleEffect(orbHeld ? 0.88 : 1)
                .brightness(orbHeld ? -0.18 : 0)
                .animation(.easeOut(duration: 0.12), value: orbHeld)
                // Hold to flip. A hidden gesture on a decorative-looking part
                // is a poor primary affordance, but this one is a deliberate
                // easter egg: the orb depresses under the finger so the
                // feedback arrives before the flip does.
                //
                // One second, down from two. Two is long enough that someone who
                // already knows the gesture assumes it has stopped working and
                // lets go early — the orb depressing gives immediate feedback,
                // so the hold only has to be long enough not to fire on a tap.
                .onLongPressGesture(minimumDuration: 1.0) {
                    Haptics.tap()
                    orbHeld = false
                    isFlipped = true
                } onPressingChanged: { pressing in
                    orbHeld = pressing
                    if pressing { Haptics.orbPress() }
                }
                .fixedSize()
                // VoiceOver never delivers a long press to a decorative
                // element, so without this the back of the device — version,
                // maker's mark, serial, stamps — had no route in at all. One
                // element with a button trait and an activation action, which
                // is the same gesture VoiceOver already uses for every other
                // control on the chassis. (AUDIT **M21**)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Indicator orb")
                .accessibilityHint("Turns the device over to its back plate")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    Haptics.tap()
                    isFlipped = true
                }

            // Status lights to the *right* of the orb, as a layout sibling.
            //
            // They were an overlay pinned to the orb's top-right shoulder, which
            // cost no width but did put the cluster across the orb's own edge —
            // at one shared control size the two collide outright. Beside it they
            // cost real width, which the flanking spacers pay for; the cluster is
            // sized off the orb so the pair stays proportional.
            Color.clear.frame(width: DexMetrics.statusDotsGap)
            statusDots(size: dot)
                // Lifted off the orb's centre line so they read as indicator
                // lamps above the control rather than as more of the orb — see
                // `DexMetrics.statusDotsRise`.
                .offset(y: -DexMetrics.statusDotsRise)
                // Decoration only, and never a touch target sitting next to one.
                .allowsHitTesting(false)
                .fixedSize()

            // The title lip holds the island's clearance open (0.6.5, item 4),
            // centred between the orb and the cog. The lip is taller than the
            // row and bottom-aligned in it, so it reaches the display's top
            // edge; the letters keep to its lower band, below the ~48pt the
            // hardware cutout claims.
            //
            // On a flat-topped display there is no cutout to keep clear of, so
            // the reservation goes and the lip takes the width its wordmark
            // actually needs — which on an SE-class screen is width the orb,
            // lamps and cog were being squeezed out of, to hold open a hole
            // that is not there. (AUDIT **L32**)
            Spacer(minLength: 0)
            titleLip(control: control)
                .frame(minWidth: hasCutout ? DexMetrics.islandClearance : 0)
                .frame(height: control, alignment: .bottom)
                .offset(y: -DexMetrics.islandBottomInset)
            Spacer(minLength: 0)

            // Cog pinned right, directly above Home.
            settingsButton(size: control)
                .fixedSize()
        }
        .padding(.horizontal, DexMetrics.islandFlankPaddingH)
        // Bottom-aligned with the small inset below, mirroring the footer's
        // asymmetry: extra strip height (a device reporting a deeper top inset
        // than we ask for) lands above the controls, on bare chassis, rather
        // than being split and reopening the gap to the screen housing.
        .padding(.bottom, DexMetrics.islandBottomInset)
        .frame(height: height, alignment: .bottom)
    }

    /// A brushed-silver cog: the settings button.
    ///
    /// Was the pixel-V wordmark, which looked like branding and so read as
    /// decoration — nobody expects a logo to be tappable. A cog states what it
    /// does. Same diameter as the footer controls, so every button on the
    /// chassis is one size.
    /// Back on the skin's caps (v0.5.4, reversing 0.5.3's mode livery) —
    /// see the note on `ChassisButton`. The glyph keeps its brushed-silver
    /// gradient: a machined part, whatever the shell.
    private func settingsButton(size: CGFloat) -> some View {
        Button {
            Haptics.tap()
            onSettings?()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(dexHex: "#f4f5f6"),
                            Color(dexHex: "#c3c6ca"),
                            Color(dexHex: "#8b8f95"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
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
            .modifier(
                PulseGlow(
                    color: skin.orbGlow,
                    period: 5.3,
                    minRadius: 2,
                    maxRadius: size * 0.3,
                    paused: showsBackFace
                )
            )
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
            .modifier(
                PulseGlow(
                    color: fill,
                    period: period,
                    minRadius: 1,
                    maxRadius: size * 0.7,
                    paused: showsBackFace
                )
            )
    }

    // MARK: Screen

    private var screenHousing: some View {
        // The white bezel: 6pt borders on left/right/bottom, none on top.
        VStack(spacing: 0) {
            // Just enough margin to clear the bezel's rounded corner — the orb,
            // lights and wordmark now live in the island strip above.
            Color.clear.frame(height: DexMetrics.bezelTopMargin)
            innerBezel
            bottomVents
        }
        .background(skin.panel)
        .clipShape(
            .rect(
                topLeadingRadius: DexMetrics.screenPanelCorner,
                bottomLeadingRadius: DexMetrics.screenPanelCorner,
                bottomTrailingRadius: DexMetrics.screenPanelCorner,
                topTrailingRadius: DexMetrics.screenPanelCorner
            )
        )
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: DexMetrics.screenPanelCorner,
                bottomLeadingRadius: DexMetrics.screenPanelCorner,
                bottomTrailingRadius: DexMetrics.screenPanelCorner,
                topTrailingRadius: DexMetrics.screenPanelCorner
            )
            .strokeBorder(skin.panelEdge, lineWidth: DexMetrics.screenPanelBorder)
            // NOCTURNE's charge: the housing rim glows softly. Two stacked
            // shadows — a tight one and a wide one — read as phosphor rather
            // than as a drop shadow.
            .shadow(color: skin.rimGlow?.opacity(0.9) ?? .clear, radius: 6)
            .shadow(color: skin.rimGlow?.opacity(0.5) ?? .clear, radius: 16)
        }
        .padding(.horizontal, DexMetrics.screenPanelInset)
        .frame(maxHeight: .infinity)
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
        ZStack {
            Circle()
                .fill(Dex.red500)
                .frame(width: DexMetrics.ventDot, height: DexMetrics.ventDot)
                .overlay(Circle().strokeBorder(Dex.red800, lineWidth: 1))
                .shadow(color: Dex.red500.opacity(0.8), radius: 3)

            HStack {
                Spacer()
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(skin.grill).frame(width: 64, height: 2)
                    }
                }
                .opacity(0.5)
                // Pulled in off the panel's rounded corner, which the slats
                // were running into at their right end.
                .padding(.trailing, DexMetrics.headerPaddingH + DexMetrics.screenPanelCorner * 0.5)
            }
        }
        .frame(height: DexMetrics.ventStripHeight)
    }

    // MARK: Footer

    private func footer() -> some View {
        HStack(spacing: 8) {
            // Back and Home act on whatever is in front of you. With the panel
            // open (or the device flipped) they dismiss that first, rather than
            // navigating underneath it and appearing to do nothing.
            // Back where there is somewhere to go; otherwise the slot earns
            // its keep as the way into saved entries.
            if showsBack || isFlipped {
                ChassisButton(kind: .back, enabled: true) {
                    if isFlipped {
                        isFlipped = false
                    } else {
                        onBack?()
                    }
                }
            } else {
                ChassisButton(kind: .bookmarks, enabled: onBookmarks != nil) {
                    onBookmarks?()
                }
            }

            MarqueeBanner(
                segments: footerSegments,
                symbol: footerSymbol,
                fontSize: DexMetrics.marqueeTextSize,
                // `showsBackFace`, not `isFlipped`: the front face stays fully
                // visible through the first half of the turn, and freezing a
                // marquee that is still on screen reads as a hang. This is the
                // exact instant the face goes to `opacity 0`. (AUDIT M8)
                paused: showsBackFace
            )
            .frame(maxWidth: DexMetrics.marqueeMaxWidth)
            .frame(maxWidth: .infinity)

            ChassisButton(kind: .home, enabled: onHome != nil) {
                isFlipped = false
                        onHome?()
            }
        }
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
}

/// The title lip's silhouette (0.6.5, item 4): wide at the top edge where it
/// leaves the chassis, shoulders curving in to a narrower flat foot — the
/// 0.6.2 trapezoid bump turned upside down, hanging instead of rising.
private struct TitleLip: Shape {
    func path(in rect: CGRect) -> Path {
        let shoulder = rect.width * 0.14
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY),
            control: CGPoint(x: rect.maxX - shoulder * 0.3, y: rect.maxY - rect.height * 0.18)
        )
        p.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.minX + shoulder * 0.3, y: rect.maxY - rect.height * 0.18)
        )
        p.closeSubpath()
        return p
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
        let loaded = DexResources.url(named: name, ext: "png", in: .chassis)
            .flatMap { UIImage(contentsOfFile: $0.path) }
        cache[name] = loaded
        return loaded
    }
}

/// The pixel-V wordmark, bundled from the web app's logo.
struct LogoMark: View {
    init() {}

    var body: some View {
        if let url = DexResources.url(named: "vinodex-logo", ext: "png", in: .logo),
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
