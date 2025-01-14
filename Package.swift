// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swiftui-api-interface",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "APIInterface",
            targets: ["APIInterface"]
        ),
    ],
    targets: [
        .target(name: "APIInterface"),
    ]
)
