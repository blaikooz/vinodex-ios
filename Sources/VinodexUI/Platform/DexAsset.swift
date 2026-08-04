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
enum DexAsset: String, CaseIterable, Sendable {
    // Rasterised — scripts/rasterize-icons.sh
    case icons = "Resources/Icons"
    case flags = "Resources/Flags"

    // Drawn art — art/ importers, verified by `npm run icons:verify`
    case flavorArt = "Resources/FlavorArt"
    case grapeArt = "Resources/GrapeArt"
    case styleArt = "Resources/StyleArt"
    /// Taxonomy + outline art (v0.5.7): classes, subclasses, colour, body,
    /// climate, soils, style classes and country outlines, reached through
    /// `art:` icon ids — see `DexIcon`.
    case classArt = "Resources/ClassArt"
    /// Back-plate stamp and sticker glyphs (0.6.4, F2/F3), imported from
    /// `art/icons/stamps/` — the directory ships empty-of-art until the glyphs
    /// are authored; a miss falls through to the SF stand-ins.
    case stampArt = "Resources/StampArt"

    // Unmanaged binaries — produced by no script, traced to no source
    case fonts = "Resources/Fonts"
    case maps = "Resources/Maps"
    case sfx = "Resources/SFX"
    case chassis = "Resources/Chassis"
    case logo = "Resources/Logo"
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
/// Under `.copy("Resources")` SwiftPM preserves the directory structure
/// verbatim, so nothing is ever at the bundle root and that line could not
/// succeed for any of the call sites. It returned `nil` one line later than the
/// lookup above it did, while reading as though a miss had been handled — and
/// it sat inside the project's only asset guard rail, since `DexAssetAudit`
/// resolves every manifest id through this exact function.
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
