import Foundation

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
            "SCANNER"
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
    public var marqueeSymbol: String {
        switch self {
        case .list(let category, _):
            category.marqueeSymbol
        case .masterSearch:
            "magnifyingglass"
        // A fallback: detail titles come from the entry, and so does the
        // symbol — see `WineEntry.scanSymbol`.
        case .detail:
            "viewfinder"
        case .globe:
            "globe.americas.fill"
        case .globeSearch:
            "magnifyingglass"
        case .bookmarks:
            "bookmark.fill"
        case .country:
            "map.fill"
        case .state:
            "mappin.and.ellipse"
        case .dailyGrape:
            "questionmark.diamond.fill"
        case .scanner:
            "viewfinder"
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
        case .wsetQuiz:
            "graduationcap.fill"
        case .dailyChallenge:
            "calendar"
        case .passport:
            "book.closed.fill"
        case .walkthrough:
            "figure.walk"
        case .continent:
            "globe.americas.fill"
        }
    }
}

public extension EntryCategory {
    /// The category's marquee glyph — see `DexRoute.marqueeSymbol`.
    var marqueeSymbol: String {
        switch self {
        case .grapes: "leaf.fill"
        case .regions: "map.fill"
        case .styles: "wineglass.fill"
        case .flavors: "sparkles"
        case .continents: "globe.americas.fill"
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
