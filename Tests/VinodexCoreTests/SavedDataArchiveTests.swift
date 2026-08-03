import Testing
import Foundation
@testable import VinodexCore

/// AUDIT **M35**. The bundle ID is the container identity on iOS, so a future
/// App ID change orphans every key below with no migration possible — an
/// export the user carries across is what exists instead. These tests pin the
/// registry that makes such an export enumerable, and the round trip that makes
/// it worth having.
@MainActor
@Suite("Saved data registry and archive")
struct SavedDataArchiveTests {
    /// Each test gets its own suite so they cannot see each other's keys,
    /// matching `BookmarkTests.makeStore`. `.standard` is never touched.
    private func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - The registry

    /// The test that fails when someone adds a key. That is the point of it:
    /// a twenty-first key has to be added to `SavedDataKey` to compile
    /// `export`/`apply` at all, and this makes the count a deliberate change
    /// rather than a silent one.
    @Test("the registry holds every key exactly once")
    func registryIsComplete() {
        #expect(SavedDataKey.allCases.count == 20)
        let raws = SavedDataKey.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count, "duplicate key string: \(raws)")
        #expect(raws.allSatisfy { !$0.isEmpty })
    }

    /// Every Core-side declaring constant must resolve to its registry case.
    /// Without this the registry is a *second* copy of the strings, which is
    /// worse than none.
    ///
    /// **The seven UI-side keys cannot be checked from here** — `uiScale`,
    /// `lcdMode`, `chassisSkin`, `hapticsEnabled`, `soundsEnabled`,
    /// `keepAwakeEnabled` and `userDisplayName` are declared in `VinodexUI`,
    /// which is invisible to Linux and to this target. They are derived from
    /// the same cases at their declaration sites, and
    /// `scripts/typecheck-ios-surface.sh` is the only local check that sees
    /// them. This is a stated gap, not a covered one.
    @Test("every Core storage constant derives from the registry")
    func coreConstantsMatchRegistry() {
        #expect(Shelf.saved.storageKey == SavedDataKey.savedShelf.rawValue)
        #expect(Shelf.wantToTry.storageKey == SavedDataKey.wantToTryShelf.rawValue)
        #expect(Shelf.tried.storageKey == SavedDataKey.triedShelf.rawValue)
        #expect(BookmarkStore.storageKey == SavedDataKey.savedShelf.rawValue)
        #expect(BookmarkStore.ratingsKey == SavedDataKey.triedRatings.rawValue)
        #expect(RecentlyViewedStore.storageKey == SavedDataKey.recentlyViewed.rawValue)
        #expect(QuizProgress.storageKey == SavedDataKey.quizTierUnlocked.rawValue)
        #expect(StreakStore.streakKey == SavedDataKey.dailyStreak.rawValue)
        #expect(StreakStore.lastDayKey == SavedDataKey.dailyLastDay.rawValue)
        #expect(StreakStore.bestKey == SavedDataKey.dailyBestStreak.rawValue)
        #expect(RevealCursor.storageKey == SavedDataKey.revealCursor.rawValue)
        #expect(AccessStore.storageKey == SavedDataKey.starterTierOnly.rawValue)
        #expect(AccessStore.entitlementsKey == SavedDataKey.grantedEntitlements.rawValue)
        #expect(TextScale.storageKey == SavedDataKey.textScale.rawValue)
    }

    /// The saved shelf keeps the key bookmarks were made under before shelves
    /// existed. Renaming it would strand every pre-shelf bookmark.
    @Test("the saved shelf keeps its pre-shelf key")
    func savedShelfKeyIsStable() {
        #expect(SavedDataKey.savedShelf.rawValue == "bookmarkedEntryIDs")
    }

    // MARK: - Round trip

    @Test("a populated device round-trips through the archive")
    func roundTrip() throws {
        let source = makeDefaults()
        let bookmarks = BookmarkStore(defaults: source)
        bookmarks.toggle("G001")
        bookmarks.toggle("R014", on: .wantToTry)
        bookmarks.toggle("S007", on: .tried)
        bookmarks.setRating(TriedRating(rating: 4, note: "smoke and plum", day: 20660), for: "S007")

        let recents = RecentlyViewedStore(defaults: source)
        recents.record("G001")
        recents.record("S007")

        let streaks = StreakStore(defaults: source)
        streaks.record(day: 20668, passed: true)

        let quiz = QuizProgress(defaults: source)
        quiz.recordPass(tier: .novice)

        source.set("E", forKey: SavedDataKey.displayName.rawValue)
        source.set("LARGE", forKey: SavedDataKey.textScale.rawValue)
        source.set(true, forKey: SavedDataKey.hapticsEnabled.rawValue)
        source.set(false, forKey: SavedDataKey.soundsEnabled.rawValue)
        source.set(31, forKey: SavedDataKey.revealCursor.rawValue)

        let archive = SavedDataArchiver.export(from: source, day: 20669)
        #expect(archive.format == SavedDataArchive.currentFormat)
        #expect(archive.app == SavedDataArchive.appTag)
        #expect(archive.exportedDay == 20669)

        // Through JSON, not just through memory — the file is the product.
        let restored = try SavedDataArchive.decode(from: archive.encoded())
        #expect(restored == archive)

        // Into a *second, empty* suite, then read back through fresh stores:
        // the only proof that matters is what the app would see next launch.
        let target = makeDefaults()
        let written = SavedDataArchiver.apply(restored, to: target)
        // 20 keys, less the two entitlement keys `apply` refuses, less the
        // four this device never set (uiScale, lcdMode, chassisSkin,
        // keepAwakeEnabled) — those are removed rather than written.
        #expect(written.count == 14, "got \(written.map(\.rawValue))")

        let restoredBookmarks = BookmarkStore(defaults: target)
        #expect(restoredBookmarks.contains("G001"))
        #expect(restoredBookmarks.contains("R014", on: .wantToTry))
        #expect(restoredBookmarks.contains("S007", on: .tried))
        #expect(restoredBookmarks.rating(for: "S007")?.note == "smoke and plum")
        #expect(restoredBookmarks.rating(for: "S007")?.rating == 4)

        #expect(RecentlyViewedStore(defaults: target).ids == recents.ids)

        let restoredStreaks = StreakStore(defaults: target)
        #expect(restoredStreaks.current == streaks.current)
        #expect(restoredStreaks.best == streaks.best)
        #expect(restoredStreaks.lastDay == 20668)

        #expect(QuizProgress(defaults: target).highestUnlocked == quiz.highestUnlocked)

        #expect(target.string(forKey: SavedDataKey.displayName.rawValue) == "E")
        #expect(target.string(forKey: SavedDataKey.textScale.rawValue) == "LARGE")
        #expect(target.integer(forKey: SavedDataKey.revealCursor.rawValue) == 31)
    }

    /// The distinction `StreakStore` goes out of its way to preserve: "never
    /// played" and "played on the epoch" are different states, and an archive
    /// that folds them writes a streak onto a device that has none.
    @Test("a nil last-day survives as nil, and day zero survives as zero")
    func lastDayOptionality() {
        let empty = makeDefaults()
        let archived = SavedDataArchiver.export(from: empty)
        #expect(archived.dailyLastDay == nil)

        let target = makeDefaults()
        target.set(99, forKey: SavedDataKey.dailyLastDay.rawValue)
        SavedDataArchiver.apply(archived, to: target)
        #expect(target.object(forKey: SavedDataKey.dailyLastDay.rawValue) == nil,
                "a nil field must remove the key, not write zero over it")
        #expect(StreakStore(defaults: target).lastDay == nil)

        var zeroed = archived
        zeroed.dailyLastDay = 0
        let zeroTarget = makeDefaults()
        SavedDataArchiver.apply(zeroed, to: zeroTarget)
        #expect(StreakStore(defaults: zeroTarget).lastDay == 0)
    }

    /// Absent is a *value* for these three: haptics and keep-awake default on
    /// when missing, sounds defaults off. Exporting them through
    /// `bool(forKey:)` would hand a fresh device's archive three explicit
    /// falses and silently switch two settings off on restore.
    @Test("untouched tri-state settings stay absent rather than becoming false")
    func absentSettingsStayAbsent() {
        let archived = SavedDataArchiver.export(from: makeDefaults())
        #expect(archived.hapticsEnabled == nil)
        #expect(archived.soundsEnabled == nil)
        #expect(archived.keepAwakeEnabled == nil)

        let target = makeDefaults()
        target.set(false, forKey: SavedDataKey.hapticsEnabled.rawValue)
        SavedDataArchiver.apply(archived, to: target)
        #expect(target.object(forKey: SavedDataKey.hapticsEnabled.rawValue) == nil)
    }

    /// The one deliberate asymmetry. An importable `grantedEntitlements` is a
    /// free unlock for anyone with a text editor, so `export` records the two
    /// entitlement keys and `apply` refuses them — and their absence from the
    /// returned list is what the UI reports.
    @Test("entitlements are exported but never imported")
    func entitlementsAreNotImportable() {
        let source = makeDefaults()
        let access = AccessStore(defaults: source)
        access.starterOnly = true
        access.grant(.skins)

        let archive = SavedDataArchiver.export(from: source)
        #expect(archive.starterTierOnly)
        #expect(archive.grantedEntitlements == [Entitlement.skins.id])

        let target = makeDefaults()
        let written = SavedDataArchiver.apply(archive, to: target)
        #expect(!written.contains(.starterTierOnly))
        #expect(!written.contains(.grantedEntitlements))
        #expect(target.object(forKey: SavedDataKey.starterTierOnly.rawValue) == nil)
        #expect(target.object(forKey: SavedDataKey.grantedEntitlements.rawValue) == nil)
        #expect(AccessStore(defaults: target).granted.isEmpty)

        // The refusal is targeted, not a bail-out: everything this sparse
        // archive actually held did land. Note `written` reports what was
        // *written*, and a nil optional removes its key rather than writing
        // one — so a device that never opened settings restores fewer keys
        // than the registry holds, and the count the UI reports is honest
        // rather than always twenty.
        #expect(written.count == 8, "got \(written.map(\.rawValue))")
    }

    // MARK: - What the reader refuses

    @Test("a foreign or future archive is refused by name")
    func refusals() throws {
        let archive = SavedDataArchiver.export(from: makeDefaults())

        var foreign = archive
        foreign.app = "some-other-app"
        #expect(throws: SavedDataArchive.Refusal.self) {
            try SavedDataArchive.decode(from: foreign.encoded())
        }

        var future = archive
        future.format = 99
        #expect(throws: SavedDataArchive.Refusal.self) {
            try SavedDataArchive.decode(from: future.encoded())
        }

        // Its own output is always readable.
        #expect(throws: Never.self) {
            try SavedDataArchive.decode(from: archive.encoded())
        }
    }

    /// Forward compatibility in the direction that actually happens: a newer
    /// build adds a field, an older one reads the file. An unknown key is
    /// ignored, and a *missing optional* is nil rather than a decode failure —
    /// so `format` only has to move when a field's meaning changes.
    @Test("an unknown field is ignored and a missing optional decodes")
    func forwardCompatibility() throws {
        let json = """
        {
          "format": 1, "app": "vinodex-ios", "appVersion": "9.9.9", "exportedDay": 20669,
          "savedShelf": ["G001"], "wantToTryShelf": [], "triedShelf": [], "triedRatings": {},
          "recentlyViewed": [], "dailyStreak": 0, "dailyBestStreak": 0, "revealCursor": 0,
          "starterTierOnly": false, "grantedEntitlements": [],
          "somethingFromTheFuture": {"nested": true}
        }
        """
        let archive = try SavedDataArchive.decode(from: Data(json.utf8))
        #expect(archive.savedShelf == ["G001"])
        #expect(archive.quizTierUnlocked == nil)
        #expect(archive.dailyLastDay == nil)
        #expect(archive.avatarJPEG == nil)
        #expect(archive.appVersion == "9.9.9")
    }

    @Test("the filename names the version and the day")
    func filename() {
        var archive = SavedDataArchiver.export(from: makeDefaults(), day: 20669)
        archive.appVersion = "0.6.5"
        #expect(archive.suggestedFilename == "vinodex-backup-0.6.5-20669.json")
    }

    // MARK: - reload()

    /// The trap this whole item turns on. `apply` writing to `UserDefaults` is
    /// not enough and looks like it worked: the six `@Observable` stores read
    /// their defaults once in `init` and hold them for the life of the
    /// process, so an import would display nothing and then overwrite the
    /// imported values with the stale in-memory ones on the next mutation.
    @Test("a live store picks up an import only after reload")
    func reloadPicksUpAnImport() {
        let defaults = makeDefaults()
        let live = BookmarkStore(defaults: defaults)
        #expect(live.isEmpty)

        var archive = SavedDataArchiver.export(from: makeDefaults())
        archive.savedShelf = ["G001", "R014"]
        SavedDataArchiver.apply(archive, to: defaults)

        // Still stale — this is the bug, demonstrated rather than described.
        #expect(live.isEmpty)
        live.reload()
        #expect(live.count == 2)
        #expect(live.contains("G001"))
    }

    @Test("reload is a no-op when nothing changed underneath")
    func reloadIsIdempotent() {
        let defaults = makeDefaults()
        let store = BookmarkStore(defaults: defaults)
        store.toggle("G001")
        store.reload()
        #expect(store.ids == ["G001"])

        let streaks = StreakStore(defaults: defaults)
        streaks.record(day: 20668, passed: true)
        let before = (streaks.current, streaks.best, streaks.lastDay)
        streaks.reload()
        #expect(streaks.current == before.0)
        #expect(streaks.best == before.1)
        #expect(streaks.lastDay == before.2)
    }
}
