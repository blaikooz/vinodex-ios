import Foundation

// MARK: - Normalisation
//
// Ports the helpers in `src/services/entryUtils.ts`. `String.folding` with
// `.diacriticInsensitive` replaces the web app's `normalize('NFD')` + combining
// mark strip.

public enum TextNormalize {
    /// Hoisted out of `label`. This is called tens of thousands of times per
    /// render of a full list, and constructing a `Locale` per call was a
    /// measurable slice of that on its own.
    private static let foldingLocale = Locale(identifier: "en_US_POSIX")

    /// `normalizeLabel` — lowercase, diacritics removed.
    public static func label(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: foldingLocale)
    }

    /// `normalizeKey` — lowercase, diacritics removed, non-alphanumerics collapsed to spaces.
    public static func key(_ value: String) -> String {
        let folded = label(value)
        let mapped = folded.map { ch -> Character in
            ch.isLetter || ch.isNumber ? ch : " "
        }
        return String(mapped)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    /// `normalizeTerm` — as `label`, with separators collapsed. Used for whole-term matching.
    public static func term(_ value: String) -> String {
        let folded = label(value)
        let mapped = folded.map { ch -> Character in
            "_-/(),.;".contains(ch) ? " " : ch
        }
        return String(mapped)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    /// `matchesWholeTerm` — equality, or a whole-word containment check.
    public static func matchesWholeTerm(_ candidate: String, _ searchTerm: String) -> Bool {
        let c = term(candidate)
        let t = term(searchTerm)
        guard !c.isEmpty, !t.isEmpty else { return false }
        if c == t { return true }
        return " \(c) ".contains(" \(t) ")
    }
}

// MARK: - Filters

/// An active filter narrowing a listing, replacing the web app's stringly-typed
/// `filterMode` / `filterValue` pair with associated values.
///
/// `region([String])` is the continent filter: the globe passes the country list
/// for a continent, sourced from `palette.continentCountries`. It is **not**
/// dropped alongside `COUNTRY_GATE` — it is what makes the globe work.
public enum EntryFilter: Sendable, Hashable {
    case region([String])
    case type(String)
    case tasting(String)
    /// Flavours filed under one subclass (BERRY, SMOKY, …). `tasting` cannot
    /// express this: it matches notes and classifications, and a flavour's
    /// subclass is a third taxonomy level neither of those reach.
    case flavorSubclass(String)
    case soil(String)
    case origin(String)
    case rarity(RarityLabel)
    case system(String)
    case climate(ClimateClass)

    /// LCD header title when this filter is active.
    public var scanTitle: String {
        switch self {
        case .region: "SECTOR SCAN"
        case .type: "STYLE SCAN"
        case .tasting: "FLAVOR SCAN"
        case .flavorSubclass: "FLAVOR SCAN"
        case .soil: "GEOLOGY SCAN"
        case .origin: "REGION SCAN"
        case .rarity: "RARITY SCAN"
        // The value, not the word SYSTEM (0.6.2, D1): a class filter opened
        // from the ORIGIN chip must read "ORIGIN SCAN", not "SYSTEM SCAN".
        case .system(let v): "\(v.uppercased()) SCAN"
        case .climate: "CLIMATE SCAN"
        }
    }

    /// Marquee glyph while this filter is active (0.7.0, K2).
    ///
    /// `scanTitle` has existed since the filters did, and `DexRoute.marqueeSymbol`
    /// threw the filter away — `case .list(let category, _)` — so a GEOLOGY SCAN
    /// showed the regions map, a RARITY SCAN showed the grape leaf and a CLIMATE
    /// SCAN showed the map again. The title said one thing and the glyph beside
    /// it said another, on nine reachable filter kinds.
    ///
    /// Pairs one-to-one with `scanTitle` and sits beside it for that reason: a
    /// new filter kind that gets a title without a glyph is the bug this fixes.
    /// All iOS 17-safe — see KNOWN-ISSUES on symbols with a later OS floor
    /// rendering blank rather than failing to compile.
    public var marqueeSymbol: String {
        switch self {
        // A continent's countries — the sector this scan covers.
        case .region: "globe.europe.africa.fill"
        case .type: "wineglass.fill"
        case .tasting, .flavorSubclass: "leaf.fill"
        // Rock, for a soil scan. The one filter whose subject is literally
        // under the vineyard.
        case .soil: "mountain.2.fill"
        case .origin: "mappin.and.ellipse"
        case .rarity: "star.fill"
        case .system: "checkmark.seal.fill"
        case .climate: "thermometer.medium"
        }
    }

    /// Label shown in the filter indicator bar.
    public var indicatorText: String {
        switch self {
        case .region: "FILTER: REGIONAL SECTOR"
        case .type(let v): "FILTER: \(v.uppercased())"
        case .tasting(let v): "FILTER: \(v.uppercased())"
        case .flavorSubclass(let v): "FILTER: \(v.replacingOccurrences(of: "_", with: " ").uppercased())"
        case .soil(let v): "FILTER: \(v.uppercased())"
        case .origin(let v): "FILTER: REGION \(v.uppercased())"
        case .rarity(let v): "FILTER: \(v.rawValue) RARITY"
        case .system(let v): "FILTER: \(v.uppercased())"
        case .climate(let v): "FILTER: \(v.rawValue.uppercased()) CLIMATE"
        }
    }

    /// Whether an entry satisfies this filter. Ports the predicate branches in
    /// `EncyclopediaList.tsx`.
    public func matches(_ entry: WineEntry) -> Bool {
        switch self {
        case .region(let keywords):
            return keywords.contains { keyword in
                let k = TextNormalize.label(keyword)
                if let origin = entry.origin, TextNormalize.label(origin).contains(k) { return true }
                if entry.tags.contains(where: { TextNormalize.label($0).contains(k) }) { return true }
                return TextNormalize.label(entry.name).contains(k)
            }

        case .type(let value):
            let target = TextNormalize.label(value)
            guard case .grape(let g) = entry else {
                // Styles also match on their inferred colour type in the web app;
                // that inference lives in the UI layer, so styles fall through here.
                return false
            }
            // DUAL is a style-side colour type — a style spanning both colours
            // — that no single grape carries, so the chip returned nothing
            // (0.6.2, D2). Dual-purpose means both colours qualify.
            if target == "dual" { return true }
            if TextNormalize.label(g.grapeStyle) == target { return true }
            if let wineType = g.wineType, TextNormalize.label(wineType) == target { return true }
            return TextNormalize.label(g.grapeType.rawValue) == target

        case .tasting(let value):
            let target = TextNormalize.label(value)
            if entry.tastingProfile.contains(where: { TextNormalize.label($0.note) == target }) { return true }
            if let classification = entry.classification {
                return TextNormalize.label(classification) == target
            }
            return false

        case .flavorSubclass(let value):
            guard case .flavor(let f) = entry else { return false }
            return TextNormalize.label(f.details.subclass) == TextNormalize.label(value)

        case .soil(let value):
            guard case .region(let r) = entry, let soil = r.details.soilType else { return false }
            return TextNormalize.label(soil).contains(TextNormalize.label(value))

        case .origin(let value):
            if let origin = entry.origin, TextNormalize.matchesWholeTerm(origin, value) { return true }
            return entry.tags.contains { TextNormalize.matchesWholeTerm($0, value) }

        case .rarity(let value):
            return entry.rarity == value

        case .system(let value):
            // Styles compare through the same class inference the UI shows
            // (0.6.x): their raw `classification` strings ("STYLE") predate
            // the class system, so filtering on them from the CLASS tile
            // landed on a stale near-everything list instead of the class
            // the chip actually named.
            if case .style(let s) = entry {
                let cls = EntryDisplay.styleClass(
                    name: s.common.name,
                    classification: s.details.classification
                )
                return TextNormalize.label(cls.rawValue) == TextNormalize.label(value)
            }
            guard let classification = entry.classification else { return false }
            return TextNormalize.label(classification) == TextNormalize.label(value)

        case .climate(let value):
            return entry.climate == value
        }
    }
}

// MARK: - Query

/// A listing request: which categories, an optional filter, and a search string.
public struct EntryQuery: Sendable, Hashable {
    public var categories: Set<EntryCategory>
    public var filter: EntryFilter?
    public var search: String

    public init(categories: Set<EntryCategory>, filter: EntryFilter? = nil, search: String = "") {
        self.categories = categories
        self.filter = filter
        self.search = search
    }

    /// Master search spans every category, matching the web app's MASTER_SEARCH.
    public static func masterSearch(_ search: String = "") -> EntryQuery {
        EntryQuery(categories: Set(EntryCategory.allCases), search: search)
    }

    public static func category(_ category: EntryCategory, filter: EntryFilter? = nil, search: String = "") -> EntryQuery {
        EntryQuery(categories: [category], filter: filter, search: search)
    }
}

extension WineEntry {
    /// The fields free-text search scans, matching the web app's list.
    ///
    /// One definition, read by both the folded index and the unindexed match,
    /// so the two cannot drift into searching different things.
    var searchFields: [String] {
        var fields: [String] = [name, entryDescription]
        if let origin { fields.append(origin) }
        if let classification { fields.append(classification) }
        if case .region(let r) = self, let state = r.details.state { fields.append(state) }
        fields.append(contentsOf: keyRegions)
        fields.append(contentsOf: synonyms)
        fields.append(contentsOf: tags)
        return fields
    }

    /// `searchFields`, folded once and joined — the value `WineDatabase` builds
    /// at load so a query costs one `contains` per entry instead of folding
    /// every field of every entry again (AUDIT M5).
    ///
    /// The newline separator is load-bearing. A query cannot contain one (the
    /// search bar is a single-line `UITextField`), so any newline-free
    /// substring of the joined text lies wholly inside one field — the join
    /// cannot manufacture a match that spans two of them, which is what makes
    /// this exactly equivalent to the per-field scan below.
    var searchHaystack: String {
        searchFields.map(TextNormalize.label).joined(separator: "\n")
    }

    /// Free-text match across the same fields the web app searches.
    ///
    /// The unindexed path: it folds every field of the entry on every call.
    /// Prefer `WineDatabase.entries(matching:)`, which folds once at load; this
    /// stays for `[WineEntry].apply(_:)`, which has no index to read.
    func matchesSearch(_ query: String) -> Bool {
        let q = TextNormalize.label(query)
        guard !q.isEmpty else { return true }
        return searchFields.contains { TextNormalize.label($0).contains(q) }
    }
}

public extension Array where Element == WineEntry {
    /// Applies a query, returning entries sorted by name — the same order the
    /// web app's list uses (`localeCompare`).
    ///
    /// Unindexed, so it re-folds and re-sorts on every call. Screens should go
    /// through `WineDatabase.entries(matching:)` instead (AUDIT M5); this is
    /// for callers holding an arbitrary array rather than the database.
    func apply(_ query: EntryQuery) -> [WineEntry] {
        filter { entry in
            guard query.categories.contains(entry.category) else { return false }
            guard entry.matchesSearch(query.search) else { return false }
            guard let filter = query.filter else { return true }
            return filter.matches(entry)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
