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
        .library(name: "APIInterface", targets: ["APIInterface"]),
        .library(name: "HTTPAPIInterface", targets: ["HTTPAPIInterface", "APIInterface"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.24.0"),
    ],
    targets: [
        .target(
            name: "APIInterface"
        ),
        .target(
            name: "HTTPAPIInterface",
            dependencies: [
                .target(name: "APIInterface"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "JSONLegacy", package: "swift-json"),
            ]
        ),
    ]
)
