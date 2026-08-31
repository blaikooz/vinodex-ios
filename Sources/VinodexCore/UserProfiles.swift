import Foundation
import Observation

/// Named snapshots of the whole saved state — up to five of them (0.8.92,
/// item 5).
///
/// **What a profile is.** Everything the app persists lives in
/// `UserDefaults` under the app's own domain: the shelves, ratings, streaks,
/// purchases, skin, screen mode, the lot. A profile is that domain,
/// filtered to the app's own keys and written to a plist on disk. SAVE
/// captures the current domain into a slot; LOAD replaces the current domain
/// with a slot's snapshot and the app relaunches into it — see
/// `ProfileSwitcher` in `VinodexUI` for the destructive half and why it ends
/// in `exit(0)` rather than a live reload.
///
/// **Why snapshots and not a keyed namespace.** The honest alternative is
/// prefixing every storage key with a profile id, which would mean touching
/// all ~40 stores, every `@AppStorage` declaration, and every raw-key read —
/// the exact surface the migration-hazard notes exist to keep small. A
/// snapshot leaves every store byte-for-byte on the keys it has always used;
/// the whole feature is two file operations and a restart, and deleting it
/// would leave no trace in any store.
///
/// **The two built-in test users.** FRESH is not a slot: it is a virtual row
/// the LOAD list offers whose snapshot is empty — loading it is a fresh
/// install, every time, for walking the first-run experience. HORIZON is
/// slot 1, seeded on first launch of this build with no snapshot yet: it
/// starts fresh, and it keeps whatever is saved into it from then on.
///
/// **Store shape.** The index (names, dates) is a small JSON file beside the
/// snapshots in Application Support, deliberately *outside* `UserDefaults` —
/// if the index lived in the domain it snapshots, every profile would carry
/// a copy of the profile table and loading one would rewrite it. Filtering
/// still guards against strangers in the domain: iOS itself plants keys in
/// an app's defaults (`AppleLanguages`, `NS...`, WebKit's), and carrying
/// those between profiles would let a test profile flip system-level state.
///
/// `@MainActor @Observable` like every other store; Foundation-only, so the
/// slot logic and the key filter are testable on Linux. File IO goes through
/// an injected directory for the same reason.
@MainActor
@Observable
public final class UserProfileStore {
    public static let shared = UserProfileStore()

    /// The slot cap the item names. Slots are 1-based.
    public static let maxProfiles = 5

    /// The virtual fresh-install row's display name. Not a slot — see the
    /// type note — and therefore not a name a saved slot may take, or the
    /// LOAD list would show two rows that claim different things and read
    /// the same.
    public static let freshProfileName = "FRESH"

    /// One saved (or seeded) profile.
    public struct Profile: Identifiable, Codable, Sendable, Equatable {
        /// 1...maxProfiles.
        public let slot: Int
        public var name: String
        /// Nil until the first SAVE lands in this slot — a seeded profile
        /// (HORIZON) exists in the index before it has a snapshot, and
        /// loading it is a fresh start until it is saved into.
        public var savedAt: Date?

        public var id: Int { slot }

        public init(slot: Int, name: String, savedAt: Date? = nil) {
            self.slot = slot
            self.name = name
            self.savedAt = savedAt
        }
    }

    public private(set) var profiles: [Profile] = []

    private let directory: URL
    private let fm = FileManager.default

    /// The production store: `Application Support/UserProfiles/`.
    private convenience init() {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        self.init(directory: base.appendingPathComponent("UserProfiles", isDirectory: true))
    }

    /// Injectable for tests; everything below goes through `directory`.
    init(directory: URL) {
        self.directory = directory
        load()
        // `seedIfNeeded()` retired here (0.9.41): a fresh install starts
        // with five empty slots and no built-in rows — see the note on the
        // seeder below.
    }

    // MARK: The key filter

    /// Whether a defaults key is the app's own saved state.
    ///
    /// A prefix blacklist rather than a whitelist of known keys: the app's
    /// keys are declared across ~40 stores and grow every batch, and a
    /// whitelist here would be the classic second copy that rots. What the
    /// system plants is the stable side — Apple's own prefixes — so that is
    /// the side written down.
    public nonisolated static func isAppStateKey(_ key: String) -> Bool {
        let systemPrefixes = [
            "Apple", "NS", "PK", "AK", "CK", "INNext", "WebKit",
            "com.apple", "METAL_", "AddingEmojiKeybordHandled",
            "PreferredLanguages", "AutofillSettings",
        ]
        return !systemPrefixes.contains { key.hasPrefix($0) }
    }

    /// The snapshot of a domain: its app-state keys only.
    public nonisolated static func snapshot(of domain: [String: Any]) -> [String: Any] {
        domain.filter { isAppStateKey($0.key) }
    }

    // MARK: Slots

    /// The profile in a slot, if the index has one.
    public func profile(inSlot slot: Int) -> Profile? {
        profiles.first { $0.slot == slot }
    }

    /// Every slot number, occupied or not, for the SAVE list.
    public var allSlots: [Int] { Array(1...Self.maxProfiles) }

    /// Capture `domain` into a slot. `name` applies to a new slot (or a
    /// rename); an occupied slot keeps its name when nil is passed. Throws on
    /// an out-of-range slot or unwritable disk — both are programmer/IO
    /// errors the UI reports rather than swallows.
    public func save(_ domain: [String: Any], intoSlot slot: Int, name: String? = nil) throws {
        guard (1...Self.maxProfiles).contains(slot) else {
            throw ProfileError.badSlot(slot)
        }
        let cleaned = Self.snapshot(of: domain)
        try ensureDirectory()
        let data = try PropertyListSerialization.data(
            fromPropertyList: cleaned, format: .binary, options: 0
        )
        try data.write(to: snapshotURL(slot: slot), options: .atomic)

        let resolvedName = name ?? profile(inSlot: slot)?.name ?? "PROFILE \(slot)"
        var next = profiles.filter { $0.slot != slot }
        next.append(Profile(slot: slot, name: resolvedName, savedAt: Date()))
        profiles = next.sorted { $0.slot < $1.slot }
        persistIndex()
    }

    /// A slot's snapshot, or nil when it has never been saved into — the
    /// caller treats nil as "fresh install", which is exactly what a seeded
    /// but never-saved HORIZON should load as.
    public func snapshot(ofSlot slot: Int) -> [String: Any]? {
        guard profile(inSlot: slot) != nil,
              let data = try? Data(contentsOf: snapshotURL(slot: slot)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any] else { return nil }
        return dict
    }

    public enum ProfileError: Error, Equatable {
        case badSlot(Int)
    }

    // MARK: Files

    private var indexURL: URL { directory.appendingPathComponent("index.json") }

    private func snapshotURL(slot: Int) -> URL {
        directory.appendingPathComponent("slot-\(slot).plist")
    }

    private func ensureDirectory() throws {
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([Profile].self, from: data) else {
            return
        }
        // Out-of-range or duplicate slots cannot arise from this code, but the
        // index is a file on disk and files get edited; dropping strangers is
        // the same self-clean `BookmarkStore` applies to dead entry ids.
        var seen = Set<Int>()
        profiles = decoded
            .filter { (1...Self.maxProfiles).contains($0.slot) && seen.insert($0.slot).inserted }
            .sorted { $0.slot < $1.slot }
    }

    private func persistIndex() {
        guard (try? ensureDirectory()) != nil,
              let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    /// HORIZON seeding, retired (0.9.41; was 0.8.92, item 5).
    ///
    /// The built-in test users were development furniture: HORIZON held a
    /// long-lived tester's state and FRESH walked the first run. The first
    /// version build ships the feature blank — five empty slots, the user's
    /// own names — so nothing seeds. A device that already carries a HORIZON
    /// row keeps it: the index exists, and deleting a user's profiles on
    /// update is exactly the resurrection-in-reverse the old guard clause
    /// existed to prevent. The method stays for a dev build to call.
    private func seedIfNeeded() {
        guard !fm.fileExists(atPath: indexURL.path) else { return }
        profiles = [Profile(slot: 1, name: "HORIZON", savedAt: nil)]
        persistIndex()
    }
}
