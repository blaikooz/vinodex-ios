import Foundation
import Observation

/// The entries most recently opened, newest first (0.6.3, item 3 — the
/// V1-ROADMAP M2 "recently viewed" slot).
///
/// Mirrors `BookmarkStore`'s decisions on purpose, because they are the
/// storage schema this app has already committed to: ids rather than entry
/// copies (a regenerated dataset must not leave stale text behind — an id that
/// no longer resolves is dropped on read), `UserDefaults` at this size, and an
/// injectable defaults so the behaviour is testable on Linux.
///
/// Deliberately a *trail*, not a history: one capped list with each entry
/// appearing once, at its latest position. Recording a repeat visit moves the
/// id to the front rather than duplicating it — twenty rows of the same grape
/// would tell you nothing you did not already know.
@MainActor
@Observable
public final class RecentlyViewedStore {
    public static let shared = RecentlyViewedStore()

    public static let storageKey = SavedDataKey.recentlyViewed.rawValue

    /// Enough to scroll back through a browsing session, small enough that the
    /// strip drawing it stays one glance. Trimmed on write, so lowering it in
    /// a future build self-heals stored lists on the next record.
    public static let capacity = 20

    private let defaults: UserDefaults
    private(set) public var ids: [String]

    /// Injectable for tests; defaults to `.standard` in the app.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ids = []
        reload()
    }

    /// Re-reads from `defaults` after a restore wrote the key behind this
    /// store's back — see `BookmarkStore.reload()` for the full reasoning.
    public func reload() {
        ids = defaults.stringArray(forKey: Self.storageKey) ?? []
    }

    /// Notes a visit. Newest first; a repeat visit moves to the front.
    public func record(_ id: String) {
        var list = ids
        if let index = list.firstIndex(of: id) {
            // Already at the front: nothing would change, and writing anyway
            // would invalidate every observer for a no-op — coming *back* from
            // an entry re-fires the detail screen's record.
            if index == 0 { return }
            list.remove(at: index)
        }
        list.insert(id, at: 0)
        if list.count > Self.capacity {
            list.removeLast(list.count - Self.capacity)
        }
        ids = list
        defaults.set(list, forKey: Self.storageKey)
    }

    /// Recent entries in visit order, skipping ids the dataset no longer has —
    /// the same self-cleaning read as `BookmarkStore.entries(in:)`.
    public func entries(in db: WineDatabase) -> [WineEntry] {
        ids.compactMap { db.entry(id: $0) }
    }

    public var isEmpty: Bool { ids.isEmpty }

    /// CLEAR SAVED DATA's slice of this store.
    public func clear() {
        guard !ids.isEmpty else { return }
        ids = []
        defaults.removeObject(forKey: Self.storageKey)
    }
}
