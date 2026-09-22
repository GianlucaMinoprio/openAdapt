// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenAdaptCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "OpenAdaptCore", targets: ["OpenAdaptCore"])],
    dependencies: [.package(url: "https://github.com/apple/swift-crypto.git", exact: "4.5.2")],
    targets: [
        .target(name: "OpenAdaptCore", dependencies: [.product(name: "CryptoExtras", package: "swift-crypto")]),
        .testTarget(name: "OpenAdaptCoreTests", dependencies: ["OpenAdaptCore"])
    ]
)
