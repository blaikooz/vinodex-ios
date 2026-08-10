import Testing
import Foundation
@testable import VinodexCore

@MainActor
@Suite("Free tier access")
struct AccessTests {
    let db = WineDatabase.shared

    private func makeStore() -> AccessStore {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AccessStore(defaults: defaults)
    }

    /// The whole dataset must be visible on a fresh install.
    @Test("starter tier is off by default")
    func defaultsOff() {
        #expect(makeStore().starterOnly == false)
    }

    @Test("nothing is locked while starter tier is off")
    func nothingLockedByDefault() {
        let store = makeStore()
        for entry in db.entries {
            #expect(!store.isLocked(entry, in: db))
        }
    }

    @Test("starter tier locks some entries but not all")
    func locksSome() {
        let store = makeStore()
        store.starterOnly = true
        let locked = db.entries.filter { store.isLocked($0, in: db) }
        #expect(!locked.isEmpty, "starter tier locked nothing — tiers.json missing?")
        #expect(locked.count < db.entries.count, "starter tier locked everything")
    }

    /// The free tier has to be self-consistent: a browsable region whose key
    /// grape is locked would be a dead end.
    @Test("free regions and styles only reference free grapes")
    func freeTierIsClosed() {
        let store = makeStore()
        store.starterOnly = true

        let freeGrapeNames = Set(
            db.entries(in: .grapes).filter { db.isFree($0.id) }.map(\.name)
        )

        for entry in db.entries where db.isFree(entry.id) {
            guard entry.category == .regions || entry.category == .styles else { continue }
            let linked = entry.notableGrapes
            guard !linked.isEmpty else { continue }
            #expect(
                linked.contains(where: { freeGrapeNames.contains($0) }),
                "\(entry.name) is free but names no free grape"
            )
        }
    }

    /// Locking navigation would strand the user on the globe.
    @Test("continents are never locked")
    func continentsAlwaysFree() {
        let store = makeStore()
        store.starterOnly = true
        for entry in db.entries(in: .continents) {
            #expect(!store.isLocked(entry, in: db), "\(entry.name) is locked")
        }
    }

    @Test("the toggle persists")
    func persists() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        AccessStore(defaults: defaults).starterOnly = true
        #expect(AccessStore(defaults: defaults).starterOnly == true)
    }

    /// An id outside the manifest is locked — that is the paywall working.
    @Test("ids outside the manifest are not free")
    func unknownIsLocked() {
        #expect(!db.isFree("NOT_A_REAL_ID"))
    }

    /// The inverse guard: a free id that names no entry is silent drift — a
    /// regeneration renamed or dropped the entry, and `isFree` just returns
    /// false for an id nobody ever looks up.
    @Test("every free id in the manifest resolves to an entry")
    func freeIDsResolve() {
        #expect(!db.freeIDs.isEmpty, "bundled tiers.json lists no free ids")
        for id in db.freeIDs {
            #expect(db.entry(id: id) != nil, "tiers.json free id \(id) has no entry")
        }
    }

    /// The one safety valve: a build whose tiers manifest failed to load must
    /// unlock everything rather than lock the user out of the whole dataset.
    @Test("a database with no tier manifest is fully unlocked")
    func missingManifestUnlocks() {
        let open = WineDatabase(
            entries: db.entries,
            palette: db.palette,
            icons: db.icons,
            freeIDs: []
        )
        let store = makeStore()
        store.starterOnly = true
        for entry in open.entries {
            #expect(!store.isLocked(entry, in: open))
        }
    }

    // MARK: Bundles

    /// Pro is the superset: granting it must open everything, which is what
    /// makes it a coherent top tier rather than one bundle among several.
    @Test("pro unlocks every entry")
    func proUnlocksAll() {
        let store = makeStore()
        store.starterOnly = true
        store.grant(.pro)
        for entry in db.entries {
            #expect(!store.isLocked(entry, in: db), "\(entry.name) still locked with Pro")
        }
    }

    /// The edge case the single boolean could never express: one bundle owned,
    /// everything else still shut.
    ///
    /// **Still asserted after 0.8.3 (D) retired this bundle**, and that is the
    /// point of the test now: `.flavors` is off the shop and must go on opening
    /// exactly what it always opened for everybody who bought it. See
    /// `Entitlement.isRetired`.
    @Test("the flavors bundle opens flavors and nothing else")
    func flavorsBundleIsNarrow() {
        let store = makeStore()
        store.starterOnly = true

        let lockedBefore = db.entries.filter { store.isLocked($0, in: db) }
        store.grant(.flavors)

        for entry in db.entries(in: .flavors) {
            #expect(!store.isLocked(entry, in: db), "\(entry.name) locked despite the flavor bundle")
        }

        // Everything it opened must have been a flavour.
        let opened = lockedBefore.filter { !store.isLocked($0, in: db) }
        #expect(!opened.isEmpty, "the flavor bundle opened nothing — was anything locked?")
        for entry in opened {
            #expect(entry.category == .flavors, "\(entry.name) is not a flavour but the bundle opened it")
        }
    }

    /// A country bundle covers grapes, regions and styles from that country,
    /// and must not leak into its neighbours. Retired in 0.8.3 (D) and still
    /// covering, for the reason above.
    @Test("a country bundle opens only that country")
    func countryBundleIsNarrow() {
        let store = makeStore()
        store.starterOnly = true

        let lockedBefore = db.entries.filter { store.isLocked($0, in: db) }
        store.grant(.country("France"))

        let opened = lockedBefore.filter { !store.isLocked($0, in: db) }
        #expect(!opened.isEmpty, "the France bundle opened nothing")
        for entry in opened {
            #expect(
                TextNormalize.label(entry.origin ?? "") == "france",
                "\(entry.name) (\(entry.origin ?? "no origin")) opened by the France bundle"
            )
        }
    }

    /// Case is not consistent in the authored origins, so the bundle has to
    /// fold — same reasoning as `hasRegions(inCountry:)`.
    @Test("country bundles are case-insensitive")
    func countryBundleFoldsCase() {
        let store = makeStore()
        store.starterOnly = true
        store.grant(.country("france"))

        let french = db.entries(in: .regions).filter {
            TextNormalize.label($0.origin ?? "") == "france"
        }
        #expect(!french.isEmpty)
        for entry in french {
            #expect(!store.isLocked(entry, in: db), "\(entry.name) locked by a lower-case grant")
        }
    }

    /// Cosmetics gate a setting, not a page — they must never open an entry.
    @Test("cosmetic bundles unlock no entries")
    func cosmeticsAreNotContent() {
        let store = makeStore()
        store.starterOnly = true
        let lockedBefore = Set(db.entries.filter { store.isLocked($0, in: db) }.map(\.id))

        store.grant(.skins)
        store.grant(.lightMode)

        let lockedAfter = Set(db.entries.filter { store.isLocked($0, in: db) }.map(\.id))
        #expect(lockedBefore == lockedAfter, "a cosmetic bundle changed which entries are readable")
        #expect(store.isUnlocked(.skins))
        #expect(store.isUnlocked(.lightMode))
    }

    /// With the free tier off, nothing is gated — including cosmetics, so the
    /// developer switch gives the whole app back in one move.
    @Test("cosmetics are open while the free tier is off")
    func cosmeticsFollowTheTierSwitch() {
        let store = makeStore()
        #expect(store.starterOnly == false)
        #expect(store.isUnlocked(.skins))
        store.starterOnly = true
        #expect(!store.isUnlocked(.skins))
    }

    @Test("grants survive a reload and can be revoked")
    func grantsPersist() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let first = AccessStore(defaults: defaults)
        first.grant(.flavors)
        first.grant(.country("Italy"))

        let reloaded = AccessStore(defaults: defaults)
        #expect(reloaded.granted.contains(.flavors))
        #expect(reloaded.granted.contains(.country("Italy")))

        reloaded.revokeAll()
        #expect(AccessStore(defaults: defaults).granted.isEmpty)
    }

    /// CLEAR SAVED DATA's half of this store: unlike `revokeAll`, the tier
    /// switch unwinds too and both stored keys vanish outright.
    @Test("clearAll returns the store to install state")
    func clearAllResets() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let store = AccessStore(defaults: defaults)
        store.starterOnly = true
        store.grant(.flavors)
        store.grant(.country("Italy"))

        store.clearAll()
        #expect(store.granted.isEmpty)
        #expect(store.starterOnly == false)
        #expect(defaults.object(forKey: AccessStore.storageKey) == nil)
        #expect(defaults.object(forKey: AccessStore.entitlementsKey) == nil)

        let fresh = AccessStore(defaults: defaults)
        #expect(fresh.granted.isEmpty)
        #expect(fresh.starterOnly == false)
    }

    /// The ids are the persisted vocabulary, so they have to round-trip exactly.
    ///
    /// Extended in 0.7.3 (F1) with the three cases the later sub-batches read:
    /// an expansion pack, the workshop, and an easter egg. All three are stored
    /// in the same set as a purchase, which is the point — see `Entitlement`.
    /// `.lineage` joined them in 0.7.5 (E1).
    @Test("every entitlement round-trips through its id")
    func entitlementIDsRoundTrip() {
        let all: [Entitlement] = [
            .pro, .flavors, .skins, .lightMode, .country("New Zealand"),
            .expansion("champagne"), .workshop, .lineage, .easterEgg("verboseBoot"),
        ]
        for entitlement in all {
            #expect(Entitlement(id: entitlement.id) == entitlement, "\(entitlement.id) did not round-trip")
        }
        #expect(Entitlement(id: "nonsense") == nil)
        // Every namespaced form rejects an empty name rather than minting an
        // entitlement nobody can name.
        #expect(Entitlement(id: "country:") == nil)
        #expect(Entitlement(id: "pack:") == nil)
        #expect(Entitlement(id: "egg:") == nil)
    }

    /// The id namespaces have to stay disjoint, or one kind of unlock decodes as
    /// another and grants the wrong thing.
    @Test("the id namespaces do not collide")
    func namespacesAreDisjoint() {
        let ids: [Entitlement] = [
            .country("Chablis"), .expansion("Chablis"), .easterEgg("Chablis"),
        ]
        #expect(Set(ids.map(\.id)).count == ids.count)
        for entitlement in ids {
            #expect(Entitlement(id: entitlement.id) == entitlement)
        }
    }

    /// **The anti-orphan gate (0.8.3, D).**
    ///
    /// This used to read "the prompt should offer the bundle that actually
    /// covers what you tapped, not Pro for everything", and checked only the
    /// covering half. D removes four things from the shop, and the failure it
    /// is written against is the one a coverage-only check cannot see: an entry
    /// gated behind a bundle that still covers it perfectly well and that
    /// nothing sells any more. That entry is unreachable, and every assertion
    /// in the old version of this test would have passed.
    ///
    /// So both halves are asserted, over **every** entry rather than only the
    /// locked ones — an entry that is free today can stop being free when a
    /// data batch moves its rarity, and the offer for it has to be sound before
    /// that happens rather than after. This is what makes retiring a bundle a
    /// checkable act: take `.pro` off the shelf without a replacement and this
    /// fails 446 times.
    @Test("every entry's offer both covers it and can be bought")
    func everyEntryHasABuyableOffer() throws {
        let store = makeStore()
        store.starterOnly = true

        // The precondition the old test asserted, kept: a run where nothing is
        // locked would pass the loop below vacuously.
        #expect(!db.entries.filter { store.isLocked($0, in: db) }.isEmpty)

        for entry in db.entries {
            let offer = Entitlement.offer(for: entry)
            #expect(
                offer.covers(entry, in: db),
                "\(entry.name) would be offered \(offer.id), which does not cover it"
            )
            #expect(
                !offer.isRetired && store.isPurchasable(offer),
                "\(entry.name) would be offered \(offer.id), which is not for sale"
            )
        }
    }

    // MARK: Retired bundles (0.8.3, D)

    /// **The migration guarantee.** `country:France` and `flavors` are strings
    /// in `grantedEntitlements` on shipped devices. D takes both off the shop,
    /// and the one thing that must not follow is the grant becoming
    /// unreadable — `LocalEntitlementStore` decodes through
    /// `Entitlement.init(id:)` and `compactMap`s, so a case that stopped
    /// parsing would drop a purchase in silence rather than crash, which is
    /// worse.
    ///
    /// Written against the raw stored strings rather than against the enum, so
    /// it is testing the storage format an old install actually holds.
    @Test("a grant persisted before 0.8.3 still decodes and still opens its content")
    func retiredGrantsSurvive() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaults.set(
            ["country:France", "flavors"],
            forKey: LocalEntitlementStore.storageKey
        )

        let store = AccessStore(defaults: defaults)
        #expect(store.granted == [.country("France"), .flavors])

        store.starterOnly = true
        let french = db.entries.filter { TextNormalize.label($0.origin ?? "") == "france" }
        #expect(!french.isEmpty)
        for entry in french {
            #expect(!store.isLocked(entry, in: db), "\(entry.name) locked despite a stored France grant")
        }
        for entry in db.entries(in: .flavors) {
            #expect(!store.isLocked(entry, in: db), "\(entry.name) locked despite a stored flavors grant")
        }
    }

    /// Retired means unsellable, and unsellable has to be true of the *store*
    /// rather than of the one view that draws a shelf — a second surface listing
    /// products is how a retired row comes back.
    @Test("retired bundles cannot be bought, and nothing else is retired")
    func retiredBundlesAreNotForSale() async {
        let store = makeStore()

        for retired: Entitlement in [.flavors, .country("France"), .country("Italy"), .country("Spain")] {
            #expect(retired.isRetired)
            #expect(!store.isPurchasable(retired))
            let outcome = await store.purchase(retired)
            #expect(outcome == .unavailable, "\(retired.id) was sold after being retired")
        }
        #expect(store.granted.isEmpty)

        // The other side of the same fence: retiring a family must not have
        // caught anything that is still on the shelf.
        for live: Entitlement in [.pro, .skins, .lightMode, .workshop, .lineage, .expansion("old-world")] {
            #expect(!live.isRetired, "\(live.id) was retired by accident")
            #expect(store.isPurchasable(live))
        }
    }
}

@Suite("Display hyphenation")
struct HyphenationTests {
    private let soft = EntryDisplay.softHyphen

    @Test("long words gain break opportunities")
    func longWord() {
        let out = EntryDisplay.hyphenated("MEDITERRANEAN")
        #expect(out.contains(soft))
        // The visible text must be unchanged once the soft hyphens are removed.
        #expect(out.replacingOccurrences(of: soft, with: "") == "MEDITERRANEAN")
    }

    @Test("short words are left alone")
    func shortWord() {
        for word in ["RED", "CHALK", "AOC", "SWEET"] {
            #expect(EntryDisplay.hyphenated(word) == word)
        }
    }

    @Test("no break lands within a chunk of either end")
    func noOrphans() {
        let out = EntryDisplay.hyphenated("MEDITERRANEAN", minWordLength: 10, chunk: 4)
        let pieces = out.components(separatedBy: soft)
        for piece in pieces {
            #expect(piece.count >= 4, "orphan fragment '\(piece)' in \(pieces)")
        }
    }

    @Test("each word in a phrase is handled independently")
    func phrase() {
        let out = EntryDisplay.hyphenated("OLD MEDITERRANEAN")
        let words = out.split(separator: " ")
        #expect(words.count == 2)
        #expect(!words[0].contains(soft), "short word gained a break")
        #expect(words[1].contains(soft))
    }
}
