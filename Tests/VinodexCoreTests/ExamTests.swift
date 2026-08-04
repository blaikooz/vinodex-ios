import Foundation
import Testing
@testable import VinodexCore

/// The Wine Exam's Core gates (0.7.5, D).
///
/// Everything the exam does that is not drawing lives in `VinodexCore` and is
/// therefore visible to the Linux CI — which is the whole reason D4's generation
/// and scoring were put there rather than in the screen. The one thing these
/// cannot see is the seven answering UIs; `ExamQuestionCard`'s switch over
/// `ExamQuestion.Payload` is exhaustive, so the *clean xtool build* is that
/// gate.
@Suite("Wine Exam")
struct ExamTests {
    private static let catalog = ExamCatalog.shared

    // MARK: - The bank

    @Test("the shipped bank decodes, whole")
    func examBankDecodes() {
        #expect(!Self.catalog.isEmpty, "exam.json did not load — see ExamCatalog.unavailable")
        // Element-wise decoding means a broken question costs one question and
        // says nothing. This is where it says something.
        #expect(
            Self.catalog.decodeErrors.isEmpty,
            "questions failed to decode: \(Self.catalog.decodeErrors.joined(separator: "; "))"
        )
    }

    /// The authored total, pinned. 407 at 0.7.5 (D) — sommbot's bank as landed.
    /// Moves only when the bank does, and deliberately, like every other count
    /// in `CoverageTests`.
    @Test("the bank holds the questions it was authored to")
    func bankSize() {
        #expect(Self.catalog.questions.count == 407, "the exam bank changed size")
        #expect(Self.catalog.count(tier: .beginner) == 137)
        #expect(Self.catalog.count(tier: .intermediate) == 147)
        #expect(Self.catalog.count(tier: .advanced) == 123)
    }

    @Test("every question id is unique")
    func idsAreUnique() {
        let ids = Self.catalog.questions.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    /// The bank ships `minCellCount` as its own claim about itself. This checks
    /// the claim against what actually decoded — the two can only disagree if a
    /// question was lost on the way in, which is exactly the failure worth
    /// catching.
    @Test("the shipped cell floor matches the live pools")
    func minCellCountMatchesTheBank() {
        #expect(Self.catalog.minCellCount == 6)
        for tier in ExamTier.allCases {
            #expect(
                Self.catalog.thinnestCell(tier: tier) >= Self.catalog.minCellCount,
                "\(tier) has a cell below the shipped floor"
            )
        }
    }

    @Test("every format is represented, so every answering UI is reachable")
    func allFormatsPresent() {
        let present = Set(Self.catalog.questions.map(\.format))
        for format in ExamFormat.allCases {
            #expect(present.contains(format), "no question uses \(format) — its UI is dead code")
        }
    }

    /// D5 asks for all seven formats *at every tier the user can sit*. Not
    /// asserted per tier — the bank does not promise that and forcing it would
    /// be a data demand dressed as a test — but the count is worth stating so a
    /// format quietly collapsing to one tier is visible.
    @Test("the format mix is what the bank was authored to")
    func formatMix() {
        var counts: [ExamFormat: Int] = [:]
        for q in Self.catalog.questions { counts[q.format, default: 0] += 1 }
        #expect(counts[.multipleChoice] == 234)
        #expect(counts[.trueFalse] == 63)
        #expect(counts[.selectAll] == 37)
        #expect(counts[.aromaIdentification] == 23)
        #expect(counts[.matching] == 21)
        #expect(counts[.ordering] == 18)
        #expect(counts[.imageIdentification] == 11)
    }

    /// The exam's authoring vocabulary and the device's ladder are one ladder
    /// (D1). If these ever disagree, a user's SOMMELIER unlock starts opening
    /// the wrong papers.
    @Test("exam tiers map onto the device's ladder in order")
    func examTierMatchesLadder() {
        for tier in ExamTier.allCases {
            #expect(tier.ladder.rank == tier.rank, "\(tier) is not the \(tier.rank)th rung")
            #expect(tier.ladder.examTier == tier, "the map is not a bijection at \(tier)")
        }
        for rung in QuizTier.allCases {
            #expect(rung.examTier.ladder == rung)
        }
    }

    // MARK: - D3, shuffling

    /// **The bug this whole layer exists to prevent.** Authored option order is
    /// answer order, so an engine that does not shuffle puts the right answer
    /// first on every single question — learnable in three questions and
    /// unnoticeable in any test that only checks grading.
    @Test("the correct option is not always first")
    func shufflingMovesTheAnswer() {
        let single = Self.catalog.questions.filter {
            switch $0.payload {
            case .multipleChoice, .aromaIdentification, .imageIdentification: true
            default: false
            }
        }
        #expect(single.count > 100, "not enough single-answer questions to measure")

        var atZero = 0
        var distribution: [Int: Int] = [:]
        for (i, question) in single.enumerated() {
            let prompt = ExamPrompt(question: question, seed: 1_000 &+ i &* 7919)
            guard let slot = prompt.correctChoice else {
                Issue.record("\(question.id) has no correct slot")
                continue
            }
            if slot == 0 { atZero += 1 }
            distribution[slot, default: 0] += 1
        }
        // Four-option questions dominate, so a fair shuffle lands the answer at
        // slot 0 about a quarter of the time. The band is wide because this is a
        // falsifier for "never shuffled" (100%) and for "always moved off zero"
        // (0%), not a chi-squared test.
        let share = Double(atZero) / Double(single.count)
        #expect(share > 0.10 && share < 0.45, "answer-at-slot-0 share is \(share) — the shuffle is not fair")
        #expect(distribution.keys.count >= 4, "the answer only ever lands in \(distribution.keys.count) slots")
    }

    @Test("an ordering question is never presented already solved")
    func orderingIsNeverPreSolved() {
        let ordering = Self.catalog.questions.filter { $0.format == .ordering }
        #expect(!ordering.isEmpty)
        // Every seed, not a sample: the identity permutation is exactly the case
        // a sampled test would miss, and a three-item ordering hits it one run
        // in six.
        for question in ordering {
            for seed in 0..<200 {
                let prompt = ExamPrompt(question: question, seed: seed)
                #expect(
                    prompt.order != Array(prompt.order.indices),
                    "\(question.id) presented in authored order at seed \(seed)"
                )
            }
        }
    }

    @Test("the shuffle is a permutation, never a loss")
    func shuffleKeepsEveryOption() {
        for question in Self.catalog.questions {
            let prompt = ExamPrompt(question: question, seed: 42)
            switch question.payload {
            case .trueFalse:
                #expect(prompt.order.isEmpty)
            case .matching(let pairs):
                #expect(Set(prompt.order) == Set(pairs.indices), "\(question.id)")
                #expect(prompt.matchingRight.count == pairs.count)
                #expect(Set(prompt.matchingRight) == Set(pairs.map(\.right)), "\(question.id)")
            case .multipleChoice(let options, _),
                 .selectAll(let options, _),
                 .aromaIdentification(_, let options, _),
                 .imageIdentification(_, let options, _):
                #expect(Set(prompt.order) == Set(options.indices), "\(question.id)")
                #expect(Set(prompt.presentedOptions) == Set(options), "\(question.id)")
            case .ordering(let items, _):
                #expect(Set(prompt.order) == Set(items.indices), "\(question.id)")
                #expect(Set(prompt.presentedOptions) == Set(items), "\(question.id)")
            }
        }
    }

    @Test("the same seed presents the same question the same way")
    func shuffleIsDeterministic() {
        for question in Self.catalog.questions.prefix(60) {
            #expect(
                ExamPrompt(question: question, seed: 7).order
                    == ExamPrompt(question: question, seed: 7).order
            )
        }
    }

    // MARK: - Grading

    /// Grading walks the shuffle in both directions, so it is checked against
    /// the *authored* truth rather than against itself: the right answer is
    /// recomputed from the payload and pushed back through `order`.
    @Test("the authored answer grades correct, on every question and format")
    func gradingAgreesWithTheBank() {
        for (i, question) in Self.catalog.questions.enumerated() {
            let prompt = ExamPrompt(question: question, seed: i &* 31 &+ 5)
            let right: ExamAnswer
            switch question.payload {
            case .trueFalse(let answer):
                right = .truth(answer)
            case .multipleChoice, .aromaIdentification, .imageIdentification:
                guard let slot = prompt.correctChoice else {
                    Issue.record("\(question.id) has no correct slot"); continue
                }
                right = .choice(slot)
            case .selectAll:
                right = .selection(prompt.correctSelection)
            case .matching:
                right = .pairing(prompt.correctPairing)
            case .ordering:
                right = .sequence(prompt.correctSequence)
            }
            #expect(prompt.isCorrect(right), "\(question.id) (\(question.format)) graded its own answer wrong")
        }
    }

    @Test("a wrong answer grades wrong, on every format")
    func wrongAnswersGradeWrong() {
        for (i, question) in Self.catalog.questions.enumerated() {
            let prompt = ExamPrompt(question: question, seed: i &* 17 &+ 3)
            let wrong: ExamAnswer
            switch question.payload {
            case .trueFalse(let answer):
                wrong = .truth(!answer)
            case .multipleChoice, .aromaIdentification, .imageIdentification:
                guard let slot = prompt.correctChoice else { continue }
                wrong = .choice((slot + 1) % max(prompt.order.count, 1))
            case .selectAll:
                // The complement is always wrong: `assertExam` forbids both an
                // empty answer set and one holding every option, so the
                // complement is neither the answer nor empty.
                wrong = .selection(Set(prompt.order.indices).subtracting(prompt.correctSelection))
            case .matching:
                var map = prompt.correctPairing
                let lefts = map.keys.sorted()
                if let a = lefts.first, let b = lefts.dropFirst().first {
                    let held = map[a]
                    map[a] = map[b]
                    map[b] = held
                }
                wrong = .pairing(map)
            case .ordering:
                wrong = .sequence(prompt.correctSequence.reversed())
            }
            #expect(!prompt.isCorrect(wrong), "\(question.id) (\(question.format)) accepted a wrong answer")
        }
    }

    /// An answer of the wrong shape is a programming error, not a wrong answer.
    /// It grades false — and is asserted so, because the alternative is a
    /// `default` arm that silently marks mismatches correct.
    @Test("an answer of the wrong shape never grades correct")
    func mismatchedAnswerShapesGradeFalse() {
        guard let mc = Self.catalog.questions.first(where: { $0.format == .multipleChoice }) else {
            Issue.record("no multipleChoice question"); return
        }
        let prompt = ExamPrompt(question: mc, seed: 11)
        #expect(!prompt.isCorrect(.truth(true)))
        #expect(!prompt.isCorrect(.sequence([0, 1])))
        #expect(!prompt.isCorrect(.pairing([0: 0])))
    }

    // MARK: - D4, assembly

    @Test("a paper is balanced, distinct, and the length it asked for")
    func papersAreBalancedAndDistinct() {
        for tier in ExamTier.allCases {
            for seed in 0..<40 {
                guard case .success(let paper) = ExamPaper.assemble(tier: tier, seed: seed, in: Self.catalog) else {
                    Issue.record("assembly failed at \(tier)/\(seed)"); continue
                }
                #expect(paper.count == ExamPaper.length)
                #expect(Set(paper.map(\.id)).count == paper.count, "a question repeats at \(tier)/\(seed)")
                #expect(paper.allSatisfy { $0.question.tier == tier }, "off-tier question at \(tier)/\(seed)")
                // Ten questions over sixteen categories: the round robin cannot
                // take two from one category before it has taken one from each.
                #expect(
                    Set(paper.map(\.question.category)).count == paper.count,
                    "a category repeats inside a ten-question paper at \(tier)/\(seed)"
                )
            }
        }
    }

    @Test("different seeds examine different ground")
    func seedsRotateTheSyllabus() {
        guard
            case .success(let a) = ExamPaper.assemble(tier: .intermediate, seed: 1, in: Self.catalog),
            case .success(let b) = ExamPaper.assemble(tier: .intermediate, seed: 2, in: Self.catalog)
        else { Issue.record("assembly failed"); return }
        #expect(a.map(\.id) != b.map(\.id))
        // The rotation is the point: two consecutive papers should not walk the
        // same ten categories with different questions.
        #expect(Set(a.map(\.question.category)) != Set(b.map(\.question.category)))
    }

    @Test("the same seed is the same paper")
    func assemblyIsDeterministic() {
        for tier in ExamTier.allCases {
            guard
                case .success(let a) = ExamPaper.assemble(tier: tier, seed: 99, in: Self.catalog),
                case .success(let b) = ExamPaper.assemble(tier: tier, seed: 99, in: Self.catalog)
            else { Issue.record("assembly failed"); return }
            #expect(a.map(\.id) == b.map(\.id))
            #expect(a.map(\.order) == b.map(\.order))
        }
    }

    /// **A paper that runs dry says so.** The alternative — quietly serving a
    /// question twice — is the failure this was written against, and it is
    /// invisible on any paper shorter than the pool.
    @Test("assembly refuses rather than repeating")
    func assemblyRefusesWhenTheBankIsShort() {
        let tiny = ExamCatalog(questions: Array(Self.catalog.questions.prefix(3)), minCellCount: 1)
        let tier = tiny.questions[0].tier
        let outcome = ExamPaper.assemble(tier: tier, length: 10, seed: 0, in: tiny)
        guard case .failure(let why) = outcome else {
            Issue.record("a 3-question bank produced a 10-question paper"); return
        }
        #expect(why == .tooShort(tier: tier, requested: 10, available: tiny.count(tier: tier)))
        #expect(!why.message.isEmpty)
    }

    @Test("an empty bank is refused, not presented")
    func emptyBankIsRefused() {
        let outcome = ExamPaper.assemble(tier: .beginner, seed: 0, in: .unavailable)
        #expect(outcome == .failure(.emptyBank(tier: .beginner)))
    }

    /// A paper drawn right up to the balanced ceiling still repeats nothing.
    /// This is where an off-by-one in the round robin would show, and a
    /// ten-question paper never would.
    @Test("a paper at the balanced ceiling is still distinct")
    func fullLengthPaperIsDistinct() {
        for tier in ExamTier.allCases {
            let ceiling = ExamPaper.balancedCapacity(tier: tier, in: Self.catalog)
            #expect(ceiling == Self.catalog.thinnestCell(tier: tier) * 16)
            guard case .success(let paper) = ExamPaper.assemble(
                tier: tier, length: ceiling, seed: 5, in: Self.catalog
            ) else { Issue.record("assembly failed at the ceiling for \(tier)"); continue }
            #expect(paper.count == ceiling)
            #expect(Set(paper.map(\.id)).count == ceiling, "a question repeats in a full-length \(tier) paper")
            var perCategory: [ExamCategory: Int] = [:]
            for prompt in paper { perCategory[prompt.question.category, default: 0] += 1 }
            #expect(
                Set(perCategory.values).count == 1,
                "the balanced ceiling was not evenly split: \(perCategory.values.sorted())"
            )
        }
    }

    /// Past the balanced ceiling the paper leans on the fat categories rather
    /// than failing — and still never repeats. The degradation is deliberate;
    /// this pins that it is the *stated* one.
    @Test("beyond the balanced ceiling a paper degrades rather than repeating")
    func beyondCeilingStillDistinct() {
        let tier = ExamTier.intermediate
        let ceiling = ExamPaper.balancedCapacity(tier: tier, in: Self.catalog)
        let total = ExamPaper.capacity(tier: tier, in: Self.catalog)
        #expect(total > ceiling)
        guard case .success(let paper) = ExamPaper.assemble(
            tier: tier, length: total, seed: 3, in: Self.catalog
        ) else { Issue.record("assembly failed at full capacity"); return }
        #expect(Set(paper.map(\.id)).count == total, "a question repeats when the whole tier is drawn")
    }

    // MARK: - The run

    @Test("a run grades, advances and completes exactly once per question")
    func runLifecycle() {
        guard case .success(let paper) = ExamPaper.assemble(tier: .beginner, seed: 12, in: Self.catalog) else {
            Issue.record("assembly failed"); return
        }
        var run = ExamRun(seed: 12, tier: .beginner)
        #expect(!run.isComplete)

        for prompt in paper {
            // Advancing before a submission is a no-op — the trap a screen with
            // an eager NEXT button falls into.
            let held = run.index
            run.advance()
            #expect(run.index == held)

            let right: ExamAnswer = switch prompt.question.payload {
            case .trueFalse(let a): .truth(a)
            case .multipleChoice, .aromaIdentification, .imageIdentification:
                .choice(prompt.correctChoice ?? 0)
            case .selectAll: .selection(prompt.correctSelection)
            case .matching: .pairing(prompt.correctPairing)
            case .ordering: .sequence(prompt.correctSequence)
            }
            run.draft(right)
            // Bound out of the `#expect` rather than called inside it: the macro
            // captures its expression in a closure, where `run` is immutable and
            // a `mutating` call will not compile.
            let graded = run.submit(prompt)
            #expect(graded)
            // A second submission is ignored: the first commit is the answer.
            let regraded = run.submit(prompt)
            #expect(!regraded)
            #expect(run.marks.count == held + 1)
            run.advance()
        }

        #expect(run.isComplete)
        #expect(run.correct == ExamPaper.length)
        #expect(run.passed)
        #expect(run.marks.count == ExamPaper.length)
        #expect(run.markedCategories.count == ExamPaper.length)
    }

    @Test("a failed paper is a failed paper")
    func failingRun() {
        guard case .success(let paper) = ExamPaper.assemble(tier: .advanced, seed: 8, in: Self.catalog) else {
            Issue.record("assembly failed"); return
        }
        var run = ExamRun(seed: 8, tier: .advanced)
        for prompt in paper {
            // A deliberately shapeless answer: never correct on any format.
            run.draft(.sequence([]))
            run.submit(prompt)
            run.advance()
        }
        #expect(run.correct == 0)
        #expect(!run.passed)
    }

    @Test("a run round-trips through the session store's encoding")
    func runIsCodable() throws {
        var run = ExamRun(seed: 5, tier: .intermediate)
        run.draft(.selection([0, 2]))
        let data = try JSONEncoder().encode(run)
        let back = try JSONDecoder().decode(ExamRun.self, from: data)
        #expect(back == run)
        // The seed is what re-derives the paper, so it is the one field whose
        // survival is load-bearing.
        #expect(back.seed == 5)
    }

    @Test("retry is a different paper at the same tier")
    func retryIsNotAReplay() {
        let first = ExamRun(seed: 100, tier: .beginner)
        let second = first.retry()
        #expect(second.tier == first.tier)
        #expect(second.length == first.length)
        #expect(second.seed != first.seed)
        guard
            case .success(let a) = ExamPaper.assemble(tier: .beginner, seed: first.seed, in: Self.catalog),
            case .success(let b) = ExamPaper.assemble(tier: .beginner, seed: second.seed, in: Self.catalog)
        else { Issue.record("assembly failed"); return }
        #expect(a.map(\.id) != b.map(\.id))
    }

    // MARK: - D6, tracking

    @MainActor
    @Test("the history derives the statistics rather than counting alongside them")
    func statsDeriveFromHistory() {
        let defaults = UserDefaults(suiteName: "exam.stats.\(UUID().uuidString)")!
        let store = ExamRecordStore(defaults: defaults)
        #expect(store.stats == .empty)

        for (correct, passed) in [(10, true), (9, true), (4, false), (8, true)] {
            var run = ExamRun(seed: correct, tier: .beginner)
            for i in 0..<ExamPaper.length {
                run.draft(.truth(i < correct))
                let prompt = ExamPrompt(
                    question: ExamQuestion(
                        id: "T\(i)", tier: .beginner, category: .grapes,
                        prompt: "p", explanation: "e", payload: .trueFalse(answer: true)
                    ),
                    seed: 0
                )
                run.submit(prompt)
                run.advance()
            }
            #expect(run.correct == correct)
            #expect(run.passed == passed)
            store.record(run, day: 100)
        }

        let stats = store.stats
        #expect(stats.papers == 4)
        #expect(stats.passes == 3)
        #expect(stats.perfectPapers == 1)
        #expect(stats.questionsAnswered == 40)
        #expect(stats.questionsRight == 31)
        // The tail is one pass, because the third paper failed.
        #expect(stats.passStreak == 1)
        #expect(stats.bestPassStreak == 2)
        #expect(stats.bestByTier[.beginner] == 1.0)
        #expect(stats.byCategory[.grapes]?.asked == 40)
    }

    @MainActor
    @Test("the history is bounded, oldest first")
    func historyIsBounded() {
        let defaults = UserDefaults(suiteName: "exam.bound.\(UUID().uuidString)")!
        let store = ExamRecordStore(defaults: defaults)
        for day in 0..<(ExamRecordStore.historyLimit + 20) {
            var run = ExamRun(seed: day, tier: .beginner)
            for _ in 0..<ExamPaper.length {
                run.draft(.truth(true))
                run.submit(ExamPrompt(
                    question: ExamQuestion(
                        id: "T", tier: .beginner, category: .grapes,
                        prompt: "p", explanation: "e", payload: .trueFalse(answer: true)
                    ),
                    seed: 0
                ))
                run.advance()
            }
            store.record(run, day: day)
        }
        #expect(store.history.count == ExamRecordStore.historyLimit)
        // Trimmed from the front, so the newest — which the streak reads — is
        // never the thing that got dropped.
        #expect(store.history.last?.day == ExamRecordStore.historyLimit + 19)
        // **The streak saturates at the history limit, and that is the design.**
        // 120 papers passed in a row, 100 still on file, so the derived streak
        // reads 100 rather than 120. The alternative is a stored counter beside
        // a stored list, which is the disagreement `ExamRecordStore` exists to
        // avoid — see the note on `passStreak`. Pinned so the saturation is a
        // decision rather than a surprise.
        #expect(store.passStreak == ExamRecordStore.historyLimit)
        #expect(store.bestPassStreak == ExamRecordStore.historyLimit)
    }

    @MainActor
    @Test("the weakest category ignores samples too small to mean anything")
    func weakestNeedsASample() {
        let stats = ExamStats(
            papers: 1, passes: 1, questionsAnswered: 10, questionsRight: 5,
            passStreak: 1, bestPassStreak: 1, perfectPapers: 0,
            bestByTier: [:],
            byCategory: [
                // 0% but a single question — noise, not a weakness.
                .fortified: ExamCategoryTally(right: 0, asked: 1),
                .faults: ExamCategoryTally(right: 2, asked: 8),
                .grapes: ExamCategoryTally(right: 7, asked: 8),
            ]
        )
        #expect(stats.weakest()?.category == .faults)
        #expect(stats.strongest()?.category == .grapes)
        // With no floor the one-question cell wins, which is the whole reason
        // the floor exists.
        #expect(stats.weakest(minimumAsked: 1)?.category == .fortified)
    }

    @MainActor
    @Test("passing a paper unlocks the next rung of the device's ladder")
    func passingUnlocksTheLadder() {
        let defaults = UserDefaults(suiteName: "exam.ladder.\(UUID().uuidString)")!
        let store = ExamRecordStore(defaults: defaults)
        QuizProgress.shared.reset()
        defer { QuizProgress.shared.reset() }

        var run = ExamRun(seed: 1, tier: .beginner)
        for _ in 0..<ExamPaper.length {
            run.draft(.truth(true))
            run.submit(ExamPrompt(
                question: ExamQuestion(
                    id: "T", tier: .beginner, category: .grapes,
                    prompt: "p", explanation: "e", payload: .trueFalse(answer: true)
                ),
                seed: 0
            ))
            run.advance()
        }
        #expect(store.record(run, day: 1) == .enthusiast)
        #expect(QuizProgress.shared.isCompleted(.novice))
    }

    // MARK: - D7

    @Test("every question carries a teachable explanation")
    func everyQuestionExplainsItself() {
        for question in Self.catalog.questions {
            #expect(!question.explanation.isEmpty, "\(question.id) has no explanation")
            // Not a length pin so much as a floor on effort: a one-word
            // "explanation" is the failure mode D7 exists to prevent, and the
            // shortest sommbot authored is comfortably over this.
            #expect(question.explanation.count > 40, "\(question.id)'s explanation is a stub")
        }
    }

    @Test("the category labels the screen shows come from the bank")
    func categoryLabelsResolve() {
        for category in ExamCategory.allCases {
            let label = Self.catalog.label(for: category)
            #expect(!label.isEmpty)
            // The raw value leaking through means the table did not ship — the
            // screen would print FLAVOR_PROFILES at somebody.
            #expect(label != category.rawValue || !category.rawValue.contains("_"))
        }
    }
}
