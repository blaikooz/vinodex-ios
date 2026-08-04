import Foundation
import Observation

/// Whether the app is running as the free tier, and which bundles have been
/// bought on top of it.
///
/// **The one place the app asks "does the user have this".** Content pages
/// (`isLocked`), cosmetics (`isUnlocked`), cheat codes, and — from 0.7.3b and
/// 0.7.3c — the workshop and the expansion packs all come through here. F1's
/// instruction was to unify rather than fork, and the honest finding was that
/// most of the unifying had already happened: there has only ever been one
/// entitlement set. What had forked was the *rule* for cosmetics, copy-pasted
/// into four view bodies; see `CosmeticOption`.
///
/// **Storage moved out in 0.7.3 (F1).** Reading and writing `UserDefaults` is
/// now `LocalEntitlementStore` behind `EntitlementStoring`, so a StoreKit
/// adapter can take its place without this type or any view changing. This kept
/// the half that is genuinely policy: what the free-tier switch means, what a
/// bundle covers, and the `Observable` identity SwiftUI watches.
///
/// `starterOnly` is deliberately not called "purchased" — it is the developer
/// switch for seeing the locked experience, and calling it what it is keeps that
/// honest. It used to be the whole mechanism: free tier, or everything. That is
/// one edge case out of many, and it made the interesting states unreachable —
/// there was no way to see the app as someone who bought the flavour wheel but
/// not the atlas, or one country and nothing else. See `Entitlement`.
///
/// **Off by default**, so a fresh install shows the whole dataset.
@MainActor
@Observable
public final class AccessStore {
    public static let shared = AccessStore()

    public static let storageKey = "starterTierOnly"
    /// Kept as an alias of the store's key. Nothing in the app reads it any
    /// more, and removing it would break the one thing an external reader
    /// (a test, a defaults dump) uses to find the grants.
    public static var entitlementsKey: String { LocalEntitlementStore.storageKey }

    private let defaults: UserDefaults
    private let store: any EntitlementStoring

    /// `true` = free tier: only the starter selection plus whatever bundles
    /// have been granted are browsable.
    public var starterOnly: Bool {
        didSet {
            guard starterOnly != oldValue else { return }
            defaults.set(starterOnly, forKey: Self.storageKey)
        }
    }

    /// Bundles the user owns.
    ///
    /// Mirrored out of the store rather than forwarded to it: `@Observable`
    /// tracks property reads on *this* object, and a computed property reading
    /// through to a plain class would leave every gate in the app un-invalidated
    /// when a grant landed. The store stays the source of truth; this is the
    /// observable projection of it, refreshed on every mutation below.
    public private(set) var granted: Set<Entitlement>

    /// - Parameter store: defaults to the on-device store. Injected by tests,
    ///   and the seam a `StoreKitEntitlementStore` slots into.
    public init(
        defaults: UserDefaults = .standard,
        store: (any EntitlementStoring)? = nil
    ) {
        self.defaults = defaults
        self.store = store ?? LocalEntitlementStore(defaults: defaults)
        // `bool(forKey:)` returns false for a missing key, which is the default
        // we want anyway.
        self.starterOnly = defaults.bool(forKey: Self.storageKey)
        self.granted = self.store.owned
    }

    // MARK: Grants

    public func grant(_ entitlement: Entitlement) {
        store.grant(entitlement)
        sync()
    }

    public func revoke(_ entitlement: Entitlement) {
        store.revoke(entitlement)
        sync()
    }

    public func toggle(_ entitlement: Entitlement) {
        if granted.contains(entitlement) {
            revoke(entitlement)
        } else {
            grant(entitlement)
        }
    }

    /// Wipes every purchase. The control that makes the other states testable
    /// more than once.
    public func revokeAll() {
        store.revokeAll()
        sync()
    }

    /// Everything back to install state: tier off, no bundles, both stored
    /// keys removed. `revokeAll` is the user-facing purchase reset; this one
    /// exists for CLEAR SAVED DATA, which also unwinds the developer switch.
    public func clearAll() {
        starterOnly = false
        defaults.removeObject(forKey: Self.storageKey)
        store.reset()
        sync()
    }

    /// Ask the store again — a receipt refresh, once there is a receipt.
    public func refresh() {
        store.refresh()
        sync()
    }

    /// Pull the store's answer back into the observed property.
    ///
    /// Assigned unconditionally rather than guarded on inequality: `Set` is
    /// `Equatable`, so an unchanged assignment is cheap, and a guard here would
    /// be a second place for the mirror to fall out of step with the store.
    private func sync() {
        granted = store.owned
    }

    // MARK: Queries

    /// Whether a cosmetic bundle is available.
    ///
    /// Free-tier off means everything is unlocked, so flipping the tier switch
    /// back gives the whole app without having to re-grant each bundle by hand.
    public func isUnlocked(_ entitlement: Entitlement) -> Bool {
        guard starterOnly else { return true }
        return granted.contains(.pro) || granted.contains(entitlement)
    }

    /// Whether a cosmetic option is available (0.7.3, F1).
    ///
    /// The single predicate the skin and screen-mode pickers now share. Each
    /// option names the bundle it needs — or `nil` if it is the free one — and
    /// this answers for all of them, so adding a picker cannot reintroduce the
    /// `option != .classic && !access.isUnlocked(.skins)` pattern that was
    /// written out four times by 0.7.2. See `CosmeticOption`.
    ///
    /// Free options short-circuit ahead of the free-tier switch: the default
    /// skin is not a bundle anyone can fail to own.
    public func isUnlocked(_ option: some CosmeticOption) -> Bool {
        guard let required = option.requiredEntitlement else { return true }
        return isUnlocked(required)
    }

    /// Whether an easter egg has been found (0.7.3, F1).
    ///
    /// Bypasses `starterOnly` entirely, and that is the difference between an
    /// unlock and a purchase: `isUnlocked(_:)` answers `true` for everything
    /// when the free-tier switch is off, which is right for a paywall and wrong
    /// here — it would mean every hidden feature in the app is on by default for
    /// every user, and the cheat console would have nothing to reveal.
    public func hasFound(_ egg: String) -> Bool {
        granted.contains(.easterEgg(egg))
    }

    /// Whether this entry is gated right now.
    ///
    /// Free entries are always readable; beyond those, any granted bundle that
    /// covers the entry opens it.
    public func isLocked(_ entry: WineEntry, in db: WineDatabase) -> Bool {
        guard starterOnly else { return false }
        if db.isFree(entry.id) { return false }
        return !granted.contains { $0.covers(entry, in: db) }
    }

    /// Id-only overload, for call sites that have not resolved the entry.
    ///
    /// Bundle coverage needs the entry's category and origin, so an id that
    /// does not resolve falls back to the free-tier check alone.
    public func isLocked(_ id: String, in db: WineDatabase) -> Bool {
        guard let entry = db.entry(id: id) else {
            return starterOnly && !db.isFree(id)
        }
        return isLocked(entry, in: db)
    }
}
