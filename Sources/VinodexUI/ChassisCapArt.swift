#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

/// Serves the drawn footer caps re-inked to the chassis skin (0.8.2).
///
/// **The problem, stated plainly.** `art/icons/footerbuttons/` holds four
/// drawings — Back, Home, Settings, User — and each one is a *whole moulded
/// cap*: rim, lit face, and the symbol incised into it. (Each carried a painted
/// cast shadow too, until 0.8.3's B1 stripped it at import — see
/// `import-footer-art.py`.) They are drawn once, in one cream colourway. The
/// app has twenty-one chassis skins,
/// and a skin's identity is largely the colour of these four caps. Shipping the
/// art untouched would put the same cream button on BLUSH, on HALLOWEEN and on
/// the console liveries, which does not degrade the skin system so much as
/// delete it from the one part of the chassis the eye lands on first.
///
/// **Why not the mechanisms already here.**
///
/// - `DexChromeGlyph` deliberately does *not* tint its art, and `DexIcon`
///   renders `art:` ids untinted for the same stated reason: catalog art ships
///   its own colours. That rule is right and is not being reopened — see the
///   note below on why this is a separate type rather than a flag on that one.
/// - `.renderingMode(.template)` is the usual SwiftUI answer and is wrong here.
///   It discards everything but alpha, so a moulded cap with a rim, a highlight
///   and an incised glyph collapses to a solid disc. The drawing *is* the
///   product. (0.8.3's A does reach for exactly that operation, deliberately,
///   on a different surface: `DexChromeGlyph.flatten` renders a marquee page
///   glyph as a black silhouette, where losing the modelling is the ask.)
/// - `.colorMultiply` — the idiom the LCD's monochrome modes use — can only
///   darken. Eleven of the skins give their caps a white glyph, where multiply
///   is a no-op and the cap stays cream; the light skins multiply toward black
///   and lose the internal shading that makes it read as moulded plastic. It is
///   the right tool for flattening a whole screen to one phosphor and the wrong
///   one for re-inking a single object.
///
/// **What this does instead is the rule `GrapeSpriteLoader` set in 0.6.2**:
/// keep each pixel's *value* and take the target's hue and saturation. That is
/// the operation "the same drawing, in a different colour" — the black outline
/// stays black because black has no value to give up, the highlight stays a
/// highlight, the cast shadow stays a shadow, and the cap arrives in the skin's
/// colourway with its modelling intact. The measurement that makes it safe
/// here: all four sprites are a single hue family (0.05–0.16, the cream band)
/// running the full value range, so there is no second hue for a global
/// re-hueing to destroy.
///
/// **It has `GrapeSpriteLoader`'s masking now (0.8.4, E1), and the sentence that
/// used to end that paragraph -- "a sprite with two meaningful hues would need"
/// it, "and this deliberately does not have it" -- was the whole defect.** The
/// four sprites have one hue *as drawn*, and E1 is the observation that the
/// result should not: with a single target hue the incised symbol comes out as
/// the cap in a darker value, so the house on HOME is the same colour as the
/// button it is pressed into and reads as a groove rather than as a glyph.
/// Every skin already carries a second colour for exactly this -- `cap.glyph`,
/// which the no-art fallback path has always used to tint its SF Symbol -- and
/// until now the drawn caps threw it away.
///
/// So the pass takes two inks and a mask decides which each pixel gets. See
/// `glyphRadius` and `glyphValue`.
///
/// **A separate loader, not a flag on `PixelArtLoader`.** The base sprite is
/// still fetched through that loader — one search path, one cache of file
/// reads — and this sits on top keyed additionally by the ink. So nothing about
/// `ClassArt`, `FlavorArt` or the 32 button glyphs changes: they resolve
/// exactly as before, untinted, and no call site acquires a tint it did not ask
/// for. The tinting is opt-in at the two chassis call sites and reachable
/// nowhere else.
///
/// Cached per `stem|hex`, unbounded, which is four sprites times however many
/// skins one session tries on. `GrapeSpriteLoader` makes the same trade for the
/// same reason: the work is a full-image pass and the key space is small.
@MainActor
final class ChassisCapLoader {
    static let shared = ChassisCapLoader()

    /// The stem prefix `import-footer-art.py` writes. Kept here so the two ends
    /// of the contract are one grep apart.
    static let prefix = "footer-"

    private var cache: [String: UIImage?] = [:]

    private init() {}

    /// The cap for `stem`, re-inked to `hex`, or nil if there is no art —
    /// which is the signal the caller falls back on. A miss is cached so an
    /// unauthored cap is not re-probed and re-missed every render.
    /// `glyphHex` is the second ink (0.8.4, E1). Passing nil keeps the
    /// single-tone behaviour every caller had through 0.8.3, which is what a
    /// future caller with only one colour to give should get.
    func image(stem: String, inkHex: String, glyphHex: String? = nil) -> UIImage? {
        let key = "\(stem)|\(inkHex)|\(glyphHex ?? "-")"
        if let hit = cache[key] { return hit }
        let result = PixelArtLoader.shared.image(Self.prefix + stem)
            .flatMap { reink($0, stem: stem, to: inkHex, glyph: glyphHex) }
        cache[key] = result
        return result
    }

    // MARK: The cap's own geometry (0.8.5, E2)

    /// The circle the drawing actually occupies, and the mask that says which
    /// of its dark pixels are the incised symbol. Derived from the sprite,
    /// cached per stem, and independent of ink -- so a session that tries on
    /// twelve skins measures each cap once.
    private struct CapShape {
        /// Centre of the moulded part and its median radius, in pixels.
        ///
        /// **A scale, not a boundary, since 0.8.6 (B1).** Through 0.8.5 this
        /// circle was both: the mask normalised its radii by it *and* every
        /// pixel outside it was cut away. It is only the first now — see
        /// `coverage` for what replaced the second — so the percentile that
        /// makes it a good scale is the median rather than the 10th, which was
        /// chosen to trim the hand-drawn wobble off a clip.
        let cx: CGFloat
        let cy: CGFloat
        let radius: CGFloat
        /// How much of each pixel belongs to the cap: 0 outside the moulded
        /// part, 1 in its interior, ramping over `edgeFeather` at its edge
        /// (0.8.6, B1).
        let coverage: [CGFloat]
        /// One flag per pixel: this is the incised symbol and takes the glyph
        /// ink rather than the body's.
        let isGlyph: [Bool]
    }

    private var shapes: [String: CapShape] = [:]

    /// How dark a pixel must be to be a candidate for the incised symbol.
    ///
    /// Unchanged from 0.8.4's `glyphValue`, and it was never the half that was
    /// wrong. The symbol is a dark cel line cut into a near-white face; 0.60
    /// sits above every pixel of that line and below the face.
    private static let glyphValue: CGFloat = 0.60

    /// A dark region is the symbol only if it reaches this far *in*.
    ///
    /// See `capShape` for why the test is on a connected region rather than on
    /// a pixel. The rim, the bevel and the knurl are annuli, and every symbol
    /// in the drop covers the middle of the face.
    ///
    /// **0.50 through 0.8.5, and it was measured off a misidentified region
    /// (0.8.6, B1).** That pass recorded "the deepest-starting non-symbol is the
    /// knurl at 0.61" and "the cog's own ring is the widest symbol at 0.73". The
    /// second is not the cog. On `settings` the *facets along the bottom of the
    /// dial* are joined into one 2,491-pixel region by the moulded shading they
    /// sit in, and that region runs 0.30 to 0.735 — it is what 0.8.5 measured,
    /// admitted at both ends, and then re-inked as the symbol. Which is the grey
    /// band across the lower teeth of the gear in the reference photographs: the
    /// glyph ink is a near-white on most liveries, and a near-white has no
    /// saturation to give, so a pixel wrongly claimed by it comes out at its own
    /// value in grey and reads as art that was never recoloured at all.
    ///
    /// Re-measured over the four: the symbols reach 0.002, 0.038, 0.043 and
    /// 0.107, and the nearest thing that is not one bottoms out at 0.297. The
    /// bound goes between them rather than beside one of them.
    private static let glyphInnerReach: CGFloat = 0.20

    /// And it may not reach this far out. Kept from 0.8.5 as a second guard:
    /// with the inner reach corrected it excludes nothing on this drop, and it
    /// is what would stop a knurl that merged into a symbol from carrying the
    /// symbol's ink out to the rim. The symbols run to 0.578-0.624, so it is not
    /// close to any of them.
    private static let glyphOuterLimit: CGFloat = 0.78

    /// The width, in source pixels, of the alpha ramp at the cap's edge.
    ///
    /// The sprites have strictly binary alpha -- measured: zero pixels between
    /// 0 and 255 in all four -- so without this the silhouette is an aliased
    /// staircase at 250px which nearest-neighbour then carries, unsoftened,
    /// down to the 60pt the band draws it at.
    private static let edgeFeather: CGFloat = 1.5

    // MARK: Fitting the cap (0.8.5, E2)

    /// Measure the cap's circle and its symbol, once per sprite.
    ///
    /// **Why the 0.8.4 pair of constants had to go.** That pass masked the
    /// symbol as "within 0.72 of the *image's* inscribed radius, and darker than
    /// 0.60", on a stated measurement that the values inside the disc are
    /// bimodal with the bevel sitting safely at 0.70-0.78. Re-measured over the
    /// shipped drop, they are not: every radius band carries 760-1,711 pixels
    /// below 0.50, and 61% of what the mask captured on BACK sat between 0.6 and
    /// 0.72 of the radius -- the moulded bevel along the lower right, painted in
    /// the *glyph* ink. On a cream cap over a cream chassis that is invisible;
    /// on a pink cap over a green one it is the grey band across the bottom of
    /// every button in the photographs.
    ///
    /// No pair of thresholds separates them, because the two sets overlap in
    /// both variables. What separates them cleanly is *shape*: the symbol is an
    /// island in the middle of the face, and the rim, bevel and knurl are annuli
    /// that never come near the centre. So the dark pixels are grouped into
    /// connected regions and a region is the symbol when it starts inside
    /// `glyphInnerReach` and stays inside `glyphOuterLimit`. Measured over the
    /// four: the symbols run 0.00-0.62, 0.00-0.62, 0.10-0.60 and 0.04-0.73, and
    /// every other region begins at 0.61 or beyond and runs past 0.80.
    ///
    /// That keeps 0.8.4's real virtue -- nobody authors a stencil, and a fifth
    /// cap drawn in this style is masked correctly by arriving -- while failing
    /// visibly rather than silently for one drawn in some other style: its
    /// symbol stays the body colour, which is where all four sat in 0.8.3.
    ///
    /// **And the clip is not a circle any more (0.8.6, B1).** 0.8.4 clipped at
    /// `min(w, h) / 2` about the image centre; 0.8.5 refitted that to the alpha
    /// centroid and the 10th percentile of 360 rays, which was a better circle
    /// and still the wrong *kind* of boundary. Two things are wrong with fitting
    /// one at all. The cap the fit was validated on is a disc and the cog is a
    /// knurled dial, so the one sprite whose silhouette the measurement does not
    /// describe is the one the item is about. And a low percentile is by
    /// construction inside the drawing: measured, it cut away 1,387 opaque
    /// pixels of `settings`, 2,912 of `home`, and left the cel outline under two
    /// pixels thick on 25 of 360 rays around the cog and gone entirely on 154
    /// around the house. An outline that survives on some rays and not others is
    /// a ragged dark rim, which is the fringe the photographs show.
    ///
    /// The clip the drawing already carries is its own alpha. So the moulded
    /// part is the **largest connected opaque component** and the coverage ramps
    /// with each pixel's distance to the outside of it -- shape-correct for a
    /// disc, for a gear, and for whatever a fifth cap is drawn as, with no
    /// constant to re-fit. What the disc was there to remove in 0.8.4, the 301
    /// to 630 stray pixels the painted cast shadow left outside each cap, this
    /// removes by the same rule: after 0.8.5 border-flooded that shadow at
    /// import, the strays are down to **159 pixels on `home` and one or two on
    /// the other three**, and they are speckle detached from the part.
    private func capShape(stem: String, data: [UInt8], w: Int, h: Int) -> CapShape {
        if let hit = shapes[stem] { return hit }
        let fitted = fitCap(data: data, w: w, h: h)
        shapes[stem] = fitted
        return fitted
    }

    /// The measurement itself. Separate from the cache so the cache is one line
    /// and the geometry is the rest of the file.
    private func fitCap(data: [UInt8], w: Int, h: Int) -> CapShape {
        let count = w * h
        let blank = CapShape(cx: CGFloat(w) / 2, cy: CGFloat(h) / 2,
                             radius: CGFloat(min(w, h)) / 2,
                             coverage: [CGFloat](repeating: 0, count: count),
                             isGlyph: [Bool](repeating: false, count: count))

        // The moulded part: the largest connected run of opaque pixels. Flood
        // fills throughout this method use an explicit stack rather than
        // recursion — a cap is a quarter of a million pixels and one region can
        // be most of them.
        var opaque = [Bool](repeating: false, count: count)
        for p in 0..<count where data[p * 4 + 3] > 0 { opaque[p] = true }
        var seen = [Bool](repeating: false, count: count)
        var part = [Bool](repeating: false, count: count)
        var stack: [Int] = []
        var region: [Int] = []
        var bestSize = 0
        for start in 0..<count where opaque[start] && !seen[start] {
            stack.removeAll(keepingCapacity: true)
            region.removeAll(keepingCapacity: true)
            stack.append(start)
            seen[start] = true
            while let p = stack.popLast() {
                region.append(p)
                let x = p % w, y = p / w
                if x > 0, opaque[p - 1], !seen[p - 1] { seen[p - 1] = true; stack.append(p - 1) }
                if x < w - 1, opaque[p + 1], !seen[p + 1] { seen[p + 1] = true; stack.append(p + 1) }
                if y > 0, opaque[p - w], !seen[p - w] { seen[p - w] = true; stack.append(p - w) }
                if y < h - 1, opaque[p + w], !seen[p + w] { seen[p + w] = true; stack.append(p + w) }
            }
            if region.count > bestSize {
                bestSize = region.count
                part = [Bool](repeating: false, count: count)
                for p in region { part[p] = true }
            }
        }
        guard bestSize > 0 else { return blank }

        // Coverage: a breadth-first distance from the outside of the part, in
        // pixels, converted to an alpha ramp `edgeFeather` wide. Four-connected
        // is exact enough for a ramp a pixel and a half across.
        var dist = [Int32](repeating: .max, count: count)
        var queue: [Int] = []
        queue.reserveCapacity(bestSize / 4)
        for p in 0..<count where part[p] {
            let x = p % w, y = p / w
            let edge = x == 0 || x == w - 1 || y == 0 || y == h - 1
                || !part[p - 1] || !part[p + 1] || !part[p - w] || !part[p + w]
            if edge { dist[p] = 1; queue.append(p) }
        }
        var head = 0
        while head < queue.count {
            let p = queue[head]; head += 1
            let x = p % w, y = p / w
            let next = dist[p] + 1
            if x > 0, part[p - 1], dist[p - 1] > next { dist[p - 1] = next; queue.append(p - 1) }
            if x < w - 1, part[p + 1], dist[p + 1] > next { dist[p + 1] = next; queue.append(p + 1) }
            if y > 0, part[p - w], dist[p - w] > next { dist[p - w] = next; queue.append(p - w) }
            if y < h - 1, part[p + w], dist[p + w] > next { dist[p + w] = next; queue.append(p + w) }
        }
        var coverage = [CGFloat](repeating: 0, count: count)
        for p in 0..<count where part[p] {
            coverage[p] = min(CGFloat(dist[p]) / Self.edgeFeather, 1)
        }

        var sx = 0, sy = 0, n = 0
        for p in 0..<count where part[p] { sx += p % w; sy += p / w; n += 1 }
        let cx = CGFloat(sx) / CGFloat(n)
        let cy = CGFloat(sy) / CGFloat(n)

        // The part's outermost radius per ray, taken at the median: the mask
        // below divides by this, so what is wanted is the cap's size, not a
        // boundary anything is cut at.
        let rays = 360
        var radii = [CGFloat](repeating: 0, count: rays)
        let limit = CGFloat(max(w, h))
        for i in 0..<rays {
            let theta = CGFloat(i) * 2 * .pi / CGFloat(rays)
            let dx = cos(theta), dy = sin(theta)
            var r: CGFloat = 0
            var last: CGFloat = 0
            while r < limit {
                let x = Int((cx + r * dx).rounded())
                let y = Int((cy + r * dy).rounded())
                if x >= 0, x < w, y >= 0, y < h, part[y * w + x] { last = r }
                r += 0.5
            }
            radii[i] = last
        }
        radii.sort()
        let radius = max(radii[rays / 2], 1)

        // Dark regions, grouped.
        var dark = [Bool](repeating: false, count: count)
        for p in 0..<count where part[p] {
            let i = p * 4
            let v = Self.value(r: data[i], g: data[i + 1], b: data[i + 2], a: data[i + 3])
            dark[p] = v > 0.06 && v < Self.glyphValue
        }
        var isGlyph = [Bool](repeating: false, count: count)
        var visited = [Bool](repeating: false, count: count)
        for start in 0..<count where dark[start] && !visited[start] {
            stack.removeAll(keepingCapacity: true)
            region.removeAll(keepingCapacity: true)
            stack.append(start)
            visited[start] = true
            var minR = CGFloat.greatestFiniteMagnitude
            var maxR: CGFloat = 0
            while let p = stack.popLast() {
                region.append(p)
                let x = p % w, y = p / w
                let dx = CGFloat(x) - cx, dy = CGFloat(y) - cy
                let d = (dx * dx + dy * dy).squareRoot() / radius
                minR = min(minR, d)
                maxR = max(maxR, d)
                if x > 0, dark[p - 1], !visited[p - 1] { visited[p - 1] = true; stack.append(p - 1) }
                if x < w - 1, dark[p + 1], !visited[p + 1] { visited[p + 1] = true; stack.append(p + 1) }
                if y > 0, dark[p - w], !visited[p - w] { visited[p - w] = true; stack.append(p - w) }
                if y < h - 1, dark[p + w], !visited[p + w] { visited[p + w] = true; stack.append(p + w) }
            }
            guard minR < Self.glyphInnerReach, maxR < Self.glyphOuterLimit else { continue }
            for p in region { isGlyph[p] = true }
        }

        return CapShape(cx: cx, cy: cy, radius: radius, coverage: coverage, isGlyph: isGlyph)
    }

    private static func value(r: UInt8, g: UInt8, b: UInt8, a: UInt8) -> CGFloat {
        let af = max(CGFloat(a) / 255, 0.001)
        return min(max(CGFloat(r), max(CGFloat(g), CGFloat(b))) / 255 / af, 1)
    }

    // MARK: Re-inking

    /// Every opaque pixel keeps its value and takes one of the two targets' hue
    /// and saturation. See the type's note for why this and not a template or a
    /// multiply, and `glyphRadius` / `glyphValue` for how the two are told apart.
    ///
    /// **And the clip, which is the silhouette's own since 0.8.6 (B1).** See
    /// `capShape` for the three fits this has had and why a circle was the wrong
    /// kind of boundary for a knurled dial. What survives from 0.8.4's pass is
    /// the part that was right and is kept verbatim: the clip belongs *here*
    /// rather than in a `.clipShape(Circle())` at the call site, because the
    /// view lays the sprite out with `.aspectRatio(.fit)` inside a square frame,
    /// so a circle in view space is the sprite's circle only when the sprite is
    /// exactly square -- three of the four are not (253x256, 254x256, 266x263)
    /// -- and a shape modifier would clip the press animation's scale along with
    /// it. In pixel space the two are the same by construction, and this runs
    /// once per (stem, ink) pair rather than every frame.
    ///
    /// The alpha *ramps* over the last `edgeFeather` pixels instead of stopping
    /// dead (0.8.5, E2). The sprites are strictly binary -- there is not one
    /// partially transparent pixel in the drop -- so every edge in this pipeline
    /// was aliased from the file all the way to the screen.
    private func reink(_ image: UIImage, stem: String, to hex: String, glyph glyphHex: String?) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }

        let body = hsv(of: hex)
        let ink = glyphHex.map(hsv(of:)) ?? body
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &data, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        let shape = capShape(stem: stem, data: data, w: w, h: h)

        for y in 0..<h {
            for x in 0..<w {
                let p = y * w + x
                let i = p * 4
                let a = data[i + 3]
                guard a > 0 else { continue }

                // Nothing detached from the moulded part reaches the chassis,
                // and the last pixel and a half of it fades rather than stops.
                let coverage = shape.coverage[p]
                if coverage <= 0 {
                    data[i] = 0; data[i + 1] = 0; data[i + 2] = 0; data[i + 3] = 0
                    continue
                }

                let (_, _, value) = hsv(r: data[i], g: data[i + 1], b: data[i + 2], a: a)
                // A near-black pixel has no colour to restate: the cel outline is
                // structure, and pushing a hue into it would draw the cap's own
                // edge in the skin's colour and lose the thing that separates the
                // part from the shell behind it. (Through 0.8.2 this also protected
                // the painted cast shadow; 0.8.3's B1 removed that at import, so
                // the outline is all this clause is guarding now.)
                let outA = UInt8((CGFloat(a) * coverage).rounded())
                guard value > 0.06 else {
                    if coverage < 1 {
                        // Rescale the premultiplied channels with the alpha, or
                        // the feathered ring of the outline draws at full weight
                        // against a fading alpha and reads as a bright fringe.
                        data[i] = UInt8((CGFloat(data[i]) * coverage).rounded())
                        data[i + 1] = UInt8((CGFloat(data[i + 1]) * coverage).rounded())
                        data[i + 2] = UInt8((CGFloat(data[i + 2]) * coverage).rounded())
                        data[i + 3] = outA
                    }
                    continue
                }

                let target = shape.isGlyph[p] ? ink : body
                let out = rgb(h: target.h, s: target.s, v: value)
                data[i] = UInt8(out.r * CGFloat(outA) / 255)
                data[i + 1] = UInt8(out.g * CGFloat(outA) / 255)
                data[i + 2] = UInt8(out.b * CGFloat(outA) / 255)
                data[i + 3] = outA
            }
        }

        guard let outCG = ctx.makeImage() else { return nil }
        return UIImage(cgImage: outCG, scale: image.scale, orientation: .up)
    }

    // MARK: Colour maths
    //
    // The same three functions `GrapeSpriteLoader` carries. Copied rather than
    // shared: that type is a catalog concern and this is a chassis one, they
    // would have to agree on a home, and three private pure functions is a
    // cheaper duplication than a colour utility that two unrelated features
    // both depend on. If a third caller appears, that is the moment to hoist.

    private func hsv(r: UInt8, g: UInt8, b: UInt8, a: UInt8) -> (h: CGFloat, s: CGFloat, v: CGFloat) {
        let af = max(CGFloat(a) / 255, 0.001)
        let rf = min(CGFloat(r) / 255 / af, 1)
        let gf = min(CGFloat(g) / 255 / af, 1)
        let bf = min(CGFloat(b) / 255 / af, 1)
        let maxC = max(rf, gf, bf), minC = min(rf, gf, bf)
        let delta = maxC - minC
        var hue: CGFloat = 0
        if delta > 0 {
            if maxC == rf { hue = ((gf - bf) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxC == gf { hue = (bf - rf) / delta + 2 }
            else { hue = (rf - gf) / delta + 4 }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, maxC == 0 ? 0 : delta / maxC, maxC)
    }

    /// Accepts `#rrggbb`. The skin tables also carry a handful of
    /// `rgba(...)` strings for the translucent shells; those resolve to a
    /// saturation of zero here, which greys the cap rather than mis-hueing it —
    /// the honest failure, and the one a smoked shell wants anyway.
    private func hsv(of hex: String) -> (h: CGFloat, s: CGFloat, v: CGFloat) {
        guard hex.hasPrefix("#"), hex.count >= 7 else { return (0, 0, 1) }
        var value: UInt64 = 0
        Scanner(string: String(hex.dropFirst()).prefix(6).description).scanHexInt64(&value)
        return hsv(
            r: UInt8((value >> 16) & 0xFF),
            g: UInt8((value >> 8) & 0xFF),
            b: UInt8(value & 0xFF),
            a: 255
        )
    }

    private func rgb(h: CGFloat, s: CGFloat, v: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let c = v * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        let (r, g, b): (CGFloat, CGFloat, CGFloat)
        switch Int(h * 6) % 6 {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return ((r + m) * 255, (g + m) * 255, (b + m) * 255)
    }
}
#endif
