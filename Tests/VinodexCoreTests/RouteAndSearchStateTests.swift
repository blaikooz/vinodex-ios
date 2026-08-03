import Testing
import Foundation
@testable import VinodexCore

/// AUDIT M47. `SearchState.swift:87–91` says the storage key is spelled out
/// rather than derived from `indicatorText` or `String(describing:)` precisely
/// so that reworded display copy cannot orphan a stored query. Nothing pinned
/// that, so the next rewording would have done exactly what the comment warns
/// against, silently.
@MainActor
@Suite("Search state persistence")
struct SearchStateTests {
    @Test("every filter case has a stable, spelled-out storage key")
    func storageKeys() {
        #expect(EntryFilter.region(["Spain", "France"]).storageKey == "region:France,Spain")
        #expect(EntryFilter.type("red").storageKey == "type:red")
        #expect(EntryFilter.tasting("SWEET").storageKey == "tasting:SWEET")
        #expect(EntryFilter.flavorSubclass("BERRY").storageKey == "flavorSubclass:BERRY")
        #expect(EntryFilter.soil("Limestone").storageKey == "soil:Limestone")
        #expect(EntryFilter.origin("France").storageKey == "origin:France")
        #expect(EntryFilter.rarity(.noble).storageKey == "rarity:NOBLE")
        #expect(EntryFilter.system("ORIGIN").storageKey == "system:ORIGIN")
        #expect(EntryFilter.climate(.warm).storageKey == "climate:warm")
    }

    /// The invariant the comment names: neither the display copy nor the
    /// compiler's own description may be what gets stored.
    @Test("the storage key is independent of the display copy")
    func keyIsNotDisplayCopy() {
        let filter = EntryFilter.origin("France")
        #expect(filter.indicatorText == "FILTER: REGION FRANCE")
        #expect(filter.scanTitle == "REGION SCAN")
        #expect(filter.storageKey == "origin:France")
        #expect(filter.storageKey != String(describing: filter))
    }

    /// `region` sorts its countries, so a globe filter rebuilt from a
    /// differently ordered country list still finds the same stored query.
    @Test("the region key is order-independent")
    func regionKeyIsSorted() {
        #expect(
            EntryFilter.region(["Italy", "France", "Spain"]).storageKey
                == EntryFilter.region(["Spain", "Italy", "France"]).storageKey
        )
        #expect(WineDatabase.shared.filter(for: .europe).storageKey.hasPrefix("region:"))
    }

    @Test("the listing key sorts its categories and appends the filter")
    func listingKey() {
        #expect(SearchStateStore.key(categories: [.grapes], filter: nil) == "GRAPES")
        // A `Set`'s iteration order is not stable between launches — this is
        // the whole reason `key` sorts.
        #expect(SearchStateStore.key(categories: [.styles, .grapes], filter: nil) == "GRAPES+STYLES")
        #expect(SearchStateStore.key(categories: [.grapes], filter: .type("red")) == "GRAPES|type:red")
        #expect(
            SearchStateStore.key(categories: Set(EntryCategory.allCases), filter: nil)
                == "CONTINENTS+FLAVORS+GRAPES+REGIONS+STYLES"
        )
        // Two listings differing only by filter must not share a key.
        #expect(
            SearchStateStore.key(categories: [.grapes], filter: .type("red"))
                != SearchStateStore.key(categories: [.grapes], filter: .type("white"))
        )
    }

    @Test("queries and anchors round-trip, keyed per listing")
    func roundTrip() {
        let store = SearchStateStore()
        let grapes = SearchStateStore.key(categories: [.grapes], filter: nil)
        let regions = SearchStateStore.key(categories: [.regions], filter: nil)

        #expect(store.isEmpty)
        #expect(store.query(for: grapes) == "")
        #expect(store.anchor(for: grapes) == nil)

        store.setQuery("caber", for: grapes)
        store.setAnchor("G001", for: grapes)
        #expect(store.query(for: grapes) == "caber")
        #expect(store.anchor(for: grapes) == "G001")
        // Carrying one screen's query into another would be its own bug.
        #expect(store.query(for: regions) == "")
    }

    /// A changed query renders the old anchor meaningless — that row may not
    /// even be in the new results, so restoring it scrolls somewhere random
    /// mid-type.
    @Test("editing the query drops the anchor")
    func editingDropsTheAnchor() {
        let store = SearchStateStore()
        let key = SearchStateStore.key(categories: [.grapes], filter: nil)
        store.setQuery("caber", for: key)
        store.setAnchor("G001", for: key)
        store.setQuery("cabern", for: key)
        #expect(store.anchor(for: key) == nil)
        #expect(store.query(for: key) == "cabern")
    }

    @Test("an emptied query is removed rather than stored")
    func emptyQueryIsRemoved() {
        let store = SearchStateStore()
        let key = SearchStateStore.key(categories: [.grapes], filter: nil)
        store.setQuery("caber", for: key)
        #expect(!store.isEmpty)
        store.setQuery("", for: key)
        #expect(store.isEmpty, "clearing a field must cost nothing and isEmpty must mean it")
    }

    /// `clear()` is what the Home button calls — both tables, not just queries.
    @Test("clear empties queries and anchors")
    func clearEmptiesBoth() {
        let store = SearchStateStore()
        store.setQuery("x", for: "a")
        store.setAnchor("y", for: "b")
        #expect(!store.isEmpty)
        store.clear()
        #expect(store.isEmpty)
        #expect(store.query(for: "a") == "")
        #expect(store.anchor(for: "b") == nil)
    }
}

/// AUDIT M47. `DexRoute` is the app's whole navigation vocabulary — pure,
/// non-UI, sitting in Core — and had no test at all. Both computed properties
/// feed the LCD marquee, where a wrong answer is a blank header rather than a
/// crash, so only a walk over every case catches it.
@Suite("Route vocabulary")
struct DexRouteTests {
    private let db = WineDatabase.shared

    @Test("a list route titles itself from its filter, falling back to its category")
    func listTitles() {
        #expect(DexRoute.list(category: .grapes, filter: nil).title == "VARIETIES")
        #expect(DexRoute.list(category: .flavors, filter: nil).title == "FLAVORS")
        #expect(DexRoute.list(category: .grapes, filter: .type("red")).title == "STYLE SCAN")
        #expect(DexRoute.list(category: .regions, filter: .climate(.warm)).title == "CLIMATE SCAN")
        // 0.6.2 D1: a class filter opened from the ORIGIN chip must read
        // "ORIGIN SCAN", not "SYSTEM SCAN".
        #expect(DexRoute.list(category: .styles, filter: .system("ORIGIN")).title == "ORIGIN SCAN")
        #expect(DexRoute.state(name: "California").title == "CALIFORNIA")
    }

    @Test("a settings section route carries the section's own copy and glyph")
    func settingsSectionRoutes() {
        for section in SettingsSection.allCases {
            #expect(DexRoute.settingsSection(section).title == section.rawValue)
            #expect(DexRoute.settingsSection(section).marqueeSymbol == section.symbol)
            #expect(section.id == section.rawValue)
            #expect(!section.symbol.isEmpty)
        }
        // The raw values are display copy, and CUSTOMIZE is the one that had to
        // shrink to fit its square.
        #expect(SettingsSection.customization.rawValue == "CUSTOMIZE")
    }

    /// Both properties are exhaustive switches, so a new case cannot compile
    /// without an answer — but an *empty* answer compiles fine and renders as a
    /// blank marquee. Only the walk catches that.
    @Test("every route has a non-empty title and marquee glyph",
          arguments: DexRouteTests.everyRoute)
    func everyRouteIsLabelled(_ route: DexRoute) {
        #expect(!route.title.isEmpty)
        #expect(!route.marqueeSymbol.isEmpty)
    }

    static let everyRoute: [DexRoute] =
        EntryCategory.allCases.map { .list(category: $0, filter: nil) }
        + SettingsSection.allCases.map { .settingsSection($0) }
        + [
            .masterSearch, .detail(entryID: "G001"), .globe, .globeSearch, .bookmarks,
            .country(name: "France"), .state(name: "California"), .dailyGrape, .scanner,
            .moonDial, .settings, .minigames, .chipFilter, .wsetQuiz, .dailyChallenge,
            .passport, .walkthrough, .continent(entryID: "CONT_EUROPE"),
        ]

    @Test("every category has its own marquee glyph")
    func categoryGlyphsAreDistinct() {
        let glyphs = EntryCategory.allCases.map(\.marqueeSymbol)
        #expect(glyphs.allSatisfy { !$0.isEmpty })
        #expect(Set(glyphs).count == glyphs.count, "two categories share a glyph: \(glyphs)")
    }

    /// The entry-side half of the vocabulary: where a row leads, and what its
    /// detail screen calls itself. `ContinentTests` pins the `.continent`
    /// branch; this pins the other four and the two scan labels.
    @Test("every entry's destination and scan labels match its category")
    func entryVocabulary() throws {
        for category in EntryCategory.allCases {
            let entry = try #require(db.entries(in: category).first,
                                     "no \(category.rawValue) entries in the catalogue")
            #expect(entry.scanSymbol == category.marqueeSymbol)
            #expect(!entry.scanTitle.isEmpty)
            if category == .continents {
                #expect(entry.destination == .continent(entryID: entry.id))
            } else {
                #expect(entry.destination == .detail(entryID: entry.id))
            }
        }
        let grape = try #require(db.entries(in: .grapes).first)
        #expect(grape.scanTitle == "GRAPE SCAN")
    }
}
