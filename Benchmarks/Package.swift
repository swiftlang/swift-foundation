// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "benchmarks",
    platforms: [
        .macOS("13.3"),
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.11.1"),
    ],
    targets: [
        .executableTarget(
            name: "Benchmarks",
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
