import Foundation
import Observation

/// Whether the app is running as the free tier or with everything unlocked.
///
/// This is the shape a real IAP would plug into: the paid state becomes a
/// receipt check instead of a stored flag, and nothing else has to move. It is
/// deliberately not called "purchased" — right now it is a developer switch for
/// seeing the locked experience, and calling it what it is keeps that honest.
///
/// **Off by default**, so a fresh install shows the whole dataset.
@MainActor
@Observable
public final class AccessStore {
    public static let shared = AccessStore()

    public static let storageKey = "starterTierOnly"

    private let defaults: UserDefaults

    /// `true` = free tier: only the starter selection is browsable.
    public var starterOnly: Bool {
        didSet {
            guard starterOnly != oldValue else { return }
            defaults.set(starterOnly, forKey: Self.storageKey)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `bool(forKey:)` returns false for a missing key, which is the default
        // we want anyway.
        self.starterOnly = defaults.bool(forKey: Self.storageKey)
    }

    /// Whether this entry is gated behind Vinodex Pro right now.
    public func isLocked(_ id: String, in db: WineDatabase) -> Bool {
        starterOnly && !db.isFree(id)
    }

    public func isLocked(_ entry: WineEntry, in db: WineDatabase) -> Bool {
        isLocked(entry.id, in: db)
    }
}
