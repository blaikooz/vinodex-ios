#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// A country's page, built to the same shape as `ContinentScreen`: flag hero,
/// then the regions it holds.
///
/// Countries have no entry of their own — the web app's COUNTRY_GATE entries
/// are not ported and cannot even be decoded (see `generate.ts`). So this is
/// assembled from the regions that name the country as their origin, which is
/// also why it needs no data change to exist.
public struct CountryScreen: View {
    let country: String
    let onSelectRegion: (WineEntry) -> Void
    let onSelectState: (String) -> Void

    @State private var access = AccessStore.shared
    @State private var bookmarks = BookmarkStore.shared
    /// Expander state and scroll position live outside the view, so they survive
    /// it being torn down and rebuilt on the way back from a region — see
    /// `ScreenStateStore`.
    @State private var screens = ScreenStateStore.shared
    /// The database this screen reads. Defaulted so no call site changes, but
    /// injectable, which is the whole of **M27**: a screen that hard-reads
    /// `WineDatabase.shared` cannot be put in front of a fixture.
    private let db: WineDatabase
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    /// Countries have no entry, so the bookmark key is synthesised. Prefixed so
    /// it can never collide with a real entry id.
    ///
    /// Built through `SavedItem` rather than from a string literal (AUDIT
    /// **L1**): `BookmarkStore.saved(in:)` reads the same ids back through
    /// `SavedItem.countryPrefix`, so a literal here would strand every saved
    /// place the day that prefix changed.
    private var bookmarkID: String { SavedItem.country(country).storageID }

    private var screenKey: String { ScreenStateStore.country(country) }

    /// Section identities, doubling as scroll anchors and as the names of the
    /// expander flags. One set of constants rather than two, since a section
    /// that can be scrolled to is the same section that can be expanded.
    private enum Anchor {
        static let hero = "hero"
        static let info = "info"
        static let states = "states"
        static let grapes = "grapes"
        static let appellations = "appellations"
        static let regions = "regions"
    }

    private var showsAllStates: Bool { screens.isOn(Anchor.states, for: screenKey) }
    private var showsAllGrapes: Bool { screens.isOn(Anchor.grapes, for: screenKey) }
    private var showsAllRegions: Bool { screens.isOn(Anchor.regions, for: screenKey) }

    /// Two-way: SwiftUI writes the top-most visible section as you scroll, and
    /// scrolls back to it when the value is set on rebuild. That rebuild is
    /// exactly what happens on the way back from a region.
    private var anchorBinding: Binding<String?> {
        Binding(
            get: { screens.anchor(for: screenKey) },
            set: { screens.setAnchor($0, for: screenKey) }
        )
    }

    /// Everything derived from the country's regions, resolved once (AUDIT M7).
    ///
    /// These were computed properties, and `regions` ran a full-database
    /// filter — `.origin` normalises the origin and every tag of every entry —
    /// then sorted the survivors. `body` reached it about ten times per pass:
    /// the states section, the grapes section, the appellations fallback, the
    /// regions list, and once more per state row for its count. Resolved in
    /// `init` instead. The page is `.id(country)`-keyed and the database is
    /// immutable for the life of the process, so there is nothing a later pass
    /// could see that this one cannot.
    private let regions: [WineEntry]
    /// States that actually carry regions, in name order. Only the USA has any
    /// in this data, so the section simply does not render elsewhere.
    private let states: [String]
    /// How many regions each state holds — the trailing number on a state row.
    private let regionCounts: [String: Int]
    /// Every grape this country's regions name, deduplicated and ordered by how
    /// often they appear — the ones defining the country come first.
    private let notableGrapes: [String]
    /// The same list resolved to real entries, so the section is something you
    /// can open rather than a row of chips that look tappable and are not.
    private let grapeEntries: [WineEntry]
    /// The country's appellation systems (0.6, A2): the authored canonical
    /// list from `countries.json` when it exists, else the systems its
    /// regions actually carry — the pre-0.6 derivation, kept as the fallback.
    private let appellations: [String]

    public init(
        db: WineDatabase = .shared,
        country: String,
        onSelectRegion: @escaping (WineEntry) -> Void,
        onSelectState: @escaping (String) -> Void = { _ in }
    ) {
        self.db = db
        self.country = country
        self.onSelectRegion = onSelectRegion
        self.onSelectState = onSelectState

        // Everything below reads the *parameter*, not `self.db`: `self` is not
        // fully initialised yet, so the property cannot be read here even
        // though it has just been assigned.
        let regions = db.entries(
            matching: EntryQuery(categories: [.regions], filter: .origin(country), search: "")
        )
        self.regions = regions

        // One walk for all four derivations rather than one walk each.
        var perState: [String: Int] = [:]
        var grapeCounts: [String: Int] = [:]
        var classifications: Set<String> = []
        for entry in regions {
            for name in entry.notableGrapes { grapeCounts[name, default: 0] += 1 }
            guard case .region(let r) = entry else { continue }
            if let state = r.details.state { perState[state, default: 0] += 1 }
            if !r.details.classification.isEmpty {
                classifications.insert(r.details.classification)
            }
        }
        self.regionCounts = perState
        self.states = perState.keys.sorted()

        let ranked = grapeCounts
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .map(\.key)
        self.notableGrapes = ranked
        self.grapeEntries = ranked.compactMap { db.entry(named: $0, category: .grapes) }

        if let system = db.countryInfo(country)?.appellationSystem, !system.isEmpty {
            self.appellations = system
        } else {
            self.appellations = classifications.sorted()
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero.id(Anchor.hero)
                infoSection.id(Anchor.info)
                if !states.isEmpty { statesSection.id(Anchor.states) }
                if !notableGrapes.isEmpty { grapesSection.id(Anchor.grapes) }
                if !appellations.isEmpty { appellationsSection.id(Anchor.appellations) }
                regionsSection.id(Anchor.regions)
            }
            // Pairs with `scrollPosition(id:)` below — without it the scroll
            // view has no per-section geometry to report or to scroll to, and
            // the binding stays nil forever.
            .scrollTargetLayout()
        }
        // Content margins rather than padding around the target layout — see
        // the note in `EncyclopediaListScreen`. The generous tail keeps the
        // last section clear of the footer, matching pb-20.
        .contentMargins(.horizontal, 14, for: .scrollContent)
        .contentMargins(.bottom, 72, for: .scrollContent)
        .scrollPosition(id: anchorBinding)
        .background(lcd.page)
        .id(country)
    }

    private var hero: some View {
        DexHero(title: country) {
            // The flag *is* the hero here — there is no entry icon to carry
            // the page — so it gets hero proportions rather than the row size.
            FlagSwatch(db: db, country: country, width: 168, height: 106)
                .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
        } actions: {
            DexSaveButton(id: bookmarkID, store: bookmarks)
        }
    }

    /// The country blurb, authored in `shared/data/countries.ts` and generated
    /// into `countries.json`.
    ///
    /// A derived caption used to sit under the blurb — "12 REGIONS IN THIS
    /// DATABASE · COOL, MARITIME". It was the last survivor of the days when
    /// that readout *was* the whole section, before there were authored blurbs
    /// to replace it. It describes the app rather than the country, it was the
    /// same sentence with the nouns swapped on all eighteen pages, and the
    /// REGIONS section directly below already shows the count. Gone.
    private var infoSection: some View {
        DexSection("INFO", symbol: "book") {
            VStack(alignment: .leading, spacing: 8) {
                // The blurb alone — the appellation system has its own
                // section below; a chip row here too said it twice (0.6.x).
                if let info = db.countryInfo(country) {
                    Text(info.description)
                        .font(DexFont.mono(18))
                        .foregroundStyle(lcd.bodyText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .background(alignment: .leading) {
                lcd.accent.frame(width: 4)
            }
            .background(lcd.accent.opacity(0.06))
        }
    }

    private var grapesSection: some View {
        let all = grapeEntries
        let shown = showsAllGrapes ? all : Array(all.prefix(3))
        return DexSection("NOTABLE GRAPES", symbol: "list.bullet") {
            VStack(spacing: 8) {
                ForEach(shown) { entry in
                    EntryTileView(
                        entry: entry,
                        palette: db.palette,
                        locked: access.isLocked(entry, in: db)
                    ) {
                        onSelectRegion(entry)
                    }
                }
                if all.count > 3 {
                    expander(expanded: showsAllGrapes, total: all.count) {
                        screens.toggleFlag(Anchor.grapes, for: screenKey)
                    }
                }
            }
        }
    }

    /// Shared show-all control. Every long section here shows three and hides
    /// the rest — with the full database a country can carry a dozen grapes and
    /// as many regions, which buried everything below it.
    private func expander(
        expanded: Bool,
        total: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.select()
            withAnimation(.easeOut(duration: 0.2)) { action() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                Text(expanded ? "SHOW FEWER" : "SHOW ALL (\(total))")
                    .font(DexFont.retro(10))
                    .tracking(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(lcd.accent)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(lcd.well))
            .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
    }

    private var appellationsSection: some View {
        DexSection("APPELLATION SYSTEM", symbol: "shield") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(appellations, id: \.self) { system in
                    let full = EntryDisplay.appellationName(classification: system, country: country)
                    HStack(alignment: .top, spacing: 8) {
                        ChipView(
                            label: system,
                            chip: db.palette.resolve(
                                TileChip(label: system, key: system, table: .classification)
                            )
                        )
                        // The spelled-out form, when there is one — a name
                        // the authored list already writes in full ("Vinho
                        // Regional") would just repeat its own chip.
                        if full != system {
                            Text(full)
                                .font(DexFont.mono(17))
                                .foregroundStyle(lcd.subtext)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    /// Three states, then the rest behind a toggle. USA is the only country
    /// with enough to need it, and an eight-row block above the regions list
    /// pushed the regions themselves off the first screen.
    private var visibleStates: [String] {
        showsAllStates ? states : Array(states.prefix(3))
    }

    private var statesSection: some View {
        DexSection("STATES", symbol: "map") {
            VStack(spacing: 8) {
                ForEach(visibleStates, id: \.self) { state in
                    Button {
                        Haptics.select()
                        onSelectState(state)
                    } label: {
                        HStack(spacing: 12) {
                            FlagSwatch(db: db, country: state, width: 68, height: 44)
                            Text(state.uppercased())
                                .font(DexFont.retro(12))
                                .foregroundStyle(lcd.text)
                            Spacer()
                            Text("\(regionCounts[state] ?? 0)")
                                .font(DexFont.mono(18))
                                .foregroundStyle(lcd.subtext)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Dex.stone600)
                        }
                        .padding(10)
                        .background(lcd.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(lcd.surfaceEdge, lineWidth: 2)
                        )
                    }
                    .buttonStyle(DexPressStyle(scale: 0.98))
                }

                if states.count > 3 {
                    expander(expanded: showsAllStates, total: states.count) {
                        screens.toggleFlag(Anchor.states, for: screenKey)
                    }
                }
            }
        }
    }

    private var regionsSection: some View {
        let all = regions
        let shown = showsAllRegions ? all : Array(all.prefix(3))
        return DexSection("REGIONS", symbol: "mappin.and.ellipse") {
            VStack(spacing: 8) {
                // The same unguarded heading `StateScreen` had (AUDIT **L36**).
                // This one is the more reachable of the two: `CountryScreen` is
                // assembled from whatever regions name the country, so a
                // partial decode failure can empty it outright.
                if all.isEmpty {
                    DexEmptyState(db: db) {
                        DexSectionEmpty(
                            symbol: "mappin.slash",
                            message: "NO REGIONS FOUND"
                        )
                    }
                }
                // One red dot per region, geographically placed where the
                // data carries a `mapPosition` (0.6.x) — see `CountryOutlineMap`.
                CountryOutlineMap(country: country, regions: all)
                    .padding(.bottom, 6)
                ForEach(shown) { entry in
                    EntryTileView(
                        entry: entry,
                        palette: db.palette,
                        locked: access.isLocked(entry, in: db)
                    ) {
                        onSelectRegion(entry)
                    }
                }
                if all.count > 3 {
                    expander(expanded: showsAllRegions, total: all.count) {
                        screens.toggleFlag(Anchor.regions, for: screenKey)
                    }
                }
            }
        }
    }
}
#endif
