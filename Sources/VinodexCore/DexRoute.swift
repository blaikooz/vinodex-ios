import Foundation

/// Glyphs that more than one screen has to agree on.
///
/// **Why this exists (0.7.0, D1).** The streak flame was the literal
/// `"flame.fill"` typed out in five places — the TOOLS tile, the saved-entries
/// streak row, the passport badge, the quiz result and the back-plate stamp's
/// fallback — with the marquee showing a `calendar` instead. D1 asks for a
/// different fire icon *everywhere it is used*, and the only way to make
/// "everywhere" checkable is for there to be one place. A new surface that wants
/// the flame reads this and is correct by default.
///
/// In Core rather than VinodexUI because `BackPlateStamps` and `DexRoute` both
/// need it and neither can see the UI module.
public enum DexGlyph {
    /// The daily-challenge / streak fire.
    ///
    /// `flame.circle.fill` rather than `flame.fill`: the disc reads at the
    /// marquee glyph's size and at the 10pt streak row alike, where the bare
    /// flame's tapering tip disappeared, and it is unmistakably a *different*
    /// fire icon, which is what was asked for. SF Symbols 3 / iOS 15, so it
    /// clears the iOS 17 floor — see KNOWN-ISSUES on symbols that render blank
    /// rather than failing to compile.
    public static let streakFlame = "flame.circle.fill"
}

/// One group of settings, each with its own panel.
///
/// The settings screen is a grid of these rather than one long scroll: the
/// toggles had grown past a screenful, and the two a user actually reaches for
/// were below the developer-facing ones.
///
/// SCREEN, TEXT and SKIN used to be three tiles. They are one CUSTOMIZE tile
/// now: all three answer the same question — what the device looks like — and
/// splitting them meant three taps to try a colourway against a screen mode,
/// with a trip back to the grid between each. Their panels were also the three
/// shortest in the app, so a combined one still fits a screenful.
///
/// The raw values are display copy, not storage: no `SettingsSection` is
/// persisted anywhere, so CUSTOMIZATION could simply be shortened to CUSTOMIZE
/// — thirteen characters was the longest label on the grid and the only one
/// that had to shrink to fit its square.
public enum SettingsSection: String, CaseIterable, Hashable, Sendable, Identifiable {
    case customization = "CUSTOMIZE"
    /// Device behaviour rather than device looks: text size, haptics, and the
    /// stored-data reset. Split from CUSTOMIZE so that panel stays purely
    /// cosmetic — a wipe button between two colour pickers is a trap.
    case settings = "SETTINGS"
    /// What the database actually holds. Read-only, unlike everything else
    /// here — it is a readout rather than a setting, but the settings grid is
    /// where a user goes looking for "what is in this thing".
    case data = "DATA"
    case access = "ACCESS"
    case dev = "DEV"

    public var id: String { rawValue }

    /// SF Symbol for the grid tile. All iOS 17-safe — see KNOWN-ISSUES on
    /// symbols with a later OS floor rendering blank rather than failing.
    public var symbol: String {
        switch self {
        case .customization: "paintpalette.fill"
        case .settings: "slider.horizontal.3"
        case .data: "chart.bar.fill"
        case .access: "lock.fill"
        case .dev: "ladybug.fill"
        }
    }
}

/// A destination on the navigation stack.
///
/// Filters travel as associated values rather than the web app's stringly-typed
/// `filterMode` / `filterValue` query-parameter pair, so an unrepresentable
/// combination cannot be constructed.
///
/// `detail` carries an id rather than a whole entry: routes are hashed on every
/// navigation change, and hashing a full entry graph for that is wasteful.
public enum DexRoute: Hashable, Sendable {
    case list(category: EntryCategory, filter: EntryFilter?)
    /// A plain text search over the whole database.
    ///
    /// **Unreachable from the UI since 0.7.0 (I1)**, and deliberately left
    /// standing. I1 points the main menu's round button — this route's only
    /// entry — at `.chipFilter` instead, and removes FILTER SEARCH from the
    /// tools shelf, so there is nowhere left that pushes this. That is the
    /// spec's intent rather than an oversight: `ChipFilterScreen` runs the very
    /// same `EntryQuery.masterSearch(_:)` behind its own field, so the filter
    /// search is a strict superset of this screen and shipping both would be
    /// two doors onto one room.
    ///
    /// The route and its screen stay because *deleting a working screen was not
    /// what was asked*, and re-linking it is one line if the answer changes.
    /// `EntryQuery.masterSearch(_:)` in `EntryFilter.swift` is a different thing
    /// with the same name — the query itself — and is very much still in use.
    case masterSearch
    case detail(entryID: String)
    case globe
    /// Place search: continents and regions, which between them carry the
    /// country and state names too. Its own screen rather than an overlay on
    /// the globe — results floating over a spinning sphere read as a glitch.
    case globeSearch
    /// Saved entries — see `BookmarkStore`.
    case bookmarks
    /// A country's page: its regions, and its states where it has any.
    /// Assembled from region origins rather than a data entry, since
    /// COUNTRY_GATE is not ported.
    case country(name: String)
    /// The regions of one state within a country.
    case state(name: String)
    /// The daily reveal — see `DailyPick`. Named "WHAT'S THAT…?" rather than
    /// "grape of the day" since the pick rotates through regions and styles too.
    case dailyGrape
    /// The guided grape identifier — colour, body, origin and flavours, then a
    /// deduction. See `GrapeScanCriteria`.
    case scanner
    /// The biodynamic day readout — see `MoonCalendar`.
    case moonDial
    /// System settings. A pushed screen rather than a side flap: the flap
    /// could never be more than a strip wide, and the toggles want room.
    /// Now a grid of `SettingsSection` tiles rather than the toggles themselves.
    case settings
    /// One settings group's toggles. A real route, not local state in the panel,
    /// so the chassis Back button returns to the settings grid instead of
    /// dropping the user out of settings entirely.
    case settingsSection(SettingsSection)
    /// The tools hub — games *and* instruments.
    ///
    /// Called MINIGAMES while everything on it was a game. It now also holds the
    /// chip filter, which is a search tool with no play in it at all, and
    /// "minigames" was the wrong promise for a shelf you go to in order to get
    /// work done. The case keeps its name because nothing persists it; only the
    /// label moved.
    case minigames
    /// Filter the whole database by tapping chips — colour, body, rarity, type,
    /// climate — with a live count of what survives. See `ChipFilter`.
    case chipFilter
    /// The WSET-style tasting quiz: one question, four answers, then the entry
    /// behind the right one. Three tiers — see `QuizTier`.
    case wsetQuiz
    /// The daily paper: five questions, everyone gets the same ones, one
    /// sitting per day. What the streak hangs off — see `StreakStore`.
    case dailyChallenge
    /// The tried shelf's stats page — see `Passport`.
    case passport
    /// The guided tour. Opt-in from the settings grid, never shown unasked.
    case walkthrough
    /// The continent info screen — INFO blurb plus a COUNTRIES list, each
    /// linking to that country's regions. Reached from the globe markers.
    case continent(entryID: String)

    public var title: String {
        switch self {
        case .list(let category, let filter):
            filter?.scanTitle ?? category.listTitle
        case .masterSearch:
            "MASTER SEARCH"
        case .detail:
            "SCAN"
        case .globe:
            "GLOBE SCAN"
        case .globeSearch:
            "WORLD SEARCH"
        case .bookmarks:
            "SAVED"
        // The scan-family label (v0.5.8, D3) — the page's own hero already
        // names the country, so the marquee names the *kind* of page, like
        // every other scan screen.
        case .country:
            "COUNTRY SCAN"
        case .state(let name):
            name.uppercased()
        case .dailyGrape:
            "WHAT'S THAT…?"
        case .scanner:
            // Renamed from SCANNER (0.7.0, I3) — the label only, per the same
            // convention `wsetQuiz` and `chipFilter` already follow: the case,
            // `ScannerScreen`, `ScannerBackRouter` and every `ScreenStateStore`
            // key keep their names, because those are vocabulary rather than
            // copy. On a device where every listing is a *scan*, SCANNER named
            // the wrong thing; this is the tool that identifies a glass.
            "IDENTIFY"
        case .moonDial:
            "MOON DIAL"
        case .settings:
            "SYSTEM"
        case .settingsSection(let section):
            section.rawValue
        case .minigames:
            "TOOLS"
        case .chipFilter:
            "FILTER SEARCH"
        case .wsetQuiz:
            // Renamed from TASTING QUIZ (v0.5.9, D1); the case keeps its name
            // — `wsetQuiz` is woven into `ScreenStateStore` keys.
            "WINE EXAM"
        case .dailyChallenge:
            "DAILY CHALLENGE"
        case .passport:
            "PASSPORT"
        case .walkthrough:
            "WALKTHROUGH"
        case .continent:
            "CONTINENT SCAN"
        }
    }

    /// SF Symbol shown between the marquee's text repetitions (v0.5.7) —
    /// `SYSTEM ⟨gear⟩ SYSTEM ⟨gear⟩ …`. Sits beside `title` because the two
    /// travel together into the footer. All iOS 17-safe — see KNOWN-ISSUES on
    /// symbols with a later OS floor rendering blank rather than failing.
    ///
    /// **Audited end to end in 0.7.0 (K2).** The table was written a route at a
    /// time as routes arrived, and by 0.6.9 a third of it was either generic or
    /// simply not this page's glyph. Three rules came out of going through all
    /// twenty-nine of them, and they are worth stating because the next route
    /// added here will need them:
    ///
    /// 1. **A page's glyph is the glyph on the control that opens it.** The
    ///    marquee confirms where you have arrived; showing something other than
    ///    what you just tapped is a small lie every time. Six entries disagreed
    ///    with their own tile.
    /// 2. **A filter is a page.** `.list` discarded its filter, so GEOLOGY,
    ///    RARITY and CLIMATE scans all wore their parent category's glyph. See
    ///    `EntryFilter.marqueeSymbol`.
    /// 3. **Collisions are only allowed where the pages really are the same
    ///    kind of page.** `map.fill` stood for the regions listing, a country
    ///    and a region detail; `globe.americas.fill` for four different world
    ///    screens; `sparkles` for both FLAVORS and the daily reveal. Those are
    ///    separated now by what the page actually is — the globe screen keeps
    ///    the globe, continents take `globe.europe.africa.fill`, a country takes
    ///    a flag.
    ///
    /// The remaining deliberate repeats are a category's glyph appearing on both
    /// its listing and its detail pages, which is `WineEntry.scanSymbol` agreeing
    /// with `EntryCategory.marqueeSymbol` on purpose.
    public var marqueeSymbol: String {
        switch self {
        // The filter's own glyph where there is one — a GEOLOGY SCAN is not a
        // regions listing wearing a map (K2, rule 2).
        case .list(let category, let filter):
            filter?.marqueeSymbol ?? category.marqueeSymbol
        case .masterSearch:
            "magnifyingglass"
        // A fallback: detail titles come from the entry, and so does the
        // symbol — see `WineEntry.scanSymbol`.
        case .detail:
            "viewfinder"
        case .globe:
            "globe.americas.fill"
        // Places, not text: this searches continents, countries and regions, and
        // the plain magnifier it shared with MASTER SEARCH said nothing about
        // which of the two searches you were in.
        case .globeSearch:
            "map.circle.fill"
        case .bookmarks:
            "bookmark.fill"
        // A country, not a map — `map.fill` is the regions listing's, and this
        // is the one screen whose subject is a nation.
        case .country:
            "flag.fill"
        case .state:
            "mappin.and.ellipse"
        // Matches the TOOLS tile that opens it (K2, rule 1).
        case .dailyGrape:
            "sparkles"
        // Matches its TOOLS tile, and frees `viewfinder` to be only the
        // unresolved-entry fallback above.
        case .scanner:
            "sparkle.magnifyingglass"
        case .moonDial:
            "moon.stars.fill"
        case .settings:
            "gearshape.fill"
        case .settingsSection(let section):
            section.symbol
        case .minigames:
            "wrench.and.screwdriver.fill"
        case .chipFilter:
            "line.3.horizontal.decrease.circle.fill"
        // Matches its TOOLS tile. `graduationcap.fill` was a reasonable glyph
        // for an exam and the wrong one for *this* exam.
        case .wsetQuiz:
            "checkmark.seal.fill"
        // The streak flame, which is what this page is. `calendar` was the only
        // hairline glyph in the table and it named the schedule rather than the
        // thing being kept. Through the constant, so D1 moved it here too.
        case .dailyChallenge:
            DexGlyph.streakFlame
        case .passport:
            "book.closed.fill"
        case .walkthrough:
            "figure.walk"
        // Not the globe: the globe screen is the globe, and a continent page is
        // one continent (K2, rule 3).
        case .continent:
            "globe.europe.africa.fill"
        }
    }
}

public extension EntryCategory {
    /// The category's marquee glyph — see `DexRoute.marqueeSymbol`.
    var marqueeSymbol: String {
        switch self {
        // The main menu's own GRAPES tile (K2, rule 1). `leaf.fill` was doubly
        // wrong: it is the glyph on the menu's *FLAVORS* tile, so tapping GRAPES
        // put the other category's icon on the marquee.
        case .grapes: "circle.grid.3x3.fill"
        case .regions: "map.fill"
        case .styles: "wineglass.fill"
        // The menu's FLAVORS tile, now that grapes no longer hold it.
        case .flavors: "leaf.fill"
        case .continents: "globe.europe.africa.fill"
        }
    }
}

public extension WineEntry {
    /// Where tapping this entry leads.
    ///
    /// The web app branches here for COUNTRY_GATE entries (drilling into states
    /// or regions). Those are out of scope for the starter, so every entry opens
    /// its detail readout — except continents, which open the dedicated
    /// ContinentScreen rather than the generic entry detail readout.
    var destination: DexRoute {
        if case .continent(let c) = self { return .continent(entryID: c.id) }
        return .detail(entryID: id)
    }

    /// Header title for the detail screen, matching the web app's scan titles.
    var scanTitle: String {
        switch self {
        case .grape: "GRAPE SCAN"
        case .region: "REGION SCAN"
        case .flavor: "FLAVOR SCAN"
        case .style: "STYLE SCAN"
        case .continent: "CONTINENT SCAN"
        }
    }

    /// Marquee glyph for the detail screen — the entry-level counterpart of
    /// `scanTitle`, same reasoning as `DexRoute.marqueeSymbol`.
    var scanSymbol: String {
        switch self {
        case .grape: EntryCategory.grapes.marqueeSymbol
        case .region: EntryCategory.regions.marqueeSymbol
        case .flavor: EntryCategory.flavors.marqueeSymbol
        case .style: EntryCategory.styles.marqueeSymbol
        case .continent: EntryCategory.continents.marqueeSymbol
        }
    }
}
