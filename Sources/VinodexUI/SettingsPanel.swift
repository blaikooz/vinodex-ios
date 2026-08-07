#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UIKit
import UserNotifications
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
    // `onWalkthrough` retired here in 0.7.6 (F1) — the tour moved into
    // SETTINGS > DEVICE, so `SettingsSectionPanel` takes the callback now. See
    // the note on the grid below for what that costs and why it is paid.

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(
        onClose: @escaping () -> Void,
        onSection: @escaping (SettingsSection) -> Void = { _ in },
        onMinigames: @escaping () -> Void = {}
    ) {
        self.onClose = onClose
        self.onSection = onSection
        self.onMinigames = onMinigames
    }

    /// **Five tiles since 0.7.6 (F1), in three rows: two, two, and one wide.**
    ///
    /// F1 moves the tutorial into SETTINGS > DEVICE, which takes a tile out of a
    /// grid that was a fixed three-by-two sized to fill the LCD. Five tiles in
    /// that grid is an orphan on the last row, so the last row is one tile
    /// instead — and the tile that gets it is SHOP, which is the right one for
    /// reasons beyond arithmetic: it is the storefront, it is the only tile on
    /// this grid that leads to something with a price, and C spends this batch
    /// making its contents larger and clearer. A full-width shelf at the bottom
    /// of the panel reads as a shop front rather than as a leftover.
    ///
    /// **What F1 costs, stated rather than hidden.** TUTORIAL was first on this
    /// grid deliberately: it is the tile that matters to exactly one person —
    /// someone who has just opened this thing — and that person must not have to
    /// hunt for it. It is now two taps away instead of one. Two things pay for
    /// that. It is *first* in the DEVICE section rather than last, so anyone who
    /// opens SETTINGS looking for it meets it immediately; and DEVICE is where
    /// the walkthrough actually belongs — 0.7.3a's own note calls that section
    /// "three things the device can tell you or do", and a guided tour of the
    /// device is a fourth.
    public var body: some View {
        // A fixed grid that fills the LCD (v0.5.6) — no scrolling: the panel is
        // sized by the screen, not by its content.
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // A wrench, not a gamepad — the hub holds more instruments
                // than games, and the tile should promise what it opens.
                featureTile(
                    title: "TOOLS",
                    symbol: "wrench.and.screwdriver.fill",
                    art: "tools",
                    action: onMinigames
                )
                featureTile(
                    title: SettingsSection.customization.rawValue,
                    symbol: SettingsSection.customization.symbol,
                    art: SettingsSection.customization.artStem
                ) {
                    onSection(.customization)
                }
            }
            // DEV is deliberately absent from the grid — it lives as a
            // button inside SETTINGS, where developer plumbing belongs.
            HStack(spacing: 10) {
                featureTile(
                    title: SettingsSection.settings.rawValue,
                    symbol: SettingsSection.settings.symbol,
                    art: SettingsSection.settings.artStem
                ) {
                    onSection(.settings)
                }
                featureTile(
                    title: SettingsSection.data.rawValue,
                    symbol: SettingsSection.data.symbol,
                    art: SettingsSection.data.artStem
                ) {
                    onSection(.data)
                }
            }
            // The shop, the width of the panel. `displayName`, not `rawValue`:
            // this tile is the one place on the grid where the two differ, and
            // 0.7.5's B2 renamed the label rather than the stored word.
            featureTile(
                title: SettingsSection.access.displayName,
                symbol: SettingsSection.access.symbol,
                art: SettingsSection.access.artStem
            ) {
                onSection(.access)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(lcd.panelGround)
    }

    /// Per-tile colours, tuned separately for the pale and dark grounds
    /// (v0.5.6, reversing 0.5.3's uniform mode ramp): each tile is unique
    /// again — the colour is half the identity — and light mode runs the
    /// deeper cuts because the bright faces washed out on the pale page.
    private func tileColors(_ title: String) -> (face: String, shadow: String, ink: Color) {
        // Keyed on the label the tile shows. The TUTORIAL entry went with the
        // tile in 0.7.6 (F1); the green it used is not reassigned, because the
        // remaining five each already have one and a spare colour is not a
        // reason to repaint a grid people know.
        if lcd.isLight {
            return switch title {
            case "TOOLS": ("#B45309", "#7A3606", .white)
            case "CUSTOMIZE": ("#B91C1C", "#7A1010", .white)
            case "SETTINGS": ("#C2410C", "#7C2D12", .white)
            case "DATA": ("#1D6FA8", "#11486E", .white)
            default: ("#7E22CE", "#4C1D95", .white)   // SHOP
            }
        }
        return switch title {
        // White ink like every other tile (0.6.4, E1) — the dark-amber ink
        // made TOOLS the odd one out on the grid. The face deepens a step so
        // white still clears it, rather than sitting white-on-yellow.
        case "TOOLS": ("#EAB308", "#A16207", .white)
        case "CUSTOMIZE": ("#EF4444", "#991B1B", .white)
        case "SETTINGS": ("#F97316", "#9A3412", .white)
        case "DATA": ("#2AB5FF", "#136A99", .white)
        default: ("#A855F7", "#6B21A8", .white)       // SHOP
        }
    }

    /// Styled like the main menu's tiles — filled face, 6pt bottom extrusion,
    /// top-left sheen. Stretches to fill its grid cell rather than squaring
    /// off (v0.5.6): the grid fits the LCD, so the tiles absorb the height.
    private func featureTile(
        title: String,
        symbol: String,
        art: String? = nil,
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
                // Squared at 44 (0.8.1, J3) — the same box the tools shelf
                // uses, so the two grids of tiles stay one instrument.
                DexChromeGlyph(art ?? symbol, symbol: symbol, size: 44, tint: ink)
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
    /// The guided tour (0.7.6, F1). A fourth door in the DEVICE section, and a
    /// route push like the two above so Back returns to SETTINGS rather than
    /// dropping the user out of the panel entirely.
    let onWalkthrough: () -> Void
    /// Starts the attract loop. Not a route — demo mode drives the *whole* route
    /// stack, so it is the app's business rather than a screen to push.
    let onDemoMode: () -> Void
    /// CUSTOMIZE's door to the builder (0.7.3, A1). A route push like the two
    /// above, so the chassis Back button returns here rather than dropping out
    /// of settings.
    let onDeviceWorkshop: () -> Void
    // `onExpansionPacks` retired in 0.7.5 (B1) along with `packsDoor` and
    // `SettingsSection.packs`. The shelf is not pushed from anywhere any more —
    // it is part of the shop's own body.

    /// Which cartridge's splash is open, by `Entitlement.id`, or nil for the
    /// shelf (0.8.4, C1).
    ///
    /// **An input, not `@State`.** Through 0.8.3 this was a `@State` property
    /// and the splash was an overlay raised over the shop — which meant the
    /// user could be looking at a pack page while the navigation stack said
    /// they were on the shop, and one Back popped both at once, landing on
    /// SYSTEM. See `DexRoute.pack(id:)` for the full argument. Making it a
    /// parameter is the entire mechanism: the route owns the value, so the
    /// stack and the screen agree, and Back pops one frame like everywhere else.
    let openPack: String?
    /// Opening one, which the shelf's tiles call. A route push.
    let onOpenPack: (String) -> Void
    /// CLOSE on the splash. A pop rather than a state clear, so the button and
    /// the chassis Back do the same thing — which they visibly did not before.
    let onClosePack: () -> Void

    @State private var access = AccessStore.shared
    /// Read only to name the saved build the device is currently wearing — see
    /// `deviceWorkshop`. `@State` on the shared store rather than a fresh one, so
    /// saving a build in the workshop is reflected here on the way back out.
    @State private var customDevices = CustomDeviceStore.shared
    /// The tried shelf, for the cartridge shelf's collection scores (0.7.3c).
    /// Observed rather than read once, so marking a tasting elsewhere and coming
    /// back finds the bars moved.
    @State private var bookmarks = BookmarkStore.shared
    /// Which cartridge's splash is open — now `openPack`, straight through
    /// (0.8.4, C1).
    ///
    /// Kept as a name rather than folded into the four call sites, because the
    /// argument the old `@State` carried is still the right one and is now
    /// answered by the route instead of by this view: which cartridge you last
    /// opened is not a place the way a scroll anchor is, and it is deliberately
    /// *not* in `ScreenStateStore` — leaving and coming back finds the shelf,
    /// not the splash you closed by leaving. A route frame has exactly that
    /// lifetime already.
    private var openShopItem: String? { openPack }
    /// Set when a gated cosmetic is tapped; drives the same upgrade prompt a
    /// locked entry raises, so a paywalled *setting* behaves like a paywalled
    /// page rather than being a dead control.
    @State private var lockedBundle: Entitlement?
    /// A preset tapped in CUSTOMIZE that is waiting on the user to confirm it
    /// may clear fitted parts (0.7.8, A2). `nil` on any device that has not
    /// been through the workshop, because `fit(_:)` only sets it when there is
    /// something to say.
    @State private var pendingPreset: PendingPreset?
    /// CLEAR SAVED DATA asks first — it is the one control here that cannot be
    /// undone by tapping it again.
    @State private var confirmingWipe = false
    /// Set when TUTORIAL is tapped (0.7.6, F1). The tour is a few minutes of
    /// someone's time, so it asks before it takes them — and asking is also what
    /// makes it findable without being imposed: the row says what it is, the
    /// prompt says what it will do, and NOT NOW costs one tap.
    @State private var offeringTour = false
    @AppStorage(Haptics.storageKey) private var hapticsOn = true
    /// Off by default from v0.5.1 — sounds are opt-in. See `Sounds`.
    @AppStorage(Sounds.storageKey) private var soundsOn = false
    /// Scroll position outlives the view — see `ScreenStateStore`. ACCESS and
    /// DATA are both taller than the LCD, so opening the upgrade prompt from a
    /// bundle row near the bottom used to bounce the panel back to the top.
    @State private var screens = ScreenStateStore.shared
    /// Reminders (0.7.8, D1). Observed rather than read from a stored bool —
    /// see `dailyReminderRow`.
    @State private var notifications = NotificationScheduler.shared
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
        openPack: String? = nil,
        onDev: @escaping () -> Void = {},
        onFirmwareHistory: @escaping () -> Void = {},
        onCheatConsole: @escaping () -> Void = {},
        onWalkthrough: @escaping () -> Void = {},
        onDemoMode: @escaping () -> Void = {},
        onDeviceWorkshop: @escaping () -> Void = {},
        onOpenPack: @escaping (String) -> Void = { _ in },
        onClosePack: @escaping () -> Void = {}
    ) {
        self.section = section
        self.openPack = openPack
        self.onDev = onDev
        self.onFirmwareHistory = onFirmwareHistory
        self.onCheatConsole = onCheatConsole
        self.onWalkthrough = onWalkthrough
        self.onDemoMode = onDemoMode
        self.onDeviceWorkshop = onDeviceWorkshop
        self.onOpenPack = onOpenPack
        self.onClosePack = onClosePack
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
                        let bundle = lockedBundle
                        self.lockedBundle = nil
                        // **Through the purchase provider since 0.7.5 (B2).**
                        // It was `access.grant(bundle)`; it is now the same
                        // grant reached through `AccessStore.purchase`, which is
                        // where a payment step would go. `LocalPurchaseProvider`
                        // succeeds immediately, so this is today's behaviour
                        // with a seam in it — the `await` resumes in the same
                        // run loop pass on this build.
                        Task {
                            let outcome = await access.purchase(bundle)
                            // **Continue where they were going** (0.7.3, C1).
                            // The cosmetic bundles have nowhere to continue
                            // *to* — the picker they were tapped from is
                            // already on screen and has just unlocked in
                            // place — but the workshop is a door, and stopping
                            // at "unlocked!" beside a button they now have to
                            // find and press again is the same half-finished
                            // unlock `RootView` fixed for locked entries.
                            //
                            // Gated on the outcome now: a cancelled or failed
                            // purchase must not open the door it did not buy.
                            if outcome.entitlement == .workshop { onDeviceWorkshop() }
                        }
                    },
                    onCancel: { self.lockedBundle = nil }
                )
            } else if let open = openShopItem,
                      let item = allShopItems.first(where: { $0.id == open }) {
                shopSplash(item)
            } else if offeringTour {
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
            } else if let pending = pendingPreset {
                DexAlert(
                    title: "FIT \(pending.label)?",
                    message: pending.message(fitted: customDevices.matching(DeviceBuild.active())),
                    confirmLabel: "FIT",
                    cancelLabel: "KEEP MINE",
                    onConfirm: {
                        pendingPreset = nil
                        pending.commit()
                    },
                    onCancel: { pendingPreset = nil }
                )
            }
        }
        .animation(DexMotion.overlay, value: lockedBundle)
        .animation(DexMotion.overlay, value: openShopItem)
        .animation(DexMotion.overlay, value: offeringTour)
        .animation(DexMotion.overlay, value: confirmingWipe)
        .animation(DexMotion.overlay, value: pendingPreset)
    }

    /// Apply a preset, asking first only when there is something to ask about
    /// (0.7.8, A2).
    ///
    /// **The prompt is the exception, not the rule.** A device that has never
    /// been through the workshop has no fitted parts, `cleared` is empty, and
    /// the tap lands exactly as it always did — a picker that raised a modal
    /// every time you tried a shell on would be a worse screen than the one A2
    /// is fixing. The prompt exists for the one user this changes anything for:
    /// somebody who spent a while choosing ten parts and would otherwise lose
    /// seven of them to a stray tap with no undo.
    private func fit(_ preset: PendingPreset) {
        if preset.cleared.isEmpty {
            preset.commit()
        } else {
            pendingPreset = preset
        }
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
                    case .access: shop
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

    // MARK: The shop (0.7.5, B1/B2/B3)

    /// The storefront: upgrade cartridges, the three pack shelves, and the
    /// developer switch at the bottom.
    ///
    /// **This replaces the ACCESS harness rather than dressing it up.** What was
    /// here was a column of `settingRow`s with `DexToggle`s — a developer's test
    /// rig for reaching the unowned state of every gate in one tap, under a
    /// heading that 0.7.3c had already renamed from BUNDLES to EXPANSION PACKS.
    /// B1 gives that heading's *name* to the real cartridge shelves, B2 makes
    /// this the route for paid content, and B3 says the whole surface is drawn
    /// in the cartridge style. A toggle switch is not a storefront, so the
    /// toggles are gone and every purchasable thing is a cartridge that opens to
    /// a splash (B4).
    ///
    /// **The test rig is not lost, it moved into the splash.** The unowned state
    /// of any gate is still one tap away — tap the cartridge, and its splash
    /// carries the same UNLOCK the upgrade prompt does; REVOKE ALL PURCHASES at
    /// the bottom still puts every gate back. What is lost is the ability to
    /// revoke *one* entitlement without revoking the rest, which was a
    /// convenience of the toggle shape rather than a thing the harness needed:
    /// FREE TIER plus REVOKE ALL still reaches every combination, one more tap
    /// at a time.
    ///
    /// **Ordering.** What is for sale first, the developer switch last. It reads
    /// as a shop with a service panel at the bottom rather than as a test rig
    /// with some products in it.
    @ViewBuilder
    private var shop: some View {
        settingsSection("UPGRADES") {
            LazyVGrid(columns: pickerColumns, spacing: 8) {
                ForEach(shopUpgrades) { item in
                    shopTile(item)
                }
            }
        }

        packShelf

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

                Text("Off means everything is open regardless of what you own — turn it on to see the locked experience.")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)

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

                // **No RESTORE PURCHASES button, deliberately.**
                // `LocalPurchaseProvider.restore()` returns nothing and says why:
                // a local restore hands back the set it was given. A button that
                // reports success and changes nothing is the exact fault
                // `CheatCodes`' own note forbids, so the control arrives with the
                // adapter that can honour it — see `PurchaseProviding`.
            }
        }
    }

    /// One thing the shop sells, whether or not it is a pack.
    ///
    /// A small value type rather than two parallel tile builders: B3 asks for one
    /// presentation across the whole shop, and the way to get one presentation is
    /// one input. `pack` is the only thing that differs — it is what gives a
    /// splash a collection score instead of a plain entry count.
    private struct ShopItem: Identifiable {
        let entitlement: Entitlement
        let symbol: String
        let title: String
        let blurb: String
        /// Non-nil for the twelve cartridges; nil for the plain upgrades.
        let pack: ExpansionPack?

        var id: String { entitlement.id }

        init(entitlement: Entitlement, symbol: String, title: String, blurb: String) {
            self.entitlement = entitlement
            self.symbol = symbol
            self.title = title
            self.blurb = blurb
            self.pack = nil
        }

        init(pack: ExpansionPack) {
            self.entitlement = pack.entitlement
            self.symbol = pack.symbol
            self.title = pack.title
            self.blurb = pack.blurb
            self.pack = pack
        }
    }

    /// Everything on sale that is not a cartridge.
    ///
    /// **Five rows since 0.8.3 (D), down from nine.** D removes the flavour
    /// wheel and the three country packs — which were ITALY, FRANCE and SPAIN,
    /// not because anybody chose those three but because a `topCountries`
    /// helper here counted region entries per origin and took the largest
    /// three. That helper is gone with the rows; nothing else called it.
    ///
    /// The removal is a *retirement* rather than a deletion, and the whole of
    /// why is on `Entitlement.isRetired`: the ids are persisted, so the cases
    /// stay, decode, and keep covering what they covered. Filtering the two
    /// arms out here rather than leaving them to `isPurchasable` is deliberate
    /// belt and braces — the filter below would already drop them, and a reader
    /// asking "what does this shop sell" should be able to read the answer off
    /// one line.
    ///
    /// **`granted.contains` still has work to do.** It is why an owned row
    /// survives the purchasable filter — but note it can no longer resurrect a
    /// retired bundle, because a retired bundle is not in the list to begin
    /// with. That is the phantom D asks about: somebody holding
    /// `country:France` sees five rows, not six, and no FRANCE PACK on a shelf
    /// that no longer has one. What they keep is the access, which
    /// `Entitlement.covers` never stopped granting.
    ///
    /// **The twelve packs are deliberately absent**: they are the three shelves
    /// underneath, which is the whole of B1. The atlas three used to be listed
    /// here as harness rows because only they move the browsable count, and that
    /// reason went with the harness.
    ///
    /// `.easterEgg` stays out, and now says so in code as well as in a comment —
    /// `LocalPurchaseProvider.canPurchase` refuses it, so it could not be sold
    /// even if it were listed.
    private var shopUpgrades: [ShopItem] {
        let entitlements: [Entitlement] = [
            .pro,
            // `.lineage` joins the two premium *features* (0.7.5, E1). Beside
            // `.workshop` rather than up with `.pro`, because the order here is
            // the shelf order and these two are the same kind of thing: a screen
            // you buy, not a slice of the catalog.
            .skins, .lightMode, .workshop, .lineage,
        ]
        return entitlements
            .filter { access.granted.contains($0) || access.isPurchasable($0) }
            .map {
                ShopItem(
                    entitlement: $0,
                    symbol: bundleSymbol($0),
                    title: $0.title,
                    blurb: $0.blurb
                )
            }
    }

    private func bundleSymbol(_ entitlement: Entitlement) -> String {
        switch entitlement {
        case .pro: "crown.fill"
        // Retired in 0.8.3 (D) and unreachable from `shopUpgrades` above. Kept
        // for the reason `.expansion`'s arm below is: `Entitlement` is
        // exhaustive here, and the honest glyph is a better answer than a
        // `default:` that would swallow the next case somebody adds.
        case .flavors: "leaf.fill"
        case .country: "flag.fill"
        case .skins: "paintpalette.fill"
        case .lightMode: "sun.max.fill"
        // `.expansion` does not reach here — a pack's `ShopItem` takes the
        // pack's own glyph, which is what distinguishes twelve cartridges from
        // one another. Kept because `Entitlement` is exhaustive and a shipping
        // box is the right answer if one ever arrives by another route.
        case .expansion: "shippingbox.fill"
        case .workshop: "wrench.and.screwdriver.fill"
        // The same branch the LINEAGE button and the route's marquee wear
        // (K2, rule 1 — a page's glyph is the glyph on the control that opens it).
        case .lineage: "arrow.triangle.branch"
        // Never reachable: eggs are found rather than bought, and
        // `LocalPurchaseProvider.canPurchase` refuses them.
        case .easterEgg: "key.fill"
        }
    }

    /// How many entries the *current* combination of tier and bundles opens.
    private var browsableCount: Int {
        db.entries.filter { !access.isLocked($0, in: db) }.count
    }

    /// DAILY REMINDER (0.7.8, D1).
    ///
    /// In DEVICE rather than a new section: the device is where the things that
    /// change how the hardware behaves live — the tutorial, the firmware, the
    /// cheat console — and a reminder the device sends is one of those. A
    /// NOTIFICATIONS section holding exactly one switch would be a heading for
    /// its own sake.
    ///
    /// **The switch renders `isOn`, not the stored preference.** Permission can
    /// be denied at the prompt or withdrawn later in iOS Settings without this
    /// app running, and a switch that shows ON while the system drops every
    /// request is the failure this row is arranged around. `refresh()` re-reads
    /// the real status whenever the panel appears, and the denied case says so
    /// and offers the only thing that can actually fix it.
    private var dailyReminderRow: some View {
        Button {
            Haptics.screenTap()
            if notifications.isOn {
                notifications.disable()
            } else if notifications.status == .denied {
                // The system prompt is one-shot; asking again returns the old
                // answer silently. iOS Settings is the only way back.
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } else {
                Task {
                    await notifications.enable(
                        todayDone: StreakStore.shared.isTodayDone(),
                        streak: StreakStore.shared.current
                    )
                }
            }
        } label: {
            settingRow(
                symbol: notifications.isOn ? "bell.fill" : "bell.slash.fill",
                tint: notifications.isOn ? Dex.green : lcd.subtext,
                title: "DAILY REMINDER",
                detail: reminderDetail
            ) {
                if notifications.status == .denied {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(lcd.subtext)
                } else {
                    DexToggle(isOn: notifications.isOn, tint: Dex.green) {
                        Haptics.screenTap()
                        if notifications.isOn {
                            notifications.disable()
                        } else {
                            Task {
                                await notifications.enable(
                                    todayDone: StreakStore.shared.isTodayDone(),
                                    streak: StreakStore.shared.current
                                )
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .task { await notifications.refresh() }
    }

    private var reminderDetail: String {
        if notifications.status == .denied {
            return "Notifications are switched off for Vinodex in iOS Settings. Tap to open them."
        }
        if notifications.isOn {
            return "A nudge when today's exam is live, and again if a streak is about to break."
        }
        return "Get told when today's challenge is live, and before your streak runs out."
    }

    /// The shared shape of a settings row: glyph, title, one line of
    /// explanation, and a control on the right.
    private func settingRow<C: View>(
        symbol: String,
        /// The drawn face for this row, if one exists. Nil keeps the SF Symbol
        /// — half these rows have a button face and half do not (0.8.1, J3),
        /// and a row must not have to wait for art to render.
        art: String? = nil,
        tint: Color,
        title: String,
        detail: String,
        @ViewBuilder control: () -> C
    ) -> some View {
        HStack(spacing: 12) {
            // The 30pt gutter was already here and is already the answer to
            // J3's problem — a fixed width every row's glyph is fitted into.
            // `DexChromeGlyph` squares it so the drawn faces cannot make the
            // rows different heights either.
            DexChromeGlyph(art ?? symbol, symbol: symbol, size: 22, weight: .bold, tint: tint)
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

    // `packsDoor` retired in 0.7.5 (B1). It was a `settingsSection("EXPANSION
    // PACKS")` here holding one OPEN row, and it existed because the settings
    // grid is a fixed three-by-two that fills the LCD, so the shelf could not
    // have a tile of its own without orphaning one on a fourth row. B1 moves the
    // shelf into the shop, which had a tile already — so the door is not
    // relocated, it is deleted, and CUSTOMIZE goes back to being three pickers
    // and one workshop door with nothing else to say about its layout: it is a
    // scrolling column of sections, so removing one shortens it and moves
    // nothing.

    // MARK: The cartridge shelf (0.7.3c, A2/B/C/D/E1; in the shop since 0.7.5, B1)

    /// Three shelves of cartridges, one per `ExpansionPack.Kind`.
    ///
    /// **Built out of the skin picker's own parts**, which is what A2 asks for:
    /// `settingsSection` around each shelf, `pickerColumns` for the grid,
    /// `DexPickerTile` for the tile, and the picker's interaction model
    /// unchanged — tap to select, the selected tile takes `lcd.accent`, a gated
    /// tile dims and raises the ordinary `UpgradePrompt` through `lockedBundle`.
    ///
    /// **The detail strip became a splash in 0.7.5 (B4).** 0.7.3c expanded a
    /// blurb and a progress bar in place under the grid, which is as much as a
    /// strip between two rows of tiles can carry. B4 asks for a screen, so
    /// tapping a cartridge now raises `shopSplash` over the whole panel — see
    /// there for why it is an overlay rather than a route.
    @ViewBuilder
    private var packShelf: some View {
        ForEach(ExpansionPack.Kind.allCases) { kind in
            settingsSection("\(kind.rawValue) PACKS") {
                LazyVGrid(columns: pickerColumns, spacing: 8) {
                    ForEach(ExpansionPacks.packs(of: kind), id: \.id) { pack in
                        shopTile(ShopItem(pack: pack))
                    }
                }
            }
        }
    }

    /// Every cartridge in the shop, for resolving `openShopItem` back to what it
    /// names. Order matters only in that it is stable.
    private var allShopItems: [ShopItem] {
        shopUpgrades + ExpansionPacks.all.map { ShopItem(pack: $0) }
    }

    /// Everything on the tried shelf, as ids.
    ///
    /// Computed per pass rather than cached: `BookmarkStore` is `@Observable` and
    /// held in `@State` above, so a tasting marked while this panel is open
    /// invalidates the body and the progress bars move — which is the whole point
    /// of a collection score being on screen.
    private var triedIDs: Set<String> {
        Set(bookmarks.ids(on: .tried))
    }

    /// Whether the user owns a shop item. Packs answer through `impliedBy`.
    private func owns(_ item: ShopItem) -> Bool {
        if let pack = item.pack { return access.owns(pack) }
        return access.granted.contains(item.entitlement)
    }

    /// One cartridge on any shelf in the shop (0.7.5, B3).
    ///
    /// **`DexPickerTile` and `CartridgeShape`, unchanged.** 0.7.3c consolidated
    /// four bespoke grids into three plus this shared tile and noted that
    /// finishing the job was a sitting of its own. B3 is that sitting for the
    /// shop: what was a column of toggle rows is this, and the shop now has one
    /// tile shape for everything it sells rather than a fourth grid of its own.
    /// `skinGrid` and `modeGrid` are still hand-written — see the note on
    /// `skinGrid` for what remains.
    ///
    /// Tapping always opens the splash, owned or not. An owned tile that did
    /// nothing would be a dead control, and the splash is where the unowned one
    /// is bought — so there is one gesture and one destination whatever state a
    /// cartridge is in.
    private func shopTile(_ item: ShopItem) -> some View {
        let owned = owns(item)
        let chosen = openShopItem == item.id

        return DexPickerTile(
            label: item.title,
            isChosen: chosen,
            // A padlock replaces the item's own glyph rather than joining it,
            // exactly as it does on a workshop part chip.
            symbol: owned ? nil : "lock.fill",
            lcd: lcd,
            // 46 → 58 (0.8.3, E2). "A bit larger", explicitly not C3's
            // treatment: the shelf is a three-column grid whose cell width the
            // label also has to live in, so the cartridge grows a register and
            // the grid does not move. Removing the outline is what paid for it —
            // the swatch no longer has a border to clear.
            swatchSize: 58,
            labelSize: 9,
            labelMinHeight: 24,
            // No border (0.8.3, E1) — see `DexPickerTile.outline`. The
            // cartridges draw their own.
            outline: CartridgeShape?.none,
            // A push since 0.8.4 (C1). It used to set local state and raise an
            // overlay; the id it passes is unchanged, and so is everything the
            // splash does with it.
            action: { onOpenPack(item.id) },
            swatch: {
                PackCartridge(
                    symbol: item.symbol,
                    ink: chosen ? lcd.onAccent : lcd.subtext,
                    ground: chosen ? lcd.accent : lcd.surface,
                    // On a pack this is a finished collection; on an upgrade it
                    // is simply ownership. Both mean "you are done here", which
                    // is what the tick has always said.
                    isComplete: item.pack.map {
                        $0.progress(tried: triedIDs, in: db)?.isComplete ?? owned
                    } ?? owned,
                    // The drawn cartridge on the shelf (0.8.2). Nil for the
                    // flavour wheel and the country packs, which keep A2's
                    // drawing — see `CartridgeArt`.
                    art: CartridgeArt.stem(for: item.entitlement)
                )
            }
        )
        .opacity(owned ? 1 : 0.45)
    }

    /// The splash a cartridge opens to (0.7.5, B4).
    ///
    /// **An overlay over the panel rather than a route.** A route would mean a
    /// `DexRoute` case per pack or one carrying an id, plus `ChromeTests`
    /// coverage, a marquee title and a glyph — for a card that is dismissed by
    /// looking away from it. The overlay sits exactly where `UpgradePrompt` and
    /// the wipe alert already do, inside the LCD, and the chassis Back button
    /// still means "leave the shop", which is the behaviour a splash should not
    /// steal.
    ///
    /// **Cartridge mockups, plural.** Three plates fanned behind one another,
    /// the hero on top carrying the glyph — a product shot rather than a bigger
    /// version of the tile that was just tapped. They are `CartridgeShape` all
    /// the way down, so the splash cannot drift from the shelf.
    ///
    /// The contents line has three shapes because the three kinds of thing
    /// answer different questions: an atlas pack has a collection score over a
    /// bar, a cosmetic pack has a member count, and a plain upgrade has however
    /// many entries it opens — or nothing at all, if it opens none, which is the
    /// honest answer for the three cosmetic entitlements.
    ///
    /// **Larger, and with a preview of what is inside (0.7.6, C2/C3/C4).** B4
    /// built the shape; C asks it to actually sell something. Three changes, and
    /// they are all the same change: the type steps up (title 15 → 19, blurb 18 →
    /// 19, buttons 11 → 13 with more height under them), the mockups grow with
    /// it, and a **preview strip** sits under the contents line — the shells and
    /// screens a cosmetic pack contains, drawn as the picker tiles they will
    /// become, or a handful of the entries an upgrade opens. See `splashPreview`.
    ///
    /// **It stays an overlay, and C does not push it past what an overlay should
    /// carry.** B4's note argued a route would mean a `DexRoute` case per pack or
    /// one carrying an id, `ChromeTests` coverage, a marquee title and a glyph —
    /// for a card dismissed by looking away from it. Everything C adds is content
    /// *inside* the same scrolling column: no new navigation, no state that has
    /// to survive a back-stack, nothing that wants a title of its own. The line
    /// this would cross is a splash that could push somewhere — tapping a shell
    /// in the preview strip to try it on, say — and it deliberately does not:
    /// the strip is a picture of what is in the box.
    @ViewBuilder
    private func shopSplash(_ item: ShopItem) -> some View {
        let owned = owns(item)

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    cartridgeMockups(item)

                    // **The title is on the cartridge now (0.8.3, C4)** — this
                    // row is what is left for a product with no art, whose
                    // fallback cartridge has a glyph plate where the well
                    // would be and so cannot carry a name. Nothing on the
                    // shelves takes this branch today (`CartridgeArtTests`
                    // gates all seventeen), and a splash with no name at all
                    // is not a state worth being one edit away from.
                    if CartridgeArt.stem(for: item.entitlement) == nil {
                        Text(item.title)
                            .font(DexFont.retro(19))
                            .tracking(1)
                            .foregroundStyle(lcd.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(item.blurb)
                        .font(DexFont.mono(19))
                        .foregroundStyle(lcd.subtext)
                        .fixedSize(horizontal: false, vertical: true)

                    splashContents(item)
                    splashPreview(item)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.select()
                    onClosePack()
                } label: {
                    Text("CLOSE")
                        .font(DexFont.retro(13))
                        .tracking(1)
                        .foregroundStyle(lcd.subtext)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(lcd.surfaceEdge, lineWidth: 2)
                        )
                }
                .buttonStyle(DexPressStyle(scale: 0.98))

                if owned {
                    // Not a button. There is nothing left to do to an owned
                    // cartridge, and a disabled control saying OWNED would be a
                    // thing to try to press.
                    Text("OWNED")
                        .font(DexFont.retro(13))
                        .tracking(1)
                        .foregroundStyle(Dex.green)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Dex.green.opacity(0.55), lineWidth: 2)
                        )
                } else {
                    Button {
                        Haptics.select()
                        // Straight to the ordinary upgrade prompt, which is
                        // where the purchase happens for a locked entry and a
                        // locked skin alike — see `body`'s overlay. The shop
                        // deliberately does not grow a second confirm step.
                        //
                        // **No longer closes the splash first (0.8.4, C1).**
                        // It used to, because both were `@State` on this view
                        // and clearing one to set the other cost nothing. Now
                        // that closing is a *pop*, doing it here would tear down
                        // the view that is about to set `lockedBundle` and the
                        // prompt would never appear. Staying is also the better
                        // behaviour: the prompt arrives over the product it is
                        // asking about, and `body` already orders `lockedBundle`
                        // ahead of the splash in the overlay chain.
                        lockedBundle = item.entitlement
                    } label: {
                        Text("UNLOCK")
                            .font(DexFont.retro(13))
                            .tracking(1)
                            .foregroundStyle(lcd.onAccent)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.accent))
                    }
                    .buttonStyle(DexPressStyle(scale: 0.98))
                }
            }
            .padding(18)
            .background(lcd.panelGround)
        }
        .background(lcd.panelGround)
        // Swallows anything aimed at the panel underneath, which is still
        // mounted and still scrollable without this.
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    // MARK: Splash previews (0.7.6, C2/C4)

    /// What is actually in the box.
    ///
    /// **Three shapes, matching the three kinds of thing the shop sells**, and in
    /// each case the preview is drawn in the vocabulary the contents will arrive
    /// in — which is the whole of C2's "mockups": a shell pack previews shells as
    /// the swatches the picker will show, a screen pack previews screens as the
    /// mode cards, and an upgrade previews entries as the tiles the encyclopedia
    /// draws. A preview in a vocabulary the app does not otherwise use would be an
    /// illustration of the product rather than a look at it.
    ///
    /// Nothing here is a control. See `shopSplash` for where the line is.
    @ViewBuilder
    private func splashPreview(_ item: ShopItem) -> some View {
        if let pack = item.pack {
            if let section = ChassisSkinSection.allCases.first(where: { $0.pack.id == pack.id }) {
                previewStrip("SHELLS IN THIS PACK") {
                    ForEach(section.skins) { skin in
                        shellSwatch(skin)
                    }
                }
            } else if let section = LcdModeSection.allCases.first(where: { $0.pack.id == pack.id }) {
                previewStrip("SCREENS IN THIS PACK") {
                    ForEach(section.modes) { mode in
                        screenSwatch(mode)
                    }
                }
            } else {
                // An atlas pack: real entries, exactly like an upgrade. Its
                // collection bar is already above this, so the strip is the
                // "what am I buying" half rather than the "how far am I" half.
                entryPreview(pack.entries(in: db))
            }
        } else {
            entryPreview(db.entries.filter { item.entitlement.covers($0, in: db) })
        }
    }

    /// A sample of the entries something opens (C4).
    ///
    /// **Six, and taken off the front of the list rather than at random.** A
    /// random six would change under the user every time the body re-ran —
    /// `BookmarkStore` is observed on this panel, so that is often — and a splash
    /// whose contents shuffle while you read it reads as a bug. Six is two rows
    /// of three at the tile size below, which is a sample rather than a catalog:
    /// the count beside the heading is what says how many there really are.
    @ViewBuilder
    private func entryPreview(_ entries: [WineEntry]) -> some View {
        let sample = Array(entries.prefix(6))
        if !sample.isEmpty {
            previewStrip("A LOOK INSIDE") {
                ForEach(sample) { entry in
                    VStack(spacing: 5) {
                        EntryIconWell(entry: entry, size: 40)
                        Text(entry.name)
                            .font(DexFont.retro(8))
                            .tracking(0.5)
                            .foregroundStyle(lcd.subtext)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .frame(height: 22, alignment: .top)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// One shell, as the picker draws it (0.8.1, A2).
    ///
    /// It used to be a 40pt circle of `skin.body` — the right colour and the
    /// wrong shape, which for a shop selling the *look* of a device is most of
    /// the product missing. Now it is `ChassisMockup`, the same drawing the
    /// CUSTOMIZE picker shows, so "a preview and the thing previewed are the
    /// same picture" is true of the outline as well as the colour.
    private func shellSwatch(_ skin: ChassisSkin) -> some View {
        VStack(spacing: 5) {
            ChassisMockup(skin: skin, height: 40)
                .frame(width: 62)
            Text(skin.displayName)
                .font(DexFont.retro(8))
                .tracking(0.5)
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .frame(height: 22, alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }

    /// One screen mode, drawn as a screen (0.8.2, coordinator 4 — amending
    /// 0.8.1's A2).
    ///
    /// A2's note read: "A display pack sells a screen, and a bare disc of
    /// `mode.screen` shows the colour without saying it is a screen.
    /// `ChassisMockup` lights its panel strip with the mode instead, which puts
    /// the swatch in the device it belongs to and makes the two shelves in this
    /// shop read as one kind of product."
    ///
    /// The first half of that was right and the conclusion was not. Making the
    /// two shelves read as one kind of product is the *problem*: a device pack
    /// and a display pack are not one kind of product, and drawing both as the
    /// same chassis meant the three display tiles differed only in the tint of
    /// a 24×3pt capsule inside a device that was otherwise identical on all
    /// three. The shell varied nothing and dominated the tile.
    ///
    /// `ScreenMockup` draws the panel itself — ground, ink and accent, all
    /// three of the decisions a mode actually makes. `shellSwatch` above keeps
    /// `ChassisMockup` untouched, because a device pack does sell the device.
    ///
    /// **The full card since 0.8.3 (F)**: `ScreenMockup` *is* the CUSTOMIZE
    /// picker's card now, glyph and monochrome pass included, so this is the
    /// same drawing at 40pt that the picker shows at 50. What it was missing
    /// mattered — without the monochrome pass, AMBER and VINTAGE previewed in
    /// the green they are derived from.
    private func screenSwatch(_ mode: LcdMode) -> some View {
        VStack(spacing: 5) {
            ScreenMockup(mode: mode, height: 40)
                .frame(width: 62)
            Text(mode.displayName)
                .font(DexFont.retro(8))
                .tracking(0.5)
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .frame(height: 22, alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }

    /// The heading and grid every preview shares.
    ///
    /// A `LazyVGrid` on `pickerColumns` rather than a horizontal scroller: the
    /// splash already scrolls vertically, and a second scroll axis inside it is
    /// the one gesture arrangement this app has repeatedly had to unpick.
    private func previewStrip<C: View>(
        _ heading: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heading)
                .font(DexFont.retro(11))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
            LazyVGrid(columns: pickerColumns, spacing: 10) {
                content()
            }
        }
        .padding(.top, 4)
    }

    /// The cartridge at the top of a splash — **the page's subject since 0.8.3
    /// (C1/C2/C3/C4)**.
    ///
    /// What C replaces: a fanned trio at 168pt, the hero taking half the width
    /// and offset down-left, with two `CartridgeShape` plates stepped up-right
    /// behind it. The plates were introduced as "the rest of the box, not three
    /// separate products", and on a shelf where every product is now a drawn
    /// cartridge they read as what they geometrically are — two blank file cards
    /// behind the pack (C1). They are gone, the hero is centred (C2), and it
    /// takes the width the fan was reserving for the step (C3).
    ///
    /// **C4 is what set the size.** The name moves into the sprite's own label
    /// well, so the hero has to be large enough for thirteen characters to be
    /// legible in a recess that is 11% of its height — see
    /// `PackCartridge.labelWell(for:in:)`. 260 is where CHASSIS SKINS and GRAPE
    /// LINEAGE clear it. The strip is still bounded by `min(width, height)`, so
    /// a narrow LCD shrinks the cartridge rather than clipping it, and the
    /// splash still scrolls.
    private func cartridgeMockups(_ item: ShopItem) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            PackCartridge(
                symbol: item.symbol,
                ink: lcd.accent,
                ground: lcd.panelGround,
                isComplete: false,
                // **The same file, larger** (0.8.2, coordinator 5). The
                // cartridges ship at source resolution precisely so the
                // splash's hero can be this size without the shelf's tile size
                // deciding it — see `import-cartridge-art.py`.
                art: CartridgeArt.stem(for: item.entitlement),
                label: item.title
            )
            .frame(width: side, height: side)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func splashContents(_ item: ShopItem) -> some View {
        if let pack = item.pack, let progress = pack.progress(tried: triedIDs, in: db) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(progress.collected) / \(progress.total) TRIED")
                        .font(DexFont.retro(13))
                        .tracking(1)
                        .foregroundStyle(progress.isComplete ? Dex.green : lcd.text)
                    Spacer(minLength: 8)
                    Text("\(pack.entries(in: db).count) ENTRIES")
                        .font(DexFont.retro(13))
                        .tracking(1)
                        .foregroundStyle(lcd.subtext)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(lcd.surfaceEdge)
                        Capsule()
                            .fill(progress.isComplete ? Dex.green : lcd.accent)
                            .frame(width: geo.size.width * progress.fraction)
                    }
                }
                .frame(height: 10)
            }
        } else if let pack = item.pack {
            // A cosmetic pack: members you own or do not, and no denominator
            // `ExpansionPack.progress` is willing to invent. The count is
            // resolved here, in the module that can see `ChassisSkinSection`.
            Text("\(pack.cosmeticMemberCount) IN THIS PACK")
                .font(DexFont.retro(13))
                .tracking(1)
                .foregroundStyle(lcd.text)
        } else {
            let covered = db.entries.filter { item.entitlement.covers($0, in: db) }.count
            if covered > 0 {
                Text("\(covered) ENTRIES")
                    .font(DexFont.retro(13))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
            }
        }
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
                        art: owned ? "workshop" : nil,
                        tint: owned ? lcd.accent : Dex.yellow,
                        title: owned ? "OPEN" : "UNLOCK",
                        detail: owned
                            ? "Mix shell, buttons, orb, lights, marquee, grille, screen and font. Save the builds you like."
                            : "Build your own handheld: ten parts, mixed and matched, saved by name."
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
                    Text("The shell and screen pickers below stay free. The workshop is the eight parts they cannot reach — buttons, the header and marquee lights, the orb, the marquee, the grille colour and pattern, and the font.")
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
                    symbol: "iphone.radiowaves.left.and.right", art: "haptics",
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
                    // **Two faces, not one (0.8.9a, A7).** Every other row
                    // here has a single drawn face because every other row's
                    // glyph names a *place*; this one names a state, and the
                    // drop is the only one so far to deliver both halves of a
                    // toggle. The SF symbol stays singular deliberately -- it
                    // is the fallback, and a fallback that also branched would
                    // be two ways to be wrong about the same pixel.
                    symbol: "speaker.wave.2.fill",
                    art: soundsOn ? UIGlyph.soundsOn.artStem : UIGlyph.soundsOff.artStem,
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
        //
        // **The tutorial joins it in 0.7.6 (F1)**, and goes first. It is the one
        // row here somebody might be actively looking for — see the note on
        // `SettingsPanel.body` for what moving it off the grid cost and how
        // leading this section pays for it. It also fits the heading's own
        // argument: none of these is a *setting*, they are things the device can
        // tell you or do, and a guided tour of the device is squarely that.
        settingsSection("DEVICE") {
            VStack(alignment: .leading, spacing: 10) {
                dailyReminderRow

                Button {
                    Haptics.screenTap()
                    offeringTour = true
                } label: {
                    settingRow(
                        // The glyph the grid tile wore, so the row is
                        // recognisable to anyone who knew where it used to be.
                        symbol: "flag.checkered", art: "tutorial",
                        tint: lcd.accent,
                        title: "TUTORIAL",
                        detail: "A guided walk round the device. About a minute, and you can leave at any point."
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(lcd.subtext)
                    }
                }
                .buttonStyle(DexPressStyle(scale: 0.98))

                Button {
                    Haptics.screenTap()
                    onFirmwareHistory()
                } label: {
                    settingRow(
                        symbol: "memorychip.fill", art: "firmware",
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
                        symbol: "terminal.fill", art: "cheatcodes",
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
                        symbol: "play.rectangle.fill", art: "demomode",
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

                // "quiz and game scores" since 0.8.8 (E3): WHAT'S THAT…? keeps a
                // record now and this button erases it, so the sentence that
                // tells you what you are about to lose has to say so.
                Text("Erases bookmarks, tastings and ratings, quiz and game scores, the daily streak, name and photo, purchases, skin, screen and text settings. The encyclopedia itself is untouched.")
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
                    symbol: "ladybug.fill", art: "dev",
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
                        // **The shell wins over the workshop** (0.7.8, A2) —
                        // see `PendingPreset` and `DeviceBuild.choose`.
                        fit(PendingPreset(axis: .shell,
                                          value: option.rawValue,
                                          defaultValue: ChassisSkin.classic.rawValue,
                                          label: option.displayName))
                    }
                } label: {
                    VStack(spacing: 8) {
                        // Body over panel, so the swatch reads as the
                        // actual shell — with the skin's emblem glyph in
                        // the middle, the way the screen-mode tiles carry
                        // theirs, at the same 50pt so the two pickers
                        // read as one instrument (v0.5.6).
                        //
                        // **The drawing moved to `ChassisMockup` (0.8.1,
                        // A2)** so the shop's pack previews are the same
                        // picture rather than a fourth one. Nothing about
                        // it changed here except the orb, which A1 sends
                        // back to the mockup's own part scale.
                        ChassisMockup(skin: option, height: 50)
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
                        // Same rule as the shell above, over the one axis a
                        // screen mode governs — its font ink (0.7.8, A2).
                        fit(PendingPreset(axis: .screen,
                                          value: option.rawValue,
                                          defaultValue: LcdMode.dark.rawValue,
                                          label: option.displayName))
                    }
                } label: {
                    VStack(spacing: 8) {
                        // **The card moved into `ScreenMockup` (0.8.3, F).**
                        // The drawing is unchanged in every respect but the
                        // ink — see that type for why `ownInk` replaces `text`
                        // here as well as there. F asks for the shop's preview
                        // to be "exactly as it appears in Customise", and the
                        // only way to make that a fact rather than a promise is
                        // for there to be one card with two callers.
                        ScreenMockup(mode: option, height: 50)
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
                    // **`marquee-encyclopedia`, claimed here (0.8.8, G1).** The
                    // 0.8.4 drop shipped 34 faces and five of them were never
                    // wired to anything; this is the one whose subject is
                    // literally "the whole catalog", which is what this block
                    // counts. `lcd.accent` rather than a row colour — see
                    // `statGlyph`'s note for why that is the same rule as the
                    // tiles below and not an exception to it.
                    //
                    // The file arrived spelled `encylopedia.png`. It was
                    // **renamed** rather than mapped, on 0.8.3's cartridge rule:
                    // a typo in a filename is a typo, a typo in a table is a
                    // permanent second spelling. Nothing referenced the
                    // misspelling — it was unclaimed, which is the only moment
                    // renaming one of these is free.
                    DexChromeGlyph(
                        "marquee-encyclopedia",
                        symbol: "square.stack.3d.up.fill",
                        size: 26,
                        weight: .semibold,
                        tint: lcd.accent,
                        flatten: lcd.accent,
                        smoothing: true
                    )
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

    /// Art, glyph and tint per table.
    ///
    /// ## The drawn face, and where the symbol now comes from (0.8.8, G1)
    ///
    /// The six tiles were bare `Image(systemName:)` — this panel is the
    /// *ancestor* of the passport's TASTINGS tile (`PassportScreen.statTile`
    /// opens "the DATA panel's stat tile, at passport duty"), and it had been
    /// left behind by 0.8.6's C5 and 0.8.7's B2. The 0.8.4 drop already holds a
    /// face for all six rows, so this needed no art drawn.
    ///
    /// **The symbols were hand-listed here and two of them were wrong.** This
    /// table gave REGIONS `globe.americas.fill` and CONTINENTS `map.fill`;
    /// `EntryCategory.marqueeSymbol` gives regions `map.fill` and continents
    /// `globe.europe.africa.fill`. The two were swapped against the canonical
    /// table, which is exactly the drift a second hand-written copy produces and
    /// the reason this now reads `EntryCategory` for the five real tables rather
    /// than restating them. The old comment's claim — that the tiles "reuse the
    /// main menu's own symbols so a count is recognisably the same thing as the
    /// tile that opens it" — is true for the first time.
    ///
    /// COUNTRIES is not an `EntryCategory` and takes `DexRoute.country(name:)`'s
    /// pair, which is the same source the passport's COUNTRIES tile reads.
    ///
    /// ## Why `tint`, worked out here rather than carried over
    ///
    /// 0.8.7's B2 chose `tint` over 0.8.4 A2's `ink` on the passport, and the
    /// argument has to be re-made on this surface rather than copied, because
    /// A2's principle — a glyph and the thing beside it are one mark in one
    /// material — is what decides it and it points at different colours on
    /// different surfaces. On the chassis marquee the material is the lit panel,
    /// so the glyph reads `skin.marqueeShadow`, the same expression the letters
    /// do. Here the tile has drawn its border in `glyph.tint` since the panel
    /// shipped and its SF stand-in has always been `glyph.tint` too, so the row's
    /// own colour is already the material and the drawn face arriving in one ink
    /// would be the only part of the tile not saying which row it is. `lcd.text`
    /// would make all six identical; `lcd.accent` would make them identical *and*
    /// the same colour as the DATABASE heading above them.
    ///
    /// So `tint` — but note this is not simply the passport's answer restated.
    /// TOTAL ENTRIES below takes `lcd.accent`, and that is the same rule reaching
    /// a different colour: it is not a row, it is the total, it has no per-row
    /// colour to be the material of, and `lcd.accent` is what it has drawn its
    /// number's companion in all along.
    private func statGlyph(_ label: String) -> (art: String?, symbol: String, tint: Color) {
        if let category = EntryCategory(rawValue: label) {
            return (category.marqueeArt, category.marqueeSymbol, statTint(label))
        }
        // COUNTRIES — synthesised rows, no category of their own.
        let route = DexRoute.country(name: "")
        return (route.marqueeArt, "flag.fill", Dex.yellow)
    }

    /// The row's colour. Unchanged values — four of the six are the same hexes
    /// the passport's TASTINGS tiles use, which is why the two panels read as
    /// one vocabulary and why neither should be renumbered alone.
    private func statTint(_ label: String) -> Color {
        switch label {
        case "GRAPES": Color(dexHex: "#a855f7")
        case "REGIONS": Color(dexHex: "#22c55e")
        case "STYLES": Color(dexHex: "#f97316")
        case "FLAVORS": Color(dexHex: "#10b981")
        case "CONTINENTS": Dex.blue
        default: Dex.yellow
        }
    }

    private func statTile(label: String, count: Int) -> some View {
        let glyph = statGlyph(label)

        return HStack(spacing: 10) {
            // `art ?? ""` for `DexChromeGlyph`'s reason on the passport: it takes
            // a stem rather than an optional, and an empty stem resolves in no
            // directory, which is precisely the fallback a nil art wants.
            // `flatten:` and `tint:` take the same colour so the drawn branch and
            // the SF stand-in cannot disagree. `smoothing:` because these are
            // antialiased dots rather than a pixel grid.
            DexChromeGlyph(
                glyph.art ?? "",
                symbol: glyph.symbol,
                size: 20,
                weight: .semibold,
                tint: glyph.tint,
                flatten: glyph.tint,
                smoothing: true
            )
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
        // The Wine Exam's history and pass streak (0.7.5, D6). Its own store,
        // its own two keys — an un-reset history would leave a fresh start
        // claiming a hundred papers' worth of statistics.
        ExamRecordStore.shared.reset()
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
        // WHAT'S THAT…?'s record and the tool cards (0.8.8, E3/D1). Both are
        // exactly the shape this function's other entries warn about: a wipe
        // that left the record standing would open a fresh start claiming a
        // hundred solves and a live run, and one that left the seen-ids set
        // would silently swallow all six introductions on the one run where
        // meeting the tools again is the whole point.
        WhatsThatRecordStore.shared.reset()
        ToolIntroStore.shared.reset()
        // Professor Vino's ledger (0.8.9c, E1), for the reason the tool cards
        // above are here: a wipe that left the seen-ids set standing would open
        // a fresh start with him already silent, on the one run where meeting
        // him again is the whole point. `reset()` drops the seeded flag too, or
        // the wiped device would decline to re-seed and every later `seed` call
        // would be a no-op. The queue is cleared as well, so a bubble fired a
        // second before the wipe does not survive it.
        FirstTimeTriggerStore.shared.reset()
        VinoPresenter.shared.clear()
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
            // The ladder's ledger (0.8.7, D1). Belt to `PassportProgress.reset()`'s
            // braces, exactly as the badge key above it is — the two `seeded`
            // flags stay internal to Core and are only reachable through
            // `reset()`, which this list is a second line of defence for.
            PassportProgress.tierStorageKey,
            QuickPinStore.storageKey,
            StreakStore.streakKey,
            StreakStore.lastDayKey,
            StreakStore.bestKey,
            ExamRecordStore.storageKey,
            ExamRecordStore.bestStreakKey,
            CustomDeviceStore.storageKey,
            WhatsThatRecordStore.storageKey,
            ToolIntroStore.storageKey,
            // Belt to `FirstTimeTriggerStore.reset()`'s braces, like the two
            // above it. The seeded flag is listed too because it is the half a
            // key-loop-only wipe would miss.
            FirstTimeTriggerStore.storageKey,
            FirstTimeTriggerStore.seededKey,
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
            NotificationScheduler.enabledKey,
        ] {
            defaults.removeObject(forKey: key)
        }
        // Clearing the preference is not the same as cancelling what it already
        // scheduled: a wiped device with a week of pending reminders would keep
        // firing them at somebody who just erased everything (0.7.8, D1).
        NotificationScheduler.shared.disable()
    }
}

// MARK: - Fitting a preset

/// A preset the user has tapped in CUSTOMIZE, and what fitting it will cost
/// (0.7.8, A2).
///
/// **Why this is a value rather than two `if` branches in the two grids.** The
/// SHELL and SCREEN pickers are the same instrument with different contents —
/// they were written that way on purpose in 0.5.6 — and A2's rule is one rule
/// about presets, not two rules about skins and modes. Modelling the tap as a
/// value lets both grids raise the same alert, and lets the alert be built from
/// what the tap *is* rather than from a copy of the rule per call site. It also
/// means the eleventh axis, whenever it arrives, changes `DeviceAxis.inherits`
/// and nothing here.
///
/// The three things it holds beyond the choice itself are all things Core
/// cannot know: `label` is a `displayName` (a `VinodexUI` concept), and
/// `defaultValue` is which raw value means "as it ships" for this particular
/// enum, which is `ChassisSkin.classic` / `LcdMode.dark` — again UI's.
struct PendingPreset: Equatable {
    let axis: DeviceAxis
    let value: String
    let defaultValue: String
    let label: String

    /// The fitted parts this choice would clear. Read once, at the moment of
    /// the tap, so the alert cannot describe a device that has since changed.
    let cleared: [DeviceAxis]

    init(axis: DeviceAxis, value: String, defaultValue: String, label: String) {
        self.axis = axis
        self.value = value
        self.defaultValue = defaultValue
        self.label = label
        self.cleared = DeviceBuild.overrides(clearedByChoosing: axis)
    }

    func commit() {
        DeviceBuild.choose(axis, value, defaultValue: defaultValue)
    }

    /// What the alert says.
    ///
    /// `fitted` is the saved build the device currently matches, if any. It is
    /// named when there is one because "your build stops being fitted" and
    /// "your build is gone" are the two readings of what is about to happen and
    /// only one of them is true — `customDevices` is untouched by any of this,
    /// and saying so is cheaper than a user discovering it or not.
    func message(fitted: CustomDevice?) -> String {
        let parts = cleared.map(\.title).joined(separator: ", ")
        let count = cleared.count == 1 ? "part" : "parts"
        var lines = [
            "\(label) brings its own colours, so the \(cleared.count) \(count) you fitted "
            + "(\(parts)) go back to following it.",
        ]
        if let fitted {
            lines.append("\(fitted.name) stays saved in the Workshop — fit it again there whenever you like.")
        } else {
            lines.append("Save a build in the Workshop first if you want to come back to it.")
        }
        return lines.joined(separator: " ")
    }
}
#endif
