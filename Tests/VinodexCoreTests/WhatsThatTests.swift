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

    /// **Every clue costs something, and buying the round bottoms it out**
    /// (0.8.8, E2).
    ///
    /// Walked over every round the dealer produces rather than one sampled
    /// entry, and that is deliberate: the score is now a function of *which*
    /// clues were bought, so a single round only ever exercises one weight
    /// combination. What breaks in a weighted model is a branch — one kind whose
    /// weight is wrong or zero — and the branch is only visible across the set.
    @Test("score falls with every clue, and the floor is the whole round")
    func scoreFallsWithEveryClue() throws {
        for cursor in 0..<60 {
            let round = try #require(self.round(cursor))
            var revealed: Set<WhatsThat.Clue.Kind> = []
            #expect(round.score(revealed: revealed) == 100)

            // In the round's own order, then in reverse — a weighted score must
            // not depend on the order the same set was bought in.
            for clue in round.purchasable {
                let before = round.score(revealed: revealed)
                revealed.insert(clue.kind)
                let after = round.score(revealed: revealed)
                #expect(after < before, "\(clue.kind) cost nothing in round \(cursor)")
                #expect(after >= WhatsThat.scoreFloor)
            }
            #expect(round.score(revealed: revealed) == WhatsThat.scoreFloor)

            let reversed = Set(round.purchasable.reversed().map(\.kind))
            #expect(round.score(revealed: reversed) == WhatsThat.scoreFloor)
            // A kind this round does not hold cannot be spent.
            #expect(
                round.score(revealed: [.appellation, .grape, .region, .style])
                    == round.score(
                        revealed: Set(round.purchasable.map(\.kind))
                            .intersection([.appellation, .grape, .region, .style])
                    )
            )
        }
    }

    /// The advertised price is exactly what pressing the chip takes off.
    @Test("a clue's price is the score it removes")
    func priceMatchesTheDrop() throws {
        for cursor in 0..<40 {
            let round = try #require(self.round(cursor))
            var revealed: Set<WhatsThat.Clue.Kind> = []
            for clue in round.purchasable {
                let quoted = round.price(of: clue, revealed: revealed)
                let before = round.score(revealed: revealed)
                revealed.insert(clue.kind)
                #expect(before - round.score(revealed: revealed) == quoted)
                #expect(quoted > 0, "\(clue.kind) is free")
            }
        }
    }

    /// A specific clue costs more than a vague one, which is the decision E2
    /// adds — without it, choosing which chip to buy collapses to "the most
    /// specific one, always".
    @Test("giving more away costs more")
    func weightsRankTheKinds() {
        #expect(WhatsThat.Clue.Kind.category.weight == 0)
        #expect(WhatsThat.Clue.Kind.appellation.weight > WhatsThat.Clue.Kind.color.weight)
        #expect(WhatsThat.Clue.Kind.grape.weight > WhatsThat.Clue.Kind.country.weight)
        #expect(WhatsThat.Clue.Kind.region.weight > WhatsThat.Clue.Kind.rarity.weight)
        // Only the opener is free. Anything else at zero would be a chip that
        // costs nothing and so is never a decision.
        for kind in WhatsThat.Clue.Kind.allCases where kind != .category {
            #expect(kind.weight > 0, "\(kind) is free")
        }
    }

    @Test("two rounds of different lengths pay the same at the same point")
    func scoreIsProportional() {
        let five = WhatsThat.Round(answerID: "X", answerName: "X", clues: Self.blankClues(5))
        let six = WhatsThat.Round(answerID: "Y", answerName: "Y", clues: Self.blankClues(6))
        #expect(five.score(revealed: []) == six.score(revealed: []))
        // Buying the whole of either lands on the floor — the property that
        // stops the game rewarding a short draw.
        #expect(five.score(revealed: Set(five.purchasable.map(\.kind))) == WhatsThat.scoreFloor)
        #expect(six.score(revealed: Set(six.purchasable.map(\.kind))) == WhatsThat.scoreFloor)
    }

    // MARK: - Playing (0.8.8, E1/E2)

    /// **A wrong name costs a clue; nonsense does not.** The economy E1 adds,
    /// and the reason the game had a dominant strategy before it: guessing was
    /// free, so the optimal play was to type every name you knew before ever
    /// spending a point.
    @Test("a named wrong guess turns over the cheapest clue left")
    func wrongGuessesCost() throws {
        let round = try #require(self.round(5))
        var play = WhatsThat.Play(round: round)
        #expect(play.revealed.count == 1)
        #expect(play.revealed.first == .category)
        #expect(play.round.score(revealed: play.revealedKinds) == 100)

        let expected = try #require(play.forfeit)
        // The cheapest of what is left, not the next in order.
        for clue in play.hidden {
            #expect(play.price(of: expected) <= play.price(of: clue))
        }

        let taken = play.record(.wrong(named: "Merlot"))
        #expect(taken?.id == expected.id)
        #expect(play.revealedKinds.contains(expected.kind))
        #expect(play.wrongGuesses == 1)
        #expect(!play.isOver)

        // Nothing in the dex by that name is a typo, not a wrong answer.
        let before = play.revealedKinds
        #expect(play.record(.unrecognized) == nil)
        #expect(play.revealedKinds == before)
        #expect(play.wrongGuesses == 1)
    }

    /// The losing condition the game did not have.
    @Test("wrong with nothing left to turn over ends the round")
    func runningOutIsALoss() throws {
        let round = try #require(self.round(7))
        var play = WhatsThat.Play(round: round)
        while play.forfeit != nil { play.record(.wrong(named: "Merlot")) }
        #expect(!play.isOver, "the round ended before the clues ran out")
        #expect(play.hidden.isEmpty)

        play.record(.wrong(named: "Merlot"))
        #expect(play.outcome == .lost)
        #expect(play.score == 0)
        // A finished round absorbs nothing further.
        let settled = play
        play.record(.correct)
        play.reveal(.appellation)
        play.giveUp()
        #expect(play == settled)
    }

    @Test("solving banks the score the chips said it would")
    func solvingPaysTheQuotedScore() throws {
        let round = try #require(self.round(11))
        var play = WhatsThat.Play(round: round)
        let bought = try #require(play.hidden.first)
        let quoted = play.price(of: bought)
        play.reveal(bought.kind)
        play.record(.correct)
        #expect(play.outcome == .solved)
        #expect(play.score == 100 - quoted)
    }

    @Test("a round survives being put down and picked up")
    func playIsCodable() throws {
        let round = try #require(self.round(13))
        var play = WhatsThat.Play(round: round)
        play.record(.wrong(named: "Merlot"))
        play.reveal(try #require(play.hidden.last).kind)
        let data = try JSONEncoder().encode(play)
        #expect(try JSONDecoder().decode(WhatsThat.Play.self, from: data) == play)
    }

    // MARK: - The record (0.8.8, E3)

    @Test("the record counts a round once, and only a solve pays")
    func recordFolds() throws {
        let round = try #require(self.round(17))
        var record = WhatsThatRecord.empty
        #expect(record.isEmpty)

        // In progress — nothing to count yet.
        var live = WhatsThat.Play(round: round)
        record.record(live)
        #expect(record.played == 0)

        live.record(.correct)
        record.record(live)
        #expect(record.played == 1)
        #expect(record.solved == 1)
        #expect(record.streak == 1)
        #expect(record.bestStreak == 1)
        #expect(record.bestScore == 100)
        #expect(record.averageScore == 100)
        #expect(record.solveRate == 100)

        var lost = WhatsThat.Play(round: round)
        lost.giveUp()
        record.record(lost)
        #expect(record.played == 2)
        #expect(record.solved == 1)
        // The run breaks; the best it reached does not.
        #expect(record.streak == 0)
        #expect(record.bestStreak == 1)
        #expect(record.bestScore == 100)
        #expect(record.solveRate == 50)
    }

    /// The migration hazard, checked from the direction it actually arrives:
    /// a blob written before a field existed must still decode.
    @Test("a record saved before a field existed still decodes")
    func recordDecodesLeniently() throws {
        let partial = Data(#"{"played":4,"solved":3}"#.utf8)
        let record = try JSONDecoder().decode(WhatsThatRecord.self, from: partial)
        #expect(record.played == 4)
        #expect(record.solved == 3)
        #expect(record.bestStreak == 0)

        // A present-but-wrong value loses the field, not the record.
        let corrupt = Data(#"{"played":4,"bestScore":"lots"}"#.utf8)
        #expect(try JSONDecoder().decode(WhatsThatRecord.self, from: corrupt).played == 4)
        #expect(try JSONDecoder().decode(WhatsThatRecord.self, from: corrupt).bestScore == 0)
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

    // MARK: - Type-ahead (0.8.0, E2)

    /// Every id in the catalog, as the worst case a caller could ever hand in.
    private var wholeCatalog: [String] {
        EntryCategory.allCases.flatMap { db.entries(in: $0).map(\.id) }
    }

    /// **The property E2 exists to protect: the field is not a menu.**
    ///
    /// One character must return nothing even when the caller passes the entire
    /// catalog as "discovered" — which is the strongest form of the check,
    /// because it fails on the gate rather than on the pool happening to be
    /// small. A player who types `N` and reads a list has been handed the round.
    @Test("a single character never enumerates anything")
    func oneLetterSuggestsNothing() {
        for letter in ["a", "n", "c", "z", " ", "é"] {
            #expect(
                WhatsThat.suggestions(for: letter, among: wholeCatalog, in: db).isEmpty,
                "\(letter) produced suggestions"
            )
        }
        #expect(WhatsThat.suggestions(for: "", among: wholeCatalog, in: db).isEmpty)
    }

    /// **The pool is the decision, so the pool is what is pinned.** A name the
    /// player has never met is not offered no matter how well it matches — this
    /// is the whole of E2-a, and without it the type-ahead undoes `judge`'s
    /// non-inferred rule by autocompletion.
    @Test("nothing outside the discovered pool is ever suggested")
    func onlyDiscoveredNames() throws {
        let nebbiolo = try #require(db.entry(named: "Nebbiolo"))
        #expect(WhatsThat.suggestions(for: "NEBB", among: [], in: db).isEmpty)
        #expect(
            WhatsThat.suggestions(for: "NEBB", among: [nebbiolo.id], in: db) == ["Nebbiolo"],
            "a discovered name should complete"
        )
        // And a discovered *other* entry does not answer for it.
        let merlot = try #require(db.entry(named: "Merlot"))
        #expect(WhatsThat.suggestions(for: "NEBB", among: [merlot.id], in: db).isEmpty)
    }

    /// Only the two categories a round can be about. A flavour or a style
    /// completing in this field is noise in a round it cannot win.
    @Test("suggestions are grapes and regions only")
    func suggestionsAreGuessable() {
        let names = WhatsThat.suggestions(
            for: "a", among: wholeCatalog, in: db, limit: 500
        )
        #expect(names.isEmpty, "one character is still the floor")

        let all = WhatsThat.suggestions(for: "ri", among: wholeCatalog, in: db, limit: 500)
        for name in all {
            let entry = db.entry(named: name)
            #expect(
                entry?.category == .grapes || entry?.category == .regions,
                "\(name) is a \(entry?.category.rawValue ?? "nothing")"
            )
        }
    }

    /// The list is short by contract, not by luck: a two-character query over the
    /// whole catalog is the case that would otherwise print an index.
    @Test("the list is capped and prefixes lead")
    func listIsCappedAndOrdered() throws {
        let names = WhatsThat.suggestions(for: "ri", among: wholeCatalog, in: db)
        #expect(names.count <= WhatsThat.suggestionLimit)
        // Everything that starts with the query comes before anything that merely
        // contains it, so the row's first chip is the likeliest completion.
        let starts = names.map { TextNormalize.label($0).hasPrefix("ri") }
        #expect(starts == starts.sorted(by: { $0 && !$1 }), "prefix matches must lead: \(names)")
    }

    /// **The answer is not filtered out, and that is deliberate** — see
    /// `suggestions`. Withholding it would tell a player who had met it, and
    /// typed most of it, exactly which entry was being withheld.
    @Test("the round's own answer is not specially excluded")
    func answerIsNotAnOracle() throws {
        let hand = try #require(round(0))
        let answer = try #require(db.entry(id: hand.answerID))
        let stem = String(TextNormalize.label(answer.name).prefix(4))
        #expect(
            WhatsThat.suggestions(for: stem, among: [answer.id], in: db).contains(answer.name),
            "\(answer.name) was withheld — silence is information"
        )
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
