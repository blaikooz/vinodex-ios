import Testing
import Foundation
@testable import VinodexCore

/// AUDIT H2/M3 (0.6.3, item 1): one malformed entry must cost one entry, not
/// the whole database, and the failure must say which entry it was.
///
/// Fixtures are built by re-encoding *real* bundled entries (`WineEntry` is
/// Codable both ways) and splicing corrupt records in between them — so the
/// "good" halves of the fixture can never drift from the real schema the way a
/// hand-written JSON blob would.
@Suite("Decode robustness")
struct DecodeRobustnessTests {
    /// A JSON array of the given fragments, wrapped as `entries.json` is.
    private func array(_ fragments: [String]) -> Data {
        Data("[\(fragments.joined(separator: ","))]".utf8)
    }

    private func encodedRealEntries(_ count: Int) throws -> [String] {
        let real = Array(WineDatabase.shared.entries.prefix(count))
        #expect(real.count == count, "bundled database too small for the fixture")
        return try real.map { String(decoding: try JSONEncoder().encode($0), as: UTF8.self) }
    }

    @Test("good entries survive a malformed sibling")
    func goodEntriesSurvive() throws {
        let good = try encodedRealEntries(2)
        // A grape with every grape-specific key missing: the discriminator
        // decodes, the payload does not.
        let corrupt = #"{"id":"BAD1","name":"Broken Grape","category":"GRAPES"}"#
        let data = array([good[0], corrupt, good[1]])

        let (entries, failures) = try WineDatabase.decodeEntries(from: data)
        #expect(entries.count == 2)
        #expect(failures.count == 1)
    }

    @Test("failures name the culprit by id")
    func failuresNameTheCulprit() throws {
        let good = try encodedRealEntries(1)
        let corrupt = #"{"id":"BAD1","name":"Broken Grape","category":"GRAPES"}"#
        let unknownCategory = #"{"id":"BAD2","name":"Uncharted","category":"NOT_A_CATEGORY"}"#
        let data = array([corrupt, good[0], unknownCategory])

        let (entries, failures) = try WineDatabase.decodeEntries(from: data)
        #expect(entries.count == 1)
        #expect(failures.count == 2)
        #expect(failures.contains { $0.contains("BAD1") })
        #expect(failures.contains { $0.contains("BAD2") })
    }

    @Test("an entry with no id still yields a diagnostic")
    func unidentifiedEntryStillReports() throws {
        let data = array([#"{"category":"GRAPES"}"#])
        let (entries, failures) = try WineDatabase.decodeEntries(from: data)
        #expect(entries.isEmpty)
        #expect(failures.count == 1)
        #expect(failures[0].contains("<unidentified entry>"))
    }

    @Test("a file that is not an array still throws")
    func fileLevelCorruptionThrows() {
        #expect(throws: (any Error).self) {
            _ = try WineDatabase.decodeEntries(from: Data(#"{"oops": true}"#.utf8))
        }
    }

    /// End-to-end guard for the M3 half: the bundled stamp exists, decodes, and
    /// matches this build. (`CoverageTests` separately pins `decodeErrors`
    /// empty, which this feeds.)
    ///
    /// `loadNotices` is pinned empty here for a reason that is the whole second
    /// half of **M45**: since a missing stamp is a notice rather than a fault,
    /// `decodeErrors` alone no longer notices data that predates the stamp. This
    /// assertion is what does — it fails the *build* on data with no stamp,
    /// which is the trade M45 asked for. It covers `countries.json` and
    /// `tiers.json` going absent for the same reason.
    @Test("bundled data carries a current schema stamp and every optional table")
    func schemaStampMatches() {
        let db = WineDatabase.shared
        #expect(db.decodeErrors.isEmpty, "load errors: \(db.decodeErrors)")
        #expect(db.loadNotices.isEmpty, "load notices: \(db.loadNotices)")
        #expect(WineDatabase.expectedSchemaVersion == 1)
    }
}

/// AUDIT M45/M46: what the loader does when one bundled table is absent or
/// broken. Every case below was unreachable before `WineDatabase(reading:)` —
/// the bundle only ever offers the healthy one — which is why these two items
/// stayed open through four re-verification passes.
///
/// The dividing line under test: `decodeErrors` means *the app is damaged* and
/// drives the launch alert; `loadNotices` means *a maintainer should know* and
/// drives nothing. Getting a case on the wrong side of it is the defect, in
/// both directions.
@Suite("Loader fallbacks")
struct LoaderFallbackTests {
    /// Fixtures re-encode the *real* bundled tables, so a "healthy" fixture
    /// cannot drift from the schema the way a hand-written blob would — the
    /// same trick `DecodeRobustnessTests` plays with entries.
    private static let healthy: [String: Data] = {
        let live = WineDatabase.shared
        let encoder = JSONEncoder()
        return [
            "entries": (try? encoder.encode(Array(live.entries.prefix(3)))) ?? Data(),
            "palette": (try? encoder.encode(live.palette)) ?? Data(),
            "icons": (try? encoder.encode(live.icons)) ?? Data(),
            "countries": (try? encoder.encode(live.countries)) ?? Data(),
            "tiers": Data(#"{"free":[]}"#.utf8),
            "schema": Data(#"{"schemaVersion":1}"#.utf8),
        ]
    }()

    private static let garbage = Data("{ not json at all".utf8)

    /// The healthy fixture with one table replaced, or removed when `data` is nil.
    private func database(replacing resource: String, with data: Data?) -> WineDatabase {
        var files = Self.healthy
        files[resource] = data
        return WineDatabase(reading: .fixture(files))
    }

    @Test("the healthy fixture loads clean")
    func healthyFixtureIsClean() {
        let db = WineDatabase(reading: .fixture(Self.healthy))
        #expect(db.entries.count == 3)
        #expect(db.decodeErrors.isEmpty, "\(db.decodeErrors)")
        #expect(db.loadNotices.isEmpty, "\(db.loadNotices)")
    }

    // MARK: - M45, the schema stamp

    @Test("a missing stamp is a notice, not a launch alert")
    func missingStampIsANotice() {
        let db = database(replacing: "schema", with: nil)
        #expect(db.decodeErrors.isEmpty, "a stale snapshot must not raise DATA LOAD ERROR: \(db.decodeErrors)")
        #expect(db.loadNotices.contains { $0.hasPrefix("schema.json is not bundled") })
        #expect(db.entries.count == 3, "and it must not cost the catalogue")
    }

    @Test("a wrong stamp is still a fault")
    func wrongStampIsAFault() {
        let db = database(replacing: "schema", with: Data(#"{"schemaVersion":99}"#.utf8))
        #expect(db.decodeErrors.contains { $0.contains("generation 99") })
    }

    /// The case that keeps the missing/wrong split honest: *present but
    /// unreadable* is damage, not age, and must not take the notice path.
    @Test("a corrupt stamp is a fault")
    func corruptStampIsAFault() {
        let db = database(replacing: "schema", with: Self.garbage)
        #expect(db.decodeErrors.contains { $0.contains("schema.json is present but unreadable") })
        #expect(db.loadNotices.isEmpty)
    }

    // MARK: - M46, the tables H2 did not cover

    @Test("a corrupt palette costs the palette, not the database")
    func corruptPaletteKeepsEntries() {
        let db = database(replacing: "palette", with: Self.garbage)
        #expect(db.entries.count == 3, "a colour table must not empty the catalogue")
        #expect(db.palette.countryChips.isEmpty, "and must fall back to the unstyled palette")
        #expect(db.decodeErrors.contains { $0.hasPrefix("palette.json failed to decode") })
    }

    @Test("a corrupt icon manifest costs the glyphs, not the database")
    func corruptIconsKeepEntries() {
        let db = database(replacing: "icons", with: Self.garbage)
        #expect(db.entries.count == 3)
        #expect(db.icons.unique.isEmpty)
        #expect(db.icons.fallback == "mdi:help-circle-outline", "the placeholder manifest is still a manifest")
        #expect(db.decodeErrors.contains { $0.hasPrefix("icons.json failed to decode") })
    }

    /// The sharpest of the three: `(try? …) ?? [:]` reported nothing at all, so
    /// a malformed countries file showed up only as every country page quietly
    /// dropping to its derived summary.
    @Test("a corrupt countries file is no longer silent")
    func corruptCountriesIsReported() {
        let db = database(replacing: "countries", with: Self.garbage)
        #expect(db.countries.isEmpty)
        #expect(db.decodeErrors.contains { $0.hasPrefix("countries.json failed to decode") })
    }

    @Test("a missing countries file stays quiet — the fallback is the design")
    func missingCountriesIsANotice() {
        let db = database(replacing: "countries", with: nil)
        #expect(db.decodeErrors.isEmpty)
        #expect(db.loadNotices.contains { $0.hasPrefix("countries.json is not bundled") })
    }

    @Test("entries are the one table whose loss empties the catalogue")
    func missingEntriesEmptiesTheCatalogue() {
        let db = database(replacing: "entries", with: nil)
        #expect(db.entries.isEmpty)
        #expect(db.decodeErrors.contains { $0.hasPrefix("entries.json is not in the bundle") })
    }

    /// A well-formed empty array reported nothing at all, so a build with no
    /// catalogue showed NO DATA FOUND on every screen and never raised the alert.
    @Test("a well-formed but empty catalogue is still a fault")
    func emptyCatalogueIsAFault() {
        let db = database(replacing: "entries", with: Data("[]".utf8))
        #expect(db.entries.isEmpty)
        #expect(db.decodeErrors.contains { $0.hasPrefix("entries.json decoded to an empty array") })
    }

    /// The distinction a fixture author gets wrong: `resourceData` reports
    /// `.fileNoSuchFile` only when the resource is absent. A zero-byte file
    /// yields `Data()` and a `DecodingError` — corrupt, not missing — and it
    /// must not take the quiet path.
    @Test("an empty file is corrupt, not missing")
    func emptyFileIsCorruptNotMissing() {
        let db = database(replacing: "tiers", with: Data())
        #expect(db.decodeErrors.contains { $0.hasPrefix("tiers.json failed to decode") })
        #expect(db.loadNotices.isEmpty)
    }

    /// M1's semantics, re-pinned through the shared reader: missing unlocks
    /// everything and says so quietly, corrupt says so loudly.
    @Test("tiers keep M1's missing-versus-corrupt split")
    func tiersKeepTheirSplit() {
        let missing = database(replacing: "tiers", with: nil)
        #expect(missing.decodeErrors.isEmpty)
        #expect(missing.loadNotices.contains { $0.hasPrefix("tiers.json is not bundled") })
        #expect(missing.isFree("ANYTHING"), "a build with no manifest is fully unlocked")

        let corrupt = database(replacing: "tiers", with: Self.garbage)
        #expect(corrupt.decodeErrors.contains { $0.hasPrefix("tiers.json failed to decode") })
    }
}
