#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

// MARK: - Perforated frame

/// The classic postage-stamp silhouette (0.6.4, F2): a rectangle with a ring
/// of small circles subtracted along its border, so every edge scallops.
///
/// Drawn as code, not art, exactly so it can tint per stamp and stay
/// pixel-consistent across the whole series — no per-stamp border art to
/// redraw. Filled with `FillStyle(eoFill: true)`: the outer rect is one
/// winding, each perforation circle centred on the boundary is another, and
/// even-odd turns the overlap into a bite. Corner circles are emitted once
/// (the vertical runs skip their endpoints) because two coincident circles
/// would cancel back to solid under even-odd.
struct PerforatedStampShape: Shape {
    var toothRadius: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)

        let d = toothRadius * 2
        // Teeth at least 1.6 diameters apart so neighbouring circles never
        // overlap (overlaps would re-fill under even-odd).
        let spacing = d * 1.6

        let countX = max(Int(rect.width / spacing), 2)
        let stepX = rect.width / CGFloat(countX)
        for i in 0...countX {
            let x = rect.minX + CGFloat(i) * stepX
            p.addEllipse(in: CGRect(x: x - toothRadius, y: rect.minY - toothRadius, width: d, height: d))
            p.addEllipse(in: CGRect(x: x - toothRadius, y: rect.maxY - toothRadius, width: d, height: d))
        }

        let countY = max(Int(rect.height / spacing), 2)
        let stepY = rect.height / CGFloat(countY)
        // Endpoints skipped: the horizontal runs already own the corners.
        for i in 1..<countY {
            let y = rect.minY + CGFloat(i) * stepY
            p.addEllipse(in: CGRect(x: rect.minX - toothRadius, y: y - toothRadius, width: d, height: d))
            p.addEllipse(in: CGRect(x: rect.maxX - toothRadius, y: y - toothRadius, width: d, height: d))
        }
        return p
    }
}

// MARK: - Worn treatment

/// The shared "aged object" pass (0.6.4, F2/F3), applied over stamps and
/// stickers alike so both read as the same handled material: a seeded
/// paper-grain speckle, a faint tea-stain tint, and the uneven press the
/// 0.6.2 ink stamps already used — heavier at one corner, lighter at the
/// other. Ageing in code means no asset is hand-aged and every future glyph
/// arrives pre-weathered.
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

// MARK: - The stamp

/// One back-plate postage stamp (0.6.4, F2): code-drawn perforated paper in
/// the record's own ink, the glyph inside, a denomination corner, the worn
/// pass over the lot. Rendered "realistically like the barcode sticker" —
/// opaque label stock, faded inks, a real drop shadow — decoration that has
/// *happened to* the plate, not UI chrome.
struct BackPlateStampView: View {
    let stamp: BackPlateStamp
    var width: CGFloat = 76
    var height: CGFloat = 90

    private var ink: Color { Color(dexHex: stamp.colorHex) }

    var body: some View {
        let paper = Color(dexHex: "#E9E6DA")   // the barcode sticker's stock

        ZStack {
            PerforatedStampShape()
                .fill(paper, style: FillStyle(eoFill: true))

            VStack(spacing: 4) {
                glyph
                    .frame(maxHeight: .infinity)
                Text(stamp.title)
                    .font(DexFont.retro(10))
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(ink.opacity(0.9))
            }
            .padding(10)

            // Thin inner keyline — the printed frame inside the perforation.
            Rectangle()
                .strokeBorder(ink.opacity(0.7), lineWidth: 1)
                .padding(6)
        }
        .overlay(alignment: .topTrailing) {
            Text(stamp.denomination)
                .font(DexFont.retro(10))
                .foregroundStyle(ink)
                .padding(.top, 8)
                .padding(.trailing, 9)
        }
        .frame(width: width, height: height)
        .modifier(WornOverlay(seed: WornOverlay.seed(stamp.id)))
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
    }

    /// The illustration: the authored pixel-art glyph when
    /// `art/icons/stamps/` has shipped one, the SF Symbol stand-in until
    /// then. The art path renders as drawn — the pipeline's portraits carry
    /// their own colours — while the stand-in prints in the stamp's ink,
    /// which is what a one-colour engraving would do.
    @ViewBuilder
    private var glyph: some View {
        if let art = PixelArtLoader.shared.image(stamp.artStem) {
            Image(uiImage: art)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: stamp.fallbackSymbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(ink)
        }
    }
}

// MARK: - The skin stamp

/// The per-skin back-plate artifact, as a postage stamp (0.6.5, item 8 —
/// replacing 0.6.4's die-cut sticker outright). The Passport stamps set the
/// plate's visual dialect and the skin piece now speaks it: the same
/// perforated fringe, the same paper stock and keyline, the same worn pass —
/// square where the badge stamps are portrait, so it still reads as its own
/// issue. Per-skin identity survives in the glyph and the ink.
///
/// Each skin brings its own art: `sticker-<skin>` through the stamps art
/// pipeline once authored (Santa hat for WINE XMAS, the cat for BLUSH, a
/// detailed take on the skin's emblem elsewhere), with the skin's emblem
/// symbol standing in until then.
struct SkinStickerView: View {
    let skin: ChassisSkin
    var size: CGFloat = 70

    var body: some View {
        let paper = Color(dexHex: "#E9E6DA")
        let ink = skin.accent.mid

        ZStack {
            PerforatedStampShape()
                .fill(paper, style: FillStyle(eoFill: true))

            glyph
                .frame(width: size * 0.52, height: size * 0.52)

            // Thin inner keyline — the printed frame inside the perforation,
            // exactly as the badge stamps wear it.
            Rectangle()
                .strokeBorder(ink.opacity(0.7), lineWidth: 1)
                .padding(6)
        }
        .frame(width: size, height: size)
        .modifier(WornOverlay(seed: WornOverlay.seed(skin.rawValue)))
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
    }

    @ViewBuilder
    private var glyph: some View {
        if let art = PixelArtLoader.shared.image(skin.stickerStem) {
            Image(uiImage: art)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: skin.stickerSymbol)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(skin.accent.mid)
        }
    }
}

extension ChassisSkin {
    /// The authored sticker art's stem under `Resources/StampArt` — e.g.
    /// `sticker-wine-xmas` for the Christmas skin. Derived from the persisted
    /// raw value, so renamed display labels never orphan an asset.
    var stickerStem: String {
        "sticker-" + rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    /// The SF Symbol standing in until the sticker art lands. WINE XMAS's
    /// Santa hat has no SF Symbol, so its gift emblem holds the slot; BLUSH
    /// gets the little cat the brief names (SF Symbols 5, clears iOS 17).
    var stickerSymbol: String {
        switch self {
        case .blush: "cat.fill"
        default: symbol
        }
    }
}
#endif
