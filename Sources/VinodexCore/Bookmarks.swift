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
    ///
    /// Entry-backed bookmarks only — countries and states are not entries. Use
    /// `saved(in:)` for the whole list.
    public func entries(in db: WineDatabase) -> [WineEntry] {
        ids.compactMap { db.entry(id: $0) }
    }

    /// Everything saved, in save order.
    ///
    /// Countries and states have no entry to resolve against, so they were
    /// being silently dropped by `entries(in:)` — saving one and then opening
    /// the saved list showed nothing. They round-trip through their prefixed
    /// ids instead.
    public func saved(in db: WineDatabase) -> [SavedItem] {
        ids.compactMap { id in
            if let entry = db.entry(id: id) { return .entry(entry) }
            if let name = id.dropPrefix(SavedItem.countryPrefix) { return .country(name) }
            if let name = id.dropPrefix(SavedItem.statePrefix) { return .state(name) }
            // Neither an entry nor a place: a stale id from an older build.
            return nil
        }
    }

    private func persist() {
        defaults.set(ids, forKey: Self.storageKey)
    }
}

/// One row in the saved list. Countries and states are places rather than
/// entries — there is no COUNTRY_GATE data in this port — so they carry only a
/// name, and the UI renders them as flag rows.
public enum SavedItem: Identifiable, Sendable {
    case entry(WineEntry)
    case country(String)
    case state(String)

    public static let countryPrefix = "COUNTRY_"
    public static let statePrefix = "STATE_"

    /// The id this item is stored under.
    public var storageID: String {
        switch self {
        case .entry(let e): e.id
        case .country(let name): Self.countryPrefix + name
        case .state(let name): Self.statePrefix + name
        }
    }

    public var id: String { storageID }

    public var displayName: String {
        switch self {
        case .entry(let e): e.name
        case .country(let name), .state(let name): name
        }
    }
}

private extension String {
    /// The remainder after `prefix`, or nil when it does not match.
    func dropPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
