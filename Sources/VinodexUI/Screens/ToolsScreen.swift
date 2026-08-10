#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The tools hub.
///
/// This began as MINIGAMES, when the daily reveal was promoted out of the
/// settings list and needed a shelf of its own. It has since collected things
/// with no play in them at all — BLIND TASTING is an identification aid and
/// LABEL SCAN is another — so the name was promising the wrong thing to anyone
/// looking for either. TOOLS covers both; a game is a tool you use for fun.
///
/// Both identification tools are real as of 0.7.2: BLIND TASTING deduces from a
/// glass with no label, LABEL SCAN reads the label when there is one. They sit
/// side by side in the top row for that reason.
///
/// **The shelf is still six tiles** (0.7.0, I1/I2). MASTER SEARCH left it — it
/// was called FILTER SEARCH then — because the main menu's big round button is
/// that screen now and a tool reachable two ways from one screen is a tool
/// nobody can find; LABEL SCAN took
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
    let onLabelReader: () -> Void

    // No `settings` here, unlike every other screen (arch **A17**). This one
    // held an `@AppStorage(LcdMode.storageKey)` and an `lcd` derived from it,
    // and *nothing in the body read either* — the six tiles carry authored hex
    // faces and `DexScreenBackground` reads the mode for itself. The
    // declaration was buying a rebuild that produced identical output, so it
    // went with the migration rather than being carried across as a property
    // nothing observes.

    public init(
        onDailyGrape: @escaping () -> Void,
        onScanner: @escaping () -> Void = {},
        onMoonDial: @escaping () -> Void = {},
        onQuiz: @escaping () -> Void = {},
        onDailyChallenge: @escaping () -> Void = {},
        onLabelReader: @escaping () -> Void = {}
    ) {
        self.onDailyGrape = onDailyGrape
        self.onScanner = onScanner
        self.onMoonDial = onMoonDial
        self.onQuiz = onQuiz
        self.onDailyChallenge = onDailyChallenge
        self.onLabelReader = onLabelReader
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
                    // **BLIND TASTING** (0.7.1, E3), after IDENTIFY (0.7.0, I3),
                    // after SCANNER. A UI-string rename each time, per house
                    // convention: `DexRoute.scanner`, `ScannerScreen` and
                    // `ScannerBackRouter` all keep their names, and nothing
                    // persisted moves. SCANNER named the mechanism on a device
                    // where every listing is already a *scan*; IDENTIFY named
                    // the verb; BLIND TASTING names what the four steps are —
                    // colour, body, origin, flavour, with no label in front of
                    // you. The glyph follows E3 out of the magnifier family
                    // (A2 reserves those for search) into the premise itself.
                    tile(
                        title: "BLIND\nTASTING",
                        art: "blindtasting",
                        symbol: "eye.slash.fill",
                        face: "#22c55e", shadow: "#15803d",
                        action: onScanner
                    )
                    // **LABEL SCAN, built** (0.7.2, LR1). Announced as COMING
                    // SOON in 0.7.0 (I2) and given its route here: point the
                    // camera at a bottle, read the label on-device, match it
                    // against the catalog. See `LabelReaderView`.
                    //
                    // Off the placeholder slate and onto a face of its own now
                    // that it does something — the grey was the COMING SOON
                    // treatment, not this tool's colour.
                    //
                    // **Blue, because it is the one hue the shelf was not
                    // already using.** The other five are green, purple, red,
                    // amber and cyan, and the six squares are meant to be told
                    // apart at a glance from the far side of a table; an amber
                    // here (tried first) sat a few points from WHAT'S THAT…?'s
                    // `#EAB308` and turned the grid into two pairs. White ink
                    // clears `#3B82F6` comfortably, so this needs none of the
                    // dark-ink handling the yellow and cyan faces once did.
                    tile(
                        title: "LABEL\nSCAN",
                        art: "labelscanner",
                        symbol: "camera.viewfinder",
                        face: "#3B82F6", shadow: "#1d4ed8",
                        action: onLabelReader
                    )
                }
                // The quiz family sits together: the practice ladder, then
                // the one paper a day that keeps the streak.
                HStack(spacing: 10) {
                    tile(
                        title: "WINE\nEXAM",
                        art: "wineexam",
                        symbol: "checkmark.seal.fill",
                        face: "#a855f7", shadow: "#6b21a8",
                        action: onQuiz
                    )
                    tile(
                        title: "DAILY\nCHALLENGE",
                        art: "dailychallenge",
                        symbol: DexGlyph.challenge,
                        face: "#ef4444", shadow: "#991b1b",
                        action: onDailyChallenge
                    )
                }
                HStack(spacing: 10) {
                    // Named for the question it asks rather than for its pick:
                    // the answer is a region as often as a grape, so "grape of
                    // the day" was wrong half the time.
                    //
                    // **The tile is unchanged in 0.7.9 (B) and the screen is
                    // not.** What used to be a silhouette and a REVEAL button is
                    // a clue-by-clue guessing round now (`WhatsThatScreen`); the
                    // title was already the question the game asks, which is why
                    // replacing the feature cost this shelf nothing.
                    //
                    // Both run white ink now (0.6.4, E1), matching the other
                    // four tiles — the dark inks made this row read as a
                    // different kind of button. Their faces deepen a step each
                    // (yellow → amber, pale cyan → cyan) so white still
                    // clears them; the old pale faces were the whole reason
                    // for the dark ink.
                    tile(
                        title: "WHAT'S\nTHAT…?",
                        art: "whatsthat",
                        symbol: "sparkles",
                        face: "#EAB308", shadow: "#a16207",
                        action: onDailyGrape
                    )
                    tile(
                        title: "MOON DIAL",
                        art: "moondial",
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
    /// **No tile passes it as of 0.7.2** — LABEL SCAN was the only one and it is
    /// built now. Kept rather than deleted because it is not a flag, it is a
    /// documented treatment that the country gates and this shelf agreed on, and
    /// the next announced-but-unbuilt tool would otherwise have to re-derive the
    /// three rules below from scratch.
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
        art: String,
        symbol: String,
        face: String,
        shadow: String,
        ink: Color = .white,
        comingSoon: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        // C5 (0.7.1): the hand-picked pair goes in, the screen mode decides
        // what comes out. A no-op on every mode outside EMULATOR — see
        // `LcdMode.chrome(face:shadow:)`.
        let paint = lcd.chrome(face: face, shadow: shadow)
        let label = lcd.chromeInk(over: face, preferring: ink)

        return Button {
            Haptics.screenTap()
            action()
        } label: {
            VStack(spacing: 12) {
                // Drawn faces since 0.8.1 (J3), in a square box for the
                // reason the menu tiles keep theirs: six bitmaps at six
                // aspects would otherwise be six tile heights.
                DexChromeGlyph(art, symbol: symbol, size: 44, tint: label)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2)
                Text(title)
                    .font(DexFont.retro(13))
                    .tracking(1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(label)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 1, y: 1)
                if comingSoon {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 9, weight: .bold))
                        // `retro(10)`, not `retro(7)` (0.7.1, A4).
                        // `TypeScale.nominalFloor` is 10 and is applied
                        // *before* the scale factor, so this has never
                        // rendered at 7 — the source was understating what
                        // ships by 43%, which is how eleven characters plus
                        // tracking plus the hourglass came to need 150.5pt in
                        // a 150.5pt tile and wrapped to COMING / SOON,
                        // unbalancing the six-tile grid on anything narrower.
                        // The size now says what it draws, and the guards the
                        // title above already had are here too.
                        Text("COMING SOON")
                            .font(DexFont.retro(10))
                            .tracking(1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(label.opacity(0.85))
                    .accessibilityLabel("Coming soon — not built yet")
                }
            }
            .opacity(comingSoon ? 0.62 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(paint.face)
                    .overlay(alignment: .bottom) {
                        // The same 6pt fake extrusion the menu tiles carry.
                        paint.shadow.frame(height: 6)
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
