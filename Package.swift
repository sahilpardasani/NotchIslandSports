// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchIslandSports",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "NotchIslandSports",
            path: "Sources",
            exclude: ["App/Info.plist"]
        )
    ]
)
