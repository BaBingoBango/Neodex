// swift-tools-version: 6.2
import PackageDescription

// Scope Lens: the live Pokémon Champions battle observer and advisor, as a library the Mac app
// links. It keeps the compile settings it grew up with (Swift 5 language mode, main-actor default
// isolation, approachable concurrency) so the sources stay byte-for-byte shareable with the
// standalone Scope Lens app and its diagnostics harnesses.
let package = Package(
    name: "ScopeLens",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ScopeLens", targets: ["ScopeLens"]),
    ],
    targets: [
        .target(
            name: "ScopeLens",
            resources: [.process("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        .testTarget(
            name: "ScopeLensTests",
            dependencies: ["ScopeLens"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .defaultIsolation(MainActor.self),
            ]
        ),
    ]
)
