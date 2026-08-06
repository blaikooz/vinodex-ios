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
// xtool expects exactly one library product, which is the app.
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
        // `StampArt` and `StickerArt` are deliberately absent: both are declared
        // on `PixelArtLoader`'s search path but neither exists on disk yet (the
        // art is unauthored, and the importers are tolerant of that by design).
        // `.copy` on a path that does not exist is a build error, so they join
        // this list in the batch that draws them — which is exactly what the
        // gate above will insist on.
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
                .copy("Resources/GrapeArt"),
                .copy("Resources/Icons"),
                .copy("Resources/Logo"),
                .copy("Resources/Maps"),
                .copy("Resources/SFX"),
                .copy("Resources/StyleArt"),
            ]
        ),
        .target(
            name: "VinodexApp",
            dependencies: ["VinodexUI"]
        ),
        .testTarget(
            name: "VinodexCoreTests",
            dependencies: ["VinodexCore"]
        ),
    ]
)
