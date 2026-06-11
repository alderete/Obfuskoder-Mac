// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ObfuskoderKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ObfuskoderKit", targets: ["ObfuskoderKit"]),
        .library(name: "ObfuskodeCLI", targets: ["ObfuskodeCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "ObfuskoderKit",
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [.linkedFramework("JavaScriptCore")]
        ),
        .target(
            name: "ObfuskodeCLI",
            dependencies: [
                "ObfuskoderKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ObfuskoderKitTests",
            dependencies: ["ObfuskoderKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ObfuskodeCLITests",
            dependencies: ["ObfuskodeCLI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
