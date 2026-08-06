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
///
/// **`flatten` is the one exception, and it is a different operation (0.8.3,
/// A).** The marquee asks for two opposite treatments of the same drop on the
/// same surface: the page glyph flat black (A), the status lamps in their own
/// colours (H). Those cannot both be defaults, so the flat one is opt-in and
/// the coloured one is what every existing caller keeps.
///
/// It is a **silhouette**, not a tint — `.renderingMode(.template)` discards
/// everything but alpha and fills the result with one colour. That is exactly
/// wrong for `ChassisCapLoader`'s problem, where a moulded cap with a rim and a
/// cast shadow would collapse to a solid disc, and it is exactly right for
/// this one: the marquee's glyph has always been a filled SF Symbol on a lit
/// panel, so a filled silhouette of the button face is the same object drawn
/// from a better outline. Do not reach for this to re-colour art — that is
/// `ChassisCapLoader`, which keeps every pixel's value and takes only the hue.
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
    /// Draw the art as a solid silhouette in this colour instead of its own
    /// (0.8.3, A). Nil keeps the drawing, which is every caller but one.
    ///
    /// Applies to the art only. The symbol fallback still takes `tint`, so a
    /// route with no face keeps whatever ink its surface was already giving it
    /// rather than being quietly recruited into the flat treatment.
    var flatten: Color?
    /// Resample smoothly instead of nearest-neighbour (0.8.4, A1).
    ///
    /// **Off everywhere but the marquee, and the exception is not a preference.**
    /// `.interpolation(.none)` is the house rule for `art:` ids and for every
    /// drawn face, and the argument behind it is that these are pixel art: the
    /// pixels sit on a grid the illustrator drew, and any filter smears that
    /// grid.
    ///
    /// The marquee glyphs are not on a grid. They are antialiased *circles* —
    /// a dot-matrix drawing at roughly 145px, where the dot is the unit and the
    /// pixel is just how it was stored. Fitted into `DexMetrics.marqueeGlyph`
    /// they land near 0.7 scale, and nearest-neighbour at 0.7 does not preserve
    /// a grid there, it drops every third row and column: the dots come out
    /// different sizes from each other, which reads as the glyph being damaged
    /// rather than as it being pixellated. Smooth resampling keeps them round
    /// and keeps them equal.
    ///
    /// This is also why the rule can be relaxed here without arguing about it
    /// elsewhere — nothing else in the app draws circles.
    var smoothing: Bool = false

    init(
        _ stem: String,
        symbol: String,
        size: CGFloat,
        weight: Font.Weight = .semibold,
        tint: Color? = nil,
        flatten: Color? = nil,
        smoothing: Bool = false
    ) {
        self.stem = stem
        self.symbol = symbol
        self.size = size
        self.weight = weight
        self.tint = tint
        self.flatten = flatten
        self.smoothing = smoothing
    }

    var body: some View {
        Group {
            if let art = PixelArtLoader.shared.image(stem) {
                // Two branches rather than one with a conditional
                // `foregroundStyle`: a style applied over `.original` is
                // ignored today and is not documented to be, and the failure if
                // it ever stopped being ignored is every drawn face in the app
                // turning one colour.
                if let flatten {
                    Image(uiImage: art)
                        .interpolation(smoothing ? .high : .none)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(flatten)
                } else {
                    Image(uiImage: art)
                        // Pixel art: every pixel is an authored decision, and any
                        // filter smears the grid it was drawn on. Same rule
                        // `DexIcon` applies to its `art:` branch. See `smoothing`
                        // for the one drop this is wrong for.
                        .interpolation(smoothing ? .high : .none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
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
