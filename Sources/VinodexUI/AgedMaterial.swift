#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

// MARK: - Worn treatment

/// The shared "aged object" pass (0.6.4, F2/F3), applied over the back plate's
/// leavings so they read as the same handled material: a seeded paper-grain
/// speckle, a faint tea-stain tint, and the uneven press the 0.6.2 ink stamps
/// already used — heavier at one corner, lighter at the other. Ageing in code
/// means no asset is hand-aged and every future glyph arrives pre-weathered.
///
/// **Moved out of `StampFrame.swift` in 0.7.8 (A1).** It was declared in the
/// stamps' file and reached across by the per-skin sticker, which is exactly
/// the shape A1 exists to undo: the two objects on the plate are different
/// things and neither should have to import the other's file to get weathered.
/// What they genuinely share is a *material* treatment — sun, thumbs and shelf
/// dust do not care whether they are working on perforated paper or die-cut
/// vinyl — so the treatment lives on its own and both sides depend on it
/// rather than on each other.
///
/// Nothing here knows about stamps or stickers. That is the test of whether
/// the split was drawn in the right place.
struct WornOverlay: ViewModifier {
    /// Seeds the grain so each object wears differently — but identically
    /// from launch to launch; the plate must not re-weather itself.
    let seed: UInt64

    /// FNV-1a over the id, NOT `hashValue`: Swift's hashing is per-process
    /// seeded, and a seed that changes each launch would regrain every
    /// object every time the app opens.
    static func seed(_ id: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                GrainSpeckle(seed: seed)
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
            )
            .overlay(
                // Tea-stain: warm, faint, heavier toward one edge.
                LinearGradient(
                    colors: [
                        Color(dexHex: "#8A6B3F").opacity(0.16),
                        Color(dexHex: "#8A6B3F").opacity(0.05),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.multiply)
                .allowsHitTesting(false)
            )
            .compositingGroup()
            // The angled press, verbatim from the 0.6.2 stamps: opacity
            // carried in a gradient mask so the fade is directional.
            .opacity(0.92)
            .mask(
                LinearGradient(
                    colors: [.black, .black.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

/// Deterministic paper-grain: a couple hundred dark speckles from a seeded
/// linear congruential generator. A `Canvas`, not an image asset — it scales
/// with its object and ships no bytes.
private struct GrainSpeckle: View {
    let seed: UInt64

    var body: some View {
        Canvas { context, size in
            var state = seed == 0 ? 0x9E3779B9 : seed
            func next() -> CGFloat {
                // Numerical Recipes LCG — quality is irrelevant, stability is not.
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat(state >> 33) / CGFloat(UInt32.max)
            }
            let count = Int(size.width * size.height / 38)
            for _ in 0..<count {
                let x = next() * size.width
                let y = next() * size.height
                let edge = 0.6 + next() * 0.9
                context.fill(
                    Path(CGRect(x: x, y: y, width: edge, height: edge)),
                    with: .color(.black.opacity(0.05 + Double(next()) * 0.07))
                )
            }
        }
    }
}
#endif
