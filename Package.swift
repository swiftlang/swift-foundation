// swift-tools-version: 5.8
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
    ],
    dependencies: [
        .package(
          url: "https://github.com/apple/swift-collections",
          revision: "2ca40e2a653e5e04a1c5468a35fc7494ef6db1d3"), // on release/1.1
        .package(url: "https://github.com/apple/swift-foundation-icu", exact: "0.0.2")
    ],
    targets: [
        // Foundation (umbrella)
        .target(
            name: "FoundationPreview",
            dependencies: [
                "FoundationEssentials",
                "FoundationInternationalization",
            ],
            path: "Sources/Foundation"),

        // RustShims (Internal)
        .target(
            name: "RustShims",
            plugins: [.plugin(name: "RustShimsSourceGenPlugin")]),
        .plugin(
            name: "RustShimsSourceGenPlugin",
            capability: .buildTool()
        ),
        
        // TestSupport (Internal)
        .target(name: "TestSupport", dependencies: [
            "FoundationEssentials",
            "FoundationInternationalization",
        ]),

        // FoundationEssentials
        .target(
          name: "FoundationEssentials",
          dependencies: [
            "RustShims",
            .product(name: "_RopeModule", package: "swift-collections"),
          ],
          swiftSettings: [
            .enableExperimentalFeature("VariadicGenerics"),
            .enableExperimentalFeature("AccessLevelOnImport")
          ],
          linkerSettings: [LinkerSetting.unsafeFlags(["-L./Sources/RustShims/", "-lpthread", "-ldl"])]
        ),
        .testTarget(name: "FoundationEssentialsTests", dependencies: [
            "TestSupport",
            "FoundationEssentials"
        ]),

        // FoundationInternationalization
        .target(
            name: "FoundationInternationalization",
            dependencies: [
                .target(name: "FoundationEssentials"),
                .target(name: "RustShims"),
                .product(name: "FoundationICU", package: "swift-foundation-icu")
            ],
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport")
            ],
            linkerSettings: [LinkerSetting.unsafeFlags(["-L./Sources/RustShims/", "-lpthread", "-ldl"])]
        ),
        .testTarget(name: "FoundationInternationalizationTests", dependencies: [
            "TestSupport",
            "FoundationInternationalization"
        ]),
    ]
)
