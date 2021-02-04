import PackageDescription

let package = Package(
    name: "FayeSwift",
    targets: [],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", majorVersion: 4),
		.package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "4.0.0"),
    ]
)
