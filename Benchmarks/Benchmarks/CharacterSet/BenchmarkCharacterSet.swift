//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
import FoundationInternationalization
#else
import Foundation
#endif

let benchmarks = {
    
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .throughput]
    
    let string = "Hello, Let's use Character Set"
    let range = Unicode.Scalar(0x10000)!..<UnicodeScalar(0x20000)!
    let data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    
    // MARK: Initialize CharacterSet
    
    Benchmark("CharacterSet: String") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet(charactersIn: string))
        }
    }
    
    Benchmark("CharacterSet: Range") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet(charactersIn: range))
        }
    }
    
    Benchmark("CharacterSet: Predefined") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet.whitespacesAndNewlines)
        }
    }
    
    Benchmark("CharacterSet: Data") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet(bitmapRepresentation: data))
        }
    }
    
    // MARK: Get Bitmap Representation of CharacterSet
    
    Benchmark("CharacterSet.GetStringBitmapRepresentation") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet(charactersIn: string).bitmapRepresentation)
        }
    }
    
    Benchmark("CharacterSet.GetRangeBitmapRepresentation") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet(charactersIn: range).bitmapRepresentation)
        }
    }
    
    Benchmark("CharacterSet.GetPredefinedBitmapRepresentation") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet.whitespacesAndNewlines.bitmapRepresentation)
        }
    }
    
    Benchmark("CharacterSet.GetDataBitmapRepresentation") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet(bitmapRepresentation: data).bitmapRepresentation)
        }
    }
    
    // MARK: Check Membership
   
    Benchmark("CharacterSet: String Membership") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs = CharacterSet(charactersIn: string)
            blackHole(cs.contains(UnicodeScalar("a")))
        }
    }
    
    Benchmark("CharacterSet: Range Membership") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs = CharacterSet(charactersIn: range)
            blackHole(cs.contains(UnicodeScalar(0x4999)!))
        }
    }
    
    Benchmark("CharacterSet: Predefined Membership") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs = CharacterSet.whitespacesAndNewlines
            blackHole(cs.contains(UnicodeScalar(0x0045)!))
        }
    }
    
    Benchmark("CharacterSet: Data Membership") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs = CharacterSet(bitmapRepresentation: data)
            blackHole(cs.contains(UnicodeScalar(0x0031)!))
        }
    }
    
    // MARK: Common Usage Patterns
    
    let input1 = "\n\t  hello world  \r\n"
    let input2 = "###  hello world  ###"
    let input3 = "hello world swift testing"
    let input4 = "abc123def456ghi"
    let input5 = "line1\nline2\rline3\r\nline4"
    let validAlphanumericsInput = "Test123"
    let invalidAlphanumericsInput = "Test@123"
    
    Benchmark("CharacterSet: Trim Whitespaces and Newlines") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(input1.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    
    Benchmark("CharacterSet: Trim Custom Characters") { benchmark in
        for _ in benchmark.scaledIterations {
            var customSet = CharacterSet.whitespaces
            customSet.insert(charactersIn: "#")
            blackHole(input2.trimmingCharacters(in: customSet))
        }
    }
    
    Benchmark("CharacterSet: Split String by Whitespaces") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(input3.components(separatedBy: .whitespaces))
        }
    }
    
    Benchmark("CharacterSet: Split String by Inverted Decimal Digits") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(input4.components(separatedBy: CharacterSet.decimalDigits.inverted))
        }
    }
    
    Benchmark("CharacterSet: Split String by Newlines") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(input5.components(separatedBy: .newlines).filter { !$0.isEmpty })
        }
    }
    
    Benchmark("CharacterSet: Validate Alphanumerics Input") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(CharacterSet.alphanumerics.isSuperset(of: CharacterSet(charactersIn: validAlphanumericsInput)))
            blackHole(!CharacterSet.alphanumerics.isSuperset(of: CharacterSet(charactersIn: invalidAlphanumericsInput)))
        }
    }
}
#endif
