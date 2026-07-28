#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// Four category tiles around a central search button.
///
/// Slimmed from the web app's menu: the moon-dial and separate globe buttons are
/// out of scope, and REGIONS opens the globe directly rather than a 2D map.
public struct MainMenuScreen: View {
    let onSelect: (DexRoute) -> Void

    /// `DexFont` applies the text scale globally; this is here only so the
    /// view re-renders when it changes.
    @AppStorage(TextScale.storageKey) private var scaleRaw = TextScale.small.rawValue
    @AppStorage(LcdMode.storageKey) private var modeRaw = LcdMode.dark.rawValue

    private var mode: LcdMode { LcdMode(rawValue: modeRaw) ?? .dark }

    public init(onSelect: @escaping (DexRoute) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            // Tightened so the tiles claim more of the LCD. Kept at 8/10pt
            // rather than zero: the tiles carry a 6pt fake extrusion on their
            // bottom edge, and butting them together loses that read.
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    tile("GRAPES", symbol: "circle.grid.3x3.fill",
                         face: "#a855f7", shadow: "#6b21a8") {
                        onSelect(.list(category: .grapes, filter: nil))
                    }
                    tile("REGIONS", symbol: "globe.americas.fill",
                         face: "#22c55e", shadow: "#15803d") {
                        onSelect(.globe)
                    }
                }

                searchButton

                HStack(spacing: 10) {
                    tile("STYLES", symbol: "square.stack.3d.up.fill",
                         face: "#f97316", shadow: "#9a3412") {
                        onSelect(.list(category: .styles, filter: nil))
                    }
                    tile("FLAVORS", symbol: "leaf.fill",
                         face: "#10b981", shadow: "#065f46") {
                        onSelect(.list(category: .flavors, filter: nil))
                    }
                }
            }
            .padding(8)
        }
    }

    private func tile(
        _ title: String,
        symbol: String,
        face: String,
        shadow: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2)
                Text(title)
                    .font(DexFont.retro(16))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 1, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DexMetrics.menuTileCorner)
                    .fill(Color(dexHex: face))
                    .overlay(alignment: .bottom) {
                        // The web tiles use a 6px bottom border as a fake extrusion.
                        Color(dexHex: shadow).frame(height: 6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DexMetrics.menuTileCorner))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DexMetrics.menuTileCorner)
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

    private var searchButton: some View {
        Button {
            Haptics.tap()
            onSelect(.masterSearch)
        } label: {
            ZStack {
                Circle().fill(Dex.yellow)
                Circle().strokeBorder(Dex.yellow600, lineWidth: 6)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Dex.amber900)
            }
            .frame(width: 92, height: 92)
            .shadow(color: Dex.yellow.opacity(0.4), radius: 12)
        }
        .buttonStyle(DexPressStyle(scale: 0.95))
        // Tight to the 92pt circle; the extra 4pt was dead space between rows.
        .frame(height: 92)
    }
}
#endif
