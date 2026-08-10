import Testing
import Foundation
@testable import VinodexCore

@Suite("Chip filter")
struct ChipFilterTests {
    private let db = WineDatabase.shared

    private func option(_ facet: ChipFacet, _ value: String) -> ChipOption {
        db.chipOptions(for: facet).first { $0.value == value }!
    }

    @Test("an empty filter excludes nothing")
    func emptyMatchesEverything() {
        let filter = ChipFilter()
        #expect(filter.isEmpty)
        #expect(db.entries(matching: filter).count == db.entries.count)
    }

    @Test("every facet offers at least two chips")
    func facetsArePopulated() {
        for facet in ChipFacet.allCases {
            let options = db.chipOptions(for: facet)
            #expect(options.count >= 2, "\(facet.rawValue) has \(options.count) options")
            #expect(!facet.title.isEmpty)
            #expect(!facet.note.isEmpty)
        }
    }

    @Test("chip ids are unique across every facet")
    func optionIDsAreUnique() {
        let all = db.allChipOptions
        #expect(Set(all.map(\.id)).count == all.count)
    }

    @Test("toggling a chip on and off returns to empty")
    func toggleRoundTrip() {
        var filter = ChipFilter()
        let red = option(.color, "red")

        filter.toggle(red)
        #expect(filter.isOn(red))
        #expect(filter.count == 1)

        filter.toggle(red)
        #expect(!filter.isOn(red))
        #expect(filter.isEmpty)
    }

    /// The core semantic. Two chips in one facet widen; two chips across facets
    /// narrow. Getting this backwards produces a filter that behaves the
    /// opposite way to every chip UI anyone has used.
    @Test("within a facet chips OR, across facets they AND")
    func orWithinAndAcross() {
        var reds = ChipFilter()
        reds.toggle(option(.color, "red"))
        var whites = ChipFilter()
        whites.toggle(option(.color, "white"))
        var both = ChipFilter()
        both.toggle(option(.color, "red"))
        both.toggle(option(.color, "white"))

        let redCount = db.entries(matching: reds).count
        let whiteCount = db.entries(matching: whites).count
        #expect(db.entries(matching: both).count == redCount + whiteCount)

        // Across facets: adding a rarity can only shrink the red set.
        var redNoble = reds
        redNoble.toggle(option(.rarity, "NOBLE"))
        #expect(db.entries(matching: redNoble).count <= redCount)
    }

    /// A grape-only facet has to exclude everything that cannot carry it, or
    /// "RED" would quietly return flavours too.
    @Test("a grape-only facet excludes other categories")
    func grapeOnlyFacetsExclude() {
        var filter = ChipFilter()
        filter.toggle(option(.color, "red"))
        #expect(db.entries(matching: filter).allSatisfy { $0.category == .grapes })

        var climate = ChipFilter()
        climate.toggle(option(.climate, "maritime"))
        #expect(db.entries(matching: climate).allSatisfy { $0.category == .regions })
    }

    @Test("a category chip returns only that category")
    func categoryChip() {
        var filter = ChipFilter()
        filter.toggle(option(.category, "GRAPES"))
        let results = db.entries(matching: filter)
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.category == .grapes })
    }

    /// Contradictory chips are allowed and simply return nothing — the screen
    /// says so rather than the model refusing the tap.
    @Test("incompatible facets yield nothing rather than throwing")
    func contradictionIsEmpty() {
        var filter = ChipFilter()
        filter.toggle(option(.category, "REGIONS"))
        filter.toggle(option(.color, "red"))
        #expect(db.entries(matching: filter).isEmpty)
    }

    /// The number printed on each chip has to be the number you get after
    /// tapping it, or the tool lies.
    @Test("the count shown on a chip is the count it produces")
    func chipCountsAreHonest() {
        var filter = ChipFilter()
        filter.toggle(option(.category, "GRAPES"))

        for facet in ChipFacet.allCases {
            for chip in db.chipOptions(for: facet) {
                let predicted = db.count(withChip: chip, added: filter)
                let actual = db.entries(matching: filter.toggling(chip)).count
                #expect(predicted == actual, "\(chip.id) predicted \(predicted), got \(actual)")
            }
        }
    }

    @Test("a filter round-trips through JSON for the screen state store")
    func codableRoundTrip() throws {
        var filter = ChipFilter()
        filter.toggle(option(.color, "white"))
        filter.toggle(option(.rarity, "NOBLE"))

        let data = try JSONEncoder().encode(filter)
        let back = try JSONDecoder().decode(ChipFilter.self, from: data)
        #expect(back == filter)
        #expect(back.count == 2)
    }
}

@Suite("Tasting quiz")
struct TastingQuizTests {
    private let db = WineDatabase.shared

    /// Every slot of every session across a spread of seeds, negatives
    /// included — a session that goes blank at question seven is a broken run,
    /// not a degraded one.
    @Test("every question of every session exists")
    func alwaysProducesAQuestion() {
        for sessionSeed in stride(from: -45, to: 255, by: 10) {
            for number in 0..<QuizSession.length {
                #expect(
                    TastingQuiz.question(number: number, sessionSeed: sessionSeed, in: db) != nil,
                    "seed \(sessionSeed) question \(number) produced nothing"
                )
            }
        }
    }

    /// The properties that make a multiple-choice question fair: four distinct
    /// candidates, the answer among them, and every candidate a real entry.
    @Test("every question is well formed")
    func questionsAreWellFormed() {
        for sessionSeed in stride(from: 0, to: 200, by: 10) {
            for number in 0..<QuizSession.length {
                guard let q = TastingQuiz.question(number: number, sessionSeed: sessionSeed, in: db) else { continue }
                let tag = "seed \(sessionSeed) q\(number)"
                #expect(q.optionIDs.count == TastingQuiz.optionCount, "\(tag)")
                #expect(Set(q.optionIDs).count == q.optionIDs.count, "\(tag) repeats an option")
                #expect(q.optionIDs.contains(q.answerID), "\(tag) omits its own answer")
                #expect(!q.prompt.isEmpty)
                for id in q.optionIDs {
                    #expect(db.entry(id: id) != nil, "\(tag) names a missing entry \(id)")
                }
            }
        }
    }

    /// A run is a syllabus, not a single-subject drill: the rotation must give
    /// every topic at least three of the ten questions.
    @Test("a session mixes all three kinds")
    func sessionsAreBalanced() {
        for sessionSeed in stride(from: -20, to: 120, by: 7) {
            var counts: [QuizQuestion.Kind: Int] = [:]
            for number in 0..<QuizSession.length {
                guard let q = TastingQuiz.question(number: number, sessionSeed: sessionSeed, in: db) else { continue }
                counts[q.kind, default: 0] += 1
            }
            for kind in QuizQuestion.Kind.allCases {
                #expect(counts[kind, default: 0] >= 3, "seed \(sessionSeed): \(kind.rawValue) appears \(counts[kind, default: 0]) times")
            }
        }
    }

    /// The failure that would make the quiz worthless: a distractor that is
    /// also a correct answer. Checked against the same fields the prompt was
    /// built from, per kind.
    @Test("no distractor is also a right answer")
    func distractorsAreWrong() {
        for sessionSeed in stride(from: 0, to: 200, by: 5) {
            for number in 0..<QuizSession.length {
                guard let q = TastingQuiz.question(number: number, sessionSeed: sessionSeed, in: db),
                      let answer = db.entry(id: q.answerID) else { continue }
                let tag = "seed \(sessionSeed) q\(number)"

                switch q.kind {
                case .grapes:
                    guard case .grape(let right) = answer else {
                        Issue.record("\(tag): grapes answer is not a grape")
                        continue
                    }
                    for id in q.optionIDs where id != q.answerID {
                        guard case .grape(let other)? = db.entry(id: id) else {
                            Issue.record("\(tag): grapes distractor \(id) is not a grape")
                            continue
                        }
                        let differs = other.grapeType != right.grapeType
                            || TextNormalize.label(other.grapeBodyClass) != TextNormalize.label(right.grapeBodyClass)
                            || TextNormalize.label(other.grapeCountryOfOrigin) != TextNormalize.label(right.grapeCountryOfOrigin)
                        #expect(differs, "\(tag): \(other.common.name) matches every fact of \(right.common.name)")
                    }
                case .region, .style:
                    // Recover the grape from the prompt's own wording; the
                    // origin fallback form is checked via `origin` instead.
                    if let grape = promptedGrape(in: q.prompt) {
                        let key = TextNormalize.label(grape)
                        for id in q.optionIDs where id != q.answerID {
                            guard let other = db.entry(id: id) else { continue }
                            let carries = other.notableGrapes.contains { TextNormalize.label($0) == key }
                            #expect(!carries, "\(tag): \(other.name) also names \(grape)")
                        }
                    } else if let country = promptedOrigin(in: q.prompt) {
                        let key = TextNormalize.label(country)
                        for id in q.optionIDs where id != q.answerID {
                            guard let other = db.entry(id: id) else { continue }
                            #expect(
                                TextNormalize.label(other.origin ?? "") != key,
                                "\(tag): \(other.name) also originates in \(country)"
                            )
                        }
                    } else {
                        Issue.record("\(tag): unrecognised prompt \(q.prompt)")
                    }
                }
            }
        }
    }

    private func promptedGrape(in prompt: String) -> String? {
        for prefix in ["Which of these regions is known for ", "Which of these styles features "] where prompt.hasPrefix(prefix) {
            return String(prompt.dropFirst(prefix.count).dropLast())
        }
        return nil
    }

    private func promptedOrigin(in prompt: String) -> String? {
        let prefix = "Which of these styles originates in "
        guard prompt.hasPrefix(prefix) else { return nil }
        return String(prompt.dropFirst(prefix.count).dropLast())
    }

    @Test("the same slot of the same session gives the same question")
    func deterministic() {
        for sessionSeed in stride(from: 0, to: 100, by: 7) {
            for number in 0..<QuizSession.length {
                #expect(
                    TastingQuiz.question(number: number, sessionSeed: sessionSeed, in: db)
                        == TastingQuiz.question(number: number, sessionSeed: sessionSeed, in: db)
                )
            }
        }
    }

    /// Consecutive questions must differ, or NEXT appears not to work.
    @Test("consecutive questions differ")
    func consecutiveQuestionsDiffer() {
        var repeats = 0
        for sessionSeed in stride(from: 0, to: 100, by: 11) {
            for number in 0..<(QuizSession.length - 1) {
                let a = TastingQuiz.question(number: number, sessionSeed: sessionSeed, in: db)
                let b = TastingQuiz.question(number: number + 1, sessionSeed: sessionSeed, in: db)
                if a == b { repeats += 1 }
            }
        }
        #expect(repeats == 0, "\(repeats) consecutive question pairs were identical")
    }

    // MARK: Tiers

    /// A filtered pool must degrade to the full one, never to a blank screen —
    /// every tier fills every slot.
    @Test("every tier fills every slot of every session")
    func tieredQuestionsAlwaysExist() {
        for tier in QuizTier.allCases {
            for sessionSeed in stride(from: -20, to: 160, by: 12) {
                for number in 0..<QuizSession.length {
                    #expect(
                        TastingQuiz.question(number: number, sessionSeed: sessionSeed, tier: tier, in: db) != nil,
                        "\(tier.rawValue) seed \(sessionSeed) q\(number) produced nothing"
                    )
                }
            }
        }
    }

    @Test("tiered questions are deterministic")
    func tieredQuestionsAreDeterministic() {
        for tier in QuizTier.allCases {
            for sessionSeed in stride(from: 0, to: 90, by: 13) {
                for number in 0..<QuizSession.length {
                    #expect(
                        TastingQuiz.question(number: number, sessionSeed: sessionSeed, tier: tier, in: db)
                            == TastingQuiz.question(number: number, sessionSeed: sessionSeed, tier: tier, in: db)
                    )
                }
            }
        }
    }

    /// The ladder's whole promise: novice grape answers are household names,
    /// sommelier grape answers are the cellar's back corner. The grape pool is
    /// large enough per rarity band that the tier filter must never need its
    /// full-pool fallback here.
    @Test("grape answers respect the tier's rarity band")
    func grapeAnswersRespectTier() {
        for sessionSeed in stride(from: 0, to: 200, by: 7) {
            for number in 0..<QuizSession.length {
                for (tier, allowed) in [
                    (QuizTier.novice, Set<RarityLabel>([.noble, .common])),
                    // GODFORSAKEN joined the sommelier band in 0.6.2 — the
                    // backest corner of the cellar there is.
                    (QuizTier.sommelier, Set<RarityLabel>([.uncommon, .rare, .godforsaken])),
                ] {
                    guard let q = TastingQuiz.question(number: number, sessionSeed: sessionSeed, tier: tier, in: db),
                          q.kind == .grapes,
                          case .grape(let answer)? = db.entry(id: q.answerID) else { continue }
                    #expect(
                        allowed.contains(answer.rarity),
                        "\(tier.rawValue): answer \(answer.common.name) is \(answer.rarity.rawValue)"
                    )
                }
            }
        }
    }

    /// Novice region answers are places famous for several grapes, not one.
    @Test("novice region answers name at least two resolvable grapes")
    func noviceRegionAnswersAreBroad() {
        let grapeKeys = Set(
            db.entries(in: .grapes).map { TextNormalize.label($0.name) }
        )
        for sessionSeed in stride(from: 0, to: 200, by: 7) {
            for number in 0..<QuizSession.length {
                guard let q = TastingQuiz.question(number: number, sessionSeed: sessionSeed, tier: .novice, in: db),
                      q.kind == .region,
                      let answer = db.entry(id: q.answerID) else { continue }
                let resolvable = answer.notableGrapes.filter { grapeKeys.contains(TextNormalize.label($0)) }
                #expect(resolvable.count >= 2, "novice region \(answer.name) names \(resolvable.count)")
            }
        }
    }
}

@Suite("Quiz session")
struct QuizSessionTests {
    private let db = WineDatabase.shared

    private func someQuestion(for session: QuizSession) -> QuizQuestion {
        TastingQuiz.question(number: session.index, sessionSeed: session.seed, in: db)!
    }

    @Test("a fresh session starts clean")
    func freshSession() {
        let session = QuizSession(seed: 3)
        #expect(session.index == 0)
        #expect(session.correct == 0)
        #expect(session.chosenID == nil)
        #expect(!session.answered)
        #expect(!session.isComplete)
        #expect(!session.passed)
    }

    @Test("choosing scores rights and not wrongs, and the first tap is final")
    func choosingScores() {
        var session = QuizSession(seed: 5)
        let q = someQuestion(for: session)

        let wrong = q.optionIDs.first { $0 != q.answerID }!
        session.choose(wrong, in: q)
        #expect(session.correct == 0)
        #expect(session.chosenID == wrong)

        // A second tap — even on the right answer — is ignored.
        session.choose(q.answerID, in: q)
        #expect(session.correct == 0)
        #expect(session.chosenID == wrong)

        session.advance()
        let q2 = someQuestion(for: session)
        session.choose(q2.answerID, in: q2)
        #expect(session.correct == 1)
    }

    @Test("advance requires an answer, clears it, and completes at ten")
    func advanceWalksTheRun() {
        var session = QuizSession(seed: 9)

        // Advancing an unanswered question is a no-op.
        session.advance()
        #expect(session.index == 0)

        for number in 0..<QuizSession.length {
            #expect(session.index == number)
            let q = someQuestion(for: session)
            session.choose(q.answerID, in: q)
            #expect(session.answered)
            session.advance()
            #expect(!session.answered)
        }
        #expect(session.isComplete)
        #expect(session.correct == QuizSession.length)
        #expect(session.passed)

        // A completed session is inert.
        let done = session
        session.advance()
        #expect(session == done)
    }

    /// The 80% boundary: eight right passes, seven fails.
    @Test("the pass mark sits at eight of ten")
    func passBoundary() {
        for target in [QuizSession.passMark - 1, QuizSession.passMark] {
            var session = QuizSession(seed: 12)
            for number in 0..<QuizSession.length {
                let q = someQuestion(for: session)
                let id = number < target ? q.answerID : q.optionIDs.first { $0 != q.answerID }!
                session.choose(id, in: q)
                session.advance()
            }
            #expect(session.correct == target)
            #expect(session.passed == (target == QuizSession.passMark), "\(target) right")
        }
    }

    @Test("retry starts a different paper from scratch")
    func retryIsFresh() {
        var session = QuizSession(seed: 21)
        let q = someQuestion(for: session)
        session.choose(q.answerID, in: q)
        session.advance()

        let next = session.retry()
        #expect(next.seed != session.seed)
        #expect(next.index == 0)
        #expect(next.correct == 0)
        #expect(next.chosenID == nil)
    }

    /// The screen persists the whole session as one JSON blob through
    /// `ScreenStateStore.encode`/`decoded`; this is the round trip it relies on.
    @Test("a session round-trips through JSON")
    func codableRoundTrip() throws {
        var session = QuizSession(seed: 33, tier: .sommelier)
        let q = someQuestion(for: session)
        session.choose(q.answerID, in: q)

        let data = try JSONEncoder().encode(session)
        let back = try JSONDecoder().decode(QuizSession.self, from: data)
        #expect(back == session)
        #expect(back.tier == .sommelier)
    }

    /// The daily challenge's paper: a shorter session with its own pass mark.
    @Test("a custom-length session completes and grades on its own shape")
    func customLengthSession() {
        for target in [3, 4] {
            var session = QuizSession(seed: 17, length: 5, passMark: 4)
            for number in 0..<5 {
                #expect(!session.isComplete, "complete early at q\(number)")
                let q = TastingQuiz.question(number: session.index, sessionSeed: session.seed, in: db)!
                let id = number < target ? q.answerID : q.optionIDs.first { $0 != q.answerID }!
                session.choose(id, in: q)
                session.advance()
            }
            #expect(session.isComplete)
            #expect(session.correct == target)
            #expect(session.passed == (target >= 4), "\(target) right on a 5/4 paper")
        }
    }

    @Test("retry preserves the paper's shape and tier")
    func retryKeepsShape() {
        let session = QuizSession(seed: 9, length: 5, passMark: 4, tier: .novice)
        let next = session.retry()
        #expect(next.seed != session.seed)
        #expect(next.length == 5)
        #expect(next.passMark == 4)
        #expect(next.tier == .novice)
    }
}

@Suite("Quiz progress")
struct QuizProgressTests {
    private func makeDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @MainActor
    @Test("a fresh ladder opens at novice only")
    func freshLadder() {
        let progress = QuizProgress(defaults: makeDefaults())
        #expect(progress.unlocked(.novice))
        #expect(!progress.unlocked(.enthusiast))
        #expect(!progress.unlocked(.sommelier))
    }

    @MainActor
    @Test("passes climb the ladder one rung at a time")
    func passesClimb() {
        let progress = QuizProgress(defaults: makeDefaults())
        #expect(progress.recordPass(tier: .novice) == .enthusiast)
        #expect(progress.unlocked(.enthusiast))
        #expect(!progress.unlocked(.sommelier))
        // A repeat pass opens nothing new.
        #expect(progress.recordPass(tier: .novice) == nil)
        #expect(progress.recordPass(tier: .enthusiast) == .sommelier)
        #expect(progress.unlocked(.sommelier))
        // The top of the ladder has nothing above it.
        #expect(progress.recordPass(tier: .sommelier) == nil)
    }

    @MainActor
    @Test("unlocks survive a reload and reset clears them")
    func persistsAndResets() {
        let defaults = makeDefaults()
        QuizProgress(defaults: defaults).recordPass(tier: .novice)

        let reloaded = QuizProgress(defaults: defaults)
        #expect(reloaded.unlocked(.enthusiast))

        reloaded.reset()
        #expect(!QuizProgress(defaults: defaults).unlocked(.enthusiast))
    }

    // MARK: Completion stars (0.6.7, A4)

    @MainActor
    @Test("nothing is starred on a fresh ladder")
    func noStarsFresh() {
        let progress = QuizProgress(defaults: makeDefaults())
        for tier in QuizTier.allCases {
            #expect(!progress.isCompleted(tier))
        }
    }

    @MainActor
    @Test("a pass stars its own exam, not the one it unlocks")
    func starsThePassedExam() {
        let progress = QuizProgress(defaults: makeDefaults())
        progress.recordPass(tier: .novice)
        #expect(progress.isCompleted(.novice))
        // ENTHUSIAST is open, but nobody has sat it.
        #expect(progress.unlocked(.enthusiast))
        #expect(!progress.isCompleted(.enthusiast))
    }

    @MainActor
    @Test("the top of the ladder still earns its star")
    func topOfLadderStars() {
        // The one case a star cannot be derived from `highestUnlocked`:
        // passing SOMMELIER unlocks nothing, so the ladder does not move.
        let progress = QuizProgress(defaults: makeDefaults())
        progress.recordPass(tier: .novice)
        progress.recordPass(tier: .enthusiast)
        #expect(progress.recordPass(tier: .sommelier) == nil)
        #expect(progress.isCompleted(.sommelier))
    }

    @MainActor
    @Test("stars survive a reload and reset clears them")
    func starsPersistAndReset() {
        let defaults = makeDefaults()
        QuizProgress(defaults: defaults).recordPass(tier: .novice)

        let reloaded = QuizProgress(defaults: defaults)
        #expect(reloaded.isCompleted(.novice))

        reloaded.reset()
        #expect(!QuizProgress(defaults: defaults).isCompleted(.novice))
    }
}

/// Where the back-plate stamps have been dragged to (0.6.7, C1).
@Suite("Stamp layout")
struct StampLayoutTests {
    private func makeDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @MainActor
    @Test("an untouched plate reports every stamp at its issued spot")
    func freshPlate() {
        let layout = StampLayoutStore(defaults: makeDefaults())
        #expect(layout.offsets.isEmpty)
        for stamp in StampCatalog.all {
            #expect(layout.offset(for: stamp.id) == .zero)
        }
    }

    @MainActor
    @Test("a move survives a relaunch")
    func movePersists() {
        let defaults = makeDefaults()
        StampLayoutStore(defaults: defaults).move("firstSip", to: StampOffset(dx: 40, dy: -18))

        let reloaded = StampLayoutStore(defaults: defaults)
        #expect(reloaded.offset(for: "firstSip") == StampOffset(dx: 40, dy: -18))
        // Moving one stamp does not move any other.
        #expect(reloaded.offset(for: "sommelier") == .zero)
    }

    @MainActor
    @Test("dragging a stamp back home leaves nothing stored")
    func homeClearsTheEntry() {
        let defaults = makeDefaults()
        let layout = StampLayoutStore(defaults: defaults)
        layout.move("allNoble", to: StampOffset(dx: 12, dy: 9))
        #expect(!layout.offsets.isEmpty)

        layout.move("allNoble", to: .zero)
        #expect(layout.offsets.isEmpty)
        #expect(StampLayoutStore(defaults: defaults).offsets.isEmpty)
    }

    @MainActor
    @Test("reset re-scatters the whole plate")
    func resetClears() {
        let defaults = makeDefaults()
        let layout = StampLayoutStore(defaults: defaults)
        layout.move("firstSip", to: StampOffset(dx: 5, dy: 5))
        layout.move("tenBottles", to: StampOffset(dx: -30, dy: 60))

        layout.reset()
        #expect(layout.offsets.isEmpty)
        #expect(StampLayoutStore(defaults: defaults).offsets.isEmpty)
    }
}

@Suite("Walkthrough")
struct WalkthroughTests {
    @Test("every step carries real copy")
    func stepsHaveCopy() {
        #expect(Walkthrough.steps.count >= 5)
        for step in Walkthrough.steps {
            #expect(!step.id.isEmpty)
            #expect(!step.title.isEmpty)
            // Long enough to be a sentence rather than a placeholder.
            #expect(step.body.count > 40, "\(step.id) body is \(step.body.count) chars")
        }
    }

    @Test("step ids are unique")
    func idsAreUnique() {
        let ids = Walkthrough.steps.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    /// v0.5.4's flow: the main screen first — the whole app is up there —
    /// and the tour closes on the whole device ("off you go"). The orb step
    /// is deliberately gone: an easter egg you are told about is not one.
    @Test("the tour opens on the screen and closes on the device")
    func bookends() {
        #expect(Walkthrough.steps.first?.highlight == .screen)
        #expect(Walkthrough.steps.last?.highlight == .device)
        #expect(!Walkthrough.steps.contains { $0.highlight == .orb })
    }

    /// Terse is the contract now (v0.5.4): a step that grows past a couple
    /// of sentences has stopped being a tour and started being a manual.
    @Test("step copy stays terse")
    func copyStaysTerse() {
        for step in Walkthrough.steps {
            #expect(step.body.count < 180, "\(step.id) body is \(step.body.count) chars")
        }
    }

    /// Every part the tour claims to explain must actually get a step, or the
    /// diagram has a highlight nothing ever triggers.
    @Test("the parts the diagram can light are all covered")
    func coversTheControls() {
        let used = Set(Walkthrough.steps.map(\.highlight))
        for required: WalkthroughStep.Highlight in [
            .screen, .search, .entry, .settings, .tools, .back, .home, .marquee, .collection,
        ] {
            #expect(used.contains(required), "no step highlights \(required.rawValue)")
        }
    }

    /// AUDIT **M48**: the diagram is the tour's whole instructional payload and
    /// it is conveyed by opacity alone. Every highlight it can draw needs a
    /// spoken equivalent, and no two may share one — a copy-pasted label is the
    /// failure mode that looks fixed from the outside.
    @Test("every highlight the diagram can draw has a distinct description")
    func diagramDescriptions() {
        let all = WalkthroughStep.Highlight.allCases
        for highlight in all {
            let described = highlight.diagramDescription(isolated: false)
            #expect(described.count > 40, "\(highlight.rawValue): \(described)")
            #expect(described.hasPrefix("Diagram of"), "\(highlight.rawValue) does not say it is describing a picture")
            #expect(highlight.diagramDescription(isolated: true).hasSuffix("Nothing else is drawn."))
        }
        let distinct = Set(all.map { $0.diagramDescription(isolated: false) })
        #expect(distinct.count == all.count, "two highlights share a description")
    }

    /// The description describes the *drawing*; the body is the prose beside it.
    /// If they were ever the same string the label would have stopped adding
    /// anything, which is the state M48 found the screen in.
    @Test("a step's diagram description is not its body")
    func descriptionIsNotBody() {
        for step in Walkthrough.steps {
            #expect(step.diagramDescription != step.body, "\(step.id)")
            #expect(!step.diagramDescription.isEmpty)
        }
    }
    /// **The tour names the tools the shelf actually holds** (0.8.8, D2).
    ///
    /// This is the assertion that would have caught the bug D2 found: the step
    /// listed six tools, one of which (master search) is not on that shelf and
    /// never has been, while WHAT'S THAT…? was absent. It had been wrong since
    /// 0.7.9, through a release that rewrote the very tool it omitted, because
    /// prose in one file and a grid of literals in another cannot be compared.
    /// The sentence is derived from `ToolRoster` now, so this test is really
    /// pinning that it *stays* derived.
    @Test("the tools step names the shelf")
    func toolsStepNamesTheShelf() throws {
        let step = try #require(Walkthrough.steps.first { $0.id == "tools" })
        let body = step.body.lowercased()
        for tool in ToolRoster.all {
            #expect(body.contains(tool.title.lowercased()), "the tour never mentions \(tool.title)")
        }
        // The one that is not a tool, and the reason this test exists.
        #expect(!body.contains("master search"))
    }
}

/// **The tool roster is the shelf, the tour and the cards** (0.8.8, D1/D2).
@Suite("Tool roster")
struct ToolRosterTests {
    @Test("every tool has a card worth reading")
    func introsAreWritten() {
        #expect(ToolRoster.all.count == 6)
        for intro in ToolRoster.all {
            #expect(!intro.id.isEmpty)
            #expect(!intro.title.isEmpty)
            #expect(!intro.art.isEmpty)
            #expect(!intro.symbol.isEmpty)
            #expect(intro.tagline.count > 20, "\(intro.id) tagline is a stub")
            // Long enough to say how the thing works, short enough to read
            // before you have started using it.
            #expect(intro.body.count > 100, "\(intro.id) body is \(intro.body.count) chars")
            #expect(intro.body.count < 400, "\(intro.id) body is \(intro.body.count) chars")
            #expect(intro.faceHex.hasPrefix("#") && intro.faceHex.count == 7)
        }
    }

    @Test("ids and faces are distinct")
    func rosterIsWellFormed() {
        let ids = ToolRoster.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        let stems = ToolRoster.all.map(\.art)
        #expect(Set(stems).count == stems.count)
        // Six tiles told apart at a glance is the shelf's own rule.
        let faces = ToolRoster.all.map(\.faceHex)
        #expect(Set(faces).count == faces.count)
    }

    /// **Every card is reachable, and only tools raise one.**
    ///
    /// The failure this catches is a card written, shipped and never shown —
    /// which is invisible on the device, because the symptom is nothing
    /// happening. Checked from both directions: each roster entry must be
    /// produced by some route, and no non-tool route may produce one.
    @Test("every tool card has a route that raises it")
    func everyToolIsReachable() {
        let toolRoutes: [DexRoute] = [
            .scanner, .labelReader, .wsetQuiz, .dailyChallenge, .dailyGrape, .moonDial,
        ]
        let reached = Set(toolRoutes.compactMap { ToolRoster.intro(for: $0)?.id })
        #expect(reached == Set(ToolRoster.all.map(\.id)))

        for route: DexRoute in [
            .globe, .passport, .chipFilter, .settings, .bookmarks,
            .walkthrough, .deviceWorkshop, .stampCollection,
            .list(category: .grapes, filter: nil), .detail(entryID: "G001"),
        ] {
            #expect(ToolRoster.intro(for: route) == nil, "\(route) raised a tool card")
        }
    }

    @Test("the sentence lists all six and reads as one")
    func sentenceIsComplete() {
        let sentence = ToolRoster.sentence
        for intro in ToolRoster.all {
            #expect(sentence.contains(intro.title.lowercased()))
        }
        #expect(sentence.contains(", and "))
    }

    /// The store's contract: additive, id-keyed, and unknown ids dropped so a
    /// tool removed later cannot hold a slot forever.
    @MainActor
    @Test("seen ids persist, widen and survive a stranger")
    func storeRoundTrips() {
        let defaults = UserDefaults(suiteName: "toolIntroTests-\(UUID().uuidString)")!
        let store = ToolIntroStore(defaults: defaults)
        #expect(store.seen.isEmpty)
        #expect(store.pending("whatsThat")?.id == "whatsThat")

        store.markSeen("whatsThat")
        #expect(store.hasSeen("whatsThat"))
        #expect(store.pending("whatsThat") == nil)
        // A tool with no roster entry cannot be marked seen.
        store.markSeen("nosuchtool")
        #expect(store.seen == ["whatsThat"])
        #expect(store.pending("nosuchtool") == nil)

        #expect(ToolIntroStore(defaults: defaults).seen == ["whatsThat"])

        // A stored id the roster no longer knows is dropped on read.
        defaults.set("whatsThat,retiredTool", forKey: ToolIntroStore.storageKey)
        #expect(ToolIntroStore(defaults: defaults).seen == ["whatsThat"])

        store.markAllSeen()
        #expect(store.seen == Set(ToolRoster.all.map(\.id)))
        for intro in ToolRoster.all {
            #expect(store.pending(intro.id) == nil)
        }

        store.reset()
        #expect(ToolIntroStore(defaults: defaults).seen.isEmpty)
    }
}
