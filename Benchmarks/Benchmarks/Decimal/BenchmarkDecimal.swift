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

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.scalingFactor = .mega
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)
    Benchmark.defaultConfiguration.maxIterations = .count(100_000_000)

    Benchmark("Decimal init from Double(1)") { benchmark in
        let value = Double(1)

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(Decimal.init(value))
        }
        benchmark.stopMeasurement()
    }

    Benchmark("Decimal init from Double.pi") { benchmark in
        let value = Double.pi

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(Decimal.init(value))
        }
        benchmark.stopMeasurement()
    }

    Benchmark("Decimal divide") { benchmark in
        let value = Decimal(Double.pi)
        let divisor = Decimal(10_000)

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(value / divisor)
        }
        benchmark.stopMeasurement()
    }

    Benchmark("Decimal multiply") { benchmark in
        let value1 = Decimal(Double.pi)
        let value2 = Decimal(Double.pi)

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(value1 * value2)
        }
        benchmark.stopMeasurement()
    }

    Benchmark("Decimal add") { benchmark in
        let value1 = Decimal(Double.pi)
        let value2 = Decimal(Double.pi)

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(value1 + value2)
        }
        benchmark.stopMeasurement()
    }
}
