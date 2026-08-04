#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import VinodexCore

/// The device's own menu: a grid of square feature tiles.
///
/// This was one scrolling column of every toggle in the app, plus a DEV tab.
/// That worked while there were two settings; by five it had grown past a
/// screenful, so the screen mode and text size a user actually reaches for sat
/// below developer tooling and a paywall switch. Each group now gets a tile and
/// its own panel, which also gives every group room to explain itself rather
/// than being squeezed into a single row.
///
/// Tiles push real routes (`DexRoute.settingsSection`), so the chassis Back
/// button steps back to this grid. Local state would have made Back exit
/// settings altogether from one level down.
public struct SettingsPanel: View {
    let onClose: () -> Void
    let onSection: (SettingsSection) -> Void
    let onMinigames: () -> Void
    let onWalkthrough: () -> Void

    /// Set when TUTORIAL is tapped. The tour is a few minutes of someone's time, so
    /// it asks before it takes them — and asking is also what makes it findable
    /// without being imposed: the tile says what it is, the prompt says what it
    /// will do, and NO costs one tap.
    @State private var offeringTour = false

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(
        onClose: @escaping () -> Void,
        onSection: @escaping (SettingsSection) -> Void = { _ in },
        onMinigames: @escaping () -> Void = {},
        onWalkthrough: @escaping () -> Void = {}
    ) {
        self.onClose = onClose
        self.onSection = onSection
        self.onMinigames = onMinigames
        self.onWalkthrough = onWalkthrough
    }

    public var body: some View {
        // A fixed three-row grid that fills the LCD (v0.5.6) — six tiles, no
        // scrolling: the panel is sized by the screen, not by its content.
        // TUTORIAL first, deliberately: it is the tile that matters to
        // exactly one person — someone who has just opened this thing — and
        // that person must not have to hunt for it.
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                featureTile(title: "TUTORIAL", symbol: "flag.checkered") {
                    offeringTour = true
                }
                // A wrench, not a gamepad — the hub holds more instruments
                // than games, and the tile should promise what it opens.
                featureTile(
                    title: "TOOLS",
                    symbol: "wrench.and.screwdriver.fill",
                    action: onMinigames
                )
            }
            // DEV is deliberately absent from the grid — it lives as a
            // button inside SETTINGS, where developer plumbing belongs.
            HStack(spacing: 10) {
                featureTile(
                    title: SettingsSection.customization.rawValue,
                    symbol: SettingsSection.customization.symbol
                ) {
                    onSection(.customization)
                }
                featureTile(
                    title: SettingsSection.settings.rawValue,
                    symbol: SettingsSection.settings.symbol
                ) {
                    onSection(.settings)
                }
            }
            HStack(spacing: 10) {
                featureTile(
                    title: SettingsSection.data.rawValue,
                    symbol: SettingsSection.data.symbol
                ) {
                    onSection(.data)
                }
                featureTile(
                    title: SettingsSection.access.rawValue,
                    symbol: SettingsSection.access.symbol
                ) {
                    onSection(.access)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(lcd.panelGround)
        // In-LCD, like every other dialog in the app — a system alert would
        // slide up from the device and break the chassis metaphor.
        .overlay {
            if offeringTour {
                DexAlert(
                    title: "TAKE THE TOUR?",
                    message: "A quick walk round the device — what each button does and where things live. About a minute, and you can leave at any point.",
                    confirmLabel: "YES",
                    cancelLabel: "NOT NOW",
                    onConfirm: {
                        offeringTour = false
                        onWalkthrough()
                    },
                    onCancel: { offeringTour = false }
                )
            }
        }
        .animation(DexMotion.overlay, value: offeringTour)
    }

    /// Per-tile colours, tuned separately for the pale and dark grounds
    /// (v0.5.6, reversing 0.5.3's uniform mode ramp): each tile is unique
    /// again — the colour is half the identity — and light mode runs the
    /// deeper cuts because the bright faces washed out on the pale page.
    private func tileColors(_ title: String) -> (face: String, shadow: String, ink: Color) {
        if lcd.isLight {
            return switch title {
            case "TUTORIAL": ("#15803D", "#0B4A24", .white)
            case "TOOLS": ("#B45309", "#7A3606", .white)
            case "CUSTOMIZE": ("#B91C1C", "#7A1010", .white)
            case "SETTINGS": ("#C2410C", "#7C2D12", .white)
            case "DATA": ("#1D6FA8", "#11486E", .white)
            default: ("#7E22CE", "#4C1D95", .white)   // ACCESS
            }
        }
        return switch title {
        case "TUTORIAL": ("#22C55E", "#15803D", .white)
        // White ink like every other tile (0.6.4, E1) — the dark-amber ink
        // made TOOLS the odd one out on the grid. The face deepens a step so
        // white still clears it, rather than sitting white-on-yellow.
        case "TOOLS": ("#EAB308", "#A16207", .white)
        case "CUSTOMIZE": ("#EF4444", "#991B1B", .white)
        case "SETTINGS": ("#F97316", "#9A3412", .white)
        case "DATA": ("#2AB5FF", "#136A99", .white)
        default: ("#A855F7", "#6B21A8", .white)       // ACCESS
        }
    }

    /// Styled like the main menu's tiles — filled face, 6pt bottom extrusion,
    /// top-left sheen. Stretches to fill its grid cell rather than squaring
    /// off (v0.5.6): the grid fits the LCD, so the tiles absorb the height.
    private func featureTile(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        let style = tileColors(title)
        // C5 (0.7.1): the `controlAccent` doc has claimed since 0.5.4 that the
        // settings tiles follow the screen mode. They never did — this table
        // was the counter-example, six literals with an `isLight` branch. Under
        // an Emulator mode they follow it now, and everywhere else the table
        // stands exactly as tuned.
        let paint = lcd.chrome(face: style.face, shadow: style.shadow)
        let ink = lcd.chromeInk(over: style.face, preferring: style.ink)

        return Button {
            Haptics.screenTap()
            action()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(ink)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2)
                Text(title)
                    .font(DexFont.retro(13))
                    .tracking(1)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 1, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(paint.face)
                    .overlay(alignment: .bottom) {
                        // The same 6pt fake extrusion the menu tiles carry.
                        paint.shadow.frame(height: 6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
    }
}

// MARK: - Section panels

/// The toggles for one `SettingsSection`.
///
/// Every group that was a section of the old single-column panel is now one of
/// these, reached from the grid. The controls themselves are unchanged — this is
/// a re-parenting, not a redesign of the switches.
public struct SettingsSectionPanel: View {
    let section: SettingsSection
    /// Opens the DEV panel. DEV lost its tile on the settings grid — it is
    /// developer plumbing, not a setting — and lives behind a button at the
    /// bottom of SETTINGS instead. A route push, so Back still works.
    let onDev: () -> Void
    /// The DEVICE section's three doors (0.7.3, A2–A4).
    ///
    /// Route pushes rather than local state, for the same reason `onDev` is: the
    /// chassis Back button has to return to the System panel rather than drop
    /// the user out of settings entirely.
    let onFirmwareHistory: () -> Void
    let onCheatConsole: () -> Void
    /// Starts the attract loop. Not a route — demo mode drives the *whole* route
    /// stack, so it is the app's business rather than a screen to push.
    let onDemoMode: () -> Void
    /// CUSTOMIZE's door to the builder (0.7.3, A1). A route push like the two
    /// above, so the chassis Back button returns here rather than dropping out
    /// of settings.
    let onDeviceWorkshop: () -> Void

    @State private var access = AccessStore.shared
    /// Read only to name the saved build the device is currently wearing — see
    /// `deviceWorkshop`. `@State` on the shared store rather than a fresh one, so
    /// saving a build in the workshop is reflected here on the way back out.
    @State private var customDevices = CustomDeviceStore.shared
    /// Set when a gated cosmetic is tapped; drives the same upgrade prompt a
    /// locked entry raises, so a paywalled *setting* behaves like a paywalled
    /// page rather than being a dead control.
    @State private var lockedBundle: Entitlement?
    /// CLEAR SAVED DATA asks first — it is the one control here that cannot be
    /// undone by tapping it again.
    @State private var confirmingWipe = false
    @AppStorage(Haptics.storageKey) private var hapticsOn = true
    /// Off by default from v0.5.1 — sounds are opt-in. See `Sounds`.
    @AppStorage(Sounds.storageKey) private var soundsOn = false
    /// Scroll position outlives the view — see `ScreenStateStore`. ACCESS and
    /// DATA are both taller than the LCD, so opening the upgrade prompt from a
    /// bundle row near the bottom used to bounce the panel back to the top.
    @State private var screens = ScreenStateStore.shared
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    @AppStorage(TextScale.storageKey) private var scaleRaw = TextScale.small.rawValue
    @AppStorage(UIScale.storageKey) private var uiScaleRaw = UIScale.small.rawValue
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue

    private let db = WineDatabase.shared

    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }
    private var scale: TextScale { TextScale(rawValue: scaleRaw) ?? .small }
    private var uiScale: UIScale { UIScale(rawValue: uiScaleRaw) ?? .small }
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    private var totalCount: Int { db.entries.count }

    public init(
        section: SettingsSection,
        onDev: @escaping () -> Void = {},
        onFirmwareHistory: @escaping () -> Void = {},
        onCheatConsole: @escaping () -> Void = {},
        onDemoMode: @escaping () -> Void = {},
        onDeviceWorkshop: @escaping () -> Void = {}
    ) {
        self.section = section
        self.onDev = onDev
        self.onFirmwareHistory = onFirmwareHistory
        self.onCheatConsole = onCheatConsole
        self.onDemoMode = onDemoMode
        self.onDeviceWorkshop = onDeviceWorkshop
    }

    private var screenKey: String { ScreenStateStore.settings(section.rawValue) }

    private var anchorBinding: Binding<String?> {
        Binding(
            get: { screens.anchor(for: screenKey) },
            set: { screens.setAnchor($0, for: screenKey) }
        )
    }

    public var body: some View {
        panelContent
            .background(lcd.panelGround)
        .overlay {
            if let lockedBundle {
                UpgradePrompt(
                    entitlement: lockedBundle,
                    onUnlock: {
                        access.grant(lockedBundle)
                        self.lockedBundle = nil
                        // **Continue where they were going** (0.7.3, C1). The
                        // cosmetic bundles have nowhere to continue *to* — the
                        // picker they were tapped from is already on screen and
                        // has just unlocked in place — but the workshop is a
                        // door, and stopping at "unlocked!" beside a button they
                        // now have to find and press again is the same
                        // half-finished unlock `RootView` fixed for locked
                        // entries.
                        if lockedBundle == .workshop { onDeviceWorkshop() }
                    },
                    onCancel: { self.lockedBundle = nil }
                )
            } else if confirmingWipe {
                DexAlert(
                    title: "CLEAR SAVED DATA?",
                    message: "Everything stored on this device — bookmarks, recents, tastings and ratings, quiz progress, streak, profile, purchases and appearance — goes back to a fresh install. This cannot be undone.",
                    confirmLabel: "ERASE",
                    onConfirm: {
                        confirmingWipe = false
                        SavedDataReset.wipeAll()
                    },
                    onCancel: { confirmingWipe = false }
                )
            }
        }
        .animation(DexMotion.overlay, value: lockedBundle)
        .animation(DexMotion.overlay, value: confirmingWipe)
    }

    /// DATA is a fixed page (0.6.4, C2) — everything else scrolls.
    ///
    /// The readout is three short blocks and was the only panel whose scroll
    /// existed purely because the growth graph sat at a fixed 96pt with dead
    /// space beneath it. The graph absorbs the leftover height instead, so
    /// the page fits the LCD exactly and the scroll machinery (and its
    /// anchor restoration) has nothing left to do here.
    @ViewBuilder
    private var panelContent: some View {
        if section == .data {
            dataReadout
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch section {
                    case .customization: customization
                    case .settings: systemSettings
                    // Handled by the fixed branch above; unreachable here,
                    // kept so the switch stays exhaustive.
                    case .data: EmptyView()
                    case .access: paywallTesting
                    case .dev: dev
                    }
                }
                // Pairs with `scrollPosition(id:)` — without it nothing in this
                // column is addressable and the anchor is ignored. Every branch
                // above emits `settingsSection`s as direct children, which is what
                // makes them the scroll targets; each carries its own title as its
                // id, so an anchor names a heading rather than an offset.
                .frame(maxWidth: .infinity, alignment: .leading)
                .scrollTargetLayout()
            }
            // Content margins rather than padding around the target layout — see
            // the note in `EncyclopediaListScreen`.
            .contentMargins(12, for: .scrollContent)
            .scrollPosition(id: anchorBinding)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    /// Free-tier switch, then the individual bundles.
    ///
    /// One boolean could only produce two states — all locked or all open — so
    /// every interesting case went untested. The bundle rows below reproduce
    /// them: own one country and nothing else, own the flavour wheel but no
    /// atlas, own a cosmetic but no content. The counter under the master
    /// switch reports what the current combination actually yields, which is
    /// the fastest way to see a coverage rule behaving wrongly.
    @ViewBuilder
    private var paywallTesting: some View {
        settingsSection("FREE TIER") {
            VStack(alignment: .leading, spacing: 10) {
                settingRow(
                    symbol: access.starterOnly ? "lock.fill" : "lock.open.fill",
                    tint: access.starterOnly ? Dex.yellow : Dex.green,
                    title: access.starterOnly ? "FREE TIER" : "EVERYTHING UNLOCKED",
                    detail: access.starterOnly
                        ? "\(browsableCount) of \(totalCount) entries browsable"
                        : "All \(totalCount) entries browsable"
                ) {
                    DexToggle(isOn: access.starterOnly) { access.starterOnly.toggle() }
                }

                Text("Off means everything is open regardless of bundles — turn it on to test the locked experience.")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        settingsSection("BUNDLES") {
            VStack(spacing: 10) {
                ForEach(testableEntitlements, id: \.id) { entitlement in
                    settingRow(
                        symbol: bundleSymbol(entitlement),
                        tint: access.granted.contains(entitlement) ? Dex.green : lcd.subtext,
                        title: entitlement.title,
                        detail: entitlement.blurb
                    ) {
                        DexToggle(
                            isOn: access.granted.contains(entitlement),
                            tint: Dex.green
                        ) {
                            access.toggle(entitlement)
                        }
                    }
                }

                if !access.granted.isEmpty {
                    Button {
                        Haptics.select()
                        access.revokeAll()
                    } label: {
                        Text("REVOKE ALL PURCHASES")
                            .font(DexFont.retro(11))
                            .tracking(1)
                            .foregroundStyle(Dex.red500)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Dex.red500.opacity(0.55), lineWidth: 2)
                            )
                    }
                    .buttonStyle(DexPressStyle(scale: 0.98))
                }
            }
        }
    }

    /// The bundles the ACCESS panel offers as test cases.
    ///
    /// Country bundles are drawn from the countries that actually have regions,
    /// capped at the three largest — the panel is a test harness, not a store,
    /// and eighteen country rows would bury the cosmetic cases underneath them.
    /// `.workshop` joined the cosmetics in 0.7.3 (C1). It is a real gate with a
    /// real surface behind it now, and the ACCESS harness exists so that the
    /// *unowned* state of a gate can be reached in one tap — which for a premium
    /// feature is the state most likely to be wrong and least likely to be seen
    /// by the person who built it.
    ///
    /// `.expansion` and `.easterEgg` still stay out: no pack ships yet, and eggs
    /// are found rather than bought (see the note on `bundleSymbol`).
    private var testableEntitlements: [Entitlement] {
        [.pro, .flavors] + topCountries.map { Entitlement.country($0) } + [.skins, .lightMode, .workshop]
    }

    private var topCountries: [String] {
        var counts: [String: Int] = [:]
        for entry in db.entries(in: .regions) {
            guard let origin = entry.origin, !origin.isEmpty else { continue }
            counts[origin, default: 0] += 1
        }
        return counts
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .prefix(3)
            .map(\.key)
    }

    private func bundleSymbol(_ entitlement: Entitlement) -> String {
        switch entitlement {
        case .pro: "crown.fill"
        case .flavors: "leaf.fill"
        case .country: "flag.fill"
        case .skins: "paintpalette.fill"
        case .lightMode: "sun.max.fill"
        // Not in `testableEntitlements`, so these never reach the ACCESS
        // harness today — the switch is exhaustive because `Entitlement` is,
        // and 0.7.3b/0.7.3c will want them listed here when they have something
        // to sell. `key.fill` matches the cheat console's own progress row.
        case .expansion: "shippingbox.fill"
        case .workshop: "wrench.and.screwdriver.fill"
        case .easterEgg: "key.fill"
        }
    }

    /// How many entries the *current* combination of tier and bundles opens.
    private var browsableCount: Int {
        db.entries.filter { !access.isLocked($0, in: db) }.count
    }

    /// The shared shape of a settings row: glyph, title, one line of
    /// explanation, and a control on the right.
    private func settingRow<C: View>(
        symbol: String,
        tint: Color,
        title: String,
        detail: String,
        @ViewBuilder control: () -> C
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DexFont.retro(13))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
        )
    }

    /// Screen mode, then the shell — what the device looks like. Text size
    /// lived here too until SETTINGS existed; it is a comfort setting, not a
    /// colour choice, and it moved out with the other device behaviour.
    ///
    /// **The workshop goes first (0.7.3, B1/A1)**, above the two pickers rather
    /// than below them, because it is the *superset*: it sets the shell and the
    /// screen mode as well as the six parts these two panels have never been able
    /// to touch. Putting it under twenty-one skin tiles and nine mode cards would
    /// have buried the page's most capable control behind two full screenfuls of
    /// the two axes it also contains.
    @ViewBuilder
    private var customization: some View {
        deviceWorkshop
        screenMode
        skinTesting
    }

    /// The door to the Device Workshop (0.7.3, A1/C1).
    ///
    /// **Shown whether or not it is owned, which is C1's instruction and the
    /// 0.7.3 position on premium.** Premium is an entitlement flag, unlockable
    /// now and StoreKit-swappable later — not a hard paywall — so the unowned
    /// state is not a locked door with nothing behind it: the section says what
    /// the workshop is, and the button offers to unlock it. Hiding the section
    /// outright was the other option and it is worse in both directions; nobody
    /// discovers a feature that is invisible, and a device that grows a new
    /// settings section on purchase looks broken before it.
    ///
    /// **No new store.** Ownership is `access.isUnlocked(.workshop)` — the one
    /// entitlement set F1 left, reached through the one predicate — and the
    /// unlock path is `UpgradePrompt`, exactly as a locked skin or a locked entry
    /// takes. It grants and then *continues* into the workshop rather than
    /// stopping at "unlocked!", which is the correction `RootView`'s own paywall
    /// note records for the entry gate.
    private var deviceWorkshop: some View {
        let owned = access.isUnlocked(.workshop)
        return settingsSection("DEVICE WORKSHOP") {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    Haptics.screenTap()
                    if owned {
                        onDeviceWorkshop()
                    } else {
                        // Granting continues into the builder — see the note
                        // above. The prompt's own `onUnlock` fires first.
                        lockedBundle = .workshop
                    }
                } label: {
                    settingRow(
                        // Matches the marquee glyph the route wears (K2, rule 1)
                        // — see `DexRoute.deviceWorkshop`.
                        symbol: owned ? "hammer.fill" : "lock.fill",
                        tint: owned ? lcd.accent : Dex.yellow,
                        title: owned ? "OPEN" : "UNLOCK",
                        detail: owned
                            ? "Mix shell, buttons, orb, marquee, grille, screen and font. Save the builds you like."
                            : "Build your own handheld: eight parts, mixed and matched, saved by name."
                    ) {
                        Image(systemName: owned ? "chevron.right" : "lock.open.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(lcd.subtext)
                    }
                }
                .buttonStyle(DexPressStyle(scale: 0.98))

                if owned, let fitted = customDevices.matching(DeviceBuild.active()) {
                    // States which saved build is fitted, derived rather than
                    // stored — see `CustomDeviceStore.matching(_:)`. Nothing
                    // shows when the device is wearing something unsaved, which
                    // is honest: it is not wearing one of your builds.
                    Text("FITTED: \(fitted.name)")
                        .font(DexFont.retro(10))
                        .tracking(1)
                        .foregroundStyle(lcd.accent)
                } else if !owned {
                    Text("The shell and screen pickers below stay free. The workshop is the six parts they cannot reach — buttons, orb, marquee, grille colour and pattern, and the font.")
                        .font(DexFont.mono(17))
                        .foregroundStyle(lcd.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Device behaviour: text size, UI size, haptics, and the stored-data reset.
    @ViewBuilder
    private var systemSettings: some View {
        textSize
        uiSize

        settingsSection("HAPTICS") {
            VStack(alignment: .leading, spacing: 10) {
                settingRow(
                    symbol: "iphone.radiowaves.left.and.right",
                    tint: hapticsOn ? Dex.green : lcd.subtext,
                    title: "HAPTICS",
                    detail: hapticsOn
                        ? "Every chassis button clicks in your hand."
                        : "The buttons are silent to the hand."
                ) {
                    DexToggle(isOn: hapticsOn, tint: Dex.green) { hapticsOn.toggle() }
                }
            }
        }

        settingsSection("SOUNDS") {
            VStack(alignment: .leading, spacing: 10) {
                settingRow(
                    symbol: "speaker.wave.2.fill",
                    tint: soundsOn ? Dex.green : lcd.subtext,
                    title: "SOUNDS",
                    detail: soundsOn
                        ? "Clicks, pings and stings from the SFX pack."
                        : "The device is silent to the ear."
                ) {
                    DexToggle(isOn: soundsOn, tint: Dex.green) { soundsOn.toggle() }
                }
                Text("The ring/silent switch always wins — sounds never interrupt your music.")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        // **The System panel's new row of doors (0.7.3, A2–A4).** One section
        // rather than three: A3 and A4 both ask for "a new button in the System
        // panel", A2 for one "in Settings", and three more headings in a panel
        // that already had six would have buried TEXT SIZE — the setting people
        // actually come here for — under a stack of device curiosities. They
        // belong together anyway: none of the three is a *setting*, they are
        // three things the device can tell you or do.
        settingsSection("DEVICE") {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    Haptics.screenTap()
                    onFirmwareHistory()
                } label: {
                    settingRow(
                        symbol: "memorychip.fill",
                        tint: lcd.accent,
                        title: "FIRMWARE",
                        // States the installed version on the row itself. The
                        // panel behind it is the history; the number is the
                        // thing most people opening this want, and making them
                        // tap through for it would be a step for nothing.
                        detail: "\(AppVersion.display) — what changed, release by release."
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(lcd.subtext)
                    }
                }
                .buttonStyle(DexPressStyle(scale: 0.98))

                Button {
                    Haptics.screenTap()
                    onCheatConsole()
                } label: {
                    settingRow(
                        symbol: "terminal.fill",
                        tint: lcd.accent,
                        title: "CHEAT CODES",
                        detail: "Enter unlock codes for cosmetics and hidden features."
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(lcd.subtext)
                    }
                }
                .buttonStyle(DexPressStyle(scale: 0.98))

                Button {
                    Haptics.select()
                    onDemoMode()
                } label: {
                    settingRow(
                        symbol: "play.rectangle.fill",
                        tint: lcd.accent,
                        title: "DEMO MODE",
                        detail: "Cycles the tools unattended. Any input stops it."
                    ) {
                        // No chevron: this one does not open a panel, it starts
                        // something and closes settings behind it. A chevron
                        // would promise a page to come back from.
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(lcd.subtext)
                    }
                }
                .buttonStyle(DexPressStyle(scale: 0.98))
            }
        }

        settingsSection("STORED DATA") {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    Haptics.select()
                    confirmingWipe = true
                } label: {
                    Text("CLEAR SAVED DATA")
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .foregroundStyle(Dex.red500)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Dex.red500.opacity(0.55), lineWidth: 2)
                        )
                }
                .buttonStyle(DexPressStyle(scale: 0.98))

                Text("Erases bookmarks, tastings and ratings, quiz progress, the daily streak, name and photo, purchases, skin, screen and text settings. The encyclopedia itself is untouched.")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        settingsSection("DEVELOPER") {
            Button {
                Haptics.screenTap()
                onDev()
            } label: {
                settingRow(
                    symbol: "ladybug.fill",
                    tint: lcd.subtext,
                    title: "DEV",
                    detail: "Diagnostics, the component gallery and the icon sheet."
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(lcd.subtext)
                }
            }
            .buttonStyle(DexPressStyle(scale: 0.98))
        }
    }

    /// "CHASSIS SKINS", not "SHELL SKINS": the rest of the app calls this part
    /// of the device the chassis — `DeviceChassis`, `ChassisSkin`,
    /// `ChassisButton` — and the settings panel was the one place using a
    /// second word for it.
    ///
    /// Everything past the default is gated on `.skins`, which is what makes a
    /// cosmetic bundle a testable paywall case rather than a hypothetical one.
    /// The same three-column card grid the screen modes use, so the two
    /// cosmetic pickers read as one instrument. Was a vertical list — at
    /// fourteen skins the rows pushed everything below them off screen.
    private var skinTesting: some View {
        settingsSection("CHASSIS SKINS") {
            // **Grouped since 0.7.0 (B2).** Twenty-one tiles in one flat grid
            // showed the whole range and said nothing about it. The headings
            // come from `ChassisSkinSection`, and the membership is derived
            // from `ChassisSkin.allCases` rather than listed here — see the
            // note on `ChassisSkin.section`. Nothing in this file can drop a
            // skin from the picker.
            VStack(alignment: .leading, spacing: 16) {
                ForEach(ChassisSkinSection.allCases) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        pickerHeading(group.rawValue)
                        skinGrid(group.skins)
                    }
                }
            }
        }
    }

    /// A sub-heading inside one of the two cosmetic pickers (0.7.0, B1/B2).
    ///
    /// Deliberately quieter than `settingsSection`'s own title: this is a
    /// division *within* a section, and at the same weight the panel would read
    /// as having twelve top-level sections rather than two with headings in
    /// them. Subtext rather than accent, no rule, and a shorter tracking run.
    private func pickerHeading(_ title: String) -> some View {
        Text(title)
            .font(DexFont.retro(11))
            .tracking(1.5)
            .foregroundStyle(lcd.subtext)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func skinGrid(_ skins: [ChassisSkin]) -> some View {
        LazyVGrid(columns: pickerColumns, spacing: 8) {
            ForEach(skins) { option in
                // The option names its own bundle since 0.7.3 (F1) — see
                // `CosmeticEntitlements`. This line used to be
                // `option != .classic && !access.isUnlocked(.skins)`, written
                // out here and three more times elsewhere.
                let locked = !access.isUnlocked(option)

                Button {
                    Haptics.select()
                    if locked {
                        lockedBundle = .skins
                    } else {
                        skinRaw = option.rawValue
                    }
                } label: {
                    VStack(spacing: 8) {
                        // Body over panel, so the swatch reads as the
                        // actual shell — with the skin's emblem glyph in
                        // the middle, the way the screen-mode tiles carry
                        // theirs, at the same 50pt so the two pickers
                        // read as one instrument (v0.5.6). The dark base
                        // under the body is for the translucent skins,
                        // whose smoke needs something to be over.
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(dexHex: "#1B1D21"))
                            .overlay(RoundedRectangle(cornerRadius: 5).fill(option.body))
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .topLeading) {
                                Circle()
                                    .fill(option.orb)
                                    .frame(width: 10, height: 10)
                                    .padding(5)
                            }
                            .overlay(alignment: .topTrailing) {
                                Circle()
                                    .fill(option.accent.bright)
                                    .frame(width: 10, height: 10)
                                    .padding(5)
                            }
                            .overlay {
                                // Through `SkinEmblem` rather than
                                // `Image(systemName:)` since 0.6.7 (K1):
                                // PSVino's badge is a drawing now, not a
                                // symbol name.
                                SkinEmblem(skin: option, size: 17, tint: option.accent.pale)
                                    .shadow(color: .black.opacity(0.55), radius: 0, x: 1, y: 1)
                                    // Centred in the deck, not the tile —
                                    // the bottom 14pt is the panel strip.
                                    .offset(y: -7)
                            }
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(option.panel)
                                    .frame(height: 14)
                                    .overlay {
                                        Capsule()
                                            .fill(option.marqueeText)
                                            .frame(width: 24, height: 3)
                                    }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(option.panelEdge, lineWidth: 1)
                            )
                            .overlay(alignment: .bottomTrailing) {
                                // Lock/tick rides the preview so the name
                                // below keeps the tile's full width.
                                if locked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(4)
                                } else if skin == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(4)
                                }
                            }
                            .opacity(locked ? 0.45 : 1)

                        // A fixed two-line box (v0.5.8, C2). The old
                        // word-per-line stack gave every tile its own
                        // height — three-word names ran a line taller and
                        // one-word tiles floated short in their grid row.
                        // Reserving two lines makes all fourteen tiles
                        // congruent; long names wrap, short ones centre.
                        Text(option.displayName)
                            .font(DexFont.retro(10))
                            .tracking(1)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            // `minHeight`, not `height` (0.7.1, A4).
                            // `minimumScaleFactor` resolves a *width*
                            // shortfall; it does nothing about a two-line box
                            // exceeding a hard height. VINODEX CLASSIC in an
                            // 82pt cell settles near 0.94 to fit its longest
                            // word, and two lines at 11.5 × 0.94 × the face's
                            // 1.374 em line height is 29.7pt against 28 — the
                            // second line's descenders clipped. A minimum
                            // still gives the congruent box the note above
                            // wants, and lets the rare tall case breathe.
                            .frame(minHeight: 28)
                    }
                    .foregroundStyle(skin == option ? lcd.onAccent : lcd.subtext)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(skin == option ? lcd.accent : lcd.surface)
                    )
                }
                .buttonStyle(DexPressStyle(scale: 0.97))
            }
        }
    }

    /// Separate from the chassis skin on purpose: the shell and the screen are
    /// independent choices, and a light screen in the red shell is a perfectly
    /// good combination.
    /// A three-column grid of mode cards, one per `LcdMode`. Was a horizontal
    /// shelf for one release — at ten modes the shelf hid most of them off the
    /// right edge, and a grid shows the whole range at once.
    ///
    /// **Grouped since 0.7.0 (B1)**, on the same mechanism as the skins above:
    /// headings from `LcdModeSection`, membership derived from
    /// `LcdMode.allCases`.
    ///
    /// Each card is a miniature LCD in the mode's own colours: glyph, a text
    /// line, a caption line. The monochrome modes run the real grayscale-and-
    /// tint pass over their miniature, so AMBER previews amber rather than
    /// the green its raw tokens would show.
    private var screenMode: some View {
        settingsSection("SCREEN MODE") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(LcdModeSection.allCases) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        pickerHeading(group.rawValue)
                        modeGrid(group.modes)
                    }
                }
            }
        }
    }

    private func modeGrid(_ modes: [LcdMode]) -> some View {
        LazyVGrid(columns: pickerColumns, spacing: 8) {
            ForEach(modes) { option in
                // Every mode past the default gates on the same cosmetic
                // bundle — a paywall case that costs nothing to test and
                // touches every screen. Which mode is the default, and which
                // bundle the rest ride, is the option's own business since
                // 0.7.3 (F1) — see `CosmeticEntitlements`.
                let locked = !access.isUnlocked(option)

                Button {
                    Haptics.select()
                    if locked {
                        lockedBundle = .lightMode
                    } else {
                        lcdRaw = option.rawValue
                    }
                } label: {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(option.screen)
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .overlay {
                                VStack(spacing: 4) {
                                    Image(systemName: option.symbol)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(option.accent)
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(option.text.opacity(0.85))
                                        .frame(width: 34, height: 3)
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(option.subtext.opacity(0.8))
                                        .frame(width: 24, height: 3)
                                }
                            }
                            .grayscale(option.monochromeTint == nil ? 0 : 1)
                            .colorMultiply(option.monochromeTint ?? .white)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(option.surfaceEdge, lineWidth: 1)
                            )
                            .opacity(locked ? 0.45 : 1)

                        HStack(spacing: 4) {
                            if locked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            Text(option.displayName)
                                .font(DexFont.retro(10))
                                .tracking(1)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                        }
                    }
                    .foregroundStyle(lcd == option ? lcd.onAccent : lcd.subtext)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(lcd == option ? lcd.accent : lcd.surface)
                    )
                }
                .buttonStyle(DexPressStyle(scale: 0.97))
            }
        }
    }

    /// The shared three-column layout both cosmetic pickers use.
    private var pickerColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }

    private var textSize: some View {
        settingsSection("TEXT SIZE") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(TextScale.allCases) { option in
                        Button {
                            Haptics.select()
                            scaleRaw = option.rawValue
                        } label: {
                            Text(option.rawValue)
                                // No `.tracking(1)` since 0.6.4: a third option
                                // splits the row into ~97pt columns, and the
                                // retro face advances a full em, so six letters
                                // plus tracking no longer clear it. The letter-
                                // spacing is what gives, not the size.
                                .font(DexFont.retro(13))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(scale == option ? lcd.onAccent : lcd.subtext)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(scale == option ? lcd.accent : lcd.surface)
                                )
                        }
                        .buttonStyle(DexPressStyle(scale: 0.97))
                    }
                }
                Text("Vinodex sizes its own text — this is the control, not iOS Settings.")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The chrome axis (v0.5.8, F1) — same two-button shape as TEXT SIZE so
    /// the pair reads as siblings, one per axis.
    private var uiSize: some View {
        settingsSection("UI SIZE") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(UIScale.allCases) { option in
                        Button {
                            Haptics.select()
                            uiScaleRaw = option.rawValue
                        } label: {
                            // The guards its sibling `textSize` carries, and
                            // the note that explains them (0.7.1, A4). This
                            // has two options and does not break today; it
                            // breaks the day a third is added, which is
                            // exactly the change that broke `textSize` and
                            // produced that note.
                            Text(option.rawValue)
                                .font(DexFont.retro(13))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(uiScale == option ? lcd.onAccent : lcd.subtext)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(uiScale == option ? lcd.accent : lcd.surface)
                                )
                        }
                        .buttonStyle(DexPressStyle(scale: 0.97))
                    }
                }
                Text("Buttons, wells and chassis chrome — the text keeps its own size above.")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Data

    /// A readout, not a setting: what the shipped database actually holds.
    ///
    /// Counts come from `WineDatabase.databaseStats` rather than being counted
    /// here, so `CoverageTests` can pin them — `VinodexUI` has no test target.
    ///
    /// A fixed page since 0.6.4 (C2): one `VStack` sized by the LCD, the
    /// growth graph absorbing whatever height the two count blocks leave, and
    /// the explanatory caption under the graph gone with the scroll. (The
    /// loose-sections layout this replaces existed for scroll-anchor
    /// addressability, which a non-scrolling page no longer needs.)
    private var dataReadout: some View {
        let stats = db.databaseStats

        return VStack(alignment: .leading, spacing: 18) {
            // TOTAL ENTRIES leads (0.6.8, A1). It was under the per-table
            // breakdown, which is the wrong way round for a readout: the total
            // is the headline and the six tiles are how it is made up, so
            // reading down the page now goes from the fact to its parts rather
            // than asking you to add up six numbers and then confirming them.
            settingsSection("TOTAL ENTRIES") {
                // Centred (0.6.4, C3) — the "ACROSS 6 TABLES" tail is gone;
                // the number is the fact, so it holds the middle.
                HStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(lcd.accent)
                    Text("\(stats.total)")
                        .font(DexFont.retro(24))
                        .foregroundStyle(lcd.text)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                )
            }

            settingsSection("DATABASE") {
                LazyVGrid(columns: statColumns, spacing: 8) {
                    ForEach(stats.categoryLines) { line in
                        statTile(label: line.label, count: line.count)
                    }
                }
            }

            settingsSection("GROWTH") {
                DataWave(milestones: stats.waveMilestones, lcd: lcd)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var statColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]
    }

    /// Glyph and tint per table. The five categories reuse the main menu's own
    /// symbols and colours so a count is recognisably the same thing as the
    /// tile that opens it; COUNTRIES is the odd one out and gets a flag.
    private func statGlyph(_ label: String) -> (symbol: String, tint: Color) {
        switch label {
        case "GRAPES": ("circle.grid.3x3.fill", Color(dexHex: "#a855f7"))
        case "REGIONS": ("globe.americas.fill", Color(dexHex: "#22c55e"))
        case "STYLES": ("wineglass.fill", Color(dexHex: "#f97316"))
        case "FLAVORS": ("leaf.fill", Color(dexHex: "#10b981"))
        case "CONTINENTS": ("map.fill", Dex.blue)
        default: ("flag.fill", Dex.yellow)
        }
    }

    private func statTile(label: String, count: Int) -> some View {
        let glyph = statGlyph(label)

        return HStack(spacing: 10) {
            Image(systemName: glyph.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(glyph.tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(count)")
                    .font(DexFont.retro(15))
                    .foregroundStyle(lcd.text)
                Text(label)
                    .font(DexFont.mono(15))
                    .foregroundStyle(lcd.subtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(glyph.tint.opacity(0.45), lineWidth: 1)
        )
    }

    private func settingsSection<C: View>(
        _ title: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        // Titles were 10pt retro over a 1pt hairline — smaller than the body
        // copy beneath them, so they read as captions rather than as headings
        // and the panel had no visible structure. 14pt over a 2pt rule.
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
        // The heading doubles as the section's scroll anchor — see
        // `anchorBinding`. Titles are unique within a panel, which is what makes
        // them usable as ids.
        .id(title)
    }

    // MARK: Dev

    /// Report, then the component gallery, then the icon sheet last — the icon
    /// grid is the longest thing here and buried everything after it.
    ///
    /// Loose rather than in a `VStack`, for the same reason `dataReadout` is:
    /// this is the tallest panel in the app and its three blocks have to be
    /// individually addressable for the scroll position to come back.
    @ViewBuilder
    private var dev: some View {
        DiagnosticsReport(db: db).id("DIAGNOSTICS")
        CatalogScreen(db: db, showsIcons: false).id("COMPONENTS")
        CatalogScreen.IconSheet(db: db).id("ICONS")
    }
}

// MARK: - Physical toggle

/// A hardware-looking switch: a recessed track with a raised, bevelled throw
/// that slides between two detents.
///
/// Replaces a flat 42x24 capsule with a white dot in it. On a chassis built
/// entirely out of physical metaphors — moulded buttons, a screwed-on back
/// plate, a glass orb — the one actual *setting* control was the only thing
/// that looked like a web page. Sized to be hit with a thumb, too: the old one
/// was under the 44pt touch minimum in both axes.
public struct DexToggle: View {
    let isOn: Bool
    /// Lit colour of the track and the throw's inset when engaged.
    var tint: Color = Dex.yellow
    let action: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(isOn: Bool, tint: Color = Dex.yellow, action: @escaping () -> Void) {
        self.isOn = isOn
        self.tint = tint
        self.action = action
    }

    private let width: CGFloat = 76
    private let height: CGFloat = 40
    private var throwSize: CGFloat { height - 8 }

    public var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                // The well. Darker than the surface it sits on, so the throw
                // reads as sitting *in* something rather than on top of it.
                Capsule()
                    .fill(isOn ? tint.opacity(0.85) : Dex.stone900)
                    .overlay(
                        Capsule().strokeBorder(
                            isOn ? tint : Dex.stone700,
                            lineWidth: 2
                        )
                    )
                    .overlay(
                        // Inner shadow along the top lip — the cue that sells a
                        // recess. A full inner shadow is not available, so this
                        // is the top edge alone, which is the part the eye uses.
                        Capsule()
                            .stroke(.black.opacity(0.45), lineWidth: 3)
                            .blur(radius: 2)
                            .mask(Capsule().fill(
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            ))
                    )

                // The throw: bevelled, with a knurled grip line so it reads as
                // something a thumb pushes.
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Dex.stone200, Dex.stone400, Dex.stone600],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                    .overlay(
                        Capsule()
                            .fill(Dex.stone700.opacity(0.55))
                            .frame(width: 2, height: throwSize * 0.42)
                    )
                    .frame(width: throwSize, height: throwSize)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                    .padding(4)
            }
            .frame(width: width, height: height)
            .animation(DexMotion.settle, value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "On" : "Off")
    }
}

// MARK: - Growth wave

/// The DATA panel's growth graph: an area chart that sweeps left to right
/// through the dataset's milestones while a counter runs up alongside it.
///
/// Drawn in a `Canvas` rather than assembled from shapes because the curve is
/// sampled per pixel-column — a ripple rides on top of the value line so it
/// reads as a wave rather than as three straight segments.
private struct DataWave: View {
    let milestones: [Int]
    let lcd: LcdMode

    /// When the sweep started, and whether it has run out.
    ///
    /// Driven by a `TimelineView` clock rather than by animating a `@State`
    /// through an `Animatable` view. The obvious version — a view conforming to
    /// `Animatable` so SwiftUI hands it interpolated values — does not compile
    /// under Swift 6: `View` conformance isolates the type to the main actor
    /// while `Animatable.animatableData` is a nonisolated requirement, and the
    /// conformance is rejected as a data race. A clock needs no such crossing,
    /// and `paused` lets the timeline stop once the sweep is done rather than
    /// redrawing this panel forever.
    @State private var start = Date()
    @State private var finished = false
    /// The sweep is decoration over a number that is already correct, so under
    /// Reduce Motion it simply starts finished — the panel shows the settled
    /// curve and the real total, and no clock runs. (AUDIT M18)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let duration: Double = 2.6

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.animation(paused: finished || reduceMotion)) { timeline in
                // The counter and the curve must advance together, so both are
                // rendered from the same value.
                let elapsed = timeline.date.timeIntervalSince(start)
                let linear = reduceMotion ? 1 : min(max(elapsed / Self.duration, 0), 1)
                // Eased so the sweep settles into the total instead of running
                // at full speed and stopping dead on the last frame.
                let p = linear * linear * (3 - 2 * linear)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(Int(dataWaveValue(at: p, in: milestones).rounded()))")
                        .font(DexFont.retro(22))
                        .foregroundStyle(lcd.accent)
                    wave(p)
                }
            }
            legend
        }
        .onAppear {
            start = Date()
            finished = false
        }
        .task {
            // A little past the end, so the final frame is the settled one.
            try? await Task.sleep(for: .seconds(Self.duration + 0.15))
            finished = true
        }
    }

    private func wave(_ p: Double) -> some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }
            let peak = Double(milestones.max() ?? 0)
            guard peak > 0 else { return }

            let baseline = size.height - 8
            let top: CGFloat = 8
            let usable = baseline - top
            guard usable > 0 else { return }

            // Never exactly zero: a zero-width sweep produces a degenerate path
            // that Canvas draws as a stray dot at the origin.
            let visible = min(max(p, 0.0001), 1)
            let steps = 140

            func point(at f: Double) -> CGPoint {
                let v = dataWaveValue(at: f, in: milestones) / peak
                // The ripple scales with the value so the flat empty start does
                // not wobble below its own axis.
                let ripple = sin(f * 13 + p * 5) * 0.03 * v
                let height = min(max(v + ripple, 0), 1)
                return CGPoint(
                    x: CGFloat(f) * size.width,
                    y: baseline - CGFloat(height) * usable
                )
            }

            var line = Path()
            var area = Path()
            area.move(to: CGPoint(x: 0, y: baseline))

            for i in 0...steps {
                let f = Double(i) / Double(steps) * visible
                let pt = point(at: f)
                if i == 0 { line.move(to: pt) } else { line.addLine(to: pt) }
                area.addLine(to: pt)
            }
            area.addLine(to: CGPoint(x: CGFloat(visible) * size.width, y: baseline))
            area.closeSubpath()

            // Axis first, so the fill sits over it rather than cutting it.
            var axis = Path()
            axis.move(to: CGPoint(x: 0, y: baseline))
            axis.addLine(to: CGPoint(x: size.width, y: baseline))
            context.stroke(axis, with: .color(lcd.accent.opacity(0.3)), lineWidth: 1)

            context.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [lcd.accent.opacity(0.42), lcd.accent.opacity(0.03)]),
                    startPoint: CGPoint(x: 0, y: top),
                    endPoint: CGPoint(x: 0, y: baseline)
                )
            )
            context.stroke(line, with: .color(lcd.accent), lineWidth: 2)

            let head = point(at: visible)
            context.fill(
                Path(ellipseIn: CGRect(x: head.x - 4, y: head.y - 4, width: 8, height: 8)),
                with: .color(lcd.accent)
            )
        }
        // Flexible since 0.6.4 (C2): the DATA page is fixed-height now and
        // the wave is what soaks up the LCD's leftover space.
        //
        // **The 96pt floor is gone (0.6.7, I1).** It was the old fixed height,
        // kept "so the curve can never collapse", and it was half of why this
        // page changed the size of the LCD when you opened it: a hard minimum
        // on the one screen in the app that does not scroll is a demand the
        // page makes of the housing, and on a shorter device (or at a larger
        // text step) the sum of the two count blocks plus 96 exceeded the
        // display. The housing is clamped at the other end now — see
        // `DeviceChassis.innerBezel` — but a page that only fits because it is
        // being clipped is not fitting. The `Canvas` has no intrinsic size, so
        // without a floor the graph simply takes what is left, down to
        // nothing, and the readout above it always fits.
        .frame(maxHeight: .infinity)
    }

    /// Milestone values under the curve, pinned to the ends so the first and
    /// last sit over the points they label rather than floating inward.
    private var legend: some View {
        HStack(spacing: 0) {
            ForEach(Array(milestones.enumerated()), id: \.offset) { index, value in
                Text("\(value)")
                    .font(DexFont.mono(15))
                    .foregroundStyle(lcd.subtext)
                    .frame(
                        maxWidth: .infinity,
                        alignment: index == 0
                            ? .leading
                            : (index == milestones.count - 1 ? .trailing : .center)
                    )
            }
        }
    }

}

/// The value along the milestone track at `f` in 0...1.
///
/// Eased between stops with a smoothstep rather than interpolated linearly, so
/// the curve arcs into each milestone instead of turning a hard corner at it —
/// the difference between a wave and a zigzag.
///
/// A free function rather than a method on `DataWave`: it is called from the
/// `Canvas` renderer, which is a nonisolated closure, and a member of a
/// main-actor-isolated `View` reached from there is diagnosed as a cross-actor
/// call. Nothing here touches view state, so it does not need to be one.
private func dataWaveValue(at f: Double, in points: [Int]) -> Double {
    guard let first = points.first else { return 0 }
    guard points.count > 1 else { return Double(first) }

    let clamped = min(max(f, 0), 1)
    let scaled = clamped * Double(points.count - 1)
    let index = min(Int(scaled), points.count - 2)
    let local = scaled - Double(index)
    let eased = local * local * (3 - 2 * local)

    let a = Double(points[index])
    let b = Double(points[index + 1])
    return a + (b - a) * eased
}

// MARK: - Clear saved data

/// CLEAR SAVED DATA. Lives in UI because half of what it clears (skin, LCD
/// mode, text scale, haptics, avatar) is UI-owned; the Core stores expose
/// their own resets and are called rather than reached into.
///
/// No relaunch needed: the `@AppStorage` reads are KVO-backed, so removing a
/// key snaps every view back to its declared default, and the stores are all
/// `@Observable` and mutated in memory here — removing their defaults keys
/// alone would leave stale state cached until the next launch.
@MainActor
enum SavedDataReset {
    static func wipeAll() {
        BookmarkStore.shared.removeEverything()
        RecentlyViewedStore.shared.clear()
        RevealCursor.shared.reset()
        AccessStore.shared.clearAll()
        AvatarStore.shared.clear()
        QuizProgress.shared.reset()
        StreakStore.shared.reset()
        // The back plate goes back to the scatter it ships with (0.6.7, C1).
        StampLayoutStore.shared.reset()
        // The stamp-unlock ledger and the pin bar (0.7.1, D2/B5). Both are
        // user state that survives a wipe otherwise: an un-reset ledger would
        // silently swallow the celebrations of a fresh start, which is the one
        // run where earning FIRST SIP again actually means something.
        PassportProgress.shared.reset()
        QuickPinStore.shared.reset()
        // The saved builds (0.7.3, B2). The *fitted* parts are cleared by the
        // key loop below — every `DeviceAxis` is in it — but the saved recipes
        // are their own store and would survive a wipe otherwise.
        CustomDeviceStore.shared.reset()
        ScreenStateStore.shared.clear()
        SearchStateStore.shared.clear()

        let defaults = UserDefaults.standard
        for key in DeviceAxis.allCases.map(\.storageKey) + [
            // Belt and braces after each store's own reset.
            Shelf.saved.storageKey,
            Shelf.wantToTry.storageKey,
            Shelf.tried.storageKey,
            BookmarkStore.ratingsKey,
            RevealCursor.storageKey,
            QuizProgress.storageKey,
            QuizProgress.completedKey,
            StampLayoutStore.storageKey,
            BookmarkStore.triedDaysKey,
            PassportProgress.storageKey,
            QuickPinStore.storageKey,
            StreakStore.streakKey,
            StreakStore.lastDayKey,
            StreakStore.bestKey,
            CustomDeviceStore.storageKey,
            // `LcdMode.storageKey` and `ChassisSkin.storageKey` are no longer
            // listed here: both are `DeviceAxis` entries now (0.7.3, B1) and
            // arrive through the eight keys prepended above. Listing them twice
            // was harmless and listing them once is checkable — a ninth part
            // cannot be forgotten here the way the six new ones would have been.
            TextScale.storageKey,
            UIScale.storageKey,
            UserProfile.displayNameKey,
            Haptics.storageKey,
            Sounds.storageKey,
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
#endif
