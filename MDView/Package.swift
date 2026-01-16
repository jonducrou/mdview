// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MDView",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "MarkdownParserLib", targets: ["MarkdownParserLib"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MarkdownParserLib",
            dependencies: []
        ),
        .executableTarget(
            name: "MDView",
            dependencies: ["MarkdownParserLib"]
        ),
        .testTarget(
            name: "MarkdownParserTests",
            dependencies: ["MarkdownParserLib"]
        )
    ]
)
