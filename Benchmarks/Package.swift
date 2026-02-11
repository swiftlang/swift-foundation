// swift-tools-version: 5.9

import PackageDescription

enum UsePackage {
    /// Use a known package hash downloaded from GitHub. Set with env var `USE_PACKAGE`
    case useGitHubPackage

    /// Use a local package, rooted at `String`. For example ".." to back up one directory from the Benchmark package. This is useful when testing local changes. 
    /// Set with env var `SWIFTCI_USE_LOCAL_DEPS=<path to root>`, for example `SWIFTCI_USE_LOCAL_DEPS=..`
    case useLocalPackage(String)

    /// Use Foundation.framework (Darwin) or the toolchain (Linux)
    case useToolchain

    var description: String {
        switch self {
            case .useGitHubPackage: 
                return "Using GitHub package"
            case .useLocalPackage(let root):
                #if os(macOS)
                    return "Using local package checkout at \(root)/swift-foundation"
                #else
                    return "Using local package checkout at \(root)/swift-corelibs-foundation"
                #endif
            case .useToolchain:
                #if os(macOS)
                    return "Using system Foundation.framework"
                #else
                    return "Using toolchain Foundation"
                #endif
        }
    }
}

let usePackage: UsePackage

if let useLocalPackageEnv = Context.environment["SWIFTCI_USE_LOCAL_DEPS"], !useLocalPackageEnv.isEmpty {
    if useLocalPackageEnv == "1" {
        usePackage = .useLocalPackage("../..")
    } else {
        usePackage = .useLocalPackage(useLocalPackageEnv)
    }
} else if let usePackageEnv = Context.environment["USE_PACKAGE"], !usePackageEnv.isEmpty {
    usePackage = .useGitHubPackage
} else {
    usePackage = .useToolchain
}

print("swift-foundation benchmarks: \(usePackage.description)")

// ------------

var packageDependency : [Package.Dependency] = [.package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.11.1")]
var targetDependency : [Target.Dependency] = [.product(name: "Benchmark", package: "package-benchmark")]
var i18nTargetDependencies : [Target.Dependency] = []
var swiftSettings : [SwiftSetting] = [.unsafeFlags(["-Rmodule-loading"]), .enableUpcomingFeature("MemberImportVisibility")]

switch usePackage {
    case .useLocalPackage(let root):
        #if os(macOS)
            packageDependency.append(.package(name: "foundation-local", path: "\(root)/swift-foundation"))
            targetDependency.append(.product(name: "FoundationEssentials", package: "foundation-local"))
            targetDependency.append(.product(name: "FoundationInternationalization", package: "foundation-local"))
        #else
            packageDependency.append(.package(name: "foundation-local", path: "\(root)/swift-corelibs-foundation"))
            // Foundation re-exports FoundationEssentials and FoundationInternationalization
            targetDependency.append(.product(name: "Foundation", package: "foundation-local"))
        #endif
        swiftSettings.append(.define("USE_PACKAGE"))

    case .useGitHubPackage:
        #if os(macOS)
            packageDependency.append(.package(url: "https://github.com/apple/swift-foundation", branch: "main"))
            targetDependency.append(.product(name: "FoundationEssentials", package: "swift-foundation"))
            targetDependency.append(.product(name: "FoundationInternationalization", package: "swift-foundation"))
        #else
            packageDependency.append(.package(url: "https://github.com/apple/swift-corelibs-foundation", branch: "main"))
            targetDependency.append(.product(name: "Foundation", package: "swift-corelibs-foundation"))
        #endif

        swiftSettings.append(.define("USE_PACKAGE"))

    case .useToolchain:
        break
}


let package = Package(
    name: "benchmarks",
    platforms: [.macOS("26"), .iOS("26"), .tvOS("26"), .watchOS("26"), .visionOS("26")], // Should match parent project
    dependencies: packageDependency,
    targets: [
        .executableTarget(
            name: "PredicateBenchmarks",
            dependencies: targetDependency,
            path: "Benchmarks/Predicates",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "InternationalizationBenchmarks",
            dependencies: targetDependency,
            path: "Benchmarks/Internationalization",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "EssentialsBenchmarks",
            dependencies: targetDependency,
            path: "Benchmarks/Essentials",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "DataBenchmarks",
            dependencies: targetDependency,
            path: "Benchmarks/Data",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "DataIOBenchmarks",
            dependencies: targetDependency,
            path: "Benchmarks/DataIO",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "FormattingBenchmarks",
            dependencies: targetDependency,
            path: "Benchmarks/Formatting",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "StringBenchmarks",
            dependencies: targetDependency,
            path: "Benchmarks/String",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "AttributedStringBenchmarks",
            dependencies: targetDependency,
            path: "Benchmarks/AttributedString",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "JSONBenchmarks",
            dependencies: targetDependency,
            path: "Benchmarks/JSON",
            resources: [.copy("Resources")],
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "URLBenchmarks",
            dependencies: targetDependency,
            path: "Benchmarks/URL",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "Base64Benchmarks",
            dependencies: targetDependency,
            path: "Benchmarks/Base64",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
    ]
)

