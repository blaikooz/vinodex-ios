#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

/// The outline of a game cartridge (0.7.3, 0.7.3c — A2).
///
/// A rounded rectangle with the top-right corner **stepped down** rather than
/// chamfered — the asymmetric shoulder is the whole reason a cartridge is
/// recognisable in silhouette, and it is also what tells you which way up it
/// goes. Without it this is a rounded rectangle, which is every other tile in
/// the app.
///
/// `InsettableShape` rather than `Shape` because `DexPickerTile` draws its border
/// with `strokeBorder`, which insets the line rather than straddling the path. A
/// plain `Shape` would have forced that call site down to `stroke` and put half
/// the border outside the silhouette on all twelve tiles.
struct CartridgeShape: InsettableShape {
    /// Where the shoulder starts, as a fraction of the width.
    var shoulderX: CGFloat = 0.60
    /// How far it steps down, as a fraction of the height.
    var shoulderY: CGFloat = 0.22
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> CartridgeShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        // A zero or inverted rect happens during the first layout pass and while
        // an LCD is being resized; `addArc(tangent1End:)` on one produces NaNs
        // that propagate into the whole render tree rather than drawing nothing.
        guard r.width > 0, r.height > 0 else { return path }

        let corner = min(r.width, r.height) * 0.12
        let shoulderRadius = corner * 0.7
        let stepX = r.minX + r.width * shoulderX
        let stepY = r.minY + r.height * shoulderY

        // Clockwise from the left edge. Each `addArc` rounds the corner it names
        // and heads for the next one — the standard tangent-arc chain, so the
        // radii never have to be reasoned about as arc centres.
        path.move(to: CGPoint(x: r.minX, y: r.minY + corner))
        path.addArc(
            tangent1End: CGPoint(x: r.minX, y: r.minY),
            tangent2End: CGPoint(x: stepX, y: r.minY),
            radius: corner
        )
        path.addArc(
            tangent1End: CGPoint(x: stepX, y: r.minY),
            tangent2End: CGPoint(x: stepX, y: stepY),
            radius: shoulderRadius
        )
        path.addArc(
            tangent1End: CGPoint(x: stepX, y: stepY),
            tangent2End: CGPoint(x: r.maxX, y: stepY),
            radius: shoulderRadius
        )
        path.addArc(
            tangent1End: CGPoint(x: r.maxX, y: stepY),
            tangent2End: CGPoint(x: r.maxX, y: r.maxY),
            radius: corner
        )
        path.addArc(
            tangent1End: CGPoint(x: r.maxX, y: r.maxY),
            tangent2End: CGPoint(x: r.minX, y: r.maxY),
            radius: corner
        )
        path.addArc(
            tangent1End: CGPoint(x: r.minX, y: r.maxY),
            tangent2End: CGPoint(x: r.minX, y: r.minY),
            radius: corner
        )
        path.closeSubpath()
        return path
    }
}

/// One pack drawn as a cartridge (0.7.3, 0.7.3c — A2).
///
/// **Painted entirely out of `lcd` tokens and one ink colour, with no per-pack
/// hue.** The tempting version gives each cartridge its own plastic colour, and
/// it fails on the four single-phosphor modes and the Retro group, where the
/// chassis greys the whole LCD — twelve carefully chosen colours arriving as
/// twelve identical greys, which is worse than never having promised colour. The
/// glyph is the identity instead, and it survives monochrome intact. This is the
/// same rule `PartColor`'s font axis argued one batch earlier: a surface the mode
/// can repaint must not carry meaning the mode can destroy.
///
/// The label plate, the shoulder and the connector fingers are the three details
/// that make the silhouette read as a cartridge rather than as a badge; all
/// three are proportional, so the same view is honest at the 46pt shelf size and
/// would be at twice that.
/// **Takes a glyph rather than a pack since 0.7.5 (B3).** B3 replaces the shop's
/// remaining hand-written rows with this cartridge, and the things on sale there
/// are `Entitlement`s — PRO, the flavour wheel, a country — which are not packs
/// and never will be. Depending on `ExpansionPack` for one string was the only
/// thing stopping one cartridge serving both, so it now takes the string. The
/// pack-shaped call site is unchanged; see the convenience initialiser below.
struct PackCartridge: View {
    /// The SF Symbol on the label plate. The cartridge's whole identity — see
    /// the note above on why it is not a colour.
    let symbol: String
    /// The tile's foreground — `lcd.onAccent` on the chosen tile, `lcd.subtext`
    /// otherwise. Taken as a parameter rather than derived, so the cartridge
    /// cannot disagree with the label underneath it.
    let ink: Color
    /// What the tile sits on, used to punch the glyph back out of the plate.
    let ground: Color
    /// A completed collection gets a tick on the shoulder — the flat area the
    /// step leaves free, which is what that step is for on a real cartridge too.
    /// On the shop's upgrade cartridges this means "owned".
    let isComplete: Bool
    /// The drawn cartridge's stem, where one exists (0.8.2).
    ///
    /// It was nil for the flavour wheel and the country packs; 0.8.3's D took
    /// both off the shop, so every product the shelves draw now has art and the
    /// fallback below is a guard rather than a routine path. It stays a guard:
    /// a pack id written by a later build resolves to no stem here, and an empty
    /// tile is exactly what the drawing exists to prevent.
    var art: String?
    /// The pack's name, printed **inside** the drawn cartridge's label well
    /// (0.8.3, C4).
    ///
    /// **On the shelf too, since 0.8.92 (item 1).** C4's measurement — the
    /// well is 11% of the cartridge's height, six points of type at the
    /// shelf's 58pt — kept it off the shelf for five releases, and the item
    /// overrules it knowingly: the ask is the name *on the icon*, in tiny
    /// type, with the tile's caption underneath still carrying legibility.
    /// On the splash hero the same fraction is a real label; see `wellLabel`'s
    /// raised cap.
    ///
    /// Ignored when there is no art — the code-drawn cartridge below has a
    /// glyph plate where the well would be, and printing a name over it would
    /// stack two identities on one plate.
    var label: String?
    /// The **kind**, printed in the top band of the drawn cartridge — ATLAS,
    /// DEVICE or DISPLAY (0.8.92, item 1; the band printed the pack's *name*
    /// for one release, 0.8.91's A1, before the name moved down into the well
    /// where the printed label belongs).
    ///
    /// Separate from `label` rather than a placement flag on it, because the
    /// two are different jobs: the well is the cartridge's own printed label,
    /// the band is the shelf it came off. Nil on the five upgrade cartridges,
    /// which are not a `Kind` and whose gold band carries a drawn star where
    /// the type would land.
    ///
    /// The band is burgundy on the atlas packs, teal on the device packs and
    /// amber on the display ones — `bandInk` is what copes with that.
    var title: String?

    init(
        symbol: String,
        ink: Color,
        ground: Color,
        isComplete: Bool,
        art: String? = nil,
        label: String? = nil,
        title: String? = nil
    ) {
        self.symbol = symbol
        self.ink = ink
        self.ground = ground
        self.isComplete = isComplete
        self.art = art
        self.label = label
        self.title = title
    }

    /// The 0.7.3c call: a pack draws its own glyph.
    init(
        pack: ExpansionPack,
        ink: Color,
        ground: Color,
        isComplete: Bool,
        art: String? = nil,
        label: String? = nil,
        title: String? = nil
    ) {
        self.init(
            symbol: pack.symbol, ink: ink, ground: ground,
            isComplete: isComplete, art: art, label: label, title: title
        )
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            ZStack {
                if let image = art.flatMap({ PixelArtLoader.shared.image($0) }) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay(alignment: .topLeading) {
                            wellLabel(image: image, in: geo.size)
                        }
                        .overlay(alignment: .topLeading) {
                            bandTitle(image: image, stem: art, in: geo.size)
                        }
                } else {
                    drawn(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .topTrailing) {
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: side * 0.16, weight: .black))
                        .foregroundStyle(ground)
                        .padding(side * 0.03)
                        .background(Circle().fill(ink))
                        .offset(x: -side * 0.02, y: side * 0.02)
                }
            }
        }
    }

    // MARK: The label well (0.8.3, C4)

    /// Where the name sits inside the drawn cartridge, as fractions of the
    /// **fitted image**, not of the tile.
    ///
    /// **Measured across all seventeen sprites rather than eyeballed on one.**
    /// 0.8.2 flagged that `chassisskins`, `screenmodes` and `vinodexpro` ship at
    /// 418×564 against the other fourteen's ~225×302, and the worry that
    /// followed was that the well would therefore be somewhere else on those
    /// three. It is not: measured, the well spans y 0.813–0.934 and x
    /// 0.105–0.888 on every one of the seventeen, the three large files
    /// included. They are the same drawing at twice the resolution, so the
    /// fractions are identical and the size difference is invisible here.
    ///
    /// **What does vary, and is the thing that would have broken this, is the
    /// aspect ratio** — 0.678 (`vessel`, `wines`) to 0.798 (`godforsaken`).
    /// `.aspectRatio(contentMode: .fit)` letterboxes, so a cartridge that is
    /// proportionally narrower than its tile leaves bars at the sides and one
    /// that is taller leaves them top and bottom. A fraction of the *tile* would
    /// therefore have put the label in the well on whichever sprite the numbers
    /// were tuned against and progressively outside it on the rest. So the rect
    /// is computed from the image's own size, and the letterbox offset is added
    /// back — which is `labelWell(for:in:)` below and the whole reason it takes
    /// two sizes.
    ///
    /// The numbers are inset a little from the measured extents: the well is a
    /// recess with a lip, and type run to its exact edge reads as a sticker
    /// applied over the lip rather than as a label printed in it.
    private static let wellOrigin = CGPoint(x: 0.135, y: 0.822)
    private static let wellSize = CGSize(width: 0.730, height: 0.105)

    /// The label well in the tile's coordinates, given the sprite's own size.
    ///
    /// `.zero` on a degenerate size — the first layout pass hands out zeroes,
    /// and the same NaN argument `CartridgeShape.path(in:)` makes applies here.
    ///
    /// Through the shared `rect(origin:size:for:in:)` since 0.8.91 (A1), which
    /// is the same arithmetic the top band needs — two rectangles on one sprite
    /// with two copies of the letterbox maths is how they come to disagree by a
    /// point on the one cartridge with an odd aspect.
    static func labelWell(for image: CGSize, in container: CGSize) -> CGRect {
        rect(origin: wellOrigin, size: wellSize, for: image, in: container)
    }

    /// The name, printed in the well.
    ///
    /// **A fixed dark ink rather than `ink`.** Every one of the seventeen wells
    /// is a light cream recess — that is how the measurement found them — and
    /// the tile's `ink` is `lcd.onAccent` on a chosen tile, which is near-white
    /// and would vanish. The label is part of the picture, and the picture ships
    /// its own colours: the same rule `DexIcon` applies to `art:` ids and
    /// `DexChromeGlyph` to its faces. A monochrome LCD mode still flattens the
    /// whole panel, label included, which is correct — it flattens the sprite
    /// underneath by the same pass.
    ///
    /// **Sized off the well, floored by `minimumScaleFactor`.** The type scale
    /// still applies through `DexFont.retro`, and the well does not grow with
    /// it, so the setting can only push the name past the recess it belongs in.
    /// `MarqueeBanner` reached the same arrangement for the same reason — the
    /// panel's height does not move, so the words shrink into it. The longest
    /// names on sale are CHASSIS SKINS and GRAPE LINEAGE at thirteen characters,
    /// which is what the floor here has to clear.
    @ViewBuilder
    private func wellLabel(image: UIImage, in container: CGSize) -> some View {
        if let label {
            let well = Self.labelWell(for: image.size, in: container)
            if well.width > 0, well.height > 0 {
                Text(label)
                    // The cap is 16 since 0.8.92 (item 1), up from 11. It only
                    // ever binds on the splash hero — at the shelf's 58pt the
                    // proportional term is far below either number — and 11
                    // was leaving a 27pt well two-thirds empty on the page
                    // whose whole job is to print the name legibly.
                    .font(DexFont.retro(min(16, well.height * 0.52)))
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(Color(dexHex: "#2B2118"))
                    .frame(width: well.width, height: well.height)
                    .offset(x: well.minX, y: well.minY)
            }
        }
    }

    // MARK: The top band (0.8.91, A1)

    /// The band in the sprite's own coordinates, as fractions.
    ///
    /// Measured across all seventeen shipped cartridges, the same way
    /// `wellOrigin`/`wellSize` were: the band's full extent runs y 0.101-0.216
    /// and x 0.07-0.94, and these are the rectangle that is *inside* it on every
    /// one of them. The aspect ratios vary from 0.678 to 0.798, so the
    /// letterbox arithmetic in `titleBand(for:in:)` is not optional — it is the
    /// same arithmetic `labelWell` does and for the same reason.
    private static let bandOrigin = CGPoint(x: 0.135, y: 0.125)
    private static let bandSize = CGSize(width: 0.735, height: 0.063)

    /// The band in the tile's coordinates. See `labelWell(for:in:)`, which this
    /// mirrors — one derivation, two rectangles.
    static func titleBand(for image: CGSize, in container: CGSize) -> CGRect {
        rect(origin: bandOrigin, size: bandSize, for: image, in: container)
    }

    /// The letterbox-aware mapping both rectangles need.
    private static func rect(
        origin: CGPoint,
        size: CGSize,
        for image: CGSize,
        in container: CGSize
    ) -> CGRect {
        guard image.width > 0, image.height > 0,
              container.width > 0, container.height > 0 else { return .zero }
        let scale = min(container.width / image.width, container.height / image.height)
        let fitted = CGSize(width: image.width * scale, height: image.height * scale)
        let inset = CGPoint(
            x: (container.width - fitted.width) / 2,
            y: (container.height - fitted.height) / 2
        )
        return CGRect(
            x: inset.x + fitted.width * origin.x,
            y: inset.y + fitted.height * origin.y,
            width: fitted.width * size.width,
            height: fitted.height * size.height
        )
    }

    /// Cream or near-black, decided by the band the type lands on.
    ///
    /// **Measured, not tabled by pack kind.** A table keyed on
    /// `ExpansionPack.Kind` would be a second place the art's colours are
    /// written down, and the shop's five upgrade cartridges are not a `Kind` at
    /// all. So this reads the sprite: the mean luminance of the band rectangle,
    /// once per stem, cached.
    ///
    /// The split is not close. Across the seventeen the means run 0.27-0.41 on
    /// the burgundy and teal bands and 0.65-0.70 on the amber and gold ones,
    /// with nothing between — so a threshold at 0.5 has a quarter of the range
    /// of headroom on both sides, and a nineteenth cartridge in some new colour
    /// gets the right ink by arriving.
    ///
    /// The two inks are the picture's own: `#2B2118` is what `wellLabel`
    /// already prints in, and the cream is the chrome family's highlight.
    private static let bandInkThreshold: CGFloat = 0.5

    @MainActor private static var bandLuminance: [String: CGFloat] = [:]

    @MainActor
    private static func bandIsLight(_ image: UIImage, stem: String) -> Bool {
        if let hit = bandLuminance[stem] { return hit >= bandInkThreshold }
        let measured = measureBand(image) ?? 0
        bandLuminance[stem] = measured
        return measured >= bandInkThreshold
    }

    /// The mean luminance of the band's opaque pixels, or nil when the sprite
    /// cannot be read. Nil resolves to dark, which puts cream on it — the safer
    /// failure, because fifteen of seventeen bands are dark and a cream label on
    /// a light band is faint where a dark one on a dark band is gone.
    private static func measureBand(_ image: UIImage) -> CGFloat? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &data, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        let y0 = Int(CGFloat(h) * bandOrigin.y)
        let y1 = min(h - 1, Int(CGFloat(h) * (bandOrigin.y + bandSize.height)))
        let x0 = Int(CGFloat(w) * bandOrigin.x)
        let x1 = min(w - 1, Int(CGFloat(w) * (bandOrigin.x + bandSize.width)))
        guard y0 <= y1, x0 <= x1 else { return nil }

        var total: CGFloat = 0
        var n = 0
        for y in y0...y1 {
            for x in x0...x1 {
                let i = (y * w + x) * 4
                guard data[i + 3] > 200 else { continue }
                total += (0.299 * CGFloat(data[i])
                    + 0.587 * CGFloat(data[i + 1])
                    + 0.114 * CGFloat(data[i + 2])) / 255
                n += 1
            }
        }
        return n > 0 ? total / CGFloat(n) : nil
    }

    /// The name, printed in the top band.
    ///
    /// Sized off the band and floored by `minimumScaleFactor`, exactly as
    /// `wellLabel` is and for the same reason: `DexFont.retro` follows TEXT
    /// SIZE, the band does not, so the setting can only push the name out of the
    /// stripe it belongs in. The longest names on sale are CHASSIS SKINS and
    /// GRAPE LINEAGE at thirteen characters, which is what the floor clears.
    ///
    /// A one-pixel shadow in the opposite ink, which the well label does not
    /// have. The well is a flat cream recess; these bands carry a moulded
    /// highlight along their top edge on several sprites, and a single hard
    /// offset is what keeps the type off it without a halo.
    @ViewBuilder
    private func bandTitle(image: UIImage, stem: String?, in container: CGSize) -> some View {
        if let title, let stem {
            let band = Self.titleBand(for: image.size, in: container)
            if band.width > 0, band.height > 0 {
                let light = Self.bandIsLight(image, stem: stem)
                Text(title)
                    // 14 since 0.8.92 (item 1), up from 10, for `wellLabel`'s
                    // reason: the cap only binds on the splash hero, where the
                    // band is ~16pt tall and the type was floating in it.
                    .font(DexFont.retro(min(14, band.height * 0.62)))
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .foregroundStyle(light ? Color(dexHex: "#2B2118") : Color(dexHex: "#F7DEB6"))
                    .shadow(
                        color: (light ? Color.white : Color.black).opacity(0.45),
                        radius: 0, x: 0, y: 1
                    )
                    .frame(width: band.width, height: band.height)
                    .offset(x: band.minX, y: band.minY)
            }
        }
    }

    /// The code-drawn cartridge (0.7.3c, A2), the fallback for any product with
    /// no art.
    ///
    /// It had two standing users — the flavour wheel and the country packs —
    /// until 0.8.3's D retired both. Nothing on a shelf reaches it now, and it
    /// stays: `CartridgeArt.stem(for:)` answers nil for an id this build has
    /// never heard of, and the alternative to a drawn cartridge there is an
    /// empty tile.
    ///
    /// **A2's "no per-pack hue" argument is not overturned by the drawn art, it
    /// is satisfied by it.** That argument was that twelve chosen plastic
    /// colours arrive as twelve identical greys under the four single-phosphor
    /// modes, so colour must not carry the identity. The drawn cartridges carry
    /// theirs in the *picture* — a map of Europe, a crowned V, a knurled dial —
    /// which is still twelve different pictures after the LCD's `colorMultiply`
    /// has flattened them. What A2 forbade was a coloured rectangle, and this is
    /// not one.
    private func drawn(side: CGFloat) -> some View {
        let plateInset = side * 0.16

        return ZStack(alignment: .top) {
            CartridgeShape().fill(ink.opacity(0.22))

            VStack(spacing: 0) {
                // The label plate, sitting under the shoulder so it never
                // runs into the stepped corner.
                RoundedRectangle(cornerRadius: side * 0.06)
                    .fill(ink.opacity(0.45))
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: side * 0.26, weight: .bold))
                            .foregroundStyle(ground)
                    }
                    .padding(.horizontal, plateInset)
                    .frame(height: side * 0.42)
                    .padding(.top, side * 0.30)

                Spacer(minLength: 0)

                // Connector fingers. Four, because three reads as a grille
                // and five closes up at this size.
                HStack(spacing: side * 0.055) {
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule().fill(ink.opacity(0.6))
                    }
                }
                .frame(height: side * 0.11)
                .padding(.horizontal, plateInset)
                .padding(.bottom, side * 0.09)
            }
        }
    }
}
#endif
