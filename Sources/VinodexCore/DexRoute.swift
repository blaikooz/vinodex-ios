import Foundation

/// One group of settings, each with its own panel.
///
/// The settings screen is a grid of these rather than one long scroll: the
/// toggles had grown past a screenful, and the two a user actually reaches for
/// were below the developer-facing ones.
public enum SettingsSection: String, CaseIterable, Hashable, Sendable, Identifiable {
    case screen = "SCREEN"
    case text = "TEXT"
    case skin = "SKIN"
    case access = "ACCESS"
    case dev = "DEV"

    public var id: String { rawValue }

    /// SF Symbol for the grid tile. All iOS 17-safe — see KNOWN-ISSUES on
    /// symbols with a later OS floor rendering blank rather than failing.
    public var symbol: String {
        switch self {
        case .screen: "sun.max.fill"
        case .text: "textformat.size"
        case .skin: "paintpalette.fill"
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
    /// The daily grape reveal — see `DailyPick`.
    case dailyGrape
    /// System settings. A pushed screen rather than a side flap: the flap
    /// could never be more than a strip wide, and the toggles want room.
    /// Now a grid of `SettingsSection` tiles rather than the toggles themselves.
    case settings
    /// One settings group's toggles. A real route, not local state in the panel,
    /// so the chassis Back button returns to the settings grid instead of
    /// dropping the user out of settings entirely.
    case settingsSection(SettingsSection)
    /// The minigames hub. Grape of the day used to hang off the settings list;
    /// it is a game, not a setting, and there is now more than one of them.
    case minigames
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
        case .country(let name):
            name.uppercased()
        case .state(let name):
            name.uppercased()
        case .dailyGrape:
            "GRAPE OF THE DAY"
        case .settings:
            "SYSTEM"
        case .settingsSection(let section):
            section.rawValue
        case .minigames:
            "MINIGAMES"
        case .continent:
            "CONTINENT SCAN"
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
}
