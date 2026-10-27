// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchIslandSports",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .target(name: "IslandCore", path: "Core"),
        .testTarget(name: "IslandCoreTests", dependencies: ["IslandCore"], path: "Tests/IslandCoreTests"),
        .executableTarget(name: "notch-approval-hook", dependencies: ["IslandCore"], path: "Helpers/ApprovalHook"),
        .executableTarget(
            name: "NotchIslandSports",
            dependencies: ["IslandCore"],
            path: "Sources",
            exclude: ["App/Info.plist"]
        )
    ]
)

