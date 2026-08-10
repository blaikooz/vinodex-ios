#if canImport(SwiftUI) && canImport(UIKit)
import Testing
import SwiftUI
import UIKit
import VinodexCore
// `@testable`: the three loaders this suite drives — `IconLoader`,
// `PixelArtLoader`, `FlagLoader` — are internal to the module on purpose.
@testable import VinodexUI

/// Every icon an entry can ask for actually loads, from the shipped bundle (S1).
///
/// **The gap this closes.** The generator's `assertAssetsExist` already walks the
/// manifest and fails if an emitted id has no file — but it checks the *source
/// tree*, at generation time, on the machine that ran `npm run generate`. What it
/// cannot check is the other half: that the file was copied into the app bundle,
/// that `Package.swift` lists the directory it lives in, and that the bytes
/// decode into a `UIImage` on a device. Those are three separate ways to arrive
/// at a blank glyph with every existing gate green.
///
/// And the failure is silent by construction. `IconLoader.image` returns `nil`
/// for anything it cannot find, `PixelArtLoader.image` does the same, and
/// `DexIcon` renders a red `questionmark.square.dashed` — deliberately visible,
/// but only to someone holding the phone and looking at that screen. There are
/// 446 entries; nobody looks at all of them.
///
/// This has bitten three times. `Package.swift` names each bundled directory by
/// hand (a codesign requirement), and a directory missing from that list ships an
/// app with no art in it while every other check stays green —
/// `ArtPipelineRosterTests` exists because of exactly that. This suite is the
/// runtime half of the same guard: the roster test proves the list is right, and
/// this proves the images come back.
/// `@MainActor` because all three loaders are. `IconLoader`, `PixelArtLoader` and
/// `FlagLoader` each hold a mutable image cache, which Swift 6 strict
/// concurrency only allows as main-actor state — `IconLoader`'s own comment says
/// so. A nonisolated test cannot touch `shared`, and the simulator was the first
/// thing able to say that: `VinodexUI` compiles to nothing on Linux and macOS,
/// so no local gate on this machine sees an isolation error in this file.
@MainActor
@Suite("Icon resolution")
struct IconResolutionTests {
    private let db = WineDatabase.shared

    /// Mirrors `DexIcon`'s own resolution order, deliberately.
    ///
    /// `DexIcon` branches on an `art:` prefix — `artStem` is
    /// `iconID.hasPrefix("art:") ? String(iconID.dropFirst(4)) : nil`, art goes
    /// to `PixelArtLoader` and everything else to `IconLoader`. Asserting a
    /// different rule here would test a loader the app does not use for that id;
    /// a hand-drawn `art:` stem is not `IconLoader`'s to find, and demanding it
    /// would fail on ids that render perfectly.
    ///
    /// The third branch is the one being defended: if neither loader answers,
    /// the screen draws a red question mark. Nothing here should reach it.
    @Test("every entry's icon loads through the loader that owns it")
    func everyEntryIconLoads() {
        var checked = 0
        for entry in db.entries {
            let iconID = db.iconID(for: entry)
            #expect(!iconID.isEmpty, "\(entry.id) resolves to an empty icon id")

            if iconID.hasPrefix("art:") {
                let stem = String(iconID.dropFirst(4))
                #expect(
                    PixelArtLoader.shared.image(stem) != nil,
                    "\(entry.id) -> art:\(stem) did not load — DexIcon would draw the red question mark"
                )
            } else {
                #expect(
                    IconLoader.shared.image(iconID) != nil,
                    "\(entry.id) -> \(iconID) did not load — DexIcon would draw the red question mark"
                )
            }
            checked += 1
        }
        #expect(checked == db.entries.count)
        #expect(checked > 0, "no entries — the database did not load")
    }

    /// The fallback is the one icon that is guaranteed to be asked for: it is
    /// what `IconManifest.iconID(for:)` returns for any id it does not know, so
    /// if it cannot load then a *missing* entry icon degrades to a second
    /// missing icon rather than to a working one.
    @Test("the manifest's fallback icon loads")
    func fallbackLoads() {
        // Through `IconManifest`, not `WineDatabase`: the id-taking overload
        // lives on the manifest, and `WineDatabase.iconID(for:)` takes a
        // `WineEntry`, which is exactly what this test cannot supply.
        let unknown = db.icons.iconID(for: "NO_SUCH_ENTRY_ID_\(UUID().uuidString)")
        #expect(!unknown.isEmpty)
        if unknown.hasPrefix("art:") {
            #expect(PixelArtLoader.shared.image(String(unknown.dropFirst(4))) != nil)
        } else {
            #expect(IconLoader.shared.image(unknown) != nil, "the fallback icon \(unknown) does not load")
        }
    }

    /// Soil glyphs resolve through a keyword table rather than per-entry ids, so
    /// they miss the loop above entirely — and they are the exact table that
    /// silently dropped six glyphs when it was double-sourced (the `soilKeywords`
    /// comment in `IconManifest` records it).
    @Test("every soil glyph in the table loads")
    func everySoilIconLoads() {
        let keywords = db.icons.soilKeywords ?? []
        #expect(!keywords.isEmpty, "no soil keywords — the table did not decode")
        for keyword in keywords {
            let icon = db.icons.soilIcon(keyword)
            #expect(!icon.icon.isEmpty, "\(keyword) resolves to an empty glyph id")
            if icon.icon.hasPrefix("art:") {
                #expect(PixelArtLoader.shared.image(String(icon.icon.dropFirst(4))) != nil, "soil \(keyword)")
            } else {
                #expect(IconLoader.shared.image(icon.icon) != nil, "soil \(keyword) -> \(icon.icon) did not load")
            }
        }
    }

    /// Flags have their own loader and their own bundled directory, so a missing
    /// `Flags` entry in `Package.swift` would show up here and nowhere else at
    /// runtime.
    ///
    /// `FlagLoader`, not `PixelArtLoader` — they are two classes with two caches,
    /// and only `FlagLoader` takes a country. `PixelArtLoader.image(_:)` takes a
    /// filename stem, so the `for:` label was simply the wrong call.
    @Test("every shipped flag loads")
    func everyFlagLoads() {
        let countries = db.icons.flags.keys.sorted()
        #expect(!countries.isEmpty, "no flags — the table did not decode")
        for country in countries {
            #expect(
                FlagLoader.shared.image(for: country) != nil,
                "\(country) ships a flag path but the image did not load"
            )
        }
    }
}
#endif
