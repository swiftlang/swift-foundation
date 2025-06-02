//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(TestSupport)
import TestSupport
#endif

final class AttributedStringIndexValidityTests: XCTestCase {
    public func testStartEndRange() {
        let str = AttributedString("Hello, world")
        
        XCTAssertTrue(str.startIndex.isValid(within: str))
        XCTAssertFalse(str.endIndex.isValid(within: str))
        XCTAssertTrue((str.startIndex ..< str.endIndex).isValid(within: str))
        XCTAssertTrue((str.startIndex ..< str.startIndex).isValid(within: str))
        XCTAssertTrue((str.endIndex ..< str.endIndex).isValid(within: str))
        
        let subStart = str.index(afterCharacter: str.startIndex)
        let subEnd = str.index(beforeCharacter: str.endIndex)
        
        do {
            let substr = str[str.startIndex ..< str.endIndex]
            XCTAssertTrue(substr.startIndex.isValid(within: substr))
            XCTAssertFalse(substr.endIndex.isValid(within: substr))
            XCTAssertTrue((substr.startIndex ..< substr.endIndex).isValid(within: substr))
        }
        
        do {
            let substr = str[subStart ..< str.endIndex]
            XCTAssertTrue(substr.startIndex.isValid(within: substr))
            XCTAssertFalse(substr.endIndex.isValid(within: substr))
            XCTAssertTrue((substr.startIndex ..< substr.endIndex).isValid(within: substr))
        }
        
        do {
            let substr = str[str.startIndex ..< subEnd]
            XCTAssertTrue(substr.startIndex.isValid(within: substr))
            XCTAssertFalse(substr.endIndex.isValid(within: substr))
            XCTAssertTrue((substr.startIndex ..< substr.endIndex).isValid(within: substr))
        }
        
        do {
            let substr = str[subStart ..< subEnd]
            XCTAssertTrue(substr.startIndex.isValid(within: substr))
            XCTAssertFalse(substr.endIndex.isValid(within: substr))
            XCTAssertTrue((substr.startIndex ..< substr.endIndex).isValid(within: substr))
            XCTAssertTrue((substr.startIndex ..< substr.startIndex).isValid(within: substr))
            XCTAssertTrue((substr.endIndex ..< substr.endIndex).isValid(within: substr))
        }
        
        do {
            let substr = str[RangeSet(str.startIndex ..< str.endIndex)]
            XCTAssertTrue(str.startIndex.isValid(within: substr))
            XCTAssertFalse(str.endIndex.isValid(within: substr))
            XCTAssertTrue((str.startIndex ..< str.endIndex).isValid(within: substr))
        }
        
        do {
            let substr = str[RangeSet(subStart ..< str.endIndex)]
            XCTAssertTrue(subStart.isValid(within: substr))
            XCTAssertFalse(str.endIndex.isValid(within: substr))
            XCTAssertTrue((subStart ..< str.endIndex).isValid(within: substr))
        }
        
        do {
            let substr = str[RangeSet(str.startIndex ..< subEnd)]
            XCTAssertTrue(str.startIndex.isValid(within: substr))
            XCTAssertFalse(subEnd.isValid(within: substr))
            XCTAssertTrue((str.startIndex ..< subEnd).isValid(within: substr))
        }
        
        do {
            let substr = str[RangeSet(subStart ..< subEnd)]
            XCTAssertTrue(subStart.isValid(within: substr))
            XCTAssertFalse(subEnd.isValid(within: substr))
            XCTAssertTrue((subStart ..< subEnd).isValid(within: substr))
            XCTAssertTrue((subStart ..< subStart).isValid(within: substr))
            XCTAssertTrue((subEnd ..< subEnd).isValid(within: substr))
        }
    }
    
    public func testExhaustiveIndices() {
        let str = AttributedString("Hello Cafe\u{301} 👍🏻🇺🇸 World")
        for idx in str.characters.indices {
            XCTAssertTrue(idx.isValid(within: str))
        }
        for idx in str.unicodeScalars.indices {
            XCTAssertTrue(idx.isValid(within: str))
        }
        for idx in str.utf8.indices {
            XCTAssertTrue(idx.isValid(within: str))
        }
        for idx in str.utf16.indices {
            XCTAssertTrue(idx.isValid(within: str))
        }
    }
    
    public func testOutOfBoundsContiguous() {
        let str = AttributedString("Hello, world")
        let subStart = str.index(afterCharacter: str.startIndex)
        let subEnd = str.index(beforeCharacter: str.endIndex)
        let substr = str[subStart ..< subEnd]
        
        XCTAssertFalse(str.startIndex.isValid(within: substr))
        XCTAssertFalse(str.endIndex.isValid(within: substr))
        XCTAssertFalse((str.startIndex ..< str.endIndex).isValid(within: substr))
        XCTAssertFalse((str.startIndex ..< substr.startIndex).isValid(within: substr))
        XCTAssertFalse((substr.startIndex ..< str.endIndex).isValid(within: substr))
        XCTAssertFalse((str.startIndex ..< str.startIndex).isValid(within: substr))
        XCTAssertFalse((str.endIndex ..< str.endIndex).isValid(within: substr))
    }
    
    public func testOutOfBoundsDiscontiguous() {
        let str = AttributedString("Hello, world")
        let idxA = str.index(afterCharacter: str.startIndex)
        let idxB = str.index(afterCharacter: idxA)
        let idxD = str.index(beforeCharacter: str.endIndex)
        let idxC = str.index(beforeCharacter: idxD)
        let middleIdx = str.index(afterCharacter: idxB)
        let substr = str[RangeSet([idxA ..< idxB, idxC ..< idxD])]
        
        XCTAssertFalse(str.startIndex.isValid(within: substr))
        XCTAssertFalse(str.endIndex.isValid(within: substr))
        XCTAssertFalse(idxD.isValid(within: substr))
        XCTAssertFalse(middleIdx.isValid(within: substr))
        XCTAssertFalse((str.startIndex ..< idxA).isValid(within: substr))
        XCTAssertFalse((idxA ..< middleIdx).isValid(within: substr))
        XCTAssertFalse((middleIdx ..< idxD).isValid(within: substr))
        XCTAssertFalse((str.startIndex ..< str.startIndex).isValid(within: substr))
        XCTAssertFalse((str.endIndex ..< str.endIndex).isValid(within: substr))
    }
    
    public func testMutationInvalidation() {
        func checkInPlace(_ mutation: (inout AttributedString) -> (), file: StaticString = #filePath, line: UInt = #line) {
            var str = AttributedString("Hello World")
            let idxA = str.startIndex
            let idxB = str.index(afterCharacter: idxA)
            
            XCTAssertTrue(idxA.isValid(within: str), "Initial index A was invalid in original", file: file, line: line)
            XCTAssertTrue(idxB.isValid(within: str), "Initial index B was invalid in original", file: file, line: line)
            XCTAssertTrue((idxA ..< idxB).isValid(within: str), "Initial range was invalid in original", file: file, line: line)
            XCTAssertTrue(RangeSet(idxA ..< idxB).isValid(within: str), "Initial range set was invalid in original", file: file, line: line)
            
            mutation(&str)
            
            XCTAssertFalse(idxA.isValid(within: str), "Initial index A was valid in in-place mutated", file: file, line: line)
            XCTAssertFalse(idxB.isValid(within: str), "Initial index B was valid in in-place mutated", file: file, line: line)
            XCTAssertFalse((idxA ..< idxB).isValid(within: str), "Initial range was valid in in-place mutated", file: file, line: line)
            XCTAssertFalse(RangeSet(idxA ..< idxB).isValid(within: str), "Initial range set was valid in in-place mutated", file: file, line: line)
        }
        
        func checkCopy(_ mutation: (inout AttributedString) -> (), file: StaticString = #filePath, line: UInt = #line) {
            let str = AttributedString("Hello World")
            let idxA = str.startIndex
            let idxB = str.index(afterCharacter: idxA)
            
            var copy = str
            XCTAssertTrue(idxA.isValid(within: str), "Initial index A was invalid in original", file: file, line: line)
            XCTAssertTrue(idxB.isValid(within: str), "Initial index B was invalid in original", file: file, line: line)
            XCTAssertTrue((idxA ..< idxB).isValid(within: str), "Initial range was invalid in original", file: file, line: line)
            XCTAssertTrue(RangeSet(idxA ..< idxB).isValid(within: str), "Initial range set was invalid in original", file: file, line: line)
            XCTAssertTrue(idxA.isValid(within: copy), "Initial index A was invalid in copy", file: file, line: line)
            XCTAssertTrue(idxB.isValid(within: copy), "Initial index B was invalid in copy", file: file, line: line)
            XCTAssertTrue((idxA ..< idxB).isValid(within: copy), "Initial range was invalid in copy", file: file, line: line)
            XCTAssertTrue(RangeSet(idxA ..< idxB).isValid(within: copy), "Initial range set was invalid in copy", file: file, line: line)
            
            mutation(&copy)
            
            XCTAssertTrue(idxA.isValid(within: str), "Initial index A was invalid in original after copy", file: file, line: line)
            XCTAssertTrue(idxB.isValid(within: str), "Initial index B was invalid in original after copy", file: file, line: line)
            XCTAssertTrue((idxA ..< idxB).isValid(within: str), "Initial range was invalid in original after copy", file: file, line: line)
            XCTAssertTrue(RangeSet(idxA ..< idxB).isValid(within: str), "Initial range set was invalid in original after copy", file: file, line: line)
            XCTAssertFalse(idxA.isValid(within: copy), "Initial index A was valid in copy", file: file, line: line)
            XCTAssertFalse(idxB.isValid(within: copy), "Initial index B was valid in copy", file: file, line: line)
            XCTAssertFalse((idxA ..< idxB).isValid(within: copy), "Initial range was valid in copy", file: file, line: line)
            XCTAssertFalse(RangeSet(idxA ..< idxB).isValid(within: copy), "Initial range set was valid in copy", file: file, line: line)
        }
        
        func check(_ mutation: (inout AttributedString) -> (), file: StaticString = #filePath, line: UInt = #line) {
            checkInPlace(mutation, file: file, line: line)
            checkCopy(mutation, file: file, line: line)
        }
        
        check {
            $0.replaceSubrange($0.startIndex ..< $0.endIndex, with: AttributedString("Hello"))
        }
        
        check {
            $0.testInt = 2
        }
        
        check {
            $0.characters.append(contentsOf: "Hello")
        }
        
        check {
            $0.unicodeScalars.remove(at: $0.startIndex)
        }
        
        check {
            $0[$0.startIndex ..< $0.index(afterCharacter: $0.startIndex)].testInt = 2
        }
    }
}
