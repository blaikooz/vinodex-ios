import Testing
import Foundation
@testable import VinodexCore

/// Coverage for the continent info screen's data: the `CONTINENTS` category
/// brought back into scope for `ContinentScreen`, and the `WineDatabase`
/// helpers it relies on (`continentEntry(_:)`, `hasRegions(inCountry:)`).
@Suite("Continent screen data")
struct ContinentTests {
    let db = WineDatabase.shared

    @Test("database includes exactly the six continents")
    func continentCount() {
        #expect(db.entries(in: .continents).count == 6)
    }

    @Test("every continent has a description and a non-empty country list")
    func continentContent() {
        for entry in db.entries(in: .continents) {
            guard case .continent(let c) = entry else {
                Issue.record("\(entry.id) is in .continents but not a .continent case")
                continue
            }
            #expect(!c.common.description.isEmpty, "\(c.common.name) has no INFO description")
            #expect(!c.details.keyRegions.isEmpty, "\(c.common.name) has no countries listed")
        }
    }

    @Test("every Continent enum case resolves to its CONT_ entry", arguments: Continent.allCases)
    func continentLookup(_ continent: Continent) {
        let entry = db.continentEntry(continent)
        #expect(entry != nil, "no CONT_\(continent.rawValue) entry in the dataset")
        #expect(entry?.id == "CONT_\(continent.rawValue)")
    }

    @Test("a continent's destination opens the continent screen, not the generic detail screen")
    func destinationRoute() throws {
        let europe = try #require(db.continentEntry(.europe))
        let route = WineEntry.continent(europe).destination
        guard case .continent(let id) = route else {
            Issue.record("expected .continent route, got \(route)")
            return
        }
        #expect(id == europe.id)
    }

    /// France backs several regions in the starter selection (Bordeaux,
    /// Burgundy, Champagne, ...) so its country row should be tappable.
    @Test("hasRegions is true for a country with regions in the selection")
    func hasRegionsTrue() {
        #expect(db.hasRegions(inCountry: "France"))
        // Case-insensitivity matters: continent country names and region
        // origins are both hand-authored strings.
        #expect(db.hasRegions(inCountry: "france"))
    }

    /// Egypt appears in no region's origin anywhere in the starter selection —
    /// its row (were it ever listed) would render greyed and inert, matching
    /// `isLinkable` in the web app.
    @Test("hasRegions is false for a country with no regions in the selection")
    func hasRegionsFalse() {
        #expect(!db.hasRegions(inCountry: "Egypt"))
    }

    /// Guards against a continent listing a country whose name can never
    /// resolve because it doesn't match how region origins spell it.
    @Test("every continent has at least one tappable (region-backed) country")
    func continentsHaveAtLeastOneLinkableCountry() {
        for entry in db.entries(in: .continents) {
            guard case .continent(let c) = entry else { continue }
            let linkable = c.details.keyRegions.contains { db.hasRegions(inCountry: $0) }
            #expect(linkable, "\(c.common.name) has no country whose regions are in the selection")
        }
    }
}
