#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The premium device builder (0.7.3, B1/B2).
///
/// **The live preview is the device you are holding.** B1 asks the workshop to
/// "live-preview the device as parts change", and the obvious build of that — a
/// thumbnail that updates — would have been the second-best answer available:
/// this screen runs *inside* the LCD of the thing being customised, with the orb
/// eight points above it and the grille, marquee and face buttons below. So the
/// rows here write the same `UserDefaults` keys the chassis has always read, the
/// chassis's `@AppStorage` is KVO-backed, and fitting a violet orb turns the real
/// orb violet while your thumb is still on the chip. Nothing is threaded between
/// the two surfaces, because there is nothing to thread: there is one device and
/// this screen is inside it.
///
/// The panel at the top is a *schematic*, not a preview — a labelled diagram
/// showing all eight parts at once, including the two (the screen ground and the
/// font ink) you cannot see while you are looking at them. It is drawn from the
/// same values.
///
/// **Editing live means editing the live thing**, which needs an undo: REVERT
/// restores the build as it was when the screen opened. That is the whole cost of
/// the decision, and it is cheaper than a draft — a draft would have been a
/// second answer to "what does the device look like right now", which is the
/// exact fork `CustomDevice`'s note refuses.
///
/// **Nothing here needs a global invalidation.** The font axis is the one part
/// read through a plain `UserDefaults` lookup rather than an `@AppStorage`
/// (`LcdMode.fontInk` — an enum's computed property has nowhere to put a property
/// wrapper), so it does not invalidate SwiftUI on its own. It does not have to:
/// this screen holds `@AppStorage` for it, so setting it re-runs *this* body and
/// every `lcd.text` in it re-reads; and every other screen in the app is built
/// fresh on the next navigation, because the LCD swaps its whole content when
/// the route changes. Keying the chassis on it, the way `RootView` keys on the
/// text scale, would have thrown away this screen's `@State` — including the
/// REVERT snapshot — every time somebody tried a font colour.
public struct DeviceWorkshopScreen: View {
    // The ten axes, live. Declared in `DeviceAxis` order so this block reads
    // as the device's parts list.
    @AppStorage(DeviceAxis.shell.storageKey) private var shell = ""
    @AppStorage(DeviceAxis.buttons.storageKey) private var buttons = ""
    @AppStorage(DeviceAxis.orb.storageKey) private var orb = ""
    @AppStorage(DeviceAxis.headerLamps.storageKey) private var headerLamps = ""
    @AppStorage(DeviceAxis.marquee.storageKey) private var marquee = ""
    @AppStorage(DeviceAxis.marqueeLamps.storageKey) private var marqueeLamps = ""
    @AppStorage(DeviceAxis.grilleColor.storageKey) private var grilleColor = ""
    @AppStorage(DeviceAxis.grilleShape.storageKey) private var grilleShape = ""
    @AppStorage(DeviceAxis.screen.storageKey) private var screen = ""
    @AppStorage(DeviceAxis.font.storageKey) private var font = ""

    @State private var access = AccessStore.shared
    @State private var store = CustomDeviceStore.shared
    /// What the device looked like when this screen opened — REVERT's target.
    @State private var openedWith: DeviceBuild?
    @State private var typedName = ""
    @State private var notice: Notice?
    @State private var confirmingDelete: CustomDevice?
    /// Raised when a *shell* or *screen mode* the player does not own is tapped.
    /// The six new axes ride `.workshop`, which they must already hold to be
    /// here; the two old axes keep the two old bundles — see `chooseSkin`.
    @State private var lockedBundle: Entitlement?
    @State private var screens = ScreenStateStore.shared

    /// One line of feedback under the name field. An enum rather than a string so
    /// the failures cannot be spelled two ways.
    private enum Notice: Equatable {
        case saved(String)
        case replaced(String)
        case needsName
        case full
        case nameTaken
        case applied(String)
        case reverted

        var isBad: Bool {
            switch self {
            case .needsName, .full, .nameTaken: true
            default: false
            }
        }

        var text: String {
            switch self {
            case .saved(let name): "SAVED AS \(name)."
            case .replaced(let name): "\(name) UPDATED."
            case .needsName: "GIVE THE BUILD A NAME FIRST."
            case .full: "\(CustomDeviceStore.capacity) BUILDS ALREADY SAVED. DELETE ONE."
            case .nameTaken: "ANOTHER BUILD ALREADY HAS THAT NAME."
            case .applied(let name): "\(name) FITTED."
            case .reverted: "PARTS BACK AS YOU FOUND THEM."
            }
        }
    }

    public init() {}

    private var lcd: LcdMode { LcdMode(rawValue: screen) ?? .dark }
    private var look: ChassisLook { ChassisLook(build: build) }

    /// The live build, assembled from the eight stored axes.
    ///
    /// Deliberately not `DeviceBuild.active()`: that reads `UserDefaults`
    /// directly and SwiftUI would not know when to re-run this body. These are
    /// the same eight values through the wrappers that do.
    private var build: DeviceBuild {
        DeviceBuild(
            shell: shell,
            buttons: buttons,
            orb: orb,
            headerLamps: headerLamps,
            marquee: marquee,
            marqueeLamps: marqueeLamps,
            grilleColor: grilleColor,
            grilleShape: grilleShape,
            screen: screen,
            font: font
        )
    }

    /// Write one axis.
    ///
    /// A switch rather than ten closures at the call sites: the rows are built
    /// by `ForEach(DeviceAxis.allCases)` and each needs a way to set *its* axis,
    /// and a row wired to the wrong property is a bug no Linux test could see.
    private func set(_ axis: DeviceAxis, _ value: String) {
        switch axis {
        case .shell: shell = value
        case .buttons: buttons = value
        case .orb: orb = value
        case .headerLamps: headerLamps = value
        case .marquee: marquee = value
        case .marqueeLamps: marqueeLamps = value
        case .grilleColor: grilleColor = value
        case .grilleShape: grilleShape = value
        case .screen: screen = value
        case .font: font = value
        }
    }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            ScrollView {
                // **SAVE THIS BUILD and SAVED BUILDS ride above SHELL (0.8.8,
                // H1).** They sat last because they were written last, and the
                // shape of the page argues against it: the ten axis sections
                // below are one long editing pass, so the two controls that act
                // on the *result* of that pass were ten scroll-lengths from the
                // schematic showing what you had made. Directly under the
                // schematic they are next to the thing they save, and FIT on a
                // stored build is now the first control on the page rather than
                // the last — which is the right order for the commoner visit,
                // since choosing a build you already made is one tap and making
                // a new one is ten sections.
                //
                // Order within the pair is unchanged and deliberate: you save
                // what is fitted, then you see what you have.
                //
                // `section(_:)` sets `.id(title)`, and those ids are the scroll
                // anchors `ScreenStateStore.deviceWorkshop` persists. Moving a
                // section does not change its id, so a restored anchor still
                // finds its section — it simply lands at a different offset,
                // which is what moving it means.
                VStack(alignment: .leading, spacing: 18) {
                    schematic
                    savedBuilds
                    ForEach(DeviceAxis.allCases) { axis in
                        section(axis.title) { chooser(for: axis) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .scrollTargetLayout()
            }
            .contentMargins(14, for: .scrollContent)
            .scrollPosition(id: anchorBinding)
            .scrollDismissesKeyboard(.interactively)
        }
        .overlay {
            if let lockedBundle {
                UpgradePrompt(
                    entitlement: lockedBundle,
                    onUnlock: {
                        // Through the purchase provider since 0.7.5 (B2) — the
                        // same grant, reached through the seam a payment step
                        // would live in. See `PurchaseProviding`.
                        let bundle = lockedBundle
                        self.lockedBundle = nil
                        Task { await access.purchase(bundle) }
                    },
                    onCancel: { self.lockedBundle = nil }
                )
            } else if let doomed = confirmingDelete {
                DexAlert(
                    title: "DELETE \(doomed.name)?",
                    message: "The saved build goes. The device keeps whatever parts are fitted right now.",
                    confirmLabel: "DELETE",
                    onConfirm: {
                        store.delete(id: doomed.id)
                        confirmingDelete = nil
                    },
                    onCancel: { confirmingDelete = nil }
                )
            }
        }
        .animation(DexMotion.overlay, value: lockedBundle)
        .animation(DexMotion.overlay, value: confirmingDelete)
        .onAppear {
            // Once per visit. `??=` in spirit: reopening after an overlay must
            // not re-snapshot, or REVERT would undo nothing.
            if openedWith == nil { openedWith = build }
        }
    }

    private var anchorBinding: Binding<String?> {
        Binding(
            get: { screens.anchor(for: ScreenStateStore.deviceWorkshop) },
            set: { screens.setAnchor($0, for: ScreenStateStore.deviceWorkshop) }
        )
    }

    // MARK: The schematic

    /// Every part at once, at a third the size.
    ///
    /// Two things here are not visible on the real device while you are using it
    /// — the screen ground and the font ink, because you are looking through
    /// them — and one is hard to judge at 2pt (the grille pattern). Those three
    /// are the schematic's whole justification; everything else on it is a
    /// courtesy so the picture is a device rather than a swatch book.
    private var schematic: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                miniDevice
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(build.chosenCount) OF \(DeviceAxis.allCases.count) PARTS FITTED")
                        .font(DexFont.retro(10))
                        .tracking(1)
                        .foregroundStyle(lcd.subtext)
                    if let fitted = store.matching(build) {
                        badge(fitted.name, symbol: "checkmark.seal.fill", tint: lcd.accent)
                    } else if build.isStock {
                        badge("FACTORY STOCK", symbol: "shippingbox.fill", tint: lcd.subtext)
                    } else {
                        badge("UNSAVED", symbol: "hammer.fill", tint: lcd.subtext)
                    }
                    Spacer(minLength: 0)
                    // Drawn in `Dex.red500`, a fixed colour rather than an LCD
                    // token, on purpose: this is the way out of a font colour
                    // that turned out to be unreadable on the chosen screen, and
                    // a way out drawn in the ink you just broke is no way out.
                    Button {
                        Haptics.select()
                        (openedWith ?? .stock).apply()
                        notice = .reverted
                    } label: {
                        Text("REVERT")
                            .font(DexFont.retro(10))
                            .tracking(1)
                            .foregroundStyle(Dex.red500)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Dex.red500.opacity(0.6), lineWidth: 2)
                            )
                    }
                    .buttonStyle(DexPressStyle(scale: 0.97))
                    .disabled(openedWith.map { $0 == build } ?? true)
                    .opacity((openedWith.map { $0 == build } ?? true) ? 0.4 : 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(lcd.accent.opacity(0.5), lineWidth: 2)
        )
        .id("SCHEMATIC")
    }

    private func badge(_ text: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(DexFont.retro(10))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(tint)
    }

    /// The device, small. Proportions follow the real chassis loosely rather
    /// than exactly — it is a diagram, and a faithful 1:3 chassis would be
    /// unreadable at this size.
    private var miniDevice: some View {
        // The island row's own geometry, named rather than repeated, because
        // 0.7.9's A1 makes the orb a *function* of these two numbers.
        let lamp: CGFloat = 4
        let gap: CGFloat = 4
        let orbWidth = DexMetrics.islandOrbWidth(lamp: lamp, spacing: gap)
        // **Height from the lamp, not from the aspect (0.8.0, C1).** It was
        // `orbWidth / islandOrbAspect` — the chassis's aspect over this diagram's
        // width — which the aspect becoming a derived quotient of two chassis
        // metrics turns into a number about nothing. `islandOrbHeight(lamp:)` is
        // the same rule the real strip now follows: one lamp tall.
        let orbHeight = DexMetrics.islandOrbHeight(lamp: lamp)

        return VStack(spacing: 5) {
            // Island: the orb, then the lamp trio.
            HStack(spacing: gap) {
                // A stadium, with the real orb (0.7.5 A2, 0.7.6 E1) — this is
                // the live preview of the device being built, so its parts
                // follow the device's shapes as well as its colours.
                //
                // **Width derived from this diagram's own trio (0.7.9, A1).**
                // It was a hand-set 11pt with the height divided out of the
                // aspect, which was fine at 2.35 and would be a 2pt hairline at
                // 5.3. The chassis rule is "the orb is as long as the lamp
                // cluster", and a preview that does not obey it is previewing a
                // different device — so it obeys it, on its own 4pt lamps.
                // The rim is proportional for the same reason: a flat 1pt on a
                // 3.8pt bead leaves a core the wrong fraction of the whole.
                Capsule(style: .continuous)
                    .fill(look.orb)
                    .frame(width: orbWidth, height: orbHeight)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(.white, lineWidth: max(orbHeight * 0.11, 0.5))
                    )
                    .shadow(color: look.orbGlow, radius: 3)
                Spacer(minLength: 0)
                // `headerLights`, not `statusLights` (0.7.6, B1): the schematic
                // is the fitted device, so it has to show the axis rather than
                // the shell it falls back to.
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(look.headerLights[index].fill)
                        .frame(width: lamp, height: lamp)
                }
            }

            // The LCD, with two lines of ink on it. Runs the real
            // grayscale-and-tint pass so AMBER previews amber rather than the
            // green its raw tokens hold — the same treatment the screen-mode
            // picker's cards get, and the only way the FONT row's "follows the
            // screen" note is visibly true.
            RoundedRectangle(cornerRadius: 3)
                .fill(lcd.screen)
                .frame(height: 46)
                .overlay {
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 1).fill(lcd.text).frame(width: 44, height: 4)
                        RoundedRectangle(cornerRadius: 1).fill(lcd.bodyText).frame(width: 56, height: 3)
                        RoundedRectangle(cornerRadius: 1).fill(lcd.subtext).frame(width: 34, height: 3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                }
                .grayscale(lcd.monochromeTint == nil ? 0 : 1)
                .colorMultiply(lcd.monochromeTint ?? .white)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // The bottom strip: lamp, wordmark, grille.
            HStack(spacing: 4) {
                Circle().fill(Dex.red500).frame(width: 3, height: 3)
                Spacer(minLength: 0)
                // 34 rather than the schematic's proportional share: at 26 the
                // DOTS pattern lands under a point across and every pattern
                // reads as a smudge, which defeats the one part this panel
                // exists to show. The real 64pt grille below the LCD is the
                // authority; this is a legible hint at it.
                ChassisGrille(shape: look.grilleShape, ink: look.grill, width: 34)
            }
            .frame(height: 10)

            // The footer: a cap, the marquee, a lit button.
            HStack(spacing: 5) {
                Circle()
                    .fill(LinearGradient(
                        colors: [look.control.top, look.control.bottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(look.control.edge, lineWidth: 1))
                // The marquee column: its two lamp buttons over the panel,
                // which is how the real footer is stacked. The lamps are on the
                // schematic since 0.7.6 (B1) because they are an axis now, and a
                // part you can choose that the diagram does not show is a row
                // with no preview.
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Capsule().fill(look.marqueeLights[0].fill).frame(height: 3)
                        Capsule().fill(look.marqueeLights[2].fill).frame(height: 3)
                    }
                    RoundedRectangle(cornerRadius: 2)
                        .fill(look.marqueeText)
                        .frame(height: 13)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(look.marqueeShadow, lineWidth: 1.5)
                        )
                }
                Circle()
                    .fill(LinearGradient(
                        colors: [look.accent.light, look.accent.mid],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(look.accent.edge, lineWidth: 1))
            }
        }
        .padding(7)
        .frame(width: 104)
        .background(
            RoundedRectangle(cornerRadius: 7).fill(look.underlay)
                .overlay(RoundedRectangle(cornerRadius: 7).fill(look.body))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7).strokeBorder(look.panelEdge, lineWidth: 1)
        )
    }

    // MARK: The eight rows

    @ViewBuilder
    private func chooser(for axis: DeviceAxis) -> some View {
        switch axis {
        case .shell: shellChooser
        case .screen: screenChooser
        case .grilleShape: grilleShapeChooser
        case .buttons, .orb, .headerLamps, .marquee, .marqueeLamps, .grilleColor, .font:
            colorChooser(axis)
        }
    }

    /// The seven colour axes, all through one grid.
    ///
    /// One row builder for seven axes rather than seven near-identical ones — the
    /// difference between them is which key it writes and which swatch the chip
    /// paints, and both come off `PartColor` and `DeviceAxis`. The FOLLOW chip is
    /// first because "leave this to the shell" is the state the device ships in
    /// and the one a player reaches for when a choice was a mistake.
    @ViewBuilder
    private func colorChooser(_ axis: DeviceAxis) -> some View {
        let chosen = build[axis]
        // FONT offers only the inks this screen will actually draw in — every
        // other axis offers the whole palette, because every other axis is
        // decoration and this one is what the screen says things with. See
        // `LcdMode.accepts(_:)`; the rule is enforced there rather than here, so
        // an ink chosen on a dark screen simply stops applying when the screen
        // turns pale instead of leaving an unreadable device behind.
        let options = axis == .font ? PartColor.allCases.filter { lcd.accepts($0) } : PartColor.allCases

        if axis == .font, let note = fontNote {
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Dex.yellow)
                Text(note)
                    .font(DexFont.mono(15))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        }

        LazyVGrid(columns: swatchColumns, spacing: 8) {
            partChip(
                label: "FOLLOW",
                isChosen: chosen.isEmpty,
                symbol: axis == .font ? "textformat" : "arrow.turn.down.right"
            ) {
                set(axis, "")
            } swatch: {
                // Whatever the part is when nothing overrides it — the honest
                // preview of "follow the shell", which is not a colour anybody
                // can name in advance.
                inheritedSwatch(axis)
            }

            ForEach(options) { option in
                partChip(
                    label: option.displayName,
                    isChosen: chosen == option.rawValue,
                    symbol: nil
                ) {
                    set(axis, option.rawValue)
                } swatch: {
                    Circle().fill(option.color)
                }
            }
        }
    }

    /// Why the FONT row looks the way it does, when it needs saying.
    ///
    /// Nil in the ordinary case. The two things worth explaining are both states
    /// the player can reach without doing anything wrong: choosing a
    /// single-phosphor screen, and keeping an ink that the screen they have since
    /// switched to cannot show.
    private var fontNote: String? {
        if !lcd.honorsFontInk {
            return "\(lcd.displayName) tints the whole display to one phosphor, so it sets the ink itself. Pick another screen to choose a font colour."
        }
        if let part = PartColor(rawValue: font), !lcd.accepts(part) {
            return "\(part.displayName) does not read on \(lcd.displayName) — the screen's own ink is in use. It comes back on a screen it suits."
        }
        return nil
    }

    /// What an unset axis actually paints, drawn as a swatch.
    @ViewBuilder
    private func inheritedSwatch(_ axis: DeviceAxis) -> some View {
        let stock = ChassisLook(skinRaw: shell)
        switch axis {
        case .buttons: Circle().fill(stock.accent.bright)
        case .orb: Circle().fill(stock.orbGlow)
        // The middle lamp of the shell's own trio, which is the one stop that
        // represents a three-lamp set in a single swatch — the outer two are
        // deliberately its extremes.
        case .headerLamps, .marqueeLamps: Circle().fill(stock.statusLights[1].fill)
        case .marquee: Circle().fill(stock.marqueeText)
        case .grilleColor: Circle().fill(stock.grill)
        // The screen mode's own ink, which is what an unset font follows —
        // `ownInk`, not `text`, or the chip that clears the axis would preview
        // whatever the axis is currently set to. See `LcdMode.ownInk`.
        case .font: Circle().fill(lcd.ownInk)
        // Not reachable — the three non-colour axes have their own choosers —
        // and exhaustive rather than `default:` so an eleventh axis has to answer
        // here instead of silently painting itself the shell's body colour.
        case .shell, .grilleShape, .screen: Circle().fill(stock.body)
        }
    }

    private var grilleShapeChooser: some View {
        LazyVGrid(columns: swatchColumns, spacing: 8) {
            ForEach(GrilleShape.allCases) { option in
                partChip(
                    label: option.displayName,
                    isChosen: (GrilleShape(rawValue: grilleShape) ?? .slats) == option,
                    symbol: option.symbol
                ) {
                    // SLATS is the default, so it is stored as *absence* — the
                    // invariant on `DeviceBuild`, and what keeps an untouched
                    // device's defaults clean.
                    set(.grilleShape, option == .slats ? "" : option.rawValue)
                } swatch: {
                    Circle().fill(look.grill.opacity(0.7))
                }
            }
        }
    }

    /// The shell, and the one place in this screen that is still a paywall.
    ///
    /// The six axes the workshop *adds* ride `Entitlement.workshop`, which the
    /// player must already hold to have got here. The two axes that predate it
    /// keep the two bundles they have always had — a workshop that quietly handed
    /// over all twenty-one chassis skins and all nine screen modes would be
    /// selling `.skins` and `.lightMode` for the price of `.workshop`. The gate
    /// is `access.isUnlocked(option)`, the same single predicate the CUSTOMIZE
    /// pickers use since F1.
    private var shellChooser: some View {
        LazyVGrid(columns: swatchColumns, spacing: 8) {
            ForEach(ChassisSkin.allCases) { option in
                let locked = !access.isUnlocked(option)
                partChip(
                    label: option.displayName,
                    isChosen: (ChassisSkin(rawValue: shell) ?? .classic) == option,
                    symbol: locked ? "lock.fill" : nil
                ) {
                    if locked {
                        lockedBundle = .skins
                    } else {
                        set(.shell, option == .classic ? "" : option.rawValue)
                    }
                } swatch: {
                    Circle()
                        .fill(Color(dexHex: "#1B1D21"))
                        .overlay(Circle().fill(option.body))
                }
                .opacity(locked ? 0.45 : 1)
            }
        }
    }

    private var screenChooser: some View {
        LazyVGrid(columns: swatchColumns, spacing: 8) {
            ForEach(LcdMode.allCases) { option in
                let locked = !access.isUnlocked(option)
                partChip(
                    label: option.displayName,
                    isChosen: lcd == option,
                    symbol: locked ? "lock.fill" : option.symbol
                ) {
                    if locked {
                        lockedBundle = .lightMode
                    } else {
                        set(.screen, option == .dark ? "" : option.rawValue)
                    }
                } swatch: {
                    Circle()
                        .fill(option.screen)
                        .overlay(Circle().strokeBorder(option.text.opacity(0.6), lineWidth: 1.5))
                }
                .opacity(locked ? 0.45 : 1)
            }
        }
    }

    /// One part chip: a swatch, an optional glyph over it, and a label.
    ///
    /// **The body moved to `DexPickerTile` in 0.7.3c** so the cartridge shelf
    /// could reuse it instead of becoming the app's fifth hand-written picker
    /// grid — see the note on that type. This stayed as a wrapper rather than
    /// being deleted for two reasons: the eight `chooser(for:)` rows call it with
    /// the workshop's own defaults (26pt swatch, circular outline) and should not
    /// each restate them, and keeping the signature meant the eight call sites
    /// and `DeviceWorkshopTests`' references to `shellChooser` did not move in a
    /// batch that was not about the workshop.
    private func partChip<S: View>(
        label: String,
        isChosen: Bool,
        symbol: String?,
        action: @escaping () -> Void,
        // `@escaping` where the old body did not need it: `DexPickerTile` stores
        // the builder as a property rather than calling it inside this function's
        // own `body` evaluation.
        @ViewBuilder swatch: @escaping () -> S
    ) -> some View {
        DexPickerTile(
            label: label,
            isChosen: isChosen,
            symbol: symbol,
            lcd: lcd,
            outline: Circle(),
            action: action,
            swatch: swatch
        )
    }

    /// Four columns: the chip is a 26pt swatch over a two-line label, and at
    /// three columns the twenty-one shells run seven rows deep.
    private var swatchColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    }

    // MARK: Saved builds (B2)

    @ViewBuilder
    private var savedBuilds: some View {
        section("SAVE THIS BUILD") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    DexSearchField(text: $typedName, placeholder: "NAME", fontSize: 18)
                        .frame(height: 30)
                    Button {
                        submitSave()
                    } label: {
                        Text("SAVE")
                            .font(DexFont.retro(11))
                            .tracking(1)
                            .foregroundStyle(lcd.onAccent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.accent))
                    }
                    .buttonStyle(DexPressStyle(scale: 0.97))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                )

                if let notice {
                    Text(notice.text)
                        .font(DexFont.mono(15))
                        .foregroundStyle(notice.isBad ? Dex.red500 : lcd.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Saving under a name you have already used replaces that build — which is how you edit one.")
                    .font(DexFont.mono(15))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        section("SAVED BUILDS") {
            if store.devices.isEmpty {
                Text("Nothing saved yet. Fit some parts, name the result, and it lands here.")
                    .font(DexFont.mono(16))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.devices) { device in
                        savedRow(device)
                    }
                }
            }
        }
    }

    private func savedRow(_ device: CustomDevice) -> some View {
        let isFitted = device.build == build
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(device.name)
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(isFitted ? lcd.accent : lcd.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if isFitted {
                    Text("FITTED")
                        .font(DexFont.retro(8))
                        .tracking(1)
                        .foregroundStyle(lcd.onAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 3).fill(lcd.accent))
                }
                Spacer(minLength: 8)
                // The build's own parts, as five dots — enough to tell two saved
                // builds apart in a list without opening either.
                HStack(spacing: 3) {
                    let saved = ChassisLook(build: device.build)
                    ForEach(
                        Array([saved.body, saved.accent.bright, saved.orb, saved.marqueeText, saved.grill].enumerated()),
                        id: \.offset
                    ) { _, color in
                        Circle().fill(color).frame(width: 8, height: 8)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    Haptics.select()
                    device.build.apply()
                    notice = .applied(device.name)
                } label: {
                    rowAction("FIT", tint: lcd.accent)
                }
                .buttonStyle(DexPressStyle(scale: 0.97))
                .disabled(isFitted)
                .opacity(isFitted ? 0.4 : 1)

                Button {
                    Haptics.select()
                    typedName = device.name
                } label: {
                    rowAction("EDIT", tint: lcd.subtext)
                }
                .buttonStyle(DexPressStyle(scale: 0.97))

                Button {
                    Haptics.select()
                    confirmingDelete = device
                } label: {
                    rowAction("DELETE", tint: Dex.red500)
                }
                .buttonStyle(DexPressStyle(scale: 0.97))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(
                isFitted ? lcd.accent.opacity(0.6) : lcd.surfaceEdge,
                lineWidth: isFitted ? 2 : 1
            )
        )
    }

    private func rowAction(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(DexFont.retro(10))
            .tracking(1)
            .foregroundStyle(tint)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 5).strokeBorder(tint.opacity(0.55), lineWidth: 2)
            )
    }

    /// EDIT loads the name into the field rather than opening a modal editor:
    /// the parts are already editable — they are the eight rows above — so the
    /// only thing an edit mode could add is a second way to type the same name.
    /// Re-saving under it replaces the build, which is `CustomDeviceStore.save`'s
    /// documented behaviour rather than a coincidence.
    private func submitSave() {
        Haptics.select()
        switch store.save(name: typedName, build: build) {
        case .saved:
            notice = .saved(CustomDeviceStore.normalize(typedName))
            typedName = ""
        case .replaced:
            notice = .replaced(CustomDeviceStore.normalize(typedName))
            typedName = ""
        case .needsName:
            notice = .needsName
        case .full:
            notice = .full
        case .nameTaken:
            notice = .nameTaken
        }
    }

    // MARK: Chrome

    /// The same heading shape the settings panels use, and the scroll anchor
    /// with it — see `SettingsSectionPanel.settingsSection`.
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(DexFont.retro(14))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
                .padding(.bottom, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { lcd.accent.opacity(0.45).frame(height: 2) }
            content()
        }
        .id(title)
    }
}
#endif
