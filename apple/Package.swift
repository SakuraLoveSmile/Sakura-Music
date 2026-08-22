// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SakuraMusicApple",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17)
    ],
    products: [
        .executable(
            name: "SakuraMusicApple",
            targets: ["SakuraMusicApple"]
        ),
        .library(
            name: "SubsonicKit",
            targets: ["SubsonicKit"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SubsonicKit",
            dependencies: [],
            path: "Sources/SubsonicKit"
        ),
        .executableTarget(
            name: "SakuraMusicApple",
            dependencies: ["SubsonicKit"],
            path: "Sources/SakuraMusicApple"
        ),
        .testTarget(
            name: "SubsonicKitTests",
            dependencies: ["SubsonicKit"],
            path: "Tests/SubsonicKitTests"
        )
    ]
)
