#if canImport(SwiftUI)
import SwiftUI

/// A chrome glyph: the drawn button face if there is one, the SF Symbol if
/// there is not (0.8.1, J3).
///
/// **The box is the point.** `Image(systemName:)` lays out at the symbol's own
/// bounding box, which is why 0.8.0's L had to introduce a fixed 56pt frame
/// before the four menu tiles would share a baseline — four symbols were four
/// heights. The 32 button faces make that worse rather than better: they run
/// from 0.62 (`styles`, 134x216) to 1.88 (`cheatcodes`, 231x123), so swapping
/// a symbol for a bitmap in place would have re-broken every alignment the app
/// has, silently, one control at a time.
///
/// So this never lays out at the art's size. It takes a square `size`, fits the
/// art inside it, and letterboxes whatever is left over. A row of these is
/// aligned by construction whatever is drawn in them, which is the same
/// guarantee the 56pt box gives and the reason that box survives item H.
///
/// **Falling back is a feature, not a gap.** `art` is nil for any stem with no
/// PNG, and the symbol renders instead — so the conversion can be partial
/// without any control being blank, and a stem typed wrong degrades to the icon
/// that was there before rather than to nothing. `IconLoader.image` returning
/// nil silently is the fault this shape is written around: `PixelArtLoader`
/// does the same, and the only defence is never to depend on it succeeding.
///
/// Tinting is deliberately *not* applied to the art. These faces ship their own
/// colours, the same rule `DexIcon` follows for `art:` ids; `tint` colours the
/// symbol fallback only, so a converted control and an unconverted one still
/// look like they belong to the same app.
struct DexChromeGlyph: View {
    /// The button-art stem, e.g. `"backarrow"`. Also the fallback's SF Symbol
    /// name when `symbol` is not given separately.
    let stem: String
    /// The SF Symbol to draw when there is no art for `stem`.
    let symbol: String
    /// The square the glyph is fitted into. Both dimensions, always.
    var size: CGFloat
    var weight: Font.Weight = .semibold
    var tint: Color?

    init(_ stem: String, symbol: String, size: CGFloat, weight: Font.Weight = .semibold, tint: Color? = nil) {
        self.stem = stem
        self.symbol = symbol
        self.size = size
        self.weight = weight
        self.tint = tint
    }

    var body: some View {
        Group {
            if let art = PixelArtLoader.shared.image(stem) {
                Image(uiImage: art)
                    // Pixel art: every pixel is an authored decision, and any
                    // filter smears the grid it was drawn on. Same rule
                    // `DexIcon` applies to its `art:` branch.
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size, weight: weight))
                    .foregroundStyle(tint ?? .primary)
            }
        }
        .frame(width: size, height: size)
    }
}
#endif
