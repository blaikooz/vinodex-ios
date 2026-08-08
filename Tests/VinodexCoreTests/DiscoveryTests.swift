import Testing
import Foundation
@testable import VinodexCore

/// Phase 1's acceptance criterion, in Core where CI can see it: marking updates
/// the counts and the insight, live (0.8.9b).
@Suite("Discovery")
struct DiscoveryTests {
    private let db = WineDatabase.shared

    private var allGrapes: [GrapeEntry] {
        db.entries(in: .grapes).compactMap { if case .grape(let g) = $0 { g } else { nil } }
    }

    private var allStyles: [WineEntry] { db.entries(in: .styles) }

    @MainActor
    private func makeStore() -> DiscoveryStore {
        let suite = UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("could not make a test suite")
        }
        defaults.removePersistentDomain(forName: suite)
        return DiscoveryStore(bookmarks: BookmarkStore(defaults: defaults))
    }

    // MARK: A1 — the store

    @MainActor
    @Test("marking is idempotent where toggling is not")
    func markIsIdempotent() throws {
        let store = makeStore()
        let id = try #require(allGrapes.first).id
        #expect(store.markTried(id) == true)
        #expect(store.isTried(id))
        // The bug this method exists to prevent: a second mark must not
        // un-mark, or A2's batch would un-try anything already on the shelf.
        #expect(store.markTried(id) == false)
        #expect(store.isTried(id))
        #expect(store.triedCount == 1)
    }

    @MainActor
    @Test("a batch reports only what it added")
    func batchReportsAdditions() {
        let store = makeStore()
        let ids = allGrapes.prefix(3).map(\.id)
        store.markTried(ids[0])
        let added = store.markTried(ids: Array(ids))
        #expect(added == [ids[1], ids[2]])
        #expect(store.triedCount == 3)
    }

    @MainActor
    @Test("marking dates the entry and un-marking forgets it")
    func firstTriedDate() throws {
        let store = makeStore()
        let id = try #require(allGrapes.first).id
        #expect(store.firstTriedDay(id) == nil)
        store.markTried(id)
        #expect(store.firstTriedDay(id) == DailyPick.dayIndex())
        #expect(store.daysSinceTried(id) == 0)
        // A day in the future is a moved clock, not a negative age.
        #expect(store.daysSinceTried(id, today: DailyPick.dayIndex() - 5) == nil)
        store.unmarkTried(id)
        #expect(store.firstTriedDay(id) == nil)
    }

    /// The whole reason `DiscoveryStore` is a façade: a scan and a tap must
    /// reach the same shelf, or the passport and the panel disagree.
    @MainActor
    @Test("the discovery store and the tried shelf are the same shelf")
    func oneSourceOfTruth() throws {
        let suite = UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { fatalError("no suite") }
        let bookmarks = BookmarkStore(defaults: defaults)
        let store = DiscoveryStore(bookmarks: bookmarks)
        let id = try #require(allGrapes.first).id

        store.markTried(id)
        #expect(bookmarks.contains(id, on: .tried))
        #expect(bookmarks.triedDay(for: id) != nil)

        bookmarks.toggle(id, on: .tried)
        #expect(!store.isTried(id))
    }

    /// Marking tried takes it off the wishlist — a coupling rule that lives in
    /// `BookmarkStore.toggle` and would have been lost by a second store.
    @MainActor
    @Test("a scan-marked tasting still clears the wishlist row")
    func couplingSurvivesTheFacade() throws {
        let suite = UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { fatalError("no suite") }
        let bookmarks = BookmarkStore(defaults: defaults)
        let store = DiscoveryStore(bookmarks: bookmarks)
        let id = try #require(allGrapes.first).id

        bookmarks.toggle(id, on: .wantToTry)
        #expect(bookmarks.contains(id, on: .wantToTry))
        store.markTried(id)
        #expect(!bookmarks.contains(id, on: .wantToTry))
    }

    // MARK: The index and the counters (C2)

    @Test("the index splits the shelf by category and ignores stale ids")
    func indexSplits() {
        let grapes = allGrapes.prefix(4).map(\.id)
        let styles = allStyles.prefix(2).map(\.id)
        let index = DiscoveryIndex(tried: Array(grapes) + Array(styles) + ["NOT_REAL"], in: db)
        #expect(index.triedGrapes.count == 4)
        #expect(index.triedStyles.count == 2)
        #expect(index.triedTotal == 6)
    }

    @Test("counters read tried over the catalog's own total")
    func counters() {
        let index = DiscoveryIndex(tried: allGrapes.prefix(7).map(\.id), in: db)
        let grapes = index.count(of: .grapes)
        #expect(grapes?.tried == 7)
        #expect(grapes?.total == db.databaseStats.grapes)
        #expect(grapes?.label == "7/\(db.databaseStats.grapes)")
        #expect(index.count(of: .styles)?.tried == 0)
        // Reference categories have no shelf to fill, so no counter.
        #expect(index.count(of: .regions) == nil)
        #expect(index.count(of: .flavors) == nil)
        #expect(index.count(of: .continents) == nil)
    }

    @Test("an empty catalog counter is zero, not a division by zero")
    func emptyCounter() {
        #expect(DiscoveryCount(tried: 0, total: 0).fraction == 0)
        #expect(DiscoveryCount(tried: 3, total: 6).fraction == 0.5)
        // Clamped: a shelf holding a retired entry must not report 110%.
        #expect(DiscoveryCount(tried: 9, total: 6).fraction == 1)
    }

    /// **The cache and the query must agree.** `DiscoveryCatalog` is folded once
    /// in `WineDatabase.init` so the INSIGHT panel does not re-scan the catalog
    /// on every scroll event; the risk a cache buys is that it silently stops
    /// describing the thing it caches. This is the two-way check — every bucket
    /// against the query it replaced.
    @Test("the cached catalog agrees with the database it was built from")
    func catalogDoesNotDrift() {
        let catalog = db.discoveryCatalog
        // **By set, not by sequence, and that is the real contract.**
        // `entries(in:)` hands back `sortedEntries` — display order, folded by
        // name at load — while the catalog walks the raw array and keeps source
        // order. Nothing downstream reads either as an order: the counts and the
        // completion predicates are order-free, and `recommendations` imposes its
        // own sort. Pinning sequence equality here would be pinning a coincidence
        // and would fail the next time the display sort changed.
        #expect(Set(catalog.allGrapes.map(\.id)) == Set(allGrapes.map(\.id)))
        #expect(Set(catalog.allStyles.map(\.id)) == Set(allStyles.map(\.id)))
        #expect(catalog.allGrapes.count == allGrapes.count)
        #expect(catalog.allStyles.count == allStyles.count)
        #expect(catalog.allGrapes.count == db.databaseStats.grapes)
        #expect(catalog.allStyles.count == db.databaseStats.styles)
        #expect(catalog.allStyleIDs == Set(allStyles.map(\.id)))
        #expect(catalog.allGrapeKeys == Set(allGrapes.map { TextNormalize.label($0.common.name) }))
        // Tastable is the two, in that order, and nothing else.
        #expect(catalog.allTastable.count == catalog.allGrapes.count + catalog.allStyles.count)
        let nonTastable = catalog.allTastable.filter { !$0.isTastable }
        #expect(nonTastable.isEmpty)

        // Buckets partition the grape list — no grape lost, none counted twice.
        let countryTotal = catalog.grapesByCountry.values.map(\.count).reduce(0, +)
        let rarityTotal = catalog.grapesByRarity.values.map(\.count).reduce(0, +)
        #expect(countryTotal == catalog.allGrapes.count)
        #expect(rarityTotal == catalog.allGrapes.count)

        let misfiledByRarity = catalog.grapesByRarity.flatMap { rarity, band in
            band.filter { $0.rarity != rarity }
        }
        #expect(misfiledByRarity.isEmpty)

        let misfiledByCountry = catalog.grapesByCountry.flatMap { country, pool in
            pool.filter { TextNormalize.label($0.grapeCountryOfOrigin) != country }
        }
        #expect(misfiledByCountry.isEmpty)

        // Every grape resolves from its own folded name.
        let unresolvable = catalog.allGrapes.filter {
            catalog.grapesByKey[TextNormalize.label($0.common.name)] == nil
        }
        #expect(unresolvable.isEmpty)
    }

    // MARK: C2 — the completion badges keep their guards

    /// The two hardest stamps in the series. The guard is the point: a database
    /// that failed to load must not hand them out on first launch.
    @Test("an empty catalog cannot complete anything")
    func emptyCatalogCompletesNothing() {
        let index = DiscoveryIndex(tried: [], in: db)
        #expect(!index.allGrapesTried)
        #expect(!index.allStylesTried)
        #expect(!index.allNobleTried)
        #expect(!index.regionComplete(in: db))
    }

    @Test("tried-all-grapes needs every grape, and then it is earned")
    func allGrapesTried() {
        let all = allGrapes.map(\.id)
        #expect(!DiscoveryIndex(tried: Array(all.dropLast()), in: db).allGrapesTried)
        #expect(DiscoveryIndex(tried: all, in: db).allGrapesTried)
    }

    @Test("tried-all-styles compares by id, and needs every style")
    func allStylesTried() {
        let all = allStyles.map(\.id)
        #expect(!DiscoveryIndex(tried: Array(all.dropLast()), in: db).allStylesTried)
        #expect(DiscoveryIndex(tried: all, in: db).allStylesTried)
    }

    /// The badge and the counter must not be able to disagree — the whole
    /// reason the conditions moved onto one type in 0.8.9b.
    @Test("the passport's badges agree with the index that now feeds them")
    func passportAgreesWithIndex() {
        let tried = allGrapes.map(\.id) + allStyles.map(\.id)
        let index = DiscoveryIndex(tried: tried, in: db)
        let passport = Passport.compute(
            tried: tried, in: db, bestStreak: 0, highestTier: .novice
        )
        #expect(passport.triedGrapes == index.triedGrapes.count)
        #expect(passport.triedStyles == index.triedStyles.count)
        #expect(passport.badges.first { $0.id == "allGrapes" }?.earned == index.allGrapesTried)
        #expect(passport.badges.first { $0.id == "allStyles" }?.earned == index.allStylesTried)
        #expect(passport.badges.first { $0.id == "allNoble" }?.earned == index.allNobleTried)
        #expect(index.allGrapesTried)
        #expect(index.allStylesTried)
    }

    /// Grapes fold by name and styles compare by id — the asymmetry 0.8.6
    /// established and this batch inherited rather than re-litigated.
    @Test("a grape is tried by name, a style by id")
    func foldingRules() throws {
        let grape = try #require(allGrapes.first)
        let index = DiscoveryIndex(tried: [grape.id], in: db)
        #expect(index.hasTriedGrape(named: grape.common.name))
        #expect(index.hasTriedGrape(named: grape.common.name.uppercased()))
        #expect(!index.hasTriedGrape(named: "Not A Grape"))
    }

    // MARK: A2 — what a scan may mark

    @Test("only an identified reading offers anything to mark")
    func scanCandidates() throws {
        let grape = try #require(allGrapes.first)
        let style = try #require(allStyles.first)

        // Identified: a wine name carries the reading over the floor.
        let identified = LabelReading(
            recognizedText: ["BAROLO"],
            matches: [LabelMatch(field: .wineName, name: "Barolo", readAs: "BAROLO")],
            grapeIDs: [grape.id],
            styleIDs: [style.id]
        )
        #expect(identified.outcome == .identified)
        #expect(identified.triedCandidateIDs == [grape.id, style.id])

        // Ambiguous: the same lists, and the reader is telling you it could not
        // choose. Marking these would put guesses on the shelf that move the
        // rank ladder and gate both completion badges.
        let ambiguous = LabelReading(
            recognizedText: ["SOMETHING"],
            matches: [],
            grapeIDs: [grape.id],
            styleIDs: [style.id],
            suggestedCountries: ["Italy"]
        )
        #expect(ambiguous.outcome == .ambiguous)
        #expect(ambiguous.triedCandidateIDs.isEmpty)

        let nothing = LabelReading(recognizedText: [], matches: [])
        #expect(nothing.outcome == .unrecognized)
        #expect(nothing.triedCandidateIDs.isEmpty)
    }

    /// A grape read outright *and* inferred from the appellation appears twice
    /// in the reading; it must not be offered twice.
    @Test("scan candidates are de-duplicated in place")
    func scanCandidatesDeduplicate() throws {
        let grape = try #require(allGrapes.first)
        let reading = LabelReading(
            recognizedText: ["X"],
            matches: [LabelMatch(field: .wineName, name: "X", readAs: "X")],
            grapeIDs: [grape.id, grape.id],
            styleIDs: [grape.id]
        )
        #expect(reading.triedCandidateIDs == [grape.id])
    }

    /// The acceptance criterion, end to end and in one test: a scan's ids go in
    /// through the store, and the counters and the passport move.
    @MainActor
    @Test("a scan updates the counts it is supposed to update")
    func scanUpdatesCounts() throws {
        let store = makeStore()
        let grape = try #require(allGrapes.first)
        let style = try #require(allStyles.first)
        let reading = LabelReading(
            recognizedText: ["BAROLO"],
            matches: [LabelMatch(field: .wineName, name: "Barolo", readAs: "BAROLO")],
            grapeIDs: [grape.id],
            styleIDs: [style.id]
        )

        #expect(store.count(of: .grapes, in: db)?.tried == 0)
        let added = store.markTried(ids: reading.triedCandidateIDs)
        #expect(added.count == 2)
        #expect(store.count(of: .grapes, in: db)?.tried == 1)
        #expect(store.count(of: .styles, in: db)?.tried == 1)

        let passport = Passport.compute(
            tried: store.triedIDs, in: db, bestStreak: 0, highestTier: .novice
        )
        #expect(passport.triedTotal == 2)
        #expect(passport.badges.first { $0.id == "firstSip" }?.earned == true)
    }
}
