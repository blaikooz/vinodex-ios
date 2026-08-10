import Testing
import Foundation
@testable import VinodexCore

/// **The voice rules, as a build gate** (0.8.9c, D/E).
///
/// The point of tagging the copy — `gag`, the expression, the deferral reason —
/// is that the bible's rules stop being a matter of taste and start being a
/// thing that fails. `VinoDialogue.problems()` holds the rules; this runs it.
@Suite("Professor Vino dialogue")
struct VinoDialogueTests {
    @Test("the copy satisfies every voice rule")
    func copyIsClean() {
        let problems = VinoDialogue.problems()
        #expect(problems.isEmpty, "\n  \(problems.joined(separator: "\n  "))")
    }

    /// The gag budget, restated as a number rather than as a pass/fail, so a
    /// failure says how far over it went. Four of seventeen today: 4 x 4 = 16,
    /// which is <= 17 by one. Adding a fifth gag line requires adding four
    /// lines with it, which is the cap doing its job.
    @Test("the can't-drink gag stays inside one line in four")
    func gagBudget() {
        let gags = VinoDialogue.all.filter(\.gag).count
        let total = VinoDialogue.all.count
        #expect(
            gags * VinoDialogue.gagBudgetDivisor <= total,
            "\(gags) gag lines of \(total); \(total) lines allow \(total / VinoDialogue.gagBudgetDivisor)"
        )
        // A floor as well as a cap. The gag is the character premise, and a
        // well-meaning copy pass that removed all of it would pass a cap.
        #expect(gags >= 2, "the character has lost his one joke entirely")
    }

    /// The draft set used `{name}` in 4 of 16 bubbles against a bible whose
    /// Do-list opens with "address the user by name". The corrected set is 16
    /// of 17 — every line but the one that asks for the name.
    @Test("every line but the ask addresses the player by name")
    func namesThePlayer() {
        for line in VinoDialogue.all where line.trigger != .firstLaunch {
            #expect(line.usesName, "\(line.trigger.rawValue) never says the player's name")
        }
        #expect(VinoDialogue.line(for: .firstLaunch)?.usesName == false)
    }

    /// The constraint that keeps the lowercase fallback grammatical. See
    /// `VinoName`: if a line ever opened with the placeholder, `explorer` would
    /// need a capitalised variant and the substitution would stop being a single
    /// string. Covered inside `problems()` too; here explicitly, because this is
    /// the rule most likely to be broken by someone adding a line in good faith.
    @Test("no line puts the name first, so the lowercase fallback reads")
    func fallbackStaysGrammatical() {
        for line in VinoDialogue.all {
            #expect(
                !line.line.hasPrefix(VinoName.placeholder),
                "\(line.trigger.rawValue) opens with the name"
            )
            let rendered = line.rendered(name: nil)
            #expect(!rendered.contains(VinoName.placeholder), "\(line.trigger.rawValue) left a placeholder unsubstituted")
            if line.usesName {
                #expect(rendered.contains(VinoName.fallback))
            }
        }
    }

    @Test("a skipped, blank or oversized name all resolve sensibly")
    func nameResolution() throws {
        #expect(VinoName.resolved(nil) == VinoName.fallback)
        #expect(VinoName.resolved("") == VinoName.fallback)
        // Whitespace-only must land on the fallback rather than render
        // "Pleasure, .".
        #expect(VinoName.resolved("   \n ") == VinoName.fallback)
        #expect(VinoName.resolved("  Kim  ") == "Kim")
        // The 14-character marquee precedent: a 40-character name turns a
        // 20-word line into something else on a 320pt LCD.
        let long = String(repeating: "A", count: 40)
        #expect(VinoName.resolved(long).count == VinoName.maxLength)

        let line = try #require(VinoDialogue.line(for: .firstWineExam))
        #expect(line.rendered(name: "Kim") == "Exam time, Kim. I ask, you answer. Fair warning: I grade like a French appellation board.")
        #expect(line.rendered(name: nil).hasPrefix("Exam time, explorer."))
    }

    /// Printable ASCII on every shipped string, for the reason `assertFirmware`
    /// and `assertExam` assert it on theirs: the bubble draws in VT323 over
    /// Press Start 2P and renders anything else as a blank box, silently.
    ///
    /// `sommbot`'s reviewed set arrived with four em dashes and two chirps
    /// carrying a `U+25B9` arrow and another em dash. This is what caught them.
    @Test("every shipped string is printable ASCII")
    func asciiOnly() {
        func check(_ text: String, _ where_: String) {
            for scalar in text.unicodeScalars {
                #expect(
                    scalar.value >= 0x20 && scalar.value <= 0x7E,
                    "\(where_): U+\(String(format: "%04X", scalar.value)) in \"\(text)\""
                )
            }
        }
        for line in VinoDialogue.all {
            check(line.line, line.trigger.rawValue)
            if let chirp = line.chirp { check(chirp.text, line.trigger.rawValue + " chirp") }
        }
        for chirp in VinoChirp.allCases { check(chirp.text, "VinoChirp." + chirp.rawValue) }
    }

    @Test("no line is longer than the bubble")
    func wordCap() {
        for line in VinoDialogue.all {
            #expect(
                line.wordCount <= VinoDialogue.maxWords,
                "\(line.trigger.rawValue) is \(line.wordCount) words"
            )
        }
    }

    /// Six portraits were cut and wired in 0.8.9a on the promise that Phase 2
    /// would map triggers onto them. An expression nothing draws is a file in a
    /// folder, which is what `VinoArt` was created to stop being.
    @Test("all six portraits are used, and every line names one that exists")
    func expressionsAreCovered() {
        let used = Set(VinoDialogue.all.map(\.expression))
        #expect(used.count == VinoExpression.allCases.count, "unused: \(Set(VinoExpression.allCases).subtracting(used))")
        for expression in VinoExpression.allCases {
            #expect(expression.artStem == "vino-" + expression.rawValue)
        }
    }

    /// The denylist, over both authored copy sets in Core.
    ///
    /// **This is the gate that converts terminology drift from a review finding
    /// into a build failure.** It is worth its ten lines because the failure has
    /// already happened twice on this exact surface: "the written paper" survived
    /// 0.8.0's rename and sat on a shipping first-run card until a person read it
    /// against the spec in 0.8.9b.
    ///
    /// `ToolRoster` is included and `VinoDialogue` is not the only client on
    /// purpose — the next authored set is one `append` away from being covered.
    @Test("no shipped copy uses a retired label")
    func noRetiredTerms() {
        var problems: [String] = []
        for line in VinoDialogue.all {
            problems += RetiredTerms.problems(in: line.line, where: "vino." + line.trigger.rawValue)
        }
        for intro in ToolRoster.all {
            problems += RetiredTerms.problems(in: intro.title, where: "tool." + intro.id + ".title")
            problems += RetiredTerms.problems(in: intro.tagline, where: "tool." + intro.id + ".tagline")
            problems += RetiredTerms.problems(in: intro.body, where: "tool." + intro.id + ".body")
        }
        #expect(problems.isEmpty, "\n  \(problems.joined(separator: "\n  "))")
    }

    /// The matcher itself, because a denylist that over-matches gets deleted by
    /// the first person it inconveniences, and one that under-matches is
    /// decoration.
    @Test("retired terms match on word boundaries, not substrings")
    func denylistMatching() {
        #expect(RetiredTerms.contains("ACCESS", in: "open ACCESS now"))
        #expect(RetiredTerms.contains("ACCESS", in: "the access panel"))
        #expect(!RetiredTerms.contains("ACCESS", in: "fully accessible"))
        #expect(!RetiredTerms.contains("paper", in: "paperwork piles up"))
        #expect(RetiredTerms.contains("paper", in: "The written paper, in three tiers."))
        // Across the space, which is the case a naive word split would miss.
        #expect(RetiredTerms.contains("TASTING QUIZ", in: "open the tasting quiz"))
        #expect(!RetiredTerms.contains("TASTING QUIZ", in: "Blind Tasting, {name}: no label"))
        #expect(RetiredTerms.contains("cartridges", in: "cartridges of pure knowledge"))
    }
}

/// The trigger vocabulary, its persistence, and the queue that draws from it.
///
/// `@MainActor` because both stores are — they are `@Observable` state the views
/// read, the same isolation `ToolIntroStore` and `BookmarkStore` carry.
@MainActor
@Suite("First-time triggers")
struct FirstTimeTriggerTests {
    private let db = WineDatabase.shared

    private func store() -> FirstTimeTriggerStore {
        let defaults = UserDefaults(suiteName: "vino.triggers." + UUID().uuidString)!
        return FirstTimeTriggerStore(defaults: defaults)
    }

    @Test("every trigger has a line and every line has a trigger")
    func parity() {
        for trigger in FirstTimeTrigger.allCases {
            #expect(VinoDialogue.line(for: trigger) != nil, "\(trigger.rawValue) has no line")
        }
        #expect(Set(VinoDialogue.all.map(\.trigger)).count == FirstTimeTrigger.allCases.count)
    }

    /// The starter set from spec §E2 is fifteen. This is seventeen: "first app
    /// open" is two bubbles, and `firstFlavorViewed` was added because FLAVORS is
    /// a main-menu tile with 100+ entries and was the only one of the four
    /// categories with no line.
    @Test("the roster is the spec's fifteen, plus the launch split and FLAVORS")
    func rosterSize() {
        #expect(FirstTimeTrigger.allCases.count == 17)
        // **Down to one in 0.8.9d.** Both launch lines were deferred on "Phase 3
        // owns the capture field a question needs"; `VinoIntroCard` is that
        // field, so the gate comes off and sixteen of the seventeen are live.
        // `firstFlavorViewed` still waits on the flavour rework's Batch C, which
        // is a different batch's promise and not this one's to cash.
        let deferred = VinoDialogue.all.filter(\.isDeferred).map(\.trigger)
        #expect(Set(deferred) == [.firstFlavorViewed])
    }

    /// The reachability half Core can actually prove. Every trigger declaring
    /// itself route-driven must really be produced by `triggers(for:entry:)` —
    /// otherwise it is copy that is written, shipped, and never raised, which is
    /// the failure `ToolRoster.intro(for:)` moved into Core to prevent.
    @Test("every route-sourced trigger is reachable from some route")
    func routeTriggersAreReachable() {
        let godforsaken = db.entries.first { $0.rarity == .godforsaken }
        #expect(godforsaken != nil, "the catalog has no GODFORSAKEN entry to open")

        var produced: Set<FirstTimeTrigger> = []
        let routes: [(DexRoute, WineEntry?)] = [
            (.dailyChallenge, nil),
            (.wsetQuiz, nil),
            (.scanner, nil),
            (.passport, nil),
            (.settingsSection(.customization), nil),
            (.settingsSection(.access), nil),
            (.pack(id: "oldWorld"), nil),
        ] + EntryCategory.allCases.compactMap { category in
            db.entries.first { $0.category == category }.map { (DexRoute.detail(entryID: $0.id), $0) }
        } + [(DexRoute.detail(entryID: godforsaken?.id ?? ""), godforsaken)]

        for (route, entry) in routes {
            produced.formUnion(FirstTimeTrigger.triggers(for: route, entry: entry))
        }

        for trigger in FirstTimeTrigger.allCases where trigger.source == .route {
            #expect(produced.contains(trigger), "\(trigger.rawValue) claims .route but no route produces it")
        }
        // And the converse: nothing route-produced may claim to be an event.
        for trigger in produced {
            #expect(trigger.source == .route, "\(trigger.rawValue) is route-produced but declares \(trigger.source)")
        }
    }

    /// One arrival, two firsts. This is why `triggers(for:entry:)` returns a list
    /// and why the presenter has a queue at all.
    @Test("a Godforsaken grape opened first owes two lines, category first")
    func godforsakenGrapeOwesTwo() {
        guard let entry = db.entries.first(where: { $0.rarity == .godforsaken && $0.category == .grapes }) else {
            Issue.record("no GODFORSAKEN grape in the catalog")
            return
        }
        let triggers = FirstTimeTrigger.triggers(for: .detail(entryID: entry.id), entry: entry)
        #expect(triggers == [.firstGrapeViewed, .firstGodforsaken])
    }

    @Test("a route that names an entry produces nothing without one")
    func detailWithoutEntry() {
        #expect(FirstTimeTrigger.triggers(for: .detail(entryID: "GRAPE-1")).isEmpty)
        #expect(FirstTimeTrigger.triggers(for: .globe).isEmpty)
        #expect(FirstTimeTrigger.triggers(for: .settingsSection(.dev)).isEmpty)
    }

    @Test("fireOnce fires once")
    func fireOnceIsOnce() {
        let store = store()
        #expect(store.fireOnce(.firstPassport)?.trigger == .firstPassport)
        #expect(store.fireOnce(.firstPassport) == nil)
        #expect(store.hasFired(.firstPassport))
        #expect(!store.hasFired(.firstShop))
    }

    /// A deferred line must not fire **and must not be marked seen**, or
    /// switching it on later would silently show it to nobody.
    @Test("a deferred line neither fires nor burns its key")
    func deferredDoesNotBurn() {
        let store = store()
        #expect(store.fireOnce(.firstFlavorViewed) == nil)
        #expect(!store.hasFired(.firstFlavorViewed))
        // The launch pair moved to the live side in 0.8.9d — see `rosterSize`.
        // Kept here as the *contrast*, so this test still proves the rule rather
        // than just the one remaining instance of it: a live line burns, a
        // deferred one does not.
        #expect(store.fireOnce(.firstLaunch) != nil)
        #expect(store.hasFired(.firstLaunch))
    }

    @Test("the seen set survives a reload and drops unknown keys")
    func persistence() {
        let suite = "vino.triggers." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let first = FirstTimeTriggerStore(defaults: defaults)
        first.fireOnce(.firstShop)
        first.fireOnce(.firstPassport)

        defaults.set(
            (defaults.string(forKey: FirstTimeTriggerStore.storageKey) ?? "") + ",firstTeleporterUsed",
            forKey: FirstTimeTriggerStore.storageKey
        )

        let second = FirstTimeTriggerStore(defaults: defaults)
        #expect(second.hasFired(.firstShop))
        #expect(second.hasFired(.firstPassport))
        #expect(second.seen.count == 2, "an unknown key kept a slot: \(second.seen)")
    }

    // MARK: The first-run trap

    /// **The batch's most consequential decision, pinned.** An existing player
    /// with tastings on disk must not be handed `firstTried` and `firstInsight`
    /// for things they did weeks ago — that is `PassportProgress.seed`'s failure
    /// mode and it gets `PassportProgress`'s answer.
    @Test("an existing player's history is seeded, not replayed")
    func seedSuppressesHistoryDerivedLines() {
        let store = store()
        store.seed(triedCount: 12, hasAnnouncedStamps: true)
        #expect(store.hasFired(.firstTried))
        #expect(store.hasFired(.firstInsight))
        #expect(store.hasFired(.firstStamp))
    }

    /// **And the other half, which is the one worth guarding.** Seeding the whole
    /// set would silently rob every existing player of the entire character — the
    /// opposite failure, and a much quieter one. Only history-derived triggers
    /// are seeded; the fourteen that need the player to do something keep
    /// `ToolIntroStore`'s no-seed reasoning.
    @Test("seeding never suppresses a line the player has to earn")
    func seedLeavesNavigationTriggersAlone() {
        let store = store()
        store.seed(triedCount: 500, hasAnnouncedStamps: true)
        for trigger in FirstTimeTrigger.allCases where !trigger.isDerivedFromHistory {
            #expect(!store.hasFired(trigger), "\(trigger.rawValue) was seeded away")
        }
        #expect(store.fireOnce(.firstGrapeViewed) != nil)
        #expect(store.fireOnce(.firstShop) != nil)
    }

    /// A fresh install seeds to empty and is owed everything. The reason the
    /// seeded flag cannot be "is the set empty".
    @Test("a new install seeds to empty and keeps every line")
    func newInstallLosesNothing() {
        let store = store()
        store.seed(triedCount: 0, hasAnnouncedStamps: false)
        #expect(store.seen.isEmpty)
        #expect(store.fireOnce(.firstTried) != nil)
        #expect(store.fireOnce(.firstInsight) != nil)
        #expect(store.fireOnce(.firstStamp) != nil)
    }

    @Test("seeding runs once ever, even after the set is added to")
    func seedIsOnce() {
        let defaults = UserDefaults(suiteName: "vino.triggers." + UUID().uuidString)!
        let store = FirstTimeTriggerStore(defaults: defaults)
        store.seed(triedCount: 0, hasAnnouncedStamps: false)
        // The player then tries their first wine, the normal way.
        #expect(store.fireOnce(.firstTried) != nil)
        // A later launch must not re-seed and must not disturb anything.
        store.seed(triedCount: 40, hasAnnouncedStamps: true)
        #expect(!store.hasFired(.firstInsight), "a second seed suppressed a line the player had not earned")
    }

    /// The INSIGHT threshold is read through `InsightDepth` rather than
    /// hardcoded, so the ladder moving moves this with it.
    @Test("the insight seed follows the InsightDepth ladder")
    func insightSeedTracksTheLadder() {
        let store = store()
        store.seed(triedCount: InsightDepth.first.threshold, hasAnnouncedStamps: false)
        #expect(store.hasFired(.firstInsight))
        #expect(!store.hasFired(.firstStamp))
    }

    /// CLEAR SAVED DATA must take the ledger *and* the seeded flag with it.
    /// Leaving either standing would open a fresh start with Professor Vino
    /// already silent — the exact fault the wipe routine's own comments warn
    /// about for `PassportProgress` and `ToolIntroStore`.
    @Test("a data wipe gives the player every line back")
    func resetRestoresEverything() {
        let defaults = UserDefaults(suiteName: "vino.triggers." + UUID().uuidString)!
        let store = FirstTimeTriggerStore(defaults: defaults)
        store.seed(triedCount: 40, hasAnnouncedStamps: true)
        store.fireOnce(.firstShop)
        store.reset()

        #expect(store.seen.isEmpty)
        #expect(store.fireOnce(.firstShop) != nil)
        // The seeded flag too, or a wiped device would decline to re-seed and
        // the next `seed` call would be a silent no-op.
        #expect(!defaults.bool(forKey: FirstTimeTriggerStore.seededKey))
        #expect(store.fireOnce(.firstTried) != nil)
    }
}

/// The queue, and the sequencing rule that keeps two first-run interruptions off
/// one screen.
@MainActor
@Suite("Professor Vino presenter")
struct VinoPresenterTests {
    private func pair() -> (VinoPresenter, FirstTimeTriggerStore) {
        let defaults = UserDefaults(suiteName: "vino.presenter." + UUID().uuidString)!
        return (VinoPresenter(), FirstTimeTriggerStore(defaults: defaults))
    }

    @Test("lines queue in the order they fire and dismiss one at a time")
    func queueing() {
        let (vino, store) = pair()
        #expect(vino.current == nil)
        vino.fireOnce(.firstGrapeViewed, in: store)
        vino.fireOnce(.firstTried, in: store)
        #expect(vino.current?.trigger == .firstGrapeViewed)
        vino.dismiss()
        #expect(vino.current?.trigger == .firstTried)
        vino.dismiss()
        #expect(vino.current == nil)
        #expect(vino.isEmpty)
        // Dismissing an empty queue is a no-op, not a crash - the view's tap
        // target and the host's navigation can both call it.
        vino.dismiss()
    }

    @Test("a line never queues twice, even if a site double-fires")
    func dedupe() throws {
        let (vino, store) = pair()
        vino.fireOnce(.firstShop, in: store)
        vino.fireOnce(.firstShop, in: store)
        #expect(vino.queue.count == 1)
        // And directly, bypassing the store's own once-ness.
        let line = try #require(VinoDialogue.line(for: .firstShop))
        vino.present(line)
        #expect(vino.queue.count == 1)
    }

    /// **The ToolIntro collision.** Four triggers fire on screens that already
    /// raise an explainer card. Suspended, the line waits rather than stacking on
    /// top of the card — and it is not dropped, which is the half that would be
    /// easy to get wrong and impossible to notice.
    @Test("a suspended presenter holds its queue instead of dropping it")
    func suspension() {
        let (vino, store) = pair()
        vino.setSuspended(true, by: "toolIntro")
        vino.fireOnce(.firstDailyChallenge, in: store)
        #expect(vino.current == nil, "a bubble drew over the ToolIntro card")
        #expect(!vino.isEmpty, "the line was dropped rather than held")
        vino.setSuspended(false, by: "toolIntro")
        #expect(vino.current?.trigger == .firstDailyChallenge)
    }

    /// Two hosts, one queue. `RootView` owns the chrome overlays and
    /// `EntryDetailScreen` owns the stamp and rating prompts — and both are live
    /// on the screen where `firstTried` and `firstStamp` fire. One host resuming
    /// must not speak for the other.
    @Test("one host resuming does not release another host's hold")
    func suspensionIsPerHost() {
        let (vino, store) = pair()
        vino.setSuspended(true, by: "chrome")
        vino.setSuspended(true, by: "entryPrompt")
        vino.fireOnce(.firstStamp, in: store)

        vino.setSuspended(false, by: "chrome")
        #expect(vino.current == nil, "the entry prompt's hold was released by the chrome")

        vino.setSuspended(false, by: "entryPrompt")
        #expect(vino.current?.trigger == .firstStamp)
        // Idempotent, because these are called from render-adjacent modifiers.
        vino.setSuspended(false, by: "entryPrompt")
        #expect(vino.current?.trigger == .firstStamp)
    }

    @Test("a route arrival fires every line it owes")
    func routeArrival() {
        let (vino, store) = pair()
        let db = WineDatabase.shared
        guard let entry = db.entries.first(where: { $0.rarity == .godforsaken && $0.category == .grapes }) else {
            Issue.record("no GODFORSAKEN grape in the catalog")
            return
        }
        vino.fireOnce(for: .detail(entryID: entry.id), entry: entry, in: store)
        #expect(vino.queue.map(\.trigger) == [.firstGrapeViewed, .firstGodforsaken])
    }

    @Test("clear empties the queue without un-firing anything")
    func clearing() {
        let (vino, store) = pair()
        vino.fireOnce(.firstPassport, in: store)
        vino.clear()
        #expect(vino.isEmpty)
        // Once is once: navigating away does not earn the line back.
        vino.fireOnce(.firstPassport, in: store)
        #expect(vino.isEmpty)
    }
}
