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

    /// One-line name, for anywhere the marker's line break would be wrong: the
    /// globe's continent-list fallback, VoiceOver labels, the scanner's step
    /// title. Callers used to reach for `markerLabel` and strip the newline by
    /// hand, which is a rule about globe geometry leaking into three unrelated
    /// places. (AUDIT M20)
    public var displayName: String {
        markerLabel.replacingOccurrences(of: "\n", with: " ")
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

    /// Style id -> `StyleColorType` rawValue, as the shared `getColorType`
    /// answers it. Read by `CoverageTests` and by nothing else: it exists so
    /// that `EntryDisplay.colorType`'s port cannot drift from `entryUtils.ts`
    /// unnoticed again (0.8.1, B).
    public let styleColorTypes: [String: String]

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
    /// Country name -> the filename its flag is bundled under, generated
    /// alongside `flags` (AUDIT **L25**). Optional so an older manifest still
    /// decodes; `flagSlug(for:)` then falls back to the rule this replaced.
    public let flagSlugs: [String: String]?

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
    ///
    /// Read from the generated table rather than re-derived (AUDIT **L25**).
    /// The name is decided by `flagSlug()` in `generate-ios-data.ts`, which is
    /// also what `rasterize-icons.sh` names the copied PNG with — one rule, so
    /// the file the app asks for is by construction the file that was written.
    ///
    /// The fallback is the pre-**L25** derivation, kept only so a manifest
    /// generated before the table existed still finds its flags. It is correct
    /// for every current key and wrong for the first accented one, which is
    /// the whole reason the table exists.
    public func flagSlug(for country: String?) -> String? {
        guard let country, flags[country] != nil else { return nil }
        if let generated = flagSlugs?[country] { return generated }
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
    ///
    /// Read this as *the app is damaged*: it raises the launch `DexAlert`, it
    /// decides what an empty screen means (`dataState`), and it is pinned empty
    /// by `CoverageTests`. Anything that does not cost the app data or
    /// correctness belongs in `loadNotices` instead.
    public let decodeErrors: [String]

    /// Load-time observations that are **not** faults (AUDIT **M45**).
    ///
    /// The distinction is the whole of M45. A *missing* schema stamp used to
    /// append a decode error unconditionally, so every build carrying data
    /// generated before the stamp existed raised the DATA LOAD ERROR alert on
    /// every single launch — a false positive for anyone testing an older
    /// snapshot. But an absent stamp is not evidence of damage: data older than
    /// the stamp either decodes, in which case nothing is wrong, or fails
    /// per-entry, in which case those failures are already faults in their own
    /// right and say far more than the stamp could. So it goes in front of a
    /// maintainer — the DEV panel, and `DecodeRobustnessTests`, which fails CI
    /// if the *bundled* data has no stamp. That is the item's other half:
    /// fail the build, not the launch.
    public let loadNotices: [String]
    /// The pedigree graph (0.7.5, E).
    ///
    /// Built here for the reason `byID` and `byName` are: it is a reverse index
    /// over the whole grape list, the screen that reads it would otherwise
    /// rebuild it on every navigation, and this type is where "one pass at load"
    /// already lives. One pass over 171 records; see `GrapeLineageIndex`.
    public let lineage: GrapeLineageIndex

    /// id -> entry, so `entry(id:)` is a hash lookup rather than a scan of the
    /// whole entry array. Every navigation used to pay that scan.
    private let byID: [String: WineEntry]

    /// The tastable half of the catalog, folded once (0.8.9b).
    ///
    /// Built here for the reason `byID`, `byName` and `lineage` are, and the
    /// note on `byName` is the precedent word for word: `DiscoveryIndex` is
    /// constructed on every evaluation of the entry screen's INSIGHT panel — and
    /// the entry screen re-evaluates on scroll, because its anchor is state — so
    /// the catalog side of it would otherwise fold ~180 grape names through
    /// `TextNormalize.label` and scan the entry array twice, per scroll event.
    /// That is precisely the "tens of thousands of diacritic foldings per
    /// render" `byName` was extracted to stop.
    ///
    /// The catalog cannot change for a loaded database, so only the *shelf* side
    /// of `DiscoveryIndex` is per-call, and that is proportional to what the
    /// user has actually tried.
    public let discoveryCatalog: DiscoveryCatalog

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

    /// Every entry, pre-sorted into the display order every listing uses, and
    /// the folded search text for each — parallel arrays, built once at load
    /// (AUDIT M5).
    ///
    /// `[WineEntry].apply(_:)` did both halves per call: it folded every
    /// searched field of every entry against the query, then sorted the
    /// survivors with `localizedCaseInsensitiveCompare`. On the list screen
    /// that ran per keystroke; on the chip filter and the scanner it ran per
    /// *body pass*. Sorting once and folding once is the same trick `byName`
    /// already plays for `entry(named:)` — see the note there.
    ///
    /// Filtering a sorted array preserves its order, so `entries(matching:)`
    /// needs no sort at all.
    private let sortedEntries: [WineEntry]
    private let searchHaystacks: [String]

    /// Countries, as searchable items (v0.5.6). Countries are not entries —
    /// a country page is assembled from the regions that name it — so master
    /// and world search list them from here. Only countries with regions in
    /// the selection ship: a hit must open a page with something on it.
    public let searchableCountries: [String]

    /// The same origins folded through `TextNormalize.label`, as a set (AUDIT
    /// **L14**).
    ///
    /// `hasRegions(inCountry:)` used to answer by re-filtering the whole
    /// catalog into a fresh array and folding every survivor's origin — once
    /// per country row, per render, on a continent page that shows a dozen of
    /// them. It is a membership test against a set built by the walk two lines
    /// above, which was already visiting exactly these strings.
    ///
    /// Normalised rather than raw, unlike `searchableCountries`: the callers
    /// compare through `TextNormalize.label`, and a set of raw origins would
    /// silently miss every row whose case the authored data disagrees about —
    /// which is the whole reason that fold is there.
    private let regionOriginLabels: Set<String>

    public init(
        entries: [WineEntry],
        palette: Palette,
        icons: IconManifest,
        countries: [String: CountryInfo] = [:],
        freeIDs: Set<String> = [],
        decodeErrors: [String] = [],
        loadNotices: [String] = []
    ) {
        self.entries = entries
        self.palette = palette
        self.icons = icons
        self.countries = countries
        self.freeIDs = freeIDs
        self.decodeErrors = decodeErrors
        self.loadNotices = loadNotices

        var countrySet = Set<String>()
        var originLabels = Set<String>()
        for entry in entries {
            if case .region(let r) = entry, !r.details.origin.isEmpty {
                countrySet.insert(r.details.origin)
                let label = TextNormalize.label(r.details.origin)
                if !label.isEmpty { originLabels.insert(label) }
            }
        }
        self.searchableCountries = countrySet.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        self.regionOriginLabels = originLabels

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
        self.discoveryCatalog = DiscoveryCatalog(entries: entries)

        let sorted = entries.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        self.sortedEntries = sorted
        self.searchHaystacks = sorted.map(\.searchHaystack)

        self.lineage = GrapeLineageIndex(
            grapes: entries.compactMap {
                if case .grape(let g) = $0 { return g }
                return nil
            }
        )
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

    /// The three outcomes of reading one bundled table (AUDIT **M46**).
    ///
    /// `tiers.json` has told missing from corrupt since **M1**, and that is the
    /// shape every optional table wants: absent is a documented fallback,
    /// present-but-broken is a fault worth naming. Spelling it once lets the
    /// five loads below read as one rule instead of five coincidences.
    private enum ResourceLoad<T> {
        case loaded(T)
        case missing
        case corrupt(any Error)
    }

    /// Where the loader gets a table's bytes.
    ///
    /// Threaded rather than hardcoded because otherwise none of the failure
    /// semantics below can be tested at all: every branch of **M45**/**M46** is
    /// a statement about what happens when a specific file is absent or
    /// malformed, and the bundle only ever offers the healthy case. It is also
    /// the shortest route to the fixture database the audit keeps asking for
    /// (**M27**, **M32**) — hand it two entries and the real decode path builds
    /// everything else.
    ///
    /// Internal, not public: the app has no use for it, and VinodexCore is not
    /// in the habit of exporting seams that exist for tests (`@testable import`
    /// is what the suites already use).
    struct ResourceReader: Sendable {
        /// Must throw `CocoaError(.fileNoSuchFile)` for a resource that is not
        /// there — the same signal `Bundle.module` gives — so "missing" means
        /// the same thing to a fixture as it does to a build.
        let data: @Sendable (_ resource: String) throws -> Data

        init(data: @escaping @Sendable (_ resource: String) throws -> Data) {
            self.data = data
        }

        /// The app's own resources.
        static let bundled = ResourceReader { try WineDatabase.resourceData($0) }

        /// A reader over in-memory tables. Any name absent from the dictionary
        /// reads as missing, which is what a fixture almost always wants.
        static func fixture(_ files: [String: Data]) -> ResourceReader {
            ResourceReader { resource in
                guard let data = files[resource] else {
                    throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(resource).json"])
                }
                return data
            }
        }
    }

    private static func loadResource<T: Decodable>(
        _ resource: String,
        from reader: ResourceReader
    ) -> ResourceLoad<T> {
        do {
            return .loaded(try JSONDecoder().decode(T.self, from: reader.data(resource)))
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return .missing
        } catch {
            return .corrupt(error)
        }
    }

    private convenience init() {
        self.init(reading: .bundled)
    }

    /// The real load path, over whichever tables `reader` offers.
    convenience init(reading reader: ResourceReader) {
        var faults: [String] = []
        var notices: [String] = []

        // Entries: the one table with no useful degraded form, and the only one
        // whose failure may empty the database. A *per-entry* failure costs that
        // entry and names it (H2); a file-level failure costs the catalogue,
        // because there is nothing to fall back to. Recorded and continued
        // rather than trapped — crashing on launch makes this undiagnosable on
        // a device with no debugger attached.
        var entries: [WineEntry] = []
        do {
            let (decoded, failures) = try Self.decodeEntries(from: reader.data("entries"))
            entries = decoded
            faults.append(contentsOf: failures)
            // A well-formed empty array was the last silent blank app in the
            // loader: nothing to report, so every screen said NO DATA FOUND and
            // the alert never fired. An empty catalogue is a build problem
            // whatever shape it arrives in.
            if decoded.isEmpty, failures.isEmpty {
                faults.append("entries.json decoded to an empty array — the app has no catalogue; regenerate (npm run generate)")
            }
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            faults.append(
                "entries.json is not in the bundle — the app has no catalogue; regenerate (npm run generate) and rebuild"
            )
        } catch {
            faults.append("entries.json is not a decodable JSON array; no entries loaded — \(error)")
        }

        // Palette and icons sat inside the same `try` as entries, so either one
        // failing emptied the *whole* database: the catalogue disappeared
        // because a colour table did, and the alert said nothing about which
        // (M46). Each now costs only itself. A missing palette draws chips
        // unstyled, a missing manifest draws the placeholder glyph, and the
        // entries stay on screen either way — degraded is legible, blank is not.
        var palette = Self.emptyPalette
        let paletteLoad: ResourceLoad<Palette> = Self.loadResource("palette", from: reader)
        switch paletteLoad {
        case .loaded(let value):
            palette = value
        case .missing:
            faults.append("palette.json is not in the bundle — chips and tints fall back to the unstyled palette")
        case .corrupt(let error):
            faults.append("palette.json failed to decode; chips and tints fall back to the unstyled palette — \(error)")
        }

        var icons = Self.emptyIcons
        let iconLoad: ResourceLoad<IconManifest> = Self.loadResource("icons", from: reader)
        switch iconLoad {
        case .loaded(let value):
            icons = value
        case .missing:
            faults.append("icons.json is not in the bundle — every glyph falls back to the placeholder")
        case .corrupt(let error):
            faults.append("icons.json failed to decode; every glyph falls back to the placeholder — \(error)")
        }

        // Countries were the last fully silent decode failure in the loader:
        // `(try? …) ?? [:]` swallowed a malformed file with no entry in
        // `decodeErrors` at all, and the only symptom was every country page
        // quietly dropping to its derived summary sentence (M46). Missing stays
        // quiet — the fallback is the documented behaviour — but broken does not.
        var countries: [String: CountryInfo] = [:]
        let countryLoad: ResourceLoad<[String: CountryInfo]> = Self.loadResource("countries", from: reader)
        switch countryLoad {
        case .loaded(let value):
            countries = value
        case .missing:
            notices.append("countries.json is not bundled — country pages fall back to their derived summary")
        case .corrupt(let error):
            faults.append("countries.json failed to decode; country pages fall back to their derived summary — \(error)")
        }

        // Tiers: a *missing* manifest means "everything free" (a build with no
        // paywall), which is the only safe fallback that can't lock a build out
        // of its own data. But a *present-but-corrupt* manifest must not take
        // that same silent unlock — record it so it reaches decodeErrors and
        // the DEV panel instead of quietly opening the whole catalogue. (M1)
        var freeIDs: Set<String> = []
        let tierLoad: ResourceLoad<EntryTiers> = Self.loadResource("tiers", from: reader)
        switch tierLoad {
        case .loaded(let tiers):
            freeIDs = Set(tiers.free)
        case .missing:
            notices.append("tiers.json is not bundled — every entry is free")
        case .corrupt(let error):
            faults.append("tiers.json failed to decode; paywall left open — \(error)")
        }

        // The schema stamp, generated alongside the dataset. A *wrong* stamp is
        // a fault: the data and the app are from different generations and the
        // decode failures above are its symptoms. A *missing* stamp is not the
        // same condition in older clothes — it is the absence of evidence, and
        // treating it as a fault raised the launch alert on every start of every
        // build carrying pre-stamp data (M45). It is a notice; the test suite is
        // what refuses to ship data without one.
        let stampLoad: ResourceLoad<SchemaStamp> = Self.loadResource("schema", from: reader)
        switch stampLoad {
        case .loaded(let stamp) where stamp.schemaVersion == Self.expectedSchemaVersion:
            break
        case .loaded(let stamp):
            faults.append(
                "schema.json is generation \(stamp.schemaVersion); this build expects \(Self.expectedSchemaVersion) — regenerate (npm run generate)"
            )
        case .missing:
            notices.append(
                "schema.json is not bundled — this data predates the schema stamp; regenerate (npm run generate) to pin its generation"
            )
        case .corrupt(let error):
            faults.append("schema.json is present but unreadable — \(error)")
        }

        self.init(
            entries: entries,
            palette: palette,
            icons: icons,
            countries: countries,
            freeIDs: freeIDs,
            decodeErrors: faults,
            loadNotices: notices
        )
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

    /// The manifest a build with no `icons.json` runs on: every lookup misses
    /// and `DexIcon` draws its placeholder. Hoisted out of the old whole-load
    /// catch block by **M46**, which needed it as a per-table fallback rather
    /// than as part of one all-or-nothing empty database.
    private static let emptyIcons = IconManifest(
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
        flags: [:],
        flagSlugs: nil
    )

    private static let emptyPalette = Palette(
        countryChips: [:], classificationChips: [:], wineTypeChips: [:], rarityChips: [:],
        colorTypeChips: [:], styleClassChips: [:], flavorClassChips: [:], flavorSubclassChips: [:],
        namedChips: [:], styleTones: [:], climates: [:],
        regionClassificationIconColors: [:], flavorSubclassIconColors: [:],
        continentCountries: [:], styleColorTypes: [:]
    )

    // MARK: - Queries

    /// A listing, resolved against the load-time index (AUDIT M5).
    ///
    /// Prefer this to `entries.apply(_:)` anywhere the database is to hand:
    /// entries are walked in display order against haystacks folded at load,
    /// so a query costs one substring test per entry and no sort at all. The
    /// filter, when there is one, is evaluated last — it is the only clause
    /// that still normalises per call.
    public func entries(matching query: EntryQuery) -> [WineEntry] {
        let q = TextNormalize.label(query.search)
        var out: [WineEntry] = []
        for index in sortedEntries.indices {
            let entry = sortedEntries[index]
            guard query.categories.contains(entry.category) else { continue }
            if !q.isEmpty, !searchHaystacks[index].contains(q) { continue }
            if let filter = query.filter, !filter.matches(entry) { continue }
            out.append(entry)
        }
        return out
    }

    /// Every entry in the display order every listing uses, sorted once at
    /// load. Exposed so a listing narrowed by something that is not an
    /// `EntryQuery` — the chip filter — also needs no sort of its own.
    public var entriesInDisplayOrder: [WineEntry] { sortedEntries }

    public func entries(in category: EntryCategory) -> [WineEntry] {
        entries(matching: .category(category))
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
        entries(matching: .category(.regions, filter: filter(for: continent)))
    }

    /// Whether at least one region in the current selection has this country
    /// as its origin — what makes a continent's country row tappable.
    /// Case-insensitive: region origins and continent country names are
    /// both authored strings and don't always agree on case.
    ///
    /// A set lookup rather than a catalog scan — see `regionOriginLabels`
    /// (AUDIT **L14**).
    public func hasRegions(inCountry country: String) -> Bool {
        regionOriginLabels.contains(TextNormalize.label(country))
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
    /// That is precisely the set `hasRegions(inCountry:)` answers from, so it
    /// is counted rather than rebuilt (AUDIT **L14**).
    public var countryCount: Int { regionOriginLabels.count }

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
            375,  // 0.6.2 — outgoing total, appended by 0.6.4 batch 2
            405,  // 0.6.4–0.7.3b — outgoing total, appended by 0.7.3c when
                  // Brazil moved the catalog off the number it had stood at
                  // for eight releases.
            407,  // 0.7.3c — outgoing total, appended by 0.7.4's grape
                  // overhaul (+25 grapes, +6 regions). It stood for one
                  // release, which is why two milestones sit this close.
            438,  // 0.7.4–0.7.8 — outgoing total, appended by 0.7.9 (G) when
                  // sommbot's P1/P2 batch landed +6 grapes and +2 styles.
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
