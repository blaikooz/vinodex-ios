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
        // 0.6.4 batch 2: +18 grapes, +12 regions (the FR/IT/ES expansion).
        // 0.7.3c: +2 regions, both Brazilian (Serra Gaúcha, Campanha) — added
        // because the New World expansion pack names Brazil and the catalog had
        // no such country. No new grapes: all six notable grapes across the two
        // regions were already here, which is the house rule for a new country.
        // 0.7.4 grape overhaul: +25 grapes and +6 regions (Ribeiro, Mallorca,
        // Azores, South West France, San Benito, Itata Valley) — the regions
        // exist so the new varieties point at a real home rather than the
        // nearest famous neighbour. Flavours held at 106: all 75 new tasting
        // notes were drawn from the existing vocabulary on purpose.
        // 0.7.9 (G): sommbot's P1/P2 data batch. +6 grapes (G173 Sercial, G174
        // Boal, G175 Malvasia de São Jorge, G176 Gouais Blanc, G177 Plavac
        // Mali, G178 Manto Negro) and +2 styles (S033 Madeira, S034 Cava).
        // Regions unchanged at 124 — every new grape had a home already.
        #expect(db.entries(in: .grapes).count == 177)
        #expect(db.entries(in: .regions).count == 124)
        // 31 since 0.6.x: Medium-Full Red removed, its grapes now Full-Body.
        // 33 since 0.7.9 (G): Madeira and Cava.
        #expect(db.entries(in: .styles).count == 33)
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
        // 375 since 0.6.2: the rare-grape push (+27 grapes, +6 regions);
        // 405 since 0.6.4 batch 2: the FR/IT/ES expansion (+18 grapes,
        // +12 regions), flavours again unchanged at 106 by note reuse.
        // 407 since 0.7.3c: Brazil, +2 regions. The first data change since
        // 0.6.4 batch 2 — 405 stood for eight releases, and is now the last
        // fixed entry in `waveMilestones`.
        // 438 since 0.7.4: the grape overhaul (+25 grapes, +6 regions), with
        // flavours unchanged at 106 for the fourth data batch running.
        // 446 since 0.7.9 (G): sommbot's P1/P2 batch, +6 grapes and +2 styles.
        // Flavours unchanged at 106 for the fifth data batch running.
        #expect(stats.total == 446)
        // 26 since 0.7.3c: Brazil is the first *new* origin since Mexico. The
        // count is distinct region origins, so the coming-soon gates still do
        // not count and adding a country without a region would not move it.
        //
        // **Still 26 after 0.7.9's data batch**, and that is the rule working
        // rather than a coincidence: Blaufränkisch's origin moved to Slovenia
        // (see `ExpansionPacks.oldWorld`) and Gouais Blanc's is Croatia, but
        // neither is a *region* origin — Slovenia has no region entry at all,
        // and Croatia already had one.
        #expect(stats.countries == 26)
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

    /// **The body bar distinguishes medium-full from full (0.7.5, E).**
    ///
    /// `bodyFromText` tested `full` before `medium-full`, and every test in it is
    /// a substring test — so `'Medium-Full'.includes('full')` was true and the
    /// 16 grapes authored `"Medium-Full"` drew the same 5/5 bar as the 34
    /// authored `"Full"`. The identical defect in `levelFromText` cost the
    /// tannin bar in 0.7.4.
    ///
    /// Cabernet Sauvignon above is the only grape whose characteristics were
    /// pinned anywhere, and it is genuinely `"Full"` — so nothing caught this.
    /// The distribution is pinned here instead of one more grape, because what
    /// broke was a *branch*, and a branch is only observable across the set.
    @Test("the body bar separates Medium-Full from Full")
    func bodyBarsAreDistinct() throws {
        var counts: [Int: Int] = [:]
        for entry in db.entries(in: .grapes) {
            guard case .grape(let grape) = entry else { continue }
            counts[Int(grape.grapeCharacteristics.body), default: 0] += 1
        }
        // 41 Light, 80 Medium (58 authored `"Medium"` plus 22 `"Light-Medium"`,
        // which rounds to the same bar), 16 Medium-Full, 34 Full. Moves with a
        // data batch; say which one when it does. Before the fix the 4 bucket
        // was empty and the 5 held 50.
        //
        // 0.7.9 (G): +1 Light (Gouais Blanc), +1 Medium (Manto Negro), +1
        // Medium-Full (Boal) and +3 Full (Sercial, Malvasia de São Jorge,
        // Plavac Mali) from sommbot's P1/P2 batch. **Not in the 0.7.9 spec's
        // pin list** — it moves with every grape batch by construction, which
        // is exactly what it is for.
        #expect(counts == [2: 42, 3: 81, 4: 17, 5: 37])

        // Chardonnay is authored `body: "Medium-Full"` and drew a full bar.
        // (`grapeBodyClass` still reads "Full" for it — that is a *different*
        // derivation, `getGrapeBodyClass`, which consults the grape's style
        // label "Full-Body White" before its authored body. Out of scope here
        // and parked in PLAN.md.)
        let chardonnay = try #require(db.entry(named: "Chardonnay"))
        guard case .grape(let c) = chardonnay else { return }
        #expect(c.grapeCharacteristics.body == 4, "Medium-Full must not render as Full")
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

    /// **The gate that was missing (0.7.5, D).**
    ///
    /// `icons.countryShapeIcons` is a hand-kept table in the generator, and
    /// nothing checked it against the catalog. Both consumers resolve region art
    /// through it by `details.origin`: `EntryVisual.regionVisual` degrades
    /// quietly to a climate glyph, and `CountryOutlineMap` has no `else` at all
    /// — its `if let` fails and the country page draws **nothing** where the
    /// dotted map belongs. Brazil (added in 0.7.3c) and Mexico both shipped that
    /// way and were found by reading, which is the third silent-missing-asset
    /// bug in three batches after `icon: "fruit"` (0.7.4) and the two logo
    /// layers (0.7.5, A5).
    ///
    /// It is pinned as an **exact set**, not a `<=`, so it fails in both
    /// directions and both failures are the right ones:
    ///
    /// - a *new* place with regions and no outline fails immediately, at the
    ///   batch that adds it, rather than four batches later;
    /// - a place whose outline gets drawn also fails, which is the pleasant
    ///   failure — it says "delete this from the list and from the generator's
    ///   `OUTLINE_BACKLOG`".
    ///
    /// **The list is empty as of 0.7.9 (E)**, which is the pleasant failure the
    /// paragraph above predicted: Brazil and Mexico are drawn, the generator's
    /// `OUTLINE_BACKLOG` is deleted, and this pin becomes "every region's place
    /// has outline art" with no exceptions at all. The two new silhouettes are
    /// script-rasterised from authored coordinates rather than hand-drawn — the
    /// deleted note said that would be visibly not of the set, and that trade is
    /// recorded in PLAN.md rather than hidden here.
    ///
    /// Four countries (UK, Slovenia, Bulgaria, Lebanon) have flag gradients and
    /// no outline but no regions either, so they are latent rather than live and
    /// this gate correctly says nothing about them. Slovenia became an *entry
    /// origin* in 0.7.9 (F) without becoming a region origin, which is exactly
    /// the distinction this test draws.
    @Test("every region's place has outline art")
    func regionsHaveOutlineArt() {
        var missing = Set<String>()
        for entry in db.entries(in: .regions) {
            guard case .region(let r) = entry else { continue }
            // State first, exactly as `EntryVisual.regionVisual` resolves it.
            if let state = r.details.state,
               db.icons.countryShapeIcons[TextNormalize.label(state)] != nil { continue }
            let origin = r.details.origin.isEmpty ? r.common.name : r.details.origin
            if db.icons.countryShapeIcons[TextNormalize.label(origin)] != nil { continue }
            missing.insert(origin)
        }
        #expect(
            missing.isEmpty,
            "these places have regions but no outline art: \(missing.sorted())"
        )
    }
}
