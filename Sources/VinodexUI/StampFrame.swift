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

// MARK: - The stamp

/// One back-plate postage stamp (0.6.4, F2): code-drawn perforated paper in
/// the record's own ink, the glyph inside, a denomination corner, the worn
/// pass over the lot. Rendered "realistically like the barcode sticker" —
/// opaque label stock, faded inks, a real drop shadow — decoration that has
/// *happened to* the plate, not UI chrome.
struct BackPlateStampView: View {
    let stamp: BackPlateStamp
    /// 88x104 since 0.7.0 (E1), up from 76x90.
    ///
    /// The title is the widest thing on a stamp and it did not fit; the two ways
    /// out were to shrink the words further or to give them room, and the words
    /// were already being crushed to an illegible size. See the note on the
    /// title itself for the arithmetic. `DeviceBackPlate.stampSize` mirrors
    /// this, because the slot origins and the drag clamp both need it.
    var width: CGFloat = 88
    var height: CGFloat = 104

    private var ink: Color { Color(dexHex: stamp.colorHex) }

    var body: some View {
        let paper = Color(dexHex: "#E9E6DA")   // the barcode sticker's stock

        ZStack {
            PerforatedStampShape()
                .fill(paper, style: FillStyle(eoFill: true))

            VStack(spacing: 4) {
                glyph
                    .frame(maxHeight: .infinity)
                // **The title fits inside the stamp** (0.7.0, E1).
                //
                // It did not, and the reason is worth writing down because the
                // number in the call below is a lie about what renders.
                // `DexFont.retro` routes through `TypeScale.resolve`, which
                // applies `nominalFloor` **before** the scale step — so
                // `retro(6)` has never rendered at 6pt. It renders at
                // `max(10, 6) × factor`, i.e. 8.5pt at SMALL and 11.5pt at
                // HUGE. The floor is right (it is an accessibility guarantee and
                // there is no arguing with it), but it silently promoted this
                // one label by 67% at some point in 0.6.x, and nothing on this
                // surface was re-measured afterwards.
                //
                // At 11.5pt in the Press Start face — a full em per character —
                // COMPLETE alone is ~96pt of advance, against the 56pt the old
                // `.padding(10)` left it on a 76pt stamp. One line and a
                // `minimumScaleFactor(0.6)` was the whole budget, so the title
                // was being crushed to ~7pt of a pixel face that has no legible
                // pixels there. REGION COMPLETE was the worst; STREAK WEEK and
                // TEN BOTTLES were the same failure a notch milder.
                //
                // Fixed by giving it room rather than by shrinking it further:
                // the stamp itself is wider (see `BackPlateStampView.width`),
                // the title wraps to the two lines every multi-word title in
                // `StampCatalog` naturally wants, it takes back the block's
                // horizontal padding so it can use the full width inside the
                // keyline, and the scale floor comes *up* to 0.75. Worst case is
                // now COMPLETE at HUGE, which needs ~0.77 — inside the floor,
                // with the glyph above absorbing whatever the second line costs.
                Text(stamp.title)
                    .font(DexFont.retro(6))
                    .tracking(0.5)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(ink.opacity(0.9))
                    .padding(.horizontal, -4)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Thin inner keyline — the printed frame inside the perforation.
            Rectangle()
                .strokeBorder(ink.opacity(0.7), lineWidth: 1)
                .padding(6)
        }
        .overlay(alignment: .topTrailing) {
            Text(stamp.denomination)
                .font(DexFont.retro(7))
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
                // Smooth since 0.8.5 (F1) — see `SkinStickerView.glyph`, which
                // makes the identical argument about the identical situation.
                // This branch had never run either: `StampArt` was empty from
                // 0.6.4 until the badges were drawn in this batch, and the
                // drawings are painted at ~300px inside an 88x104 stamp.
                .interpolation(.high)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: stamp.fallbackSymbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(ink)
        }
    }
}

// The per-skin back-plate artifact used to live here, as a postage stamp on
// the frame above (0.6.5, item 8). **It moved out in 0.7.8 (A1)** and stopped
// being a stamp at all: it is the shell's own aged decal now, drawn in
// `SkinSticker.swift` on a die-cut silhouette with nothing in common with this
// file. This note is left because a reader looking for `SkinStickerView` in
// the stamps' file is a reader who remembers the two being one thing.
//
// What went with it: `ChassisSkin.stickerStem` / `.stickerSymbol`, and the art
// namespace — `sticker-*` now imports from `art/icons/stickers/` into
// `Resources/StickerArt`, leaving `art/icons/stamps/` -> `Resources/StampArt`
// to the six Passport badges alone. `WornOverlay` was declared here and used
// by both; it is a material rather than either object's identity, so it is now
// in `AgedMaterial.swift` and this file imports it on the same terms the
// sticker does.
#endif
