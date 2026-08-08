import Testing
import Foundation
@testable import VinodexCore

@Suite("Moon dial")
struct MoonCalendarTests {
    private func date(_ iso: String) -> Date {
        let f = DateFormatter()
        // Pinned like the `utc` calendar beside this: inheriting the process
        // locale/calendar makes the parse return nil under non-Gregorian or
        // non-Latin-digit regions, and the `!` then kills the whole runner.
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: iso)!
    }

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    @Test("longitude stays in range across a long span")
    func longitudeRange() {
        // Including dates before J2000, where the raw formula goes negative.
        for offset in stride(from: -20_000, through: 20_000, by: 137) {
            let day = date("2000-01-01").addingTimeInterval(Double(offset) * 86_400)
            let l = MoonCalendar.longitude(for: day)
            #expect(l >= 0 && l < 360, "longitude \(l) out of range at offset \(offset)")
            #expect((0...11).contains(MoonCalendar.zodiacIndex(for: day)))
        }
    }

    /// Element follows sign index modulo four — fire, earth, air, water — which
    /// is the whole basis for the fruit/root/flower/leaf mapping.
    @Test("day type follows the sign's element")
    func elementMapping() {
        for offset in 0..<120 {
            let day = date("2026-01-01").addingTimeInterval(Double(offset) * 86_400)
            let expected: MoonDay = switch MoonCalendar.zodiacIndex(for: day) % 4 {
            case 0: .fruit
            case 1: .root
            case 2: .flower
            default: .leaf
            }
            #expect(MoonCalendar.day(for: day) == expected)
        }
    }

    /// The moon crosses all twelve signs in about 27 days, so a month of
    /// sampling must produce every day type — a mapping stuck on one value
    /// would still look plausible on any single day.
    @Test("a lunar month covers all four day types")
    func coversAllTypes() {
        var seen: Set<MoonDay> = []
        for offset in 0..<30 {
            let day = date("2026-07-01").addingTimeInterval(Double(offset) * 86_400)
            seen.insert(MoonCalendar.day(for: day))
        }
        #expect(seen.count == MoonDay.allCases.count, "only saw \(seen.map(\.rawValue).sorted())")
    }

    @Test("fruit and flower days are the drinking days")
    func drinkingDays() {
        #expect(MoonDay.fruit.isGoodForDrinking)
        #expect(MoonDay.flower.isGoodForDrinking)
        #expect(!MoonDay.leaf.isGoodForDrinking)
        #expect(!MoonDay.root.isGoodForDrinking)
    }

    /// Reopening the app must not reshuffle the line, and every day type needs
    /// one — an empty quote would render as a blank panel.
    @Test("quotes are stable within a day and never empty")
    func quotes() {
        for offset in 0..<40 {
            let day = date("2026-01-01").addingTimeInterval(Double(offset) * 86_400)
            let a = MoonCalendar.quote(for: day, calendar: utc)
            let b = MoonCalendar.quote(for: day.addingTimeInterval(3600 * 5), calendar: utc)
            #expect(!a.isEmpty)
            #expect(a == b, "quote changed within one day")
        }
    }
}

@Suite("Scanner")
struct GrapeScanTests {
    let db = WineDatabase.shared

    @Test("no criteria matches every grape")
    func emptyMatchesAll() {
        let all = db.grapesMatching(GrapeScanCriteria())
        #expect(all.count == db.entries(in: .grapes).count)
    }

    @Test("colour and body narrow the field")
    func colorAndBody() {
        let reds = db.grapesMatching(GrapeScanCriteria(color: .red))
        #expect(!reds.isEmpty)
        for entry in reds {
            guard case .grape(let g) = entry else { Issue.record("not a grape"); continue }
            #expect(g.grapeType == .red)
        }

        let fullReds = db.grapesMatching(GrapeScanCriteria(color: .red, body: .full))
        #expect(!fullReds.isEmpty)
        #expect(fullReds.count < reds.count, "body did not narrow anything")
        for entry in fullReds {
            guard case .grape(let g) = entry else { continue }
            #expect(g.grapeBodyClass == "Full")
        }
    }

    /// Every body chip the scanner offers must select something. A fourth value
    /// appearing in the data would leave one of the three matching nothing,
    /// which you could only discover by tapping it.
    @Test("every body class the scanner offers exists in the data")
    func bodyClassesAreReal() {
        for body in GrapeBody.allCases {
            #expect(
                !db.grapesMatching(GrapeScanCriteria(body: body)).isEmpty,
                "\(body.rawValue) matches no grape"
            )
        }
    }

    @Test("country of origin filters by whole term")
    func country() {
        let french = db.grapesMatching(GrapeScanCriteria(country: "France"))
        #expect(!french.isEmpty)
        for entry in french {
            guard case .grape(let g) = entry else { continue }
            #expect(g.grapeCountryOfOrigin == "France")
        }
    }

    /// Flavours are ANDed, so adding one can only ever shrink the result — and
    /// each grape returned must genuinely carry the note.
    @Test("flavors are combined with AND")
    func flavorsAreAnded() throws {
        let flavor = try #require(db.entries(in: .flavors).first { !$0.notableGrapes.isEmpty })
        let withFlavor = db.grapesMatching(GrapeScanCriteria(flavorIDs: [flavor.id]))

        #expect(!withFlavor.isEmpty, "\(flavor.name) links grapes but matched none")
        #expect(withFlavor.count <= db.entries(in: .grapes).count)
        for grape in withFlavor {
            #expect(db.grape(grape, carries: flavor))
        }
    }

    @Test("the basket refuses more than the limit")
    func basketCap() {
        var criteria = GrapeScanCriteria()
        let flavors = db.entries(in: .flavors).prefix(GrapeScanCriteria.flavorLimit + 2)
        for flavor in flavors {
            criteria.toggleFlavor(flavor.id)
        }
        #expect(criteria.flavorIDs.count == GrapeScanCriteria.flavorLimit)
        #expect(criteria.flavorsAreFull)

        // Toggling an existing one off makes room again.
        let first = criteria.flavorIDs[0]
        criteria.toggleFlavor(first)
        #expect(criteria.flavorIDs.count == GrapeScanCriteria.flavorLimit - 1)
        #expect(!criteria.flavorIDs.contains(first))
    }

    @Test("isEmpty tracks whether anything was answered")
    func emptiness() {
        #expect(GrapeScanCriteria().isEmpty)
        #expect(!GrapeScanCriteria(color: .white).isEmpty)
        #expect(!GrapeScanCriteria(country: "Italy").isEmpty)
    }

    /// The scanner lists these as tiles, so each must lead somewhere.
    @Test("every flavor class and subclass tile has entries behind it")
    func flavorGroupsResolve() {
        #expect(!db.flavorClasses.isEmpty)
        #expect(!db.flavorSubclasses.isEmpty)

        for value in db.flavorClasses {
            #expect(!db.flavors(inClass: value).isEmpty, "class \(value) is empty")
        }
        for value in db.flavorSubclasses {
            #expect(!db.flavors(subclass: value).isEmpty, "subclass \(value) is empty")
        }
    }
}

@Suite("What's that reveal")
struct DailyRevealTests {
    let db = WineDatabase.shared

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func date(_ iso: String) -> Date {
        let f = DateFormatter()
        // Pinned like the `utc` calendar beside this: inheriting the process
        // locale/calendar makes the parse return nil under non-Gregorian or
        // non-Latin-digit regions, and the `!` then kills the whole runner.
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: iso)!
    }

    /// The reveal draws on grapes, regions and styles — the rename exists
    /// because it stopped being grape-only.
    @Test("the reveal rotates through all three categories")
    func rotatesCategories() throws {
        var seen: Set<EntryCategory> = []
        for offset in 0..<9 {
            let day = date("2026-01-01").addingTimeInterval(Double(offset) * 86_400)
            seen.insert(try #require(DailyPick.entry(for: day, in: db, calendar: utc)).category)
        }
        #expect(seen == Set(DailyPick.categories))
    }

    /// Deliberately unrestricted, unlike `DailyPick.grape` — the free slice was
    /// small enough that the same handful came round repeatedly.
    @Test("the reveal pool is the whole category, not the free tier")
    func usesEveryEntry() {
        var ids: Set<String> = []
        for offset in 0..<400 {
            let day = date("2026-01-01").addingTimeInterval(Double(offset) * 86_400)
            if let pick = DailyPick.entry(for: day, in: db, calendar: utc) {
                ids.insert(pick.id)
            }
        }
        let free = ids.filter { db.isFree($0) }.count
        #expect(ids.count > free, "every reveal in a year was free — the pool is still restricted")
    }

    /// The whole point of the cursor: opening it again gives you something new
    /// to guess rather than the answer you were just shown.
    @Test("consecutive opens on the same day give different entries")
    func cursorAdvancesThePick() throws {
        let day = date("2026-03-14")
        var ids: [String] = []
        for cursor in 0..<12 {
            ids.append(try #require(
                DailyPick.entry(cursor: cursor, for: day, in: db, calendar: utc)
            ).id)
        }

        for (a, b) in zip(ids, ids.dropFirst()) {
            #expect(a != b, "cursor did not move the pick: \(a) twice running")
        }
        #expect(Set(ids).count == ids.count, "the cycle repeated within 12 opens")
    }

    /// The day still seeds the cycle, so two people opening it cold on the same
    /// day agree — the cursor changes what *you* see next, not what the day is.
    @Test("the same cursor and day always give the same entry")
    func cursorIsDeterministic() throws {
        let day = date("2026-03-14")
        let first = try #require(DailyPick.entry(cursor: 5, for: day, in: db, calendar: utc))
        let again = try #require(DailyPick.entry(cursor: 5, for: day, in: db, calendar: utc))
        #expect(first.id == again.id)
    }

    /// A long run must keep moving rather than settling into a short orbit —
    /// the stride is chosen for exactly this.
    @Test("the cycle covers a wide spread of the database")
    func cursorCoversTheDatabase() {
        let day = date("2026-03-14")
        var ids: Set<String> = []
        for cursor in 0..<200 {
            if let pick = DailyPick.entry(cursor: cursor, for: day, in: db, calendar: utc) {
                ids.insert(pick.id)
            }
        }
        #expect(ids.count > 100, "200 opens surfaced only \(ids.count) distinct entries")
    }

    @MainActor
    @Test("the cursor persists and advances by one")
    func cursorPersists() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let cursor = RevealCursor(defaults: defaults)
        #expect(cursor.value == 0)
        #expect(cursor.advance() == 1)
        #expect(cursor.advance() == 2)
        // A fresh instance over the same defaults continues rather than resetting.
        #expect(RevealCursor(defaults: defaults).value == 2)
    }

    // MARK: - The empty-category fallback (AUDIT M32)

    /// `DailyPick`'s `return nil`. Unreachable against the shipped catalogue —
    /// which is precisely why it had no coverage until there was a fixture —
    /// and all three pickers own a copy of the guard.
    @Test("an empty database reveals nothing rather than trapping")
    func emptyDatabaseRevealsNothing() throws {
        let empty = try DBFixture.database()
        #expect(empty.entries.isEmpty)
        let day = date("2026-03-14")
        #expect(DailyPick.entry(for: day, in: empty, calendar: utc) == nil)
        #expect(DailyPick.entry(cursor: 3, for: day, in: empty, calendar: utc) == nil)
        #expect(DailyPick.grape(for: day, in: empty, calendar: utc) == nil)
    }

    /// Entries present, but none in the three rotated categories: the loop has
    /// to walk the whole of `ordered` before giving up rather than stopping at
    /// the first empty pool.
    @Test("a database with no grapes, regions or styles reveals nothing")
    func noRotatableCategoriesRevealsNothing() throws {
        let db = try DBFixture.database(DBFixture.flavor, DBFixture.continent)
        #expect(db.entries.count == 2)
        #expect(DailyPick.categories.allSatisfy { db.entries(in: $0).isEmpty })
        #expect(DailyPick.entry(for: date("2026-03-14"), in: db, calendar: utc) == nil)
    }

    /// The `continue` in the fallback loop — better a grape than an empty
    /// screen. One surviving category carries every day of the rotation.
    @Test("one surviving category carries every day of the rotation")
    func fallsBackToTheOnlyNonEmptyCategory() throws {
        let stylesOnly = try DBFixture.database(DBFixture.style)
        for offset in 0..<9 {
            let day = date("2026-01-01").addingTimeInterval(Double(offset) * 86_400)
            let pick = try #require(DailyPick.entry(for: day, in: stylesOnly, calendar: utc))
            #expect(pick.id == "FX_S", "day \(offset) landed on \(pick.id)")
        }
    }

    /// The fallback *order* is `[wanted] + categories.filter { $0 != wanted }` —
    /// the rotation's own order, not the database's. With grapes and styles
    /// present and regions empty, a regions day lands on the grape (first in
    /// `DailyPick.categories`), never on the style, whichever order the entries
    /// were loaded in. The fixture deliberately loads the style *first*, so a
    /// naive "take the first entry" implementation would fail here.
    @Test("the fallback walks the rotation order, not the database order")
    func fallbackOrderIsTheRotationOrder() throws {
        let db = try DBFixture.database(DBFixture.style, DBFixture.grape)

        #expect(DailyPick.category(for: date("1970-01-01"), calendar: utc) == .grapes)
        #expect(DailyPick.entry(for: date("1970-01-01"), in: db, calendar: utc)?.id == "FX_G")

        #expect(DailyPick.category(for: date("1970-01-02"), calendar: utc) == .regions)
        #expect(DailyPick.entry(for: date("1970-01-02"), in: db, calendar: utc)?.id == "FX_G")
    }

    // MARK: - Negative day indices (AUDIT M32)

    @Test("dayIndex is zero at the epoch and negative before it")
    func dayIndexAcrossTheEpoch() {
        #expect(DailyPick.dayIndex(for: date("1970-01-01"), calendar: utc) == 0)
        #expect(DailyPick.dayIndex(for: date("1969-12-31"), calendar: utc) == -1)
        #expect(DailyPick.dayIndex(for: date("1900-06-15"), calendar: utc) < 0)
    }

    /// `((i % n) + n) % n` appears four times — in `category` and in all three
    /// pickers — because a raw `%` on a negative index walks backwards off the
    /// front of the array. `DailyPickTests.preEpoch` pins only `grape(for:)`;
    /// these are the other three, plus a negative *cursor*, which `RevealCursor`
    /// can produce because `advance()` wraps.
    @Test("every picker survives a negative day index")
    func negativeDayIndexIsNormalised() throws {
        #expect(DailyPick.category(for: date("1969-12-31"), calendar: utc) == .styles)

        let old = date("1900-06-15")
        _ = try #require(DailyPick.entry(for: old, in: db, calendar: utc))
        _ = try #require(DailyPick.grape(for: old, in: db, calendar: utc))
        _ = try #require(DailyPick.entry(cursor: 7, for: old, in: db, calendar: utc))
        _ = try #require(DailyPick.entry(cursor: -5, for: old, in: db, calendar: utc))
    }
}
