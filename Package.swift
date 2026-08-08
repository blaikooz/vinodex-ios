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
        .target(
            name: "VinodexCore",
            // `.copy`, not `.process`: `.process` would flatten the directory
            // structure every lookup depends on — `subdirectory: "Resources"`
            // for the six JSONs here, and all twelve `DexAsset` subdirectory
            // paths in VinodexUI (arch A22).
            resources: [.copy("Resources")]
        ),
        .target(
            name: "VinodexUI",
            dependencies: ["VinodexCore"],
            // `.copy` for the same reason as VinodexCore above.
            resources: [.copy("Resources")]
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
    ]
)
