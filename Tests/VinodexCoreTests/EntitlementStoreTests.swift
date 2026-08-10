import Testing
import Foundation
@testable import VinodexCore

/// The entitlement store behind the protocol (0.7.3, F1).
@MainActor
@Suite("Entitlement store")
struct EntitlementStoreTests {
    private func suite() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// **The compatibility pin.** `grantedEntitlements` holds real grants on
    /// real installs. A "cleaner" key or a JSON blob would silently revoke every
    /// one of them on update, and nothing would report it — the user would just
    /// find their skins locked again.
    @Test("the storage key and encoding are unchanged")
    func storageIsCompatible() {
        let defaults = suite()
        #expect(LocalEntitlementStore.storageKey == "grantedEntitlements")
        #expect(AccessStore.entitlementsKey == LocalEntitlementStore.storageKey)

        let store = LocalEntitlementStore(defaults: defaults)
        store.grant(.skins)
        store.grant(.country("Italy"))

        // A sorted array of `Entitlement.id` strings, exactly as through 0.7.2.
        let raw = defaults.stringArray(forKey: LocalEntitlementStore.storageKey)
        #expect(raw == ["country:Italy", "skins"])
    }

    /// A set written by the old code reads back through the new store.
    @Test("grants written before 0.7.3 still load")
    func readsLegacyGrants() {
        let defaults = suite()
        defaults.set(["flavors", "lightMode", "country:France"], forKey: LocalEntitlementStore.storageKey)

        let store = LocalEntitlementStore(defaults: defaults)
        #expect(store.owned == [.flavors, .lightMode, .country("France")])

        // And through the façade the app actually uses.
        let access = AccessStore(defaults: defaults)
        #expect(access.granted == [.flavors, .lightMode, .country("France")])
    }

    /// An id the current build cannot parse is dropped rather than crashing the
    /// load — a device that owned a pack from a later build must still boot.
    @Test("an unrecognised id is dropped, not fatal")
    func unknownIDsAreDropped() {
        let defaults = suite()
        defaults.set(["skins", "sorcery:unknown", ""], forKey: LocalEntitlementStore.storageKey)
        #expect(LocalEntitlementStore(defaults: defaults).owned == [.skins])
    }

    @Test("granting is idempotent and revoking is exact")
    func grantAndRevoke() {
        let store = LocalEntitlementStore(defaults: suite())
        store.grant(.workshop)
        store.grant(.workshop)
        #expect(store.owned == [.workshop])

        store.revoke(.skins)
        #expect(store.owned == [.workshop], "revoking something unowned changed the set")

        store.revoke(.workshop)
        #expect(store.owned.isEmpty)
    }

    /// `revokeAll` empties the set but leaves the store usable; `reset` also
    /// takes the key away. CLEAR SAVED DATA calls the second.
    @Test("revokeAll and reset differ where it matters")
    func revokeAllVersusReset() {
        let defaults = suite()
        let store = LocalEntitlementStore(defaults: defaults)
        store.grant(.pro)

        store.revokeAll()
        #expect(store.owned.isEmpty)
        #expect(defaults.object(forKey: LocalEntitlementStore.storageKey) != nil, "the key survives a revoke")

        store.grant(.pro)
        store.reset()
        #expect(store.owned.isEmpty)
        #expect(defaults.object(forKey: LocalEntitlementStore.storageKey) == nil, "reset leaves no key behind")
    }

    /// **The seam a StoreKit adapter slots into.** If this compiles and passes,
    /// the swap F1 asks for is a one-line change at the call site — no view, no
    /// gate and no query moves.
    @Test("AccessStore works against an injected store")
    func acceptsAnInjectedStore() {
        final class StubStore: EntitlementStoring {
            var owned: Set<Entitlement> = [.pro]
            private(set) var refreshes = 0
            func grant(_ entitlement: Entitlement) { owned.insert(entitlement) }
            func revoke(_ entitlement: Entitlement) { owned.remove(entitlement) }
            func revokeAll() { owned.removeAll() }
            func reset() { owned.removeAll() }
            func refresh() { refreshes += 1 }
        }

        let stub = StubStore()
        let access = AccessStore(defaults: suite(), store: stub)
        access.starterOnly = true

        // Seeded from the store rather than from defaults.
        #expect(access.granted == [.pro])
        #expect(access.isUnlocked(.skins), "pro supersedes every bundle")

        access.grant(.workshop)
        #expect(stub.owned.contains(.workshop), "the grant did not reach the store")
        #expect(access.granted.contains(.workshop), "the observable mirror did not follow")

        access.refresh()
        #expect(stub.refreshes == 1)
    }

    /// The observable mirror has to follow the store on every path, or a gate
    /// keeps answering with a stale set.
    @Test("the mirror tracks the store through every mutation")
    func mirrorStaysInStep() {
        let access = AccessStore(defaults: suite())
        access.grant(.flavors)
        #expect(access.granted == [.flavors])

        access.toggle(.flavors)
        #expect(access.granted.isEmpty)

        access.toggle(.flavors)
        access.grant(.skins)
        access.revokeAll()
        #expect(access.granted.isEmpty)

        access.grant(.lightMode)
        access.clearAll()
        #expect(access.granted.isEmpty)
        #expect(access.starterOnly == false)
    }
}

/// The cosmetic gate the pickers share (0.7.3, F1).
///
/// `ChassisSkin` and `LcdMode` conform in `VinodexUI`, which Linux cannot
/// compile — so the conformances themselves are proved by the clean xtool build,
/// and what is pinned here is the predicate they all go through.
@MainActor
@Suite("Cosmetic gating")
struct CosmeticGateTests {
    private struct Option: CosmeticOption {
        let requiredEntitlement: Entitlement?
    }

    private func makeStore() -> AccessStore {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AccessStore(defaults: defaults)
    }

    /// The free option is free even behind the paywall — the default skin is not
    /// a bundle anyone can fail to own.
    @Test("a free option is never gated")
    func freeOptionIsFree() {
        let store = makeStore()
        store.starterOnly = true
        #expect(store.isUnlocked(Option(requiredEntitlement: nil)))
    }

    /// **The four copy-pasted gates, in one place.** Through 0.7.2 this rule was
    /// written out twice for skins and twice for modes, in view bodies Linux
    /// cannot see.
    @Test("a gated option follows its bundle")
    func gatedOptionFollowsItsBundle() {
        let store = makeStore()
        let skin = Option(requiredEntitlement: .skins)
        let mode = Option(requiredEntitlement: .lightMode)

        // Paywall off: everything is available, which is the fresh-install state.
        #expect(store.isUnlocked(skin))
        #expect(store.isUnlocked(mode))

        store.starterOnly = true
        #expect(!store.isUnlocked(skin))
        #expect(!store.isUnlocked(mode))

        store.grant(.skins)
        #expect(store.isUnlocked(skin))
        #expect(!store.isUnlocked(mode), "the skins bundle must not open the screen modes")

        store.grant(.pro)
        #expect(store.isUnlocked(mode), "pro supersedes every bundle")
    }
}
