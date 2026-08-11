import Foundation

/// One stop on the unattended tour (0.7.3, A2).
public struct DemoStop: Sendable, Hashable, Identifiable {
    /// Where the tour navigates to.
    public let route: DexRoute
    /// How long it stays. Not uniform — see `DemoTour.stops`.
    public let dwell: TimeInterval

    /// The route's own title, so a stop cannot be captioned as something other
    /// than the screen it shows.
    public var caption: String { route.title }
    public var id: String { caption + "|" + String(dwell) }

    public init(route: DexRoute, dwell: TimeInterval) {
        self.route = route
        self.dwell = dwell
    }
}

/// The in-store attract loop (0.7.3, A2).
///
/// **What a demo mode is for decides what is on it.** This runs on a device
/// nobody is holding, in front of somebody who has not decided to pick it up, so
/// every stop has to be legible from arm's length in the few seconds it gets.
/// That rules the tour's shape more than "show everything" does: the four
/// screens A2 names lead, the rest of the shelf follows, and screens that are
/// mostly a text list are not on it at all.
///
/// **Why the dwells differ.** A uniform interval makes the loop read as a
/// slideshow of screenshots. The globe is the longest because it is the only
/// stop that animates on its own and needs a moment to be *seen* turning; the
/// list screens are shortest because a list says what it is instantly and then
/// says nothing more.
///
/// **The loop is the point of the ordering.** It ends on the globe rather than
/// on a tool, so the wrap from last stop to first is the one cut in the sequence
/// a passer-by is most likely to catch mid-motion.
public enum DemoTour: Sendable {
    /// In order, looping forever.
    ///
    /// A2 names Scanner, Globe, Encyclopedia and Passport explicitly, then "the
    /// other tools" — which here means the five remaining shelf tiles plus
    /// MASTER SEARCH, the tool the shelf itself omits.
    public static let stops: [DemoStop] = [
        // The four the spec names, first and in its order.
        DemoStop(route: .scanner, dwell: 4.5),
        DemoStop(route: .globe, dwell: 6.0),
        DemoStop(route: .list(category: .grapes, filter: nil), dwell: 3.5),
        DemoStop(route: .passport, dwell: 4.5),
        // The rest of the shelf.
        DemoStop(route: .labelReader, dwell: 4.0),
        DemoStop(route: .wsetQuiz, dwell: 4.5),
        DemoStop(route: .dailyChallenge, dwell: 4.0),
        // PROF. VINO holds WHAT'S THAT…?'s slot (0.8.93, item 9): the loop
        // still walks the whole shelf, and the shelf changed.
        DemoStop(route: .profVino, dwell: 4.0),
        DemoStop(route: .moonDial, dwell: 4.5),
        DemoStop(route: .chipFilter, dwell: 3.5),
        // Two more of the encyclopedia, so the loop is not nine tools and one
        // list — the catalog is what the tools are all *for*.
        DemoStop(route: .list(category: .styles, filter: nil), dwell: 3.5),
        DemoStop(route: .list(category: .flavors, filter: nil), dwell: 3.5),
    ]

    /// One full pass, for the "how long until it repeats" line in Settings.
    public static var cycle: TimeInterval { stops.reduce(0) { $0 + $1.dwell } }

    /// The stop after this one, wrapping.
    ///
    /// Takes any `Int` and floors it at zero, exactly as `MarqueeCheers.toast`
    /// does and for the same reason: the caller is a counter that only goes up,
    /// and a modulo on a negative would be a crash rather than a compile error
    /// if that stopped being true.
    public static func stop(at index: Int) -> DemoStop {
        stops[max(index, 0) % stops.count]
    }
}
