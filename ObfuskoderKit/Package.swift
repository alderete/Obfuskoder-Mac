// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ObfuskoderKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ObfuskoderKit", targets: ["ObfuskoderKit"])
    ],
    targets: [
        .target(
            name: "ObfuskoderKit",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("JavaScriptCore")]
        ),
        .testTarget(
            name: "ObfuskoderKitTests",
            dependencies: ["ObfuskoderKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
