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

import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("AttributedString Index Validity")
private struct AttributedStringIndexValidityTests {
    @available(FoundationAttributedString 5.5, *)
    @Test func startEndRange() {
        let str = AttributedString("Hello, world")
        
        #expect(str.startIndex.isValid(within: str))
        #expect(!str.endIndex.isValid(within: str))
        #expect((str.startIndex ..< str.endIndex).isValid(within: str))
        #expect((str.startIndex ..< str.startIndex).isValid(within: str))
        #expect((str.endIndex ..< str.endIndex).isValid(within: str))
        
        let subStart = str.index(afterCharacter: str.startIndex)
        let subEnd = str.index(beforeCharacter: str.endIndex)
        
        do {
            let substr = str[str.startIndex ..< str.endIndex]
            #expect(substr.startIndex.isValid(within: substr))
            #expect(!substr.endIndex.isValid(within: substr))
            #expect((substr.startIndex ..< substr.endIndex).isValid(within: substr))
        }
        
        do {
            let substr = str[subStart ..< str.endIndex]
            #expect(substr.startIndex.isValid(within: substr))
            #expect(!substr.endIndex.isValid(within: substr))
            #expect((substr.startIndex ..< substr.endIndex).isValid(within: substr))
        }
        
        do {
            let substr = str[str.startIndex ..< subEnd]
            #expect(substr.startIndex.isValid(within: substr))
            #expect(!substr.endIndex.isValid(within: substr))
            #expect((substr.startIndex ..< substr.endIndex).isValid(within: substr))
        }
        
        do {
            let substr = str[subStart ..< subEnd]
            #expect(substr.startIndex.isValid(within: substr))
            #expect(!substr.endIndex.isValid(within: substr))
            #expect((substr.startIndex ..< substr.endIndex).isValid(within: substr))
            #expect((substr.startIndex ..< substr.startIndex).isValid(within: substr))
            #expect((substr.endIndex ..< substr.endIndex).isValid(within: substr))
        }
        
        do {
            let substr = str[RangeSet(str.startIndex ..< str.endIndex)]
            #expect(str.startIndex.isValid(within: substr))
            #expect(!str.endIndex.isValid(within: substr))
            #expect((str.startIndex ..< str.endIndex).isValid(within: substr))
        }
        
        do {
            let substr = str[RangeSet(subStart ..< str.endIndex)]
            #expect(subStart.isValid(within: substr))
            #expect(!str.endIndex.isValid(within: substr))
            #expect((subStart ..< str.endIndex).isValid(within: substr))
        }
        
        do {
            let substr = str[RangeSet(str.startIndex ..< subEnd)]
            #expect(str.startIndex.isValid(within: substr))
            #expect(!subEnd.isValid(within: substr))
            #expect((str.startIndex ..< subEnd).isValid(within: substr))
        }
        
        do {
            let substr = str[RangeSet(subStart ..< subEnd)]
            #expect(subStart.isValid(within: substr))
            #expect(!subEnd.isValid(within: substr))
            #expect((subStart ..< subEnd).isValid(within: substr))
            #expect((subStart ..< subStart).isValid(within: substr))
            #expect((subEnd ..< subEnd).isValid(within: substr))
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func exhaustiveIndices() {
        let str = AttributedString("Hello Cafe\u{301} 👍🏻🇺🇸 World")
        for idx in str.characters.indices {
            #expect(idx.isValid(within: str))
        }
        for idx in str.unicodeScalars.indices {
            #expect(idx.isValid(within: str))
        }
        for idx in str.utf8.indices {
            #expect(idx.isValid(within: str))
        }
        for idx in str.utf16.indices {
            #expect(idx.isValid(within: str))
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func outOfBoundsContiguous() {
        let str = AttributedString("Hello, world")
        let subStart = str.index(afterCharacter: str.startIndex)
        let subEnd = str.index(beforeCharacter: str.endIndex)
        let substr = str[subStart ..< subEnd]
        
        #expect(!str.startIndex.isValid(within: substr))
        #expect(!str.endIndex.isValid(within: substr))
        #expect(!(str.startIndex ..< str.endIndex).isValid(within: substr))
        #expect(!(str.startIndex ..< substr.startIndex).isValid(within: substr))
        #expect(!(substr.startIndex ..< str.endIndex).isValid(within: substr))
        #expect(!(str.startIndex ..< str.startIndex).isValid(within: substr))
        #expect(!(str.endIndex ..< str.endIndex).isValid(within: substr))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func outOfBoundsDiscontiguous() {
        let str = AttributedString("Hello, world")
        let idxA = str.index(afterCharacter: str.startIndex)
        let idxB = str.index(afterCharacter: idxA)
        let idxD = str.index(beforeCharacter: str.endIndex)
        let idxC = str.index(beforeCharacter: idxD)
        let middleIdx = str.index(afterCharacter: idxB)
        let substr = str[RangeSet([idxA ..< idxB, idxC ..< idxD])]
        
        #expect(!str.startIndex.isValid(within: substr))
        #expect(!str.endIndex.isValid(within: substr))
        #expect(!idxD.isValid(within: substr))
        #expect(!middleIdx.isValid(within: substr))
        #expect(!(str.startIndex ..< idxA).isValid(within: substr))
        #expect(!(idxA ..< middleIdx).isValid(within: substr))
        #expect(!(middleIdx ..< idxD).isValid(within: substr))
        #expect(!(str.startIndex ..< str.startIndex).isValid(within: substr))
        #expect(!(str.endIndex ..< str.endIndex).isValid(within: substr))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func mutationInvalidation() {
        func checkInPlace(_ mutation: (inout AttributedString) -> (), sourceLocation: SourceLocation = #_sourceLocation) {
            var str = AttributedString("Hello World")
            let idxA = str.startIndex
            let idxB = str.index(afterCharacter: idxA)
            
            #expect(idxA.isValid(within: str), "Initial index A was invalid in original", sourceLocation: sourceLocation)
            #expect(idxB.isValid(within: str), "Initial index B was invalid in original", sourceLocation: sourceLocation)
            #expect((idxA ..< idxB).isValid(within: str), "Initial range was invalid in original", sourceLocation: sourceLocation)
            #expect(RangeSet(idxA ..< idxB).isValid(within: str), "Initial range set was invalid in original", sourceLocation: sourceLocation)
            
            mutation(&str)
            
            #expect(!idxA.isValid(within: str), "Initial index A was valid in in-place mutated", sourceLocation: sourceLocation)
            #expect(!idxB.isValid(within: str), "Initial index B was valid in in-place mutated", sourceLocation: sourceLocation)
            #expect(!(idxA ..< idxB).isValid(within: str), "Initial range was valid in in-place mutated", sourceLocation: sourceLocation)
            #expect(!RangeSet(idxA ..< idxB).isValid(within: str), "Initial range set was valid in in-place mutated", sourceLocation: sourceLocation)
        }
        
        func checkCopy(_ mutation: (inout AttributedString) -> (), sourceLocation: SourceLocation = #_sourceLocation) {
            let str = AttributedString("Hello World")
            let idxA = str.startIndex
            let idxB = str.index(afterCharacter: idxA)
            
            var copy = str
            #expect(idxA.isValid(within: str), "Initial index A was invalid in original", sourceLocation: sourceLocation)
            #expect(idxB.isValid(within: str), "Initial index B was invalid in original", sourceLocation: sourceLocation)
            #expect((idxA ..< idxB).isValid(within: str), "Initial range was invalid in original", sourceLocation: sourceLocation)
            #expect(RangeSet(idxA ..< idxB).isValid(within: str), "Initial range set was invalid in original", sourceLocation: sourceLocation)
            #expect(idxA.isValid(within: copy), "Initial index A was invalid in copy", sourceLocation: sourceLocation)
            #expect(idxB.isValid(within: copy), "Initial index B was invalid in copy", sourceLocation: sourceLocation)
            #expect((idxA ..< idxB).isValid(within: copy), "Initial range was invalid in copy", sourceLocation: sourceLocation)
            #expect(RangeSet(idxA ..< idxB).isValid(within: copy), "Initial range set was invalid in copy", sourceLocation: sourceLocation)
            
            mutation(&copy)
            
            #expect(idxA.isValid(within: str), "Initial index A was invalid in original after copy", sourceLocation: sourceLocation)
            #expect(idxB.isValid(within: str), "Initial index B was invalid in original after copy", sourceLocation: sourceLocation)
            #expect((idxA ..< idxB).isValid(within: str), "Initial range was invalid in original after copy", sourceLocation: sourceLocation)
            #expect(RangeSet(idxA ..< idxB).isValid(within: str), "Initial range set was invalid in original after copy", sourceLocation: sourceLocation)
            #expect(!idxA.isValid(within: copy), "Initial index A was valid in copy", sourceLocation: sourceLocation)
            #expect(!idxB.isValid(within: copy), "Initial index B was valid in copy", sourceLocation: sourceLocation)
            #expect(!(idxA ..< idxB).isValid(within: copy), "Initial range was valid in copy", sourceLocation: sourceLocation)
            #expect(!RangeSet(idxA ..< idxB).isValid(within: copy), "Initial range set was valid in copy", sourceLocation: sourceLocation)
        }
        
        func check(_ mutation: (inout AttributedString) -> (), sourceLocation: SourceLocation = #_sourceLocation) {
            checkInPlace(mutation, sourceLocation: sourceLocation)
            checkCopy(mutation, sourceLocation: sourceLocation)
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
