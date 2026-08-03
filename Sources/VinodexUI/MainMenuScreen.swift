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
    /// Drives the TODAY strip's done-state and streak count (AUDIT M23).
    @State private var streak = StreakStore.shared

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
                    tile("GRAPES", symbol: "circle.grid.3x3.fill", livery: .violet) {
                        onSelect(.list(category: .grapes, filter: nil))
                    }
                    tile("REGIONS", symbol: "globe.americas.fill", livery: .green) {
                        onSelect(.globe)
                    }
                }

                searchButton

                HStack(spacing: 10) {
                    // Matches the web app's own STYLES button, which uses
                    // lucide's `Wine` (MainMenu.tsx). This was
                    // `square.stack.3d.up.fill` — a layers glyph that had no
                    // counterpart on the web side. SF Symbols 4 / iOS 16, so
                    // it clears the iOS 17 deployment target.
                    tile("STYLES", symbol: "wineglass.fill", livery: .orange) {
                        onSelect(.list(category: .styles, filter: nil))
                    }
                    tile("FLAVORS", symbol: "leaf.fill", livery: .emerald) {
                        onSelect(.list(category: .flavors, filter: nil))
                    }
                }

                todayStrip
            }
            .padding(8)
        }
    }

    /// The day's two returning features, and the streak they feed.
    ///
    /// Both used to be reachable only through the cog, then TOOLS, then a tile
    /// — three taps down a path nobody walks daily — which meant the app's only
    /// reasons to come back tomorrow were invisible from the screen you land
    /// on. The streak was worse still: it was printed on the profile, so the
    /// number counting your consecutive days could not be seen without going
    /// looking for it. (AUDIT **M23**)
    ///
    /// A strip rather than a fifth tile: the four categories are what this app
    /// *is*, and demoting one of them to make room for a minigame would trade
    /// a worse problem for this one. The tiles are `maxHeight: .infinity`, so
    /// the strip's fixed height is the only thing they give up.
    private var todayStrip: some View {
        HStack(spacing: 8) {
            dailyPill(
                title: "WHAT'S THAT?",
                symbol: "questionmark.circle.fill",
                // The reveal is session state cleared on Home (see
                // `DailyGrapeScreen`), so unlike the challenge there is no
                // honest "done today" to show here.
                done: false,
                badge: nil
            ) { onSelect(.dailyGrape) }

            dailyPill(
                title: "CHALLENGE",
                symbol: "target",
                done: streak.isTodayDone(),
                badge: streak.current > 0 ? streak.current : nil
            ) { onSelect(.dailyChallenge) }
        }
        .frame(height: 54)
    }

    /// One TODAY button. Deliberately in the LCD's own livery rather than the
    /// tiles' painted plastic: these are secondary to the four categories, and
    /// four bright tiles plus two more would read as six equals.
    private func dailyPill(
        title: String,
        symbol: String,
        done: Bool,
        badge: Int?,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: done ? "checkmark.circle.fill" : symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(done ? Dex.green : mode.accent)
                Text(title)
                    .font(DexFont.retro(11))
                    .tracking(1)
                    .foregroundStyle(mode.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                if let badge {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(badge)")
                            .font(DexFont.retro(11))
                    }
                    .foregroundStyle(Dex.yellow)
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DexMetrics.menuTileCorner)
                    .fill(mode.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DexMetrics.menuTileCorner)
                    .strokeBorder(mode.surfaceEdge, lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
        // Spoken as one thing, with the state the glyphs carry visually — a
        // tick and a flame say nothing out loud on their own.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [
                title,
                done ? "done today" : nil,
                badge.map { "\($0) day streak" },
            ].compactMap { $0 }.joined(separator: ", ")
        )
    }

    /// A category tile.
    ///
    /// The livery is a token rather than a pair of hex literals at the call
    /// site (AUDIT **L33**). Two consequences beyond tidiness: the four faces
    /// here and the settings grid's six were the same seven colours written
    /// twice, and these four had no light-mode value at all — a bright face on
    /// the pale page, which is precisely the class of miss the item names.
    /// See `DexTileLivery`.
    private func tile(
        _ title: String,
        symbol: String,
        livery: DexTileLivery,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            // Sized up in 0.6.1, then eased back a notch (0.6.2, B1) — 64pt
            // glyphs crowded the tile edges at the LARGE text scale.
            VStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(livery.ink)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2)
                Text(title)
                    .font(DexFont.retro(19))
                    .foregroundStyle(livery.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 1, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DexMetrics.menuTileCorner)
                    .fill(livery.face(mode))
                    .overlay(alignment: .bottom) {
                        // The web tiles use a 6px bottom border as a fake extrusion.
                        livery.shadow(mode).frame(height: 6)
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

    /// v0.5.3: the search button wears the mode's control livery, like the
    /// chassis buttons around it — in DARK that resolves to the same amber
    /// it has always been.
    private var searchButton: some View {
        Button {
            Haptics.tap()
            onSelect(.masterSearch)
        } label: {
            ZStack {
                Circle().fill(mode.controlAccent.bright)
                Circle().strokeBorder(mode.controlAccent.mid, lineWidth: 6)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(mode.controlAccent.ink)
            }
            .frame(width: 102, height: 102)
            .shadow(color: mode.controlAccent.bright.opacity(0.4), radius: 12)
        }
        .buttonStyle(DexPressStyle(scale: 0.95))
        // Tight to the circle; extra height was dead space between rows.
        .frame(height: 102)
    }
}
#endif
