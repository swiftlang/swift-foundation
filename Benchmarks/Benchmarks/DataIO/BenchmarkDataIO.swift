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

func cleanupTestPath() {
    try? FileManager.default.removeItem(at: testPath)
    // Ignore any errors
}

// 16 MB file, big enough to trigger things like chunking
let data = generateTestData(count: 1 << 24)
#if compiler(>=6)
let testPath = FileManager.default.temporaryDirectory.appending(path: "testfile-\(UUID().uuidString)", directoryHint: .notDirectory)
#else
let testPath = FileManager.default.temporaryDirectory.appendingPathComponent("testfile-\(UUID().uuidString)")
#endif
let nonExistentPath = URL(filePath: "/does-not-exist", directoryHint: .notDirectory)

let base64Data = generateTestData(count: 1024 * 1024)
let base64DataString = base64Data.base64EncodedString()

extension Benchmark.Configuration {
    fileprivate static var cleanupTestPathConfig: Self {
        .init(teardown: cleanupTestPath)
    }
}

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

    Benchmark("read-write-emptyFile", configuration: .cleanupTestPathConfig) { benchmark in
        let data = Data()
        try data.write(to: testPath)
        let read = try Data(contentsOf: testPath, options: [])
    }

    Benchmark("write-regularFile", configuration: .cleanupTestPathConfig) { benchmark in
        try data.write(to: testPath)
    }
    
    Benchmark("write-regularFile-atomic", configuration: .cleanupTestPathConfig) { benchmark in
        try data.write(to: testPath, options: .atomic)
    }
    
    Benchmark("write-regularFile-alreadyExists",
              configuration: .init(
                setup: {
                    try! Data().write(to: testPath)
                },
                teardown: cleanupTestPath
              )
    ) { benchmark in
        try? data.write(to: testPath)
    }
    
    Benchmark("write-regularFile-alreadyExists-atomic",
              configuration: .init(
                setup: {
                    try! Data().write(to: testPath)
                },
                teardown: cleanupTestPath
              )
    ) { benchmark in
        try? data.write(to: testPath, options: .atomic)
    }
    
    Benchmark("read-regularFile", 
              configuration: .init(
                setup: {
                    try! data.write(to: testPath)
                },
                teardown: cleanupTestPath
              )
    ) { benchmark in
        blackHole(try Data(contentsOf: testPath))
    }
    
    Benchmark("read-nonExistentFile") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try? Data(contentsOf: nonExistentPath))
        }
    }
    
    Benchmark("read-nonExistentFile-userInfo") { benchmark in
        for _ in benchmark.scaledIterations {
            do {
                blackHole(try Data(contentsOf: nonExistentPath))
            } catch {
                blackHole((error as? CocoaError)?.userInfo["NSURLErrorKey"])
            }
        }
    }
    
    Benchmark("read-hugeFile",
              configuration: .init(
                setup: {
                    try! generateTestData(count: 1 << 30).write(to: testPath)
                },
                teardown: cleanupTestPath
              )
    ) { benchmark in
        blackHole(try Data(contentsOf: testPath))
    }
}
