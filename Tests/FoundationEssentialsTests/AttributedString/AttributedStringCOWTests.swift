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

#if FOUNDATION_FRAMEWORK
import Foundation
#else
import FoundationEssentials
#endif

extension AttributedStringProtocol {
    fileprivate mutating func genericSetAttribute() {
        self.testInt = 3
    }
}

/// Tests for `AttributedString` to confirm expected CoW behavior
final class TestAttributedStringCOW: XCTestCase {
    
    // MARK: - Utility Functions
    
    func createAttributedString() -> AttributedString {
        var str = AttributedString("Hello", attributes: container)
        str += AttributedString(" ")
        str += AttributedString("World", attributes: containerB)
        return str
    }
    
    func assertCOWCopy(file: StaticString = #filePath, line: UInt = #line, _ operation: (inout AttributedString) -> Void) {
        let str = createAttributedString()
        var copy = str
        operation(&copy)
        XCTAssertNotEqual(str, copy, "Mutation operation did not copy when multiple references exist", file: file, line: line)
    }
    
    func assertCOWCopyManual(file: StaticString = #filePath, line: UInt = #line, _ operation: (inout AttributedString) -> Void) {
        var str = createAttributedString()
        let gutsPtr = Unmanaged.passUnretained(str._guts)
        operation(&str)
        let newGutsPtr = Unmanaged.passUnretained(str._guts)
        XCTAssertNotEqual(gutsPtr.toOpaque(), newGutsPtr.toOpaque(), "Mutation operation with manual copy did not perform copy", file: file, line: line)
    }
    
    func assertCOWNoCopy(file: StaticString = #filePath, line: UInt = #line, _ operation: (inout AttributedString) -> Void) {
        var str = createAttributedString()
        let gutsPtr = Unmanaged.passUnretained(str._guts)
        operation(&str)
        let newGutsPtr = Unmanaged.passUnretained(str._guts)
        XCTAssertEqual(gutsPtr.toOpaque(), newGutsPtr.toOpaque(), "Mutation operation copied when only one reference exists", file: file, line: line)
    }
    
    func assertCOWBehavior(file: StaticString = #filePath, line: UInt = #line, _ operation: (inout AttributedString) -> Void) {
        assertCOWCopy(file: file, line: line, operation)
        assertCOWNoCopy(file: file, line: line, operation)
    }
    
    func makeSubrange(_ str: AttributedString) -> Range<AttributedString.Index> {
        return str.characters.index(str.startIndex, offsetBy: 2)..<str.characters.index(str.endIndex, offsetBy: -2)
    }
    
    func makeSubranges(_ str: AttributedString) -> RangeSet<AttributedString.Index> {
        let rangeA = str.characters.index(str.startIndex, offsetBy: 2)..<str.characters.index(str.startIndex, offsetBy: 4)
        let rangeB = str.characters.index(str.endIndex, offsetBy: -4)..<str.characters.index(str.endIndex, offsetBy: -2)
        return RangeSet([rangeA, rangeB])
    }
    
    lazy var container: AttributeContainer = {
        var container = AttributeContainer()
        container.testInt = 2
        return container
    }()
    
    lazy var containerB: AttributeContainer = {
        var container = AttributeContainer()
        container.testBool = true
        return container
    }()
    
    // MARK: - Tests
    
    func testTopLevelType() {
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
    
    func testSubstring() {
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
    
    func testDiscontiguousSubstring() {
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
    
    func testCharacters() {
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
    
    func testUnicodeScalars() {
        let scalar: UnicodeScalar = "a"
        
        assertCOWBehavior { (str) in
            str.unicodeScalars.replaceSubrange(makeSubrange(str), with: [scalar, scalar])
        }
    }
    
    func testGenericProtocol() {
        assertCOWBehavior {
            $0.genericSetAttribute()
        }
        assertCOWBehavior {
            $0[makeSubrange($0)].genericSetAttribute()
        }
    }
    
    func testIndexTracking() {
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
        XCTAssertNotEqual(storage, "")
        
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
        XCTAssertNotEqual(storage, "")
    }
}
