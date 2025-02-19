// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OSCTools2",
    platforms: [
        .iOS(.v14),
        .tvOS(.v14),
        .macOS(.v11),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "OSCTools2", targets: ["OSCTools2"]),
    ],
    dependencies: [
        .package(url: "https://github.com/orchetect/OSCKit", from: "1.0.0"),
        .package(url: "https://github.com/heestand-xyz/Logger", from: "0.3.0"),
        .package(url: "https://github.com/rwbutler/connectivity", from: "6.1.1"),
    ],
    targets: [
        .target(
            name: "OSCTools2",
            dependencies: [
                "OSCKit",
                .product(name: "Connectivity", package: "connectivity"),
                "Logger"
            ]
        ),
    ]
)
