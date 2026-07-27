import Foundation

/// Continent identifiers matching the globe's markers.
public enum Continent: String, Sendable, CaseIterable, Identifiable {
    case northAmerica = "NORTH_AMERICA"
    case southAmerica = "SOUTH_AMERICA"
    case europe = "EUROPE"
    case africa = "AFRICA"
    case asia = "ASIA"
    case oceania = "OCEANIA"

    public var id: String { rawValue }

    /// Two-line label used on the globe markers.
    public var markerLabel: String {
        switch self {
        case .northAmerica: "NORTH\nAMERICA"
        case .southAmerica: "SOUTH\nAMERICA"
        default: rawValue
        }
    }

    /// Latitude/longitude the marker is pinned to, from `RetroGlobeScreen.tsx`.
    public var coordinate: (lat: Double, lng: Double) {
        switch self {
        case .northAmerica: (38, -122)
        case .southAmerica: (-33, -70)
        case .europe: (43, 12)
        case .africa: (-33, 20)
        case .asia: (34, 105)
        case .oceania: (-35, 147)
        }
    }
}

/// Colour tables generated from the web app's lookup functions.
public struct Palette: Codable, Sendable {
    public struct Chip: Codable, Sendable, Hashable {
        public let bg: String
        public let border: String
        public let text: String

        /// Explicit because a struct's memberwise init is internal, and the UI
        /// module constructs ad-hoc chips for tasting notes and cross-links.
        public init(bg: String, border: String, text: String) {
            self.bg = bg
            self.border = border
            self.text = text
        }
    }

    public struct StyleTone: Codable, Sendable, Hashable {
        public let primary: String
        public let secondary: String
    }

    public struct ClimateMeta: Codable, Sendable {
        public let name: String
        public let description: String?
        public let colors: Chip
    }

    public let countryChips: [String: Chip]
    public let classificationChips: [String: Chip]
    public let wineTypeChips: [String: Chip]
    public let rarityChips: [String: Chip]
    public let colorTypeChips: [String: Chip]
    public let styleClassChips: [String: Chip]
    public let flavorClassChips: [String: Chip]
    public let flavorSubclassChips: [String: Chip]
    public let namedChips: [String: Chip]
    public let appellationChips: [Chip]
    public let styleTones: [String: StyleTone]
    public let climates: [String: ClimateMeta]
    public let regionClassificationIconColors: [String: String]
    public let flavorSubclassIconColors: [String: String]
    public let continentColors: [String: String]
    public let continentCountries: [String: [String]]

    public func chip(country: String?) -> Chip? {
        guard let country else { return nil }
        return countryChips[country]
    }

    public func climate(_ climate: ClimateClass) -> ClimateMeta? {
        climates[climate.rawValue]
    }
}

/// Which icon each entry uses, derived from the data by the generator rather
/// than hand-maintained. Ids are Iconify names (`game-icons:cherry`,
/// `lucide:droplet`), which the rasteriser turns into bundled PNGs.
public struct IconManifest: Codable, Sendable {
    public let byEntry: [String: String]
    public let unique: [String]
    public let fallback: String
    public let bodyIcons: [String: String]
    public let climateIcons: [String: String]
    public let colorIcons: [String: String]
    /// Glyph per style classification (TYPE/BLEND/ORIGIN/METHOD/STYLE).
    public let styleClassIcons: [String: String]
    /// Country outline glyphs, used to mask a flag into the country's shape.
    public let countryShapeIcons: [String: String]
    /// Icon-well background per style classification.
    public let styleClassBg: [String: String]
    /// Glyph tint per wine colour family.
    public let styleColorTypeColors: [String: String]
    /// Soil keyword -> glyph + colour.
    public let soilIcons: [String: SoilIcon]
    /// Soils used when a region carries no explicit `soilType`.
    public let climateSoilFallback: [String: [String]]
    public let defaultSoils: [String]
    /// Country name -> pixel-flag path in the web repo. Only countries present
    /// in the current selection ship.
    public let flags: [String: String]

    public struct SoilIcon: Codable, Sendable, Hashable {
        public let icon: String
        public let color: String
    }

    public func iconID(for entryID: String) -> String {
        byEntry[entryID] ?? fallback
    }

    /// Keyword match over the soil table, mirroring `getSoilIcon`.
    public func soilIcon(_ soil: String) -> SoilIcon {
        let s = soil.lowercased()
        for key in ["volcanic", "clay", "sand", "limestone", "chalk", "slate", "schist", "granite", "gravel"]
        where s.contains(key) {
            if let hit = soilIcons[key] { return hit }
        }
        return soilIcons["default"] ?? SoilIcon(icon: "lucide:mountain", color: "#8B4513")
    }

    /// `getSoilsForRegion`: split an explicit soil list, else fall back by climate.
    public func soils(soilType: String?, climate: ClimateClass?) -> [String] {
        if let soilType, !soilType.isEmpty {
            let parts: [String] = soilType
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return Array(parts.prefix(3))
        }
        if let climate, let fallback = climateSoilFallback[climate.rawValue] { return fallback }
        return defaultSoils
    }

    public func bodyIcon(_ bodyClass: String) -> String {
        bodyIcons[bodyClass] ?? "game-icons:scales"
    }

    public func climateIcon(_ climate: ClimateClass?) -> String {
        guard let climate else { return "game-icons:fluffy-cloud" }
        return climateIcons[climate.rawValue] ?? "game-icons:fluffy-cloud"
    }

    public func colorIcon(_ colorType: String) -> String {
        colorIcons[colorType] ?? "game-icons:wine-glass"
    }

    /// Bundled flag stem for a country, e.g. `New Zealand` -> `new-zealand`.
    public func flagSlug(for country: String?) -> String? {
        guard let country, flags[country] != nil else { return nil }
        return country.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    /// Filesystem-safe stem for a bundled PNG, e.g. `game-icons--cherry`.
    public static func slug(for iconID: String) -> String {
        iconID.replacingOccurrences(of: ":", with: "--")
    }
}

/// Loads and holds the bundled database.
///
/// Immutable after construction, so `shared` is safe under Swift 6 strict
/// concurrency without an actor. Note that anything genuinely mutable (an icon
/// cache, for instance) cannot be a bare `static var` — that is a compile error
/// in Swift 6 language mode.
public final class WineDatabase: Sendable {
    public static let shared = WineDatabase()

    public let entries: [WineEntry]
    public let palette: Palette
    public let icons: IconManifest

    /// Entries that failed to decode, if any. Empty in a healthy build; surfaced
    /// rather than swallowed so a schema drift is visible instead of silent.
    public let decodeErrors: [String]

    public init(entries: [WineEntry], palette: Palette, icons: IconManifest, decodeErrors: [String] = []) {
        self.entries = entries
        self.palette = palette
        self.icons = icons
        self.decodeErrors = decodeErrors
    }

    private convenience init() {
        do {
            let entries: [WineEntry] = try Self.decode("entries")
            let palette: Palette = try Self.decode("palette")
            let icons: IconManifest = try Self.decode("icons")
            self.init(entries: entries, palette: palette, icons: icons)
        } catch {
            // A failed load is a build problem, not a runtime condition to paper
            // over — but crashing the app on launch makes it undiagnosable on a
            // device with no debugger attached, so record and continue empty.
            self.init(
                entries: [],
                palette: Self.emptyPalette,
                icons: IconManifest(
                    byEntry: [:],
                    unique: [],
                    fallback: "mdi:help-circle-outline",
                    bodyIcons: [:],
                    climateIcons: [:],
                    colorIcons: [:],
                    styleClassIcons: [:],
                    countryShapeIcons: [:],
                    styleClassBg: [:],
                    styleColorTypeColors: [:],
                    soilIcons: [:],
                    climateSoilFallback: [:],
                    defaultSoils: [],
                    flags: [:]
                ),
                decodeErrors: ["\(error)"]
            )
        }
    }

    /// The icon id for an entry.
    public func iconID(for entry: WineEntry) -> String {
        icons.iconID(for: entry.id)
    }

    private static func decode<T: Decodable>(_ resource: String) throws -> T {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "json", subdirectory: "Resources")
            ?? Bundle.module.url(forResource: resource, withExtension: "json")
        else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(resource).json"])
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    private static let emptyPalette = Palette(
        countryChips: [:], classificationChips: [:], wineTypeChips: [:], rarityChips: [:],
        colorTypeChips: [:], styleClassChips: [:], flavorClassChips: [:], flavorSubclassChips: [:],
        namedChips: [:], appellationChips: [], styleTones: [:], climates: [:],
        regionClassificationIconColors: [:], flavorSubclassIconColors: [:],
        continentColors: [:], continentCountries: [:]
    )

    // MARK: - Queries

    public func entries(in category: EntryCategory) -> [WineEntry] {
        entries.apply(.category(category))
    }

    public func entry(id: String) -> WineEntry? {
        entries.first { $0.id == id }
    }

    /// Resolves a free-text name (or synonym) to an entry, for detail cross-links.
    ///
    /// Returning `nil` is expected and common in the starter dataset: most linked
    /// names point outside the 30-entry selection. Callers must render those as
    /// non-tappable labels rather than dead buttons — matching `isLinkable` in
    /// `EntryDetail.tsx`.
    public func entry(named name: String, category: EntryCategory? = nil) -> WineEntry? {
        let target = TextNormalize.key(name)
        guard !target.isEmpty else { return nil }
        let pool = category.map { c in entries.filter { $0.category == c } } ?? entries

        if let exact = pool.first(where: { TextNormalize.key($0.name) == target }) { return exact }
        return pool.first { entry in
            entry.synonyms.contains { TextNormalize.key($0) == target }
        }
    }

    /// The countries the globe attributes to a continent. Sourced from
    /// `data/continents.ts`, whose `keyRegions` field holds **country** names.
    public func countries(in continent: Continent) -> [String] {
        palette.continentCountries[continent.rawValue] ?? []
    }

    /// The filter a globe marker applies.
    public func filter(for continent: Continent) -> EntryFilter {
        .region(countries(in: continent))
    }

    public func regions(in continent: Continent) -> [WineEntry] {
        entries.apply(.category(.regions, filter: filter(for: continent)))
    }
}
