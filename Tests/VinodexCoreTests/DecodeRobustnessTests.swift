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
    @Test("bundled schema stamp matches the build")
    func schemaStampMatches() {
        #expect(WineDatabase.shared.decodeErrors.isEmpty, "load errors: \(WineDatabase.shared.decodeErrors)")
        #expect(WineDatabase.expectedSchemaVersion == 1)
    }
}
