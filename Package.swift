// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "MoonGoatCore",
    platforms: [.iOS(.v17)],
    products: [.library(name: "MoonGoatCore", targets: ["MoonGoatCore"])],
    targets: [.target(name: "MoonGoatCore"), .testTarget(name: "MoonGoatCoreTests", dependencies: ["MoonGoatCore"])])
