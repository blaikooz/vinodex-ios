import Foundation
import Testing
@testable import VinodexCore

/// The purchase seam (0.7.5, B2).
///
/// Modelled on `EntitlementStoreTests.acceptsAnInjectedStore`, which is the
/// suite's template for "prove the injection point works with a stub": F1's
/// argument was that a StoreKit adapter should drop into `AccessStore` without
/// touching a view, and the only way to know that is true is to drop something
/// else in and watch it work.
@MainActor
@Suite("Purchases")
struct PurchaseTests {
    private func makeStore(
        purchases: (any PurchaseProviding)? = nil
    ) -> AccessStore {
        let defaults = UserDefaults(suiteName: "purchases-\(UUID().uuidString)")!
        return AccessStore(defaults: defaults, purchases: purchases)
    }

    // MARK: The shipped provider

    @Test("the local provider grants immediately, which is 0.7.4's behaviour")
    func localPurchaseGrants() async {
        let access = makeStore()
        #expect(!access.granted.contains(.workshop))

        let outcome = await access.purchase(.workshop)

        #expect(outcome == .purchased(.workshop))
        #expect(access.granted.contains(.workshop))
    }

    /// Eggs are found, not bought. The one rule in `LocalPurchaseProvider` that
    /// is a property of the entitlement rather than a placeholder, so a real
    /// storefront inherits it.
    @Test("an easter egg cannot be bought")
    func eggsAreNotForSale() async {
        let access = makeStore()

        let outcome = await access.purchase(.easterEgg("verboseBoot"))

        #expect(outcome == .unavailable)
        #expect(access.granted.isEmpty)
    }

    @Test("what is already owned is not on sale")
    func ownedIsNotPurchasable() async {
        let access = makeStore()
        #expect(access.isPurchasable(.flavors))

        await access.purchase(.flavors)

        #expect(!access.isPurchasable(.flavors))
        // Still refused for the reason it always was, not because it is owned.
        #expect(!access.isPurchasable(.easterEgg("verboseBoot")))
    }

    /// A local restore would hand back the set it was given, which looks like a
    /// working feature and is not one — which is why the shop has no button for
    /// it on this build.
    @Test("the local provider restores nothing")
    func localRestoreIsEmpty() async {
        let access = makeStore()
        await access.purchase(.skins)

        let restored = await access.restorePurchases()

        #expect(restored.isEmpty)
        // And it does not revoke what was already there.
        #expect(access.granted.contains(.skins))
    }

    // MARK: The injection point

    /// Records what it was asked and answers however it was told to.
    private final class StubProvider: PurchaseProviding {
        var asked: [Entitlement] = []
        var restores = 0
        var outcome: PurchaseOutcome = .cancelled
        var owned: Set<Entitlement> = []

        func canPurchase(_ entitlement: Entitlement) -> Bool { true }

        func purchase(_ entitlement: Entitlement) async -> PurchaseOutcome {
            asked.append(entitlement)
            return outcome
        }

        func restore() async -> Set<Entitlement> {
            restores += 1
            return owned
        }
    }

    @Test("a provider can be injected, and it is the one that is asked")
    func acceptsAnInjectedProvider() async {
        let stub = StubProvider()
        stub.outcome = .purchased(.pro)
        let access = makeStore(purchases: stub)

        let outcome = await access.purchase(.pro)

        #expect(stub.asked == [.pro])
        #expect(outcome == .purchased(.pro))
        #expect(access.granted.contains(.pro))
    }

    /// The behaviour the three `UpgradePrompt` call sites depend on: they gate
    /// their "continue where you were going" step on the outcome, so a refusal
    /// must leave the store untouched.
    @Test("a cancelled purchase grants nothing")
    func cancellationGrantsNothing() async {
        let stub = StubProvider()
        stub.outcome = .cancelled
        let access = makeStore(purchases: stub)

        let outcome = await access.purchase(.pro)

        #expect(outcome == .cancelled)
        #expect(outcome.entitlement == nil)
        #expect(access.granted.isEmpty)
    }

    @Test("a failed purchase grants nothing and carries a reason")
    func failureGrantsNothing() async {
        let stub = StubProvider()
        stub.outcome = .failed("network")
        let access = makeStore(purchases: stub)

        let outcome = await access.purchase(.flavors)

        #expect(outcome == .failed("network"))
        #expect(access.granted.isEmpty)
    }

    /// A restore has to reach the observable mirror, not just the store — the
    /// specific trap `AccessStore.granted`'s own note names, and the one a
    /// StoreKit transaction listener will hit first.
    @Test("a restore grants what the provider found and updates the mirror")
    func restoreGrantsAndMirrors() async {
        let stub = StubProvider()
        stub.owned = [.skins, .lightMode]
        // Bought first, so the restore has something to *not* re-add. The stub
        // answers `.cancelled` unless told otherwise, which is what makes this
        // line load-bearing rather than decorative.
        stub.outcome = .purchased(.skins)
        let access = makeStore(purchases: stub)
        await access.purchase(.skins)

        let added = await access.restorePurchases()

        #expect(stub.restores == 1)
        // Only what was missing is reported as restored.
        #expect(added == [.lightMode])
        #expect(access.granted == [.skins, .lightMode])
    }

    /// The provider must not write ownership itself; `AccessStore` does, in one
    /// place. If a provider ever grew a store reference this would still pass,
    /// so it is the *shape* being pinned: a provider that returns `.cancelled`
    /// can have no effect on the entitlement store at all.
    @Test("the provider never writes ownership on its own")
    func providerDoesNotRecord() async {
        let stub = StubProvider()
        stub.outcome = .cancelled
        let defaults = UserDefaults(suiteName: "purchases-\(UUID().uuidString)")!
        let store = LocalEntitlementStore(defaults: defaults)
        let access = AccessStore(defaults: defaults, store: store, purchases: stub)

        await access.purchase(.workshop)

        #expect(store.owned.isEmpty)
        #expect(access.granted.isEmpty)
    }

    // MARK: The default

    /// `AccessStore()` must keep behaving as it did before B2 for every caller
    /// that does not name a provider — which is all of them but the tests.
    @Test("the default provider is the local one")
    func defaultsToLocal() async {
        let access = makeStore(purchases: nil)

        #expect(await access.purchase(.lightMode) == .purchased(.lightMode))
    }
}
