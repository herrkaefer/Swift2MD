// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Swift2MD",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Swift2MD",
            targets: ["Swift2MD"]
        ),
        .executable(
            name: "swift2md",
            targets: ["Swift2MDCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "Swift2MD"
        ),
        .executableTarget(
            name: "Swift2MDCLI",
            dependencies: [
                "Swift2MD",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/Swift2MDCLI"
        ),
        .testTarget(
            name: "Swift2MDTests",
            dependencies: ["Swift2MD"]
        )
    ]
)
