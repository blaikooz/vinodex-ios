#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The continent info screen: an INFO blurb plus a COUNTRIES list, each
/// country linking to that country's regions.
///
/// Ported from the web app's `EntryDetail.tsx` `isContinent` branch (there is
/// no separate `ContinentScreen.tsx` — continents render through the generic
/// detail screen there). This native port gives it its own file because the
/// generic `EntryDetailScreen` is driven by the grape/region/style/flavor
/// variants and a continent's layout (globe hero, no header tiles, a country
/// list instead of a linked-entry list) doesn't fit that shape.
///
/// Country rows don't drill into a COUNTRY_GATE screen — that whole feature
/// (states, appellation systems, per-country readouts) is still out of scope.
/// Instead, tapping a country jumps straight to that country's regions, which
/// is the useful destination the web app's country screen would otherwise
/// lead to, using machinery (`EntryFilter.origin`) this port already has.
public struct ContinentScreen: View {
    let continent: ContinentEntry
    let onSelectCountry: (String) -> Void

    private let db = WineDatabase.shared

    public init(continent: ContinentEntry, onSelectCountry: @escaping (String) -> Void) {
        self.continent = continent
        self.onSelectCountry = onSelectCountry
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                if !continent.common.description.isEmpty {
                    infoSection
                }
                countriesSection
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 72)
        }
        .background(Color.black)
    }

    // MARK: Hero
    //
    // Uses the generated glyph, same as every other entry. This was a plain SF
    // Symbol globe on the theory that the rasterised set might be missing, but
    // that made every continent identical here *and* inconsistent with the
    // search rows — and the icons are committed to the bundle, not fetched at
    // runtime, so the hedge was protecting against nothing.

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(dexHex: continent.common.color))
                DexIcon(
                    iconID: WineDatabase.shared.iconID(for: .continent(continent)),
                    size: 44,
                    color: .white
                )
            }
            .frame(width: 80, height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.black.opacity(0.3), lineWidth: 2)
            )

            Text(continent.common.name.uppercased())
                .font(DexFont.retro(21))
                .foregroundStyle(.white)
                .shadow(color: Color(dexHex: "#006400").opacity(0.8), radius: 0, x: 4, y: 4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            ZStack {
                Color(dexHex: "#14532d").opacity(0.1)
                DexGridBackground(spacing: 34, color: Color(dexHex: "#14532d"), opacity: 0.5)
            }
        )
        .overlay(alignment: .bottom) {
            Color(dexHex: "#166534").frame(height: 4)
        }
        .padding(.horizontal, -14)
        .padding(.bottom, 16)
    }

    // MARK: Info

    private var infoSection: some View {
        section("INFO", symbol: "book") {
            Text(continent.common.description)
                .font(DexFont.mono(21))
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

    // MARK: Countries

    @ViewBuilder
    private var countriesSection: some View {
        let countries = continent.details.keyRegions
        if !countries.isEmpty {
            section("COUNTRIES", symbol: "list.bullet") {
                VStack(spacing: 8) {
                    ForEach(countries, id: \.self) { country in
                        countryRow(country)
                    }
                }
            }
        }
    }

    private func countryRow(_ country: String) -> some View {
        let hasRegions = db.hasRegions(inCountry: country)

        return Button {
            guard hasRegions else { return }
            Haptics.select()
            onSelectCountry(country)
        } label: {
            HStack(spacing: 10) {
                FlagSwatch(country: country)

                Text(country.uppercased())
                    .font(DexFont.retro(11))
                    .foregroundStyle(hasRegions ? .white : Dex.stone600)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                if hasRegions {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Dex.stone600)
                }
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Dex.stone900)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(hasRegions ? Dex.stone700 : Dex.stone800, lineWidth: 1)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .disabled(!hasRegions)
    }

    /// Section header: symbol plus label over a green rule, matching
    /// `EntryDetailScreen`'s treatment (duplicated rather than shared — the
    /// two screens' section helpers are small and independently readable).
    private func section<C: View>(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Dex.green500)
                Text(title)
                    .font(DexFont.retro(10))
                    .tracking(1.5)
                    .foregroundStyle(Dex.green500)
                Spacer()
            }
            .padding(.bottom, 5)
            .overlay(alignment: .bottom) {
                Color(dexHex: "#166534").frame(height: 2)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 22)
    }
}
#endif
