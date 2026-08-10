// swift-tools-version: 6.0

import PackageDescription

// VinodexCore is deliberately Foundation-only: no UIKit, no SwiftUI. That keeps
// it testable on the Linux host (`swift test` in WSL, no device required) and
// keeps a future macOS target cheap.
//
// VinodexUI and VinodexApp guard their sources with `#if canImport(SwiftUI)`
// so they compile to nothing on Linux — without that, `swift test` on the host
// would fail to build the package at all.
//
// xtool builds the product it is told to — `Vinodex`, the app — so the extra
// products below don't disturb it. Core and UI are exported so a future CLI
// validator, snapshot harness, or macOS target can depend on them directly
// (arch A5).
let package = Package(
    name: "Vinodex",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Vinodex",
            targets: ["VinodexApp"]
        ),
        .library(
            name: "VinodexCore",
            targets: ["VinodexCore"]
        ),
        .library(
            name: "VinodexUI",
            targets: ["VinodexUI"]
        ),
    ],
    targets: [
        // Each subfolder/file is copied individually rather than the Resources
        // folder itself: a shallow (iOS-style) bundle whose root contains a
        // directory literally named "Resources" makes codesign refuse it as
        // "bundle format unrecognized, invalid, or unsuitable" — it can no
        // longer tell a flat bundle from a deep (macOS-style) one. Copying the
        // children keeps the source tree (and the art pipeline that writes
        // into it) exactly where it was; only the bundle layout loses the
        // wrapper. New top-level resource files or folders must be listed here.
        //
        // **That last sentence is a trap, so it is now a gate.** `.copy("Resources")`
        // picked up a new directory the moment the importer created one; this
        // list does not, and a missing entry ships a bundle with no art in it
        // while every other check stays green — `PixelArtLoader` returns nil,
        // `IconLoader` returns nil, and the app degrades to SF Symbols in
        // silence. `ArtPipelineRosterTests.bundledArtDirectoriesAreRegistered`
        // parses this file and holds it equal to the directories on disk and to
        // `PixelArtLoader.subdirectories`, which is the same discipline the four
        // importer rosters already run under.
        //
        // `StampArt` and `StickerArt` were deliberately absent through 0.8.4:
        // both were declared on `PixelArtLoader`'s search path but neither
        // existed on disk, because the art was unauthored and the importers are
        // tolerant of that by design. `.copy` on a path that does not exist is
        // a build error, so the note here said they would join this list "in
        // the batch that draws them — which is exactly what the gate above will
        // insist on". **That batch is 0.8.5 (F1), and the gate did insist**:
        // the moment the two directories appeared,
        // `ArtPipelineRosterTests.loaderSearchPathIsBundled` failed on its own
        // exemption list, which is the whole reason that list was written as a
        // two-way check rather than as a permanent excuse.
        .target(
            name: "VinodexCore",
            resources: [
                .copy("Resources/countries.json"),
                .copy("Resources/entries.json"),
                .copy("Resources/exam.json"),
                .copy("Resources/firmware.json"),
                .copy("Resources/icons.json"),
                .copy("Resources/palette.json"),
                .copy("Resources/schema.json"),
                .copy("Resources/tiers.json"),
            ]
        ),
        .target(
            name: "VinodexUI",
            dependencies: ["VinodexCore"],
            resources: [
                // 0.8.1's drawn button faces, 0.8.2's footer caps and drawn
                // cartridges. All three landed on batch branches while this
                // list was being written on another, so all three were missing
                // from it — the three sets 0.8.1 through 0.8.3 are built on.
                .copy("Resources/ButtonArt"),
                .copy("Resources/CartridgeArt"),
                .copy("Resources/Chassis"),
                .copy("Resources/ClassArt"),
                .copy("Resources/Flags"),
                .copy("Resources/FlavorArt"),
                .copy("Resources/Fonts"),
                .copy("Resources/FooterArt"),
                // The painted UI glyphs and the Professor Vino expression
                // set (0.8.9a, A2/A3).
                .copy("Resources/GlyphArt"),
                .copy("Resources/GrapeArt"),
                .copy("Resources/Icons"),
                .copy("Resources/Logo"),
                // The dot-matrix marquee glyphs (0.8.4, A1).
                .copy("Resources/MarqueeArt"),
                .copy("Resources/Maps"),
                .copy("Resources/SFX"),
                // Authored in 0.8.5 (F1) — the six Passport badges plus four
                // back-plate decals, and the twenty shell decals.
                .copy("Resources/StampArt"),
                .copy("Resources/StickerArt"),
                .copy("Resources/StyleArt"),
                .copy("Resources/VinoArt"),
            ]
        ),
        .target(
            name: "VinodexApp",
            dependencies: ["VinodexUI"],
            // The privacy manifest describes the whole app (all three modules
            // link into one binary), so it rides the app-level target. `.copy`
            // of the single file puts it at the *root* of this target's
            // resource bundle, where App Store tooling looks — nested under a
            // Resources/ directory it would be invisible (arch A2 / auditS H3;
            // placement caveat documented in the file itself).
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "VinodexCoreTests",
            dependencies: ["VinodexCore"]
        ),
        // The first tests that can see the UI layer (S1).
        //
        // `VinodexUI` compiles to nothing on Linux and on macOS — UIKit is
        // absent on both — so for the app's whole life the only thing that ever
        // checked a theme value was someone looking at a phone. The CI
        // `ios-test` job runs `xcodebuild test` on a simulator, and this target
        // is what it was added to host: every file here carries the same
        // `#if canImport(SwiftUI) && canImport(UIKit)` guard as all of
        // `Sources/VinodexUI/`, so it builds to an empty module under
        // `swift test` and runs for real on the simulator.
        //
        // **Appended after `VinodexCoreTests` on purpose.**
        // `ArtPipelineRosterTests` parses this file as text, slicing from
        // `name: "VinodexUI"` to the first `resources: [` that follows. A target
        // carrying a `resources:` list inserted *above* `VinodexUI` would
        // silently repoint that parser at the wrong list — and an empty parse is
        // what a silently-passing gate looks like. Append; do not insert.
        .testTarget(
            name: "VinodexUITests",
            dependencies: ["VinodexUI", "VinodexCore"]
        ),
    ]
)
