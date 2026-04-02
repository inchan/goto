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
    ],
    targets: [
        .target(
            name: "GotoNativeCore"
        ),
        .testTarget(
            name: "GotoNativeCoreTests",
            dependencies: ["GotoNativeCore"]
        ),
    ]
)
