import Foundation
import Observation

/// Which passport badges the user has already been told about (0.7.1, D2).
///
/// **The problem D2 exposes.** `Passport` is documented as "pure arithmetic
/// over the tried ids and the database, computed on demand — no store, no
/// persistence, nothing to migrate", and that is a genuinely good property: a
/// badge cannot get out of step with the shelf it describes, because it *is*
/// the shelf, recomputed. But it means the app can only ever answer "is this
/// earned", never "did this just become earned". D2 asks for a moment, and a
/// pure predicate has no moments in it.
///
/// So the diff lives here instead of in `Passport`, and the split is the point:
/// `Passport` keeps knowing nothing, and this remembers exactly one thing —
/// the set of ids already announced. Everything else is still derived.
///
/// **`announce` is not idempotent, and must not be.** It returns the newly
/// earned ids *and* records them in the same call, which is what makes it safe
/// to call from a view: a body that re-renders twice cannot fire the same
/// celebration twice. That is `QuizProgress.recordPass(tier:)`'s contract too,
/// and its call site carries the warning this one inherits — record at the
/// moment the thing happens, never in a view body.
@MainActor
@Observable
public final class PassportProgress {
    public static let shared = PassportProgress()

    /// Badge ids already announced, comma-joined.
    ///
    /// Ids, not indices or a bitmask: the badge list is ordered today and a
    /// seventh badge could plausibly be inserted rather than appended, at which
    /// point a positional encoding would silently re-announce everything after
    /// it.
    public static let storageKey = "passportSeenBadges"

    private let defaults: UserDefaults
    private(set) public var seen: Set<String>

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        seen = Set(raw.split(separator: ",").map(String.init)).filter { !$0.isEmpty }
    }

    /// Whether anything has been recorded yet.
    ///
    /// The distinction `seed(with:)` needs: an empty set on a device that has
    /// been used for a year is not the same claim as an empty set on a fresh
    /// install, and only one of them should produce six popups.
    public var isEmpty: Bool { seen.isEmpty }

    /// The badges earned since the last call, in catalog order — and they are
    /// marked announced by the act of asking.
    @discardableResult
    public func announce(_ passport: Passport) -> [BackPlateStamp] {
        let earned = passport.badges.filter(\.earned).map(\.id)
        let fresh = earned.filter { !seen.contains($0) }
        guard !fresh.isEmpty else { return [] }
        seen.formUnion(fresh)
        persist()
        return fresh.compactMap { StampCatalog.stamp(for: $0) }
    }

    /// Mark everything currently earned as already announced, without
    /// returning it.
    ///
    /// **This is the upgrade path, and it is load-bearing.** Every existing
    /// user arrives at 0.7.1 with badges earned and nothing recorded, so the
    /// first `announce` would hand them a queue of up to six celebrations for
    /// things they did weeks ago. The app seeds once, on first launch after
    /// the update, and the difference between "seeded to empty" and "never
    /// seeded" is a separate flag rather than the emptiness of the set —
    /// because a genuinely new user with no badges must also be seeded, and
    /// their seed is empty too.
    public func seed(with passport: Passport) {
        guard !defaults.bool(forKey: Self.seededKey) else { return }
        seen = Set(passport.badges.filter(\.earned).map(\.id))
        defaults.set(true, forKey: Self.seededKey)
        persist()
    }

    public func reset() {
        seen = []
        defaults.removeObject(forKey: Self.seededKey)
        persist()
    }

    static let seededKey = "passportSeenBadgesSeeded"

    private func persist() {
        if seen.isEmpty {
            defaults.removeObject(forKey: Self.storageKey)
        } else {
            defaults.set(seen.sorted().joined(separator: ","), forKey: Self.storageKey)
        }
    }
}
