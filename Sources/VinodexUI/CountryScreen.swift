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
    @State private var showsAllStates = false
    @State private var showsAllGrapes = false
    @State private var showsAllRegions = false
    private let db = WineDatabase.shared

    /// Countries have no entry, so the bookmark key is synthesised. Prefixed so
    /// it can never collide with a real entry id.
    private var bookmarkID: String { "COUNTRY_\(country)" }

    public init(
        country: String,
        onSelectRegion: @escaping (WineEntry) -> Void,
        onSelectState: @escaping (String) -> Void = { _ in }
    ) {
        self.country = country
        self.onSelectRegion = onSelectRegion
        self.onSelectState = onSelectState
    }

    private var regions: [WineEntry] {
        db.entries.apply(EntryQuery(categories: [.regions], filter: .origin(country), search: ""))
    }

    /// States that actually carry regions, in name order. Only the USA has any
    /// in this data, so the section simply does not render elsewhere.
    private var states: [String] {
        var seen: Set<String> = []
        for entry in regions {
            guard case .region(let r) = entry, let state = r.details.state else { continue }
            seen.insert(state)
        }
        return seen.sorted()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                infoSection
                if !states.isEmpty { statesSection }
                if !notableGrapes.isEmpty { grapesSection }
                if !appellations.isEmpty { appellationsSection }
                regionsSection
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 72)
        }
        .background(Color.black)
        .id(country)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            FlagSwatch(country: country)
                .frame(width: 96, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.black.opacity(0.35), lineWidth: 2)
                )

            Text(country.uppercased())
                .font(DexFont.retro(21))
                .foregroundStyle(.white)
                .shadow(color: Color(dexHex: "#006400").opacity(0.8), radius: 0, x: 4, y: 4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            saveButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            ZStack {
                Color(dexHex: "#14532d").opacity(0.1)
                DexGridBackground(spacing: 34, color: Color(dexHex: "#14532d"), opacity: 0.5)
            }
        )
        .overlay(alignment: .bottom) { Color(dexHex: "#166534").frame(height: 4) }
        .padding(.horizontal, -14)
        .padding(.bottom, 16)
    }

    /// Same control as the entry screens, so a country is savable like
    /// anything else.
    private var saveButton: some View {
        let saved = bookmarks.contains(bookmarkID)
        return Button {
            Haptics.select()
            bookmarks.toggle(bookmarkID)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14, weight: .bold))
                Text(saved ? "SAVED" : "SAVE")
                    .font(DexFont.retro(10))
                    .tracking(2)
            }
            .foregroundStyle(saved ? .black : Dex.green)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(saved ? Dex.green : .black.opacity(0.35)))
            .overlay(Capsule().strokeBorder(Dex.green, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.94))
    }

    /// A country has no authored description, so this is assembled from what
    /// its regions actually say — climates, region count, appellation systems.
    /// Stating that plainly beats inventing prose the data cannot support.
    private var infoSection: some View {
        let climates = Set(regions.compactMap(\.climate)).map(\.rawValue).sorted()
        let text = "\(country) holds \(regions.count) region\(regions.count == 1 ? "" : "s") in this database"
            + (climates.isEmpty ? "" : ", across \(climates.joined(separator: ", ")) climates")
            + "."

        return section("INFO", symbol: "book") {
            Text(text)
                .font(DexFont.mono(18))
                .foregroundStyle(Color(dexHex: "#bbf7d0"))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
                .padding(.vertical, 10)
                .background(alignment: .leading) {
                    Color(dexHex: "#15803d").frame(width: 4)
                }
                .background(Color(dexHex: "#14532d").opacity(0.08))
        }
    }

    /// Every grape this country's regions name, deduplicated and ordered by how
    /// often they appear — the ones defining the country come first.
    private var notableGrapes: [String] {
        var counts: [String: Int] = [:]
        for entry in regions {
            for name in entry.notableGrapes { counts[name, default: 0] += 1 }
        }
        return counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.map(\.key)
    }

    /// Resolved to real entries so the section is a list you can open, not a
    /// row of chips that look tappable and are not.
    private var grapeEntries: [WineEntry] {
        notableGrapes.compactMap { db.entry(named: $0, category: .grapes) }
    }

    private var grapesSection: some View {
        let all = grapeEntries
        let shown = showsAllGrapes ? all : Array(all.prefix(3))
        return section("NOTABLE GRAPES", symbol: "list.bullet") {
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
                        showsAllGrapes.toggle()
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
            .foregroundStyle(Dex.green)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(.black))
            .overlay(Capsule().strokeBorder(Dex.stone600, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
    }

    /// Every appellation system in use here.
    private var appellations: [String] {
        var seen: Set<String> = []
        for entry in regions {
            if case .region(let r) = entry, !r.details.classification.isEmpty {
                seen.insert(r.details.classification)
            }
        }
        return seen.sorted()
    }

    private var appellationsSection: some View {
        section("APPELLATION SYSTEMS", symbol: "shield") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(appellations, id: \.self) { system in
                    HStack(alignment: .top, spacing: 8) {
                        ChipView(
                            label: system,
                            chip: db.palette.resolve(
                                TileChip(label: system, key: system, table: .classification)
                            )
                        )
                        Text(EntryDisplay.appellationName(classification: system, country: country))
                            .font(DexFont.mono(17))
                            .foregroundStyle(Dex.stone400)
                            .fixedSize(horizontal: false, vertical: true)
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
        section("STATES", symbol: "map") {
            VStack(spacing: 8) {
                ForEach(visibleStates, id: \.self) { state in
                    Button {
                        Haptics.select()
                        onSelectState(state)
                    } label: {
                        HStack(spacing: 12) {
                            FlagSwatch(country: state)
                                .frame(width: 40, height: 26)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(.black.opacity(0.3), lineWidth: 1)
                                )
                            Text(state.uppercased())
                                .font(DexFont.retro(12))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(regionCount(in: state))")
                                .font(DexFont.mono(18))
                                .foregroundStyle(Dex.stone400)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Dex.stone600)
                        }
                        .padding(10)
                        .background(Dex.stone900)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Dex.stone700, lineWidth: 2)
                        )
                    }
                    .buttonStyle(DexPressStyle(scale: 0.98))
                }

                if states.count > 3 {
                    expander(expanded: showsAllStates, total: states.count) {
                        showsAllStates.toggle()
                    }
                }
            }
        }
    }

    private func regionCount(in state: String) -> Int {
        regions.filter {
            if case .region(let r) = $0 { return r.details.state == state }
            return false
        }.count
    }

    private var regionsSection: some View {
        let all = regions
        let shown = showsAllRegions ? all : Array(all.prefix(3))
        return section("REGIONS", symbol: "mappin.and.ellipse") {
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
                    expander(expanded: showsAllRegions, total: all.count) {
                        showsAllRegions.toggle()
                    }
                }
            }
        }
    }

    private func section<C: View>(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Dex.green)
                Text(title)
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(Dex.green)
            }
            .padding(.bottom, 2)
            .overlay(alignment: .bottom) { Dex.green.opacity(0.4).frame(height: 2) }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 22)
    }
}
#endif
