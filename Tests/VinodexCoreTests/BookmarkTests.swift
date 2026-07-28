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
}
