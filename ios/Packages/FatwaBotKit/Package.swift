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
        .testTarget(name: "CoreKitTests", dependencies: ["CoreKit"]),
        .testTarget(name: "NetworkingKitTests", dependencies: ["NetworkingKit"]),
        .testTarget(name: "DesignSystemKitTests", dependencies: ["DesignSystemKit"]),
    ]
)
