import Foundation

/// How an entitlement is *acquired* (0.7.5, B2).
///
/// **The other half of F1's seam, and deliberately a second protocol.** 0.7.3a
/// split "where ownership lives" out of `AccessStore` into `EntitlementStoring`
/// so a `StoreKitEntitlementStore` could answer "what do you own?" from a
/// transaction history instead of a defaults key. What it did not split out is
/// the step *before* that — the one where money changes hands — because at the
/// time there was no step: `UpgradePrompt` called `access.grant(_:)` on confirm,
/// and its own doc says as much ("There is still no payment step. When there is
/// one, it goes between the tap and `onUnlock`"). B2 makes the shop the route
/// for paid content, so that gap becomes the thing to build.
///
/// **Two protocols rather than one, because they answer to different owners.**
/// A store answers to the device; a provider answers to a payment system. Apple
/// decides whether a purchase succeeded, and the app then *records* the result —
/// so folding `purchase` into `EntitlementStoring` would give the local store a
/// method it can only lie about, and would make `LocalEntitlementStore`, which
/// exists to be an honest set of ids, into a pretend cashier. They compose in
/// `AccessStore` instead, which is where the two already meet.
///
/// **Async, and that is the whole point of the shape.** `Product.purchase()` is
/// `async throws` and puts a system sheet on screen; a synchronous seam would be
/// unimplementable by the one adapter it exists for, which is the failure mode
/// F1 was written to avoid. The cost is three `Task { }`s at the call sites, and
/// that is the correct cost.
///
/// **There is no StoreKit here and no payment path of any kind.**
/// `LocalPurchaseProvider` below grants immediately — *exactly* today's
/// behaviour, unchanged — so this batch moves no money and changes nothing a
/// user can observe. What a real adapter would have to supply is listed on
/// `LocalPurchaseProvider`; none of it is guessed at here.
///
/// `@MainActor` for the same reason `EntitlementStoring` is: `AccessStore` is,
/// and the outcome lands on state the UI reads during `body`.
@MainActor
public protocol PurchaseProviding: AnyObject {
    /// Whether this provider can sell the thing at all.
    ///
    /// Not every entitlement is a product: `.easterEgg` is found, not bought,
    /// and a provider fronted by a real storefront can only offer what it has
    /// products for. A shop asks this before drawing a price, so a missing
    /// product is a tile that does not offer to sell rather than a purchase
    /// that fails after the tap.
    func canPurchase(_ entitlement: Entitlement) -> Bool

    /// Attempt to buy it.
    ///
    /// Returns rather than throws: "the user changed their mind" is the single
    /// most common result and is not an error, and a `PurchaseOutcome` makes the
    /// caller handle it. The provider does **not** record ownership — see
    /// `AccessStore.purchase(_:)`, which grants on `.purchased` and is the one
    /// place a successful purchase becomes a grant.
    func purchase(_ entitlement: Entitlement) async -> PurchaseOutcome

    /// Everything this provider can prove was already paid for.
    ///
    /// Required by the platform for non-consumable purchases, and meaningless
    /// locally — which is why the local implementation returns nothing rather
    /// than returning what the device happens to have, a "restore" that restores
    /// the state it was handed being worse than no restore at all.
    func restore() async -> Set<Entitlement>
}

/// What came of a purchase attempt (0.7.5, B2).
///
/// Cancellation and unavailability are separated from failure because a shop has
/// to treat them differently: one is silent, one greys the tile out, and only the
/// third is worth an alert.
public enum PurchaseOutcome: Sendable, Equatable {
    /// Paid for. The caller grants it; the provider does not.
    case purchased(Entitlement)
    /// The user backed out. Not an error, and nothing should be said about it.
    case cancelled
    /// No product exists for this entitlement, or the storefront is unreachable.
    case unavailable
    /// It went wrong, with something a person could be shown.
    case failed(String)

    /// Convenience for the common branch.
    public var entitlement: Entitlement? {
        if case .purchased(let entitlement) = self { return entitlement }
        return nil
    }
}

/// The provider this build ships with: everything is free and instant.
///
/// **This is today's behaviour, moved behind the protocol and otherwise
/// unchanged.** Before 0.7.5 an unlock was `access.grant(offer)` in the confirm
/// handler of `UpgradePrompt`; it is now that same grant, reached through
/// `AccessStore.purchase(_:)`. Nothing about what the app does has changed, and
/// that is the intent — B2 asks for the seam, not for a storefront.
///
/// **What a `StoreKitPurchaseProvider` would have to fill in**, written down
/// here because the next person to open this file is the person writing it, and
/// none of it is invented in this batch:
///
/// 1. **A product-identifier mapping, which does not exist anywhere yet.**
///    `Entitlement.id` is *storage* — `LocalEntitlementStore` writes those exact
///    strings and `EntitlementStoreTests.storageIsCompatible` pins them — so it
///    must not be quietly reused as an App Store product id. The mapping is a
///    new table, in both directions, and it must be total over whatever the shop
///    offers or `canPurchase` will say yes to something with nothing behind it.
/// 2. **Twenty-one products, or a decision not to sell some of them.** Eight
///    `Entitlement` cases, three of which carry associated values: twelve packs
///    through `.expansion`, one per country through `.country`, and `.easterEgg`,
///    which must never be purchasable.
/// 3. **A `Transaction.updates` listener, and it must land through
///    `AccessStore`.** `AccessStore.granted` is an observable *mirror* of the
///    store's set, refreshed by `sync()`; a transaction arriving on a background
///    task that writes straight to the entitlement store updates ownership
///    without updating the mirror, and the UI keeps drawing the old answer. This
///    is the specific trap in this design and the reason `purchase` returns to
///    `AccessStore` rather than to a view.
/// 4. **Restore.** `AppStore.sync()` plus a sweep of `Transaction.currentEntitlements`,
///    mapped back through (1). `restore()` returns the set; `AccessStore` grants it.
/// 5. **Verification and revocation.** `VerificationResult` unwrapping, and a
///    decision about refunded or revoked transactions — the local store has no
///    notion of ownership being taken away by anyone but the user.
///
/// None of the above is scaffolded here. An empty StoreKit shell would be a
/// second thing to keep working with nothing behind it, which is the fault
/// `CheatCodes`' own note names about codes that report success and do nothing.
@MainActor
public final class LocalPurchaseProvider: PurchaseProviding {
    public init() {}

    /// Everything except an easter egg, which is found rather than sold.
    ///
    /// The one rule that is *not* a placeholder: it is a property of what the
    /// entitlement means, so a real storefront inherits it rather than
    /// re-deciding it.
    public func canPurchase(_ entitlement: Entitlement) -> Bool {
        if case .easterEgg = entitlement { return false }
        return true
    }

    public func purchase(_ entitlement: Entitlement) async -> PurchaseOutcome {
        guard canPurchase(entitlement) else { return .unavailable }
        return .purchased(entitlement)
    }

    /// Nothing. See the protocol: a local restore would hand back the set it was
    /// given, which looks like a working feature and is not one.
    public func restore() async -> Set<Entitlement> { [] }
}
