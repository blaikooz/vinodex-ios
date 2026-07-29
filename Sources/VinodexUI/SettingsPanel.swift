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

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                // Games first: it is the only tile here anyone opens for fun,
                // and burying it under the toggles is what it was already
                // suffering from as a row in the old list.
                featureTile(
                    title: "MINIGAMES",
                    symbol: "gamecontroller.fill",
                    tint: Dex.yellow,
                    action: onMinigames
                )

                ForEach(SettingsSection.allCases) { section in
                    featureTile(
                        title: section.rawValue,
                        symbol: section.symbol,
                        tint: tint(for: section)
                    ) {
                        onSection(section)
                    }
                }
            }
            .padding(12)
        }
        .background(lcd.isLight ? lcd.page : Dex.screen)
    }

    private func tint(for section: SettingsSection) -> Color {
        switch section {
        case .customization: Dex.red500
        case .data: Dex.blue
        case .access: Dex.yellow
        case .dev: Dex.stone400
        }
    }

    /// Square by construction — `aspectRatio(1, contentMode: .fit)` inside a
    /// flexible grid column — so the grid stays square whatever the device width.
    private func featureTile(
        title: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            // Glyph and label both up a size: these tiles are square and mostly
            // empty, so the artwork was floating in the middle of a lot of
            // nothing and the caption underneath it was the smallest type on
            // the screen. The tile geometry did not need to change — only what
            // is drawn in it.
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(tint)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2)
                Text(title)
                    .font(DexFont.retro(13))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(RoundedRectangle(cornerRadius: 10).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(tint.opacity(0.5), lineWidth: 2)
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

    @State private var access = AccessStore.shared
    /// Set when a gated cosmetic is tapped; drives the same upgrade prompt a
    /// locked entry raises, so a paywalled *setting* behaves like a paywalled
    /// page rather than being a dead control.
    @State private var lockedBundle: Entitlement?
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    @AppStorage(TextScale.storageKey) private var scaleRaw = TextScale.small.rawValue
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue

    private let db = WineDatabase.shared

    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }
    private var scale: TextScale { TextScale(rawValue: scaleRaw) ?? .small }
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    private var totalCount: Int { db.entries.count }

    public init(section: SettingsSection) {
        self.section = section
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch section {
                case .customization: customization
                case .data: dataReadout
                case .access: paywallTesting
                case .dev: dev
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(lcd.isLight ? lcd.page : Dex.screen)
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
            }
        }
        .animation(.easeOut(duration: 0.15), value: lockedBundle)
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
    private var testableEntitlements: [Entitlement] {
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

    /// Screen mode, then text size, then the shell — the three questions that
    /// used to be three tiles, in the order you answer them: the screen is what
    /// you read, the text is how big, the shell is the frame around both.
    @ViewBuilder
    private var customization: some View {
        screenMode
        textSize
        skinTesting
    }

    /// "CHASSIS SKIN", not "SHELL SKIN": the rest of the app calls this part of
    /// the device the chassis — `DeviceChassis`, `ChassisSkin`, `ChassisButton`
    /// — and the settings panel was the one place using a second word for it.
    ///
    /// Everything past the default is gated on `.skins`, which is what makes a
    /// cosmetic bundle a testable paywall case rather than a hypothetical one.
    private var skinTesting: some View {
        settingsSection("CHASSIS SKIN") {
            VStack(spacing: 8) {
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
                        HStack(spacing: 12) {
                            // Body over panel, so the pair reads as the actual
                            // shell rather than one flat swatch.
                            RoundedRectangle(cornerRadius: 4)
                                .fill(option.body)
                                .frame(width: 44, height: 34)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(option.panel)
                                        .frame(height: 12)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(option.panelEdge, lineWidth: 1)
                                )
                                .opacity(locked ? 0.45 : 1)
                            Text(option.displayName)
                                .font(DexFont.retro(13))
                                .tracking(1)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                            Spacer(minLength: 0)
                            if locked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16, weight: .bold))
                            } else if skin == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 17, weight: .bold))
                            }
                        }
                        .foregroundStyle(skin == option ? .white : lcd.subtext)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(skin == option ? lcd.accent : lcd.surface)
                        )
                    }
                    .buttonStyle(DexPressStyle(scale: 0.98))
                }
            }
        }
    }

    /// Separate from the chassis skin on purpose: the shell and the screen are
    /// independent choices, and a light screen in the red shell is a perfectly
    /// good combination.
    private var screenMode: some View {
        settingsSection("SCREEN MODE") {
            HStack(spacing: 8) {
                ForEach(LcdMode.allCases) { option in
                    // Light mode is a cosmetic bundle, so it is a paywall case
                    // that costs nothing to test and touches every screen.
                    let locked = option.isLight && !access.isUnlocked(.lightMode)

                    Button {
                        Haptics.select()
                        if locked {
                            lockedBundle = .lightMode
                        } else {
                            lcdRaw = option.rawValue
                        }
                    } label: {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(option.screen)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(option.accent, lineWidth: 1)
                                )
                            Text(option.rawValue)
                                .font(DexFont.retro(13))
                                .tracking(1)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            if locked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 13, weight: .bold))
                            }
                        }
                        .foregroundStyle(lcd == option ? .white : lcd.subtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
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
                                .font(DexFont.retro(13))
                                .tracking(1)
                                .foregroundStyle(scale == option ? .white : lcd.subtext)
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
                Text("Applies everywhere. Capped so the retro face still fits its tiles.")
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
                HStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(lcd.accent)
                    Text("\(stats.total)")
                        .font(DexFont.retro(24))
                        .foregroundStyle(lcd.text)
                    Spacer(minLength: 0)
                    Text("ACROSS \(stats.categoryLines.count) TABLES")
                        .font(DexFont.mono(16))
                        .foregroundStyle(lcd.subtext)
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
                VStack(alignment: .leading, spacing: 8) {
                    DataWave(milestones: stats.waveMilestones, lcd: lcd)
                    Text("Entries shipped, from the first starter selection to the current build.")
                        .font(DexFont.mono(15))
                        .foregroundStyle(lcd.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
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
    }

    // MARK: Dev

    /// Report, then the component gallery, then the icon sheet last — the icon
    /// grid is the longest thing here and buried everything after it.
    private var dev: some View {
        VStack(alignment: .leading, spacing: 16) {
            DiagnosticsReport(db: db)
            CatalogScreen(db: db, showsIcons: false)
            CatalogScreen.IconSheet(db: db)
        }
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
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isOn)
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

    private static let duration: Double = 2.6

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.animation(paused: finished)) { timeline in
                // The counter and the curve must advance together, so both are
                // rendered from the same value.
                let elapsed = timeline.date.timeIntervalSince(start)
                let linear = min(max(elapsed / Self.duration, 0), 1)
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
        .frame(height: 96)
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
#endif
