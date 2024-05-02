// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OSCTools2",
    platforms: [
        .iOS(.v14),
        .tvOS(.v14),
        .macOS(.v11),
    ],
    products: [
        .library(name: "OSCTools2", targets: ["OSCTools2"]),
    ],
    dependencies: [
        .package(url: "https://github.com/orchetect/OSCKit", from: "0.5.0"),
        .package(url: "https://github.com/heestand-xyz/Logger", from: "0.3.0"),
        .package(name: "Reachability", url: "https://github.com/ashleymills/Reachability.swift", from: "5.1.0"),
    ],
    targets: [
        .target(name: "OSCTools2", dependencies: ["OSCKit", "Reachability", "Logger"]),
    ]
)
