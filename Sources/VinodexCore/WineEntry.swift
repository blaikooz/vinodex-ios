import Foundation

/// The category discriminator carried by every entry in `entries.json`.
///
/// The starter dataset emits four categories. `CONTINENTS` and `COUNTRY_GATE`
/// exist in the web app but are out of scope here — the globe filters regions
/// directly rather than drilling through continent and country screens.
public enum EntryCategory: String, Codable, Sendable, CaseIterable {
    case grapes = "GRAPES"
    case regions = "REGIONS"
    case styles = "STYLES"
    case flavors = "FLAVORS"

    /// Uppercase title shown in the LCD header for a category listing.
    public var listTitle: String {
        switch self {
        case .grapes: "VARIETIES"
        case .regions: "REGIONS"
        case .styles: "STYLES"
        case .flavors: "FLAVORS"
        }
    }
}

public enum RarityLabel: String, Codable, Sendable, CaseIterable {
    case common = "COMMON"
    case uncommon = "UNCOMMON"
    case rare = "RARE"
    case noble = "NOBLE"
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

// MARK: - Shared fields

/// Fields common to every variant. Kept as a struct rather than a protocol so
/// the variants stay plain `Codable` value types.
public struct EntryCommon: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let color: String
    public let tags: [String]
    public let icon: String?
    public let iconCallback: String?
    public let tileCallback: String?
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

    public var id: String { common.id }

    private enum CodingKeys: String, CodingKey {
        case grapeType, grapeStyle, grapeBodyClass, grapeCharacteristics
        case grapeAlternateNames, grapeNotableRegions, grapeCountryOfOrigin
        case rarity, wineType, tastingProfile, details
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

    public var common: EntryCommon {
        switch self {
        case .grape(let e): e.common
        case .region(let e): e.common
        case .style(let e): e.common
        case .flavor(let e): e.common
        }
    }

    public var category: EntryCategory {
        switch self {
        case .grape: .grapes
        case .region: .regions
        case .style: .styles
        case .flavor: .flavors
        }
    }

    public var id: String { common.id }
    public var name: String { common.name }
    public var entryDescription: String { common.description }
    public var color: String { common.color }
    public var tags: [String] { common.tags }

    // Convenience accessors mirroring the web app's shared `details` reads.

    public var origin: String? {
        switch self {
        case .grape(let e): e.details.origin
        case .region(let e): e.details.origin
        case .style(let e): e.details.origin
        case .flavor: nil
        }
    }

    public var classification: String? {
        switch self {
        case .grape(let e): e.details.classification
        case .region(let e): e.details.classification
        case .style(let e): e.details.classification
        case .flavor(let e): e.details.classification
        }
    }

    public var synonyms: [String] {
        switch self {
        case .grape(let e): e.details.synonyms
        case .region(let e): e.details.synonyms ?? []
        case .style, .flavor: []
        }
    }

    public var keyRegions: [String] {
        switch self {
        case .grape(let e): e.details.keyRegions
        case .style(let e): e.details.keyRegions
        case .region, .flavor: []
        }
    }

    public var notableGrapes: [String] {
        switch self {
        case .region(let e): e.details.notableGrapes
        case .style(let e): e.details.notableGrapes
        case .flavor(let e): e.details.notableGrapes
        case .grape: []
        }
    }

    public var tastingProfile: [TastingNote] {
        switch self {
        case .grape(let e): e.tastingProfile ?? []
        case .style(let e): e.tastingProfile ?? []
        case .flavor(let e): e.tastingProfile
        case .region: []
        }
    }

    public var rarity: RarityLabel? {
        switch self {
        case .grape(let e): e.rarity
        case .style(let e): e.rarity
        case .region, .flavor: nil
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
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .grape(let e): try e.encode(to: encoder)
        case .region(let e): try e.encode(to: encoder)
        case .style(let e): try e.encode(to: encoder)
        case .flavor(let e): try e.encode(to: encoder)
        }
        var c = encoder.container(keyedBy: DiscriminatorKey.self)
        try c.encode(category, forKey: .category)
    }
}
