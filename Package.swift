import PackageDescription

let package = Package(
    name: "FayeSwift",
    targets: [],
    dependencies: [
		.Package(url: "https://github.com/daltoniam/Starscream.git", versions: "4.0.0" ..< Version.max)
    ]
)
