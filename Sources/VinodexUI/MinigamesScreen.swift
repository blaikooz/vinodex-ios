#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The minigames hub.
///
/// Grape of the day used to be a row in the settings list, which was the wrong
/// home for it twice over: it is not a setting, and it was the only game so it
/// had nowhere else to go. With the moon dial coming it needs a shelf.
///
/// Tiles match the settings grid deliberately — square, glyph over label — so
/// the two screens reachable from the cog read as one system.
public struct MinigamesScreen: View {
    let onDailyGrape: () -> Void
    let onScanner: () -> Void
    let onMoonDial: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(
        onDailyGrape: @escaping () -> Void,
        onScanner: @escaping () -> Void = {},
        onMoonDial: @escaping () -> Void = {}
    ) {
        self.onDailyGrape = onDailyGrape
        self.onScanner = onScanner
        self.onMoonDial = onMoonDial
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    public var body: some View {
        ZStack {
            DexScreenBackground()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    // Named for the question it asks rather than for its pick:
                    // the reveal rotates through regions and styles as well as
                    // grapes, so "grape of the day" was wrong two days in three.
                    tile(
                        title: "WHAT'S\nTHAT…?",
                        symbol: "sparkles",
                        tint: Dex.yellow,
                        action: onDailyGrape
                    )

                    tile(
                        title: "SCANNER",
                        symbol: "sparkle.magnifyingglass",
                        tint: Dex.green,
                        action: onScanner
                    )

                    tile(
                        title: "MOON DIAL",
                        symbol: "moon.stars.fill",
                        tint: Dex.blue,
                        action: onMoonDial
                    )
                }
                .padding(12)
            }
        }
    }

    private func tile(
        title: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            tileFace(title: title, symbol: symbol, tint: tint)
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
    }

    private func tileFace(title: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2)
            Text(title)
                .font(DexFont.retro(10))
                .tracking(1)
                .multilineTextAlignment(.center)
                .foregroundStyle(lcd.text)
                .lineLimit(2)
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
}
#endif
