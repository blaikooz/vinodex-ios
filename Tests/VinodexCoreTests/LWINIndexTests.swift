import Testing
import Foundation
@testable import VinodexCore

/// The LWIN bottle-identification index (0.9.54).
///
/// **What is on trial here is the agreement between three parties**: the
/// generator (`scripts/generate-lwin-index.py`), which folds and packs 185k
/// records; the loader, which must reconstruct exactly what was packed; and
/// `TextNormalize.key`, which folds the label's side of every comparison. A
/// disagreement anywhere in that triangle does not crash — it silently stops
/// matching bottles, which is the failure mode this suite exists to make loud.
///
/// Fixtures are real records (Lafite Rothschild, Sassicaia) rather than
/// synthetic ones: the resource ships in the bundle, so the database *is* the
/// fixture, and a regeneration that lost either of those bottles would be a
/// data regression worth failing over.
@Suite("LWIN index")
struct LWINIndexTests {
    private let index = LWINIndex.shared

    /// A label, as OCR would deliver it — one string per line.
    private func label(_ lines: String...) -> [RecognizedString] {
        lines.map { RecognizedString(text: $0, confidence: 0.9, prominence: 0.2) }
    }

    // MARK: - Loading

    @Test("the bundled index loads, at full size")
    func indexLoads() throws {
        let storage = try #require(index.storage(), "lwin.tsv missing or malformed")
        // The trimmed database is ~185k wines; a threshold rather than an
        // exact count so a routine regeneration does not fail the suite, set
        // high enough that shipping half the file would.
        #expect(storage.recordCount > 150_000)
        #expect(storage.producers.count > 25_000)
        #expect(storage.pairCountries.count > 300)
        // Parallel arrays are only parallel if they are the same length.
        #expect(storage.ids.count == storage.recordCount)
        #expect(storage.tails.count == storage.recordCount)
        #expect(storage.producerIndex.count == storage.recordCount)
        #expect(storage.recordTokenOffsets.count == storage.recordCount + 1)
    }

    @Test("a missing resource degrades to no matches, not a crash")
    func missingResource() {
        let absent = LWINIndex(resourceURL: URL(fileURLWithPath: "/nonexistent/lwin.tsv"))
        #expect(absent.matches(for: label("CHATEAU LAFITE ROTHSCHILD")) == [])
        #expect(absent.recordCount == 0)
    }

    // MARK: - The triangle: generator, loader, normaliser

    /// Every unannotated line in the file relies on the loader's ASCII fold
    /// being `TextNormalize.key` exactly; every annotated line relies on the
    /// generator's Python fold being the same. This walks a deterministic
    /// sample of records and holds the tokens the loader indexed equal to
    /// the tokens `TextNormalize.key` produces from the reconstructed
    /// display name — the comparison every real match depends on.
    @Test("indexed tokens agree with TextNormalize.key")
    func vocabularyAgreement() throws {
        let storage = try #require(index.storage())
        var checked = 0
        for record in stride(from: 0, to: storage.recordCount, by: 997) {
            let producer = storage.producers[Int(storage.producerIndex[record])]
            let tail = storage.tails[record]
            let display = tail.isEmpty ? producer : "\(producer), \(tail)"

            var expected = Set<String>()
            for token in TextNormalize.key(display).split(separator: " ") {
                let text = String(token)
                if LWINIndex.admits(text) { expected.insert(text) }
            }
            var indexed = Set<String>()
            let start = Int(storage.recordTokenOffsets[record])
            let end = Int(storage.recordTokenOffsets[record + 1])
            for offset in start..<end {
                indexed.insert(storage.tokenTexts[Int(storage.recordTokens[offset])])
            }
            #expect(indexed == expected, "record \(record) (\(display)) indexed \(indexed), key says \(expected)")
            checked += 1
        }
        #expect(checked > 150)
    }

    // MARK: - Matching

    @Test("a first growth identifies itself")
    func lafiteMatches() {
        // The database's official name carries the classification the label
        // does not print — which is exactly what `rankWords` exists for: the
        // classified form must outrank the estate's assortment cases.
        let matches = index.matches(for: label("CHATEAU LAFITE ROTHSCHILD", "PAUILLAC", "2015"))
        let first = matches.first
        #expect(first?.displayName == "Chateau Lafite Rothschild Premier Cru Classe, Pauillac")
        #expect(first?.producer == "Chateau Lafite Rothschild Premier Cru Classe")
        #expect(first?.country == "France")
        #expect(first?.region == "Bordeaux")
        #expect(first?.colour == "Red")
        #expect(first?.wineType == "Still")
        #expect(first?.id.count == 7)
        #expect((first?.score ?? 0) >= LWINIndex.confidenceFloor)
    }

    @Test("a fantasy-name cuvee is reachable — the reason LWIN ships at all")
    func sassicaiaMatches() {
        // `Sassicaia` appears in no catalog entry; the label scan alone could
        // never resolve it. This is the capability the 8MB buys.
        let matches = index.matches(for: label("TENUTA SAN GUIDO", "SASSICAIA", "BOLGHERI"))
        #expect(matches.first?.displayName == "Sassicaia, Tenuta San Guido, Bolgheri")
        #expect(matches.first?.country == "Italy")
    }

    @Test("an OCR-garbled name still lands, one edit away")
    func fuzzyTokenMatch() {
        // LAFITTE for LAFITE — the doubled letter OCR loves. The token's
        // 4-byte prefix survives, so the bucket pass finds it.
        // `LAFITTE` is also a real producer, so the exact hit must not
        // silence the fuzzy neighbours — the true reading appears among the
        // candidates even though the literal one ranks.
        let matches = index.matches(for: label("CHATEAU LAFITTE ROTHSCHILD", "PAUILLAC"))
        #expect(matches.contains { $0.producer == "Chateau Lafite Rothschild Premier Cru Classe" })
    }

    @Test("a lone place word identifies nothing")
    func lonePlaceWord() {
        // Hundreds of records carry `Barolo`; a bottle has not been
        // identified until the label narrows them. The empty answer is the
        // conservative floor doing its job.
        #expect(index.matches(for: label("BAROLO")) == [])
        #expect(index.matches(for: label("PAUILLAC", "2015")) == [])
    }

    @Test("nonsense matches nothing")
    func nonsenseMatchesNothing() {
        #expect(index.matches(for: label("GLORPINALE ZIXWAXIAN", "FLURBOZZLE ESTATE")) == [])
        #expect(index.matches(for: []) == [])
        #expect(index.matches(for: label("")) == [])
    }

    @Test("results respect the limit and rank the full name first")
    func limitAndOrder() {
        let matches = index.matches(for: label("CHATEAU LAFITE ROTHSCHILD", "PAUILLAC"), limit: 3)
        #expect(matches.count <= 3)
        // Ordered by score descending — the property the results screen
        // renders straight through.
        #expect(matches == matches.sorted { $0.score > $1.score })
        #expect(index.matches(for: label("CHATEAU LAFITE ROTHSCHILD"), limit: 0) == [])
    }

    // MARK: - The reading carries it

    @Test("a read carries its LWIN matches; an empty answer is an array")
    func readingCarriesMatches() {
        let service = LabelRecognitionService()
        let identified = service.read(label("CHATEAU LAFITE ROTHSCHILD", "PAUILLAC", "2015"))
        #expect(identified.lwinMatches?.isEmpty == false)
        #expect(identified.lwinMatches?.first?.producer == "Chateau Lafite Rothschild Premier Cru Classe")

        // A label the database does not know still carries the field — `[]`,
        // the honest default, not `nil`.
        let unknown = service.read(label("GLORPINALE ZIXWAXIAN"))
        #expect(unknown.lwinMatches == [])
    }

    /// The same decode contract `importer`/`bottler` shipped under: a reading
    /// stored by an older build has no `lwinMatches` key and must decode.
    @Test("stored readings from before 0.9.54 still decode")
    func decodesWithoutField() throws {
        let old = """
        {"recognizedText":["BAROLO"],"matches":[],"grapeIDs":[],"styleIDs":[],
         "suggestedCountries":[],"suggestedRegionIDs":[],"providerName":"test"}
        """
        let reading = try JSONDecoder().decode(LabelReading.self, from: Data(old.utf8))
        #expect(reading.lwinMatches == nil)

        // And a reading with matches round-trips whole.
        let match = LWINMatch(
            id: "1011247", displayName: "Chateau Lafite Rothschild, Pauillac",
            producer: "Chateau Lafite Rothschild", wine: "Pauillac",
            country: "France", region: "Bordeaux", colour: "Red",
            wineType: "Still", score: 1.0
        )
        let modern = LabelReading(
            recognizedText: [], matches: [], lwinMatches: [match]
        )
        let decoded = try JSONDecoder().decode(
            LabelReading.self, from: JSONEncoder().encode(modern)
        )
        #expect(decoded.lwinMatches == [match])
    }

    // MARK: - Performance sanity

    /// Bounds, not benchmarks: generous enough that CI load never trips them,
    /// tight enough that an accidental O(n²) in the parser or a fuzzy pass
    /// that walks the whole vocabulary cannot land quietly. Debug builds run
    /// several times slower than the shipping binary, and the bounds are set
    /// for debug — on-device release cost is a fraction of these.
    @Test("load and match stay inside their bounds")
    func performanceSanity() {
        let clock = ContinuousClock()

        // **A wall-clock budget cannot mean the same thing on a machine we own
        // and on a runner we share.** The cold load took 38.7s against a 20s
        // bound on GitHub's macOS simulator job and under 2s locally — and in
        // that same run three trivial tests that take ten seconds here each
        // took a hundred and seventy. The index had not changed; the runner was
        // contended.
        //
        // The bound is a *shape* guard, not a benchmark: what it exists to
        // catch is an accidental O(n^2) in the parser or a fuzzy pass that
        // walks the whole vocabulary, and those are measured in minutes, not in
        // the difference between twenty seconds and forty. So it keeps its real
        // tightness where timing is meaningful, and on CI it loosens to
        // something only a genuine change of shape can trip. Deleting it there
        // was the other option; a loose bound still catches what this guards.
        let shared = ProcessInfo.processInfo.environment["CI"] != nil
        let loadBudget: Duration = shared ? .seconds(180) : .seconds(20)
        let matchBudget: Duration = shared ? .seconds(45) : .seconds(5)

        // A fresh instance, so this measures a real cold load even when the
        // shared index is already warm from the other tests.
        let fresh = LWINIndex()
        let loadTime = clock.measure { _ = fresh.storage() }
        #expect(fresh.recordCount > 150_000)
        #expect(loadTime < loadBudget, "cold load took \(loadTime)")

        let matchTime = clock.measure {
            for _ in 0..<10 {
                _ = fresh.matches(for: label("CHATEAU LAFITE ROTHSCHILD", "PAUILLAC", "2015"))
            }
        }
        #expect(matchTime < matchBudget, "10 matches took \(matchTime)")
    }
}
