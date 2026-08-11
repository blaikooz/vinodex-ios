import Foundation
import Observation

/// The declared default for every stored setting, in one place.
///
/// These used to be spelled at each reader: `?? .dark` in `LcdMode.current`,
/// `LcdMode.dark.rawValue` in thirty-five `@AppStorage` declarations, `?? true`
/// in `Haptics.enabled`, `= true` in the toggle that writes it. Same value,
/// four spellings, no way to change one of them and be sure the rest followed —
/// and a reader and a writer that disagree about a default produce a control
/// that shows OFF and behaves as ON until the first tap.
///
/// Nonisolated on purpose: `LcdMode.current` and friends are nonisolated
/// statics on the render path and must be able to read these without hopping.
public enum SettingsDefault {
    public static let textScale: TextScale = .small
    public static let uiScale: UIScale = .small
    public static let lcdMode: LcdMode = .dark
    public static let chassisSkin: ChassisSkin = .classic
    /// Missing key = on: haptics are part of the device's character, so only
    /// an explicit opt-out disables them.
    public static let hapticsEnabled = true
    /// Off since v0.5.1 — sounds are opt-in. See `Sounds`.
    public static let soundsEnabled = false
    /// On, preserving the behaviour this setting was carved out of (AUDIT
    /// **L40**). See `ScreenWake`.
    public static let keepAwakeEnabled = true
    /// Empty means "not set" — the profile header draws TASTER instead.
    public static let displayName = ""
}

/// Every setting the user can turn, as one observable model (arch **A17**).
///
/// **What this replaces.** There was no state architecture for settings —
/// there were four uncoordinated mechanisms, and the audit counted them:
/// fifty-seven `@AppStorage` declarations over eight keys, `lcdMode` alone
/// re-declared thirty-five times, each carrying its own literal default and its
/// own `LcdMode(rawValue:) ?? .dark` decode. Settings were *stored*, not
/// modelled. Nothing owned the set, so nothing could be handed a different one,
/// and adding a ninth setting meant finding every file that cared.
///
/// **Why a defaulted stored property rather than the environment.** The
/// obvious injection point is `.environment(settings)`, and it is the wrong one
/// here — this is the trap **M27** found the hard way. `ChipFilterScreen`,
/// `CountryScreen` and `RootView` read their dependencies in `init` *on
/// purpose* (moving that to `onAppear` reopens the first-frame "0 MATCHES"
/// flash **M5** closed), and `.id(…)`-keyed screens re-run `init` on every TEXT
/// SIZE change — exactly when an environment value is invisible. So this
/// follows the `db: WineDatabase = .shared` precedent instead: a stored
/// property with a default, readable in `init`, replaceable by a test.
///
/// **What still is not modelled, and why.** `DexFont.retro(_:)` and
/// `DexMetrics.footerControl` are statics reachable from 206 and 62 call sites
/// with no view in scope, and they read `TextScale.current` / `UIScale.current`
/// through `SettingsCache`. SwiftUI cannot observe a static, so the
/// `.id(scaleRaw + "|" + uiScaleRaw)` remount in `RootView` is still the
/// mechanism by which a text-size change takes effect (**H3**'s residual).
/// Retiring it means threading a settings instance through every font and
/// metric call site, which is a change of a different order and is deliberately
/// not taken here. What *has* changed is that the key it remounts on now comes
/// from this type rather than from a parallel `@AppStorage` declaration.
///
/// **`SettingsCache` is this type's storage layer, not a rival.** Writes here
/// go to `UserDefaults`, whose `didChangeNotification` fires synchronously on
/// the writing thread and drops the cache — so the nonisolated static readers
/// see the new value on the very next read, before SwiftUI re-renders. There is
/// one write path and one decode rule per key (`LcdMode.current(in:)` and its
/// siblings), which is the property that makes the two mechanisms agree.
///
/// **Adding a setting means adding a case to `SavedDataKey` first** — see the
/// note there. Then a property here, a default in `SettingsDefault`, and a
/// line in `reload()`.
@MainActor
@Observable
public final class AppSettings {
    /// The composition root's instance. Named in `RootView` and defaulted into
    /// every view that reads a setting, exactly as `WineDatabase.shared` is.
    public static let shared = AppSettings()

    private let defaults: UserDefaults

    /// True while this object is *adopting* what storage already says, rather
    /// than *deciding* it. Every `didSet` below checks it before writing.
    ///
    /// Without it, `reload()` writes all eight keys straight back — and that is
    /// not merely redundant. `SavedDataReset.wipeAll()` removes every key and
    /// then reloads, so a write-back re-creates each key the user had moved off
    /// its default, with the default in it. `TextScale.seedIfUnset` keys on the
    /// key being *absent*, so a wipe would permanently disable the first-launch
    /// accessibility seed for anyone who had ever changed their text size — and
    /// `displayName` would come back as a stored `""` rather than as nothing,
    /// which then rides into `SavedDataArchiver.export`.
    ///
    /// `@ObservationIgnored` because it is bookkeeping: observing it would
    /// invalidate every view twice per reload for no reason.
    @ObservationIgnored private var isAdopting = false

    // MARK: Appearance

    public var textScale: TextScale {
        didSet {
            guard !isAdopting, textScale != oldValue else { return }
            defaults.set(textScale.rawValue, forKey: TextScale.storageKey)
        }
    }

    public var uiScale: UIScale {
        didSet {
            guard !isAdopting, uiScale != oldValue else { return }
            defaults.set(uiScale.rawValue, forKey: UIScale.storageKey)
        }
    }

    public var lcdMode: LcdMode {
        didSet {
            guard !isAdopting, lcdMode != oldValue else { return }
            defaults.set(lcdMode.rawValue, forKey: LcdMode.storageKey)
        }
    }

    public var chassisSkin: ChassisSkin {
        didSet {
            guard !isAdopting, chassisSkin != oldValue else { return }
            defaults.set(chassisSkin.rawValue, forKey: ChassisSkin.storageKey)
        }
    }

    // MARK: Behaviour
    //
    // The three booleans keep their nonisolated readers — `Haptics.enabled`,
    // `Sounds.enabled`, `ScreenWake.enabled` — because those are consulted
    // from ~55 call sites that have no view and no settings instance. Both
    // sides take their default from `SettingsDefault`, so the reader and the
    // toggle cannot disagree about what an absent key means.

    public var hapticsEnabled: Bool {
        didSet {
            guard !isAdopting, hapticsEnabled != oldValue else { return }
            defaults.set(hapticsEnabled, forKey: SavedDataKey.hapticsEnabled.rawValue)
        }
    }

    public var soundsEnabled: Bool {
        didSet {
            guard !isAdopting, soundsEnabled != oldValue else { return }
            defaults.set(soundsEnabled, forKey: SavedDataKey.soundsEnabled.rawValue)
        }
    }

    public var keepAwakeEnabled: Bool {
        didSet {
            guard !isAdopting, keepAwakeEnabled != oldValue else { return }
            defaults.set(keepAwakeEnabled, forKey: SavedDataKey.keepAwakeEnabled.rawValue)
        }
    }

    // MARK: Profile

    /// The name on the passport and the bookmarks header. Stored here rather
    /// than as a file like the avatar is: a name is a few dozen bytes and
    /// belongs in the defaults database (see `AvatarStore`).
    public var displayName: String {
        didSet {
            guard !isAdopting, displayName != oldValue else { return }
            defaults.set(displayName, forKey: SavedDataKey.displayName.rawValue)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = Stored(reading: defaults)
        self.textScale = stored.textScale
        self.uiScale = stored.uiScale
        self.lcdMode = stored.lcdMode
        self.chassisSkin = stored.chassisSkin
        self.hapticsEnabled = stored.hapticsEnabled
        self.soundsEnabled = stored.soundsEnabled
        self.keepAwakeEnabled = stored.keepAwakeEnabled
        self.displayName = stored.displayName
    }

    /// Re-reads every key — the seventh instance of the trap **M35** recorded.
    ///
    /// Like the six `@Observable` stores before it, this one reads
    /// `UserDefaults` once in `init` and holds the values for the life of the
    /// process. A restore that writes the keys and stops has changed nothing on
    /// screen, and the next toggle writes the stale value back over the
    /// imported one. `SavedDataRestore.apply` and `SavedDataReset.wipeAll` both
    /// call this.
    ///
    /// Each assignment runs `didSet`, which is why every one of them guards on
    /// `oldValue`: without the guard a reload would write all eight keys
    /// straight back, and a *wipe* would immediately re-create the keys it had
    /// just removed.
    public func reload() {
        let stored = Stored(reading: defaults)
        adopt {
            textScale = stored.textScale
            uiScale = stored.uiScale
            lcdMode = stored.lcdMode
            chassisSkin = stored.chassisSkin
            hapticsEnabled = stored.hapticsEnabled
            soundsEnabled = stored.soundsEnabled
            keepAwakeEnabled = stored.keepAwakeEnabled
            displayName = stored.displayName
        }
    }

    /// The first-launch text-size seed, routed through this model.
    ///
    /// `TextScale.seedIfUnset` writes `UserDefaults` directly — it has to, since
    /// it runs before anything has been decided and its whole contract is "only
    /// if the key is absent". Calling it and stopping there was a real bug for
    /// exactly one launch: this object is built when `RootView` is constructed,
    /// which is *before* `onAppear`, so it had already snapshotted `.small` by
    /// the time the seed ran. The result was a model that disagreed with storage
    /// for the whole session — `DexFont` drew the seeded step (it reads
    /// `TextScale.current`), SETTINGS ▸ TEXT SIZE highlighted SMALL, and tapping
    /// SMALL did nothing at all because the `oldValue` guard saw no change.
    ///
    /// That is precisely the "the settings picker lies" failure
    /// `TextScale.seedIfUnset`'s own doc comment says the seeding design exists
    /// to avoid, so it belongs here rather than at the call site.
    ///
    /// - Returns: the step written, or `nil` if the user already has one.
    @discardableResult
    public func seedTextScaleIfUnset(systemOrdinal ordinal: Int) -> TextScale? {
        guard let seeded = TextScale.seedIfUnset(systemOrdinal: ordinal, in: defaults) else {
            return nil
        }
        // `adopt`, not a plain assignment: `seedIfUnset` has already written the
        // key, and re-writing it here would be a second `didChangeNotification`
        // for a value that has not moved.
        adopt { textScale = seeded }
        return seeded
    }

    /// Runs `body` with the write-back suppressed — see `isAdopting`.
    private func adopt(_ body: () -> Void) {
        isAdopting = true
        defer { isAdopting = false }
        body()
    }

    /// One read of all eight keys.
    ///
    /// A type rather than eight expressions repeated in `init` and `reload()`,
    /// because those two lists drifting apart is a *silent* bug with a very
    /// specific shape: the setting would be correct at launch and wrong after a
    /// restore, or the reverse. This is the same hazard `SavedDataKey` exists
    /// for one level up, answered the same way — write the list once.
    ///
    /// Each value goes through its own type's `current(in:)`, so the rule for
    /// turning stored bytes into a setting lives with the setting rather than
    /// here, and the `SettingsCache`-backed static that reads the same key on
    /// the render path cannot decode it differently.
    private struct Stored {
        let textScale: TextScale
        let uiScale: UIScale
        let lcdMode: LcdMode
        let chassisSkin: ChassisSkin
        let hapticsEnabled: Bool
        let soundsEnabled: Bool
        let keepAwakeEnabled: Bool
        let displayName: String

        init(reading defaults: UserDefaults) {
            textScale = TextScale.current(in: defaults)
            uiScale = UIScale.current(in: defaults)
            lcdMode = LcdMode.current(in: defaults)
            chassisSkin = ChassisSkin.current(in: defaults)
            hapticsEnabled = Self.flag(.hapticsEnabled, in: defaults,
                                       default: SettingsDefault.hapticsEnabled)
            soundsEnabled = Self.flag(.soundsEnabled, in: defaults,
                                      default: SettingsDefault.soundsEnabled)
            keepAwakeEnabled = Self.flag(.keepAwakeEnabled, in: defaults,
                                         default: SettingsDefault.keepAwakeEnabled)
            displayName = defaults.string(forKey: SavedDataKey.displayName.rawValue)
                ?? SettingsDefault.displayName
        }

        /// A stored flag, or `fallback` when the key has never been written.
        ///
        /// `bool(forKey:)` alone cannot express that third state — it returns
        /// `false` for an absent key, which would turn haptics' and keep-awake's
        /// opt-*out* into an opt-in on every fresh install. Mirrors
        /// `SettingsCache.bool(forKey:)`, which does the same thing for
        /// `.standard`.
        private static func flag(
            _ key: SavedDataKey,
            in defaults: UserDefaults,
            default fallback: Bool
        ) -> Bool {
            defaults.object(forKey: key.rawValue) == nil
                ? fallback
                : defaults.bool(forKey: key.rawValue)
        }
    }
}
