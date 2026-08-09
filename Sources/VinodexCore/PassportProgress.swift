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
        // `object(forKey:)` rather than `integer(forKey:)`: the latter answers 0
        // for an absent key, and 0 is MASTER — "never announced" and "announced
        // MASTER" are different states and the first must not decode as the
        // second (0.8.7, D1). Still index 0 after 0.8.9b, which is the whole
        // point of appending APPRENTICE rather than prepending it.
        seenTierRank = defaults.object(forKey: Self.tierStorageKey) as? Int
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
        seenTierRank = nil
        defaults.removeObject(forKey: Self.seededKey)
        defaults.removeObject(forKey: Self.tierSeededKey)
        persist()
        persistTier()
    }

    static let seededKey = "passportSeenBadgesSeeded"

    private func persist() {
        if seen.isEmpty {
            defaults.removeObject(forKey: Self.storageKey)
        } else {
            defaults.set(seen.sorted().joined(separator: ","), forKey: Self.storageKey)
        }
    }

    // MARK: - The ladder (0.8.7, D1)

    /// The highest rung already announced, as `PassportTier.storageIndex`.
    ///
    /// **The index, not the tier.** `PassportTier`'s rawValue *is* its display
    /// copy — `PassportProgressionTests.tiersAreNotStorage` pins that equality
    /// precisely so a rung can be renamed without a migration, and its own note
    /// says "the moment a tier is written to defaults, the rename freedom is
    /// gone and this test should be the thing that forces the conversation".
    /// This is that conversation, and the answer is to store the thing that is
    /// not the label.
    ///
    /// **0.8.9b tested that promise and it held.** LEGEND became LEGENDARY and
    /// IMMORTAL became WINE MONK, all four lost the `VINODEX ` prefix, and not a
    /// byte of stored state moved — because what is on disk is a declaration
    /// index and those four declarations did not move. The same batch added a
    /// rung *below* MASTER, which is the thing this scheme genuinely could not
    /// absorb, and the answer was to append it rather than insert it: see
    /// `PassportTier`'s type note.
    ///
    /// The consequence for this file is one line, and it is `announceTier`'s
    /// comparison. Declaration order is no longer the ladder, so "have I already
    /// announced something at least this high" is a **threshold** question now.
    /// Comparing the raw stored integers would say APPRENTICE (index 4) outranks
    /// WINE MONK (index 3).
    ///
    /// The key keeps its 0.8.7 spelling on purpose — renaming a defaults key is
    /// a migration, and none of this is one.
    public static let tierStorageKey = "passportSeenTierRank"

    /// **A second flag, and the whole of D1's upgrade safety.**
    ///
    /// It would have been tidier to fold the ladder into `seededKey` and seed
    /// both together. That is exactly the bug 0.7.5 flagged against `seed`
    /// running once ever: `seededKey` has been true on every install since
    /// 0.7.1, so a ladder guarded by it would never be seeded at all, and the
    /// first `announceTier` after this update would celebrate a rank the user
    /// has held for months. A vocabulary added later needs a flag added later.
    static let tierSeededKey = "passportSeenTierSeeded"

    /// nil means nothing has been announced — which is also a genuinely
    /// unranked player, and is why the flag above exists separately.
    private(set) public var seenTierRank: Int?

    /// The rung crossed since the last call, or nil.
    ///
    /// Returns *the tier now held* rather than each rung passed on the way: the
    /// ladder can be climbed by more than one rung in a single tasting only by
    /// importing a shelf, and three stacked celebrations for one tap would be
    /// the unreadable pile `advanceUnlockQueue` avoids for stamps. Recorded by
    /// the act of asking, on `announce`'s contract and for its reason.
    @discardableResult
    public func announceTier(_ passport: Passport) -> PassportTier? {
        guard let tier = passport.tier else { return nil }
        // By threshold, never by stored index — see `tierStorageKey`. An index
        // this build does not know resolves to nil and is treated as "nothing
        // announced", which at worst repeats one card and never invents a
        // demotion.
        if let seen = seenTierRank.flatMap(PassportTier.fromStorage),
           seen.threshold >= tier.threshold { return nil }
        seenTierRank = tier.storageIndex
        persistTier()
        return tier
    }

    /// Mark the rung currently held as already announced. Once ever, on its own
    /// flag — see `tierSeededKey`.
    public func seedTier(with passport: Passport) {
        guard !defaults.bool(forKey: Self.tierSeededKey) else { return }
        seenTierRank = passport.tier?.storageIndex
        defaults.set(true, forKey: Self.tierSeededKey)
        persistTier()
    }

    /// Whether either ledger still owes a seed.
    ///
    /// Exposed so a screen can decide *not* to compute a `Passport` — see
    /// `seedIfNeeded`.
    public var needsSeeding: Bool {
        !defaults.bool(forKey: Self.seededKey) || !defaults.bool(forKey: Self.tierSeededKey)
    }

    /// Seed both ledgers, computing the passport only if one of them needs it.
    ///
    /// **Why this exists rather than another `seed(with:)` call site.** Seeding
    /// has happened in exactly one place since 0.7.1 — the passport screen's
    /// `task` — which leaves a hole D1 makes reachable: a user who updates and
    /// then taps TRIED without ever opening the passport announces against an
    /// unseeded ledger. For badges that hole has been open since 0.7.1 and costs
    /// a stale celebration; for the ladder it would cost one on the *first tap
    /// after updating*, which is the likeliest thing a returning player does.
    ///
    /// So the entry page seeds on appear, which is always before its own TRIED
    /// pill can be pressed. `@autoclosure` keeps that free: after the first
    /// launch `needsSeeding` is false and the passport is never computed, so
    /// opening an entry does not walk the catalog for a flag that will be false
    /// for the rest of the install's life.
    public func seedIfNeeded(_ passport: @autoclosure () -> Passport) {
        guard needsSeeding else { return }
        let computed = passport()
        seed(with: computed)
        seedTier(with: computed)
    }

    private func persistTier() {
        if let seenTierRank {
            defaults.set(seenTierRank, forKey: Self.tierStorageKey)
        } else {
            defaults.removeObject(forKey: Self.tierStorageKey)
        }
    }
}
