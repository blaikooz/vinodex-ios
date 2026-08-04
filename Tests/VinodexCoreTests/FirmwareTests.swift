import Testing
import Foundation
@testable import VinodexCore

/// The firmware catalog, and the version machinery now reading from it
/// (0.7.3, F3).
///
/// The generator already gates the changelog's *shape* — ordering, ASCII,
/// headline length — at generation time, and repeating those assertions here
/// would only re-test the generator. What is worth pinning on this side is the
/// join: that the resource ships, that it decodes, and that `AppVersion` and the
/// catalog cannot disagree about what this build is. Those are the failures that
/// would otherwise surface as a boot screen quietly reading `v0.0.0`.
@Suite("Firmware catalog")
struct FirmwareTests {
    let catalog = FirmwareCatalog.shared

    /// **The regression this file exists for.** `firmware.json` is a generated
    /// resource, and a resource that stops being copied into the bundle fails
    /// silently: `load()` catches everything and returns `unavailable`, which is
    /// exactly the right runtime behaviour and exactly the wrong thing to ship.
    @Test("the bundled catalog loads")
    func catalogLoads() {
        #expect(!catalog.releases.isEmpty, "firmware.json missing or unreadable — run npm run generate")
        #expect(
            catalog.version != FirmwareCatalog.unavailable.version,
            "the catalog resolved to the distress value; the resource did not load"
        )
    }

    /// One source of truth means the two ends of it agree.
    @Test("AppVersion reports the catalog's version")
    func appVersionFollowsTheCatalog() {
        #expect(AppVersion.fallback == catalog.version)
        // `current` goes through `resolve`, and on Linux the bundle declares
        // nothing, so this is the path every xtool build takes as well.
        #expect(AppVersion.current == catalog.version)
    }

    /// The head of the list is the current build, and it has notes — the panel
    /// opens on this release, so an empty one is a panel opening onto nothing.
    @Test("the current version is the newest release and has notes")
    func currentIsTheHead() throws {
        let head = try #require(catalog.releases.first)
        #expect(head.version == catalog.version)
        let current = try #require(catalog.current)
        #expect(current == head)
        #expect(!current.notes.isEmpty)
    }

    /// Versions identify releases, so a duplicate would make `release(_:)`
    /// return whichever came first and hide the other from the panel entirely.
    @Test("versions are unique")
    func versionsAreUnique() {
        let versions = catalog.releases.map(\.version)
        #expect(Set(versions).count == versions.count)
    }

    /// Newest first, which is what makes deriving the current version from the
    /// head legitimate rather than a coincidence of authoring order.
    @Test("releases are newest first")
    func releasesDescend() {
        func rank(_ version: String) -> [Int] {
            version.split(separator: ".").map { Int($0) ?? 0 }
        }
        for pair in zip(catalog.releases, catalog.releases.dropFirst()) {
            let (newer, older) = pair
            #expect(
                rank(newer.version).lexicographicallyPrecedes(rank(older.version)) == false,
                "\(newer.version) does not sort above \(older.version)"
            )
            #expect(newer.version != older.version)
        }
    }

    /// Every release has to be printable in the retro face — see the note in
    /// `shared/data/firmware.ts`. The generator checks this too; it is repeated
    /// here because the generator is not what CI runs on a Swift-only change,
    /// and a hand-edited `firmware.json` would sail past it.
    @Test("every release is printable ASCII")
    func printableASCII() {
        for release in catalog.releases {
            #expect(release.headline == release.headline.uppercased(), "\(release.version) headline is not uppercase")
            #expect(release.headline.count <= 24, "\(release.version) headline is \(release.headline.count) chars")
            #expect(!release.notes.isEmpty, "\(release.version) has no notes")
            for text in [release.headline] + release.notes {
                let ascii = text.allSatisfy { $0.isASCII && !$0.isNewline }
                #expect(ascii, "\(release.version): not printable ASCII — \(text)")
            }
        }
    }

    /// Dates are printed verbatim beside the version; a malformed one is visible
    /// on the panel and nowhere else.
    @Test("dates are ISO")
    func datesAreISO() {
        for release in catalog.releases {
            let parts = release.date.split(separator: "-", omittingEmptySubsequences: false)
            #expect(parts.count == 3, "\(release.version): \(release.date) is not YYYY-MM-DD")
            let widths = parts.map(\.count)
            #expect(widths == [4, 2, 2], "\(release.version): \(release.date) is not YYYY-MM-DD")
            let allNumeric = parts.allSatisfy { $0.allSatisfy(\.isNumber) }
            #expect(allNumeric, "\(release.version): \(release.date) has a non-numeric component")
        }
    }

    /// Lookup by version, which is how the boot screen finds the notes for the
    /// build it is booting.
    @Test("release lookup finds what the list holds and nothing else")
    func lookup() throws {
        let head = try #require(catalog.releases.first)
        #expect(catalog.release(head.version) == head)
        #expect(catalog.release("99.99.99") == nil)
    }

    /// The distress value is not a plausible version anyone could ship, which is
    /// what makes `catalogLoads` above able to tell the two apart.
    @Test("the unavailable catalog is unmistakable")
    func unavailableIsObvious() {
        #expect(FirmwareCatalog.unavailable.releases.isEmpty)
        #expect(FirmwareCatalog.unavailable.current == nil)
        // Still three components, so `AppVersion`'s shape rule stays a real
        // check rather than one that only passes because the data is good.
        #expect(FirmwareCatalog.unavailable.version.split(separator: ".").count == 3)
    }
}
