#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

// MARK: - The die-cut silhouette

/// A die-cut sticker's outline: a rounded rectangle with one corner taken off
/// on the diagonal, where the vinyl has started to lift.
///
/// The dog-ear is the whole point of the shape. A rounded rectangle on its own
/// is a card, a tile or a button — the app is full of them — and the one thing
/// this object has to say at 70pt, without a caption, is *a previous owner
/// stuck this here*. A lifted corner says it in one read, and it is the
/// silhouette a postage stamp can never have, which is the other half of the
/// job (0.7.8, A1).
struct DieCutStickerShape: Shape {
    /// The rounded corners, as a fraction of the shorter side.
    var cornerFraction: CGFloat = 0.26
    /// The diagonal bite at the bottom-trailing corner, same units.
    var foldFraction: CGFloat = 0.22

    /// Resolved against a concrete rect, so the flap below can be drawn from
    /// the identical numbers rather than from a second guess at them.
    static func fold(in rect: CGRect, fraction: CGFloat) -> CGFloat {
        min(rect.width, rect.height) * fraction
    }

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let corner = side * cornerFraction
        let fold = Self.fold(in: rect, fraction: foldFraction)

        var p = Path()
        p.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        // Top-right corner, then down the right edge to where the ear starts.
        p.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: corner
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - fold))
        // The diagonal cut — no radius, because a torn/lifted edge is the one
        // edge on this object that was not cut by a machine.
        p.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY))
        p.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.minY),
            radius: corner
        )
        p.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY),
            radius: corner
        )
        p.closeSubpath()
        return p
    }
}

/// The triangle the die-cut shape leaves empty, filled by the lifted corner
/// itself — the sticker's own back, showing adhesive rather than print.
private struct PeelFlap: Shape {
    var foldFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        let fold = DieCutStickerShape.fold(in: rect, fraction: foldFraction)
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - fold))
        p.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - The per-skin artifact

/// The back plate's per-skin artifact: one aged die-cut sticker, unique to the
/// shell fitted, stuck on by whoever owned this device before you.
///
/// **It is not a stamp, and 0.7.8's A1 is the batch that made that true.**
/// 0.6.4's F3 introduced it as a die-cut sticker; 0.6.5's item 8 replaced that
/// outright with a postage stamp on the badge stamps' own perforated frame, on
/// the reasoning that the Passport stamps set the plate's visual dialect and
/// the skin piece should speak it. The cost of that reasoning is what A1
/// reverses: two objects that look like the same *kind* of thing get read as
/// the same kind of thing, so the plate appeared to carry seven collectibles
/// when it carries six collectibles and one decoration. The dialect argument
/// was answering a question about materials; the answer it gave was about
/// identity.
///
/// So the two are drawn apart on every axis that carries meaning:
///
/// | | Passport stamp | this |
/// | --- | --- | --- |
/// | silhouette | perforated rectangle, portrait 88x104 | die-cut with a lifted corner, square 70 |
/// | stock | cream postage paper | tinted vinyl over a cream die-cut margin |
/// | printing | inner keyline, denomination corner, title | the glyph alone |
/// | surface | matte | a gloss sweep — vinyl catches light, paper does not |
/// | interaction | tap for its story, hold to drag | **inert** |
/// | earned | by a Passport unlock | comes with the shell |
///
/// What they still share is `WornOverlay`, and only that: both are objects
/// that have been on a shelf. That treatment is a material, not an identity,
/// and it lives in `AgedMaterial.swift` so neither of these files imports the
/// other's.
///
/// Art arrives as `sticker-<skin>` through **its own** pipeline —
/// `art/icons/stickers/` -> `scripts/import-sticker-art.py` ->
/// `Resources/StickerArt` — with the skin's emblem standing in until then. The
/// stamps' `art/icons/stamps/` -> `Resources/StampArt` path is now entirely
/// separate, so an illustrator working one set cannot land a file in the
/// other's namespace by mistake.
struct SkinStickerView: View {
    let skin: ChassisSkin
    var size: CGFloat = 70

    /// The vinyl's die-cut margin — the uncut border every sticker carries
    /// around its artwork. Warmer and lighter than the stamps' `#E9E6DA`
    /// postage stock on purpose: at a glance on the same plate, the two must
    /// not read as cut from one sheet.
    private let margin = Color(dexHex: "#F5F1E4")
    /// The printed face under the glyph.
    private let face = Color(dexHex: "#EAE4D3")

    private var ink: Color { skin.accent.mid }
    private var foldFraction: CGFloat { 0.22 }

    var body: some View {
        let shape = DieCutStickerShape(foldFraction: foldFraction)

        ZStack {
            // The die-cut margin, then the printed face inset inside it. Two
            // fills rather than a stroke: a sticker's border is uncut vinyl of
            // the same sheet, so it has the shape's own dog-ear rather than a
            // stroked outline that would follow the artwork.
            shape.fill(margin)
            shape
                .fill(face)
                .overlay(shape.fill(ink.opacity(0.16)))
                .padding(4)

            glyph
                .frame(width: size * 0.50, height: size * 0.50)

            // The lifted corner: the sticker's own back, pale and matt where
            // the printed side is not, with the fold line darkened so the
            // triangle reads as folded up rather than as a hole cut out.
            PeelFlap(foldFraction: foldFraction)
                .fill(
                    LinearGradient(
                        colors: [Color(dexHex: "#D8D2C2"), Color(dexHex: "#F7F4EA")],
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    )
                )
                .overlay(
                    PeelFlap(foldFraction: foldFraction)
                        .stroke(Color.black.opacity(0.18), lineWidth: 0.75)
                )
                .shadow(color: .black.opacity(0.28), radius: 1.5, x: -1, y: -1)
        }
        .frame(width: size, height: size)
        // Gloss, clipped to the die-cut so it cannot bleed past the edge. The
        // one treatment the stamps deliberately do not get.
        .overlay(
            LinearGradient(
                colors: [.white.opacity(0.30), .white.opacity(0.02), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(shape)
            .allowsHitTesting(false)
        )
        .modifier(WornOverlay(seed: WornOverlay.seed(skin.rawValue)))
        .shadow(color: .black.opacity(0.28), radius: 1.5, y: 1.5)
        // **Inert, and it says so itself** (0.7.8, A1). The call site on
        // `DeviceBackPlate` also declines hits, as every other leaving on the
        // plate does — this is the belt to that pair of braces, because the
        // stamps' whole drag mechanism sits one `ZStack` layer above and the
        // 0.7.2 A2 failure was a hit region reaching somewhere nobody expected
        // it to. A decoration that can only ever refuse a touch cannot be the
        // cause of the next one of those. There is deliberately no
        // `contentShape` anywhere in this file.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyph: some View {
        if let art = PixelArtLoader.shared.image(skin.stickerStem) {
            Image(uiImage: art)
                // **Smooth since 0.8.5 (F1), and this branch had never once
                // run before it.** `StickerArt` was empty from the day 0.7.8
                // created it, so `.interpolation(.none)` was the house default
                // applied to a code path with nothing to apply it to. The drop
                // that arrived is painted illustration at 255-296px — 35,000 to
                // 75,000 distinct colours before quantisation — shown inside a
                // 70pt die-cut, which is roughly a fifth scale. Nearest-
                // neighbour there keeps one pixel in five and discards the
                // other four, and what it discards is most of the drawing.
                //
                // The house rule is about art drawn *on a grid*, where a filter
                // smears an authored decision. Nothing here was drawn on a
                // grid. Same exception, same argument, as `DexChromeGlyph`'s
                // marquee dots (0.8.4) and the footer caps (0.8.5, E2).
                .interpolation(.high)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if skin.drawnMark != nil {
            // The drawn mark outranks the SF-Symbol stand-in (0.6.7, K1) — it
            // *is* this skin's emblem, not a placeholder for one.
            SkinEmblem(skin: skin, size: size * 0.36, tint: ink)
        } else {
            Image(systemName: skin.stickerSymbol)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(ink)
        }
    }
}

extension ChassisSkin {
    /// The authored sticker art's stem under `Resources/StickerArt` — e.g.
    /// `sticker-christmas` for the WINE XMAS shell. Derived from the persisted
    /// raw value, so renamed display labels never orphan an asset.
    ///
    /// **`StickerArt`, not `StampArt`, since 0.7.8 (A1).** The stems did not
    /// change and neither did the illustrator's brief; what changed is which
    /// directory they land in, so that the two families can be commissioned,
    /// reviewed and shipped without either one's importer touching the other's
    /// output. See `art/icons/stickers/README.md`.
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
