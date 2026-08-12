// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "GazePointExample",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .executableTarget(
            name: "GazePointExample",
            dependencies: [
                .product(name: "GazePointSDK", package: "GazePointSDK")
            ],
            path: "."
        )
    ]
)
