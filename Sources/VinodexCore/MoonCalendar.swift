import Foundation

/// The biodynamic tasting calendar's four day types.
///
/// Growers following Maria Thun's calendar divide the month by which zodiac
/// sign the moon is passing through, and group those signs by classical
/// element: fire days are *fruit* days, air *flower*, water *leaf*, earth
/// *root*. The wine trade picked this up because several UK supermarkets and a
/// good many sommeliers schedule tastings by it — fruit and flower days are
/// held to show a wine at its best, leaf and root days at their dullest.
///
/// Whether it is true is not this screen's problem. It is a real, widely used
/// calendar with a defined rule, which is what makes it worth computing rather
/// than inventing a "type of day" out of nothing.
public enum MoonDay: String, Codable, Sendable, CaseIterable, Identifiable {
    case fruit = "FRUIT"
    case flower = "FLOWER"
    case leaf = "LEAF"
    case root = "ROOT"

    public var id: String { rawValue }

    /// The classical element of the sign the moon is in.
    public var element: String {
        switch self {
        case .fruit: "FIRE"
        case .flower: "AIR"
        case .leaf: "WATER"
        case .root: "EARTH"
        }
    }

    /// Whether the calendar rates this a good day to taste.
    public var isGoodForDrinking: Bool {
        switch self {
        case .fruit, .flower: true
        case .leaf, .root: false
        }
    }

    /// The headline answer, which is the whole reason anyone opens this screen.
    public var verdict: String {
        isGoodForDrinking ? "GOOD DAY TO DRINK" : "MAYBE NOT TODAY"
    }

    /// What the day is said to favour.
    public var summary: String {
        switch self {
        case .fruit:
            "Fruit days favour ripe, expressive wine. The classic day to open something you actually care about."
        case .flower:
            "Flower days lift aromatics. Perfumed whites, and anything you drink mostly with your nose."
        case .leaf:
            "Leaf days run watery and closed. Wine is said to show its dullest face."
        case .root:
            "Root days push tannin and structure forward, and everything charming backward."
        }
    }
}

/// Which biodynamic day a date falls on, and a line about it.
public enum MoonCalendar {
    /// Reference epoch J2000.0 — 2000-01-01 12:00 UTC.
    private static let j2000 = Date(timeIntervalSince1970: 946_728_000)

    /// The moon's mean ecliptic longitude in degrees, 0..<360.
    ///
    /// The standard low-precision formula: the moon advances ~13.176° a day
    /// from a known position at J2000. It ignores the major perturbations, so
    /// it can sit a few degrees off true longitude and land on a neighbouring
    /// sign near a boundary. That is well inside the tolerance of a calendar
    /// whose own practitioners disagree about boundaries — and the alternative
    /// is a full lunar theory for a screen that prints one word.
    public static func longitude(for date: Date = Date()) -> Double {
        let days = date.timeIntervalSince(j2000) / 86_400
        let raw = (218.316 + 13.176396 * days).truncatingRemainder(dividingBy: 360)
        return raw < 0 ? raw + 360 : raw
    }

    /// The instant a whole calendar day is judged by.
    ///
    /// Local noon, **not** the moment of the call. The moon changes sign at an
    /// arbitrary hour, so reading the live longitude made the screen flip from
    /// a leaf day to a fruit day over lunch — and the quote with it. A day gets
    /// one type. Noon rather than midnight because a sign entered at 03:00
    /// governs the overwhelming majority of that day, and midnight would file
    /// the whole day under the sign it was leaving.
    private static func anchor(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
            ?? calendar.startOfDay(for: date)
    }

    /// Which of the twelve signs the moon is in for the given day, Aries = 0.
    public static func zodiacIndex(
        for date: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        min(Int(longitude(for: anchor(date, calendar)) / 30), 11)
    }

    /// The sign's name, shown as the readout under the day type.
    public static func zodiac(
        for date: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let names = [
            "ARIES", "TAURUS", "GEMINI", "CANCER", "LEO", "VIRGO",
            "LIBRA", "SCORPIO", "SAGITTARIUS", "CAPRICORN", "AQUARIUS", "PISCES",
        ]
        return names[zodiacIndex(for: date, calendar: calendar)]
    }

    /// The day type.
    ///
    /// The elements cycle in a fixed order through the zodiac — fire, earth,
    /// air, water, repeating — so the sign index modulo four *is* the element,
    /// with no table needed.
    public static func day(
        for date: Date = Date(),
        calendar: Calendar = .current
    ) -> MoonDay {
        switch zodiacIndex(for: date, calendar: calendar) % 4 {
        case 0: .fruit    // fire  — Aries, Leo, Sagittarius
        case 1: .root     // earth — Taurus, Virgo, Capricorn
        case 2: .flower   // air   — Gemini, Libra, Aquarius
        default: .leaf    // water — Cancer, Scorpio, Pisces
        }
    }

    /// A line about today, rotating so two consecutive fruit days do not read
    /// identically. Deterministic from the date for the same reason the daily
    /// pick is: reopening the app must not reshuffle it.
    public static func quote(
        for date: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        // Threaded through, not defaulted: picking the pool in one calendar
        // and the index in another lets the two disagree about which day it
        // is, which shows up as the line changing during the day.
        let pool = quotes[day(for: date, calendar: calendar)] ?? []
        guard !pool.isEmpty else { return "" }
        let i = DailyPick.dayIndex(for: date, calendar: calendar)
        return pool[((i % pool.count) + pool.count) % pool.count]
    }

    private static let quotes: [MoonDay: [String]] = [
        .fruit: [
            "Fruit day. The universe has signed off. Open the good bottle.",
            "Fruit day: even the sceptics pour a second glass.",
            "Fruit day. Blame the moon, not your judgement.",
            "Fruit day — the wine is showing off, and so should you.",
        ],
        .flower: [
            "Flower day. Aromatics are running the show. Something perfumed, please.",
            "Flower day: the bouquet does the talking tonight.",
            "Flower day — pour something that smells like a compliment.",
            "Flower day. Riesling has been waiting by the phone.",
        ],
        .leaf: [
            "Leaf day. The wine is sulking. Have a cup of tea and a think.",
            "Leaf day: technically drinkable, spiritually inadvisable.",
            "Leaf day — save the good bottle. It will not thank you today.",
            "Leaf day. Even the grapes are having an off one.",
        ],
        .root: [
            "Root day. Wine goes quiet and tannin does all the talking.",
            "Root day: the least romantic entry in the lunar calendar.",
            "Root day — a night for stew, not for Burgundy.",
            "Root day. Put the cork back in. Trust the moon.",
        ],
    ]
}
