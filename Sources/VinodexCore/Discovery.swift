import Foundation
import Observation

/// The tried shelf, split by category and answered against the catalog
/// (0.8.9b, A1).
///
/// **Why this is derived and not stored.** The v9.0 spec asks for a
/// `DiscoveryStore` holding `triedGrapeIDs` and `triedStyleIDs` with a
/// first-tried date each. Every one of those facts already exists: the tried
/// shelf has been `BookmarkStore`'s since shelves landed, `triedEntryDays` has
/// carried the date since 0.7.1's D1, and the ids are the entry ids. Building a
/// second set would have forked the truth in the worst possible place — the
/// tried count drives the rank ladder, six of the eight passport badges, the
/// activity graph and both completion stamps, and a player who had marked
/// eighty entries would have opened a Discovery panel reading zero.
///
/// So the store below is a *façade*, and this type is the *split*. The split is
/// the part worth having: `BookmarkStore` deliberately knows nothing about the
/// database — it stores ids and drops the ones that stop resolving — so
/// "how many grapes have I tried" is a question only something holding a
/// `WineDatabase` can answer, and until now three call sites answered it
/// separately.
///
/// **`Passport.compute` is one of those three, and it now reads this.** The two
/// completion badges' conditions moved here verbatim, guards included: grapes
/// fold through `TextNormalize.label` because the shelf stores ids while the
/// catalog is compared by name everywhere else, styles compare by *id* because
/// they are entries rather than a typed model and ids are the stronger
/// comparison where it is available, and both are guarded non-empty so a
/// database that failed to load cannot hand out the two hardest stamps in the
/// series on first launch. That behaviour is unchanged by the move; what
/// changed is that the insight panel, the counters and the badges now read one
/// definition of "tried grapes" instead of three.
///
/// Pure, `Sendable` and Foundation-only: everything interesting about discovery
/// is arithmetic over ids and the catalog, and arithmetic is what Linux CI can
/// see.
/// The catalog side of discovery, folded once at load.
///
/// Everything here is a function of the dataset alone — no user state — so it is
/// built with the other reverse indexes in `WineDatabase.init` and read by every
/// `DiscoveryIndex`. See `WineDatabase.discoveryCatalog` for why it is not
/// computed per call.
public struct DiscoveryCatalog: Sendable {
    public let allGrapes: [GrapeEntry]
    public let allStyles: [WineEntry]
    /// Every grape name in the catalog, folded — the key grapes are compared on.
    public let allGrapeKeys: Set<String>
    /// Every style id in the catalog, exact.
    public let allStyleIDs: Set<String>
    /// Grape name key -> the grape, so a `notableGrapes` string resolves without
    /// a scan.
    public let grapesByKey: [String: GrapeEntry]
    /// Everything with a tried shelf — grapes then styles — as entries. The pool
    /// `PalateProfile.recommendations` ranks.
    public let allTastable: [WineEntry]
    /// Folded country name -> its grapes. Pre-bucketed because the INSIGHT
    /// panel's country line would otherwise fold ~180 origin strings per draw.
    public let grapesByCountry: [String: [GrapeEntry]]
    /// Rarity band -> its grapes, for the same reason.
    public let grapesByRarity: [RarityLabel: [GrapeEntry]]

    public init(entries: [WineEntry]) {
        var grapes: [GrapeEntry] = []
        var styles: [WineEntry] = []
        var tastable: [WineEntry] = []
        var keys: Set<String> = []
        var byKey: [String: GrapeEntry] = [:]
        var styleIDs: Set<String> = []
        var byCountry: [String: [GrapeEntry]] = [:]
        var byRarity: [RarityLabel: [GrapeEntry]] = [:]

        for entry in entries {
            switch entry {
            case .grape(let g):
                grapes.append(g)
                tastable.append(entry)
                let key = TextNormalize.label(g.common.name)
                keys.insert(key)
                // First wins, matching `byName`'s precedence rule: two grapes
                // folding to one key is a data problem, and the earlier entry is
                // the one every other lookup in this file already resolves to.
                if byKey[key] == nil { byKey[key] = g }
                let country = TextNormalize.label(g.grapeCountryOfOrigin)
                if !country.isEmpty { byCountry[country, default: []].append(g) }
                byRarity[g.rarity, default: []].append(g)
            case .style:
                styles.append(entry)
                tastable.append(entry)
                styleIDs.insert(entry.id)
            case .region, .flavor, .continent:
                continue
            }
        }

        allGrapes = grapes
        allStyles = styles
        allTastable = tastable
        allGrapeKeys = keys
        allStyleIDs = styleIDs
        grapesByKey = byKey
        grapesByCountry = byCountry
        grapesByRarity = byRarity
    }
}

public struct DiscoveryIndex: Sendable {
    /// Tried entries that are grapes, in shelf order.
    public let triedGrapes: [GrapeEntry]
    /// Tried entries that are styles, in shelf order.
    public let triedStyles: [WineEntry]
    /// Every grape the catalog holds.
    public let allGrapes: [GrapeEntry]
    /// Every style the catalog holds.
    public let allStyles: [WineEntry]

    /// The catalog side, folded once at load. Held so the derived lines can
    /// reach its buckets without re-scanning.
    public let catalog: DiscoveryCatalog

    /// Tried grape names, folded — the key the catalog is compared on.
    public let triedGrapeKeys: Set<String>
    /// Every grape name in the catalog, folded.
    public let allGrapeKeys: Set<String>
    /// Tried style ids, exact.
    public let triedStyleIDs: Set<String>
    /// Every style id in the catalog, exact.
    public let allStyleIDs: Set<String>

    /// Grapes and styles together — the figure the rank ladder reads.
    public var triedTotal: Int { triedGrapes.count + triedStyles.count }

    /// Only the *shelf* side is computed here; the catalog side is read from
    /// `WineDatabase.discoveryCatalog`, which folded it once at load. So the
    /// cost of this is proportional to what the user has tried rather than to
    /// the size of the database — which matters, because the INSIGHT panel
    /// builds one on every evaluation of a screen that re-evaluates on scroll.
    public init(tried: [String], in db: WineDatabase) {
        catalog = db.discoveryCatalog
        let entries = tried.compactMap { db.entry(id: $0) }
        triedGrapes = entries.compactMap { if case .grape(let g) = $0 { g } else { nil } }
        triedStyles = entries.filter { $0.category == .styles }
        allGrapes = catalog.allGrapes
        allStyles = catalog.allStyles

        triedGrapeKeys = Set(triedGrapes.map { TextNormalize.label($0.common.name) })
        allGrapeKeys = catalog.allGrapeKeys
        triedStyleIDs = Set(triedStyles.map(\.id))
        allStyleIDs = catalog.allStyleIDs
    }

    // MARK: Counts

    /// Tried and total for one tastable category, for the X/N counters (C2).
    ///
    /// Returns `nil` for a category the shelves do not apply to — regions,
    /// flavours and continents are reference, not tastings, and a "0 of 91
    /// regions tried" counter would be reporting on a shelf that cannot be
    /// filled. See `WineEntry.isTastable`.
    public func count(of category: EntryCategory) -> DiscoveryCount? {
        switch category {
        case .grapes: DiscoveryCount(tried: triedGrapes.count, total: allGrapes.count)
        case .styles: DiscoveryCount(tried: triedStyles.count, total: allStyles.count)
        case .regions, .flavors, .continents: nil
        }
    }

    // MARK: Completion (moved from `Passport.compute`, 0.8.6 C6 → 0.8.9b C2)

    /// Every grape in the catalog, tried.
    ///
    /// Guarded non-empty for the reason `regionComplete` is: an empty
    /// requirement is not an achievement, and a database that failed to load
    /// would otherwise award this on first launch. A grape whose entry has been
    /// retired cannot make the set uncompletable, because the tried side is
    /// folded to the same keys the catalog side is.
    public var allGrapesTried: Bool {
        !allGrapes.isEmpty && allGrapeKeys.isSubset(of: triedGrapeKeys)
    }

    /// Every style in the catalog, tried. By id, not by name — see the type
    /// note.
    public var allStylesTried: Bool {
        !allStyleIDs.isEmpty && allStyleIDs.isSubset(of: triedStyleIDs)
    }

    /// Every noble grape, tried — ALL NOBLE's condition, same shape narrowed to
    /// one rarity and guarded the same way.
    public var allNobleTried: Bool {
        let noble = allGrapes.filter { $0.rarity == .noble }
        return !noble.isEmpty && noble.allSatisfy {
            triedGrapeKeys.contains(TextNormalize.label($0.common.name))
        }
    }

    /// Whether some region has every one of its resolvable notable grapes
    /// tried. A region naming nothing the catalog holds cannot be completed.
    public func regionComplete(in db: WineDatabase) -> Bool {
        db.entries(in: .regions).contains { region in
            let resolvable = region.notableGrapes
                .map { TextNormalize.label($0) }
                .filter { allGrapeKeys.contains($0) }
            return !resolvable.isEmpty && resolvable.allSatisfy { triedGrapeKeys.contains($0) }
        }
    }

    // MARK: Membership

    /// Whether a *grape name* has been tried, folded. The name form exists
    /// because the catalog cross-references grapes by name everywhere —
    /// `notableGrapes`, `keyRegions`' other end, lineage's off-catalog refs —
    /// and an id lookup cannot answer those.
    public func hasTriedGrape(named name: String) -> Bool {
        triedGrapeKeys.contains(TextNormalize.label(name))
    }
}

/// A tried-versus-total pair, for the X/N counters.
public struct DiscoveryCount: Sendable, Equatable {
    public let tried: Int
    public let total: Int

    public init(tried: Int, total: Int) {
        self.tried = tried
        self.total = total
    }

    /// 0...1, and 0 rather than a division by zero on an empty catalog.
    public var fraction: Double {
        total > 0 ? min(max(Double(tried) / Double(total), 0), 1) : 0
    }

    /// `"12/80"` — the counter as it is drawn.
    public var label: String { "\(tried)/\(total)" }
}

/// The discovery API over the tried shelf (0.8.9b, A1).
///
/// **A façade, deliberately.** See `DiscoveryIndex` for why there is no second
/// store: everything here forwards to `BookmarkStore`, which remains the one
/// place tried membership changes and therefore the one place the coupling
/// rules live — marking tried clears the wishlist row, un-marking drops the
/// rating, and both stamp the day. Routing discovery's writes through the same
/// door means the passport, the stamps and the activity graph all see a
/// scanner-marked tasting exactly as they see a hand-marked one.
///
/// **`markTried` is idempotent and `toggle` is not.** That is the whole reason
/// this method exists rather than call sites reaching for
/// `toggle(_:on: .tried)`: A2 marks a batch of ids from one scan, and a batch
/// containing something already on the shelf must not silently un-try it. The
/// toggle stays the entry page's control, where the user can see what they are
/// flipping.
///
/// `@MainActor @Observable` like the store it wraps, so SwiftUI re-renders when
/// a scan changes the counts — and still Foundation-only, so the behaviour is
/// testable on Linux.
@MainActor
@Observable
public final class DiscoveryStore {
    public static let shared = DiscoveryStore()

    private let bookmarks: BookmarkStore

    /// Injectable for tests; the app uses the shared shelf.
    public init(bookmarks: BookmarkStore = .shared) {
        self.bookmarks = bookmarks
    }

    // MARK: Reading

    /// Every tried id, newest first.
    public var triedIDs: [String] { bookmarks.ids(on: .tried) }

    /// How many things have been tried, without consulting the catalog. The
    /// *typed* counts need a database — see `index(in:)`.
    public var triedCount: Int { bookmarks.count(on: .tried) }

    public func isTried(_ id: String) -> Bool { bookmarks.contains(id, on: .tried) }

    /// The day this was first marked, as a `DailyPick.dayIndex`, or nil for
    /// something marked before 0.7.1 started keeping the log. Nil rather than a
    /// guessed date, for the reason `BookmarkStore.triedDay(for:)` gives.
    public func firstTriedDay(_ id: String) -> Int? { bookmarks.triedDay(for: id) }

    /// How many days ago this was first marked, or nil when unknown or in the
    /// future (a clock that moved backwards is not a negative age).
    public func daysSinceTried(_ id: String, today: Int = DailyPick.dayIndex()) -> Int? {
        guard let day = firstTriedDay(id), day <= today else { return nil }
        return today - day
    }

    /// The catalog-aware split. Rebuilt per call rather than cached: it is a
    /// couple of hundred dictionary inserts over an array the app already holds
    /// in memory, and a cache here would be a second thing to invalidate every
    /// time the shelf moved — which is the failure mode this whole file exists
    /// to avoid.
    public func index(in db: WineDatabase) -> DiscoveryIndex {
        DiscoveryIndex(tried: triedIDs, in: db)
    }

    /// Tried and total for one category, or nil for a non-tastable one.
    public func count(of category: EntryCategory, in db: WineDatabase) -> DiscoveryCount? {
        index(in: db).count(of: category)
    }

    // MARK: Writing

    /// Marks one entry tried. Returns true when this call is what put it there,
    /// false when it was already on the shelf — so a caller can tell a new
    /// tasting from a repeat without reading the shelf first.
    @discardableResult
    public func markTried(_ id: String) -> Bool {
        guard !isTried(id) else { return false }
        bookmarks.toggle(id, on: .tried)
        return true
    }

    /// Marks a batch and returns the ids this call actually added, in the order
    /// given. A2's shape: one scan resolves several grapes and a style, and the
    /// screen wants to say what it added rather than what it was handed.
    @discardableResult
    public func markTried(ids: [String]) -> [String] {
        ids.filter { markTried($0) }
    }

    /// Takes one off the shelf, with the rating and the recorded day, exactly
    /// as un-toggling it on the entry page does.
    public func unmarkTried(_ id: String) {
        bookmarks.remove(id, on: .tried)
    }
}

// MARK: - What a scan is allowed to mark

public extension LabelReading {
    /// The entries a successful read may mark tried (0.8.9b, A2).
    ///
    /// **Only on `.identified`, and never on the shortlist.** The results screen
    /// heads these two lists POSSIBLE GRAPES and POSSIBLE STYLES, and it means
    /// it: `grapeIDs` is usually *inferred from the place* rather than read off
    /// the bottle, so a Bordeaux label yields six grapes of which the bottle
    /// contained some unknown subset. On an `.ambiguous` reading the same lists
    /// are a shortlist of candidates the reader is telling you it could not
    /// choose between. Marking either set tried would put entries on the shelf
    /// that move the rank ladder, stamp the activity graph and gate both
    /// completion badges — on evidence the reader itself describes as possible.
    ///
    /// So this returns the ids and the *screen asks*: A2 is a one-tap confirm on
    /// the identified card, not a silent write. One tap still marks six grapes
    /// and a style at once, which is what makes the scanner the fast path the
    /// spec wants it to be; what it does not do is decide on the user's behalf
    /// that they drank something.
    ///
    /// Grapes lead, styles follow, and the whole thing is de-duplicated in
    /// place because a grape read outright *and* inferred from the appellation
    /// appears in both `matches` and `grapeIDs`.
    var triedCandidateIDs: [String] {
        guard outcome == .identified else { return [] }
        var seen = Set<String>()
        var out: [String] = []
        for id in grapeIDs + styleIDs where seen.insert(id).inserted {
            out.append(id)
        }
        return out
    }
}
