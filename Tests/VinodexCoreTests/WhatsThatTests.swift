import Testing
import Foundation
@testable import VinodexCore

/// The guessing game behind WHAT'S THAT…? (0.7.9, B).
///
/// **This suite is the reason the game is in Core.** The clue rules, the reveal
/// order, the scoring curve and the answer matching are all claims about *wine*
/// and about the catalog, and the house rule `OCRService` writes down puts those
/// where `swift test` on Linux can see them. The view chooses fonts.
///
/// Two properties matter more than the rest and both are checked across the
/// whole shuffle rather than on a favourite example: **every clue is true of its
/// own answer**, and **the full clue set identifies that answer uniquely**. The
/// spec calls the second one out — "a round that cannot be won on the full set
/// is a bug, and that is a testable property" — and the first is its silent
/// partner, because a round can be uniquely solvable and still lie.
@Suite("What's that")
struct WhatsThatTests {
    private let db = WineDatabase.shared

    /// Enough of the shuffle to cross both categories many times over, at a
    /// cursor stride that walks the whole pool.
    private var sampleCursors: [Int] { Array(0..<120) }

    private func round(_ cursor: Int) -> WhatsThat.Round? {
        WhatsThat.round(cursor: cursor, for: Self.fixedDay, in: db, calendar: Self.utc)
    }

    /// The round for one entry by id. Nested `#require` is a macro-expansion
    /// error, so the two lookups are folded here rather than at each call site.
    private func round(entryID: String) -> WhatsThat.Round? {
        db.entry(id: entryID).flatMap { WhatsThat.round(for: $0, in: db) }
    }

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private static let fixedDay = Date(timeIntervalSince1970: 1_760_000_000)

    // MARK: - The two properties

    /// **Every clue must be true of the answer.** A clue is generated from the
    /// entry and checked back against it through the *same* predicate the
    /// candidate filter uses, so a generator and a filter that disagree — the
    /// way to make a round unwinnable without making it look broken — fails
    /// here rather than in someone's hands.
    @Test("every clue is true of its own answer")
    func cluesAreTrue() throws {
        for cursor in sampleCursors {
            let round = try #require(self.round(cursor), "cursor \(cursor) dealt nothing")
            let answer = try #require(db.entry(id: round.answerID))
            for clue in round.clues {
                #expect(
                    WhatsThat.entry(answer, satisfies: clue, in: db),
                    "\(round.answerName): '\(clue.text)' is not true of it"
                )
            }
        }
    }

    /// **The spec's property.** No other entry in the catalog is consistent with
    /// the full set, so the round can always be argued to its answer.
    @Test("a dealt round is always solvable on its full clue set")
    func roundsAreSolvable() throws {
        for cursor in sampleCursors {
            let round = try #require(self.round(cursor))
            let candidates = WhatsThat.candidates(for: round.clues, in: db)
            #expect(
                candidates.map(\.id) == [round.answerID],
                """
                \(round.answerName) is not singled out by its clues — also fits \
                \(candidates.map(\.name).filter { $0 != round.answerName })
                """
            )
        }
    }

    /// And the round refuses to exist rather than existing unsolvable. The only
    /// two outcomes of `round(for:)` are a solvable round and nil.
    ///
    /// The coverage figure is pinned as a floor alongside it, because "refuse
    /// everything" would pass the first assertion perfectly. The greedy
    /// selection in `round(for:)` — extras taken from the specific end — is what
    /// carries this; taking them in reveal order instead drops it far enough
    /// that Cabernet Sauvignon is undealable.
    @Test("an entry that cannot be singled out deals no round at all")
    func unsolvableEntriesAreRefused() {
        let pool = db.entries(in: .grapes) + db.entries(in: .regions)
        var dealt = 0
        for entry in pool {
            guard let round = WhatsThat.round(for: entry, in: db) else { continue }
            dealt += 1
            #expect(WhatsThat.isSolvable(round, in: db), "\(entry.name) dealt an unwinnable round")
        }
        #expect(
            Double(dealt) / Double(pool.count) > 0.85,
            "only \(dealt) of \(pool.count) entries can be played — the clue kinds are too coarse"
        )
    }

    // MARK: - Shape

    @Test("clue counts stay inside the authored range")
    func clueCountsAreBounded() throws {
        for cursor in sampleCursors {
            let round = try #require(self.round(cursor))
            #expect(round.clues.count >= WhatsThat.minClues)
            #expect(round.clues.count <= WhatsThat.maxClues)
            // One clue per kind: two flavours would be one fact said twice.
            #expect(Set(round.clues.map(\.kind)).count == round.clues.count)
            #expect(round.clues.allSatisfy { !$0.text.isEmpty })
        }
    }

    /// **Vague to specific**, which is the game. `Kind.allCases` order is the
    /// reveal order, so every round's chips must come out in it.
    @Test("clues are ordered vague to specific")
    func cluesAreOrdered() throws {
        let rank = Dictionary(
            uniqueKeysWithValues: WhatsThat.Clue.Kind.allCases.enumerated().map { ($1, $0) }
        )
        for cursor in sampleCursors {
            let round = try #require(self.round(cursor))
            let ranks = round.clues.compactMap { rank[$0.kind] }
            #expect(ranks == ranks.sorted(), "\(round.answerName): clues are out of order")
            // The first chip is always the broadest fact there is.
            #expect(round.clues.first?.kind == .category)
        }
    }

    /// The last chip should be worth having. Not a hard rule about *which* kind
    /// it is — that depends on what the entry can support — but the set must
    /// narrow: each clue in order must cut the candidate pool or be the one that
    /// finishes it.
    @Test("each clue narrows the field")
    func cluesNarrow() throws {
        for cursor in sampleCursors.prefix(40) {
            let round = try #require(self.round(cursor))
            var previous = WhatsThat.candidates(for: [], in: db).count
            for prefix in 1...round.clues.count {
                let count = WhatsThat.candidates(for: Array(round.clues.prefix(prefix)), in: db).count
                #expect(count <= previous, "\(round.answerName): clue \(prefix) widened the field")
                #expect(count >= 1, "\(round.answerName): clue \(prefix) excluded the answer")
                previous = count
            }
            #expect(previous == 1)
        }
    }

    /// The hidden entry is a grape **or** a region — the tile's name never
    /// promised grapes, and the catalog holds 177 and 124 of them.
    @Test("the shuffle deals both categories")
    func bothCategoriesAreDealt() throws {
        var seen: Set<EntryCategory> = []
        for cursor in sampleCursors {
            let round = try #require(self.round(cursor))
            let answer = try #require(db.entry(id: round.answerID))
            seen.insert(answer.category)
        }
        #expect(seen == [.grapes, .regions], "got \(seen)")
    }

    /// One round per open, and the same cursor always deals the same hand — the
    /// contract `ScreenStateStore` relies on when it restores a round after the
    /// player has been off reading an entry.
    @Test("a cursor deals a stable round")
    func roundsAreDeterministic() throws {
        let a = try #require(round(9))
        let b = try #require(round(9))
        #expect(a == b)
        #expect(try #require(round(10)).answerID != a.answerID)
    }

    // MARK: - Scoring

    /// Fewer chips revealed, higher score. The curve is a fraction of the
    /// round's own length so a five-clue round and a six-clue round pay the same
    /// for the same *proportion* of the way through.
    @Test("score falls as the clues come out")
    func scoreFallsWithReveals() throws {
        let round = try #require(self.round(3))
        var last = Int.max
        for revealed in 1...round.clues.count {
            let score = round.score(revealed: revealed)
            #expect(score < last, "score did not fall at \(revealed)")
            #expect(score >= 20)
            #expect(score <= 100)
            last = score
        }
        #expect(round.score(revealed: 1) == 100)
        // Out of range clamps rather than going negative or over 100.
        #expect(round.score(revealed: 0) == 100)
        #expect(round.score(revealed: 99) == round.score(revealed: round.clues.count))
    }

    @Test("two rounds of different lengths pay the same at the same point")
    func scoreIsProportional() {
        let five = WhatsThat.Round(answerID: "X", answerName: "X", clues: Self.blankClues(5))
        let six = WhatsThat.Round(answerID: "Y", answerName: "Y", clues: Self.blankClues(6))
        #expect(five.score(revealed: 1) == six.score(revealed: 1))
        #expect(five.score(revealed: 5) == six.score(revealed: 6))
    }

    private static func blankClues(_ n: Int) -> [WhatsThat.Clue] {
        WhatsThat.Clue.Kind.allCases.prefix(n).map {
            WhatsThat.Clue(kind: $0, value: $0.rawValue, text: $0.rawValue)
        }
    }

    // MARK: - Judging, through the label matcher

    /// **The reuse, asserted rather than assumed.** Everything below is
    /// behaviour `LabelRecognitionService` already has and this file does not
    /// reimplement: accents, case, synonyms, near misses.
    @Test("a guess is matched by the label reader's own matcher")
    func judgeUsesTheLabelMatcher() throws {
        let cab = try #require(round(entryID: "G001"))
        #expect(WhatsThat.judge("Cabernet Sauvignon", in: cab) == .correct)
        #expect(WhatsThat.judge("cabernet sauvignon", in: cab) == .correct)
        // One transposed character, inside the length-scaled tolerance.
        #expect(WhatsThat.judge("cabernet sauvignoon", in: cab) == .correct)
    }

    @Test("a synonym counts, because the matcher indexes synonyms")
    func judgeAcceptsSynonyms() throws {
        let chenin = try #require(db.entry(named: "Chenin Blanc", category: .grapes))
        let round = try #require(WhatsThat.round(for: chenin, in: db))
        // Chenin Blanc's South African name, straight out of `details.synonyms`.
        #expect(WhatsThat.judge("Steen", in: round) == .correct)
    }

    @Test("naming something else says what it was")
    func judgeNamesTheWrongAnswer() throws {
        let cab = try #require(round(entryID: "G001"))
        #expect(WhatsThat.judge("Merlot", in: cab) == .wrong(named: "Merlot"))
    }

    @Test("nonsense is unrecognized rather than wrong")
    func judgeRejectsNonsense() throws {
        let cab = try #require(round(entryID: "G001"))
        #expect(WhatsThat.judge("zzqqxxvv", in: cab) == .unrecognized)
        #expect(WhatsThat.judge("   ", in: cab) == .unrecognized)
        #expect(WhatsThat.judge("", in: cab) == .unrecognized)
    }

    /// **The restriction that makes judging correct.** A reading walks the
    /// catalog, so naming a region produces that region's notable grapes and
    /// naming an appellation produces an inferred country. Counting either would
    /// let a player win a grape round by naming a region that grows it, which is
    /// a guess *near* the answer rather than at it.
    @Test("an inferred entry is not a correct guess")
    func judgeIgnoresInference() throws {
        // Nebbiolo is Piedmont's leading grape, so reading "PIEDMONT" infers it.
        let nebbiolo = try #require(db.entry(named: "Nebbiolo", category: .grapes))
        let round = try #require(WhatsThat.round(for: nebbiolo, in: db))
        let verdict = WhatsThat.judge("Piedmont", in: round)
        #expect(verdict != .correct, "a region that grows it is not the grape")
        #expect(verdict == .wrong(named: "Piedmont"))
    }

    /// A region round is won by naming the region, and — deliberately — by
    /// naming one of its appellations, because the matcher resolves an
    /// appellation to its owning region and that is a better guess than a miss.
    @Test("a region round accepts the region and its appellations")
    func judgeAcceptsAppellations() throws {
        let piedmont = try #require(round(entryID: "R022"))
        #expect(WhatsThat.judge("Piedmont", in: piedmont) == .correct)
        #expect(WhatsThat.judge("Barolo", in: piedmont) == .correct)
    }

    // MARK: - Round trip

    /// `ScreenStateStore` holds the round while the screen is torn down; opening
    /// the answer's entry and pressing Back must not deal a new hand.
    @Test("a round survives a JSON round trip")
    func roundIsCodable() throws {
        let original = try #require(round(4))
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(WhatsThat.Round.self, from: data) == original)
    }
}
