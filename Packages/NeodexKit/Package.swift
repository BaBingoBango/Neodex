// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NeodexKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "NeodexKit", targets: ["NeodexKit"]),
    ],
    targets: [
        .target(
            name: "NeodexKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "NeodexKitTests",
            dependencies: ["NeodexKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
