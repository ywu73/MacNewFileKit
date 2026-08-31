// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RightClick",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "FileCreationCore",
            targets: ["FileCreationCore"]
        ),
        .library(
            name: "RightClickShared",
            targets: ["RightClickShared"]
        ),
    ],
    targets: [
        .target(
            name: "FileCreationCore"
        ),
        .target(
            name: "RightClickShared",
            dependencies: ["FileCreationCore"]
        ),
        .testTarget(
            name: "FileCreationCoreTests",
            dependencies: ["FileCreationCore"]
        ),
        .testTarget(
            name: "RightClickSharedTests",
            dependencies: ["RightClickShared"]
        ),
    ]
)
