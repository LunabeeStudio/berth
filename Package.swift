// swift-tools-version: 6.0
import PackageDescription

let nio: [Target.Dependency] = [
    .product(name: "NIOCore", package: "swift-nio"),
    .product(name: "NIOPosix", package: "swift-nio"),
]

let package = Package(
    name: "berth",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "berth", targets: ["berth"]),
        .library(name: "BerthCore", targets: ["BerthCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.80.0"),
    ],
    targets: [
        .target(name: "BerthCore", dependencies: nio),
        .target(name: "BerthDaemon", dependencies: ["BerthCore"] + nio),
        .executableTarget(
            name: "berth",
            dependencies: [
                "BerthCore",
                "BerthDaemon",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ] + nio
        ),
        .testTarget(name: "BerthDaemonTests", dependencies: ["BerthDaemon", "BerthCore"]),
    ]
)
