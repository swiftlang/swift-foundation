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

    Benchmark("Decimal init from Double") { benchmark in
        for i in benchmark.scaledIterations {
            let double = Double(i)
            let result = Decimal(double)
            blackHole(result)
        }
    }

//    Benchmark("Decimal divide") { benchmark in
//        let divisor = Decimal(10_000)
//        for i in benchmark.scaledIterations {
//            let result = Decimal(i) / divisor
//            blackHole(result)
//        }
//    }
}
