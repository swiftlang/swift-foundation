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
    platforms: [.macOS("14"), .iOS("16.4"), .tvOS("16.4"), .watchOS("9.4")],
    products: [
        .library(name: "FoundationMacrosLinux", targets: ["FoundationMacrosLinux"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-syntax.git",
            from: "509.0.2")
    ],
    targets: [
        .target(
            name: "FoundationMacrosLinux",
            dependencies: ["FoundationMacrosOrdo"],
            swiftSettings: [
                .enableExperimentalFeature(
                    "AccessLevelOnImport"
                )
            ] + availabilityMacros
        ),
        .macro(
            name: "FoundationMacrosOrdo",
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
                "FoundationMacrosOrdo"
            ],
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport")
            ] + availabilityMacros
        )
    ]
)
