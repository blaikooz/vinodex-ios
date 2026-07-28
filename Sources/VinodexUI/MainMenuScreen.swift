#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// Four category tiles around a central search button.
///
/// Slimmed from the web app's menu: the moon-dial and separate globe buttons are
/// out of scope, and REGIONS opens the globe directly rather than a 2D map.
public struct MainMenuScreen: View {
    let onSelect: (DexRoute) -> Void

    public init(onSelect: @escaping (DexRoute) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            VStack(spacing: 12) {
                HStack(spacing: 14) {
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

                HStack(spacing: 14) {
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
            .padding(14)
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(dexHex: face))
                    .overlay(alignment: .bottom) {
                        // The web tiles use a 6px bottom border as a fake extrusion.
                        Color(dexHex: shadow).frame(height: 6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
        .frame(height: 96)
    }
}
#endif
