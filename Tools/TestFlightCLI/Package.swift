// swift-tools-version: 6.2
import PackageDescription

/// A small App Store Connect API client for Neodex: TestFlight feedback, crash reports and build
/// status, signed with an API key that lives in ~/.appstoreconnect and never in this repository.
let package = Package(
    name: "TestFlightCLI",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "testflight", targets: ["testflight"]),
    ],
    targets: [
        .target(name: "AppStoreConnect"),
        .executableTarget(name: "testflight", dependencies: ["AppStoreConnect"]),
        .testTarget(name: "AppStoreConnectTests", dependencies: ["AppStoreConnect"]),
    ]
)
