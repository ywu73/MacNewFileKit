// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacNewFileKit",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "FileCreationCore",
            targets: ["FileCreationCore"]
        ),
        .library(
            name: "MacNewFileKitShared",
            targets: ["MacNewFileKitShared"]
        ),
    ],
    targets: [
        .target(
            name: "FileCreationCore",
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "MacNewFileKitShared",
            dependencies: ["FileCreationCore"]
        ),
        .testTarget(
            name: "FileCreationCoreTests",
            dependencies: ["FileCreationCore"]
        ),
        .testTarget(
            name: "MacNewFileKitSharedTests",
            dependencies: ["MacNewFileKitShared"]
        ),
    ]
)
