// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HotPlus",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "HotPlus",
            path: "Sources/HotPlus",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
