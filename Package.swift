// swift-tools-version: 6.0
// The standalone Swift package is in swift/.
// This manifest preserves Swift Package Manager integration from the repository root.

import PackageDescription

let package = Package(
    name: "DependencyInitializer",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "DependencyInitializer", targets: ["DependencyInitializer"]),
    ],
    targets: [
        .target(
            name: "DependencyInitializer",
            path: "swift/Sources/DependencyInitializer"
        ),
        .testTarget(
            name: "DependencyInitializerTests",
            dependencies: ["DependencyInitializer"],
            path: "swift/Tests/DependencyInitializerTests"
        ),
    ]
)
