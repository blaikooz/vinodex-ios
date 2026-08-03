#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
// `.json` for the RESTORE picker's `allowedContentTypes` (AUDIT **M35**).
import UniformTypeIdentifiers
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
                featureTile(title: "TUTORIAL", symbol: "flag.checkered", livery: .green) {
                    offeringTour = true
                }
                // A wrench, not a gamepad — the hub holds more instruments
                // than games, and the tile should promise what it opens.
                featureTile(
                    title: "TOOLS",
                    symbol: "wrench.and.screwdriver.fill",
                    livery: .amber,
                    action: onMinigames
                )
            }
            // DEV is deliberately absent from the grid — it lives as a
            // button inside SETTINGS, where developer plumbing belongs.
            HStack(spacing: 10) {
                featureTile(
                    title: SettingsSection.customization.rawValue,
                    symbol: SettingsSection.customization.symbol,
                    livery: .red
                ) {
                    onSection(.customization)
                }
                featureTile(
                    title: SettingsSection.settings.rawValue,
                    symbol: SettingsSection.settings.symbol,
                    livery: .orange
                ) {
                    onSection(.settings)
                }
            }
            HStack(spacing: 10) {
                featureTile(
                    title: SettingsSection.data.rawValue,
                    symbol: SettingsSection.data.symbol,
                    livery: .sky
                ) {
                    onSection(.data)
                }
                featureTile(
                    title: SettingsSection.access.rawValue,
                    symbol: SettingsSection.access.symbol,
                    livery: .violet
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
        .animation(.easeOut(duration: 0.15), value: offeringTour)
    }

    /// Styled like the main menu's tiles — filled face, 6pt bottom extrusion,
    /// top-left sheen. Stretches to fill its grid cell rather than squaring
    /// off (v0.5.6): the grid fits the LCD, so the tiles absorb the height.
    ///
    /// The livery is now a parameter rather than a lookup on `title` (AUDIT
    /// **L33**). Two parallel six-row tables of hexes lived here, both switched
    /// on the tile's display string, both ending in a `default:` that meant
    /// ACCESS — so renaming a tile silently repainted it purple, and the
    /// compiler had nothing to say about it. See `DexTileLivery`.
    private func featureTile(
        title: String,
        symbol: String,
        livery: DexTileLivery,
        action: @escaping () -> Void
    ) -> some View {
        let style = (
            face: livery.face(lcd),
            shadow: livery.shadow(lcd),
            ink: livery.ink
        )

        return Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(style.ink)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2)
                Text(title)
                    .font(DexFont.retro(13))
                    .tracking(1)
                    .foregroundStyle(style.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 1, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(style.face)
                    .overlay(alignment: .bottom) {
                        // The same 6pt fake extrusion the menu tiles carry.
                        style.shadow.frame(height: 6)
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

    @State private var access = AccessStore.shared
    /// Set when a gated cosmetic is tapped; drives the same upgrade prompt a
    /// locked entry raises, so a paywalled *setting* behaves like a paywalled
    /// page rather than being a dead control.
    @State private var lockedBundle: Entitlement?
    /// CLEAR SAVED DATA asks first — it is the one control here that cannot be
    /// undone by tapping it again.
    @State private var confirmingWipe = false
    /// BACK UP / RESTORE (AUDIT **M35**). The archive is written to a temp file
    /// and handed to `ShareLink`; the URL is held so the button can be built
    /// before the user taps anything, since `ShareLink` wants its item up front.
    @State private var backupURL: URL?
    @State private var showingImporter = false
    /// A decoded archive waiting on the in-LCD confirmation. Restoring is
    /// destructive in the same way the wipe is — it replaces the shelves rather
    /// than merging into them — so it asks with the same dialog.
    @State private var pendingImport: SavedDataArchive?
    /// One line of outcome, success or refusal. Nil when there is nothing to
    /// report.
    @State private var transferNotice: String?
    @AppStorage(Haptics.storageKey) private var hapticsOn = true
    /// Off by default from v0.5.1 — sounds are opt-in. See `Sounds`.
    @AppStorage(Sounds.storageKey) private var soundsOn = false
    /// On by default, preserving the behaviour this setting was carved out of
    /// (AUDIT **L40**). See `ScreenWake`.
    @AppStorage(ScreenWake.storageKey) private var keepAwakeOn = true
    /// Scroll position outlives the view — see `ScreenStateStore`. ACCESS and
    /// DATA are both taller than the LCD, so opening the upgrade prompt from a
    /// bundle row near the bottom used to bounce the panel back to the top.
    @State private var screens = ScreenStateStore.shared
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    @AppStorage(TextScale.storageKey) private var scaleRaw = TextScale.small.rawValue
    @AppStorage(UIScale.storageKey) private var uiScaleRaw = UIScale.small.rawValue
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue

    /// The database this screen reads. Defaulted so no call site changes, but
    /// injectable, which is the whole of **M27**: a screen that hard-reads
    /// `WineDatabase.shared` cannot be put in front of a fixture.
    private let db: WineDatabase

    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }
    private var scale: TextScale { TextScale(rawValue: scaleRaw) ?? .small }
    private var uiScale: UIScale { UIScale(rawValue: uiScaleRaw) ?? .small }
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    private var totalCount: Int { db.entries.count }

    public init(db: WineDatabase = .shared, section: SettingsSection, onDev: @escaping () -> Void = {}) {
        self.db = db
        self.section = section
        self.onDev = onDev
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
                    },
                    onCancel: { self.lockedBundle = nil }
                )
            } else if confirmingWipe {
                DexAlert(
                    title: "CLEAR SAVED DATA?",
                    message: "Everything stored on this device — bookmarks, recents, tastings and ratings, quiz progress, streak, profile, purchases and appearance — goes back to a fresh install. This cannot be undone.",
                    confirmLabel: "ERASE",
                    destructive: true,
                    onConfirm: {
                        confirmingWipe = false
                        SavedDataReset.wipeAll()
                    },
                    onCancel: { confirmingWipe = false }
                )
            } else if let pendingImport {
                DexAlert(
                    title: "RESTORE THIS BACKUP?",
                    message: Self.importSummary(pendingImport),
                    confirmLabel: "RESTORE",
                    destructive: true,
                    onConfirm: {
                        self.pendingImport = nil
                        let written = SavedDataRestore.apply(pendingImport)
                        transferNotice = "Restored \(written.count) of \(SavedDataKey.allCases.count) items. Purchases are not restored from a file."
                    },
                    onCancel: { self.pendingImport = nil }
                )
            } else if let transferNotice {
                DexAlert(
                    title: "STORED DATA",
                    message: transferNotice,
                    confirmLabel: "OK",
                    // An outcome, not a choice — one button, per DexAlert's note.
                    cancelLabel: nil,
                    onConfirm: { self.transferNotice = nil },
                    onCancel: { self.transferNotice = nil }
                )
            }
        }
        // The house rule is that dialogs render inside the LCD (AUDIT **L41**),
        // and every one above does. `.fileImporter` is the third documented
        // exception, after `PhotosPicker` for the avatar and `ShareLink` below:
        // the OS owns the file browser, an app cannot draw one, and building a
        // fake in-LCD browser over `FileManager` would be worse than the
        // inconsistency. What follows the picker is a `DexAlert` like
        // everything else.
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .animation(.easeOut(duration: 0.15), value: lockedBundle)
        .animation(.easeOut(duration: 0.15), value: confirmingWipe)
        .animation(.easeOut(duration: 0.15), value: pendingImport)
        .animation(.easeOut(duration: 0.15), value: transferNotice)
    }

    /// BACK UP and RESTORE share a face. Drawn like the CLEAR button below
    /// them rather than like a `settingRow`, because all three are actions on
    /// the whole store rather than settings with a value.
    private func transferLabel(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
            Text(title)
                .font(DexFont.retro(11))
                .tracking(1)
        }
        .foregroundStyle(tint)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(tint.opacity(0.4), lineWidth: 2)
        )
    }

    /// What the confirmation names, so "restore" is not a blind tap: where the
    /// file came from and how much is in it.
    private static func importSummary(_ archive: SavedDataArchive) -> String {
        let shelved = archive.savedShelf.count + archive.wantToTryShelf.count + archive.triedShelf.count
        let age = DailyPick.dayIndex() - archive.exportedDay
        let when = age <= 0 ? "today" : age == 1 ? "yesterday" : "\(age) days ago"
        return "From v\(archive.appVersion), backed up \(when). It holds \(shelved) shelved items and \(archive.triedRatings.count) tasting notes. Everything currently on this device is replaced, not merged."
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            transferNotice = "Could not open that file: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            // A file handed over by the picker lives outside the app's
            // sandbox, so it has to be opened under a security scope — without
            // this the read fails with a permission error on a real device and
            // works fine in the simulator, which is the worst way to find out.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingImport = try SavedDataArchive.decode(from: Data(contentsOf: url))
            } catch let refusal as SavedDataArchive.Refusal {
                switch refusal {
                case .notOurArchive(let app):
                    transferNotice = "That file is not a Vinodex backup (it says \"\(app)\")."
                case .unreadableFormat(let format):
                    transferNotice = "That backup is in format \(format), which this build does not know how to read. Update the app and try again."
                }
            } catch {
                transferNotice = "That file is not readable as a backup."
            }
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
                    case .access: accessReadout
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

    /// What this copy of the app can open, and what it cannot (AUDIT **L42**).
    ///
    /// Read-only, and that is the change. This panel used to *be* the test
    /// harness: a FREE TIER master switch that turned the paywall off outright,
    /// a toggle per bundle that granted it, a REVOKE ALL, and copy describing
    /// itself as "a test harness, not a store" — all of it one tap from the
    /// settings grid, in front of every user. The harness is still exactly as
    /// useful and still exists; it has moved behind DEV, where the rest of the
    /// developer plumbing already lives. What a user sees here is a statement
    /// of what they have.
    @ViewBuilder
    private var accessReadout: some View {
        settingsSection("YOUR LIBRARY") {
            VStack(alignment: .leading, spacing: 10) {
                settingRow(
                    symbol: access.starterOnly ? "lock.fill" : "lock.open.fill",
                    tint: access.starterOnly ? Dex.yellow : Dex.green,
                    title: access.starterOnly ? "FREE LIBRARY" : "FULL LIBRARY",
                    detail: access.starterOnly
                        ? "\(browsableCount) of \(totalCount) entries open to you"
                        : "All \(totalCount) entries open to you"
                ) {
                    EmptyView()
                }

                Text("More of the catalog comes with the bundles below. There is no store in this build — nothing here can be bought yet.")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        settingsSection("BUNDLES") {
            VStack(spacing: 10) {
                ForEach(offerableEntitlements, id: \.id) { entitlement in
                    let owned = access.granted.contains(entitlement)
                    settingRow(
                        symbol: bundleSymbol(entitlement),
                        tint: owned ? Dex.green : lcd.subtext,
                        title: entitlement.title,
                        detail: entitlement.blurb
                    ) {
                        // A state, not a control. The tick says what is true;
                        // it does not offer to change it.
                        Image(systemName: owned ? "checkmark.circle.fill" : "lock.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(owned ? Dex.green : lcd.subtext)
                            .accessibilityLabel(owned ? "Owned" : "Locked")
                    }
                }
            }
        }
    }

    /// The entitlement grants, as a developer tool — the controls that used to
    /// sit in ACCESS (AUDIT **L42**).
    ///
    /// One boolean could only produce two states — all locked or all open — so
    /// every interesting case went untested. The bundle rows here reproduce
    /// them: own one country and nothing else, own the flavour wheel but no
    /// atlas, own a cosmetic but no content. The counter under the master
    /// switch reports what the current combination actually yields, which is
    /// the fastest way to see a coverage rule behaving wrongly. All of that is
    /// worth keeping; none of it was ever worth shipping to the settings grid.
    @ViewBuilder
    private var entitlementHarness: some View {
        settingsSection("PAYWALL TESTING") {
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

        settingsSection("GRANT BUNDLES") {
            VStack(spacing: 10) {
                ForEach(offerableEntitlements, id: \.id) { entitlement in
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

    /// The bundles both panels list — ACCESS as a readout, DEV as switches.
    ///
    /// Country bundles are drawn from the countries that actually have regions,
    /// capped at the three largest: eighteen country rows would bury the
    /// cosmetic ones underneath them.
    private var offerableEntitlements: [Entitlement] {
        [.pro, .flavors] + topCountries.map { Entitlement.country($0) } + [.skins, .lightMode]
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
    @ViewBuilder
    private var customization: some View {
        screenMode
        skinTesting
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

        // The third row beside HAPTICS and SOUNDS, and the same shape: a device
        // behaviour the app used to simply assert. Keeping the screen alive for
        // the whole life of the process is defensible for a book you read with
        // a glass in your hand and indefensible as something nobody was asked
        // about. (AUDIT **L40**)
        settingsSection("SCREEN") {
            VStack(alignment: .leading, spacing: 10) {
                settingRow(
                    symbol: keepAwakeOn ? "sun.max.fill" : "moon.zzz.fill",
                    tint: keepAwakeOn ? Dex.green : lcd.subtext,
                    title: "KEEP AWAKE",
                    detail: keepAwakeOn
                        ? "The screen stays on while the app is open."
                        : "The screen locks on your usual schedule."
                ) {
                    DexToggle(isOn: keepAwakeOn, tint: Dex.green) {
                        keepAwakeOn.toggle()
                        // Applied now rather than at the next launch — a
                        // setting whose effect you cannot observe reads as
                        // broken.
                        ScreenWake.settingChanged()
                    }
                }
                Text("Reading a bottle takes longer than the auto-lock allows. Turn it off if you would rather the phone behaved normally.")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        settingsSection("STORED DATA") {
            VStack(alignment: .leading, spacing: 10) {
                // Backup sits immediately above the button that destroys what
                // it backs up. A bundle-ID change orphans this device's
                // container outright — there is no migration to write, so a
                // file the user keeps is the only thing that survives one
                // (AUDIT **M35**; KNOWN-ISSUES, "Changing the bundle ID is a
                // one-way door").
                //
                // `ShareLink` is a system sheet, and the second documented
                // exception to the in-LCD dialog rule for the same reason
                // `.fileImporter` is: the OS owns the destination picker.
                if let backupURL {
                    ShareLink(item: backupURL) {
                        transferLabel("BACK UP", symbol: "square.and.arrow.up", tint: lcd.text)
                    }
                    .buttonStyle(DexPressStyle(scale: 0.98))
                } else {
                    Button {
                        Haptics.tap()
                        do {
                            backupURL = try SavedDataRestore.writeTemporaryFile(
                                SavedDataRestore.archive()
                            )
                        } catch {
                            transferNotice = "Could not write the backup file: \(error.localizedDescription)"
                        }
                    } label: {
                        transferLabel("BACK UP", symbol: "square.and.arrow.up", tint: lcd.text)
                    }
                    .buttonStyle(DexPressStyle(scale: 0.98))
                }

                Button {
                    Haptics.tap()
                    showingImporter = true
                } label: {
                    transferLabel("RESTORE", symbol: "square.and.arrow.down", tint: lcd.text)
                }
                .buttonStyle(DexPressStyle(scale: 0.98))

                Text("A backup is one file holding your shelves, tastings, progress and settings. Keep it somewhere off the phone: reinstalling, or a change to the app's identity on a future release, leaves everything on this page behind. Purchases are not in it — those come back from the store, never from a file.")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)

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

                Text("Erases bookmarks, tastings and ratings, quiz progress, the daily streak, name and photo, purchases, skin, screen and text settings. The encyclopedia itself is untouched. Back up first if you want any of it again.")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        // The back of the device was reachable only by a one-second press on
        // an orb that looks like a lamp — an easter egg doing the job of a
        // signpost, with the version number, the maker's mark and the earned
        // collector stamps behind it. The egg stays; this is the route for
        // people who were never going to guess it. (AUDIT **M21**)
        settingsSection("ABOUT") {
            Button {
                Haptics.tap()
                ChassisFlipRouter.shared.flip()
            } label: {
                settingRow(
                    // iOS 13 vintage, deliberately: the `arrow.trianglehead.*`
                    // family reads better here and renders blank on 17, which
                    // is the floor. See KNOWN-ISSUES.
                    symbol: "arrow.triangle.2.circlepath",
                    tint: lcd.subtext,
                    title: "TURN THE DEVICE OVER",
                    detail: "Version, serial and maker's mark are engraved on the back — along with any collector stamps you have earned. Swipe to come back."
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(lcd.subtext)
                }
            }
            .buttonStyle(DexPressStyle(scale: 0.98))
        }

        settingsSection("DEVELOPER") {
            Button {
                Haptics.tap()
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
            LazyVGrid(columns: pickerColumns, spacing: 8) {
                ForEach(ChassisSkin.allCases) { option in
                    let locked = option != .classic && !access.isUnlocked(.skins)

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
                                    Image(systemName: option.symbol)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(option.accent.pale)
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
                                .frame(height: 28)
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
    }

    /// Separate from the chassis skin on purpose: the shell and the screen are
    /// independent choices, and a light screen in the red shell is a perfectly
    /// good combination.
    /// A three-column grid of mode cards, one per `LcdMode`. Was a horizontal
    /// shelf for one release — at ten modes the shelf hid most of them off the
    /// right edge, and a grid shows the whole range at once.
    ///
    /// Each card is a miniature LCD in the mode's own colours: glyph, a text
    /// line, a caption line. The monochrome modes run the real grayscale-and-
    /// tint pass over their miniature, so AMBER previews amber rather than
    /// the green its raw tokens would show.
    private var screenMode: some View {
        settingsSection("SCREEN MODE") {
            LazyVGrid(columns: pickerColumns, spacing: 8) {
                ForEach(LcdMode.allCases) { option in
                    // Every mode past the default gates on the same cosmetic
                    // bundle — a paywall case that costs nothing to test and
                    // touches every screen.
                    let locked = option != .dark && !access.isUnlocked(.lightMode)

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
                                //
                                // Still three options after M49, deliberately:
                                // a fourth splits this row into ~69pt columns,
                                // and a control you have to squint at to pick a
                                // text size is its own joke. M49's extra range
                                // went into HUGE instead of into a new button.
                                // The row is sized by its longest label — SMALL,
                                // five characters, wanting `5 × 13f` points, so
                                // 84.5pt of a ~97pt column at the new 1.30 top.
                                // It fits without shrinking; 0.8 is headroom.
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
                            Text(option.rawValue)
                                .font(DexFont.retro(13))
                                .tracking(1)
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
            settingsSection("DATABASE") {
                LazyVGrid(columns: statColumns, spacing: 8) {
                    ForEach(stats.categoryLines) { line in
                        statTile(label: line.label, count: line.count)
                    }
                }
            }

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
        // The entitlement grants, moved here from ACCESS (AUDIT **L42**) —
        // developer plumbing, behind the button the rest of it lives behind.
        entitlementHarness
        CatalogScreen(db: db, showsIcons: false).id("COMPONENTS")
        CatalogScreen.IconSheet(db: db).id("ICONS")
    }
}

// MARK: - Physical toggle

#endif
