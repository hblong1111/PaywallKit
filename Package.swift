// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PaywallKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PaywallKit", targets: ["PaywallKit"]),
        .library(name: "PaywallKitUI", targets: ["PaywallKitUI"]),
        .library(name: "PaywallKitRevenueCat", targets: ["PaywallKitRevenueCat"]),
        .library(name: "PaywallKitSuperwall", targets: ["PaywallKitSuperwall"]),
    ],
    targets: [
        .target(
            name: "PaywallKit"
        ),
        .target(
            name: "PaywallKitUI",
            dependencies: ["PaywallKit"]
        ),
        .target(
            name: "PaywallKitRevenueCat",
            dependencies: ["PaywallKit"]
        ),
        .target(
            name: "PaywallKitSuperwall",
            dependencies: ["PaywallKit"]
        ),
        .testTarget(
            name: "PaywallKitTests",
            dependencies: ["PaywallKit"]
        ),
    ]
)
