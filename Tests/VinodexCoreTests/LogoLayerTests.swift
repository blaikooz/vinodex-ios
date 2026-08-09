import Foundation
import Testing

/// The screensaver's wordmark layers exist and are real rasters (0.7.5, A5).
///
/// **This closes a gap 0.7.4 found and could only write down.** Two grapes
/// landed that batch pointing at `lucide:apple`, an icon id that had never been
/// rasterised; `IconLoader.image` returns `nil` for a missing asset, `DexIcon`
/// draws its placeholder, `swift test` sees nothing (art lives in `VinodexUI`,
/// which no Linux gate compiles) and the clean build sees nothing either,
/// because a missing *file* is not a compile error. The note in `PLAN.md` says
/// plainly: "no test or build gate covers icon assets."
///
/// A5 ships an asset the screensaver is built around — if it is absent, the
/// bouncing mark is an invisible rectangle for the whole idle period. So it gets
/// a gate.
///
/// **Scoped to these two files, deliberately.** The general problem — auditing
/// all 207 rasterised icons against `icons.json`'s `unique` list, plus the five
/// drawn-art directories against the manifests that name them — is a real piece
/// of work and belongs in the generator or in `verify-art.py`, next to the
/// tables it would check. What is here is the narrow version that covers the
/// asset this batch introduced, in the idiom the suite already has.
///
/// **Reached through `#filePath` rather than a bundle.** The art is
/// `VinodexUI`'s and this target links only `VinodexCore`, so there is no
/// `Bundle.module` to ask; and going through the UI module would make the test
/// uncompilable on the host, which is the whole reason this gate did not exist.
/// The path is resolved at compile time and is correct in the WSL mirror and in
/// CI's checkout alike.
@Suite("Screensaver wordmark art")
struct LogoLayerTests {
    /// `Tests/VinodexCoreTests/<this file>` → the package root.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var logoDirectory: URL {
        repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("VinodexUI")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Logo")
    }

    /// The two layers `ScreensaverMarkArt` loads, by the stems it loads them by.
    private static let layers = ["vinodex-mark-face", "vinodex-mark-shade"]

    /// `width` and `height` out of a PNG's IHDR, or nil if this is not a PNG.
    ///
    /// Parsed rather than trusted: an empty file, a truncated copy or a stray
    /// text file with a `.png` on it all pass an "exists" check and all draw
    /// nothing, which is the exact failure mode this suite is about.
    private static func pngSize(_ data: Data) -> (width: Int, height: Int)? {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard data.count >= 24, Array(data.prefix(8)) == signature else { return nil }
        let bytes = Array(data)
        func be32(_ offset: Int) -> Int {
            (Int(bytes[offset]) << 24) | (Int(bytes[offset + 1]) << 16)
                | (Int(bytes[offset + 2]) << 8) | Int(bytes[offset + 3])
        }
        // IHDR is always the first chunk: 8 bytes of signature, 4 of length,
        // 4 of type, then width and height.
        guard Array(bytes[12..<16]) == Array("IHDR".utf8) else { return nil }
        return (be32(16), be32(20))
    }

    @Test("both layers ship, and both are PNGs with pixels in them")
    func layersRasterise() throws {
        for stem in Self.layers {
            let url = Self.logoDirectory.appendingPathComponent("\(stem).png")
            #expect(
                FileManager.default.fileExists(atPath: url.path),
                "\(stem).png is missing — run scripts/import-logo-art.py"
            )
            let data = try Data(contentsOf: url)
            let size = Self.pngSize(data)
            #expect(size != nil, "\(stem).png is not a PNG")
            #expect((size?.width ?? 0) > 0, "\(stem).png has no width")
            #expect((size?.height ?? 0) > 0, "\(stem).png has no height")
        }
    }

    /// The face is what `ScreensaverMarkArt.aspect` measures the bounce box
    /// from, and the shade is drawn into the same frame. Different dimensions
    /// would misregister the relief — the extruded edge sliding off the face —
    /// which is a fault that still bounces correctly and so would ship.
    @Test("the two layers are the same size, so the relief registers")
    func layersRegister() throws {
        let sizes = try Self.layers.map { stem -> (width: Int, height: Int) in
            let url = Self.logoDirectory.appendingPathComponent("\(stem).png")
            let size = Self.pngSize(try Data(contentsOf: url))
            return size ?? (0, 0)
        }
        #expect(sizes[0] == sizes[1], "face and shade differ in size: \(sizes)")
    }

    /// The screensaver sizes its bounce box off this, and a mark taller than it
    /// is wide would mean the layers were imported from the wrong master.
    @Test("the mark is landscape, as the wordmark is")
    func markIsLandscape() throws {
        let url = Self.logoDirectory.appendingPathComponent("vinodex-mark-face.png")
        let size = Self.pngSize(try Data(contentsOf: url))
        #expect((size?.width ?? 0) > (size?.height ?? 0))
    }
}
