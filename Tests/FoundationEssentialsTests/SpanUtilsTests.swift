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

    @Test(arguments: [
        (string: "hello world", candidate: "world", expected: 6..<11),
        (string: "hello world", candidate: "hello", expected: 0..<5),
        (string: "hello world", candidate: "xyz", expected: nil),
        (string: "hello", candidate: "", expected: 0..<0),
        (string: "ab", candidate: "abc", expected: nil),
        (string: "abc", candidate: "abc", expected: 0..<3),
        (string: "abcabc", candidate: "abc", expected: 0..<3),
        (string: "", candidate: "a", expected: nil),
        (string: "hello", candidate: "l", expected: 2..<3),
    ] as [(string: String, candidate: String, expected: Range<Int>?)])
    func firstRangeOfASCIIStrings(string: String, candidate: String, expected: Range<Int>?) {
        let actual = string.utf8.span.firstRange(of: candidate.utf8.span)
        #expect(actual == expected)
    }
}

struct OutputSpanExtensionTests {

    @Test(arguments: [
        (string: "hello", ranges: [1..<3], expected: "hlo"),
        (string: "hello", ranges: [0..<2], expected: "llo"),
        (string: "hello", ranges: [3..<5], expected: "hel"),
        (string: "hello", ranges: [0..<5], expected: ""),
        (string: "hello", ranges: [4..<5], expected: "hell"),
        (string: "hello", ranges: [2..<2], expected: "hello"),
        (string: "abcdefg", ranges: [1..<2, 2..<4], expected: "acfg"), // abcdefg -> acdefg -> acfg
    ] as [(string: String, ranges: [Range<Int>], expected: String)])
    func removesSubrange(string: String, ranges: [Range<Int>], expected: String) {
        let result = Array<UInt8>(capacity: string.utf8.count) { output in
            for byte in string.utf8 {
                output.append(byte)
            }
            for range in ranges {
                output.removeSubrange(range)
            }
        }
        #expect(result == Array(expected.utf8))
    }
}
