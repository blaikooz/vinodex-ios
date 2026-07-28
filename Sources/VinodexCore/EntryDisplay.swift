import Foundation

/// Display-label inference ported from `src/services/entryUtils.ts` and
/// `grapeDisplay.ts`. Lives in Core rather than UI because it is pure string
/// logic and the tests depend on it.

public enum StyleClassType: String, Sendable, CaseIterable {
    case origin = "ORIGIN"
    case method = "METHOD"
    case type = "TYPE"
    case blend = "BLEND"
    case style = "STYLE"
}

public enum StyleColorType: String, Sendable, CaseIterable {
    case red = "RED"
    case white = "WHITE"
    case rose = "ROSE"
    case orange = "ORANGE"
    case dual = "DUAL"
}

public enum EntryDisplay {
    // Keyword tables transcribed from entryUtils.ts. Order matters: ORIGIN is
    // tested before TYPE before METHOD.
    static let originKeywords = [
        "champagne", "port", "sherry", "prosecco", "cremant", "cru beaujolais", "super tuscan",
    ]
    static let methodKeywords = [
        "sparkling", "fortified", "dessert", "late harvest", "ice wine", "botrytis",
        "petillant", "natural wine", "orange wine",
    ]
    static let typeKeywords = [
        "full-body", "full body", "full-bodied", "full bodied",
        "light-body", "light body", "light-bodied", "light bodied",
        "medium-body", "medium body", "medium-bodied", "medium bodied",
        "aromatic", "white", "red", "rose", "sweet white", "sparkling wine",
    ]

    /// Note that `classification: "STYLE"` is *not* an override — only ORIGIN,
    /// METHOD, TYPE and BLEND are. Everything else falls through to keyword
    /// matching, which is why no entry in the database resolves to `.style`.
    public static func styleClass(name: String, classification: String?) -> StyleClassType {
        if let raw = classification?.uppercased(),
           let override = StyleClassType(rawValue: raw),
           override != .style {
            return override
        }
        let normalized = TextNormalize.label(name)
        if originKeywords.contains(where: { normalized.contains($0) }) { return .origin }
        if typeKeywords.contains(where: { normalized.contains($0) }) { return .type }
        if methodKeywords.contains(where: { normalized.contains($0) }) { return .method }
        return .style
    }

    public static func colorType(name: String) -> StyleColorType {
        let n = TextNormalize.label(name)
        if n.contains("orange") { return .orange }
        if n.contains("rose") { return .rose }
        if n.contains("red") { return .red }
        if n.contains("white") { return .white }
        return .dual
    }

    /// RED / WHITE label for a grape tile chip.
    public static func grapeColorLabel(_ grape: GrapeEntry) -> String {
        grape.grapeType.rawValue.uppercased()
    }

    /// Body class label, already normalised upstream by `getGrapeBodyClass`.
    public static func grapeBodyLabel(_ grape: GrapeEntry) -> String {
        grape.grapeBodyClass.uppercased()
    }

    /// Title-cases an underscored key for display, e.g. `ORCHARD_FRUIT` -> `Orchard Fruit`.
    public static func humanize(_ raw: String) -> String {
        raw.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    /// Spells out an appellation abbreviation for the region detail screen.
    ///
    /// The dataset stores the short form (`AOC`, `DOCG`) because that is what
    /// labels and the chip palette are keyed by, but the abbreviation alone
    /// tells a reader nothing. Country matters: `DOC` and `DO` are used by
    /// several countries for differently-spelled systems, so the pair is the
    /// key, not the abbreviation on its own.
    ///
    /// Unknown pairs return the classification unchanged, so a new region
    /// renders its abbreviation rather than blank.
    public static func appellationName(classification: String, country: String) -> String {
        let system = classification.trimmingCharacters(in: .whitespaces)
        let place = TextNormalize.label(country)

        switch (system.uppercased(), place) {
        case ("AOC", _):   return "Appellation d'Origine Contrôlée"
        case ("AVA", _):   return "American Viticultural Area"
        case ("DAC", _):   return "Districtus Austriae Controllatus"
        case ("DHC", _):   return "Districtus Hungaricus Controllatus"
        case ("GI", _):    return "Geographical Indication"
        case ("PDO", _):   return "Protected Designation of Origin"
        case ("WO", _):    return "Wine of Origin"
        case ("DOCG", _):  return "Denominazione di Origine Controllata e Garantita"
        case ("DOCA", _):  return "Denominación de Origen Calificada"
        case ("DO", _):    return "Denominación de Origen"

        // The genuinely ambiguous one: same abbreviation, three languages.
        case ("DOC", "italy"):    return "Denominazione di Origine Controllata"
        case ("DOC", "portugal"): return "Denominação de Origem Controlada"
        case ("DOC", _):          return "Denominación de Origen Controlada"

        default: return system
        }
    }
}

public extension WineEntry {
    /// The chips shown on this entry's list tile, as (label, paletteKey, table)
    /// triples resolved against the generated palette by the UI layer.
    var tileChips: [TileChip] {
        switch self {
        case .grape(let g):
            return [
                TileChip(label: EntryDisplay.grapeColorLabel(g), key: g.grapeType.rawValue, table: .wineType),
                TileChip(label: EntryDisplay.grapeBodyLabel(g), key: g.grapeStyle, table: .wineType),
                TileChip(label: g.details.origin.uppercased(), key: g.details.origin, table: .country),
            ]
        case .region(let r):
            var chips = [
                TileChip(label: r.details.origin.uppercased(), key: r.details.origin, table: .country),
                TileChip(label: r.details.classification.uppercased(), key: "SYSTEM", table: .named),
            ]
            if let climate = r.climate {
                chips.append(TileChip(label: climate.rawValue.uppercased(), key: climate.rawValue, table: .climate))
            }
            return chips
        case .style(let s):
            let cls = EntryDisplay.styleClass(name: s.common.name, classification: s.details.classification)
            let color = EntryDisplay.colorType(name: s.common.name)
            var chips = [
                TileChip(label: cls.rawValue, key: cls.rawValue, table: .styleClass),
                TileChip(label: color.rawValue, key: color.rawValue, table: .colorType),
            ]
            if s.details.origin.lowercased() != "various" {
                chips.append(TileChip(label: s.details.origin.uppercased(), key: s.details.origin, table: .country))
            }
            return chips
        case .flavor(let f):
            return [
                TileChip(label: f.details.classification, key: f.details.classification, table: .flavorClass),
                TileChip(label: EntryDisplay.humanize(f.details.subclass).uppercased(), key: f.details.subclass, table: .flavorSubclass),
            ]
        case .continent:
            // Continents aren't shown in a generic tile listing — they're
            // reached only via the globe, straight to ContinentScreen — so
            // this case is unexercised in practice.
            return []
        }
    }
}

public struct TileChip: Sendable, Hashable, Identifiable {
    public enum Table: Sendable, Hashable {
        case country, wineType, climate, styleClass, colorType, flavorClass, flavorSubclass, rarity, named
    }

    public let label: String
    public let key: String
    public let table: Table

    public init(label: String, key: String, table: Table) {
        self.label = label
        self.key = key
        self.table = table
    }

    public var id: String { "\(table)-\(key)-\(label)" }
}
