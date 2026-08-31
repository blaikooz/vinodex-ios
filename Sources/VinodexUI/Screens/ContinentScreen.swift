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

    /// The database this screen reads. Defaulted so no call site changes, but
    /// injectable, which is the whole of **M27**: a screen that hard-reads
    /// `WineDatabase.shared` cannot be put in front of a fixture.
    private let db: WineDatabase
    @State private var bookmarks = BookmarkStore.shared
    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }
    @State private var comingSoon: String?
    /// Scroll position outlives the view — see `ScreenStateStore`.
    @State private var screens = ScreenStateStore.shared

    public init(db: WineDatabase = .shared, continent: ContinentEntry, onSelectCountry: @escaping (String) -> Void) {
        self.db = db
        self.continent = continent
        self.onSelectCountry = onSelectCountry
    }

    private var screenKey: String { ScreenStateStore.continent(continent.id) }

    private enum Anchor {
        static let hero = "hero"
        static let info = "info"
        static let countries = "countries"
    }

    private var anchorBinding: Binding<String?> {
        Binding(
            get: { screens.anchor(for: screenKey) },
            set: { screens.setAnchor($0, for: screenKey) }
        )
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero.id(Anchor.hero)
                if !continent.common.description.isEmpty {
                    infoSection.id(Anchor.info)
                }
                countriesSection.id(Anchor.countries)
            }
            .scrollTargetLayout()
        }
        // Content margins rather than padding around the target layout — see
        // the note in `EncyclopediaListScreen`. The generous tail keeps the
        // last section clear of the footer, matching pb-20.
        .contentMargins(.horizontal, 14, for: .scrollContent)
        .contentMargins(.bottom, 72, for: .scrollContent)
        .scrollPosition(id: anchorBinding)
        .background(lcd.page)
        .overlay {
            if let comingSoon {
                // A deliberately generic notice (0.6.5, item 11 — reversing
                // 0.6.4's teaser-blurb wiring): the popup is a status, not a
                // country page, and the blurb read as one. The authored
                // teasers stay in countries.json for the day the gates open.
                DexAlert(
                    title: "COMING SOON",
                    message: "\(comingSoon.uppercased()) is not in the database yet. Its regions are on the way — check back after an update.",
                    confirmLabel: "OK",
                    cancelLabel: nil,
                    onConfirm: { self.comingSoon = nil },
                    onCancel: { self.comingSoon = nil }
                )
            }
        }
        .animation(DexMotion.overlay, value: comingSoon)
    }

    // MARK: Hero
    //
    // Uses the generated glyph, same as every other entry. This was a plain SF
    // Symbol globe on the theory that the rasterised set might be missing, but
    // that made every continent identical here *and* inconsistent with the
    // search rows — and the icons are committed to the bundle, not fetched at
    // runtime, so the hedge was protecting against nothing.

    private var hero: some View {
        DexHero(title: continent.common.name) {
            EntryIconWell(db: db, entry: .continent(continent), size: DexMetrics.heroWell, cornerRadius: 20)
        } actions: {
            DexSaveButton(id: continent.id, store: bookmarks)
        }
    }

    // MARK: Info

    private var infoSection: some View {
        DexSection("INFO", symbol: "book") {
            Text(continent.common.description)
                .font(DexFont.mono(21))
                .foregroundStyle(lcd.bodyText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
                .padding(.vertical, 10)
                .background(alignment: .leading) {
                    lcd.accent.frame(width: 4)
                }
                .background(lcd.accent.opacity(0.06))
        }
    }

    // MARK: Countries

    @ViewBuilder
    private var countriesSection: some View {
        // **Unwritten countries are off the list (0.9.4).** Through 0.9.3 a
        // country with no regions in the data sat here dimmed, promising
        // COMING SOON — a designed state (0.6.4, batch 2), and still a row
        // that goes nowhere. The first version build lists what it has; the
        // teasers stay authored in countries.json and the dimmed-row
        // treatment below stays built, so the promise costs one filter to
        // bring back when the data lands.
        let countries = continent.details.keyRegions.filter { db.hasRegions(inCountry: $0) }
        if !countries.isEmpty {
            DexSection("COUNTRIES", symbol: "list.bullet") {
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
            Haptics.select()
            if hasRegions {
                onSelectCountry(country)
            } else {
                // Unwritten rather than locked — say so instead of being a
                // dead row that looks identical to a paywalled one.
                comingSoon = country
            }
        } label: {
            HStack(spacing: 10) {
                FlagSwatch(db: db, country: country)

                Text(country.uppercased())
                    .font(DexFont.retro(11))
                    .foregroundStyle(hasRegions ? lcd.text : lcd.disabledText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                // Three distinct states, which used to be two. A country with
                // no regions in the data is *unwritten*, not locked and not
                // broken — it says so in words now (0.6.4, batch 2: the
                // coming-soon gates made this a designed state rather than a
                // gap). The 0.6.2 question mark read as "something is wrong";
                // COMING SOON reads as a promise.
                if hasRegions {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Dex.stone600)
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 10, weight: .bold))
                        Text("COMING SOON")
                            .font(DexFont.retro(10))
                            .tracking(1)
                    }
                    .foregroundStyle(lcd.disabledText)
                    .accessibilityLabel("Coming soon — no entries yet")
                }
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(lcd.surface)
            // The text dims (`disabledText` + the COMING SOON label) but the
            // flag stays at full strength (0.6.5, item 11 — reversing the
            // whole-row dim): the flag is the row's identity, and washing it
            // out read as a missing asset rather than a muted state.
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(hasRegions ? Dex.stone700 : Dex.stone800, lineWidth: 1)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
    }

}
#endif
