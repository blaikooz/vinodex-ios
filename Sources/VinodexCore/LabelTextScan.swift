import Foundation

/// The string work behind the label reader (0.7.2, LR1): normalisation, n-gram
/// generation, edit distance, vintage detection and the producer heuristic.
///
/// Separate from `LabelRecognitionService` because none of it knows what a wine
/// is — it is the layer that turns a photograph's worth of text into candidate
/// phrases, and it is the layer with the most edge cases, so it is the layer
/// worth testing on its own.
///
/// **Normalisation is `TextNormalize.key` and nothing else.** That is the same
/// function `WineDatabase` folds every entry name and synonym through at load,
/// which is what makes a label n-gram and a catalog key comparable at all. A
/// second normaliser here — even a slightly better one — would silently stop
/// agreeing with the index it is being compared against, which is the whole
/// class of bug the reuse rule exists to prevent.
public enum LabelTextScan {

    // MARK: - Phrases

    /// The longest phrase the matcher will consider, in words.
    ///
    /// Four covers everything the catalog actually holds — `Châteauneuf-du-Pape`
    /// is one word after normalisation, `Vosne-Romanée` likewise, and the
    /// longest real multi-word names (`Melon de Bourgogne`, `Montagne de Reims`,
    /// `Denominación de Origen Calificada`) top out at four. Five would double
    /// the candidate count for nothing.
    public static let maxPhraseWords = 4

    /// A phrase lifted from one recognised line, with where it came from.
    ///
    /// The line index is what lets the producer heuristic exclude text the
    /// database has already claimed: a line reading `BAROLO` is an appellation,
    /// not an estate, and it should not also be offered as the producer.
    public struct Phrase: Sendable, Hashable {
        /// `TextNormalize.key` output — the comparable form.
        public let key: String
        /// The words as they appeared, for showing the user what was read.
        public let text: String
        /// Index into the `[RecognizedString]` this came from.
        public let line: Int
        public let words: Int

        public init(key: String, text: String, line: Int, words: Int) {
            self.key = key
            self.text = text
            self.line = line
            self.words = words
        }
    }

    /// Every 1…`maxPhraseWords`-word window of every recognised line, longest
    /// first.
    ///
    /// Longest-first is load-bearing: `Cabernet Sauvignon` and `Cabernet` are
    /// both real grapes in the catalog, and a label saying the former must not
    /// resolve to the latter because a shorter window happened to be tested
    /// first. The matcher takes the first hit per field and stops.
    ///
    /// Duplicate keys are dropped, keeping the first (and therefore longest,
    /// earliest) occurrence — a label repeating its region on the neck and the
    /// body should not produce two candidates.
    public static func phrases(in strings: [RecognizedString]) -> [Phrase] {
        var out: [Phrase] = []
        var seen = Set<String>()

        for size in stride(from: maxPhraseWords, through: 1, by: -1) {
            for (line, recognized) in strings.enumerated() {
                let words = TextNormalize.key(recognized.text)
                    .split(separator: " ", omittingEmptySubsequences: true)
                    .map(String.init)
                guard words.count >= size else { continue }

                // The raw words, aligned with the folded ones so `text` can show
                // what the camera saw rather than the folded key. Splitting the
                // raw string on whitespace can disagree with the folded split
                // when punctuation is involved (`Saint-Émilion` folds to two
                // words), so the raw form is only used when the counts line up.
                let raw = recognized.text
                    .split(whereSeparator: { $0.isWhitespace })
                    .map(String.init)
                let alignable = raw.count == words.count

                for start in 0...(words.count - size) {
                    let slice = words[start..<(start + size)]
                    let key = slice.joined(separator: " ")
                    guard !seen.contains(key) else { continue }
                    seen.insert(key)
                    let text = alignable
                        ? raw[start..<(start + size)].joined(separator: " ")
                        : key
                    out.append(Phrase(key: key, text: text, line: line, words: size))
                }
            }
        }
        return out
    }

    // MARK: - Fuzzy matching

    /// How many single-character edits a phrase of this length may be off by.
    ///
    /// OCR errors are per-character and roughly proportional to the number of
    /// characters, so the tolerance is too. The zero for short strings is the
    /// important row: at four characters or fewer, one edit reaches a large
    /// share of the whole vocabulary — `Rosé`/`Rose`/`Rose`, `Port`/`Porto`,
    /// `Toro`/`Tokaj` — and a fuzzy match there is a coin toss wearing a number.
    public static func allowedDistance(forLength length: Int) -> Int {
        switch length {
        case ..<5: 0
        case 5..<9: 1
        case 9..<14: 2
        default: 3
        }
    }

    /// Levenshtein distance, bailing out once it exceeds `limit`.
    ///
    /// Two rows rather than a full matrix, and an early return on the length
    /// difference: the matcher runs this across every phrase against every
    /// candidate name in the catalog, so the cheap rejections have to be cheap.
    public static func editDistance(_ a: String, _ b: String, limit: Int) -> Int? {
        if a == b { return 0 }
        let x = Array(a.utf8)
        let y = Array(b.utf8)
        if abs(x.count - y.count) > limit { return nil }
        if x.isEmpty { return y.count <= limit ? y.count : nil }
        if y.isEmpty { return x.count <= limit ? x.count : nil }

        var previous = Array(0...y.count)
        var current = [Int](repeating: 0, count: y.count + 1)

        for i in 1...x.count {
            current[0] = i
            var rowBest = current[0]
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
                rowBest = min(rowBest, current[j])
            }
            // Every remaining row can only grow, so a whole row already past the
            // limit means the final cell will be too.
            if rowBest > limit { return nil }
            swap(&previous, &current)
        }
        let distance = previous[y.count]
        return distance <= limit ? distance : nil
    }

    // MARK: - Vintage

    /// The earliest year the reader will accept off a label.
    ///
    /// 1900 rather than something older on purpose. Pre-1900 vintages exist and
    /// are not what a camera pointed at a shelf is looking at, whereas four-digit
    /// numbers in the 1700s and 1800s are all over wine labels as *founding
    /// dates* — "EST. 1855", "DEPUIS 1789". Refusing them costs the reader
    /// nothing real and stops it announcing a museum piece.
    public static let earliestVintage = 1900

    /// The four-digit year on a label, if there is a plausible one.
    ///
    /// Scans the normalised token stream rather than the raw text so that
    /// `750ML`, `12,5%` and `N°2019` all tokenise the way a reader would expect,
    /// and takes the **most recent** plausible year when several qualify — a
    /// label carrying both a founding date and a vintage states the vintage
    /// second in time, and the newest number is reliably the one in the bottle.
    ///
    /// `now` is injectable so the test does not stop working next January.
    public static func vintage(in strings: [RecognizedString], now: Date = Date()) -> Int? {
        let year = Calendar(identifier: .gregorian).component(.year, from: now)
        // A wine can be on a shelf a few months before its nominal year in the
        // southern hemisphere and in sparkling disgorgement dates, so the
        // ceiling is next year rather than this one.
        let range = earliestVintage...(year + 1)

        var best: Int?
        for recognized in strings {
            for token in TextNormalize.key(recognized.text).split(separator: " ") {
                guard token.count == 4, token.allSatisfy(\.isNumber),
                      let value = Int(token), range.contains(value)
                else { continue }
                best = max(best ?? value, value)
            }
        }
        return best
    }

    // MARK: - Producer

    /// Words that introduce an estate on a wine label.
    ///
    /// **This is not wine knowledge the data provides** — the catalog has no
    /// producer entity of any kind (see `LabelField.producer`), so there is
    /// nothing here to walk instead. It is a list of the words that mean "the
    /// name beside me is a winery", in the languages the catalog's countries
    /// actually use, and it is the entire extent of the hardcoding: no producer
    /// *names* appear here, and none should.
    ///
    /// Stored folded, so the comparison is against `TextNormalize.key` output.
    public static let producerKeywords: Set<String> = [
        // French
        "domaine", "chateau", "clos", "mas", "maison", "cave", "caves", "cellier",
        "champagne", "vignoble", "vignobles",
        // Italian
        "tenuta", "cantina", "cantine", "azienda", "castello", "poderi", "podere",
        "fattoria", "villa",
        // Spanish / Portuguese
        "bodega", "bodegas", "quinta", "vina", "vinas", "herdade", "casa",
        // German / Austrian
        "weingut", "schloss", "weinhaus",
        // English
        "estate", "estates", "winery", "wines", "vineyard", "vineyards", "cellars",
    ]

    /// The best guess at a producer name, or nil.
    ///
    /// Two passes, in this order:
    ///
    /// 1. **A line containing an estate keyword.** `DOMAINE HUET` is a producer
    ///    because it says so; nothing else on a label does.
    /// 2. **The most prominent unclaimed line.** Failing a keyword, the largest
    ///    text that no other field matched is the producer far more often than
    ///    not — that is how bottles are designed. This is why `RecognizedString`
    ///    carries `prominence` at all.
    ///
    /// `claimedLines` are the lines other fields have already resolved, so a
    /// label whose biggest word is BAROLO does not also nominate BAROLO as the
    /// estate. Lines that are only a vintage or only a volume are filtered out
    /// by the digit test rather than by a list of them.
    public static func producerGuess(
        in strings: [RecognizedString],
        claimedLines: Set<Int>
    ) -> String? {
        let candidates = strings.enumerated()
            .filter { index, recognized in
                guard !claimedLines.contains(index) else { return false }
                let key = TextNormalize.key(recognized.text)
                guard key.count >= 3 else { return false }
                // Anything mostly numeric is an ABV, a volume or a year.
                return key.contains(where: \.isLetter)
                    && !key.allSatisfy { $0.isNumber || $0 == " " }
            }

        for (_, recognized) in candidates {
            let words = Set(TextNormalize.key(recognized.text).split(separator: " ").map(String.init))
            if !words.isDisjoint(with: producerKeywords) {
                return tidy(recognized.text)
            }
        }

        return candidates
            .max { $0.element.prominence < $1.element.prominence }
            .map { tidy($0.element.text) }
    }

    /// Collapses the whitespace and newlines OCR sprinkles through a line,
    /// without touching case or accents — this string is shown to the user as
    /// the producer's name, so it must stay the name.
    public static func tidy(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
