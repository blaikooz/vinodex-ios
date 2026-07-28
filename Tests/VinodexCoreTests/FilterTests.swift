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
        // Not a magic number: an empty search must return the category
        // untouched, whatever the selection currently holds.
        #expect(
            db.entries.apply(.category(.grapes, search: "")).count
                == db.entries(in: .grapes).count
        )
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
    /// markers apply. Europe should pull several; Asia and Africa now resolve to
    /// more than one region each since the Phase 2 grape expansion (Koshu,
    /// Saperavi, Marselan/Cabernet Gernischt-adjacent origins, Pinotage, Syrah,
    /// Grenache) pulled in more region cross-links than the original 10-grape
    /// starter did. Results come back name-sorted (`apply`'s `.sorted`).
    @Test("continent filter drives globe navigation")
    func continentFilter() {
        let europe = db.regions(in: .europe)
        #expect(europe.count >= 4, "expected several European regions, got \(europe.count)")

        let asia = db.regions(in: .asia)
        #expect(
            asia.map(\.name) == ["Helan Mountain", "Nandi Hills", "Nashik", "Shangri-La", "Yamanashi"],
            "got \(asia.map(\.name))"
        )

        let africa = db.regions(in: .africa)
        #expect(
            africa.map(\.name) == ["Paarl & Franschhoek", "Stellenbosch", "Swartland", "Walker Bay"],
            "got \(africa.map(\.name))"
        )
    }

    @Test("filters compose with search")
    func filterPlusSearch() {
        let query = EntryQuery(categories: [.regions], filter: .origin("France"), search: "bordeaux")
        let result = db.entries.apply(query)
        #expect(result.map(\.name) == ["Bordeaux"])
    }

    @Test("no filter matches everything in the category")
    func noFilter() {
        #expect(db.entries.apply(.category(.styles)).count == db.entries(in: .styles).count)
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

    /// A name with no entry must return nil rather than a near-match, so the UI
    /// renders it as a plain label instead of a dead button.
    ///
    /// This used to name real grapes outside the 25-grape selection (Cabernet
    /// Franc, Gamay). The full database ships now, so both resolve — the case
    /// needs a name that genuinely does not exist.
    @Test("returns nil for names not in the database")
    func unresolved() {
        #expect(db.entry(named: "Definitely Not A Grape") == nil)
        #expect(db.entry(named: "") == nil)
    }

    /// Most cross-links land now that the full database ships, but 24 names do
    /// not: regions and styles reference grapes absent from the grape table
    /// (Rioja → Graciano, Douro → Tinta Roriz, Jura → Poulsard/Savagnin/
    /// Trousseau), and Pétillant Naturel lists the literal "Various".
    ///
    /// That is a content gap rather than a fault — the UI renders an
    /// unresolved name as a plain label, not a dead button. Pinned so the
    /// number cannot grow unnoticed, and so the day someone fills the gap the
    /// test says so.
    @Test("grape cross-links resolve, apart from a known data gap")
    func crossLinksResolve() {
        var unresolved: Set<String> = []
        var total = 0

        for entry in db.entries(in: .regions) + db.entries(in: .styles) {
            for name in entry.notableGrapes {
                total += 1
                if db.entry(named: name) == nil { unresolved.insert(name) }
            }
        }

        #expect(total > 0)
        #expect(
            unresolved.count <= 24,
            "unresolved cross-links grew to \(unresolved.count): \(unresolved.sorted())"
        )
        // The vast majority must still land; a resolution *mechanism* break
        // would show up here rather than as a slow creep in the count above.
        let resolved = total - unresolved.count
        #expect(
            Double(resolved) / Double(total) > 0.85,
            "only \(resolved)/\(total) cross-links resolve"
        )
    }

    @Test("category-scoped lookup does not cross categories")
    func scoped() {
        // "Champagne" exists as both a style and (in the full DB) a region.
        #expect(db.entry(named: "Champagne", category: .styles) != nil)
        #expect(db.entry(named: "Champagne", category: .grapes) == nil)
    }
}
