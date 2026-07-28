import Testing
import Foundation
@testable import VinodexCore

@Suite("Grape of the day")
struct DailyPickTests {
    let db = WineDatabase.shared

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func date(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: iso)!
    }

    /// The whole point: reopening the app must not reshuffle it.
    @Test("the same day always gives the same grape")
    func stableWithinADay() throws {
        let morning = date("2026-07-28")
        let later = morning.addingTimeInterval(60 * 60 * 9)

        let a = try #require(DailyPick.grape(for: morning, in: db, calendar: utc))
        let b = try #require(DailyPick.grape(for: later, in: db, calendar: utc))
        #expect(a.id == b.id)
    }

    @Test("consecutive days give different grapes")
    func changesDaily() throws {
        var seen: [String] = []
        for offset in 0..<5 {
            let day = date("2026-07-28").addingTimeInterval(Double(offset) * 86_400)
            seen.append(try #require(DailyPick.grape(for: day, in: db, calendar: utc)).id)
        }
        // Adjacent days must differ; the sequence walks the pool by one.
        for pair in zip(seen, seen.dropFirst()) {
            #expect(pair.0 != pair.1, "two days running gave \(pair.0)")
        }
    }

    /// A locked pick would be a daily advertisement rather than a daily read.
    @Test("the pick is always in the free tier")
    func alwaysFree() throws {
        for offset in 0..<40 {
            let day = date("2026-01-01").addingTimeInterval(Double(offset) * 86_400)
            let pick = try #require(DailyPick.grape(for: day, in: db, calendar: utc))
            #expect(db.isFree(pick.id), "\(pick.name) is not in the free tier")
            #expect(pick.category == .grapes)
        }
    }

    /// `dayIndex` goes negative before 1970, and a raw `%` would then index
    /// backwards off the front of the array.
    @Test("dates before the epoch still resolve")
    func preEpoch() {
        #expect(DailyPick.grape(for: date("1962-03-04"), in: db, calendar: utc) != nil)
    }

    @Test("the cycle covers many different grapes")
    func coversThePool() throws {
        var ids: Set<String> = []
        for offset in 0..<30 {
            let day = date("2026-01-01").addingTimeInterval(Double(offset) * 86_400)
            ids.insert(try #require(DailyPick.grape(for: day, in: db, calendar: utc)).id)
        }
        // Not a fixed number — the free tier's size is a data decision — but
        // 30 days landing on a handful would mean the index is barely moving.
        #expect(ids.count >= 10, "30 days produced only \(ids.count) distinct grapes")
    }

    @Test("same-day comparison respects the calendar")
    func sameDay() {
        let a = date("2026-07-28")
        #expect(DailyPick.isSameDay(a, a.addingTimeInterval(3600), calendar: utc))
        #expect(!DailyPick.isSameDay(a, a.addingTimeInterval(86_400), calendar: utc))
    }
}
