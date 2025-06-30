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
import Dispatch

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
import FoundationInternationalization
#else
import Foundation
#endif

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .throughput]
        
    let date = Date(timeIntervalSinceReferenceDate: 665076946.0)

    // ISO8601FormatStyle is only available in Swift 6 or newer, macOS 12 or newer
    #if compiler(>=6)

    let iso8601 = Date.ISO8601FormatStyle()
    let formats: [Date.ISO8601FormatStyle] = [
        iso8601.year().month().day().dateSeparator(.dash),
        iso8601.year().month().day().dateSeparator(.omitted),
        iso8601.weekOfYear().day().dateSeparator(.dash),
        iso8601.day().time(includingFractionalSeconds: false).timeSeparator(.colon),
        iso8601.time(includingFractionalSeconds: false).timeSeparator(.colon),
        iso8601.time(includingFractionalSeconds: false).timeZone(separator: .omitted),
        iso8601.time(includingFractionalSeconds: false).timeZone(separator: .colon),
        iso8601.timeZone(separator: .colon).time(includingFractionalSeconds: false).timeSeparator(.colon),
    ]
    
    let preformatted = formats.map { ($0, $0.format(date)) }

    Benchmark("iso8601-format", configuration: .init(scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            for fmt in formats {
                blackHole(fmt.format(date))
            }
        }
    }

    Benchmark("iso8601-parse", configuration: .init(scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            for fmt in preformatted {
                let result = try? fmt.0.parse(fmt.1)
                blackHole(result)
            }
        }
    }

    Benchmark("parallel-number-formatting", configuration: .init(scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            DispatchQueue.concurrentPerform(iterations: 1000) { _ in
                let result = 10.123.formatted()
                blackHole(result)
            }
        }
    }

    Benchmark("parallel-and-serialized-number-formatting", configuration: .init(scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            DispatchQueue.concurrentPerform(iterations: 10) { _ in
                // Reuse the values on this thread a bunch
                for _ in 0..<100 {
                    let result = 10.123.formatted()
                    blackHole(result)
                }
            }
        }
    }

    Benchmark("serialized-number-formatting", configuration: .init(scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            for _ in 0..<1000 {
                let result = 10.123.formatted()
                blackHole(result)
            }
        }
    }

    #endif // swift(>=6)
}
