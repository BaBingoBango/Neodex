// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NeodexData",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../Packages/NeodexKit"),
    ],
    targets: [
        // Everything the pipeline does, as a library so it can be tested.
        .target(
            name: "NeodexDataCore",
            dependencies: [.product(name: "NeodexKit", package: "NeodexKit")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // The command-line entry point: argument parsing only.
        .executableTarget(
            name: "neodex-data",
            dependencies: ["NeodexDataCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "NeodexDataCoreTests",
            dependencies: ["NeodexDataCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
