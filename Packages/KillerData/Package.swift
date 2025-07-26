// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KillerData",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(
            name: "KillerData",
            targets: ["KillerData"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.0.1"),
        .package(path: "../../../packages/AndHashUtilities"),
    ],
    targets: [
        .target(
            name: "KillerData",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "UtilViews", package: "AndHashUtilities"),
                .product(name: "UtilExtensions", package: "AndHashUtilities"),
                .product(name: "Logging", package: "AndHashUtilities"),
            ]
        ),
        .testTarget(
            name: "KillerDataTests",
            dependencies: ["KillerData"]
        ),
    ]
)
