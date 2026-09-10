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
        #if DEBUG
        // `-vinodexScreenshot france:bordeaux` opens with a region already
        // chosen. The simulator cannot be sent a tap, so without this the
        // panel — half the screen — could only ever be photographed empty.
        _selected = State(initialValue: Self.screenshotStem())
        #endif
    }

    #if DEBUG
    private static func screenshotStem() -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-vinodexScreenshot"),
              args.index(after: flag) < args.endIndex else { return nil }
        let name = args[args.index(after: flag)]
        guard name.hasPrefix("france:") else { return nil }
        return String(name.dropFirst("france:".count))
    }
    #endif

    private var atlas: FranceAtlas? { FranceAtlas.shared }

    /// **One page, no scrolling** (maintainer order). The map takes the room
    /// left over and the panel beneath it is a fixed height, so choosing a
    /// region never reflows the page under the finger that chose it — which
    /// is the whole reason to probe a hit test here rather than on a list
    /// that scrolls away from you.
    public var body: some View {
        VStack(spacing: 10) {
            if let atlas {
                mapCard(atlas)
                    .frame(maxHeight: .infinity)
                panel(atlas)
                    .frame(height: Self.panelHeight)
            } else {
                DexSectionEmpty(symbol: "map.slash", message: "MAP NOT INSTALLED")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Tall enough for the four rows `southwest` needs — the deepest of the
    /// fourteen — so the panel is the same height whichever region is
    /// showing, and the map above it never moves.
    private static let panelHeight: CGFloat = 190
    /// The box every detail drawing is fitted into. The renderer normalises
    /// each to a 310px long axis, but their aspects run from Loire's 310x145
    /// to Corsica's 140x310; fitting them all into one square is what makes
    /// "equally sized" true on screen rather than only in the file.
    private static let detailBox: CGFloat = 150

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

                // **Unpinned** (maintainer order). The markers were the size
                // the renderer proves collision-free, and at phone width they
                // still swallowed the areas they marked — Beaujolais, the
                // smallest region, disappeared under its own dot. They were
                // never targets either, since the tap is a colour lookup on
                // the map beneath them, so removing them costs nothing and
                // gives the drawing back its fourteen colours. Which region
                // is chosen is said by the panel below, in words.
                ZStack(alignment: .topLeading) {
                    Image(uiImage: atlas.base)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)

                    // **The chosen region lifts off the map in place.** Its
                    // own detail drawing, laid over the patch of France it is
                    // a close-up of and grown 12%, so the selection is
                    // legible where the finger is rather than only in the
                    // panel below. The frame comes from the renderer's
                    // published projected bounds — see `Region.detailFrame`.
                    if let stem = selected,
                       let region = atlas.map.regions.first(where: { $0.id == stem }),
                       let art = atlas.detail(stem),
                       region.detailFrame.w > 0 {
                        let f = region.detailFrame
                        Image(uiImage: art)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: CGFloat(f.w) * fitted.width,
                                   height: CGFloat(f.h) * fitted.height)
                            .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
                            .scaleEffect(1.12)
                            .position(
                                x: ox + CGFloat(f.x + f.w / 2) * fitted.width,
                                y: oy + CGFloat(f.y + f.h / 2) * fitted.height
                            )
                            .allowsHitTesting(false)
                            .transition(.opacity)
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

    /// The fixed-height foot of the page: the chosen region's drawing at the
    /// one size they all share, its name, and the catalog entries behind it.
    @ViewBuilder
    private func panel(_ atlas: FranceAtlas) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(lcd.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                    )
                if let stem = selected, let art = atlas.detail(stem) {
                    Image(uiImage: art)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                        // "Expand slightly with tap": the drawing arrives a
                        // little under size and settles. Keyed on the stem so
                        // it replays when you move from one region to the
                        // next, rather than only on the first choice.
                        .transition(.scale(scale: 0.88).combined(with: .opacity))
                        .id(stem)
                }
            }
            .frame(width: Self.detailBox, height: Self.detailBox)

            if let stem = selected {
                regionList(atlas, stem: stem)
            } else {
                Text("Tap anywhere in France.\n\nEvery tap lands on a region — the nearest one, if you miss the small ones.")
                    .font(DexFont.mono(16))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func regionList(_ atlas: FranceAtlas, stem: String) -> some View {
        let entries = atlas.map.regionIDs(for: stem).compactMap { db.entry(id: $0) }
        VStack(alignment: .leading, spacing: 6) {
            Text(atlas.map.displayName(stem))
                .font(DexFont.retro(14))
                .tracking(1)
                .foregroundStyle(lcd.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if entries.isEmpty {
                // Stated rather than rendered as a dead tap: an area the
                // catalog does not cover is a finding about the catalog, and
                // the test is asked to report it. Today there are none.
                Text("NO CATALOG REGION HERE")
                    .font(DexFont.mono(15))
                    .foregroundStyle(lcd.subtext)
            } else {
                // Compact rows rather than `EntryTileView`: four of them have
                // to fit a fixed panel without scrolling, and a full tile is
                // three times the height. The tile's job — art, lock, tried —
                // belongs on the page these open.
                ForEach(entries) { entry in
                    Button {
                        Haptics.screenTap()
                        onSelectRegion(entry)
                    } label: {
                        HStack(spacing: 6) {
                            Text(entry.name.uppercased())
                                .font(DexFont.retro(11))
                                .foregroundStyle(lcd.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 4)
                            if bookmarks.contains(entry.id, on: .tried) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Dex.green)
                            }
                            Image(systemName: access.isLocked(entry, in: db)
                                  ? "lock.fill" : "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(lcd.subtext)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 5).fill(lcd.surface))
                    }
                    .buttonStyle(DexPressStyle(scale: 0.97))
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The unpinned base map, sized for the REGIONS section of France's country
/// page (0.9.55). Replaces the dotted outline there by maintainer order —
/// the outline art itself and every other country's page are untouched.
struct FranceMapThumb: View {
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }
    let onOpen: () -> Void

    var body: some View {
        if let atlas = FranceAtlas.shared {
            Button {
                Haptics.screenTap()
                onOpen()
            } label: {
                VStack(spacing: 4) {
                    Image(uiImage: atlas.base)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    Text("TAP TO EXPLORE THE REGIONS")
                        .font(DexFont.retro(10))
                        .tracking(1)
                        .foregroundStyle(lcd.accent)
                }
            }
            .buttonStyle(DexPressStyle(scale: 0.98))
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
