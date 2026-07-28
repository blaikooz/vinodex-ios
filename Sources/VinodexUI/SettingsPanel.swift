#if canImport(SwiftUI) && canImport(UIKit)
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
        case .screen: Dex.green
        case .text: Dex.blue
        case .skin: Dex.red500
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
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(tint)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2)
                Text(title)
                    .font(DexFont.retro(10))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    @AppStorage(TextScale.storageKey) private var scaleRaw = TextScale.small.rawValue
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue

    private let db = WineDatabase.shared

    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }
    private var scale: TextScale { TextScale(rawValue: scaleRaw) ?? .small }
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    private var totalCount: Int { db.entries.count }
    private var freeCount: Int { db.entries.filter { db.isFree($0.id) }.count }

    public init(section: SettingsSection) {
        self.section = section
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch section {
                case .screen: screenMode
                case .text: textSize
                case .skin: skinTesting
                case .access: paywallTesting
                case .dev: dev
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(lcd.isLight ? lcd.page : Dex.screen)
    }

    private var paywallTesting: some View {
        settingsSection("PAYWALL TESTING") {
            Button {
                Haptics.select()
                access.starterOnly.toggle()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: access.starterOnly ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(access.starterOnly ? Dex.yellow : Dex.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(access.starterOnly ? "FREE TIER" : "EVERYTHING UNLOCKED")
                            .font(DexFont.retro(11))
                            .tracking(1)
                            .foregroundStyle(lcd.text)
                        Text(access.starterOnly
                            ? "\(freeCount) of \(totalCount) entries browsable"
                            : "All \(totalCount) entries browsable")
                            .font(DexFont.mono(16))
                            .foregroundStyle(lcd.subtext)
                    }
                    Spacer(minLength: 0)
                    toggleTrack(on: access.starterOnly)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                )
            }
            .buttonStyle(DexPressStyle(scale: 0.98))
        }
    }

    private var skinTesting: some View {
        settingsSection("SKIN TESTING") {
            VStack(spacing: 8) {
                ForEach(ChassisSkin.allCases) { option in
                    Button {
                        Haptics.select()
                        skinRaw = option.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            // Body over panel, so the pair reads as the actual
                            // shell rather than one flat swatch.
                            RoundedRectangle(cornerRadius: 4)
                                .fill(option.body)
                                .frame(width: 34, height: 26)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(option.panel)
                                        .frame(height: 9)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(option.panelEdge, lineWidth: 1)
                                )
                            Text(option.rawValue)
                                .font(DexFont.retro(11))
                                .tracking(1)
                            Spacer(minLength: 0)
                            if skin == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .foregroundStyle(skin == option ? .white : lcd.subtext)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 13)
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
                    Button {
                        Haptics.select()
                        lcdRaw = option.rawValue
                    } label: {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(option.screen)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(option.accent, lineWidth: 1)
                                )
                            Text(option.rawValue)
                                .font(DexFont.retro(11))
                                .tracking(1)
                        }
                        .foregroundStyle(lcd == option ? .white : lcd.subtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(TextScale.allCases) { option in
                        Button {
                            Haptics.select()
                            scaleRaw = option.rawValue
                        } label: {
                            Text(option.rawValue)
                                .font(DexFont.retro(11))
                                .tracking(1)
                                .foregroundStyle(scale == option ? .white : lcd.subtext)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(scale == option ? lcd.accent : lcd.surface)
                                )
                        }
                        .buttonStyle(DexPressStyle(scale: 0.97))
                    }
                }
                Text("Applies everywhere. Capped so the retro face still fits its tiles.")
                    .font(DexFont.mono(15))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func toggleTrack(on: Bool) -> some View {
        Capsule()
            .fill(on ? Dex.yellow : Dex.stone700)
            .frame(width: 42, height: 24)
            .overlay(alignment: on ? .trailing : .leading) {
                Circle().fill(.white).frame(width: 18, height: 18).padding(3)
            }
    }

    private func settingsSection<C: View>(
        _ title: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(DexFont.retro(10))
                .tracking(1)
                .foregroundStyle(lcd.accent)
                .padding(.bottom, 2)
                .overlay(alignment: .bottom) { lcd.accent.opacity(0.35).frame(height: 1) }
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
#endif
