// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "FayeSwift",
    products: [
        .library(name: "FayeSwift", targets: ["FayeSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0")
    ],
    targets: [
        .systemLibrary(name: "FayeSwift", path: "Sources", pkgConfig: nil, providers: nil)
    ]
)
