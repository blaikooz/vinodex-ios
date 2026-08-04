import Foundation
import Observation

/// The three shelves of the user panel. Saved is the reference shelf — the
/// original bookmarks, places included. Want-to-try is the wishlist and tried
/// is the history; both hold only things you can drink a glass of (see
/// `WineEntry.isTastable`), and only tried carries ratings.
public enum Shelf: String, CaseIterable, Sendable {
    case saved
    case wantToTry
    case tried

    /// Per-shelf defaults key. Saved keeps the original key so bookmarks made
    /// before shelves existed survive the upgrade.
    public var storageKey: String {
        switch self {
        case .saved: "bookmarkedEntryIDs"
        case .wantToTry: "wantToTryEntryIDs"
        case .tried: "triedEntryIDs"
        }
    }
}

/// A tried entry's journal line: how much you liked it, one line of why, and
/// the day it was recorded (a `DailyPick.dayIndex`, since that is already the
/// app's date currency).
///
/// Not called "TastingNote" — that name belongs to the flavour chips in
/// `WineEntry`.
public struct TriedRating: Codable, Sendable, Equatable {
    /// 1...5.
    public var rating: Int
    public var note: String
    public var day: Int

    public init(rating: Int, note: String, day: Int) {
        self.rating = rating
        self.note = note
        self.day = day
    }
}

/// Saved entries, persisted as lists of entry ids — one list per shelf.
///
/// Ids rather than whole entries: the dataset is regenerated regularly, and
/// storing copies would leave bookmarks showing stale text after a data change.
/// An id that no longer resolves is simply dropped on read, which is also how a
/// removed entry cleans itself up.
///
/// One store rather than three because the shelves are coupled: marking
/// something tried takes it off the wishlist, and un-trying it takes its
/// rating with it. Split into three singletons, those rules would live in
/// whichever screen remembered to enforce them.
///
/// The un-suffixed API (`contains`, `toggle`, `entries(in:)`, …) is the saved
/// shelf, unchanged from before shelves existed, so existing call sites read
/// exactly as they always did.
///
/// `Observable` so SwiftUI views re-render on change, but the type itself is
/// Foundation-only and lives in Core so its behaviour is testable on Linux.
@MainActor
@Observable
public final class BookmarkStore {
    public static let shared = BookmarkStore()

    public static let storageKey = "bookmarkedEntryIDs"
    /// The tried shelf's rating map, JSON-encoded. A few dozen bytes per
    /// entry, so defaults is proportionate — the avatar's file-based reasoning
    /// does not apply at this size.
    public static let ratingsKey = "triedRatings"
    /// When each tried entry was marked, as a `DailyPick.dayIndex` (0.7.1, D1).
    ///
    /// **Why this is new and not a lookup.** D1 wants entries collected per
    /// day, and until now nothing recorded the day an entry was collected. The
    /// nearest thing was `TriedRating.day` — but a rating is optional (the
    /// prompt has a SKIP), and *editing* one overwrites its `day` with today,
    /// so a graph built on ratings would have shown a sparse, retroactively
    /// wrong history. This records the event itself.
    ///
    /// Written here rather than at the tap site for the same reason the
    /// wishlist coupling is: `toggle(_:on:)` is documented as "the one place
    /// membership changes", so a future second way to mark something tried
    /// gets dated for free.
    public static let triedDaysKey = "triedEntryDays"

    private let defaults: UserDefaults
    /// The saved shelf, by its original name.
    private(set) public var ids: [String]
    private var wantIDs: [String]
    private var triedIDs: [String]
    private var ratings: [String: TriedRating]
    /// Entry id to the day it joined the tried shelf. See `triedDaysKey`.
    private var triedDays: [String: Int]

    /// Injectable for tests; defaults to `.standard` in the app.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ids = defaults.stringArray(forKey: Shelf.saved.storageKey) ?? []
        wantIDs = defaults.stringArray(forKey: Shelf.wantToTry.storageKey) ?? []
        triedIDs = defaults.stringArray(forKey: Shelf.tried.storageKey) ?? []
        if let data = defaults.data(forKey: Self.ratingsKey),
           let decoded = try? JSONDecoder().decode([String: TriedRating].self, from: data) {
            ratings = decoded
        } else {
            ratings = [:]
        }
        if let data = defaults.data(forKey: Self.triedDaysKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            triedDays = decoded
        } else {
            triedDays = [:]
        }
    }

    // MARK: Saved-shelf facade

    public var isEmpty: Bool { ids.isEmpty }
    public var count: Int { ids.count }

    public func contains(_ id: String) -> Bool { contains(id, on: .saved) }

    @discardableResult
    public func toggle(_ id: String) -> Bool { toggle(id, on: .saved) }

    public func remove(_ id: String) { remove(id, on: .saved) }

    public func removeAll() { removeAll(on: .saved) }

    /// Bookmarked entries in save order, skipping ids the dataset no longer has.
    ///
    /// Entry-backed bookmarks only — countries and states are not entries. Use
    /// `saved(in:)` for the whole list.
    public func entries(in db: WineDatabase) -> [WineEntry] { entries(on: .saved, in: db) }

    /// Everything saved, in save order.
    ///
    /// Countries and states have no entry to resolve against, so they were
    /// being silently dropped by `entries(in:)` — saving one and then opening
    /// the saved list showed nothing. They round-trip through their prefixed
    /// ids instead. Places only ever live on the saved shelf.
    public func saved(in db: WineDatabase) -> [SavedItem] {
        ids.compactMap { id in
            if let entry = db.entry(id: id) { return .entry(entry) }
            if let name = id.dropPrefix(SavedItem.countryPrefix) { return .country(name) }
            if let name = id.dropPrefix(SavedItem.statePrefix) { return .state(name) }
            // Neither an entry nor a place: a stale id from an older build.
            return nil
        }
    }

    // MARK: Shelves

    public func ids(on shelf: Shelf) -> [String] {
        switch shelf {
        case .saved: ids
        case .wantToTry: wantIDs
        case .tried: triedIDs
        }
    }

    public func contains(_ id: String, on shelf: Shelf) -> Bool {
        ids(on: shelf).contains(id)
    }

    public func count(on shelf: Shelf) -> Int { ids(on: shelf).count }

    /// Most recent first, so every shelf reads newest-at-top without the
    /// caller having to reverse it.
    ///
    /// Coupling rules live here, at the one place membership changes:
    /// marking tried removes the wishlist row (you no longer *want* to try
    /// it), and un-marking tried drops the rating (a score for something you
    /// now say you haven't drunk is a contradiction on disk).
    @discardableResult
    public func toggle(_ id: String, on shelf: Shelf) -> Bool {
        var list = ids(on: shelf)
        let added: Bool
        if let index = list.firstIndex(of: id) {
            list.remove(at: index)
            added = false
        } else {
            list.insert(id, at: 0)
            added = true
        }
        setIDs(list, on: shelf)

        if shelf == .tried {
            if added {
                if let wantIndex = wantIDs.firstIndex(of: id) {
                    wantIDs.remove(at: wantIndex)
                    persist(.wantToTry)
                }
                recordTriedDay(for: id)
            } else {
                clearRating(for: id)
                clearTriedDay(for: id)
            }
        }
        return added
    }

    public func remove(_ id: String, on shelf: Shelf) {
        var list = ids(on: shelf)
        guard let index = list.firstIndex(of: id) else { return }
        list.remove(at: index)
        setIDs(list, on: shelf)
        if shelf == .tried {
            clearRating(for: id)
            clearTriedDay(for: id)
        }
    }

    public func removeAll(on shelf: Shelf) {
        guard !ids(on: shelf).isEmpty else { return }
        setIDs([], on: shelf)
        if shelf == .tried {
            if !ratings.isEmpty {
                ratings.removeAll()
                persistRatings()
            }
            if !triedDays.isEmpty {
                triedDays.removeAll()
                persistTriedDays()
            }
        }
    }

    /// Shelf entries in save order, skipping ids the dataset no longer has.
    public func entries(on shelf: Shelf, in db: WineDatabase) -> [WineEntry] {
        ids(on: shelf).compactMap { db.entry(id: $0) }
    }

    /// All three shelves and the ratings — CLEAR SAVED DATA's half of this
    /// store.
    public func removeEverything() {
        for shelf in Shelf.allCases { setIDs([], on: shelf) }
        ratings.removeAll()
        persistRatings()
        triedDays.removeAll()
        persistTriedDays()
    }

    // MARK: Tried days (0.7.1, D1)

    /// The day an entry joined the tried shelf, or nil for one marked before
    /// 0.7.1 started keeping the log.
    ///
    /// Nil rather than a guessed date: a back-fill would have to invent one,
    /// and a graph with fifty entries stacked on the day the user installed the
    /// update is a worse lie than a graph that starts today. The activity chart
    /// says so in words — see `Passport.activity`.
    public func triedDay(for id: String) -> Int? { triedDays[id] }

    /// Entries collected per day, keyed by `DailyPick.dayIndex` — D1's series.
    ///
    /// Counts the *log*, not the shelf, so the two cannot drift: an entry with
    /// no recorded day simply is not in the histogram.
    public var triedDayCounts: [Int: Int] {
        triedDays.values.reduce(into: [:]) { counts, day in
            counts[day, default: 0] += 1
        }
    }

    /// The whole log, for `Passport.compute`.
    public var triedDayLog: [String: Int] { triedDays }

    /// First mark wins. Re-marking something you had un-marked writes a new
    /// day, which is correct — you tried it again — but the guard means the
    /// ordinary "toggle twice by accident" does not rewrite history, because
    /// un-marking cleared the entry first.
    private func recordTriedDay(for id: String) {
        triedDays[id] = DailyPick.dayIndex()
        persistTriedDays()
    }

    private func clearTriedDay(for id: String) {
        guard triedDays.removeValue(forKey: id) != nil else { return }
        persistTriedDays()
    }

    private func persistTriedDays() {
        if triedDays.isEmpty {
            defaults.removeObject(forKey: Self.triedDaysKey)
        } else if let data = try? JSONEncoder().encode(triedDays) {
            defaults.set(data, forKey: Self.triedDaysKey)
        }
    }

    // MARK: Ratings

    public func rating(for id: String) -> TriedRating? { ratings[id] }

    /// Sets or clears (nil) the journal line for a tried entry.
    public func setRating(_ rating: TriedRating?, for id: String) {
        if let rating {
            ratings[id] = rating
        } else {
            ratings.removeValue(forKey: id)
        }
        persistRatings()
    }

    private func clearRating(for id: String) {
        guard ratings.removeValue(forKey: id) != nil else { return }
        persistRatings()
    }

    // MARK: Persistence

    private func setIDs(_ new: [String], on shelf: Shelf) {
        switch shelf {
        case .saved: ids = new
        case .wantToTry: wantIDs = new
        case .tried: triedIDs = new
        }
        persist(shelf)
    }

    private func persist(_ shelf: Shelf) {
        defaults.set(ids(on: shelf), forKey: shelf.storageKey)
    }

    private func persistRatings() {
        if ratings.isEmpty {
            defaults.removeObject(forKey: Self.ratingsKey)
        } else if let data = try? JSONEncoder().encode(ratings) {
            defaults.set(data, forKey: Self.ratingsKey)
        }
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
