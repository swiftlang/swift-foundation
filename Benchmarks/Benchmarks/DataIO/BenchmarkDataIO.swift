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

#if FOUNDATION_FRAMEWORK
import Foundation
#else
@testable import FoundationEssentials
#endif


#if canImport(Glibc)
import Glibc
#endif
#if canImport(Darwin)
import Darwin
#endif

#if !FOUNDATION_FRAMEWORK
func testPath() -> String {
    // Generate a random file name
    FileManager.default.temporaryDirectory.path.appendingPathComponent("testfile-\(UUID().uuidString)")
}
#else
func testPath() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "testfile-\(UUID().uuidString)", directoryHint: .notDirectory)
}
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

#if !FOUNDATION_FRAMEWORK
func cleanup(at path: String) {
    try? FileManager.default.removeItem(atPath: path)
    // Ignore any errors
}
#else
func cleanup(at path: URL) {
    try? FileManager.default.removeItem(at: path)
    // Ignore any errors
}
#endif

// 16 MB file, big enough to trigger things like chunking
let data = generateTestData(count: 1 << 24)
let readMe = testPath()

let base64Data = generateTestData(count: 1024 * 1024)
let base64DataString = base64Data.base64EncodedString()

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .mallocCountTotal, .throughput]

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
    
    // MARK: base64
        
    Benchmark("base64-encode", configuration: .init(scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(base64Data.base64EncodedString())
            }
        }
    }
    
    
    Benchmark("base64-decode", configuration: .init(scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(Data(base64Encoded: base64DataString))
            }
        }
    }

}
