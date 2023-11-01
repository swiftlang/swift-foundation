// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

// Availability Macros
let availabilityMacros: [SwiftSetting] = [
    "FoundationPreview 0.1:macOS 9999, iOS 9999, tvOS 9999, watchOS 9999",
    "FoundationPreview 0.2:macOS 9999, iOS 9999, tvOS 9999, watchOS 9999",
    "FoundationPreview 0.3:macOS 9999, iOS 9999, tvOS 9999, watchOS 9999",
    "FoundationPreview 0.4:macOS 9999, iOS 9999, tvOS 9999, watchOS 9999",
].map { .enableExperimentalFeature("AvailabilityMacro=\($0)") }

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
            revision: "d8003787efafa82f9805594bc51100be29ac6903"), // on release/1.1
        .package(
            url: "https://github.com/apple/swift-foundation-icu",
            revision: "0c1de7149a39a9ff82d4db66234dec587b30a3ad"),
        .package(
            url: "https://github.com/apple/swift-syntax.git",
            from: "509.0.2")
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

        // _CShims (Internal)
        .target(name: "_CShims",
                cSettings: [.define("_CRT_SECURE_NO_WARNINGS",
                                    .when(platforms: [.windows]))]),

        // TestSupport (Internal)
        .target(name: "TestSupport", dependencies: [
            "FoundationEssentials",
            "FoundationInternationalization",
        ], swiftSettings: availabilityMacros),

        // FoundationEssentials
        .target(
          name: "FoundationEssentials",
          dependencies: [
            "_CShims",
            "FoundationMacros",
            .product(name: "_RopeModule", package: "swift-collections"),
          ],
          swiftSettings: [
            .enableExperimentalFeature("VariadicGenerics"),
            .enableExperimentalFeature("AccessLevelOnImport")
          ] + availabilityMacros
        ),
        .testTarget(name: "FoundationEssentialsTests", dependencies: [
            "TestSupport",
            "FoundationEssentials"
        ], swiftSettings: availabilityMacros),

        // FoundationInternationalization
        .target(
            name: "FoundationInternationalization",
            dependencies: [
                .target(name: "FoundationEssentials"),
                .target(name: "_CShims"),
                .product(name: "FoundationICU", package: "swift-foundation-icu")
            ],
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport")
            ] + availabilityMacros
        ),
        
        // FoundationMacros
        .macro(
            name: "FoundationMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftParserDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport")
            ] + availabilityMacros
        ),
        .testTarget(
            name: "FoundationMacrosTests",
            dependencies: [
                "FoundationMacros",
                "TestSupport"
            ],
            swiftSettings: availabilityMacros
        )
    ]
)

#if canImport(RegexBuilder)
package.targets.append(contentsOf: [
    .testTarget(name: "FoundationInternationalizationTests", dependencies: [
        "TestSupport",
        "FoundationInternationalization"
    ], swiftSettings: availabilityMacros),
])
#endif
