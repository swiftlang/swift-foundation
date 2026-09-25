//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

struct SpanExtensionTests {

    @Test func firstRangeOfASCIIStrings() {

        func check(_ string: String, _ candidate: String, expects result: Range<Int>?, file: StaticString = #filePath, line: UInt = #line) {
            let actual = string.utf8.span.firstRange(of: candidate.utf8.span)
            #expect(actual == result)
        }

        check("hello world", "world", expects: 6..<11)
        check("hello world", "hello", expects: 0..<5)
        check("hello world", "xyz", expects: nil)
        check("hello", "", expects: nil)
        check("ab", "abc", expects: nil)
        check("abc", "abc", expects: 0..<3)
        check("abcabc", "abc", expects: 0..<3)
        check("", "a", expects: nil)
        check("hello", "l", expects: 2..<3)
    }
}

struct OutputSpanExtensionTests {

    @Test func removesSubrange() {

        func check(_ string: String, _ ranges: Range<Int>..., expect: String, file: StaticString = #filePath, line: UInt = #line) {
            let result = Array<UInt8>(capacity: string.utf8.count) { output in
                for byte in string.utf8 {
                    output.append(byte)
                }
                for range in ranges {
                    output.removeSubrange(range)
                }
            }
            #expect(result == Array(expect.utf8))
        }

        check("hello", 1..<3, expect: "hlo")
        check("hello", 0..<2, expect: "llo")
        check("hello", 3..<5, expect: "hel")
        check("hello", 0..<5, expect: "")
        check("hello", 4..<5, expect: "hell")
        check("hello", 2..<2, expect: "hello")
        check("abcdefg", 1..<2, 2..<4, expect: "acfg") // abcdefg -> acdefg -> acfg
    }
}
