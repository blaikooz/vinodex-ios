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
    /// and must not leak into its neighbours.
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

    /// The ids are the persisted vocabulary, so they have to round-trip exactly.
    @Test("every entitlement round-trips through its id")
    func entitlementIDsRoundTrip() {
        let all: [Entitlement] = [.pro, .flavors, .skins, .lightMode, .country("New Zealand")]
        for entitlement in all {
            #expect(Entitlement(id: entitlement.id) == entitlement, "\(entitlement.id) did not round-trip")
        }
        #expect(Entitlement(id: "nonsense") == nil)
        #expect(Entitlement(id: "country:") == nil)
    }

    /// The prompt should offer the bundle that actually covers what you tapped,
    /// not Pro for everything.
    @Test("the offer for a locked entry covers it")
    func offerCoversTheEntry() throws {
        let store = makeStore()
        store.starterOnly = true

        let locked = db.entries.filter { store.isLocked($0, in: db) }
        #expect(!locked.isEmpty)

        for entry in locked {
            let offer = Entitlement.offer(for: entry)
            #expect(
                offer.covers(entry, in: db),
                "\(entry.name) would be offered \(offer.id), which does not cover it"
            )
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
