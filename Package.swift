// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swiftui-api-interface",
    platforms: [
        .macOS("10.15")
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
