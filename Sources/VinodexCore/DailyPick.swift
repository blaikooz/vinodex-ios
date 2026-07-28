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
}
