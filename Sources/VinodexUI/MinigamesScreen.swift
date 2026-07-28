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

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(onDailyGrape: @escaping () -> Void) {
        self.onDailyGrape = onDailyGrape
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
                    tile(
                        title: "GRAPE OF\nTHE DAY",
                        symbol: "sparkles",
                        tint: Dex.yellow,
                        action: onDailyGrape
                    )

                    // Shown rather than hidden: an empty-looking hub reads as
                    // broken, and the placeholder is what makes it obvious this
                    // screen is a shelf with room on it. Not yet built — see
                    // `web/components/MoonDialScreen.tsx` for the reference.
                    comingSoonTile(title: "MOON DIAL", symbol: "moon.stars.fill")
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

    private func comingSoonTile(title: String, symbol: String) -> some View {
        tileFace(title: title, symbol: symbol, tint: lcd.subtext)
            .overlay(alignment: .topTrailing) {
                Text("SOON")
                    .font(DexFont.retro(8))
                    .tracking(1)
                    .foregroundStyle(Dex.screen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(lcd.subtext))
                    .padding(8)
            }
            .opacity(0.55)
            // Not a disabled Button: there is nothing to press, and a dead
            // button that depresses under the finger promises otherwise.
            .accessibilityLabel("\(title), coming soon")
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
