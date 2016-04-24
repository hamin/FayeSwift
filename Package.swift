import PackageDescription

let package = Package(
    name: "FayeSwift",
    targets: [],
    dependencies: [
        .Package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", versions: "2.3.3" ..< Version.max),
		.Package(url: "https://github.com/daltoniam/Starscream.git", versions: "1.1.3" ..< Version.max)
    ]
)
