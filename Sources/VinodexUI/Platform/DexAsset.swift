#if canImport(SwiftUI) && canImport(UIKit)
import Foundation

/// Every directory this module loads a file out of (arch **A22**).
///
/// **What this replaces.** Twelve string literals across eight files, with no
/// shared constant between them. The failure mode was specific and survivable
/// for a long time: a typo or a directory rename compiles, `swift test` stays
/// green, and the app ships as a red questionmark glyph, a grey block, a system
/// monospace font, a silent tap, or a flat green sphere — *most of which are
/// plausible enough to survive a device check*. A rename is one edit now, and
/// `-Wswitch`-style exhaustiveness is not the point; being one symbol is.
///
/// **Why an enum and not `static let` strings.** `DexAssetAudit` (**L26**)
/// checks that every id the manifest names has a file behind it, and it did so
/// by re-spelling the same literals — so it caught a *missing file* and could
/// never catch a *wrong literal*, because it shared the mistake. Both sides
/// take the path from here now, which is the whole of A22's remedy.
///
/// Ordered as the pipeline produces them: rasterised glyphs and flags first
/// (`scripts/rasterize-icons.sh`), then the drawn art (`art/`, **H12**), then
/// the four unmanaged trees that no script produces (**R7**).
/// **Bare directory names, not `Resources/…` paths.** Changed on integration
/// with `upstream/testing`, and the reason is a device-only failure that no
/// simulator build shows.
///
/// `Package.swift` used to ship `.copy("Resources")`, which put a directory
/// literally named `Resources` at the root of the bundle. A shallow iOS bundle
/// shaped that way makes codesign refuse it — *"bundle format unrecognized,
/// invalid, or unsuitable"* — because it can no longer tell a flat bundle from
/// a deep macOS-style one. The manifest now copies each *child*, so the wrapper
/// is gone from the bundle and every `Bundle.module` subdirectory lookup drops
/// the prefix to match. The source tree is untouched: the importers still write
/// to `Sources/VinodexUI/Resources/<Dir>`.
///
/// **Getting this wrong is silent**, which is why it is worth the note. A stale
/// `Resources/Icons` simply returns `nil`, and every drawn face degrades to the
/// SF Symbol it replaced. Nothing throws and nothing logs — the failure looks
/// like a design choice.
enum DexAsset: String, CaseIterable, Sendable {
    // Rasterised — scripts/rasterize-icons.sh
    case icons = "Icons"
    case flags = "Flags"

    // Drawn art — art/ importers, verified by `npm run icons:verify`
    case flavorArt = "FlavorArt"
    case grapeArt = "GrapeArt"
    case styleArt = "StyleArt"
    /// Taxonomy + outline art (v0.5.7): classes, subclasses, colour, body,
    /// climate, soils, style classes and country outlines, reached through
    /// `art:` icon ids — see `DexIcon`.
    case classArt = "ClassArt"
    /// Back-plate stamp and sticker glyphs (0.6.4, F2/F3), imported from
    /// `art/icons/stamps/` — the directory ships empty-of-art until the glyphs
    /// are authored; a miss falls through to the SF stand-ins.
    case stampArt = "StampArt"

    // Drawn art that arrived with upstream/testing (0.8.1–0.8.9). Registered
    // here rather than looked up by string literal for the reason the enum
    // exists at all: `DexAssetAudit` takes its paths from these cases, so a
    // directory that is not a case is a directory nothing checks.
    case buttonArt = "ButtonArt"
    case cartridgeArt = "CartridgeArt"
    case footerArt = "FooterArt"
    case glyphArt = "GlyphArt"
    case marqueeArt = "MarqueeArt"
    case stickerArt = "StickerArt"
    case vinoArt = "VinoArt"

    // Unmanaged binaries — produced by no script, traced to no source
    case fonts = "Fonts"
    case maps = "Maps"
    case sfx = "SFX"
    case chassis = "Chassis"
    case logo = "Logo"
}

/// Bundle lookup without an asset catalog.
///
/// SwiftPM places target resources in `Bundle.module`, not `Bundle.main` — a
/// distinction that matters because the skeleton's version looked in `.main`.
/// Moved out of `DexTheme.swift` to sit beside `DexAsset`, which is now the
/// only way to name a directory here.
///
/// **The subdirectory-less fallback is gone (arch A14).** This used to take an
/// optional subdirectory and, on a miss, retry the flat name against the whole
/// bundle:
///
/// ```swift
/// return Bundle.module.url(forResource: name, withExtension: ext)
/// ```
///
/// SwiftPM preserves each copied directory verbatim, so every asset lives in a
/// named subdirectory and nothing is at the bundle root — that line could not
/// succeed for any of the call sites. It returned `nil` one line later than the
/// lookup above it did, while reading as though a miss had been handled — and
/// it sat inside the project's only asset guard rail, since `DexAssetAudit`
/// resolves every manifest id through this exact function.
///
/// Still true after the bundle lost its `Resources/` wrapper on integration
/// (see `DexAsset`): the directories moved up one level, they did not go away.
/// A flat fallback would now be *more* dangerous, not less — it would find some
/// files and mask exactly the misspelling the enum exists to prevent.
enum DexResources {
    static func url(named name: String, ext: String, in directory: DexAsset) -> URL? {
        Bundle.module.url(
            forResource: name,
            withExtension: ext,
            subdirectory: directory.rawValue
        )
    }
}
#endif
