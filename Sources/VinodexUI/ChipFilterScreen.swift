#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// Narrow the whole database by tapping chips, with the result count moving
/// under your finger as you do.
///
/// The app already had filtering — every cross-link on an entry pushes a
/// filtered listing — but only ever *one* filter at a time, chosen for you by
/// whatever you tapped. There was no way to ask a question with two clauses in
/// it: full-bodied reds, or noble grapes from a maritime climate. This is that,
/// and it is a tool rather than a screen you land on, which is why it lives
/// under TOOLS.
///
/// Every chip carries the count it would produce **if tapped**, so the filter
/// can be read rather than probed — you can see that adding NOBLE takes you from
/// 40 to 6 before you commit to it, and you can see which chips would take you
/// to nothing at all.
public struct ChipFilterScreen: View {
    let onSelect: (WineEntry) -> Void
    /// Opens a country page — the COUNTRIES pseudo-category's rows are
    /// synthesised here (0.6.2, B3), since countries are not entries.
    let onSelectCountry: (String) -> Void

    /// Survives the trip into an entry and back — see `ScreenStateStore`. A
    /// filter you spent six taps building is exactly the thing that must not be
    /// thrown away because you opened one of its results.
    @State private var filter = ChipFilter()
    /// The search box (v0.5.9, E1). Session-local on purpose, like the
    /// scanner's flavour query: the chips persist across the trip into an
    /// entry, but a half-typed string is scaffolding, not an answer.
    @State private var query = ""
    /// Whether the chip rows are unfolded — see `chipDropdown`.
    @State private var showsChips = false
    @State private var screens = ScreenStateStore.shared
    @State private var access = AccessStore.shared
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    /// The database this screen reads. Defaulted so no call site changes, but
    /// injectable, which is the whole of **M27**: a screen that hard-reads
    /// `WineDatabase.shared` cannot be put in front of a fixture.
    private let db: WineDatabase

    public init(
        db: WineDatabase = .shared,
        onSelect: @escaping (WineEntry) -> Void,
        onSelectCountry: @escaping (String) -> Void = { _ in }
    ) {
        self.db = db
        self.onSelect = onSelect
        self.onSelectCountry = onSelectCountry

        // Restored here rather than in `onAppear`, and the first answer seeded
        // with it. `results` moved into `@State` (AUDIT M5), and a `task`
        // cannot run before the first render — so without this the screen opens
        // on "0 MATCHES / NOTHING MATCHES" and corrects itself a frame later,
        // which on a screen whose whole subject is a live count is exactly the
        // wrong first impression.
        //
        // The `db` read below is the *parameter*, not the property: `self` is
        // not fully initialised until the `State` assignments have all landed.
        let restored = ScreenStateStore.shared
            .decoded(ChipFilter.self, "filter", for: ScreenStateStore.chipFilter) ?? ChipFilter()
        _filter = State(initialValue: restored)
        _results = State(initialValue: db.entriesInDisplayOrder.filter { restored.matches($0) })
        _countryResults = State(
            initialValue: restored.includesCountries ? db.searchableCountries : []
        )
    }

    /// The chip-filtered set, narrowed again by the search box (v0.5.9, E1) —
    /// the summary's count reads off this, so it moves live under both.
    ///
    /// Held in `@State` and recomputed on change rather than computed in `body`
    /// (AUDIT M5). As computed properties these ran on every *body pass*, not
    /// merely every keystroke — and `body` reads `results` three times (the
    /// summary's total, the empty check, the `ForEach`), so one re-render cost
    /// three full filter-and-sort passes over the catalog.
    @State private var results: [WineEntry] = []
    /// Country rows, shown only while the COUNTRIES chip is lit (0.6.2, B3).
    @State private var countryResults: [String] = []
    /// What each chip's badge would read if tapped, costed once per filter
    /// change. This is the screen's real expense: `count(withChip:added:)` is a
    /// full pass over the catalog, and the chip rows hold three dozen chips.
    /// It depends on the chips alone, so typing does not disturb it.
    @State private var chipCounts: [ChipOption: Int] = [:]
    /// The query the last `task` run started from — see `awaitSearchDebounce`.
    @State private var debouncedFrom = ""

    /// Every chip on the screen, in one flat list — the set `chipCounts` costs.
    /// Off the database rather than `static`, since the COUNTRY chips are a
    /// property of the data loaded, not of the type (AUDIT **M27**). Read once
    /// per recompute, which already costs a full catalog pass per chip.
    private var allOptions: [ChipOption] { db.allChipOptions }

    private func recomputeResults() {
        let q = query.trimmingCharacters(in: .whitespaces)
        // One indexed pass (AUDIT M5): `entries(matching:)` walks the
        // pre-sorted list against haystacks folded at load, and the chip
        // predicate rides along on the survivors. The old shape ran the chip
        // filter and then re-folded and re-sorted the result through
        // `apply(.masterSearch(_:))`.
        results = db.entries(matching: .masterSearch(q)).filter { filter.matches($0) }
        countryResults = filter.includesCountries ? db.countries(matching: q) : []
    }

    private func recomputeChipCounts() {
        // Countries are not entries, so their share is added by hand (0.6.2, B3).
        let countryShare = db.searchableCountries.count
        var costed: [ChipOption: Int] = [:]
        costed.reserveCapacity(allOptions.count)
        for option in allOptions {
            costed[option] = db.count(withChip: option, added: filter)
                + (filter.toggling(option).includesCountries ? countryShare : 0)
        }
        chipCounts = costed
    }

    private var anchorBinding: Binding<String?> {
        Binding(
            get: { screens.anchor(for: ScreenStateStore.chipFilter) },
            set: { screens.setAnchor($0, for: ScreenStateStore.chipFilter) }
        )
    }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    summary.id("__summary__")

                    DexSearchBar(text: $query, placeholder: "SEARCH MATCHES…")
                        .id("__search__")

                    chipDropdown.id("__filters__")

                    // Folded away by default (v0.5.9, E1): six facet rows are
                    // a screen and a half of controls, and they buried the
                    // results they drive.
                    if showsChips {
                        ForEach(ChipFacet.allCases) { facet in
                            facetRow(facet).id(facet.rawValue)
                        }
                    }

                    resultsHeader.id("__results__")

                    if results.isEmpty && countryResults.isEmpty {
                        // "NOTHING MATCHES" blames the chips. On a database
                        // that failed to load, nothing matches anything, and
                        // the chips are innocent (AUDIT M2).
                        DexEmptyState(db: db) { emptyState }
                    } else {
                        // Synthesised country rows lead (0.6.2, B3): they are
                        // the few, the entries the many.
                        ForEach(countryResults, id: \.self) { country in
                            countryRow(country)
                        }
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
                .scrollTargetLayout()
            }
            .contentMargins(10, for: .scrollContent)
            .scrollPosition(id: anchorBinding)
        }
        // A chip tap is a discrete act, so it re-costs immediately; typing is a
        // burst, so it is debounced — `task(id:)` cancels the pending run on the
        // next keystroke, filtering once at the end of the burst (AUDIT M5).
        .task(id: filter) {
            recomputeChipCounts()
            recomputeResults()
        }
        .task(id: query) {
            let previous = debouncedFrom
            debouncedFrom = query
            guard await awaitSearchDebounce(from: previous, to: query) else { return }
            recomputeResults()
        }
        .onChange(of: filter) { _, value in
            screens.encode(value.isEmpty ? nil : value, "filter", for: ScreenStateStore.chipFilter)
        }
    }

    // MARK: Summary

    /// The running total, and the way out of a filter that has gone too far.
    private var summary: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(lcd.accent)

            VStack(alignment: .leading, spacing: 3) {
                let total = results.count + countryResults.count
                Text("\(total) MATCH\(total == 1 ? "" : "ES")")
                    .font(DexFont.retro(16))
                    .foregroundStyle(lcd.text)
                Text(filter.isEmpty
                     ? "Tap chips to narrow the database."
                     : "\(filter.count) chip\(filter.count == 1 ? "" : "s") active")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
            }

            Spacer(minLength: 0)

            if !filter.isEmpty {
                Button {
                    Haptics.select()
                    filter.clear()
                } label: {
                    Text("RESET")
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .foregroundStyle(Dex.red500)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Dex.red500.opacity(0.55), lineWidth: 2)
                        )
                }
                .buttonStyle(DexPressStyle(scale: 0.95))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.accent.opacity(0.5), lineWidth: 2)
        )
    }

    // MARK: Chip rows

    /// The way into the chips (v0.5.9, E1): a dropdown header that unfolds
    /// the facet rows in place. The active count rides on the button so a
    /// collapsed filter is still legible at a glance.
    private var chipDropdown: some View {
        Button {
            Haptics.select()
            withAnimation(.easeOut(duration: 0.2)) { showsChips.toggle() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(lcd.accent)
                Text("FILTER CHIPS")
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                if filter.count > 0 {
                    Text("\(filter.count) ON")
                        .font(DexFont.retro(10))
                        .foregroundStyle(chipInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(lcd.accent))
                }
                Spacer(minLength: 0)
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
        .accessibilityLabel(
            "Filter chips, \(filter.count) active, \(showsChips ? "expanded" : "collapsed")"
        )
    }

    private func facetRow(_ facet: ChipFacet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(facet.title)
                .font(DexFont.retro(13))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { lcd.accent.opacity(0.4).frame(height: 2) }

            Text(facet.note)
                .font(DexFont.mono(16))
                .foregroundStyle(lcd.subtext)

            // A wrapping flow rather than a horizontal scroller: a chip you have
            // to scroll sideways to discover is a chip nobody taps, and every
            // row here fits in two lines at most.
            ChipFlow(spacing: 8) {
                ForEach(db.chipOptions(for: facet)) { option in
                    chip(option)
                }
            }
        }
    }

    private func chip(_ option: ChipOption) -> some View {
        let on = filter.isOn(option)
        // What the results would become. For a lit chip that is the count after
        // turning it *off*, which is equally the useful number. Costed once per
        // filter change in `recomputeChipCounts` rather than here, which is
        // inside a `ForEach` inside a body pass (AUDIT M5).
        let costed = chipCounts[option]
        let count = costed ?? 0
        // A chip that leads nowhere is still tappable — it is a fact about the
        // data worth being able to see — but it says so. Keyed off `costed`,
        // not `count`: an uncosted chip is unknown, not dead.
        let dead = !on && costed == 0

        return Button {
            Haptics.select()
            filter.toggle(option)
        } label: {
            HStack(spacing: 7) {
                Text(option.label)
                    .font(DexFont.retro(11))
                    .tracking(0.5)
                Text("\(count)")
                    .font(DexFont.mono(16))
                    .opacity(0.75)
            }
            .foregroundStyle(on ? chipInk : (dead ? lcd.disabledText : lcd.text))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Capsule().fill(on ? lcd.accent : lcd.surface))
            .overlay(
                Capsule().strokeBorder(
                    on ? lcd.accent : (dead ? lcd.surfaceEdge.opacity(0.5) : lcd.surfaceEdge),
                    lineWidth: 2
                )
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.94))
        .accessibilityLabel("\(option.label), \(count) entries")
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    /// Text on a lit chip.
    ///
    /// Not `.white`: in dark mode `lcd.accent` is #4ADE80 mint, and white on
    /// mint is the ~1.8:1 contrast failure already logged against the settings
    /// panel's selected states. Black on mint, white on the deep bottle green
    /// light mode uses.
    private var chipInk: Color { lcd.isLight ? .white : .black }

    // MARK: Results

    private var resultsHeader: some View {
        Text(filter.isEmpty ? "EVERYTHING" : "MATCHES")
            .font(DexFont.retro(14))
            .tracking(2)
            .foregroundStyle(lcd.accent)
            .padding(.top, 6)
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { lcd.accent.opacity(0.45).frame(height: 2) }
    }

    /// A country as a result row: flag, name, chevron — the same furniture
    /// the country lists elsewhere use, opening the same page.
    private func countryRow(_ country: String) -> some View {
        Button {
            Haptics.select()
            onSelectCountry(country)
        } label: {
            HStack(spacing: 12) {
                FlagSwatch(db: db, country: country, width: 52, height: 34)
                Text(country.uppercased())
                    .font(DexFont.retro(13))
                    .foregroundStyle(lcd.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(lcd.subtext)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(lcd.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "circle.slash")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Dex.red500)
            Text("NOTHING MATCHES")
                .font(DexFont.retro(12))
                .tracking(2)
                .foregroundStyle(Dex.red500)
            Text(query.trimmingCharacters(in: .whitespaces).isEmpty
                 ? "Those chips have no overlap. Turn one off."
                 : "Nothing fits the chips and the search together.")
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Wrapping chip row

/// A left-to-right flow that wraps, which `HStack` will not do and `LazyVGrid`
/// only fakes by forcing every cell to one width.
///
/// Chips are all different widths — `RED` against `MEDITERRANEAN` — so a grid
/// either pads the short ones out into buttons with a lot of dead space or
/// truncates the long ones. This is the standard `Layout` implementation of the
/// thing CSS calls `flex-wrap`, and it is about thirty lines.
struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = layout(subviews: subviews, maxWidth: maxWidth)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: maxWidth == .infinity ? rows.map(\.width).max() ?? 0 : maxWidth,
                      height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layout(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                var size = subviews[index].sizeThatFits(.unspecified)
                // See `FlowLayout` in CatalogScreen (AUDIT **M49**): the
                // never-break-on-the-first-chip rule below is right, but it
                // left an over-wide chip placed at its natural width, past the
                // container edge, where the chassis clip hid it. Proposing the
                // row width makes it shrink into the space that exists.
                size.width = min(size.width, bounds.width)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layout(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            // Clamped before the row arithmetic, so a row holding an over-wide
            // chip measures the width it will actually be placed at.
            size.width = min(size.width, maxWidth)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            // Never break on the first chip of a row: a chip wider than the
            // container has to go somewhere, and an empty row followed by an
            // overflowing one is worse than one overflowing row.
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
#endif
