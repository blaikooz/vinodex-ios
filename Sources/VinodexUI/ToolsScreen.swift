#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The tools hub.
///
/// This began as MINIGAMES, when the daily reveal was promoted out of the
/// settings list and needed a shelf of its own. It has since collected things
/// with no play in them at all — IDENTIFY is an identification aid, LABEL SCAN
/// will be another — so the name was promising the wrong thing to anyone
/// looking for either. TOOLS covers both; a game is a tool you use for fun.
///
/// **The shelf is still six tiles** (0.7.0, I1/I2). FILTER SEARCH left it,
/// because the main menu's big round button is the filter search now and a tool
/// reachable two ways from one screen is a tool nobody can find; LABEL SCAN took
/// the empty square. Six keeps the fixed three-row grid that fills the LCD
/// without scrolling, which is the layout's whole contract.
///
/// Tiles match the main menu's deliberately — filled faces with the fake
/// extrusion, not outlines — so every grid of big square buttons in the app
/// reads as the same furniture.
public struct ToolsScreen: View {
    let onDailyGrape: () -> Void
    let onScanner: () -> Void
    let onMoonDial: () -> Void
    let onQuiz: () -> Void
    let onDailyChallenge: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(
        onDailyGrape: @escaping () -> Void,
        onScanner: @escaping () -> Void = {},
        onMoonDial: @escaping () -> Void = {},
        onQuiz: @escaping () -> Void = {},
        onDailyChallenge: @escaping () -> Void = {}
    ) {
        self.onDailyGrape = onDailyGrape
        self.onScanner = onScanner
        self.onMoonDial = onMoonDial
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
                    //
                    // **IDENTIFY, not SCANNER** (0.7.0, I3). A UI-string rename
                    // only, per house convention: `DexRoute.scanner`,
                    // `ScannerScreen` and `ScannerBackRouter` all keep their
                    // names, and nothing persisted moves. The old label named
                    // the mechanism, and on a device where every listing is
                    // already called a *scan* it named the wrong one — this is
                    // the tool that tells you what is in the glass.
                    tile(
                        title: "IDENTIFY",
                        symbol: "sparkle.magnifyingglass",
                        face: "#22c55e", shadow: "#15803d",
                        action: onScanner
                    )
                    // **LABEL SCAN, coming soon** (0.7.0, I2). No action and no
                    // route: `comingSoon` is the country gates' own treatment
                    // (see `DexEmptyState` / the gated country rows), reused
                    // rather than a second disabled style invented here.
                    tile(
                        title: "LABEL\nSCAN",
                        symbol: "camera.viewfinder",
                        face: "#64748B", shadow: "#334155",
                        comingSoon: true,
                        action: {}
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
                        symbol: DexGlyph.streakFlame,
                        face: "#ef4444", shadow: "#991b1b",
                        action: onDailyChallenge
                    )
                }
                HStack(spacing: 10) {
                    // Named for the question it asks rather than for its pick:
                    // the reveal rotates through regions and styles as well as
                    // grapes, so "grape of the day" was wrong two days in three.
                    //
                    // Both run white ink now (0.6.4, E1), matching the other
                    // four tiles — the dark inks made this row read as a
                    // different kind of button. Their faces deepen a step each
                    // (yellow → amber, pale cyan → cyan) so white still
                    // clears them; the old pale faces were the whole reason
                    // for the dark ink.
                    tile(
                        title: "WHAT'S\nTHAT…?",
                        symbol: "sparkles",
                        face: "#EAB308", shadow: "#a16207",
                        action: onDailyGrape
                    )
                    tile(
                        title: "MOON DIAL",
                        symbol: "moon.stars.fill",
                        face: "#0891B2", shadow: "#155e75",
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
    ///
    /// `comingSoon` marks a tile that is announced but not built (0.7.0, I2).
    ///
    /// The same three ideas the country gates settled on: the row still exists
    /// and still *looks like* what it will be, its ink dims, and it says COMING
    /// SOON in words. Not `.disabled()` — a dead tile that has gone grey is
    /// indistinguishable from a paywalled one and from a bug, which is the
    /// distinction `ContinentScreen`'s note spends a paragraph on. It stays
    /// tappable and does nothing, because there is nothing yet to explain that
    /// the label has not already said.
    private func tile(
        title: String,
        symbol: String,
        face: String,
        shadow: String,
        ink: Color = .white,
        comingSoon: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.screenTap()
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
                if comingSoon {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 9, weight: .bold))
                        Text("COMING SOON")
                            .font(DexFont.retro(7))
                            .tracking(1)
                    }
                    .foregroundStyle(ink.opacity(0.85))
                    .accessibilityLabel("Coming soon — not built yet")
                }
            }
            .opacity(comingSoon ? 0.62 : 1)
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
