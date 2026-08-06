import Foundation

/// The category discriminator carried by every entry in `entries.json`.
///
/// The starter dataset originally emitted four categories, with `CONTINENTS`
/// and `COUNTRY_GATE` left out — the globe filtered regions directly rather
/// than drilling through continent and country screens. `CONTINENTS` is back
/// in scope as of the continent info screen; `COUNTRY_GATE` (full per-country
/// screens, USA state drill-down, etc.) remains out of scope. Continent
/// "country" rows instead link straight to that country's regions.
public enum EntryCategory: String, Codable, Sendable, CaseIterable {
    case grapes = "GRAPES"
    case regions = "REGIONS"
    case styles = "STYLES"
    case flavors = "FLAVORS"
    case continents = "CONTINENTS"

    /// Uppercase title shown in the LCD header for a category listing.
    public var listTitle: String {
        switch self {
        case .grapes: "VARIETIES"
        case .regions: "REGIONS"
        case .styles: "STYLES"
        case .flavors: "FLAVORS"
        case .continents: "CONTINENTS"
        }
    }
}

/// The rarity ladder, lowest to highest — `allCases` order IS the ranking,
/// so anything sorting or filtering by tier reads it from here.
public enum RarityLabel: String, Codable, Sendable, CaseIterable {
    case common = "COMMON"
    case uncommon = "UNCOMMON"
    case rare = "RARE"
    case noble = "NOBLE"
    /// Above NOBLE (0.6.2, A1): the ultra-rares you only ever really find in
    /// one place — Châteauneuf's forgotten varieties, Verduno's Pelaverga.
    case godforsaken = "GODFORSAKEN"
}

public enum ClimateClass: String, Codable, Sendable, CaseIterable {
    case maritime, continental, cool, warm, mediterranean
}

public enum GrapeColor: String, Codable, Sendable {
    case red, white
}

/// A single tasting note with its glyph key and accent colour.
public struct TastingNote: Codable, Sendable, Hashable, Identifiable {
    public let note: String
    public let icon: String
    public let color: String

    public var id: String { note + icon }
}

/// 0–5 characteristic levels used by the grape stat bars.
///
/// These are **authored** values carried through from `grapeCards.ts`. They are
/// deliberately not re-derived from descriptive text — the Rork skeleton invented
/// them (`aromatics = tastingProfile.count + 2`), which is exactly the kind of
/// plausible-but-wrong output this port avoids.
public struct GrapeCharacteristics: Codable, Sendable, Hashable {
    public let tannin: Double
    public let acid: Double
    public let colorIntensity: Double
    public let aromatics: Double
    public let body: Double

    /// Ordered for display, matching the web app's stat rows.
    public var bars: [(label: String, value: Double)] {
        [
            ("BODY", body),
            ("ACID", acid),
            ("TANNIN", tannin),
            ("AROMATICS", aromatics),
            ("COLOR", colorIntensity),
        ]
    }
}

/// One end of a pedigree edge (0.7.5, E).
///
/// Mirrors `LineageRef` in `shared/types.ts`, where the two decisions behind the
/// shape are argued at length. The short version, because it is the thing to get
/// wrong here:
///
/// **An in-catalog link is an `id`; an off-catalog ancestor is a `name`.**
/// Exactly one is set. Every other cross-reference in this app resolves through
/// `TextNormalize` — `keyRegions`, `notableGrapes`, `wineType` — and the grape
/// *name* index is precisely where that breaks down: "Espadeiro" answers to five
/// VIVC prime names and "Nerello" to seven, so a pedigree resolved by name would
/// wire a Galician vine to a Portuguese one. Ids are stable by house rule.
///
/// A named ancestor is not a broken link. Gouais Blanc is the mother of ten
/// grapes in this catalog and will never be a collectible entry; the renderer
/// draws it as a **terminal** node — present, legible, not tappable — rather
/// than dropping the most-pointed-at variety in the dataset. See
/// `GrapeLineageIndex`.
public struct LineageRef: Codable, Sendable, Hashable {
    /// Seed vs pollen parent, where the cross direction is established.
    public enum Role: String, Codable, Sendable {
        case mother, father
    }

    /// Catalog grape id. Mutually exclusive with `name`.
    public let id: String?
    /// Display name of a variety the catalog does not carry.
    public let name: String?
    public let role: Role?
    /// The relationship is real; its direction or one party's identity is not.
    public let contested: Bool

    private enum CodingKeys: String, CodingKey {
        case id, name, role, contested
    }

    public init(id: String? = nil, name: String? = nil, role: Role? = nil, contested: Bool = false) {
        self.id = id
        self.name = name
        self.role = role
        self.contested = contested
    }

    /// Hand-written for two reasons, both about what a bad value should cost.
    ///
    /// `contested` defaults to `false` rather than being optional: absent means
    /// settled, and an optional `Bool` would make every reader write
    /// `?? false` and one of them eventually forget.
    ///
    /// **`role` is decoded leniently, and deliberately.** Entries decode
    /// element-wise (0.6.3), so a throw here costs the whole grape — its
    /// description, its stats, its art — for the sake of one word of garnish
    /// that only ever decorates a tree node. An unrecognised role is worth
    /// dropping; it is not worth a missing Cabernet Sauvignon. Everything else
    /// on this type is load-bearing and still throws.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        role = (try? c.decodeIfPresent(Role.self, forKey: .role)) ?? nil
        contested = try c.decodeIfPresent(Bool.self, forKey: .contested) ?? false
    }
}

/// A grape's marker-confirmed relatives, as authored (0.7.5, E).
///
/// **Only the child-facing direction is stored.** Offspring, mutations and
/// siblings are derived by one reverse pass — see `GrapeLineageIndex`. Storing
/// both directions would mean two places to be wrong and an offspring list that
/// rots every time a grape is added.
///
/// Nothing in here is asserted beyond what markers confirm. Where the markers
/// establish the relationship but not its direction, the ref carries
/// `contested` and `note` says why, rather than the entry quietly picking a
/// side.
public struct GrapeLineage: Codable, Sendable, Hashable {
    /// At most two. An unidentified second parent is absent, never a placeholder.
    public let parents: [LineageRef]
    /// A somatic mutation of that variety — same genotype, different skin.
    public let mutationOf: LineageRef?
    /// A first-degree relative whose direction is unresolved, or a half-sibling
    /// whose shared parent the catalog cannot name.
    public let related: [LineageRef]
    /// One sentence for the tree's footnote wherever the above is contested.
    public let note: String?

    /// **"Nobody knows" as opposed to "nobody has written it down yet"**
    /// (0.7.9, C2).
    ///
    /// Absence of `parents` is ambiguous today and the ambiguity is the whole
    /// problem: 116 of 177 grapes carry no lineage block, and the app cannot
    /// tell the ones whose parentage is genuinely undetermined from the ones a
    /// data batch has not reached. Silence is the honest rendering of the
    /// second and a *wrong* rendering of the first — Zinfandel's parents are not
    /// pending, they are unresolved, and saying nothing implies otherwise.
    ///
    /// **This is the contract C1 was going to have to invent, settled in the UI
    /// first, which is why the sequencing was inverted.** `true` is an authored
    /// claim: research has been done and no parent pair is established. It is
    /// **not** a default, and `shared/` emits it nowhere yet — sommbot's C1 pass
    /// is what fills it in. Until then this decodes to `false` everywhere and
    /// nothing renders, which is exactly the behaviour that shipped in 0.7.5.
    ///
    /// It deliberately does **not** make a grape "connected": a tree whose only
    /// content is a statement that there is no tree is not worth a screen. See
    /// `isEmpty` below, and `GrapeLineageIndex.parentageIsUnknown`, which is
    /// answerable for a grape with no lineage at all.
    public let parentageUnknown: Bool

    private enum CodingKeys: String, CodingKey {
        case parents, mutationOf, related, note, parentageUnknown
    }

    public init(
        parents: [LineageRef] = [],
        mutationOf: LineageRef? = nil,
        related: [LineageRef] = [],
        note: String? = nil,
        parentageUnknown: Bool = false
    ) {
        self.parents = parents
        self.mutationOf = mutationOf
        self.related = related
        self.note = note
        self.parentageUnknown = parentageUnknown
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        parents = try c.decodeIfPresent([LineageRef].self, forKey: .parents) ?? []
        mutationOf = try c.decodeIfPresent(LineageRef.self, forKey: .mutationOf)
        related = try c.decodeIfPresent([LineageRef].self, forKey: .related) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note)
        // `decodeIfPresent` and not `decode`, on the rule the whole file
        // follows: every entry in the catalog predates this key, and a
        // synthesised decoder would treat its absence as a failure and cost the
        // grape. Defaulted to `false` rather than made optional so no reader has
        // to write `?? false` and eventually forget to.
        parentageUnknown = try c.decodeIfPresent(Bool.self, forKey: .parentageUnknown) ?? false
    }

    /// Whether this block says anything the *tree* can draw. A grape can carry
    /// the key and still have no edges if every ref were stripped; treat that as
    /// absent.
    ///
    /// `parentageUnknown` is deliberately not counted. It is an annotation on a
    /// tree rather than an edge in one, and counting it would open the pedigree
    /// screen — connectors, tiers, half-sibling groups — on a grape whose only
    /// content is a sentence saying there is nothing to show.
    public var isEmpty: Bool {
        parents.isEmpty && mutationOf == nil && related.isEmpty
    }
}

// MARK: - Shared fields

/// Fields common to every variant. Kept as a struct rather than a protocol so
/// the variants stay plain `Codable` value types.
public struct EntryCommon: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let color: String
    public let tags: [String]
    // `icon`, `iconCallback` and `tileCallback` were carried from the web schema
    // but never read (the icon system resolves through `IconManifest`). Dropped
    // from both the generator output and here to shrink the launch-time parse
    // (audit M4).
}

// MARK: - Variants

public struct GrapeDetails: Codable, Sendable, Hashable {
    public let origin: String
    public let synonyms: [String]
    public let keyRegions: [String]
    public let body: String
    public let acidity: String?
    public let tannin: String?
    public let classification: String?
}

public struct GrapeEntry: Codable, Sendable, Hashable, Identifiable {
    public let common: EntryCommon
    public let grapeType: GrapeColor
    public let grapeStyle: String
    public let grapeBodyClass: String
    public let grapeCharacteristics: GrapeCharacteristics
    public let grapeAlternateNames: [String]
    public let grapeNotableRegions: [String]
    public let grapeCountryOfOrigin: String
    public let rarity: RarityLabel
    public let wineType: String?
    public let tastingProfile: [TastingNote]?
    public let details: GrapeDetails
    /// Authored genetics (0.7.5, E), absent on 114 of the 171 grapes.
    ///
    /// Top level rather than inside `details` because that is where the
    /// generator can see it: `grapeCard` is stripped on the way out and
    /// `details` is assembled field by field in `constants.ts`, so a field that
    /// travelled by either route would silently never arrive.
    public let lineage: GrapeLineage?

    public var id: String { common.id }

    private enum CodingKeys: String, CodingKey {
        case grapeType, grapeStyle, grapeBodyClass, grapeCharacteristics
        case grapeAlternateNames, grapeNotableRegions, grapeCountryOfOrigin
        case rarity, wineType, tastingProfile, details, lineage
    }

    public init(from decoder: any Decoder) throws {
        common = try EntryCommon(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grapeType = try c.decode(GrapeColor.self, forKey: .grapeType)
        grapeStyle = try c.decode(String.self, forKey: .grapeStyle)
        grapeBodyClass = try c.decode(String.self, forKey: .grapeBodyClass)
        grapeCharacteristics = try c.decode(GrapeCharacteristics.self, forKey: .grapeCharacteristics)
        grapeAlternateNames = try c.decodeIfPresent([String].self, forKey: .grapeAlternateNames) ?? []
        grapeNotableRegions = try c.decodeIfPresent([String].self, forKey: .grapeNotableRegions) ?? []
        grapeCountryOfOrigin = try c.decode(String.self, forKey: .grapeCountryOfOrigin)
        rarity = try c.decode(RarityLabel.self, forKey: .rarity)
        wineType = try c.decodeIfPresent(String.self, forKey: .wineType)
        tastingProfile = try c.decodeIfPresent([TastingNote].self, forKey: .tastingProfile)
        details = try c.decode(GrapeDetails.self, forKey: .details)
        lineage = try c.decodeIfPresent(GrapeLineage.self, forKey: .lineage)
    }

    public func encode(to encoder: any Encoder) throws {
        try common.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(grapeType, forKey: .grapeType)
        try c.encode(grapeStyle, forKey: .grapeStyle)
        try c.encode(grapeBodyClass, forKey: .grapeBodyClass)
        try c.encode(grapeCharacteristics, forKey: .grapeCharacteristics)
        try c.encode(grapeAlternateNames, forKey: .grapeAlternateNames)
        try c.encode(grapeNotableRegions, forKey: .grapeNotableRegions)
        try c.encode(grapeCountryOfOrigin, forKey: .grapeCountryOfOrigin)
        try c.encode(rarity, forKey: .rarity)
        try c.encodeIfPresent(wineType, forKey: .wineType)
        try c.encodeIfPresent(tastingProfile, forKey: .tastingProfile)
        try c.encode(details, forKey: .details)
        try c.encodeIfPresent(lineage, forKey: .lineage)
    }
}

public struct RegionDetails: Codable, Sendable, Hashable {
    public let origin: String
    public let state: String?
    public let notableGrapes: [String]
    public let classification: String
    public let appellations: [String]?
    public let soilType: String?
    public let synonyms: [String]?
    /// Where the region sits on its outline art (0.6.x), as fractions of the
    /// PNG canvas. Authored geography, replacing the hash walk that put Alto
    /// Adige in Calabria; renderers snap it to the nearest land pixel, and a
    /// region without one falls back to the seeded walk.
    public let mapPosition: MapPosition?
}

/// A fractional point on an outline PNG — x from the left, y from the top.
public struct MapPosition: Codable, Sendable, Hashable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct RegionEntry: Codable, Sendable, Hashable, Identifiable {
    public let common: EntryCommon
    public let climate: ClimateClass?
    public let climateDescription: String?
    public let details: RegionDetails

    public var id: String { common.id }

    private enum CodingKeys: String, CodingKey {
        case climate, climateDescription, details
    }

    public init(from decoder: any Decoder) throws {
        common = try EntryCommon(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        climate = try c.decodeIfPresent(ClimateClass.self, forKey: .climate)
        climateDescription = try c.decodeIfPresent(String.self, forKey: .climateDescription)
        details = try c.decode(RegionDetails.self, forKey: .details)
    }

    public func encode(to encoder: any Encoder) throws {
        try common.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(climate, forKey: .climate)
        try c.encodeIfPresent(climateDescription, forKey: .climateDescription)
        try c.encode(details, forKey: .details)
    }
}

public struct StyleDetails: Codable, Sendable, Hashable {
    public let origin: String
    public let body: String?
    public let tannin: String?
    public let acidity: String?
    public let keyRegions: [String]
    public let notableGrapes: [String]
    public let classification: String
}

public struct StyleEntry: Codable, Sendable, Hashable, Identifiable {
    public let common: EntryCommon
    public let rarity: RarityLabel?
    public let tastingProfile: [TastingNote]?
    public let details: StyleDetails

    public var id: String { common.id }

    private enum CodingKeys: String, CodingKey {
        case rarity, tastingProfile, details
    }

    public init(from decoder: any Decoder) throws {
        common = try EntryCommon(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rarity = try c.decodeIfPresent(RarityLabel.self, forKey: .rarity)
        tastingProfile = try c.decodeIfPresent([TastingNote].self, forKey: .tastingProfile)
        details = try c.decode(StyleDetails.self, forKey: .details)
    }

    public func encode(to encoder: any Encoder) throws {
        try common.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(rarity, forKey: .rarity)
        try c.encodeIfPresent(tastingProfile, forKey: .tastingProfile)
        try c.encode(details, forKey: .details)
    }
}

public struct FlavorDetails: Codable, Sendable, Hashable {
    public let classification: String
    public let subclass: String
    public let notableGrapes: [String]
}

public struct FlavorEntry: Codable, Sendable, Hashable, Identifiable {
    public let common: EntryCommon
    public let tastingProfile: [TastingNote]
    public let details: FlavorDetails

    public var id: String { common.id }

    private enum CodingKeys: String, CodingKey {
        case tastingProfile, details
    }

    public init(from decoder: any Decoder) throws {
        common = try EntryCommon(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tastingProfile = try c.decodeIfPresent([TastingNote].self, forKey: .tastingProfile) ?? []
        details = try c.decode(FlavorDetails.self, forKey: .details)
    }

    public func encode(to encoder: any Encoder) throws {
        try common.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tastingProfile, forKey: .tastingProfile)
        try c.encode(details, forKey: .details)
    }
}

/// `keyRegions` holds **country** names for a continent, despite the name —
/// carried over verbatim from `data/continents.ts`.
public struct ContinentDetails: Codable, Sendable, Hashable {
    public let keyRegions: [String]
}

public struct ContinentEntry: Codable, Sendable, Hashable, Identifiable {
    public let common: EntryCommon
    public let details: ContinentDetails

    public var id: String { common.id }

    private enum CodingKeys: String, CodingKey {
        case details
    }

    public init(from decoder: any Decoder) throws {
        common = try EntryCommon(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        details = try c.decode(ContinentDetails.self, forKey: .details)
    }

    public func encode(to encoder: any Encoder) throws {
        try common.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(details, forKey: .details)
    }
}

// MARK: - The union

/// Swift equivalent of the web app's discriminated `WineEntry` union.
///
/// `if case .grape(let g)` replaces the TypeScript `isGrapeEntry(e)` guards 1:1.
/// Modelling this as an enum rather than a flat struct with optionals is
/// deliberate — the web app moved to the union in commit `73fe0d5`, and the
/// Rork skeleton's flat shape predates that.
public enum WineEntry: Sendable, Hashable, Identifiable {
    case grape(GrapeEntry)
    case region(RegionEntry)
    case style(StyleEntry)
    case flavor(FlavorEntry)
    case continent(ContinentEntry)

    public var common: EntryCommon {
        switch self {
        case .grape(let e): e.common
        case .region(let e): e.common
        case .style(let e): e.common
        case .flavor(let e): e.common
        case .continent(let e): e.common
        }
    }

    public var category: EntryCategory {
        switch self {
        case .grape: .grapes
        case .region: .regions
        case .style: .styles
        case .flavor: .flavors
        case .continent: .continents
        }
    }

    public var id: String { common.id }
    public var name: String { common.name }
    public var entryDescription: String { common.description }
    public var color: String { common.color }
    public var tags: [String] { common.tags }

    /// Whether the tried and want-to-try shelves apply: things you can drink
    /// a glass of. Regions, flavours and continents are reference, not
    /// tastings — the same grapes-and-styles pair that carries a rarity.
    public var isTastable: Bool {
        category == .grapes || category == .styles
    }

    // Convenience accessors mirroring the web app's shared `details` reads.

    public var origin: String? {
        switch self {
        case .grape(let e): e.details.origin
        case .region(let e): e.details.origin
        case .style(let e): e.details.origin
        case .flavor, .continent: nil
        }
    }

    public var classification: String? {
        switch self {
        case .grape(let e): e.details.classification
        case .region(let e): e.details.classification
        case .style(let e): e.details.classification
        case .flavor(let e): e.details.classification
        case .continent: nil
        }
    }

    public var synonyms: [String] {
        switch self {
        case .grape(let e): e.details.synonyms
        case .region(let e): e.details.synonyms ?? []
        case .style, .flavor, .continent: []
        }
    }

    /// For continents this is (per the web app) actually a list of **country**
    /// names, not regions — see `ContinentDetails`.
    public var keyRegions: [String] {
        switch self {
        case .grape(let e): e.details.keyRegions
        case .style(let e): e.details.keyRegions
        case .continent(let e): e.details.keyRegions
        case .region, .flavor: []
        }
    }

    public var notableGrapes: [String] {
        switch self {
        case .region(let e): e.details.notableGrapes
        case .style(let e): e.details.notableGrapes
        case .flavor(let e): e.details.notableGrapes
        case .grape, .continent: []
        }
    }

    public var tastingProfile: [TastingNote] {
        switch self {
        case .grape(let e): e.tastingProfile ?? []
        case .style(let e): e.tastingProfile ?? []
        case .flavor(let e): e.tastingProfile
        case .region, .continent: []
        }
    }

    public var rarity: RarityLabel? {
        switch self {
        case .grape(let e): e.rarity
        case .style(let e): e.rarity
        case .region, .flavor, .continent: nil
        }
    }

    public var climate: ClimateClass? {
        if case .region(let e) = self { return e.climate }
        return nil
    }
}

// MARK: - Codable

extension WineEntry: Codable {
    private enum DiscriminatorKey: String, CodingKey {
        case category
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: DiscriminatorKey.self)
        let category = try c.decode(EntryCategory.self, forKey: .category)
        switch category {
        case .grapes: self = .grape(try GrapeEntry(from: decoder))
        case .regions: self = .region(try RegionEntry(from: decoder))
        case .styles: self = .style(try StyleEntry(from: decoder))
        case .flavors: self = .flavor(try FlavorEntry(from: decoder))
        case .continents: self = .continent(try ContinentEntry(from: decoder))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .grape(let e): try e.encode(to: encoder)
        case .region(let e): try e.encode(to: encoder)
        case .style(let e): try e.encode(to: encoder)
        case .flavor(let e): try e.encode(to: encoder)
        case .continent(let e): try e.encode(to: encoder)
        }
        var c = encoder.container(keyedBy: DiscriminatorKey.self)
        try c.encode(category, forKey: .category)
    }
}
