// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TypeFreeCore",
    defaultLocalization: "zh_CN",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "TypeFreeCore", targets: ["TypeFreeCore"])
    ],
    targets: [
        .target(name: "TypeFreeCore"),
        .testTarget(
            name: "TypeFreeCoreTests",
            dependencies: ["TypeFreeCore"]
        )
    ]
)
