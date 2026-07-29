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
/// Two kinds of state, because those are the two that survive being restored
/// blind. An anchor names a *section* (`Anchor.regions`), not a pixel offset, so
/// a screen whose content changed underneath — a bookmark removed, a tier
/// unlocked — still restores somewhere sensible instead of into empty space.
/// Flags are named booleans, so a screen that gains or loses a section does not
/// invalidate the ones it kept.
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

    // MARK: Lifecycle

    public func clear() {
        anchors.removeAll()
        flags.removeAll()
    }

    /// Drops one screen's state without touching the rest — for a screen whose
    /// content is gone rather than merely changed.
    public func forget(_ key: String) {
        anchors.removeValue(forKey: key)
        flags.removeValue(forKey: key)
    }

    public var isEmpty: Bool { anchors.isEmpty && flags.isEmpty }

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
    public static let bookmarks = "bookmarks"
}
