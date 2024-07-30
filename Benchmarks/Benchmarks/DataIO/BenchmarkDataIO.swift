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

func testPath() -> URL {
    #if compiler(>=6)
    FileManager.default.temporaryDirectory.appending(path: "testfile-\(UUID().uuidString)", directoryHint: .notDirectory)
    #else
    FileManager.default.temporaryDirectory.appendingPathComponent("testfile-\(UUID().uuidString)")
    #endif
}

func generateTestData(count: Int) -> Data {
    let memory = malloc(count)!
    let ptr = memory.bindMemory(to: UInt8.self, capacity: count)
    
    // Set a few bytes so we're sure to not be all zeros
    let buf = UnsafeMutableBufferPointer(start: ptr, count: count)
    for i in 0..<128 {
        buf[i] = UInt8.random(in: UInt8.min..<UInt8.max)
    }
    
    return Data(bytesNoCopy: ptr, count: count, deallocator: .free)
}

func cleanup(at path: URL) {
    try? FileManager.default.removeItem(at: path)
    // Ignore any errors
}

// 16 MB file, big enough to trigger things like chunking
let data = generateTestData(count: 1 << 24)
let readMe = testPath()

let base64Data = generateTestData(count: 1024 * 1024)
let base64DataString = base64Data.base64EncodedString()

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    #if os(macOS)
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .mallocCountTotal, .throughput, .syscalls]
    #elseif os(Linux)
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .mallocCountTotal, .throughput, .readSyscalls, .writeSyscalls]
    #else
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .mallocCountTotal, .throughput]
    #endif

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
    
    Benchmark("read-hugeFile",
              configuration: .init(
                setup: {
                    try! generateTestData(count: 1 << 30).write(to: readMe)
                },
                teardown: {
                    cleanup(at: readMe)
                }
              )
    ) { benchmark in
        blackHole(try Data(contentsOf: readMe))
    }
    
    // MARK: base64
        
    Benchmark("base64-encode", configuration: .init(
        metrics: [.cpuTotal, .mallocCountTotal, .peakMemoryResident, .throughput],
        scalingFactor: .kilo)
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(base64Data.base64EncodedString())
            }
        }
    }
    
    
    Benchmark("base64-decode", configuration: .init(
        metrics: [.cpuTotal, .mallocCountTotal, .peakMemoryResident, .throughput],
        scalingFactor: .kilo)
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(Data(base64Encoded: base64DataString))
            }
        }
    }

}
