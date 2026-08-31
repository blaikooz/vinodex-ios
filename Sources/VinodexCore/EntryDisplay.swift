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

    /// The colour of grape a wine of this style is actually made from, or nil
    /// where the style spans both.
    ///
    /// **ROSE and ORANGE name a process, not a grape**, and no grape in the
    /// catalogue carries either — `GrapeColor` has exactly two cases. Before
    /// this mapping their COLOR chip opened onto an empty list.
    ///
    /// The answers are not a judgement call: they are stated in the shipped
    /// entries' own descriptions. Rosé — *"pink wines made from **red grapes**
    /// with minimal skin contact"*. Orange Wine — *"**White grapes** vinified
    /// like red wine, with extended skin contact"*. So the chip on a Rosé page
    /// leads to the red grapes it is pressed from, which is the question
    /// someone tapping it is asking.
    public var grapeColor: GrapeColor? {
        switch self {
        case .red: .red
        case .white: .white
        case .rose: .red
        case .orange: .white
        case .dual: nil
        }
    }
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

    /// `STYLE_NAME_COLOR_OVERRIDES`, transcribed from `entryUtils.ts`.
    ///
    /// **This table was missing entirely until 0.8.1, item B.** `getColorType`
    /// consults it *before* the keyword chain; the Swift port went straight to
    /// the keywords, so all sixteen overrides — every one of which names a real
    /// style exactly — stopped at the shared/device boundary. Sixteen of the
    /// thirty-three styles therefore reported a different colour on the phone
    /// than the data says, and fifteen of them landed on `.dual`, which is a
    /// plausible-looking answer for a name with no colour word in it. That is
    /// why it survived: DUAL is what an un-overridden Champagne *should* look
    /// like if you did not know the table existed.
    ///
    /// Keys are `TextNormalize.label` output (lowercased, diacritics folded,
    /// punctuation intact) and are looked up trimmed, exactly as the TS does.
    static let colorOverrides: [String: StyleColorType] = [
        "prosecco": .white,
        "champagne": .white,
        "cremant": .white,
        "sparkling wine": .white,
        // Sherry's white ruling (0.8.1): an override states the colour of the
        // wine, and Sherry is a white wine that happens to arrive in the
        // glass brown — oxidative ageing darkens it, not red fruit.
        //
        // The "cava" and "madeira" rows left with their style entries
        // (0.9.42): S033 and S034 came off the shelf, this table's own test
        // requires every key to name a real style, and an override for a
        // name no entry carries is a row waiting to mislead the next reader.
        // Madeira's white ruling (0.8.2, sommbot) is preserved in the git
        // history should the style return.
        "sherry": .white,
        "port": .red,
        "gsm blend": .red,
        "bordeaux blend": .red,
        "super tuscan": .red,
        "cru beaujolais": .red,
        "dessert wine": .white,
        "late harvest": .white,
        "ice wine": .white,
        "botrytis wine": .white,
        "qvevri amber": .orange,
    ]

    /// `\b` semantics: a hit only counts when neither edge abuts a word
    /// character. The TS keyword chain is four `\b`-anchored regexes and the
    /// port used bare `contains`, which is the second half of item B and the
    /// half that did visible damage.
    ///
    /// **`"prosecco"` contains `"rose"`** — p·*rose*·cco. With the override
    /// table absent and the boundary absent, Prosecco did not merely fall
    /// through to DUAL like its fifteen neighbours; it matched the rosé branch
    /// and shipped a confident wrong answer. One missing table and one missing
    /// boundary, and only their intersection was loud enough to get reported.
    static func containsWord(_ haystack: String, _ word: String) -> Bool {
        let isWordChar: (Character) -> Bool = { $0.isLetter || $0.isNumber || $0 == "_" }
        var search = haystack[...]
        while let found = search.range(of: word) {
            let beforeOK = found.lowerBound == haystack.startIndex
                || !isWordChar(haystack[haystack.index(before: found.lowerBound)])
            let afterOK = found.upperBound == haystack.endIndex
                || !isWordChar(haystack[found.upperBound])
            if beforeOK && afterOK { return true }
            search = haystack[found.lowerBound...].dropFirst()
        }
        return false
    }

    /// `getColorType` — the override table first, then `\b`-anchored keywords.
    ///
    /// Kept as a derivation rather than a lookup of a generated field because
    /// `WineEntry.tileChips` is a property on the entry with no database in
    /// scope, and because the label scanner asks this question about names that
    /// are not in the catalog at all. The generated `Palette.styleColorTypes`
    /// is not a second answer, it is the pin: `CoverageTests` asserts this
    /// function reproduces the shared one for every style that ships.
    public static func colorType(name: String) -> StyleColorType {
        let n = TextNormalize.label(name)
        if let override = colorOverrides[n.trimmingCharacters(in: .whitespaces)] { return override }
        if containsWord(n, "orange") { return .orange }
        if containsWord(n, "rose") { return .rose }
        if containsWord(n, "red") { return .red }
        if containsWord(n, "white") { return .white }
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
        case ("AOP", _):   return "Appellation d'Origine Protégée"
        case ("IGP", _):   return "Indication Géographique Protégée"
        case ("IGT", _):   return "Indicazione Geografica Tipica"
        case ("AVA", _):   return "American Viticultural Area"
        case ("DAC", _):   return "Districtus Austriae Controllatus"
        case ("DHC", _):   return "Districtus Hungaricus Controllatus"
        case ("GI", _):    return "Geographical Indication"
        case ("PDO", _):   return "Protected Designation of Origin"
        case ("PGI", _):   return "Protected Geographical Indication"
        case ("WO", _):    return "Wine of Origin"
        // The 0.6.2 code-chip pass: every abbreviated tag on a country page
        // gets its plain-text expansion beside the chip.
        case ("VR", _):        return "Vinho Regional"
        case ("PAGO", _):      return "Vino de Pago"
        case ("VP", _):        return "Vino de Pago"
        case ("PRÄDIKAT", _):  return "Prädikatswein"
        case ("QBA", _):       return "Qualitätswein bestimmter Anbaugebiete"
        case ("VDP", _):       return "Verband Deutscher Prädikatsweingüter"
        case ("PUTTONYOS", _): return "Tokaji Aszú puttonyos scale"
        case ("VCP", _):       return "Vino de Calidad Preferente"
        case ("DOCG", _):  return "Denominazione di Origine Controllata e Garantita"
        case ("DOCA", _):  return "Denominación de Origen Calificada"
        // Priorat's Catalan form of DOCa (0.6, A2).
        case ("DOQ", _):   return "Denominació d'Origen Qualificada"
        // Portuguese, not Spanish — the same trap `DOC` below is split three
        // ways for. Brazil's country chips carry `DO` and would otherwise have
        // been spelled out in the wrong language on its own page.
        case ("DO", "brazil"): return "Denominação de Origem"
        case ("DO", _):    return "Denominación de Origen"
        // The 0.6 catalog boost's new systems: Canada, Croatia, Morocco, and
        // the Spanish-American IG countries (Argentina, Uruguay).
        case ("VQA", _):   return "Vintners Quality Alliance"
        case ("ZOI", _):   return "Zaštićena Oznaka Izvornosti"
        case ("AOG", _):   return "Appellation d'Origine Garantie"
        case ("IG", _):    return "Indicación Geográfica"
        // Brazil (0.7.3c). `IP` is the tier most of the Serra's delimited areas
        // hold; `DO` is the one above it, which only Vale dos Vinhedos and a
        // handful of others have reached.
        case ("IP", _):    return "Indicação de Procedência"

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
                // **The colour chip reads `colorTypeChips`, uppercased**
                // (0.6.9, I1). It asked `wineTypeChips` for `"red"` / `"white"`
                // — the wrong table *and* the wrong case. `wineTypeChips` is
                // keyed by style ("Full-Body Red", "Aromatic White"), every
                // generated palette table is keyed uppercase, and the lookup
                // therefore missed on all 146 grapes and fell through to
                // `Palette.resolve`'s neutral stone fallback. That is what
                // "the red and white chips show the wrong colors" was: not a
                // bad palette, a chip that never reached one. `colorTypeChips`
                // has carried the right pair the whole time — RED is #3b0f0f
                // on #8b0000 and WHITE is #3b2f00 on #b8860b, which is the dark
                // red and the yellow the brief asks for.
                //
                // The label was already correct (`grapeColorLabel` uppercases),
                // which is exactly why this survived: the chip said RED and was
                // grey, so it read as a styling choice rather than a miss.
                TileChip(
                    label: EntryDisplay.grapeColorLabel(g),
                    key: g.grapeType.rawValue.uppercased(),
                    table: .colorType
                ),
                // The *style* chip does belong to `wineTypeChips`, and its key
                // matches that table's vocabulary as authored.
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
