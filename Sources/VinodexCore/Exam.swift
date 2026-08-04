import Foundation

/// The Wine Exam question bank (0.7.5, D) — the decoded half of
/// `shared/data/exam.ts`.
///
/// ## What this file is, and what `TastingQuiz.swift` still is
///
/// **The Wine Exam is not a new feature; it is this app's exam screen, rebuilt.**
/// `DexRoute.wsetQuiz` has been titled `"WINE EXAM"` since 0.5.9, its picker is
/// headed CHOOSE YOUR EXAM, its way out says BACK TO EXAMS, and the passport's
/// SOMMELIER stamp says in shipped copy that it is "The Wine Exam's top tier".
/// D1 asks to expand the Wine Exam into a full educational system, so this
/// **absorbs** that screen rather than sitting beside it — a second thing called
/// an exam, with a second ladder and a stamp pointing at the wrong one, is the
/// outcome nobody could have wanted.
///
/// `TastingQuiz` is not retired and is not dead code. It keeps the one job it is
/// better at: the **daily challenge**, five questions, the same paper for
/// everybody, derived from the day index. A generated paper cannot run out,
/// cannot go stale against the catalog, and cannot contradict an entry — which
/// is exactly what a daily needs and exactly what a finite authored bank cannot
/// promise. See `DailyChallenge`.
///
/// ## Two tier vocabularies, one ladder
///
/// The bank is authored in `beginner` / `intermediate` / `advanced`; the device's
/// ladder is `QuizTier`'s NOVICE / ENTHUSIAST / SOMMELIER. Those are not two
/// ladders — they are an authoring vocabulary and a product one, and they map
/// 1:1 and in order. `ExamTier.ladder` is that map, and `examTierMatchesLadder`
/// pins it.
///
/// The device's words win on screen for two reasons that are not taste:
/// `QuizTier`'s raw values are **persisted** in `quizTierUnlocked` and
/// `quizTiersCompleted`, so a user's SOMMELIER unlock is a string on disk; and
/// they are the words already printed on a shipped back-plate stamp. The bank's
/// words never reach the screen.
public enum ExamTier: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case beginner
    case intermediate
    case advanced

    public var id: String { rawValue }

    /// This tier's rung on the device's ladder — the words the user sees.
    public var ladder: QuizTier {
        switch self {
        case .beginner: .novice
        case .intermediate: .enthusiast
        case .advanced: .sommelier
        }
    }

    /// Order for lock checks; agrees with `QuizTier.rank` by construction.
    public var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

public extension QuizTier {
    /// The bank tier this rung draws from — the inverse of `ExamTier.ladder`.
    var examTier: ExamTier {
        switch self {
        case .novice: .beginner
        case .enthusiast: .intermediate
        case .sommelier: .advanced
        }
    }
}

/// The sixteen syllabus areas (D3). Raw values are the authored keys; the label
/// a screen shows comes from `ExamCatalog.label(for:)`, which reads the table
/// `shared/` already carries rather than restating it here.
public enum ExamCategory: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case grapes = "GRAPES"
    case regions = "REGIONS"
    case countries = "COUNTRIES"
    case styles = "STYLES"
    case flavorProfiles = "FLAVOR_PROFILES"
    case viticulture = "VITICULTURE"
    case winemaking = "WINEMAKING"
    case faults = "FAULTS"
    case foodPairing = "FOOD_PAIRING"
    case servingStorage = "SERVING_STORAGE"
    case sparkling = "SPARKLING"
    case fortified = "FORTIFIED"
    case sweetWine = "SWEET_WINE"
    case history = "HISTORY"
    case appellations = "APPELLATIONS"
    case blindTasting = "BLIND_TASTING"

    public var id: String { rawValue }
}

/// The seven question shapes (D5). Every one of them has an answering UI —
/// `ExamQuestionCard`'s switch over `ExamQuestion.Payload` is exhaustive, so an
/// eighth format cannot be added without the screen refusing to compile.
public enum ExamFormat: String, Codable, CaseIterable, Sendable, Hashable {
    case multipleChoice
    case trueFalse
    case selectAll
    case matching
    case ordering
    case imageIdentification
    case aromaIdentification
}

/// An image a question is asked *about*.
///
/// Indirect by design, and the indirection is the point: `countryOutline` names
/// a key in `icons.json`'s `countryShapeIcons`, `entryIcon` a catalog entry id.
/// **No question stores a file path**, so a renamed asset is a generator failure
/// rather than a blank tile on a question that is nothing but a picture.
public struct ExamImageRef: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable, Hashable {
        case countryOutline
        case entryIcon
    }

    public let kind: Kind
    public let key: String

    public init(kind: Kind, key: String) {
        self.kind = kind
        self.key = key
    }
}

/// One left/right pair in a matching question, authored correctly paired.
public struct ExamMatchPair: Codable, Sendable, Hashable {
    public let left: String
    public let right: String

    public init(left: String, right: String) {
        self.left = left
        self.right = right
    }
}

/// The two poles an ordering runs between, for the card's axis caption —
/// "DRIEST" to "SWEETEST" tells the candidate which way to sort, which the
/// items alone never can.
public struct ExamOrderAxis: Codable, Sendable, Hashable {
    public let from: String
    public let to: String

    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
}

/// One authored question.
///
/// ## Why the payload is an enum and not seven optionals
///
/// The bank serialises flat — the per-format fields are deliberately
/// non-overlapping, so `options`/`answer`/`pairs`/`items`/`noteKeys` never
/// collide and the whole thing *could* decode into one struct with seven
/// optional properties. It does not, because that shape pushes the same question
/// onto every reader forever: *is this the format whose `options` are populated?*
/// An enum with associated values answers it once, here, and every consumer gets
/// an exhaustive switch — which is what makes "all seven formats have an
/// answering UI" a compiler guarantee instead of a claim.
///
/// **Authored order is answer order.** `answerIndex` indexes the authored
/// `options`, matching pairs are authored correctly paired, and ordering items
/// are in the correct sequence. Nothing in this type is presentation-ready;
/// `ExamPrompt` is what a screen shows, and it shuffles.
public struct ExamQuestion: Sendable, Hashable, Identifiable, Decodable {
    public enum Payload: Sendable, Hashable {
        case multipleChoice(options: [String], answerIndex: Int)
        case trueFalse(answer: Bool)
        case selectAll(options: [String], answerIndices: [Int])
        case matching(pairs: [ExamMatchPair])
        case ordering(items: [String], axis: ExamOrderAxis)
        case aromaIdentification(noteKeys: [String], options: [String], answerIndex: Int)
        case imageIdentification(image: ExamImageRef, options: [String], answerIndex: Int)

        public var format: ExamFormat {
            switch self {
            case .multipleChoice: .multipleChoice
            case .trueFalse: .trueFalse
            case .selectAll: .selectAll
            case .matching: .matching
            case .ordering: .ordering
            case .aromaIdentification: .aromaIdentification
            case .imageIdentification: .imageIdentification
            }
        }
    }

    /// `EXQ-<CATEGORY-CODE>-<nnn>`. Stable across re-tiering.
    public let id: String
    public let tier: ExamTier
    public let category: ExamCategory
    /// The stem. For `trueFalse` this is the statement to be judged.
    public let prompt: String
    /// D7 — required on every question, and surfaced the moment it is answered
    /// rather than saved for a results screen. See `ExamQuestionCard`.
    public let explanation: String
    /// Cited where the claim is not self-evident from the catalog.
    public let source: String?
    /// Catalog entry **ids**, never names — the reason `LineageRef` uses ids.
    /// Walked by `find-missing-refs.mjs`; empty rather than nil when absent, so
    /// no caller has to think about the difference.
    public let entryRefs: [String]
    public let payload: Payload

    public var format: ExamFormat { payload.format }

    /// Internal rather than private so `ExamCatalog`'s element-wise decoder can
    /// fish an `id` out of a question that failed to decode — an error naming
    /// the question is worth an access level.
    enum CodingKeys: String, CodingKey {
        case id, tier, category, prompt, explanation, source, entryRefs, format
        case options, answerIndex, answer, answerIndices, pairs, items, axis, noteKeys, image
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        tier = try c.decode(ExamTier.self, forKey: .tier)
        category = try c.decode(ExamCategory.self, forKey: .category)
        prompt = try c.decode(String.self, forKey: .prompt)
        explanation = try c.decode(String.self, forKey: .explanation)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        entryRefs = try c.decodeIfPresent([String].self, forKey: .entryRefs) ?? []

        // `format` decides which payload keys are required, so an unknown format
        // throws here rather than decoding to a question with nothing in it.
        // `ExamCatalog` decodes element-wise, so that costs one question.
        switch try c.decode(ExamFormat.self, forKey: .format) {
        case .multipleChoice:
            payload = .multipleChoice(
                options: try c.decode([String].self, forKey: .options),
                answerIndex: try c.decode(Int.self, forKey: .answerIndex)
            )
        case .trueFalse:
            payload = .trueFalse(answer: try c.decode(Bool.self, forKey: .answer))
        case .selectAll:
            payload = .selectAll(
                options: try c.decode([String].self, forKey: .options),
                answerIndices: try c.decode([Int].self, forKey: .answerIndices)
            )
        case .matching:
            payload = .matching(pairs: try c.decode([ExamMatchPair].self, forKey: .pairs))
        case .ordering:
            payload = .ordering(
                items: try c.decode([String].self, forKey: .items),
                axis: try c.decode(ExamOrderAxis.self, forKey: .axis)
            )
        case .aromaIdentification:
            payload = .aromaIdentification(
                noteKeys: try c.decode([String].self, forKey: .noteKeys),
                options: try c.decode([String].self, forKey: .options),
                answerIndex: try c.decode(Int.self, forKey: .answerIndex)
            )
        case .imageIdentification:
            payload = .imageIdentification(
                image: try c.decode(ExamImageRef.self, forKey: .image),
                options: try c.decode([String].self, forKey: .options),
                answerIndex: try c.decode(Int.self, forKey: .answerIndex)
            )
        }
    }

    public init(
        id: String,
        tier: ExamTier,
        category: ExamCategory,
        prompt: String,
        explanation: String,
        source: String? = nil,
        entryRefs: [String] = [],
        payload: Payload
    ) {
        self.id = id
        self.tier = tier
        self.category = category
        self.prompt = prompt
        self.explanation = explanation
        self.source = source
        self.entryRefs = entryRefs
        self.payload = payload
    }
}

/// The decoded bank, loaded once from `exam.json`.
///
/// Independent of `WineDatabase` for the reason `FirmwareCatalog` is: the exam
/// is answerable without the catalog being decodable, and threading it through a
/// database that might have failed to load would make one failure into two. The
/// two do meet — `entryRefs` are catalog ids and the reveal resolves them — but
/// that join happens at the screen, where a nil entry is a tile that is simply
/// not drawn.
public struct ExamCatalog: Sendable {
    public let questions: [ExamQuestion]
    public let categoryLabels: [String: String]
    public let tierLabels: [String: String]
    /// The thinnest tier×category cell in the bank at authoring time (6). The
    /// number that bounds a balanced paper's per-category draw — see
    /// `ExamPaper`. Shipped as data rather than restated as a Swift literal,
    /// because a literal here would silently disagree with the bank the first
    /// time somebody added questions.
    public let minCellCount: Int
    /// Questions the JSON carried but that failed to decode. Non-empty is a
    /// data fault, not a runtime condition — `DiagnosticsReport` surfaces it and
    /// `examBankDecodes` fails on it.
    public let decodeErrors: [String]

    public init(
        questions: [ExamQuestion],
        categoryLabels: [String: String] = [:],
        tierLabels: [String: String] = [:],
        minCellCount: Int = 0,
        decodeErrors: [String] = []
    ) {
        self.questions = questions
        self.categoryLabels = categoryLabels
        self.tierLabels = tierLabels
        self.minCellCount = minCellCount
        self.decodeErrors = decodeErrors
        var pools: [ExamTier: [ExamCategory: [ExamQuestion]]] = [:]
        for question in questions {
            pools[question.tier, default: [:]][question.category, default: []].append(question)
        }
        // Sorted by id so a pool's order is the bank's order rather than the
        // JSON's — `ExamPaper` shuffles from a seed, and a seed is only
        // reproducible over a stable input order.
        self.pools = pools.mapValues { $0.mapValues { $0.sorted { $0.id < $1.id } } }
    }

    /// tier → category → questions, built once. Every draw goes through this;
    /// filtering 407 questions per question of a paper is the shape that makes a
    /// list screen stutter.
    public let pools: [ExamTier: [ExamCategory: [ExamQuestion]]]

    public static let shared: ExamCatalog = load()

    /// The distress signal, matching `FirmwareCatalog.unavailable`: an empty
    /// bank is not a degraded exam, it is no exam, and the screen says so rather
    /// than presenting a paper with nothing on it.
    public static let unavailable = ExamCatalog(questions: [])

    public var isEmpty: Bool { questions.isEmpty }

    public func label(for category: ExamCategory) -> String {
        categoryLabels[category.rawValue] ?? category.rawValue
    }

    /// The bank's own word for a tier. **Not what the screen shows** — the
    /// device's ladder does that, see `ExamTier.ladder`. Kept because the
    /// diagnostics panel reports on the bank as authored.
    public func label(for tier: ExamTier) -> String {
        tierLabels[tier.rawValue] ?? tier.rawValue
    }

    public func questions(tier: ExamTier, category: ExamCategory) -> [ExamQuestion] {
        pools[tier]?[category] ?? []
    }

    public func count(tier: ExamTier) -> Int {
        pools[tier]?.values.reduce(0) { $0 + $1.count } ?? 0
    }

    /// The thinnest live cell in a tier — recomputed from what actually decoded
    /// rather than trusting `minCellCount`, which is the *bank's* claim. The two
    /// agreeing is what `minCellCountMatchesTheBank` checks.
    public func thinnestCell(tier: ExamTier) -> Int {
        ExamCategory.allCases.map { questions(tier: tier, category: $0).count }.min() ?? 0
    }

    /// Element-wise, exactly as `WineDatabase` decodes entries: one malformed
    /// question costs one question, not the bank. A paper is assembled from
    /// whatever survived, and 406 questions is a working exam.
    private struct FailableQuestion: Decodable {
        let question: ExamQuestion?
        let error: String?

        init(from decoder: any Decoder) throws {
            do {
                question = try ExamQuestion(from: decoder)
                error = nil
            } catch {
                question = nil
                let id = try? decoder.container(keyedBy: ExamQuestion.CodingKeys.self)
                    .decodeIfPresent(String.self, forKey: .id)
                self.error = "\(id ?? "<no id>"): \(error)"
            }
        }
    }

    private struct Wire: Decodable {
        let questions: [FailableQuestion]
        let categoryLabels: [String: String]
        let tierLabels: [String: String]
        let minCellCount: Int
    }

    private static func load() -> ExamCatalog {
        guard
            let url = Bundle.module.url(forResource: "exam", withExtension: "json", subdirectory: "Resources")
                ?? Bundle.module.url(forResource: "exam", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let wire = try? JSONDecoder().decode(Wire.self, from: data)
        else { return unavailable }
        return ExamCatalog(
            questions: wire.questions.compactMap(\.question),
            categoryLabels: wire.categoryLabels,
            tierLabels: wire.tierLabels,
            minCellCount: wire.minCellCount,
            decodeErrors: wire.questions.compactMap(\.error)
        )
    }
}
