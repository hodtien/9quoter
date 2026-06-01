// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "9QuoterApp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "9QuoterApp",
            path: "Sources/9QuoterApp"
        ),
        .testTarget(
            name: "9QuoterAppTests",
            dependencies: ["9QuoterApp"],
            path: "Tests/9QuoterAppTests"
        )
    ]
)
