import Foundation

/// Where ownership actually lives (0.7.3, F1).
///
/// **What this is for.** Through 0.7.2 `AccessStore` both decided what "owned"
/// means and did its own `UserDefaults` reading and writing, which was fine
/// while ownership was a set of strings and will stop being fine the moment a
/// receipt is involved: StoreKit does not hand you a set to keep, it hands you a
/// stream of transactions to ask about. Splitting the two now means that day
/// changes one type — a `StoreKitEntitlementStore` conforming to this — and
/// touches no view, no gate and no call site.
///
/// **Deliberately not a persistence protocol.** The obvious shape was
/// `load()`/`save(_:)`, and it is the wrong one: a StoreKit adapter has nothing
/// to save, and forcing it to pretend would put a stale mirror of Apple's
/// receipt in `UserDefaults` — the exact bug this indirection is meant to avoid.
/// So the protocol asks the questions a *store* can answer, whatever it is
/// backed by, and lets the implementation decide whether answering means reading
/// a defaults key or a transaction history.
///
/// `@MainActor` because `AccessStore` is, and because the UI reads `owned`
/// during `body`. An adapter that talks to the network does its waiting inside
/// `refresh()`.
@MainActor
public protocol EntitlementStoring: AnyObject {
    /// Everything owned right now. The one question every gate in the app asks.
    var owned: Set<Entitlement> { get }

    /// Record an unlock. Idempotent — granting what is already owned is a no-op,
    /// not a duplicate.
    func grant(_ entitlement: Entitlement)

    /// Take one back. The developer harness uses this; a real storefront would
    /// not, which is why it is not called `refund`.
    func revoke(_ entitlement: Entitlement)

    /// Take them all back, leaving the store usable.
    func revokeAll()

    /// Back to install state, including any keys the store owns.
    ///
    /// Distinct from `revokeAll()` on purpose: that is the user-facing purchase
    /// reset, this is what CLEAR SAVED DATA calls, and a store backed by
    /// something other than defaults may have to do more than empty a set.
    func reset()

    /// Re-read the source of truth.
    ///
    /// A no-op locally — the set *is* the truth — and the whole of a StoreKit
    /// adapter's job. Present so callers that want fresh state have somewhere to
    /// ask, rather than the local implementation's "nothing to do" being baked
    /// into the app's structure.
    func refresh()
}

/// The on-device store: a set of ids in `UserDefaults` (0.7.3, F1).
///
/// This is exactly what `AccessStore` did inline through 0.7.2, moved behind the
/// protocol and otherwise unchanged — **same key, same encoding**. That is the
/// point rather than an implementation detail: `grantedEntitlements` holds real
/// grants on real installs, and a "cleaner" key or a JSON blob would silently
/// revoke every one of them on update. `Entitlement.id`'s spellings are load-
/// bearing for the same reason.
///
/// Sorted on write so the stored array is stable and a diff of a device's
/// defaults is readable.
@MainActor
public final class LocalEntitlementStore: EntitlementStoring {
    /// Unchanged since the paywall was one boolean. Do not rename.
    public static let storageKey = "grantedEntitlements"

    private let defaults: UserDefaults
    public private(set) var owned: Set<Entitlement>

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.owned = Set(
            (defaults.stringArray(forKey: Self.storageKey) ?? [])
                .compactMap(Entitlement.init(id:))
        )
    }

    public func grant(_ entitlement: Entitlement) {
        guard !owned.contains(entitlement) else { return }
        owned.insert(entitlement)
        persist()
    }

    public func revoke(_ entitlement: Entitlement) {
        guard owned.contains(entitlement) else { return }
        owned.remove(entitlement)
        persist()
    }

    public func revokeAll() {
        guard !owned.isEmpty else { return }
        owned.removeAll()
        persist()
    }

    public func reset() {
        owned.removeAll()
        defaults.removeObject(forKey: Self.storageKey)
    }

    /// Nothing to re-read: the stored set is the source of truth on this device.
    public func refresh() {}

    private func persist() {
        defaults.set(owned.map(\.id).sorted(), forKey: Self.storageKey)
    }
}

/// Anything cosmetic a bundle can gate (0.7.3, F1).
///
/// **The unification F1 asks for.** Skins and screen modes were already stored
/// in the one entitlement set — there was never a second store — but the *rule*
/// was copy-pasted into four view bodies:
///
/// ```swift
/// let locked = option != .classic && !access.isUnlocked(.skins)     // ×2
/// let locked = option != .dark    && !access.isUnlocked(.lightMode) // ×2
/// ```
///
/// Four places encoding which option is free and which bundle covers the rest,
/// none of them reachable from a test, in a module Linux cannot compile. A fifth
/// picker would have made it five. The knowledge belongs to the option, so the
/// option declares it and the one predicate below answers every caller.
///
/// `ChassisSkin` and `LcdMode` live in `VinodexUI` and conform there — Core
/// cannot see a `Color` — which is exactly why this is a protocol and not a
/// switch over an enum Core would have to import.
public protocol CosmeticOption {
    /// The bundle that unlocks this option, or `nil` when it ships free.
    ///
    /// `nil` rather than an `isFree` flag beside an entitlement, so "free" and
    /// "needs the skins bundle" cannot both be true of one option.
    var requiredEntitlement: Entitlement? { get }
}
