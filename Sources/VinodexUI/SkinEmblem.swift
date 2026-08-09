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
        SkinMarkView(mark: skin.drawnMark, fallback: skin.symbol, size: size, tint: tint, weight: weight)
    }
}

/// Renders whichever kind of glyph a skin is carrying (0.7.0, B2).
///
/// Split out of `SkinEmblem` because a skin now has *two* mark slots: the badge
/// (`drawnMark`, on the picker tile and the plate sticker) and the user button's
/// cap glyph (`userMark`). Both need the same "drawn mark, or an SF Symbol if
/// there is none" resolution, and the button had no business reimplementing it.
struct SkinMarkView: View {
    let mark: SkinMark?
    /// The SF Symbol to use when there is no drawn mark.
    let fallback: String
    let size: CGFloat
    let tint: Color
    var weight: Font.Weight = .semibold

    var body: some View {
        Group {
            switch mark {
            case .sigil:
                SkinSigil()
                    .stroke(tint, style: StrokeStyle(lineWidth: max(size * 0.11, 1.4), lineJoin: .round))
                    .frame(width: size, height: size)
            case .pumpkin:
                // Filled, and `eoFill` is what cuts the face out of the body —
                // see `SkinPumpkin`. Slightly wider than tall, which is the one
                // proportion that stops a pumpkin reading as an apple.
                SkinPumpkin()
                    .fill(tint, style: FillStyle(eoFill: true))
                    .frame(width: size * 1.08, height: size)
            case nil:
                Image(systemName: fallback)
                    .font(.system(size: size, weight: weight))
                    .foregroundStyle(tint)
            }
        }
    }
}

/// **A jack-o'-lantern** (0.7.0, B2) — HALLOWEEN's badge, and the glyph on its
/// user button.
///
/// Drawn here for the same reason `SkinSigil` is, arrived at from the other
/// direction: the sigil replaced a symbol that existed and was not ours to ship,
/// and this replaces a symbol that is nobody's because SF Symbols has no pumpkin
/// at the iOS 17 deployment floor. Reaching for a near-miss (`carrot`, a leaf, a
/// circle) would have been the same failure as a beige "hand-drawn" mode: the
/// thing that says *pumpkin* is the silhouette and the triangular face, and no
/// amount of orange substitutes for it.
///
/// One closed silhouette with the stem built into it, then the face as separate
/// subpaths — filled `eoFill`, so the eyes, nose and grin are holes rather than
/// darker shapes. That matters on the user button, where the cap shows through
/// them and the lantern reads as cut out of the cap rather than printed on it.
///
/// Laid out on a unit square and scaled, like the sigil, so one drawing serves a
/// 17pt picker tile, a 25pt stamp and a ~13pt button glyph.
struct SkinPumpkin: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + u * w, y: rect.minY + v * h)
        }

        var path = Path()

        // The silhouette, clockwise from the stem's top-left. The stem is part
        // of this outline rather than a second shape: two overlapping subpaths
        // would cancel their overlap under even-odd and leave a seam where the
        // stem meets the body.
        path.move(to: p(0.44, 0.10))
        path.addLine(to: p(0.56, 0.04))
        path.addLine(to: p(0.58, 0.26))
        path.addCurve(to: p(0.99, 0.60), control1: p(0.86, 0.24), control2: p(0.99, 0.38))
        path.addCurve(to: p(0.50, 0.99), control1: p(0.99, 0.86), control2: p(0.78, 0.99))
        path.addCurve(to: p(0.01, 0.60), control1: p(0.22, 0.99), control2: p(0.01, 0.86))
        path.addCurve(to: p(0.42, 0.26), control1: p(0.01, 0.38), control2: p(0.14, 0.24))
        path.closeSubpath()

        // Two triangular eyes, points down.
        path.move(to: p(0.22, 0.46))
        path.addLine(to: p(0.40, 0.46))
        path.addLine(to: p(0.31, 0.62))
        path.closeSubpath()

        path.move(to: p(0.60, 0.46))
        path.addLine(to: p(0.78, 0.46))
        path.addLine(to: p(0.69, 0.62))
        path.closeSubpath()

        // The nose, the same triangle at a third the width.
        path.move(to: p(0.44, 0.58))
        path.addLine(to: p(0.56, 0.58))
        path.addLine(to: p(0.50, 0.68))
        path.closeSubpath()

        // The grin: a wide band with two teeth dropped out of its top edge, so
        // the mouth still reads at button size where a row of separate teeth
        // would close up into a smudge.
        path.move(to: p(0.22, 0.74))
        path.addLine(to: p(0.34, 0.74))
        path.addLine(to: p(0.40, 0.80))
        path.addLine(to: p(0.46, 0.74))
        path.addLine(to: p(0.54, 0.74))
        path.addLine(to: p(0.60, 0.80))
        path.addLine(to: p(0.66, 0.74))
        path.addLine(to: p(0.78, 0.74))
        path.addCurve(to: p(0.50, 0.90), control1: p(0.74, 0.88), control2: p(0.64, 0.90))
        path.addCurve(to: p(0.22, 0.74), control1: p(0.36, 0.90), control2: p(0.26, 0.88))
        path.closeSubpath()

        return path
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
