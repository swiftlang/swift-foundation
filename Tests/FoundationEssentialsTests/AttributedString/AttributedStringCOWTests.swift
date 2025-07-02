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
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

@available(FoundationAttributedString 5.5, *)
extension AttributedStringProtocol {
    fileprivate mutating func genericSetAttribute() {
        self.testInt = 3
    }
}

/// Tests for `AttributedString` to confirm expected CoW behavior
@Suite("AttributedString Copy on Write")
private struct AttributedStringCOWTests {
    
    // MARK: - Utility Functions
    @available(FoundationAttributedString 5.5, *)
    func createAttributedString() -> AttributedString {
        var str = AttributedString("Hello", attributes: container)
        str += AttributedString(" ")
        str += AttributedString("World", attributes: containerB)
        return str
    }
    
    @available(FoundationAttributedString 5.5, *)
    func assertCOWCopy(sourceLocation: SourceLocation = #_sourceLocation, _ operation: (inout AttributedString) -> Void) {
        let str = createAttributedString()
        var copy = str
        operation(&copy)
        #expect(str != copy, "Mutation operation did not copy when multiple references exist", sourceLocation: sourceLocation)
    }
    
    @available(FoundationAttributedString 5.5, *)
    func assertCOWCopyManual(sourceLocation: SourceLocation = #_sourceLocation, _ operation: (inout AttributedString) -> Void) {
        var str = createAttributedString()
        let gutsPtr = Unmanaged.passUnretained(str._guts)
        operation(&str)
        let newGutsPtr = Unmanaged.passUnretained(str._guts)
        #expect(gutsPtr.toOpaque() != newGutsPtr.toOpaque(), "Mutation operation with manual copy did not perform copy", sourceLocation: sourceLocation)
    }
    
    @available(FoundationAttributedString 5.5, *)
    func assertCOWNoCopy(sourceLocation: SourceLocation = #_sourceLocation, _ operation: (inout AttributedString) -> Void) {
        var str = createAttributedString()
        let gutsPtr = Unmanaged.passUnretained(str._guts)
        operation(&str)
        let newGutsPtr = Unmanaged.passUnretained(str._guts)
        #expect(gutsPtr.toOpaque() == newGutsPtr.toOpaque(), "Mutation operation copied when only one reference exists", sourceLocation: sourceLocation)
    }
    
    @available(FoundationAttributedString 5.5, *)
    func assertCOWBehavior(sourceLocation: SourceLocation = #_sourceLocation, _ operation: (inout AttributedString) -> Void) {
        assertCOWCopy(sourceLocation: sourceLocation, operation)
        assertCOWNoCopy(sourceLocation: sourceLocation, operation)
    }
    
    @available(FoundationAttributedString 5.5, *)
    func makeSubrange(_ str: AttributedString) -> Range<AttributedString.Index> {
        return str.characters.index(str.startIndex, offsetBy: 2)..<str.characters.index(str.endIndex, offsetBy: -2)
    }
    
    @available(FoundationAttributedString 5.5, *)
    func makeSubranges(_ str: AttributedString) -> RangeSet<AttributedString.Index> {
        let rangeA = str.characters.index(str.startIndex, offsetBy: 2)..<str.characters.index(str.startIndex, offsetBy: 4)
        let rangeB = str.characters.index(str.endIndex, offsetBy: -4)..<str.characters.index(str.endIndex, offsetBy: -2)
        return RangeSet([rangeA, rangeB])
    }
    
    @available(FoundationAttributedString 5.5, *)
    var container: AttributeContainer {
        var container = AttributeContainer()
        container.testInt = 2
        return container
    }
    
    @available(FoundationAttributedString 5.5, *)
    var containerB: AttributeContainer {
        var container = AttributeContainer()
        container.testBool = true
        return container
    }
    
    // MARK: - Tests
    
    @available(FoundationAttributedString 5.5, *)
    @Test func topLevelType() {
        assertCOWBehavior { (str) in
            str.setAttributes(container)
        }
        assertCOWBehavior { (str) in
            str.mergeAttributes(container)
        }
        assertCOWBehavior { (str) in
            str.replaceAttributes(container, with: containerB)
        }
        assertCOWBehavior { (str) in
            str.append(AttributedString("b", attributes: containerB))
        }
        assertCOWBehavior { (str) in
            str.insert(AttributedString("b", attributes: containerB), at: str.startIndex)
        }
        assertCOWBehavior { (str) in
            str.removeSubrange(..<str.characters.index(str.startIndex, offsetBy: 3))
        }
        assertCOWBehavior { (str) in
            str.removeSubranges(makeSubranges(str))
        }
        assertCOWBehavior { (str) in
            str.replaceSubrange(..<str.characters.index(str.startIndex, offsetBy: 3), with: AttributedString("b", attributes: containerB))
        }
        assertCOWBehavior { (str) in
            str[AttributeScopes.TestAttributes.TestIntAttribute.self] = 3
        }
        assertCOWBehavior { (str) in
            str.testInt = 3
        }
        assertCOWBehavior { (str) in
            str.test.testInt = 3
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func substring() {
        assertCOWBehavior { (str) in
            str[makeSubrange(str)].setAttributes(container)
        }
        assertCOWBehavior { (str) in
            str[makeSubrange(str)].mergeAttributes(container)
        }
        assertCOWBehavior { (str) in
            str[makeSubrange(str)].replaceAttributes(container, with: containerB)
        }
        assertCOWBehavior { (str) in
            str[makeSubrange(str)][AttributeScopes.TestAttributes.TestIntAttribute.self] = 3
        }
        assertCOWBehavior { (str) in
            str[makeSubrange(str)].testInt = 3
        }
        assertCOWBehavior { (str) in
            str[makeSubrange(str)].test.testInt = 3
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func discontiguousSubstring() {
        assertCOWBehavior { (str) in
            str[makeSubranges(str)].setAttributes(container)
        }
        assertCOWBehavior { (str) in
            str[makeSubranges(str)].mergeAttributes(container)
        }
        assertCOWBehavior { (str) in
            str[makeSubranges(str)].replaceAttributes(container, with: containerB)
        }
        assertCOWBehavior { (str) in
            str[makeSubranges(str)][AttributeScopes.TestAttributes.TestIntAttribute.self] = 3
        }
        assertCOWBehavior { (str) in
            str[makeSubranges(str)].testInt = 3
        }
        assertCOWBehavior { (str) in
            str[makeSubranges(str)].test.testInt = 3
        }
        assertCOWBehavior { (str) in
            let other = AttributedString("___________")
            str[makeSubranges(str)] = other[makeSubranges(other)]
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func characters() {
        let char: Character = "a"
        
        assertCOWBehavior { (str) in
            str.characters.replaceSubrange(makeSubrange(str), with: "abc")
        }
        assertCOWBehavior { (str) in
            str.characters.append(char)
        }
        assertCOWBehavior { (str) in
            str.characters.append(contentsOf: "abc")
        }
        assertCOWBehavior { (str) in
            str.characters.append(contentsOf: [char, char, char])
        }
        assertCOWBehavior { (str) in
            str.characters[str.startIndex] = "A"
        }
        assertCOWBehavior { (str) in
            str.characters[makeSubrange(str)].append("a")
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func unicodeScalars() {
        let scalar: UnicodeScalar = "a"
        
        assertCOWBehavior { (str) in
            str.unicodeScalars.replaceSubrange(makeSubrange(str), with: [scalar, scalar])
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func genericProtocol() {
        assertCOWBehavior {
            $0.genericSetAttribute()
        }
        assertCOWBehavior {
            $0[makeSubrange($0)].genericSetAttribute()
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func indexTracking() {
        assertCOWBehavior {
            _ = $0.transform(updating: $0.startIndex ..< $0.endIndex) {
                $0.testInt = 2
            }
        }
        assertCOWBehavior {
            _ = $0.transform(updating: $0.startIndex ..< $0.endIndex) {
                $0.insert(AttributedString("_"), at: $0.startIndex)
            }
        }
        assertCOWBehavior {
            _ = $0.transform(updating: [$0.startIndex ..< $0.endIndex]) {
                $0.testInt = 2
            }
        }
        assertCOWBehavior {
            _ = $0.transform(updating: [$0.startIndex ..< $0.endIndex]) {
                $0.insert(AttributedString("_"), at: $0.startIndex)
            }
        }
        
        // Ensure that creating a reference in the transformation closure still causes a copy to happen during post-mutation index updates
        var storage = AttributedString()
        assertCOWCopyManual {
            _ = $0.transform(updating: $0.startIndex ..< $0.endIndex) {
                $0.insert(AttributedString("_"), at: $0.startIndex)
                // Store a reference after performing the mutation so the mutation doesn't cause an inherent copy
                storage = $0
            }
        }
        #expect(storage != "")
        
        // Ensure the same semantics hold even when the closure throws
        storage = AttributedString()
        assertCOWCopyManual {
            _ = try? $0.transform(updating: $0.startIndex ..< $0.endIndex) {
                $0.insert(AttributedString("_"), at: $0.startIndex)
                // Store a reference after performing the mutation so the mutation doesn't cause an inherent copy
                storage = $0
                throw CocoaError(.fileReadUnknown)
            }
        }
        #expect(storage != "")
    }
}
