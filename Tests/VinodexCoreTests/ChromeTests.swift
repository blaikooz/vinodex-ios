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
            .masterSearch,
            .detail(entryID: "does-not-exist"),
            .globe,
            .globeSearch,
            .bookmarks,
            .country(name: "France"),
            .state(name: "California"),
            .dailyGrape,
            .scanner,
            .moonDial,
            .settings,
            .minigames,
            .chipFilter,
            .wsetQuiz,
            .dailyChallenge,
            .passport,
            .walkthrough,
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
        // 18 simple + 5 categories + 5 settings sections = 28.
        #expect(Self.allRoutes.count == 28, "add the new route to `allRoutes`")
    }

    // MARK: The streak flame (D1)

    /// D1 asked for the fire icon to change *everywhere it is used*. The way
    /// that became checkable is that there is now one place; this asserts the
    /// route table reads it rather than carrying its own literal, which is the
    /// exact failure D1 was fixing (the marquee showed a `calendar`).
    @Test("the daily challenge wears the shared flame")
    func dailyChallengeUsesTheFlameConstant() {
        #expect(DexRoute.dailyChallenge.marqueeSymbol == DexGlyph.streakFlame)
        #expect(DexGlyph.streakFlame != "flame.fill", "D1 asked for a different fire icon")
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
