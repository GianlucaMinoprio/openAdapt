// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenAdaptCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "OpenAdaptCore", targets: ["OpenAdaptCore"])],
    targets: [
        .target(name: "OpenAdaptCore"),
        .testTarget(name: "OpenAdaptCoreTests", dependencies: ["OpenAdaptCore"])
    ]
)
