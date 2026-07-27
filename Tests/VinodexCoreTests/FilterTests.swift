import Testing
import Foundation
@testable import VinodexCore

/// Exercises the ported `EncyclopediaList.tsx` filter predicate.
@Suite("Entry filtering and search")
struct FilterTests {
    let db = WineDatabase.shared

    @Test("search matches name, origin, tags and synonyms")
    func searchFields() {
        let all = db.entries

        #expect(all.apply(.masterSearch("cabernet")).contains { $0.name == "Cabernet Sauvignon" })
        // origin
        #expect(all.apply(.category(.regions, search: "japan")).contains { $0.name == "Yamanashi" })
        // synonym — Napa Valley carries "Napa"
        #expect(all.apply(.category(.regions, search: "napa")).contains { $0.name == "Napa Valley" })
    }

    @Test("search is diacritic-insensitive")
    func diacritics() {
        let all = db.entries
        // Albariño / Rías Baixas both carry diacritics.
        #expect(all.apply(.masterSearch("albarino")).contains { $0.name == "Albariño" })
        #expect(all.apply(.category(.regions, search: "rias")).contains { $0.name == "Rías Baixas" })
    }

    @Test("empty search returns the whole category")
    func emptySearch() {
        #expect(db.entries.apply(.category(.grapes, search: "")).count == 10)
    }

    @Test("results are sorted by name")
    func sorted() {
        let names = db.entries.apply(.category(.grapes)).map(\.name)
        #expect(names == names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    @Test("rarity filter selects only that tier")
    func rarityFilter() {
        let noble = db.entries.apply(.category(.grapes, filter: .rarity(.noble)))
        #expect(!noble.isEmpty)
        #expect(noble.allSatisfy { $0.rarity == .noble })
    }

    @Test("climate filter selects only that climate")
    func climateFilter() {
        let warm = db.entries.apply(.category(.regions, filter: .climate(.warm)))
        #expect(!warm.isEmpty)
        #expect(warm.allSatisfy { $0.climate == .warm })
    }

    @Test("origin filter matches whole terms only")
    func originFilter() {
        let french = db.entries.apply(.category(.regions, filter: .origin("France")))
        #expect(french.contains { $0.name == "Bordeaux" })
        #expect(french.allSatisfy { $0.origin == "France" })
    }

    /// The continent filter is the array form of `.region`, and is what the globe
    /// markers apply. Europe should pull several; Asia exactly Yamanashi.
    @Test("continent filter drives globe navigation")
    func continentFilter() {
        let europe = db.regions(in: .europe)
        #expect(europe.count >= 4, "expected several European regions, got \(europe.count)")

        let asia = db.regions(in: .asia)
        #expect(asia.map(\.name) == ["Yamanashi"], "got \(asia.map(\.name))")

        let africa = db.regions(in: .africa)
        #expect(africa.map(\.name) == ["Stellenbosch"])
    }

    @Test("filters compose with search")
    func filterPlusSearch() {
        let query = EntryQuery(categories: [.regions], filter: .origin("France"), search: "bordeaux")
        let result = db.entries.apply(query)
        #expect(result.map(\.name) == ["Bordeaux"])
    }

    @Test("no filter matches everything in the category")
    func noFilter() {
        #expect(db.entries.apply(.category(.styles)).count == 10)
    }
}

@Suite("Cross-link resolution")
struct CrossLinkTests {
    let db = WineDatabase.shared

    @Test("resolves names that are in the dataset")
    func resolves() {
        #expect(db.entry(named: "Bordeaux") != nil)
        #expect(db.entry(named: "cabernet sauvignon") != nil, "lookup should be case-insensitive")
    }

    /// At starter scale most linked names point outside the selection. Returning
    /// nil is the expected, common path — the UI must render those as
    /// non-tappable labels rather than dead buttons.
    @Test("returns nil for names outside the selection")
    func unresolved() {
        #expect(db.entry(named: "Merlot") == nil)
        #expect(db.entry(named: "Nebbiolo") == nil)
    }

    @Test("Bordeaux lists grapes both inside and outside the selection")
    func mixedLinks() throws {
        let bordeaux = try #require(db.entry(named: "Bordeaux"))
        let linked = bordeaux.notableGrapes
        let resolved = linked.filter { db.entry(named: $0) != nil }
        let unresolved = linked.filter { db.entry(named: $0) == nil }

        #expect(!resolved.isEmpty, "expected at least Cabernet Sauvignon to resolve")
        #expect(!unresolved.isEmpty, "expected Merlot / Cabernet Franc to be unresolved")
    }

    @Test("category-scoped lookup does not cross categories")
    func scoped() {
        // "Champagne" exists as both a style and (in the full DB) a region.
        #expect(db.entry(named: "Champagne", category: .styles) != nil)
        #expect(db.entry(named: "Champagne", category: .grapes) == nil)
    }
}
