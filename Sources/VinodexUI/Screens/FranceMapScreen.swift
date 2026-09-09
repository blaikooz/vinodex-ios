#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

/// **The France region map** (0.9.55) — a test of a richer country view.
///
/// Fourteen wine regions painted onto a projected France. Tap anywhere inside
/// the country and it resolves to a region; the map swaps to that region's
/// detail drawing with its catalog entries beneath, and tapping one opens it.
///
/// ## Why the tap is a colour lookup and not fourteen buttons
///
/// At phone width the base map is about 2.1pt per logical pixel, and **seven
/// of the fourteen regions have a bounding box under Apple's 44pt minimum —
/// Bordeaux among them, at 38pt**. Fourteen 44pt targets do not fit on a
/// phone-width France, and France is nearly square, so a taller phone buys
/// nothing. Buttons were never available here.
///
/// So the tap samples the pixel under the finger and matches it against the
/// manifest's fills. When it hits nothing — unassigned département, the
/// outline stroke, or the sea just off the coast — it searches outward for
/// the nearest painted pixel and takes that region instead.
///
/// **That outward search is the design, not a fallback.** It means there is
/// no dead space: every tap inside France answers, and a small region's
/// catchment is far larger than its footprint. A tap in the Charentes lands
/// on Bordeaux, which is the right answer for someone who does not know why
/// that part is grey.
public struct FranceMapScreen: View {
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

    private let db: WineDatabase
    @State private var access = AccessStore.shared
    @State private var bookmarks = BookmarkStore.shared
    /// The painted area under the last tap, or nil for the whole country.
    @State private var selected: String?
    let onSelectRegion: (WineEntry) -> Void

    public init(db: WineDatabase = .shared, onSelectRegion: @escaping (WineEntry) -> Void) {
        self.db = db
        self.onSelectRegion = onSelectRegion
    }

    private var atlas: FranceAtlas? { FranceAtlas.shared }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let atlas {
                    mapCard(atlas)
                    if let stem = selected {
                        detail(atlas, stem: stem)
                    } else {
                        Text("Tap anywhere in France. Every tap lands on a region — the nearest one, if you miss.")
                            .font(DexFont.mono(17))
                            .foregroundStyle(lcd.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    DexSectionEmpty(symbol: "map.slash", message: "MAP NOT INSTALLED")
                }
            }
            .padding(14)
        }
    }

    // MARK: The map

    private func mapCard(_ atlas: FranceAtlas) -> some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                // The fitted rect, not the view rect: `.aspectRatio(.fit)`
                // letterboxes, and a tap converted against the view's own
                // frame is wrong by however much letterbox there is. Same
                // arithmetic 0.8.4's C4 needed for the label well.
                let art = atlas.baseSize
                let scale = min(geo.size.width / art.width, geo.size.height / art.height)
                let fitted = CGSize(width: art.width * scale, height: art.height * scale)
                let ox = (geo.size.width - fitted.width) / 2
                let oy = (geo.size.height - fitted.height) / 2

                ZStack(alignment: .topLeading) {
                    Image(uiImage: atlas.base)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)

                    ForEach(atlas.map.regions) { region in
                        let lit = region.id == selected
                        Circle()
                            .fill(lit ? Dex.yellow : Dex.red500)
                            .overlay(Circle().strokeBorder(.black.opacity(0.75), lineWidth: 1))
                            // Eight logical pixels, which the renderer proves
                            // collision-free on every render — the tightest
                            // pair, Languedoc and Roussillon, sits 8.2 apart.
                            // They are markers, not targets: the tap is
                            // handled by the map underneath them.
                            .frame(width: 8 * scale * atlas.exportScale,
                                   height: 8 * scale * atlas.exportScale)
                            .position(
                                x: ox + CGFloat(region.button.x) * fitted.width,
                                y: oy + CGFloat(region.button.y) * fitted.height
                            )
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { point in
                    let inArt = CGPoint(x: (point.x - ox) / scale, y: (point.y - oy) / scale)
                    if let stem = atlas.region(atX: inArt) {
                        Haptics.select()
                        withAnimation(DexMotion.settle) { selected = stem }
                    }
                }
            }
            .aspectRatio(atlas.baseSize.width / atlas.baseSize.height, contentMode: .fit)
        }
    }

    // MARK: The chosen region

    @ViewBuilder
    private func detail(_ atlas: FranceAtlas, stem: String) -> some View {
        let ids = atlas.map.regionIDs(for: stem)
        let entries = ids.compactMap { db.entry(id: $0) }

        DexSection(atlas.map.displayName(stem), symbol: "mappin.and.ellipse") {
            VStack(alignment: .leading, spacing: 10) {
                if let art = atlas.detail(stem) {
                    Image(uiImage: art)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }

                if entries.isEmpty {
                    // Stated rather than rendered as a dead tap: an area the
                    // catalog does not cover is a finding about the catalog,
                    // and the test is asked to report it.
                    DexSectionEmpty(symbol: "mappin.slash", message: "NO CATALOG REGION HERE")
                } else {
                    ForEach(entries) { entry in
                        EntryTileView(
                            entry: entry,
                            palette: db.palette,
                            locked: access.isLocked(entry, in: db),
                            tried: bookmarks.contains(entry.id, on: .tried)
                        ) {
                            onSelectRegion(entry)
                        }
                    }
                }
            }
        }
    }
}

/// Loads the map once and answers "which region is this pixel".
///
/// A class with a shared instance rather than state on the view: the base map
/// is 810x780, and building its stem index costs a pass over 632,000 pixels.
/// That is cheap once and wasteful on every re-render, and the view re-renders
/// on every tap.
@MainActor
final class FranceAtlas {
    static let shared = FranceAtlas()

    let map: FranceMap
    let base: UIImage
    let baseSize: CGSize
    /// The 5x nearest-neighbour export multiplier, so an "8 logical pixel"
    /// marker can be drawn at the size the renderer proved collision-free.
    let exportScale: CGFloat = 5

    /// One byte per pixel: an index into `map.regions`, or one of the two
    /// sentinels below. A flat table rather than a dictionary of points — the
    /// outward search walks it, and 632KB is a fair price for a test.
    private let stems: [UInt8]
    /// Inside France, but no wine region here — unassigned département, or
    /// the coastline stroke. These search outward.
    private static let unassigned: UInt8 = 254
    /// Outside the coastline entirely: sea, or the keyed-away surround.
    ///
    /// **Separated from `unassigned` after probing the built map.** With one
    /// "no region" value and a generous radius, a tap in the open Atlantic
    /// resolved to the Loire 135 pixels away and the canvas's far corner to
    /// Corsica — the search happily crossed the sea to find something. The
    /// drop promises that every tap *inside France* resolves, and says
    /// nothing about the water; answering a tap on empty background with a
    /// region 135px distant is not generosity, it is a wrong answer
    /// delivered confidently. So the sea now refuses, and the search runs
    /// only from land.
    private static let outside: UInt8 = 255
    private let w: Int, h: Int
    private var details: [String: UIImage] = [:]

    private init?() {
        guard let manifestURL = Self.url("france-manifest", "json"),
              let indexURL = Self.url("france-region-index", "json"),
              let baseURL = Self.url("france-regions", "png"),
              let manifest = try? Data(contentsOf: manifestURL),
              let index = try? Data(contentsOf: indexURL),
              let map = try? FranceMap(manifest: manifest, index: index),
              let image = UIImage(contentsOfFile: baseURL.path),
              let cg = image.cgImage
        else { return nil }

        self.map = map
        self.base = image
        self.baseSize = image.size

        // Everything below works in locals and assigns at the end: the
        // pixel-reading closure would otherwise capture a half-initialised
        // `self` to reach `w` and `h`.
        let width = cg.width, height = cg.height
        var raw = [UInt8](repeating: 0, count: width * height * 4)
        var table = [UInt8](repeating: Self.outside, count: width * height)
        raw.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(
                data: buf.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var lookup: [FranceMap.RGB: UInt8] = [:]
        for (i, region) in map.regions.enumerated() { lookup[region.fill] = UInt8(i) }
        for p in 0..<(width * height) {
            let o = p * 4
            // Transparent stays `outside`: the magenta key was stripped at
            // install, so alpha is exactly the coastline.
            guard raw[o + 3] > 0 else { continue }
            let rgb = FranceMap.RGB(r: Int(raw[o]), g: Int(raw[o + 1]), b: Int(raw[o + 2]))
            table[p] = lookup[rgb] ?? Self.unassigned
        }
        self.w = width
        self.h = height
        self.stems = table
    }

    private static func url(_ name: String, _ ext: String) -> URL? {
        // `Bundle.module` directly rather than through `DexAsset`: adding a
        // case there would enlist `DexAssetAudit` to police this directory,
        // and the drop's §6 is explicit that no gate should gain a new tree
        // to walk for a test. `Maps` is already declared and already owned by
        // another loader, so nothing here is unaccounted for.
        Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Maps/france")
    }

    func detail(_ stem: String) -> UIImage? {
        if let hit = details[stem] { return hit }
        guard let url = Self.url("map-" + stem, "png"),
              let art = UIImage(contentsOfFile: url.path) else { return nil }
        details[stem] = art
        return art
    }

    /// The region at a point in base-image space, or the nearest one.
    ///
    /// Returns nil only for a tap so far outside France that nothing is found
    /// inside the search radius — the corners of the canvas, which are sea.
    func region(atX point: CGPoint) -> String? {
        let px = Int(point.x.rounded()), py = Int(point.y.rounded())
        guard let idx = nearestIndex(x: px, y: py) else { return nil }
        return map.regions[Int(idx)].id
    }

    private func nearestIndex(x: Int, y: Int) -> UInt8? {
        // A tap in the sea answers nothing at all — see `outside`. This is
        // the guard that keeps the outward search a *catchment* rather than
        // a magnet reaching across open water.
        guard x >= 0, y >= 0, x < w, y < h, stems[y * w + x] != Self.outside else { return nil }
        if let hit = at(x, y) { return hit }
        // Expanding square rings from a point known to be on land. The cap is
        // a quarter of the canvas, which comfortably clears the widest
        // unassigned stretch (the Charentes need 20px, Brittany more).
        let maxR = min(w, h) / 4
        var r = 1
        while r <= maxR {
            for dx in -r...r {
                if let hit = at(x + dx, y - r) { return hit }
                if let hit = at(x + dx, y + r) { return hit }
            }
            for dy in (-r + 1)...(r - 1) where r > 1 {
                if let hit = at(x - r, y + dy) { return hit }
                if let hit = at(x + r, y + dy) { return hit }
            }
            r += 1
        }
        return nil
    }

    private func at(_ x: Int, _ y: Int) -> UInt8? {
        guard x >= 0, y >= 0, x < w, y < h else { return nil }
        let v = stems[y * w + x]
        return v >= Self.unassigned ? nil : v
    }
}
#endif
