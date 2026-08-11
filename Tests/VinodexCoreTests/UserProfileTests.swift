import Foundation
import Testing
@testable import VinodexCore

/// User profiles (0.8.92, item 5): the slot logic, the key filter and the
/// seeding rule, exercised against a scratch directory. The destructive half
/// — replacing the live defaults domain and exiting — lives in `VinodexUI`'s
/// `ProfileSwitcher` and is verified by the clean build plus a hand test, the
/// same split every store/UI pair here makes.
@MainActor
struct UserProfileTests {
    private func scratchDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("UserProfileTests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("a fresh index seeds HORIZON, unsaved, in slot 1")
    func seedsHorizon() {
        let store = UserProfileStore(directory: scratchDirectory())
        #expect(store.profiles.count == 1)
        #expect(store.profiles.first?.name == "HORIZON")
        #expect(store.profiles.first?.slot == 1)
        #expect(store.profiles.first?.savedAt == nil)
        // Never saved into means no snapshot — loading it is a fresh start.
        #expect(store.snapshot(ofSlot: 1) == nil)
    }

    @Test("save and reload round-trips a snapshot")
    func saveRoundTrips() throws {
        let dir = scratchDirectory()
        let store = UserProfileStore(directory: dir)
        let domain: [String: Any] = [
            "bookmarkedEntryIDs": ["G001", "R002"],
            "dexTextScale": "LARGE",
            "someCount": 7,
            "someFlag": true,
            // A system key that must NOT survive into the snapshot.
            "AppleLanguages": ["en"],
        ]
        try store.save(domain, intoSlot: 2, name: "TESTER")

        #expect(store.profile(inSlot: 2)?.name == "TESTER")
        #expect(store.profile(inSlot: 2)?.savedAt != nil)

        // A second store over the same directory — the relaunch — sees the
        // same index and the same snapshot.
        let reloaded = UserProfileStore(directory: dir)
        #expect(reloaded.profile(inSlot: 2)?.name == "TESTER")
        let snapshot = try #require(reloaded.snapshot(ofSlot: 2))
        #expect(snapshot["dexTextScale"] as? String == "LARGE")
        #expect(snapshot["someCount"] as? Int == 7)
        #expect(snapshot["someFlag"] as? Bool == true)
        #expect(snapshot["bookmarkedEntryIDs"] as? [String] == ["G001", "R002"])
        #expect(snapshot["AppleLanguages"] == nil, "system keys must not travel between profiles")
    }

    @Test("saving into an occupied slot keeps its name unless renamed")
    func overwriteKeepsName() throws {
        let store = UserProfileStore(directory: scratchDirectory())
        try store.save(["a": 1], intoSlot: 3, name: "KEEP ME")
        try store.save(["a": 2], intoSlot: 3)
        #expect(store.profile(inSlot: 3)?.name == "KEEP ME")
        let snapshot = try #require(store.snapshot(ofSlot: 3))
        #expect(snapshot["a"] as? Int == 2, "the snapshot itself must be replaced")
    }

    @Test("slots outside 1...5 are refused")
    func slotCap() {
        let store = UserProfileStore(directory: scratchDirectory())
        #expect(throws: UserProfileStore.ProfileError.badSlot(0)) {
            try store.save([:], intoSlot: 0)
        }
        #expect(throws: UserProfileStore.ProfileError.badSlot(6)) {
            try store.save([:], intoSlot: UserProfileStore.maxProfiles + 1)
        }
        #expect(UserProfileStore.maxProfiles == 5, "the item names five; the UI blurb restates it")
    }

    @Test("an existing-but-empty index does not re-seed HORIZON")
    func deletedProfilesStayDeleted() throws {
        let dir = scratchDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: dir.appendingPathComponent("index.json"))
        let store = UserProfileStore(directory: dir)
        #expect(store.profiles.isEmpty, "re-seeding would resurrect deleted profiles")
    }

    @Test("the key filter keeps app keys and drops the system's")
    func keyFilter() {
        // The app's own keys, sampled across stores — all must pass.
        for key in [
            Shelf.saved.storageKey, Shelf.tried.storageKey,
            BookmarkStore.ratingsKey, QuickPinStore.storageKey,
            StreakStore.streakKey, TextScale.storageKey,
        ] {
            #expect(UserProfileStore.isAppStateKey(key), "\(key) is app state and must snapshot")
        }
        // What iOS plants — none may travel between profiles.
        for key in [
            "AppleLanguages", "AppleKeyboards", "NSLanguages",
            "PKKeychainVersionKey", "WebKitShowLinkPreviews",
            "com.apple.content-rating.AppRating", "INNextHearbeatDate",
        ] {
            #expect(!UserProfileStore.isAppStateKey(key), "\(key) is the system's, not the profile's")
        }
    }

    @Test("FRESH is a reserved name, not a slot")
    func freshIsVirtual() {
        let store = UserProfileStore(directory: scratchDirectory())
        // Nothing in the seeded index claims the name; the LOAD list's FRESH
        // row is synthesised by the UI and never persisted.
        #expect(store.profiles.allSatisfy { $0.name != UserProfileStore.freshProfileName })
    }
}
