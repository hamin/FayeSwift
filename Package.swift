// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "FayeSwift",
    products: [
        .library(name: "FayeClient", targets: ["Faye"]),
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0")
    ],
    targets: [
    .systemLibrary(name: "Faye", path: "Sources", pkgConfig: nil, providers: nil)
    ]
)
