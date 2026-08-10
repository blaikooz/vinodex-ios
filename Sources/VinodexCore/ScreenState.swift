import Foundation
import Observation

/// Per-screen UI state — where a screen was scrolled to, and which of its
/// collapsible sections were open — kept alive across navigation.
///
/// `RootView` has no `NavigationStack`. It swaps the LCD's content on a `path`
/// change, so the screen you navigate *away* from is destroyed outright and
/// rebuilt from scratch when you come back. Every `@State` it held goes with
/// it. `SearchStateStore` already rescued the list screens' query and scroll
/// anchor for exactly this reason; this is the same fix for everything else.
///
/// What it was like without this: open France, tap SHOW ALL (14) on its
/// regions, scroll down to Saint-Émilion, open it, press Back — and land at the
/// top of a re-collapsed France showing the first three regions again, having
/// to expand and scroll a second time to reach the row next to the one you had
/// just read. The deeper the page, the worse it got, and countries and entry
/// readouts are the longest pages in the app.
///
/// Three kinds of state, all of which survive being restored blind. An anchor
/// names a *section* (`Anchor.regions`), not a pixel offset, so a screen whose
/// content changed underneath — a bookmark removed, a tier unlocked — still
/// restores somewhere sensible instead of into empty space. Flags are named
/// booleans, so a screen that gains or loses a section does not invalidate the
/// ones it kept. Values are named strings for the screens whose state is neither
/// — how far through the scanner's five questions you are, what you have told it
/// so far, where the globe was spun to.
///
/// Keyed per screen instance rather than per screen *type*: France and Italy are
/// different pages and must not share a scroll position. Callers build the key
/// (`"country:France"`), mirroring how `SearchStateStore` keys a listing.
///
/// Deliberately **not** persisted to `UserDefaults`, for the same reason as
/// `SearchStateStore`: this is session state. A cold launch should open a
/// country at the top with its sections collapsed, not halfway down where you
/// left it last week. `clear()` is called when Home is pressed, so Home is the
/// way to get a clean screen.
@MainActor
@Observable
public final class ScreenStateStore {
    public static let shared = ScreenStateStore()

    private var anchors: [String: String] = [:]
    private var flags: [String: Set<String>] = [:]
    private var values: [String: [String: String]] = [:]

    public init() {}

    // MARK: Scroll position

    /// The id of the section at the top of the viewport, or nil for the top of
    /// the screen.
    public func anchor(for key: String) -> String? {
        anchors[key]
    }

    public func setAnchor(_ anchor: String?, for key: String) {
        if let anchor {
            anchors[key] = anchor
        } else {
            anchors.removeValue(forKey: key)
        }
    }

    // MARK: Expanded sections

    public func isOn(_ flag: String, for key: String) -> Bool {
        flags[key]?.contains(flag) ?? false
    }

    /// Off is stored as absence rather than as `false`, so collapsing every
    /// section leaves nothing behind and `isEmpty` means what it says.
    public func setFlag(_ flag: String, _ on: Bool, for key: String) {
        var set = flags[key] ?? []
        if on {
            set.insert(flag)
        } else {
            set.remove(flag)
        }
        if set.isEmpty {
            flags.removeValue(forKey: key)
        } else {
            flags[key] = set
        }
    }

    public func toggleFlag(_ flag: String, for key: String) {
        setFlag(flag, !isOn(flag, for: key), for: key)
    }

    // MARK: Named values

    /// A named string belonging to one screen — the scanner's current question,
    /// the entry the daily reveal is holding, the globe's heading.
    public func value(_ name: String, for key: String) -> String? {
        values[key]?[name]
    }

    /// Nil clears, like `setAnchor`, and an emptied screen leaves nothing behind.
    public func setValue(_ value: String?, _ name: String, for key: String) {
        var bag = values[key] ?? [:]
        bag[name] = value
        if bag.isEmpty {
            values.removeValue(forKey: key)
        } else {
            values[key] = bag
        }
    }

    public func number(_ name: String, for key: String) -> Double? {
        value(name, for: key).flatMap(Double.init)
    }

    public func setNumber(_ number: Double?, _ name: String, for key: String) {
        // Spelled out rather than `String.init`, which is ambiguous for Double
        // across the describing/reflecting overloads.
        setValue(number.map { String($0) }, name, for: key)
    }

    /// JSON round-trip for the one piece of screen state that is a structure
    /// rather than a scalar: the scanner's accumulated answers.
    ///
    /// Worth the encoder because the alternative is spreading four fields —
    /// one of them an array — across four named values and reassembling them by
    /// hand at the call site, which is where a restored-but-wrong criteria set
    /// would come from. A decode failure yields nil and the screen opens fresh,
    /// which is the same outcome as never having stored anything.
    public func decoded<T: Decodable>(_ type: T.Type, _ name: String, for key: String) -> T? {
        guard let raw = value(name, for: key), let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func encode(_ value: (some Encodable)?, _ name: String, for key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            setValue(nil, name, for: key)
            return
        }
        setValue(String(decoding: data, as: UTF8.self), name, for: key)
    }

    // MARK: Lifecycle

    public func clear() {
        anchors.removeAll()
        flags.removeAll()
        values.removeAll()
    }

    /// Drops one screen's state without touching the rest — for a screen whose
    /// content is gone rather than merely changed.
    public func forget(_ key: String) {
        anchors.removeValue(forKey: key)
        flags.removeValue(forKey: key)
        values.removeValue(forKey: key)
    }

    public var isEmpty: Bool { anchors.isEmpty && flags.isEmpty && values.isEmpty }

    // MARK: Keys
    //
    // Spelled out rather than derived from a route's `String(describing:)` — that
    // is a compiler detail, and it would silently orphan stored state when a
    // case was renamed. Prefixed per screen kind so a country and a state of the
    // same name cannot collide.

    public static func country(_ name: String) -> String { "country:" + name }
    public static func state(_ name: String) -> String { "state:" + name }
    public static func detail(_ entryID: String) -> String { "detail:" + entryID }
    public static func continent(_ entryID: String) -> String { "continent:" + entryID }
    /// One grape's pedigree tree (0.7.5, E1). Its own prefix rather than
    /// `detail`'s: walking up a tree and coming back must land you where you
    /// were on *the tree*, not where you were on the scan behind it.
    public static func lineage(_ entryID: String) -> String { "lineage:" + entryID }
    /// One instance each — unlike the countries and entries, there is only ever
    /// one saved list, one questionnaire, one reveal and one globe.
    public static let bookmarks = "bookmarks"
    public static let scanner = "scanner"
    public static let dailyGrape = "dailyGrape"
    public static let globe = "globe"
    public static let chipFilter = "chipFilter"
    public static let wsetQuiz = "wsetQuiz"
    public static let dailyChallenge = "dailyChallenge"
    /// The label reader's last result (0.7.2, LR1). The reading is a structure,
    /// so it round-trips through `encode(_:_:for:)` like the scanner's criteria
    /// do — and for the same reason: opening a suggested grape from the results
    /// tears this screen down, and coming back to the camera instead of to the
    /// result you were reading would make the Back button feel broken.
    public static let labelReader = "labelReader"
    /// The device workshop (0.7.3, B1). Nine sections deep, and every part
    /// choice raises an overlay or repaints the schematic at the top — without
    /// an anchor, fitting a grille pattern from the sixth section would bounce
    /// the page back to the preview.
    public static let deviceWorkshop = "deviceWorkshop"
    /// The settings panels are one screen per section, so they key like the
    /// countries do rather than sharing a scroll position between DATA and DEV.
    public static func settings(_ section: String) -> String { "settings:" + section }
    /// The user panel's shelves each keep their own scroll position, so
    /// switching from SAVED to TRIED and back does not land you at a row id
    /// the other shelf cannot resolve.
    public static func shelf(_ name: String) -> String { "bookmarks:" + name }
}
