import Testing
import Foundation
@testable import VinodexCore

/// The chip filter's facets (0.7.0, H1/H2/H3).
///
/// `ChipFilter` shipped in 0.6.2 with no tests at all, which was survivable
/// while one screen used it and three of its facets. H puts chips on three more
/// screens and adds three more facets, and every one of the new ones is backed
/// by *authored* data rather than by an enum — a flavour's family is a string in
/// `entries.json`. So the failure mode is a silent empty row after a catalog
/// regeneration, which is precisely what a coverage test is for.
@Suite("Chip facets")
struct ChipFacetTests {
    let db = WineDatabase.shared

    @Test("every facet offers at least two options")
    func facetsAreUseful() {
        for facet in ChipFacet.allCases {
            let options = ChipFilter.options(for: facet)
            #expect(
                options.count >= 2,
                "\(facet.rawValue) offers \(options.count) chips — a row with one chip is a label"
            )
            #expect(!facet.title.isEmpty)
            #expect(!facet.note.isEmpty)
        }
    }

    @Test("every facet's options match something in the catalog")
    func facetsAreLive() {
        for facet in ChipFacet.allCases {
            let hits = ChipFilter.options(for: facet).filter { option in
                var f = ChipFilter()
                f.toggle(option)
                return db.entries.contains { f.matches($0) }
            }
            // COUNTRIES is the one deliberately dead chip: it is a pseudo-value
            // no *entry* can satisfy, because country rows are synthesised.
            let expected = facet == .category
                ? ChipFilter.options(for: facet).count - 1
                : ChipFilter.options(for: facet).count
            #expect(hits.count == expected, "\(facet.rawValue) has chips that match nothing")
        }
    }

    // MARK: H2 — styles

    @Test("the style-class facet partitions the styles")
    func styleClassCoversEveryStyle() {
        let styles = db.entries(in: .styles)
        #expect(!styles.isEmpty)
        var covered = 0
        for option in ChipFilter.options(for: .styleClass) {
            var f = ChipFilter()
            f.toggle(option)
            covered += styles.filter { f.matches($0) }.count
        }
        // Every style has exactly one inferred class, so the arms must sum to
        // the whole set — no double counting and nothing left out.
        #expect(covered == styles.count, "style classes cover \(covered) of \(styles.count)")
    }

    @Test("style chips exclude every other category")
    func styleClassIsStylesOnly() {
        var f = ChipFilter()
        f.toggle(ChipFilter.options(for: .styleClass)[0])
        for entry in db.entries where f.matches(entry) {
            #expect(entry.category == .styles, "\(entry.name) is not a style")
        }
    }

    // MARK: H3 — flavours

    @Test("both flavour facets partition the flavours")
    func flavorFacetsCoverEveryFlavor() {
        let flavors = db.entries(in: .flavors)
        #expect(!flavors.isEmpty)
        for facet in [ChipFacet.flavorClass, .flavorSubclass] {
            var covered = 0
            for option in ChipFilter.options(for: facet) {
                var f = ChipFilter()
                f.toggle(option)
                covered += flavors.filter { f.matches($0) }.count
            }
            #expect(
                covered == flavors.count,
                "\(facet.rawValue) covers \(covered) of \(flavors.count) flavours"
            )
        }
    }

    @Test("flavour chips exclude every other category")
    func flavorFacetsAreFlavorsOnly() {
        for facet in [ChipFacet.flavorClass, .flavorSubclass] {
            var f = ChipFilter()
            f.toggle(ChipFilter.options(for: facet)[0])
            for entry in db.entries where f.matches(entry) {
                #expect(entry.category == .flavors, "\(entry.name) is not a flavour")
            }
        }
    }

    /// The options come from the data, not from a hardcoded list — so they must
    /// agree with what the data actually holds.
    @Test("flavour facet options are derived from the entries")
    func flavorOptionsMirrorTheData() {
        #expect(Set(db.flavorClasses) == Set(ChipFilter.options(for: .flavorClass).map(\.value)))
        #expect(Set(db.flavorSubclasses) == Set(ChipFilter.options(for: .flavorSubclass).map(\.value)))
        // Stable between launches — `counted(_:)` breaks size ties
        // alphabetically for exactly this reason.
        #expect(db.flavorSubclasses == db.flavorSubclasses)
        #expect(Set(db.flavorSubclasses).count == db.flavorSubclasses.count, "duplicate family")
    }

    // MARK: H1 — the world search's scoped TYPE row

    @Test("the type row scopes to a screen's own tables")
    func categoryOptionsScope() {
        let world = ChipFilter.options(
            for: .category,
            in: [.continents, .regions],
            includingCountries: true
        )
        #expect(
            world.map(\.value).sorted() == ["CONTINENTS", "COUNTRIES", "REGIONS"],
            "world search offered \(world.map(\.value))"
        )
        // Without country rows, the pseudo-value has no meaning and goes.
        let noCountries = ChipFilter.options(
            for: .category,
            in: [.continents, .regions],
            includingCountries: false
        )
        #expect(!noCountries.contains { $0.value == ChipFilter.countriesCategoryValue })
        // The unscoped call is the filter-search tool's, and is unchanged.
        #expect(ChipFilter.options(for: .category).count == EntryCategory.allCases.count + 1)
    }

    /// The rule H1 needed: a synthesised country row cannot go through
    /// `matches`, so whether it survives is a statement about the *selection*.
    @Test("country rows survive only a countries-only selection")
    func countryRowVisibility() {
        var empty = ChipFilter()
        #expect(empty.allowsCountryRows, "nothing lit must not hide anything")

        let countries = ChipOption(
            facet: .category,
            value: ChipFilter.countriesCategoryValue,
            label: "COUNTRIES"
        )
        empty.toggle(countries)
        #expect(empty.allowsCountryRows, "the COUNTRIES chip must not hide the countries")

        var withRegions = ChipFilter()
        withRegions.toggle(countries)
        withRegions.toggle(ChipOption(facet: .category, value: "REGIONS", label: "REGIONS"))
        #expect(withRegions.allowsCountryRows, "both lit means both shown")

        var regionsOnly = ChipFilter()
        regionsOnly.toggle(ChipOption(facet: .category, value: "REGIONS", label: "REGIONS"))
        #expect(!regionsOnly.allowsCountryRows, "REGIONS alone must drop the country rows")

        // A real constraint a country cannot meet still drops them, even
        // alongside the COUNTRIES chip.
        var mixed = ChipFilter()
        mixed.toggle(countries)
        mixed.toggle(ChipFilter.options(for: .climate)[0])
        #expect(!mixed.allowsCountryRows, "a country has no climate")
    }

    // MARK: Semantics that predate this batch and were never pinned

    @Test("within a facet OR, across facets AND")
    func selectionSemantics() {
        let red = ChipFilter.options(for: .color).first { $0.value.lowercased() == "red" }
        let white = ChipFilter.options(for: .color).first { $0.value.lowercased() == "white" }
        guard let red, let white else {
            Issue.record("the colour facet lost RED or WHITE")
            return
        }
        var either = ChipFilter()
        either.toggle(red)
        either.toggle(white)
        let eitherCount = db.entries(matching: either).count

        var justRed = ChipFilter()
        justRed.toggle(red)
        #expect(eitherCount > db.entries(matching: justRed).count, "a second chip narrowed a row")

        // Across facets it narrows instead.
        var redAndBody = justRed
        redAndBody.toggle(ChipFilter.options(for: .body)[0])
        #expect(db.entries(matching: redAndBody).count <= db.entries(matching: justRed).count)
    }
}
