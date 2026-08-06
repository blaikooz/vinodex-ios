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
            .flatMap { reink($0, to: inkHex, glyph: glyphHex) }
        cache[key] = result
        return result
    }

    // MARK: The glyph mask (0.8.4, E1)

    /// How far out from the centre a pixel may sit and still be the symbol, as
    /// a fraction of the cap's radius.
    ///
    /// The four drawings put their symbol inside the moulded face and their rim,
    /// bevel and knurl outside it. Measured across all four, the symbol's
    /// furthest ink is at 0.55 of the radius and the rim's nearest is at 0.78 --
    /// SETTINGS being the tight one, because its knurl is a ring of dark ticks
    /// that would otherwise read as symbol. 0.72 sits in that gap.
    private static let glyphRadius: CGFloat = 0.72

    /// And how dark. The symbol is *incised*: a dark cel line cut into a face
    /// that is otherwise near-white. Inside the disc the values are bimodal with
    /// a wide empty band between the modes -- the line runs 0.19-0.47, the
    /// moulded face sits at 0.96, and the only thing between them is the bottom
    /// bevel at 0.70-0.78. 0.60 separates the line from both.
    ///
    /// **Two numbers rather than a stencil per sprite**, and that is the
    /// argument for the whole approach: a fifth cap drawn in this style is
    /// masked correctly with nobody authoring anything, and a fifth cap drawn in
    /// some other style fails *visibly* rather than silently -- its symbol stays
    /// the body colour, which is exactly where all four were in 0.8.3.
    private static let glyphValue: CGFloat = 0.60

    // MARK: Re-inking

    /// Every opaque pixel keeps its value and takes one of the two targets' hue
    /// and saturation. See the type's note for why this and not a template or a
    /// multiply, and `glyphRadius` / `glyphValue` for how the two are told apart.
    ///
    /// **Also the disc clip (0.8.4, E2).** Every pixel outside the cap's
    /// inscribed circle has its alpha cleared before anything is re-inked. E2
    /// reports the recolour spilling past the button, and the sprite is how it
    /// gets out: the drawings are square, the cap is round, and the corners are
    /// not empty -- they carry the outer edge of the cel outline plus whatever
    /// survived `import-footer-art.py`'s key sweep. Un-inked those read as a
    /// dark fleck against a dark chassis and nobody saw them for two releases;
    /// re-inked they are fully saturated *skin-coloured* pixels standing outside
    /// the moulded part, on the shell and toward the neighbouring control.
    ///
    /// A clip here rather than a `.clipShape(Circle())` at the call site,
    /// deliberately. The view lays the sprite out with `.aspectRatio(.fit)`
    /// inside a square frame, so a circle in *view* space is the sprite's circle
    /// only when the sprite is exactly square -- three of the four are not
    /// (253x256, 254x256, 266x263) -- and a shape modifier would clip the press
    /// animation's scale along with it. In pixel space the two circles are the
    /// same by construction, this runs once per (stem, ink) pair rather than
    /// every frame, and it composes with nothing.
    ///
    /// Measured on the drop: 301-630 pixels cleared per cap.
    private func reink(_ image: UIImage, to hex: String, glyph glyphHex: String?) -> UIImage? {
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

        let cx = CGFloat(w - 1) / 2
        let cy = CGFloat(h - 1) / 2
        let radius = CGFloat(min(w, h)) / 2
        let glyphR = radius * Self.glyphRadius

        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let a = data[i + 3]
                guard a > 0 else { continue }

                let dx = CGFloat(x) - cx
                let dy = CGFloat(y) - cy
                let d = (dx * dx + dy * dy).squareRoot()
                // E2: nothing outside the moulded part reaches the chassis.
                if d > radius {
                    data[i] = 0
                    data[i + 1] = 0
                    data[i + 2] = 0
                    data[i + 3] = 0
                    continue
                }

                let (_, _, value) = hsv(r: data[i], g: data[i + 1], b: data[i + 2], a: a)
                // A near-black pixel has no colour to restate: the cel outline is
                // structure, and pushing a hue into it would draw the cap's own
                // edge in the skin's colour and lose the thing that separates the
                // part from the shell behind it. (Through 0.8.2 this also protected
                // the painted cast shadow; 0.8.3's B1 removed that at import, so
                // the outline is all this clause is guarding now.)
                guard value > 0.06 else { continue }

                let target = (d < glyphR && value < Self.glyphValue) ? ink : body
                let out = rgb(h: target.h, s: target.s, v: value)
                data[i] = UInt8(out.r * CGFloat(a) / 255)
                data[i + 1] = UInt8(out.g * CGFloat(a) / 255)
                data[i + 2] = UInt8(out.b * CGFloat(a) / 255)
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
