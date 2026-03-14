import PackageDescription
let package = Package(name: "swift-macro-demo", platforms: [.macOS(.v10_15)], targets: [.executableTarget(name: "swift-macro-demo", path: "Sources")])
