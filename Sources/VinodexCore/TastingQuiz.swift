import Foundation
import Observation

/// One multiple-choice question, in the shape a WSET Level 1 paper asks them:
/// a short factual prompt and four candidates, exactly one right.
///
/// Options are **entry ids**, not strings. That is what makes the reveal worth
/// having — the right answer is a real entry with a real page behind it, so
/// "learn more" is a route rather than a dead end, and a wrong answer can still
/// be shown as the thing it actually is.
public struct QuizQuestion: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case grapes
        case region
        case style

        /// The little label above the prompt, so a run of questions reads as a
        /// syllabus rather than as trivia.
        public var topic: String {
            switch self {
            case .grapes: "GRAPES"
            case .region: "REGIONS"
            case .style: "STYLES"
            }
        }
    }

    public let kind: Kind
    public let prompt: String
    public let optionIDs: [String]
    public let answerID: String

    public var id: String { kind.rawValue + ":" + answerID }

    public func isCorrect(_ entryID: String) -> Bool { entryID == answerID }
}

/// The quiz's difficulty ladder. Passing a tier's paper unlocks the next —
/// see `QuizProgress`.
///
/// Difficulty is a property of the *answer pool*, not of the question shape:
/// a novice paper asks about the grapes everyone has heard of, a sommelier
/// paper about the ones almost nobody has. The mechanics — four options, one
/// right — never change, because the mechanics are not what is hard about
/// wine.
public enum QuizTier: String, Codable, CaseIterable, Sendable, Identifiable {
    case novice = "NOVICE"
    case enthusiast = "ENTHUSIAST"
    case sommelier = "SOMMELIER"

    public var id: String { rawValue }

    public var displayName: String { rawValue }

    /// Order for lock checks: novice < enthusiast < sommelier.
    public var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// The tier a pass at this one unlocks; nil at the top of the ladder.
    public var next: QuizTier? {
        let all = Self.allCases
        let index = rank + 1
        return index < all.count ? all[index] : nil
    }
}

/// A quiz run with a pass mark.
///
/// A plain value type so the whole session round-trips through
/// `ScreenStateStore`'s JSON helpers as one blob — restoring a half-finished
/// run is a decode, not a reassembly of loose counters.
///
/// `length` and `passMark` are instance values, not just the statics: the
/// daily challenge is a shorter paper, and a second session type for it would
/// duplicate everything else here.
public struct QuizSession: Sendable, Codable, Equatable {
    /// The practice paper's shape, and the default.
    public static let length = 10
    /// Correct answers needed to pass the default paper — 8/10, 80%.
    public static let passMark = 8

    /// Fixed at start; every question in the run derives from it.
    public let seed: Int
    /// This paper's shape.
    public let length: Int
    public let passMark: Int
    public let tier: QuizTier
    /// Zero-based position of the current question.
    public private(set) var index: Int
    public private(set) var correct: Int
    /// The option picked for the current question; nil while unanswered.
    public private(set) var chosenID: String?
    /// Right or wrong per question answered so far, oldest first (0.7.8, C1).
    ///
    /// **Correctness only, and that is the whole security argument.** The share
    /// string built from this is published to people holding the same daily
    /// paper, so what it encodes has to be something they cannot invert. A
    /// per-question *chosen option* would be exactly that leak — four options
    /// and a "wrong" marker eliminates one for everybody who reads it. A bare
    /// boolean says how you did and nothing about what the answer was. See
    /// `DailyResult`.
    ///
    /// `correct` is kept rather than derived from this so `passed` reads the
    /// same field it always has; `marksAgreeWithCount` pins the two together.
    public private(set) var marks: [Bool]

    public init(
        seed: Int,
        length: Int = QuizSession.length,
        passMark: Int = QuizSession.passMark,
        tier: QuizTier = .enthusiast
    ) {
        self.seed = seed
        self.length = length
        self.passMark = passMark
        self.tier = tier
        index = 0
        correct = 0
        chosenID = nil
        marks = []
    }

    /// Decoded by hand for one reason: `marks` did not exist before 0.7.8, and
    /// the synthesised initialiser treats a missing key as a failure rather
    /// than as a default. A paper half-sat across the upgrade would decode to
    /// nil and be silently thrown away — the exact "losing a half-finished
    /// paper" cost this type's storage note weighs. `decodeIfPresent` keeps it,
    /// minus a grid it never recorded; `DailyResult.card` handles that case.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seed = try container.decode(Int.self, forKey: .seed)
        length = try container.decode(Int.self, forKey: .length)
        passMark = try container.decode(Int.self, forKey: .passMark)
        tier = try container.decode(QuizTier.self, forKey: .tier)
        index = try container.decode(Int.self, forKey: .index)
        correct = try container.decode(Int.self, forKey: .correct)
        chosenID = try container.decodeIfPresent(String.self, forKey: .chosenID)
        marks = try container.decodeIfPresent([Bool].self, forKey: .marks) ?? []
    }

    public var isComplete: Bool { index >= length }
    public var passed: Bool { correct >= passMark }
    public var answered: Bool { chosenID != nil }

    /// Locks in an answer. A second tap is ignored — the first click is the
    /// exam's answer, exactly like the option rows already behave.
    public mutating func choose(_ id: String, in question: QuizQuestion) {
        guard chosenID == nil, !isComplete else { return }
        chosenID = id
        let right = question.isCorrect(id)
        if right { correct += 1 }
        marks.append(right)
    }

    /// Steps to the next question once the current one is answered. Stepping
    /// off the last question is what makes the session complete.
    public mutating func advance() {
        guard chosenID != nil, !isComplete else { return }
        chosenID = nil
        index += 1
    }

    /// The next session after RETRY — a fresh run whose seed is derived from
    /// this one, so retrying never replays the identical paper. The paper's
    /// shape and tier carry over.
    public func retry() -> QuizSession {
        QuizSession(seed: seed &+ 7919, length: length, passMark: passMark, tier: tier)
    }
}

/// Which tiers have been unlocked. Novice is always open; passing a tier's
/// paper opens the next.
///
/// In `UserDefaults` rather than `ScreenStateStore` because progression is the
/// one quiz fact that must survive a cold launch — losing a half-finished
/// paper is an inconvenience, losing the SOMMELIER unlock is a betrayal.
@MainActor
@Observable
public final class QuizProgress {
    public static let shared = QuizProgress()

    public static let storageKey = "quizTierUnlocked"
    /// Which exams have been passed at least once (0.6.7, A4) — the star on
    /// the exam list.
    ///
    /// Deliberately **not** derivable from `highestUnlocked`. The two agree for
    /// the first two tiers and diverge at the top: passing ENTHUSIAST unlocks
    /// SOMMELIER, so a ladder position of "sommelier unlocked" says nothing
    /// about whether SOMMELIER itself has ever been passed, and that is exactly
    /// the exam whose star is worth having. Stored as its own list.
    public static let completedKey = "quizTiersCompleted"

    private let defaults: UserDefaults

    /// The highest tier the user may start. Missing or unreadable → novice.
    private(set) public var highestUnlocked: QuizTier
    /// Every tier passed at least once, in no particular order.
    private(set) public var completed: Set<QuizTier>

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        highestUnlocked = .novice
        completed = []
        reload()
    }

    /// Re-reads from `defaults` after a restore wrote the key behind this
    /// store's back — see `BookmarkStore.reload()` for the full reasoning.
    public func reload() {
        highestUnlocked = defaults.string(forKey: Self.storageKey)
            .flatMap(QuizTier.init(rawValue:)) ?? .novice
        // An unreadable or partly-unknown list degrades to whatever of it still
        // resolves, matching how the bookmark shelves treat a stale id: a
        // renamed tier should cost its own star, not the whole set.
        let raw = defaults.array(forKey: Self.completedKey) as? [String] ?? []
        completed = Set(raw.compactMap(QuizTier.init(rawValue:)))
    }

    public func unlocked(_ tier: QuizTier) -> Bool {
        tier.rank <= highestUnlocked.rank
    }

    /// Whether this exam has ever been passed — drives its completion star.
    public func isCompleted(_ tier: QuizTier) -> Bool {
        completed.contains(tier)
    }

    /// Records a pass; returns the newly unlocked tier, or nil if the pass
    /// opened nothing new (repeat passes, or the top of the ladder).
    ///
    /// The completion star is recorded *before* that guard, and has to be: a
    /// repeat pass and a pass at the top of the ladder both return nil, and
    /// both are still passes.
    @discardableResult
    public func recordPass(tier: QuizTier) -> QuizTier? {
        if completed.insert(tier).inserted {
            defaults.set(completed.map(\.rawValue).sorted(), forKey: Self.completedKey)
        }
        guard let next = tier.next, next.rank > highestUnlocked.rank else { return nil }
        highestUnlocked = next
        defaults.set(next.rawValue, forKey: Self.storageKey)
        return next
    }

    public func reset() {
        highestUnlocked = .novice
        completed = []
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.completedKey)
    }
}

/// Builds questions out of the shipped database.
///
/// Generated rather than authored, for the same reason the entry text is not
/// paraphrased anywhere in this app: a hand-written question bank is a second
/// copy of the data that goes stale the first time the generator runs. Every
/// prompt below is assembled from fields the dataset already holds, so a
/// question cannot assert something the entry it links to contradicts.
///
/// Deterministic from a seed rather than randomised, matching `DailyPick`.
/// That makes the whole thing testable — a given seed is a given question — and
/// costs nothing, since the session seed is fixed at start anyway.
public enum TastingQuiz {
    /// Candidates per question. Four is the WSET paper's own shape.
    public static let optionCount = 4

    /// Question `number` (0..<session length) of a session.
    ///
    /// The kind rotates from the seed — `kinds[mod(seed + number, 3)]` — so
    /// every run gets a near-even split across the three topics and two runs
    /// with different seeds start on different topics. The per-question seed is
    /// spread with a prime so adjacent questions do not share pools. If the
    /// rotated kind cannot furnish a question, the remaining kinds are tried,
    /// so an under-populated table degrades to a different topic rather than
    /// to a blank screen.
    public static func question(
        number: Int,
        sessionSeed: Int,
        tier: QuizTier = .enthusiast,
        in db: WineDatabase
    ) -> QuizQuestion? {
        let kinds = QuizQuestion.Kind.allCases
        let start = mod(sessionSeed &+ number, kinds.count)
        let seed = sessionSeed &+ number &* 7919
        for step in 0..<kinds.count {
            let kind = kinds[(start + step) % kinds.count]
            if let question = question(kind: kind, seed: seed, tier: tier, in: db) {
                return question
            }
        }
        return nil
    }

    /// A kind's question at the tier, degrading to the full pool rather than
    /// to nothing: a tier that filters a pool below what `assemble` needs
    /// should cost the difficulty, not the question.
    static func question(
        kind: QuizQuestion.Kind,
        seed: Int,
        tier: QuizTier = .enthusiast,
        in db: WineDatabase
    ) -> QuizQuestion? {
        switch kind {
        case .grapes:
            grapeQuestion(seed: seed, in: db, answerEligible: grapeEligible(tier))
                ?? grapeQuestion(seed: seed, in: db, answerEligible: { _ in true })
        case .region:
            regionQuestion(seed: seed, in: db, answerEligible: regionEligible(tier, in: db))
                ?? regionQuestion(seed: seed, in: db, answerEligible: { _ in true })
        case .style:
            styleQuestion(seed: seed, in: db, answerEligible: styleEligible(tier))
                ?? styleQuestion(seed: seed, in: db, answerEligible: { _ in true })
        }
    }

    // MARK: Tier predicates
    //
    // Difficulty filters the *answer* pool only. The distractor pools are
    // untouched, so the single-right-answer predicates in each generator are
    // exactly what they always were — a sommelier paper is harder because the
    // right answer is obscure, not because the wrong answers cheat.

    /// Novice asks about household names; sommelier about the cellar's back
    /// corner. NOBLE sits with COMMON on the easy side deliberately — nobility
    /// is fame, not obscurity.
    private static func grapeEligible(_ tier: QuizTier) -> (GrapeEntry) -> Bool {
        switch tier {
        case .novice: { $0.rarity == .noble || $0.rarity == .common }
        case .enthusiast: { _ in true }
        // GODFORSAKEN is the backest corner there is (0.6.2, A1).
        case .sommelier: { $0.rarity == .uncommon || $0.rarity == .rare || $0.rarity == .godforsaken }
        }
    }

    /// Styles mirror the grape ladder; a style without a stated rarity counts
    /// as easy, since the unstated ones are the everyday categories.
    private static func styleEligible(_ tier: QuizTier) -> (WineEntry) -> Bool {
        switch tier {
        case .novice: { $0.rarity == nil || $0.rarity == .noble || $0.rarity == .common }
        case .enthusiast: { _ in true }
        case .sommelier: { $0.rarity == .uncommon || $0.rarity == .rare || $0.rarity == .godforsaken }
        }
    }

    /// Regions carry no rarity, so the novice filter is breadth instead: a
    /// region famous for several grapes is easier to place than one known for
    /// a single obscure variety.
    private static func regionEligible(_ tier: QuizTier, in db: WineDatabase) -> (WineEntry) -> Bool {
        switch tier {
        case .novice:
            let grapeKeys = Set(grapes(in: db).map { TextNormalize.label($0.common.name) })
            return { region in
                region.notableGrapes.count { grapeKeys.contains(TextNormalize.label($0)) } >= 2
            }
        case .enthusiast, .sommelier:
            return { _ in true }
        }
    }

    // MARK: Kinds

    /// "Which of these grapes is a FULL-BODIED WHITE from FRANCE?"
    ///
    /// The three facts come from the answer grape itself, so the prompt can
    /// never disagree with the entry. A distractor must *provably* fail one of
    /// them: a grape whose body or country field is empty is only eligible as
    /// a distractor through a fact it does state — otherwise a grape that
    /// merely doesn't record its body could sit next to the answer as a second
    /// right answer nobody can disprove.
    private static func grapeQuestion(
        seed: Int,
        in db: WineDatabase,
        answerEligible: (GrapeEntry) -> Bool
    ) -> QuizQuestion? {
        let candidates = grapes(in: db) {
            !$0.grapeBodyClass.isEmpty && !$0.grapeCountryOfOrigin.isEmpty && answerEligible($0)
        }
        guard !candidates.isEmpty else { return nil }

        // Walk from the seed rather than indexing once: a candidate whose fact
        // trio is too common to leave three provable failures would otherwise
        // abandon the whole kind.
        for step in 0..<candidates.count {
            let answer = candidates[mod(seed &+ step, candidates.count)]
            let bodyKey = TextNormalize.label(answer.grapeBodyClass)
            let countryKey = TextNormalize.label(answer.grapeCountryOfOrigin)

            let matching = grapes(in: db) {
                answerEligible($0)
                    && $0.grapeType == answer.grapeType
                    && TextNormalize.label($0.grapeBodyClass) == bodyKey
                    && TextNormalize.label($0.grapeCountryOfOrigin) == countryKey
            }
            let others = grapes(in: db) {
                $0.grapeType != answer.grapeType
                    || (!$0.grapeBodyClass.isEmpty && TextNormalize.label($0.grapeBodyClass) != bodyKey)
                    || (!$0.grapeCountryOfOrigin.isEmpty && TextNormalize.label($0.grapeCountryOfOrigin) != countryKey)
            }
            if let question = assemble(
                kind: .grapes,
                prompt: "Which of these grapes is a \(answer.grapeBodyClass.uppercased())-BODIED"
                    + " \(answer.grapeType.rawValue.uppercased())"
                    + " from \(answer.grapeCountryOfOrigin.uppercased())?",
                matching: matching.map(WineEntry.grape),
                others: others.map(WineEntry.grape),
                seed: seed
            ) {
                return question
            }
        }
        return nil
    }

    /// "Which of these regions is known for MERLOT?" — the region is the
    /// answer, inverting the old grape-answer form.
    ///
    /// Prompts only ever name a grape that both resolves to a real entry and
    /// appears in some region's `notableGrapes`, and the distractor pool
    /// excludes every region that names it — otherwise a second Merlot region
    /// appears as a "wrong" option and the question has two right answers.
    private static func regionQuestion(
        seed: Int,
        in db: WineDatabase,
        answerEligible: (WineEntry) -> Bool
    ) -> QuizQuestion? {
        let regions = db.entries(in: .regions).sorted { $0.id < $1.id }
        guard !regions.isEmpty else { return nil }

        let grapeKeys = Set(grapes(in: db).map { TextNormalize.label($0.common.name) })
        var names: [String] = []
        var seen = Set<String>()
        for region in regions {
            for name in region.notableGrapes {
                let key = TextNormalize.label(name)
                if grapeKeys.contains(key), seen.insert(key).inserted {
                    names.append(name)
                }
            }
        }
        names.sort()
        guard !names.isEmpty else { return nil }

        // Walk from the seed: a grape named by nearly every region cannot
        // leave three distractors, and should cost one step, not the kind.
        for step in 0..<names.count {
            let name = names[mod(seed &+ step, names.count)]
            let key = TextNormalize.label(name)
            let matching = regions.filter { region in
                answerEligible(region)
                    && region.notableGrapes.contains { TextNormalize.label($0) == key }
            }
            let others = regions.filter { region in
                !region.notableGrapes.contains { TextNormalize.label($0) == key }
            }
            if let question = assemble(
                kind: .region,
                prompt: "Which of these regions is known for \(name.uppercased())?",
                matching: matching,
                others: others,
                seed: seed
            ) {
                return question
            }
        }
        return nil
    }

    /// "Which of these styles features MERLOT?" — the style is the answer.
    ///
    /// Same single-right-answer discipline as the region kind, against
    /// `StyleDetails.notableGrapes`. If no grape name can furnish a question,
    /// falls back to the origin form — "Which of these styles originates in
    /// FRANCE?" — before giving the kind up.
    private static func styleQuestion(
        seed: Int,
        in db: WineDatabase,
        answerEligible: (WineEntry) -> Bool
    ) -> QuizQuestion? {
        let styles = db.entries(in: .styles).sorted { $0.id < $1.id }
        guard !styles.isEmpty else { return nil }

        let grapeKeys = Set(grapes(in: db).map { TextNormalize.label($0.common.name) })
        var names: [String] = []
        var seen = Set<String>()
        for style in styles {
            for name in style.notableGrapes {
                let key = TextNormalize.label(name)
                if grapeKeys.contains(key), seen.insert(key).inserted {
                    names.append(name)
                }
            }
        }
        names.sort()

        for step in 0..<names.count {
            let name = names[mod(seed &+ step, names.count)]
            let key = TextNormalize.label(name)
            let matching = styles.filter { style in
                answerEligible(style)
                    && style.notableGrapes.contains { TextNormalize.label($0) == key }
            }
            let others = styles.filter { style in
                !style.notableGrapes.contains { TextNormalize.label($0) == key }
            }
            if let question = assemble(
                kind: .style,
                prompt: "Which of these styles features \(name.uppercased())?",
                matching: matching,
                others: others,
                seed: seed
            ) {
                return question
            }
        }

        // Origin fallback. Empty origins stay out of both pools: a style that
        // does not state its origin can neither be the answer nor be proven
        // wrong.
        let countries = styles
            .compactMap(\.origin)
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { acc, c in if !acc.contains(c) { acc.append(c) } }
            .sorted()
        for step in 0..<countries.count {
            let country = countries[mod(seed &+ step, countries.count)]
            let key = TextNormalize.label(country)
            let matching = styles.filter {
                answerEligible($0) && TextNormalize.label($0.origin ?? "") == key
            }
            let others = styles.filter {
                let actual = TextNormalize.label($0.origin ?? "")
                return !actual.isEmpty && actual != key
            }
            if let question = assemble(
                kind: .style,
                prompt: "Which of these styles originates in \(country.uppercased())?",
                matching: matching,
                others: others,
                seed: seed
            ) {
                return question
            }
        }
        return nil
    }

    // MARK: Assembly

    /// One right answer plus `optionCount - 1` wrong ones, at a stable position.
    ///
    /// The answer's slot is derived from the seed rather than being shuffled, so
    /// it moves between questions but is reproducible for a given one. A fixed
    /// slot would be learnable within about three questions.
    private static func assemble(
        kind: QuizQuestion.Kind,
        prompt: String,
        matching: [WineEntry],
        others: [WineEntry],
        seed: Int
    ) -> QuizQuestion? {
        guard !matching.isEmpty, others.count >= optionCount - 1 else { return nil }

        let answer = matching[mod(seed, matching.count)]

        // Strided so the three distractors are spread through the pool instead
        // of being neighbours in id order, which tends to pick the same family
        // three times.
        var distractors: [WineEntry] = []
        var cursor = mod(seed, others.count)
        while distractors.count < optionCount - 1 {
            let candidate = others[cursor % others.count]
            if candidate.id != answer.id, !distractors.contains(where: { $0.id == candidate.id }) {
                distractors.append(candidate)
            }
            cursor += 17
            // Guard against a pool too small to yield enough distinct entries.
            if cursor > others.count * optionCount { return nil }
        }

        var ids = distractors.map(\.id)
        ids.insert(answer.id, at: mod(seed, optionCount))

        return QuizQuestion(kind: kind, prompt: prompt, optionIDs: ids, answerID: answer.id)
    }

    private static func grapes(
        in db: WineDatabase,
        where predicate: (GrapeEntry) -> Bool = { _ in true }
    ) -> [GrapeEntry] {
        db.entries(in: .grapes)
            .compactMap { if case .grape(let g) = $0 { g } else { nil } }
            .filter(predicate)
            .sorted { $0.id < $1.id }
    }

    /// Non-negative modulo. `seed` is a running counter and `%` in Swift keeps
    /// the sign of the dividend, which would index out of bounds.
    private static func mod(_ value: Int, _ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((value % count) + count) % count
    }
}
