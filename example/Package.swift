// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "GazePointExample",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .executableTarget(
            name: "GazePointExample",
            dependencies: [
                .product(name: "GazePointSDK", package: "macos")
            ],
            path: ".",
            exclude: ["README.md", "Package.swift"]
        )
    ]
)
