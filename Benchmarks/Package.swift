// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "benchmarks",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.11.1"),
    ],
    targets: [
        .executableTarget(
            name: "PredicateBenchmarks",
            dependencies: [
                .product(name: "FoundationEssentials", package: "swift-foundation"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/Predicates",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
    ]
)
