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
@testable import FoundationEssentials

#if canImport(Glibc)
import Glibc
#endif
#if canImport(Darwin)
import Darwin
#endif

func testPath() -> String {
    // Generate a random file name
    String.temporaryDirectoryPath.appendingPathComponent("testfile-\(UUID().uuidString)")
}

func generateTestData() -> Data {
    // 16 MB file, big enough to trigger things like chunking
    let count = 1 << 24
    
    let memory = malloc(count)!
    let ptr = memory.bindMemory(to: UInt8.self, capacity: count)
    
    // Set a few bytes so we're sure to not be all zeros
    let buf = UnsafeMutableBufferPointer(start: ptr, count: count)
    for i in 0..<128 {
        buf[i] = UInt8.random(in: 1..<42)
    }
    
    return Data(bytesNoCopy: ptr, count: count, deallocator: .free)
}

func cleanup(at path: String) {
    _ = unlink(path)
    // Ignore any errors
}

let data = generateTestData()
let readMe = testPath()

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
//    Benchmark.defaultConfiguration.metrics = .arc + [.cpuTotal, .wallClock, .mallocCountTotal, .throughput] // use ARC to see traffic
//  Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .mallocCountTotal, .throughput] // skip ARC as it has some overhead
  Benchmark.defaultConfiguration.metrics = .all // Use all metrics to easily see which ones are of interest for this benchmark suite

    Benchmark("read-write-emptyFile") { benchmark in
        let path = testPath()
        let data = Data()
        try data.write(to: path)
        let read = try Data(contentsOf: path, options: [])
        cleanup(at: path)
    }

    Benchmark("write-regularFile") { benchmark in
        let path = testPath()
        try data.write(to: path)
        cleanup(at: path)
    }
    
    Benchmark("read-regularFile", 
              configuration: .init(
                setup: {
                    try! data.write(to: readMe)
                },
                teardown: {
                    cleanup(at: readMe)
                }
              )
    ) { benchmark in
        blackHole(try Data(contentsOf: readMe))
    }
}
