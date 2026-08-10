#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import VinodexCore

// Wipe, back up and restore: the three things that act on the whole of
// what this device has stored. Split out of SettingsPanel.swift (AUDIT
// **M30**) so the panel file is the panels. They live in `VinodexUI`
// rather than Core because half of what they touch is UI-owned — see
// each type's own note. Nothing changed in the move itself; the extra stores
// and keys `wipeAll` has gained since came with the feature work after it.

/// CLEAR SAVED DATA. Lives in UI because half of what it clears (skin, LCD
/// mode, text scale, haptics, avatar, daily reminders) is UI-owned; the Core
/// stores expose their own resets and are called rather than reached into.
///
/// No relaunch needed, but that is now a property of the code rather than of
/// `@AppStorage`. Every setting used to be a KVO-backed `@AppStorage`
/// declaration, so removing a key snapped each view back to its declared
/// default on its own. Since arch **A17** the settings are one `@Observable`
/// model that reads defaults in `init`, which puts them in exactly the same
/// position as every store below: removing the keys alone would leave the
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
        // The Wine Exam's history and pass streak (0.7.5, D6). Its own store,
        // its own two keys — an un-reset history would leave a fresh start
        // claiming a hundred papers' worth of statistics.
        ExamRecordStore.shared.reset()
        // The back plate goes back to the scatter it ships with (0.6.7, C1).
        StampLayoutStore.shared.reset()
        // The stamp-unlock ledger and the pin bar (0.7.1, D2/B5). Both are
        // user state that survives a wipe otherwise: an un-reset ledger would
        // silently swallow the celebrations of a fresh start, which is the one
        // run where earning FIRST SIP again actually means something.
        PassportProgress.shared.reset()
        QuickPinStore.shared.reset()
        // The saved builds (0.7.3, B2). The *fitted* parts are cleared by the
        // key loop below — every `DeviceAxis` is in it — but the saved recipes
        // are their own store and would survive a wipe otherwise.
        CustomDeviceStore.shared.reset()
        // The tool cards (0.8.8, D1) — exactly the shape this function's other
        // entries warn about: a wipe that left the seen-ids set standing would
        // silently swallow all six introductions on the one run where meeting
        // the tools again is the whole point. WHAT'S THAT…?'s record stood
        // beside it until 0.8.93 (item 9) retired the tool, store and all.
        ToolIntroStore.shared.reset()
        // Professor Vino's ledger (0.8.9c, E1), for the reason the tool cards
        // above are here: a wipe that left the seen-ids set standing would open
        // a fresh start with him already silent, on the one run where meeting
        // him again is the whole point. `reset()` drops the seeded flag too, or
        // the wiped device would decline to re-seed and every later `seed` call
        // would be a no-op. The queue is cleared as well, so a bubble fired a
        // second before the wipe does not survive it.
        FirstTimeTriggerStore.shared.reset()
        // The onboarding walkthrough's three flags (0.8.9d, G2), for exactly the
        // reason above it: a wipe that left `hasBeenOffered` standing would open
        // a fresh start with the guided first find already spent, on the one run
        // where it is the whole point.
        CoachmarkEngine.shared.reset()
        VinoPresenter.shared.clear()
        // Clearing the preference is not the same as cancelling what it already
        // scheduled: a wiped device with a week of pending reminders would keep
        // firing them at somebody who just erased everything (0.7.8, D1). Placed
        // here with the other stores rather than after the key loop, because
        // `disable()` *writes* `dailyRemindersEnabled` as false — running it
        // first lets the loop below take the key away again, so the invariant
        // this function is built on (no key survives a wipe) still holds.
        NotificationScheduler.shared.disable()
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

        // The keys the feature work since **M35** added, which the registry
        // does not carry yet. They belong in `SavedDataKey` — that is the whole
        // point of the type — and until they are there the archive
        // `SavedDataArchiver` writes is a device without its exam history, its
        // stamp layout or its fitted parts. Folding them in is a Core change (a
        // case each, plus an arm each in `export` and `apply`, which switch
        // exhaustively on purpose), so it is left as a follow-up rather than
        // half-done here: of the two failures, a wipe that misses a key is much
        // the worse, and this list closes that one today.
        //
        // The ten `DeviceAxis` keys are mapped rather than listed, so an
        // eleventh part cannot be forgotten here the way the six added in
        // 0.7.3b would have been. Two of them — `chassisSkin` and `lcdMode` —
        // are `SavedDataKey` cases as well; removing a key twice costs nothing,
        // and neither list is allowed to shrink on the other's word.
        for key in DeviceAxis.allCases.map(\.storageKey) + [
            QuizProgress.completedKey,
            BookmarkStore.triedDaysKey,
            StampLayoutStore.storageKey,
            PassportProgress.storageKey,
            // The ladder's ledger (0.8.7, D1). Belt to `PassportProgress.reset()`'s
            // braces, exactly as the badge key above it is — the two `seeded`
            // flags stay internal to Core and are only reachable through
            // `reset()`, which this list is a second line of defence for.
            PassportProgress.tierStorageKey,
            QuickPinStore.storageKey,
            ExamRecordStore.storageKey,
            ExamRecordStore.bestStreakKey,
            CustomDeviceStore.storageKey,
            ToolIntroStore.storageKey,
            // Belt to `FirstTimeTriggerStore.reset()`'s braces, like the two
            // above it. The seeded flag is listed too because it is the half a
            // key-loop-only wipe would miss.
            FirstTimeTriggerStore.storageKey,
            FirstTimeTriggerStore.seededKey,
            // The silence preference and the walkthrough's three flags (0.8.9d),
            // belt to their own `reset()`s in the same manner.
            FirstTimeTriggerStore.silencedKey,
            CoachmarkEngine.reachedKey,
            CoachmarkEngine.offeredKey,
            CoachmarkEngine.completedKey,
            NotificationScheduler.enabledKey,
        ] {
            defaults.removeObject(forKey: key)
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

// MARK: - Switching profiles

/// The destructive half of user profiles (0.8.92, item 5): replace the app's
/// entire defaults domain and relaunch into it.
///
/// **Why a restart and not a live reload.** `SavedDataReset.wipeAll` can work
/// live because "everything to its default" is a state every store knows how
/// to reach — each exposes a `reset()`. "Everything to *these forty arbitrary
/// values*" is not: the stores read their keys once at init and cache, and no
/// reload API exists or should be grown across ~40 singletons for a test
/// harness. Writing the domain and exiting makes the next launch read the
/// snapshot exactly the way it reads any other cold start — which for the
/// FRESH profile is also precisely the point: the item asks for the *first
/// -run experience*, and that includes the boot, the intro and the
/// walkthrough offer, none of which replay without a launch.
///
/// `exit(0)` is against App Store guidelines and deliberately acceptable
/// here: this is a sideloaded, free-provisioned build and the feature is a
/// test harness. The alert the UI raises says the app will close, so the
/// close is a kept promise rather than a crash.
@MainActor
enum ProfileSwitcher {
    /// The app's defaults domain as it stands — the thing SAVE snapshots.
    static func currentDomain() -> [String: Any] {
        guard let bundleID = Bundle.main.bundleIdentifier else { return [:] }
        return UserDefaults.standard.persistentDomain(forName: bundleID) ?? [:]
    }

    /// Replace the domain with `snapshot` (nil = fresh install) and exit.
    static func apply(_ snapshot: [String: Any]?) {
        // The outgoing profile's pending reminders must not fire into the
        // incoming one — the same argument `wipeAll` makes, made before the
        // domain moves so the scheduler is still the outgoing user's.
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let defaults = UserDefaults.standard
        for key in currentDomain().keys where UserProfileStore.isAppStateKey(key) {
            defaults.removeObject(forKey: key)
        }
        if let snapshot {
            for (key, value) in UserProfileStore.snapshot(of: snapshot) {
                defaults.set(value, forKey: key)
            }
        }

        // A beat between the writes and the exit: the defaults are with
        // cfprefsd synchronously, but the notification-centre call above is
        // XPC and deserves the grace period. The UI is behind the DexAlert's
        // scrim for the whole of it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            exit(0)
        }
    }
}
#endif
