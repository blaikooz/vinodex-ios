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
    private let db = WineDatabase.shared

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
                if !states.isEmpty { statesSection }
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

            Text("\(regions.count) REGION\(regions.count == 1 ? "" : "S")")
                .font(DexFont.retro(10))
                .tracking(2)
                .foregroundStyle(Color(dexHex: "#86efac"))
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

    private var statesSection: some View {
        section("STATES", symbol: "map") {
            VStack(spacing: 8) {
                ForEach(states, id: \.self) { state in
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
        section("REGIONS", symbol: "mappin.and.ellipse") {
            VStack(spacing: 8) {
                ForEach(regions) { entry in
                    EntryTileView(
                        entry: entry,
                        palette: db.palette,
                        locked: access.isLocked(entry, in: db)
                    ) {
                        onSelectRegion(entry)
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
