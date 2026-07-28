#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The device's own menu, hinged on the right edge of the LCD.
///
/// It slides in from the right and covers most — not all — of the screen, so
/// the app stays visible behind it and the panel reads as a flap swung out of
/// the side of the device rather than a page you navigated to. That is also the
/// shape a folding screen wants: the same view can occupy the second panel
/// unchanged when there is one.
public struct SettingsPanel: View {
    public enum Tab: String, CaseIterable, Identifiable {
        case settings = "SETTINGS"
        /// Diagnostics and the component catalog — both developer tools, and
        /// they were competing for tab space with the one tab a user opens.
        case dev = "DEV"

        public var id: String { rawValue }
    }

    let onClose: () -> Void
    let onDailyGrape: () -> Void

    @State private var tab: Tab = .settings
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

    public init(onClose: @escaping () -> Void, onDailyGrape: @escaping () -> Void = {}) {
        self.onClose = onClose
        self.onDailyGrape = onDailyGrape
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabBar

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch tab {
                    case .settings: settings
                    case .dev: dev
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(lcd.isLight ? lcd.page : Dex.screen)
    }

    private var header: some View {
        HStack {
            Text("SYSTEM")
                .font(DexFont.retro(13))
                .tracking(2)
                .foregroundStyle(Dex.green)
            Spacer()
            Button {
                Haptics.tap()
                onClose()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(lcd.text)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(lcd.surface))
            }
            .buttonStyle(DexPressStyle(scale: 0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Dex.stone900)
        .overlay(alignment: .bottom) { Dex.green.opacity(0.4).frame(height: 2) }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { item in
                Button {
                    Haptics.select()
                    tab = item
                } label: {
                    Text(item.rawValue)
                        .font(DexFont.retro(9))
                        .tracking(1)
                        .foregroundStyle(tab == item ? .white : lcd.subtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(tab == item ? lcd.accent : lcd.surface)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) { Dex.stone700.frame(height: 1) }
    }

    // MARK: Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: 18) {
            dailyGrapeButton
            paywallTesting
            skinTesting
            screenMode
            textSize
        }
    }

    private var dailyGrapeButton: some View {
        Button {
            Haptics.tap()
            onDailyGrape()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Dex.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("GRAPE OF THE DAY")
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .foregroundStyle(lcd.text)
                    Text("A new one every day")
                        .font(DexFont.mono(16))
                        .foregroundStyle(lcd.subtext)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(lcd.subtext)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 6).strokeBorder(Dex.yellow.opacity(0.5), lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
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
