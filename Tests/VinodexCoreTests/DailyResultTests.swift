import Testing
import Foundation
@testable import VinodexCore

@Suite("Daily result string")
struct DailyResultTests {
    let db = WineDatabase.shared

    /// A fixed calendar, the same convention as `DailyChallengeTests`.
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "GMT")!
        return calendar
    }

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: iso)!
    }

    /// Sits a session against the real generator, answering each question
    /// according to `script` — true answers correctly, false picks any other
    /// option. Returns the finished session.
    private func sit(_ session: QuizSession, script: [Bool]) -> QuizSession {
        var run = session
        for number in 0..<run.length {
            guard let question = TastingQuiz.question(
                number: number, sessionSeed: run.seed, tier: run.tier, in: db
            ) else { continue }
            let wanted = script[number]
            let pick = wanted
                ? question.answerID
                : (question.optionIDs.first { $0 != question.answerID } ?? question.answerID)
            run.choose(pick, in: question)
            run.advance()
        }
        return run
    }

    // MARK: The encoding

    @Test("the string is banner, score, grid and streak")
    func shape() {
        let card = DailyResult.Card(
            correct: 4, length: 5, passed: true,
            marks: [true, true, false, true, false], streak: 12
        )
        #expect(DailyResult.string(for: card) == "🍷 Vinodex 4/5 🟩🟩⬛🟩⬛  streak: 12")
    }

    @Test("a broken streak is left off rather than printed as zero")
    func zeroStreakOmitted() {
        let card = DailyResult.Card(
            correct: 2, length: 5, passed: false,
            marks: [true, false, true, false, false], streak: 0
        )
        let line = DailyResult.string(for: card)
        #expect(line == "🍷 Vinodex 2/5 🟩⬛🟩⬛⬛")
        #expect(!line.contains("streak"))
    }

    @Test("a failed paper prints its real score, not an X")
    func failurePrintsScore() {
        let card = DailyResult.Card(
            correct: 3, length: 5, passed: false, marks: [true, true, true, false, false], streak: 4
        )
        #expect(DailyResult.string(for: card).contains("3/5"))
        #expect(!DailyResult.string(for: card).contains("X/"))
    }

    @Test("an incomplete record drops the grid instead of padding it")
    func partialRecordHasNoGrid() {
        // What a paper half-sat across the 0.7.8 upgrade decodes to.
        let card = DailyResult.Card(correct: 2, length: 5, passed: false, marks: [true, true], streak: 3)
        #expect(!card.hasGrid)
        #expect(card.grid.isEmpty)
        let line = DailyResult.string(for: card)
        #expect(line == "🍷 Vinodex 2/5  streak: 3")
        #expect(!line.contains(String(DailyResult.hit)))
    }

    @Test("there is no card until the paper is finished")
    func noCardWhileInProgress() {
        let session = DailyChallenge.session(for: date("2026-08-05"), calendar: utc)
        #expect(DailyResult.card(for: session, streak: 3) == nil)
        #expect(DailyResult.string(for: session, streak: 3) == nil)
    }

    // MARK: The session record

    @Test("marks record each answer and agree with the correct count")
    func marksAgreeWithCount() {
        let script = [true, false, true, true, false]
        let run = sit(DailyChallenge.session(for: date("2026-08-05"), calendar: utc), script: script)
        #expect(run.isComplete)
        #expect(run.marks == script)
        #expect(run.marks.filter { $0 }.count == run.correct)
    }

    @Test("a pre-0.7.8 session decodes rather than being thrown away")
    func decodesWithoutMarks() throws {
        // The blob shape `ScreenStateStore` persisted before `marks` existed.
        let legacy = """
        {"seed":42,"length":5,"passMark":4,"tier":"ENTHUSIAST","index":2,"correct":2}
        """
        let session = try JSONDecoder().decode(QuizSession.self, from: Data(legacy.utf8))
        #expect(session.seed == 42)
        #expect(session.correct == 2)
        #expect(session.marks.isEmpty)
    }

    @Test("a session round-trips its marks")
    func marksRoundTrip() throws {
        let run = sit(DailyChallenge.session(for: date("2026-08-05"), calendar: utc), script: [true, true, false, true, true])
        let data = try JSONEncoder().encode(run)
        let back = try JSONDecoder().decode(QuizSession.self, from: data)
        #expect(back.marks == run.marks)
    }

    // MARK: Spoiler safety — the falsifier

    /// The property the whole feature rests on: a reader holding the same paper
    /// must learn nothing about the answers. Checked against the real generated
    /// paper rather than asserted in a comment.
    @Test("the result string names nothing on the paper")
    func resultStringLeaksNoAnswer() {
        for day in ["2026-08-05", "2026-08-06", "2026-08-07", "2026-11-19"] {
            let session = DailyChallenge.session(for: date(day), calendar: utc)
            let run = sit(session, script: [true, false, true, true, false])
            guard let line = DailyResult.string(for: run, streak: 12) else {
                Issue.record("no string for a completed paper on \(day)")
                continue
            }
            let haystack = line.lowercased()

            for number in 0..<session.length {
                guard let question = TastingQuiz.question(
                    number: number, sessionSeed: session.seed, tier: session.tier, in: db
                ) else { continue }

                // Neither the prompt nor the question's identity — the id is
                // `kind:answerID`, so it carries the answer literally.
                #expect(!haystack.contains(question.answerID.lowercased()))
                #expect(!haystack.contains(question.id.lowercased()))
                #expect(!haystack.contains(question.kind.rawValue.lowercased()))

                // Nor any option's display name, right or wrong: naming the
                // wrong ones eliminates them just as usefully.
                for id in question.optionIDs {
                    guard let entry = db.entry(id: id) else { continue }
                    let name = entry.name.lowercased()
                    guard name.count >= 3 else { continue }
                    #expect(!haystack.contains(name), "\(day) leaked \(entry.name)")
                    #expect(!haystack.contains(id.lowercased()))
                }
            }
        }
    }

    @Test("the string is built from a closed character set")
    func closedCharacterSet() {
        let run = sit(DailyChallenge.session(for: date("2026-08-05"), calendar: utc), script: [true, true, true, true, false])
        let line = DailyResult.string(for: run, streak: 9) ?? ""
        // Everything the format is allowed to emit, assembled from the format's
        // own pieces rather than typed out — a hand-written allowlist is one
        // typo away from either failing or, worse, quietly permitting.
        let allowed = Set(
            DailyResult.banner + "0123456789/ streak:"
                + String(DailyResult.hit) + String(DailyResult.miss)
        )
        let stray = Set(line).subtracting(allowed)
        #expect(stray.isEmpty, "unexpected characters: \(stray)")
    }
}
