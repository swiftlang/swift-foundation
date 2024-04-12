// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

// Availability Macros

let availabilityTags: [_Availability] = [
    _Availability("FoundationPreview"), // Default FoundationPreview availability,
    _Availability("FoundationPredicate", availability: .macOS14_0), // Predicate relies on pack parameter runtime support
    _Availability("FoundationPredicateRegex", availability: .future) // Predicate regexes rely on new stdlib APIs
]
let versionNumbers = ["0.1", "0.2", "0.3", "0.4"]

// Availability Macro Utilities

enum _OSAvailability: String {
    case alwaysAvailable = "macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4" // This should match the package's deployment target
    case macOS14_0 = "macOS 14, iOS 17, tvOS 17, watchOS 10"
    // Use 10000 for future availability to avoid compiler magic around the 9999 version number but ensure it is greater than 9999
    case future = "macOS 10000, iOS 10000, tvOS 10000, watchOS 10000"
}
struct _Availability {
    let name: String
    let osAvailability: _OSAvailability
    
    init(_ name: String, availability: _OSAvailability = .alwaysAvailable) {
        self.name = name
        self.osAvailability = availability
    }
}
let availabilityMacros: [SwiftSetting] = versionNumbers.flatMap { version in
    availabilityTags.map {
        .enableExperimentalFeature("AvailabilityMacro=\($0.name) \(version):\($0.osAvailability.rawValue)")
    }
}

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
            from: "1.1.0"),
        .package(
            url: "https://github.com/apple/swift-foundation-icu",
            exact: "0.0.6"),
        .package(
            url: "https://github.com/apple/swift-syntax.git",
            from: "510.0.0"),
        .package(
            url: "https://github.com/apple/swift-testing.git",
            branch: "main"),
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
            .product(name: "OrderedCollections", package: "swift-collections"),
          ],
          cSettings: [
            .define("_GNU_SOURCE", .when(platforms: [.linux]))
          ],
          swiftSettings: [
            .enableExperimentalFeature("VariadicGenerics"),
            .enableExperimentalFeature("AccessLevelOnImport")
          ] + availabilityMacros
        ),
        .testTarget(
            name: "FoundationEssentialsTests",
            dependencies: [
                "FoundationEssentials",
                .product(name: "Testing", package: "swift-testing"),
            ],
            resources: [
                .copy("Resources")
            ],
            swiftSettings: availabilityMacros
        ),

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
        ),
    ]
)

#if canImport(RegexBuilder)
package.targets.append(contentsOf: [
    .testTarget(name: "FoundationInternationalizationTests", dependencies: [
        "TestSupport",
        "FoundationInternationalization",
    ], swiftSettings: availabilityMacros),
])
#endif
