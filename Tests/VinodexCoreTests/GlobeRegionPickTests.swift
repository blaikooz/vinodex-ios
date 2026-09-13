import Testing
import Foundation
@testable import VinodexCore

/// The two decisions the globe makes about the catalog, over the shipped data.
///
/// Both were written after a bug and neither was pinned by anything: the globe
/// opened an empty page for the United States for the whole of 0.9.55, and a
/// painted region answered with an appellation inside it rather than itself.
/// A regenerated atlas or a renamed entry reopens either silently, which is
/// exactly the kind of thing a test is for.
@Suite("Globe to catalog")
struct GlobeRegionPickTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func globeIndex() throws -> GlobeIndex {
        let url = Self.root.appendingPathComponent(
            "Sources/VinodexUI/Resources/Maps/globe-meta.json")
        return try GlobeIndex(meta: Data(contentsOf: url))
    }

    private func catalogCountries() throws -> Set<String> {
        let url = Self.root.appendingPathComponent(
            "Sources/VinodexCore/Resources/countries.json")
        let decoded = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return Set((decoded as? [String: Any] ?? [:]).keys)
    }

    /// The one that matters: every country the globe can name has to resolve to
    /// a country the catalog holds. A thirty-first country whose Natural Earth
    /// spelling differs would otherwise reopen the empty-page bug in silence.
    @Test("every globe country resolves to a catalog country")
    func everyCountryResolves() throws {
        let index = try globeIndex()
        let catalog = try catalogCountries()
        #expect(!catalog.isEmpty)
        for country in index.countries {
            let resolved = GlobeIndex.catalogName(for: country.admin)
            #expect(catalog.contains(resolved),
                    "\(country.admin) resolves to \(resolved), which the catalog does not hold")
        }
    }

    /// The correction itself, so removing the table fails here rather than on a
    /// country page somebody opens.
    @Test("the atlas spelling of the United States is corrected")
    func unitedStates() {
        #expect(GlobeIndex.catalogName(for: "United States of America") == "USA")
        // Everything else passes through untouched.
        #expect(GlobeIndex.catalogName(for: "Italy") == "Italy")
        #expect(GlobeIndex.catalogName(for: "New Zealand") == "New Zealand")
    }

    private func map(_ key: String) throws -> RegionMap {
        let dir = Self.root.appendingPathComponent("Sources/VinodexUI/Resources/Maps/\(key)")
        return try RegionMap(
            manifest: Data(contentsOf: dir.appendingPathComponent("\(key)-manifest.json")),
            index: Data(contentsOf: dir.appendingPathComponent("\(key)-region-index.json"))
        )
    }

    /// A painted region answers with itself, not with what is inside it.
    ///
    /// The names are given in the order the catalog holds them, because that
    /// order is the whole hazard: a first-mapped fallback picks whatever
    /// happens to be first, and for `southwest` that is Gaillac.
    @Test("a region's own entry wins over the appellations inside it")
    func regionOverAppellation() throws {
        let italy = try map("italy")
        #expect(italy.primaryEntryID(for: "veneto", names: [
            ("R023", "Veneto"), ("R071", "Valpolicella"),
        ]) == "R023")
        #expect(italy.primaryEntryID(for: "sicily", names: [
            ("R024", "Sicily"), ("R073", "Etna"),
        ]) == "R024")

        // Exact match fails here — "SOUTH WEST" is not "South West France" —
        // and the first entry is an appellation. The contains step is what
        // stops this picking Gaillac.
        let france = try map("france")
        #expect(france.primaryEntryID(for: "southwest", names: [
            ("R1", "Gaillac"), ("R2", "Cahors"),
            ("R3", "South West France"), ("R4", "Jurançon"),
        ]) == "R3")
    }

    /// Diacritics must not decide it: the catalog writes Rhône with the
    /// circumflex and the map's display name does not have to.
    @Test("the match ignores accents and case")
    func foldsDiacritics() throws {
        let france = try map("france")
        let picked = france.primaryEntryID(for: "rhone", names: [
            ("A", "Côte-Rôtie"), ("B", "Rhône Valley"),
        ])
        #expect(picked == "B")
    }

    /// Where nothing is named after the region, the first mapped entry stands
    /// in — a region still leads somewhere rather than reading as empty — and
    /// where nothing is mapped at all the answer is nothing.
    @Test("no name match falls back, no entries answers nothing")
    func fallbacks() throws {
        let italy = try map("italy")
        #expect(italy.primaryEntryID(for: "veneto", names: [("X", "Soave")]) == "X")
        #expect(italy.primaryEntryID(for: "veneto", names: []) == nil)
    }

    /// **The fallback has to admit that it is one** (0.9.58).
    ///
    /// Standing in is a fine way to choose a destination and a terrible way to
    /// choose a name. On the device, California — a painted state with six
    /// AVAs in the catalog and no page of its own — raised a tile reading NAPA
    /// VALLEY, because the fallback's answer was presented as the thing that
    /// had been tapped. `isOwnEntry` separates "this entry IS the area" from
    /// "this entry is merely inside it", and the card says so either way.
    @Test("a stand-in entry is marked as one, and a real one is not")
    func ownEntryIsDistinguished() throws {
        let usa = try map("usa")
        // The six the map actually carries under `california`. Not one of them
        // is named California, and none of them should claim to be.
        let california = usa.primaryEntry(for: "california", names: [
            ("R013", "Napa Valley"), ("R014", "Sonoma"), ("R016", "Paso Robles"),
            ("R018", "Santa Barbara"), ("R020", "Lodi"), ("R123", "San Benito"),
        ])
        #expect(california?.id == "R013")
        #expect(california?.isOwnEntry == false, "Napa Valley is not California")

        // Both matching steps are the area itself, exact and longer-spelled.
        let italy = try map("italy")
        #expect(italy.primaryEntry(for: "veneto", names: [
            ("R023", "Veneto"), ("R071", "Valpolicella"),
        ])?.isOwnEntry == true)
        let france = try map("france")
        #expect(france.primaryEntry(for: "southwest", names: [
            ("R1", "Gaillac"), ("R3", "South West France"),
        ])?.isOwnEntry == true)

        #expect(usa.primaryEntry(for: "california", names: []) == nil)
    }

    /// Which painted areas have no page of their own, named. Ten areas carry
    /// more than one catalog entry and most of them are still a place — the
    /// interesting set is the ones that are not, because those are the taps
    /// that used to be renamed after their contents.
    @Test("the USA map paints states, and the catalog has no state pages")
    func usaPaintsStates() throws {
        let usa = try map("usa")
        let stems = Set(usa.regions.map(\.id))
        #expect(stems == ["california", "oregon", "washington", "newyork"],
                "the USA map's painted areas changed: \(stems.sorted())")
        // Six AVAs under one state. When state pages arrive this count moves
        // to the state and this test is where that shows up.
        #expect(usa.regionIDs(for: "california").count == 6)
        #expect(usa.regionIDs(for: "oregon").count == 1)
    }
}
