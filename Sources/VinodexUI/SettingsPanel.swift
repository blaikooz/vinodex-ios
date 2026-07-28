#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The device's own menu: SETTINGS and a DEV tab holding diagnostics and the
/// component catalog.
///
/// Presented inside the LCD rather than as a `.sheet`. A sheet slides over the
/// whole chassis, which breaks the device metaphor — the bezel, footer and
/// island strip are meant to be physical furniture that never moves. Confining
/// the panel to the screen keeps that intact and makes it read as the device
/// showing a menu rather than iOS showing a modal.
public struct SettingsPanel: View {
    public enum Tab: String, CaseIterable, Identifiable {
        case settings = "SETTINGS"
        /// Diagnostics and the component catalog, which are both developer
        /// tools and were competing for tab space with the one tab a user has
        /// any reason to open.
        case dev = "DEV"

        public var id: String { rawValue }
    }

    let onClose: () -> Void

    @State private var tab: Tab = .settings
    /// Placeholder until there is something real to configure.
    @State private var scratch = ""
    /// Same key `DeviceChassis` reads, so the chassis repaints as this changes.
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue

    @State private var access = AccessStore.shared

    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }
    private var totalCount: Int { db.entries.count }
    private var freeCount: Int { db.entries.filter { db.isFree($0.id) }.count }

    private let db = WineDatabase.shared

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            tabBar

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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
        .background(Dex.screen)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Dex.green.opacity(0.55), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Dex.stone200)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Dex.stone800))
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
                        .foregroundStyle(tab == item ? .black : Dex.stone400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(tab == item ? Dex.green : Dex.stone800)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) { Dex.stone700.frame(height: 1) }
    }

    /// Report first, then the component gallery, then the icon sheet last —
    /// the icon grid is the longest thing in the panel by far and pushed
    /// everything else off-screen when it sat in the middle.
    private var dev: some View {
        VStack(alignment: .leading, spacing: 16) {
            DiagnosticsReport(db: db)
            CatalogScreen(db: db, showsIcons: false)
            CatalogScreen.IconSheet(db: db)
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STARTER TIER")
                .font(DexFont.retro(9))
                .foregroundStyle(Dex.green)

            Button {
                Haptics.select()
                access.starterOnly.toggle()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: access.starterOnly ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(access.starterOnly ? Dex.yellow : Dex.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(access.starterOnly ? "STARTER — 25 GRAPES" : "EVERYTHING UNLOCKED")
                            .font(DexFont.retro(10))
                            .tracking(1)
                            .foregroundStyle(Dex.stone200)
                        Text(access.starterOnly
                            ? "\(freeCount) of \(totalCount) entries browsable"
                            : "All \(totalCount) entries browsable")
                            .font(DexFont.mono(15))
                            .foregroundStyle(Dex.stone600)
                    }
                    Spacer(minLength: 0)
                    // A switch-like track, drawn rather than a UISwitch so it
                    // matches the rest of the panel.
                    Capsule()
                        .fill(access.starterOnly ? Dex.yellow : Dex.stone700)
                        .frame(width: 42, height: 24)
                        .overlay(alignment: access.starterOnly ? .trailing : .leading) {
                            Circle()
                                .fill(.white)
                                .frame(width: 18, height: 18)
                                .padding(3)
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Dex.stone800))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Dex.stone700, lineWidth: 1)
                )
            }
            .buttonStyle(DexPressStyle(scale: 0.98))
            .padding(.bottom, 10)

            Text("CHASSIS SKIN")
                .font(DexFont.retro(9))
                .foregroundStyle(Dex.green)

            HStack(spacing: 0) {
                ForEach(ChassisSkin.allCases) { option in
                    Button {
                        Haptics.select()
                        skinRaw = option.rawValue
                    } label: {
                        HStack(spacing: 8) {
                            // A chip of the actual moulding colour, so the
                            // choice is legible without applying it first.
                            RoundedRectangle(cornerRadius: 3)
                                .fill(option.body)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(option.panelEdge, lineWidth: 1)
                                )
                            Text(option.rawValue)
                                .font(DexFont.retro(9))
                        }
                        .foregroundStyle(skin == option ? .black : Dex.stone400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(skin == option ? Dex.green : Dex.stone800)
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Dex.stone700, lineWidth: 1)
            )
            .padding(.bottom, 6)


            Text("SCRATCH FIELD")
                .font(DexFont.retro(9))
                .foregroundStyle(Dex.green)

            HStack(spacing: 8) {
                DexSearchField(text: $scratch, placeholder: "TYPE HERE...", fontSize: 20)
                    .frame(height: 30)
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(Capsule().fill(.black))
            .overlay(Capsule().strokeBorder(Dex.stone600, lineWidth: 2))

            Text("Placeholder. Real settings land here once there is something worth persisting.")
                .font(DexFont.mono(17))
                .foregroundStyle(Dex.stone600)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
