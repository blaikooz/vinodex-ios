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
        // The full database now ships — `STARTER_SELECTION` is nil. The one
        // thing still filtered is COUNTRY_GATE, whose category `EntryCategory`
        // cannot decode; shipping it failed the whole entries.json decode.
        //
        // Update these deliberately when the data changes; a change you did not
        // intend is exactly what this is here to catch.
        // 0.6 catalog boost (A1): +21 grapes, +38 regions, +3 styles — every
        // cross-reference now resolves; see scripts/find-missing-refs.mjs.
        #expect(db.entries(in: .grapes).count == 128)
        #expect(db.entries(in: .regions).count == 104)
        // 31 since 0.6.x: Medium-Full Red removed, its grapes now Full-Body.
        #expect(db.entries(in: .styles).count == 31)
        #expect(db.entries(in: .continents).count == 6)
    }

    /// The DATA panel draws these. A drift here is a wrong number shown to the
    /// user rather than a crash, so it needs pinning as much as the raw counts
    /// do — and `VinodexUI`, where the panel lives, has no test target.
    @Test("database stats account for every entry")
    func databaseStats() {
        let stats = db.databaseStats

        #expect(stats.grapes == db.entries(in: .grapes).count)
        #expect(stats.regions == db.entries(in: .regions).count)
        #expect(stats.styles == db.entries(in: .styles).count)
        #expect(stats.flavors == db.entries(in: .flavors).count)
        #expect(stats.continents == db.entries(in: .continents).count)
        #expect(stats.total == db.entries.count)

        // Every entry belongs to exactly one of the five categories, so they
        // must sum to the total — a new category that nobody added a line for
        // shows up here as a shortfall.
        let sum = stats.grapes + stats.regions + stats.styles + stats.flavors + stats.continents
        #expect(sum == stats.total, "categories do not account for every entry")

        // 282 since 0.5.7 (Liquorice→Licorice merge, umbrella Citrus removed);
        // 281 since 0.5.8: generic Apple merged into Red Apple (E2);
        // 343 since 0.6: the catalog boost, with flavours unchanged at 106 —
        // every new grape reuses existing tasting notes on purpose;
        // 342 since 0.6.1: Medium-Full Red folded into Full-Body Red;
        // 375 since 0.6.2: the rare-grape push (+27 grapes, +6 regions).
        #expect(stats.total == 375)
        #expect(stats.countries == 25)
        #expect(stats.categoryLines.count == 6)
    }

    /// The growth wave sweeps these in order. A total that fell below an
    /// earlier milestone would make the curve double back on itself, which
    /// reads as a rendering bug rather than as the data shrinking.
    @Test("growth milestones rise to the live total")
    func waveMilestones() {
        let milestones = db.databaseStats.waveMilestones

        #expect(milestones.first == 0)
        #expect(milestones.last == db.entries.count)
        #expect(milestones == milestones.sorted(), "milestones go backwards: \(milestones)")
    }

    /// Flavours are derived from the grapes' tasting notes, collapsing shared
    /// notes (e.g. "cherry") across grapes — so the count must stay well below
    /// the number of note *instances*. The real assertion is the loop: every
    /// flavour must link a grape that exists.
    @Test("flavors are derived from the grapes")
    func flavorsDerived() {
        let flavors = db.entries(in: .flavors)
        let noteInstances = db.entries(in: .grapes)
            .reduce(0) { $0 + $1.tastingProfile.count }
        #expect(!flavors.isEmpty)
        #expect(
            flavors.count < noteInstances,
            "\(flavors.count) flavours from \(noteInstances) notes — shared notes are not merging"
        )

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
        #expect(db.palette.rarityChips.count == 5)
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

    /// The region screen spells out the appellation abbreviation. An unmapped
    /// system falls back to the abbreviation, which renders but reads as a
    /// bug — so adding a region in a new country should fail here first.
    @Test("every region's appellation system has a spelled-out name")
    func appellationNamesResolve() {
        for entry in db.entries(in: .regions) {
            guard case .region(let r) = entry else { continue }
            let short = r.details.classification
            guard !short.isEmpty else { continue }
            let full = EntryDisplay.appellationName(classification: short, country: r.details.origin)
            #expect(
                full != short || short == "Prädikatswein",
                "\(r.common.name): '\(short)' (\(r.details.origin)) has no spelled-out name"
            )
        }
    }

    /// Flavour INFO is only worth showing while the blurbs are specific. They
    /// were hidden originally because every one was the same sentence with the
    /// nouns swapped. Since 0.5.7 (G1) the copy describes the aroma itself and
    /// must *not* fall back to naming grapes — the wine framing ("carried here
    /// by Barbera…") described the database, not the flavour, and the grapes
    /// already appear in NOTABLE GRAPES.
    @Test("flavor descriptions are distinct and about the flavor itself")
    func flavorDescriptions() {
        let flavors = db.entries(in: .flavors)
        #expect(!flavors.isEmpty)

        var seen: Set<String> = []
        for entry in flavors {
            let text = entry.entryDescription
            #expect(!text.isEmpty, "\(entry.name) has no description")
            #expect(seen.insert(text).inserted, "duplicate blurb: \(text)")
            #expect(
                !text.contains("carried here by"),
                "\(entry.name) still carries the wine framing"
            )
        }
    }

    /// Every country you can navigate to has a country page, and that page's
    /// INFO block needs authored prose. Without one it falls back to a derived
    /// summary line, which is what the whole block used to be.
    @Test("every region's country has an authored INFO blurb")
    func countryBlurbs() {
        let origins = Set(db.entries(in: .regions).compactMap(\.origin)).filter { !$0.isEmpty }
        #expect(!origins.isEmpty, "no region origins — nothing was checked")

        for origin in origins.sorted() {
            let info = db.countryInfo(origin)
            #expect(info != nil, "\(origin) has no entry in countries.json")
            #expect(info?.description.isEmpty == false, "\(origin) has an empty blurb")
        }
    }

    /// The flavour scan's CLASS and SUBCLASS tiles sit side by side. They both
    /// used to draw the entry's own glyph, so they were always identical to each
    /// other and changed with whichever note was open. Each level now owns a
    /// glyph, and no two levels may share one.
    @Test("every flavor class and subclass has its own glyph")
    func flavorTaxonomyGlyphs() {
        var owners: [String: String] = [:]
        // Qualified by kind, not by name alone: SALTY is *both* a class and a
        // subclass, and they are two levels that each need their own glyph.
        var levels: Set<String> = []

        for entry in db.entries(in: .flavors) {
            guard case .flavor(let f) = entry else { continue }
            for (kind, value, icon) in [
                ("class", f.details.classification, db.icons.flavorClassIcon(f.details.classification)),
                ("subclass", f.details.subclass, db.icons.flavorSubclassIcon(f.details.subclass)),
            ] {
                let level = "\(kind) \(value)"
                levels.insert(level)
                #expect(icon != db.icons.fallback, "flavor \(level) has no glyph")
                #expect(
                    owners[icon] == nil || owners[icon] == level,
                    "flavor \(level) reuses \(icon), already owned by \(owners[icon] ?? "")"
                )
                owners[icon] = level
            }
        }

        #expect(!levels.isEmpty, "no flavor classes or subclasses were exercised")
        #expect(owners.count == levels.count, "glyphs and taxonomy levels are not 1:1")
    }

    /// The pixel-art flavour portraits (v0.5.1). Every key in the map must
    /// name a real flavour — an orphan key is a typo shipping dead weight —
    /// and the lookup must land through the normalised accessor. Coverage is
    /// deliberately *not* required to be total: flavours without convincing
    /// art keep their tinted glyph by design, but the mapped share is pinned
    /// so a regeneration cannot silently drop the table.
    @Test("flavor art maps real flavours and resolves through the accessor")
    func flavorArtWiring() {
        let art = db.icons.flavorArt
        #expect(art != nil, "manifest lost its flavorArt table")
        guard let art else { return }

        let names = Set(db.entries(in: .flavors).map { TextNormalize.label($0.name) })
        for key in art.keys {
            #expect(names.contains(key), "flavorArt key '\(key)' names no flavour")
        }

        let mapped = db.entries(in: .flavors).filter {
            db.icons.flavorArtStem(for: $0.name) != nil
        }
        #expect(
            Double(mapped.count) / Double(names.count) > 0.8,
            "only \(mapped.count) of \(names.count) flavours have art"
        )

        // The accessor normalises: case must not matter.
        #expect(db.icons.flavorArtStem(for: "BLACKCURRANT") != nil)
    }

    /// The pixel-art style portraits (v0.5.6): every key names a real style,
    /// and — unlike flavours, where partial coverage is by design — the set
    /// covers *all* of them, so the styles screen is never a mix of art and
    /// tinted glyphs.
    ///
    /// One deliberate exception (0.6.4, D1): GSM Blend renders the BLEND
    /// class glyph rather than a portrait — `EntryIconWell` draws a portrait
    /// *over* the entry glyph, so the 0.6.2 icon swap could only land by
    /// removing the portrait from the table.
    @Test("every style has a portrait, and every portrait names a style")
    func styleArtWiring() {
        let art = db.icons.styleArt
        #expect(art != nil, "manifest lost its styleArt table")
        guard let art else { return }

        let portraitless: Set<String> = ["gsm blend"]

        let names = Set(db.entries(in: .styles).map { TextNormalize.label($0.name) })
        for key in art.keys {
            #expect(names.contains(key), "styleArt key '\(key)' names no style")
        }
        for entry in db.entries(in: .styles) {
            let key = TextNormalize.label(entry.name)
            if portraitless.contains(key) {
                #expect(
                    db.icons.styleArtStem(for: entry.name) == nil,
                    "\(entry.name) grew a portrait back — it should wear its class glyph (0.6.4, D1)"
                )
            } else {
                #expect(
                    db.icons.styleArtStem(for: entry.name) != nil,
                    "\(entry.name) has no style art"
                )
            }
        }
    }

    /// Every soil the region screen can show must match a keyword. Falling
    /// through to the default mountain renders, but reads as a bug — six terms
    /// were silently doing exactly that.
    @Test("every soil in the dataset resolves to a specific glyph")
    func soilsResolve() {
        let fallback = db.icons.soilIcons["default"]
        var seen: Set<String> = []

        for entry in db.entries(in: .regions) {
            guard case .region(let r) = entry else { continue }
            for soil in db.icons.soils(soilType: r.details.soilType, climate: r.climate) {
                seen.insert(soil)
                #expect(
                    db.icons.soilIcon(soil) != fallback,
                    "'\(soil)' (\(r.common.name)) has no soil keyword — falls back to the default glyph"
                )
            }
        }
        #expect(!seen.isEmpty, "no soils were exercised at all")
    }

    /// Matching is first-substring-wins, so the generated keyword order is
    /// load-bearing: "clay loam" must reach clay, "sandstone" must reach sand.
    @Test("soil keyword order disambiguates compound terms")
    func soilKeywordOrder() throws {
        let keywords = try #require(db.icons.soilKeywords, "generator no longer emits soilKeywords")
        let clay = try #require(keywords.firstIndex(of: "clay"))
        let loam = try #require(keywords.firstIndex(of: "loam"))
        #expect(clay < loam, "'clay loam' would resolve as loam")

        #expect(db.icons.soilIcon("Clay loam") == db.icons.soilIcons["clay"])
        #expect(db.icons.soilIcon("sandstone") == db.icons.soilIcons["sand"])
        #expect(db.icons.soilIcon("Volcanic ash") == db.icons.soilIcons["volcanic"])
    }

    /// `DOC` means three different things depending on the country, so the
    /// lookup is keyed by the pair rather than the abbreviation alone.
    @Test("DOC resolves per country")
    func docIsCountrySpecific() {
        #expect(EntryDisplay.appellationName(classification: "DOC", country: "Italy")
            == "Denominazione di Origine Controllata")
        #expect(EntryDisplay.appellationName(classification: "DOC", country: "Portugal")
            == "Denominação de Origem Controlada")
        #expect(EntryDisplay.appellationName(classification: "DOC", country: "Argentina")
            == "Denominación de Origen Controlada")
        // Unknown systems pass through rather than rendering empty.
        #expect(EntryDisplay.appellationName(classification: "XYZ", country: "Nowhere") == "XYZ")
    }
}
