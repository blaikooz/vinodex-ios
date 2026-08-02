#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// A skin's badge, wherever one is drawn — the picker tile and the back plate's
/// per-skin stamp.
///
/// One view rather than two `Image(systemName: skin.symbol)` call sites, because
/// since 0.6.7 (K1) a skin's emblem is not necessarily a symbol name. PSVino
/// carried `playstation.logo`: a real SF Symbol, and a real registered
/// trademark, which being one API call away does not make ours to ship. It
/// carries `SkinSigil` now — a mark drawn here, from scratch — and every other
/// skin still resolves to its SF Symbol through the same view, so neither call
/// site has to know which kind it is holding.
struct SkinEmblem: View {
    let skin: ChassisSkin
    /// The glyph's nominal size. The drawn mark is sized to the same box as the
    /// symbol it replaces rather than to its own idea of a good size, so
    /// swapping one for the other does not move the layout.
    var size: CGFloat
    var tint: Color
    var weight: Font.Weight = .semibold

    var body: some View {
        Group {
            switch skin.drawnMark {
            case .sigil:
                SkinSigil()
                    .stroke(tint, style: StrokeStyle(lineWidth: max(size * 0.11, 1.4), lineJoin: .round))
                    .frame(width: size, height: size)
            case nil:
                Image(systemName: skin.symbol)
                    .font(.system(size: size, weight: weight))
                    .foregroundStyle(tint)
            }
        }
    }
}

/// **The Vinodex sigil** — an original maker's mark (0.6.7, K1).
///
/// Drawn rather than borrowed, and deliberately built out of the app's own
/// vocabulary rather than out of anybody's console iconography: a wine glass
/// abstracted to three strokes. A downward triangle for the bowl, a stem
/// dropped from its apex, a foot across the bottom. Nothing here is a
/// circle-cross-square-triangle set, nothing is an X-sphere, and the only
/// resemblance it bears to a trademark is that both are marks.
///
/// A `Shape` and stroked rather than filled, so it reads as engraved at stamp
/// size and as a keyline at picker size, and so it takes the tint the caller
/// already computed for the symbol it replaces.
///
/// Laid out on a unit square and scaled, which is what lets one drawing serve a
/// 17pt picker tile and a 25pt stamp glyph without a second set of numbers.
struct SkinSigil: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let x = rect.midX - s / 2
        let y = rect.midY - s / 2
        func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
            CGPoint(x: x + u * s, y: y + v * s)
        }

        var path = Path()

        // The bowl: a wide, shallow triangle pointing down. Open at the top —
        // the rim is the stroke's own two endpoints, which is what stops it
        // reading as a plain triangle badge.
        path.move(to: p(0.10, 0.16))
        path.addLine(to: p(0.90, 0.16))
        path.addLine(to: p(0.50, 0.62))
        path.closeSubpath()

        // The stem, dropped from the bowl's point.
        path.move(to: p(0.50, 0.62))
        path.addLine(to: p(0.50, 0.86))

        // The foot.
        path.move(to: p(0.26, 0.88))
        path.addLine(to: p(0.74, 0.88))

        return path
    }
}
#endif
