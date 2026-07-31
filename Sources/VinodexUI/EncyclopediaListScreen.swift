#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The scrolling entry list, with an optional filter banner and search bar.
public struct EncyclopediaListScreen: View {
    let categories: Set<EntryCategory>
    let filter: EntryFilter?
    let showsSearch: Bool
    /// Whether country rows join the results (v0.5.6). Countries are not
    /// entries — their pages are assembled from regions — so master and
    /// world search list them explicitly rather than through the query.
    let showsCountries: Bool
    let onSelect: (WineEntry) -> Void
    let onSelectCountry: (String) -> Void

    /// Held outside the view, so it survives the screen being torn down and
    /// rebuilt when you open an entry and come back — see `SearchStateStore`.
    @State private var searches = SearchStateStore.shared
    @State private var access = AccessStore.shared
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    private let db = WineDatabase.shared

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

    /// Where the list was scrolled to, held in the same store as the query so
    /// the two are restored together and dropped together.
    private var anchorBinding: Binding<String?> {
        Binding(
            get: { searches.anchor(for: searchKey) },
            set: { searches.setAnchor($0, for: searchKey) }
        )
    }

    public init(
        categories: Set<EntryCategory>,
        filter: EntryFilter? = nil,
        showsSearch: Bool = true,
        showsCountries: Bool = false,
        onSelect: @escaping (WineEntry) -> Void,
        onSelectCountry: @escaping (String) -> Void = { _ in }
    ) {
        self.categories = categories
        self.filter = filter
        self.showsSearch = showsSearch
        self.showsCountries = showsCountries
        self.onSelect = onSelect
        self.onSelectCountry = onSelectCountry
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

    private func recompute() {
        let entries = db.entries.apply(
            EntryQuery(categories: categories, filter: filter, search: search)
        ).map(SearchRow.entry)
        let countries = showsCountries
            ? db.countries(matching: search).map(SearchRow.country)
            : []
        rows = (entries + countries).sorted {
            $0.sortName.localizedCaseInsensitiveCompare($1.sortName) == .orderedAscending
        }
    }

    /// `task(id:)` alone covers first appearance. The `onAppear` that used to sit
    /// alongside it made the screen build its entire row tree twice on entry —
    /// `onAppear` filled `results`, then the initial `task` reassigned it, and a
    /// `@State` assignment invalidates whether or not the value changed.
    public var body: some View {
        content
            .task(id: search) { recompute() }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let filter {
                filterBanner(filter)
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

                        if rows.isEmpty {
                            // An empty list with an empty query cannot be a
                            // no-results message — if the database also reported
                            // load errors, say so instead of letting a broken
                            // build read like a search that found nothing.
                            // (0.6.3, item 1 — AUDIT M2)
                            if !db.decodeErrors.isEmpty && search.isEmpty {
                                dataLoadErrorState
                            } else {
                                emptyState
                            }
                        } else {
                            ForEach(rows) { row in
                                switch row {
                                case .country(let country):
                                    countryRow(country)
                                case .entry(let entry):
                                    EntryTileView(
                                        entry: entry,
                                        palette: db.palette,
                                        locked: access.isLocked(entry, in: db)
                                    ) {
                                        onSelect(entry)
                                    }
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
        DexSearchBar(text: searchBinding)
    }

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
                FlagSwatch(country: name, width: 60, height: 38)
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

    /// The truth when the database itself failed to load (0.6.3, item 1 —
    /// AUDIT M2). "NO DATA FOUND" reads as a no-results message, which sent
    /// anyone hitting a broken build hunting for a typo in their search; the
    /// detail lives in the DEV panel, and this points there.
    private var dataLoadErrorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Dex.red500)
            Text("DATA LOAD ERROR")
                .font(DexFont.retro(11))
                .foregroundStyle(Dex.red500)
            Text("The wine database failed to load. See SETTINGS > DEV for details.")
                .font(DexFont.mono(16))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
#endif
