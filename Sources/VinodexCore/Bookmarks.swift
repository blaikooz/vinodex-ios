import Foundation
import Observation

/// Saved entries, persisted as a list of entry ids.
///
/// Ids rather than whole entries: the dataset is regenerated regularly, and
/// storing copies would leave bookmarks showing stale text after a data change.
/// An id that no longer resolves is simply dropped on read, which is also how a
/// removed entry cleans itself up.
///
/// `Observable` so SwiftUI views re-render on change, but the type itself is
/// Foundation-only and lives in Core so its behaviour is testable on Linux.
@MainActor
@Observable
public final class BookmarkStore {
    public static let shared = BookmarkStore()

    public static let storageKey = "bookmarkedEntryIDs"

    private let defaults: UserDefaults
    private(set) public var ids: [String]

    /// Injectable for tests; defaults to `.standard` in the app.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.ids = defaults.stringArray(forKey: Self.storageKey) ?? []
    }

    public var isEmpty: Bool { ids.isEmpty }
    public var count: Int { ids.count }

    public func contains(_ id: String) -> Bool { ids.contains(id) }

    /// Most recent first, so the list reads newest-at-top without the caller
    /// having to reverse it.
    @discardableResult
    public func toggle(_ id: String) -> Bool {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
            persist()
            return false
        }
        ids.insert(id, at: 0)
        persist()
        return true
    }

    public func remove(_ id: String) {
        guard let index = ids.firstIndex(of: id) else { return }
        ids.remove(at: index)
        persist()
    }

    public func removeAll() {
        guard !ids.isEmpty else { return }
        ids.removeAll()
        persist()
    }

    /// Bookmarked entries in save order, skipping ids the dataset no longer has.
    public func entries(in db: WineDatabase) -> [WineEntry] {
        ids.compactMap { db.entry(id: $0) }
    }

    private func persist() {
        defaults.set(ids, forKey: Self.storageKey)
    }
}
