#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

/// The country's drawn outline with one red dot per region (v0.5.8, D5).
///
/// Placement is geographic where the data says so (0.6.x): regions carry an
/// authored `mapPosition` — fractions of their outline PNG — which is snapped
/// to the nearest land pixel. The original seeded hash walk stays as the
/// fallback for regions without one, and for regions whose own icon is a
/// *different* outline than this map (US regions on the USA map render their
/// state outline elsewhere, so their authored point does not apply here).
/// Either way the one hard promise holds: a dot never lands in the sea.
public struct CountryOutlineMap: View {
    let country: String
    let regions: [WineEntry]
    var size: CGFloat = 132

    private let db = WineDatabase.shared

    public init(country: String, regions: [WineEntry], size: CGFloat = 132) {
        self.country = country
        self.regions = regions
        self.size = size
    }

    private var artStem: String? {
        guard let id = db.icons.countryShapeIcons[TextNormalize.label(country)],
              id.hasPrefix("art:")
        else { return nil }
        return String(id.dropFirst(4))
    }

    /// The outline stem this region's *own* icon resolves to — state first,
    /// like `EntryVisual.regionVisual`.
    private func stem(of r: RegionEntry) -> String? {
        let origin = r.details.origin.isEmpty ? r.common.name : r.details.origin
        let id = r.details.state.flatMap { db.icons.countryShapeIcons[TextNormalize.label($0)] }
            ?? db.icons.countryShapeIcons[TextNormalize.label(origin)]
        guard let id, id.hasPrefix("art:") else { return nil }
        return String(id.dropFirst(4))
    }

    public var body: some View {
        if let mapStem = artStem,
           let art = PixelArtLoader.shared.image(mapStem),
           !regions.isEmpty {
            let specs: [OutlineDotPlacer.Spec] = regions
                .compactMap { entry -> OutlineDotPlacer.Spec? in
                    guard case .region(let r) = entry else { return nil }
                    // The authored point only applies on the art it was
                    // authored against.
                    let hint = stem(of: r) == mapStem ? r.details.mapPosition : nil
                    return OutlineDotPlacer.Spec(name: r.common.name, hint: hint)
                }
                .sorted { $0.name < $1.name }
            let dots = OutlineDotPlacer.shared.dots(stem: mapStem, specs: specs)
            let scale = min(size / art.size.width, size / art.size.height)
            let fitted = CGSize(width: art.size.width * scale, height: art.size.height * scale)

            ZStack {
                Image(uiImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                ForEach(Array(dots.enumerated()), id: \.offset) { _, dot in
                    Circle()
                        .fill(Dex.red500)
                        .overlay(Circle().strokeBorder(.black.opacity(0.7), lineWidth: 1))
                        .frame(width: 7, height: 7)
                        .position(x: dot.x * scale, y: dot.y * scale)
                }
            }
            .frame(width: fitted.width, height: fitted.height)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Scans an outline PNG's alpha channel and hands out interior points —
/// authored positions snapped to land, or deterministic seeded ones for
/// regions without. Cached per (stem, specs) — the scan is cheap but the list
/// screens rebuild often.
@MainActor
final class OutlineDotPlacer {
    static let shared = OutlineDotPlacer()

    /// One region to place: its name (the hash seed) and, when the data has
    /// one, its authored fractional position on this outline.
    struct Spec {
        let name: String
        let hint: MapPosition?
    }

    private var cache: [String: [CGPoint]] = [:]

    private init() {}

    func dots(stem: String, specs: [Spec]) -> [CGPoint] {
        let key = stem + "|" + specs
            .map { "\($0.name)@\($0.hint.map { "\($0.x),\($0.y)" } ?? "-")" }
            .joined(separator: "|")
        if let hit = cache[key] { return hit }
        let placed = place(stem: stem, specs: specs)
        cache[key] = placed
        return placed
    }

    private func place(stem: String, specs: [Spec]) -> [CGPoint] {
        guard let image = PixelArtLoader.shared.image(stem),
              let candidates = interiorPoints(of: image),
              !candidates.isEmpty
        else { return [] }

        // Keep *derived* dots apart by a fraction of the art's smaller edge —
        // enough that a cluster still reads as separate pins. Authored dots
        // are exempt: their geography is the point, even when regions crowd.
        let minDist = min(image.size.width, image.size.height) * 0.16
        var placed: [CGPoint] = []

        // Authored positions first, snapped to the nearest interior point so
        // an approximate fraction can never land in the sea.
        for spec in specs {
            guard let hint = spec.hint else { continue }
            let target = CGPoint(
                x: CGFloat(hint.x) * image.size.width,
                y: CGFloat(hint.y) * image.size.height
            )
            let nearest = candidates.min {
                hypot($0.x - target.x, $0.y - target.y) < hypot($1.x - target.x, $1.y - target.y)
            }
            if let nearest { placed.append(nearest) }
        }

        // Then the seeded walk for the rest, avoiding everything already down.
        var derived: [CGPoint] = []
        for spec in specs where spec.hint == nil {
            // A stable hash, NOT Hasher: Swift seeds its per launch, and the
            // dots must not wander between runs.
            var index = Int(fnv1a(spec.name) % UInt64(candidates.count))
            var chosen = candidates[index]
            var attempts = 0
            while attempts < candidates.count {
                let point = candidates[index]
                let clear = (placed + derived).allSatisfy {
                    hypot($0.x - point.x, $0.y - point.y) >= minDist
                }
                if clear {
                    chosen = point
                    break
                }
                // A prime stride visits the whole list before repeating.
                index = (index + 37) % candidates.count
                attempts += 1
            }
            derived.append(chosen)
        }

        // Back into spec order: authored and derived were placed in two
        // passes, but callers index the result by their input order.
        var hinted = placed.makeIterator()
        var walked = derived.makeIterator()
        return specs.compactMap { $0.hint == nil ? walked.next() : hinted.next() }
    }

    /// Opaque pixels comfortably inside the silhouette, on a coarse grid.
    ///
    /// "Comfortably" is the neighbour test: a point only qualifies if the
    /// pixels a margin away in all four directions are opaque too, which
    /// keeps dots off the coastline and out of the outline stroke.
    private func interiorPoints(of image: UIImage) -> [CGPoint]? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }

        var alpha = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(
            data: &alpha, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        func opaque(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, x < w, y >= 0, y < h else { return false }
            return alpha[y * w + x] > 127
        }

        let margin = max(3, min(w, h) / 14)
        let stride = max(2, min(w, h) / 40)
        var points: [CGPoint] = []
        var y = margin
        while y < h - margin {
            var x = margin
            while x < w - margin {
                if opaque(x, y),
                   opaque(x - margin, y), opaque(x + margin, y),
                   opaque(x, y - margin), opaque(x, y + margin) {
                    // CGContext raster rows run top-down, matching SwiftUI's
                    // coordinate space — and the placement is approximate
                    // anyway, so parity hardly matters. Points are in the
                    // image's pixel space; the view scales them.
                    let sx = CGFloat(x) * image.size.width / CGFloat(w)
                    let sy = CGFloat(y) * image.size.height / CGFloat(h)
                    points.append(CGPoint(x: sx, y: sy))
                }
                x += stride
            }
            y += stride
        }
        return points
    }

    private func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
#endif
