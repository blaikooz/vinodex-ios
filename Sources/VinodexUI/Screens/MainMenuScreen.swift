#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// Four category tiles curved around a central search button.
///
/// Slimmed from the web app's menu: the moon-dial and separate globe buttons are
/// out of scope, and REGIONS opens the globe directly rather than a 2D map.
///
/// **One cluster since 0.8.4 (B1).** Through 0.8.3 this was a `VStack` of three
/// rows — two tiles, the search circle, two tiles — which is the same four
/// destinations and a different object: the circle was a *row* between two pairs,
/// so it read as a fifth control filed with the others rather than as the thing
/// they are arranged around, and the menu was three bands of furniture stacked up
/// the LCD.
///
/// B1 asks for the four to become the four corners of one housing with the
/// search circle in the middle of them, each tile rounded on its outer corner
/// and scooped on its inner one so the four scoops describe the circle. That is
/// a real change of subject and not a re-skin: the four tiles stop being a list
/// and become a *dial*, which is what the reference is — a moulded four-way pad
/// with a select button at the centre, the shape every handheld this device is
/// pretending to be has had on its front since 1989.
///
/// The geometry lives in `ScoopedTile`; everything about the tiles themselves —
/// the colours, the fake extrusion, the press, the fitted glyph box — is
/// unchanged from 0.8.0's L and 0.8.1's J3.
public struct MainMenuScreen: View {
    let onSelect: (DexRoute) -> Void

    /// The eight stored settings, as one model (arch **A17**).
    ///
    /// This screen used to hold a second declaration, on `TextScale`, whose
    /// only job was to force a re-render when the text size changed. It is
    /// gone and nothing was lost: `RootView` keys the whole chassis on
    /// `.id(textScale|uiScale)`, so a text-size change destroys and rebuilds
    /// this screen anyway. The belt was doing the braces' work.
    var settings: AppSettings = .shared
    /// Drives the TODAY strip's done-state and streak count (AUDIT M23).
    @State private var streak = StreakStore.shared

    private var mode: LcdMode { settings.lcdMode }

    public init(onSelect: @escaping (DexRoute) -> Void) {
        self.onSelect = onSelect
    }

    // MARK: Cluster geometry
    //
    // Four numbers, all of them in points and none of them a fraction of the
    // LCD, because the housing is a moulded part and a moulded part does not
    // change proportion with the screen it is on.

    /// The channel between the four tiles, and between each tile and the
    /// circle. One number for both, which is what makes the cross read as a
    /// cross rather than as four tiles that happen to be near a button.
    private static let channel: CGFloat = 9
    /// The central button's diameter. Larger than 0.8.3's 102 — B1 asks for a
    /// "prominent centre circle", and the tiles gave up the row it used to
    /// occupy, so there is height to spend.
    private static let centerDiameter: CGFloat = 116
    /// The rounded *outer* corner. `DexMetrics.menuTileCorner` is 26 and was
    /// drawn for a tile rounded on all four; on a tile with one concave corner
    /// a larger radius reads better, because the eye has the scoop to compare
    /// it against.
    private static let outerCorner: CGFloat = 30
    /// The housing's own padding around the four tiles.
    ///
    /// 9 → 6 in 0.8.5 (C2). See `outerPad` for what the pair of trims buys.
    private static let housingInset: CGFloat = 6

    /// What the housing leaves between itself and the LCD's edge.
    ///
    /// **9pt of it goes back to the tiles in 0.8.5 (C2).** It was a bare
    /// `.padding(8)` with `housingInset` at 9, so the cluster was inset 17pt on
    /// every side of a screen it is the only thing on. C2 asks for the four
    /// buttons to fill the main screen, and this is where the room was: the
    /// tiles already take everything the housing gives them
    /// (`.frame(maxWidth: .infinity, maxHeight: .infinity)`), so the resize is
    /// entirely a question of what the housing is asked to give up.
    ///
    /// 2 rather than 0 because the housing has a 2pt stroke and a shadow, and a
    /// moulded plate flush against the bezel reads as a rendering error rather
    /// than as a part. Named rather than inline so the two numbers that make up
    /// the inset are in one place — which is the thing that made this hard to
    /// see, one of them being a literal at the bottom of `body`.
    private static let outerPad: CGFloat = 2

    /// The radius of the bite taken out of each tile: the circle plus one
    /// channel, so the gap around the button is the same gap as between the
    /// tiles.
    private static var scoop: CGFloat { centerDiameter / 2 + channel }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            ZStack {
                VStack(spacing: Self.channel) {
                    HStack(spacing: Self.channel) {
                        tile("GRAPES", quadrant: .topLeading,
                             art: "grapes", symbol: "circle.grid.3x3.fill",
                             livery: .violet) {
                            onSelect(.list(category: .grapes, filter: nil))
                        }
                        // The walkthrough's first step (0.8.9d, G2). GRAPES
                        // rather than one of the other three because it is the
                        // shelf with a TRIED control at the end of it, which is
                        // where the sequence is going.
                        .coachmarkTarget(.menuTile)
                        tile("REGIONS", quadrant: .topTrailing,
                             art: "regions", symbol: "globe.americas.fill",
                             livery: .green) {
                            onSelect(.globe)
                        }
                    }
                    HStack(spacing: Self.channel) {
                        // Matches the web app's own STYLES button, which uses
                        // lucide's `Wine` (MainMenu.tsx). This was
                        // `square.stack.3d.up.fill` — a layers glyph that had no
                        // counterpart on the web side. SF Symbols 4 / iOS 16, so
                        // it clears the iOS 17 deployment target.
                        tile("STYLES", quadrant: .bottomLeading,
                             art: "styles", symbol: "wineglass.fill",
                             livery: .orange) {
                            onSelect(.list(category: .styles, filter: nil))
                        }
                        tile("FLAVORS", quadrant: .bottomTrailing,
                             art: "flavors", symbol: "leaf.fill",
                             livery: .emerald) {
                            onSelect(.list(category: .flavors, filter: nil))
                        }
                    }
                }
                // The circle is drawn *over* the cluster and the cluster is cut
                // away beneath it, rather than the two being laid out beside
                // each other. That is the only arrangement in which the scoops
                // and the button are guaranteed concentric at every LCD size —
                // both are centred on the same point by construction.
                searchButton
            }
            .padding(Self.housingInset)
            .background(housing)
            .padding(Self.outerPad)
        }
    }

    /// The dark moulded plate the four tiles are set into.
    ///
    /// New in 0.8.4. The three-row layout had no housing because it had nothing
    /// to house — four tiles on the LCD ground, with the ground showing between
    /// them. A cluster needs one: the channels between the tiles are what makes
    /// the shape read, and a channel is only a channel if there is something
    /// visible at the bottom of it.
    private var housing: some View {
        RoundedRectangle(cornerRadius: Self.outerCorner + Self.housingInset, style: .continuous)
            .fill(mode.ground.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: Self.outerCorner + Self.housingInset, style: .continuous)
                    .strokeBorder(.black.opacity(0.35), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    /// A category tile.
    ///
    /// The livery is a token rather than a pair of hex literals at the call
    /// site (AUDIT **L33**). Two consequences beyond tidiness: the four faces
    /// here and the settings grid's six were the same seven colours written
    /// twice, and these four had no light-mode value at all — a bright face on
    /// the pale page, which is precisely the class of miss the item names.
    /// See `DexTileLivery`.
    private func tile(
        _ title: String,
        quadrant: ScoopedTile.Quadrant,
        art: String,
        symbol: String,
        livery: DexTileLivery,
        action: @escaping () -> Void
    ) -> some View {
        // C5 (0.7.1): under an Emulator mode the four category faces fold
        // toward that machine's ramp, so the menu stops being four Tailwind
        // squares bolted to a starship console. Untouched everywhere else.
        // The blend works on the hexes, not on the resolved `Color`s, which is
        // why the livery is asked for those.
        let style = livery.hexes(mode)
        let paint = mode.chrome(face: style.face, shadow: style.shadow)
        let label = mode.chromeInk(over: style.face, preferring: livery.ink)
        let shape = ScoopedTile(
            quadrant: quadrant,
            outerCorner: Self.outerCorner,
            scoop: Self.scoop,
            channel: Self.channel / 2
        )

        return Button {
            Haptics.screenTap()
            action()
        } label: {
            // **The tile measures itself as of 0.8.5 (C1).** See `contentShift`
            // for why a `GeometryReader` had to appear here: the place the
            // content belongs depends on the tile's own width and height, and a
            // `.offset` computed from constants could not see either.
            GeometryReader { geo in
                let shift = Self.contentShift(in: geo.size, quadrant: quadrant)
                tileContent(title, symbol: symbol, art: art, label: label)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .offset(x: shift.x, y: shift.y)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                shape
                    .fill(paint.face)
                    .overlay(alignment: .bottom) {
                        // The web tiles use a 6px bottom border as a fake
                        // extrusion. Clipped to the tile's own shape now, so the
                        // strip follows the scoop out instead of running under
                        // it — on the two bottom tiles the bite is *in* this
                        // edge, and an unclipped band would have drawn straight
                        // across the channel the circle sits in.
                        paint.shadow.frame(height: 6)
                    }
                    .clipShape(shape)
            )
            .overlay(
                shape
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            )
            // The hit area follows the drawing. Without this the corner the
            // scoop removed is still tappable, and the 9pt channel around the
            // circle becomes a place where a press lands on a tile the user is
            // not pointing at.
            .contentShape(shape)
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
    }

    /// The glyph over the label — one tile's contents, extracted in 0.8.5 (C1)
    /// so the `GeometryReader` above wraps something with a name.
    private func tileContent(
        _ title: String,
        symbol: String,
        art: String,
        label: Color
    ) -> some View {
        // Sized up in 0.6.1, then eased back a notch (0.6.2, B1) — 64pt
        // glyphs crowded the tile edges at the LARGE text scale.
        VStack(spacing: 10) {
                DexChromeGlyph(art, symbol: symbol, size: 52, tint: label)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2)
                    // **The fixed glyph box is what aligns the four titles**
                    // (0.8.0, L). The report was that STYLES and FLAVORS sit off
                    // the baseline the other two share, and the cause is not in
                    // this `VStack` or in either of those tiles: an
                    // `Image(systemName:)` lays out at the *symbol's own*
                    // bounding box, and four SF Symbols at one point size are
                    // four different heights. `wineglass.fill` is tall and
                    // narrow, `leaf.fill` is squat, `circle.grid.3x3.fill` and
                    // `globe.americas.fill` are both near-square — so each stack
                    // was a different total height, each centred in its own tile,
                    // and the labels landed at four different y positions. The
                    // two square glyphs agreeing with each other is what made it
                    // look like a fault in the other two.
                    //
                    // The same number as the point size, so a glyph that happens
                    // to be exactly square is unmoved and every other one centres
                    // inside the box it would have filled. `frame` does not clip,
                    // so a symbol taller than its nominal size still draws whole —
                    // it simply stops charging the stack for it. Fixing it here
                    // rather than per tile is the point: the fifth tile anybody
                    // adds is aligned by default.
                    //
                    // **The box outlived the symbols (0.8.1, J3).** These four
                    // are drawn button faces now, and bitmaps have a fixed
                    // aspect of their own that is not the symbol's — `styles`
                    // is 134x216 and `flavors` is 215x198. Left to itself a
                    // raster swap would have re-broken exactly what L fixed, in
                    // the same place, for a different reason.
                    // `DexChromeGlyph` fits inside a square of this size, so
                    // the box below is now redundant rather than wrong: kept
                    // because a fifth tile added with a plain symbol still
                    // needs it, and because deleting the guard is how the bug
                    // comes back.
                    //
                    // 56 -> 52 in 0.8.4 (B1), the one number the cluster moved:
                    // the content has to clear the scoop as well as the tile's
                    // own edges, and `contentShift` is what buys most of that
                    // back.
                    .frame(height: 52)
                Text(title)
                    .font(DexFont.retro(18))
                    .foregroundStyle(label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 1, y: 1)
            }
    }

    /// How far a tile's contents move away from the centre of the cluster.
    ///
    /// **Measured rather than guessed, as of 0.8.5 (C1).** 0.8.4 shipped a flat
    /// `scoop / 8` — 8.38pt — on both axes, with the reasoning that the tile's
    /// rectangle is missing a quarter, so centred content sits partly under the
    /// bite and has to be pushed out of it. The observation was right and the
    /// number was arrived at by eye, which C1 is the report of. Two things are
    /// wrong with a constant here:
    ///
    /// 1. **It is not the same on both axes.** The bite is a circle and the
    ///    tiles are not square — at the sizes the cluster lays out at they run
    ///    roughly 150x180 to 170x220 — so the bite removes a different fraction
    ///    of the width than of the height. The correct pair over that range is
    ///    about (-4.4, -6.4) to (-7.1, -8.0). 0.8.4 pushed 8.38 on both, which
    ///    is up to 4pt too far horizontally and up to 2pt too far vertically.
    /// 2. **It does not scale.** The right offset shrinks as the tile grows,
    ///    because the bite is a fixed radius taking a smaller share of a larger
    ///    tile. A constant is therefore wrong in a direction that changes with
    ///    the phone — and C2 has just made every tile 9pt larger, which would
    ///    have made an already-too-large constant worse.
    ///
    /// So this is the area centroid of the shape `ScoopedTile` actually draws:
    /// the rectangle, less the bite, less the three rounded outer corners. The
    /// content is centred on *that* point, which is what "centred in the curved
    /// tile" means and is a definition rather than a taste.
    ///
    /// **Integrated in horizontal strips**, not over a grid: for each row the
    /// shape spans one interval, whose ends are the rounded left edge and either
    /// the rounded right edge or the bite's chord. That is `strips` iterations
    /// instead of `strips²`, exact to the strip height, and it was validated
    /// against a 700x700 grid before it was written here — the two agree to
    /// within 0.002pt at every tile size above.
    ///
    /// Computed for the top-leading quadrant and mirrored, exactly as the path
    /// itself is, so there is one piece of geometry to get right rather than
    /// four.
    static func contentShift(in size: CGSize, quadrant: ScoopedTile.Quadrant) -> CGPoint {
        let w = size.width, h = size.height
        guard w > 1, h > 1 else { return .zero }

        let biteX = w + channel / 2
        let biteY = h + channel / 2
        let r = min(outerCorner, min(w, h) / 2)
        let strips = 240
        let dy = h / CGFloat(strips)

        var area: CGFloat = 0, mx: CGFloat = 0, my: CGFloat = 0
        for i in 0..<strips {
            let y = (CGFloat(i) + 0.5) * dy
            var lo: CGFloat = 0
            if y < r {
                lo = r - (max(r * r - (r - y) * (r - y), 0)).squareRoot()
            } else if y > h - r {
                let d = y - (h - r)
                lo = r - (max(r * r - d * d, 0)).squareRoot()
            }
            var hi = w
            if y < r {
                hi = w - r + (max(r * r - (r - y) * (r - y), 0)).squareRoot()
            }
            let dyb = y - biteY
            if abs(dyb) < scoop {
                hi = min(hi, biteX - (scoop * scoop - dyb * dyb).squareRoot())
            }
            guard hi > lo else { continue }
            let a = (hi - lo) * dy
            area += a
            mx += (hi + lo) / 2 * a
            my += y * a
        }
        guard area > 0 else { return .zero }

        let dx = mx / area - w / 2
        let dyOut = my / area - h / 2
        switch quadrant {
        case .topLeading: return CGPoint(x: dx, y: dyOut)
        case .topTrailing: return CGPoint(x: -dx, y: dyOut)
        case .bottomLeading: return CGPoint(x: dx, y: -dyOut)
        case .bottomTrailing: return CGPoint(x: -dx, y: -dyOut)
        }
    }

    /// v0.5.3: the search button wears the mode's control livery, like the
    /// chassis buttons around it — in DARK that resolves to the same amber
    /// it has always been.
    ///
    /// **It opens MASTER SEARCH.** Since 0.7.0 (I1) the destination is
    /// `.chipFilter`, which used to be called FILTER SEARCH: a text field over
    /// the whole database (the identical `.masterSearch(_:)` query the retired
    /// route ran) *plus* the chips and a live surviving-count. It is a strict
    /// superset, so the menu's most prominent control leads to the better of
    /// the two; 0.7.1's A1 finished the job by giving it the name.
    ///
    /// **The glyph is the magnifier again (0.7.1, A2).** 0.7.0 swapped it for
    /// `line.3.horizontal.decrease` so the change of destination would be
    /// visible from the one screen it happens on. That was right for one
    /// release and wrong as a resting state: filter bars are a statement about
    /// a list you are already looking at, and this is the way *in*. A2 puts
    /// every search affordance in the app on `DexGlyph.search`, and this is the
    /// largest one. The bare form, not `.circle.fill` — a glyph with its own
    /// circle inside the circle reads as a button drawn twice.
    ///
    /// **The centre of the dial since 0.8.4 (B1)**, which is why it no longer
    /// carries a `.frame(height:)`: it used to be a row in a `VStack` and had to
    /// declare how much of the column it took. It is now laid over the cluster
    /// and takes none.
    private var searchButton: some View {
        Button {
            Haptics.screenTap()
            onSelect(.chipFilter)
        } label: {
            ZStack {
                Circle().fill(mode.controlAccent.bright)
                Circle().strokeBorder(mode.controlAccent.mid, lineWidth: 6)
                DexChromeGlyph(
                    "search",
                    symbol: DexGlyph.search,
                    size: 44,
                    weight: .bold,
                    tint: mode.controlAccent.ink
                )
            }
            .frame(width: Self.centerDiameter, height: Self.centerDiameter)
            // Radius trimmed to under the channel width. The glow is what makes
            // the button read as lit, and at 12 it washed the full 9pt gap and
            // spilled onto all four tiles — which on a cluster reads as the
            // scoops being out of register rather than as a glow.
            .shadow(color: mode.controlAccent.bright.opacity(0.4), radius: 7)
        }
        .buttonStyle(DexPressStyle(scale: 0.95))
    }
}

/// One corner tile of the main menu's dial: rounded outside, scooped inside
/// (0.8.4, B1).
///
/// **Why a hand-built path rather than a rounded rect minus a circle.**
/// `Path.subtracting` would give the concave corner in three lines, and it was
/// the first thing tried. What it cannot give is the *transition*: where the
/// bite's arc meets the tile's straight edge, the two cross at close to a right
/// angle, so each scoop ends in two hard cusps. On one tile that reads as a
/// chip in the moulding; on four, arranged symmetrically around a circle, it
/// reads as eight of them. The reference's tiles meet their scoop smoothly,
/// which means a fillet, which means knowing where the tangent points are.
///
/// So the path is drawn: outer corners, then a small convex fillet, the concave
/// arc, the matching fillet, and back. The fillet centre sits at distance
/// `fillet` from the edge and `scoop + fillet` from the bite's centre — external
/// tangency, which is the condition for the two arcs to meet without a corner —
/// and `d` below is the one length that falls out of it.
///
/// Built for the top-leading quadrant and mirrored for the other three, so there
/// is one piece of geometry to get right rather than four. Mirroring reverses the
/// winding, which is invisible under the non-zero fill this is always used with.
///
/// **Angles increase clockwise on screen**, because y is down here; SwiftUI's
/// `clockwise:` flag is expressed in the unflipped convention, so an arc drawn in
/// the direction of increasing angle passes `clockwise: false`. Every arc below
/// but the concave one does.
struct ScoopedTile: Shape {
    enum Quadrant {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
    }

    let quadrant: Quadrant
    /// Radius of the three corners that are not the scoop.
    var outerCorner: CGFloat
    /// Radius of the bite, measured from the centre of the cluster.
    var scoop: CGFloat
    /// Half the gap between two tiles — the distance from this tile's inner
    /// corner to the cluster's centre, along each axis.
    var channel: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        // The bite's centre, in the top-leading tile's own coordinates: past its
        // bottom-right corner by half a channel on each axis.
        let c = CGPoint(x: w + channel, y: h + channel)

        // Fillet radius. A fraction of the scoop rather than a constant, so the
        // softening stays in proportion when the cluster is laid out larger, and
        // clamped so a very small tile cannot produce a fillet wider than the
        // edge it is filleting.
        let f = min(scoop * 0.22, min(w, h) / 6)
        // Distance from the bite's centre to each tangent point, along the edge.
        // Guarded because `scoop <= channel` would put the bite entirely outside
        // the tile and leave nothing to solve for — in which case there is no
        // scoop and the tile is an ordinary rounded rectangle.
        let inner = f + channel
        let outer = scoop + f
        guard outer > inner else {
            return Path(roundedRect: rect, cornerRadius: outerCorner, style: .continuous)
        }
        let d = ((outer * outer) - (inner * inner)).squareRoot()

        // Where the fillets touch the two straight edges.
        let onRight = CGPoint(x: w, y: c.y - d)
        let onBottom = CGPoint(x: c.x - d, y: h)
        // Their centres.
        let rightCentre = CGPoint(x: w - f, y: onRight.y)
        let bottomCentre = CGPoint(x: onBottom.x, y: h - f)
        // And the directions from each fillet centre toward the bite's centre,
        // which are where the fillet hands over to the concave arc.
        let toC1 = angle(from: rightCentre, to: c)
        let toC2 = angle(from: bottomCentre, to: c)

        let r = min(outerCorner, min(w, h) / 2)
        var p = Path()
        p.move(to: CGPoint(x: r, y: 0))
        p.addLine(to: CGPoint(x: w - r, y: 0))
        p.addArc(center: CGPoint(x: w - r, y: r), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: onRight)
        p.addArc(center: rightCentre, radius: f,
                 startAngle: .degrees(0), endAngle: .radians(toC1), clockwise: false)
        // The bite. Drawn in the direction of *decreasing* angle, which is what
        // makes it cut into the tile instead of bulging out of it.
        p.addArc(center: c, radius: scoop,
                 startAngle: .radians(toC1 + .pi), endAngle: .radians(toC2 + .pi), clockwise: true)
        p.addArc(center: bottomCentre, radius: f,
                 startAngle: .radians(toC2), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r, y: h))
        p.addArc(center: CGPoint(x: r, y: h - r), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addArc(center: CGPoint(x: r, y: r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()

        return p.applying(mirror(in: rect))
    }

    private func angle(from a: CGPoint, to b: CGPoint) -> CGFloat {
        atan2(b.y - a.y, b.x - a.x)
    }

    /// Flip the top-leading path into this tile's quadrant, about the rect's
    /// own centre.
    private func mirror(in rect: CGRect) -> CGAffineTransform {
        let sx: CGFloat = (quadrant == .topTrailing || quadrant == .bottomTrailing) ? -1 : 1
        let sy: CGFloat = (quadrant == .bottomLeading || quadrant == .bottomTrailing) ? -1 : 1
        guard sx < 0 || sy < 0 else { return .identity }
        return CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .scaledBy(x: sx, y: sy)
            .translatedBy(x: -rect.midX, y: -rect.midY)
    }
}
#endif
