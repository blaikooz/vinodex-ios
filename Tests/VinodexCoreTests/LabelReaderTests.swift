import Testing
import Foundation
@testable import VinodexCore

/// The label reader's Linux-visible half (0.7.2, LR1).
///
/// **This suite is the reason the feature is split the way it is.** Vision, the
/// camera and the pickers cannot run in CI, so the pipeline is cut at
/// `LabelRecognitionProvider` and everything below the cut — normalisation,
/// phrase generation, edit distance, vintage detection, matching, scoring and
/// the §8 inference walk — is Foundation-only and asserted here. The half that
/// cannot be tested is the half that only moves bytes around.
///
/// Fixtures are `[RecognizedString]` because that is exactly what a provider
/// hands over: a test that starts from a photograph would be testing Apple's
/// OCR, which is not ours to regress.
@Suite("Label reader")
struct LabelReaderTests {
    private let db = WineDatabase.shared
    private var service: LabelRecognitionService { LabelRecognitionService(db: db) }

    /// A label, as OCR would deliver it — one string per line, biggest first.
    private func label(_ lines: String..., prominences: [Double] = []) -> [RecognizedString] {
        lines.enumerated().map { index, text in
            RecognizedString(
                text: text,
                confidence: 0.9,
                prominence: index < prominences.count
                    ? prominences[index]
                    : max(0.05, 0.4 - Double(index) * 0.05)
            )
        }
    }

    // MARK: - Normalisation

    /// The reuse rule, asserted rather than trusted.
    ///
    /// If `LabelTextScan` ever grows a normaliser of its own, the phrases it
    /// produces stop agreeing with the keys `WineDatabase` folded at load and
    /// the matcher silently stops matching. This is the check that would notice.
    @Test("phrases are folded with the app's own normaliser")
    func phrasesUseTextNormalizeKey() {
        let phrases = LabelTextScan.phrases(in: label("Châteauneuf-du-Pape"))
        let keys = Set(phrases.map(\.key))
        #expect(keys.contains(TextNormalize.key("Châteauneuf-du-Pape")))
        // Accents folded, punctuation collapsed to spaces, lowercased.
        #expect(keys.contains("chateauneuf du pape"))
        for key in keys {
            #expect(key == TextNormalize.key(key), "\(key) is not a normalised key")
        }
    }

    @Test("phrases come out longest first, deduplicated")
    func phraseOrdering() {
        let phrases = LabelTextScan.phrases(in: label("CABERNET SAUVIGNON"))
        #expect(phrases.first?.key == "cabernet sauvignon")
        #expect(Set(phrases.map(\.key)).count == phrases.count)
        #expect(phrases.allSatisfy { $0.words <= LabelTextScan.maxPhraseWords })
    }

    @Test("phrases carry the line they came from")
    func phraseProvenance() {
        let phrases = LabelTextScan.phrases(in: label("DOMAINE HUET", "VOUVRAY"))
        let vouvray = phrases.first { $0.key == "vouvray" }
        #expect(vouvray?.line == 1)
        #expect(vouvray?.isJoined == false)
    }

    // MARK: - Phrases across a line break (0.7.9, D-a)

    /// **The eight-bottle bug.** OCR returns one string per line of *type*, and
    /// a long appellation is routinely set over two of them. Windows drawn
    /// inside a single line can never see those names.
    @Test("a phrase set across a line break is a candidate")
    func joinedPhrases() {
        let phrases = LabelTextScan.phrases(in: label("CHATEAUNEUF", "DU-PAPE", "2019"))
        let joined = phrases.first { $0.key == "chateauneuf du pape" }
        #expect(joined != nil, "the appellation was never offered to the matcher")
        #expect(joined?.isJoined == true)
        #expect(joined?.lines == [0, 1])
    }

    /// A break cannot skip a line of type, so a three-line join must consume the
    /// middle one whole.
    @Test("a three-line join takes the middle line entire")
    func joinedPhrasesSpanThree() {
        let phrases = LabelTextScan.phrases(in: label("VINO", "NOBILE", "DI MONTEPULCIANO"))
        let joined = phrases.first { $0.key == "vino nobile di montepulciano" }
        #expect(joined?.lines == [0, 1, 2])
        // And not a join that leapfrogs: `vino di montepulciano` skips NOBILE.
        #expect(!phrases.contains { $0.key == "vino di montepulciano" })
    }

    /// The join is a suffix-to-prefix run, not a cross product. `TELEGRAPHE
    /// 2019` is two adjacent lines and is not a phrase anyone means.
    @Test("only contiguous runs join, and only forwards")
    func joinsAreContiguousAndForward() {
        let phrases = LabelTextScan.phrases(in: label("DOMAINE", "HUET", "VOUVRAY"))
        #expect(phrases.contains { $0.key == "domaine huet" })
        #expect(phrases.contains { $0.key == "huet vouvray" })
        // Backwards is not a reading order.
        #expect(!phrases.contains { $0.key == "vouvray huet" })
        // A phrase never starts mid-line and ends mid-line two lines down
        // without taking everything in between — covered above — and never
        // exceeds the cap.
        #expect(phrases.allSatisfy { $0.words <= LabelTextScan.maxPhraseWords })
    }

    /// **The gate the 0.7.9 note asks for.** `maxPhraseWords` is a claim about
    /// the catalog, and the claim it replaced ("the longest real names top out
    /// at four") went stale without anything noticing — three five-word names
    /// were simply unmatchable. This fails the day a six-word name lands.
    @Test("the phrase window reaches the longest name in the catalog")
    func phraseWindowCoversTheLongestName() {
        var longest = 0
        var worst = ""
        for entry in db.entries {
            var names = [entry.name]
            if case .grape(let g) = entry {
                names += g.details.synonyms + g.grapeAlternateNames
            }
            if case .region(let r) = entry {
                names += r.details.synonyms ?? []
                names += r.details.appellations ?? []
            }
            for name in names {
                let words = TextNormalize.key(name).split(separator: " ").count
                if words > longest { longest = words; worst = name }
            }
        }
        #expect(
            longest <= LabelTextScan.maxPhraseWords,
            "'\(worst)' is \(longest) words and can never be matched — raise maxPhraseWords"
        )
    }

    /// A phrase that spanned two lines must claim **both**, or the leftover half
    /// is offered as an estate name.
    @Test("a joined match claims every line it consumed")
    func joinedMatchesClaimAllTheirLines() {
        let reading = service.read(label("CHATEAUNEUF", "DU-PAPE", "DOMAINE DU VIEUX TELEGRAPHE", "2019"))
        #expect(reading.match(.appellation)?.name == "Châteauneuf-du-Pape")
        #expect(reading.match(.producer)?.name == "DOMAINE DU VIEUX TELEGRAPHE")
    }

    // MARK: - Prominence (0.7.9, D-a)

    /// Two equally long exact hits on one field: the one set in bigger type
    /// wins, because that is the label's own statement about which matters.
    @Test("prominence breaks a tie between two exact matches")
    func prominenceRanksExactMatches() {
        // Both are regions in the catalog. RIOJA is set small at the foot of the
        // label; PRIORAT is the headline.
        let reading = service.read(
            label("PRIORAT", "RIOJA", prominences: [0.36, 0.08])
        )
        #expect(reading.match(.region)?.name == "Priorat")
        // And the other way round, so this is prominence rather than order.
        let flipped = service.read(
            label("PRIORAT", "RIOJA", prominences: [0.08, 0.36])
        )
        #expect(flipped.match(.region)?.name == "Rioja")
    }

    /// Prominence is a tie-break, never a reason to prefer a shorter phrase.
    /// The longest-window rule is what stops `Cabernet Sauvignon` resolving to
    /// `Cabernet`, and it outranks type size absolutely.
    @Test("prominence never beats a longer phrase")
    func lengthOutranksProminence() {
        let reading = service.read(
            label("CABERNET FRANC", "MERLOT", prominences: [0.10, 0.40])
        )
        // MERLOT is set larger, but CABERNET FRANC is the longer phrase and both
        // are exact, so the grape list leads with the longer claim.
        let grapes = reading.grapeIDs.compactMap { db.entry(id: $0)?.name }
        #expect(grapes.first == "Cabernet Franc", "got \(grapes)")
    }

    // MARK: - Outcome (0.7.9, D-a)

    /// **Three states, not two.** A photograph the reader got nothing from and a
    /// label narrowed to a shortlist of real entries were both "no match".
    @Test("a confident reading is identified")
    func outcomeIdentified() {
        #expect(service.read(label("BAROLO", "2016")).outcome == .identified)
    }

    @Test("a country plus a shortlist is ambiguous, not a failure")
    func outcomeAmbiguous() {
        let reading = service.read(label("ZZZZQQ WINERY", "PRODUIT DE FRANCE", "2018"))
        #expect(reading.outcome == .ambiguous)
        #expect(!reading.isConfident)
        #expect(!reading.suggestedRegionIDs.isEmpty, "ambiguous with nothing to offer")
    }

    @Test("nothing the catalog reaches is unrecognized")
    func outcomeUnrecognized() {
        #expect(service.read([]).outcome == .unrecognized)
    }

    /// `isConfident` is the outcome, so the two can never disagree — which they
    /// could while both were computed from the same fields independently.
    @Test("isConfident and outcome cannot drift apart")
    func outcomeAgreesWithConfidence() {
        for lines in [["BAROLO"], ["PRODUIT DE FRANCE"], ["ZZQQ"], ["RIOJA", "2016"]] {
            let reading = service.read(label(lines[0], lines.count > 1 ? lines[1] : ""))
            #expect(reading.isConfident == (reading.outcome == .identified))
        }
    }

    // MARK: - Edit distance

    @Test("edit distance is symmetric and bounded")
    func editDistanceBasics() {
        #expect(LabelTextScan.editDistance("barolo", "barolo", limit: 2) == 0)
        #expect(LabelTextScan.editDistance("barolo", "baralo", limit: 2) == 1)
        #expect(LabelTextScan.editDistance("baralo", "barolo", limit: 2) == 1)
        // Past the limit is nil rather than a large number — the caller only
        // ever asks "is this close enough".
        #expect(LabelTextScan.editDistance("barolo", "rioja", limit: 1) == nil)
        // A length gap wider than the limit short-circuits.
        #expect(LabelTextScan.editDistance("a", "abcdefgh", limit: 2) == nil)
    }

    /// Short strings get **zero** tolerance, and that is the point of the table:
    /// one edit on a four-letter word reaches a large share of the vocabulary.
    @Test("fuzzy tolerance scales with length and is zero for short strings")
    func toleranceLadder() {
        #expect(LabelTextScan.allowedDistance(forLength: 4) == 0)
        #expect(LabelTextScan.allowedDistance(forLength: 6) == 1)
        #expect(LabelTextScan.allowedDistance(forLength: 10) == 2)
        #expect(LabelTextScan.allowedDistance(forLength: 20) == 3)
    }

    // MARK: - Vintage

    @Test("a plausible four-digit year is read as the vintage")
    func vintageDetected() {
        let year = LabelTextScan.vintage(in: label("BAROLO", "2016", "750ML  14,5% vol"))
        #expect(year == 2016)
    }

    @Test("volumes, percentages and founding dates are not vintages")
    func vintageRejections() {
        // 750 and 145 are three digits; 13.5 tokenises as 13 and 5.
        #expect(LabelTextScan.vintage(in: label("750 ML", "13.5% ALC")) == nil)
        // 1855 is before the floor — a Bordeaux classification date, not a wine
        // anyone is holding.
        #expect(LabelTextScan.vintage(in: label("GRAND CRU CLASSÉ EN 1855")) == nil)
    }

    @Test("the newest plausible year wins")
    func vintagePrefersTheNewest() {
        let year = LabelTextScan.vintage(in: label("ESTABLISHED 1936", "2019"))
        #expect(year == 2019)
    }

    @Test("the vintage ceiling tracks the clock rather than a hardcoded year")
    func vintageCeilingIsRelative() {
        let past = Date(timeIntervalSince1970: 1_000_000_000)   // 2001
        #expect(LabelTextScan.vintage(in: label("2019"), now: past) == nil)
        #expect(LabelTextScan.vintage(in: label("1999"), now: past) == 1999)
    }

    // MARK: - Producer (there is no producer entity — see LabelField.producer)

    @Test("an estate keyword names the producer")
    func producerByKeyword() {
        let guess = LabelTextScan.producerGuess(
            in: label("VOUVRAY", "DOMAINE HUET", "2019"),
            claimedLines: []
        )
        #expect(guess == "DOMAINE HUET")
    }

    /// The fallback that justifies `RecognizedString.prominence` existing at all.
    @Test("failing a keyword, the most prominent unclaimed line is the producer")
    func producerByProminence() {
        let strings = label(
            "BAROLO",
            "GIACOMO CONTERNO",
            "2016",
            prominences: [0.30, 0.22, 0.05]
        )
        // Line 0 is the appellation, so the matcher would have claimed it.
        let guess = LabelTextScan.producerGuess(in: strings, claimedLines: [0])
        #expect(guess == "GIACOMO CONTERNO")
    }

    @Test("a claimed line is never offered as the producer")
    func producerSkipsClaimedLines() {
        let guess = LabelTextScan.producerGuess(in: label("BAROLO"), claimedLines: [0])
        #expect(guess == nil)
    }

    @Test("a line that is only digits is never the producer")
    func producerSkipsNumbers() {
        let guess = LabelTextScan.producerGuess(in: label("2016", "750"), claimedLines: [])
        #expect(guess == nil)
    }

    // MARK: - Matching

    @Test("an exact region name resolves")
    func regionMatch() {
        let reading = service.read(label("RIOJA", "RESERVA"))
        #expect(reading.match(.region)?.name == "Rioja")
        #expect(reading.match(.region)?.isExact == true)
        #expect(reading.match(.country)?.name == "Spain")
    }

    @Test("an exact grape name resolves")
    func grapeMatch() {
        let reading = service.read(label("CABERNET SAUVIGNON"))
        #expect(reading.match(.grape)?.name == "Cabernet Sauvignon")
    }

    /// The longest-window rule: `Cabernet Sauvignon` and `Cabernet Franc` are
    /// both grapes and both contain a one-word phrase that is neither.
    @Test("a two-word grape beats its first word")
    func longestPhraseWins() {
        let reading = service.read(label("CABERNET FRANC"))
        #expect(reading.match(.grape)?.name == "Cabernet Franc")
    }

    @Test("a synonym resolves to the entry that owns it")
    func synonymMatch() {
        // Chenin Blanc's South African name, straight out of `details.synonyms`.
        let reading = service.read(label("STEEN"))
        #expect(reading.match(.grape)?.name == "Chenin Blanc")
    }

    @Test("a single OCR error still lands, and is marked inexact")
    func fuzzyMatch() {
        // One transposed character in a nine-letter region name.
        let reading = service.read(label("MARLBOROGH"))
        let region = reading.match(.region)
        #expect(region?.name == "Marlborough")
        #expect(region?.isExact == false)
    }

    /// An exact hit anywhere on the label must beat a fuzzy one, whatever order
    /// the lines arrived in.
    @Test("exact beats fuzzy")
    func exactOutranksFuzzy() {
        let reading = service.read(label("MARLBOROGH", "RIOJA"))
        #expect(reading.match(.region)?.name == "Rioja")
        #expect(reading.match(.region)?.isExact == true)
    }

    @Test("short fragments cannot match")
    func shortFragmentsAreIgnored() {
        // Three letters: below `LabelIndex.minExactLength`, and a fragment that
        // short hits something in a 400-entry catalog nearly every time.
        let reading = service.read(label("RED", "DRY", "VIN"))
        #expect(reading.match(.region) == nil)
        #expect(reading.match(.grape) == nil)
        #expect(reading.match(.wineName) == nil)
    }

    // MARK: - The §8 inference walk

    /// **The spec's own example.** Nothing in the label reader knows that Barolo
    /// is in Piedmont, that Piedmont is in Italy, that Piedmont grows Nebbiolo
    /// or that Nebbiolo makes a full-bodied red. Every one of those is a link
    /// already in the catalog, walked in that order.
    @Test("Barolo infers Italy, Piedmont, Nebbiolo and a full-bodied red")
    func baroloWalk() {
        let reading = service.read(label("BAROLO", "2016"))

        #expect(reading.match(.appellation)?.name == "Barolo")
        #expect(reading.match(.country)?.name == "Italy")
        #expect(reading.vintage == 2016)

        let regionID = reading.match(.appellation)?.entryID
        #expect(db.entry(id: regionID ?? "")?.name == "Piedmont")

        let grapes = reading.grapeIDs.compactMap { db.entry(id: $0)?.name }
        #expect(grapes.contains("Nebbiolo"), "got \(grapes)")

        let styles = reading.styleIDs.compactMap { db.entry(id: $0)?.name }
        #expect(styles.contains("Full-Body Red"), "got \(styles)")
    }

    /// The spec's other example. Vouvray is an appellation of the Loire Valley,
    /// whose notable grapes lead with Chenin Blanc.
    @Test("Vouvray infers France, the Loire Valley and Chenin Blanc")
    func vouvrayWalk() {
        let reading = service.read(label("DOMAINE HUET", "VOUVRAY", "2019"))

        #expect(reading.match(.appellation)?.name == "Vouvray")
        #expect(reading.match(.country)?.name == "France")
        #expect(reading.match(.producer)?.name == "DOMAINE HUET")

        let regionID = reading.match(.appellation)?.entryID
        #expect(db.entry(id: regionID ?? "")?.name == "Loire Valley")

        let grapes = reading.grapeIDs.compactMap { db.entry(id: $0)?.name }
        #expect(grapes.contains("Chenin Blanc"), "got \(grapes)")
        #expect(!reading.styleIDs.isEmpty)
    }

    /// Grapes read off the label outrank grapes inferred from the place — the
    /// bottle said so.
    @Test("a named grape beats the region's notable grapes")
    func namedGrapeWinsOverInference() {
        let reading = service.read(label("BAROLO", "BARBERA"))
        let grapes = reading.grapeIDs.compactMap { db.entry(id: $0)?.name }
        #expect(grapes == ["Barbera"], "got \(grapes)")
    }

    @Test("every inferred id resolves to a real entry")
    func inferredIDsResolve() {
        for text in ["BAROLO", "VOUVRAY", "RIOJA", "MARLBOROUGH", "NAPA VALLEY"] {
            let reading = service.read(label(text))
            for id in reading.grapeIDs {
                #expect(db.entry(id: id)?.category == .grapes, "\(text): dangling grape \(id)")
            }
            for id in reading.styleIDs {
                #expect(db.entry(id: id)?.category == .styles, "\(text): dangling style \(id)")
            }
            for id in reading.suggestedRegionIDs {
                #expect(db.entry(id: id)?.category == .regions, "\(text): dangling region \(id)")
            }
        }
    }

    // MARK: - Confidence

    /// The weights are the spec's, summed and clamped.
    @Test("each matched field contributes its weight")
    func scoreIsTheSumOfWeights() {
        let reading = LabelReading(
            recognizedText: [],
            matches: [
                LabelMatch(field: .region, name: "Rioja", readAs: "RIOJA"),
                LabelMatch(field: .country, name: "Spain", readAs: "SPAIN"),
                LabelMatch(field: .vintage, name: "2016", readAs: "2016"),
            ]
        )
        #expect(reading.score == LabelConfidence.region + LabelConfidence.country + LabelConfidence.vintage)
    }

    @Test("the score clamps at 100")
    func scoreClamps() {
        let everything = LabelReading(
            recognizedText: [],
            matches: [
                LabelMatch(field: .producer, name: "Domaine X", readAs: "DOMAINE X"),
                LabelMatch(field: .wineName, name: "Champagne", readAs: "CHAMPAGNE"),
                LabelMatch(field: .appellation, name: "Vouvray", readAs: "VOUVRAY"),
                LabelMatch(field: .region, name: "Loire Valley", readAs: "LOIRE"),
                LabelMatch(field: .country, name: "France", readAs: "FRANCE"),
                LabelMatch(field: .vintage, name: "2019", readAs: "2019"),
            ]
        )
        #expect(everything.score == 100)
    }

    /// **The producer degradation.** There is no producer index, so a producer
    /// is never confirmed and its 50-point weight is not what a reading gets.
    @Test("an unconfirmed producer contributes the reduced weight")
    func producerDegradesGracefully() {
        let reading = LabelReading(
            recognizedText: [],
            matches: [LabelMatch(field: .producer, name: "Domaine Huet", readAs: "DOMAINE HUET")]
        )
        #expect(reading.score == LabelConfidence.producerTextOnly)
        #expect(LabelConfidence.producerTextOnly < LabelConfidence.producerConfirmed)
        // And a producer alone can never carry a reading over the floor: it is
        // a guess about which line is the estate, not a fact about a wine.
        #expect(!reading.isConfident)
    }

    /// A walked field is shown but not paid for. Barolo's 35 points must not
    /// become 35 + 25 (Piedmont) + 20 (Italy) because the catalog was consulted.
    @Test("inferred fields are shown but score nothing")
    func inferredFieldsAreFree() {
        let reading = service.read(label("BAROLO", "2016"))
        let region = reading.match(.region)
        let country = reading.match(.country)

        #expect(region?.isInferred == true)
        #expect(country?.isInferred == true)
        #expect(reading.score == LabelConfidence.appellation + LabelConfidence.vintage)
    }

    /// An inferred field is not evidence either: a reading whose only place-shaped
    /// match was walked to has nothing that was actually read.
    @Test("an inferred region does not make a reading confident")
    func inferredRegionIsNotEvidence() {
        let reading = LabelReading(
            recognizedText: [],
            matches: [
                LabelMatch(field: .region, name: "Piedmont", readAs: "Barolo", isInferred: true),
                LabelMatch(field: .country, name: "Italy", readAs: "Piedmont", isInferred: true),
                LabelMatch(field: .producer, name: "X Estate", readAs: "X ESTATE"),
            ]
        )
        #expect(!reading.isConfident)
    }

    @Test("a fuzzy match is worth less than an exact one")
    func fuzzyScoresLower() {
        let exact = LabelReading(
            recognizedText: [],
            matches: [LabelMatch(field: .region, name: "Rioja", readAs: "RIOJA", isExact: true)]
        )
        let fuzzy = LabelReading(
            recognizedText: [],
            matches: [LabelMatch(field: .region, name: "Rioja", readAs: "RIOHA", isExact: false)]
        )
        #expect(fuzzy.score < exact.score)
    }

    /// A country on its own is not an identification, however plausible.
    @Test("a country alone is not a confident reading")
    func countryAloneIsNotConfident() {
        let reading = LabelReading(
            recognizedText: [],
            matches: [
                LabelMatch(field: .country, name: "France", readAs: "FRANCE"),
                LabelMatch(field: .vintage, name: "2019", readAs: "2019"),
            ]
        )
        #expect(!reading.isConfident)
    }

    // MARK: - The no-match state

    /// The spec's requirement: a failed read still owes the user the extracted
    /// text, the suggestions and the vintage.
    @Test("a no-match reading still carries text, suggestions and a vintage")
    func noMatchStillReports() {
        let reading = service.read(label("ZZZZQQ WINERY", "PRODUCT OF FRANCE", "2018"))
        #expect(!reading.isConfident)
        #expect(!reading.recognizedText.isEmpty)
        #expect(reading.vintage == 2018)
        #expect(reading.suggestedCountries.contains("France"))
        #expect(!reading.suggestedRegionIDs.isEmpty)
    }

    @Test("a confident reading carries no suggestions")
    func confidentReadingsSkipSuggestions() {
        let reading = service.read(label("BAROLO", "2016"))
        #expect(reading.isConfident)
        #expect(reading.suggestedCountries.isEmpty)
        #expect(reading.suggestedRegionIDs.isEmpty)
    }

    @Test("an empty read fails cleanly rather than inventing a match")
    func emptyInput() {
        let reading = service.read([])
        #expect(reading.matches.isEmpty)
        #expect(reading.score == 0)
        #expect(!reading.isConfident)
        #expect(reading.recognizedText.isEmpty)
    }

    @Test("the recognised text is preserved verbatim, not folded")
    func rawTextSurvives() {
        let reading = service.read(label("Châteauneuf-du-Pape", "MIS EN BOUTEILLE"))
        #expect(reading.recognizedText.contains("Châteauneuf-du-Pape"))
    }

    // MARK: - Round trip

    /// `ScreenStateStore` holds the reading as JSON while the screen is torn
    /// down; a reading that does not survive that is a Back button that loses
    /// the user's result.
    @Test("a reading survives a JSON round trip")
    func readingIsCodable() throws {
        let original = service.read(label("BAROLO", "2016"))
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(LabelReading.self, from: data)
        #expect(restored == original)
        #expect(restored.score == original.score)
    }

    // MARK: - Staging

    @Test("the stages are ordered, labelled and end at 100%")
    func stagesAreCoherent() {
        var last = 0.0
        for stage in LabelReaderStage.allCases {
            #expect(!stage.title.isEmpty)
            #expect(stage.progress > last, "\(stage) does not advance")
            last = stage.progress
        }
        #expect(LabelReaderStage.allCases.last?.progress == 1.0)
        #expect(LabelReaderStage.allCases.first == .reading)
    }

    @Test("every label field has a title and every error a message")
    func labelsExist() {
        for field in LabelField.allCases {
            #expect(!field.title.isEmpty)
        }
        for error: LabelReadError in [
            .cameraUnavailable, .cameraDenied, .photoLibraryDenied,
            .imageUnreadable, .recognitionFailed("x"),
        ] {
            #expect(!error.message.isEmpty)
        }
    }
}
