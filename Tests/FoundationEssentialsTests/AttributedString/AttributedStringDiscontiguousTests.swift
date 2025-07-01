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

import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("Discontiguous AttributedString")
private struct AttributedStringDiscontiguousTests {
    @available(FoundationAttributedString 5.5, *)
    @Test func emptySlice() {
        let str = AttributedString()
        let slice = str[RangeSet()]
        #expect(slice.runs.isEmpty)
        #expect(slice.characters.isEmpty)
        #expect(slice.unicodeScalars.isEmpty)
        #expect(slice == slice)
        #expect(slice.runs.startIndex == slice.runs.endIndex)
        #expect(slice.characters.startIndex == slice.characters.endIndex)
        #expect(slice.unicodeScalars.startIndex == slice.unicodeScalars.endIndex)
        #expect(AttributedString("abc")[RangeSet()] == AttributedString("def")[RangeSet()])
        
        for r in slice.runs {
            Issue.record("Enumerating empty runs should not have produced \(r)")
        }
        for c in slice.characters {
            Issue.record("Enumerating empty characters should not have produced \(c)")
        }
        for s in slice.unicodeScalars {
            Issue.record("Enumerating empty unicode scalars should not have produced \(s)")
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func characters() {
        let str = AttributedString("abcdefgabc")
        let fullSlice = str[str.startIndex ..< str.endIndex].characters
        let fullDiscontiguousSlice = str[RangeSet(str.startIndex ..< str.endIndex)].characters
        #expect(fullSlice.elementsEqual(fullDiscontiguousSlice))
        
        let rangeA = str.startIndex ..< str.index(str.startIndex, offsetByCharacters: 3)
        let rangeB = str.index(str.endIndex, offsetByCharacters: -3) ..< str.endIndex
        let rangeSet = RangeSet([rangeA, rangeB])
        let slice = str[rangeSet].characters
        #expect(Array(slice) == ["a", "b", "c", "a", "b", "c"])
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func unicodeScalars() {
        let str = AttributedString("abcdefgabc")
        let fullSlice = str[str.startIndex ..< str.endIndex].unicodeScalars
        let fullDiscontiguousSlice = str[RangeSet(str.startIndex ..< str.endIndex)].unicodeScalars
        #expect(fullSlice.elementsEqual(fullDiscontiguousSlice))
        
        let rangeA = str.startIndex ..< str.index(str.startIndex, offsetByUnicodeScalars: 3)
        let rangeB = str.index(str.endIndex, offsetByUnicodeScalars: -3) ..< str.endIndex
        let rangeSet = RangeSet([rangeA, rangeB])
        let slice = str[rangeSet].unicodeScalars
        #expect(Array(slice) == ["a", "b", "c", "a", "b", "c"])
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func attributes() {
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
            #expect(a == b)
        }
        
        do {
            var a = str
            a[ranges].test.testInt = 2
            var b = str
            for range in ranges.ranges {
                b[range].test.testInt = 2
            }
            #expect(a == b)
        }
        
        do {
            var a = str
            a[ranges][AttributeScopes.TestAttributes.TestIntAttribute.self] = 2
            var b = str
            for range in ranges.ranges {
                b[range][AttributeScopes.TestAttributes.TestIntAttribute.self] = 2
            }
            #expect(a == b)
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
            #expect(a == b)
        }
        
        do {
            var a = str
            a.testInt = 2
            #expect(a[ranges].testInt == 2)
            a[rangeA].testInt = 3
            #expect(a[ranges].testInt == nil)
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
            #expect(a == b)
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
            #expect(a == b)
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
            #expect(a == b)
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
            #expect(a == b)
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func reinitialization() {
        var str = AttributedString("abcdefg")
        let rangeA = str.startIndex ..< str.index(str.startIndex, offsetByCharacters: 1)
        let rangeB = str.index(str.startIndex, offsetByCharacters: 2) ..< str.index(str.startIndex, offsetByCharacters: 3)
        let rangeC = str.index(str.startIndex, offsetByCharacters: 4) ..< str.index(str.startIndex, offsetByCharacters: 5)
        let ranges = RangeSet([rangeA, rangeB, rangeC])
        str[ranges].testInt = 2
        
        let reinitialized = AttributedString(str[ranges])
        #expect(reinitialized == AttributedString("ace", attributes: AttributeContainer.testInt(2)))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func reslicing() {
        var str = AttributedString("abcdefg")
        let rangeA = str.startIndex ..< str.index(str.startIndex, offsetByCharacters: 1)
        let rangeB = str.index(str.startIndex, offsetByCharacters: 2) ..< str.index(str.startIndex, offsetByCharacters: 3)
        let rangeC = str.index(str.startIndex, offsetByCharacters: 4) ..< str.index(str.startIndex, offsetByCharacters: 5)
        let ranges = RangeSet([rangeA, rangeB, rangeC])
        str[ranges].testInt = 2
        
        #expect(str[ranges] == str[ranges][ranges])
        #expect(AttributedString(str[ranges][RangeSet([rangeA, rangeB])]) == AttributedString("ac", attributes: AttributeContainer.testInt(2)))
        #expect(AttributedString(str[ranges][rangeA.lowerBound ..< rangeB.upperBound]) == AttributedString("ac", attributes: AttributeContainer.testInt(2)))
        
        #expect(str[RangeSet()][RangeSet()] == str[RangeSet()])
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func runs() {
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
        #expect(runs.count == expectedRanges.count)
        #expect(runs.reversed().count == expectedRanges.reversed().count)
        #expect(runs.map(\.range) == expectedRanges)
        #expect(runs.reversed().map(\.range) == expectedRanges.reversed())
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func coalescedRuns() {
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
        #expect(runs[\.testInt].map(EquatableBox.init) == testIntExpectation)
        #expect(runs[\.testInt].reversed().map(EquatableBox.init) == testIntExpectation.reversed())
        
        let testStringExpectation = [EquatableBox(nil, rangeA), EquatableBox("foo", rangeB_first), EquatableBox("bar", rangeB_second), EquatableBox("baz", rangeC), EquatableBox(nil, rangeD), EquatableBox(nil, rangeE)]
        #expect(runs[\.testString].map(EquatableBox.init) == testStringExpectation)
        #expect(runs[\.testString].reversed().map(EquatableBox.init) == testStringExpectation.reversed())
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func removeSubranges() {
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
        #expect(str == result)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func sliceSetter() {
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
            #expect(copy == str)
        }
        
        do {
            var copy = str
            copy[ranges] = str[ranges]
            #expect(copy == str)
        }
        
        do {
            let str2 = AttributedString("Z_Y_X__")
            let rangeA2 = str2.startIndex ..< str2.index(str2.startIndex, offsetByCharacters: 1)
            let rangeB2 = str2.index(str.startIndex, offsetByCharacters: 2) ..< str2.index(str2.startIndex, offsetByCharacters: 3)
            let rangeC2 = str2.index(str.startIndex, offsetByCharacters: 4) ..< str2.index(str2.startIndex, offsetByCharacters: 5)
            let ranges2 = RangeSet([rangeA2, rangeB2, rangeC2])
            var copy = str
            copy[ranges] = str2[ranges2]
            #expect(String(copy.characters) == "ZbYdXfg")
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func graphemesAcrossDiscontiguousRanges() {
        let str = "a\n\u{301}"
        let attrStr = AttributedString(str)
        let strRangeA = str.startIndex ..< str.index(after: str.startIndex) // Range of 'a'
        let strRangeB = str.index(before: str.endIndex) ..< str.endIndex // Range of '\u{301}'
        let attrStrRangeA = attrStr.startIndex ..< attrStr.index(afterCharacter: attrStr.startIndex) // Range of 'a'
        let attrStrRangeB = attrStr.index(beforeCharacter: attrStr.endIndex) ..< attrStr.endIndex // Range of '\u{301}'
        let strRanges = RangeSet([strRangeA, strRangeB])
        let attrStrRanges = RangeSet([attrStrRangeA, attrStrRangeB])
        
        // These discontiguous slices represent subranges that include the scalar 'a' followed by \u{301}
        // Unicode grapheme breaking rules dictate that these two unicode scalars form one grapheme cluster
        // While it may be considered unexpected, DiscontiguousSlice<String> nor DiscontiguousSlice<AttributedString.CharacterView> today will not combine these together and instead produce two Character elements
        // However, the important behavior that we are testing here is that:
        //      (1) Slicing in this manner does not crash
        //      (2) The behavior is consistent between String and AttributedString.CharacterView
        let strSlice = str[strRanges]
        let attrStrSlice = attrStr[attrStrRanges].characters
        #expect(strSlice.elementsEqual(attrStrSlice), "Characters \(Array(strSlice)) and \(Array(attrStrSlice)) do not match")
    }
}
