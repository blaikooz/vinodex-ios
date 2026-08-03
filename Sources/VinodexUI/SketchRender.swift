#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

// MARK: - Hand-drawn rendering (0.6.9, M1)
//
// M1 asks for a hand-drawn skin *and* a hand-drawn screen mode, and the thing
// worth saying up front is that neither can be done with colour tokens. Every
// other skin in the range is a palette: eighteen sets of hexes poured into the
// same geometry, which is exactly why a nineteenth set of them would produce a
// device that looked machine-moulded in beige. "As though it were drawn by
// hand" is a statement about *lines*, not about hues — a hand-drawn rectangle
// is not a rectangle, it is four strokes that wobble, miss their corners and
// are drawn over twice where the artist pressed harder.
//
// So this file is a small rendering vocabulary rather than a colourway:
//
//   `SketchRoundedRect` / `SketchCircle` — the app's two chrome silhouettes,
//        re-emitted as wobbled paths. Everything the sketch skin outlines goes
//        through one of these.
//   `SketchStroke`        — the double-pass overshooting ink line.
//   `PaperGrain`          — the tooth of the paper the ink sits on.
//   `RuledPaper`          — the notebook page the LCD becomes.
//
// **Deterministic, and that is load-bearing.** Every wobble comes out of
// `SketchRandom`, seeded from a caller-supplied integer, so the same part draws
// the identical line on every frame. Random-per-render would make the chassis
// visibly crawl — a shimmer, not a drawing — and, worse, would make the whole
// shell re-rasterise continuously on a screen that is otherwise static. A drawn
// line is drawn once and then stays where it is.
//
// **No new art.** These are `Shape`s and `Canvas`es, so the skin ships with the
// binary, follows `UIScale` for free, and needs nothing from `art/icons/` or
// the import scripts.

/// A tiny deterministic generator — an LCG, seeded per part.
///
/// Not `SystemRandomNumberGenerator` and not `Int.random`: the whole point is
/// that the line does not change between frames. Not `hashValue` either, which
/// Swift explicitly seeds per process, so a hand-drawn chassis would come out
/// subtly different on every launch — recognisable as a bug precisely because
/// nobody could say what had changed.
struct SketchRandom {
    private var state: UInt64

    init(seed: UInt64) {
        // Any odd constant; nonzero so a zero seed still advances.
        state = seed &* 6364136223846793005 &+ 1442695040888963407
    }

    private mutating func nextBits() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 33
    }

    /// A value in `-amplitude ... +amplitude`.
    mutating func jitter(_ amplitude: CGFloat) -> CGFloat {
        let unit = CGFloat(nextBits() % 2001) / 1000 - 1
        return unit * amplitude
    }
}

/// Turns a run of sampled points into one continuous hand line.
///
/// Midpoint quadratics rather than straight segments between the perturbed
/// samples: a polyline through jittered points reads as a *jagged* line, which
/// is a different thing from a hand-drawn one — a pen has momentum and rounds
/// its own corrections. Each sample becomes a control point and the curve
/// passes through the midpoints, which is the standard cheap smoothing and is
/// what makes the wobble read as a wrist rather than as noise.
private func sketchPath(through points: [CGPoint]) -> Path {
    var path = Path()
    guard points.count > 2 else { return path }

    let start = CGPoint(
        x: (points[points.count - 1].x + points[0].x) / 2,
        y: (points[points.count - 1].y + points[0].y) / 2
    )
    path.move(to: start)
    for index in points.indices {
        let current = points[index]
        let next = points[(index + 1) % points.count]
        let mid = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
        path.addQuadCurve(to: mid, control: current)
    }
    path.closeSubpath()
    return path
}

/// A rounded rectangle drawn by hand.
///
/// The outline is walked by arc length — four straight runs and four quarter
/// arcs — rather than by corner points, so the samples are evenly spaced and
/// the wobble has the same frequency along an edge as it does around a corner.
/// Sampling a `Path(roundedRect:)`'s own elements would have clustered every
/// perturbation at the eight vertices, which reads as a rectangle with dented
/// corners.
struct SketchRoundedRect: Shape {
    var cornerRadius: CGFloat
    /// How far the pen strays, in points. About 1.5 at chassis scale: enough to
    /// see, small enough that the part is still plainly the part.
    var amplitude: CGFloat = 1.5
    /// Which line this is. Two strokes of the same shape at different seeds are
    /// what makes `SketchStroke`'s double pass read as one pen going round
    /// twice rather than as a shape with a thick border.
    var seed: UInt64 = 1
    /// Samples around the whole perimeter. 72 lands roughly one every 4–8pt on
    /// the parts this is used for.
    var samples: Int = 72

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0, samples > 2 else { return Path() }

        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        let runH = rect.width - 2 * radius
        let runV = rect.height - 2 * radius
        let arc = .pi / 2 * radius
        let total = 2 * runH + 2 * runV + 4 * arc
        guard total > 0 else { return Path() }

        var rng = SketchRandom(seed: seed)
        var points: [CGPoint] = []
        points.reserveCapacity(samples)

        for index in 0..<samples {
            var point = Self.point(
                at: CGFloat(index) / CGFloat(samples) * total,
                in: rect,
                radius: radius,
                runH: runH,
                runV: runV,
                arc: arc
            )
            point.x += rng.jitter(amplitude)
            point.y += rng.jitter(amplitude)
            points.append(point)
        }

        return sketchPath(through: points)
    }

    /// Distance `s` along the outline, clockwise from the top-left corner's end
    /// of the top edge.
    private static func point(
        at s: CGFloat,
        in rect: CGRect,
        radius: CGFloat,
        runH: CGFloat,
        runV: CGFloat,
        arc: CGFloat
    ) -> CGPoint {
        var d = s

        // Top edge, left to right.
        if d < runH { return CGPoint(x: rect.minX + radius + d, y: rect.minY) }
        d -= runH
        // Top-right corner.
        if d < arc {
            return corner(
                centre: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                radius: radius, from: -.pi / 2, sweep: d / max(arc, 0.0001)
            )
        }
        d -= arc
        // Right edge.
        if d < runV { return CGPoint(x: rect.maxX, y: rect.minY + radius + d) }
        d -= runV
        // Bottom-right corner.
        if d < arc {
            return corner(
                centre: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                radius: radius, from: 0, sweep: d / max(arc, 0.0001)
            )
        }
        d -= arc
        // Bottom edge, right to left.
        if d < runH { return CGPoint(x: rect.maxX - radius - d, y: rect.maxY) }
        d -= runH
        // Bottom-left corner.
        if d < arc {
            return corner(
                centre: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                radius: radius, from: .pi / 2, sweep: d / max(arc, 0.0001)
            )
        }
        d -= arc
        // Left edge.
        if d < runV { return CGPoint(x: rect.minX, y: rect.maxY - radius - d) }
        d -= runV
        // Top-left corner, closing the loop.
        return corner(
            centre: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius, from: .pi, sweep: min(d / max(arc, 0.0001), 1)
        )
    }

    private static func corner(
        centre: CGPoint,
        radius: CGFloat,
        from start: CGFloat,
        sweep: CGFloat
    ) -> CGPoint {
        let angle = start + sweep * .pi / 2
        return CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
    }
}

/// A circle drawn by hand — the button caps, the orb, the lamps.
///
/// The radius is perturbed rather than the point, which is what a compass-less
/// circle actually does: it stays roughly round and drifts in and out, instead
/// of wandering off-centre.
struct SketchCircle: Shape {
    var amplitude: CGFloat = 1.2
    var seed: UInt64 = 1
    var samples: Int = 48

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0, samples > 2 else { return Path() }

        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var rng = SketchRandom(seed: seed)

        let points = (0..<samples).map { index -> CGPoint in
            let angle = CGFloat(index) / CGFloat(samples) * 2 * .pi
            let r = radius + rng.jitter(amplitude)
            return CGPoint(x: centre.x + cos(angle) * r, y: centre.y + sin(angle) * r)
        }

        return sketchPath(through: points)
    }
}

/// The ink line itself: the same silhouette stroked **twice** at two seeds.
///
/// This is the single detail that does most of the work. One wobbled stroke
/// reads as a slightly wonky printed outline; two, at different seeds and
/// slightly different weights, read as a pen that went round, lifted, and came
/// back over — which is what a real drawn outline looks like and what every
/// hand-drawn illustration convention is quoting. The second pass is drawn
/// lighter so it reads as the overshoot rather than as a doubled border.
struct SketchStroke<S: Shape>: View {
    /// Built twice with two seeds — hence a factory rather than a shape.
    let shape: (UInt64) -> S
    let ink: Color
    var lineWidth: CGFloat = 2
    var seed: UInt64 = 1

    var body: some View {
        ZStack {
            shape(seed)
                .stroke(ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            shape(seed &+ 977)
                .stroke(
                    ink.opacity(0.55),
                    style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round)
                )
        }
        .allowsHitTesting(false)
    }
}

/// The tooth of the paper (0.6.9, M1).
///
/// A deterministic stipple, drawn once into a `Canvas` and then static. Cheap
/// on purpose: this covers the whole shell, so it is specks rather than
/// strokes, and the cell size is large enough that a phone-sized chassis is a
/// few thousand rects rather than a few hundred thousand.
///
/// `drawingGroup()` is deliberately *not* applied — the canvas rasterises once
/// as it is, and the flattening pass would only add a texture upload to every
/// chassis rebuild (a skin change, a text-size change) for no repaint saved.
struct PaperGrain: View {
    let color: Color
    var cell: CGFloat = 7
    var seed: UInt64 = 4021

    var body: some View {
        Canvas { context, size in
            var rng = SketchRandom(seed: seed)
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    // Two of every three cells get a speck, so the grain reads
                    // as irregular rather than as a halftone screen.
                    let roll = rng.jitter(1)
                    if roll > -0.35 {
                        let dx = rng.jitter(cell * 0.4)
                        let dy = rng.jitter(cell * 0.4)
                        let side = 1 + abs(rng.jitter(0.9))
                        context.fill(
                            Path(
                                ellipseIn: CGRect(
                                    x: x + cell / 2 + dx,
                                    y: y + cell / 2 + dy,
                                    width: side,
                                    height: side
                                )
                            ),
                            with: .color(color.opacity(0.5 + Double(abs(roll)) * 0.4))
                        )
                    }
                    x += cell
                }
                y += cell
            }
        }
        .allowsHitTesting(false)
    }
}

/// The ruled page the LCD used to become in NOTEBOOK mode (0.6.9, M1).
///
/// **Unmounted since 0.7.0 (C1) and kept on purpose.** C1 removes the NOTEBOOK
/// screen mode, which was this view's only call site; B2 keeps the PÉT-NAT
/// shell, because the shell and the screen have always been independent
/// choices. So the drawn *device* survives and the drawn *page* has no owner —
/// not a bug, and not something to fix by quietly re-pointing the paper at
/// `ChassisSkin.sketch`, which would fuse the two halves the user deliberately
/// picked apart. It is a finished drawing waiting on a decision; deleting it
/// would mean redrawing it to act on that decision. Re-mounting it is one `if`
/// in `DexScreenBackground`.
///
/// Replaces `DexGridBackground` rather than recolouring it, which is the
/// difference between a hand-drawn *mode* and a beige *palette*: a square
/// engineering grid says CRT whatever colour it is drawn in. This is ruled
/// paper — horizontal rules only, each one wobbled along its length, with the
/// red margin line down the left that is the single most recognisable thing
/// about a school exercise book.
///
/// Every rule is drawn from one seeded generator walked left to right, so the
/// page is stable frame to frame for `SketchRandom`'s reasons, and no two rules
/// share a wobble.
struct RuledPaper: View {
    let rule: Color
    let margin: Color
    var spacing: CGFloat = 22
    var seed: UInt64 = 8191

    var body: some View {
        Canvas { context, size in
            var rng = SketchRandom(seed: seed)

            var y = spacing
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y + rng.jitter(0.7)))
                var x: CGFloat = 24
                while x < size.width {
                    path.addLine(to: CGPoint(x: x, y: y + rng.jitter(0.7)))
                    x += 24
                }
                path.addLine(to: CGPoint(x: size.width, y: y + rng.jitter(0.7)))
                context.stroke(path, with: .color(rule.opacity(0.5)), lineWidth: 1)
                y += spacing
            }

            // The margin rule, a third of the way through the left gutter.
            let mx = min(size.width * 0.09, 30)
            var edge = Path()
            edge.move(to: CGPoint(x: mx + rng.jitter(0.8), y: 0))
            var ey: CGFloat = 30
            while ey < size.height {
                edge.addLine(to: CGPoint(x: mx + rng.jitter(0.8), y: ey))
                ey += 30
            }
            edge.addLine(to: CGPoint(x: mx + rng.jitter(0.8), y: size.height))
            context.stroke(edge, with: .color(margin.opacity(0.55)), lineWidth: 1.4)
        }
        .allowsHitTesting(false)
    }
}
#endif
