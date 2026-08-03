import Foundation

/// One dimension the chip filter can narrow on.
///
/// Only facets the shipped data actually carries, and only ones with a small
/// closed set of values — a chip row is unusable past a dozen options, which is
/// why country and region are search-bar territory and not here.
public enum ChipFacet: String, CaseIterable, Codable, Sendable, Identifiable {
    case category
    case color
    case body
    case rarity
    case climate
    /// Countries joined in 0.6.x — the closed-set rule above bent once the
    /// catalog boost made "which country" the question the tool was most
    /// often opened to answer. The row is long, but it wraps.
    case country

    public var id: String { rawValue }

    /// Row heading.
    public var title: String {
        switch self {
        case .category: "TYPE"
        case .color: "COLOUR"
        case .body: "BODY"
        case .rarity: "RARITY"
        case .climate: "CLIMATE"
        case .country: "COUNTRY"
        }
    }

    /// One line saying what the row does, and — where it matters — what it
    /// excludes. COLOUR and BODY are grape-only, and a user who taps RED and
    /// watches the regions vanish deserves to have been told first.
    public var note: String {
        switch self {
        case .category: "Which tables to search."
        case .color: "Grapes only — everything else drops out."
        case .body: "Grapes only."
        case .rarity: "Grapes and styles carry a rarity."
        case .climate: "Regions only."
        case .country: "Anything with an origin — flavors drop out."
        }
    }
}

/// One tappable chip: a facet and one of its values.
public struct ChipOption: Sendable, Hashable, Identifiable {
    public let facet: ChipFacet
    /// The stored form — an enum's raw value.
    public let value: String
    /// The form shown on the chip.
    public let label: String

    public var id: String { facet.rawValue + ":" + value }

    public init(facet: ChipFacet, value: String, label: String) {
        self.facet = facet
        self.value = value
        self.label = label
    }
}

/// A set of chip selections, and the rule for what survives them.
///
/// **Within a facet, OR. Across facets, AND.** Tapping RED and WHITE means
/// "either colour"; tapping RED and NOBLE means "red *and* noble". That is what
/// a row of chips reads as, and getting it the other way round produces a tool
/// that narrows when you expect it to widen.
///
/// A facet with nothing selected is not a constraint. An entry that *cannot*
/// carry a selected facet fails it — pick a colour and regions drop out, because
/// no region has one. That is the honest reading of an AND across facets, and
/// the live count on the screen is what makes the consequence visible in the
/// same second you cause it. `ChipFacet.note` warns first.
///
/// Selections are stored as raw strings keyed by facet rather than as five typed
/// sets. One dictionary is one thing to encode for `ScreenStateStore`, one thing
/// to clear, and one `toggle` for the UI to call — five typed sets meant five of
/// each, and the screen would have had to know which was which.
public struct ChipFilter: Codable, Sendable, Hashable {
    private var selected: [String: Set<String>]

    public init() {
        selected = [:]
    }

    // MARK: Selection

    public func isOn(_ option: ChipOption) -> Bool {
        selected[option.facet.rawValue]?.contains(option.value) ?? false
    }

    public mutating func toggle(_ option: ChipOption) {
        var set = selected[option.facet.rawValue] ?? []
        if set.contains(option.value) {
            set.remove(option.value)
        } else {
            set.insert(option.value)
        }
        // An emptied facet is removed rather than left as an empty set, so
        // `isEmpty` means what it says and the encoded form stays small.
        if set.isEmpty {
            selected.removeValue(forKey: option.facet.rawValue)
        } else {
            selected[option.facet.rawValue] = set
        }
    }

    /// A copy with one chip flipped — for costing a chip before it is tapped.
    public func toggling(_ option: ChipOption) -> ChipFilter {
        var copy = self
        copy.toggle(option)
        return copy
    }

    public var isEmpty: Bool { selected.isEmpty }

    /// How many chips are lit, for the RESET button's badge.
    public var count: Int { selected.values.reduce(0) { $0 + $1.count } }

    public mutating func clear() { selected.removeAll() }

    // MARK: Matching

    public func matches(_ entry: WineEntry) -> Bool {
        for facet in ChipFacet.allCases {
            guard let chosen = selected[facet.rawValue], !chosen.isEmpty else { continue }
            guard Self.entry(entry, satisfies: facet, anyOf: chosen) else { return false }
        }
        return true
    }

    private static func entry(
        _ entry: WineEntry,
        satisfies facet: ChipFacet,
        anyOf chosen: Set<String>
    ) -> Bool {
        switch facet {
        case .category:
            return chosen.contains(entry.category.rawValue)

        case .color:
            guard case .grape(let g) = entry else { return false }
            return chosen.contains(g.grapeType.rawValue)

        case .body:
            // Compared through `TextNormalize` rather than by raw equality: the
            // dataset writes "Light"/"Medium"/"Full" as free text on the grape,
            // and matching it case-sensitively is the sort of thing that works
            // until one row is regenerated with different capitalisation.
            guard case .grape(let g) = entry else { return false }
            let actual = TextNormalize.label(g.grapeBodyClass)
            return chosen.contains { TextNormalize.label($0) == actual }

        case .rarity:
            guard let rarity = entry.rarity else { return false }
            return chosen.contains(rarity.rawValue)

        case .climate:
            guard let climate = entry.climate else { return false }
            return chosen.contains(climate.rawValue)

        case .country:
            // Normalised like BODY: origins are hand-authored strings.
            guard let origin = entry.origin, !origin.isEmpty else { return false }
            let actual = TextNormalize.label(origin)
            return chosen.contains { TextNormalize.label($0) == actual }
        }
    }

    // MARK: The chips themselves

    /// Every option a facet offers, in the order the row draws them.
    ///
    /// Driven off the enums' own `allCases` so a value added to the data model
    /// appears here without anyone remembering to add a chip.
    /// The category facet's one pseudo-value (0.6.2, B3). Countries are not
    /// entries — their rows are synthesised by the screen — but they are a
    /// thing worth filtering to, so the TYPE row offers them alongside the
    /// real categories. `matches` never sees it: no entry can satisfy it.
    public static let countriesCategoryValue = "COUNTRIES"

    /// Whether the countries pseudo-category is lit.
    public var includesCountries: Bool {
        selected[ChipFacet.category.rawValue]?.contains(Self.countriesCategoryValue) ?? false
    }

    /// The chips a facet offers.
    ///
    /// `countries` is a parameter rather than a `WineDatabase.shared` read
    /// because this is Core: the singleton reaches the *bundled* database, so
    /// a unit test asking for the COUNTRY chips was quietly asserting against
    /// shipping data instead of its own fixture. Callers holding a database
    /// should use `WineDatabase.chipOptions(for:)` below, which fills this in
    /// from themselves. (AUDIT **M27**)
    public static func options(for facet: ChipFacet, countries: [String]) -> [ChipOption] {
        switch facet {
        case .category:
            return EntryCategory.allCases.map {
                ChipOption(facet: facet, value: $0.rawValue, label: $0.rawValue)
            } + [ChipOption(facet: facet, value: countriesCategoryValue, label: countriesCategoryValue)]
        case .color:
            return [GrapeColor.red, .white].map {
                ChipOption(facet: facet, value: $0.rawValue, label: $0.rawValue.uppercased())
            }
        case .body:
            return GrapeBody.allCases.map {
                ChipOption(facet: facet, value: $0.rawValue, label: $0.label)
            }
        case .rarity:
            return RarityLabel.allCases.map {
                ChipOption(facet: facet, value: $0.rawValue, label: $0.rawValue)
            }
        case .climate:
            return ClimateClass.allCases.map {
                ChipOption(facet: facet, value: $0.rawValue, label: $0.rawValue.uppercased())
            }
        case .country:
            // The countries that actually have pages — same list search uses.
            return countries.map {
                ChipOption(facet: facet, value: $0, label: $0.uppercased())
            }
        }
    }
}

public extension WineDatabase {
    /// This database's chips for a facet. The one call shape the app should
    /// use: it is the database in hand that decides which countries have pages,
    /// not whichever one the process happens to have loaded.
    func chipOptions(for facet: ChipFacet) -> [ChipOption] {
        ChipFilter.options(for: facet, countries: searchableCountries)
    }

    /// Every chip across every facet, flattened.
    var allChipOptions: [ChipOption] {
        ChipFacet.allCases.flatMap { chipOptions(for: $0) }
    }

    /// Everything surviving a chip selection, in the same name order every other
    /// listing uses.
    /// Filtering the pre-sorted list rather than sorting the survivors: the
    /// order is already right, and this ran per body pass (AUDIT M5).
    func entries(matching filter: ChipFilter) -> [WineEntry] {
        entriesInDisplayOrder.filter { filter.matches($0) }
    }

    /// What the result count *would be* if this chip were tapped.
    ///
    /// Shown on the chip itself, which is the difference between a filter you
    /// have to probe by trial and one you can read. 284 entries against a couple
    /// of dozen chips is a few thousand comparisons — cheap enough to do on
    /// every render rather than caching and having to invalidate it.
    func count(withChip option: ChipOption, added filter: ChipFilter) -> Int {
        let candidate = filter.toggling(option)
        return entries.reduce(0) { $0 + (candidate.matches($1) ? 1 : 0) }
    }
}
