//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Benchmark
import func Benchmark.blackHole
import FoundationEssentials

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .throughput] // use ARC to see traffic
    
    // MARK: UUID
    
    Benchmark("UUIDEqual", configuration: .init(scalingFactor: .mega)) { benchmark in
        let u1 = UUID()
        let u2 = UUID()
        for _ in benchmark.scaledIterations {
            assert(u1 != u2)
        }
    }
}
