import Foundation
import Observation

/// Whether the app is running as the free tier, and which bundles have been
/// bought on top of it.
///
/// This is the shape a real IAP would plug into: `granted` becomes a receipt
/// check instead of a stored set, and nothing else has to move. `starterOnly`
/// is deliberately not called "purchased" — it is the developer switch for
/// seeing the locked experience, and calling it what it is keeps that honest.
///
/// It used to be that switch alone: free tier, or everything. That is one edge
/// case out of many, and it made the interesting states unreachable — there was
/// no way to see the app as someone who bought the flavour wheel but not the
/// atlas, or one country and nothing else. See `Entitlement`.
///
/// **Off by default**, so a fresh install shows the whole dataset.
@MainActor
@Observable
public final class AccessStore {
    public static let shared = AccessStore()

    public static let storageKey = "starterTierOnly"
    public static let entitlementsKey = "grantedEntitlements"

    private let defaults: UserDefaults

    /// `true` = free tier: only the starter selection plus whatever bundles
    /// have been granted are browsable.
    public var starterOnly: Bool {
        didSet {
            guard starterOnly != oldValue else { return }
            defaults.set(starterOnly, forKey: Self.storageKey)
        }
    }

    /// Bundles the user owns. Persisted by `Entitlement.id`.
    public private(set) var granted: Set<Entitlement>

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `bool(forKey:)` returns false for a missing key, which is the default
        // we want anyway.
        self.starterOnly = defaults.bool(forKey: Self.storageKey)
        self.granted = Set(
            (defaults.stringArray(forKey: Self.entitlementsKey) ?? [])
                .compactMap(Entitlement.init(id:))
        )
    }

    // MARK: Grants

    public func grant(_ entitlement: Entitlement) {
        guard !granted.contains(entitlement) else { return }
        granted.insert(entitlement)
        persist()
    }

    public func revoke(_ entitlement: Entitlement) {
        guard granted.contains(entitlement) else { return }
        granted.remove(entitlement)
        persist()
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
        guard !granted.isEmpty else { return }
        granted.removeAll()
        persist()
    }

    private func persist() {
        defaults.set(granted.map(\.id).sorted(), forKey: Self.entitlementsKey)
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
