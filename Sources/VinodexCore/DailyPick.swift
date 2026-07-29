import Foundation

/// One entry surfaced per day — the "grape of the day".
///
/// Deterministic from the date rather than stored: everyone on the same day
/// gets the same grape, reopening the app never reshuffles it, and there is no
/// state to migrate or reset. The only input is the calendar day.
public enum DailyPick {
    /// Days since a fixed epoch, in the given calendar. Using the *local* day
    /// means the pick turns over at local midnight, which is what a reader
    /// expects; a UTC day would roll at an arbitrary hour.
    public static func dayIndex(
        for date: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: date)
        let epoch = Date(timeIntervalSince1970: 0)
        let days = calendar.dateComponents([.day], from: epoch, to: start).day ?? 0
        return days
    }

    /// Categories the daily pick rotates through. Regions and styles are as
    /// guessable from a silhouette as grapes are, and rotating keeps the
    /// feature from being a grape-only habit.
    public static let categories: [EntryCategory] = [.grapes, .regions, .styles]

    /// The category for a given day — rotates one step per day, so the same
    /// kind never lands twice running.
    public static func category(
        for date: Date = Date(),
        calendar: Calendar = .current
    ) -> EntryCategory {
        let i = dayIndex(for: date, calendar: calendar)
        let n = categories.count
        return categories[((i % n) + n) % n]
    }

    /// The entry for a given day, from that day's category.
    ///
    /// Falls back through the other categories if the chosen one is empty —
    /// better a grape than an empty screen.
    ///
    /// Draws on **every** entry in the three categories, not just the free
    /// tier. `grape(for:in:)` below still restricts itself, and the reasoning
    /// there — a locked pick is an advertisement rather than a read — has not
    /// gone away; it is just outweighed here by the reveal being the point of
    /// the game. Narrowing 284 entries to the free slice made the same handful
    /// come round repeatedly. Note the consequence: with the ACCESS toggle set
    /// to free-tier, opening a locked reveal raises the paywall prompt.
    public static func entry(
        for date: Date = Date(),
        in db: WineDatabase,
        calendar: Calendar = .current
    ) -> WineEntry? {
        let wanted = category(for: date, calendar: calendar)
        let ordered = [wanted] + categories.filter { $0 != wanted }

        for category in ordered {
            let pool = db.entries(in: category).sorted { $0.id < $1.id }
            guard !pool.isEmpty else { continue }
            let i = dayIndex(for: date, calendar: calendar)
            return pool[((i % pool.count) + pool.count) % pool.count]
        }
        return nil
    }

    /// The grape for a given day.
    ///
    /// Picks from the free tier only. A locked pick would be a daily
    /// advertisement rather than a daily read — the feature exists to give a
    /// reason to reopen the app, and that only works if you can open what it
    /// offers.
    ///
    /// Sorted by id before indexing so the sequence does not depend on the
    /// order entries happen to appear in the JSON.
    public static func grape(
        for date: Date = Date(),
        in db: WineDatabase,
        calendar: Calendar = .current
    ) -> WineEntry? {
        let pool = db.entries(in: .grapes)
            .filter { db.isFree($0.id) }
            .sorted { $0.id < $1.id }
        guard !pool.isEmpty else { return nil }

        // `dayIndex` can be negative for dates before 1970; `formatTruncatingIfNeeded`
        // style wrap-around would break, so normalise into range explicitly.
        let index = ((dayIndex(for: date, calendar: calendar) % pool.count) + pool.count) % pool.count
        return pool[index]
    }

    /// Whether two dates fall on the same local day — used to decide whether
    /// today's pick has already been revealed.
    public static func isSameDay(
        _ a: Date,
        _ b: Date,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// The pick at a given position in the cycle.
    ///
    /// The reveal was strictly one entry per calendar day, which is right for a
    /// "grape of the day" and wrong for what this became: a guessing game you
    /// can play. Opening it twice showed the same answer you had already been
    /// told, so the second visit had nothing in it — and there was no way to
    /// play again short of waiting until tomorrow.
    ///
    /// `cursor` advances once per open (see `RevealCursor`). The day still sets
    /// the starting point, so the first play of the day is unchanged and two
    /// people opening it cold still get the same entry.
    ///
    /// Walks the categories as one flat sequence rather than rotating category
    /// first: stepping category-per-open made the run grape, region, style,
    /// grape, which telegraphs the answer's *kind* every time.
    public static func entry(
        cursor: Int,
        for date: Date = Date(),
        in db: WineDatabase,
        calendar: Calendar = .current
    ) -> WineEntry? {
        let pool = categories
            .flatMap { db.entries(in: $0) }
            .sorted { $0.id < $1.id }
        guard !pool.isEmpty else { return nil }

        // A stride coprime with most pool sizes, so consecutive opens land far
        // apart in the sorted order instead of walking neighbours — adjacent
        // ids are often the same grape family, which made the "new" entry look
        // like a variant of the last one.
        let stride = 37
        let start = dayIndex(for: date, calendar: calendar)
        let raw = start &+ cursor &* stride
        return pool[((raw % pool.count) + pool.count) % pool.count]
    }
}

/// How many times the reveal has been opened.
///
/// Persisted, so the cycle continues across launches rather than restarting at
/// the same entry every cold start. Lives in Core beside `DailyPick` so the
/// cycling rule is testable without a UI target.
@MainActor
public final class RevealCursor {
    public static let shared = RevealCursor()

    public static let storageKey = "revealCursor"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var value: Int {
        defaults.integer(forKey: Self.storageKey)
    }

    /// Advances and returns the new position. Called once per open.
    @discardableResult
    public func advance() -> Int {
        // Wraps well before overflow; the modulo at the call site does not care
        // about the absolute value, only that it keeps moving.
        let next = value &+ 1
        defaults.set(next, forKey: Self.storageKey)
        return next
    }

    public func reset() {
        defaults.set(0, forKey: Self.storageKey)
    }
}
