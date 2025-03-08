// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RenderKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "RenderKit", targets: ["RenderKit"])],
    targets: [
        .target(name: "RenderKit"),
        .testTarget(name: "RenderKitTests", dependencies: ["RenderKit"])
    ]
)
