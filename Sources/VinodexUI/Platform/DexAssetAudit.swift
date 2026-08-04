#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import VinodexCore

/// Checks that every asset id the manifest names has a file behind it (AUDIT
/// **L26**).
///
/// The gap this closes: nothing in the repo verified that the ids in
/// `icons.json` and the PNGs in `Resources/` describe the same set. The
/// rasteriser fails loudly when it cannot *render* something, but a slug that
/// changes shape between the manifest and the bundle — a renamed art stem, a
/// flag whose file never arrived, a scale variant lost to a half-finished run —
/// is not a failure anywhere. It is a red `questionmark.square.dashed` on one
/// tile in one corner of one screen (see `DexIcon`), which is exactly the kind
/// of thing that ships.
///
/// Nothing here is on a render path: `DiagnosticsReport` is the DEV panel and
/// the debug catalog, and this walks a few hundred `Bundle.url` lookups. It is
/// a build check that happens to have a screen, not a runtime guard.
///
/// The five surfaces are the five directories the loaders read
/// (`IconLoader`, `PixelArtLoader`, `FlagLoader`), which is the list that grew
/// from one to five while nothing was watching it.
///
/// `@MainActor` because it reads `PixelArtLoader.directories`, and the
/// loaders are main-actor isolated for their caches. The only caller is a
/// `View` body, which is already there.
@MainActor
struct DexAssetAudit {
    /// One asset family: what it is, how many ids it names, and which of them
    /// have no file.
    struct Surface: Identifiable {
        let name: String
        let total: Int
        /// Capped when reporting — a wholly missing directory would otherwise
        /// print a hundred lines saying the same thing. `total` and
        /// `missingCount` still tell the truth.
        let missing: [String]
        let missingCount: Int

        var id: String { name }
        var ok: Bool { missingCount == 0 }

        /// `icons 66` when clean, `icons 64/66 — foo, bar` when not.
        var line: String {
            guard !ok else { return "\(name) \(total)" }
            let shown = missing.joined(separator: ", ")
            let more = missingCount > missing.count ? " +\(missingCount - missing.count) more" : ""
            return "\(name) \(total - missingCount)/\(total) — \(shown)\(more)"
        }
    }

    /// How many missing ids a surface names before it starts counting instead.
    private static let namedMissesPerSurface = 4

    static func run(_ db: WineDatabase = .shared) -> [Surface] {
        let icons = db.icons

        // Iconify ids come from `unique` — the rasterisation list — plus every
        // table that can hand one to `DexIcon` at runtime. `unique` alone would
        // check what the pipeline *meant* to render rather than what the app
        // can actually ask for, and those are the same set only while nobody
        // has made a mistake.
        var referenced = Set(icons.unique)
        referenced.formUnion(icons.byEntry.values)
        referenced.formUnion(icons.bodyIcons.values)
        referenced.formUnion(icons.climateIcons.values)
        referenced.formUnion(icons.colorIcons.values)
        referenced.formUnion(icons.styleClassIcons.values)
        referenced.formUnion(icons.flavorClassIcons.map { Array($0.values) } ?? [])
        referenced.formUnion(icons.flavorSubclassIcons.map { Array($0.values) } ?? [])
        referenced.formUnion(icons.countryShapeIcons.values)
        referenced.formUnion(icons.soilIcons.values.map(\.icon))
        referenced.insert(icons.fallback)

        // `art:` ids are bundled pixel art, not rasterised glyphs — they must
        // not be looked for under `Resources/Icons` and are never fetched.
        let artStems = referenced
            .filter { $0.hasPrefix("art:") }
            .map { String($0.dropFirst(4)) }
        let glyphIDs = referenced.filter { !$0.hasPrefix("art:") }

        return [
            surface("icons", ids: glyphIDs.sorted()) { hasIconVariants(IconManifest.slug(for: $0)) },
            // Taxonomy, outline and stamp art, all reached through `art:`.
            surface("art", ids: artStems.sorted()) { exists($0, in: PixelArtLoader.directories) },
            surface("flavorArt", ids: stems(icons.flavorArt)) {
                exists($0, in: [.flavorArt])
            },
            // Deduplicated like the others: `grapeArt` is generated over the
            // full colour×body×blend×rarity grid with fallbacks, so a few dozen
            // keys share each sprite.
            surface("grapeArt", ids: stems(icons.grapeArt)) {
                exists($0, in: [.grapeArt])
            },
            surface("styleArt", ids: stems(icons.styleArt)) {
                exists($0, in: [.styleArt])
            },
            surface("flags", ids: icons.flags.keys.sorted()) { country in
                guard let slug = icons.flagSlug(for: country) else { return false }
                return exists(slug, in: [.flags])
            },
        ]
    }

    /// The distinct PNG stems an art table names, in a stable order.
    private static func stems(_ table: [String: String]?) -> [String] {
        Set(table?.values ?? [:].values).sorted()
    }

    private static func surface(
        _ name: String,
        ids: [String],
        resolves: (String) -> Bool
    ) -> Surface {
        let missing = ids.filter { !resolves($0) }
        return Surface(
            name: name,
            total: ids.count,
            missing: Array(missing.prefix(namedMissesPerSurface)),
            missingCount: missing.count
        )
    }

    /// All three scales, not just one. `IconLoader` walks down from the
    /// device's scale to `@1x`, so a set missing only its `@3x` still draws —
    /// softly, on every modern phone, for as long as nobody looks. That is the
    /// failure **L23** made impossible to *create* and this makes impossible
    /// to *keep*.
    private static func hasIconVariants(_ slug: String) -> Bool {
        [slug, "\(slug)@2x", "\(slug)@3x"].allSatisfy {
            DexResources.url(named: $0, ext: "png", in: .icons) != nil
        }
    }

    private static func exists(_ stem: String, in directories: [DexAsset]) -> Bool {
        directories.contains {
            DexResources.url(named: stem, ext: "png", in: $0) != nil
        }
    }
}
#endif
