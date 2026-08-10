import Foundation

/// A copy of everything this device holds, as one file the user owns.
///
/// **This is not a migration and must not be described as one.** AUDIT **M35**
/// asks for "a data-migration step" against a future bundle-ID change, and no
/// such step is writable: on iOS the bundle ID is the container identity, so a
/// new App ID gets a new `Library/Preferences/<bundleID>.plist` and a new
/// `Library/Application Support/`. The old container is not readable, not
/// enumerable, and goes away with the old install. Code claiming to migrate it
/// would be a lie.
///
/// What *is* possible is an archive written before the change and read after
/// it — which also happens to be a backup, and a way to move a shelf between
/// phones. The ordered preconditions for the ID change itself are in
/// KNOWN-ISSUES.md under "Changing the bundle ID is a one-way door"; this type
/// is the part of them that is code.
public struct SavedDataArchive: Codable, Sendable, Equatable {
    /// Bumped when a field's *meaning* changes, not when one is added — a
    /// reader that meets an unknown key ignores it, which is what makes adding
    /// one free.
    public static let currentFormat = 1

    /// Guards against importing some other app's JSON. Always `appTag`.
    public static let appTag = "vinodex-ios"

    public var format: Int
    public var app: String
    /// `AppVersion.fallback` at export time — informational, never enforced.
    /// An archive from a newer build is still readable.
    public var appVersion: String
    /// `DailyPick.dayIndex()` at export, so a restore can say how old it is.
    public var exportedDay: Int

    public var savedShelf: [String]
    public var wantToTryShelf: [String]
    public var triedShelf: [String]
    public var triedRatings: [String: TriedRating]
    public var recentlyViewed: [String]
    public var quizTierUnlocked: String?
    public var dailyStreak: Int
    public var dailyBestStreak: Int
    /// Optional on purpose: "never played" and "played on the epoch" must not
    /// collapse into 0. See `StreakStore.lastDay`.
    public var dailyLastDay: Int?
    public var revealCursor: Int
    /// Recorded so the archive is a complete statement of the device. **Not
    /// restored** — see `SavedDataArchiver.apply`.
    public var starterTierOnly: Bool
    public var grantedEntitlements: [String]
    public var displayName: String?
    public var textScale: String?
    public var uiScale: String?
    public var lcdMode: String?
    public var chassisSkin: String?
    public var hapticsEnabled: Bool?
    public var soundsEnabled: Bool?
    public var keepAwakeEnabled: Bool?
    /// The avatar, inline. A 512pt JPEG at q0.85 is tens of KB; base64 costs a
    /// third more and buys a single file the user cannot separate from its
    /// other half.
    public var avatarJPEG: Data?

    /// Why an archive was refused. The UI reports these rather than "import
    /// failed" — a user who picked the wrong file should be told so.
    public enum Refusal: Error, Equatable, Sendable {
        /// Not this app's archive. Almost always the wrong file picked.
        case notOurArchive(String)
        /// Written by a build whose fields mean something different. There is
        /// no downgrade path; the honest answer is to say so.
        case unreadableFormat(Int)
    }

    /// Checks the two header fields before any of the payload is trusted.
    public func validate() throws {
        guard app == Self.appTag else { throw Refusal.notOurArchive(app) }
        guard format <= Self.currentFormat else { throw Refusal.unreadableFormat(format) }
    }

    public static func decode(from data: Data) throws -> SavedDataArchive {
        let archive = try JSONDecoder().decode(SavedDataArchive.self, from: data)
        try archive.validate()
        return archive
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        // Sorted so two exports of the same state are the same bytes, and a
        // diff between two archives is readable.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// A stable, human-legible filename: the version and day are what a user
    /// scanning a Files folder actually needs.
    public var suggestedFilename: String {
        "vinodex-backup-\(appVersion)-\(exportedDay).json"
    }
}

/// Reads and writes `SavedDataArchive` against a `UserDefaults`.
///
/// Both bodies switch over `SavedDataKey.allCases` with **no `default:`**, so a
/// twenty-first key fails to compile here twice rather than being silently
/// dropped from every backup.
public enum SavedDataArchiver {
    public static func export(
        from defaults: UserDefaults = .standard,
        avatarJPEG: Data? = nil,
        day: Int = DailyPick.dayIndex()
    ) -> SavedDataArchive {
        var archive = SavedDataArchive(
            format: SavedDataArchive.currentFormat,
            app: SavedDataArchive.appTag,
            appVersion: AppVersion.fallback,
            exportedDay: day,
            savedShelf: [], wantToTryShelf: [], triedShelf: [], triedRatings: [:],
            recentlyViewed: [], quizTierUnlocked: nil,
            dailyStreak: 0, dailyBestStreak: 0, dailyLastDay: nil, revealCursor: 0,
            starterTierOnly: false, grantedEntitlements: [],
            displayName: nil, textScale: nil, uiScale: nil, lcdMode: nil,
            chassisSkin: nil, hapticsEnabled: nil, soundsEnabled: nil,
            keepAwakeEnabled: nil, avatarJPEG: avatarJPEG
        )

        for key in SavedDataKey.allCases {
            let name = key.rawValue
            switch key {
            case .savedShelf:          archive.savedShelf = defaults.stringArray(forKey: name) ?? []
            case .wantToTryShelf:      archive.wantToTryShelf = defaults.stringArray(forKey: name) ?? []
            case .triedShelf:          archive.triedShelf = defaults.stringArray(forKey: name) ?? []
            case .triedRatings:
                archive.triedRatings = defaults.data(forKey: name)
                    .flatMap { try? JSONDecoder().decode([String: TriedRating].self, from: $0) } ?? [:]
            case .recentlyViewed:      archive.recentlyViewed = defaults.stringArray(forKey: name) ?? []
            case .quizTierUnlocked:    archive.quizTierUnlocked = defaults.string(forKey: name)
            case .dailyStreak:         archive.dailyStreak = defaults.integer(forKey: name)
            case .dailyBestStreak:     archive.dailyBestStreak = defaults.integer(forKey: name)
            // `object(forKey:)`, not `integer(forKey:)` — see the field's note.
            case .dailyLastDay:        archive.dailyLastDay = defaults.object(forKey: name) as? Int
            case .revealCursor:        archive.revealCursor = defaults.integer(forKey: name)
            case .starterTierOnly:     archive.starterTierOnly = defaults.bool(forKey: name)
            case .grantedEntitlements: archive.grantedEntitlements = defaults.stringArray(forKey: name) ?? []
            case .displayName:         archive.displayName = defaults.string(forKey: name)
            case .textScale:           archive.textScale = defaults.string(forKey: name)
            case .uiScale:             archive.uiScale = defaults.string(forKey: name)
            case .lcdMode:             archive.lcdMode = defaults.string(forKey: name)
            case .chassisSkin:         archive.chassisSkin = defaults.string(forKey: name)
            // Absent is a real state for all three — `hapticsEnabled` and
            // `keepAwakeEnabled` default *on* when missing and `soundsEnabled`
            // defaults *off*, so `bool(forKey:)` would export "off, off, off"
            // for a device that has never opened settings.
            case .hapticsEnabled:      archive.hapticsEnabled = defaults.object(forKey: name) as? Bool
            case .soundsEnabled:       archive.soundsEnabled = defaults.object(forKey: name) as? Bool
            case .keepAwakeEnabled:    archive.keepAwakeEnabled = defaults.object(forKey: name) as? Bool
            }
        }
        return archive
    }

    /// Writes the archive back. Returns the keys actually written, so the
    /// caller can report "restored 14 of 20" rather than a silent success.
    ///
    /// A nil optional **removes** its key rather than writing a zero value.
    /// Restoring a device where sounds were never touched must leave the key
    /// absent, because absent is what means "off" for that one and "on" for
    /// the other two.
    @discardableResult
    public static func apply(
        _ archive: SavedDataArchive,
        to defaults: UserDefaults = .standard
    ) -> [SavedDataKey] {
        var written: [SavedDataKey] = []

        func put(_ key: SavedDataKey, _ value: Any?) {
            if let value {
                defaults.set(value, forKey: key.rawValue)
                written.append(key)
            } else {
                defaults.removeObject(forKey: key.rawValue)
            }
        }

        for key in SavedDataKey.allCases {
            switch key {
            case .savedShelf:          put(key, archive.savedShelf)
            case .wantToTryShelf:      put(key, archive.wantToTryShelf)
            case .triedShelf:          put(key, archive.triedShelf)
            case .triedRatings:        put(key, try? JSONEncoder().encode(archive.triedRatings))
            case .recentlyViewed:      put(key, archive.recentlyViewed)
            case .quizTierUnlocked:    put(key, archive.quizTierUnlocked)
            case .dailyStreak:         put(key, archive.dailyStreak)
            case .dailyBestStreak:     put(key, archive.dailyBestStreak)
            case .dailyLastDay:        put(key, archive.dailyLastDay)
            case .revealCursor:        put(key, archive.revealCursor)
            // The one deliberate asymmetry. Purchases come from a receipt,
            // never from a file the user can edit — the day there is a store,
            // an importable `grantedEntitlements` is a free unlock for anyone
            // with a text editor. `export` still records both, so the archive
            // is a complete statement of the device; `apply` refuses them, and
            // their absence from the returned list is what the UI reports.
            case .starterTierOnly, .grantedEntitlements:
                continue
            case .displayName:         put(key, archive.displayName)
            case .textScale:           put(key, archive.textScale)
            case .uiScale:             put(key, archive.uiScale)
            case .lcdMode:             put(key, archive.lcdMode)
            case .chassisSkin:         put(key, archive.chassisSkin)
            case .hapticsEnabled:      put(key, archive.hapticsEnabled)
            case .soundsEnabled:       put(key, archive.soundsEnabled)
            case .keepAwakeEnabled:    put(key, archive.keepAwakeEnabled)
            }
        }
        return written
    }
}
