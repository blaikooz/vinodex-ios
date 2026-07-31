import Testing
import Foundation
@testable import VinodexCore

@MainActor
@Suite("Bookmarks")
struct BookmarkTests {
    /// Each test gets its own suite name so they cannot see each other's keys.
    private func makeStore(_ name: String = UUID().uuidString) -> BookmarkStore {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return BookmarkStore(defaults: defaults)
    }

    @Test("toggle adds then removes")
    func toggleRoundTrip() {
        let store = makeStore()
        #expect(store.isEmpty)

        #expect(store.toggle("G001") == true)
        #expect(store.contains("G001"))
        #expect(store.count == 1)

        #expect(store.toggle("G001") == false)
        #expect(!store.contains("G001"))
        #expect(store.isEmpty)
    }

    @Test("newest saved comes first")
    func newestFirst() {
        let store = makeStore()
        store.toggle("G001")
        store.toggle("G002")
        store.toggle("G003")
        #expect(store.ids == ["G003", "G002", "G001"])
    }

    @Test("survives a reload from the same defaults")
    func persists() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let first = BookmarkStore(defaults: defaults)
        first.toggle("R001")
        first.toggle("S001")

        let second = BookmarkStore(defaults: defaults)
        #expect(second.ids == ["S001", "R001"])
    }

    /// Bookmarks store ids, so a regenerated dataset that drops an entry must
    /// not leave a dead row behind.
    @Test("ids the dataset no longer has are skipped")
    func skipsUnknownIDs() {
        let db = WineDatabase.shared
        let store = makeStore()
        let real = db.entries(in: .grapes).first!

        store.toggle("NOT_A_REAL_ID")
        store.toggle(real.id)

        let resolved = store.entries(in: db)
        #expect(resolved.count == 1)
        #expect(resolved.first?.id == real.id)
    }

    /// Countries and states are saved under prefixed ids because they have no
    /// entry to resolve against. `entries(in:)` compactMaps, so it dropped them
    /// silently — saving a country and opening the saved list showed nothing.
    @Test("countries and states survive the round trip")
    func placesResolve() {
        let db = WineDatabase.shared
        let store = makeStore()
        let grape = db.entries(in: .grapes).first!

        store.toggle(grape.id)
        store.toggle(SavedItem.countryPrefix + "France")
        store.toggle(SavedItem.statePrefix + "Oregon")

        let saved = store.saved(in: db)
        #expect(saved.count == 3, "got \(saved.map(\.displayName))")

        // Newest first.
        guard case .state(let state) = saved[0] else {
            Issue.record("expected a state first, got \(saved[0])")
            return
        }
        #expect(state == "Oregon")

        guard case .country(let country) = saved[1] else {
            Issue.record("expected a country second, got \(saved[1])")
            return
        }
        #expect(country == "France")

        guard case .entry(let entry) = saved[2] else {
            Issue.record("expected an entry third, got \(saved[2])")
            return
        }
        #expect(entry.id == grape.id)

        // `entries(in:)` still returns only the entry-backed ones.
        #expect(store.entries(in: db).count == 1)
    }

    /// The id a place round-trips under has to match what the screens toggle.
    @Test("storageID round-trips")
    func storageIDs() {
        #expect(SavedItem.country("France").storageID == "COUNTRY_France")
        #expect(SavedItem.state("Oregon").storageID == "STATE_Oregon")
    }

    /// An id that is neither an entry nor a place is dropped rather than
    /// rendering as a blank row.
    @Test("stale ids are skipped")
    func staleIDs() {
        let db = WineDatabase.shared
        let store = makeStore()
        store.toggle("NOT_REAL")
        #expect(store.saved(in: db).isEmpty)
    }

    @Test("clear empties the store")
    func clearAll() {
        let store = makeStore()
        store.toggle("G001")
        store.toggle("G002")
        store.removeAll()
        #expect(store.isEmpty)
    }

    // MARK: Shelves

    /// The un-suffixed API *is* the saved shelf — one list, two spellings.
    @Test("the saved facade and the saved shelf are the same list")
    func facadeIsSavedShelf() {
        let store = makeStore()
        store.toggle("G001")
        store.toggle("G002", on: .saved)
        #expect(store.ids == store.ids(on: .saved))
        #expect(store.contains("G001", on: .saved))
        #expect(store.contains("G002"))
        #expect(store.count == store.count(on: .saved))
    }

    @Test("shelves are independent lists under their own keys")
    func shelvesAreIndependent() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let store = BookmarkStore(defaults: defaults)
        store.toggle("G001", on: .saved)
        store.toggle("G002", on: .wantToTry)
        store.toggle("G003", on: .tried)

        #expect(!store.contains("G002", on: .saved))
        #expect(!store.contains("G003", on: .wantToTry))
        #expect(defaults.stringArray(forKey: Shelf.saved.storageKey) == ["G001"])
        #expect(defaults.stringArray(forKey: Shelf.wantToTry.storageKey) == ["G002"])
        #expect(defaults.stringArray(forKey: Shelf.tried.storageKey) == ["G003"])

        // And they come back per shelf on reload.
        let reloaded = BookmarkStore(defaults: defaults)
        #expect(reloaded.ids(on: .tried) == ["G003"])
        #expect(reloaded.ids(on: .wantToTry) == ["G002"])
    }

    /// Trying something is the end of wanting to try it.
    @Test("marking tried takes the entry off the wishlist")
    func triedClearsWant() {
        let store = makeStore()
        store.toggle("G001", on: .wantToTry)
        store.toggle("G001", on: .tried)
        #expect(store.contains("G001", on: .tried))
        #expect(!store.contains("G001", on: .wantToTry))

        // The other direction never fires: wanting does not un-try.
        store.toggle("G002", on: .tried)
        store.toggle("G002", on: .wantToTry)
        #expect(store.contains("G002", on: .tried))
    }

    @Test("ratings round-trip and follow the tried shelf")
    func ratingsFollowTried() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let store = BookmarkStore(defaults: defaults)
        store.toggle("G001", on: .tried)
        store.setRating(TriedRating(rating: 4, note: "Bright cherry.", day: 20000), for: "G001")

        let reloaded = BookmarkStore(defaults: defaults)
        #expect(reloaded.rating(for: "G001") == TriedRating(rating: 4, note: "Bright cherry.", day: 20000))

        // Un-trying prunes the rating — a score for something you now say you
        // haven't drunk is a contradiction on disk.
        reloaded.toggle("G001", on: .tried)
        #expect(reloaded.rating(for: "G001") == nil)
        #expect(BookmarkStore(defaults: defaults).rating(for: "G001") == nil)
    }

    @Test("clearing the tried shelf clears its ratings")
    func clearTriedClearsRatings() {
        let store = makeStore()
        store.toggle("G001", on: .tried)
        store.toggle("G002", on: .tried)
        store.setRating(TriedRating(rating: 5, note: "", day: 1), for: "G001")
        store.removeAll(on: .tried)
        #expect(store.rating(for: "G001") == nil)
        #expect(store.count(on: .tried) == 0)
    }

    @Test("removeEverything empties all shelves and ratings")
    func removeEverythingClearsAll() {
        let store = makeStore()
        store.toggle("G001", on: .saved)
        store.toggle("G002", on: .wantToTry)
        store.toggle("G003", on: .tried)
        store.setRating(TriedRating(rating: 3, note: "", day: 1), for: "G003")

        store.removeEverything()
        for shelf in Shelf.allCases {
            #expect(store.count(on: shelf) == 0, "\(shelf.rawValue)")
        }
        #expect(store.rating(for: "G003") == nil)
    }

    /// The shelves' scope rule: things you can drink a glass of.
    @Test("isTastable covers grapes and styles only")
    func tastableScope() {
        let db = WineDatabase.shared
        for entry in db.entries {
            let expected = entry.category == .grapes || entry.category == .styles
            #expect(entry.isTastable == expected, "\(entry.id)")
        }
    }
}
