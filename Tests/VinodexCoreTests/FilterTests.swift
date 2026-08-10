import Testing
import Foundation
@testable import VinodexCore

/// Exercises the ported `EncyclopediaList.tsx` filter predicate.
@Suite("Entry filtering and search")
struct FilterTests {
    let db = WineDatabase.shared

    @Test("search matches name, origin, tags and synonyms")
    func searchFields() {
        let all = db.entries

        #expect(all.apply(.masterSearch("cabernet")).contains { $0.name == "Cabernet Sauvignon" })
        // origin
        #expect(all.apply(.category(.regions, search: "japan")).contains { $0.name == "Yamanashi" })
        // synonym — Napa Valley carries "Napa"
        #expect(all.apply(.category(.regions, search: "napa")).contains { $0.name == "Napa Valley" })
    }

    @Test("search is diacritic-insensitive")
    func diacritics() {
        let all = db.entries
        // Albariño / Rías Baixas both carry diacritics.
        #expect(all.apply(.masterSearch("albarino")).contains { $0.name == "Albariño" })
        #expect(all.apply(.category(.regions, search: "rias")).contains { $0.name == "Rías Baixas" })
    }

    @Test("empty search returns the whole category")
    func emptySearch() {
        // Not a magic number: an empty search must return the category
        // untouched, whatever the selection currently holds.
        #expect(
            db.entries.apply(.category(.grapes, search: "")).count
                == db.entries(in: .grapes).count
        )
    }

    @Test("results are sorted by name")
    func sorted() {
        let names = db.entries.apply(.category(.grapes)).map(\.name)
        #expect(names == names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    @Test("rarity filter selects only that tier")
    func rarityFilter() {
        let noble = db.entries.apply(.category(.grapes, filter: .rarity(.noble)))
        #expect(!noble.isEmpty)
        #expect(noble.allSatisfy { $0.rarity == .noble })
    }

    @Test("climate filter selects only that climate")
    func climateFilter() {
        let warm = db.entries.apply(.category(.regions, filter: .climate(.warm)))
        #expect(!warm.isEmpty)
        #expect(warm.allSatisfy { $0.climate == .warm })
    }

    /// The SUBCLASS tile's cross-link (v0.5.1). `.tasting` cannot express
    /// this — it matches notes and classifications — so the case is its own.
    @Test("flavor subclass filter selects only that subclass")
    func flavorSubclassFilter() {
        let berries = db.entries.apply(.category(.flavors, filter: .flavorSubclass("BERRY")))
        #expect(!berries.isEmpty)
        #expect(berries.allSatisfy { entry in
            guard case .flavor(let f) = entry else { return false }
            return f.details.subclass == "BERRY"
        })

        // Normalised on both sides, so a display-cased value still filters.
        #expect(
            db.entries.apply(.category(.flavors, filter: .flavorSubclass("berry"))).count
                == berries.count
        )

        // Non-flavours never match, whatever their tasting notes say.
        #expect(db.entries.apply(.category(.grapes, filter: .flavorSubclass("BERRY"))).isEmpty)
    }

    @Test("origin filter matches whole terms only")
    func originFilter() {
        let french = db.entries.apply(.category(.regions, filter: .origin("France")))
        #expect(french.contains { $0.name == "Bordeaux" })
        #expect(french.allSatisfy { $0.origin == "France" })
    }

    /// The continent filter is the array form of `.region`, and is what the globe
    /// markers apply. Europe should pull several; Asia and Africa now resolve to
    /// more than one region each since the Phase 2 grape expansion (Koshu,
    /// Saperavi, Marselan/Cabernet Gernischt-adjacent origins, Pinotage, Syrah,
    /// Grenache) pulled in more region cross-links than the original 10-grape
    /// starter did. Results come back name-sorted (`apply`'s `.sorted`).
    @Test("continent filter drives globe navigation")
    func continentFilter() {
        let europe = db.regions(in: .europe)
        #expect(europe.count >= 4, "expected several European regions, got \(europe.count)")

        // Hebei, Shandong, Yamagata and Guerrouane joined in the 0.6 boost.
        let asia = db.regions(in: .asia)
        #expect(
            asia.map(\.name) == ["Hebei", "Helan Mountain", "Nandi Hills", "Nashik", "Shandong", "Shangri-La", "Yamagata", "Yamanashi"],
            "got \(asia.map(\.name))"
        )

        let africa = db.regions(in: .africa)
        #expect(
            africa.map(\.name) == ["Guerrouane", "Paarl & Franschhoek", "Stellenbosch", "Swartland", "Walker Bay"],
            "got \(africa.map(\.name))"
        )
    }

    /// Two results since 0.7.4, and the second one is the point rather than a
    /// regression: `searchFields` includes the description, and R122 South West
    /// France is described as "the arc of country between Bordeaux and the
    /// Pyrenees". It is French-origin and it does match "bordeaux", so both
    /// halves of the query still did their job — the filter is what keeps this
    /// to two regions instead of every entry mentioning Bordeaux.
    @Test("filters compose with search")
    func filterPlusSearch() {
        let query = EntryQuery(categories: [.regions], filter: .origin("France"), search: "bordeaux")
        let result = db.entries.apply(query)
        #expect(result.map(\.name) == ["Bordeaux", "South West France"])
    }

    @Test("no filter matches everything in the category")
    func noFilter() {
        #expect(db.entries.apply(.category(.styles)).count == db.entries(in: .styles).count)
    }

    /// v0.5.6: master search must span the whole database — every category,
    /// nothing silently excluded — and countries ride alongside as rows of
    /// their own, since a country is assembled from regions rather than
    /// being an entry.
    @Test("master search spans every entry, and countries search alongside")
    func masterSearchIsTotal() {
        #expect(db.entries.apply(.masterSearch("")).count == db.entries.count)

        #expect(!db.searchableCountries.isEmpty)
        #expect(db.searchableCountries.contains("France"))
        // Every searchable country has regions behind it — a hit must open
        // a page with something on it.
        for country in db.searchableCountries {
            #expect(db.hasRegions(inCountry: country), "\(country) has no regions")
        }

        #expect(db.countries(matching: "fra") == ["France"])
        #expect(db.countries(matching: "") == db.searchableCountries)
        #expect(db.countries(matching: "zzz").isEmpty)
    }

    // MARK: - AUDIT M33: the four branches no test reached

    /// `.type` is what a grape's COLOR and TYPE tiles emit
    /// (`EntryDetailScreen.swift:334`, `:339`). Colour is the discriminating
    /// axis, so RED and WHITE must between them account for every grape —
    /// stated as a partition rather than as two counts, since the catalogue grows.
    @Test("type filter matches a grape's colour and its style")
    func typeFilter() {
        let reds = db.entries.apply(.category(.grapes, filter: .type("red")))
        #expect(!reds.isEmpty)
        #expect(reds.allSatisfy { entry in
            guard case .grape(let g) = entry else { return false }
            return g.grapeType == .red
        })

        let whites = db.entries.apply(.category(.grapes, filter: .type("white")))
        #expect(reds.count + whites.count == db.entries(in: .grapes).count,
                "RED and WHITE must partition the grapes")

        // `grapeStyle` — the TYPE tile's value. (`wineType` is emitted
        // identically by the generator today, so it cannot be told apart here.)
        #expect(!db.entries.apply(.category(.grapes, filter: .type("Full-Body Red"))).isEmpty)
        // Normalised on both sides, so a display-cased value still filters.
        #expect(db.entries.apply(.category(.grapes, filter: .type("RED"))).count == reds.count)
        // Styles fall through unconditionally — the colour inference they would
        // need lives in the UI layer.
        #expect(db.entries.apply(.category(.styles, filter: .type("red"))).isEmpty)
    }

    /// 0.6.2 D2. A style whose name names no colour infers `DUAL`, and its
    /// COLOR tile emits `.type("DUAL")` over the grapes
    /// (`EntryDetailScreen.swift:378`). No single grape carries DUAL, so before
    /// D2 that chip opened an empty list; dual-purpose means both colours qualify.
    @Test("the DUAL colour type matches every grape")
    func typeFilterDual() {
        let all = db.entries(in: .grapes).count
        #expect(db.entries.apply(.category(.grapes, filter: .type("DUAL"))).count == all)
        #expect(db.entries.apply(.category(.grapes, filter: .type("dual"))).count == all)
        // The tile that emits it really is reachable.
        #expect(EntryDisplay.colorType(name: "Bordeaux Blend") == .dual)
        // DUAL is a grape-side answer; the `guard case .grape` still holds.
        #expect(db.entries.apply(.category(.styles, filter: .type("DUAL"))).isEmpty)
    }

    /// The two colour types no grape carries, and what they resolve to.
    ///
    /// `GrapeColor` has exactly two cases, so `Rosé` and `Orange Wine` opened
    /// their COLOR chip onto an empty list from 0.6.2 until this — the same
    /// defect D2 fixed for DUAL and left unfixed for these two. Both name a
    /// *process*, and the shipped descriptions say which grape it is applied
    /// to: rosé is "made from red grapes with minimal skin contact", orange is
    /// "white grapes vinified like red wine". So the mapping is read out of the
    /// catalogue rather than chosen.
    @Test("ROSE leads to red grapes and ORANGE to white")
    func typeFilterRoseAndOrange() {
        #expect(EntryDisplay.colorType(name: "Rosé") == .rose)
        #expect(EntryDisplay.colorType(name: "Orange Wine") == .orange)
        #expect(StyleColorType.rose.grapeColor == .red)
        #expect(StyleColorType.orange.grapeColor == .white)
        #expect(StyleColorType.dual.grapeColor == nil)

        let rose = db.entries.apply(.category(.grapes, filter: .type("ROSE")))
        let orange = db.entries.apply(.category(.grapes, filter: .type("ORANGE")))
        #expect(!rose.isEmpty)
        #expect(!orange.isEmpty)
        #expect(rose.allSatisfy { entry in
            guard case .grape(let g) = entry else { return false }
            return g.grapeType == .red
        })
        #expect(orange.allSatisfy { entry in
            guard case .grape(let g) = entry else { return false }
            return g.grapeType == .white
        })
        // They are the red and white sets exactly, not a subset of them.
        #expect(rose.map(\.id) == db.entries.apply(.category(.grapes, filter: .type("red"))).map(\.id))
        #expect(orange.map(\.id) == db.entries.apply(.category(.grapes, filter: .type("white"))).map(\.id))
        // Still grape-side only — a style never matches a colour filter.
        #expect(db.entries.apply(.category(.styles, filter: .type("ROSE"))).isEmpty)
    }

    /// **`Prosecco` is not a rosé**, and a bare `contains` said it was: the
    /// substring "rose" sits inside "p-rose-cco". Italy's best-known sparkling
    /// *white* wine carried a ROSE chip on its own detail page, and the filter
    /// behind it found nothing. The whole-term test is the same one `.origin`
    /// has always used.
    @Test("a colour word inside another word is not a colour")
    func colorTypeMatchesWholeWords() {
        #expect(EntryDisplay.colorType(name: "Prosecco") == .dual)
        // The catalogue's own Prosecco, not just the string.
        if let prosecco = db.entry(named: "Prosecco", category: .styles) {
            #expect(EntryDisplay.colorType(name: prosecco.name) == .dual)
        }
        // Hyphens still collapse, so the body styles keep resolving.
        #expect(EntryDisplay.colorType(name: "Full-Body Red") == .red)
        #expect(EntryDisplay.colorType(name: "Light-Body White") == .white)
    }

    /// The invariant the whole item is really about: **no style's COLOR chip
    /// may open onto an empty list.** Three did. A per-name test would have
    /// missed the next one; this walks the catalogue.
    @Test("every style's COLOR chip finds at least one grape")
    func everyColorChipLeadsSomewhere() {
        for entry in db.entries(in: .styles) {
            guard case .style(let s) = entry else { continue }
            let color = EntryDisplay.colorType(name: s.common.name)
            let hits = db.entries.apply(.category(.grapes, filter: .type(color.rawValue)))
            #expect(!hits.isEmpty,
                    "\(s.common.name)'s COLOR chip says \(color.rawValue) and opens onto nothing")
        }
    }

    /// `.tasting` is the FLAVOR screen's CLASS tile
    /// (`EntryDetailScreen.swift:416`). Two branches in order: a tasting *note*,
    /// then the entry's classification — and no fall-through past the second,
    /// so an entry that has a classification is judged on it alone.
    @Test("tasting filter matches a classification, then a note")
    func tastingFilter() {
        let sweet = db.entries.apply(.category(.flavors, filter: .tasting("SWEET")))
        #expect(!sweet.isEmpty)
        #expect(sweet.allSatisfy { $0.classification == "SWEET" })

        // The note branch is the only one a grape can take: no grape in the
        // catalogue carries a `details.classification` at all.
        #expect(db.entries(in: .grapes).allSatisfy { $0.classification == nil })
        let noted = db.entries.apply(.category(.grapes, filter: .tasting("Blackcurrant")))
        #expect(!noted.isEmpty)
        #expect(noted.allSatisfy { entry in
            entry.tastingProfile.contains { TextNormalize.label($0.note) == "blackcurrant" }
        })
        #expect(db.entries.apply(.category(.grapes, filter: .tasting("Not A Note"))).isEmpty)
    }

    /// `.system` is the STYLE screen's CLASS tile
    /// (`EntryDetailScreen.swift:387`), and 0.6.x made it compare through
    /// `EntryDisplay.styleClass` rather than the raw `classification` string.
    /// Champagne is what proves it: its raw classification is the
    /// near-universal "STYLE", and the chip beside it plainly says ORIGIN.
    @Test("system filter compares styles through the inferred class")
    func systemFilterOnStyles() throws {
        let champagne = try #require(db.entry(named: "Champagne", category: .styles))
        guard case .style(let s) = champagne else {
            Issue.record("Champagne is not a style"); return
        }
        #expect(s.details.classification == "STYLE")
        #expect(EntryFilter.system("ORIGIN").matches(champagne))
        #expect(!EntryFilter.system("STYLE").matches(champagne),
                "the raw classification must not filter a style any more")

        let origins = db.entries.apply(.category(.styles, filter: .system("ORIGIN")))
        #expect(!origins.isEmpty)
        #expect(origins.allSatisfy { entry in
            guard case .style(let s) = entry else { return false }
            return EntryDisplay.styleClass(
                name: s.common.name, classification: s.details.classification
            ) == .origin
        })

        // The five class values partition the styles, and STYLE takes none of
        // them — nothing infers `.style`, per the note on `EntryDisplay.styleClass`.
        let counts = StyleClassType.allCases.map {
            db.entries.apply(.category(.styles, filter: .system($0.rawValue))).count
        }
        #expect(counts.reduce(0, +) == db.entries(in: .styles).count, "got \(counts)")
        #expect(db.entries.apply(.category(.styles, filter: .system("STYLE"))).isEmpty)
    }

    /// Non-styles keep the raw-classification comparison, so a region is still
    /// reachable by its appellation system.
    @Test("system filter falls through to the raw classification for non-styles")
    func systemFilterOnRegions() {
        let aoc = db.entries.apply(.category(.regions, filter: .system("AOC")))
        #expect(!aoc.isEmpty)
        #expect(aoc.allSatisfy { $0.classification == "AOC" })
        #expect(db.entries.apply(.category(.regions, filter: .system("aoc"))).count == aoc.count)
    }

    /// `.soil` is constructed **nowhere** in `Sources/` — the GEOLOGY chip it
    /// was written for never shipped — so no shipped entry can reach it and
    /// only a fixture can. Kept rather than deleted because `scanTitle`,
    /// `indicatorText` and `storageKey` all still spell it out, and 36 of the
    /// shipped regions carry a `soilType` for it to match the day the chip lands.
    ///
    /// Note the semantics it pins: **substring**, not equality — the only
    /// filter branch that works that way.
    @Test("soil filter substring-matches a region's soil type")
    func soilFilter() throws {
        let fixture = try DBFixture.database(DBFixture.region, DBFixture.grape)
        #expect(fixture.entries.apply(.category(.regions, filter: .soil("limestone"))).map(\.id) == ["FX_R"])
        #expect(fixture.entries.apply(.category(.regions, filter: .soil("LIMESTONE"))).map(\.id) == ["FX_R"])
        #expect(fixture.entries.apply(.category(.regions, filter: .soil("granite"))).isEmpty)
        // Only regions carry soil; the `guard case .region` holds for everything else.
        #expect(fixture.entries.apply(.category(.grapes, filter: .soil("limestone"))).isEmpty)

        // …and there is real data behind it, so the branch is worth keeping.
        let real = db.entries(in: .regions).filter {
            guard case .region(let r) = $0 else { return false }
            return r.details.soilType?.isEmpty == false
        }
        #expect(real.count >= 30, "only \(real.count) regions carry a soilType")
    }

    /// Everything above goes through `[WineEntry].apply(_:)`; every screen goes
    /// through `WineDatabase.entries(matching:)`, which runs the same predicate
    /// against a load-time index (AUDIT M5). The two must not drift.
    @Test("the indexed and unindexed paths agree on every filter branch",
          arguments: [
            EntryQuery(categories: [.grapes], filter: .type("red")),
            EntryQuery(categories: [.grapes], filter: .type("DUAL")),
            EntryQuery(categories: [.flavors], filter: .tasting("SWEET")),
            EntryQuery(categories: [.styles], filter: .system("ORIGIN")),
            EntryQuery(categories: [.regions], filter: .system("AOC")),
            EntryQuery(categories: [.flavors], filter: .flavorSubclass("BERRY")),
            EntryQuery(categories: [.regions], filter: .origin("France")),
            EntryQuery(categories: [.grapes], filter: .rarity(.noble)),
            EntryQuery(categories: [.regions], filter: .climate(.warm)),
          ])
    func indexedPathAgrees(_ query: EntryQuery) {
        #expect(db.entries.apply(query).map(\.id) == db.entries(matching: query).map(\.id))
    }
}

@Suite("Cross-link resolution")
struct CrossLinkTests {
    let db = WineDatabase.shared

    @Test("resolves names that are in the dataset")
    func resolves() {
        #expect(db.entry(named: "Bordeaux") != nil)
        #expect(db.entry(named: "cabernet sauvignon") != nil, "lookup should be case-insensitive")
    }

    /// A name with no entry must return nil rather than a near-match, so the UI
    /// renders it as a plain label instead of a dead button.
    ///
    /// This used to name real grapes outside the 25-grape selection (Cabernet
    /// Franc, Gamay). The full database ships now, so both resolve — the case
    /// needs a name that genuinely does not exist.
    @Test("returns nil for names not in the database")
    func unresolved() {
        #expect(db.entry(named: "Definitely Not A Grape") == nil)
        #expect(db.entry(named: "") == nil)
    }

    /// Most cross-links land now that the full database ships, but 24 names do
    /// not: regions and styles reference grapes absent from the grape table
    /// (Rioja → Graciano, Douro → Tinta Roriz, Jura → Poulsard/Savagnin/
    /// Trousseau), and Pétillant Naturel lists the literal "Various".
    ///
    /// That is a content gap rather than a fault — the UI renders an
    /// unresolved name as a plain label, not a dead button. Pinned so the
    /// number cannot grow unnoticed, and so the day someone fills the gap the
    /// test says so.
    @Test("grape cross-links resolve, apart from a known data gap")
    func crossLinksResolve() {
        var unresolved: Set<String> = []
        var total = 0

        for entry in db.entries(in: .regions) + db.entries(in: .styles) {
            for name in entry.notableGrapes {
                total += 1
                if db.entry(named: name) == nil { unresolved.insert(name) }
            }
        }

        #expect(total > 0)
        #expect(
            unresolved.count <= 24,
            "unresolved cross-links grew to \(unresolved.count): \(unresolved.sorted())"
        )
        // The vast majority must still land; a resolution *mechanism* break
        // would show up here rather than as a slow creep in the count above.
        let resolved = total - unresolved.count
        #expect(
            Double(resolved) / Double(total) > 0.85,
            "only \(resolved)/\(total) cross-links resolve"
        )
    }

    @Test("category-scoped lookup does not cross categories")
    func scoped() {
        // "Champagne" exists as both a style and (in the full DB) a region.
        #expect(db.entry(named: "Champagne", category: .styles) != nil)
        #expect(db.entry(named: "Champagne", category: .grapes) == nil)
    }
}

/// AUDIT M33's second half. `styleClass` and `colorType` are ordered keyword
/// walks with nothing pinning the order, and `.system` reads `styleClass` for
/// **every** style (`EntryFilter.swift:162`) — so reordering a table silently
/// re-buckets the whole STYLES listing and every CLASS chip with it.
@Suite("Style class and colour inference")
struct StyleInferenceTests {
    @Test("an explicit classification overrides the keyword tables")
    func classificationOverrides() {
        // "champagne" is an ORIGIN keyword; the field wins anyway.
        #expect(EntryDisplay.styleClass(name: "Champagne", classification: "METHOD") == .method)
        #expect(EntryDisplay.styleClass(name: "Champagne", classification: "BLEND") == .blend)
    }

    /// The one value that is *not* an override — and the whole reason `.system`
    /// stopped filtering on the raw field. 22 of the 31 shipped styles carry
    /// "STYLE" here.
    @Test("a STYLE classification is not an override")
    func styleIsNotAnOverride() {
        #expect(EntryDisplay.styleClass(name: "Champagne", classification: "STYLE") == .origin)
        #expect(EntryDisplay.styleClass(name: "Full-Body Red", classification: "STYLE") == .type)
        #expect(EntryDisplay.styleClass(name: "Fortified Wine", classification: "STYLE") == .method)
    }

    /// ORIGIN, then TYPE, then METHOD — the comment above the tables says so,
    /// and shipped names depend on all three orderings.
    @Test("keyword precedence is ORIGIN, then TYPE, then METHOD")
    func keywordPrecedence() {
        // "sparkling" is a METHOD keyword and "sparkling wine" a TYPE one, so
        // the longer TYPE entry has to be tested first.
        #expect(EntryDisplay.styleClass(name: "Sparkling Wine", classification: nil) == .type)
        #expect(EntryDisplay.styleClass(name: "Sparkling Shiraz", classification: nil) == .method)
        // "prosecco" is ORIGIN and "sparkling" METHOD; ORIGIN is tested first.
        #expect(EntryDisplay.styleClass(name: "Sparkling Prosecco", classification: nil) == .origin)
        #expect(EntryDisplay.styleClass(name: "Nothing In The Tables", classification: nil) == .style)
    }

    @Test("colour precedence is ORANGE, ROSE, RED, WHITE, then DUAL")
    func colorPrecedence() {
        #expect(EntryDisplay.colorType(name: "Orange Rose Red White") == .orange)
        #expect(EntryDisplay.colorType(name: "Rose Red White") == .rose)
        #expect(EntryDisplay.colorType(name: "Red White") == .red)
        #expect(EntryDisplay.colorType(name: "White") == .white)
        #expect(EntryDisplay.colorType(name: "Bordeaux Blend") == .dual)
        // Diacritic-folded, so the catalogue's "Rosé" resolves.
        #expect(EntryDisplay.colorType(name: "Rosé") == .rose)
        // Whole words only — see `colorTypeMatchesWholeWords`. "Redcurrant" is
        // not a red wine and "Whitehaven" is not a white one.
        #expect(EntryDisplay.colorType(name: "Redcurrant") == .dual)
        #expect(EntryDisplay.colorType(name: "Whitehaven") == .dual)
    }

    /// The invariant that makes `.system` a total function over styles: every
    /// shipped style must be filtered back out by the chip its own detail
    /// screen renders.
    @Test("every style's inferred class round-trips through its own CLASS chip")
    func everyStyleRoundTrips() {
        for entry in WineDatabase.shared.entries(in: .styles) {
            guard case .style(let s) = entry else { continue }
            let cls = EntryDisplay.styleClass(
                name: s.common.name, classification: s.details.classification
            )
            #expect(EntryFilter.system(cls.rawValue).matches(entry),
                    "\(s.common.name) does not match its own CLASS chip")
        }
    }
}
