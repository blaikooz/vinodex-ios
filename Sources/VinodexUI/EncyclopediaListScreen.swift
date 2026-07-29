#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The scrolling entry list, with an optional filter banner and search bar.
public struct EncyclopediaListScreen: View {
    let categories: Set<EntryCategory>
    let filter: EntryFilter?
    let showsSearch: Bool
    let onSelect: (WineEntry) -> Void

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
        onSelect: @escaping (WineEntry) -> Void
    ) {
        self.categories = categories
        self.filter = filter
        self.showsSearch = showsSearch
        self.onSelect = onSelect
    }

    /// Recomputed only when the query actually changes.
    ///
    /// This was a computed property, so every keystroke *and* every unrelated
    /// re-render re-filtered and re-sorted all 284 entries — which is why
    /// master search, the one screen with every category selected, was slow to
    /// appear. `task(id:)` runs it once per query instead.
    @State private var results: [WineEntry] = []

    private func recompute() {
        results = db.entries.apply(
            EntryQuery(categories: categories, filter: filter, search: search)
        )
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

                        if results.isEmpty {
                            emptyState
                        } else {
                            ForEach(results) { entry in
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
                    // Pairs with `scrollPosition(id:)` below — without it the
                    // scroll view has no per-subview geometry to report or to
                    // scroll to, and the binding stays nil forever.
                    .scrollTargetLayout()
                    .padding(10)
                }
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
                .foregroundStyle(Dex.green)
            Text(filter.indicatorText)
                .font(DexFont.mono(20))
                .foregroundStyle(Dex.stone200)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Dex.stone800)
        .overlay(alignment: .bottom) {
            Dex.stone700.frame(height: 1)
        }
    }

    private var searchBar: some View {
        DexSearchBar(text: searchBinding)
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
