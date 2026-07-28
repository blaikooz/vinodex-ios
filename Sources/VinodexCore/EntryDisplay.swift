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

    /// U+00AD SOFT HYPHEN. Invisible unless the layout breaks there, in which
    /// case it renders as a hyphen.
    public static let softHyphen = "\u{00AD}"

    /// Inserts soft hyphens into long words so a narrow chip can break them.
    ///
    /// SwiftUI's `Text` exposes no hyphenation setting, so a single long word
    /// like MEDITERRANEAN cannot wrap at all — it just shrinks via
    /// `minimumScaleFactor` until it is barely legible in a third-width tile.
    /// Soft hyphens give the layout somewhere to break; they cost nothing when
    /// there is room, and they do not affect search, which runs on the raw data
    /// rather than on display strings.
    ///
    /// Naive fixed-width chunking rather than real syllabification: this is a
    /// break *opportunity*, not a typographic claim, and a dictionary for it
    /// would be far more machinery than a chip label warrants.
    public static func hyphenated(
        _ text: String,
        minWordLength: Int = 10,
        chunk: Int = 4
    ) -> String {
        text.split(separator: " ", omittingEmptySubsequences: false)
            .map { word -> String in
                guard word.count >= minWordLength else { return String(word) }
                var out = ""
                for (index, character) in word.enumerated() {
                    // Never break within `chunk` of either end: a one- or
                    // two-letter orphan on its own line looks like a typo.
                    if index > 0, index % chunk == 0, word.count - index >= chunk {
                        out += softHyphen
                    }
                    out.append(character)
                }
                return out
            }
            .joined(separator: " ")
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
                TileChip(
                    label: r.details.classification.uppercased(),
                    key: r.details.classification,
                    table: .classification
                ),
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
            // Continents do reach a tile listing now: the world search covers
            // them alongside regions. One chip is enough — naming member
            // countries here duplicated the continent screen's own list and
            // made the row noisier than the regions beside it.
            return [TileChip(label: "CONTINENT", key: "Continent", table: .named)]
        }
    }
}

public struct TileChip: Sendable, Hashable, Identifiable {
    public enum Table: Sendable, Hashable {
        case country, wineType, climate, styleClass, colorType, flavorClass, flavorSubclass, rarity, named
        /// Appellation systems. Its own table so a region's list tile and its
        /// detail section resolve the same colour — the tile used to key the
        /// literal "SYSTEM" against `namedChips` (a generic grey) while the
        /// detail keyed "AOC" against `classificationChips` (rose), so the same
        /// appellation appeared in two colours depending on where you saw it.
        case classification
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
