#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The scrolling entry list, with an optional filter banner and search bar.
public struct EncyclopediaListScreen: View {
    let categories: Set<EntryCategory>
    let filter: EntryFilter?
    let showsSearch: Bool
    let onSelect: (WineEntry) -> Void

    @State private var search = ""
    @State private var access = AccessStore.shared
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    private let db = WineDatabase.shared

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

    private var results: [WineEntry] {
        db.entries.apply(EntryQuery(categories: categories, filter: filter, search: search))
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let filter {
                filterBanner(filter)
            }

            ZStack {
                DexScreenBackground()

                ScrollView {
                    VStack(spacing: 8) {
                        if showsSearch {
                            searchBar
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
                    .padding(10)
                }
                .scrollDismissesKeyboard(.interactively)
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Dex.green500)
            DexSearchField(text: $search)
                .frame(height: 34)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(Capsule().fill(lcd.well))
        .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
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
