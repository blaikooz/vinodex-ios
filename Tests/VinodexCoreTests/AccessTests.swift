import Testing
import Foundation
@testable import VinodexCore

@MainActor
@Suite("Free tier access")
struct AccessTests {
    let db = WineDatabase.shared

    private func makeStore() -> AccessStore {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AccessStore(defaults: defaults)
    }

    /// The whole dataset must be visible on a fresh install.
    @Test("starter tier is off by default")
    func defaultsOff() {
        #expect(makeStore().starterOnly == false)
    }

    @Test("nothing is locked while starter tier is off")
    func nothingLockedByDefault() {
        let store = makeStore()
        for entry in db.entries {
            #expect(!store.isLocked(entry, in: db))
        }
    }

    @Test("starter tier locks some entries but not all")
    func locksSome() {
        let store = makeStore()
        store.starterOnly = true
        let locked = db.entries.filter { store.isLocked($0, in: db) }
        #expect(!locked.isEmpty, "starter tier locked nothing — tiers.json missing?")
        #expect(locked.count < db.entries.count, "starter tier locked everything")
    }

    /// The free tier has to be self-consistent: a browsable region whose key
    /// grape is locked would be a dead end.
    @Test("free regions and styles only reference free grapes")
    func freeTierIsClosed() {
        let store = makeStore()
        store.starterOnly = true

        let freeGrapeNames = Set(
            db.entries(in: .grapes).filter { db.isFree($0.id) }.map(\.name)
        )

        for entry in db.entries where db.isFree(entry.id) {
            guard entry.category == .regions || entry.category == .styles else { continue }
            let linked = entry.notableGrapes
            guard !linked.isEmpty else { continue }
            #expect(
                linked.contains(where: { freeGrapeNames.contains($0) }),
                "\(entry.name) is free but names no free grape"
            )
        }
    }

    /// Locking navigation would strand the user on the globe.
    @Test("continents are never locked")
    func continentsAlwaysFree() {
        let store = makeStore()
        store.starterOnly = true
        for entry in db.entries(in: .continents) {
            #expect(!store.isLocked(entry, in: db), "\(entry.name) is locked")
        }
    }

    @Test("the toggle persists")
    func persists() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        AccessStore(defaults: defaults).starterOnly = true
        #expect(AccessStore(defaults: defaults).starterOnly == true)
    }

    /// An id outside the manifest is locked — that is the paywall working.
    @Test("ids outside the manifest are not free")
    func unknownIsLocked() {
        #expect(!db.isFree("NOT_A_REAL_ID"))
    }

    /// The one safety valve: a build whose tiers manifest failed to load must
    /// unlock everything rather than lock the user out of the whole dataset.
    @Test("a database with no tier manifest is fully unlocked")
    func missingManifestUnlocks() {
        let open = WineDatabase(
            entries: db.entries,
            palette: db.palette,
            icons: db.icons,
            freeIDs: []
        )
        let store = makeStore()
        store.starterOnly = true
        for entry in open.entries {
            #expect(!store.isLocked(entry, in: open))
        }
    }
}

@Suite("Display hyphenation")
struct HyphenationTests {
    private let soft = EntryDisplay.softHyphen

    @Test("long words gain break opportunities")
    func longWord() {
        let out = EntryDisplay.hyphenated("MEDITERRANEAN")
        #expect(out.contains(soft))
        // The visible text must be unchanged once the soft hyphens are removed.
        #expect(out.replacingOccurrences(of: soft, with: "") == "MEDITERRANEAN")
    }

    @Test("short words are left alone")
    func shortWord() {
        for word in ["RED", "CHALK", "AOC", "SWEET"] {
            #expect(EntryDisplay.hyphenated(word) == word)
        }
    }

    @Test("no break lands within a chunk of either end")
    func noOrphans() {
        let out = EntryDisplay.hyphenated("MEDITERRANEAN", minWordLength: 10, chunk: 4)
        let pieces = out.components(separatedBy: soft)
        for piece in pieces {
            #expect(piece.count >= 4, "orphan fragment '\(piece)' in \(pieces)")
        }
    }

    @Test("each word in a phrase is handled independently")
    func phrase() {
        let out = EntryDisplay.hyphenated("OLD MEDITERRANEAN")
        let words = out.split(separator: " ")
        #expect(words.count == 2)
        #expect(!words[0].contains(soft), "short word gained a break")
        #expect(words[1].contains(soft))
    }
}
