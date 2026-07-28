import Testing
import Foundation
@testable import VinodexCore

/// Guardrails on the generated starter dataset.
///
/// These exist because a data swap that silently drops a UI state should fail
/// here — in two seconds on the host — rather than on a device deploy, or worse,
/// not at all.
@Suite("Starter dataset coverage")
struct CoverageTests {
    let db = WineDatabase.shared

    @Test("database loads without decode errors")
    func loads() throws {
        #expect(db.decodeErrors.isEmpty, "decode errors: \(db.decodeErrors)")
        #expect(!db.entries.isEmpty)
    }

    @Test("per-category counts match the selection")
    func counts() {
        // Phase 2: 25 hand-picked grapes, with regions/styles *derived* from
        // those grapes' real cross-links (each REGION/STYLE's
        // `notableGrapes`) rather than independently curated — so these
        // counts are a consequence of the grape selection, not a separate
        // choice. See native/scripts/generate.ts.
        #expect(db.entries(in: .grapes).count == 25)
        #expect(db.entries(in: .regions).count == 49)
        #expect(db.entries(in: .styles).count == 20)
    }

    /// 25 grapes x up to 3 notes = 75 instances collapsing to ~40-75 distinct
    /// once shared notes (e.g. "cherry") merge across grapes. A count near
    /// the full database's total would mean the selection was applied
    /// *after* `buildFlavorEntries` rather than to the source grapes — the
    /// pipeline bug the plan calls out.
    @Test("flavors are derived from the selected grapes only")
    func flavorsDerived() {
        let flavors = db.entries(in: .flavors)
        #expect(flavors.count >= 40 && flavors.count <= 75, "got \(flavors.count)")

        let grapeNames = Set(db.entries(in: .grapes).map(\.name))
        for flavor in flavors {
            let linked = Set(flavor.notableGrapes)
            #expect(
                !linked.isDisjoint(with: grapeNames),
                "flavor \(flavor.name) links no selected grape — derived from the wrong pool"
            )
        }
    }

    @Test("all four rarity tiers are represented")
    func rarityTiers() {
        let tiers = Set(db.entries(in: .grapes).compactMap(\.rarity))
        for tier in RarityLabel.allCases {
            #expect(tiers.contains(tier), "missing rarity tier \(tier.rawValue)")
        }
    }

    @Test("all five climates are represented")
    func climates() {
        let present = Set(db.entries(in: .regions).compactMap(\.climate))
        for climate in ClimateClass.allCases {
            #expect(present.contains(climate), "missing climate \(climate.rawValue)")
        }
    }

    /// The assertion that would have caught the Kakheti/Asia bug: Georgia is
    /// filed under CONT_EUROPE, so picking Kakheti for "Asia" left that marker
    /// resolving to nothing. Resolved through the generated continent map rather
    /// than assumed.
    @Test("every globe marker resolves to at least one region", arguments: Continent.allCases)
    func continentHasRegion(_ continent: Continent) {
        let countries = db.countries(in: continent)
        #expect(!countries.isEmpty, "\(continent.rawValue) has no country list")

        let regions = db.regions(in: continent)
        #expect(
            !regions.isEmpty,
            "\(continent.rawValue) resolves to no region — marker would dead-end in NO DATA FOUND. countries: \(countries.joined(separator: ", "))"
        )
    }

    @Test("palette carries the full colour tables")
    func palette() {
        #expect(db.palette.continentCountries.count == 6)
        #expect(db.palette.climates.count == 5)
        #expect(db.palette.rarityChips.count == 4)
        #expect(!db.palette.countryChips.isEmpty)
        #expect(!db.palette.styleTones.isEmpty)
    }

    /// Grape stat bars must carry the authored values from `grapeCards.ts`, not
    /// values re-derived from descriptive text. The Rork skeleton invented these
    /// (`aromatics = tastingProfile.count + 2`); this pins the real ones.
    @Test("grape characteristics are authored, not derived")
    func authoredCharacteristics() throws {
        let cab = try #require(db.entry(named: "Cabernet Sauvignon"))
        guard case .grape(let g) = cab else {
            Issue.record("Cabernet Sauvignon is not a grape entry")
            return
        }
        #expect(g.grapeCharacteristics.tannin == 4)
        #expect(g.grapeCharacteristics.acid == 4)
        #expect(g.grapeCharacteristics.aromatics == 5)
        #expect(g.grapeCharacteristics.body == 5)
        #expect(g.rarity == .noble)
        #expect(g.grapeBodyClass == "Full")
    }

    /// Napa is the only region exercising `state` and `synonyms`; if it is ever
    /// swapped out, those fields go untested.
    @Test("Napa exercises the state and synonyms fields")
    func napaFields() throws {
        let napa = try #require(db.entry(named: "Napa Valley"))
        guard case .region(let r) = napa else {
            Issue.record("Napa Valley is not a region entry")
            return
        }
        #expect(r.details.state == "California")
        #expect(r.details.synonyms?.contains("Napa") == true)
        #expect(r.climate == .warm)
    }
}
