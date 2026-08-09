import Testing
import Foundation
@testable import VinodexCore

/// The style-class keyword tables exist twice, so something has to hold them equal.
///
/// `EntryDisplay`'s three lists carry the comment "Keyword tables transcribed
/// from entryUtils.ts", and transcribed is exactly the problem: `shared/services/
/// entryUtils.ts` has the same three lists, the two are read by two different
/// apps, and until now nothing compared them. They agree today. Nothing made
/// them agree, and nothing would have said so if they stopped.
///
/// **This is a known failure mode in this repo, not a hypothetical one.** The
/// soil keyword list was hardcoded in Swift, drifted from the generator's table,
/// and silently dropped six soils onto the default glyph — `IconManifest`'s
/// `soilKeywords` comment still records it. That one was fixed by making the
/// generator emit the list; these three are still transcribed by hand.
///
/// **Why a text parity check rather than generating them.** Single-sourcing
/// through the generator is the better end state (rule 4 — the lists are data),
/// but it means emitting a new table, decoding it, and changing how
/// `styleClass(name:classification:)` resolves — a behaviour-carrying change to
/// the function that decides what every style entry *is*. This gate costs
/// nothing, catches the drift it exists to catch, and is the same discipline
/// `ArtPipelineRosterTests` already runs on the art rosters: read both files off
/// disk through `#filePath` and hold them equal. Generating them is written up
/// as a proposal rather than done here.
@Suite("Style keyword parity")
struct KeywordParityTests {
    /// `Tests/VinodexCoreTests/<this file>` -> the package root.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func read(_ components: String...) throws -> String {
        var url = repoRoot
        for component in components { url.appendPathComponent(component) }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The text between `open` and the first `]` after it.
    private static func slice(_ text: String, from open: String) -> String? {
        guard let start = text.range(of: open) else { return nil }
        let rest = text[start.upperBound...]
        guard let end = rest.firstIndex(of: "]") else { return nil }
        return String(rest[..<end])
    }

    /// Every `"..."` or `'...'` run in `text`. Both spellings, because one side
    /// of this comparison is Swift and the other is TypeScript.
    private static func quoted(_ text: String) -> [String] {
        var out: [String] = []
        var current: String?
        var quote: Character?
        for character in text {
            if let open = quote {
                if character == open {
                    if let value = current { out.append(value) }
                    current = nil
                    quote = nil
                } else {
                    current?.append(character)
                }
            } else if character == "\"" || character == "'" {
                quote = character
                current = ""
            }
        }
        return out
    }

    private static func swiftList(_ name: String) throws -> Set<String> {
        let text = try read("Sources", "VinodexCore", "EntryDisplay.swift")
        guard let list = slice(text, from: "static let \(name) = [") else { return [] }
        return Set(quoted(list))
    }

    private static func typescriptList(_ name: String) throws -> Set<String> {
        let text = try read("shared", "services", "entryUtils.ts")
        guard let list = slice(text, from: "const \(name) = [") else { return [] }
        return Set(quoted(list))
    }

    /// Compared as sets, not as arrays, and the distinction is deliberate.
    ///
    /// Both sides test membership with `contains`/`some` over the whole list, so
    /// within-list order changes nothing — asserting array equality would fail on
    /// a harmless reordering and teach everyone to distrust the gate. (Order
    /// *between* the three lists does matter — ORIGIN before TYPE before METHOD —
    /// but that is control flow in each language, not data, and both files state
    /// it.)
    @Test(
        "the style keyword tables match their TypeScript source",
        arguments: [
            ("originKeywords", "ORIGIN_KEYWORDS"),
            ("methodKeywords", "METHOD_KEYWORDS"),
            ("typeKeywords", "TYPE_KEYWORDS"),
        ]
    )
    func listsMatch(swiftName: String, tsName: String) throws {
        let swift = try Self.swiftList(swiftName)
        let typescript = try Self.typescriptList(tsName)

        // An empty parse is what a silently-passing gate looks like — the exact
        // trap `ArtPipelineRosterTests` records having fallen into. Assert the
        // parser found something before asserting the two agree.
        #expect(!swift.isEmpty, "parsed no keywords out of EntryDisplay.\(swiftName)")
        #expect(!typescript.isEmpty, "parsed no keywords out of \(tsName) in entryUtils.ts")

        #expect(
            swift == typescript,
            """
            \(swiftName) has drifted from \(tsName).
            only in Swift: \(swift.subtracting(typescript).sorted())
            only in TypeScript: \(typescript.subtracting(swift).sorted())
            """
        )
    }

    /// The parser is only trustworthy if it reads the values the runtime uses, so
    /// this ties the parsed text back to the compiled constants.
    @Test("the parsed Swift lists are the ones the code actually uses")
    func parsedListsMatchTheCompiledOnes() throws {
        #expect(try Self.swiftList("originKeywords") == Set(EntryDisplay.originKeywords))
        #expect(try Self.swiftList("methodKeywords") == Set(EntryDisplay.methodKeywords))
        #expect(try Self.swiftList("typeKeywords") == Set(EntryDisplay.typeKeywords))
    }
}
