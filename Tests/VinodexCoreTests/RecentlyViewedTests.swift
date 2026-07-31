import Testing
import Foundation
@testable import VinodexCore

@MainActor
@Suite("Recently viewed")
struct RecentlyViewedTests {
    /// Each test gets its own suite name so they cannot see each other's keys.
    private func makeStore(_ name: String = UUID().uuidString) -> RecentlyViewedStore {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return RecentlyViewedStore(defaults: defaults)
    }

    @Test("newest visit comes first")
    func newestFirst() {
        let store = makeStore()
        store.record("G001")
        store.record("R001")
        store.record("S001")
        #expect(store.ids == ["S001", "R001", "G001"])
    }

    @Test("a repeat visit moves to the front instead of duplicating")
    func repeatMovesToFront() {
        let store = makeStore()
        store.record("G001")
        store.record("R001")
        store.record("G001")
        #expect(store.ids == ["G001", "R001"])
    }

    @Test("re-recording the front id is a no-op")
    func frontIsStable() {
        let store = makeStore()
        store.record("G001")
        store.record("G001")
        #expect(store.ids == ["G001"])
    }

    @Test("the trail is capped")
    func capped() {
        let store = makeStore()
        for i in 0..<(RecentlyViewedStore.capacity + 5) {
            store.record("E\(i)")
        }
        #expect(store.ids.count == RecentlyViewedStore.capacity)
        // Newest survive, oldest fall off.
        #expect(store.ids.first == "E\(RecentlyViewedStore.capacity + 4)")
        #expect(!store.ids.contains("E0"))
    }

    @Test("survives a reload from the same defaults")
    func persists() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let first = RecentlyViewedStore(defaults: defaults)
        first.record("G001")
        first.record("R001")

        let second = RecentlyViewedStore(defaults: defaults)
        #expect(second.ids == ["R001", "G001"])
    }

    /// Ids are stored, so a regenerated dataset that drops an entry must not
    /// leave a dead tile behind.
    @Test("ids the dataset no longer has are skipped")
    func skipsUnknownIDs() {
        let db = WineDatabase.shared
        let store = makeStore()
        let real = db.entries(in: .grapes).first!

        store.record("NOT_A_REAL_ID")
        store.record(real.id)

        let entries = store.entries(in: db)
        #expect(entries.map(\.id) == [real.id])
    }

    @Test("clear empties the trail and the stored key")
    func clears() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let store = RecentlyViewedStore(defaults: defaults)
        store.record("G001")
        store.clear()
        #expect(store.isEmpty)
        #expect(defaults.stringArray(forKey: RecentlyViewedStore.storageKey) == nil)
    }
}
