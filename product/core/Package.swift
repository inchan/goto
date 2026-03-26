// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "GotoNativeCore",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "GotoNativeCore",
            targets: ["GotoNativeCore"]
        ),
        .executable(
            name: "GotoNativeLaunch",
            targets: ["GotoNativeLaunch"]
        ),
    ],
    targets: [
        .target(
            name: "GotoNativeCore"
        ),
        .executableTarget(
            name: "GotoNativeLaunch",
            dependencies: ["GotoNativeCore"]
        ),
        .testTarget(
            name: "GotoNativeCoreTests",
            dependencies: ["GotoNativeCore"]
        ),
    ]
)
