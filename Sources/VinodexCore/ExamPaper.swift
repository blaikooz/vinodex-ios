import Foundation

/// A seeded generator, so a paper is reproducible.
///
/// Deterministic rather than random for the reason `TastingQuiz` and `DailyPick`
/// are: a given seed is a given paper, which is what makes any of this testable.
/// `SystemRandomNumberGenerator` would make the shuffle correct and the shuffle's
/// *tests* impossible — and "every answer is first" is precisely the bug that a
/// test has to be able to see.
///
/// SplitMix64. Twenty lines, no dependencies beyond Foundation, and it passes
/// the only bar that matters here: successive draws from the same stream are
/// uncorrelated, so option order and question order do not move together.
public struct ExamRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: Int) {
        // The golden-ratio odd constant, so a seed of 0 is not a degenerate
        // stream — papers are seeded off day indices and counters, and 0 is a
        // value both of those really take.
        state = UInt64(bitPattern: Int64(seed)) &+ 0x9E37_79B9_7F4A_7C15
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// What the candidate actually did.
///
/// Indices are **presented** indices throughout — the position on screen, not
/// the authored one. Nothing outside `ExamPrompt` ever sees an authored index,
/// which is the whole reason the shuffle cannot leak.
public enum ExamAnswer: Sendable, Codable, Equatable, Hashable {
    /// multipleChoice, aromaIdentification, imageIdentification.
    case choice(Int)
    case truth(Bool)
    /// selectAll. A set, so tapping an option twice is a toggle rather than a
    /// second vote.
    case selection(Set<Int>)
    /// matching: presented-left index → presented-right index. Partial while the
    /// candidate is still working.
    case pairing([Int: Int])
    /// ordering: presented indices in the order the candidate put them.
    case sequence([Int])
}

/// One question as a screen shows it: shuffled, with the answer expressed
/// against the shuffle.
///
/// ## Shuffling is the engine's job, and this is the engine
///
/// The bank authors the correct answer first, matching pairs correctly paired
/// and ordering items already in order — which is the only sane way to author
/// them and completely unusable as a presentation. Every `ExamPrompt` is built
/// through a seeded permutation, and the permutation is stored, so grading is a
/// lookup rather than a second guess at what the user saw.
///
/// `trueFalse` is the one format with nothing to shuffle. TRUE and FALSE are
/// fixed poles, not options — a paper that sometimes drew FALSE above TRUE would
/// be adding difficulty by making the candidate re-read the buttons.
public struct ExamPrompt: Sendable, Hashable, Identifiable {
    public let question: ExamQuestion
    /// Presentation order over the authored list: presented slot `i` holds
    /// authored index `order[i]`. Empty for `trueFalse`.
    ///
    /// For `matching` this permutes the **right** column only — the left column
    /// is the question and reordering it would change what is being asked.
    public let order: [Int]

    public var id: String { question.id }
    public var format: ExamFormat { question.format }

    /// The authored options/items, in presentation order. Empty for `trueFalse`
    /// and `matching`, which have their own accessors.
    public var presentedOptions: [String] {
        let authored: [String] = switch question.payload {
        case .multipleChoice(let options, _): options
        case .selectAll(let options, _): options
        case .aromaIdentification(_, let options, _): options
        case .imageIdentification(_, let options, _): options
        case .ordering(let items, _): items
        case .trueFalse, .matching: []
        }
        return order.compactMap { authored.indices.contains($0) ? authored[$0] : nil }
    }

    /// The left column, in authored order — the prompts of a matching question.
    public var matchingLeft: [String] {
        guard case .matching(let pairs) = question.payload else { return [] }
        return pairs.map(\.left)
    }

    /// The right column, shuffled — the answers to be dragged against the left.
    public var matchingRight: [String] {
        guard case .matching(let pairs) = question.payload else { return [] }
        return order.compactMap { pairs.indices.contains($0) ? pairs[$0].right : nil }
    }

    /// The presented slot holding the single correct option, where the format
    /// has one. `nil` for the formats that do not.
    public var correctChoice: Int? {
        let authored: Int
        switch question.payload {
        case .multipleChoice(_, let index),
             .aromaIdentification(_, _, let index),
             .imageIdentification(_, _, let index):
            authored = index
        case .trueFalse, .selectAll, .matching, .ordering:
            return nil
        }
        return order.firstIndex(of: authored)
    }

    /// Every presented slot holding a correct option, for `selectAll`.
    public var correctSelection: Set<Int> {
        guard case .selectAll(_, let indices) = question.payload else { return [] }
        return Set(indices.compactMap { order.firstIndex(of: $0) })
    }

    /// The correct presented sequence, for `ordering` — the presented slots in
    /// the authored order.
    public var correctSequence: [Int] {
        guard case .ordering(let items, _) = question.payload else { return [] }
        return items.indices.compactMap { order.firstIndex(of: $0) }
    }

    /// presented-left → presented-right, for `matching`. Left is unshuffled, so
    /// left slot `i` is authored pair `i`, whose right sits wherever the
    /// permutation put it.
    public var correctPairing: [Int: Int] {
        guard case .matching(let pairs) = question.payload else { return [:] }
        var map: [Int: Int] = [:]
        for i in pairs.indices {
            if let slot = order.firstIndex(of: i) { map[i] = slot }
        }
        return map
    }

    /// Whether a given presented slot is part of the correct answer — what the
    /// reveal paints green, independent of what was picked.
    public func isCorrectSlot(_ slot: Int) -> Bool {
        switch question.payload {
        case .multipleChoice, .aromaIdentification, .imageIdentification:
            correctChoice == slot
        case .selectAll:
            correctSelection.contains(slot)
        case .trueFalse, .matching, .ordering:
            false
        }
    }

    /// Grading. All-or-nothing on every format, including `selectAll`.
    ///
    /// Partial credit was considered and rejected: `correct` is an integer out
    /// of `length` on a results card and against a pass mark, and a paper where
    /// one question can be worth two thirds makes both of those numbers a lie.
    /// The *reveal* still shows which individual options were right, so nothing
    /// is hidden — the score just does not pretend to a precision it has no
    /// scale for.
    public func isCorrect(_ answer: ExamAnswer) -> Bool {
        switch (question.payload, answer) {
        case (.trueFalse(let expected), .truth(let given)):
            return expected == given
        case (.multipleChoice, .choice(let slot)),
             (.aromaIdentification, .choice(let slot)),
             (.imageIdentification, .choice(let slot)):
            return correctChoice == slot
        case (.selectAll, .selection(let slots)):
            return slots == correctSelection
        case (.matching, .pairing(let map)):
            return map == correctPairing
        case (.ordering, .sequence(let slots)):
            return slots == correctSequence
        // A mismatched pair is a programming error rather than a wrong answer,
        // and marking it wrong would hide it. There is no fifth arm that could
        // be right, so it grades false and the format switch above is what a
        // test asserts on.
        default:
            return false
        }
    }

    /// Builds the presentation. `seed` is per-question so two papers containing
    /// the same question do not present it identically.
    public init(question: ExamQuestion, seed: Int) {
        self.question = question
        var rng = ExamRandom(seed: seed)

        let count: Int = switch question.payload {
        case .multipleChoice(let options, _): options.count
        case .selectAll(let options, _): options.count
        case .aromaIdentification(_, let options, _): options.count
        case .imageIdentification(_, let options, _): options.count
        case .ordering(let items, _): items.count
        case .matching(let pairs): pairs.count
        case .trueFalse: 0
        }

        var permutation = Array(0..<count).shuffled(using: &rng)
        // **An ordering question presented in the authored order is presented
        // already solved.** One run in `n!` is the identity and for a
        // three-item ordering that is one in six, which is often enough to be
        // seen. Options are deliberately *not* corrected this way: forcing the
        // answer off slot 0 would make slot 0 never correct, which is a bigger
        // tell than the one it fixes.
        if case .ordering = question.payload,
           count > 1,
           permutation == Array(0..<count) {
            permutation.swapAt(0, 1)
        }
        order = permutation
    }
}

/// Why a paper could not be assembled.
public enum ExamAssemblyFailure: Error, Sendable, Equatable, Hashable {
    /// The bank did not load, or holds nothing at this tier.
    case emptyBank(tier: ExamTier)
    /// The tier holds fewer distinct questions than the paper asks for.
    /// **Assembly stops here rather than repeating one** — a paper that asks the
    /// same question twice is not a shorter paper, it is a broken one, and a
    /// candidate who spots the repeat has been told that the bank ran out.
    case tooShort(tier: ExamTier, requested: Int, available: Int)

    /// **What the player is shown, so it follows 0.8.0's F.** The type, the cases
    /// and every identifier in this file keep "paper"; these two strings reach a
    /// screen and say "exam" like the rest of the app now does.
    public var message: String {
        switch self {
        case .emptyBank(let tier):
            "NO QUESTIONS AT \(tier.ladder.displayName). THE EXAM BANK DID NOT LOAD."
        case .tooShort(let tier, let requested, let available):
            "\(tier.ladder.displayName) HOLDS \(available) QUESTIONS; THIS EXAM NEEDS \(requested)."
        }
    }
}

/// D4 — assembling a balanced paper from the bank.
public enum ExamPaper {
    /// The practice paper's shape, unchanged from the generated quiz it
    /// replaces: ten questions, eight to pass. Kept rather than re-picked
    /// because the number is on screen ("Ten questions, 8 to pass"), in the
    /// locked-tier alert, and in every user's head.
    public static let length = 10
    public static let passMark = 8

    /// How many questions a tier can furnish while every category still
    /// contributes equally — the thinnest cell times the sixteen categories.
    ///
    /// This, not the tier total, is the number that bounds a *balanced* paper:
    /// 147 intermediate questions do not make a 147-question balanced paper
    /// possible when one of its cells holds six. Beyond this point `assemble`
    /// still returns a full paper, but the tail of it leans on the fat
    /// categories — which is the honest degradation, and why the two numbers are
    /// reported separately.
    public static func balancedCapacity(tier: ExamTier, in catalog: ExamCatalog = .shared) -> Int {
        catalog.thinnestCell(tier: tier) * ExamCategory.allCases.count
    }

    /// Every distinct question at a tier.
    public static func capacity(tier: ExamTier, in catalog: ExamCatalog = .shared) -> Int {
        catalog.count(tier: tier)
    }

    /// A balanced paper, or the reason there isn't one.
    ///
    /// ## How the balance is struck
    ///
    /// Round-robin over the sixteen categories, **starting at a rotation derived
    /// from the seed**, taking one unused question from each in turn. That gives
    /// three properties worth naming:
    ///
    /// - A paper shorter than sixteen questions holds sixteen *different*
    ///   categories' worth of ground, never two from GRAPES and none from
    ///   FAULTS. The default ten-question paper covers ten of the sixteen.
    /// - *Which* ten rotates with the seed, so consecutive papers at the same
    ///   tier examine different parts of the syllabus rather than the same ten
    ///   with different questions.
    /// - An exhausted category is skipped, never re-drawn from. That is the
    ///   whole promise: **no question appears twice in a paper**, and if the
    ///   tier cannot furnish `length` distinct ones, the paper is refused.
    ///
    /// Within a category the pool is shuffled from the same seed, so the same
    /// seed always yields the same paper and two different seeds rarely share a
    /// question.
    public static func assemble(
        tier: ExamTier,
        length: Int = ExamPaper.length,
        seed: Int,
        in catalog: ExamCatalog = .shared
    ) -> Result<[ExamPrompt], ExamAssemblyFailure> {
        let available = capacity(tier: tier, in: catalog)
        guard available > 0 else { return .failure(.emptyBank(tier: tier)) }
        guard length > 0 else { return .success([]) }
        guard available >= length else {
            return .failure(.tooShort(tier: tier, requested: length, available: available))
        }

        let categories = ExamCategory.allCases
        var rng = ExamRandom(seed: seed)
        // One shuffled queue per category, drawn from the front.
        var queues: [[ExamQuestion]] = categories.map {
            catalog.questions(tier: tier, category: $0).shuffled(using: &rng)
        }
        var cursors = [Int](repeating: 0, count: categories.count)

        // The rotation. Non-negative modulo: `seed` is a running counter and
        // Swift's `%` keeps the sign of the dividend.
        let start = ((seed % categories.count) + categories.count) % categories.count

        var drawn: [ExamQuestion] = []
        var step = 0
        while drawn.count < length {
            var tookOne = false
            for offset in 0..<categories.count {
                guard drawn.count < length else { break }
                let index = (start + step + offset) % categories.count
                guard cursors[index] < queues[index].count else { continue }
                drawn.append(queues[index][cursors[index]])
                cursors[index] += 1
                tookOne = true
            }
            // Every category is exhausted and the paper is still short. Cannot
            // happen given the `available >= length` guard above — but a loop
            // whose termination depends on a guard three lines away is one
            // refactor from spinning forever.
            guard tookOne else {
                return .failure(.tooShort(tier: tier, requested: length, available: drawn.count))
            }
            step += 1
        }

        // Presented in draw order, which is round-robin order — so a paper walks
        // the syllabus rather than serving GRAPES, GRAPES, GRAPES. The per-
        // question seed is spread with a prime so adjacent questions' shuffles
        // are uncorrelated.
        return .success(drawn.enumerated().map { position, question in
            ExamPrompt(question: question, seed: seed &+ position &* 7919)
        })
    }
}

/// A sitting, in the shape that survives a trip into an entry and back.
///
/// A plain `Codable` value like `QuizSession`, and for the same reason: the run
/// round-trips through `ScreenStateStore` as one blob, so LEARN MORE does not
/// cost the paper you are halfway through.
///
/// **It stores the seed, not the questions.** Ten questions with their prompts,
/// options, explanations and shuffles would be a few kilobytes of session state
/// re-encoded on every tap; the seed is one integer and re-derives all of it
/// exactly, because `ExamPaper.assemble` is a pure function of (tier, length,
/// seed, bank).
public struct ExamRun: Sendable, Codable, Equatable {
    public let seed: Int
    public let tier: ExamTier
    public let length: Int
    public let passMark: Int
    /// Zero-based position of the current question.
    public private(set) var index: Int
    /// The answer to the current question; nil while unanswered. Held rather
    /// than discarded on advance so the reveal can show what was picked.
    public private(set) var answer: ExamAnswer?
    /// Whether the current question has been submitted. Separate from `answer`
    /// because the multi-touch formats build an answer up over several taps —
    /// a selectAll is a legitimate work-in-progress, and committing on the first
    /// tap would make it a one-option question.
    public private(set) var submitted: Bool
    /// One flag per graded question, oldest first. The score *and* the
    /// per-question record the results card and the stats store both read.
    public private(set) var marks: [Bool]
    /// Category of each graded question, parallel to `marks` — what makes
    /// "you are weakest on FAULTS" possible without keeping the paper.
    public private(set) var markedCategories: [ExamCategory]

    public init(
        seed: Int,
        tier: ExamTier,
        length: Int = ExamPaper.length,
        passMark: Int = ExamPaper.passMark
    ) {
        self.seed = seed
        self.tier = tier
        self.length = length
        self.passMark = passMark
        index = 0
        answer = nil
        submitted = false
        marks = []
        markedCategories = []
    }

    public var correct: Int { marks.count { $0 } }
    public var isComplete: Bool { index >= length }
    public var passed: Bool { correct >= passMark }

    /// Builds up the current answer without grading it. Every format routes
    /// through here; the multi-tap ones call it repeatedly.
    public mutating func draft(_ answer: ExamAnswer) {
        guard !submitted, !isComplete else { return }
        self.answer = answer
    }

    /// Locks the answer in and grades it. A second call is ignored — the first
    /// commit is the exam's answer, which is how the option rows have always
    /// behaved.
    @discardableResult
    public mutating func submit(_ prompt: ExamPrompt) -> Bool {
        guard !submitted, !isComplete, let answer else { return false }
        submitted = true
        let right = prompt.isCorrect(answer)
        marks.append(right)
        markedCategories.append(prompt.question.category)
        return right
    }

    /// Steps to the next question once the current one is graded. Stepping off
    /// the last one is what completes the paper.
    public mutating func advance() {
        guard submitted, !isComplete else { return }
        answer = nil
        submitted = false
        index += 1
    }

    /// A fresh paper after RETRY, seeded off this one so a retry is never a
    /// replay. Shape and tier carry over — `QuizSession.retry`'s contract, and
    /// the same prime.
    public func retry() -> ExamRun {
        ExamRun(seed: seed &+ 7919, tier: tier, length: length, passMark: passMark)
    }

    /// The record this sitting leaves behind, for `ExamRecordStore`.
    public func result(day: Int) -> ExamResult {
        var tallies: [String: ExamCategoryTally] = [:]
        for (mark, category) in zip(marks, markedCategories) {
            let tally = tallies[category.rawValue] ?? ExamCategoryTally(right: 0, asked: 0)
            tallies[category.rawValue] = ExamCategoryTally(
                right: tally.right + (mark ? 1 : 0),
                asked: tally.asked + 1
            )
        }
        return ExamResult(
            tier: tier,
            correct: correct,
            length: length,
            passed: passed,
            day: day,
            categories: tallies
        )
    }
}
