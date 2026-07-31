#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The tools hub.
///
/// This began as MINIGAMES, when the daily reveal was promoted out of the
/// settings list and needed a shelf of its own. It has since collected two
/// things with no play in them at all — the scanner is an identification aid and
/// the filter search is a query builder — so the name was promising the wrong
/// thing to anyone looking for either. TOOLS covers both; a game is a tool you
/// use for fun.
///
/// Tiles match the main menu's deliberately — filled faces with the fake
/// extrusion, not outlines — so every grid of big square buttons in the app
/// reads as the same furniture.
public struct ToolsScreen: View {
    let onDailyGrape: () -> Void
    let onScanner: () -> Void
    let onMoonDial: () -> Void
    let onChipFilter: () -> Void
    let onQuiz: () -> Void
    let onDailyChallenge: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(
        onDailyGrape: @escaping () -> Void,
        onScanner: @escaping () -> Void = {},
        onMoonDial: @escaping () -> Void = {},
        onChipFilter: @escaping () -> Void = {},
        onQuiz: @escaping () -> Void = {},
        onDailyChallenge: @escaping () -> Void = {}
    ) {
        self.onDailyGrape = onDailyGrape
        self.onScanner = onScanner
        self.onMoonDial = onMoonDial
        self.onChipFilter = onChipFilter
        self.onQuiz = onQuiz
        self.onDailyChallenge = onDailyChallenge
    }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            // A fixed three-row grid that fills the LCD (v0.5.6), like the
            // settings grid — six tools, no scrolling.
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    // The two that answer a question about a specific glass go
                    // first — they are the reason to open this screen while
                    // actually drinking something.
                    tile(
                        title: "SCANNER",
                        symbol: "sparkle.magnifyingglass",
                        face: "#22c55e", shadow: "#15803d",
                        action: onScanner
                    )
                    tile(
                        title: "FILTER\nSEARCH",
                        symbol: "line.3.horizontal.decrease.circle.fill",
                        face: "#2AB5FF", shadow: "#136A99",
                        action: onChipFilter
                    )
                }
                // The quiz family sits together: the practice ladder, then
                // the one paper a day that keeps the streak.
                HStack(spacing: 10) {
                    tile(
                        title: "WINE\nEXAM",
                        symbol: "checkmark.seal.fill",
                        face: "#a855f7", shadow: "#6b21a8",
                        action: onQuiz
                    )
                    tile(
                        title: "DAILY\nCHALLENGE",
                        symbol: "flame.fill",
                        face: "#ef4444", shadow: "#991b1b",
                        action: onDailyChallenge
                    )
                }
                HStack(spacing: 10) {
                    // Named for the question it asks rather than for its pick:
                    // the reveal rotates through regions and styles as well as
                    // grapes, so "grape of the day" was wrong two days in three.
                    tile(
                        title: "WHAT'S\nTHAT…?",
                        symbol: "sparkles",
                        face: "#FACC15", shadow: "#ca8a04", ink: Dex.amber900,
                        action: onDailyGrape
                    )
                    tile(
                        title: "MOON DIAL",
                        symbol: "moon.stars.fill",
                        face: "#67e8f9", shadow: "#155e75", ink: Color(dexHex: "#164e63"),
                        action: onMoonDial
                    )
                }
            }
            .padding(12)
        }
    }

    /// The main menu's tile, at tools scale: filled face, 6pt bottom
    /// extrusion, top-left sheen. Yellow and cyan faces take a dark ink —
    /// white on either is unreadable, the same rule the menu's search button
    /// follows.
    private func tile(
        title: String,
        symbol: String,
        face: String,
        shadow: String,
        ink: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(ink)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2)
                Text(title)
                    .font(DexFont.retro(13))
                    .tracking(1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 1, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(dexHex: face))
                    .overlay(alignment: .bottom) {
                        // The same 6pt fake extrusion the menu tiles carry.
                        Color(dexHex: shadow).frame(height: 6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
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
}
#endif
