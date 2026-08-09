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
public struct EntryVisual {
    public enum Well {
        case color(Color)
        /// Country flag, filling the well. The 0.5.6 shaped-flag treatment
        /// (flag masked into an Iconify country outline) is gone — regions
        /// carry the drawn outline art as their glyph instead (v0.5.7, B3).
        case flag(country: String)
    }

    public var well: Well
    public var iconID: String?
    public var iconColor: Color
    /// Drawn as a 2pt ring around the well.
    public var ringColor: Color?
    /// Glyph scale relative to the well, matching the web app's per-category sizes.
    public var iconScale: CGFloat = 0.62
    /// Full-colour pixel-art portrait stem (Resources/FlavorArt). When set and
    /// the asset resolves, it replaces the tinted glyph — the art carries its
    /// own colours and outline, so no tint or `PixelOutline` applies.
    public var artName: String? = nil

    public static func resolve(_ entry: WineEntry, db: WineDatabase = .shared) -> EntryVisual {
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
        let well = grapeWellColor(style: g.grapeStyle.isEmpty ? (g.wineType ?? "") : g.grapeStyle,
                                  body: g.grapeBodyClass)

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

    /// `getGrapeIconColor`: the style tone palette first, then colour/body
    /// keyword heuristics.
    static func grapeWellColor(style: String, body: String, db: WineDatabase = .shared) -> Color {
        if let tone = styleTone(for: style, db: db) {
            return Color(dexHex: tone)
        }

        let type = TextNormalize.label(style)
        let bodyLevel = TextNormalize.label(body)
        guard !type.isEmpty else { return Color(dexHex: "#78716c") }

        if type.contains("red") || type.contains("bold") {
            if bodyLevel.contains("light") { return Color(dexHex: "#DC143C") }
            if bodyLevel.contains("full") { return Color(dexHex: "#4A0E0E") }
            return Color(dexHex: "#8B0000")
        }
        if type.contains("white") || type.contains("aromatic") {
            if bodyLevel.contains("light") { return Color(dexHex: "#FAFAD2") }
            if bodyLevel.contains("full") { return Color(dexHex: "#B8860B") }
            return Color(dexHex: "#DAA520")
        }
        if type.contains("rose") { return Color(dexHex: "#DB7093") }
        if type.contains("sweet") { return Color(dexHex: "#CD853F") }
        return Color(dexHex: "#78716c")
    }

    /// `normalizeStyleKey` + `STYLE_TONE_PALETTE`. The palette is generated, the
    /// matching is here.
    private static func styleTone(for style: String, db: WineDatabase) -> String? {
        let t = TextNormalize.label(style)
        guard !t.isEmpty else { return nil }

        func has(_ needles: [String]) -> Bool { needles.contains { t.contains($0) } }

        let key: String?
        if has(["full-body red", "full body red", "full-bodied red", "full bodied red"]) {
            key = "full-bodied red"
        } else if t.contains("bright red") {
            key = "bright red"
        } else if has(["light-body red", "light body red", "light-bodied red", "light bodied red"]) {
            key = "light-bodied red"
        } else if t.contains("dark red") {
            key = "dark red"
        } else if has(["medium-body red", "medium body red", "medium-bodied red", "medium bodied red"]) {
            key = "medium-bodied red"
        } else if has(["pink", "rose"]) {
            key = "rosé"
        } else if has(["light-body white", "light body white", "light-bodied white", "light bodied white"]) {
            key = "light-bodied white"
        } else if t.contains("aromatic white") {
            key = "aromatic white"
        } else if has(["high-acid white", "high acid white"]) {
            key = "high-acid white"
        } else if has(["full-body white", "full body white", "full-bodied white", "full bodied white"]) {
            key = "full-bodied white"
        } else if t.contains("sweet white") {
            key = "sweet white"
        } else if has(["medium-body white", "medium body white", "medium-bodied white", "medium bodied white"]) {
            key = "medium-bodied white"
        } else {
            key = nil
        }

        guard let key else { return nil }
        return db.palette.styleTones[key]?.primary
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
public final class EntryVisualCache {
    public static let shared = EntryVisualCache()

    private var cache: [String: EntryVisual] = [:]

    private init() {}

    public func visual(for entry: WineEntry) -> EntryVisual {
        if let hit = cache[entry.id] { return hit }
        let resolved = EntryVisual.resolve(entry)
        cache[entry.id] = resolved
        return resolved
    }
}

/// Loads the bundled pixel-art portraits — flavour art and grape bunches —
/// cached, with misses recorded so an absent asset is not re-probed every
/// render. Mirrors `FlagLoader`. One loader for both sets because the well
/// only carries one `artName` and the stems do not collide.
@MainActor
public final class PixelArtLoader {
    public static let shared = PixelArtLoader()

    /// **Bare directory names, not `Resources/...` paths** (merged from the
    /// Aug 5 Xcode/codesign branch).
    ///
    /// `Package.swift` used to ship `.copy("Resources")`, which put a directory
    /// literally named `Resources` at the root of the bundle — and a shallow
    /// iOS bundle shaped that way makes codesign refuse it as "bundle format
    /// unrecognized", because it can no longer tell a flat bundle from a deep
    /// macOS-style one. The fix copies each *child* individually, so the
    /// wrapper is gone from the bundle and every `Bundle.module` subdirectory
    /// lookup drops the prefix to match. The source tree is untouched; the
    /// importers still write to `Sources/VinodexUI/Resources/<Dir>`.
    ///
    /// **This is a silent failure if it is got wrong**, which is why it is
    /// worth a note rather than a shrug: `DexResources.url` falls back to a
    /// root-level lookup when the subdirectory misses, and a nested file is not
    /// at the root, so a stale `Resources/ButtonArt` returns nil and every
    /// drawn face degrades to the SF Symbol it replaced. Nothing throws and
    /// nothing logs. `ArtPipelineRosterTests.bundledArtDirectoriesAreRegistered`
    /// holds this list, `Package.swift` and the directories on disk equal so a
    /// tenth entry cannot land in two of the three.
    private static let subdirectories = [
        "FlavorArt",
        "GrapeArt",
        "StyleArt",
        // Taxonomy + outline art (v0.5.7): classes, subclasses, colour, body,
        // climate, soils, style classes and country outlines, reached through
        // `art:` icon ids — see `DexIcon`.
        "ClassArt",
        // Back-plate Passport stamp glyphs (0.6.4, F2), imported from
        // art/icons/chrome/stamps/ — the directory ships empty-of-art until the
        // glyphs are authored; a miss falls through to the SF stand-ins.
        "StampArt",
        // Per-skin back-plate sticker glyphs (0.7.8, A1), imported from
        // art/icons/chrome/stickers/. Its own directory since the sticker stopped
        // being a stamp — the two families are commissioned separately and a
        // shared folder was how a decal could be filed as a badge unnoticed.
        // Also ships empty-of-art; a miss falls through to the skin emblem.
        //
        // Two directories on this search path can never collide because the
        // stems are disjoint by construction (`stamp-*` from `StampCatalog`,
        // `sticker-*` from `ChassisSkin.stickerStem`), so "first hit wins"
        // stays a statement about ordering rather than about precedence.
        "StickerArt",
        // Drawn button faces (0.8.1, J2), imported from art/icons/chrome/buttons/.
        //
        // **Last on purpose, and the first entry that could actually collide.**
        // The two above are safe by construction — their stems carry `stamp-`
        // and `sticker-` prefixes — but these are named for the control they
        // sit on, so `search`, `home`, `edit`, `data`, `camera`, `regions`,
        // `styles`, `grapes` and `flavors` all enter a namespace that is flat
        // and global across every directory here. None of the 32 collides with
        // a catalog stem today (checked against FlavorArt/GrapeArt/StyleArt/
        // ClassArt at import). Ordering it last is the guard for tomorrow: if a
        // future flavour or style lands on one of these words, the catalog art
        // keeps winning and the button falls back to its stand-in, which is the
        // recoverable direction — the reverse would silently swap a portrait
        // for a piece of chrome.
        "ButtonArt",
        // Drawn footer caps (0.8.2), imported from art/icons/chrome/footer/,
        // and drawn cartridges (0.8.2), from art/icons/chrome/cartridges/.
        //
        // **Both prefixed, which is what keeps the entry above the last one
        // that had to argue about ordering.** `ButtonArt`'s note explains that
        // its stems are bare words in a flat global namespace and that placing
        // it last is a guard rather than a guarantee. These two do not need the
        // guard: `footer-` and `cartridge-` make them disjoint from everything
        // by construction, exactly as `stamp-` and `sticker-` are. It is the
        // convention to follow for the next directory — a second bare-word set
        // would mean two entries whose safety is a fact about today's catalog.
        "FooterArt",
        "CartridgeArt",
        // The dot-matrix marquee glyphs (0.8.4, A1), from
        // art/icons/chrome/marquee/. `marquee-` prefixed, which is the
        // convention the entry above asks the next directory to follow — and
        // here it is load-bearing rather than tidy: most of the stems are
        // words `ButtonArt` already uses (`settings`, `system`,
        // `shop`, `tools`, `user`, `data`, `dev`, `passport`, `firmware`,
        // `customize`, `moondial`, `tutorial`, `cheatcodes`,
        // `haptics`, `labelscanner`, `blindtasting`, `dailychallenge`,
        // `wineexam`; `whatsthat` was one until 0.8.93 atticked both
        // drawings), because they are the same pages drawn for a different
        // surface. Unprefixed, "first hit wins" would have decided which
        // register every one of those controls got, by list order.
        "MarqueeArt",
        // The painted UI glyphs (0.8.9a, A2), from art/icons/chrome/glyphs/,
        // and the Professor Vino expression set (A3), from
        // art/icons/chrome/vino/.
        //
        // **`glyph-` is the entry `ButtonArt`'s note was written for.** That
        // note argues that its own bare words are safe only as a fact about
        // today's catalog, and asks the next set to carry a prefix. This is
        // that set, and it needed the prefix on arrival rather than later:
        // `tools`, `firmware`, `seal` and `stamp` are all words already
        // spoken for above — by `ButtonArt`, by `MarqueeArt` and by
        // `StampArt` — so unprefixed, three of them would have been decided
        // by list order between two live drawings of the same subject in two
        // different registers, which is the exact fault `marquee-` was
        // introduced to prevent.
        "GlyphArt",
        // `VinoArt` ships ahead of anything that draws it: the presenter is
        // 0.8.9's phase 2. A directory searched before its art exists is the
        // case `unauthoredArtDirectories` was built for and this is not it —
        // the art is here, the *caller* is not, which no gate needs to know
        // about because a stem nobody asks for is simply never looked up.
        "VinoArt",
    ]

    private var cache: [String: UIImage?] = [:]

    private init() {}

    public func image(_ stem: String) -> UIImage? {
        if let hit = cache[stem] { return hit }
        var loaded: UIImage?
        for subdirectory in Self.subdirectories {
            if let url = DexResources.url(named: stem, ext: "png", subdirectory: subdirectory) {
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
public final class FlagLoader {
    public static let shared = FlagLoader()

    /// Keyed by country, with `nil` recorded for countries that have no flag so
    /// a miss is not retried on every render.
    private var cache: [String: UIImage?] = [:]

    private init() {}

    public func image(for country: String) -> UIImage? {
        if let hit = cache[country] { return hit }

        let loaded: UIImage? = WineDatabase.shared.icons.flagSlug(for: country)
            .flatMap { DexResources.url(named: $0, ext: "png", subdirectory: "Flags") }
            .flatMap { UIImage(contentsOfFile: $0.path) }

        cache[country] = loaded
        return loaded
    }
}

/// Renders an `EntryVisual` at a given size.
public struct EntryIconWell: View {
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

    private var visual: EntryVisual { EntryVisualCache.shared.visual(for: entry) }

    public init(
        entry: WineEntry,
        size: CGFloat = 48,
        cornerRadius: CGFloat = 8,
        showsGlyph: Bool = true,
        showsRegionDot: Bool = true
    ) {
        self.entry = entry
        self.size = size
        self.cornerRadius = cornerRadius
        self.showsGlyph = showsGlyph
        self.showsRegionDot = showsRegionDot
    }

    public var body: some View {
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
            FlagImage(country: country)
        }
    }
}

/// A bundled pixel flag, or the stone fallback when a country has none.
public struct FlagImage: View {
    let country: String

    public init(country: String) { self.country = country }

    public var body: some View {
        if let image = FlagLoader.shared.image(for: country) {
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
