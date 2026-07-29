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
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

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
        .background(lcd.page)
        .id(country)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            // The flag *is* the hero here — there is no entry icon to carry the
            // page — so it gets hero proportions rather than the row size.
            FlagSwatch(country: country, width: 168, height: 106)
                .shadow(color: .black.opacity(0.45), radius: 6, y: 3)

            Text(country.uppercased())
                .font(DexFont.retro(21))
                .foregroundStyle(lcd.text)
                .shadow(color: lcd.accent.opacity(0.55), radius: 0, x: 4, y: 4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            saveButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            ZStack {
                lcd.heroWash
                DexGridBackground(spacing: 34, color: Color(dexHex: "#14532d"), opacity: 0.5)
            }
        )
        .overlay(alignment: .bottom) { lcd.accent.frame(height: 4) }
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
            .foregroundStyle(saved ? .white : lcd.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(saved ? lcd.accent : lcd.buttonWell))
            .overlay(Capsule().strokeBorder(lcd.accent, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.94))
    }

    /// The country blurb, plus a one-line readout of what this database holds
    /// for it.
    ///
    /// The prose used to be the readout: "France holds 12 regions in this
    /// database, across cool, maritime, mediterranean climates." That was
    /// honest — a country has no entry here, so there was nothing authored to
    /// show — but it described the *app*, not the country, and it was the same
    /// sentence with the nouns swapped on all eighteen pages. The blurbs are
    /// authored in `shared/data/countries.ts` and generated into
    /// `countries.json`; the derived line stays, demoted to a caption, because
    /// knowing how much of a country is covered is genuinely useful.
    private var infoSection: some View {
        let climates = Set(regions.compactMap(\.climate)).map(\.rawValue).sorted()
        let summary = "\(regions.count) region\(regions.count == 1 ? "" : "s") in this database"
            + (climates.isEmpty ? "" : " · \(climates.joined(separator: ", "))")

        return section("INFO", symbol: "book") {
            VStack(alignment: .leading, spacing: 8) {
                if let info = db.countryInfo(country) {
                    Text(info.description)
                        .font(DexFont.mono(18))
                        .foregroundStyle(lcd.bodyText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(summary.uppercased())
                    .font(DexFont.retro(8))
                    .tracking(1)
                    .foregroundStyle(lcd.accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            .foregroundStyle(lcd.accent)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(lcd.well))
            .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
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
                            FlagSwatch(country: state, width: 68, height: 44)
                            Text(state.uppercased())
                                .font(DexFont.retro(12))
                                .foregroundStyle(lcd.text)
                            Spacer()
                            Text("\(regionCount(in: state))")
                                .font(DexFont.mono(18))
                                .foregroundStyle(Dex.stone400)
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
                    .foregroundStyle(lcd.accent)
                Text(title)
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(lcd.accent)
            }
            .padding(.bottom, 2)
            .overlay(alignment: .bottom) { lcd.accent.opacity(0.4).frame(height: 2) }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 22)
    }
}
#endif
