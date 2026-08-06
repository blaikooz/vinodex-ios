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
/// re-hueing to destroy. A sprite with two meaningful hues would need
/// `GrapeSpriteLoader`'s masking, and this deliberately does not have it.
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
    func image(stem: String, inkHex: String) -> UIImage? {
        let key = "\(stem)|\(inkHex)"
        if let hit = cache[key] { return hit }
        let result = PixelArtLoader.shared.image(Self.prefix + stem)
            .flatMap { reink($0, to: inkHex) }
        cache[key] = result
        return result
    }

    // MARK: Re-inking

    /// Every opaque pixel keeps its value and takes the target's hue and
    /// saturation. See the type's note for why this and not a template or a
    /// multiply.
    private func reink(_ image: UIImage, to hex: String) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }

        let target = hsv(of: hex)
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &data, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        for i in stride(from: 0, to: data.count, by: 4) {
            let a = data[i + 3]
            guard a > 0 else { continue }
            let (_, _, value) = hsv(r: data[i], g: data[i + 1], b: data[i + 2], a: a)
            // A near-black pixel has no colour to restate: the cel outline is
            // structure, and pushing a hue into it would draw the cap's own
            // edge in the skin's colour and lose the thing that separates the
            // part from the shell behind it. (Through 0.8.2 this also protected
            // the painted cast shadow; 0.8.3's B1 removed that at import, so
            // the outline is all this clause is guarding now.)
            guard value > 0.06 else { continue }
            let out = rgb(h: target.h, s: target.s, v: value)
            data[i] = UInt8(out.r * CGFloat(a) / 255)
            data[i + 1] = UInt8(out.g * CGFloat(a) / 255)
            data[i + 2] = UInt8(out.b * CGFloat(a) / 255)
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
