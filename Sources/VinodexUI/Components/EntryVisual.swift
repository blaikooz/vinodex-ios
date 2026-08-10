#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// How one entry's icon well is drawn: the background behind the glyph, the
/// glyph itself, its tint, and an optional ring.
///
/// Ports `resolveEntryIconVisual` from `entryIconVisuals.tsx`. Every category
/// gets its own rule below rather than sharing one generic path, because the
/// categories genuinely differ — grapes colour the well by wine style and take
/// their glyph from their primary tasting note, regions show a country flag
/// ringed by climate, styles colour by classification, flavours by subclass.
struct EntryVisual {
    enum Well {
        case color(Color)
        /// Country flag, filling the well. The 0.5.6 shaped-flag treatment
        /// (flag masked into an Iconify country outline) is gone — regions
        /// carry the drawn outline art as their glyph instead (v0.5.7, B3).
        case flag(country: String)
    }

    var well: Well
    var iconID: String?
    var iconColor: Color
    /// Drawn as a 2pt ring around the well.
    var ringColor: Color?
    /// Glyph scale relative to the well, matching the web app's per-category sizes.
    var iconScale: CGFloat = 0.62
    /// Full-colour pixel-art portrait stem (Resources/FlavorArt). When set and
    /// the asset resolves, it replaces the tinted glyph — the art carries its
    /// own colours and outline, so no tint or `PixelOutline` applies.
    var artName: String? = nil

    static func resolve(_ entry: WineEntry, db: WineDatabase = .shared) -> EntryVisual {
        switch entry {
        case .grape(let g): grapeVisual(g, db: db)
        case .region(let r): regionVisual(r, db: db)
        case .style(let s): styleVisual(s, db: db)
        case .flavor(let f): flavorVisual(f, db: db)
        case .continent(let c): continentVisual(c, db: db)
        }
    }

    // MARK: - Grapes
    //
    // Well colour comes from the wine style; the glyph is the grape's *primary
    // tasting note*, not a generic grape icon — so Cabernet reads as blackcurrant
    // and Chardonnay as apple. Tint follows that note's flavour subclass.

    private static func grapeVisual(_ g: GrapeEntry, db: WineDatabase) -> EntryVisual {
        // Through the injected `db`, not `.shared`: the old call dropped the
        // parameter on the floor, so an injected database got the bundled
        // one's well colours. (AUDIT **M27**, and the rule itself is **M29**.)
        let well = Color(dexHex: db.palette.grapeWellHex(
            style: g.grapeStyle.isEmpty ? (g.wineType ?? "") : g.grapeStyle,
            body: g.grapeBodyClass
        ))

        let primary = g.tastingProfile?.first
        let relatedFlavor = primary.flatMap { db.entry(named: $0.note, category: .flavors) }

        let iconID: String?
        let tint: Color

        if let relatedFlavor {
            iconID = db.iconID(for: relatedFlavor)
            if case .flavor(let f) = relatedFlavor,
               let hex = db.palette.flavorSubclassIconColors[f.details.subclass] {
                tint = Color(dexHex: hex)
            } else {
                tint = Color(dexHex: primary?.color ?? "#e5e7eb")
            }
        } else {
            iconID = db.iconID(for: .grape(g))
            tint = Color(dexHex: primary?.color ?? "#e5e7eb")
        }

        return EntryVisual(
            well: .color(well),
            iconID: iconID,
            iconColor: tint,
            // **Ringed by rarity since 0.6.9 (I2).** Grapes were the one
            // category with no ring at all — regions take their climate's,
            // styles take white, flavours take their subclass's — so a grape
            // well fell through to `EntryIconWell`'s 1pt black hairline, which
            // is the "no ring" case rather than a colour.
            //
            // Rarity is the right axis for it because the sprite inside the
            // well is *already* keyed on rarity: `GrapeSpriteLoader` re-inks
            // the bunch's leaf to the rarity colour (0.6.2, A2). The ring makes
            // that legible at row size, where a re-inked leaf is four pixels,
            // and it means one grape carries one rarity signal in two registers
            // rather than a badge bolted on beside it.
            //
            // The chip table's `border` stop, not `text` or `bg`: it is the
            // saturated one of the three, and it is what the RARITY chip on the
            // same row is already outlined in — so the ring and the chip
            // visibly agree. Optional-chained rather than defaulted, so a
            // rarity absent from the generated table leaves the hairline it
            // always had instead of inventing a colour.
            ringColor: db.palette.rarityChips[g.rarity.rawValue].map { Color(dexHex: $0.border) },
            // The bunch sprite (0.5.4): colour, depth, blend and leaf derived
            // from the grape itself — see `GrapeArt`. The tasting-note glyph
            // above stays resolved as the fallback.
            artName: db.icons.grapeArtStem(forKey: GrapeArt.key(for: g))
        )
    }

    // MARK: - Regions
    //
    // The well *is* the country flag, ringed in the region's climate colour,
    // with the country's drawn outline art on top (v0.5.7, B3). Both the
    // borrowed key-grape glyph and the masked-flag outline treatment are gone
    // — the outline art says "place" more plainly than either did.

    private static func regionVisual(_ r: RegionEntry, db: WineDatabase) -> EntryVisual {
        let origin = r.details.origin.isEmpty ? r.common.name : r.details.origin

        let ring = r.climate.flatMap { db.palette.climates[$0.rawValue]?.colors.border }

        // The outline art, via the manifest's shape table. State first
        // (v0.5.8, D2): a Willamette row should read as Oregon, not as the
        // whole USA. Climate stays the fallback for a place with no outline.
        let iconID = r.details.state.flatMap { db.icons.countryShapeIcons[TextNormalize.label($0)] }
            ?? db.icons.countryShapeIcons[TextNormalize.label(origin)]
            ?? db.icons.climateIcon(r.climate)

        return EntryVisual(
            well: .flag(country: origin),
            iconID: iconID,
            iconColor: .white,
            ringColor: ring.map { Color(dexHex: $0) },
            iconScale: 0.78
        )
    }

    // MARK: - Styles
    //
    // Well is the origin country's flag when the style has a real origin;
    // otherwise a colour keyed to its classification. Glyph is the class icon,
    // tinted by wine colour family.

    private static func styleVisual(_ s: StyleEntry, db: WineDatabase) -> EntryVisual {
        let cls = EntryDisplay.styleClass(name: s.common.name, classification: s.details.classification)
        let colorType = EntryDisplay.colorType(name: s.common.name)

        let tint = Color(dexHex: db.icons.styleColorTypeColors[colorType.rawValue] ?? "#e5e7eb")
        let iconID = db.icons.styleClassIcons[cls.rawValue] ?? db.icons.fallback

        let origin = s.details.origin
        let hasRealOrigin = !origin.isEmpty
            && origin.lowercased() != "various"
            && db.icons.flagSlug(for: origin) != nil

        // The pixel-art portrait (0.5.6), when the set has one — over the
        // flag or the class-coloured well alike; the glyph stays the fallback.
        let artName = db.icons.styleArtStem(for: s.common.name)

        // A style with no portrait wears its class glyph as the picture
        // (GSM Blend, deliberately portrait-less since 0.6.4 D1) — and at
        // 0.95 rather than glyph scale (0.6.5, item 5): the drawn class art
        // carries its own margins, so at 0.62 it floated small in the well,
        // reading as an icon where its siblings show a portrait.
        let glyphScale: CGFloat = artName == nil ? 0.95 : 0.62

        if hasRealOrigin {
            return EntryVisual(
                well: .flag(country: origin),
                iconID: iconID,
                iconColor: tint,
                ringColor: .white,
                iconScale: glyphScale,
                artName: artName
            )
        }

        return EntryVisual(
            well: .color(Color(dexHex: db.icons.styleClassBg[cls.rawValue] ?? s.common.color)),
            iconID: iconID,
            iconColor: tint,
            ringColor: .white,
            iconScale: glyphScale,
            artName: artName
        )
    }

    // MARK: - Continents
    //
    // Well is the continent's own authored colour, with the generated continent
    // glyph drawn on top. This used to render no glyph — the icon wasn't
    // guaranteed to be rasterised — so continent rows in world search were the
    // only ones that were a bare colour block; the glyph is now generated and
    // bundled like every other icon.

    private static func continentVisual(_ c: ContinentEntry, db: WineDatabase) -> EntryVisual {
        // `iconID: nil` rendered a bare colour block, so continents in the
        // world search were the only rows with no glyph at all.
        EntryVisual(
            well: .color(Color(dexHex: c.common.color)),
            iconID: db.iconID(for: .continent(c)),
            iconColor: .white,
            ringColor: nil,
            // The drawn globes (v0.5.9, B1): at the default 0.62 the sphere
            // floated small in its well, because the canvas's transparent
            // margins are part of the art. Near-full-bleed reads right.
            iconScale: 0.9
        )
    }

    // MARK: - Flavors
    //
    // Well is the flavour's own colour, ringed and tinted by its subclass, with
    // a slightly larger glyph.

    private static func flavorVisual(_ f: FlavorEntry, db: WineDatabase) -> EntryVisual {
        let subclassColor = Color(
            dexHex: db.palette.flavorSubclassIconColors[f.details.subclass] ?? "#e5e7eb"
        )
        return EntryVisual(
            well: .color(Color(dexHex: f.common.color)),
            iconID: db.iconID(for: .flavor(f)),
            iconColor: subclassColor,
            ringColor: subclassColor,
            iconScale: 0.72,
            // The pixel-art portrait, when the set has one for this flavour.
            // The glyph above stays resolved as the fallback — and as what
            // grapes borrow for their primary-note icon.
            artName: db.icons.flavorArtStem(for: f.common.name)
        )
    }
}

/// Memoises `EntryVisual.resolve` per entry id.
///
/// Resolving is not cheap — a region walks its key grape, that grape's primary
/// tasting note, and the flavour subclass palette — and it was being redone on
/// every render of every row, including rows that had not changed. The result
/// depends only on the entry and the immutable database, so it is safe to
/// compute once and keep. `@MainActor` for the same reason as `IconLoader`:
/// Swift 6 strict concurrency rejects a mutable static cache.
@MainActor
final class EntryVisualCache {
    static let shared = EntryVisualCache()

    /// Keyed by database *identity* first, then entry id (AUDIT **M27**).
    ///
    /// This is the trap the item's own remedy walks into. Threading a `db`
    /// parameter through every screen while leaving a process-wide cache keyed
    /// on `entry.id` alone makes injection *look* done: the second database to
    /// ask about an entry silently receives the first one's answer, and no
    /// compile check in this project can see it, in the one module no test can
    /// run. The database is immutable for its lifetime, so identity is a sound
    /// key — and there is exactly one in a shipping build, so the extra level
    /// costs one dictionary lookup.
    private var cache: [ObjectIdentifier: [String: EntryVisual]] = [:]

    private init() {}

    func visual(for entry: WineEntry, in db: WineDatabase) -> EntryVisual {
        let owner = ObjectIdentifier(db)
        if let hit = cache[owner]?[entry.id] { return hit }
        let resolved = EntryVisual.resolve(entry, db: db)
        cache[owner, default: [:]][entry.id] = resolved
        return resolved
    }
}

/// Loads the bundled pixel-art portraits — flavour art and grape bunches —
/// cached, with misses recorded so an absent asset is not re-probed every
/// render. Mirrors `FlagLoader`. One loader for both sets because the well
/// only carries one `artName` and the stems do not collide.
@MainActor
final class PixelArtLoader {
    static let shared = PixelArtLoader()

    /// Not private: `DexAssetAudit` walks the same five directories, and two
    /// copies of this list is exactly the drift **L26** exists to catch. Each
    /// entry's path comes from `DexAsset`, which is where the rest of the
    /// drift **A22** named used to live — the cases carry the notes.
    static let directories: [DexAsset] = [
        .flavorArt,
        .grapeArt,
        .styleArt,
        .classArt,
        .stampArt,
    ]

    private var cache: [String: UIImage?] = [:]

    private init() {}

    func image(_ stem: String) -> UIImage? {
        if let hit = cache[stem] { return hit }
        var loaded: UIImage?
        for directory in Self.directories {
            if let url = DexResources.url(named: stem, ext: "png", in: directory) {
                loaded = UIImage(contentsOfFile: url.path)
                break
            }
        }
        cache[stem] = loaded
        return loaded
    }
}

/// Loads bundled flag PNGs, cached.
///
/// Mirrors `IconLoader`. Uncached, this re-read and re-decoded the same PNG from
/// the bundle on every render — and the masked-flag path builds two `FlagImage`s
/// for the same country, so a list of regions was doing hundreds of redundant
/// filesystem lookups per frame.
@MainActor
final class FlagLoader {
    static let shared = FlagLoader()

    /// Keyed by *slug* — a filename — with `nil` recorded for a slug that has
    /// no bundled PNG so a miss is not retried on every render.
    ///
    /// It used to key on country and resolve the slug itself off
    /// `WineDatabase.shared`, which made the cache a data cache wearing an
    /// asset cache's clothes: two databases disagreeing about a country's flag
    /// would have shared one entry. Resolving the slug at the call site leaves
    /// this keyed on the thing it actually loads. (AUDIT **M27**)
    private var cache: [String: UIImage?] = [:]

    private init() {}

    func image(slug: String) -> UIImage? {
        if let hit = cache[slug] { return hit }

        let loaded = DexResources.url(named: slug, ext: "png", in: .flags)
            .flatMap { UIImage(contentsOfFile: $0.path) }

        cache[slug] = loaded
        return loaded
    }
}

/// Renders an `EntryVisual` at a given size.
struct EntryIconWell: View {
    let entry: WineEntry
    var size: CGFloat
    var cornerRadius: CGFloat
    /// Whether the glyph/art layer draws at all. The region *hero* passes
    /// false (v0.5.6): at hero size the flag well is the picture, and a
    /// glyph stamped on it read as a badge on a flag. Rows keep theirs.
    var showsGlyph: Bool
    /// Whether a region's outline glyph carries its red location dot
    /// (v0.5.9, C1) — the country-scan treatment, at well size. On by
    /// default since 0.6 (B1): list rows carry it too, scaled to the row
    /// icon, so a region reads as a *place on its map* everywhere it appears.
    var showsRegionDot: Bool

    var db: WineDatabase

    private var visual: EntryVisual { EntryVisualCache.shared.visual(for: entry, in: db) }

    init(
        db: WineDatabase = .shared,
        entry: WineEntry,
        size: CGFloat = 48,
        cornerRadius: CGFloat = 8,
        showsGlyph: Bool = true,
        showsRegionDot: Bool = true
    ) {
        self.db = db
        self.entry = entry
        self.size = size
        self.cornerRadius = cornerRadius
        self.showsGlyph = showsGlyph
        self.showsRegionDot = showsRegionDot
    }

    var body: some View {
        let v = visual
        ZStack {
            background(v)
            if !showsGlyph {
                // The well alone — see `showsGlyph`.
                EmptyView()
            } else if showsRegionDot, case .region(let r) = entry,
                      let iconID = v.iconID, iconID.hasPrefix("art:"),
                      let art = PixelArtLoader.shared.image(String(iconID.dropFirst(4))) {
                dottedOutline(art, stem: String(iconID.dropFirst(4)), region: r, visual: v)
            } else if let stem = v.artName, let art = artImage(stem) {
                // The portrait ships its own colours and chunky outline, so it
                // renders as-is — tinting or outlining it would double up.
                // Slightly larger than the glyph scale: the art's transparent
                // margins are part of the canvas.
                Image(uiImage: art)
                    // AUDIT **L28**. The grape bunches and flavour portraits
                    // are the largest pixel art the app draws, and they were
                    // the ones still sampling linearly — a soft, smeared
                    // upscale where every other pixel surface stays crisp.
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.82, height: size * 0.82)
            } else if let iconID = v.iconID {
                DexIcon(iconID: iconID, size: size * v.iconScale, color: v.iconColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(v.ringColor ?? .black.opacity(0.25), lineWidth: v.ringColor == nil ? 1 : 2)
        )
    }

    /// The portrait for an art stem. Grape bunches route through
    /// `GrapeSpriteLoader` (0.6.2, A2) so their leaf is re-inked to the
    /// rarity's colour; everything else loads as drawn.
    private func artImage(_ stem: String) -> UIImage? {
        if case .grape(let g) = entry {
            return GrapeSpriteLoader.shared.image(stem: stem, rarity: g.rarity)
        }
        return PixelArtLoader.shared.image(stem)
    }

    /// The region's outline glyph with its red location dot (v0.5.9, C1) —
    /// `CountryOutlineMap`'s treatment, at well size. Geographic where the
    /// region carries a `mapPosition` (0.6.x), snapped to land; the seeded
    /// walk stays as the fallback. Sized off the well (v0.6, B1) so one rule
    /// serves both registers: ~14pt on a hero, ~5pt in a list row.
    private func dottedOutline(
        _ art: UIImage,
        stem: String,
        region r: RegionEntry,
        visual v: EntryVisual
    ) -> some View {
        let box = size * v.iconScale
        let scale = min(box / art.size.width, box / art.size.height)
        let fitted = CGSize(width: art.size.width * scale, height: art.size.height * scale)
        let dotSize = max(5, size * 0.095)
        return ZStack {
            Image(uiImage: art)
                // The region outline, crisp for the same reason (AUDIT **L28**).
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
            if let dot = OutlineDotPlacer.shared.dots(
                stem: stem,
                specs: [.init(name: r.common.name, hint: r.details.mapPosition)]
            ).first {
                Circle()
                    .fill(Dex.red500)
                    .overlay(Circle().strokeBorder(.black.opacity(0.7), lineWidth: max(1, dotSize * 0.11)))
                    .frame(width: dotSize, height: dotSize)
                    .position(x: dot.x * scale, y: dot.y * scale)
            }
        }
        .frame(width: fitted.width, height: fitted.height)
    }

    @ViewBuilder
    private func background(_ v: EntryVisual) -> some View {
        switch v.well {
        case .color(let color):
            color
        case .flag(let country):
            FlagImage(db: db, country: country)
        }
    }
}

/// A bundled pixel flag, or the stone fallback when a country has none.
struct FlagImage: View {
    let country: String
    var db: WineDatabase

    init(db: WineDatabase = .shared, country: String) {
        self.db = db
        self.country = country
    }

    var body: some View {
        if let slug = db.icons.flagSlug(for: country), let image = FlagLoader.shared.image(slug: slug) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fill)
        } else {
            Dex.stone800
        }
    }
}
#endif
