// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KillerModels",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(
            name: "KillerModels",
            targets: ["KillerModels"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3"),
        .package(path: "../KillerData"),
    ],
    targets: [
        .target(
            name: "KillerModels",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                "KillerData",
            ]
        ),
    ]
)
