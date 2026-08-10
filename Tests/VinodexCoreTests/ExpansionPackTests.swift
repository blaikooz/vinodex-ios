import Testing
import Foundation
@testable import VinodexCore

/// The pack catalog and what it promises (0.7.3, 0.7.3c).
///
/// The load-bearing test here is `atlasCountriesResolve`. `ExpansionPacks` is
/// the one list in the app that names `shared/` content from Swift, so it is the
/// one list `find-missing-refs.mjs` cannot see — it audits the generated data
/// against itself and knows nothing about a country list living in a `.swift`
/// file. This suite is that gate. B2 named Brazil while Brazil was not in the
/// catalog; this is what makes the next such line fail loudly instead of
/// shipping a pack that quietly holds nothing.
@MainActor
@Suite("Expansion packs")
struct ExpansionPackTests {
    let db = WineDatabase.shared

    private func makeStore() -> AccessStore {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AccessStore(defaults: defaults)
    }

    // MARK: The catalog itself

    /// **Every country an atlas pack names must exist in the catalog.**
    ///
    /// Not "must be spelled like a country we have heard of" — must actually
    /// resolve to entries, which is the only version of the promise a user can
    /// tell apart from a typo. `TextNormalize.label` does the folding, exactly as
    /// `ExpansionPack.contains` does at runtime, so a mismatch in accent or case
    /// fails here rather than silently emptying the pack.
    @Test("every country named by an atlas pack resolves to entries")
    func atlasCountriesResolve() {
        let origins = Set(
            db.entries.compactMap(\.origin).map { TextNormalize.label($0) }
        )
        for pack in ExpansionPacks.atlas {
            guard case .countries(let names) = pack.contents else { continue }
            for name in names {
                #expect(
                    origins.contains(TextNormalize.label(name)),
                    "\(pack.title) names \(name), which no entry has as its origin"
                )
            }
        }
    }

    /// Brazil by name, because it is the country this batch added and the reason
    /// the test above exists. A regression that dropped it would otherwise only
    /// show as the New World pack being a little smaller.
    @Test("Brazil is in the catalog and in the New World pack")
    func brazilIsWired() {
        let brazilian = db.entries.filter {
            TextNormalize.label($0.origin ?? "") == TextNormalize.label("Brazil")
        }
        #expect(!brazilian.isEmpty, "no entry originates in Brazil")
        for entry in brazilian {
            #expect(ExpansionPacks.newWorld.contains(entry))
            #expect(!ExpansionPacks.oldWorld.contains(entry))
        }
    }

    /// No pack may be empty. A cartridge holding nothing is the failure mode the
    /// cheat-code table's own note describes one layer over: something that
    /// reports itself as a thing you can own and then does nothing.
    @Test("every atlas pack holds entries")
    func atlasPacksAreNotEmpty() {
        for pack in ExpansionPacks.atlas {
            #expect(!pack.entries(in: db).isEmpty, "\(pack.title) is empty")
            #expect(
                !pack.collectibleEntries(in: db).isEmpty,
                "\(pack.title) has nothing that can be tried"
            )
        }
    }

    /// The cosmetic packs hold no *entries* by construction — their members are
    /// skins and modes over in `VinodexUI`. Asserted rather than assumed, because
    /// the alternative reading (a device pack quietly covering catalog entries)
    /// is a paywall bug rather than a display one.
    @Test("device and display packs hold no catalog entries")
    func cosmeticPacksHoldNoEntries() {
        for pack in ExpansionPacks.device + ExpansionPacks.display {
            #expect(pack.contents == .cosmetics)
            #expect(pack.entries(in: db).isEmpty)
            #expect(pack.progress(tried: [], in: db) == nil)
        }
    }

    /// Old World and New World must not overlap: a country in both would be
    /// double-sold, and the shelf's two headline cartridges would disagree about
    /// where France is.
    @Test("the two atlas hemispheres are disjoint")
    func hemispheresAreDisjoint() {
        let old = Set(ExpansionPacks.oldWorld.entries(in: db).map(\.id))
        let new = Set(ExpansionPacks.newWorld.entries(in: db).map(\.id))
        #expect(old.intersection(new).isEmpty)
        #expect(!old.isEmpty)
        #expect(!new.isEmpty)
    }

    /// GODFORSAKEN is defined by rarity, not by a name list, so what it holds is
    /// a fact about the data rather than about this file. Recorded here: today
    /// every entry at that tier is a grape, which is what B3 assumed. A future
    /// godforsaken *style* would flip the second expectation, and the right
    /// response would be to update this line rather than to narrow the pack.
    @Test("the godforsaken pack is the rarest tier, and today that is all grapes")
    func godforsakenIsRarity() {
        let members = ExpansionPacks.godforsaken.entries(in: db)
        #expect(!members.isEmpty)
        #expect(members.allSatisfy { $0.rarity == .godforsaken })
        #expect(
            members.allSatisfy { $0.category == .grapes },
            "a non-grape reached GODFORSAKEN; B3 called it a grape pack"
        )
    }

    // MARK: Identity and storage

    /// **Pack ids are storage.** They persist inside `Entitlement.expansion`, so
    /// they must be unique, non-empty, and must survive the round trip through
    /// `Entitlement.id` / `Entitlement.init(id:)` — which is where an id with a
    /// stray colon or an empty tail would come apart.
    @Test("pack ids are unique and round-trip through the entitlement store")
    func idsAreStorageSafe() {
        var seen: Set<String> = []
        for pack in ExpansionPacks.all {
            #expect(!pack.id.isEmpty)
            #expect(seen.insert(pack.id).inserted, "duplicate pack id \(pack.id)")
            #expect(pack.id == pack.id.trimmingCharacters(in: .whitespaces))

            let entitlement = pack.entitlement
            #expect(entitlement.id == "pack:" + pack.id)
            #expect(Entitlement(id: entitlement.id) == entitlement)
        }
        #expect(ExpansionPacks.all.count == 12)
    }

    @Test("every pack is labelled")
    func packsAreLabelled() {
        for pack in ExpansionPacks.all {
            #expect(!pack.title.isEmpty)
            #expect(!pack.blurb.isEmpty)
            #expect(!pack.symbol.isEmpty)
            #expect(ExpansionPacks.pack(id: pack.id) == pack)
        }
    }

    /// The shelves partition the catalog, so no cartridge can be dropped by
    /// being left off a list or shown twice by being on two.
    @Test("the three shelves partition the pack catalog")
    func shelvesPartition() {
        let byKind = ExpansionPack.Kind.allCases.flatMap { ExpansionPacks.packs(of: $0) }
        #expect(byKind.count == ExpansionPacks.all.count)
        #expect(Set(byKind.map(\.id)) == Set(ExpansionPacks.all.map(\.id)))
        for kind in ExpansionPack.Kind.allCases {
            #expect(ExpansionPacks.packs(of: kind).allSatisfy { $0.kind == kind })
        }
    }

    /// **The clause that stops the cosmetic cartridges revoking a purchase.**
    ///
    /// If a device pack ever stopped naming `.skins` here, a user who owns the
    /// skins bundle would find six cartridges they had paid for reading as
    /// unowned. The atlas packs must stay `nil`: they are content, and no
    /// existing bundle covers a group of countries.
    @Test("cosmetic packs are implied by the bundle that already gates them")
    func implicationsAreCorrect() {
        for pack in ExpansionPacks.device {
            #expect(pack.impliedBy == .skins, "\(pack.title) would re-gate the skins")
        }
        for pack in ExpansionPacks.display {
            #expect(pack.impliedBy == .lightMode, "\(pack.title) would re-gate the modes")
        }
        for pack in ExpansionPacks.atlas {
            #expect(pack.impliedBy == nil)
        }
    }

    // MARK: Coverage — the arm 0.7.3a left at `false`

    @Test("owning an atlas pack opens its countries and nothing else")
    func atlasPacksCover() {
        let french = db.entries.first {
            TextNormalize.label($0.origin ?? "") == "france"
        }
        let chilean = db.entries.first {
            TextNormalize.label($0.origin ?? "") == "chile"
        }
        #expect(french != nil)
        #expect(chilean != nil)
        guard let french, let chilean else { return }

        let old = ExpansionPacks.oldWorld.entitlement
        #expect(old.covers(french, in: db))
        #expect(!old.covers(chilean, in: db))

        let new = ExpansionPacks.newWorld.entitlement
        #expect(new.covers(chilean, in: db))
        #expect(!new.covers(french, in: db))
    }

    /// Cosmetic bundles cover nothing — the rule `Entitlement.covers` states for
    /// `.skins`, now that a cosmetic can arrive wearing the `.expansion` case.
    @Test("device and display packs unlock no entries")
    func cosmeticPacksCoverNothing() {
        for pack in ExpansionPacks.device + ExpansionPacks.display {
            let entitlement = pack.entitlement
            for entry in db.entries {
                #expect(!entitlement.covers(entry, in: db), "\(pack.title) covered \(entry.name)")
            }
        }
    }

    /// A grant stored by a later build. It must degrade to covering nothing
    /// rather than to a crash or to covering everything.
    @Test("an unknown pack id covers nothing")
    func unknownPackIsInert() {
        let ghost = Entitlement.expansion("pack-from-the-future")
        #expect(ExpansionPacks.pack(id: "pack-from-the-future") == nil)
        for entry in db.entries {
            #expect(!ghost.covers(entry, in: db))
        }
        #expect(ghost.title == "PACK-FROM-THE-FUTURE PACK")
    }

    /// **The regression this batch's decision was made to avoid.**
    ///
    /// Packs collect rather than gate, and the operational form of that promise
    /// is this: on a default install — `starterOnly` off, nothing granted — not
    /// one entry in the catalog is locked, pack membership or no pack membership.
    /// `AccessTests.nothingLockedByDefault` asserts the same thing for the app as
    /// a whole; this one is here so that a future change to `covers` that broke
    /// it fails in the packs' own suite, next to the reasoning.
    @Test("packs lock nothing on a default install")
    func packsLockNothing() {
        let store = makeStore()
        #expect(store.starterOnly == false)
        for pack in ExpansionPacks.all {
            for entry in pack.entries(in: db) {
                #expect(!store.isLocked(entry, in: db))
            }
        }
    }

    /// And the other half: under the free-tier switch, a pack can only ever
    /// *unlock*. Nothing readable before the grant may be unreadable after it.
    @Test("granting a pack never locks anything that was open")
    func grantingOnlyUnlocks() {
        let store = makeStore()
        store.starterOnly = true
        let before = Set(db.entries.filter { !store.isLocked($0, in: db) }.map(\.id))

        store.grant(ExpansionPacks.oldWorld.entitlement)
        let after = Set(db.entries.filter { !store.isLocked($0, in: db) }.map(\.id))

        #expect(before.isSubset(of: after))
        #expect(after.count > before.count, "the Old World pack opened nothing")
    }

    // MARK: Ownership (E1)

    @Test("the skins bundle already owns every device cartridge")
    func skinsImplyDevicePacks() {
        let store = makeStore()
        store.starterOnly = true
        store.grant(.skins)

        for pack in ExpansionPacks.device {
            #expect(store.owns(pack), "\(pack.title) was revoked from a skins owner")
        }
        for pack in ExpansionPacks.display + ExpansionPacks.atlas {
            #expect(!store.owns(pack))
        }
    }

    @Test("a pack can be granted on its own, and pro owns them all")
    func grantsAndPro() {
        let store = makeStore()
        store.starterOnly = true
        #expect(ExpansionPacks.all.allSatisfy { !store.owns($0) })

        store.grant(ExpansionPacks.godforsaken.entitlement)
        #expect(store.owns(ExpansionPacks.godforsaken))
        #expect(!store.owns(ExpansionPacks.oldWorld))

        store.revokeAll()
        store.grant(.pro)
        #expect(ExpansionPacks.all.allSatisfy { store.owns($0) })
    }

    /// With the free-tier switch off — every real install — the shelf reports
    /// everything owned, because everything *is*. See `AccessStore.owns`.
    @Test("with the free tier off, every pack reads as owned")
    func everythingOwnedByDefault() {
        let store = makeStore()
        #expect(ExpansionPacks.all.allSatisfy { store.owns($0) })
    }

    // MARK: Collection progress

    @Test("progress counts tried grapes and styles, and only those")
    func progressCountsTheTriedShelf() {
        let pack = ExpansionPacks.oldWorld
        let members = pack.collectibleEntries(in: db)
        #expect(members.allSatisfy { $0.category == .grapes || $0.category == .styles })

        let empty = pack.progress(tried: [], in: db)
        #expect(empty?.collected == 0)
        #expect(empty?.total == members.count)
        #expect(empty?.fraction == 0)
        #expect(empty?.isComplete == false)

        // A region of the pack is not collectible, so marking it changes nothing.
        let regions = pack.entries(in: db).filter { $0.category == .regions }
        #expect(!regions.isEmpty)
        let withRegion = pack.progress(tried: Set(regions.map(\.id)), in: db)
        #expect(withRegion?.collected == 0)

        let full = pack.progress(tried: Set(members.map(\.id)), in: db)
        #expect(full?.collected == members.count)
        #expect(full?.isComplete == true)
        #expect(full?.fraction == 1)
    }

    /// Entries outside the pack must not count toward it, which is the one way a
    /// progress bar can be wrong without looking wrong.
    @Test("progress ignores entries outside the pack")
    func progressIgnoresOutsiders() {
        let pack = ExpansionPacks.godforsaken
        let outsiders = db.entries(in: .grapes).filter { !pack.contains($0) }
        #expect(!outsiders.isEmpty)
        #expect(pack.progress(tried: Set(outsiders.map(\.id)), in: db)?.collected == 0)
    }

    @Test("an empty pack is not a complete one")
    func emptyIsNotComplete() {
        #expect(PackProgress(collected: 0, total: 0).isComplete == false)
        #expect(PackProgress(collected: 0, total: 0).fraction == 0)
        #expect(PackProgress(collected: 3, total: 4).isComplete == false)
        #expect(PackProgress(collected: 4, total: 4).isComplete == true)
    }
}
