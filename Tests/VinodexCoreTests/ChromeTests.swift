import Testing
import Foundation
@testable import VinodexCore

/// Guardrails on the chrome tables (0.7.0).
///
/// Everything asserted here is a rule that used to live only in someone's head
/// and had already been broken once by the time it was written down. The marquee
/// glyph table is the clearest case: it is `VinodexUI` that *draws* the glyph, so
/// no gate could ever see a wrong one — but the table itself is Core, and the
/// properties that make it right are checkable here in milliseconds.
@Suite("Chrome tables")
struct ChromeTests {

    // MARK: Marquee glyphs (K2)

    /// Every reachable route in the app, spelled out.
    ///
    /// A literal list rather than something derived, because `DexRoute` carries
    /// associated values and is not `CaseIterable`. That makes this list the one
    /// thing here a human has to maintain — hence `routeListIsComplete` below,
    /// which fails if a route is added and not listed.
    static let allRoutes: [DexRoute] = {
        var routes: [DexRoute] = [
            .detail(entryID: "does-not-exist"),
            .globe,
            .globeSearch,
            .bookmarks,
            .country(name: "France"),
            .state(name: "California"),
            // 0.8.93 (item 9): `.profVino` replaces `.dailyGrape` in the same
            // edit that swapped the cases — WHAT'S THAT…? is deleted and the
            // professor's page holds its slot, so the count below stands.
            .profVino,
            .scanner,
            .labelReader,
            .moonDial,
            .settings,
            .minigames,
            .chipFilter,
            .wsetQuiz,
            .dailyChallenge,
            .passport,
            .walkthrough,
            // The three 0.7.3 routes. The first two shipped in 0.7.3a and were
            // *not* added here, which meant `glyphsAreDistinct` below — the whole
            // reason this list exists — never saw them. `routeListIsComplete`
            // could not catch it either, because it asserts a count and the count
            // was correct for the list rather than for the enum; see the note
            // there for what that gap costs and why it is still a count.
            .firmwareHistory,
            .cheatConsole,
            .deviceWorkshop,
            // 0.7.5 (E1). Added here in the same edit that added the case, which
            // is the discipline 0.7.3a's two missing routes were the argument for.
            .lineage(entryID: "G001"),
            .continent(entryID: "europe"),
            // 0.8.4 (C1). Added in the same edit as the case, which is the
            // discipline 0.7.3a's two missing routes were the argument for.
            .pack(id: "does-not-exist"),
            // 0.8.6 (C3), same edit as the case, same discipline.
            .stampCollection,
            // 0.8.91 (B3, F1), same edit as the cases, same discipline.
            .recommendations,
            .support,
        ]
        routes += EntryCategory.allCases.map { .list(category: $0, filter: nil) }
        routes += SettingsSection.allCases.map { .settingsSection($0) }
        return routes
    }()

    /// Every filter kind, one value each.
    static let allFilters: [EntryFilter] = [
        .region(["France"]),
        .type("Red"),
        .tasting("Cherry"),
        .flavorSubclass("BERRY"),
        .soil("Limestone"),
        .origin("France"),
        .rarity(.noble),
        .system("Origin"),
        .climate(.continental),
        .styleColor(.red),
    ]

    @Test("every route has a title and a glyph")
    func routesAreLabelled() {
        for route in Self.allRoutes {
            #expect(!route.title.isEmpty, "\(route) has no title")
            #expect(!route.marqueeSymbol.isEmpty, "\(route) has no marquee glyph")
        }
    }

    /// **The K2 assertion.** Two different pages must not wear the same glyph.
    ///
    /// This is what caught nothing for four releases: `map.fill` stood for three
    /// pages, `globe.americas.fill` for four, `magnifyingglass` for two and
    /// `sparkles` for two more, so the marquee could not tell a user which of
    /// them they were on. The exemption list is the *deliberate* repeat — a
    /// category listing and that category's detail pages are the same subject,
    /// and `WineEntry.scanSymbol` agrees with `EntryCategory.marqueeSymbol` on
    /// purpose. Everything else must be unique.
    @Test("no two routes share a marquee glyph")
    func glyphsAreDistinct() {
        // The one documented repeat, and the reason it is allowed: a category
        // listing and that category's own pages are the same subject, so
        // `EntryCategory.marqueeSymbol` and the routes that drill into it agree
        // on purpose. CONTINENTS lists the continents; CONTINENT SCAN is one of
        // them. Anything *else* sharing a glyph is the K2 bug.
        let sameSubject: Set<Set<String>> = [["CONTINENTS", "CONTINENT SCAN"]]

        var byGlyph: [String: [String]] = [:]
        for route in Self.allRoutes {
            byGlyph[route.marqueeSymbol, default: []].append(route.title)
        }
        for (glyph, titles) in byGlyph where titles.count > 1 {
            guard !sameSubject.contains(Set(titles)) else { continue }
            Issue.record("\(glyph) is shared by \(titles.sorted().joined(separator: ", "))")
        }
    }

    /// A filtered listing shows the *filter's* glyph (K2, rule 2).
    ///
    /// Before 0.7.0 `DexRoute.marqueeSymbol` discarded the filter entirely, so a
    /// GEOLOGY SCAN and a plain REGIONS listing were indistinguishable on the
    /// panel. This asserts the discard cannot come back.
    @Test("a filter overrides its category's glyph")
    func filtersCarryTheirOwnGlyph() {
        for filter in Self.allFilters {
            for category in EntryCategory.allCases {
                let route = DexRoute.list(category: category, filter: filter)
                #expect(
                    route.marqueeSymbol == filter.marqueeSymbol,
                    "\(filter) listing shows \(route.marqueeSymbol), not the filter's glyph"
                )
            }
        }
    }

    @Test("every filter kind has a title and a glyph")
    func filtersAreLabelled() {
        for filter in Self.allFilters {
            #expect(!filter.scanTitle.isEmpty)
            #expect(!filter.marqueeSymbol.isEmpty)
            #expect(!filter.indicatorText.isEmpty)
        }
    }

    /// **A filtered listing wears its filter's face, or none — never its
    /// parent category's** (0.8.5, B1).
    ///
    /// K2 rule 2 as an assertion. The rule says a GEOLOGY SCAN is not a regions
    /// listing; the failure mode it guards against is a future edit "fixing"
    /// the four filters that answer nil by falling through to
    /// `category.marqueeArt`, which would put the regions map over GEOLOGY SCAN
    /// and the wineglass over RARITY SCAN — the exact 0.7.0 bug, one release
    /// after it was fixed for symbols.
    @Test("a filtered listing never borrows its category's marquee art")
    func filteredListingsKeepTheirOwnArt() {
        for filter in Self.allFilters {
            for category in EntryCategory.allCases {
                let route = DexRoute.list(category: category, filter: filter)
                #expect(
                    route.marqueeArt == filter.marqueeArt,
                    "\(filter.scanTitle) in \(category) shows '\(route.marqueeArt ?? "-")', not the filter's '\(filter.marqueeArt ?? "-")'"
                )
            }
        }
    }

    /// **Filter search is one destination, and it is not the category's**
    /// (0.8.7, C1).
    ///
    /// The item asks for every cross-linked tile that lands in a filter search
    /// to say so, with the magnifier, and for the chip it arrived on to be lit.
    /// That looks like it fights K2 rule 2 — `filteredListingsKeepTheirOwnArt`
    /// above — and does not: rule 2 forbids a filtered listing from borrowing
    /// its *parent category's* face, and this gives it a third identity of its
    /// own. Both are asserted here, on the same routes, so the day one is
    /// "fixed" at the other's expense this fails.
    ///
    /// The split itself is derived rather than listed — a filter is a filter
    /// search exactly when it is expressible as a chip — so what is pinned is
    /// *which* filters land on which side, because that is the decision a future
    /// edit would move without noticing.
    ///
    /// **The magnifier is its own magnifier since 0.8.9a (A5).** C1 gave these
    /// filters `marquee-mastersearch` because that was the only glass on disk
    /// and their title reads FILTER SEARCH; the drop has a glass with a funnel
    /// in it, so the third identity this test is named for now has a third
    /// picture instead of borrowing MASTER SEARCH's. Everything C1 asserted is
    /// unchanged — one destination, one title, one symbol — and the symbol
    /// stays `DexGlyph.search` on purpose: `marqueeSymbol` is the fallback, and
    /// SF has no funnelled magnifier that is safe on iOS 17.
    @Test("a filter that is a chip is a filter search, and wears the magnifier")
    func filterSearchIsOneDestination() {
        for filter in Self.allFilters {
            guard filter.chipOption != nil else { continue }
            #expect(filter.scanTitle == "FILTER SEARCH")
            #expect(filter.marqueeSymbol == DexGlyph.search)
            #expect(filter.marqueeArt == "marquee-filtersearch")
            // And the screen they land on keeps the plain glass it was drawn
            // as, which is the whole reason the two are now different files.
            #expect(DexRoute.chipFilter.marqueeArt == "marquee-mastersearch")
            // Rule 2 still holds over the same routes: the face is the
            // filter's, never the category's.
            for category in EntryCategory.allCases {
                let route = DexRoute.list(category: category, filter: filter)
                #expect(route.title == "FILTER SEARCH")
                #expect(route.marqueeArt == filter.marqueeArt)
                #expect(route.marqueeSymbol == filter.marqueeSymbol)
            }
        }
    }

    /// Which filters convert, and the facet each becomes.
    ///
    /// A table because the derivation has value-dependent arms and every one was
    /// settled by measuring the shipped catalog rather than by reading the code
    /// — see `EntryFilter.chipOption`. `.origin` is left alone because it
    /// matches tags as well as origins and nothing pushes it as a route.
    ///
    /// **0.8.8's C1 moves the `.type` rows and this is the record of it.** 0.8.7
    /// pinned `.type("Full-Body Red")` as *not* a chip, on the true measurement
    /// that it is not the BODY chip. The user overruled the resulting STYLE SCAN
    /// title, and the honest way to satisfy that was to widen the chip
    /// vocabulary rather than to point the title at a chip that would show a
    /// different list — so `.grapeStyle` exists and the ten values convert
    /// exactly. `.type("Rose")` and `.type("Orange")` are still not chips and
    /// now nothing sends them: the style COLOR tile sends `.styleColor`.
    @Test("the filters that are chips are exactly these, on exactly these facets")
    func chipMappingIsPinned() {
        #expect(EntryFilter.type("red").chipOption?.facet == .color)
        #expect(EntryFilter.type("white").chipOption?.facet == .color)
        // Case and diacritics fold, because the tile sends the raw value.
        #expect(EntryFilter.type("Red").chipOption?.value == "red")

        // The body tile, converted in 0.8.8's C1. The chip's stored value is the
        // catalog's own spelling whatever case the filter carried, so it is one
        // `ChipFilter.options` offers — `presetChipsAreOffered` checks all ten.
        #expect(EntryFilter.type("Full-Body Red").chipOption?.facet == .grapeStyle)
        #expect(EntryFilter.type("Full-Body Red").chipOption?.value == "Full-Body Red")
        #expect(EntryFilter.type("full-body red").chipOption?.value == "Full-Body Red")
        #expect(EntryFilter.type("Full-Body Red").scanTitle == "FILTER SEARCH")
        // The four values that are *not* body-and-colour compounds, which is why
        // the facet is the catalog's vocabulary and not BODY crossed with COLOUR.
        #expect(EntryFilter.type("Aromatic White").chipOption?.facet == .grapeStyle)
        #expect(EntryFilter.type("Madeira").chipOption?.facet == .grapeStyle)

        // Neither a grape colour nor a grape style, and nothing sends them any
        // more — the style COLOR tile pushes `.styleColor` since C1.
        #expect(EntryFilter.type("Rose").chipOption == nil)
        #expect(EntryFilter.type("Orange").chipOption == nil)
        // And `.type("Dual")` no longer answers "every grape": D2's special case
        // went with its caller.
        #expect(EntryFilter.type("Dual").chipOption == nil)
        #expect(WineDatabase.shared.entries.filter { EntryFilter.type("Dual").matches($0) }.isEmpty)

        #expect(EntryFilter.styleColor(.red).chipOption?.facet == .styleColor)
        #expect(EntryFilter.styleColor(.dual).chipOption?.facet == .styleColor)

        #expect(EntryFilter.tasting("SWEET").chipOption?.facet == .flavorClass)
        #expect(EntryFilter.tasting("SWEET").chipOption?.value == "SWEET")
        #expect(EntryFilter.flavorSubclass("BERRY").chipOption?.facet == .flavorSubclass)
        // The row's label unpicks the stored spelling, as the chip row does.
        #expect(EntryFilter.flavorSubclass("STONE_FRUIT").chipOption?.label == "STONE FRUIT")
        #expect(EntryFilter.rarity(.noble).chipOption?.facet == .rarity)
        #expect(EntryFilter.system("ORIGIN").chipOption?.facet == .styleClass)
        #expect(EntryFilter.climate(.cool).chipOption?.facet == .climate)

        // The two that are not chips, and keep the scans they always had.
        #expect(EntryFilter.region(["France"]).chipOption == nil)
        #expect(EntryFilter.region(["France"]).scanTitle == "SECTOR SCAN")
        #expect(EntryFilter.soil("Limestone").chipOption == nil)
        #expect(EntryFilter.soil("Limestone").scanTitle == "GEOLOGY SCAN")
        #expect(EntryFilter.origin("France").chipOption == nil)
        #expect(EntryFilter.origin("France").scanTitle == "REGION SCAN")

        // **The backlog is closed (0.8.9a, A5), and it took a drawing.**
        // 0.8.5's B1 left four scans with no drawn marquee face — GEOLOGY,
        // RARITY, SYSTEM and CLIMATE. Three of them stopped being scans in C1
        // and took the magnifier that was already on disk, which retired the
        // names without drawing anything; GEOLOGY was the one that actually
        // needed a rock, and the 0.8.9 drop has one.
        //
        // **Pinned at zero rather than deleted**, and the direction that
        // matters is the one this now fails in: a filter kind added without a
        // marquee face fails here, where before it would merely have joined a
        // backlog that had a documented member and therefore looked healthy.
        // That is the same reason `undrawnStampStems` is kept at zero entries
        // instead of removed.
        let artless = Self.allFilters.filter { $0.marqueeArt == nil }
        #expect(artless.isEmpty, "artless scans: \(artless.map(\.scanTitle))")
        #expect(EntryFilter.soil("Limestone").marqueeArt == "marquee-soilscan")
        // FILTER SEARCH stops borrowing MASTER SEARCH's glass. The chip branch
        // is an early return over eight of the ten kinds, so one of them
        // standing for the rest is the whole of it.
        #expect(EntryFilter.rarity(.noble).marqueeArt == "marquee-filtersearch")
    }

    /// **Every chip a filter names must be a chip the row actually offers.**
    ///
    /// `chipOption` builds an option from the filter's value, and a value no
    /// facet lists would light a chip the user can neither see nor clear while
    /// emptying the list under it. `EncyclopediaListScreen` guards that at the
    /// seam; this is the same check where a test can reach it, over the values
    /// the cross-linked tiles genuinely send.
    @Test("a pre-selected chip is one its facet offers")
    func presetChipsAreOffered() {
        for (filter, _) in Self.liveCrossLinks {
            guard let option = filter.chipOption else {
                Issue.record("\(filter) should be a chip")
                continue
            }
            #expect(
                ChipFilter.options(for: option.facet).contains(option),
                "\(option.facet) offers no chip for \(option.value)"
            )
        }
    }

    /// Every filter a cross-linked tile can actually build, paired with the
    /// category that tile pushes into.
    ///
    /// Enumerated from the catalog rather than sampled, which is the lesson
    /// `bodyFromText` cost: Cabernet Sauvignon was the only grape pinned
    /// anywhere and it sat on the correct side of a broken branch for two
    /// releases. What breaks in this area is a *branch* — one arm of a
    /// value-dependent derivation — so the set is what has to be walked.
    static var liveCrossLinks: [(EntryFilter, EntryCategory)] {
        var live: [(EntryFilter, EntryCategory)] = [
            (.type("red"), .grapes), (.type("white"), .grapes),
            (.system("ORIGIN"), .styles), (.system("METHOD"), .styles),
        ]
        live += RarityLabel.allCases.map { (EntryFilter.rarity($0), EntryCategory.grapes) }
        live += ClimateClass.allCases.map { (EntryFilter.climate($0), EntryCategory.regions) }
        // The grape body tile: every style the catalog carries (0.8.8, C1).
        live += WineDatabase.shared.grapeStyles.map { (EntryFilter.type($0), EntryCategory.grapes) }
        for entry in WineDatabase.shared.entries {
            switch entry {
            case .flavor(let flavor):
                live.append((.tasting(flavor.details.classification), .flavors))
                live.append((.flavorSubclass(flavor.details.subclass), .flavors))
            // The style COLOR tile, over every style in the catalog.
            case .style(let style):
                live.append((.styleColor(EntryDisplay.colorType(name: style.common.name)), .styles))
            default:
                continue
            }
        }
        return live
    }

    /// **The invariant the whole conversion rests on: a lit chip shows the list
    /// the filter showed, and turning it off widens the list.**
    ///
    /// `EncyclopediaListScreen` hands the constraint from `EntryQuery.filter` to
    /// the chip row on arrival and then drops the query filter, so the chip is a
    /// control the user can switch off rather than a decoration over an
    /// unremovable filter. That exchange is only sound where the two select the
    /// same entries, and "the same entries" is a claim about the shipped
    /// catalog that no amount of reading the code establishes — 0.8.7 chose
    /// correctly *against* converting the body tile on exactly this basis, and
    /// 0.8.8 converts it only because a facet now exists that measures identical.
    ///
    /// Two halves, and the second is what a set-equality check alone would miss:
    ///
    /// 1. **Same set.** The filtered listing equals the chip-filtered listing,
    ///    entry for entry, in the category the tile pushes into.
    /// 2. **Not everything.** The chip must actually narrow — a chip whose result
    ///    set is the whole category is a control that appears to do nothing, and
    ///    that is precisely what `.type("Dual")` was until C1 removed it: it lit,
    ///    it claimed DUAL, and it returned all 177 grapes.
    @Test("a lit chip reproduces the filtered listing, and narrows it")
    func chipsReproduceTheirFilters() {
        let db = WineDatabase.shared
        for (filter, category) in Self.liveCrossLinks {
            guard let option = filter.chipOption else { continue }
            let byFilter = db.entries(
                matching: EntryQuery(categories: [category], filter: filter)
            )
            var chips = ChipFilter()
            chips.toggle(option)
            let byChip = db.entries(matching: EntryQuery(categories: [category]))
                .filter { chips.matches($0) }

            #expect(
                byFilter.map(\.id) == byChip.map(\.id),
                """
                \(filter) and \(option.facet):\(option.value) disagree in \(category.rawValue) — \
                filter \(byFilter.count), chip \(byChip.count)
                """
            )
            let whole = db.entries(matching: EntryQuery(categories: [category])).count
            #expect(!byFilter.isEmpty, "\(filter) lands on an empty \(category.rawValue) listing")
            #expect(
                byFilter.count < whole,
                "\(filter) selects the whole of \(category.rawValue) — the chip cannot be turned off"
            )
        }
    }

    /// Catches a route added to the enum and never listed above — without which
    /// `glyphsAreDistinct` would silently stop covering it.
    ///
    /// Counted rather than derived because `DexRoute` cannot be `CaseIterable`.
    /// Bump the number *and* add the route to `allRoutes` together.
    @Test("the route list covers the whole enum")
    func routeListIsComplete() {
        // 22 simple + 5 categories + 5 settings sections = 32. **32 again in
        // 0.7.5 (E1)**, which adds `.lineage` — a grape's pedigree tree, pushed
        // from its scan. Was 31 earlier in the same version (B1), which retired
        // `SettingsSection.packs`: the cartridge
        // shelf moved into the shop, so it no longer needs a section of its own
        // to earn a marquee title and a glyph. Was 32 from 0.7.3c, which added
        // that section — it arrived on this list through
        // `SettingsSection.allCases` below and `glyphsAreDistinct` picked up its
        // `shippingbox.fill` for free; the shop's own `bag.fill` (B2, replacing
        // `lock.fill`) is covered the same way. Was 28 until
        // 0.7.3b listed `.firmwareHistory` and `.cheatConsole` — both added to
        // the enum by 0.7.3a and neither added here, so for one sub-batch the
        // uniqueness gate below could not see them — and added `.deviceWorkshop`
        // beside them. 28 since 0.7.2 (LR1) added `.labelReader`; 28 before that
        // until 0.7.1 (A1) retired `.masterSearch`, whose title `.chipFilter` now
        // carries.
        //
        // **A count is a weak gate and stays a count.** It fails only when
        // somebody bumps the enum *and* the number without touching the list,
        // which is a harder mistake to make than forgetting the list entirely —
        // and `DexRoute` carries associated values, so it cannot be
        // `CaseIterable` and there is nothing to derive from.
        // 34 since 0.8.6 (C3), which adds `.stampCollection` — the stamp series
        // as a page of objects rather than as the passport's tick list.
        // **36 since 0.8.91**, which adds `.recommendations` (B3, the full
        // ranking behind the passport's capped YOU MIGHT LIKE strip) and
        // `.support` (F1, the contact screen behind SYSTEM's new SUPPORT row).
        #expect(Self.allRoutes.count == 36, "add the new route to `allRoutes`")
    }

    // MARK: The shared glyph constants (0.7.0 D1, 0.7.1 E1/A2)

    /// D1 asked for the fire icon to change *everywhere it is used*, and E1
    /// asked for it to stop being fire at all. The way either became checkable
    /// is that there is one place; this asserts the route table reads it rather
    /// than carrying its own literal, which is the exact failure D1 was fixing
    /// (the marquee showed a `calendar`).
    @Test("the daily challenge wears the shared challenge glyph")
    func dailyChallengeUsesTheSharedConstant() {
        #expect(DexRoute.dailyChallenge.marqueeSymbol == DexGlyph.challenge)
        // E1/E2: no fire anywhere on the challenge, in any of its forms. The
        // catalog's own `lucide:flame` is a different icon on a different
        // subject and is untouched.
        #expect(!DexGlyph.challenge.contains("flame"), "E1 asked for the fire to go")
    }

    // MARK: The marquee's lamp buttons (0.7.6, A1)

    /// **Every pin resolves to a route on the table above**, which is what makes
    /// the lamps subject to `glyphsAreDistinct` for free: a pin draws its
    /// destination's glyph, and that glyph has already been proved unique against
    /// every other page in the app.
    ///
    /// It is worth being explicit that this is the property A1 needs. The lamps
    /// used to carry two hardcoded `DexRoute`s; they now carry whatever the user
    /// assigned, so "the button's mark matches where it goes" stopped being
    /// something a reader could check by eye and became something a gate has to.
    @Test("every marquee pin lands on a real route, wearing its glyph")
    func pinsResolveToRoutes() {
        for pin in MarqueePin.allCases {
            #expect(
                Self.allRoutes.contains(pin.route),
                "\(pin.rawValue) routes somewhere `allRoutes` does not list"
            )
            #expect(pin.symbol == pin.route.marqueeSymbol)
            #expect(pin.displayName == pin.route.title)
            // 0.8.3's H puts the drawn face on the lamp. Same property as the
            // symbol above, and it has to hold for the same reason: a lamp that
            // wore one destination's picture and landed on another is exactly
            // what routing both through the pin is meant to make impossible.
            //
            // **Equality became a prefix in 0.8.4 (A1)**, and the failure this
            // replaces is the one worth recording: `MarqueePin.artStem` read
            // `DexRoute.minigames.marqueeArt` for its TOOLS fallback, so
            // repointing the marquee table at the new dot-matrix drop silently
            // moved a *chassis lamp* onto art drawn for a lit LCD panel. The
            // test caught it, which is the whole reason it asserts the pairing
            // rather than trusting one expression to serve both.
            //
            // The two are still the same subject and must still name the same
            // picture — the lamp above the panel and the glyph on it are the
            // same page — so what is checked is that the marquee's stem is this
            // one with the drop's prefix. A lamp that wandered onto a different
            // page's face fails exactly as before.
            let stem = pin.artStem
            #expect(stem != nil, "\(pin.rawValue) has no drawn face; the lamp would fall back")
            #expect(
                pin.route.marqueeArt == stem.map { "marquee-" + $0 },
                "\(pin.rawValue)'s lamp shows '\(stem ?? "-")' and its page shows '\(pin.route.marqueeArt ?? "-")'"
            )
        }
    }

    // MARK: Marquee art (0.8.3, A/H)

    /// **Every stem the marquee can ask for is a file on disk.**
    ///
    /// The gate this repo has needed three times. `PixelArtLoader.image` returns
    /// nil in silence, so a stem typed wrong here does not fail, does not warn,
    /// and does not blank the panel — it quietly falls back to the SF Symbol
    /// that was there before, which is *the same picture the marquee showed in
    /// 0.8.2*. There is no state of the running app that distinguishes "the
    /// conversion has not reached this route" from "the conversion reached it
    /// and the string is wrong". Only this does.
    ///
    /// Reached through `#filePath` like `CartridgeArtTests` and
    /// `ArtPipelineRosterTests`: the source art is the authority and it is not
    /// in the bundle at test time.
    /// Stems drawn in `art/icons/<components>`, as bare filenames.
    ///
    /// **Variadic since 0.8.9a (A1).** The registers are two deep now —
    /// `entries/` for art *of* what the catalog names, `chrome/` for the
    /// device's own furniture — so a caller names the path rather than one
    /// folder. See `art/icons/README.md` for the split.
    private static func artOnDisk(_ components: String...) throws -> Set<String> {
        var dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("art")
            .appendingPathComponent("icons")
        for component in components { dir.appendPathComponent(component) }
        return Set(
            try FileManager.default.contentsOfDirectory(atPath: dir.path)
                .filter { $0.lowercased().hasSuffix(".png") }
                .map { String($0.dropLast(4)) }
        )
    }

    /// **Two drops, two directories, and the split is 0.8.4's A1.**
    ///
    /// Through 0.8.3 both halves of this test read `art/icons/buttons`, because
    /// the marquee wore the same files its controls did. A1 gives the panel its
    /// own dot-matrix set and the two now diverge by *surface*: a page glyph on
    /// a lit segment LCD comes from `chrome/marquee`, and a moulded lamp on the
    /// chassis stays on `chrome/buttons` with the rest of the hardware.
    ///
    /// The `marquee-` prefix is `import-marquee-art.py`'s and is stripped here,
    /// which also makes this the gate on the prefix itself: a stem that forgets
    /// it fails with the name it actually has.
    @Test("every marquee art stem names art that exists")
    func marqueeArtIsOnDisk() throws {
        let glyphs = try Self.artOnDisk("chrome", "marquee")
        let buttons = try Self.artOnDisk("chrome", "buttons")
        #expect(!glyphs.isEmpty, "art/icons/chrome/marquee is empty — is the checkout complete?")
        #expect(!buttons.isEmpty, "art/icons/chrome/buttons is empty — is the checkout complete?")

        let prefix = "marquee-"
        func check(_ stem: String, _ who: String) {
            #expect(
                stem.hasPrefix(prefix),
                "\(who) names marquee art '\(stem)' without the \(prefix) prefix"
            )
            let bare = String(stem.dropFirst(prefix.count))
            #expect(glyphs.contains(bare), "\(who) names marquee art '\(bare)' that is not on disk")
        }

        for route in Self.allRoutes {
            guard let stem = route.marqueeArt else { continue }
            check(stem, route.title)
        }
        for category in EntryCategory.allCases {
            guard let stem = category.marqueeArt else { continue }
            check(stem, "\(category)")
        }
        // The nine filter kinds (0.8.5, B1). They answer for the *title* of a
        // filtered listing, which is where this gate was needed and did not
        // reach: STYLE SCAN is `.type`'s title, not the styles listing's, and
        // it went three releases with no drawn glyph while a `marquee-stylescan`
        // sat on disk. A stem typed wrong here fails exactly as a route's does.
        for filter in Self.allFilters {
            guard let stem = filter.marqueeArt else { continue }
            check(stem, filter.scanTitle)
        }
        for section in SettingsSection.allCases {
            check(section.marqueeStem, "\(section.rawValue) (marqueeStem)")
        }
        // The lamps are chassis furniture and stayed on the button faces — see
        // `MarqueePin.artStem`, where the literal that keeps them there is
        // spelled out. Checked against the *other* directory on purpose: this
        // is the assertion that would have caught the borrowed expression the
        // day A1 repointed `DexRoute.marqueeArt` underneath it.
        for pin in MarqueePin.allCases {
            guard let stem = pin.artStem else { continue }
            #expect(
                buttons.contains(stem),
                "\(pin.rawValue) names button art '\(stem)' that is not on disk"
            )
        }
    }

    /// **K2 rule 1, in the weaker form 0.8.4 leaves it in.**
    ///
    /// 0.8.1's drop let "a page's glyph is the glyph on the control that opens
    /// it" be asserted as *one file used twice*, which is the strongest reading
    /// the rule has ever had here. A1 supplies a second drop drawn for the
    /// marquee alone, so that reading is gone and the honest claim is about
    /// subject: a page's marquee glyph is the same *picture* as its control's,
    /// drawn for a lit panel instead of for moulded plastic.
    ///
    /// A pairing test rather than a spelling one, then — the stems below are
    /// asserted against the control's stem with the prefix applied, which is
    /// exactly as far as the claim goes. Where the two drops disagree on a word,
    /// the disagreement is stated here rather than computed away.
    ///
    /// Deliberately *not* asserting that art stems are distinct the way
    /// `glyphsAreDistinct` asserts symbols are. The art repeats on purpose — a
    /// category listing and that category's detail pages share a face, the globe
    /// and the world search share one, and SHOP and PACKS share one — which is
    /// the same documented exemption `glyphsAreDistinct` carries and the reason
    /// `marqueeArt` had to be a table separate from `marqueeSymbol` rather than
    /// a rename of it.
    @Test("the marquee's faces are its controls' faces, drawn for the panel")
    func marqueeArtFollowsItsControl() {
        // The four main-menu tiles. Three of the four are the *scan* spelling
        // in the marquee drop and the bare word on the tile, which is the drop's
        // own vocabulary and not a mismatch: what the panel names is the page.
        #expect(EntryCategory.grapes.marqueeArt == "marquee-grapescan")
        #expect(EntryCategory.regions.marqueeArt == "marquee-regions")
        #expect(EntryCategory.styles.marqueeArt == "marquee-stylescan")
        #expect(EntryCategory.flavors.marqueeArt == "marquee-flavorscan")
        // Both stopped being nil in 0.8.4: the button drop drew no world and
        // this one does.
        #expect(EntryCategory.continents.marqueeArt == "marquee-continentscan")
        #expect(DexRoute.globe.marqueeArt == "marquee-globescan")
        // A filtered listing is not its category (K2, rule 2), so it does not
        // borrow the category's picture either.
        #expect(DexRoute.list(category: .regions, filter: nil).marqueeArt == "marquee-regions")
        #expect(
            DexRoute.list(category: .regions, filter: .soil("Limestone")).marqueeArt
                == "marquee-soilscan"
        )
        // **The passport and its collection are two pictures now (0.8.9a,
        // A6).** 0.8.6's C3 shared one because nobody had drawn a stamp for
        // this surface; the drop has one, and a repeat that art permits is not
        // a repeat art prefers.
        #expect(DexRoute.stampCollection.marqueeArt == "marquee-stamps")
        #expect(DexRoute.passport.marqueeArt == "marquee-passport")
        // The SETTINGS grid owns both tables and this defers to the marquee one
        // rather than restating five strings.
        for section in SettingsSection.allCases {
            #expect(DexRoute.settingsSection(section).marqueeArt == section.marqueeStem)
            // And the two drops agree on the word, for all five. Stated as a
            // check rather than as a computation: `marqueeStem` is allowed to
            // diverge from `artStem`, and the day one does, this is what says so.
            #expect(section.marqueeStem == "marquee-" + (section.artStem ?? ""))
        }
        // **The 0.8.3 collision, resolved.** In the button drop the route titled
        // SYSTEM had to take the `settings` face, because that drop's `system`
        // picture was the chassis cog. The marquee drop has both, so SYSTEM
        // takes `system` and SETTINGS takes `settings`.
        #expect(DexRoute.settings.marqueeArt == "marquee-system")
        #expect(DexRoute.settingsSection(.settings).marqueeArt == "marquee-settings")
        // C1: PACKS wears the shop's picture and its own symbol. Both halves,
        // because the pair is the item — the same glyph, a distinguishable page.
        #expect(DexRoute.pack(id: "x").marqueeArt == SettingsSection.access.marqueeStem)
        #expect(DexRoute.pack(id: "x").marqueeSymbol != DexRoute.settingsSection(.access).marqueeSymbol)
        #expect(DexRoute.pack(id: "x").title == "PACKS")
    }

    /// The two lamps the device ships with are the two 0.7.2's A9 hardwired.
    /// Pinned because A1's whole claim is that it adds customisation without
    /// changing what an untouched device does.
    @Test("the factory pins are TOOLS and CUSTOMIZE")
    func factoryPinsAreUnchanged() {
        #expect(QuickPinStore.defaults == [.tools, .customization])
        #expect(QuickPinStore.defaults.count == QuickPinStore.capacity)
        #expect(MarqueePin.tools.route == .minigames)
        #expect(MarqueePin.customization.route == .settingsSection(.customization))
    }

    /// A2: one magnifying glass, and every search affordance reads it.
    ///
    /// The UI is where the glyph is drawn, so no Linux gate can see a stray
    /// literal on a button — but the two search *routes* are Core, and this
    /// pins the rule that the app's search wears `DexGlyph.search` while the
    /// world search deliberately does not (it is a search of places, and
    /// `glyphsAreDistinct` above would fail if both claimed the magnifier).
    @Test("master search wears the one magnifier")
    func searchGlyphIsUnified() {
        #expect(DexGlyph.search == "magnifyingglass")
        #expect(DexRoute.chipFilter.marqueeSymbol == DexGlyph.search)
        #expect(DexRoute.chipFilter.title == "MASTER SEARCH")
        #expect(DexRoute.globeSearch.marqueeSymbol != DexGlyph.search)
        // E3/A2 together: the blind tasting left the magnifier family, so no
        // second glyph in the app can be mistaken for the search.
        #expect(!DexRoute.scanner.marqueeSymbol.contains("magnifyingglass"))
        #expect(DexRoute.scanner.title == "BLIND TASTING")
    }

    // MARK: Page room (J1/J2/J3)

    /// The property the whole of J rests on: **where the page is tightest, the
    /// growth is zero**, so every call site resolves to the number that shipped
    /// in 0.6.9 and the fit verified then is the floor case of the new
    /// arithmetic rather than a separate case to re-check.
    ///
    /// "Tightest" is the shortest supported LCD at the largest text step. 0.6.9's
    /// K2 note puts that LCD at roughly 350pt (its dial "comes out around 105pt"
    /// at a 0.30 fraction); 391 is where `floorUnits` puts the HUGE cutoff, and
    /// the margin between them is the point. If this ever fails, three fixed
    /// pages have started overflowing an LCD that clips rather than scrolls, and
    /// nothing else in the project would notice.
    @Test("the tightest page gets no growth")
    func tightestPageDoesNotGrow() {
        for height in stride(from: 200.0, through: 390.0, by: 10.0) {
            #expect(
                PageRoom.growth(pageHeight: height, step: .huge) == 0,
                "\(height)pt at HUGE grew"
            )
        }
        // And the shortest LCD 0.6.9 measured, at every step, must stay within
        // the slack its own text size frees up — never near the full budget.
        #expect(PageRoom.growth(pageHeight: 350, step: .huge) == 0)
        #expect(PageRoom.growth(pageHeight: 350, step: .large) < 0.2)
        #expect(PageRoom.growth(pageHeight: 350, step: .small) < 0.4)
    }

    @Test("growth is bounded, monotonic in height, and inverse in text size")
    func growthIsWellBehaved() {
        for step in TextScale.allCases {
            var previous = -1.0
            for height in stride(from: 0.0, through: 900.0, by: 25.0) {
                let g = PageRoom.growth(pageHeight: height, step: step)
                #expect(g >= 0 && g <= 1, "\(g) out of range")
                #expect(g >= previous, "growth fell as the page got taller")
                previous = g
            }
        }
        // Larger text must never buy *more* room — that is the axis 0.6.9's K2
        // found was the one actually breaking the fixed pages.
        let tall = 480.0
        #expect(
            PageRoom.growth(pageHeight: tall, step: .huge)
                < PageRoom.growth(pageHeight: tall, step: .small)
        )
    }

    @Test("a zero or negative page height is not a growth opportunity")
    func degeneratePageHeights() {
        #expect(PageRoom.growth(pageHeight: 0, step: .large) == 0)
        #expect(PageRoom.growth(pageHeight: -100, step: .large) == 0)
    }
}
