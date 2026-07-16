// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

// Availability Macros

let availabilityTags: [_Availability] = [
    _Availability("FoundationPreview"), // Default FoundationPreview availability
]
let versionNumbers = ["6.0.2", "6.1", "6.2", "6.3", "6.4", "6.5"]

// Availability Macro Utilities

enum _OSAvailability: String {
    case alwaysAvailable = "macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26" // This should match the package's deployment target
    // Use 10000 for future availability to avoid compiler magic around the 9999 version number but ensure it is greater than 9999
    case future = "macOS 10000, iOS 10000, tvOS 10000, watchOS 10000, visionOS 10000"
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

let featureSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableExperimentalFeature("ImportMacroAliases"),
    .enableUpcomingFeature("InferSendableFromCaptures"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .swiftLanguageMode(.v5)
]

var dependencies: [Package.Dependency] = []

let buildingForEmbedded: Bool = {
  guard let envvar = Context.environment["SF_EMBEDDED"] else {
    return false
  }
  return Bool(envvar) ?? ((Int(envvar) ?? 0) != 0)
}()

if let useLocalDepsEnv = Context.environment["SWIFTCI_USE_LOCAL_DEPS"], !useLocalDepsEnv.isEmpty {
    let root: String
    if useLocalDepsEnv == "1" {
        root = ".."
    } else {
        root = useLocalDepsEnv
    }
    dependencies +=
        [
            .package(
                name: "swift-collections",
                path: "\(root)/swift-collections"),
            .package(
                name: "swift-foundation-icu",
                path: "\(root)/swift-foundation-icu"),
            .package(
                name: "swift-syntax",
                path: "\(root)/swift-syntax")
        ]
} else {
    // These dependencies should match `update-checkout`
    // See `update-checkout-config.json` for the `main` branch-scheme
    dependencies +=
        [
            // SwiftCollections Needs to enable embedded mode as well
            .package(
                name: "swift-collections",
                path: "../SwiftCollectionsEmbedded"
            ),
            .package(
                url: "https://github.com/apple/swift-foundation-icu",
                branch: "main"),
        ]
    if !buildingForEmbedded {
        dependencies.append(
            .package(
                url: "https://github.com/swiftlang/swift-syntax",
                branch: "main")
        )
    }
}

var foundationEssentialsDependencies: [Target.Dependency] = [
    "_FoundationCShims",
    .product(name: "_RopeModule", package: "swift-collections"),
    .product(name: "DequeModule", package: "swift-collections"),
    .product(name: "OrderedCollections", package: "swift-collections"),
]
if !buildingForEmbedded {
    foundationEssentialsDependencies.append(Target.Dependency(stringLiteral: "FoundationMacros"))
}

let wasiLibcCSettings: [CSetting] = [
    .define("_WASI_EMULATED_SIGNAL", .when(platforms: [.wasi])),
    .define("_WASI_EMULATED_MMAN", .when(platforms: [.wasi])),
]

let testOnlySwiftSettings: [SwiftSetting] = [
    .define("FOUNDATION_EXIT_TESTS", .when(platforms: [.macOS, .linux, .openbsd, .windows]))
]

var targets: [Target] = [
    // _FoundationCShims (Internal)
    .target(
        name: "_FoundationCShims",
        cSettings: [
            .define("_CRT_SECURE_NO_WARNINGS", .when(platforms: [.windows]))
        ] + wasiLibcCSettings
    ),

    // FoundationEssentials
    .target(
      name: "FoundationEssentials",
      dependencies: foundationEssentialsDependencies,
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
        "URL/CMakeLists.txt",
        "NotificationCenter/CMakeLists.txt",
        "ProgressManager/CMakeLists.txt",
      ],
      cSettings: [
        .define("_GNU_SOURCE", .when(platforms: [.linux, .wasi]))
      ] + wasiLibcCSettings,
      swiftSettings: [
        .enableExperimentalFeature("VariadicGenerics"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("AddressableTypes"),
        .enableExperimentalFeature("AllowUnsafeAttribute"),
        .enableExperimentalFeature("BuiltinModule"),
        .enableExperimentalFeature("AccessLevelOnImport"),
        // Embedded Swift support is scoped to this target only. It must NOT
        // be added to the shared `featureSettings`, since that would apply it
        // to FoundationMacros (a SwiftSyntax compiler plugin that cannot build
        // in embedded mode) and other host-side targets.
        .enableExperimentalFeature("Embedded"),
        .unsafeFlags(["-wmo"]),
        .define("DATA_LEGACY_ABI", .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS]))
      ] + availabilityMacros + featureSettings,
      linkerSettings: [
        .linkedLibrary("wasi-emulated-getpid", .when(platforms: [.wasi])),
      ]
    ),
]

if !buildingForEmbedded {
    targets += [
        // TestSupport (Internal)
        .target(
            name: "TestSupport",
            path: "Tests/TestSupport",
            cSettings: wasiLibcCSettings,
            swiftSettings: availabilityMacros + featureSettings
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
            swiftSettings: [
                .define("DATA_LEGACY_ABI", .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS]))
            ] + availabilityMacros + featureSettings + testOnlySwiftSettings
        ),

        // FoundationInternationalization
        .target(
            name: "_FoundationInternationalizationData",
            dependencies: [
                "_FoundationCShims"
            ]
        ),
        .target(
            name: "FoundationInternationalization",
            dependencies: [
                .target(name: "FoundationEssentials"),
                .target(name: "_FoundationCShims"),
                .target(name: "_FoundationInternationalizationData"),
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
                "Predicate/CMakeLists.txt",
            ],
            cSettings: wasiLibcCSettings,
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport"),
                .enableExperimentalFeature("Lifetimes"),
            ] + availabilityMacros + featureSettings
        ),

        .testTarget(
            name: "FoundationInternationalizationTests",
            dependencies: [
                "TestSupport",
                "FoundationInternationalization",
            ],
            swiftSettings: availabilityMacros + featureSettings + testOnlySwiftSettings
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
            ] + availabilityMacros + featureSettings
        ),

        .testTarget(
            name: "FoundationMacrosTests",
            dependencies: [
                "FoundationMacros",
                "FoundationEssentials"
            ],
            swiftSettings: availabilityMacros + featureSettings + testOnlySwiftSettings
        )
    ]
}

var products: [Product] = [
    .library(name: "FoundationEssentials", targets: ["FoundationEssentials"])
]
if !buildingForEmbedded {
    products.append(.library(name: "FoundationInternationalization", targets: ["FoundationInternationalization"]))
}


let package = Package(
    name: "swift-foundation",
    platforms: [.macOS("26"), .iOS("26"), .tvOS("26"), .watchOS("26"), .visionOS("26")],
    products: products,
    dependencies: dependencies,
    targets: targets
)
