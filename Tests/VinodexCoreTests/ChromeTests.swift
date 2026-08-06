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
            .dailyGrape,
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
        #expect(Self.allRoutes.count == 32, "add the new route to `allRoutes`")
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
            #expect(pin.artStem == pin.route.marqueeArt)
            #expect(pin.artStem != nil, "\(pin.rawValue) has no drawn face; the lamp would fall back")
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
    @Test("every marquee art stem names a drawn button face")
    func marqueeArtIsOnDisk() throws {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("art")
            .appendingPathComponent("icons")
            .appendingPathComponent("buttons")
        let onDisk = Set(
            try FileManager.default.contentsOfDirectory(atPath: dir.path)
                .filter { $0.lowercased().hasSuffix(".png") }
                .map { String($0.dropLast(4)) }
        )
        #expect(!onDisk.isEmpty, "art/icons/buttons is empty — is the checkout complete?")

        for route in Self.allRoutes {
            guard let stem = route.marqueeArt else { continue }
            #expect(onDisk.contains(stem), "\(route.title) names button art '\(stem)' that is not on disk")
        }
        for category in EntryCategory.allCases {
            guard let stem = category.marqueeArt else { continue }
            #expect(onDisk.contains(stem), "\(category) names button art '\(stem)' that is not on disk")
        }
        for pin in MarqueePin.allCases {
            guard let stem = pin.artStem else { continue }
            #expect(onDisk.contains(stem), "\(pin.rawValue) names button art '\(stem)' that is not on disk")
        }
    }

    /// **K2 rule 1, now literally checkable.** "A page's glyph is the glyph on
    /// the control that opens it" could only ever be asserted between two SF
    /// Symbol tables before; the drop makes it a claim about one file being used
    /// twice, and these are the pairs where both ends are in Core.
    ///
    /// Deliberately *not* asserting that art stems are distinct the way
    /// `glyphsAreDistinct` asserts symbols are. The art repeats on purpose — a
    /// category listing and that category's detail pages share a face, which is
    /// the same documented exemption `glyphsAreDistinct` carries and the reason
    /// `marqueeArt` had to be a table separate from `marqueeSymbol` rather than
    /// a rename of it.
    @Test("the marquee's faces are the faces on the controls that open the pages")
    func marqueeArtFollowsItsControl() {
        // The four main-menu tiles.
        #expect(EntryCategory.grapes.marqueeArt == "grapes")
        #expect(EntryCategory.regions.marqueeArt == "regions")
        #expect(EntryCategory.styles.marqueeArt == "styles")
        #expect(EntryCategory.flavors.marqueeArt == "flavors")
        // No face draws a world; the globe keeps its symbol.
        #expect(EntryCategory.continents.marqueeArt == nil)
        #expect(DexRoute.globe.marqueeArt == nil)
        // A filtered listing is not its category (K2, rule 2), so it does not
        // borrow the category's picture either.
        #expect(DexRoute.list(category: .regions, filter: nil).marqueeArt == "regions")
        #expect(DexRoute.list(category: .regions, filter: .soil("Limestone")).marqueeArt == nil)
        // The SETTINGS grid owns its own table and this defers to it rather
        // than restating five strings.
        for section in SettingsSection.allCases {
            #expect(DexRoute.settingsSection(section).marqueeArt == section.artStem)
        }
        // The collision `SettingsSection.artStem` documents from the other
        // side: the route *titled* SYSTEM is `.settings` and takes `settings`;
        // the drop's `system` face belongs to the chassis cog.
        #expect(DexRoute.settings.marqueeArt == "settings")
        #expect(DexRoute.settingsSection(.settings).marqueeArt == "settings")
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
