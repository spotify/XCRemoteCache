// swift-tools-version:5.3
// swiftlint:disable:previous file_header
// The swift-tools-version declares the minimum version of Swift required to build this package

import PackageDescription

let package = Package(
    name: "XCRemoteCache",
    platforms: [
        .macOS(.v10_14),
    ],
    products: [
        .executable(name: "xcprebuild", targets: ["xcprebuild"]),
    ],
    dependencies: [
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.2"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.0.1"),
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.9.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "XCRemoteCache",
            dependencies: ["Zip", "Yams", "XcodeProj"]
        ),
        .target(
            name: "xcprebuild",
            dependencies: ["XCRemoteCache"]
        ),
        .target(
            name: "xcswiftc",
            dependencies: ["XCRemoteCache"]
        ),
        .target(
            name: "xcswift-frontend",
            dependencies: ["XCRemoteCache"]
        ),
        .target(
            name: "xclibtoolSupport",
            dependencies: ["XCRemoteCache"]
        ),
        .target(
            name: "xclibtool",
            dependencies: ["XCRemoteCache", "xclibtoolSupport"]
        ),
        .target(
            name: "xclipo",
            dependencies: ["XCRemoteCache"]
        ),
        .target(
            name: "xcpostbuild",
            dependencies: ["XCRemoteCache"]
        ),
        .target(
            name: "xcprepare",
            dependencies: [
                "XCRemoteCache",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "xcld",
            dependencies: ["XCRemoteCache"]
        ),
        .target(
            name: "xcldplusplus",
            dependencies: ["XCRemoteCache"]
        ),
        .target(
            name: "xcactool",
            dependencies: ["XCRemoteCache"]
        ),
        .target(
            // Wrapper target that builds all binaries but does nothing in runtime
            name: "Aggregator",
            dependencies: [
                "xcprebuild",
                "xcswiftc",
                "xcswift-frontend",
                "xclibtool",
                "xcpostbuild",
                "xcprepare",
                "xcld",
                "xcldplusplus",
                "xclipo",
                "xcactool"
            ]
        ),
        .testTarget(
            name: "XCRemoteCacheTests",
            dependencies: ["XCRemoteCache"],
            resources: [.copy("TestData")]
        ),
        .testTarget(
            name: "xclibtoolSupportTests",
            dependencies: ["xclibtoolSupport"]
        ),
    ]
)
