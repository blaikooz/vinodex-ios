import Testing
import Foundation
@testable import VinodexCore

@Suite("Chip filter")
struct ChipFilterTests {
    private let db = WineDatabase.shared

    private func option(_ facet: ChipFacet, _ value: String) -> ChipOption {
        ChipFilter.options(for: facet).first { $0.value == value }!
    }

    @Test("an empty filter excludes nothing")
    func emptyMatchesEverything() {
        let filter = ChipFilter()
        #expect(filter.isEmpty)
        #expect(db.entries(matching: filter).count == db.entries.count)
    }

    @Test("every facet offers at least two chips")
    func facetsArePopulated() {
        for facet in ChipFacet.allCases {
            let options = ChipFilter.options(for: facet)
            #expect(options.count >= 2, "\(facet.rawValue) has \(options.count) options")
            #expect(!facet.title.isEmpty)
            #expect(!facet.note.isEmpty)
        }
    }

    @Test("chip ids are unique across every facet")
    func optionIDsAreUnique() {
        let all = ChipFacet.allCases.flatMap { ChipFilter.options(for: $0) }
        #expect(Set(all.map(\.id)).count == all.count)
    }

    @Test("toggling a chip on and off returns to empty")
    func toggleRoundTrip() {
        var filter = ChipFilter()
        let red = option(.color, "red")

        filter.toggle(red)
        #expect(filter.isOn(red))
        #expect(filter.count == 1)

        filter.toggle(red)
        #expect(!filter.isOn(red))
        #expect(filter.isEmpty)
    }

    /// The core semantic. Two chips in one facet widen; two chips across facets
    /// narrow. Getting this backwards produces a filter that behaves the
    /// opposite way to every chip UI anyone has used.
    @Test("within a facet chips OR, across facets they AND")
    func orWithinAndAcross() {
        var reds = ChipFilter()
        reds.toggle(option(.color, "red"))
        var whites = ChipFilter()
        whites.toggle(option(.color, "white"))
        var both = ChipFilter()
        both.toggle(option(.color, "red"))
        both.toggle(option(.color, "white"))

        let redCount = db.entries(matching: reds).count
        let whiteCount = db.entries(matching: whites).count
        #expect(db.entries(matching: both).count == redCount + whiteCount)

        // Across facets: adding a rarity can only shrink the red set.
        var redNoble = reds
        redNoble.toggle(option(.rarity, "NOBLE"))
        #expect(db.entries(matching: redNoble).count <= redCount)
    }

    /// A grape-only facet has to exclude everything that cannot carry it, or
    /// "RED" would quietly return flavours too.
    @Test("a grape-only facet excludes other categories")
    func grapeOnlyFacetsExclude() {
        var filter = ChipFilter()
        filter.toggle(option(.color, "red"))
        #expect(db.entries(matching: filter).allSatisfy { $0.category == .grapes })

        var climate = ChipFilter()
        climate.toggle(option(.climate, "maritime"))
        #expect(db.entries(matching: climate).allSatisfy { $0.category == .regions })
    }

    @Test("a category chip returns only that category")
    func categoryChip() {
        var filter = ChipFilter()
        filter.toggle(option(.category, "GRAPES"))
        let results = db.entries(matching: filter)
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.category == .grapes })
    }

    /// Contradictory chips are allowed and simply return nothing — the screen
    /// says so rather than the model refusing the tap.
    @Test("incompatible facets yield nothing rather than throwing")
    func contradictionIsEmpty() {
        var filter = ChipFilter()
        filter.toggle(option(.category, "REGIONS"))
        filter.toggle(option(.color, "red"))
        #expect(db.entries(matching: filter).isEmpty)
    }

    /// The number printed on each chip has to be the number you get after
    /// tapping it, or the tool lies.
    @Test("the count shown on a chip is the count it produces")
    func chipCountsAreHonest() {
        var filter = ChipFilter()
        filter.toggle(option(.category, "GRAPES"))

        for facet in ChipFacet.allCases {
            for chip in ChipFilter.options(for: facet) {
                let predicted = db.count(withChip: chip, added: filter)
                let actual = db.entries(matching: filter.toggling(chip)).count
                #expect(predicted == actual, "\(chip.id) predicted \(predicted), got \(actual)")
            }
        }
    }

    @Test("a filter round-trips through JSON for the screen state store")
    func codableRoundTrip() throws {
        var filter = ChipFilter()
        filter.toggle(option(.color, "white"))
        filter.toggle(option(.rarity, "NOBLE"))

        let data = try JSONEncoder().encode(filter)
        let back = try JSONDecoder().decode(ChipFilter.self, from: data)
        #expect(back == filter)
        #expect(back.count == 2)
    }
}

@Suite("Tasting quiz")
struct TastingQuizTests {
    private let db = WineDatabase.shared

    @Test("a long run of seeds always produces a question")
    func alwaysProducesAQuestion() {
        for seed in 0..<200 {
            #expect(TastingQuiz.question(seed: seed, in: db) != nil, "seed \(seed) produced nothing")
        }
    }

    /// The properties that make a multiple-choice question fair: four distinct
    /// candidates, the answer among them, and every candidate a real entry.
    @Test("every question is well formed")
    func questionsAreWellFormed() {
        for seed in 0..<200 {
            guard let q = TastingQuiz.question(seed: seed, in: db) else { continue }
            #expect(q.optionIDs.count == TastingQuiz.optionCount, "seed \(seed)")
            #expect(Set(q.optionIDs).count == q.optionIDs.count, "seed \(seed) repeats an option")
            #expect(q.optionIDs.contains(q.answerID), "seed \(seed) omits its own answer")
            #expect(!q.prompt.isEmpty)
            for id in q.optionIDs {
                #expect(db.entry(id: id) != nil, "seed \(seed) names a missing entry \(id)")
            }
        }
    }

    /// The failure that would make the quiz worthless: a distractor that is also
    /// a correct answer. Checked against the same field the prompt was built
    /// from, per kind.
    @Test("no distractor is also a right answer")
    func distractorsAreWrong() {
        for seed in 0..<200 {
            guard let q = TastingQuiz.question(seed: seed, in: db),
                  case .grape(let answer)? = db.entry(id: q.answerID) else { continue }

            for id in q.optionIDs where id != q.answerID {
                guard case .grape(let other)? = db.entry(id: id) else { continue }
                switch q.kind {
                case .color:
                    #expect(other.grapeType != answer.grapeType, "seed \(seed): two \(answer.grapeType) grapes")
                case .body:
                    #expect(
                        TextNormalize.label(other.grapeBodyClass) != TextNormalize.label(answer.grapeBodyClass),
                        "seed \(seed): two \(answer.grapeBodyClass) grapes"
                    )
                case .origin:
                    #expect(
                        TextNormalize.label(other.grapeCountryOfOrigin)
                            != TextNormalize.label(answer.grapeCountryOfOrigin),
                        "seed \(seed): two grapes from \(answer.grapeCountryOfOrigin)"
                    )
                case .region:
                    // The region's grape list is not reachable from the options
                    // alone; well-formedness above covers the rest.
                    break
                }
            }
        }
    }

    /// A region question must not offer a second grape the region also names.
    @Test("region questions have exactly one grape from that region")
    func regionDistractorsAreNotInTheRegion() {
        for seed in 0..<300 {
            guard let q = TastingQuiz.question(kind: .region, seed: seed, in: db) else { continue }
            // Recover the region from the prompt's own wording.
            let name = q.prompt
                .replacingOccurrences(of: "Which of these grapes is notable in ", with: "")
                .replacingOccurrences(of: "?", with: "")
            guard let region = db.entries(in: .regions).first(where: {
                TextNormalize.label($0.name) == TextNormalize.label(name)
            }) else { continue }

            let named = Set(region.notableGrapes.map { TextNormalize.label($0) })
            let hits = q.optionIDs.compactMap { db.entry(id: $0) }
                .filter { named.contains(TextNormalize.label($0.name)) }
            #expect(hits.count == 1, "seed \(seed): \(hits.count) options are notable in \(region.name)")
        }
    }

    @Test("the same seed gives the same question")
    func deterministic() {
        for seed in stride(from: 0, to: 100, by: 7) {
            #expect(TastingQuiz.question(seed: seed, in: db) == TastingQuiz.question(seed: seed, in: db))
        }
    }

    /// Consecutive questions must differ, or NEXT appears not to work.
    @Test("consecutive seeds rarely repeat a question")
    func consecutiveSeedsDiffer() {
        var repeats = 0
        for seed in 0..<100 {
            let a = TastingQuiz.question(seed: seed, in: db)
            let b = TastingQuiz.question(seed: seed + 1, in: db)
            if a == b { repeats += 1 }
        }
        #expect(repeats == 0, "\(repeats) consecutive seed pairs gave the same question")
    }

    @Test("a negative seed does not crash")
    func negativeSeeds() {
        for seed in -50..<0 {
            #expect(TastingQuiz.question(seed: seed, in: db) != nil, "seed \(seed)")
        }
    }
}

@Suite("Walkthrough")
struct WalkthroughTests {
    @Test("every step carries real copy")
    func stepsHaveCopy() {
        #expect(Walkthrough.steps.count >= 5)
        for step in Walkthrough.steps {
            #expect(!step.id.isEmpty)
            #expect(!step.title.isEmpty)
            // Long enough to be a sentence rather than a placeholder.
            #expect(step.body.count > 40, "\(step.id) body is \(step.body.count) chars")
        }
    }

    @Test("step ids are unique")
    func idsAreUnique() {
        let ids = Walkthrough.steps.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    /// The tour opens and closes on the whole device, which is what makes the
    /// first and last steps read as "here is the thing" and "off you go".
    @Test("the tour opens and closes on the whole device")
    func bookends() {
        #expect(Walkthrough.steps.first?.highlight == .device)
        #expect(Walkthrough.steps.last?.highlight == .device)
    }

    /// Every control the tour claims to explain must actually get a step, or the
    /// diagram has a highlight nothing ever triggers.
    @Test("the controls the diagram can light are all covered")
    func coversTheControls() {
        let used = Set(Walkthrough.steps.map(\.highlight))
        for required: WalkthroughStep.Highlight in [.screen, .orb, .settings, .back, .home, .saved] {
            #expect(used.contains(required), "no step highlights \(required.rawValue)")
        }
    }
}
