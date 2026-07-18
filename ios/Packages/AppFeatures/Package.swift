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
        .library(name: "AwradFeature", targets: ["AwradFeature"]),
        .library(name: "HadithFeature", targets: ["HadithFeature"]),
        .library(name: "GamificationFeature", targets: ["GamificationFeature"]),
        .library(name: "LeaderboardFeature", targets: ["LeaderboardFeature"]),
        .library(name: "SearchHistoryFeature", targets: ["SearchHistoryFeature"]),
        .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
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
        .target(
            name: "AwradFeature",
            dependencies: [
                .product(name: "CoreKit", package: "FatwaBotKit"),
                .product(name: "ContentKit", package: "FatwaBotKit"),
                .product(name: "DesignSystemKit", package: "FatwaBotKit"),
                .product(name: "Factory", package: "Factory"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(name: "DuaFeatureTests", dependencies: ["DuaFeature"]),
        .target(
            name: "HadithFeature",
            dependencies: [
                .product(name: "CoreKit", package: "FatwaBotKit"),
                .product(name: "ContentKit", package: "FatwaBotKit"),
                .product(name: "DesignSystemKit", package: "FatwaBotKit"),
                .product(name: "Factory", package: "Factory"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(name: "AwradFeatureTests", dependencies: ["AwradFeature"]),
        .testTarget(name: "HadithFeatureTests", dependencies: ["HadithFeature"]),
        .target(
            name: "GamificationFeature",
            dependencies: [
                .product(name: "CoreKit", package: "FatwaBotKit"),
                .product(name: "NetworkingKit", package: "FatwaBotKit"),
                .product(name: "DesignSystemKit", package: "FatwaBotKit"),
                .product(name: "Factory", package: "Factory"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(name: "GamificationFeatureTests", dependencies: ["GamificationFeature"]),
        .target(
            name: "LeaderboardFeature",
            dependencies: [
                .product(name: "CoreKit", package: "FatwaBotKit"),
                .product(name: "NetworkingKit", package: "FatwaBotKit"),
                .product(name: "DesignSystemKit", package: "FatwaBotKit"),
                .product(name: "Factory", package: "Factory"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(name: "LeaderboardFeatureTests", dependencies: ["LeaderboardFeature"]),
        .target(
            name: "SearchHistoryFeature",
            dependencies: [
                .product(name: "CoreKit", package: "FatwaBotKit"),
                .product(name: "NetworkingKit", package: "FatwaBotKit"),
                .product(name: "DesignSystemKit", package: "FatwaBotKit"),
                .product(name: "Factory", package: "Factory"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(name: "SearchHistoryFeatureTests", dependencies: ["SearchHistoryFeature"]),
        .target(
            name: "OnboardingFeature",
            dependencies: [
                .product(name: "CoreKit", package: "FatwaBotKit"),
                .product(name: "DesignSystemKit", package: "FatwaBotKit"),
                .product(name: "Factory", package: "Factory"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(name: "OnboardingFeatureTests", dependencies: ["OnboardingFeature"]),
    ]
)
