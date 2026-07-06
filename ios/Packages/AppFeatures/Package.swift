// swift-tools-version: 5.10
// Feature modules (ADR-0010). Dependency rule: feature → core packages only;
// feature → feature is forbidden — cross-feature flows compose in the App target.
import PackageDescription

let package = Package(
    name: "AppFeatures",
    defaultLocalization: "ar",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PrayerFeature", targets: ["PrayerFeature"]),
        .library(name: "HomeFeature", targets: ["HomeFeature"]),
        .library(name: "TasbeehFeature", targets: ["TasbeehFeature"]),
        .library(name: "AzkarFeature", targets: ["AzkarFeature"]),
        .library(name: "DuaFeature", targets: ["DuaFeature"]),
    ],
    dependencies: [
        .package(path: "../FatwaBotKit"),
        .package(path: "../PrayerKit"),
        .package(url: "https://github.com/hmlongco/Factory", from: "2.4.0"),
    ],
    targets: [
        .target(
            name: "PrayerFeature",
            dependencies: [
                .product(name: "CoreKit", package: "FatwaBotKit"),
                .product(name: "ConfigKit", package: "FatwaBotKit"),
                .product(name: "DesignSystemKit", package: "FatwaBotKit"),
                .product(name: "PrayerKit", package: "PrayerKit"),
                .product(name: "Factory", package: "Factory"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "HomeFeature",
            dependencies: [
                .product(name: "CoreKit", package: "FatwaBotKit"),
                .product(name: "ConfigKit", package: "FatwaBotKit"),
                .product(name: "DesignSystemKit", package: "FatwaBotKit"),
                .product(name: "PrayerKit", package: "PrayerKit"),
                .product(name: "Factory", package: "Factory"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "TasbeehFeature",
            dependencies: [
                .product(name: "CoreKit", package: "FatwaBotKit"),
                .product(name: "DesignSystemKit", package: "FatwaBotKit"),
                .product(name: "Factory", package: "Factory"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "AzkarFeature",
            dependencies: [
                .product(name: "CoreKit", package: "FatwaBotKit"),
                .product(name: "ContentKit", package: "FatwaBotKit"),
                .product(name: "DesignSystemKit", package: "FatwaBotKit"),
                .product(name: "Factory", package: "Factory"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "DuaFeature",
            dependencies: [
                .product(name: "CoreKit", package: "FatwaBotKit"),
                .product(name: "ContentKit", package: "FatwaBotKit"),
                .product(name: "DesignSystemKit", package: "FatwaBotKit"),
                .product(name: "Factory", package: "Factory"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(name: "PrayerFeatureTests", dependencies: ["PrayerFeature"]),
        .testTarget(name: "HomeFeatureTests", dependencies: ["HomeFeature"]),
        .testTarget(name: "TasbeehFeatureTests", dependencies: ["TasbeehFeature"]),
        .testTarget(name: "AzkarFeatureTests", dependencies: ["AzkarFeature"]),
        .testTarget(name: "DuaFeatureTests", dependencies: ["DuaFeature"]),
    ]
)
