// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "WaykUpCore", platforms: [.macOS(.v14)], products: [.library(name: "WaykUpCore", targets: ["WaykUpCore"])], targets: [
    .target(name: "WaykUpCore", path: "WaykUp",
            exclude: ["Services/AlarmSoundPlayer.swift", "Services/SystemAlarmScheduler.swift", "Features/AlarmHomeView.swift", "Features/MathChallengeView.swift", "WaykUpApp.swift", "Resources", "Info.plist"],
            sources: ["Domain", "Services/AlarmRepository.swift", "Features/AlarmStore.swift"]),
    .testTarget(name: "WaykUpCoreTests", dependencies: ["WaykUpCore"], path: "Tests/WaykUpCoreTests")
])
