import Foundation
import Observation

/// What the player has done at WHAT'S THAT…? (0.8.8, E3).
///
/// ## Why this exists
///
/// The game kept nothing. Its whole state lived in `ScreenStateStore`, which is
/// session state and is documented as deliberately never written to
/// `UserDefaults`, and `VinodexApp` calls `forget` on the key when the route is
/// left — so a round's score existed for as long as you were looking at it. A
/// number that is discarded the moment it is produced is not a score, and a game
/// whose scores are discarded is a toy.
///
/// The nearest sibling on the same shelf already had the answer: DAILY CHALLENGE
/// is `TastingQuiz` plus `StreakStore`, and it is the streak — not the paper —
/// that makes a player come back. This is the same split. `WhatsThat.Play` stays
/// pure and knows nothing about disk; this holds the six numbers a played round
/// produces and nothing else.
///
/// ## What it does not do
///
/// **No daily identity, and that is deliberate.** DAILY CHALLENGE is one sitting
/// per local day and owns that shape; WHAT'S THAT…? has always dealt a fresh
/// round on every open through `RevealCursor`, and PLAY AGAIN is unbounded. A
/// second "one per day" feature on the same shelf would be two front doors to the
/// same idea. So `streak` here counts *consecutive solves*, not consecutive days
/// — a run, which is the thing an unbounded game can honestly have.
public struct WhatsThatRecord: Sendable, Hashable, Codable {
    public var played: Int
    public var solved: Int
    public var bestScore: Int
    /// Consecutive solves, broken by giving up or running out of clues.
    public var streak: Int
    public var bestStreak: Int
    /// Every point scored, so an average is available without storing one.
    public var totalScore: Int

    public init(
        played: Int = 0,
        solved: Int = 0,
        bestScore: Int = 0,
        streak: Int = 0,
        bestStreak: Int = 0,
        totalScore: Int = 0
    ) {
        self.played = played
        self.solved = solved
        self.bestScore = bestScore
        self.streak = streak
        self.bestStreak = bestStreak
        self.totalScore = totalScore
    }

    public static let empty = WhatsThatRecord()

    public var isEmpty: Bool { played == 0 }

    /// Rounded down, which is the honest direction for a boast.
    public var averageScore: Int {
        solved == 0 ? 0 : totalScore / solved
    }

    /// Solve rate as a whole percent.
    public var solveRate: Int {
        played == 0 ? 0 : Int((Double(solved) / Double(played) * 100).rounded())
    }

    /// Fold one finished round in.
    ///
    /// Takes the `Play` rather than a score so the caller cannot report a solve
    /// that did not happen, and so the "did they win" question is answered in
    /// one place by the type that knows. A round still in progress is ignored:
    /// this is called from a transition, and a transition that fires twice must
    /// not count twice.
    public mutating func record(_ play: WhatsThat.Play) {
        guard let outcome = play.outcome else { return }
        played += 1
        switch outcome {
        case .solved:
            solved += 1
            totalScore += play.score
            bestScore = max(bestScore, play.score)
            streak += 1
            bestStreak = max(bestStreak, streak)
        case .gaveUp, .lost:
            streak = 0
        }
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case played, solved, bestScore, streak, bestStreak, totalScore
    }

    /// **Hand-written, and every field is `decodeIfPresent`.**
    ///
    /// The house rule, and it is a rule because it has nearly cost real data
    /// three times: Swift's synthesised decoder treats a missing key as a
    /// failure, the store below reads with `try?`, and the two together turn "a
    /// field was added" into "the record is gone". `DeviceBuild` and
    /// `QuizSession` both carry this decoder for that reason. This type is
    /// brand new and has nothing to be compatible *with* — which is exactly when
    /// writing it is free, and exactly when it gets skipped.
    ///
    /// The double-optional dance is `DeviceBuild`'s: `decodeIfPresent` still
    /// throws on a key that is present and the wrong shape, so `try?` flattens
    /// that to the same default a missing key gets. A record with one corrupt
    /// number should lose the number, not the record.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read(_ key: CodingKeys) -> Int {
            ((try? c.decodeIfPresent(Int.self, forKey: key)) ?? nil) ?? 0
        }
        self.init(
            played: read(.played),
            solved: read(.solved),
            bestScore: read(.bestScore),
            streak: read(.streak),
            bestStreak: read(.bestStreak),
            totalScore: read(.totalScore)
        )
    }
}

/// The record on disk.
///
/// One JSON blob under one key, like `CustomDeviceStore`, rather than six
/// scalars like `StreakStore` — six related numbers written in six calls can be
/// interrupted between any two of them, and this one is written from a single
/// transition. `Observable` so the screen redraws when a round lands.
@MainActor
@Observable
public final class WhatsThatRecordStore {
    public static let shared = WhatsThatRecordStore()

    public nonisolated static let storageKey = "whatsThatRecord"

    private let defaults: UserDefaults
    public private(set) var record: WhatsThatRecord

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `try?` — which is safe only because of the decoder above. See it.
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(WhatsThatRecord.self, from: data) {
            record = decoded
        } else {
            record = .empty
        }
    }

    /// Fold in a finished round and persist.
    ///
    /// **Call from the transition, never from a view body** — the contract
    /// `PassportProgress.announce` and `QuizProgress.recordPass` both carry, for
    /// the reason both carry it: a body that re-renders would count the same
    /// round twice. `WhatsThatScreen` calls this from the one place a round can
    /// end and marks the session recorded so a restore cannot repeat it.
    public func record(_ play: WhatsThat.Play) {
        var next = record
        next.record(play)
        guard next != record else { return }
        record = next
        persist()
    }

    public func reset() {
        record = .empty
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
