import Foundation

/// The daily challenge's shareable result string (0.7.8, C1).
///
/// ```
/// 🍷 Vinodex 4/5 🟩🟩⬛🟩⬛  streak: 12
/// ```
///
/// ## Why this can exist at all
///
/// A Wordle-style result string needs three things underneath it, and all three
/// were confirmed in the shipped code before a line of this was written:
///
/// 1. **One paper, everyone, no backend.** `DailyChallenge.seed` is
///    `DailyPick.dayIndex(for:) &* 8093` and `TastingQuiz.question` takes only
///    a seed, a fixed `.enthusiast` tier and the shipped `WineDatabase`. No
///    account, no network, no user state — not even the player's unlocked tier,
///    which `DailyChallenge.tier` refuses on purpose.
/// 2. **A streak.** `StreakStore.current`, a true calendar streak of
///    consecutive passed days. Note it is *not* `ExamRecordStore.passStreak` —
///    that counts consecutive passed exam papers, saturates at
///    `historyLimit`, and is documented as deliberately not a calendar streak.
///    The passport prints `StreakStore`, so this prints `StreakStore`.
/// 3. **No retry.** `StreakStore.record` consumes the day on the first
///    sitting, win or lose, and the daily screen offers no RETRY — a retry
///    would be the identical paper with the answers in hand.
///
/// **The one caveat, recorded because the feature leans on it.** The paper is a
/// pure function of the day index *and the shipped catalog*. The catalog grows
/// every data batch, so two players on different app versions can hold
/// different papers on the same date, and their strings are then not
/// comparable. Nothing here can detect that, and it is why this string carries
/// no puzzle number: a number implying "we sat the same paper" would be the one
/// claim the build cannot honour.
///
/// ## Why it is spoiler-free
///
/// The string encodes **performance and nothing else**. Each tile is one
/// boolean out of `QuizSession.marks`: right or wrong. A reader holding the
/// same paper learns how many you got and in which positions, which tells them
/// nothing about *which of the four options* was correct anywhere.
///
/// That is the failure mode Wordle clones actually hit, and it is worth naming
/// what would have caused it here. `QuizQuestion.id` is
/// `kind.rawValue + ":" + answerID` — the answer is inside the identifier — and
/// `prompt` names the subject outright. Encoding a question id, a prompt, a
/// topic or the option the player tapped would each leak: a wrong marker beside
/// a chosen option eliminates that option for every reader. So none of them
/// appear, and `resultStringLeaksNoAnswer` checks the rendered string against
/// every answer name and every option name on the day's paper rather than
/// trusting this paragraph.
///
/// ## Two tiles, not three
///
/// The brief illustrates the grid as `🟩🟩🟨🟩⬛`, borrowing Wordle's three
/// states. The daily paper has no third state to encode: `QuizQuestion`
/// is four options and one `answerID`, `QuizSession.choose` takes the first tap
/// and cannot be changed, and `isCorrect` returns a `Bool`. There is no partial
/// credit and no second guess anywhere in the type. A yellow tile would have to
/// mean something invented, and a share string whose middle state is decorative
/// is a share string that lies about the game. So: green right, black wrong.
public enum DailyResult {
    /// Right.
    public static let hit: Character = "🟩"
    /// Wrong.
    public static let miss: Character = "⬛"
    /// Leads the string so the product is named even when the line is quoted
    /// out of context. `AppVersion` is deliberately absent — a version number
    /// on a social string dates it for no reader benefit.
    public static let banner = "🍷 Vinodex"

    /// What a finished daily paper is willing to say about itself.
    ///
    /// Foundation-only and `Equatable` so the encoding is testable on Linux,
    /// which is the whole reason it is not assembled inside the share sheet.
    public struct Card: Sendable, Equatable {
        /// Questions answered correctly.
        public let correct: Int
        /// Questions on the paper.
        public let length: Int
        /// Whether the paper passed its mark.
        public let passed: Bool
        /// Right/wrong per question, oldest first. Empty when the session was
        /// restored from a pre-0.7.8 blob that never recorded them — the score
        /// still prints, the grid is simply left off rather than guessed at.
        public let marks: [Bool]
        /// `StreakStore.current` — consecutive passed days.
        public let streak: Int

        public init(correct: Int, length: Int, passed: Bool, marks: [Bool], streak: Int) {
            self.correct = correct
            self.length = length
            self.passed = passed
            self.marks = marks
            self.streak = streak
        }

        /// Whether a full grid can be drawn. A partial record is not padded:
        /// an invented tile is a wrong tile.
        public var hasGrid: Bool { marks.count == length && length > 0 }

        /// The tile row, or empty when there is no complete record.
        public var grid: String {
            guard hasGrid else { return "" }
            return String(marks.map { $0 ? DailyResult.hit : DailyResult.miss })
        }
    }

    /// The card for a completed session. Returns nil for a paper still in
    /// progress — there is no result to share until there is a result.
    public static func card(for session: QuizSession, streak: Int) -> Card? {
        guard session.isComplete else { return nil }
        return Card(
            correct: session.correct,
            length: session.length,
            passed: session.passed,
            marks: session.marks,
            streak: streak
        )
    }

    /// The shareable line.
    ///
    /// The score always prints as `correct/length` rather than Wordle's `X/6`
    /// for a failure: 3/5 is a fail here and is also a more informative thing
    /// to have written down than an X. The streak segment is omitted at zero —
    /// a broken streak is not a statistic anybody shares, and printing
    /// `streak: 0` turns the feature into a small public humiliation.
    public static func string(for card: Card) -> String {
        var line = "\(banner) \(card.correct)/\(card.length)"
        let grid = card.grid
        if !grid.isEmpty { line += " \(grid)" }
        if card.streak > 0 { line += "  streak: \(card.streak)" }
        return line
    }

    /// Convenience: session straight to string, nil while unfinished.
    public static func string(for session: QuizSession, streak: Int) -> String? {
        card(for: session, streak: streak).map(string(for:))
    }
}
