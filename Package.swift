// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

// To develop this package on Apple platforms, set this to true
let developmentOnDarwin = false

#if canImport(Darwin)
let useSystemFoundation = !developmentOnDarwin
#else
// On non Darwin platforms always use package
let useSystemFoundation = false
#endif

let package: Package

if !useSystemFoundation {
    // Availability Macros
    let availabilityMacros: [SwiftSetting] = [
        "FoundationPreview 0.1:macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4",
        "FoundationPredicate 0.1:macOS 14, iOS 17, tvOS 17, watchOS 10",
        "FoundationPreview 0.2:macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4",
        "FoundationPreview 0.3:macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4",
        "FoundationPredicate 0.3:macOS 14, iOS 17, tvOS 17, watchOS 10",
        "FoundationPreview 0.4:macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4",
        "FoundationPredicate 0.4:macOS 14, iOS 17, tvOS 17, watchOS 10",
    ].map { .enableExperimentalFeature("AvailabilityMacro=\($0)") }

    package = Package(
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
                exact: "0.0.5"),
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
            .target(
                name: "_CShims",
                cSettings: [
                    .define("_CRT_SECURE_NO_WARNINGS", .when(platforms: [.windows]))
                ]
            ),

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
} else {
    package = Package(
        name: "FoundationPreview",
        platforms: [.iOS(.v12), .macOS(.v10_13), .tvOS(.v12), .watchOS(.v4)],
        products: [
            .library(
                name: "FoundationPreview",
                targets: ["FoundationPreview"]
            ),
            .library(
                name: "FoundationEssentials",
                targets: ["FoundationEssentials"]
            ),
            .library(
                name: "FoundationInternationalization",
                targets: ["FoundationInternationalization"]
            ),
        ],
        targets: [
            .target(
                name: "FoundationPreview",
                path: "Sources/SystemFoundationExport/FoundationPreview"
            ),
            .target(
                name: "FoundationEssentials",
                path: "Sources/SystemFoundationExport/FoundationEssentials"
            ),
            .target(
                name: "FoundationInternationalization",
                path: "Sources/SystemFoundationExport/FoundationInternationalization"
            ),
        ]
    )
}
