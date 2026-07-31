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
    ///
    /// Four of them then carry a deliberate offset *from* the centroid, judged
    /// on the device. The label is a 108x62 box centred on its point, so a
    /// centroid-accurate pin puts half the box over the landmass's northern
    /// half; biasing south (and away from the limb the continent trails toward)
    /// seats the box on the body of the landmass instead of across its top edge.
    /// Latitude down moves the marker down the screen, longitude up moves it
    /// right — see `latLngToVector3` in `RetroGlobeScreen`.
    public var coordinate: (lat: Double, lng: Double) {
        switch self {
        case .northAmerica: (37, -108)   // down + left, off (45, -100)
        case .southAmerica: (-23, -68)   // down + left, off (-15, -60)
        case .europe: (50, 15)
        case .africa: (-6, 12)           // down + left, off (2, 20)
        case .asia: (37, 100)            // down + right, off (45, 90)
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
    public let styleTones: [String: StyleTone]
    public let climates: [String: ClimateMeta]
    public let regionClassificationIconColors: [String: String]
    public let flavorSubclassIconColors: [String: String]
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
    /// Glyph per flavour class (SWEET/SOUR/SALTY/BITTER/UMAMI) and per subclass
    /// (BERRY, SMOKY, WOOD, ...). Optional so an older manifest still decodes;
    /// `flavorClassIcon(_:)` falls back to the placeholder glyph.
    ///
    /// Both tiles on a flavour's scan used to draw `byEntry` — the *entry's* own
    /// glyph — so CLASS and SUBCLASS were always the same picture, and it was a
    /// different picture for every entry in the same subclass.
    public let flavorClassIcons: [String: String]?
    public let flavorSubclassIcons: [String: String]?
    /// Full-colour pixel-art portrait per flavour, keyed by the flavour's
    /// *normalised name* (`TextNormalize.label`) rather than its id — the art
    /// set is named by flavour, and ids would break the moment one is re-keyed.
    /// Values are PNG stems under `Resources/FlavorArt`. Optional so an older
    /// manifest still decodes; flavours without art keep their tinted glyph.
    public let flavorArt: [String: String]?
    /// Bunch-sprite stem per `GrapeArt` key (`green-light-none-common` …),
    /// PNGs under `Resources/GrapeArt`. Generated over the full combo grid
    /// with fallbacks, so every key the app can derive resolves. Optional so
    /// an older manifest still decodes; grapes then keep their tinted glyph.
    public let grapeArt: [String: String]?
    /// Full-colour pixel-art portrait per style, keyed by *normalised name*
    /// like `flavorArt`. PNGs under `Resources/StyleArt`. Optional so an
    /// older manifest still decodes; styles then keep their class glyph.
    public let styleArt: [String: String]?
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

    public func flavorClassIcon(_ classification: String) -> String {
        flavorClassIcons?[classification] ?? fallback
    }

    public func flavorSubclassIcon(_ subclass: String) -> String {
        flavorSubclassIcons?[subclass] ?? fallback
    }

    /// Pixel-art stem for a flavour name, or nil when the set has no portrait
    /// for it. Normalised on the way in so "Crème de Cassis"-style accents and
    /// case differences cannot miss their art.
    public func flavorArtStem(for name: String) -> String? {
        flavorArt?[TextNormalize.label(name)]
    }

    /// Bunch-sprite stem for a `GrapeArt` key, or nil when no art shipped.
    public func grapeArtStem(forKey key: String) -> String? {
        grapeArt?[key]
    }

    /// Pixel-art stem for a style name, or nil when the set has no portrait.
    public func styleArtStem(for name: String) -> String? {
        styleArt?[TextNormalize.label(name)]
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
    /// Authored prose for the country (and state) pages, keyed by name.
    ///
    /// Countries are not entries here — a country page is assembled from the
    /// regions that name it as their origin — so there is nowhere on an entry
    /// for a country's description to live. See `CountryInfo`.
    public let countries: [String: CountryInfo]
    /// Entry ids the free tier unlocks. Empty means *everything* is free — a
    /// missing or unreadable manifest must not lock the app down.
    public let freeIDs: Set<String>

    /// Entries that failed to decode, if any. Empty in a healthy build; surfaced
    /// rather than swallowed so a schema drift is visible instead of silent.
    public let decodeErrors: [String]

    /// id -> entry, so `entry(id:)` is a hash lookup rather than a scan of the
    /// whole entry array. Every navigation used to pay that scan.
    private let byID: [String: WineEntry]

    /// (category, normalised name-or-synonym) -> entry.
    ///
    /// `entry(named:)` is the hottest call in the app: resolving one region row's
    /// visual alone called it three times, and each call used to `filter` the
    /// whole entry array into a fresh array and then `TextNormalize.key` every
    /// candidate name until it hit. Across a full list that was tens of thousands
    /// of diacritic foldings per render. Folding once per entry at load time and
    /// hashing thereafter is what makes master search open instantly.
    ///
    /// Names are inserted before synonyms and never overwritten, preserving the
    /// old lookup's precedence: an exact name match beat any synonym match.
    private let byName: [EntryCategory: [String: WineEntry]]
    /// The same table with no category constraint, for `entry(named:)` calls
    /// that pass `category: nil`.
    private let byNameAnyCategory: [String: WineEntry]

    /// Countries, as searchable items (v0.5.6). Countries are not entries —
    /// a country page is assembled from the regions that name it — so master
    /// and world search list them from here. Only countries with regions in
    /// the selection ship: a hit must open a page with something on it.
    public let searchableCountries: [String]

    public init(
        entries: [WineEntry],
        palette: Palette,
        icons: IconManifest,
        countries: [String: CountryInfo] = [:],
        freeIDs: Set<String> = [],
        decodeErrors: [String] = []
    ) {
        self.entries = entries
        self.palette = palette
        self.icons = icons
        self.countries = countries
        self.freeIDs = freeIDs
        self.decodeErrors = decodeErrors

        var countrySet = Set<String>()
        for entry in entries {
            if case .region(let r) = entry, !r.details.origin.isEmpty {
                countrySet.insert(r.details.origin)
            }
        }
        self.searchableCountries = countrySet.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        var ids: [String: WineEntry] = [:]
        ids.reserveCapacity(entries.count)
        var names: [EntryCategory: [String: WineEntry]] = [:]
        var anyName: [String: WineEntry] = [:]
        anyName.reserveCapacity(entries.count * 2)

        // Two passes so names win over synonyms globally, not just within one
        // entry — otherwise an earlier entry's synonym could shadow a later
        // entry's real name, which the old first-exact-then-synonym scan never did.
        for entry in entries {
            ids[entry.id] = entry
            let key = TextNormalize.key(entry.name)
            guard !key.isEmpty else { continue }
            if names[entry.category]?[key] == nil { names[entry.category, default: [:]][key] = entry }
            if anyName[key] == nil { anyName[key] = entry }
        }
        for entry in entries {
            for synonym in entry.synonyms {
                let key = TextNormalize.key(synonym)
                guard !key.isEmpty else { continue }
                if names[entry.category]?[key] == nil { names[entry.category, default: [:]][key] = entry }
                if anyName[key] == nil { anyName[key] = entry }
            }
        }

        self.byID = ids
        self.byName = names
        self.byNameAnyCategory = anyName
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

    /// The generated-data schema generation this build decodes (0.6.3, item 1 —
    /// AUDIT M3's Swift half).
    ///
    /// Bumped in lockstep with `SCHEMA_VERSION` in `scripts/generate-ios-data.ts`
    /// whenever the emitted shape changes incompatibly. Asserted at load: a
    /// mismatch — or a missing stamp, which means the bundled data predates the
    /// generator that this code expects — lands in `decodeErrors` and therefore
    /// in the DEV panel, the launch alert, and `CoverageTests`, instead of
    /// surfacing as an unexplained whole-app decode failure.
    public static let expectedSchemaVersion = 1

    /// The `schema.json` stamp emitted alongside the dataset.
    struct SchemaStamp: Codable {
        let schemaVersion: Int
    }

    /// One element of `entries.json`, decoded so that it can never throw
    /// (0.6.3, item 1 — AUDIT H2).
    ///
    /// `JSONDecoder` aborts an array decode at the first failing element, so one
    /// malformed entry used to empty the *whole* database with no user-facing
    /// signal (it has happened — see the COUNTRY_GATE note in
    /// `generate-ios-data.ts`). Decoding through this wrapper turns each failure
    /// into a diagnostic instead: the good entries survive, and the reasons
    /// reach `decodeErrors`.
    private struct FailableEntry: Decodable {
        let entry: WineEntry?
        let failure: String?

        /// For naming the culprit when the full decode has already failed.
        private enum IdentityKeys: String, CodingKey {
            case id, name
        }

        init(from decoder: any Decoder) {
            do {
                entry = try WineEntry(from: decoder)
                failure = nil
            } catch {
                entry = nil
                // Best-effort identification: a diagnostic that cannot say
                // *which* entry broke sends whoever reads it back to a diff of
                // the whole file.
                var who = "<unidentified entry>"
                if let c = try? decoder.container(keyedBy: IdentityKeys.self) {
                    if let id = try? c.decode(String.self, forKey: .id) {
                        who = id
                    } else if let name = try? c.decode(String.self, forKey: .name) {
                        who = name
                    }
                }
                failure = "\(who): \(error)"
            }
        }
    }

    /// Element-wise entries decode (0.6.3, item 1 — AUDIT H2).
    ///
    /// Throws only when the data is not a JSON array at all — a file-level
    /// problem the empty-database fallback below handles. A *per-entry* failure
    /// never throws: it drops that entry and reports why, so a schema drift in
    /// one record costs one record rather than all of them.
    ///
    /// `public` so the corrupt-fixture tests can exercise it directly; the
    /// bundled-resource path goes through here too, so the tests test the code
    /// the app runs.
    public static func decodeEntries(from data: Data) throws -> (entries: [WineEntry], failures: [String]) {
        let wrapped = try JSONDecoder().decode([FailableEntry].self, from: data)
        return (
            entries: wrapped.compactMap(\.entry),
            failures: wrapped.compactMap(\.failure).map { "entries.json: \($0)" }
        )
    }

    private convenience init() {
        do {
            let (entries, entryFailures) = try Self.decodeEntries(from: Self.resourceData("entries"))
            let palette: Palette = try Self.decode("palette")
            let icons: IconManifest = try Self.decode("icons")

            var loadErrors: [String] = entryFailures

            // The schema stamp, generated alongside the dataset. Checked before
            // anything is *reported* healthy: entry failures above say what
            // broke, this says why — usually "the data and the app are from
            // different generations; run npm run generate". A missing stamp is
            // the same condition wearing older clothes, so it gets the same
            // treatment rather than a silent pass.
            do {
                let stamp: SchemaStamp = try Self.decode("schema")
                if stamp.schemaVersion != Self.expectedSchemaVersion {
                    loadErrors.append(
                        "schema.json is generation \(stamp.schemaVersion); this build expects \(Self.expectedSchemaVersion) — regenerate (npm run generate)"
                    )
                }
            } catch {
                loadErrors.append(
                    "schema.json missing or unreadable — bundled data predates the schema stamp; regenerate (npm run generate)"
                )
            }

            // Tiers: a *missing* manifest means "everything free" (a build with no
            // paywall), which is the only safe fallback that can't lock a build out
            // of its own data. But a *present-but-corrupt* manifest must not take
            // that same silent unlock — record it so it reaches decodeErrors and
            // the DEV panel instead of quietly opening the whole catalogue. (M1)
            var freeIDs: Set<String> = []
            do {
                let tiers: EntryTiers = try Self.decode("tiers")
                freeIDs = Set(tiers.free)
            } catch let error as CocoaError where error.code == .fileNoSuchFile {
                // No tiers file — fully unlocked, by design.
            } catch {
                loadErrors.append("tiers.json failed to decode; paywall left open — \(error)")
            }

            // Also optional: without it a country page falls back to the
            // derived summary sentence, which is worse but not broken.
            let countries: [String: CountryInfo] = (try? Self.decode("countries")) ?? [:]
            self.init(
                entries: entries,
                palette: palette,
                icons: icons,
                countries: countries,
                freeIDs: freeIDs,
                decodeErrors: loadErrors
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
                    flavorClassIcons: nil,
                    flavorSubclassIcons: nil,
                    flavorArt: nil,
                    grapeArt: nil,
                    styleArt: nil,
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

    /// Raw bytes of a bundled resource. Split from `decode` so entries can go
    /// through the element-wise path above, which needs the data rather than a
    /// finished value.
    private static func resourceData(_ resource: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "json", subdirectory: "Resources")
            ?? Bundle.module.url(forResource: resource, withExtension: "json")
        else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(resource).json"])
        }
        return try Data(contentsOf: url)
    }

    private static func decode<T: Decodable>(_ resource: String) throws -> T {
        try JSONDecoder().decode(T.self, from: resourceData(resource))
    }

    private static let emptyPalette = Palette(
        countryChips: [:], classificationChips: [:], wineTypeChips: [:], rarityChips: [:],
        colorTypeChips: [:], styleClassChips: [:], flavorClassChips: [:], flavorSubclassChips: [:],
        namedChips: [:], styleTones: [:], climates: [:],
        regionClassificationIconColors: [:], flavorSubclassIconColors: [:],
        continentCountries: [:]
    )

    // MARK: - Queries

    public func entries(in category: EntryCategory) -> [WineEntry] {
        entries.apply(.category(category))
    }

    /// The searchable countries matching a query — all of them for an empty
    /// query, diacritic-insensitive substring otherwise, like `matchesSearch`.
    public func countries(matching query: String) -> [String] {
        let q = TextNormalize.label(query)
        guard !q.isEmpty else { return searchableCountries }
        return searchableCountries.filter { TextNormalize.label($0).contains(q) }
    }

    public func entry(id: String) -> WineEntry? {
        byID[id]
    }

    /// Resolves a free-text name (or synonym) to an entry, for detail cross-links.
    ///
    /// Returning `nil` is expected: some linked names point outside the shipped
    /// selection. Callers must render those as
    /// non-tappable labels rather than dead buttons — matching `isLinkable` in
    /// `EntryDetail.tsx`.
    /// Resolved through `byName`, built once at load — see its declaration for
    /// why this matters.
    public func entry(named name: String, category: EntryCategory? = nil) -> WineEntry? {
        let target = TextNormalize.key(name)
        guard !target.isEmpty else { return nil }
        guard let category else { return byNameAnyCategory[target] }
        return byName[category]?[target]
    }

    /// The authored blurb for a country or state, if one was generated.
    ///
    /// Case-insensitive on the same grounds as `hasRegions(inCountry:)`: region
    /// origins and the country table are both hand-authored strings and do not
    /// always agree on case.
    public func countryInfo(_ name: String) -> CountryInfo? {
        if let hit = countries[name] { return hit }
        let target = TextNormalize.label(name)
        return countries.first { TextNormalize.label($0.key) == target }?.value
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

    /// Distinct countries the regions come from.
    ///
    /// Counted off region origins rather than `palette.continentCountries`,
    /// which lists every country the globe *knows about* including ones with no
    /// region written yet — the DATA panel should report what is actually in
    /// here, not what is planned. Folded through `TextNormalize.label` for the
    /// same reason `hasRegions(inCountry:)` is: origins are hand-authored and
    /// do not always agree on case.
    public var countryCount: Int {
        Set(
            entries(in: .regions)
                .compactMap(\.origin)
                .map { TextNormalize.label($0) }
                .filter { !$0.isEmpty }
        ).count
    }

    /// Per-category counts for the DATA readout.
    ///
    /// In `VinodexCore` rather than the panel that draws it so it is reachable
    /// from `VinodexCoreTests` — `VinodexUI` has no test target, and a count
    /// that silently drifts is exactly the kind of thing `CoverageTests` is for.
    public var databaseStats: DatabaseStats {
        DatabaseStats(
            grapes: entries(in: .grapes).count,
            regions: entries(in: .regions).count,
            styles: entries(in: .styles).count,
            flavors: entries(in: .flavors).count,
            continents: entries(in: .continents).count,
            countries: countryCount,
            total: entries.count
        )
    }
}

/// What the shipped database holds, for the DATA panel.
///
/// `countries` is deliberately not an `EntryCategory`: countries are not
/// entries — a country page is assembled from the regions naming it as their
/// origin — so it is counted separately and carries no category.
public struct DatabaseStats: Sendable, Hashable {
    public let grapes: Int
    public let regions: Int
    public let styles: Int
    public let flavors: Int
    public let continents: Int
    public let countries: Int
    public let total: Int

    public init(
        grapes: Int,
        regions: Int,
        styles: Int,
        flavors: Int,
        continents: Int,
        countries: Int,
        total: Int
    ) {
        self.grapes = grapes
        self.regions = regions
        self.styles = styles
        self.flavors = flavors
        self.continents = continents
        self.countries = countries
        self.total = total
    }

    /// One labelled count in the DATA panel's grid.
    ///
    /// A struct rather than a tuple because the panel feeds these to `ForEach`,
    /// and key paths — which `Identifiable` and `ForEach(_:id:)` both need —
    /// cannot address tuple elements.
    public struct Line: Sendable, Hashable, Identifiable {
        public let label: String
        public let count: Int

        public var id: String { label }

        public init(label: String, count: Int) {
            self.label = label
            self.count = count
        }
    }

    /// Category counts in the order the panel lists them, paired with the
    /// label each is shown under. Countries sit last, after the five real
    /// categories, because they are the one line that is not an entry count.
    public var categoryLines: [Line] {
        [
            Line(label: "GRAPES", count: grapes),
            Line(label: "REGIONS", count: regions),
            Line(label: "STYLES", count: styles),
            Line(label: "FLAVORS", count: flavors),
            Line(label: "CONTINENTS", count: continents),
            Line(label: "COUNTRIES", count: countries),
        ]
    }

    /// Milestones the DATA panel's wave sweeps through: empty, the original
    /// starter selection, the first full import, then each release total the
    /// database has stood at. Fixed history plus a live tail — **append the
    /// outgoing total here whenever a data change moves it** (0.6.x), so the
    /// graph keeps a running record of how the catalog has grown.
    public var waveMilestones: [Int] {
        [
            0,
            25,   // the curated starter selection
            186,  // the first full import
            281,  // 0.5.8
            342,  // 0.6.1
            total,
        ]
    }
}

/// The free-tier manifest, generated alongside the dataset.
public struct EntryTiers: Codable, Sendable {
    public let free: [String]
}

/// Authored INFO copy for one country or state.
///
/// A struct rather than a bare `String` so the file can grow fields (a founding
/// date, a bottle count) without another optional resource and another decode
/// path — the country page has more room than it currently uses.
public struct CountryInfo: Codable, Sendable, Hashable {
    public let description: String
    /// The country's canonical appellation system(s) (0.6, A2) — e.g.
    /// ["DOCG", "DOC", "IGT"]. Optional so a pre-0.6 countries.json still
    /// decodes; the INFO section simply omits the line.
    public let appellationSystem: [String]?

    public init(description: String, appellationSystem: [String]? = nil) {
        self.description = description
        self.appellationSystem = appellationSystem
    }
}
