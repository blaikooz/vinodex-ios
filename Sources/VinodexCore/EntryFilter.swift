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
        case .soil: "GEOLOGY SCAN"
        case .origin: "REGION SCAN"
        case .rarity: "RARITY SCAN"
        case .system: "SYSTEM SCAN"
        case .climate: "CLIMATE SCAN"
        }
    }

    /// Label shown in the filter indicator bar.
    public var indicatorText: String {
        switch self {
        case .region: "FILTER: REGIONAL SECTOR"
        case .type(let v): "FILTER: \(v.uppercased())"
        case .tasting(let v): "FILTER: \(v.uppercased())"
        case .soil(let v): "FILTER: \(v.uppercased())"
        case .origin(let v): "FILTER: REGION \(v.uppercased())"
        case .rarity(let v): "FILTER: \(v.rawValue) RARITY"
        case .system(let v): "FILTER: \(v.uppercased()) SYSTEM"
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

        case .soil(let value):
            guard case .region(let r) = entry, let soil = r.details.soilType else { return false }
            return TextNormalize.label(soil).contains(TextNormalize.label(value))

        case .origin(let value):
            if let origin = entry.origin, TextNormalize.matchesWholeTerm(origin, value) { return true }
            return entry.tags.contains { TextNormalize.matchesWholeTerm($0, value) }

        case .rarity(let value):
            return entry.rarity == value

        case .system(let value):
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
    /// Free-text match across the same fields the web app searches.
    func matchesSearch(_ query: String) -> Bool {
        let q = TextNormalize.label(query)
        guard !q.isEmpty else { return true }

        var haystacks: [String] = [name, entryDescription]
        if let origin { haystacks.append(origin) }
        if let classification { haystacks.append(classification) }
        if case .region(let r) = self, let state = r.details.state { haystacks.append(state) }
        haystacks.append(contentsOf: keyRegions)
        haystacks.append(contentsOf: synonyms)
        haystacks.append(contentsOf: tags)

        return haystacks.contains { TextNormalize.label($0).contains(q) }
    }
}

public extension Array where Element == WineEntry {
    /// Applies a query, returning entries sorted by name — the same order the
    /// web app's list uses (`localeCompare`).
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
