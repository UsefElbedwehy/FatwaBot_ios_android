// swift-tools-version: 5.10
// FatwaBotKit: shared foundation modules (ADR-0010 feature-first; features arrive as
// separate targets in M1+). macOS platform is included so pure-logic tests run fast in CI.
import PackageDescription

let package = Package(
    name: "FatwaBotKit",
    defaultLocalization: "ar",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CoreKit", targets: ["CoreKit"]),
        .library(name: "NetworkingKit", targets: ["NetworkingKit"]),
        .library(name: "DesignSystemKit", targets: ["DesignSystemKit"]),
        .library(name: "ConfigKit", targets: ["ConfigKit"]),
        .library(name: "ContentKit", targets: ["ContentKit"]),
    ],
    targets: [
        .target(
            name: "CoreKit",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "NetworkingKit",
            dependencies: ["CoreKit"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "DesignSystemKit",
            dependencies: ["CoreKit"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "ConfigKit",
            dependencies: ["CoreKit", "NetworkingKit"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "ContentKit",
            dependencies: ["CoreKit", "NetworkingKit"],
            // `.process` flattens the seed JSON to the bundle root, which (a) keeps the
            // simulator bundle shallow — Xcode 26's codesign rejects a shallow bundle
            // that contains a reserved `Resources/` subfolder — and (b) lets
            // `bundle.url(forResource:withExtension:)` (no subdirectory) actually find them.
            resources: [.process("Resources")],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(name: "ConfigKitTests", dependencies: ["ConfigKit"]),
        .testTarget(name: "ContentKitTests", dependencies: ["ContentKit"]),
        .testTarget(name: "CoreKitTests", dependencies: ["CoreKit"]),
        .testTarget(name: "NetworkingKitTests", dependencies: ["NetworkingKit"]),
        .testTarget(name: "DesignSystemKitTests", dependencies: ["DesignSystemKit"]),
    ]
)
