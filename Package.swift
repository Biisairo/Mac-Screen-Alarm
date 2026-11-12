// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenAlarm",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "AlarmCore"),
        .executableTarget(name: "ScreenAlarm", dependencies: ["AlarmCore"]),
        .executableTarget(name: "CoreTestRunner", dependencies: ["AlarmCore"]),
    ]
)
