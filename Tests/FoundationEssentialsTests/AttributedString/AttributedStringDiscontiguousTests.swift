//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(TestSupport)
import TestSupport
#endif

final class AttributedStringDiscontiguousTests: XCTestCase {
    func testEmptySlice() {
        let str = AttributedString()
        let slice = str[RangeSet()]
        XCTAssertTrue(slice.runs.isEmpty)
        XCTAssertTrue(slice.characters.isEmpty)
        XCTAssertTrue(slice.unicodeScalars.isEmpty)
        XCTAssertEqual(slice, slice)
        XCTAssertEqual(slice.runs.startIndex, slice.runs.endIndex)
        XCTAssertEqual(slice.characters.startIndex, slice.characters.endIndex)
        XCTAssertEqual(slice.unicodeScalars.startIndex, slice.unicodeScalars.endIndex)
        XCTAssertEqual(AttributedString("abc")[RangeSet()], AttributedString("def")[RangeSet()])
        
        for r in slice.runs {
            XCTFail("Enumerating empty runs should not have produced \(r)")
        }
        for c in slice.characters {
            XCTFail("Enumerating empty characters should not have produced \(c)")
        }
        for s in slice.unicodeScalars {
            XCTFail("Enumerating empty unicode scalars should not have produced \(s)")
        }
    }
    
    func testCharacters() {
        let str = AttributedString("abcdefgabc")
        let fullSlice = str[str.startIndex ..< str.endIndex].characters
        let fullDiscontiguousSlice = str[RangeSet(str.startIndex ..< str.endIndex)].characters
        XCTAssertTrue(fullSlice.elementsEqual(fullDiscontiguousSlice))
        
        let rangeA = str.startIndex ..< str.index(str.startIndex, offsetByCharacters: 3)
        let rangeB = str.index(str.endIndex, offsetByCharacters: -3) ..< str.endIndex
        let rangeSet = RangeSet([rangeA, rangeB])
        let slice = str[rangeSet].characters
        XCTAssertEqual(Array(slice), ["a", "b", "c", "a", "b", "c"])
    }
    
    func testUnicodeScalars() {
        let str = AttributedString("abcdefgabc")
        let fullSlice = str[str.startIndex ..< str.endIndex].unicodeScalars
        let fullDiscontiguousSlice = str[RangeSet(str.startIndex ..< str.endIndex)].unicodeScalars
        XCTAssertTrue(fullSlice.elementsEqual(fullDiscontiguousSlice))
        
        let rangeA = str.startIndex ..< str.index(str.startIndex, offsetByUnicodeScalars: 3)
        let rangeB = str.index(str.endIndex, offsetByUnicodeScalars: -3) ..< str.endIndex
        let rangeSet = RangeSet([rangeA, rangeB])
        let slice = str[rangeSet].unicodeScalars
        XCTAssertEqual(Array(slice), ["a", "b", "c", "a", "b", "c"])
    }
    
    func testAttributes() {
        let str = AttributedString("abcdefg")
        let rangeA = str.startIndex ..< str.index(str.startIndex, offsetByCharacters: 1)
        let rangeB = str.index(str.startIndex, offsetByCharacters: 2) ..< str.index(str.startIndex, offsetByCharacters: 3)
        let rangeC = str.index(str.startIndex, offsetByCharacters: 4) ..< str.index(str.startIndex, offsetByCharacters: 5)
        let ranges = RangeSet([rangeA, rangeB, rangeC])
        
        do {
            var a = str
            a[ranges].testInt = 2
            var b = str
            for range in ranges.ranges {
                b[range].testInt = 2
            }
            XCTAssertEqual(a, b)
        }
        
        do {
            var a = str
            a[ranges].test.testInt = 2
            var b = str
            for range in ranges.ranges {
                b[range].test.testInt = 2
            }
            XCTAssertEqual(a, b)
        }
        
        do {
            var a = str
            a[ranges][AttributeScopes.TestAttributes.TestIntAttribute.self] = 2
            var b = str
            for range in ranges.ranges {
                b[range][AttributeScopes.TestAttributes.TestIntAttribute.self] = 2
            }
            XCTAssertEqual(a, b)
        }
        
        do {
            var a = str
            a.testInt = 3
            a[ranges].testInt = nil
            var b = str
            b.testInt = 3
            for range in ranges.ranges {
                b[range].testInt = nil
            }
            XCTAssertEqual(a, b)
        }
        
        do {
            var a = str
            a.testInt = 2
            XCTAssertEqual(a[ranges].testInt, 2)
            a[rangeA].testInt = 3
            XCTAssertEqual(a[ranges].testInt, nil)
        }
        
        do {
            var a = str
            a.testString = "foo"
            a[ranges].mergeAttributes(AttributeContainer.testInt(2))
            var b = str
            b.testString = "foo"
            for range in ranges.ranges {
                b[range].mergeAttributes(AttributeContainer.testInt(2))
            }
            XCTAssertEqual(a, b)
        }
        
        do {
            var a = str
            a.testString = "foo"
            a[ranges].setAttributes(AttributeContainer.testInt(2))
            var b = str
            b.testString = "foo"
            for range in ranges.ranges {
                b[range].setAttributes(AttributeContainer.testInt(2))
            }
            XCTAssertEqual(a, b)
        }
        
        do {
            var a = str
            a.testString = "foo"
            a[ranges].replaceAttributes(AttributeContainer(), with: AttributeContainer.testInt(2))
            var b = str
            b.testString = "foo"
            for range in ranges.ranges {
                b[range].replaceAttributes(AttributeContainer(), with: AttributeContainer.testInt(2))
            }
            XCTAssertEqual(a, b)
        }
        
        do {
            var a = str
            a.testString = "foo"
            a[ranges].replaceAttributes(AttributeContainer.testString("foo"), with: AttributeContainer.testInt(2))
            var b = str
            b.testString = "foo"
            for range in ranges.ranges {
                b[range].replaceAttributes(AttributeContainer.testString("foo"), with: AttributeContainer.testInt(2))
            }
            XCTAssertEqual(a, b)
        }
    }
    
    func testReinitialization() {
        var str = AttributedString("abcdefg")
        let rangeA = str.startIndex ..< str.index(str.startIndex, offsetByCharacters: 1)
        let rangeB = str.index(str.startIndex, offsetByCharacters: 2) ..< str.index(str.startIndex, offsetByCharacters: 3)
        let rangeC = str.index(str.startIndex, offsetByCharacters: 4) ..< str.index(str.startIndex, offsetByCharacters: 5)
        let ranges = RangeSet([rangeA, rangeB, rangeC])
        str[ranges].testInt = 2
        
        let reinitialized = AttributedString(str[ranges])
        XCTAssertEqual(reinitialized, AttributedString("ace", attributes: AttributeContainer.testInt(2)))
    }
    
    func testReslicing() {
        var str = AttributedString("abcdefg")
        let rangeA = str.startIndex ..< str.index(str.startIndex, offsetByCharacters: 1)
        let rangeB = str.index(str.startIndex, offsetByCharacters: 2) ..< str.index(str.startIndex, offsetByCharacters: 3)
        let rangeC = str.index(str.startIndex, offsetByCharacters: 4) ..< str.index(str.startIndex, offsetByCharacters: 5)
        let ranges = RangeSet([rangeA, rangeB, rangeC])
        str[ranges].testInt = 2
        
        XCTAssertEqual(str[ranges], str[ranges][ranges])
        XCTAssertEqual(AttributedString(str[ranges][RangeSet([rangeA, rangeB])]), AttributedString("ac", attributes: AttributeContainer.testInt(2)))
        XCTAssertEqual(AttributedString(str[ranges][rangeA.lowerBound ..< rangeB.upperBound]), AttributedString("ac", attributes: AttributeContainer.testInt(2)))
        
        XCTAssertEqual(str[RangeSet()][RangeSet()], str[RangeSet()])
    }
    
    func testRuns() {
        var str = AttributedString("AAA", attributes: AttributeContainer.testInt(2))
        str += AttributedString("BBB", attributes: AttributeContainer.testInt(3).testString("foo"))
        str += AttributedString("CC", attributes: AttributeContainer.testInt(3).testString("bar"))
        str += AttributedString("D", attributes: AttributeContainer.testInt(3).testString("baz"))
        str += AttributedString("EEEEEEEE")
        
        let rangeA = str.index(str.startIndex, offsetByCharacters: 1) ..< str.index(str.startIndex, offsetByCharacters: 2) // A
        let rangeB = str.index(str.startIndex, offsetByCharacters: 4) ..< str.index(str.startIndex, offsetByCharacters: 7) // BBC (2 runs)
        let rangeC = str.index(str.startIndex, offsetByCharacters: 8) ..< str.index(str.startIndex, offsetByCharacters: 9) // D
        let rangeD = str.index(str.startIndex, offsetByCharacters: 10) ..< str.index(str.startIndex, offsetByCharacters: 11) // E
        let rangeE = str.index(str.startIndex, offsetByCharacters: 12) ..< str.index(str.startIndex, offsetByCharacters: 13) // E
        let rangeSet = RangeSet([rangeA, rangeB, rangeC, rangeD, rangeE])
        
        let rangeB_first = str.index(str.startIndex, offsetByCharacters: 4) ..< str.index(str.startIndex, offsetByCharacters: 6)
        let rangeB_second = str.index(str.startIndex, offsetByCharacters: 6) ..< str.index(str.startIndex, offsetByCharacters: 7)
        
        let runs = str[rangeSet].runs
        let expectedRanges = [rangeA, rangeB_first, rangeB_second, rangeC, rangeD, rangeE]
        XCTAssertEqual(runs.count, expectedRanges.count)
        XCTAssertEqual(runs.reversed().count, expectedRanges.reversed().count)
        XCTAssertEqual(runs.map(\.range), expectedRanges)
        XCTAssertEqual(runs.reversed().map(\.range), expectedRanges.reversed())
    }
    
    func testCoalescedRuns() {
        struct EquatableBox<T: Equatable, U: Equatable>: Equatable, CustomStringConvertible {
            let t: T
            let u: U
            
            var description: String {
                "(\(String(describing: t)), \(String(describing: u)))"
            }
            
            init(_ values: (T, U)) {
                self.t = values.0
                self.u = values.1
            }
            
            init(_ t: T, _ u: U) {
                self.t = t
                self.u = u
            }
        }
        var str = AttributedString("AAA", attributes: AttributeContainer.testInt(2))
        str += AttributedString("BBB", attributes: AttributeContainer.testInt(3).testString("foo"))
        str += AttributedString("CC", attributes: AttributeContainer.testInt(3).testString("bar"))
        str += AttributedString("D", attributes: AttributeContainer.testInt(3).testString("baz"))
        str += AttributedString("EEEEEEEE")
        
        let rangeA = str.index(str.startIndex, offsetByCharacters: 1) ..< str.index(str.startIndex, offsetByCharacters: 2) // A
        let rangeB = str.index(str.startIndex, offsetByCharacters: 4) ..< str.index(str.startIndex, offsetByCharacters: 7) // BBC (2 runs)
        let rangeC = str.index(str.startIndex, offsetByCharacters: 8) ..< str.index(str.startIndex, offsetByCharacters: 9) // D
        let rangeD = str.index(str.startIndex, offsetByCharacters: 10) ..< str.index(str.startIndex, offsetByCharacters: 11) // E
        let rangeE = str.index(str.startIndex, offsetByCharacters: 12) ..< str.index(str.startIndex, offsetByCharacters: 13) // E
        let rangeSet = RangeSet([rangeA, rangeB, rangeC, rangeD, rangeE])
        
        let rangeB_first = str.index(str.startIndex, offsetByCharacters: 4) ..< str.index(str.startIndex, offsetByCharacters: 6)
        let rangeB_second = str.index(str.startIndex, offsetByCharacters: 6) ..< str.index(str.startIndex, offsetByCharacters: 7)
        
        let runs = str[rangeSet].runs
        
        let testIntExpectation = [EquatableBox(2, rangeA), EquatableBox(3, rangeB), EquatableBox(3, rangeC), EquatableBox(nil, rangeD), EquatableBox(nil, rangeE)]
        XCTAssertEqual(runs[\.testInt].map(EquatableBox.init), testIntExpectation)
        XCTAssertEqual(runs[\.testInt].reversed().map(EquatableBox.init), testIntExpectation.reversed())
        
        let testStringExpectation = [EquatableBox(nil, rangeA), EquatableBox("foo", rangeB_first), EquatableBox("bar", rangeB_second), EquatableBox("baz", rangeC), EquatableBox(nil, rangeD), EquatableBox(nil, rangeE)]
        XCTAssertEqual(runs[\.testString].map(EquatableBox.init), testStringExpectation)
        XCTAssertEqual(runs[\.testString].reversed().map(EquatableBox.init), testStringExpectation.reversed())
    }
    
    func testRemoveSubranges() {
        var str = AttributedString("abcdefg")
        let rangeA = str.startIndex ..< str.index(str.startIndex, offsetByCharacters: 1)
        let rangeB = str.index(str.startIndex, offsetByCharacters: 2) ..< str.index(str.startIndex, offsetByCharacters: 3)
        let rangeC = str.index(str.startIndex, offsetByCharacters: 4) ..< str.index(str.startIndex, offsetByCharacters: 5)
        let ranges = RangeSet([rangeA, rangeB, rangeC])
        str[ranges].testInt = 2
        str.testBool = true
        str[rangeA].testString = "foo"
        
        str.removeSubranges(ranges)
        let result = AttributedString("bdfg", attributes: AttributeContainer.testBool(true))
        XCTAssertEqual(str, result)
    }
    
    func testSliceSetter() {
        var str = AttributedString("abcdefg")
        let rangeA = str.startIndex ..< str.index(str.startIndex, offsetByCharacters: 1)
        let rangeB = str.index(str.startIndex, offsetByCharacters: 2) ..< str.index(str.startIndex, offsetByCharacters: 3)
        let rangeC = str.index(str.startIndex, offsetByCharacters: 4) ..< str.index(str.startIndex, offsetByCharacters: 5)
        let ranges = RangeSet([rangeA, rangeB, rangeC])
        str[ranges].testInt = 2
        str.testBool = true
        str[rangeA].testString = "foo"
        
        do {
            var copy = str
            copy[ranges] = copy[ranges]
            XCTAssertEqual(copy, str)
        }
        
        do {
            var copy = str
            copy[ranges] = str[ranges]
            XCTAssertEqual(copy, str)
        }
        
        do {
            let str2 = AttributedString("Z_Y_X__")
            let rangeA2 = str2.startIndex ..< str2.index(str2.startIndex, offsetByCharacters: 1)
            let rangeB2 = str2.index(str.startIndex, offsetByCharacters: 2) ..< str2.index(str2.startIndex, offsetByCharacters: 3)
            let rangeC2 = str2.index(str.startIndex, offsetByCharacters: 4) ..< str2.index(str2.startIndex, offsetByCharacters: 5)
            let ranges2 = RangeSet([rangeA2, rangeB2, rangeC2])
            var copy = str
            copy[ranges] = str2[ranges2]
            XCTAssertEqual(String(copy.characters), "ZbYdXfg")
        }
    }
}
