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
    /// **What colour a style is in the glass** (0.8.8, C1) — the `.styleColor`
    /// chip's constraint, and the destination a style's COLOR tile should always
    /// have had.
    ///
    /// That tile pushed `.list(category: .grapes, filter: .type(color.rawValue))`
    /// from 0.6.2 until this batch, which is a category error with three
    /// separately broken outcomes. A RED style sent you to *every red grape* —
    /// answering "which grapes are red" for a question that was about wines. A
    /// ROSE or an ORANGE style sent you to a listing of **nothing**: no grape has
    /// `grapeType`, `grapeStyle` or `wineType` equal to either word, so the tile
    /// was a dead link on every rosé and orange style in the catalog. And a DUAL
    /// style sent you to *all 177 grapes*, via a `"dual"` special case added to
    /// `matches` in 0.6.2 (D2) for exactly this caller — a cross-link whose
    /// result set is the entire table it lands in.
    ///
    /// The CLASS tile beside it has gone to `.list(category: .styles, ...)` all
    /// along. This is its sibling doing the same thing: a style's colour leads to
    /// the other styles of that colour, which is what `ChipFacet.styleColor` has
    /// meant since 0.8.1's D and what this now reuses rather than approximates.
    case styleColor(StyleColorType)

    /// The same constraint as a chip, where one says the same thing (0.8.7, C1).
    ///
    /// ## What this is for
    ///
    /// Six of the seven cross-linked tiles on an entry's page push a
    /// `.list(category:filter:)` — tap SWEET on a flavour, or a grape's COLOR,
    /// or a region's CLIMATE, and you land on that category's listing narrowed
    /// to one facet. That listing has carried a chip row since 0.6.9 offering
    /// exactly those facets, and the two mechanisms never met: the marquee said
    /// FLAVOR SCAN, a banner said `FILTER: SWEET`, and the FILTER dropdown two
    /// lines below said nothing was on. The item asks for one destination
    /// instead — **FILTER SEARCH, with the chip already selected** — which is
    /// what this makes expressible.
    ///
    /// ## Why this does not reopen K2 rule 2
    ///
    /// Rule 2 — pinned as `filteredListingsKeepTheirOwnArt` — says a filtered
    /// listing may never fall through to its *parent category's* face, because a
    /// GEOLOGY SCAN is not a regions listing. That is a rule about not borrowing
    /// the wrong identity, and it is untouched: nothing here reads
    /// `EntryCategory`. The filter still answers with its own title and its own
    /// picture; what changed is what six of them consider themselves to *be*.
    ///
    /// ## Which ones convert, and why by derivation rather than by table
    ///
    /// A filter is a filter search when it can be said as a chip, because that
    /// is precisely when the destination is a search the user can go on
    /// adjusting. `.region` (a continent's country list) and `.soil` have no
    /// chip facet and stay scans.
    ///
    /// **`.origin` deliberately does not convert.** It is expressible as the
    /// COUNTRY chip only approximately — the filter matches an entry's tags as
    /// well as its origin, through `matchesWholeTerm`, where the chip compares
    /// the origin alone — and nothing in the app pushes it as a route anyway
    /// (`CountryScreen` uses it as a query). An approximate conversion on a
    /// destination nobody visits is a behaviour change with no upside.
    ///
    /// **`.type` converts for the colour *and* the style (0.8.8, C1 supersedes
    /// 0.8.7's ruling here).** The COLOR tile sends `.type("red")` /
    /// `.type("white")`, which is the `.color` chip exactly: measured over the
    /// shipped catalog, 96 grapes and 96, 81 and 81. The *body* tile sends
    /// `.type(grapeStyle)`, and C1 kept STYLE SCAN on it because that is not the
    /// BODY chip — 35 entries against 47, 20 against 67, 7 against 47, 40
    /// against 63. Every one of those numbers is still true. The conclusion
    /// drawn from them was too narrow: they measure `.type(grapeStyle)` against
    /// the *nearest existing* chip, and the rule the property states is that a
    /// filter converts when it is expressible as a chip — not when it happens to
    /// coincide with one already drawn.
    ///
    /// So the vocabulary widened rather than the rule bending. `ChipFacet` gains
    /// `.grapeStyle`, whose values are the catalog's own ten and whose predicate
    /// compares the same field `.type` does, and the two are then identical by
    /// construction rather than by luck. Measured anyway, on all ten, over the
    /// shipped catalog: Light-Body White 43/43, Medium-Body Red 40/40,
    /// Full-Body Red 35/35, Light-Body Red 20/20, Medium-Body White 18/18,
    /// Aromatic White 7/7, Full-Body White 7/7, Madeira 3/3, Sweet White 3/3,
    /// Sparkling Red 1/1. Zero entries in either direction on every value.
    ///
    /// **Why the compound chip the obvious reading suggests would have been
    /// wrong**, since it is the first thing anyone will propose: BODY=Full ∧
    /// COLOUR=red *is* Full-Body Red, 35 and 35 — and it is one of only two of
    /// the ten it works for. Four values are not compounds at all (AROMATIC
    /// WHITE, SWEET WHITE, MADEIRA, SPARKLING RED, 14 grapes between them), and
    /// on four of the six that look like compounds the two sides disagree
    /// because `grapeBodyClass` and `grapeStyle` are independently authored:
    /// Full-Body White 7 against 12, Light-Body White 43 against 47,
    /// Medium-Body White 18 against 22, Medium-Body Red 40 against 41. A
    /// compound chip would have lit and shown a list it did not describe, which
    /// is worse than the wrong title and is the failure this property exists to
    /// prevent.
    ///
    /// **The value must be one the row offers, and that is checked here.** Both
    /// `.type` arms read the catalog rather than a type — `GrapeColor` for the
    /// two colours, `WineDatabase.grapeStyles` for the ten styles — so a
    /// `.type` built from anything else answers nil and keeps its scan instead of
    /// producing a FILTER SEARCH title above a chip row with nothing lit. That
    /// hole was real until this batch: a style's COLOR tile could send
    /// `.type("Rose")`, which is neither. It now sends `.styleColor` instead.
    ///
    /// A case answering differently for different values has precedent one
    /// property below, where `.system` titles itself from its value.
    ///
    /// **`.tasting` converts as the flavour CLASS tile.** The case is named for
    /// what it did before the taxonomy existed — it matches tasting *notes* as
    /// well as classifications — but the one place that builds it as a route is
    /// that tile, always with a classification, and over the shipped catalog the
    /// two select identically on all five (SWEET 37/37, UMAMI 44/44, BITTER
    /// 13/13, SOUR 8/8, SALTY 4/4). The residual risk is a `.tasting(note)`
    /// pushed as a route one day, which would light a chip no row offers; the
    /// screen guards that by only pre-selecting an option its facet actually
    /// offers. See `EncyclopediaListScreen`.
    public var chipOption: ChipOption? {
        switch self {
        case .type(let value):
            // The grape's own RED/WHITE first.
            if let color = GrapeColor(rawValue: TextNormalize.label(value)) {
                return ChipOption(
                    facet: .color,
                    value: color.rawValue,
                    label: color.rawValue.uppercased()
                )
            }
            // Then the catalog's ten style names. Matched through
            // `TextNormalize` and answered with the catalog's *own* spelling, so
            // the chip's stored value is the one `ChipFilter.options` offers
            // whatever case the filter was built with.
            let target = TextNormalize.label(value)
            guard let style = WineDatabase.shared.grapeStyles.first(
                where: { TextNormalize.label($0) == target }
            ) else { return nil }
            return ChipOption(facet: .grapeStyle, value: style, label: style.uppercased())
        case .styleColor(let value):
            // Data-driven for `.styleColor`'s own reason: the row offers only the
            // colours shipped styles actually resolve to, and a chip for one they
            // do not would light and empty the listing.
            guard ChipFilter.options(for: .styleColor).contains(
                where: { $0.value == value.rawValue }
            ) else { return nil }
            return ChipOption(facet: .styleColor, value: value.rawValue, label: value.rawValue)
        case .tasting(let value):
            let v = value.uppercased()
            return ChipOption(facet: .flavorClass, value: v, label: v)
        case .flavorSubclass(let value):
            let v = value.uppercased()
            return ChipOption(
                facet: .flavorSubclass,
                value: v,
                label: v.replacingOccurrences(of: "_", with: " ")
            )
        case .rarity(let value):
            return ChipOption(facet: .rarity, value: value.rawValue, label: value.rawValue)
        case .system(let value):
            return ChipOption(facet: .styleClass, value: value, label: value)
        case .climate(let value):
            return ChipOption(
                facet: .climate,
                value: value.rawValue,
                label: value.rawValue.uppercased()
            )
        // A continent's countries, a soil keyword and a region's own origin.
        // None is a row of chips. See the note.
        case .region, .soil, .origin:
            return nil
        }
    }

    /// LCD header title when this filter is active.
    ///
    /// **One title for every filter that is a chip** (0.8.7, C1). See
    /// `chipOption`: those listings are one destination reached seven ways, and
    /// naming each arrival after the facet it came in on told the user which
    /// door they used rather than which room they are in. The two that are not
    /// chips keep the scan they always had.
    ///
    /// FILTER SEARCH rather than MASTER SEARCH, which is `DexRoute.chipFilter`'s
    /// title and stays it: that one searches the whole catalog from nothing,
    /// this one opens already narrowed to a category and a facet. FILTER is also
    /// the word on the dropdown this page has had since 0.6.9, which is now the
    /// control the title is naming.
    ///
    /// **STYLE SCAN is no longer reachable from anything (0.8.8, C1).** The body
    /// tile's destination was the one arm left answering it, and the widened chip
    /// vocabulary takes it. The arm stays because `.type` is a public case and a
    /// value outside both tables has to answer *something* — and because a
    /// `default` here would have quietly renamed the next filter kind somebody
    /// adds. `marquee-stylescan` is not orphaned: it is `EntryCategory.styles`'
    /// own face and the unfiltered STYLES listing still wears it.
    public var scanTitle: String {
        if chipOption != nil { return "FILTER SEARCH" }
        switch self {
        case .region: return "SECTOR SCAN"
        case .type: return "STYLE SCAN"
        case .tasting: return "FLAVOR SCAN"
        case .flavorSubclass: return "FLAVOR SCAN"
        case .soil: return "GEOLOGY SCAN"
        case .origin: return "REGION SCAN"
        case .rarity: return "RARITY SCAN"
        // The value, not the word SYSTEM (0.6.2, D1): a class filter opened
        // from the ORIGIN chip must read "ORIGIN SCAN", not "SYSTEM SCAN".
        case .system(let v): return "\(v.uppercased()) SCAN"
        case .climate: return "CLIMATE SCAN"
        case .styleColor: return "STYLE SCAN"
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
    ///
    /// **The magnifier where the filter is a chip** (0.8.7, C1), pairing with
    /// `scanTitle` as this property's own note demands. `DexGlyph.search` is
    /// 0.7.1 A2's one magnifying glass — the same glyph the search bars, the
    /// menu's round button and MASTER SEARCH wear — so a page that has become a
    /// filter search reads as one. `glyphsAreDistinct` is untroubled: it walks
    /// `allRoutes`, which holds unfiltered listings only.
    public var marqueeSymbol: String {
        if chipOption != nil { return DexGlyph.search }
        switch self {
        // A continent's countries — the sector this scan covers.
        case .region: return "globe.europe.africa.fill"
        case .type: return "wineglass.fill"
        case .tasting, .flavorSubclass: return "leaf.fill"
        // Rock, for a soil scan. The one filter whose subject is literally
        // under the vineyard.
        case .soil: return "mountain.2.fill"
        case .origin: return "mappin.and.ellipse"
        case .rarity: return "star.fill"
        case .system: return "checkmark.seal.fill"
        case .climate: return "thermometer.medium"
        case .styleColor: return "wineglass.fill"
        }
    }

    /// The drawn marquee face while this filter is active (0.8.5, B1).
    ///
    /// **This is the whole of B1, and the report was exactly right about the
    /// symptom and one word off about the screen.** "Style Scan didn't get its
    /// glyph" reads like the styles *listing*, which has had `marquee-stylescan`
    /// since 0.8.4 — but STYLE SCAN is `scanTitle` on `.type`, the colour-class
    /// filter, and `DexRoute.marqueeArt` answered nil for every filtered listing
    /// in the app. So the panel read STYLE SCAN over a fallen-back SF wineglass
    /// while the unfiltered STYLES listing beside it wore the drawn one.
    ///
    /// The nil was deliberate and was defended under K2 rule 2 — a GEOLOGY SCAN
    /// is not a regions listing, so it may not wear the regions face. That rule
    /// is kept and this is what it actually implies: a filter answers with *its
    /// own* picture where the drop has one, and nil where it does not, exactly
    /// as `marqueeSymbol` beside it has done since 0.7.0. What it may never do
    /// is fall through to the parent category's.
    ///
    /// **Eight of the nine resolve since 0.8.7 (C1), and no glyph was drawn to
    /// get there.** B1 left a four-name backlog — nobody had drawn a rock, a
    /// star, a seal or a thermometer, so GEOLOGY, RARITY, SYSTEM and CLIMATE
    /// SCAN kept their SF Symbols. C1 makes RARITY, SYSTEM and CLIMATE stop
    /// being scans at all: they are chips, so they are FILTER SEARCH and they
    /// wear `marquee-mastersearch`, the magnifier already on disk and already
    /// worn by `DexRoute.chipFilter`. The backlog is one name, `soil` — and
    /// `.soil` is the one filter kind with no navigation entry point in the app,
    /// so nothing on screen is falling back today.
    ///
    /// `marquee-stylescan` and `marquee-flavorscan` are not orphaned by this:
    /// they are `EntryCategory.styles` and `.flavors`' own faces and are still
    /// worn by the unfiltered listings, which is where they were drawn for.
    ///
    /// **Still eight of ten after 0.8.8's C1, and `soil` is still the one.** C1
    /// adds a tenth case and converts the last live `.type` values, so
    /// `.styleColor` and every reachable `.type` now take the magnifier with the
    /// rest. `.soil` remains the single undrawn name and the single filter kind
    /// nothing pushes as a route — the backlog has not grown and has not moved.
    public var marqueeArt: String? {
        if chipOption != nil { return "marquee-mastersearch" }
        switch self {
        // A continent's countries, drawn as a continent — which is the sector
        // this scan actually covers, and the same picture `.continent` wears.
        case .region: return "marquee-continentscan"
        case .type: return "marquee-stylescan"
        case .tasting, .flavorSubclass: return "marquee-flavorscan"
        // REGION SCAN, and the regions face is this filter's own rather than a
        // borrowed parent's: `.origin` narrows to one region's entries and the
        // title says so.
        case .origin: return "marquee-regions"
        // Nobody drew a rock. See the note.
        case .soil: return nil
        // Not reached today: every value of these five answers `chipOption`, so
        // the early return above has already fired. (`.type` is the exception —
        // its body values have no chip and do reach the arm above.) Left spelled
        // out rather than defaulted, because these are what the property should
        // answer if a facet ever loses its chip row, and a `default` would have
        // answered nil for a filter that had just become a scan again.
        case .rarity, .system, .climate, .styleColor: return nil
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
        case .styleColor(let v): "FILTER: \(v.rawValue) IN THE GLASS"
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
            // **The `"dual"` arm is gone (0.8.8, C1).** 0.6.2's D2 added it
            // because DUAL is a style-side colour type no grape carries, so a
            // dual style's COLOR tile landed on an empty grape listing — and the
            // fix chosen was to make every grape qualify, turning a cross-link
            // into a route to all 177 entries of the table. The tile is the
            // arm's only caller and C1 repoints it at `.styleColor`, where DUAL
            // is a first-class value matched against the styles that actually
            // are dual. A special case whose reason has been deleted is a trap
            // for whoever builds `.type` next, so it goes with its caller rather
            // than being left to answer "everything" to a question nobody asks.
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

        // The same derivation `ChipFacet.styleColor` runs, so the filter and the
        // chip cannot disagree about what colour a style is — which is what lets
        // `EncyclopediaListScreen` hand the constraint from one to the other.
        case .styleColor(let value):
            guard case .style(let s) = entry else { return false }
            return EntryDisplay.colorType(name: s.common.name) == value
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
