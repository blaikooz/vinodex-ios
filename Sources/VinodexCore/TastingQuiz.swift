import Foundation

/// One multiple-choice question, in the shape a WSET Level 1 paper asks them:
/// a short factual prompt and four candidates, exactly one right.
///
/// Options are **entry ids**, not strings. That is what makes the reveal worth
/// having — the right answer is a real grape with a real page behind it, so
/// "learn more" is a route rather than a dead end, and a wrong answer can still
/// be shown as the thing it actually is.
public struct QuizQuestion: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case color
        case body
        case origin
        case region

        /// The little label above the prompt, so a run of questions reads as a
        /// syllabus rather than as trivia.
        public var topic: String {
            switch self {
            case .color: "GRAPE COLOUR"
            case .body: "BODY"
            case .origin: "ORIGIN"
            case .region: "REGIONAL"
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
/// costs nothing, since the seed advances per question anyway.
public enum TastingQuiz {
    /// Candidates per question. Four is the WSET paper's own shape.
    public static let optionCount = 4

    /// A question for this seed, or nil if the database cannot furnish one.
    ///
    /// Tries the four kinds starting from `seed`, so an under-populated table
    /// degrades to a different kind of question rather than to a blank screen.
    /// Only if all four fail — a database with fewer than four grapes — does
    /// this give up.
    public static func question(seed: Int, in db: WineDatabase) -> QuizQuestion? {
        let kinds = QuizQuestion.Kind.allCases
        let start = mod(seed, kinds.count)
        for step in 0..<kinds.count {
            let kind = kinds[(start + step) % kinds.count]
            if let question = question(kind: kind, seed: seed, in: db) {
                return question
            }
        }
        return nil
    }

    static func question(kind: QuizQuestion.Kind, seed: Int, in db: WineDatabase) -> QuizQuestion? {
        switch kind {
        case .color: colorQuestion(seed: seed, in: db)
        case .body: bodyQuestion(seed: seed, in: db)
        case .origin: originQuestion(seed: seed, in: db)
        case .region: regionQuestion(seed: seed, in: db)
        }
    }

    // MARK: Kinds

    /// "Which of these is a WHITE grape?" — answer white, distractors red.
    private static func colorQuestion(seed: Int, in db: WineDatabase) -> QuizQuestion? {
        let wanted: GrapeColor = mod(seed, 2) == 0 ? .white : .red
        let matching = grapes(in: db) { $0.grapeType == wanted }
        let others = grapes(in: db) { $0.grapeType != wanted }
        return assemble(
            kind: .color,
            prompt: "Which of these is a \(wanted.rawValue.uppercased()) grape?",
            matching: matching,
            others: others,
            seed: seed
        )
    }

    /// "Which of these grapes is FULL bodied?"
    private static func bodyQuestion(seed: Int, in db: WineDatabase) -> QuizQuestion? {
        let bodies = GrapeBody.allCases
        let wanted = bodies[mod(seed, bodies.count)]
        let key = TextNormalize.label(wanted.rawValue)
        let matching = grapes(in: db) { TextNormalize.label($0.grapeBodyClass) == key }
        let others = grapes(in: db) {
            let actual = TextNormalize.label($0.grapeBodyClass)
            return !actual.isEmpty && actual != key
        }
        return assemble(
            kind: .body,
            prompt: "Which of these grapes is \(wanted.label) bodied?",
            matching: matching,
            others: others,
            seed: seed
        )
    }

    /// "Which of these grapes originates in FRANCE?"
    ///
    /// The distractor pool excludes every grape from the same country, not just
    /// the answer — otherwise a second French grape can appear as a "wrong"
    /// option and the question has two right answers.
    private static func originQuestion(seed: Int, in db: WineDatabase) -> QuizQuestion? {
        let countries = grapes(in: db)
            .map(\.grapeCountryOfOrigin)
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { acc, c in if !acc.contains(c) { acc.append(c) } }
            .sorted()
        guard !countries.isEmpty else { return nil }

        let country = countries[mod(seed, countries.count)]
        let key = TextNormalize.label(country)
        let matching = grapes(in: db) { TextNormalize.label($0.grapeCountryOfOrigin) == key }
        let others = grapes(in: db) { TextNormalize.label($0.grapeCountryOfOrigin) != key }
        return assemble(
            kind: .origin,
            prompt: "Which of these grapes originates in \(country.uppercased())?",
            matching: matching,
            others: others,
            seed: seed
        )
    }

    /// "Which of these grapes is notable in BORDEAUX?"
    ///
    /// Built from the region's own `notableGrapes` list, resolved back to grape
    /// entries so the answer has a page. Distractors are grapes the region does
    /// not name — again excluding *every* grape it names, not just the answer.
    private static func regionQuestion(seed: Int, in db: WineDatabase) -> QuizQuestion? {
        let regions = db.entries(in: .regions)
            .filter { !$0.notableGrapes.isEmpty }
            .sorted { $0.id < $1.id }
        guard !regions.isEmpty else { return nil }

        // Walk from the seed rather than indexing once: most regions name one or
        // two grapes, and a region whose names do not resolve to entries would
        // otherwise abandon the whole kind.
        for step in 0..<regions.count {
            let region = regions[mod(seed &+ step, regions.count)]
            let named = Set(region.notableGrapes.map { TextNormalize.label($0) })
            let matching = grapes(in: db) { named.contains(TextNormalize.label($0.common.name)) }
            let others = grapes(in: db) { !named.contains(TextNormalize.label($0.common.name)) }
            if let question = assemble(
                kind: .region,
                prompt: "Which of these grapes is notable in \(region.name.uppercased())?",
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
        matching: [GrapeEntry],
        others: [GrapeEntry],
        seed: Int
    ) -> QuizQuestion? {
        guard !matching.isEmpty, others.count >= optionCount - 1 else { return nil }

        let answer = matching[mod(seed, matching.count)]

        // Strided so the three distractors are spread through the pool instead
        // of being neighbours in id order, which tends to pick the same grape
        // family three times.
        var distractors: [GrapeEntry] = []
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
