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
///
/// ## The transparent container (0.8.7, A3)
///
/// **A `View` that wraps its content, not a `ViewModifier` applied to it**, and
/// the change of shape is the fix rather than a tidy-up.
///
/// Both of the overlays below fill the *frame*, because that is what `.overlay`
/// does. Through 0.8.5 that was harmless: the objects wearing this treatment
/// were code-drawn and filled their frames — a perforated rectangle of postage
/// stock, a die-cut square of vinyl. 0.8.6's A1/C4 replaced both with drawn art
/// laid out `.aspectRatio(.fit)` inside a box, and a fitted image does **not**
/// fill its box: it letterboxes. So the tea-stain gradient and the grain went on
/// painting the whole rectangle while the object inside it had become a shape,
/// and a faint warm wash over an otherwise empty rectangle is exactly what "I
/// can see the transparent containers behind the passport stamps" describes. On
/// the eight stamps the leftover is the letterboxing; on the artifact, whose art
/// is a die-cut with a peeled corner, it is the whole bounding box minus the
/// sticker.
///
/// The fix is one more mask: the aged pass is clipped to the object's own alpha.
/// That needs the content *twice* — once to draw and once as the stencil — which
/// a `ViewModifier` cannot do, because `Content` is an opaque placeholder for
/// the view it is attached to rather than a value the body may use again. Stored
/// as a property on a wrapper, it can be. Everything else here is unchanged, and
/// `seed(_:)` keeps its name and its arithmetic: `ChassisSkin`'s note calls that
/// FNV-1a hash load-bearing, since a shell's raw value is simultaneously an
/// `@AppStorage` key and the seed for this wear.
struct WornOverlay<Content: View>: View {
    /// Seeds the grain so each object wears differently — but identically
    /// from launch to launch; the plate must not re-weather itself.
    let seed: UInt64
    private let content: Content

    init(seed: UInt64, @ViewBuilder content: () -> Content) {
        self.seed = seed
        self.content = content()
    }

    var body: some View {
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
            // **The object's own silhouette** (0.8.7, A3). Masks compose
            // multiplicatively, so this narrows the directional press above
            // rather than replacing it, and it costs a second render of the
            // content — an `Image` for both real call sites.
            .mask(content)
    }
}

/// The wear seed, on a home of its own (0.8.7, A3).
///
/// It was `WornOverlay.seed(_:)` until that type became generic over its
/// content, at which point every call site would have had to name a generic
/// argument it does not care about (`WornOverlay<EmptyView>.seed(…)`) to reach a
/// pure function of a string. `ChassisSkin`'s note describes a shell's raw value
/// as "the FNV-1a seed for procedural wear" and that is still exactly true; only
/// the spelling of the call moved.
enum WornSeed {
    /// FNV-1a over the id, NOT `hashValue`: Swift's hashing is per-process
    /// seeded, and a seed that changes each launch would regrain every
    /// object every time the app opens.
    static func of(_ id: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

extension View {
    /// The aged pass, clipped to this view's own alpha (0.8.7, A3). Reads at the
    /// call site the way `.modifier(WornOverlay(seed:))` did, one line up.
    func worn(id: String) -> some View {
        WornOverlay(seed: WornSeed.of(id)) { self }
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
