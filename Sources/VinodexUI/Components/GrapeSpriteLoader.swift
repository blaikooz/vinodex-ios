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
/// The leaf is found per sprite, not by hue alone: gold berries and amber
/// flecks share the leaf's yellow band, so a hue test by itself would repaint
/// fruit. Until 0.9.47 the mask was computed once, positionally, from a single
/// reference sprite — sound while every bunch was the same drawing, and the
/// silent breaker of every new drawing (the icon campaign's day-one gate).
/// Now each sprite grows its own mask from its own yellow pixels, resolved by
/// connected components: the cel outline separates every berry into its own
/// small blob, so the leaf is reliably the *largest, top-weighted* yellow
/// component even on gold-berried sprites, and split lobes are unioned back
/// in by bounding-box overlap.
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
                    guard sat > 0.3, val > 0.1, hue >= 0.05, hue <= 0.45 else { continue }
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

    /// This sprite's leaf pixels, unit-normalised. Computed once per stem.
    ///
    /// Yellow-band pixels are grouped into 4-connected components; the leaf
    /// is the component with the best area-times-height score (a component
    /// whose centroid sits in the lower 55% is discounted 4x, which is what
    /// keeps a big gold berry from beating a modest leaf), plus any other
    /// band component overlapping the winner's slightly inflated box — a
    /// leaf split into lobes by a drawn vein or the stem crossing it.
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

        // The band, as pixel indices.
        var band = [Bool](repeating: false, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let a = data[i + 3]
                guard a > 40 else { continue }
                let (hue, sat, val) = hsv(r: data[i], g: data[i + 1], b: data[i + 2], a: a)
                if hue >= 0.08, hue <= 0.17, sat > 0.45, val > 0.35 {
                    band[y * w + x] = true
                }
            }
        }

        // Components.
        struct Comp { var px: [Int] = []; var minX = Int.max; var maxX = -1; var minY = Int.max; var maxY = -1; var sumY = 0 }
        var visited = [Bool](repeating: false, count: w * h)
        var comps: [Comp] = []
        for start in 0..<(w * h) where band[start] && !visited[start] {
            var comp = Comp()
            var stack = [start]
            visited[start] = true
            while let p = stack.popLast() {
                comp.px.append(p)
                let x = p % w, y = p / w
                comp.minX = min(comp.minX, x); comp.maxX = max(comp.maxX, x)
                comp.minY = min(comp.minY, y); comp.maxY = max(comp.maxY, y)
                comp.sumY += y
                for n in [p - 1, p + 1, p - w, p + w] {
                    guard n >= 0, n < w * h, band[n], !visited[n] else { continue }
                    // Row wrap guard for the horizontal neighbours.
                    if abs((n % w) - x) > 1 { continue }
                    visited[n] = true
                    stack.append(n)
                }
            }
            comps.append(comp)
        }
        guard !comps.isEmpty else { masks[stem] = []; return [] }

        func score(_ c: Comp) -> Double {
            let centroidY = Double(c.sumY) / Double(max(c.px.count, 1)) / Double(max(h - 1, 1))
            return Double(c.px.count) * (centroidY < 0.45 ? 1.0 : 0.25)
        }
        let winner = comps.max(by: { score($0) < score($1) })!
        let inflate = max(3, w / 40)
        let keep = comps.filter { c in
            c.minX <= winner.maxX + inflate && c.maxX >= winner.minX - inflate &&
            c.minY <= winner.maxY + inflate && c.maxY >= winner.minY - inflate
        }

        var mask: [(x: CGFloat, y: CGFloat)] = []
        for c in keep {
            for p in c.px {
                mask.append((CGFloat(p % w) / CGFloat(w - 1), CGFloat(p / w) / CGFloat(h - 1)))
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
