// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GeetHubKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GeetHubKit", targets: ["GeetHubKit"]),
    ],
    targets: [
        .target(name: "GeetHubKit"),
        .testTarget(name: "GeetHubKitTests", dependencies: ["GeetHubKit"]),
    ]
)
