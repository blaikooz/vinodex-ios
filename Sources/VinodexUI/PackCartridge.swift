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
    /// The drawn cartridge's stem, where one exists (0.8.2). Nil for the
    /// flavour wheel and the country packs, which have no art and keep the
    /// drawing below.
    var art: String?

    init(symbol: String, ink: Color, ground: Color, isComplete: Bool, art: String? = nil) {
        self.symbol = symbol
        self.ink = ink
        self.ground = ground
        self.isComplete = isComplete
        self.art = art
    }

    /// The 0.7.3c call: a pack draws its own glyph.
    init(pack: ExpansionPack, ink: Color, ground: Color, isComplete: Bool, art: String? = nil) {
        self.init(
            symbol: pack.symbol, ink: ink, ground: ground,
            isComplete: isComplete, art: art
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

    /// The code-drawn cartridge (0.7.3c, A2), still the fallback and still the
    /// only thing a country pack or the flavour wheel has.
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
