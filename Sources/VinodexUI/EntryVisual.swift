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
        /// Country flag, optionally masked into that country's outline.
        case flag(country: String, shapeIcon: String?)
    }

    public var well: Well
    public var iconID: String?
    public var iconColor: Color
    /// Drawn as a 2pt ring around the well.
    public var ringColor: Color?
    /// Glyph scale relative to the well, matching the web app's per-category sizes.
    public var iconScale: CGFloat = 0.62

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

        return EntryVisual(well: .color(well), iconID: iconID, iconColor: tint, ringColor: nil)
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
    // The well *is* the country flag, ringed in the region's climate colour.
    // Where a country outline glyph exists the flag is masked into that shape;
    // otherwise it fills the well.

    private static func regionVisual(_ r: RegionEntry, db: WineDatabase) -> EntryVisual {
        let origin = r.details.origin.isEmpty ? r.common.name : r.details.origin
        let shape = db.icons.countryShapeIcons[TextNormalize.label(origin)]

        // Tint follows the region's key grape when it resolves, else its
        // appellation classification.
        var tint = Color(
            dexHex: db.palette.regionClassificationIconColors[r.details.classification] ?? "#e5e7eb"
        )
        if let keyGrape = r.details.notableGrapes.first,
           let grape = db.entry(named: keyGrape, category: .grapes),
           case .grape(let g) = grape {
            tint = grapeVisual(g, db: db).iconColor
        }

        let ring = r.climate.flatMap { db.palette.climates[$0.rawValue]?.colors.border }

        // Regions had no glyph at all — a flag well and nothing on it, the only
        // category rendering bare. The key grape's own glyph is the most
        // telling thing available (Bordeaux reads as blackcurrant, Burgundy as
        // cherry) and needs no new assets; climate is the fallback when the
        // grape does not resolve, which is the other thing a region *is*.
        var iconID: String?
        if let keyGrape = r.details.notableGrapes.first,
           let grape = db.entry(named: keyGrape, category: .grapes) {
            iconID = db.iconID(for: grape)
        }
        if iconID == nil || iconID == db.icons.fallback {
            iconID = db.icons.climateIcon(r.climate)
        }

        return EntryVisual(
            well: .flag(country: origin, shapeIcon: shape),
            iconID: iconID,
            iconColor: tint,
            ringColor: ring.map { Color(dexHex: $0) }
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

        if hasRealOrigin {
            return EntryVisual(
                well: .flag(country: origin, shapeIcon: nil),
                iconID: iconID,
                iconColor: tint,
                ringColor: .white
            )
        }

        return EntryVisual(
            well: .color(Color(dexHex: db.icons.styleClassBg[cls.rawValue] ?? s.common.color)),
            iconID: iconID,
            iconColor: tint,
            ringColor: .white
        )
    }

    // MARK: - Continents
    //
    // Well is the continent's own authored colour. No glyph: the generated
    // icon for continents (`lucide:globe`) isn't guaranteed to be rasterised
    // (see ContinentScreen, which uses an SF Symbol for its own hero instead
    // of going through this path) — showing nothing here is preferable to a
    // visible "missing icon" box wherever a continent's generic icon well is
    // drawn (e.g. the debug catalog).

    private static func continentVisual(_ c: ContinentEntry, db: WineDatabase) -> EntryVisual {
        // `iconID: nil` rendered a bare colour block, so continents in the
        // world search were the only rows with no glyph at all.
        EntryVisual(
            well: .color(Color(dexHex: c.common.color)),
            iconID: db.iconID(for: .continent(c)),
            iconColor: .white,
            ringColor: nil
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
            iconScale: 0.72
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
            .flatMap { DexResources.url(named: $0, ext: "png", subdirectory: "Resources/Flags") }
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

    private var visual: EntryVisual { EntryVisualCache.shared.visual(for: entry) }

    public init(entry: WineEntry, size: CGFloat = 48, cornerRadius: CGFloat = 8) {
        self.entry = entry
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let v = visual
        ZStack {
            background(v)
            if let iconID = v.iconID {
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

    @ViewBuilder
    private func background(_ v: EntryVisual) -> some View {
        switch v.well {
        case .color(let color):
            color
        case .flag(let country, let shapeIcon):
            if let shapeIcon {
                // Flag masked into the country's outline, over a blurred copy —
                // the shaped-flag treatment from the web app. One `FlagImage`
                // reused via `background`, not two: the same flag was previously
                // constructed twice here.
                FlagImage(country: country)
                    .mask(DexIcon(iconID: shapeIcon, size: size * 0.86, color: .white, outlined: false))
                    .background {
                        FlagImage(country: country).opacity(0.25).blur(radius: 2)
                    }
            } else {
                FlagImage(country: country)
            }
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
