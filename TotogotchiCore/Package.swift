// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TotogotchiCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TotogotchiCore", targets: ["TotogotchiCore"])
    ],
    targets: [
        .target(
            name: "TotogotchiCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "TotogotchiCoreTests",
            dependencies: ["TotogotchiCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
