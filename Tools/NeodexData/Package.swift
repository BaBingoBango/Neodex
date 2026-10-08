// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NeodexData",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../Packages/NeodexKit"),
    ],
    targets: [
        .executableTarget(
            name: "neodex-data",
            dependencies: [.product(name: "NeodexKit", package: "NeodexKit")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
