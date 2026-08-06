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
    /// The drawn button face for that glyph, or nil where the route has none
    /// (0.8.3, A). Routed from `DexRoute.marqueeArt`.
    var marqueeArt: String?
    var showsBack: Bool = false
    var onBack: (() -> Void)?
    var onHome: (() -> Void)?
    /// Opens saved entries. On the main screen this takes the Back button's
    /// slot, which would otherwise be a permanently greyed-out control.
    var onBookmarks: (() -> Void)?
    /// Opens the settings screen.
    var onSettings: (() -> Void)?
    /// Pushes any route, from the marquee's two lamp buttons (0.7.1 B5; the
    /// lamps' own since 0.7.6, A1).
    ///
    /// One callback for several destinations rather than one per destination:
    /// a lamp's target is a `MarqueePin`, which resolves to a `DexRoute`, and
    /// `DexRoute` already travels between the modules. The four above stay as
    /// they are because they are *chassis controls* — Back, Home, Saved and the
    /// cog are physical buttons whose meaning is fixed, and collapsing them into
    /// this would lose that distinction to save four lines.
    var onQuickRoute: ((DexRoute) -> Void)?
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

    /// The main screen's marquee script (0.7.1, B1-B3) — see `MarqueeScript`.
    /// State on the chassis rather than on the banner, because the chassis is
    /// what knows whether the main screen is showing and is mounted once for
    /// the life of the app, which is exactly the lifetime "once per launch"
    /// needs.
    @State private var script = MarqueeScript()
    // `drawerOpen` retired in 0.7.6 (A1) with `MarqueeDrawer` itself — see the
    // Decision recorded on `indicatorPills`. The panel is a display again.
    /// What the two marquee lamp buttons are pointed at (0.7.1 B5; 0.7.6, A1).
    ///
    /// `QuickPinStore` is `@Observable` and this is the one shared instance, so
    /// reassigning a lamp in the chooser repaints it here on the next render with
    /// nothing threaded between them.
    @State private var pins = QuickPinStore.shared
    /// Which lamp the reassignment chooser is open for, or nil (0.7.6, A1).
    @State private var lampBeingAssigned: Int?
    /// The app's one idle timer (0.7.3, F2). Drives both the marquee's greeting
    /// and the screensaver below — one threshold for both since 0.7.6 (A4). See
    /// `IdleMonitor`.
    @State private var idle = IdleMonitor.shared
    /// When the screensaver appeared, so its mark's position is measured from
    /// this run rather than from a global clock. Nil while it is down.
    @State private var screensaverSince: Date?
    /// Where on each axis's cycle this run of the screensaver began (0.7.6, A2).
    ///
    /// Drawn once, when the screensaver is raised, and held for as long as it is
    /// up — the position is still a pure function of `(now - since, start)`, so
    /// nothing is accumulated per frame. See `ScreensaverStart`.
    @State private var screensaverStart = ScreensaverStart.corner
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
    /// The workshop's part overrides (0.7.3, B1).
    ///
    /// `@AppStorage` for the reason the shell above is: it is KVO-backed, so the
    /// chassis repaints the instant a part changes — which is what makes the
    /// device itself the workshop's live preview. Nothing is threaded down from
    /// the builder screen; the builder writes the same keys the chassis reads,
    /// and the chassis is drawn around the LCD the builder is running inside.
    ///
    /// Empty is the default on every one of them and resolves to "whatever the
    /// shell says", so a device nobody has customised is byte-identical to
    /// 0.7.2's. See `ChassisLook`.
    @AppStorage(DeviceAxis.buttons.storageKey) private var partButtons = ""
    @AppStorage(DeviceAxis.orb.storageKey) private var partOrb = ""
    /// The two lamp axes (0.7.6, B1). Both empty on a device nobody has been into
    /// the workshop with, and both then resolve to the shell's own trio — which
    /// is byte-identical to what the chassis drew before they existed.
    @AppStorage(DeviceAxis.headerLamps.storageKey) private var partHeaderLamps = ""
    @AppStorage(DeviceAxis.marquee.storageKey) private var partMarquee = ""
    @AppStorage(DeviceAxis.marqueeLamps.storageKey) private var partMarqueeLamps = ""
    @AppStorage(DeviceAxis.grilleColor.storageKey) private var partGrille = ""
    @AppStorage(DeviceAxis.grilleShape.storageKey) private var partGrilleShape = ""
    /// Read for VINTAGE mode's monochrome pass over the LCD — see `innerBezel`.
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue

    /// The chassis owns the app's two largest movements — the 0.7s 3D flip and
    /// the footer marquee — so this is where Reduce Motion has to be read.
    /// (AUDIT M18)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// **A `ChassisLook`, not a `ChassisSkin`, since 0.7.3 (B1).**
    ///
    /// Every `skin.orb` / `skin.grill` / `skin.accent` in this file below still
    /// reads exactly as it did; the resolution of "the shell's, unless a part
    /// overrides it" happens once, here, rather than at each of the twenty call
    /// sites. Changing the type rather than renaming the property is deliberate —
    /// it let the compiler find every member this view actually uses, where a
    /// search-and-replace would have found the ones spelled the way I guessed.
    private var skin: ChassisLook {
        ChassisLook(
            skinRaw: skinRaw,
            buttons: partButtons,
            orb: partOrb,
            headerLamps: partHeaderLamps,
            marquee: partMarquee,
            marqueeLamps: partMarqueeLamps,
            grille: partGrille,
            grilleShape: partGrilleShape
        )
    }
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(
        title: String,
        marqueeSymbol: String? = nil,
        marqueeArt: String? = nil,
        showsBack: Bool = false,
        onBack: (() -> Void)? = nil,
        onHome: (() -> Void)? = nil,
        onBookmarks: (() -> Void)? = nil,
        onSettings: (() -> Void)? = nil,
        onQuickRoute: ((DexRoute) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.marqueeSymbol = marqueeSymbol
        self.marqueeArt = marqueeArt
        self.showsBack = showsBack
        self.onBack = onBack
        self.onHome = onHome
        self.onBookmarks = onBookmarks
        self.onSettings = onSettings
        self.onQuickRoute = onQuickRoute
        self.content = content
    }

    private var isMainScreen: Bool { title == "VINODEX" }

    /// What the panel says.
    ///
    /// **Scripted on the main screen since 0.7.1 (B1-B3), the page title
    /// everywhere else, as always.** The five toasts and the endless cycle
    /// 0.6.9's D3 built are gone; CHEERS! survives as the script's idle state,
    /// which is where a toast belonged all along. See `MarqueeScript` in Core
    /// for the three stages and the two dwells — this property is only the
    /// wiring.
    /// **Rotating toasts at rest since 0.7.2 (A8)**, which is why this reads
    /// `script.text` rather than `script.stage.text` — the stage knows it is
    /// idle, only the script knows which idle this is. See `MarqueeCheers`.
    ///
    /// **The toast is no longer main-screen-only (0.7.6, A4.)** A4 asks for the
    /// marquee greeting to fire wherever the screensaver does, which is
    /// everywhere — so the idle stage takes precedence over the page title and
    /// the panel says CHEERS! over a region scan just as it does over the menu.
    /// Everything else is unchanged: WELCOME! and MENU are still states of the
    /// *main* screen, because they are statements about a screen that is showing.
    ///
    /// The `.cheers` test rather than a read of `idle.stage` is deliberate. The
    /// script is what knows *which* toast this idle period is owed (A8's nine
    /// languages), and asking two sources whether the device is idle is how the
    /// panel ends up on a different reckoning from the screensaver behind it —
    /// the exact fault 0.7.3's F2 spent a batch removing.
    private func footerText(at now: Date) -> String {
        if script.stage == .cheers {
            // `screensaverSince` rather than a clock of the panel's own: the
            // toast and the screensaver are raised on the same threshold
            // (`IdleSchedule.cheers` resolves to `IdleSchedule.screensaver`),
            // so this is already the instant the idle period began, and reusing
            // it is what stops the words and the bouncing mark keeping two
            // reckonings of the same idle — 0.7.3's F2 again. Nil only under
            // Reduce Motion, which never reaches `.cheers` at all.
            guard let since = screensaverSince else { return script.text }
            return script.text(after: now.timeIntervalSince(since))
        }
        return isMainScreen ? script.text : title
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
    /// `isMainScreen` stays: `footerText` still needs it for the script.
    ///
    /// **K1 is partly reversed as of 0.7.2 (A3/A6)**, and it is worth being
    /// precise about which half. K1's argument was that the main screen has no
    /// *route*, so taking a glyph from the route table put an arbitrary picture
    /// on the panel. That still stands — nothing here reads `marqueeSymbol` for
    /// the main screen. What A3 adds is a glyph that names the panel's own word:
    /// MENU gets `DexGlyph.menu`, the four squares of the four tiles behind it.
    ///
    /// Only MENU. WELCOME! and the idle toasts stay bare, because a greeting is
    /// not a page and a glyph beside SANTE! would be decorating a decoration —
    /// which is the mistake K1 caught. So the glyph appears exactly when the
    /// panel is naming somewhere you are, on the main screen and every other.
    ///
    /// **A bare panel while the toast is up, on every screen (0.7.6, A4).** The
    /// rule above already said greetings get no glyph; A4 only widens where a
    /// greeting can happen, so the branch moves ahead of the page-title one
    /// rather than changing. A REGION SCAN glyph beside SANTE! would be the
    /// panel naming a page it has stopped naming.
    private var footerSymbol: String? {
        if script.stage == .cheers { return nil }
        guard isMainScreen else { return marqueeSymbol }
        return script.stage == .menu ? DexGlyph.menu : nil
    }

    /// `footerSymbol`'s drawn half (0.8.3, A), resolved through exactly the
    /// same branches so the two cannot name different pages.
    ///
    /// **MENU stopped answering nil in 0.8.4 (A1).** It answered nil for one
    /// release because the 0.8.1 button drop had no face for the menu *as a
    /// whole* — the four it had were the four categories — so the panel fell
    /// back to `DexGlyph.menu`, the four-square grid. The marquee drop has one,
    /// and it is the only glyph in either set drawn for the home screen rather
    /// than for a control on it.
    private var footerArt: String? {
        if script.stage == .cheers { return nil }
        guard isMainScreen else { return marqueeArt }
        return script.stage == .menu ? "marquee-menu" : nil
    }

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
        // The script's clock (0.7.1, B1-B3) — now only the WELCOME! beat
        // (0.7.3, F2).
        //
        // Keyed on the stage *and* on whether the main screen is showing, so a
        // navigation cancels the pending dwell and returning starts a fresh
        // one — `task(id:)` owning the lifetime is what makes an open sleep
        // safe to write, the same argument the retired greeting cycle made.
        .task(id: scriptKey) { await runScript() }
        // Leaving the main screen consumes the greeting and parks the script,
        // so coming back finds MENU rather than a second WELCOME!.
        .onChange(of: isMainScreen) { _, main in
            if !main { script.leftMainScreen() }
        }
        // **The marquee's ten seconds, now the app's ten seconds** (0.7.3, F2).
        //
        // The MENU→CHEERS! dwell used to be a `Task.sleep` in `runScript`
        // below, reset by exactly one thing in the app: a tap on the marquee
        // itself. It is now a stage of the one idle timer — the same timer that
        // raises the screensaver five seconds later — so a finger anywhere on
        // the device resets it, which is what it always claimed to mean.
        //
        // **On every screen since 0.7.6 (A4)**, and at the screensaver's own
        // threshold rather than 10 (A3; 60 seconds since 0.8.0's H, which moved
        // both together because the fold left one number).
        // The `isMainScreen` guard is gone: A4 asks for the greeting to
        // arrive with the screensaver, and the screensaver has never been
        // main-screen-only. `stage >= .toast` is unchanged and is what makes the
        // fold a threshold change — `.toast` is no longer separately reachable
        // (see `IdleSchedule.toast`), but `.screensaver` outranks it, so this
        // fires at the one threshold today and at two the day the knob comes
        // back.
        .onChange(of: idle.stage) { _, stage in
            guard stage >= .toast else { return }
            guard !reduceMotion else { return }
            script.timedOut()
        }
        // Any interaction, from anywhere. `MarqueeScript.noteActivity` returns
        // early when the panel is already at MENU, which is the overwhelming
        // majority of these.
        .onChange(of: idle.activityTick) { _, _ in
            noteActivity()
        }
    }

    /// What a script run belongs to. Off the main screen there is nothing to
    /// run, and the constant key stops a route change from restarting a task
    /// that immediately returns.
    private var scriptKey: String {
        isMainScreen ? "main|" + script.stage.rawValue : "away"
    }

    /// Sleep out the current stage's dwell, then advance.
    ///
    /// **Suspended under Reduce Motion**, and this is the stronger case of the
    /// two the banner makes: `MarqueeBanner` still cross-fades a *prompted*
    /// change (you navigated; the title follows), but these two transitions
    /// have no prompt at all — the device changes what it says while you are
    /// looking at a still screen. `PulseGlow` in this file settles on the most
    /// informative still state rather than stopping mid-cycle, and the same
    /// applies here: WELCOME! is not a resting state, so the script skips
    /// straight to MENU and holds there.
    private func runScript() async {
        guard isMainScreen else { return }
        guard !reduceMotion else {
            if script.stage != .menu { script.leftMainScreen() }
            return
        }
        guard let timeout = script.pendingTimeout else { return }
        // **Only the beat is timed here now** (0.7.3, F2). `awaitsIdleTimer`
        // marks the stages whose dwell belongs to the shared idle timer instead
        // — currently just MENU, whose ten seconds is `IdleSchedule.toast`. The
        // stage asks rather than this function hardcoding a case, so a stage
        // moving between the two clocks moves in `MarqueeScript` and not here.
        guard !script.stage.awaitsIdleTimer else { return }
        try? await Task.sleep(for: .seconds(timeout.after))
        guard !Task.isCancelled else { return }
        script.timedOut()
    }

    /// The user did something. Sends CHEERS! back to MENU and restarts the
    /// idle dwell — see `MarqueeScript.noteActivity`.
    ///
    /// **Now called for every touch in the app** (0.7.3, F2), via
    /// `IdleMonitor.activityTick`. It used to have exactly one call site — the
    /// marquee's own tap — on the argument that the four chassis buttons all
    /// navigate, and navigating off the main screen already parks the script.
    /// That was true and it was not enough: tapping a menu tile, scrolling, or
    /// any interaction that stayed on the main screen without opening the drawer
    /// counted as idleness, so the panel could drift to CHEERS! under somebody
    /// who had not stopped using the device. The marquee's tap still calls it
    /// directly, which is a harmless double-count — the second call finds the
    /// stage already at MENU and returns.
    ///
    /// **The `isMainScreen` guard came off in 0.7.6 (A4).** It was correct while
    /// the script only ever showed something on the main screen: off it, the
    /// panel was the page title and there was nothing for activity to reset. Now
    /// that a toast can be up over any screen, a touch anywhere has to be able to
    /// take it down — and `MarqueeScript.noteActivity` parks the script at MENU,
    /// which off the main screen simply means "the panel goes back to the title".
    private func noteActivity() {
        script.noteActivity()
    }

    private func frontFace(topStrip: CGFloat, housingTop: CGFloat) -> some View {
        ZStack(alignment: .top) {
            // The mock electronics sit behind the translucent shell and flip
            // with the front face — the back plate is its own opaque part.
            if skin.isTranslucent {
                InternalsView()
            }
            // The bare `ChassisSkin`, not the resolved look: the moulding, its
            // tiled pattern and PÉT-NAT's paper grain are the *shell*, and the
            // shell is the one part the workshop chooses whole rather than
            // recolours. Reaching through says so.
            ChassisShell(skin: skin.skin)

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
                lcdOrb(width: DexMetrics.islandOrb)
                    // Through `ChassisPress` since 0.8.3 (B2) — the same three
                    // numbers the footer caps now depress by. Unchanged values;
                    // they simply have a name and one home.
                    .scaleEffect(orbHeld ? ChassisPress.scale : 1)
                    .brightness(orbHeld ? ChassisPress.brightness : 0)
                    .animation(ChassisPress.motion, value: orbHeld)
                    // The bead is smaller than the slot on purpose: shrinking a
                    // control's art is not a licence to shrink its touch area,
                    // so the hit shape stays the full 44pt slot around it.
                    //
                    // **A rectangle again since 0.7.6 (E1).** 0.7.5's A2 made the
                    // hit shape follow the part's own outline, on the argument
                    // that a squared key with a circular hit region has dead
                    // corners exactly where the eye says the part is. That
                    // argument holds only while the art fills the slot. The orb
                    // is now barely half the slot's height, so following its
                    // outline would cut a 44pt target down to a 35×20 one —
                    // under the platform minimum, on the control that carries the
                    // flip gesture. The slot contains the bead either way, so
                    // there is no region here that looks like the part and does
                    // not act like it.
                    //
                    // **0.7.8's A3 elongates it further and this gets more
                    // right, not less.** The bead is 35.2 × 15.0 at SMALL now,
                    // so an outline-shaped target would be a third of the
                    // platform minimum on its short axis. Every point of
                    // elongation is an argument *for* this rectangle. The one
                    // thing to keep watching is the opposite reading — that a
                    // 44pt box around a 15pt bead is 29pt of chassis that
                    // silently flips the device — and it stays acceptable for
                    // the reason it always has: the slot is padding, nothing
                    // else lives in it, and the gesture is a one-second hold
                    // rather than a tap.
                    //
                    // **0.7.9's A1 makes the bead 79.44 × 14.98 at SMALL and
                    // 86.30 × 17.22 at LARGE, and the slot follows it across.**
                    // A3's rule was that a bead wider than the slot grows the
                    // slot to contain it, and 79.44 is comfortably past 44 — so
                    // the target is `islandOrbSlot` × `islandSlot`, 87.44 × 44
                    // at SMALL. The rectangle argument is untouched by the
                    // change and the "29pt of silent chassis" worry above is
                    // *better*: the box is now 4pt of padding either side of a
                    // bead that fills it, instead of 4.4pt around one that
                    // filled a fifth of it. The vertical padding — 14.5pt above
                    // and below — is the part still doing the platform-minimum
                    // job, and it is why the two axes had to be separated in
                    // `DexMetrics` rather than sharing one number.
                    .frame(width: DexMetrics.islandOrbSlot, height: slot)
                    .contentShape(Rectangle())
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
        // The fourth footer cap (0.8.2). Same rule as `ChassisButton`: the
        // sprite is the whole control, so it replaces the gradient, the rim and
        // the cog glyph together rather than sitting on top of them, and it is
        // withheld from the sketch shell whose parts are all pen strokes.
        // Nil falls through to everything this button drew in 0.8.1.
        // On every shell as of 0.8.5 (D1) — see `ChassisButton.drawnCap` for
        // why FIBERGLASS stopped being the exception.
        let drawnCap = ChassisCapLoader.shared.image(
            stem: "settings",
            inkHex: cap.topHex,
            // E1, same pair as `ChassisButton.capGlyphHex`: the cog is
            // incised into this cap exactly as the chevron and the house are
            // into theirs, and `settingsMoldedCap` below already tints its
            // stand-in glyph with this colour.
            glyphHex: cap.glyphHex
        )

        return Button {
            Haptics.tap()
            onSettings?()
        } label: {
            if let drawnCap {
                Image(uiImage: drawnCap)
                    // Smooth, with its three neighbours (0.8.5, E2) — see
                    // `ChassisButton`'s note. The cog is the sprite this matters
                    // most on: its knurl is a ring of dark ticks at the rim, and
                    // nearest-neighbour was sampling them to uneven widths.
                    .interpolation(.high)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                settingsMoldedCap(size: size, cap: cap)
            }
        }
        // **The chassis press, with its three neighbours (0.8.3, B2).** This
        // was `DexPressStyle(scale: 0.9)` — 0.6.7's note that "the cog has
        // pressed deeper than its three neighbours" and the sprite did not
        // change that. `ChassisPress.scale` is 0.88, which is deeper still, so
        // the exception has been overtaken rather than overruled: the four caps
        // now share one travel, and it is the one the cog was reaching for.
        .buttonStyle(ChassisPressStyle())
        .accessibilityLabel("Settings")
    }

    /// The rendered cog, and the fallback when there is no drawn cap.
    private func settingsMoldedCap(size: CGFloat, cap: ChassisControl) -> some View {
        Group {
            // The multiplier stays what it was and now sizes a box rather
            // than a symbol (0.8.1, J3): `system` is 189x190 and would have
            // laid out a point or two off the gear it replaces.
            DexChromeGlyph("system", symbol: "gearshape.fill", size: size * 0.52, tint: cap.glyph)
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
    }

    /// The orb's outline (0.7.5, A2; a stadium since 0.7.6, E1).
    ///
    /// **`RecessedLamp` covers it as of 0.8.0 (C2) — this paragraph is the
    /// argument it overturned, kept because it was right for four batches.** It
    /// read: that modifier is generic over `InsettableShape`, so the obvious read
    /// is that swapping shapes is a one-line call-site change — but the orb has
    /// never gone through it, deliberately, because it draws a part *recessed*
    /// into the deck, and the orb is a bead that stands **proud** of it. Routing
    /// the orb through it would invert the lighting on the one part meant to
    /// catch the light.
    ///
    /// Every clause of that is still true of a *bead*. It stopped being one: the
    /// orb is now the trio's length and a lamp's height, and `lcdOrb` carries the
    /// full reasoning. The shape constant stays here — it is what both the recess
    /// and the fill are cut to, and it is still one value so the next refinement
    /// is still one line.
    ///
    /// **E1 is a one-line change to that parameter, which is the point.** A2
    /// left the shape behind a single value precisely so the next refinement of
    /// it would not be a rewrite; it takes no size argument now because a
    /// `Capsule`'s radius is always half its short side, which is what makes a
    /// stadium a stadium.
    private static var orbShape: Capsule { Capsule(style: .continuous) }

    /// The bead itself.
    ///
    /// - Parameter width: the orb's **width**. Through 0.7.8 this was the number
    ///   that was authored and the height fell out of `islandOrbAspect`; since
    ///   0.7.9's A1 the arrow points the other way — the width is the lamp
    ///   trio's span and the height is the authored axis — but the arithmetic
    ///   here is unchanged, because dividing the real width by the derived
    ///   aspect returns exactly `DexMetrics.islandOrbHeight`.
    ///
    /// **C2 (0.8.0): the orb wears the lamps' treatment.** This function used to
    /// draw a bead standing proud — a thick white bezel all the way round, a
    /// specular dot, a drop shadow outward — and `RecessedLamp`'s own note above
    /// explains at length why that is *not* what the lamps get and why the orb
    /// had deliberately never been routed through it: seating a part that is
    /// meant to catch the light inverts its lighting.
    ///
    /// **That argument was about a bead, and there is no longer a bead.** It was
    /// written when the orb was a 35pt near-square catching a highlight on its
    /// crown. Since 0.7.9's A1 it is the length of the whole lamp trio, and since
    /// C1 it is also exactly a lamp's height — the same short axis, in the same
    /// row, at the same distance from the eye. Two parts that are that alike and
    /// lit two different ways do not read as a matched pair; they read as one of
    /// them being wrong, which is what C2 reports. The specular in particular was
    /// a circle sized off the short axis, and on a 79 x 22 stadium it had become
    /// a dot floating in the top-left of a slot.
    ///
    /// So it goes through `recessedLamp` like everything else on this chassis,
    /// which is the one-line call the modifier was made generic for. `size:` is
    /// the height, per its own contract for a capsule. The rim tone is
    /// `skin.orbGlow` — the deeper of the orb's two colours, which is exactly the
    /// relationship the lamps' `(fill, border)` pairs have — so no
    /// twenty-one-shell table had to be invented for this.
    ///
    /// **The glow keeps A1's short-axis rule and loses its 2pt minimum**, which
    /// was the last number in here written against the old bead. `minRadius: 1`
    /// is the lamps'.
    private func lcdOrb(width: CGFloat) -> some View {
        let shape = Self.orbShape
        let height = width / DexMetrics.islandOrbAspect
        return shape
            .fill(skin.orb)
            .frame(width: width, height: height)
            .recessedLamp(shape, size: height, rim: skin.orbGlow)
            // **Off the short axis since 0.7.9 (A1).** The glow was `width *
            // 0.3`, which was 10.6pt while the bead was 35.2 across and would
            // be 23.8 now that it is 79.4 — a halo more than twice the height
            // of the part emitting it. `height * 0.7` is the same short-axis
            // rule the recess's own fractions follow, and it is what the three
            // status lamps beside it already use.
            .modifier(
                PulseGlow(color: skin.orbGlow, period: 5.3, minRadius: 1, maxRadius: height * 0.7)
            )
    }

    private func statusDots(size: CGFloat) -> some View {
        // The shell's trio, unless the workshop has fitted a colour (0.7.6, B1).
        // `headerLights`, not `statusLights`: the two lamps over the marquee are
        // their own axis now and must not follow this one — see `ChassisLook`.
        let lights = skin.headerLights

        return HStack(spacing: DexMetrics.statusDotSpacing) {
            statusDot(lights[0].fill, border: lights[0].border, period: 6.1, size: size)
            statusDot(lights[1].fill, border: lights[1].border, period: 7.4, size: size)
            statusDot(lights[2].fill, border: lights[2].border, period: 4.8, size: size)
        }
    }

    /// Seated in its recess since 0.7.1 (A6) — see `RecessedLamp`. The pulse
    /// stays outside the recess: the glow is light leaving the lamp, so it
    /// belongs over the whole part rather than under its rim.
    private func statusDot(_ fill: Color, border: Color, period: Double, size: CGFloat) -> some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .recessedLamp(Circle(), size: size, rim: border)
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
    /// bulb at two sizes, not two parts — which is exactly why A6's "dual red
    /// indicator lights *and* the bottom-bezel red indicator light" is one
    /// edit here rather than two.
    ///
    /// Seated in its recess since 0.7.1 (A6). These sit on the *white* bezel,
    /// where a flat red disc with a hairline round it read as a printed dot
    /// more than anywhere else on the device; the recess is what makes them
    /// bulbs. The red halo stays — a lamp that is lit throws light on the
    /// plastic around it — but drops from a flat radius 3 to a fraction of the
    /// diameter, because the 10pt pair were wearing the 12pt lamp's glow.
    private func ventDot(size: CGFloat) -> some View {
        Circle()
            .fill(Dex.red500)
            .frame(width: size, height: size)
            .recessedLamp(Circle(), size: size, rim: Dex.red800)
            .shadow(color: Dex.red500.opacity(0.8), radius: size * 0.26)
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

            // The lamp-reassignment chooser (0.7.6, A1).
            //
            // Inside the LCD, above the screen and below the scanlines — the
            // slot the retired drawer used, and for the reason that outlived it:
            // every overlay in this app is confined to the display, so it is
            // subject to the monochrome pass, the tint and the clip, and reads as
            // something this screen is doing rather than as an iOS sheet.
            //
            // It is *configuration*, not navigation, which is the distinction the
            // Decision turns on: the drawer was a second way to go places beside
            // the lamps, and this is the only way to say where a lamp goes. One
            // access pattern, one settings surface for it.
            if let slot = lampBeingAssigned {
                MarqueeLampChooser(
                    slot: slot,
                    onClose: { withAnimation(DexMotion.overlay) { lampBeingAssigned = nil } }
                )
            }

            // The idle screensaver (0.7.3, A5).
            //
            // Above the content and the chooser, below the scanlines — the
            // same slot and the same reason: it is subject to the display's own
            // treatments (the monochrome pass, the tint, the clip), so it reads
            // as something this screen is doing rather than as an overlay
            // floating on top of the device.
            //
            // No dismissal wiring of its own. Any touch is seen by
            // `IdleTouchWatcher` on the window before this view hears anything,
            // which drops the stage to `.active` and takes this branch away.
            if let screensaverSince {
                Screensaver(since: screensaverSince, start: screensaverStart)
            }

            // Confined to the LCD, so the bezel, footer and island stay put and
            // the panel reads as the device's own menu rather than an iOS modal.
            ScanlineOverlay()
                .opacity(DexMetrics.scanlineOpacity)
                .allowsHitTesting(false)

            // The refresh flash (0.7.5, A3).
            //
            // Last in the stack so it covers the screen, the chooser and the
            // scanlines alike — a panel refreshing redraws all of it — but
            // still *inside* the two modifiers below, so it is desaturated and
            // tinted with everything else and comes out in the phosphor's own
            // colour rather than white.
            LcdRefreshFlash(screen: title, tint: lcd.monochromeTint, reduceMotion: reduceMotion)
                .allowsHitTesting(false)
        }
        .animation(DexMotion.overlay, value: lampBeingAssigned)
        .animation(DexMotion.overlay, value: screensaverSince)
        // Turning the device over closes it: the chooser belongs to the front
        // face, and leaving it open behind the back plate would put it there
        // waiting when the device came back round.
        .onChange(of: showsBackFace) { _, back in
            if back { lampBeingAssigned = nil }
        }
        // Raise and drop the screensaver from the shared idle stage (0.7.3, A5).
        //
        // The timestamp and the start phase are both set on the way *up* only,
        // so each idle period is its own run rather than a resumption of the last
        // one — and, since 0.7.6 (A2), so the mark begins somewhere different
        // each time instead of always in the top-left corner. Drawn here rather
        // than inside `Screensaver` because that view's body runs at display
        // rate: a random phase read per frame would be static, not a bounce.
        //
        // **Reduce Motion suppresses it**, on the same reading `runScript` makes
        // of the marquee transitions: this is an unprompted, permanently moving
        // image, which is the exact category that setting exists for. The screen
        // simply stays as it was, which on a device that never dims is the same
        // behaviour every build before 0.7.3 had.
        .onChange(of: idle.stage) { _, stage in
            guard !reduceMotion else { return }
            if stage >= .screensaver {
                if screensaverSince == nil {
                    screensaverStart = .random()
                    screensaverSince = .now
                }
            } else {
                screensaverSince = nil
            }
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
            // own room, and **fitted rather than moulded in since 0.7.3 (B1)**:
            // the pattern is a part the player chooses. `ChassisGrille` holds
            // every pattern to the slats' own 64×17 slot, so changing it cannot
            // move the wordmark or the lamp sharing this run.
            ChassisGrille(shape: skin.grilleShape, ink: skin.grill)
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

    // `ventSlat` retired in 0.7.3 (B1). It was one 64×2 capsule at 0.5 opacity,
    // stamped four times above; `ChassisGrille.slats` is that exact vent and is
    // still the default, so a device nobody has been into the workshop with is
    // drawn identically.

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
                //
                // **A display again since 0.7.6 (A1), reversing 0.7.1's B4.**
                // B4 made the panel a button because the drawer needed a handle
                // and the marquee is the one surface mounted on every screen.
                // The Decision retires the drawer, and with it the only thing
                // this button opened — so rather than leave a control that
                // toggles nothing, or invent a second destination for it, the
                // panel goes back to being what it looks like. A display that
                // does something when you press it and a display that does not
                // are both fine; a display that used to is the bad option.
                //
                // The corner pin buttons (0.7.2, A7) go with it, and for a
                // sharper reason: they existed to put a pinned section within
                // reach without opening the drawer, and the lamps two points
                // above them now *are* the pins. Two pin buttons and two pin
                // lamps on one panel would be the duplication the Decision is
                // removing, drawn twice on the same 225pt of chassis.
                // **A clock, not a timer (0.8.1, I2).** The panel is static at
                // rest, so a value that is a function of time needs something
                // to invalidate it; `TimelineView(.periodic)` is the same
                // mechanism the screensaver already uses to be a pure function
                // of `now`, one tick per language rather than one per frame.
                // Anchored on the idle's own start so a tick lands exactly on
                // each five-second boundary, and always mounted so the banner
                // keeps its identity — a conditional `TimelineView` would swap
                // the view out from under `shown` and turn every arrival at
                // CHEERS! into a remount instead of a dissolve.
                TimelineView(.periodic(from: screensaverSince ?? .now, by: MarqueeCheers.dwell)) { tick in
                    MarqueeBanner(
                        text: footerText(at: tick.date),
                        symbol: footerSymbol,
                        art: footerArt,
                        fontSize: DexMetrics.marqueeTextSize,
                        // `showsBackFace`, not `isFlipped`: the front face stays
                        // fully visible through the first half of the turn, and
                        // freezing a marquee that is still on screen reads as a
                        // hang. This is the exact instant the face goes to
                        // `opacity 0`. (AUDIT M8)
                        paused: showsBackFace,
                        // **Which changes get the long dissolve (0.8.5, A3).**
                        // Every change is pixelated now — see `MarqueeBanner.slowFade`
                        // — and this expression is unchanged in every other respect,
                        // because what it has always actually selected is the
                        // *scripted* stages: the greeting cycle on the main screen and
                        // the idle toast anywhere. Those are the panel talking to you
                        // rather than naming a page, and they get the 1.4s.
                        //
                        // The asymmetry is deliberate and is kept: this is true on the
                        // way *in* to CHEERS! (the stage is `.cheers` when the text
                        // changes to the toast) and false on the way *out* (activity
                        // has already parked the script at MENU). The user has just
                        // touched the device and wants the title back, so leaving the
                        // greeting takes the short dissolve — which as of A3 is a
                        // dissolve rather than a cross-fade, and is the one thing
                        // about this line that has changed.
                        slowFade: isMainScreen || script.stage == .cheers
                    )
                }
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

    // `pinCornerReserve`, `pinCorners` and `pinButton` retired in 0.7.6 (A1),
    // along with `MarqueeDrawer` and the three metrics they used
    // (`marqueePinButton`, `marqueePinInset`, `marqueePinGlyph` — kept in
    // `DexMetrics` with a retirement note rather than deleted, so the arithmetic
    // 0.7.2 wrote down survives the feature).
    //
    // They were 0.7.2's answer to "a pinned thing should be reachable without
    // opening the drawer", built as two 26pt circles in the panel's top corners.
    // A1 answers the same question with the two lamp buttons instead, which are
    // 24pt tall, are already there, and do not have to be paid for out of the
    // label's width — `edgeReserve` on `MarqueeBanner` was that payment and now
    // resolves to zero everywhere.

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
    /// **Skin-tinted since 0.7.1 (A7)**, reversing 0.6.5's decision, which is
    /// worth stating plainly rather than quietly deleting. That decision was:
    /// fixed red and blue, because these are the same bulbs as the vent lamp —
    /// the chassis's plain power/link indicators — and the skin's colours were
    /// already spoken for by the lamps upstairs. Two things were wrong with it.
    /// The first is that it was not true of the whole device: HALLOWINE, VINHO
    /// VERDE and CHAMPAGNE repaint the trio, the orb, the marquee ground, the
    /// grid and the letters, and then ran a Tailwind red and a Tailwind blue
    /// across the middle of all of it. The second is that "already spoken for"
    /// treats a skin's lamp colours as a scarce resource; they are a palette,
    /// and the two pills reading it is what A7 asks for.
    ///
    /// The outer two of the skin's trio, not the first two: `statusLights` is
    /// ordered light-to-deep in most skins, so `[0]` and `[2]` are the widest
    /// pair the shell offers and the pills stay two distinguishable lamps
    /// rather than one colour twice. On CHRISTMAS, whose trio is deliberately
    /// three identical holly berries, they come out identical — which is that
    /// skin working, not this rule failing.
    ///
    /// **They are buttons since 0.7.2 (A9).** Which retired the sentence that
    /// used to stand here — "pills, not circles, so they cannot be mistaken at a
    /// glance for very small buttons" — because being mistaken for a button is
    /// the point. That rule was written when the pair was pure decoration; A9
    /// gave the two lamps two destinations, so the shape should advertise
    /// exactly what it turned out to be.
    ///
    /// Three things follow from it and all three are elsewhere:
    /// `bandPillHeight` goes 14 → 20 because a control has to be worth aiming at
    /// (see `DexMetrics`), each pill carries its destination's glyph so the
    /// colour is not the only thing distinguishing them, and the specular bead
    /// comes off (A4) because it sat exactly where that glyph goes.
    ///
    /// **The two lamps are the pins now (0.7.6, A1), and this is the Decision.**
    /// A9 hardwired them to TOOLS and CUSTOMIZE; those two are still where they
    /// point on a device nobody has changed, and each is now reassignable — see
    /// `QuickPinStore` and `MarqueePin`.
    ///
    /// The reasoning for collapsing three affordances into this one is worth
    /// keeping, because two of the three were built deliberately and are being
    /// removed deliberately. Through 0.7.5 the device offered: these two lamps
    /// (fixed destinations, always visible, one tap), two pin buttons in the
    /// marquee's corners (chosen destinations, always visible, one tap, 26pt), and
    /// a swipe drawer behind the panel (every destination, hidden, two taps) whose
    /// PINNED row was the only way to choose what the corners held. Three answers
    /// to one question, one of which existed only to configure another.
    ///
    /// What the merged form keeps from each: the lamps' hardware feel — nothing
    /// to open, nothing to learn, the buttons are simply *on the device* — and the
    /// drawer's customisation, which was the whole reason the pin bar was built.
    /// What it drops is the drawer's breadth, and that is the honest cost: its
    /// TOOLS grid and CUSTOMIZE shortcuts are one tap further away again, through
    /// the shelf and the settings panel the lamps land on. Both of those screens
    /// already existed and both are still one lamp press away, which is what makes
    /// the trade payable.
    ///
    /// **Tap to go, press and hold to reassign.** The same tap/hold split the back
    /// plate's stamps use (tap opens the story, hold picks it up) and the retired
    /// drawer's own chips used (tap goes there, hold pins it) — so it is a pair
    /// this device has taught twice already rather than a new idiom. Hold is a
    /// hidden gesture and that is accepted here for a reason A7's corner pins
    /// could not claim: reassignment is a once-a-year act on a control that works
    /// perfectly without it, and the walkthrough's marquee step (F1) now says so
    /// out loud, which is the discoverability the drawer's "HOLD A SHORTCUT TO PIN
    /// IT" line used to carry.
    ///
    /// The outer two of the shell's trio, not the first two: `statusLights` is
    /// ordered light-to-deep in most skins, so `[0]` and `[2]` are the widest pair
    /// it offers and the lamps stay two distinguishable colours rather than one
    /// twice. On CHRISTMAS, whose trio is three identical holly berries, they come
    /// out identical — which is that skin working, not this rule failing.
    ///
    /// **`marqueeLights`, not `statusLights`, since 0.7.6 (B1)** — these two are
    /// their own workshop axis now, so recolouring the header trio no longer
    /// repaints the pair down here.
    ///
    /// Recessed since 0.7.1 (A6) like every other lamp.
    ///
    /// **As wide as the marquee since 0.6.7 (F4)**, and measured off it rather
    /// than given a width: the pair sits in the marquee's own column, so two
    /// pills each taking half of it less the gap span the panel exactly at any
    /// screen width and any `UIScale`. The two fixed widths this replaces (18pt,
    /// then 30) were each only ever right on one phone.
    private var indicatorPills: some View {
        let lights = skin.marqueeLights

        return HStack(spacing: DexMetrics.bandPillSpacing) {
            lampButton(slot: 0, fill: lights[0].fill, border: lights[0].border, ink: lights[0].ink)
            lampButton(slot: 1, fill: lights[2].fill, border: lights[2].border, ink: lights[2].ink)
        }
        .frame(maxWidth: .infinity)
    }

    /// One lamp button: its pin's glyph, its pin's destination, and a hold that
    /// opens the chooser for this slot.
    private func lampButton(
        slot: Int,
        fill: Color,
        border: Color,
        ink: Color
    ) -> some View {
        // The store always holds `capacity` pins, so this is a formality — but a
        // chassis that crashed because a list was short would be a poor trade for
        // one saved line. See `QuickPinStore.decode`.
        let pin = pins.pin(at: slot) ?? QuickPinStore.defaults[min(slot, QuickPinStore.defaults.count - 1)]

        return Button {
            Haptics.tap()
            noteActivity()
            onQuickRoute?(pin.route)
        } label: {
            Capsule()
                .fill(fill)
                .frame(maxWidth: .infinity)
                .frame(height: DexMetrics.bandPillHeight)
                .overlay {
                    // **The pin's name, engraved (0.8.5, A2)** — and this
                    // replaces the drawn face 0.8.3's H put here, so the
                    // paragraphs below are the argument being set aside.
                    //
                    // A2's reference is a controller's START and SELECT: a word
                    // cut into the cap rather than a picture printed on it. The
                    // reason it is the better answer *here* and not everywhere
                    // is that these two buttons are reassignable. Every other
                    // control on this chassis means one fixed thing and can be
                    // learned as a shape; a lamp means whatever the user last
                    // pointed it at, and a picture of TOOLS and a picture of
                    // DATA are two chrome glyphs a millimetre wide that nobody
                    // has any reason to be able to tell apart. The word is what
                    // makes the customisation legible from across the room,
                    // which is most of what A1 built it for.
                    //
                    // `.engraved` rather than a drop shadow: a highlight *below*
                    // the letters and a shade *above* them is what an incised
                    // legend on a lit cap looks like, and it is the same
                    // treatment the back plate's nameplate wears. Brighter and
                    // softer than the plate's defaults, because a lamp is
                    // saturated plastic with a light behind it rather than
                    // brushed aluminium.
                    //
                    // Fitted rather than truncated: CUSTOMIZE is nine characters
                    // on a cap roughly seven wide at `bandPillLabel`, so the
                    // scale factor is doing real work on the longest pin rather
                    // than sitting there as a guard.
                    //
                    // What goes with the picture, recorded because it was argued
                    // for twice. `ink` — 45% of the lamp's own hue toward black
                    // — is kept as the letter colour, and it is kept for 0.7.5
                    // A1's reason: it is a shade the lamp is already wearing,
                    // one stop below the rim it is drawn with, so the legend
                    // reads as cut into the cap rather than printed on it. What
                    // is retired is 0.8.3's H, which put the drawn button face
                    // here in its own colours; `MarqueePin.artStem` still
                    // resolves all five and is still what `MarqueeLampChooser`
                    // draws, so the faces have a surface and this one has a
                    // word.
                    //
                    // **One size for all five, fitted to the longest (0.8.6,
                    // D1).** A2 left this on `DexFont.retro` plus a scale factor
                    // down to 0.45, and the two halves of that combined into the
                    // defect the item names: `retro` multiplies by `TextScale`,
                    // which `bandPillLabel`'s own note says this legend must not
                    // do, and `minimumScaleFactor` then fits *each label
                    // separately* — so DATA rendered at the full size, SETTINGS a
                    // little under it and CUSTOMIZE well under, and the two lamps
                    // sitting side by side wore two different types.
                    //
                    // The fix is to fit once, to the widest word in the
                    // vocabulary, and give every lamp that answer. Rendering at a
                    // fixed size is the whole reason `retroFixed` exists; the
                    // fitting is `lampLabelSize`, which measures the face rather
                    // than assuming a ratio.
                    GeometryReader { geo in
                        Text(pin.displayName)
                            .font(DexFont.retroFixed(LampLegend.size(in: geo.size.width)))
                            .tracking(LampLegend.tracking)
                            .lineLimit(1)
                            .foregroundStyle(ink)
                            .engraved(light: 0.42, dark: 0.30)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .padding(.horizontal, LampLegend.inset)
                }
                // No bead (0.7.2, A4) — it would sit on the legend.
                .recessedLamp(
                    Capsule(),
                    size: DexMetrics.bandPillHeight,
                    rim: border,
                    bead: false
                )
                .modifier(
                    PulseGlow(
                        color: fill,
                        period: 5.7,
                        minRadius: 1,
                        maxRadius: DexMetrics.bandPillHeight
                    )
                )
                // The capsule is the target, not the glyph inside it.
                .contentShape(Capsule())
        }
        // Same reasoning as the marquee panel below it: these read as parts of
        // the shell, and a moulded lamp that shrinks under a finger reads as
        // loose. Arriving at the screen is the feedback.
        .buttonStyle(.plain)
        .disabled(onQuickRoute == nil || showsBackFace)
        // `simultaneousGesture` rather than `.gesture` so the button's own tap
        // is not swallowed — the two do different things and both must survive.
        // This is the drawer's own hold-to-pin wiring, kept when the surface
        // carrying it went.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                guard onQuickRoute != nil, !showsBackFace else { return }
                Haptics.select()
                noteActivity()
                withAnimation(DexMotion.overlay) { lampBeingAssigned = slot }
            }
        )
        .accessibilityLabel(pin.displayName)
        .accessibilityHint("Press and hold to point this button somewhere else")
        // VoiceOver cannot perform a long press, so the hold needs a named
        // action or the whole of A1's customisation is unreachable with the
        // screen reader on — the same provision the drawer's chips carried.
        .accessibilityAction(named: "Reassign") { lampBeingAssigned = slot }
    }
}

// MARK: - The lamp legend's one size (0.8.6, D1)

/// The arithmetic behind the two marquee lamps' engraved words.
///
/// **A file-private enum rather than statics on `DeviceChassis`**, which is
/// generic over its content and so cannot hold a static stored property at all —
/// Swift refuses them on generic types, and the two constants and the measured
/// longest word all want to be computed once rather than per lamp per frame.
private enum LampLegend {
    /// The gap between a legend and the ends of its cap.
    static let inset: CGFloat = 7
    /// Letter-spacing, in points. Absolute rather than proportional, which is
    /// why it is subtracted from the budget below rather than divided into it.
    static let tracking: CGFloat = 0.5

    /// The widest legend any lamp can ever carry.
    ///
    /// Taken from `MarqueePin.allCases` rather than written down as "CUSTOMIZE",
    /// so a sixth pin — or a `SettingsSection` renamed to something longer —
    /// moves the fitting instead of silently overflowing a cap. Counted in
    /// characters because the face is monospaced; see `DexFont.retroAdvanceRatio`.
    static let longest: Int = MarqueePin.allCases.map(\.displayName.count).max() ?? 9

    /// The size every lamp's legend renders at, on a cap this wide.
    ///
    /// The width of `n` monospaced characters at point size `s` is
    /// `n × (advance × s + tracking)`, so the largest `s` that fits a budget `w`
    /// is `(w / n − tracking) / advance`. Capped at `bandPillLabel`, which is
    /// what the type would be if the longest word did not need the help — on a
    /// wide enough device the cap applies and nothing is shrunk at all.
    ///
    /// The result is deliberately *not* per-label: it is computed for `longest`
    /// and handed to whatever word this lamp happens to be showing, which is the
    /// whole item. `lineLimit(1)` still guards the arithmetic, and it truncates
    /// rather than shrinking — a visible failure rather than the silent
    /// per-label refitting that was the bug.
    static func size(in width: CGFloat) -> CGFloat {
        let n = CGFloat(max(longest, 1))
        let fitted = (max(width, 1) / n - tracking) / DexFont.retroAdvanceRatio
        return max(min(DexMetrics.bandPillLabel, fitted), 6)
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

/// One indicator lamp, seated in a milled recess (0.7.1, A6).
///
/// **What A6 asked for and why it is one modifier.** Every lamp on this chassis
/// was drawn the same wrong way: a flat disc of colour with a 1pt keyline round
/// it. Three of them in the island strip, two on the white top bezel, one in
/// the bottom vent strip, two more as pills over the marquee — eight lamps,
/// four separate render functions, and not one of them looked like a part
/// *fitted into* the shell. The orb is the only thing on the device that did,
/// and A6 is the instruction to make the rest match it. One modifier rather
/// than four edits, because the next lamp added should be right by default —
/// the same argument `DexGlyph` makes for the glyph constants.
///
/// **The construction, and why it was not simply the orb's.** The orb was a bead
/// that stood *proud*: a thick white bezel all the way round, a specular dot,
/// and a drop shadow outward. Copying that onto a 22pt lamp gives a white ring
/// wider than the colour inside it. What reads as the orb at lamp scale is its
/// two halves separated — the bead itself keeps the highlight, and the bezel
/// becomes the well the bead sits in, which is `ButtonWell`'s rule already
/// working on the button caps six inches south:
///
/// **Since 0.8.0 (C2) the orb comes through here too**, and the paragraph above
/// is why the traffic runs this way round rather than the other: the lamp's
/// construction was derived *from* the orb, so pointing the orb at it is the
/// pair converging on the version that was already correct at both sizes. See
/// `DeviceChassis.lcdOrb`. Nothing in this modifier changed to accept it — the
/// `InsettableShape` generic and the short-axis `size:` contract were built for
/// the marquee's capsules and take the orb's unaltered.
///
/// 1. **The wall**, dark and blurred, riding a touch high — the top edge of a
///    recess is where no light reaches. Blurred because a recess has a radius;
///    a crisp stroke reads as a printed outline.
/// 2. **The lip**, pale and low, catching the same light the caps catch.
/// 3. **The keyline** the lamp always had, in the lamp's own dark tone. Kept,
///    and kept last, so the colour still terminates crisply instead of being
///    lost into the shading.
/// 4. **The bead**, a blurred white dot at the top — the orb's specular,
///    proportioned to this lamp rather than to that one. **Optional since
///    0.7.2 (A4)**; see `bead` below.
/// 5. **The seat**, a short dark drop that separates the part from the shell.
///
/// Everything is a fraction of `size` with a floor, so the same modifier is
/// correct on a 10pt vent lamp and a 22pt island lamp. Nothing here is
/// skin-coloured: shading is a property of the light, not of the plastic, which
/// is what lets one modifier serve all twenty-one shells.
///
/// Generic over `InsettableShape` because the lamps are circles and the marquee
/// indicators are capsules, and `strokeBorder` — which insets rather than
/// straddling the edge — is the only stroke that keeps a 2pt wall inside a 10pt
/// dot.
private struct RecessedLamp<S: InsettableShape>: ViewModifier {
    let shape: S
    /// The lamp's diameter (or, for a capsule, its height). Every measurement
    /// below is a fraction of it.
    let size: CGFloat
    /// The lamp's own dark keyline — the `border` half of the colour pair the
    /// skin or the palette already supplies.
    let rim: Color
    /// Whether to draw the specular bead (0.7.2, A4).
    ///
    /// A4 asks for the white dots off the **marquee** status lights, and only
    /// those pass `false`. The island trio and the vent lamps keep theirs: they
    /// are the lamps 0.7.1's A6 was drawn for, nothing sits on top of them to
    /// compete, and a chassis lamp with no highlight at all is a painted circle.
    ///
    /// The marquee pair is a different object as of A9 — the two pills are the
    /// TOOLS and CUSTOMIZE buttons and carry a glyph in the middle. A blurred
    /// white dot directly above that glyph is the specular fighting the label,
    /// and the wall/lip/keyline/seat still seat the pill perfectly well without
    /// it. So the dot comes off where the spec asked and where the drawing now
    /// needs it to, which is the same place.
    var bead: Bool = true

    func body(content: Content) -> some View {
        content
            .overlay(
                shape
                    .strokeBorder(.black.opacity(0.34), lineWidth: max(size * 0.16, 1.5))
                    .blur(radius: max(size * 0.08, 0.7))
                    .offset(y: -max(size * 0.05, 0.5))
            )
            .overlay(
                shape
                    .strokeBorder(.white.opacity(0.26), lineWidth: max(size * 0.07, 1))
                    .offset(y: max(size * 0.06, 0.6))
            )
            .overlay(shape.strokeBorder(rim, lineWidth: max(size * 0.06, 1)))
            .overlay(alignment: .top) {
                if bead {
                    Circle()
                        .fill(.white.opacity(0.7))
                        .frame(width: size * 0.24, height: size * 0.24)
                        .blur(radius: max(size * 0.04, 0.6))
                        .padding(.top, size * 0.14)
                }
            }
            .shadow(color: .black.opacity(0.45), radius: max(size * 0.12, 1), y: max(size * 0.06, 0.5))
    }
}

extension View {
    /// Seat a lamp in its recess — see `RecessedLamp` (0.7.1, A6).
    ///
    /// `bead` defaults to the highlight being present, so every existing call
    /// site is unchanged; the marquee pills opt out (0.7.2, A4).
    func recessedLamp<S: InsettableShape>(
        _ shape: S,
        size: CGFloat,
        rim: Color,
        bead: Bool = true
    ) -> some View {
        modifier(RecessedLamp(shape: shape, size: size, rim: rim, bead: bead))
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
/// Made `public` in 0.7.8 (B3) so the share cards can be cut to the device's
/// own silhouette. The card is a *still* — see `ShareCardFrame` for why it does
/// not render `DeviceChassis` itself — but the outline it traces is this one,
/// which is what stops the exported image from being a generic rounded box.
public struct ChamferedPanel: InsettableShape {
    public var corner: CGFloat
    public var chamfer: CGFloat
    public var inset: CGFloat = 0

    public init(corner: CGFloat, chamfer: CGFloat, inset: CGFloat = 0) {
        self.corner = corner
        self.chamfer = chamfer
        self.inset = inset
    }

    public func path(in rect: CGRect) -> Path {
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

    public func inset(by amount: CGFloat) -> ChamferedPanel {
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
        let loaded = DexResources.url(named: name, ext: "png", subdirectory: "Chassis")
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
    /// The button axis (0.7.3, B1) — the one part override this view can see.
    /// Read here for the same reason the shell is: the footer builds these, and
    /// threading it through would mean every future caller had to remember to.
    @AppStorage(DeviceAxis.buttons.storageKey) private var partButtons = ""

    private var skin: ChassisLook {
        ChassisLook(skinRaw: skinRaw, buttons: partButtons)
    }

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

    /// The drawn cap's stem under `Resources/FooterArt`, less the prefix.
    ///
    /// `bookmarks` is `user`, which is the illustrator's word for it and the
    /// one on the file. The enum case is not renamed: it is matched on in five
    /// places and reads correctly beside `onBookmarks`.
    private var capStem: String {
        switch kind {
        case .back: "back"
        case .home: "home"
        case .bookmarks: "user"
        }
    }

    /// The face colour the drawn cap is re-inked to.
    ///
    /// Home's comes from its accent ramp rather than from `cap`, exactly as its
    /// gradient does — `cap` is documented as never read for Home, and reading
    /// it here would have made the one lit button in the band the one button
    /// that ignored its livery.
    private var capInkHex: String {
        switch kind {
        case .back, .bookmarks: cap.topHex
        case .home: homeAccent.lightHex
        }
    }

    /// The colour the incised symbol is re-inked to (0.8.4, E1).
    ///
    /// Resolved from the same two places as `capInkHex`, so a cap cannot take
    /// its face from one livery and its glyph from another. `ChassisControl.glyph`
    /// is the colour the no-art fallback has always tinted its SF Symbol with,
    /// which is what makes this a *correction* rather than a new decision: every
    /// skin had already chosen this colour, and the drawn caps were the only
    /// surface ignoring it.
    ///
    /// Home reads `ink` rather than `glyph` because Home has no `ChassisControl`
    /// -- `cap` is documented as never read for it -- and `ChassisAccent.ink` is
    /// that ramp's own answer to the same question, the one `moldedCap` already
    /// gives the house glyph on its fallback path.
    private var capGlyphHex: String {
        switch kind {
        case .back, .bookmarks: cap.glyphHex
        case .home: homeAccent.inkHex
        }
    }

    /// The drawn cap, re-inked, when there is one and the shell wants it.
    ///
    /// **Nil on the sketch skin, deliberately.** That shell is a pen drawing —
    /// `SketchStroke` inks every circle by hand and 0.6.6's B3 removed the cast
    /// shadow from it on the grounds that "a cast shadow is the one thing a pen
    /// cannot do". A rendered pixel cap, with its own baked highlight and
    /// shadow, is a larger version of the same contradiction. It keeps the
    /// drawn controls it already had.
    /// **FIBERGLASS takes them too, as of 0.8.5 (D1)** — and the paragraph
    /// above is the argument that has been reversed, kept because it was a real
    /// one. It read: that shell is a pen drawing, `SketchStroke` inks every
    /// circle by hand, and 0.6.6's B3 removed the cast shadow from it because "a
    /// cast shadow is the one thing a pen cannot do"; a rendered pixel cap with
    /// its own baked highlight is a larger version of the same contradiction.
    ///
    /// Two things retire it. The first is that the contradiction has been
    /// shrinking on its own: 0.8.3's B1 removed the caps' painted cast shadow at
    /// import, and 0.8.5's E2 clips and feathers them to a fitted circle, so
    /// what a skin now adopts is a drawn *cap*, not a rendered photograph of
    /// one. The second is the item, which is worth taking at face value — the
    /// device's four most-used controls were one release behind on the shell a
    /// user has to pay to reach, and "it is consistent with the pen" is a
    /// smaller consideration than "it is the only skin still on the old
    /// buttons", which is what D1 says out loud.
    ///
    /// FIBERGLASS keeps its pen everywhere else: the body grain, the panel
    /// edges, the orb and the cog's rim are untouched, and the re-ink takes its
    /// own `#FBF8F1` face over `#2B3244` ink, which is the flattest pair in the
    /// range and the closest any skin gets to paper and pencil.
    private var drawnCap: UIImage? {
        ChassisCapLoader.shared.image(
            stem: capStem,
            inkHex: capInkHex,
            glyphHex: capGlyphHex
        )
    }

    public var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            // **The sprite replaces the control, not the glyph in it** (0.8.2).
            //
            // 0.8.1's J converted 32 button *faces*: glyphs that sit inside a
            // circle this view draws. These four are whole moulded caps — rim,
            // lit face, cast shadow, and the symbol incised into them. Drawing
            // one inside the gradient circle below would have stacked a painted
            // button on a rendered one, at two different rim radii.
            //
            // So the fallback is not a symbol here, it is *the entire existing
            // control*: no art, and every skin renders exactly what it rendered
            // in 0.8.1, down to the sketch stroke and the shadow. That keeps
            // "the conversion can be partial without any control being blank",
            // which is `DexChromeGlyph`'s rule and the only defence against
            // `PixelArtLoader` returning nil in silence.
            if let drawnCap {
                Image(uiImage: drawnCap)
                    // **Smooth, since 0.8.5 (E2)** — the same exception, for the
                    // same reason, that `DexChromeGlyph.smoothing` carved out
                    // for the marquee glyphs one release ago. The house rule is
                    // `.interpolation(.none)` because these are pixel art whose
                    // grid the illustrator drew; these four are not on a grid.
                    // They are a rendered circle at ~250px shown at 60pt, a 0.72
                    // downscale, and nearest-neighbour at 0.72 drops one row and
                    // column in four — which on a hard-edged disc with a dark
                    // cel outline running round it is precisely the stair-
                    // stepped fringe E2 reports. `ChassisCapLoader` feathers the
                    // silhouette so there is now something for the filter to
                    // resample.
                    .interpolation(.high)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    // No `.shadow`, for a different reason since 0.8.3 (B1).
                    // It used to be "the sprite casts its own, and the pair
                    // read as two light sources". B1 removes the sprite's, and
                    // it was removed *in the art* — the shadow was painted into
                    // the source as the magenta key at half value, so no
                    // SwiftUI change could have touched it. See
                    // `import-footer-art.py`'s `strip_key_shadow`. Adding a
                    // drawn shadow back here would be re-answering the item.
            } else {
                moldedCap
            }
        }
        // **The chassis press, not the screen press (0.8.3, B2).** These four
        // are moulded parts of the shell and now depress like the orb they sit
        // under — see `ChassisPress`, which holds the numbers both read.
        .buttonStyle(ChassisPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(accessibilityLabel)
    }

    /// The rendered control, and the fallback for every cap with no art.
    private var moldedCap: some View {
        Group {
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
        // "User", not "Saved entries", since 0.8.5 (A1): the page this opens is
        // titled USER now and holds three shelves, of which SAVED is one.
        // VoiceOver naming a control after one of the three things behind it was
        // the same mismatch the title had.
        case .bookmarks: "User"
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
            DexChromeGlyph(
                "backarrow", symbol: "chevron.left",
                size: size * 0.47, weight: .heavy, tint: cap.glyph
            )
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
                    DexChromeGlyph(
                        "home", symbol: "house.fill",
                        size: size * 0.41, weight: .bold, tint: homeAccent.ink
                    )
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
            .animation(DexMotion.press, value: configuration.isPressed)
    }
}

/// What a moulded part of the shell does under a finger (0.8.3, B2).
///
/// **The orb's numbers, named once.** The orb has depressed since it grew its
/// hold-to-flip gesture — `orbHeld` drives a scale and a brightness drop on
/// `onPressingChanged` — and B2 asks the four footer caps to do the same thing.
/// They sit on the same chassis, so the alternative to sharing the numbers is
/// two press feels a few hundredths apart on parts a thumb's width from each
/// other, which is the state a second hand-tuned constant always arrives at.
/// The orb reads them from here too.
///
/// **Distinct from `DexPressStyle`, which is the app's *screen* press.** That
/// one is the web app's `active:scale` on LCD controls — tiles, chips, rows —
/// and it is deliberately lighter (0.96, no brightness) because a flat surface
/// on a screen does not have a travel. A moulded cap does: it goes down into
/// the shell and the light falling on it drops, which is what the brightness is
/// for and why a scale alone reads as the button shrinking rather than sinking.
public enum ChassisPress {
    /// 0.88 — a visible travel, on a part large enough to show one.
    public static let scale: CGFloat = 0.88
    /// The face loses light as it goes into the shell.
    public static let brightness: Double = -0.18
    /// Fast, and eased out: a key bottoms out, it does not settle.
    public static let motion: Animation = .easeOut(duration: 0.12)
}

/// `ChassisPress` as a `ButtonStyle`, for the parts that are buttons (0.8.3, B2).
///
/// The orb is driven by `onPressingChanged` because its gesture is a *hold* and
/// it needs the pressing state for its own reasons; the caps are ordinary
/// buttons, so `configuration.isPressed` is the same signal already being
/// delivered and a second gesture recogniser on top of a `Button` would be one
/// more thing to keep out of the way of the tap.
public struct ChassisPressStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? ChassisPress.scale : 1)
            .brightness(configuration.isPressed ? ChassisPress.brightness : 0)
            .animation(ChassisPress.motion, value: configuration.isPressed)
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

/// The panel refresh when the screen changes (0.7.5, A3).
///
/// **Monochrome modes only, and the gate is derived rather than listed.** A
/// single-phosphor panel is the only display this belongs on: VINTAGE, AMBER,
/// TERMINAL and GRÜNERBOY are a reflective LCD and three phosphor tubes, all of
/// which visibly *redraw* when their contents change, and none of which can
/// show a hue. The colour modes are meant to read as a modern screen and get
/// nothing. The test is `lcd.monochromeTint != nil` — the same predicate
/// `honorsFontInk` uses — so a fifth single-phosphor mode is covered the day it
/// is added, and a colour mode can never accidentally opt in.
///
/// **It draws in white, not in the tint.** This view is mounted inside
/// `innerBezel`'s `grayscale`/`colorMultiply` pass, so white comes out as
/// whatever phosphor the mode is running. Painting the tint here would send it
/// through `grayscale(1)` first and land on a muddier version of the same
/// colour. The tint is passed in only as the gate.
///
/// **Subtle by construction.** Two things happen and both are brief: the panel
/// lifts to a quarter-strength wash and falls away over `Self.duration`, and a
/// soft band crosses it once in the same window — the sweep a dot-matrix LCD
/// makes when every row is rewritten. Nothing blanks: at no point is the screen
/// unreadable, because this fires on *arriving* somewhere and the first thing a
/// user does is read.
///
/// **Reduce Motion removes it entirely**, which is the same reading the
/// screensaver gets one stack slot up rather than the boot POST's. The POST
/// keeps its content because the content is information; this has no content —
/// it is an unprompted movement over a screen the user just asked for, and its
/// settled state is nothing at all. Skipping the animation and showing the end
/// state *is* showing nothing.
private struct LcdRefreshFlash: View {
    /// The screen's identity. The chassis's marquee `title`, which is
    /// `DexRoute.title` — one string that changes on every navigation, already
    /// threaded to this view, and already the thing the device itself claims is
    /// on screen. Keying off the route stack instead would mean routing the
    /// stack down here to learn something the title already says.
    let screen: String
    /// The mode's phosphor, or nil on a colour display. Gate only — see above.
    let tint: Color?
    let reduceMotion: Bool

    /// How long the whole refresh takes. Short enough that it reads as the
    /// panel settling rather than as a transition being played at you; long
    /// enough at 60Hz to be a movement rather than a dropped frame.
    private static let duration: Double = 0.22

    /// Peak opacity of the full-panel wash.
    private static let wash: Double = 0.26

    /// 1 at the instant the screen changes, falling to 0 as the panel settles.
    @State private var charge: Double = 0

    private var active: Bool { tint != nil && !reduceMotion }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.opacity(charge * Self.wash)

                // The rewrite sweep. Travels the panel's height once, its own
                // length either side of the bounds so it enters and leaves
                // rather than appearing and vanishing mid-screen.
                let band = geo.size.height * 0.34
                LinearGradient(
                    colors: [.clear, .white.opacity(0.5), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: band)
                .opacity(charge)
                .offset(y: -geo.size.height / 2 - band + (1 - charge) * (geo.size.height + band * 2))
            }
        }
        .blendMode(.plusLighter)
        .opacity(active ? 1 : 0)
        // `screen`, not `tint`: switching *into* a monochrome mode must not
        // fire a refresh, or the screen-mode picker flashes under the thumb
        // every time a card is tapped.
        .onChange(of: screen) { _, _ in
            guard active else { return }
            charge = 1
            withAnimation(.easeOut(duration: Self.duration)) { charge = 0 }
        }
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
///
/// **What it says is scripted now (0.7.1, B1-B3).** 0.6.9's D3 gave the main
/// screen five toasts on an endless 2.6-second cycle. B1-B3 replace the loop
/// with three states and an end — WELCOME! on launch, MENU while you are using
/// it, CHEERS! after ten seconds of not — and the state machine that decides
/// between them is `MarqueeScript` in Core, where a Linux gate can see it. The
/// banner keeps the clock and the pixels; it does not keep the rules.
public struct MarqueeBanner: View {
    /// The words on the panel. One string since 0.7.1 (B1): the five-toast
    /// list and the `index` that walked it are gone with the cycle, and the
    /// main screen now passes whichever of `MarqueeScript`'s three stages is
    /// current, exactly as every other screen passes its title.
    let text: String
    /// SF Symbol for the page, drawn **above** the title since 0.6.9 (D2) at
    /// `DexMetrics.marqueeGlyph` — or beside it, where `glyphBeside` says so
    /// (0.7.2, A3). It used to be stamped inline after the words (v0.5.7, E2),
    /// which was the only place a scrolling single line had for it. Nil runs
    /// text-only and the label takes the whole panel.
    let symbol: String?
    /// The drawn button face for `symbol`, or nil where the route has none
    /// (0.8.3, A). See `DexRoute.marqueeArt`.
    var art: String?
    let fontSize: CGFloat
    /// Freezes the transition (AUDIT M8, through D3, still true). The panel is
    /// inside the front face, which the flip merely hides at `opacity 0` — a
    /// dissolve left running behind an opaque metal back plate is a clock
    /// nobody can see, and it would be halfway through when the device came
    /// back over.
    var paused: Bool = false

    /// Whether this change gets the *long* dissolve (0.7.1 B2; renamed and
    /// narrowed 0.8.5, A3).
    ///
    /// **Every change dissolves now. This only chooses how long it takes.**
    /// Through 0.8.4 the flag decided *whether* to pixelate at all, and only the
    /// main screen passed true. The argument was: B2 asks for the slow pixelated
    /// fade between the scripted stages, and running it on every route title too
    /// would put a 1.4-second dissolve in front of every navigation in the app,
    /// which is not a transition, it is a wait.
    ///
    /// A3 asks for the dissolve on every change of the panel, and that argument
    /// does not survive it — but it was never an argument about the *effect*, it
    /// was an argument about the *duration*, and it had been settled by
    /// conflating the two. So the two come apart: the banner always dissolves,
    /// and `DexMetrics.marqueeRoutePixelFade` is what a page title costs.
    ///
    /// That is also the honest reading of what the panel is. It is a dot-matrix
    /// display; a dot-matrix display repaints by cell whatever it is repainting
    /// to, and a cross-fade was the one thing on this chassis that behaved like
    /// software. Both timings live in `DexMetrics` rather than here, per F3.
    var slowFade: Bool = false

    /// Draw the glyph beside the word rather than above it (0.7.2, A3).
    ///
    /// Extra horizontal room the label must leave at each end (0.7.2, A7).
    ///
    /// The pinned-app buttons sit in the panel's two top corners, and they are
    /// drawn by the chassis as siblings *over* this view rather than inside it —
    /// a button nested in another button's label is not a control, it is a
    /// picture. So the banner cannot see them, and without being told it would
    /// happily set CONTINENTS the full width of the panel and straight under
    /// them. This is that telling: the chassis passes the width it is about to
    /// cover, and the label treats it as unusable.
    ///
    /// Zero when nothing is pinned, so a device with no pins loses no width at
    /// all — the reserve exists only when there is something to reserve for.
    var edgeReserve: CGFloat = 0

    /// The string currently drawn. Distinct from `text` for exactly the length
    /// of a dissolve, during which both are on the panel at once.
    @State private var shown = ""
    /// The string being dissolved *out*, or nil when the panel is at rest.
    @State private var outgoing: String?
    /// The glyph's half of the same pair (0.8.1, H2). The symbol changes in the
    /// same update as the text — both derive from the route — so it is carried
    /// through `change(to:)` rather than watched separately, and the two halves
    /// of the panel cannot start their dissolves a frame apart.
    @State private var shownSymbol: String?
    @State private var outgoingSymbol: String?
    /// The drawn face's stem, carried alongside the symbol (0.8.3, A) for the
    /// reason the symbol is carried alongside the text: all three derive from
    /// the route and change in one update, so a stem watched separately could
    /// start its dissolve a frame out of step with the glyph it belongs to.
    @State private var shownArt: String?
    @State private var outgoingArt: String?
    /// When the running dissolve began; nil at rest, which is also the
    /// `TimelineView`'s pause condition.
    @State private var fadeStart: Date?

    /// Resolved in `init`, not per access (AUDIT M8): `DexFont.retro` reads
    /// `TextScale.current`, which is a `UserDefaults` lookup, and `body` is
    /// rebuilt on every skin or cycle change. `DeviceChassis` is `.id`-keyed on
    /// the text scale, so a change rebuilds this view rather than needing it
    /// re-read.
    private let segmentFont: Font

    /// The strip's phosphor follows the shell — see `ChassisSkin.marqueeText` —
    /// unless the workshop has fitted a different one (0.7.3, B1).
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    @AppStorage(DeviceAxis.marquee.storageKey) private var partMarquee = ""
    /// Read here rather than passed in by `DeviceChassis` so the banner keeps
    /// working wherever else it is mounted. (AUDIT M18)
    ///
    /// Its job changed in 0.6.9. It used to choose between the scrolling and
    /// still forms; the still form is now the only one, so what is left for it
    /// to gate is the greeting cycle — see `cycle()`.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var skin: ChassisLook {
        ChassisLook(skinRaw: skinRaw, marquee: partMarquee)
    }

    /// The lit ground: the skin's phosphor, filling the panel rather than the
    /// letters (0.6.5, B1).
    private var ground: Color { skin.marqueeText }

    /// The letters and the panel's rim — the very dark form of the phosphor,
    /// which is what a segment LCD's glyphs actually look like.
    private var ink: Color { skin.marqueeShadow }

    public init(
        text: String,
        symbol: String? = nil,
        art: String? = nil,
        fontSize: CGFloat,
        paused: Bool = false,
        slowFade: Bool = false,
        edgeReserve: CGFloat = 0
    ) {
        self.text = text
        self.symbol = symbol
        self.art = art
        self.fontSize = fontSize
        self.paused = paused
        self.slowFade = slowFade
        self.edgeReserve = edgeReserve
        self.segmentFont = DexFont.retro(fontSize)
    }

    public var body: some View {
        ZStack {
            panel
            content
        }
        .frame(height: DexMetrics.marqueeHeight)
        .onAppear {
            if shown.isEmpty { shown = text }
            shownSymbol = symbol
            shownArt = art
        }
        .onChange(of: text) { _, next in change(to: next) }
        // A symbol that moves without the text does not dissolve — there is no
        // pair to cross — but it must still not strand `shownSymbol` on the
        // previous route's glyph. Nothing in the app does this today; it costs
        // two lines to make sure nothing quietly starts.
        .onChange(of: symbol) { _, next in
            if fadeStart == nil {
                shownSymbol = next
                shownArt = art
            }
        }
        // Ends the dissolve. Keyed on the start instant, so a second change
        // arriving mid-dissolve cancels the pending teardown rather than
        // letting it fire late and clear the new one.
        .task(id: fadeStart) { await endFade() }
    }

    /// The panel's text changed under us.
    ///
    /// **Reduce Motion takes the dissolve, not the change.** A pixel dissolve
    /// is a large unprompted movement and is exactly what the setting asks to
    /// be spared; the cross-fade is the substitute Apple's own guidance offers
    /// for one, and it is what a title change has used here since D3.
    /// `PulseGlow` in this file makes the same distinction — the reduced branch
    /// settles on the most informative still state rather than simply refusing
    /// to update.
    private func change(to next: String) {
        guard shown != next else { return }
        // `paused` still refuses outright: the panel is behind an opaque back
        // plate and a dissolve nobody can see would be halfway through when the
        // device came back over. Reduce Motion still takes the cross-fade. A3
        // removes only the third condition, which was the panel's own opinion
        // about which of its changes were worth animating.
        guard !reduceMotion, !paused else {
            outgoing = nil
            outgoingSymbol = nil
            outgoingArt = nil
            fadeStart = nil
            withAnimation(.easeInOut(duration: DexMetrics.marqueeGreetingFade)) {
                shown = next
                shownSymbol = symbol
                shownArt = art
            }
            return
        }
        outgoing = shown
        shown = next
        outgoingSymbol = shownSymbol
        shownSymbol = symbol
        outgoingArt = shownArt
        shownArt = art
        fadeStart = .now
    }

    /// How long this dissolve runs (0.8.5, A3). See `slowFade`.
    private var fadeDuration: Double {
        slowFade ? DexMetrics.marqueePixelFade : DexMetrics.marqueeRoutePixelFade
    }

    private func endFade() async {
        guard fadeStart != nil else { return }
        try? await Task.sleep(for: .seconds(fadeDuration))
        guard !Task.isCancelled else { return }
        outgoing = nil
        outgoingSymbol = nil
        outgoingArt = nil
        fadeStart = nil
    }

    /// How far through the dissolve, smoothstepped.
    ///
    /// Eased rather than linear, and eased at both ends: a linear dissolve
    /// spends its whole duration flipping cells at a constant rate, which reads
    /// as noise turning on and then off. Easing gives it the two things that
    /// make it one deliberate event instead — a moment where the old word is
    /// still legible while the first cells go, and a moment where the new one
    /// is nearly whole while the last ones arrive. The same
    /// `p * p * (3 - 2p)` `DataWave` uses, for the same reason.
    private func fadeProgress(at date: Date) -> Double {
        guard let fadeStart else { return 1 }
        let linear = min(max(date.timeIntervalSince(fadeStart) / fadeDuration, 0), 1)
        return linear * linear * (3 - 2 * linear)
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
    ///
    /// **One arrangement again (0.8.1, H1).** 0.7.2's A3 added a `glyphBeside`
    /// flag and set it on the main screen, arguing that MENU is four characters
    /// on a 225pt panel and stacking a glyph over them leaves a short word
    /// marooned under a big symbol with air either side. That observation was
    /// true and is now outweighed: the panel is the one part of the chassis
    /// whose layout the user sees change as they navigate, and it was changing
    /// *shape* — glyph beside on the menu, glyph above on every page — so the
    /// return home read as the panel rearranging itself rather than as its
    /// contents changing. H2 puts the glyph through the dissolve for the same
    /// reason: one transition, not a transition plus a reflow. The flag and its
    /// branch are gone rather than left passing `false`, because a layout switch
    /// nothing selects is a switch that will be re-selected by accident.
    private var content: some View {
        VStack(spacing: DexMetrics.marqueeGlyphGap) {
            glyph
            title
        }
        .padding(.horizontal, DexMetrics.marqueeTextInset + edgeReserve)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A guard rather than a mechanism: the label is fitted, so nothing
        // should reach this. If a future title does, it is cut at the panel's
        // rim like a display clipping an oversized image, not spilled onto the
        // moulding.
        .clipShape(RoundedRectangle(cornerRadius: DexMetrics.marqueeInnerCorner))
    }

    /// The page glyph, or nothing (0.6.9, D2; extracted 0.7.2, A3).
    ///
    /// **Dissolves with the title since 0.8.1 (H2).** The title had the pixel
    /// transition and the glyph above it cut instantly, so returning home was
    /// one part of the panel dissolving while the other part next to it
    /// snapped — which reads as the dissolve failing rather than as two
    /// different treatments. Same clock, same `fadeStart`, so the two
    /// `TimelineView`s cannot drift; the cell size differs because the cell is
    /// a fraction of what it is dissolving, and the glyph is not the type.
    @ViewBuilder
    private var glyph: some View {
        if fadeStart == nil {
            glyphImage(shownSymbol, art: shownArt)
        } else {
            TimelineView(.animation) { context in
                let p = fadeProgress(at: context.date)
                ZStack {
                    glyphImage(outgoingSymbol, art: outgoingArt)
                        .mask(PixelDissolve(progress: p, cell: glyphFadeCell, incoming: false))
                    glyphImage(shownSymbol, art: shownArt)
                        .mask(PixelDissolve(progress: p, cell: glyphFadeCell, incoming: true))
                }
            }
        }
    }

    /// One glyph, or nothing at all — the toasts carry no symbol, so a nil here
    /// is a normal state of the panel rather than a missing asset.
    ///
    /// **The dot-matrix marquee glyph, in the panel's own ink (0.8.4, A).** The
    /// stem travels beside the symbol — see `DexRoute.marqueeArt` — and
    /// `DexChromeGlyph` resolves the pair the way every other converted control
    /// does: the drawing where there is one, the SF Symbol where there is not.
    ///
    /// **`ink`, not black, and this is A2 reversing 0.8.3's A.** That item
    /// argued the glyph must be black because a segment LCD's ink is what blocks
    /// light, and it was right about the *material* and wrong about the colour:
    /// what blocks light on this panel is not black, it is `skin.marqueeShadow`
    /// — a very dark register of each skin's own phosphor, which is exactly what
    /// the letters beside the glyph are drawn in. So the old rule produced a
    /// glyph that was nearly the text colour on twenty-one skins and never quite
    /// it, which is the worst of both: too close to read as a deliberate
    /// contrast, far enough to read as a different material sitting on the same
    /// panel.
    ///
    /// A2 asks for the two to recolour together, and `ink` is that in the
    /// strongest available form — not a matching value, the same expression the
    /// label reads. A skin that changes its marquee phosphor moves both in one
    /// edit, and the SF Symbol fallback below has always taken `ink` too, so a
    /// route with a face and a route without now agree for the first time.
    ///
    /// `flatten:` rather than a loader is unchanged and still right: these are
    /// silhouettes by construction (`import-marquee-art.py` throws the colour
    /// away and keeps the alpha), and `ChassisCapLoader`'s value-preserving
    /// re-ink has nothing to preserve here.
    ///
    /// **`smoothing:` is the one thing the new drop needs that the old did not**
    /// — see `DexChromeGlyph.smoothing`. These are drawn circles, and
    /// nearest-neighbour at the fitted scale turns an even grid into an uneven
    /// one.
    @ViewBuilder
    private func glyphImage(_ name: String?, art: String?) -> some View {
        if let name {
            DexChromeGlyph(
                art ?? name,
                symbol: name,
                size: DexMetrics.marqueeGlyph,
                weight: .bold,
                tint: ink,
                flatten: ink,
                smoothing: true
            )
            .shadow(color: ground.opacity(0.7), radius: 0, x: 1, y: 1)
        }
    }

    /// Coarser than the title's, for the same reason `fadeCell` is coarser than
    /// the font's own grid: a symbol is one large shape, and cells fine enough
    /// to suit 28pt letterforms read as the glyph eroding rather than
    /// dissolving.
    private var glyphFadeCell: CGFloat { max(DexMetrics.marqueeGlyph * 0.22, 3) }

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
    /// `.id(shown)` is what makes the cross-fade actually fade: SwiftUI does
    /// not animate a `Text`'s *contents* changing, so the identity has to
    /// change for the transition to have an insertion and a removal to run.
    /// That trick is only good for an alpha ramp, which is why B2's dissolve
    /// takes the other branch below and masks two live labels instead.
    @ViewBuilder
    private var title: some View {
        if fadeStart == nil {
            label(shown)
                .id(shown)
                .transition(.opacity)
        } else {
            // The clock. `TimelineView` rather than an animatable value for the
            // reason `DataWave` sets out in `SettingsPanel`: `Canvas` has no
            // animatable content, and `Animatable` on the wrapper is not usable
            // here under Swift 6.
            TimelineView(.animation) { context in
                let p = fadeProgress(at: context.date)
                ZStack {
                    if let outgoing {
                        label(outgoing)
                            .mask(PixelDissolve(progress: p, cell: fadeCell, incoming: false))
                    }
                    label(shown)
                        .mask(PixelDissolve(progress: p, cell: fadeCell, incoming: true))
                }
            }
        }
    }

    /// The dissolve's cell edge, in points.
    ///
    /// Tied to the type size rather than fixed, so it survives SETTINGS > TEXT
    /// SIZE: the letters in this face are drawn on a notional grid of about
    /// eight cells to the cap height, and a dissolve cell around a sixth of the
    /// point size lands a little coarser than the glyph's own pixels. Coarser
    /// on purpose — matching the font's grid exactly makes the letters look
    /// like they are losing strokes rather than dissolving. Floored at 3pt,
    /// below which the effect is indistinguishable from a plain alpha fade at
    /// arm's length and costs several hundred more cells to draw.
    private var fadeCell: CGFloat { max(fontSize * 0.16, 3) }

    /// One string on the panel, with the three fallbacks above applied.
    private func label(_ string: String) -> some View {
        Text(EntryDisplay.hyphenated(string))
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
    }
}

/// The pixel-V wordmark, bundled from the web app's logo.
public struct LogoMark: View {
    public init() {}

    public var body: some View {
        if let url = DexResources.url(named: "vinodex-logo", ext: "png", subdirectory: "Logo"),
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
