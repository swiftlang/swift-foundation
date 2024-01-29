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
import FoundationInternationalization

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .throughput]
        
    let date = Date(timeIntervalSinceReferenceDate: 665076946.0)

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
    
    Benchmark("iso8601", configuration: .init(scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            for fmt in formats {
                blackHole(fmt.format(date))
            }
        }
    }

}
