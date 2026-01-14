// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MDView",
    platforms: [.macOS(.v12)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MDView",
            dependencies: [],
            resources: [.process("Resources")]
        )
    ]
)
