#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
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
    /// Nil on the shelf, where the tile prints its own label underneath at a
    /// legible size: the well is 11% of the cartridge's height, which at the
    /// shelf's 58pt is six points of type. It is set on the splash hero, where
    /// the cartridge is the page and the well is the place the name belongs.
    ///
    /// Ignored when there is no art — the code-drawn cartridge below has a
    /// glyph plate where the well would be, and printing a name over it would
    /// stack two identities on one plate.
    var label: String?

    init(
        symbol: String,
        ink: Color,
        ground: Color,
        isComplete: Bool,
        art: String? = nil,
        label: String? = nil
    ) {
        self.symbol = symbol
        self.ink = ink
        self.ground = ground
        self.isComplete = isComplete
        self.art = art
        self.label = label
    }

    /// The 0.7.3c call: a pack draws its own glyph.
    init(
        pack: ExpansionPack,
        ink: Color,
        ground: Color,
        isComplete: Bool,
        art: String? = nil,
        label: String? = nil
    ) {
        self.init(
            symbol: pack.symbol, ink: ink, ground: ground,
            isComplete: isComplete, art: art, label: label
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
    static func labelWell(for image: CGSize, in container: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0,
              container.width > 0, container.height > 0 else { return .zero }
        let scale = min(container.width / image.width, container.height / image.height)
        let fitted = CGSize(width: image.width * scale, height: image.height * scale)
        let inset = CGPoint(
            x: (container.width - fitted.width) / 2,
            y: (container.height - fitted.height) / 2
        )
        return CGRect(
            x: inset.x + fitted.width * wellOrigin.x,
            y: inset.y + fitted.height * wellOrigin.y,
            width: fitted.width * wellSize.width,
            height: fitted.height * wellSize.height
        )
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
                    .font(DexFont.retro(min(11, well.height * 0.52)))
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(Color(dexHex: "#2B2118"))
                    .frame(width: well.width, height: well.height)
                    .offset(x: well.minX, y: well.minY)
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
