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
                .copy("Resources/Chassis"),
                .copy("Resources/ClassArt"),
                .copy("Resources/Flags"),
                .copy("Resources/FlavorArt"),
                .copy("Resources/Fonts"),
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
