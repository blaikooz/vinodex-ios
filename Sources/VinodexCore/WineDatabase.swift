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

    /// Latitude/longitude the marker is pinned to.
    ///
    /// These are continent centroids, not wine regions. The values ported from
    /// `RetroGlobeScreen.tsx` were the latter — North America sat on San
    /// Francisco, Africa on Cape Town, South America on Santiago — so markers
    /// hung off the edge of the landmass they label, and no uniform nudge could
    /// fix them because each was wrong by a different amount.
    public var coordinate: (lat: Double, lng: Double) {
        switch self {
        case .northAmerica: (45, -100)
        case .southAmerica: (-15, -60)
        case .europe: (50, 15)
        case .africa: (2, 20)
        case .asia: (45, 90)
        case .oceania: (-25, 135)
        }
    }

    /// Box the centroid must fall inside, so a bad edit is caught by a test
    /// rather than by squinting at the globe on a phone.
    public var coordinateBounds: (lat: ClosedRange<Double>, lng: ClosedRange<Double>) {
        switch self {
        case .northAmerica: (25...70, -130...(-60))
        case .southAmerica: (-40...10, -80...(-35))
        case .europe: (40...65, -10...40)
        case .africa: (-30...30, -15...50)
        case .asia: (20...65, 45...140)
        case .oceania: (-40...(-10), 115...155)
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
    /// Match order for `soilIcons`, generated alongside it. Optional so an
    /// older manifest still decodes; `soilIcon(_:)` falls back to the table's
    /// own keys, which costs only the ordering guarantee.
    public let soilKeywords: [String]?
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
    ///
    /// First substring wins, so the generated `soilKeywords` order matters —
    /// "clay loam" must reach `clay` before `loam`. The keyword list used to be
    /// hardcoded here and drifted from the generator's table, which silently
    /// dropped soils onto the default glyph.
    public func soilIcon(_ soil: String) -> SoilIcon {
        let s = soil.lowercased()
        let keys = soilKeywords ?? soilIcons.keys.filter { $0 != "default" }.sorted()
        for key in keys where s.contains(key) {
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
    /// Entry ids the free tier unlocks. Empty means *everything* is free — a
    /// missing or unreadable manifest must not lock the app down.
    public let freeIDs: Set<String>

    /// Entries that failed to decode, if any. Empty in a healthy build; surfaced
    /// rather than swallowed so a schema drift is visible instead of silent.
    public let decodeErrors: [String]

    public init(
        entries: [WineEntry],
        palette: Palette,
        icons: IconManifest,
        freeIDs: Set<String> = [],
        decodeErrors: [String] = []
    ) {
        self.entries = entries
        self.palette = palette
        self.icons = icons
        self.freeIDs = freeIDs
        self.decodeErrors = decodeErrors
    }

    /// Whether an entry is in the free tier.
    ///
    /// An id absent from the manifest is **not** free — that is the paywall
    /// doing its job, and there is no way to tell "paid entry" from "entry we
    /// forgot to regenerate" at this level. The only safety valve is the whole
    /// manifest being missing, which unlocks everything rather than locking a
    /// build out of its own data.
    public func isFree(_ id: String) -> Bool {
        freeIDs.isEmpty || freeIDs.contains(id)
    }

    private convenience init() {
        do {
            let entries: [WineEntry] = try Self.decode("entries")
            let palette: Palette = try Self.decode("palette")
            let icons: IconManifest = try Self.decode("icons")
            // Optional on purpose: a build without it is fully unlocked.
            let tiers: EntryTiers? = try? Self.decode("tiers")
            self.init(
                entries: entries,
                palette: palette,
                icons: icons,
                freeIDs: Set(tiers?.free ?? [])
            )
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
                    soilKeywords: nil,
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

    /// Whether at least one region in the current selection has this country
    /// as its origin — what makes a continent's country row tappable.
    /// Case-insensitive: region origins and continent country names are
    /// both authored strings and don't always agree on case.
    public func hasRegions(inCountry country: String) -> Bool {
        let target = TextNormalize.label(country)
        return entries(in: .regions).contains { TextNormalize.label($0.origin ?? "") == target }
    }

    /// The continent entry for a globe marker, by the `CONT_<RAWVALUE>` id
    /// scheme shared with the web app and `data/continents.ts`.
    public func continentEntry(_ continent: Continent) -> ContinentEntry? {
        if case .continent(let c)? = entry(id: "CONT_\(continent.rawValue)") { return c }
        return nil
    }
}

/// The free-tier manifest, generated alongside the dataset.
public struct EntryTiers: Codable, Sendable {
    public let free: [String]
}
