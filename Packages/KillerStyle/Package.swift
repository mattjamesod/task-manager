// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KillerStyle",
    platforms: [.macOS(.v15), .iOS(.v17)],
    products: [
        .library(
            name: "KillerStyle",
            targets: ["KillerStyle"]
        ),
    ],
    targets: [
        .target(
            name: "KillerStyle"
        )
    ]
)
