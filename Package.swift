// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

// Availability Macros

let availabilityTags: [_Availability] = [
    _Availability("FoundationPreview"), // Default FoundationPreview availability,
    _Availability("FoundationPredicate", availability: .macOS14_0), // Predicate relies on pack parameter runtime support
    _Availability("FoundationPredicateRegex", availability: .macOS15_0) // Predicate regexes rely on new stdlib APIs
]
let versionNumbers = ["0.1", "0.2", "0.3", "0.4", "6.0.2", "6.1", "6.2"]

// Availability Macro Utilities

enum _OSAvailability: String {
    case alwaysAvailable = "macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4" // This should match the package's deployment target
    case macOS14_0 = "macOS 14, iOS 17, tvOS 17, watchOS 10"
    case macOS15_0 = "macOS 15, iOS 18, tvOS 18, watchOS 11"
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

let concurrencyChecking: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("InferSendableFromCaptures")
]

var dependencies: [Package.Dependency] {
    if Context.environment["SWIFTCI_USE_LOCAL_DEPS"] != nil {
        [
            .package(
                name: "swift-collections",
                path: "../swift-collections"),
            .package(
                name: "swift-foundation-icu",
                path: "../swift-foundation-icu"),
            .package(
                name: "swift-syntax",
                path: "../swift-syntax")
        ]
    } else {
        [
            .package(
                url: "https://github.com/apple/swift-collections",
                from: "1.1.0"),
            .package(
                url: "https://github.com/apple/swift-foundation-icu",
                branch: "main"),
            .package(
                url: "https://github.com/swiftlang/swift-syntax",
                branch: "main")
        ]
    }
}

let wasiLibcCSettings: [CSetting] = [
    .define("_WASI_EMULATED_SIGNAL", .when(platforms: [.wasi])),
    .define("_WASI_EMULATED_MMAN", .when(platforms: [.wasi])),
]

let package = Package(
    name: "swift-foundation",
    platforms: [.macOS("13.3"), .iOS("16.4"), .tvOS("16.4"), .watchOS("9.4")],
    products: [
        .library(name: "FoundationEssentials", targets: ["FoundationEssentials"]),
        .library(name: "FoundationInternationalization", targets: ["FoundationInternationalization"]),
    ],
    dependencies: dependencies,
    targets: [
        // _FoundationCShims (Internal)
        .target(
            name: "_FoundationCShims",
            cSettings: [
                .define("_CRT_SECURE_NO_WARNINGS", .when(platforms: [.windows]))
            ] + wasiLibcCSettings
        ),

        // TestSupport (Internal)
        .target(
            name: "TestSupport",
            dependencies: [
                "FoundationEssentials",
                "FoundationInternationalization",
            ],
            cSettings: wasiLibcCSettings,
            swiftSettings: availabilityMacros + concurrencyChecking
        ),

        // FoundationEssentials
        .target(
          name: "FoundationEssentials",
          dependencies: [
            "_FoundationCShims",
            "FoundationMacros",
            .product(name: "_RopeModule", package: "swift-collections"),
            .product(name: "OrderedCollections", package: "swift-collections"),
          ],
          exclude: [
            "Formatting/CMakeLists.txt",
            "PropertyList/CMakeLists.txt",
            "Decimal/CMakeLists.txt",
            "String/CMakeLists.txt",
            "Error/CMakeLists.txt",
            "Locale/CMakeLists.txt",
            "Data/CMakeLists.txt",
            "TimeZone/CMakeLists.txt",
            "JSON/CMakeLists.txt",
            "AttributedString/CMakeLists.txt",
            "Calendar/CMakeLists.txt",
            "Predicate/CMakeLists.txt",
            "CMakeLists.txt",
            "ProcessInfo/CMakeLists.txt",
            "FileManager/CMakeLists.txt",
            "URL/CMakeLists.txt"
          ],
          cSettings: [
            .define("_GNU_SOURCE", .when(platforms: [.linux]))
          ] + wasiLibcCSettings,
          swiftSettings: [
            .enableExperimentalFeature("VariadicGenerics"),
            .enableExperimentalFeature("AccessLevelOnImport")
          ] + availabilityMacros + concurrencyChecking,
          linkerSettings: [
            .linkedLibrary("wasi-emulated-getpid", .when(platforms: [.wasi])),
          ]
        ),
        .testTarget(
            name: "FoundationEssentialsTests",
            dependencies: [
                "TestSupport",
                "FoundationEssentials"
            ],
            resources: [
                .copy("Resources")
            ],
            swiftSettings: availabilityMacros + concurrencyChecking
        ),

        // FoundationInternationalization
        .target(
            name: "FoundationInternationalization",
            dependencies: [
                .target(name: "FoundationEssentials"),
                .target(name: "_FoundationCShims"),
                .product(name: "_FoundationICU", package: "swift-foundation-icu")
            ],
            exclude: [
                "String/CMakeLists.txt",
                "TimeZone/CMakeLists.txt",
                "ICU/CMakeLists.txt",
                "Formatting/CMakeLists.txt",
                "Locale/CMakeLists.txt",
                "Calendar/CMakeLists.txt",
                "CMakeLists.txt",
                "Predicate/CMakeLists.txt"
            ],
            cSettings: wasiLibcCSettings,
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport")
            ] + availabilityMacros + concurrencyChecking
        ),
        
        .testTarget(
            name: "FoundationInternationalizationTests",
            dependencies: [
                "TestSupport",
                "FoundationInternationalization",
            ],
            swiftSettings: availabilityMacros + concurrencyChecking
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
            exclude: ["CMakeLists.txt"],
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport")
            ] + availabilityMacros + concurrencyChecking
        ),
    ]
)

// https://github.com/apple/swift-package-manager/issues/7174
// Test macro targets result in multiple definitions of `main` on Windows.
#if !os(Windows)
package.targets.append(contentsOf: [
    .testTarget(
        name: "FoundationMacrosTests",
        dependencies: [
            "FoundationMacros",
            "TestSupport"
        ],
        swiftSettings: availabilityMacros + concurrencyChecking
    )
])
#endif
