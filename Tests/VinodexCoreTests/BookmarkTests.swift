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

    @Test("clear empties the store")
    func clearAll() {
        let store = makeStore()
        store.toggle("G001")
        store.toggle("G002")
        store.removeAll()
        #expect(store.isEmpty)
    }
}
