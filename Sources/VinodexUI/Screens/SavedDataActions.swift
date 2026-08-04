#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import VinodexCore

// Wipe, back up and restore: the three things that act on the whole of
// what this device has stored. Split out of SettingsPanel.swift (AUDIT
// **M30**) so the panel file is the panels. They live in `VinodexUI`
// rather than Core because half of what they touch is UI-owned — see
// each type's own note. Nothing here changed in the move.

/// CLEAR SAVED DATA. Lives in UI because half of what it clears (skin, LCD
/// mode, text scale, haptics, avatar) is UI-owned; the Core stores expose
/// their own resets and are called rather than reached into.
///
/// No relaunch needed, but that is now a property of the code rather than of
/// `@AppStorage`. Every setting used to be a KVO-backed `@AppStorage`
/// declaration, so removing a key snapped each view back to its declared
/// default on its own. Since arch **A17** the settings are one `@Observable`
/// model that reads defaults in `init`, which puts them in exactly the same
/// position as the six stores below: removing the keys alone would leave the
/// old values cached until the next launch. `AppSettings.shared.reload()` is
/// what closes that, and it must stay the last write here — see the order
/// note at the call.
@MainActor
enum SavedDataReset {
    static func wipeAll() {
        BookmarkStore.shared.removeEverything()
        RecentlyViewedStore.shared.clear()
        RevealCursor.shared.reset()
        AccessStore.shared.clearAll()
        AvatarStore.shared.clear()
        QuizProgress.shared.reset()
        StreakStore.shared.reset()
        ScreenStateStore.shared.clear()
        SearchStateStore.shared.clear()

        // Belt and braces after each store's own reset. This was a hand-kept
        // literal array and had drifted: it omitted `recentlyViewedEntryIDs`,
        // `starterTierOnly` and `grantedEntitlements`, all three of which the
        // store calls above do clear — so no key survived a wipe, but the list
        // a reader would trust claimed a completeness it did not have (AUDIT
        // M35). `SavedDataKey.allCases` cannot drift: a new key is a new case.
        let defaults = UserDefaults.standard
        for key in SavedDataKey.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
        // *After* the loop, not before: `reload()` re-reads the keys, which is
        // only correct once they are gone. It does not write them back — see
        // `AppSettings.isAdopting`, which exists for this call. Without it a
        // wipe would re-create every key the user had moved off its default,
        // and `TextScale.seedIfUnset` would never fire again on this device.
        AppSettings.shared.reload()

        // The wipe restores the default (on), so the timer has to be re-applied
        // — the alternative is a phone that keeps itself awake until the next
        // launch because the setting that said so no longer exists.
        ScreenWake.settingChanged()
    }
}

// MARK: - Back up and restore

/// The import half of AUDIT **M35**. Export is a pure read and lives in Core
/// (`SavedDataArchiver.export`); import cannot, because writing the keys is
/// only half of it — **seven** `@Observable` stores read their defaults once in
/// `init` and hold them for the life of the process, and three of them live in
/// this module. `AppSettings` is the seventh, added by arch **A17**; before it
/// the settings were `@AppStorage` and needed no reload, which is exactly why
/// it is easy to forget.
///
/// Get this wrong and it looks like it worked: the file lands, the sheet says
/// success, nothing on screen changes, and the next bookmark tap writes the
/// stale in-memory shelf back over what was just imported. `SavedDataReset`
/// hits the same hazard from the other side and answers it the same way.
@MainActor
enum SavedDataRestore {
    /// Everything this device holds, ready to write out.
    static func archive() -> SavedDataArchive {
        SavedDataArchiver.export(avatarJPEG: AvatarStore.shared.storedJPEG)
    }

    /// Applies an archive and brings every store back in step with it.
    /// Returns the keys actually written — `starterTierOnly` and
    /// `grantedEntitlements` are deliberately not among them.
    @discardableResult
    static func apply(_ archive: SavedDataArchive) -> [SavedDataKey] {
        let written = SavedDataArchiver.apply(archive)

        if let jpeg = archive.avatarJPEG {
            AvatarStore.shared.restore(jpeg)
        } else {
            AvatarStore.shared.clear()
        }

        BookmarkStore.shared.reload()
        RecentlyViewedStore.shared.reload()
        QuizProgress.shared.reload()
        StreakStore.shared.reload()
        AccessStore.shared.reload()
        AvatarStore.shared.reload()
        AppSettings.shared.reload()
        // `RevealCursor` needs none — it reads defaults live rather than
        // caching in init.

        // Session state describes the *old* library: a restored shelf makes a
        // stored scroll anchor meaningless, and a stored query was typed
        // against a different list.
        ScreenStateStore.shared.clear()
        SearchStateStore.shared.clear()

        // Same reasoning as the wipe: the keep-awake timer has to be
        // re-applied, because the value that decides it just changed under it.
        ScreenWake.settingChanged()
        return written
    }

    /// Writes the archive to a temporary file and hands back its URL, for
    /// `ShareLink`. Temporary because the user's copy is whatever they save it
    /// as; keeping a second one in our own container would be a backup that
    /// dies with the container it was made to survive.
    static func writeTemporaryFile(_ archive: SavedDataArchive) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(archive.suggestedFilename)
        try archive.encoded().write(to: url, options: .atomic)
        return url
    }
}
#endif
