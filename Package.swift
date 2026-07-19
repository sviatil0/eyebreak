// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyeBreak",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "EyeBreak",
            path: "Sources/EyeBreak"
        ),
        .testTarget(
            name: "EyeBreakTests",
            dependencies: ["EyeBreak"],
            path: "Tests/EyeBreakTests"
        ),
    ]
)
