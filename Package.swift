// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FoundationPreview",
    platforms: [.macOS("13.3"), .iOS("16.4"), .tvOS("16.4"), .watchOS("9.4")],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(name: "FoundationPreview", targets: ["FoundationPreview"]),
        .library(name: "FoundationEssentials", targets: ["FoundationEssentials"]),
        .library(name: "FoundationInternationalization", targets: ["FoundationInternationalization"]),
        .library(name: "FoundationNetworking", targets: ["FoundationNetworking"])
    ],
    dependencies: [
        .package(url: "git@github.com:apple/swift-foundation-icu.git", branch: "main")
    ],
    targets: [
        // Foundation (umbrella)
        .target(
            name: "FoundationPreview",
            dependencies: [
                "FoundationEssentials",
                "FoundationInternationalization",
                "FoundationNetworking",
            ],
            path: "Sources/Foundation"),

        // _CShims (Internal)
        .target(name: "_CShims"),
        // TestSupport (Internal)
        .target(name: "TestSupport", dependencies: [
            "FoundationEssentials",
            "FoundationInternationalization",
            "FoundationNetworking"
        ]),

        // FoundationEssentials
        .target(name: "FoundationEssentials", dependencies: ["_CShims"]),
        .testTarget(name: "FoundationEssentialsTests", dependencies: [
            "TestSupport",
            "FoundationEssentials"
        ]),

        // FoundationInternationalization
        .target(name: "FoundationInternationalization", dependencies: [
            .target(name: "FoundationEssentials"),
            .target(name: "_CShims"),
            .product(name: "FoundationICU", package: "swift-foundation-icu")
        ]),
        .testTarget(name: "FoundationInternationalizationTests", dependencies: [
            "TestSupport",
            "FoundationInternationalization"
        ]),

        // FoundationNetworking
        .target(name: "FoundationNetworking"),
        .testTarget(name: "FoundationNetworkingTests", dependencies: [
            "TestSupport",
            "FoundationNetworking"
        ]),
    ]
)
