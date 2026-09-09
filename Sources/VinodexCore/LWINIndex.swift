import Foundation

// MARK: - What an LWIN match is

/// One bottle the LWIN database recognises in a label's text (0.9.54).
///
/// LWIN — the Liv-ex Wine Identification Number — is the wine trade's open
/// identification standard: 200k+ producer-and-wine records, Creative Commons,
/// and the first *bottle-level* entities Vinodex has ever held. The catalog's
/// entries are knowledge (grapes, regions, styles); an `LWINMatch` is a claim
/// about the actual object in front of the camera, which is why it carries its
/// own score rather than feeding `LabelReading.score` — the confidence table's
/// weights are the spec's, and a new evidence source does not get to inflate
/// them from the side.
public struct LWINMatch: Codable, Sendable, Hashable, Identifiable {
    /// The 7-digit LWIN code, as the trade writes it (`1011247`).
    public let id: String
    /// The database's full display name — `Chateau Lafite Rothschild, Pauillac`.
    public let displayName: String
    /// The producer head of the display name. LWIN's own convention: the text
    /// before the first comma is the estate.
    public let producer: String
    /// The rest — cuvée, classification, place. Empty when the display name is
    /// only a producer.
    public let wine: String
    public let country: String?
    public let region: String?
    /// `Red` / `White` / `Rose` / `Mixed`, where LWIN states one.
    public let colour: String?
    /// `Still` / `Sparkling` / `Fortified`.
    public let wineType: String?
    /// Weighted share of the record's name found on the label, 0–1. Only
    /// values at or above `LWINIndex.confidenceFloor` are ever surfaced.
    public let score: Double

    public init(
        id: String,
        displayName: String,
        producer: String,
        wine: String,
        country: String?,
        region: String?,
        colour: String?,
        wineType: String?,
        score: Double
    ) {
        self.id = id
        self.displayName = displayName
        self.producer = producer
        self.wine = wine
        self.country = country
        self.region = region
        self.colour = colour
        self.wineType = wineType
        self.score = score
    }
}

// MARK: - The index

/// The bundled LWIN database, loaded lazily and searched by token vote.
///
/// **Why this is not `LabelIndex`.** The catalog index holds ~900 targets, so
/// the matcher can afford an edit-distance pass of every phrase against every
/// target. LWIN is 185k records; that same pass would be seconds per
/// photograph. So the shape is inverted: records are broken into name tokens
/// once at load, label text is broken into tokens per read, and matching is a
/// set intersection — postings lists nominate candidate records, and each
/// candidate is scored by how much of *its* name the label covered. The work
/// per read is proportional to the label and the candidates it implicates,
/// not to the database.
///
/// **Load is lazy and belongs off-main.** 7.8MB of resource parses in the
/// high hundreds of milliseconds; nothing at app launch needs it, so nothing
/// at app launch pays for it. `LabelRecognitionService.read` already runs off
/// the main actor (the fuzzy catalog pass earned that), and the first read
/// simply pays the load once. The lock makes a second concurrent first-read
/// wait rather than load twice.
///
/// **The resource format is half of this type.** `scripts/generate-lwin-index.py`
/// writes `lwin.tsv` so that this loader never folds a string: every line's
/// match key is either derivable by the trivial ASCII fold below (which is
/// `TextNormalize.key` restricted to ASCII, byte for byte) or stored in the
/// file, pre-folded, where accents would make the two differ. The sampled
/// agreement test in `LWINIndexTests` holds the derived keys equal to
/// `TextNormalize.key` of the reconstructed display names, which is what
/// keeps the generator's Python fold and the app's one normaliser honest
/// with each other.
public final class LWINIndex: @unchecked Sendable {
    public static let shared = LWINIndex()

    // MARK: Tuning

    /// A candidate must clear this score to be surfaced at all. Conservative
    /// on purpose: an empty answer is honest, a 185k-row database
    /// volunteering "Barolo" matches for every bottle from Piedmont is noise
    /// wearing a database's authority.
    public static let confidenceFloor = 0.65
    /// How much matched weight counts as a full identification. Coverage
    /// alone is not enough: `Chateau Pauillac` is *entirely* present on a
    /// Lafite label — every word of the shorter name appears in the longer
    /// one — so a record whose whole name is two near-filler words would
    /// score a perfect share. Scaling by absolute matched weight, saturating
    /// here, means a record must be substantially *named*, not merely
    /// consistent with the label's vocabulary.
    static let evidenceSaturation = 1.5
    /// A matched token this common cannot *nominate* candidates — `chateau`
    /// implicates half of Bordeaux. It still counts toward the coverage of
    /// candidates nominated by rarer words.
    static let candidateCap = 3000
    /// At least one matched token must carry this much weight for a record
    /// to count as identified — coverage built entirely out of `chateau`,
    /// `grand` and `reserve` is a description, not a name.
    static let distinctiveWeight = 0.7
    /// A fuzzy token hit is worth this fraction of an exact one — the same
    /// judgement `LabelConfidence.fuzzyMultiplier` makes about whole fields.
    static let fuzzyTokenWeight = 0.7
    /// Tokens shorter than this never match: `de`, `la`, `du` are glue in
    /// both the database and on labels. Applied identically at load and at
    /// query, so the two vocabularies agree.
    static let minTokenLength = 3
    /// Below this length a label token is exact-only — fuzzy on short tokens
    /// is the coin-toss `LabelTextScan.allowedDistance` already refuses.
    static let minFuzzyTokenLength = 5
    /// Fuzzy candidates are found by 4-byte prefix bucket, so an OCR error in
    /// a token's first four characters loses the fuzzy match. That is the
    /// deliberate trade: buckets keep the fuzzy pass proportional to one
    /// bucket instead of an 80k-token vocabulary, and OCR errors cluster in
    /// the middles of words (accents, ligatures) far more than the openings.
    static let prefixLength = 4
    /// A record needs at least this many matched tokens — one word is never a
    /// bottle identification, whatever its coverage share.
    static let minMatchedTokens = 2

    /// How common a token is → how much of a name it is worth. Bands rather
    /// than a curve so the numbers are statable and testable: a rare word
    /// (`lafite`) is most of a name, a vocabulary word (`chardonnay`) is a
    /// hint, and filler (`chateau`) is nearly nothing.
    static func weight(documentFrequency: Int) -> Double {
        switch documentFrequency {
        case ..<51: 1.0
        case ..<501: 0.7
        case ..<5001: 0.4
        default: 0.2
        }
    }

    /// Words that state a wine's *rank*, not its identity — the same species
    /// of hardcoding as `LabelTextScan.producerKeywords`: no wine names, just
    /// the classification vocabulary of the database's languages, folded.
    ///
    /// **Why frequency alone cannot handle these.** LWIN's official name for
    /// the first growth is `Chateau Lafite Rothschild Premier Cru Classe,
    /// Pauillac`; the label says no such thing. `classe` is rare enough
    /// (df 243) that any monotone frequency weighting prices the unmatched
    /// classification above the unmatched halves of merchandising names —
    /// which ranked `NV Assortment Case` above the wine itself. A rank word
    /// is worth almost nothing whether matched or missed, so a name differs
    /// from its classified form by nearly nothing — which is how a person
    /// reads those names too.
    static let rankWords: Set<String> = [
        "premier", "premiere", "grand", "grande", "cru", "classe",
        "classico", "riserva", "reserva", "reserve", "superiore",
        "superieur", "superieure",
    ]
    static let rankWordWeight = 0.05

    // MARK: State

    /// Everything the load produces, immutable thereafter — which is what
    /// makes handing a reference out from under the lock safe.
    struct Storage {
        /// Producer heads, in file order (sorted by name).
        var producers: [String] = []
        var pairCountries: [String] = []
        var pairRegions: [String] = []
        /// Per record, parallel arrays — 185k structs of Strings would cost
        /// real memory and decode time for fields most reads never touch.
        var ids: [UInt32] = []
        var producerIndex: [Int32] = []
        var pairIndex: [Int32] = []
        var codes: [UInt8] = []
        var tails: [String] = []
        /// The token vocabulary and both directions of the map: token →
        /// records (postings, for nomination) and record → tokens (for
        /// coverage scoring). Flat arrays plus offsets, not `[[Int32]]` —
        /// a million tiny arrays is a million allocations.
        var tokenTexts: [String] = []
        var tokenLookup: [String: Int32] = [:]
        var postings: [Int32] = []
        var postingsOffsets: [Int32] = [0]
        var recordTokens: [Int32] = []
        var recordTokenOffsets: [Int32] = [0]
        /// Per token: its `weight(documentFrequency:)`, or `rankWordWeight`.
        /// Computed once at load so the scoring loop is an array read.
        var tokenWeights: [Double] = []
        /// First-`prefixLength`-bytes → token ids, for the fuzzy pass.
        var prefixBuckets: [String: [Int32]] = [:]

        var recordCount: Int { ids.count }
    }

    private enum State {
        case idle
        case loaded(Storage)
        case failed
    }

    private let lock = NSLock()
    private var state: State = .idle
    private let resourceURL: URL?

    /// The shared instance reads the bundled resource; tests may point an
    /// instance at a fixture file instead.
    public convenience init() {
        // The same two-step lookup `WineDatabase` uses: SPM layouts keep the
        // subdirectory, the flattened iOS bundle does not.
        let url = Bundle.module.url(forResource: "lwin", withExtension: "tsv", subdirectory: "Resources")
            ?? Bundle.module.url(forResource: "lwin", withExtension: "tsv")
        self.init(resourceURL: url)
    }

    init(resourceURL: URL?) {
        self.resourceURL = resourceURL
    }

    // MARK: - Loading

    /// The loaded storage, loading it on first call. Blocking by design —
    /// callers are already off-main (see the type note), and a lock held for
    /// the load is what stops two first-reads parsing 7.8MB twice.
    func storage() -> Storage? {
        lock.lock()
        defer { lock.unlock() }
        switch state {
        case .loaded(let storage): return storage
        case .failed: return nil
        case .idle: break
        }
        guard let resourceURL,
              let data = try? Data(contentsOf: resourceURL),
              let storage = Self.parse(data) else {
            // A missing or malformed resource degrades to "no matches", the
            // same posture every art loader takes — the reader keeps working
            // on the catalog alone.
            state = .failed
            return nil
        }
        state = .loaded(storage)
        return storage
    }

    /// Record count, loading if needed. For tests and diagnostics.
    var recordCount: Int { storage()?.recordCount ?? 0 }

    /// `TextNormalize.key` for ASCII bytes, without Foundation's folding
    /// machinery: lowercase letters and digits pass, everything else is a
    /// space, runs collapse. The generator stores an explicit key on any
    /// line where this would *not* equal the real fold, so applying it to
    /// every unannotated line is exact, not approximate.
    private static func asciiFoldTokens(_ bytes: ArraySlice<UInt8>, into tokens: inout [String]) {
        var current: [UInt8] = []
        func flush() {
            if !current.isEmpty {
                tokens.append(String(decoding: current, as: UTF8.self))
                current.removeAll(keepingCapacity: true)
            }
        }
        for byte in bytes {
            switch byte {
            case 0x41...0x5A: current.append(byte + 32)
            case 0x61...0x7A, 0x30...0x39: current.append(byte)
            default: flush()
            }
        }
        flush()
    }

    /// Splits a pre-folded key (from the file, or from `TextNormalize.key`)
    /// into tokens. Keys are already lowercase-and-spaces, so this is a
    /// whitespace split.
    private static func keyTokens(_ key: Substring, into tokens: inout [String]) {
        for token in key.split(separator: " ") {
            tokens.append(String(token))
        }
    }

    /// Whether a token is admitted to the vocabulary — the same test on both
    /// sides of the match, which is what makes the vocabularies comparable.
    /// Digits-only tokens are refused: a vintage year on the label must not
    /// vote for the handful of wine names that contain numbers. Internal so
    /// the agreement test applies the identical rule to its expectations.
    static func admits(_ token: String) -> Bool {
        token.count >= minTokenLength && !token.allSatisfy(\.isNumber)
    }

    private static func base36(_ bytes: ArraySlice<UInt8>) -> Int? {
        var value = 0
        for byte in bytes {
            let digit: Int
            switch byte {
            case 0x30...0x39: digit = Int(byte - 0x30)
            case 0x61...0x7A: digit = Int(byte - 0x61) + 10
            default: return nil
            }
            value = value * 36 + digit
        }
        return value
    }

    /// One pass over the file's bytes. The format (see the generator's
    /// header) is built for exactly this: fixed-width numeric prefixes, a
    /// tab only where an explicit key follows, producers as `>` group
    /// headers so each head string and its tokens are computed once for its
    /// whole group.
    static func parse(_ data: Data) -> Storage? {
        var storage = Storage()
        let bytes = [UInt8](data)

        var lineStart = 0
        var lineIndex = 0
        var pairsExpected = 0
        var recordsExpected = 0

        // Group state: the current producer's index and admitted token ids.
        var currentProducer: Int32 = -1
        var producerTokenIDs: [Int32] = []

        var tokenScratch: [String] = []

        func tokenID(_ text: String) -> Int32 {
            if let id = storage.tokenLookup[text] { return id }
            let id = Int32(storage.tokenTexts.count)
            storage.tokenTexts.append(text)
            storage.tokenLookup[text] = id
            return id
        }

        while lineStart < bytes.count {
            var lineEnd = lineStart
            while lineEnd < bytes.count, bytes[lineEnd] != 0x0A { lineEnd += 1 }
            defer { lineStart = lineEnd + 1; lineIndex += 1 }

            var tab = lineStart
            while tab < lineEnd, bytes[tab] != 0x09 { tab += 1 }
            let body = bytes[lineStart..<tab]
            let hasKey = tab < lineEnd

            if lineIndex == 0 {
                // `LWIN1\trecords\tproducers\tpairs` — the version gate.
                let fields = bytes[lineStart..<lineEnd].split(separator: 0x09)
                guard fields.count == 4,
                      String(decoding: fields[0], as: UTF8.self) == "LWIN1",
                      let records = Int(String(decoding: fields[1], as: UTF8.self)),
                      let pairs = Int(String(decoding: fields[3], as: UTF8.self))
                else { return nil }
                recordsExpected = records
                pairsExpected = pairs
                storage.ids.reserveCapacity(records)
                storage.tails.reserveCapacity(records)
                storage.recordTokenOffsets.reserveCapacity(records + 1)
                continue
            }
            if lineIndex <= pairsExpected {
                storage.pairCountries.append(String(decoding: body, as: UTF8.self))
                let region = hasKey ? String(decoding: bytes[(tab + 1)..<lineEnd], as: UTF8.self) : ""
                storage.pairRegions.append(region)
                continue
            }

            if bytes[lineStart] == 0x3E { // '>' — a producer group header
                let name = String(decoding: bytes[(lineStart + 1)..<tab], as: UTF8.self)
                storage.producers.append(name)
                currentProducer = Int32(storage.producers.count - 1)

                tokenScratch.removeAll(keepingCapacity: true)
                if hasKey {
                    let key = String(decoding: bytes[(tab + 1)..<lineEnd], as: UTF8.self)
                    keyTokens(key[...], into: &tokenScratch)
                } else {
                    asciiFoldTokens(bytes[(lineStart + 1)..<tab], into: &tokenScratch)
                }
                producerTokenIDs.removeAll(keepingCapacity: true)
                for token in tokenScratch where admits(token) {
                    producerTokenIDs.append(tokenID(token))
                }
                continue
            }

            // A record: 5 bytes LWIN base36, 2 bytes pair index, 1 code byte,
            // then the display tail.
            guard currentProducer >= 0, tab - lineStart >= 8,
                  let lwin = base36(bytes[lineStart..<(lineStart + 5)]),
                  let pair = base36(bytes[(lineStart + 5)..<(lineStart + 7)]),
                  pair < storage.pairCountries.count
            else { return nil }
            let code = bytes[lineStart + 7]
            let tailBytes = bytes[(lineStart + 8)..<tab]

            storage.ids.append(UInt32(lwin))
            storage.producerIndex.append(currentProducer)
            storage.pairIndex.append(Int32(pair))
            storage.codes.append(code)
            storage.tails.append(String(decoding: tailBytes, as: UTF8.self))

            tokenScratch.removeAll(keepingCapacity: true)
            if hasKey {
                let key = String(decoding: bytes[(tab + 1)..<lineEnd], as: UTF8.self)
                keyTokens(key[...], into: &tokenScratch)
            } else {
                asciiFoldTokens(tailBytes, into: &tokenScratch)
            }

            // The record's tokens: producer's plus the tail's, deduplicated —
            // `Riesling Riesling` must not count coverage twice.
            var recordIDs = producerTokenIDs
            for token in tokenScratch where admits(token) {
                let id = tokenID(token)
                if !recordIDs.contains(id) { recordIDs.append(id) }
            }
            storage.recordTokens.append(contentsOf: recordIDs)
            storage.recordTokenOffsets.append(Int32(storage.recordTokens.count))
        }

        guard storage.recordCount == recordsExpected else { return nil }

        // Postings: count, prefix-sum, fill — `recordTokens` plus its offsets
        // is the whole occurrence sequence, replayed twice instead of stored
        // twice.
        var counts = [Int32](repeating: 0, count: storage.tokenTexts.count)
        for token in storage.recordTokens { counts[Int(token)] += 1 }
        storage.postingsOffsets = [0]
        storage.postingsOffsets.reserveCapacity(counts.count + 1)
        var running: Int32 = 0
        for count in counts {
            running += count
            storage.postingsOffsets.append(running)
        }
        storage.postings = [Int32](repeating: 0, count: Int(running))
        var cursors = storage.postingsOffsets
        for record in 0..<storage.recordCount {
            let start = Int(storage.recordTokenOffsets[record])
            let end = Int(storage.recordTokenOffsets[record + 1])
            for index in start..<end {
                let token = Int(storage.recordTokens[index])
                storage.postings[Int(cursors[token])] = Int32(record)
                cursors[token] += 1
            }
        }

        storage.tokenWeights = storage.tokenTexts.enumerated().map { index, text in
            rankWords.contains(text)
                ? rankWordWeight
                : weight(documentFrequency: Int(counts[index]))
        }

        // Prefix buckets for the fuzzy pass. Keys are ASCII after folding, so
        // a byte prefix is a character prefix.
        for (index, token) in storage.tokenTexts.enumerated()
        where token.utf8.count >= minFuzzyTokenLength {
            let prefix = String(token.prefix(prefixLength))
            storage.prefixBuckets[prefix, default: []].append(Int32(index))
        }

        return storage
    }

    // MARK: - Matching

    /// The LWIN records a label's text identifies, best first, or `[]`.
    ///
    /// Four steps, each bounded:
    /// 1. The label's tokens, through `TextNormalize.key` — the one
    ///    normaliser, so a label word and an index token are comparable.
    /// 2. Each label token resolves to index tokens: exact by lookup, else
    ///    fuzzy within its prefix bucket under the same length-scaled
    ///    tolerance the catalog matcher uses.
    /// 3. Matched tokens rarer than `candidateCap` nominate their records.
    /// 4. Each candidate is scored: the weighted share of its own name's
    ///    tokens the label matched. The floor, the two-token minimum and the
    ///    distinctive-token requirement are what keep a lone `PAUILLAC` — or
    ///    a label from outside the database entirely — answering nothing.
    public func matches(for strings: [RecognizedString], limit: Int = 5) -> [LWINMatch] {
        guard limit > 0, !strings.isEmpty, let storage = storage() else { return [] }

        // Step 1 — the label's vocabulary.
        var labelTokens: Set<String> = []
        for recognized in strings {
            for token in TextNormalize.key(recognized.text).split(separator: " ") {
                let text = String(token)
                if Self.admits(text) { labelTokens.insert(text) }
            }
        }
        guard !labelTokens.isEmpty else { return [] }

        // Step 2 — resolve to index tokens. Quality is the better of exact
        // and fuzzy when both land on the same index token. The fuzzy pass
        // runs even when the exact lookup hit: `LAFITTE` is both a real
        // Bordeaux producer *and* the classic OCR garbling of `LAFITE`, and
        // suppressing the neighbours would make the reader certain about
        // exactly the words OCR is least reliable on.
        var matched: [Int32: Double] = [:]
        for token in labelTokens {
            if let id = storage.tokenLookup[token] {
                matched[id] = 1.0
            }
            let length = token.utf8.count
            guard length >= Self.minFuzzyTokenLength else { continue }
            let allowed = LabelTextScan.allowedDistance(forLength: length)
            guard allowed > 0,
                  let bucket = storage.prefixBuckets[String(token.prefix(Self.prefixLength))]
            else { continue }
            for id in bucket {
                let candidate = storage.tokenTexts[Int(id)]
                guard abs(candidate.utf8.count - length) <= allowed,
                      LabelTextScan.editDistance(token, candidate, limit: allowed) != nil
                else { continue }
                matched[id] = max(matched[id] ?? 0, Self.fuzzyTokenWeight)
            }
        }
        guard !matched.isEmpty else { return [] }

        // Step 3 — nomination by the rare-enough tokens. Rank words never
        // nominate whatever their frequency — `classe` is rare and still
        // identifies nothing.
        var candidates: Set<Int32> = []
        for (id, _) in matched {
            guard storage.tokenWeights[Int(id)] >= Self.weight(documentFrequency: Self.candidateCap) else { continue }
            let start = Int(storage.postingsOffsets[Int(id)])
            let end = Int(storage.postingsOffsets[Int(id) + 1])
            guard end - start <= Self.candidateCap else { continue }
            for index in start..<end { candidates.insert(storage.postings[index]) }
        }
        guard !candidates.isEmpty else { return [] }

        // Step 4 — coverage scoring.
        var scored: [(record: Int32, score: Double)] = []
        for record in candidates {
            let start = Int(storage.recordTokenOffsets[Int(record)])
            let end = Int(storage.recordTokenOffsets[Int(record) + 1])
            var total = 0.0
            var hit = 0.0
            var matchedCount = 0
            var hasDistinctive = false
            for index in start..<end {
                let token = storage.recordTokens[index]
                let weight = storage.tokenWeights[Int(token)]
                total += weight
                if let quality = matched[token] {
                    hit += weight * quality
                    matchedCount += 1
                    if weight >= Self.distinctiveWeight { hasDistinctive = true }
                }
            }
            guard total > 0, matchedCount >= Self.minMatchedTokens, hasDistinctive else { continue }
            // Coverage (share of the record's own name the label matched)
            // times evidence (how much matched weight there is at all, see
            // `evidenceSaturation`). The product is what the floor judges:
            // most of the name, and enough name to mean something.
            let coverage = hit / total
            let evidence = min(1.0, hit / Self.evidenceSaturation)
            let score = coverage * evidence
            if score >= Self.confidenceFloor {
                scored.append((record, score))
            }
        }

        // Higher score first; the LWIN code breaks ties so two runs over one
        // photograph list the same order — the stability rule every ranked
        // list in the reader already follows.
        scored.sort { a, b in
            a.score == b.score
                ? storage.ids[Int(a.record)] < storage.ids[Int(b.record)]
                : a.score > b.score
        }

        return scored.prefix(limit).map { entry in
            Self.match(record: Int(entry.record), score: entry.score, in: storage)
        }
    }

    /// The public shape of one record. Kept out of the hot loop — only the
    /// handful of winners are ever materialised.
    private static func match(record: Int, score: Double, in storage: Storage) -> LWINMatch {
        let producer = storage.producers[Int(storage.producerIndex[record])]
        let tail = storage.tails[record]
        let pair = Int(storage.pairIndex[record])
        let country = storage.pairCountries[pair]
        let region = storage.pairRegions[pair]
        let (colour, wineType) = decode(code: storage.codes[record])
        // Zero-padded by hand rather than `String(format:)` — LWIN codes are
        // always 7 digits, and format-string bridging is the one Foundation
        // corner that behaves differently on Linux.
        let digits = String(storage.ids[record])
        return LWINMatch(
            id: String(repeating: "0", count: max(0, 7 - digits.count)) + digits,
            displayName: tail.isEmpty ? producer : "\(producer), \(tail)",
            producer: producer,
            wine: tail,
            country: country.isEmpty ? nil : country,
            region: region.isEmpty ? nil : region,
            colour: colour,
            wineType: wineType,
            score: score
        )
    }

    /// The generator's code table, inverted. One character carries colour ×
    /// category; the two switch statements here and the `CODE` dict in
    /// `generate-lwin-index.py` are the two halves of one agreement.
    static func decode(code: UInt8) -> (colour: String?, wineType: String?) {
        let colour: String?
        let wineType: String?
        switch code {
        case UInt8(ascii: "r"), UInt8(ascii: "w"), UInt8(ascii: "p"),
             UInt8(ascii: "m"), UInt8(ascii: "n"):
            wineType = "Still"
        case UInt8(ascii: "R"), UInt8(ascii: "W"), UInt8(ascii: "P"),
             UInt8(ascii: "M"), UInt8(ascii: "N"):
            wineType = "Sparkling"
        case UInt8(ascii: "f"), UInt8(ascii: "g"), UInt8(ascii: "h"),
             UInt8(ascii: "i"), UInt8(ascii: "j"):
            wineType = "Fortified"
        default:
            wineType = nil
        }
        switch code {
        case UInt8(ascii: "r"), UInt8(ascii: "R"), UInt8(ascii: "f"): colour = "Red"
        case UInt8(ascii: "w"), UInt8(ascii: "W"), UInt8(ascii: "g"): colour = "White"
        case UInt8(ascii: "p"), UInt8(ascii: "P"), UInt8(ascii: "h"): colour = "Rose"
        case UInt8(ascii: "m"), UInt8(ascii: "M"), UInt8(ascii: "i"): colour = "Mixed"
        default: colour = nil
        }
        return (colour, wineType)
    }
}
