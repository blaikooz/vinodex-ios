#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The scrolling entry list, with an optional filter banner and search bar.
public struct EncyclopediaListScreen: View {
    let categories: Set<EntryCategory>
    let filter: EntryFilter?
    let showsSearch: Bool
    /// Whether the field takes focus as the screen opens — see `searchBar`.
    let focusesSearchOnAppear: Bool
    /// Whether country rows join the results (v0.5.6). Countries are not
    /// entries — their pages are assembled from regions — so master and
    /// world search list them explicitly rather than through the query.
    let showsCountries: Bool
    /// Which chip rows this listing offers (0.6.9, I3). Empty on every listing
    /// but the varieties scan — see `chipRows`.
    let chipFacets: [ChipFacet]
    let onSelect: (WineEntry) -> Void
    let onSelectCountry: (String) -> Void

    /// Held outside the view, so it survives the screen being torn down and
    /// rebuilt when you open an entry and come back — see `SearchStateStore`.
    @State private var searches = SearchStateStore.shared
    @State private var access = AccessStore.shared
    @State private var coachmarks = CoachmarkEngine.shared
    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared

    /// The row the walkthrough spotlights (onboarding pass, 2026-09-01):
    /// Pinot Noir by maintainer ruling — the heartbreak grape is a better
    /// first lesson than the alphabet's Cabernet — falling back to the
    /// first row on any list where he is absent. Hoisted out of the row
    /// loop because the inline form sent the type-checker over budget.
    private func spotlitRowID(in rows: [SearchRow]) -> String? {
        rows.first(where: { $0.sortName == "Pinot Noir" })?.id ?? rows.first?.id
    }

    private var lcd: LcdMode { settings.lcdMode }
    /// The database this screen reads. Defaulted so no call site changes, but
    /// injectable, which is the whole of **M27**: a screen that hard-reads
    /// `WineDatabase.shared` cannot be put in front of a fixture.
    private let db: WineDatabase

    private var searchKey: String {
        SearchStateStore.key(categories: categories, filter: filter)
    }

    private var search: String { searches.query(for: searchKey) }

    /// Bound straight through to the store rather than mirrored into `@State`
    /// and restored on appear: a mirror has to be seeded from *somewhere*, and
    /// every ordering of `onAppear` / `task` against the initial `task(id:)` run
    /// either filtered twice or flashed the unfiltered list first.
    private var searchBinding: Binding<String> {
        Binding(
            get: { searches.query(for: searchKey) },
            set: { searches.setQuery($0, for: searchKey) }
        )
    }

    /// Identity for the search bar within the scroll target layout.
    ///
    /// Prefixed so it can never collide with an entry id, since both flow
    /// through the same `String?` anchor.
    static let searchBarAnchor = "__searchbar__"
    /// Likewise for the chip dropdown (0.6.9, I3).
    static let chipBarAnchor = "__chipbar__"

    /// Where the list was scrolled to, held in the same store as the query so
    /// the two are restored together and dropped together.
    private var anchorBinding: Binding<String?> {
        Binding(
            get: { searches.anchor(for: searchKey) },
            set: { searches.setAnchor($0, for: searchKey) }
        )
    }

    public init(
        db: WineDatabase = .shared,
        categories: Set<EntryCategory>,
        filter: EntryFilter? = nil,
        showsSearch: Bool = true,
        focusesSearchOnAppear: Bool = false,
        showsCountries: Bool = false,
        chipFacets: [ChipFacet] = [],
        onSelect: @escaping (WineEntry) -> Void,
        onSelectCountry: @escaping (String) -> Void = { _ in }
    ) {
        self.db = db
        self.categories = categories
        self.filter = filter
        self.showsSearch = showsSearch
        self.focusesSearchOnAppear = focusesSearchOnAppear
        self.showsCountries = showsCountries
        self.chipFacets = chipFacets
        self.onSelect = onSelect
        self.onSelectCountry = onSelectCountry

        // The chip selection this listing was left with (0.6.9, I3). Keyed the
        // same way the query and the scroll anchor are, so the three are
        // restored and dropped together. `SearchStateStore.key` is static, so
        // it can be called before `self` is usable.
        let key = SearchStateStore.key(categories: categories, filter: filter)
        var restored = ScreenStateStore.shared
            .decoded(ChipFilter.self, "chips", for: key) ?? ChipFilter()

        // **The chip you arrived on, already lit** (0.8.7, C1).
        //
        // A cross-linked tile pushes `.list(category:filter:)`, and where that
        // filter is expressible as a chip the page is a filter search — see
        // `EntryFilter.chipOption` and `queryFilter` below. Seeding it here
        // rather than in a `task` is 0.6.9's own argument for restoring in
        // `init`: the list must open filtered rather than open wrong and correct
        // itself a frame later.
        //
        // **Only when nothing is restored.** The chip is a live control now, so
        // a user who turns it off must be able to; the key includes the filter,
        // so "nothing restored" means "this is the first time this door has been
        // opened", and adjusting the row is remembered from then on.
        //
        // **And only if the row actually offers it.** `chipOption` is derived
        // from the filter's value, and a value no facet lists — a `.tasting`
        // built from a tasting note rather than a classification — would light a
        // chip that cannot be seen or cleared and would empty the list. Checked
        // against the same `options(for:in:)` the row draws from, so the guard
        // and the row can never disagree.
        if restored.isEmpty,
           let preset = filter?.chipOption,
           chipFacets.contains(preset.facet),
           ChipFilter.options(
               for: preset.facet,
               in: categories,
               includingCountries: showsCountries
           ).contains(preset) {
            restored.toggle(preset)
        }
        _chips = State(initialValue: restored)
    }

    /// The filter as a chip, when it is one (0.8.7, C1).
    private var presetChip: ChipOption? { filter?.chipOption }

    /// The filter the *query* applies.
    ///
    /// **Nil once the constraint has been handed to the chip row**, which is the
    /// half of C1 that makes the pre-selected chip a control rather than a
    /// decoration. Applying both would have narrowed the list twice by the same
    /// predicate — harmless, since the two are the same set — and left the chip
    /// unable to widen it again: turning SWEET off would have changed nothing,
    /// because `EntryQuery`'s filter would still be there. A control that cannot
    /// be turned off is worse than no control.
    ///
    /// The two are only exchanged where they are the same set, which
    /// `EntryFilter.chipOption` establishes by measurement rather than by
    /// assertion — and the extra `presetChip == chips`-shaped conditions in
    /// `init` mean the exchange only happens when the chip is really lit.
    private var queryFilter: EntryFilter? {
        guard let presetChip, chips.isOn(presetChip) else { return filter }
        return nil
    }

    /// Recomputed only when the query actually changes.
    ///
    /// This was a computed property, so every keystroke *and* every unrelated
    /// re-render re-filtered and re-sorted all 284 entries — which is why
    /// master search, the one screen with every category selected, was slow to
    /// appear. `task(id:)` runs it once per query instead.
    @State private var rows: [SearchRow] = []

    /// One list, two kinds of row. Countries used to lead as a block, which
    /// read as a separate screen bolted on top — merged into name order they
    /// are just results (v0.5.7).
    private enum SearchRow: Identifiable {
        case entry(WineEntry)
        case country(String)

        var id: String {
            switch self {
            case .entry(let entry): entry.id
            // Prefixed so it can never collide with an entry id.
            case .country(let name): "__country__\(name)"
            }
        }

        var sortName: String {
            switch self {
            case .entry(let entry): entry.name
            case .country(let name): name
            }
        }
    }

    /// The query the last `task` run started from — see `awaitSearchDebounce`.
    @State private var debouncedFrom = ""

    /// The chip selection (0.6.9, I3).
    ///
    /// Mirrored into `ScreenStateStore` on change and restored in `init`,
    /// rather than read back out of the store on access — the shape
    /// `ChipFilterScreen` already uses, and for AUDIT M5's reason: the store's
    /// accessor is a JSON round-trip, and a computed property here would decode
    /// it in the `task(id:)`, in `recompute`, in the dropdown and once per chip
    /// on every body pass. Restoring in `init` also seeds the first render, so
    /// the list does not open unfiltered and correct itself a frame later.
    @State private var chips: ChipFilter
    /// Whether the chip rows are unfolded. Folded by default: the list is the
    /// subject, and three rows of chips above it unasked-for would bury the
    /// first result. Session-local, like the fold state everywhere else.
    @State private var showsChips = false
    @State private var screens = ScreenStateStore.shared
    /// The three shelves, for the SAVED / WANTED / TRIED chips and for the
    /// tried border on a row (0.8.91, B1/B2).
    @State private var bookmarks = BookmarkStore.shared

    /// The chip selection *and* whatever external state it needs to be answered
    /// (0.8.91, B1).
    ///
    /// One id for the recompute rather than two `task(id:)`s: the shelf row is
    /// the first facet whose predicate depends on something outside the filter,
    /// so a lit TRIED chip has to re-run the pass when a bookmark changes and an
    /// unlit one must not. Resolving to `.empty` when no shelf chip is lit makes
    /// that a value comparison rather than a rule each call site remembers.
    private struct ChipPass: Equatable {
        let chips: ChipFilter
        let shelves: ShelfMembership
    }

    private var chipPass: ChipPass {
        ChipPass(chips: chips, shelves: chips.usesUserState ? bookmarks.membership : .empty)
    }

    private func recompute() {
        let pass = chipPass
        // `db.entries(matching:)`, not `db.entries.apply(_:)`: the folding and
        // the sort are done once at load rather than per keystroke (AUDIT M5).
        let entries = db.entries(
            matching: EntryQuery(categories: categories, filter: queryFilter, search: search)
        )
            // The chip predicate rides on the survivors of the indexed pass,
            // exactly as `ChipFilterScreen` does it — and short-circuited when
            // nothing is lit, so the ~ten listings with no chip rows at all pay
            // nothing for the feature existing.
            .filter { pass.chips.isEmpty || pass.chips.matches($0, shelves: pass.shelves) }
            .map(SearchRow.entry)
        // Countries carry no grape facet, so a lit chip drops them — the same
        // honest reading of an AND across facets `ChipFilter` documents.
        //
        // **With one exception, added for H1 (0.7.0).** A country row is not an
        // entry; it is synthesised, and it can satisfy exactly one chip in the
        // whole system — TYPE > COUNTRIES. The blanket rule was written when the
        // only screen with chips was the grape listing, where no country row is
        // drawn at all and the question never arose. On the world search,
        // countries are a third of the results and the COUNTRIES chip is one of
        // the three H1 asks for, so the old rule made that chip mean "hide the
        // things I just asked for".
        //
        // The rule now is the honest one: countries survive when nothing is lit,
        // or when the *only* lit facet is TYPE and COUNTRIES is among its
        // values. Any other facet still drops them, because a country genuinely
        // cannot carry a climate or a rarity.
        let countries = showsCountries && chips.allowsCountryRows
            ? db.countries(matching: search).map(SearchRow.country)
            : []
        rows = (entries + countries).sorted {
            $0.sortName.localizedCaseInsensitiveCompare($1.sortName) == .orderedAscending
        }
        scrollToSpotlitRow()
    }

    /// The walkthrough's listing step spotlights Pinot Noir, who sits well
    /// below the fold of a 187-grape list. A spotlight whose target never
    /// reports geometry is a wedge: no halo draws and there is nothing to
    /// tap, which stalled the whole run on step 2 (0.9.45 test pass). So
    /// whenever this list is built or the step goes live while it is up,
    /// drive the scroll anchor to his row — the same store the two-way
    /// `scrollPosition(id:)` binding below already reads.
    private func scrollToSpotlitRow() {
        guard coachmarks.current?.id == "listing",
              let id = spotlitRowID(in: rows) else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            searches.setAnchor(id, for: searchKey)
        }
    }

    /// `task(id:)` alone covers first appearance. The `onAppear` that used to sit
    /// alongside it made the screen build its entire row tree twice on entry —
    /// `onAppear` filled `results`, then the initial `task` reassigned it, and a
    /// `@State` assignment invalidates whether or not the value changed.
    public var body: some View {
        content
            .task(id: search) {
                let previous = debouncedFrom
                debouncedFrom = search
                guard await awaitSearchDebounce(from: previous, to: search) else { return }
                recompute()
            }
            // A chip tap is a discrete act, so it re-filters immediately;
            // typing is a burst, so it debounces. Same split as
            // `ChipFilterScreen` (AUDIT M5).
            .task(id: chipPass) { recompute() }
            // Mirrored on change rather than at each call site that toggles a
            // chip — one of those would eventually be added without its save.
            .onChange(of: chips) { _, value in
                screens.encode(value.isEmpty ? nil : value, "chips", for: searchKey)
            }
            // The resumed-run case `recompute()` cannot see: the rows are
            // already built when the listing step goes live over them.
            .onChange(of: coachmarks.current?.id) { _, stepID in
                if stepID == "listing" { scrollToSpotlitRow() }
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            // The banner says what is narrowing this list — unless the chip row
            // is already saying it (0.8.7, C1). Before C1 a cross-linked arrival
            // showed `FILTER: SWEET` in a strip it could not act on, above a
            // FILTER dropdown reporting nothing on; now the constraint is a lit
            // chip in that dropdown, and a second immovable statement of it
            // would be the redundancy the item is complaining about.
            //
            // `queryFilter`, not `filter`: they differ exactly when the chip has
            // taken over, so this cannot drift from what is actually filtering.
            if let banner = queryFilter {
                filterBanner(banner)
            }

            ZStack {
                DexScreenBackground()

                ScrollView {
                    // Lazy, not a plain VStack. Master search selects every
                    // category, so a plain stack built and measured all 284 rows
                    // — each resolving an icon well and its chips — before the
                    // first frame could be shown. That was most of the delay
                    // between tapping SEARCH and the list appearing. Only the
                    // visible handful is built now.
                    LazyVStack(spacing: 8) {
                        if showsSearch {
                            searchBar
                                // Explicitly identified so it is a legal scroll
                                // target: `scrollPosition(id:)` can only address
                                // views the target layout has ids for, and
                                // without this the search bar is a hole at the
                                // top of the list that the anchor cannot name.
                                .id(Self.searchBarAnchor)
                        }

                        if !chipFacets.isEmpty {
                            chipDropdown.id(Self.chipBarAnchor)
                            if showsChips {
                                ForEach(chipFacets) { facet in
                                    chipRow(facet).id("__chips__" + facet.rawValue)
                                }
                            }
                        }

                        if rows.isEmpty {
                            // The query no longer decides whether an empty list
                            // is a fault or an answer — `db.dataState` does. The
                            // old `&& search.isEmpty` gate suppressed the error
                            // on exactly the path that produced the reported
                            // symptom, because the query survives navigation.
                            // (AUDIT M2)
                            DexEmptyState(db: db) { emptyState }
                        } else {
                            ForEach(rows) { row in
                                switch row {
                                case .country(let country):
                                    countryRow(country)
                                case .entry(let entry):
                                    EntryTileView(
                                        entry: entry,
                                        palette: db.palette,
                                        locked: access.isLocked(entry, in: db),
                                        // §B2. Read here rather than inside the
                                        // tile so the store is observed once per
                                        // listing instead of once per row.
                                        tried: bookmarks.contains(entry.id, on: .tried)
                                    ) {
                                        onSelect(entry)
                                    }
                                    // The walkthrough's second step (0.8.9d,
                                    // G2) lights the top row, whichever entry
                                    // that is. Compared by id rather than taken
                                    // from an enumerated index, so `ForEach`
                                    // keeps the stable identity the scroll
                                    // restoration below depends on.
                                    .coachmarkTarget(row.id == spotlitRowID(in: rows) ? .listingRow : nil)
                                }
                            }
                        }
                    }
                    // Pairs with `scrollPosition(id:)` below — without it the
                    // scroll view has no per-subview geometry to report or to
                    // scroll to, and the binding stays nil forever.
                    .scrollTargetLayout()
                }
                // Inset as a *content margin*, not as padding around the target
                // layout.
                //
                // `.padding(10)` here shifted the list ten points left every
                // time a position was restored. Padding outside
                // `scrollTargetLayout()` puts the targets' origin ten points in
                // from the scroll content's origin, and `scrollPosition(id:)`
                // aligns a target on both axes — so restoring one scrolled x to
                // +10 to make the origins meet. Manual scrolling only ever
                // *reads* the id, which is why it looked like a bug in the
                // saving rather than in the layout. `contentMargins` is the
                // inset the scroll system itself knows about.
                .contentMargins(10, for: .scrollContent)
                .scrollDismissesKeyboard(.interactively)
                // Two-way: SwiftUI writes the top-most visible row's id as you
                // scroll, and scrolls to it when the value is set on rebuild.
                // That rebuild is exactly what happens on the way back from an
                // entry, which is the whole point.
                .scrollPosition(id: anchorBinding)
            }
        }
    }

    private func filterBanner(_ filter: EntryFilter) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(lcd.accent)
            Text(filter.indicatorText)
                .font(DexFont.mono(20))
                .foregroundStyle(lcd.text)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(lcd.surface)
        .overlay(alignment: .bottom) {
            lcd.surfaceEdge.frame(height: 1)
        }
    }

    private var searchBar: some View {
        // Only when the caller asked — MASTER SEARCH does, because typing is
        // the entire reason that route exists and it used to open with the
        // field dark and one more tap to go. A category list does not: it is
        // there to be browsed, and a keyboard over half of it would be in the
        // way. (AUDIT **L35**)
        //
        // Not on a restored query, either. Coming back to a list you had
        // filtered restores the text (`SearchStateStore`); popping the
        // keyboard up over the results you came back to look at would undo
        // the point of restoring them.
        DexSearchBar(
            text: searchBinding,
            placeholder: searchPlaceholder,
            focusesOnAppear: focusesSearchOnAppear && search.isEmpty
        )
    }

    /// What this listing says it is searching (0.8.0, J).
    ///
    /// **Derived from `categories`, not passed in.** Every one of these screens
    /// is the same view with a different category set, and a `placeholder:`
    /// argument at the call site would be a second statement of something the
    /// screen is already holding — which is how the two call sites in
    /// `VinodexApp` would eventually disagree with the header above them.
    ///
    /// `rawValue` rather than `listTitle`: the grape listing's *title* is
    /// VARIETIES, and the ask names the thing rather than the shelf ("search
    /// grapes"). It is also the word the main-menu tile the player just pressed
    /// is labelled with, which is the string they are most likely to be holding.
    ///
    /// The multi-category case is the world search — continents, regions and
    /// country rows in one list — and it takes the globe's own wording, so the
    /// `DexSearchBarButton` on `RetroGlobeScreen` and the live field it opens
    /// read as the same control rather than as two.
    private var searchPlaceholder: String {
        guard categories.count == 1, let only = categories.first else { return "SEARCH WORLD…" }
        return "SEARCH \(only.rawValue)…"
    }

    // MARK: Chip rows (0.6.9, I3)
    //
    // **Filter chips on a category listing, not just in TOOLS.** The chip
    // filter has existed since v0.5.9, but only as its own destination under
    // TOOLS — so narrowing the varieties list meant leaving it, opening a
    // different screen, turning the TYPE row down to GRAPES, and rebuilding by
    // hand the listing you were already looking at. I3 puts the rows where the
    // list is.
    //
    // Deliberately **not** a second implementation. The chips are `DexHeroChip`
    // (J1) over `ChipFilter`, so the filter grammar, the palette and the three
    // chip states are the ones `ChipFilterScreen` uses; what is different here
    // is only *which facets are offered* and that the result set is this
    // listing's rather than the whole catalog's.
    //
    // The facets are the caller's choice rather than `ChipFacet.allCases`,
    // because "grape-only chips" is the instruction: a varieties listing is
    // already one category, so TYPE would be a row with one live value, and
    // CLIMATE is regions-only and would empty the list on any tap. See
    // `DexRoute` for what the varieties scan passes.

    /// The way into the chips — the same dropdown header `ChipFilterScreen`
    /// uses, so the control reads the same in both places. Folded by default:
    /// the list is the subject, and three rows of chips above it unasked-for
    /// would bury the first result.
    private var chipDropdown: some View {
        let active = chips.count

        return Button {
            Haptics.select()
            withAnimation(.easeOut(duration: 0.2)) { showsChips.toggle() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(lcd.accent)
                Text("FILTER")
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                if active > 0 {
                    Text("\(active) ON")
                        .font(DexFont.retro(10))
                        .foregroundStyle(lcd.isLight ? .white : .black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(lcd.accent))
                }
                Spacer(minLength: 0)
                if active > 0 {
                    // Reachable with the rows folded away, which is the state a
                    // filtered list is most likely to be left in.
                    Text("RESET")
                        .font(DexFont.retro(10))
                        .tracking(1)
                        .foregroundStyle(Dex.red500)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Dex.red500.opacity(0.55), lineWidth: 2)
                        )
                        // Its own target inside the header's, so tapping RESET
                        // clears rather than folding.
                        .onTapGesture {
                            Haptics.select()
                            chips.clear()
                        }
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(lcd.subtext)
                    .rotationEffect(.degrees(showsChips ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .accessibilityLabel("Filter, \(active) active, \(showsChips ? "expanded" : "collapsed")")
    }

    private func chipRow(_ facet: ChipFacet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(facet.title)
                .font(DexFont.retro(12))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Scoped to this screen's own tables (0.7.0, H1). On the world
            // search the TYPE row must offer CONTINENTS, REGIONS and COUNTRIES
            // and nothing else — a GRAPES chip there is a control whose only
            // possible effect is to empty the list.
            ChipFlow(spacing: 8) {
                ForEach(
                    ChipFilter.options(
                        for: facet,
                        in: categories,
                        includingCountries: showsCountries
                    )
                ) { option in
                    DexHeroChip(
                        label: option.label,
                        chip: db.palette.filterChip(option),
                        isOn: chips.isOn(option)
                    ) {
                        chips.toggle(option)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(facet.title)
        .accessibilityHint(facet.note)
    }

    // Chips are **not costed here**, unlike `ChipFilterScreen`.
    //
    // That screen prices every chip in every row against the whole catalog on
    // every change and dims the dead ones — three dozen chips × 405 entries,
    // paid once per tap. It is worth it there because the count *is* the
    // screen's subject. Here the list itself is the answer, it is one category
    // rather than five, and the same pass would run on a screen whose job is to
    // show rows. A grape facet cannot produce a dead chip on a grapes listing
    // anyway: every value in COLOUR, BODY and RARITY has grapes under it, so
    // `DexHeroChip.isDead` is left at its default.

    /// A country result, in the entry-tile shape — same well size, spacing,
    /// chevron and minimum height as `EntryTileView`, so a country reads as
    /// one more row in the results rather than a different kind of thing.
    private func countryRow(_ name: String) -> some View {
        Button {
            Haptics.select()
            onSelectCountry(name)
        } label: {
            HStack(spacing: 12) {
                // Rectangular, not the square entry well (v0.5.8, D4): a
                // cropped-square flag stops looking like a flag. Same swatch
                // size as the saved screen's place rows.
                FlagSwatch(db: db, country: name, width: 60, height: 38)
                VStack(alignment: .leading, spacing: 6) {
                    Text(name.uppercased())
                        .font(DexFont.retro(13))
                        .foregroundStyle(lcd.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    ChipView(
                        label: "COUNTRY",
                        chip: Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Dex.stone600)
            }
            .padding(8)
            .frame(minHeight: 72)
            .background(lcd.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(lcd.surfaceEdge, lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        // A stable, entry-safe scroll identity.
        .id("__country__\(name)")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(Dex.red500)
            Text("NO DATA FOUND")
                .font(DexFont.retro(11))
                .foregroundStyle(Dex.red500)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .opacity(0.6)
    }
}
#endif
