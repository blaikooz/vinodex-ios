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
        .target(
            name: "VinodexCore",
            resources: [.copy("Resources")]
        ),
        .target(
            name: "VinodexUI",
            dependencies: ["VinodexCore"],
            resources: [.copy("Resources")]
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
