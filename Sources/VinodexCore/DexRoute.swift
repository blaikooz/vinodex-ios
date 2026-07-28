import Foundation

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
