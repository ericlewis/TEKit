// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "TEKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TEKit", targets: ["TEKit"]),
    ],
    targets: [
        .target(name: "TEKit"),
    ]
)
