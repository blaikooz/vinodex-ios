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
                    tile("GRAPES", art: "grapes", symbol: "circle.grid.3x3.fill",
                         face: "#a855f7", shadow: "#6b21a8") {
                        onSelect(.list(category: .grapes, filter: nil))
                    }
                    tile("REGIONS", art: "regions", symbol: "globe.americas.fill",
                         face: "#22c55e", shadow: "#15803d") {
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
                    tile("STYLES", art: "styles", symbol: "wineglass.fill",
                         face: "#f97316", shadow: "#9a3412") {
                        onSelect(.list(category: .styles, filter: nil))
                    }
                    tile("FLAVORS", art: "flavors", symbol: "leaf.fill",
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
        art: String,
        symbol: String,
        face: String,
        shadow: String,
        action: @escaping () -> Void
    ) -> some View {
        // C5 (0.7.1): under an Emulator mode the four category faces fold
        // toward that machine's ramp, so the menu stops being four Tailwind
        // squares bolted to a starship console. Untouched everywhere else.
        let paint = mode.chrome(face: face, shadow: shadow)
        let label = mode.chromeInk(over: face, preferring: .white)

        return Button {
            Haptics.screenTap()
            action()
        } label: {
            // Sized up in 0.6.1, then eased back a notch (0.6.2, B1) — 64pt
            // glyphs crowded the tile edges at the LARGE text scale.
            VStack(spacing: 13) {
                DexChromeGlyph(art, symbol: symbol, size: 56, tint: label)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2)
                    // **The fixed glyph box is what aligns the four titles**
                    // (0.8.0, L). The report was that STYLES and FLAVORS sit off
                    // the baseline the other two share, and the cause is not in
                    // this `VStack` or in either of those tiles: an
                    // `Image(systemName:)` lays out at the *symbol's own*
                    // bounding box, and four SF Symbols at one point size are
                    // four different heights. `wineglass.fill` is tall and
                    // narrow, `leaf.fill` is squat, `circle.grid.3x3.fill` and
                    // `globe.americas.fill` are both near-square — so each stack
                    // was a different total height, each centred in its own tile,
                    // and the labels landed at four different y positions. The
                    // two square glyphs agreeing with each other is what made it
                    // look like a fault in the other two.
                    //
                    // 56, the same number as the point size, so a glyph that
                    // happens to be exactly square is unmoved and every other one
                    // centres inside the box it would have filled. `frame` does
                    // not clip, so a symbol taller than its nominal size still
                    // draws whole — it simply stops charging the stack for it.
                    // Fixing it here rather than per tile is the point: the fifth
                    // tile anybody adds is aligned by default.
                    //
                    // **The box outlived the symbols (0.8.1, J3).** These four
                    // are drawn button faces now, and bitmaps have a fixed
                    // aspect of their own that is not the symbol's — `styles`
                    // is 134x216 and `flavors` is 215x198. Left to itself a
                    // raster swap would have re-broken exactly what L fixed, in
                    // the same place, for a different reason.
                    // `DexChromeGlyph` fits inside a square of this size, so
                    // the box below is now redundant rather than wrong: kept
                    // because a fifth tile added with a plain symbol still
                    // needs it, and because deleting the guard is how the bug
                    // comes back.
                    .frame(height: 56)
                Text(title)
                    .font(DexFont.retro(19))
                    .foregroundStyle(label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 1, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DexMetrics.menuTileCorner)
                    .fill(paint.face)
                    .overlay(alignment: .bottom) {
                        // The web tiles use a 6px bottom border as a fake extrusion.
                        paint.shadow.frame(height: 6)
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
    ///
    /// **It opens MASTER SEARCH.** Since 0.7.0 (I1) the destination is
    /// `.chipFilter`, which used to be called FILTER SEARCH: a text field over
    /// the whole database (the identical `.masterSearch(_:)` query the retired
    /// route ran) *plus* the chips and a live surviving-count. It is a strict
    /// superset, so the menu's most prominent control leads to the better of
    /// the two; 0.7.1's A1 finished the job by giving it the name.
    ///
    /// **The glyph is the magnifier again (0.7.1, A2).** 0.7.0 swapped it for
    /// `line.3.horizontal.decrease` so the change of destination would be
    /// visible from the one screen it happens on. That was right for one
    /// release and wrong as a resting state: filter bars are a statement about
    /// a list you are already looking at, and this is the way *in*. A2 puts
    /// every search affordance in the app on `DexGlyph.search`, and this is the
    /// largest one. The bare form, not `.circle.fill` — a glyph with its own
    /// circle inside a 102pt circle reads as a button drawn twice.
    private var searchButton: some View {
        Button {
            Haptics.screenTap()
            onSelect(.chipFilter)
        } label: {
            ZStack {
                Circle().fill(mode.controlAccent.bright)
                Circle().strokeBorder(mode.controlAccent.mid, lineWidth: 6)
                DexChromeGlyph(
                    "search",
                    symbol: DexGlyph.search,
                    size: 40,
                    weight: .bold,
                    tint: mode.controlAccent.ink
                )
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
