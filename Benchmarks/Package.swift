// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "benchmarks",
    platforms: [.macOS("13.3"), .iOS("16.4"), .tvOS("16.4"), .watchOS("9.4")], // Should match parent project
    dependencies: [
        .package(name: "swift-foundation-local", path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.11.1"),
    ],
    targets: [
        .executableTarget(
            name: "PredicateBenchmarks",
            dependencies: [
                .product(name: "FoundationEssentials", package: "swift-foundation-local"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/Predicates",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "CalendarBenchmarks",
            dependencies: [
                .product(name: "FoundationEssentials", package: "swift-foundation-local"),
                .product(name: "FoundationInternationalization", package: "swift-foundation-local"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/Calendar",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "EssentialsBenchmarks",
            dependencies: [
                .product(name: "FoundationEssentials", package: "swift-foundation-local"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/Essentials",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "DataIOBenchmarks",
            dependencies: [
                .product(name: "FoundationEssentials", package: "swift-foundation-local"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/DataIO",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),

    ]
)
