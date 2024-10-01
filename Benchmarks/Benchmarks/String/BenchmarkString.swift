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

#if !os(macOS)
private func autoreleasepool<T>(_ block: () -> T) -> T { block() }
#endif

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .throughput]
    
    // MARK: Encoding strings
    let asciiSmallStr = "abcdefghijklmnopqrtuvwxyz"
    let nonAsciiSmallStr = "🛬x𝄞𝄢y👽"
    
    var asciiLargeStr = ""
    for _ in 0..<10_000 {
        asciiLargeStr += asciiSmallStr
    }
    
    var nonAsciiLargeStr = ""
    for _ in 0..<10_000 {
        nonAsciiLargeStr += nonAsciiSmallStr
    }
    
    let asciiSmallStrDataUTF16BE = asciiSmallStr.data(using: .utf16BigEndian)!
    let asciiSmallStrDataUTF16LE = asciiSmallStr.data(using: .utf16LittleEndian)!
    let nonAsciiSmallStrDataUTF16BE = nonAsciiSmallStr.data(using: .utf16BigEndian)!
    let nonAsciiSmallStrDataUTF16LE = nonAsciiSmallStr.data(using: .utf16LittleEndian)!

    let asciiLargeStrDataUTF16BE = asciiLargeStr.data(using: .utf16BigEndian)!
    let asciiLargeStrDataUTF16LE = asciiLargeStr.data(using: .utf16LittleEndian)!
    let nonAsciiLargeStrDataUTF16BE = nonAsciiLargeStr.data(using: .utf16BigEndian)!
    let nonAsciiLargeStrDataUTF16LE = nonAsciiLargeStr.data(using: .utf16LittleEndian)!

    let asciiSmallStrDataUTF32BE = asciiSmallStr.data(using: .utf32BigEndian)!
    let asciiSmallStrDataUTF32LE = asciiSmallStr.data(using: .utf32LittleEndian)!
    let nonAsciiSmallStrDataUTF32BE = nonAsciiSmallStr.data(using: .utf32BigEndian)!
    let nonAsciiSmallStrDataUTF32LE = nonAsciiSmallStr.data(using: .utf32LittleEndian)!

    let asciiLargeStrDataUTF32BE = asciiLargeStr.data(using: .utf32BigEndian)!
    let asciiLargeStrDataUTF32LE = asciiLargeStr.data(using: .utf32LittleEndian)!
    let nonAsciiLargeStrDataUTF32BE = nonAsciiLargeStr.data(using: .utf32BigEndian)!
    let nonAsciiLargeStrDataUTF32LE = nonAsciiLargeStr.data(using: .utf32LittleEndian)!

    // MARK: - UTF16
    
    Benchmark("utf16-encode") { benchmark in
        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(asciiSmallStr.data(using: .utf16BigEndian))
                blackHole(nonAsciiSmallStr.data(using: .utf16BigEndian))
                
                blackHole(asciiLargeStr.data(using: .utf16BigEndian))
                blackHole(nonAsciiLargeStr.data(using: .utf16BigEndian))
                
                blackHole(asciiSmallStr.data(using: .utf16LittleEndian))
                blackHole(nonAsciiSmallStr.data(using: .utf16LittleEndian))
                
                blackHole(asciiLargeStr.data(using: .utf16LittleEndian))
                blackHole(nonAsciiLargeStr.data(using: .utf16LittleEndian))

                blackHole(asciiLargeStr.data(using: .utf16))
                blackHole(nonAsciiLargeStr.data(using: .utf16))
            }
        }
    }
    
    Benchmark("utf16-decode") { benchmark in
        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(String(bytes: asciiSmallStrDataUTF16BE, encoding: .utf16BigEndian))
                blackHole(String(bytes: nonAsciiSmallStrDataUTF16BE, encoding: .utf16BigEndian))

                blackHole(String(bytes: asciiLargeStrDataUTF16BE, encoding: .utf16BigEndian))
                blackHole(String(bytes: nonAsciiLargeStrDataUTF16BE, encoding: .utf16BigEndian))

                blackHole(String(bytes: asciiSmallStrDataUTF16LE, encoding: .utf16LittleEndian))
                blackHole(String(bytes: nonAsciiSmallStrDataUTF16LE, encoding: .utf16LittleEndian))

                blackHole(String(bytes: asciiLargeStrDataUTF16LE, encoding: .utf16LittleEndian))
                blackHole(String(bytes: nonAsciiLargeStrDataUTF16LE, encoding: .utf16LittleEndian))

                // Use big endian input data with plain utf16 to get a valid string.
                blackHole(String(bytes: asciiLargeStrDataUTF16BE, encoding: .utf16))
                blackHole(String(bytes: nonAsciiLargeStrDataUTF16BE, encoding: .utf16))
            }
        }
    }
        
    // MARK: - UTF32

    Benchmark("utf32-encode") { benchmark in
        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(asciiSmallStr.data(using: .utf32BigEndian))
                blackHole(nonAsciiSmallStr.data(using: .utf32BigEndian))
                
                blackHole(asciiLargeStr.data(using: .utf32BigEndian))
                blackHole(nonAsciiLargeStr.data(using: .utf32BigEndian))
                
                blackHole(asciiSmallStr.data(using: .utf32LittleEndian))
                blackHole(nonAsciiSmallStr.data(using: .utf32LittleEndian))
                
                blackHole(asciiLargeStr.data(using: .utf32LittleEndian))
                blackHole(nonAsciiLargeStr.data(using: .utf32LittleEndian))

                blackHole(asciiLargeStr.data(using: .utf32))
                blackHole(nonAsciiLargeStr.data(using: .utf32))
            }
        }
    }
    
    Benchmark("utf32-decode") { benchmark in
        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(String(bytes: asciiSmallStrDataUTF32BE, encoding: .utf32BigEndian))
                blackHole(String(bytes: nonAsciiSmallStrDataUTF32BE, encoding: .utf32BigEndian))

                blackHole(String(bytes: asciiLargeStrDataUTF32BE, encoding: .utf32BigEndian))
                blackHole(String(bytes: nonAsciiLargeStrDataUTF32BE, encoding: .utf32BigEndian))

                blackHole(String(bytes: asciiSmallStrDataUTF32LE, encoding: .utf32LittleEndian))
                blackHole(String(bytes: nonAsciiSmallStrDataUTF32LE, encoding: .utf32LittleEndian))

                blackHole(String(bytes: asciiLargeStrDataUTF32LE, encoding: .utf32LittleEndian))
                blackHole(String(bytes: nonAsciiLargeStrDataUTF32LE, encoding: .utf32LittleEndian))

                // Use big endian input data with plain UTF32 to get a valid string.
                blackHole(String(bytes: asciiLargeStrDataUTF32BE, encoding: .utf32))
                blackHole(String(bytes: nonAsciiLargeStrDataUTF32BE, encoding: .utf32))
            }
        }
    }

    // MARK: - I/O
    let str = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

    Benchmark("read-utf8") { benchmark in
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
        #if compiler(>=6)
        let fileURL = rootURL.appending(path: "benchmark.txt", directoryHint: .notDirectory)
        #else
        let fileURL = rootURL.appendingPathComponent("benchmark.txt")
        #endif
        try! FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        try! str.write(to: fileURL, atomically: true, encoding: .utf8)

        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(try! String(contentsOf: fileURL, encoding: .utf8))
            }
        }
    }

    Benchmark("read-utf16") { benchmark in
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
        #if compiler(>=6)
        let fileURL = rootURL.appending(path: "benchmark.txt", directoryHint: .notDirectory)
        #else
        let fileURL = rootURL.appendingPathComponent("benchmark.txt")
        #endif
        try! FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        try! str.write(to: fileURL, atomically: true, encoding: .utf16LittleEndian)

        for _ in benchmark.scaledIterations {
            autoreleasepool {
                blackHole(try! String(contentsOf: fileURL, encoding: .utf16LittleEndian))
            }
        }
    }

}
