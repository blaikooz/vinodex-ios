#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The device's own menu: SETTINGS, DIAGNOSTICS and the debug CATALOG.
///
/// Presented inside the LCD rather than as a `.sheet`. A sheet slides over the
/// whole chassis, which breaks the device metaphor — the bezel, footer and
/// island strip are meant to be physical furniture that never moves. Confining
/// the panel to the screen keeps that intact and makes it read as the device
/// showing a menu rather than iOS showing a modal.
public struct SettingsPanel: View {
    public enum Tab: String, CaseIterable, Identifiable {
        case settings = "SETTINGS"
        case diagnostics = "DIAGNOSTICS"
        case catalog = "CATALOG"

        public var id: String { rawValue }
    }

    let onClose: () -> Void
    let onFlip: () -> Void

    @State private var tab: Tab = .settings
    /// Placeholder until there is something real to configure.
    @State private var scratch = ""
    /// Same key `DeviceChassis` reads, so the chassis repaints as this changes.
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue

    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }

    private let db = WineDatabase.shared

    public init(onClose: @escaping () -> Void, onFlip: @escaping () -> Void) {
        self.onClose = onClose
        self.onFlip = onFlip
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            tabBar

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab {
                    case .settings: settings
                    case .diagnostics: DiagnosticsReport(db: db)
                    case .catalog: CatalogScreen(db: db)
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

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            Button {
                Haptics.tap()
                onFlip()
            } label: {
                HStack(spacing: 10) {
                    // Available since iOS 13; the trianglehead variants are 18+
                    // and would render blank on the iOS 17 target.
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .bold))
                    Text("FLIP DEVICE")
                        .font(DexFont.retro(11))
                        .tracking(2)
                    Spacer(minLength: 0)
                    Text("SEE BACK PLATE")
                        .font(DexFont.mono(16))
                        .foregroundStyle(Dex.stone600)
                }
                .foregroundStyle(Dex.stone200)
                .padding(.horizontal, 12)
                .frame(height: 46)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(
                        LinearGradient(
                            colors: [Dex.stone700, Dex.stone900],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Dex.stone400.opacity(0.6), lineWidth: 2)
                )
            }
            .buttonStyle(DexPressStyle(scale: 0.97))
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
