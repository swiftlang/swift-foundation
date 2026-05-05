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

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
import FoundationInternationalization
#else
import Foundation
#endif

let benchmarks = {
    #if FOUNDATION_FRAMEWORK
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
    
    // MARK: rdar://173078708 Hash & Equality & Bitmap Representation
    Benchmark("CharacterSet: Hash Predefined CharacterSet") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs = CharacterSet.whitespacesAndNewlines
            var hasher = Hasher()
            cs.hash(into: &hasher)
            blackHole(hasher.finalize())
        }
    }
    
    Benchmark("CharacterSet Hash BMP-Only CharacterSet") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs: CharacterSet = {
                var cs = CharacterSet(charactersIn: "a"..."f")
                cs.insert(charactersIn: "A"..."F")
                cs.insert(charactersIn: "0"..."9")
                return cs
            }()
            var hasher = Hasher()
            cs.hash(into: &hasher)
            blackHole(hasher.finalize())
        }
    }
    
    Benchmark("CharacterSet: Hash Multi-Plane CharacterSet") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs: CharacterSet = {
                var cs = CharacterSet(charactersIn: "a"..."z")
                cs.insert(charactersIn: "A"..."Z")
                cs.insert(
                    charactersIn:
                        "_\u{00A8}\u{00AA}\u{00AD}\u{00AF}\u{00B2}\u{00B3}\u{00B4}\u{00B5}\u{00B7}\u{00B8}\u{00B9}\u{00BA}\u{00BC}\u{00BD}\u{00BE}"
                )
                cs.insert(charactersIn: "\u{00C0}"..."\u{00D6}")
                cs.insert(charactersIn: "\u{00D8}"..."\u{00F6}")
                cs.insert(charactersIn: "\u{00F8}"..."\u{00FF}")
                cs.insert(charactersIn: "\u{0100}"..."\u{02FF}")
                cs.insert(charactersIn: "\u{0370}"..."\u{167F}")
                cs.insert(charactersIn: "\u{1681}"..."\u{180D}")
                cs.insert(charactersIn: "\u{180F}"..."\u{1DBF}")
                cs.insert(charactersIn: "\u{1E00}"..."\u{1FFF}")
                cs.insert(charactersIn: "\u{200B}"..."\u{200D}")
                cs.insert(charactersIn: "\u{202A}"..."\u{202E}")
                cs.insert(charactersIn: "\u{203F}"..."\u{2040}")
                cs.insert(charactersIn: "\u{2054}")
                cs.insert(charactersIn: "\u{2060}"..."\u{206F}")
                cs.insert(charactersIn: "\u{2070}"..."\u{20CF}")
                cs.insert(charactersIn: "\u{2100}"..."\u{218F}")
                cs.insert(charactersIn: "\u{2460}"..."\u{24FF}")
                cs.insert(charactersIn: "\u{2776}"..."\u{2793}")
                cs.insert(charactersIn: "\u{2C00}"..."\u{2DFF}")
                cs.insert(charactersIn: "\u{2E80}"..."\u{2FFF}")
                cs.insert(charactersIn: "\u{3004}"..."\u{3007}")
                cs.insert(charactersIn: "\u{3021}"..."\u{302F}")
                cs.insert(charactersIn: "\u{3031}"..."\u{303F}")
                cs.insert(charactersIn: "\u{3040}"..."\u{D7FF}")
                cs.insert(charactersIn: "\u{F900}"..."\u{FD3D}")
                cs.insert(charactersIn: "\u{FD40}"..."\u{FDCF}")
                cs.insert(charactersIn: "\u{FDF0}"..."\u{FE1F}")
                cs.insert(charactersIn: "\u{FE30}"..."\u{FE44}")
                cs.insert(charactersIn: "\u{FE47}"..."\u{FFFD}")
                cs.insert(charactersIn: "\u{10000}"..."\u{1FFFD}")
                cs.insert(charactersIn: "\u{20000}"..."\u{2FFFD}")
                cs.insert(charactersIn: "\u{30000}"..."\u{3FFFD}")
                cs.insert(charactersIn: "\u{40000}"..."\u{4FFFD}")
                cs.insert(charactersIn: "\u{50000}"..."\u{5FFFD}")
                cs.insert(charactersIn: "\u{60000}"..."\u{6FFFD}")
                cs.insert(charactersIn: "\u{70000}"..."\u{7FFFD}")
                cs.insert(charactersIn: "\u{80000}"..."\u{8FFFD}")
                cs.insert(charactersIn: "\u{90000}"..."\u{9FFFD}")
                cs.insert(charactersIn: "\u{A0000}"..."\u{AFFFD}")
                cs.insert(charactersIn: "\u{B0000}"..."\u{BFFFD}")
                cs.insert(charactersIn: "\u{C0000}"..."\u{CFFFD}")
                cs.insert(charactersIn: "\u{D0000}"..."\u{DFFFD}")
                cs.insert(charactersIn: "\u{E0000}"..."\u{EFFFD}")
                return cs
            }()
            var hasher = Hasher()
            cs.hash(into: &hasher)
            blackHole(hasher.finalize())
        }
    }
    
    Benchmark("CharacterSet: Hash Almost Everything") { benchmark in
        for _ in benchmark.scaledIterations {
            let cs: CharacterSet = {
                var characterSet = CharacterSet(charactersIn: "\u{0000}"..."\u{10FFFF}")
                characterSet.remove(charactersIn: "\"\\\n\r\t\u{0008}\u{000C}")
                return characterSet
            }()
            var hasher = Hasher()
            cs.hash(into: &hasher)
            blackHole(hasher.finalize())
        }
    }
    
    let csSample1: CharacterSet = {
        var cs = CharacterSet(charactersIn: "a"..."z")
        cs.insert(charactersIn: "A"..."Z")
        cs.insert(charactersIn: "\u{10000}"..."\u{1FFFD}")
        cs.insert(charactersIn: "\u{20000}"..."\u{2FFFD}")
        return cs
    }()
    let csSample1Copy = csSample1
    Benchmark("CharacterSet: Equal between Two Bitmaps") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(csSample1 == csSample1Copy)
        }
    }
    
    let csSample2: CharacterSet = {
        var cs = CharacterSet(charactersIn: "ABC")
        cs.invert()
        return cs
    }()
    let csSample3: CharacterSet = {
        var cs = CharacterSet(charactersIn: "\u{0000}"..."\u{10FFFF}")
        cs.remove(charactersIn: "ABC")
        return cs
    }()
    Benchmark("CharacterSet: Equal between Bitmap and String") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(csSample2 == csSample3)
        }
    }
    
    let csSample4: CharacterSet = {
        var cs = CharacterSet(charactersIn: "a"..."z")
        cs.insert(charactersIn: "A"..."Z")
        cs.insert(charactersIn: "\u{10000}"..."\u{1FFFD}")
        return cs
    }()
    Benchmark("CharacterSet: Not Equal between Two Bitmaps") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(csSample1 == csSample4)
        }
    }
    
    let csSample5: CharacterSet = {
        var cs = CharacterSet(charactersIn: "Hello, World!")
        return cs
    }()
    Benchmark("CharacterSet: Not Equal Between Bitmap and String") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(csSample1 == csSample5)
        }
    }
    
    Benchmark("CharacterSet: Bitmap Representation of Small CharacterSet") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(csSample1.bitmapRepresentation)
        }
    }
    
    let csSample6: CharacterSet = {
        var cs = CharacterSet(charactersIn: "a"..."z")
        cs.insert(charactersIn: "A"..."Z")
        cs.insert(
            charactersIn:
                "_\u{00A8}\u{00AA}\u{00AD}\u{00AF}\u{00B2}\u{00B3}\u{00B4}\u{00B5}\u{00B7}\u{00B8}\u{00B9}\u{00BA}\u{00BC}\u{00BD}\u{00BE}"
        )
        cs.insert(charactersIn: "\u{00C0}"..."\u{00D6}")
        cs.insert(charactersIn: "\u{00D8}"..."\u{00F6}")
        cs.insert(charactersIn: "\u{00F8}"..."\u{00FF}")
        cs.insert(charactersIn: "\u{0100}"..."\u{02FF}")
        cs.insert(charactersIn: "\u{0370}"..."\u{167F}")
        cs.insert(charactersIn: "\u{1681}"..."\u{180D}")
        cs.insert(charactersIn: "\u{180F}"..."\u{1DBF}")
        cs.insert(charactersIn: "\u{1E00}"..."\u{1FFF}")
        cs.insert(charactersIn: "\u{200B}"..."\u{200D}")
        cs.insert(charactersIn: "\u{202A}"..."\u{202E}")
        cs.insert(charactersIn: "\u{203F}"..."\u{2040}")
        cs.insert(charactersIn: "\u{2054}")
        cs.insert(charactersIn: "\u{2060}"..."\u{206F}")
        cs.insert(charactersIn: "\u{2070}"..."\u{20CF}")
        cs.insert(charactersIn: "\u{2100}"..."\u{218F}")
        cs.insert(charactersIn: "\u{2460}"..."\u{24FF}")
        cs.insert(charactersIn: "\u{2776}"..."\u{2793}")
        cs.insert(charactersIn: "\u{2C00}"..."\u{2DFF}")
        cs.insert(charactersIn: "\u{2E80}"..."\u{2FFF}")
        cs.insert(charactersIn: "\u{3004}"..."\u{3007}")
        cs.insert(charactersIn: "\u{3021}"..."\u{302F}")
        cs.insert(charactersIn: "\u{3031}"..."\u{303F}")
        cs.insert(charactersIn: "\u{3040}"..."\u{D7FF}")
        cs.insert(charactersIn: "\u{F900}"..."\u{FD3D}")
        cs.insert(charactersIn: "\u{FD40}"..."\u{FDCF}")
        cs.insert(charactersIn: "\u{FDF0}"..."\u{FE1F}")
        cs.insert(charactersIn: "\u{FE30}"..."\u{FE44}")
        cs.insert(charactersIn: "\u{FE47}"..."\u{FFFD}")
        cs.insert(charactersIn: "\u{10000}"..."\u{1FFFD}")
        cs.insert(charactersIn: "\u{20000}"..."\u{2FFFD}")
        cs.insert(charactersIn: "\u{30000}"..."\u{3FFFD}")
        cs.insert(charactersIn: "\u{40000}"..."\u{4FFFD}")
        cs.insert(charactersIn: "\u{50000}"..."\u{5FFFD}")
        cs.insert(charactersIn: "\u{60000}"..."\u{6FFFD}")
        cs.insert(charactersIn: "\u{70000}"..."\u{7FFFD}")
        cs.insert(charactersIn: "\u{80000}"..."\u{8FFFD}")
        cs.insert(charactersIn: "\u{90000}"..."\u{9FFFD}")
        cs.insert(charactersIn: "\u{A0000}"..."\u{AFFFD}")
        cs.insert(charactersIn: "\u{B0000}"..."\u{BFFFD}")
        cs.insert(charactersIn: "\u{C0000}"..."\u{CFFFD}")
        cs.insert(charactersIn: "\u{D0000}"..."\u{DFFFD}")
        cs.insert(charactersIn: "\u{E0000}"..."\u{EFFFD}")
        return cs
    }()
    Benchmark("CharacterSet: Bitmap Representation of Large CharacterSet") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(csSample6.bitmapRepresentation)
        }
    }
    
    let csSample7: CharacterSet = {
        var characterSet = CharacterSet(charactersIn: "\u{0000}"..."\u{10FFFF}")
        characterSet.remove(charactersIn: "\"\\\n\r\t\u{0008}\u{000C}")
        return characterSet
    }()
    Benchmark("CharacterSet: Bitmap Representation of Almost Everything") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(csSample7.bitmapRepresentation)
        }
    }
    #endif // FOUNDATION_FRAMEWORK
}
