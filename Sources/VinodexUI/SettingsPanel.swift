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

    @State private var tab: Tab = .settings
    /// Placeholder until there is something real to configure.
    @State private var scratch = ""

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
