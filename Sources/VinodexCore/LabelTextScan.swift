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
    /// **Five since 0.7.9 (D-a), and the note it replaces was simply wrong.** It
    /// read: "Four covers everything the catalog actually holds … the longest
    /// real multi-word names top out at four. Five would double the candidate
    /// count for nothing." That was a claim about the data made in prose and
    /// never checked, and the data has moved four batches since. Folded, the
    /// catalog holds three five-word names — `Verdicchio dei Castelli di Jesi`
    /// (R064), `Muscat Blanc à Petits Grains` (G130) and `Malvasia Branca de São
    /// Jorge` (G175, arrived 0.7.9) — and every one of them was **unreachable**:
    /// no window this scan produced could ever equal the key, at any distance.
    ///
    /// So the number is derived from the catalog rather than asserted about it,
    /// and `LabelReaderTests.phraseWindowCoversTheLongestName` fails if a data
    /// batch adds a six-word name. That test is the point of this change as much
    /// as the fifth window is: the defect was not the 4, it was that nothing
    /// would have said when 4 stopped being enough.
    ///
    /// The old note's cost argument still holds and is still worth respecting —
    /// each extra window size is another pass over every line and, since D-a,
    /// over every line *break* — which is why this tracks the catalog rather
    /// than being set generously and forgotten.
    public static let maxPhraseWords = 5

    /// A phrase lifted from the recognised lines, with where it came from.
    ///
    /// The line indices are what let the producer heuristic exclude text the
    /// database has already claimed: a line reading `BAROLO` is an appellation,
    /// not an estate, and it should not also be offered as the producer.
    ///
    /// **`lines` is plural since 0.7.9 (D-a).** A phrase may now span a line
    /// break — see `phrases(in:)` — and when one does, *every* line it consumed
    /// has to be claimed. Claiming only the first would leave `DU-PAPE` on the
    /// table as a producer candidate after `CHATEAUNEUF DU-PAPE` matched.
    public struct Phrase: Sendable, Hashable {
        /// `TextNormalize.key` output — the comparable form.
        public let key: String
        /// The words as they appeared, for showing the user what was read.
        public let text: String
        /// Every `[RecognizedString]` index this drew words from, in order.
        /// One element for the overwhelming majority; two or three for a phrase
        /// set across a line break.
        public let lines: [Int]
        public let words: Int

        /// Where the phrase starts. The single-line accessor the matcher used
        /// before phrases could span lines, kept because "which line is this
        /// mostly on" is still the useful answer for ordering and reporting.
        public var line: Int { lines.first ?? 0 }

        /// True when the phrase was assembled across a line break, which is a
        /// weaker reading than the same words set on one line: type that runs
        /// on is one phrase, type that is broken *might* be two.
        public var isJoined: Bool { lines.count > 1 }

        public init(key: String, text: String, line: Int, words: Int) {
            self.init(key: key, text: text, lines: [line], words: words)
        }

        public init(key: String, text: String, lines: [Int], words: Int) {
            self.key = key
            self.text = text
            self.lines = lines
            self.words = words
        }
    }

    /// Every 1…`maxPhraseWords`-word window of every recognised line, longest
    /// first — **plus, since 0.7.9 (D-a), the windows that run across a line
    /// break.**
    ///
    /// Longest-first is load-bearing: `Cabernet Sauvignon` and `Cabernet` are
    /// both real grapes in the catalog, and a label saying the former must not
    /// resolve to the latter because a shorter window happened to be tested
    /// first. The matcher takes the first hit per field and stops.
    ///
    /// Duplicate keys are dropped, keeping the first (and therefore longest,
    /// earliest) occurrence — a label repeating its region on the neck and the
    /// body should not produce two candidates.
    ///
    /// **The line break is where the appellations were being lost.** OCR returns
    /// one string per line of *type*, and a long appellation is routinely set
    /// over two or three of them — `CHATEAUNEUF` above `DU-PAPE`,
    /// `VERDICCHIO DEI` above `CASTELLI DI JESI`. Windows drawn inside a single
    /// line can only ever see fragments of those, and a fragment is either
    /// nothing (`du pape`) or, worse, a real short name that is not the one on
    /// the bottle. On the 0.7.9 corpus this was every single miss: eight of
    /// twenty-four bottles, all multi-line appellations, all scoring 20 with no
    /// place at all.
    ///
    /// **The join is restricted to the shape type actually breaks in**: a
    /// *suffix* of one line joined to a *prefix* of the next, contiguous, within
    /// the same `maxPhraseWords` cap. It is not a general cross-product of the
    /// label's words, which would put `TELEGRAPHE 2019` and `MASI AMARONE` into
    /// the candidate pool and hand the fuzzy pass a much larger surface to be
    /// wrong on. A three-line join is allowed only when the middle line is
    /// consumed whole, since a break cannot skip over a line of type.
    ///
    /// Within each size, single-line windows are emitted **before** joined ones,
    /// so an unbroken reading always wins the de-duplication against a broken
    /// one of the same length. That also leaves single-line labels — which is
    /// most of `LabelReaderTests` — producing byte-identical output to 0.7.8.
    public static func phrases(in strings: [RecognizedString]) -> [Phrase] {
        /// One line, pre-split into its folded words and its raw ones.
        struct Line {
            let words: [String]
            let raw: [String]
            /// Raw words only line up with folded ones when punctuation did not
            /// split a word in the fold (`Saint-Émilion` folds to two words), so
            /// the raw form is used only when the counts agree.
            var alignable: Bool { raw.count == words.count }

            func text(_ range: Range<Int>) -> String? {
                alignable ? raw[range].joined(separator: " ") : nil
            }
        }

        let lines = strings.map { recognized in
            Line(
                words: TextNormalize.key(recognized.text)
                    .split(separator: " ", omittingEmptySubsequences: true)
                    .map(String.init),
                raw: recognized.text
                    .split(whereSeparator: { $0.isWhitespace })
                    .map(String.init)
            )
        }

        var out: [Phrase] = []
        var seen = Set<String>()

        func emit(_ parts: [(index: Int, range: Range<Int>)]) {
            let folded = parts.flatMap { lines[$0.index].words[$0.range] }
            let key = folded.joined(separator: " ")
            guard !key.isEmpty, seen.insert(key).inserted else { return }
            let raws = parts.compactMap { lines[$0.index].text($0.range) }
            let text = raws.count == parts.count ? raws.joined(separator: " ") : key
            out.append(
                Phrase(key: key, text: text, lines: parts.map(\.index), words: folded.count)
            )
        }

        for size in stride(from: maxPhraseWords, through: 1, by: -1) {
            // Unbroken windows first — see the ordering note above.
            for (index, line) in lines.enumerated() where line.words.count >= size {
                for start in 0...(line.words.count - size) {
                    emit([(index, start..<(start + size))])
                }
            }

            guard size >= 2 else { continue }

            for index in lines.indices.dropLast() {
                let head = lines[index]
                guard !head.words.isEmpty else { continue }
                // Every non-empty suffix of this line that leaves room for at
                // least one word on the next.
                for tail in 1...min(head.words.count, size - 1) {
                    let headRange = (head.words.count - tail)..<head.words.count
                    var remaining = size - tail
                    var parts: [(index: Int, range: Range<Int>)] = [(index, headRange)]
                    var next = index + 1

                    while remaining > 0, next < lines.count {
                        let body = lines[next]
                        guard !body.words.isEmpty else { break }
                        if body.words.count >= remaining {
                            parts.append((next, 0..<remaining))
                            remaining = 0
                        } else {
                            // A whole middle line, consumed so the break can
                            // carry on to the one after it.
                            parts.append((next, 0..<body.words.count))
                            remaining -= body.words.count
                            next += 1
                        }
                    }
                    guard remaining == 0 else { continue }
                    emit(parts)
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
