// swift-tools-version: 5.10
// PrayerKit: on-device prayer computation (ADR-0003). M0: spike validating the
// adhan-swift port against the shared golden corpus; the full engine (settings,
// Hijri, notifications feed, widget timeline) builds on this in M1.
import PackageDescription

let package = Package(
    name: "PrayerKit",
    defaultLocalization: "ar",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PrayerKit", targets: ["PrayerKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/batoulapps/adhan-swift", branch: "main"),
    ],
    targets: [
        .target(
            name: "PrayerKit",
            dependencies: [.product(name: "Adhan", package: "adhan-swift")],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(name: "PrayerKitTests", dependencies: ["PrayerKit"]),
    ]
)
