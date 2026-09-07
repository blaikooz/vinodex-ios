#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

/// Serves grape bunch sprites with the leaf recoloured per rarity
/// (0.6.2, A2). The leaf colour rule lives in `GrapeArt.leafHex`; the sprite
/// files ship exactly one leaf each — the yellow "rare" leaf — and this
/// loader repaints it, which is how a new tier gets a leaf without a new
/// sprite drop.
///
/// The leaf is found by SENTINEL hue since 0.9.50. Every prior scheme —
/// one positional mask (broken by new drawings), then per-sprite yellow-band
/// components (broken by golden berries: Riesling's bunch unioned into an
/// 81% "leaf" and NOBLE painted it purple) — failed because a yellow leaf
/// and golden fruit are genuinely inseparable by hue at runtime. So the
/// importer now decides once, offline, with hand-verified boxes for the
/// ambiguous sprites, and re-hues the leaf to a teal no berry uses
/// (import-grape-art.py, SENTINEL_HUE). This loader just repaints that
/// band. An unmarked sprite keeps its drawn leaf at every rarity.
@MainActor
final class GrapeSpriteLoader {
    static let shared = GrapeSpriteLoader()

    private var cache: [String: UIImage] = [:]
    /// Leaf pixels per sprite stem, in unit coordinates.
    private var masks: [String: [(x: CGFloat, y: CGFloat)]] = [:]

    private init() {}

    func image(stem: String, rarity: RarityLabel) -> UIImage? {
        let key = "\(stem)|\(rarity.rawValue)"
        if let hit = cache[key] { return hit }
        guard let base = PixelArtLoader.shared.image(stem) else { return nil }
        let recolored = recolor(base, stem: stem, to: GrapeArt.leafHex(rarity: rarity)) ?? base
        cache[key] = recolored
        return recolored
    }

    // MARK: Recolouring

    private func recolor(_ image: UIImage, stem: String, to hex: String) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0, let mask = leafMask(stem: stem, cg: cg) else { return nil }

        let target = rgb(of: hex)
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &data, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        // Paint only leaf-region pixels that are actually leaf-coloured
        // (yellow/green band) — the mask edge may graze a berry.
        for unit in mask {
            let px = Int(unit.x * CGFloat(w - 1))
            let py = Int(unit.y * CGFloat(h - 1))
            for dy in -1...1 {
                for dx in -1...1 {
                    let x = px + dx, y = py + dy
                    guard x >= 0, x < w, y >= 0, y < h else { continue }
                    let i = (y * w + x) * 4
                    let a = data[i + 3]
                    guard a > 0 else { continue }
                    let (hue, sat, val) = hsv(r: data[i], g: data[i + 1], b: data[i + 2], a: a)
                    guard sat > 0.2, val > 0.1, hue >= 0.40, hue <= 0.54 else { continue }
                    // Keep the pixel's shading (value), take the target's hue
                    // and saturation — the leaf stays drawn, only re-inked.
                    let out = rgbFrom(h: target.h, s: target.s, v: val)
                    data[i] = UInt8(out.r * CGFloat(a) / 255)
                    data[i + 1] = UInt8(out.g * CGFloat(a) / 255)
                    data[i + 2] = UInt8(out.b * CGFloat(a) / 255)
                }
            }
        }

        guard let outCG = ctx.makeImage() else { return nil }
        return UIImage(cgImage: outCG, scale: image.scale, orientation: .up)
    }

    /// This sprite's sentinel-leaf pixels, unit-normalised. Once per stem.
    private func leafMask(stem: String, cg: CGImage) -> [(x: CGFloat, y: CGFloat)]? {
        if let hit = masks[stem] { return hit }
        let w = cg.width, h = cg.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &data, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var mask: [(x: CGFloat, y: CGFloat)] = []
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let a = data[i + 3]
                guard a > 40 else { continue }
                let (hue, sat, _) = hsv(r: data[i], g: data[i + 1], b: data[i + 2], a: a)
                if hue >= 0.40, hue <= 0.54, sat > 0.2 {
                    mask.append((CGFloat(x) / CGFloat(w - 1), CGFloat(y) / CGFloat(h - 1)))
                }
            }
        }
        masks[stem] = mask
        return mask
    }

    // MARK: Colour maths

    private func hsv(r: UInt8, g: UInt8, b: UInt8, a: UInt8) -> (h: CGFloat, s: CGFloat, v: CGFloat) {
        // Un-premultiply before judging colour.
        let af = max(CGFloat(a) / 255, 0.001)
        let rf = min(CGFloat(r) / 255 / af, 1), gf = min(CGFloat(g) / 255 / af, 1), bf = min(CGFloat(b) / 255 / af, 1)
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

    private func rgb(of hex: String) -> (h: CGFloat, s: CGFloat, v: CGFloat) {
        var value: UInt64 = 0
        Scanner(string: String(hex.dropFirst())).scanHexInt64(&value)
        let r = UInt8((value >> 16) & 0xFF), g = UInt8((value >> 8) & 0xFF), b = UInt8(value & 0xFF)
        return hsv(r: r, g: g, b: b, a: 255)
    }

    private func rgbFrom(h: CGFloat, s: CGFloat, v: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
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
