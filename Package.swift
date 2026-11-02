// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mini-satset",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "mini-satset",
            targets: ["mini-satset"]
        )
    ],
    targets: [
        .executableTarget(
            name: "mini-satset",
            path: "Sources/mini-satset"
        )
    ]
)
