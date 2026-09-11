#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

/// **A country's painted region map** (0.9.55) — a test of a richer country
/// view. France and Italy have one; the roster is `RegionMap.mapped`.
///
/// The country's wine regions painted onto its projected outline, over a
/// backdrop of sea, continental shelf and neighbouring countries. Tap inside
/// the country and it resolves to a region; the chosen area lifts off the map
/// in place and its catalog entries arrive as full tiles beneath.
///
/// ## Why the tap is a colour lookup and not fourteen buttons
///
/// At phone width the base map is about 2.1pt per logical pixel, and **seven
/// of France's fourteen regions have a bounding box under Apple's 44pt
/// minimum — Bordeaux among them, at 38pt**. Fourteen 44pt targets do not fit
/// on a phone-width France, and France is nearly square, so a taller phone
/// buys nothing. Italy is worse: it is long and thin, so fitting its length
/// on screen leaves its regions narrower still. Buttons were never available.
///
/// So the tap samples the pixel under the finger on the *interactive* layer
/// and matches it against the manifest's fills. Three outcomes:
///
/// - A fill matches. That is the region.
/// - The pixel is transparent — the chroma key, which the interactive layer
///   carries everywhere outside the country. The tap was in the sea or in a
///   neighbour: **nothing happens.**
/// - The pixel is stone or coastline ink: inside the country, but on an
///   admin-1 unit no wine region claims. Search outward for the nearest
///   painted pixel.
///
/// **That outward search is the design, not a fallback.** There is no dead
/// space *inside* the country, and a small region's catchment is far larger
/// than its footprint: a tap in the Charentes lands on Bordeaux, which is the
/// right answer for someone who does not know why that part is grey. What the
/// backdrop buys beyond atmosphere is the middle case — before it, everything
/// outside France was the same key as the unassigned interior, so a tap in
/// the Atlantic had to resolve to *something*, and answered with a region 135
/// pixels away.
public struct RegionMapScreen: View {
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

    private let db: WineDatabase
    /// The catalog's spelling — "France", "Italy".
    let country: String
    @State private var access = AccessStore.shared
    @State private var bookmarks = BookmarkStore.shared
    /// The painted area under the last tap, or nil for the whole country.
    @State private var selected: String?
    /// Where the last tap landed, in real degrees, for the HUD readout.
    @State private var coordinate: (lon: Double, lat: Double)?
    /// The HUD's magnification bank — 1x, 2x, 4x, as the globe prototype
    /// wears it. The map is drawn at `scale * zoom` and stays centred on the
    /// chosen region, so zooming is what makes the small areas aimable rather
    /// than merely visible.
    @State private var zoom: CGFloat = 1
    let onSelectRegion: (WineEntry) -> Void

    public init(
        db: WineDatabase = .shared,
        country: String,
        onSelectRegion: @escaping (WineEntry) -> Void
    ) {
        self.db = db
        self.country = country
        self.onSelectRegion = onSelectRegion
        #if DEBUG
        // `-vinodexScreenshot map:france:bordeaux` opens with a region already
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
        // `map:italy:tuscany` — country and stem, so either map can be
        // photographed with a region already chosen.
        let parts = name.split(separator: ":")
        guard parts.count == 3, parts[0] == "map" else { return nil }
        return String(parts[2])
    }
    #endif

    private var atlas: RegionAtlas? { RegionAtlas.of(country) }

    /// **Built like every other page** (0.9.55, maintainer pass): one
    /// `ScrollView` with the app's content margins over `lcd.page`, and both
    /// halves in `DexSection` blocks, so this reads as a Vinodex screen
    /// rather than as a map someone bolted on.
    ///
    /// No hero, by ruling. Every other page opens with a flag and a name
    /// because it has to say what it is about; this one draws the country at
    /// a size no hero could improve on, and the marquee already carries the
    /// name.
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let atlas {
                    mapSection(atlas)
                    if let stem = selected {
                        regionSection(atlas, stem: stem)
                    }
                } else {
                    DexSection("REGION MAP", symbol: "map.fill") {
                        DexSectionEmpty(symbol: "map.slash", message: "MAP NOT INSTALLED")
                    }
                }
            }
        }
        .contentMargins(.horizontal, 14, for: .scrollContent)
        .contentMargins(.bottom, 72, for: .scrollContent)
        .background(lcd.page)
        .animation(DexMotion.settle, value: selected)
    }

    /// **The map as an instrument panel**, after the Globe Scan prototype:
    /// a square LCD with the readout laid over the picture rather than
    /// printed under it, scanlines on the glass, and a magnification bank.
    private func mapSection(_ atlas: RegionAtlas) -> some View {
        DexSection("REGION MAP", symbol: "map.fill") {
            VStack(spacing: 8) {
                ZStack {
                    mapCard(atlas)
                    mapScanlines
                    hud(atlas)
                }
                .frame(height: Self.mapHeight)
                .background(lcd.screen)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                )

                zoomBank
            }
        }
    }

    /// Glass, not a filter. `ScanlineOverlay` is the chassis's own and lays
    /// 50% black over everything — right for the LCD, far too heavy here,
    /// and doubling up with the scanlines the LCD already has underneath. A
    /// hairline at 7% every four points is what the prototype uses and is
    /// enough to read as glass without taking the map's colours down with it.
    private var mapScanlines: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(.black.opacity(0.07))
                )
                y += 4
            }
        }
        .allowsHitTesting(false)
    }

    /// Top row names the tier and the coordinate under the last tap; bottom
    /// row carries the instruction and the magnification. Both sit on a scrim
    /// so they stay legible over sea or over Sicily.
    private func hud(_ atlas: RegionAtlas) -> some View {
        VStack(spacing: 0) {
            hudRow(
                leading: selected.map(atlas.map.displayName) ?? country.uppercased(),
                trailing: coordinateText,
                top: true
            )
            Spacer(minLength: 0)
            hudRow(
                leading: selected == nil ? "TAP A REGION" : "TAP AGAIN TO CHANGE",
                trailing: zoom == 1 ? "1X" : (zoom == 2 ? "2X" : "4X"),
                top: false
            )
        }
        .allowsHitTesting(false)
    }

    private func hudRow(leading: String, trailing: String, top: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(leading)
                .font(DexFont.retro(11))
                .tracking(1)
                .foregroundStyle(top ? lcd.accent : lcd.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Text(trailing)
                .font(DexFont.mono(14))
                .foregroundStyle(top ? lcd.subtext : lcd.accent)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            LinearGradient(
                colors: top
                    ? [lcd.page.opacity(0.85), .clear]
                    : [.clear, lcd.page.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    /// Degrees under the last tap, in the readout the prototype uses.
    /// Hemispheres rather than signs: a wine map is read by people, and
    /// "44.8N 0.6W" is Bordeaux where "-0.6" is arithmetic.
    private var coordinateText: String {
        guard let c = coordinate else { return "--" }
        let ns = c.lat >= 0 ? "N" : "S"
        let ew = c.lon >= 0 ? "E" : "W"
        return String(format: "%.1f°%@ %.1f°%@", abs(c.lat), ns, abs(c.lon), ew)
    }

    private var zoomBank: some View {
        HStack(spacing: 6) {
            ForEach([CGFloat(1), 2, 4], id: \.self) { step in
                Button {
                    Haptics.select()
                    withAnimation(DexMotion.settle) { zoom = step }
                } label: {
                    Text(step == 1 ? "1X" : (step == 2 ? "2X" : "4X"))
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .foregroundStyle(zoom == step ? lcd.onAccent : lcd.subtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(zoom == step ? lcd.accent : lcd.surface)
                        )
                }
                .buttonStyle(DexPressStyle(scale: 0.97))
                .accessibilityLabel("Zoom \(Int(step)) times")
            }
        }
    }

    /// The map's height, chosen and unchanging. Big enough that Italy's
    /// narrow regions and France's small ones are still worth aiming at, and
    /// the same before and after a choice so nothing moves under the finger.
    private static let mapHeight: CGFloat = 340
    /// The box every detail drawing is fitted into. The renderer normalises
    /// each to a 310px long axis, but their aspects run from Loire's 310x145
    /// to Corsica's 140x310; fitting them all into one square is what makes
    /// "equally sized" true on screen rather than only in the file.
    private static let detailBox: CGFloat = 72

    // MARK: The map

    private func mapCard(_ atlas: RegionAtlas) -> some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                // **Sized by the country, not by the canvas.** The canvas is
                // mostly world — the country is about a third of it — so
                // aspect-fitting the whole thing would shrink it to a third
                // of the screen and take every tap target with it. Instead
                // the pair is scaled until the country's own rect fills the
                // width, and the sea and neighbours bleed off the edges
                // under the clip below. See `RegionMap.subjectRect`.
                let art = atlas.baseSize
                let fr = atlas.map.subjectRect
                let inset: CGFloat = 8
                // The country fills the width when there is height to spare,
                // and fits the height when there is not. One `min` covers
                // both because it is the country's rect being fitted, never
                // the canvas — and the two need opposite answers: France is
                // nearly square so the width binds, Italy is long and thin so
                // the height does.
                // on the full page the width binds and the world fills the
                // rest of the height, and in the shrunken band the height
                // binds so the *whole* country stays on screen. That second
                // case matters — choosing another region without going back
                // is the point of the band, and a France cropped top and
                // bottom hides Champagne and Languedoc from the next tap.
                let fit = min(
                    (geo.size.width - inset * 2) / (CGFloat(fr.w) * art.width),
                    (geo.size.height - inset * 2) / (CGFloat(fr.h) * art.height)
                )
                // Magnified about whatever is chosen, so 4x on Valle d'Aosta
                // puts Valle d'Aosta under the finger rather than somewhere
                // off the glass.
                //
                // **Only when magnified.** At 1x the whole country fits, so
                // centring on a region instead would shove the country to one
                // side of the glass to no purpose — which is exactly what it
                // did on the first cut, with France pressed against the right
                // edge and the Atlantic taking the rest.
                let scale = fit * zoom
                let middle = (x: fr.x + fr.w / 2, y: fr.y + fr.h / 2)
                let focus = zoom > 1
                    ? (selected
                        .flatMap { stem in atlas.map.regions.first { $0.id == stem } }
                        .map { (x: $0.button.x, y: $0.button.y) } ?? middle)
                    : middle
                let fitted = CGSize(width: art.width * scale, height: art.height * scale)
                // Centred on the focus — the country at rest, the chosen
                // region once there is one.
                let ox = geo.size.width / 2 - (CGFloat(focus.x) * fitted.width)
                let oy = geo.size.height / 2 - (CGFloat(focus.y) * fitted.height)

                // **Unpinned** (maintainer order). The markers were the size
                // the renderer proves collision-free, and at phone width they
                // still swallowed the areas they marked — Beaujolais, the
                // smallest region, disappeared under its own dot. They were
                // never targets either, since the tap is a colour lookup on
                // the map beneath them, so removing them costs nothing and
                // gives the drawing back its fourteen colours. Which region
                // is chosen is said by the tiles below, in words.
                ZStack(alignment: .topLeading) {
                    // Backdrop first, interactive layer directly on top, same
                    // rect — they are pixel-aligned by construction.
                    if let world = atlas.backdrop {
                        Image(uiImage: world)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: fitted.width, height: fitted.height)
                            .offset(x: ox, y: oy)
                    }
                    Image(uiImage: atlas.base)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: fitted.width, height: fitted.height)
                        .offset(x: ox, y: oy)

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
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                // What lets the world bleed: the layers are far wider than
                // the viewport by design, and this is the window onto them.
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { point in
                    let inArt = CGPoint(x: (point.x - ox) / scale, y: (point.y - oy) / scale)
                    // Nil means the tap was outside France — sea or a
                    // neighbour. Do nothing rather than reaching for whatever
                    // region is least far, which is what the backdrop buys
                    // beyond atmosphere.
                    // The readout answers every tap, including the ones that
                    // resolve to no region: "where did I just touch" is a
                    // fair question over open sea too.
                    coordinate = atlas.coordinate(atArt: inArt)
                    if let stem = atlas.region(atX: inArt) {
                        Haptics.select()
                        withAnimation(DexMotion.settle) { selected = stem }
                    }
                }
            }
            // No aspect ratio: the canvas's shape is not the window's. It
            // held the map to a square while the layers were being scaled by
            // France instead — the world is meant to fill whatever height the
            // page can spare and bleed off the rest.
        }
    }

    // MARK: The chosen region

    /// The chosen region, as a section of the page: its close-up, the blurb
    /// of the catalog region behind it, and every entry inside it as a full
    /// tile — the same `EntryTileView` every list in the app uses, so a
    /// region reached from the map looks like a region reached any other way.
    @ViewBuilder
    private func regionSection(_ atlas: RegionAtlas, stem: String) -> some View {
        let entries = atlas.map.regionIDs(for: stem).compactMap { db.entry(id: $0) }
        DexSection(atlas.map.displayName(stem), symbol: "mappin.and.ellipse") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(lcd.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                            )
                        if let art = atlas.detail(stem) {
                            Image(uiImage: art)
                                .interpolation(.none)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(6)
                                // "Expand slightly with tap": the drawing
                                // arrives a little under size and settles.
                                // Keyed on the stem so it replays when you
                                // move from one region to the next, not only
                                // on the first choice.
                                .transition(.scale(scale: 0.88).combined(with: .opacity))
                                .id(stem)
                        }
                    }
                    .frame(width: Self.detailBox, height: Self.detailBox)

                    // **The blurb, where there is exactly one.** An area
                    // holding several catalog regions has no single
                    // description to show — South West holds four, and
                    // picking one of their blurbs to stand for the area would
                    // be inventing an editorial claim the catalog never made.
                    // Those areas lead with their tiles instead, which is the
                    // honest answer and also the useful one.
                    if let solo = entries.first, entries.count == 1 {
                        Text(solo.entryDescription)
                            .font(DexFont.mono(17))
                            .foregroundStyle(lcd.bodyText)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(entries.isEmpty
                             ? "No catalog region covers this part of \(country) yet."
                             : "\(entries.count) regions of the catalog sit inside this one.")
                            .font(DexFont.mono(17))
                            .foregroundStyle(lcd.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let solo = entries.first, entries.count == 1 {
                    ReadAloudButton(text: solo.entryDescription)
                }

                if entries.isEmpty {
                    // Stated rather than rendered as a dead tap: an area the
                    // catalog does not cover is a finding about the catalog,
                    // and the test is asked to report it. Italy has three —
                    // Liguria, Molise and Valle d'Aosta.
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

/// The unpinned base map, sized for the REGIONS section of France's country
/// page (0.9.55). Replaces the dotted outline there by maintainer order —
/// the outline art itself and every other country's page are untouched.
struct RegionMapThumb: View {
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }
    let country: String
    let onOpen: () -> Void

    /// A little more than the 132pt outline this replaces — the painted map
    /// carries fourteen or twenty-one colours where the outline carried a
    /// silhouette and some dots, so it earns the extra height — but nowhere
    /// near enough to take over the page it sits on.
    static let thumbHeight: CGFloat = 168

    var body: some View {
        if let atlas = RegionAtlas.of(country) {
            Button {
                Haptics.screenTap()
                onOpen()
            } label: {
                VStack(spacing: 4) {
                    // **Cropped to the country, not the canvas.** The canvas
                    // is mostly world now and the country is about a third of
                    // it, so drawing the whole thing shrank France to a stamp
                    // in a field of nothing — the interactive layer is keyed,
                    // so that field is transparent and reads as wasted space.
                    // Here the layer is scaled until the subject rect fills
                    // the width and offset so it is what you see, which puts
                    // the country back at roughly the size the dotted outline
                    // it replaced used to be.
                    GeometryReader { geo in
                        let art = atlas.baseSize
                        let r = atlas.map.subjectRect
                        // Fitted, not filled. Letting the country fill the
                        // width made this section 318pt tall for France and
                        // 436pt for Italy — against the 132pt dotted outline
                        // it replaced, which is a thumbnail becoming the page.
                        // Fitting inside a capped height instead puts both
                        // countries at a comparable size whatever their shape,
                        // which is also what stops long thin Italy dwarfing
                        // squat France on the two pages.
                        let scale = min(
                            geo.size.width / (CGFloat(r.w) * art.width),
                            geo.size.height / (CGFloat(r.h) * art.height)
                        )
                        let w = art.width * scale
                        let h = art.height * scale
                        Image(uiImage: atlas.base)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: w, height: h)
                            .offset(
                                x: geo.size.width / 2 - CGFloat(r.x + r.w / 2) * w,
                                y: geo.size.height / 2 - CGFloat(r.y + r.h / 2) * h
                            )
                    }
                    .frame(height: Self.thumbHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()
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
final class RegionAtlas {
    /// One atlas per country, built once. The pixel table costs a pass over
    /// six million pixels for Italy, which is cheap once and wasteful on
    /// every re-render — and the view re-renders on every tap.
    private static var cache: [String: RegionAtlas] = [:]

    static func of(_ country: String) -> RegionAtlas? {
        guard let key = RegionMap.key(forCountry: country) else { return nil }
        if let hit = cache[key] { return hit }
        guard let built = RegionAtlas(key) else { return nil }
        cache[key] = built
        return built
    }

    /// The resource-directory name — `france`, `italy`.
    let key: String

    let map: RegionMap
    /// The interactive layer: France only, everything else keyed away. This
    /// is the one that gets sampled.
    let base: UIImage
    /// Sea, continental shelf and 107 neighbouring countries — opaque, drawn
    /// underneath, and never sampled. Pixel-aligned with `base` by
    /// construction: same projection, same origin, same scale, so the two are
    /// drawn into one rect with no offset arithmetic here.
    let backdrop: UIImage?
    let baseSize: CGSize
    /// The 5x nearest-neighbour export multiplier, so an "8 logical pixel"
    /// marker can be drawn at the size the renderer proved collision-free.
    let exportScale: CGFloat = 5

    /// The index raster: one byte per **logical canvas cell**, straight from
    /// `<country>-index.png`.
    ///
    /// **This replaced matching pixel colours, and the change is not
    /// cosmetic.** Colour matching works in a browser and is fragile on iOS
    /// in three separate ways, none of which announces itself: the PNGs carry
    /// no ICC profile, so anything that renders them through a P3 context
    /// shifts every channel and breaks matching everywhere at once; Xcode may
    /// repack a PNG; and any smoothing turns border pixels into blends that
    /// match nothing. The index is an integer no colour pipeline can perturb.
    ///
    /// It is also 25x smaller. The colour table needed a byte per *exported*
    /// pixel at 5x — 38.7 MB for seven countries resident, with a 25 MB
    /// transient RGBA bitmap per decode. The index is a byte per *logical*
    /// cell: 1.55 MB for all seven, 13 KB on disk.
    ///
    /// `0` is outside the country — sea, a neighbour, or the coastline ink,
    /// which is drawn one cell outside the border on purpose. `255` is inside
    /// but unassigned. Anything else is `Region.index`.
    private let cells: [UInt8]
    /// Outside the country. A tap here answers nothing at all, rather than
    /// reaching across open water for whichever region is least far.
    private static let outside: UInt8 = 0
    /// Inside the country, but on an admin-1 unit no wine region claims.
    /// These search outward.
    private static let unassigned: UInt8 = 255
    /// Index byte to position in `map.regions`.
    private let slot: [UInt8: Int]
    /// The index is at LOGICAL scale; the art is at `export_scale`. Taps
    /// arrive in art space, so they are divided down before lookup — reading
    /// the index at art coordinates was the obvious bug to write here.
    private let w: Int, h: Int
    private let exportScaleI: Int
    private var details: [String: UIImage] = [:]

    private init?(_ key: String) {
        self.key = key
        guard let manifestURL = Self.url(key, "\(key)-manifest", "json"),
              let indexURL = Self.url(key, "\(key)-region-index", "json"),
              let baseURL = Self.url(key, "\(key)-regions", "png"),
              let cellsURL = Self.url(key, "\(key)-index", "png"),
              let manifest = try? Data(contentsOf: manifestURL),
              let index = try? Data(contentsOf: indexURL),
              let map = try? RegionMap(manifest: manifest, index: index),
              let image = UIImage(contentsOfFile: baseURL.path),
              let raster = UIImage(contentsOfFile: cellsURL.path),
              let cg = raster.cgImage
        else { return nil }

        self.map = map
        self.base = image
        self.baseSize = image.size
        self.backdrop = Self.url(key, "\(key)-backdrop", "png")
            .flatMap { UIImage(contentsOfFile: $0.path) }

        // Locals until the end: the drawing closure would otherwise capture a
        // half-initialised `self`.
        let width = cg.width, height = cg.height
        var bytes = [UInt8](repeating: Self.outside, count: width * height)
        bytes.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(
                data: buf.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            // Grayscale, no alpha, no interpolation: the bytes must survive
            // the draw exactly, because they are data rather than a picture.
            ctx.interpolationQuality = .none
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        self.cells = bytes
        self.w = width
        self.h = height
        self.exportScaleI = max(1, Int((image.size.width / CGFloat(width)).rounded()))
        var slots: [UInt8: Int] = [:]
        for (i, region) in map.regions.enumerated() {
            slots[UInt8(clamping: region.index)] = i
        }
        self.slot = slots
    }

    /// **One region on its own, in its own colour** — the shape that lifts off
    /// the globe when it is tapped.
    ///
    /// Painted from the index raster at canvas resolution and filled flat,
    /// because that is what the region *is*: the art carries one colour per
    /// area, so re-deriving it from the manifest's own fill costs a quarter of
    /// a megapixel instead of masking the 5x export's six million.
    func cutout(_ stem: String) -> UIImage? {
        if let hit = cutouts[stem] { return hit }
        guard let region = map.regions.first(where: { $0.id == stem }) else { return nil }
        let want = UInt8(clamping: region.index)
        // Lifted toward white so the raised copy reads as the *selected* one
        // rather than as the same colour hovering for no reason.
        let lift: (Int) -> UInt8 = { UInt8(clamping: Int((Double($0) * 0.78 + 56).rounded())) }
        let rgbaFill = (lift(region.fill.r), lift(region.fill.g), lift(region.fill.b))
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<(w * h) where cells[i] == want {
            rgba[i * 4 + 0] = rgbaFill.0
            rgba[i * 4 + 1] = rgbaFill.1
            rgba[i * 4 + 2] = rgbaFill.2
            rgba[i * 4 + 3] = 255
        }
        let image = Self.image(from: &rgba, w: w, h: h)
        if let image {
            // **Bounded.** Each cutout is a real w*h*4 bitmap — about a
            // megabyte — and the atlas that holds them lives in a static cache
            // that never evicts, so tapping through all seven countries' 85
            // regions would pin some 77MB for the life of the process. Only the
            // current selection and the one before it are ever wanted, and a
            // cutout costs a quarter-megapixel pass to rebuild.
            if cutoutOrder.count >= 3, let oldest = cutoutOrder.first {
                cutouts.removeValue(forKey: oldest)
                cutoutOrder.removeFirst()
            }
            cutouts[stem] = image
            cutoutOrder.append(stem)
        }
        return image
    }

    private var cutouts: [String: UIImage] = [:]
    private var cutoutOrder: [String] = []

    private static func image(from rgba: inout [UInt8], w: Int, h: Int) -> UIImage? {
        var out: UIImage?
        rgba.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(
                data: buf.baseAddress, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let cg = ctx.makeImage() else { return }
            out = UIImage(cgImage: cg)
        }
        return out
    }


    private static func url(_ key: String, _ name: String, _ ext: String) -> URL? {
        // `Bundle.module` directly rather than through `DexAsset`: adding a
        // case there would enlist `DexAssetAudit` to police this directory,
        // and the drop's §6 is explicit that no gate should gain a new tree
        // to walk for a test. `Maps` is already declared and already owned by
        // another loader, so nothing here is unaccounted for.
        Bundle.module.url(forResource: name, withExtension: ext,
                          subdirectory: "Maps/" + key)
    }

    func detail(_ stem: String) -> UIImage? {
        if let hit = details[stem] { return hit }
        guard let url = Self.url(key, "map-" + stem, "png"),
              let art = UIImage(contentsOfFile: url.path) else { return nil }
        details[stem] = art
        return art
    }

    /// The real coordinate under a point in base-art space, for the HUD.
    /// Art space is `export_scale` times the canvas the projection speaks in.
    func coordinate(atArt point: CGPoint) -> (lon: Double, lat: Double) {
        map.coordinate(atCanvas: Double(point.x) / Double(exportScaleI),
                       Double(point.y) / Double(exportScaleI))
    }

    /// The region at a point in **base-art space**, or the nearest one
    /// inside the same country. Nil when the tap was outside the country.
    func region(atX point: CGPoint) -> String? {
        // Art space to index space. The index is one cell per *logical*
        // canvas unit while the art is exported at 5x, so a tap has to be
        // divided down before it is looked up.
        let cx = Int(point.x.rounded()) / exportScaleI
        let cy = Int(point.y.rounded()) / exportScaleI
        guard let byte = nearestCell(x: cx, y: cy), let i = slot[byte] else { return nil }
        return map.regions[i].id
    }

    private func nearestCell(x: Int, y: Int) -> UInt8? {
        // A tap outside the country answers nothing at all. This is the guard
        // that keeps the outward search a *catchment* rather than a magnet
        // reaching across open water — without it a tap in the Atlantic
        // answered "Loire" from 135 cells away.
        guard x >= 0, y >= 0, x < w, y < h, cells[y * w + x] != Self.outside else { return nil }
        if let hit = at(x, y) { return hit }
        // Expanding rings from a cell known to be inside the country. The cap
        // clears the widest unassigned stretch comfortably — the Charentes
        // need 4 cells, Spain's interior more.
        let maxR = min(w, h) / 4
        var r = 1
        while r <= maxR {
            for dx in -r...r {
                if let hit = at(x + dx, y - r) { return hit }
                if let hit = at(x + dx, y + r) { return hit }
            }
            if r > 1 {
                for dy in (-r + 1)...(r - 1) {
                    if let hit = at(x - r, y + dy) { return hit }
                    if let hit = at(x + r, y + dy) { return hit }
                }
            }
            r += 1
        }
        return nil
    }

    /// The region byte at a cell, or nil for outside and unassigned — the two
    /// values that are not regions.
    private func at(_ x: Int, _ y: Int) -> UInt8? {
        guard x >= 0, y >= 0, x < w, y < h else { return nil }
        let v = cells[y * w + x]
        return (v == Self.outside || v == Self.unassigned) ? nil : v
    }
}

#endif
