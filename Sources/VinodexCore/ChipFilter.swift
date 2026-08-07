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
    /// **What kind of wine a grape makes** (0.8.8, C1): FULL-BODY RED,
    /// AROMATIC WHITE, MADEIRA — the catalog's own `grapeStyle` vocabulary, ten
    /// values, grapes only.
    ///
    /// **Separate from `.body`, and this is the facet's whole justification.**
    /// The obvious reading is that this row is BODY crossed with COLOUR and so
    /// says nothing the two existing rows cannot say together. Measured over the
    /// shipped catalog that is false on both halves. Four of the ten values —
    /// AROMATIC WHITE, SWEET WHITE, MADEIRA, SPARKLING RED — are not compounds
    /// at all and name no body. And the six that look like compounds do not
    /// agree with the compound: `grapeBodyClass` and `grapeStyle` are separately
    /// authored fields, so BODY=Full ∧ COLOUR=white selects 12 grapes where
    /// `grapeStyle == "Full-Body White"` selects 7, the five in the gap being
    /// the full-bodied whites the catalog files as AROMATIC WHITE or MADEIRA.
    /// The same gap opens on three of the other five. A compound chip would have
    /// been a chip that lights and shows a different list from the one it claims.
    ///
    /// Titled STYLE rather than TYPE, and this is the item's actual ask: the
    /// grape detail page's second tile is labelled TYPE and its destination said
    /// STYLE SCAN, which is two words for one thing and the wrong one on the
    /// bigger surface. The row is what the marquee no longer has to be.
    case grapeStyle
    case rarity
    case climate
    /// Countries joined in 0.6.x — the closed-set rule above bent once the
    /// catalog boost made "which country" the question the tool was most
    /// often opened to answer. The row is long, but it wraps.
    case country
    /// **How a style is defined** (0.7.0, H2): by ORIGIN, METHOD, TYPE, BLEND
    /// or as a plain STYLE. Five values, styles only.
    ///
    /// The inferred class rather than the raw `classification` string, so this
    /// agrees with the CLASS tile on a style's own detail page and with the
    /// STYLE CLASS chips the palette already ships — see
    /// `EntryDisplay.styleClass(name:classification:)`, and the note on the
    /// detail tile for why the raw field is the wrong thing to filter on.
    case styleClass
    /// **What colour a style is in the glass** (0.8.1, D): RED, WHITE, ROSE,
    /// ORANGE or DUAL.
    ///
    /// Separate from `.color` rather than folded into it. That facet is the
    /// grape's own RED/WHITE, a two-value property of the fruit; this is a
    /// five-value property of the finished wine, and a Prosecco is not a white
    /// *grape*. One row offering both vocabularies would have been the only
    /// chip row in the app whose meaning changed with what else you had
    /// selected.
    ///
    /// Derived through `EntryDisplay.colorType`, which until this batch was
    /// missing the whole of `entryUtils.ts`'s override table — sixteen of
    /// thirty-three styles answered wrong. This row is why B had to land first:
    /// a filter is a much louder way to be wrong than a chip is.
    case styleColor
    /// **A flavour's taste family** (0.7.0, H3): the five basic tastes.
    case flavorClass
    /// **A flavour's family** (0.7.0, H3): BERRY, SMOKY, STONE FRUIT and the
    /// rest. Twenty-two values — long like COUNTRY, and it wraps like COUNTRY.
    case flavorSubclass
    /// **Your three shelves** (0.8.91, B1): SAVED, WANTED, TRIED.
    ///
    /// **The one facet that is not a property of the catalog**, and the reason
    /// `matches` grew a parameter. Every other facet can be answered from the
    /// `WineEntry` alone; this one is a fact about the *player*, held in
    /// `BookmarkStore` and therefore in `UserDefaults` — so a screen that wants
    /// it has to hand the membership in. See `ShelfMembership`.
    ///
    /// §B1 asks for Saved and Wanted as "new user states". They are not new:
    /// `Shelf` has had all three since the user panel shipped and
    /// `EntryDetailScreen` has had all three setters since. What was missing was
    /// the *filter*, which is what this is — no new storage, no new key, and
    /// nothing about tried that the v9.0 discovery system did not already own.
    /// Building a second store for a shelf that exists is how two answers to
    /// "have I tried this" come to disagree.
    case shelf

    public var id: String { rawValue }

    /// Whether this facet asks about the player rather than about the catalog.
    ///
    /// Exists so `ChipFacetTests.facetsAreLive` can say what it means: every
    /// other row must offer only chips some entry can satisfy, because a chip
    /// that always empties the listing is a broken control. A shelf chip on a
    /// fresh device matches nothing *correctly* — that is the honest answer to
    /// "show me what I have tried" before you have tried anything.
    public var isUserState: Bool { self == .shelf }

    /// Row heading.
    public var title: String {
        switch self {
        case .category: "TYPE"
        case .color: "COLOUR"
        case .body: "BODY"
        case .grapeStyle: "STYLE"
        case .rarity: "RARITY"
        case .climate: "CLIMATE"
        case .country: "COUNTRY"
        case .styleClass: "STYLE CLASS"
        case .styleColor: "COLOUR"
        case .flavorClass: "TASTE"
        case .flavorSubclass: "FAMILY"
        case .shelf: "YOURS"
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
        case .grapeStyle: "Grapes only — the wine the grape makes."
        case .rarity: "Grapes and styles carry a rarity."
        case .climate: "Regions only."
        case .country: "Anything with an origin — flavors drop out."
        case .styleClass: "Styles only — what defines the style."
        case .styleColor: "Styles only — the colour in the glass."
        case .flavorClass: "Flavors only — the basic taste."
        case .flavorSubclass: "Flavors only — the flavour family."
        case .shelf: "What you have saved, wanted or tried."
        }
    }
}

public extension Shelf {
    /// The word the chip wears (0.8.91, B1).
    ///
    /// `wantToTry`'s raw value is a storage key and may never change — see
    /// `storageKey` — so the label is a separate member, exactly as
    /// `SettingsSection.displayName` is separate from its persisted raw value.
    var chipLabel: String {
        switch self {
        case .saved: "SAVED"
        case .wantToTry: "WANTED"
        case .tried: "TRIED"
        }
    }
}

/// Which entries sit on which shelf, as a value (0.8.91, B1).
///
/// **The whole reason this is a snapshot rather than a reference to the store.**
/// `ChipFilter.matches` is pure, Foundation-only and not `@MainActor`;
/// `BookmarkStore` is an observable singleton and is all three of the opposite.
/// Reaching into it from the matcher would have made every filtering call site
/// main-actor-bound and every test of the filter dependent on a real
/// `UserDefaults` suite. A snapshot is a `Hashable` value, which is also what
/// lets a SwiftUI screen key a recompute on it.
///
/// Empty is a legitimate value and means what it says: nothing is on any shelf.
/// A caller with no store — the counting helper below, a test — gets the honest
/// answer for a device where nothing has been marked, rather than a crash or a
/// silently-inverted filter.
public struct ShelfMembership: Sendable, Hashable {
    private let ids: [Shelf: Set<String>]

    /// Nothing on any shelf.
    public static let empty = ShelfMembership(ids: [:])

    public init(ids: [Shelf: Set<String>]) {
        self.ids = ids
    }

    public func contains(_ id: String, on shelf: Shelf) -> Bool {
        ids[shelf]?.contains(id) ?? false
    }

    /// Whether an entry is on any shelf at all — what the tried border and the
    /// shelf pip on a tile ask.
    public func shelves(for id: String) -> Set<Shelf> {
        Set(Shelf.allCases.filter { contains(id, on: $0) })
    }

    public var isEmpty: Bool { ids.values.allSatisfy(\.isEmpty) }
}

public extension BookmarkStore {
    /// This store's three shelves as a value the filter can hold (0.8.91, B1).
    ///
    /// Read once per recompute rather than per entry: `ids(on:)` decodes out of
    /// `UserDefaults` and the listing screens ask about several hundred entries
    /// a pass.
    var membership: ShelfMembership {
        ShelfMembership(
            ids: Dictionary(
                uniqueKeysWithValues: Shelf.allCases.map { ($0, Set(ids(on: $0))) }
            )
        )
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

    /// Whether any lit chip needs the player's shelves to be answered (0.8.91,
    /// B1).
    ///
    /// Lets a screen pass `.empty` — and skip reading `UserDefaults` at all —
    /// on the overwhelmingly common pass where no shelf chip is lit, which is
    /// also what keeps the recompute from re-running every time a bookmark
    /// changes on a listing that is not filtering by one.
    public var usesUserState: Bool {
        ChipFacet.allCases.contains { facet in
            facet.isUserState && !(selected[facet.rawValue] ?? []).isEmpty
        }
    }

    public mutating func clear() { selected.removeAll() }

    // MARK: Matching

    /// - Parameter shelves: the player's three shelves, for the `.shelf` facet
    ///   (0.8.91, B1). Defaulted, and the default is *correct* rather than
    ///   convenient — `.empty` says nothing has been saved, wanted or tried,
    ///   which is what a caller with no store is entitled to assume. Every other
    ///   facet ignores it entirely, so the parameter costs nothing until a
    ///   shelf chip is lit.
    public func matches(_ entry: WineEntry, shelves: ShelfMembership = .empty) -> Bool {
        for facet in ChipFacet.allCases {
            guard let chosen = selected[facet.rawValue], !chosen.isEmpty else { continue }
            guard Self.entry(entry, satisfies: facet, anyOf: chosen, shelves: shelves) else {
                return false
            }
        }
        return true
    }

    private static func entry(
        _ entry: WineEntry,
        satisfies facet: ChipFacet,
        anyOf chosen: Set<String>,
        shelves: ShelfMembership
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

        case .grapeStyle:
            // Normalised like BODY and COUNTRY, and for the same reason: this is
            // a hand-authored string on the grape, not an enum's raw value.
            // Comparing `grapeStyle` alone — not `wineType` as well — is what
            // makes the chip and `EntryFilter.type` the same set: the two fields
            // are equal on all 177 grapes, so reading one is reading both, and
            // reading only the one the vocabulary is derived from means the row
            // can never offer a value the predicate cannot match.
            guard case .grape(let g) = entry else { return false }
            let actual = TextNormalize.label(g.grapeStyle)
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

        case .styleClass:
            guard case .style(let st) = entry else { return false }
            let cls = EntryDisplay.styleClass(
                name: st.common.name,
                classification: st.details.classification
            )
            return chosen.contains(cls.rawValue)

        case .styleColor:
            guard case .style(let st) = entry else { return false }
            return chosen.contains(EntryDisplay.colorType(name: st.common.name).rawValue)

        case .flavorClass:
            guard case .flavor(let f) = entry else { return false }
            return chosen.contains(f.details.classification.uppercased())

        case .flavorSubclass:
            guard case .flavor(let f) = entry else { return false }
            return chosen.contains(f.details.subclass.uppercased())

        case .shelf:
            // OR within the facet like every other row: SAVED + TRIED means
            // "either", which is what two lit chips read as. An unknown raw
            // value decodes to nothing rather than throwing — a restored
            // `ScreenStateStore` blob written by a build that knew a fourth
            // shelf must not take the whole filter down with it.
            return chosen.contains { raw in
                guard let shelf = Shelf(rawValue: raw) else { return false }
                return shelves.contains(entry.id, on: shelf)
            }
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

    /// Whether synthesised country rows should still be shown (0.7.0, H1).
    ///
    /// Country rows are not entries and so cannot go through `matches` — they
    /// carry no climate, no rarity, no origin of their own. The single chip they
    /// *can* satisfy is TYPE > COUNTRIES, so the rule is: nothing lit at all, or
    /// nothing lit outside TYPE and COUNTRIES chosen within it. Any other lit
    /// facet is a real constraint a country cannot meet, and dropping them is
    /// the same honest AND the type documents above.
    ///
    /// Lives here rather than in the screen because it is a statement about what
    /// a selection *means*, and Core is the half of the app a test can reach.
    public var allowsCountryRows: Bool {
        if isEmpty { return true }
        let otherFacetLit = selected.keys.contains { $0 != ChipFacet.category.rawValue }
        if otherFacetLit { return false }
        return includesCountries
    }

    /// Every option a facet offers.
    ///
    /// `categories` narrows the TYPE row to the tables a screen actually holds
    /// (0.7.0, H1). The world search searches continents and regions and
    /// synthesises country rows; offering it GRAPES, STYLES and FLAVORS chips
    /// would be three chips that can only ever take the count to zero, which is
    /// a control that exists solely to break the screen. Nil means "all", which
    /// is the filter-search tool's case and the default.
    ///
    /// `includingCountries` follows the screen's own `showsCountries` for the
    /// same reason: the pseudo-value is only meaningful where country rows are
    /// actually drawn.
    public static func options(
        for facet: ChipFacet,
        in categories: Set<EntryCategory>? = nil,
        includingCountries: Bool = true
    ) -> [ChipOption] {
        switch facet {
        case .category:
            let shown = EntryCategory.allCases.filter { categories?.contains($0) ?? true }
            return shown.map {
                ChipOption(facet: facet, value: $0.rawValue, label: $0.rawValue)
            } + (includingCountries
                 ? [ChipOption(facet: facet, value: countriesCategoryValue, label: countriesCategoryValue)]
                 : [])
        case .color:
            return [GrapeColor.red, .white].map {
                ChipOption(facet: facet, value: $0.rawValue, label: $0.rawValue.uppercased())
            }
        case .body:
            return GrapeBody.allCases.map {
                ChipOption(facet: facet, value: $0.rawValue, label: $0.label)
            }
        // From the data, like the flavour rows and `styleClass` — and here there
        // is not even an enum to have been tempted by. See
        // `WineDatabase.grapeStyles`.
        case .grapeStyle:
            return WineDatabase.shared.grapeStyles.map {
                ChipOption(facet: facet, value: $0, label: $0.uppercased())
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
            return WineDatabase.shared.searchableCountries.map {
                ChipOption(facet: facet, value: $0, label: $0.uppercased())
            }
        // From the data rather than from `StyleClassType.allCases`, and the
        // test is what found it: `.style` is `EntryDisplay.styleClass`'s
        // *fallback* arm, and no shipped style currently lands there, so the
        // enum-driven row offered a chip whose only possible effect was to empty
        // the listing. Same rule the flavour rows follow — a chip row describes
        // the catalog, not the type system.
        case .styleClass:
            return WineDatabase.shared.styleClasses.map {
                ChipOption(facet: facet, value: $0.rawValue, label: $0.rawValue)
            }
        // Driven off the data rather than off an enum, because neither of these
        // taxonomies is one: `FlavorDetails.classification` and `.subclass` are
        // strings the catalog authors, and hardcoding today's twenty-two
        // families here would silently drop the twenty-third.
        //
        // Through `WineDatabase.flavorClasses` / `.flavorSubclasses`, which the
        // scanner has used since it shipped — same data, same descending-size
        // order (biggest family first, ties alphabetical), so the chip row and
        // the scanner's answer list cannot disagree about what the taxonomy
        // holds. A second derivation here would have been a second answer to a
        // question that already had one.
        // From the catalog, not from `StyleColorType.allCases`, for the same
        // reason `.styleClass` is: an enum case no style resolves to would be a
        // chip whose only possible effect is to empty the listing. DUAL is a
        // real answer here and does appear; ROSE currently rests on a single
        // style, which is exactly the kind of fact a data-driven row states and
        // an enum-driven one hides.
        case .styleColor:
            let colors = WineDatabase.shared.entries(in: .styles)
                .map { EntryDisplay.colorType(name: $0.name).rawValue }
            return StyleColorType.allCases
                .map(\.rawValue)
                .filter(Set(colors).contains)
                .map { ChipOption(facet: facet, value: $0, label: $0) }
        case .flavorClass:
            return WineDatabase.shared.flavorClasses.map {
                ChipOption(facet: facet, value: $0, label: $0)
            }
        case .flavorSubclass:
            return WineDatabase.shared.flavorSubclasses.map {
                ChipOption(facet: facet, value: $0, label: $0.replacingOccurrences(of: "_", with: " "))
            }
        // The shelves themselves rather than a derived list — this is the one
        // row whose vocabulary is a type and not a catalog, because the shelves
        // are the app's own furniture. All three are always offered, including
        // empty ones: a row that hid TRIED until you had tried something would
        // hide the control at exactly the moment somebody was looking for it.
        case .shelf:
            return Shelf.allCases.map {
                ChipOption(facet: facet, value: $0.rawValue, label: $0.chipLabel)
            }
        }
    }
}

public extension WineDatabase {
    /// Everything surviving a chip selection, in the same name order every other
    /// listing uses.
    /// Filtering the pre-sorted list rather than sorting the survivors: the
    /// order is already right, and this ran per body pass (AUDIT M5).
    func entries(matching filter: ChipFilter, shelves: ShelfMembership = .empty) -> [WineEntry] {
        entriesInDisplayOrder.filter { filter.matches($0, shelves: shelves) }
    }

    /// What the result count *would be* if this chip were tapped.
    ///
    /// Shown on the chip itself, which is the difference between a filter you
    /// have to probe by trial and one you can read. 284 entries against a couple
    /// of dozen chips is a few thousand comparisons — cheap enough to do on
    /// every render rather than caching and having to invalidate it.
    func count(
        withChip option: ChipOption,
        added filter: ChipFilter,
        shelves: ShelfMembership = .empty
    ) -> Int {
        let candidate = filter.toggling(option)
        return entries.reduce(0) { $0 + (candidate.matches($1, shelves: shelves) ? 1 : 0) }
    }
}
