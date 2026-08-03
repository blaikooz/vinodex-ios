#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// A dissolve mask made of square cells (0.7.1, B2).
///
/// **What B2 needs and why nothing here already does it.** The marquee is not a
/// segment display — there is no glyph table, no per-character cells, nothing
/// to switch off one at a time. It is one `Text` in a bundled pixel face over a
/// drawn grid, and SwiftUI will not animate a `Text`'s *contents* at all: the
/// banner has always had to change the view's identity and cross-fade the two,
/// which is a smooth alpha ramp and the opposite of pixelated.
///
/// So the pixels come from the mask instead. Both strings are drawn, stacked,
/// and each is masked by a field of cells that switch on and off whole. The
/// letters never fade; the cells covering them appear and disappear, which is
/// what a dot-matrix panel repainting actually looks like.
///
/// **One field, two complementary reads.** The outgoing text keeps the cells
/// whose threshold is *above* the progress; the incoming text takes the ones at
/// or below it. Because both read the same seeded field, every cell hands over
/// at exactly one instant — there is no moment where a cell shows both strings
/// (a doubled-up smear) or neither (a hole punched through the panel). That is
/// worth the coupling: two independent random fields were the first thing tried
/// and they read as static, not as a wipe.
///
/// `Canvas` rather than a grid of `Rectangle`s, following `ScanlineOverlay` and
/// `DataWave`: at a 4pt cell a marquee-sized panel is several hundred cells,
/// and several hundred SwiftUI views repainting sixty times a second is a
/// different feature entirely.
struct PixelDissolve: View {
    /// 0 = no cells, 1 = every cell. Fed from a `TimelineView` clock rather
    /// than animated: `Canvas` has no animatable content, which is the same
    /// wall `DataWave` documents hitting under Swift 6.
    var progress: Double
    /// Cell edge in points.
    var cell: CGFloat
    /// `true` for the incoming text (cells at or below `progress`), `false` for
    /// the outgoing one (cells above it).
    var incoming: Bool

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            guard cell > 0 else { return }
            let cols = Int(ceil(size.width / cell))
            let rows = Int(ceil(size.height / cell))
            guard cols > 0, rows > 0 else { return }

            let p = min(max(progress, 0), 1)
            for row in 0..<rows {
                for col in 0..<cols {
                    let t = Self.threshold(col: col, row: row)
                    let lit = incoming ? (t <= p) : (t > p)
                    guard lit else { continue }
                    context.fill(
                        Path(
                            CGRect(
                                x: CGFloat(col) * cell,
                                y: CGFloat(row) * cell,
                                width: cell,
                                height: cell
                            )
                        ),
                        with: .color(.white)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Each cell's place in the dissolve order, in 0..<1.
    ///
    /// A hash rather than a stored table or `Double.random`: it must be *stable*
    /// (the mask is recomputed every frame, and a cell that re-rolls each frame
    /// flickers instead of dissolving) and it must not need allocating or
    /// seeding per view. This is the finalising mix from MurmurHash3 over the
    /// two classic spatial primes — cheap, and with no visible diagonal
    /// banding, which a plain `(col * k + row) % n` has plenty of.
    ///
    /// Not skewed toward the centre or any edge on purpose. A directional wipe
    /// is a different effect and reads as a transition *between screens*; B2
    /// asks for a fade, and an unordered field is what makes it one.
    static func threshold(col: Int, row: Int) -> Double {
        var h = UInt64(bitPattern: Int64(col &* 73_856_093 ^ row &* 19_349_663))
        h ^= h >> 33
        h = h &* 0xff51_afd7_ed55_8ccd
        h ^= h >> 33
        h = h &* 0xc4ce_b9fe_1a85_ec53
        h ^= h >> 33
        return Double(h % 10_000) / 10_000
    }
}
#endif
