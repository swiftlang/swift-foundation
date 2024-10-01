//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
#else
import Foundation
#endif

#if !FOUNDATION_FRAMEWORK
private func autoreleasepool<T>(_ block: () -> T) -> T { block() }
#endif

#if canImport(Glibc)
import Glibc
#endif
#if canImport(Darwin)
import Darwin
#endif

let benchmarks = {
    Benchmark(
        "base64-encode-jwtHeader-toString-noOptions",
        configuration: Benchmark.Configuration(
            metrics: [.cpuTotal, .mallocCountTotal, .throughput],
            scalingFactor: .kilo,
            maxDuration: .seconds(3)
        )
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(jwtHeaderTestData.base64EncodedString())
            }
        }
    }

    Benchmark(
        "base64-encode-1MB-toString-noOptions",
        configuration: Benchmark.Configuration(
            metrics: [.cpuTotal, .mallocCountTotal, .throughput],
            scalingFactor: .one,
            maxDuration: .seconds(3)
        )
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(oneMBTestData.base64EncodedString())
            }
        }
    }

    Benchmark(
        "base64-encode-1MB-toData-noOptions",
        configuration: Benchmark.Configuration(
            metrics: [.cpuTotal, .mallocCountTotal, .throughput],
            scalingFactor: .one,
            maxDuration: .seconds(3)
        )
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(oneMBTestData.base64EncodedData())
            }
        }
    }

    Benchmark(
        "base64-encode-1MB-toString-lineLength64",
        configuration: Benchmark.Configuration(
            metrics: [.cpuTotal, .mallocCountTotal, .throughput],
            scalingFactor: .one,
            maxDuration: .seconds(3)
        )
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(oneMBTestData.base64EncodedString(options: .lineLength64Characters))
            }
        }
    }

    Benchmark(
        "base64-decode-jwtHeader-fromString-noOptions",
        configuration: Benchmark.Configuration(
            metrics: [.cpuTotal, .mallocCountTotal, .throughput],
            scalingFactor: .kilo,
            maxDuration: .seconds(3)
        )
    ) { benchmark in
        let base64DataString = jwtHeaderTestData.base64EncodedString()

        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(Data(base64Encoded: base64DataString))
            }
        }
    }

    Benchmark(
        "base64-decode-1MB-fromString-noOptions",
        configuration: Benchmark.Configuration(
            metrics: [.cpuTotal, .mallocCountTotal, .throughput],
            scalingFactor: .one,
            maxDuration: .seconds(3)
        )
    ) { benchmark in
        let base64DataString = oneMBTestData.base64EncodedString()

        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(Data(base64Encoded: base64DataString))
            }
        }
    }

    Benchmark(
        "base64-decode-1MB-fromData-noOptions",
        configuration: Benchmark.Configuration(
            metrics: [.cpuTotal, .mallocCountTotal, .throughput],
            scalingFactor: .one,
            maxDuration: .seconds(3)
        )
    ) { benchmark in
        let base64Data = oneMBTestData.base64EncodedData()

        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(Data(base64Encoded: base64Data))
            }
        }
    }

    Benchmark(
        "base64-decode-1MB-fromData-noOptions-invalidAfter257bytes",
        configuration: Benchmark.Configuration(
            metrics: [.cpuTotal, .mallocCountTotal, .throughput],
            scalingFactor: .kilo,
            maxDuration: .seconds(3)
        )
    ) { benchmark in
        var base64Data = oneMBTestData.base64EncodedData()
        base64Data[257] = 0

        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(Data(base64Encoded: base64Data))
            }
        }
    }

    Benchmark(
        "base64-decode-1MB-fromString-lineLength64",
        configuration: Benchmark.Configuration(
            metrics: [.cpuTotal, .mallocCountTotal, .throughput],
            scalingFactor: .one,
            maxDuration: .seconds(3)
        )
    ) { benchmark in
        let base64DataString = oneMBTestData.base64EncodedString(options: .lineLength64Characters)

        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(Data(base64Encoded: base64DataString, options: .ignoreUnknownCharacters))
            }
        }
    }

}

let jwtHeaderTestData = Data(#"{"alg":"ES256","typ":"JWT"}"#.utf8)
let oneMBTestData = createTestData(count: 1000 * 1024)
func createTestData(count: Int) -> Data {
    var data = Data(count: count)
    for index in data.indices {
        data[index] = UInt8(index % Int(UInt8.max))
    }
    return data
}
