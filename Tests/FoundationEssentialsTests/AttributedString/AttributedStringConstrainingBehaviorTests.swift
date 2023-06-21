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

class TestAttributedStringConstrainingBehavior: XCTestCase {
    
    func verify<K: AttributedStringKey>(
        string: AttributedString,
        matches expected: [(String, K.Value?)],
        for key: KeyPath<AttributeDynamicLookup, K>,
        file: StaticString = #file, line: UInt = #line
    ) {
        let runs = string.runs[key]
        XCTAssertEqual(runs.count, expected.count, "Unexpected number of runs", file: file, line: line)
        for ((val, range), expectation) in zip(runs, expected) {
            let slice = String.UnicodeScalarView(string.unicodeScalars[range])
            XCTAssertTrue(slice.elementsEqual(expectation.0.unicodeScalars), "Unexpected range of run: \(slice.debugDescription) vs \(expectation.0.debugDescription)", file: file, line: line)
            XCTAssertEqual(val, expectation.1, "Unexpected value of attribute \(K.self) for range \(expectation.0)", file: file, line: line)
        }
        for ((val, range), expectation) in zip(runs.reversed(), expected.reversed()) {
            let slice = String.UnicodeScalarView(string.unicodeScalars[range])
            XCTAssertTrue(slice.elementsEqual(expectation.0.unicodeScalars), "Unexpected range of run while reverse iterating: \(slice.debugDescription) vs \(expectation.0.debugDescription)", file: file, line: line)
            XCTAssertEqual(val, expectation.1, "Unexpected value of attribute \(K.self) for range \(expectation.0) while reverse iterating", file: file, line: line)
        }
    }
    
    func verify<K: AttributedStringKey, K2: AttributedStringKey>(string: AttributedString, matches expected: [(String, K.Value?, K2.Value?)], for key: KeyPath<AttributeDynamicLookup, K>, _ key2: KeyPath<AttributeDynamicLookup, K2>, file: StaticString = #file, line: UInt = #line) {
        let runs = string.runs[key, key2]
        XCTAssertEqual(runs.count, expected.count, "Unexpected number of runs", file: file, line: line)
        for ((val1, val2, range), expectation) in zip(runs, expected) {
            XCTAssertEqual(String(string.characters[range]),expectation.0, "Unexpected range of run",  file: file, line: line)
            XCTAssertEqual(val1, expectation.1, "Unexpected value of attribute \(K.self) for range \(expectation.0)", file: file, line: line)
            XCTAssertEqual(val2, expectation.2, "Unexpected value of attribute \(K2.self) for range \(expectation.0)", file: file, line: line)
        }
        for ((val1, val2, range), expectation) in zip(runs.reversed(), expected.reversed()) {
            XCTAssertEqual(String(string.characters[range]), expectation.0, "Unexpected range of run while reverse iterating", file: file, line: line)
            XCTAssertEqual(val1, expectation.1, "Unexpected value of attribute \(K.self) for range \(expectation.0) while reverse iterating", file: file, line: line)
            XCTAssertEqual(val2, expectation.2, "Unexpected value of attribute \(K2.self) for range \(expectation.0) while reverse iterating", file: file, line: line)
        }
    }
    
    func verify<K: AttributedStringKey, K2: AttributedStringKey, K3: AttributedStringKey>(string: AttributedString, matches expected: [(String, K.Value?, K2.Value?, K3.Value?)], for key: KeyPath<AttributeDynamicLookup, K>, _ key2: KeyPath<AttributeDynamicLookup, K2>, _ key3: KeyPath<AttributeDynamicLookup, K3>, file: StaticString = #file, line: UInt = #line) {
        let runs = string.runs[key, key2, key3]
        XCTAssertEqual(runs.count, expected.count, "Unexpected number of runs", file: file, line: line)
        for ((val1, val2, val3, range), expectation) in zip(runs, expected) {
            XCTAssertEqual(String(string.characters[range]),expectation.0, "Unexpected range of run",  file: file, line: line)
            XCTAssertEqual(val1, expectation.1, "Unexpected value of attribute \(K.self) for range \(expectation.0)", file: file, line: line)
            XCTAssertEqual(val2, expectation.2, "Unexpected value of attribute \(K2.self) for range \(expectation.0)", file: file, line: line)
            XCTAssertEqual(val3, expectation.3, "Unexpected value of attribute \(K3.self) for range \(expectation.0)", file: file, line: line)
        }
        for ((val1, val2, val3, range), expectation) in zip(runs.reversed(), expected.reversed()) {
            XCTAssertEqual(String(string.characters[range]), expectation.0, "Unexpected range of run while reverse iterating", file: file, line: line)
            XCTAssertEqual(val1, expectation.1, "Unexpected value of attribute \(K.self) for range \(expectation.0) while reverse iterating", file: file, line: line)
            XCTAssertEqual(val2, expectation.2, "Unexpected value of attribute \(K2.self) for range \(expectation.0) while reverse iterating", file: file, line: line)
            XCTAssertEqual(val3, expectation.3, "Unexpected value of attribute \(K3.self) for range \(expectation.0) while reverse iterating", file: file, line: line)
        }
    }
    
    // MARK: Extending Run Tests
    
    func testExtendingRunAddCharacters() {
        let str = AttributedString("Hello, world", attributes: .init().testInt(2).testNonExtended(1))
        
        var result = str
        result.characters.append(contentsOf: "ABC")
        verify(string: result, matches: [("Hello, world", 2, 1), ("ABC", 2, nil)], for: \.testInt, \.testNonExtended)
        
        result = str
        result.characters.insert(contentsOf: "ABC", at: result.index(result.startIndex, offsetByCharacters: 3))
        verify(string: result, matches: [("Hel", 2, 1), ("ABC", 2, nil), ("lo, world", 2, 1)], for: \.testInt, \.testNonExtended)
        
        result = str
        result.characters.insert(contentsOf: "ABC", at: result.startIndex)
        verify(string: result, matches: [("ABC", 2, nil), ("Hello, world", 2, 1)], for: \.testInt, \.testNonExtended)
        
        result = str
        var subrange = result.index(result.startIndex, offsetByCharacters: 2) ..< result.index(result.startIndex, offsetByCharacters: 9)
        result.characters.replaceSubrange(subrange, with: "ABC")
        verify(string: result, matches: [("He", 2, 1), ("ABC", 2, nil), ("rld", 2, 1)], for: \.testInt, \.testNonExtended)
        
        result = str
        subrange = result.index(result.startIndex, offsetByCharacters: 2) ..< result.index(result.startIndex, offsetByCharacters: 9)
        let other = AttributedString("Hi!")
        result.characters[subrange] = other.characters[other.startIndex ..< other.endIndex]
        verify(string: result, matches: [("He", 2, 1), ("Hi!", 2, nil), ("rld", 2, 1)], for: \.testInt, \.testNonExtended)
    }
    
    func testExtendingRunAddUnicodeScalars() {
        let str = AttributedString("Hello, world", attributes: .init().testInt(2).testNonExtended(1))
        let scalarsStr = "A\u{0301}B"
        
        var result = str
        result.unicodeScalars.append(contentsOf: scalarsStr.unicodeScalars)
        verify(string: result, matches: [("Hello, world", 2, 1), (scalarsStr, 2, nil)], for: \.testInt, \.testNonExtended)
        
        result = str
        result.unicodeScalars.insert(contentsOf: scalarsStr.unicodeScalars, at: result.index(result.startIndex, offsetByUnicodeScalars: 3))
        verify(string: result, matches: [("Hel", 2, 1), (scalarsStr, 2, nil), ("lo, world", 2, 1)], for: \.testInt, \.testNonExtended)
        
        result = str
        result.unicodeScalars.insert(contentsOf: scalarsStr.unicodeScalars, at: result.startIndex)
        verify(string: result, matches: [(scalarsStr, 2, nil), ("Hello, world", 2, 1)], for: \.testInt, \.testNonExtended)
        
        result = str
        let subrange = result.index(result.startIndex, offsetByUnicodeScalars: 2) ..< result.index(result.startIndex, offsetByUnicodeScalars: 9)
        result.unicodeScalars.replaceSubrange(subrange, with: scalarsStr.unicodeScalars)
        verify(string: result, matches: [("He", 2, 1), (scalarsStr, 2, nil), ("rld", 2, 1)], for: \.testInt, \.testNonExtended)
    }
    
    // MARK: - Paragraph Constrained Tests
    
    func testParagraphAttributeExpanding() {
        var str = AttributedString("Hello, world\nNext Paragraph")
        var range = str.index(afterCharacter: str.startIndex) ..< str.index(str.startIndex, offsetByCharacters: 3)
        str[range].testParagraphConstrained = 2
        verify(string: str, matches: [("Hello, world\n", 2), ("Next Paragraph", nil)], for: \.testParagraphConstrained)
        
        range = str.index(beforeCharacter: str.endIndex) ..< str.endIndex
        str[range].testParagraphConstrained = 3
        verify(string: str, matches: [("Hello, world\n", 2), ("Next Paragraph", 3)], for: \.testParagraphConstrained)
        
        str.testInt = 1
        verify(string: str, matches: [("Hello, world\n", 2, 1), ("Next Paragraph", 3, 1)], for: \.testParagraphConstrained, \.testInt)
        
        str[range].testParagraphConstrained = 4
        verify(string: str, matches: [("Hello, world\n", 2, 1), ("Next Paragraph", 4, 1)], for: \.testParagraphConstrained, \.testInt)
        
        range = str.index(str.startIndex, offsetByCharacters: 8) ..< str.index(str.startIndex, offsetByCharacters: 14)
        str[range].testParagraphConstrained = 4
        verify(string: str, matches: [("Hello, world\n", 4), ("Next Paragraph", 4)], for: \.testParagraphConstrained)
    }
    
    func testParagraphAttributeRemoval() {
        var str = AttributedString("Hello, world\nNext Paragraph", attributes: .init().testParagraphConstrained(2))
        var range = str.index(afterCharacter: str.startIndex) ..< str.index(str.startIndex, offsetByCharacters: 3)
        str[range].testParagraphConstrained = nil
        verify(string: str, matches: [("Hello, world\n", nil), ("Next Paragraph", 2)], for: \.testParagraphConstrained)
        
        str.testInt = 1
        verify(string: str, matches: [("Hello, world\n", nil, 1), ("Next Paragraph", 2, 1)], for: \.testParagraphConstrained, \.testInt)
        
        range = str.index(beforeCharacter: str.endIndex) ..< str.endIndex
        str[range].testParagraphConstrained = nil
        verify(string: str, matches: [("Hello, world\n", nil, 1), ("Next Paragraph", nil, 1)], for: \.testParagraphConstrained, \.testInt)
        
        str = AttributedString("Hello, world\nNext Paragraph", attributes: .init().testParagraphConstrained(2))
        range = str.index(str.startIndex, offsetByCharacters: 8) ..< str.index(str.startIndex, offsetByCharacters: 14)
        str[range].testParagraphConstrained = nil
        verify(string: str, matches: [("Hello, world\n", nil), ("Next Paragraph", nil)], for: \.testParagraphConstrained)
    }
    
    func testParagraphAttributeContainerApplying() {
        var container = AttributeContainer.testParagraphConstrained(2).testString("Hello")
        var str = AttributedString("Hello, world\nNext Paragraph")
        var range = str.index(afterCharacter: str.startIndex) ..< str.index(str.startIndex, offsetByCharacters: 3)
        str[range].setAttributes(container)
        verify(string: str, matches: [("H", 2, nil), ("el", 2, "Hello"), ("lo, world\n", 2, nil), ("Next Paragraph", nil, nil)], for: \.testParagraphConstrained, \.testString)
        
        range = str.index(beforeCharacter: str.endIndex) ..< str.endIndex
        container.testParagraphConstrained = 3
        str[range].setAttributes(container)
        verify(string: str, matches: [("H", 2, nil), ("el", 2, "Hello"), ("lo, world\n", 2, nil), ("Next Paragrap", 3, nil), ("h", 3, "Hello")], for: \.testParagraphConstrained, \.testString)

        str.testInt = 1
        verify(string: str, matches: [("H", 2, nil, 1), ("el", 2, "Hello", 1), ("lo, world\n", 2, nil, 1), ("Next Paragrap", 3, nil, 1), ("h", 3, "Hello", 1)], for: \.testParagraphConstrained, \.testString, \.testInt)

        container.testInt = 2
        container.testParagraphConstrained = 4
        container.testString = nil
        str[range].mergeAttributes(container, mergePolicy: .keepCurrent)
        verify(string: str, matches: [("H", 2, nil, 1), ("el", 2, "Hello", 1), ("lo, world\n", 2, nil, 1), ("Next Paragrap", 3, nil, 1), ("h", 3, "Hello", 1)], for: \.testParagraphConstrained, \.testString, \.testInt)
        str[range].mergeAttributes(container, mergePolicy: .keepNew)
        verify(string: str, matches: [("H", 2, nil, 1), ("el", 2, "Hello", 1), ("lo, world\n", 2, nil, 1), ("Next Paragrap", 4, nil, 1), ("h", 4, "Hello", 2)], for: \.testParagraphConstrained, \.testString, \.testInt)
        
        range = str.index(str.startIndex, offsetByCharacters: 8) ..< str.index(str.startIndex, offsetByCharacters: 14)
        str[range].mergeAttributes(container, mergePolicy: .keepNew)
        verify(string: str, matches: [("H", 4, nil, 1), ("el", 4, "Hello", 1), ("lo, w", 4, nil, 1), ("orld\n", 4, nil, 2), ("N", 4, nil, 2), ("ext Paragrap", 4, nil, 1), ("h", 4, "Hello", 2)], for: \.testParagraphConstrained, \.testString, \.testInt)
    }
    
    func testParagraphAttributeContainerReplacing() {
        var str = AttributedString("Hello, world\nNext Paragraph")
        let range = str.index(afterCharacter: str.startIndex) ..< str.index(str.startIndex, offsetByCharacters: 3)
        str[range].testInt = 2
        
        var result = str.transformingAttributes(\.testInt) {
            if $0.value == 2 {
                $0.replace(with: \.testParagraphConstrained, value: 3)
            }
        }
        verify(string: result, matches: [("Hello, world\n", 3, nil), ("Next Paragraph", nil, nil)], for: \.testParagraphConstrained, \.testInt)
        
        result = str.replacingAttributes(.init().testInt(2), with: .init().testParagraphConstrained(3).testBool(true))
        verify(string: result, matches: [("H", 3, nil, nil), ("el", 3, nil, true), ("lo, world\n", 3, nil, nil), ("Next Paragraph", nil, nil, nil)], for: \.testParagraphConstrained, \.testInt, \.testBool)
        
        str.testInt = 2
        result = str
        result[range].replaceAttributes(.init().testInt(2), with: .init().testParagraphConstrained(3).testBool(true))
        verify(string: result, matches: [("H", 3, 2, nil), ("el", 3, nil, true), ("lo, world\n", 3, 2, nil), ("Next Paragraph", nil, 2, nil)], for: \.testParagraphConstrained, \.testInt, \.testBool)
    }
    
    func testParagraphTextMutation() {
        let str = AttributedString("Hello, world\n", attributes: .init().testParagraphConstrained(1)) + AttributedString("Next Paragraph", attributes: .init().testParagraphConstrained(2))
        
        var result = str
        result.characters.insert(contentsOf: "Test", at: result.index(result.startIndex, offsetByCharacters: 2))
        verify(string: result, matches: [("HeTestllo, world\n", 1), ("Next Paragraph", 2)], for: \.testParagraphConstrained)
        
        result = str
        result.characters.append(contentsOf: "Test")
        verify(string: result, matches: [("Hello, world\n", 1), ("Next ParagraphTest", 2)], for: \.testParagraphConstrained)
        
        result = str
        result.characters.insert(contentsOf: "Test", at: result.startIndex)
        verify(string: result, matches: [("TestHello, world\n", 1), ("Next Paragraph", 2)], for: \.testParagraphConstrained)
        
        result = str
        result.characters.insert(contentsOf: "Test\nInserted ", at: result.index(result.startIndex, offsetByCharacters: 2))
        verify(string: result, matches: [("HeTest\n", 1), ("Inserted llo, world\n", 1), ("Next Paragraph", 2)], for: \.testParagraphConstrained)
        
        result = str
        result.characters.removeSubrange(result.index(result.startIndex, offsetByCharacters: 8) ..< result.index(result.startIndex, offsetByCharacters: 14))
        verify(string: result, matches: [("Hello, wext Paragraph", 1)], for: \.testParagraphConstrained)
        
        result = str
        result.characters.removeSubrange(result.index(result.startIndex, offsetByCharacters: 14) ..< result.endIndex)
        verify(string: result, matches: [("Hello, world\n", 1), ("N", 2)], for: \.testParagraphConstrained)
        
        result = str
        result.characters.removeSubrange(result.startIndex ..< result.index(result.startIndex, offsetByCharacters: 8))
        verify(string: result, matches: [("orld\n", 1), ("Next Paragraph", 2)], for: \.testParagraphConstrained)
        
        result = str
        result.characters.replaceSubrange(result.index(result.startIndex, offsetByCharacters: 3) ..< result.index(result.startIndex, offsetByCharacters: 5), with: "Test")
        verify(string: result, matches: [("HelTest, world\n", 1), ("Next Paragraph", 2)], for: \.testParagraphConstrained)
        
        result = str
        result.characters.replaceSubrange(result.index(result.startIndex, offsetByCharacters: 8) ..< result.index(result.startIndex, offsetByCharacters: 15), with: "Test")
        verify(string: result, matches: [("Hello, wTestxt Paragraph", 1)], for: \.testParagraphConstrained)
        
        result = str
        result.characters.replaceSubrange(result.index(result.startIndex, offsetByCharacters: 8) ..< result.index(result.startIndex, offsetByCharacters: 15), with: "Test\nReplacement")
        verify(string: result, matches: [("Hello, wTest\n", 1), ("Replacementxt Paragraph", 1)], for: \.testParagraphConstrained)
    }
    
    func testParagraphAttributedTextMutation() {
        let str = AttributedString("Hello, world\n", attributes: .init().testParagraphConstrained(1)) + AttributedString("Next Paragraph", attributes: .init().testParagraphConstrained(2))
        let singleReplacement = AttributedString("Test", attributes: .init().testParagraphConstrained(5).testSecondParagraphConstrained(6).testBool(true))
        let multiReplacement = AttributedString("Test\nInserted", attributes: .init().testParagraphConstrained(5).testSecondParagraphConstrained(6).testBool(true))
        
        var result = str
        result.insert(singleReplacement, at: result.index(result.startIndex, offsetByCharacters: 2))
        verify(string: result, matches: [("He", 1, nil, nil), ("Test", 1, nil, true), ("llo, world\n", 1, nil, nil), ("Next Paragraph", 2, nil, nil)], for: \.testParagraphConstrained, \.testSecondParagraphConstrained, \.testBool)
        
        result = str
        result.insert(multiReplacement, at: result.index(result.startIndex, offsetByCharacters: 2))
        verify(string: result, matches: [("He", 1, nil, nil), ("Test\n", 1, nil, true), ("Inserted", 5, 6, true), ("llo, world\n", 5, 6, nil), ("Next Paragraph", 2, nil, nil)], for: \.testParagraphConstrained, \.testSecondParagraphConstrained, \.testBool)
        
        result = str
        result.append(singleReplacement)
        verify(string: result, matches: [("Hello, world\n", 1, nil, nil), ("Next Paragraph", 2, nil, nil), ("Test", 2, nil, true)], for: \.testParagraphConstrained, \.testSecondParagraphConstrained, \.testBool)
        
        result = str
        result.append(multiReplacement)
        verify(string: result, matches: [("Hello, world\n", 1, nil, nil), ("Next Paragraph", 2, nil, nil), ("Test\n", 2, nil, true), ("Inserted", 5, 6, true)], for: \.testParagraphConstrained, \.testSecondParagraphConstrained, \.testBool)
        
        result = str
        result.insert(singleReplacement, at: result.startIndex)
        verify(string: result, matches: [("Test", 5, 6, true), ("Hello, world\n", 5, 6, nil), ("Next Paragraph", 2, nil, nil)], for: \.testParagraphConstrained, \.testSecondParagraphConstrained, \.testBool)
    
        result = str
        result.insert(multiReplacement, at: result.startIndex)
        verify(string: result, matches: [("Test\n", 5, 6, true), ("Inserted", 5, 6, true), ("Hello, world\n", 5, 6, nil), ("Next Paragraph", 2, nil, nil)], for: \.testParagraphConstrained, \.testSecondParagraphConstrained, \.testBool)
        
        result = str
        result.replaceSubrange(result.index(result.startIndex, offsetByCharacters: 3) ..< result.index(result.startIndex, offsetByCharacters: 5), with: singleReplacement)
        verify(string: result, matches: [("Hel", 1, nil, nil), ("Test", 1, nil, true), (", world\n", 1, nil, nil), ("Next Paragraph", 2, nil, nil)], for: \.testParagraphConstrained, \.testSecondParagraphConstrained, \.testBool)
        
        result = str
        result.replaceSubrange(result.index(result.startIndex, offsetByCharacters: 3) ..< result.index(result.startIndex, offsetByCharacters: 5), with: AttributedString("Test", attributes: .init().testBool(true)))
        verify(string: result, matches: [("Hel", 1, nil, nil), ("Test", 1, nil, true), (", world\n", 1, nil, nil), ("Next Paragraph", 2, nil, nil)], for: \.testParagraphConstrained, \.testSecondParagraphConstrained, \.testBool)
    
        result = str
        result.replaceSubrange(result.index(result.startIndex, offsetByCharacters: 3) ..< result.index(result.startIndex, offsetByCharacters: 5), with: multiReplacement)
        verify(string: result, matches: [("Hel", 1, nil, nil), ("Test\n", 1, nil, true), ("Inserted", 5, 6, true), (", world\n", 5, 6, nil), ("Next Paragraph", 2, nil, nil)], for: \.testParagraphConstrained, \.testSecondParagraphConstrained, \.testBool)
        
        result = str
        result.replaceSubrange(result.index(result.startIndex, offsetByCharacters: 8) ..< result.index(result.startIndex, offsetByCharacters: 15), with: singleReplacement)
        verify(string: result, matches: [("Hello, w", 1, nil, nil), ("Test", 1, nil, true), ("xt Paragraph", 1, nil, nil)], for: \.testParagraphConstrained, \.testSecondParagraphConstrained, \.testBool)
    
        result = str
        result.replaceSubrange(result.index(result.startIndex, offsetByCharacters: 8) ..< result.index(result.startIndex, offsetByCharacters: 15), with: multiReplacement)
        verify(string: result, matches: [("Hello, w", 1, nil, nil), ("Test\n", 1, nil, true), ("Inserted", 5, 6, true), ("xt Paragraph", 5, 6, nil)], for: \.testParagraphConstrained, \.testSecondParagraphConstrained, \.testBool)
    }
    
#if FOUNDATION_FRAMEWORK
    func testParagraphFromUntrustedRuns() throws {
        let str = NSMutableAttributedString(string: "Hello ", attributes: [.testParagraphConstrained : NSNumber(2)])
        str.append(NSAttributedString(string: "World", attributes: [.testParagraphConstrained : NSNumber(3), .testSecondParagraphConstrained : NSNumber(4)]))
        
        let attrStr = try AttributedString(str, including: \.test)
        verify(string: attrStr, matches: [("Hello World", 2, nil)], for: \.testParagraphConstrained, \.testSecondParagraphConstrained)
    }
#endif // FOUNDATION_FRAMEWORK
    
    func testParagraphFromReplacedSubrange() {
        let str = AttributedString("Before\nHello, world\nNext Paragraph\nAfter", attributes: .init().testParagraphConstrained(1))
        
        // Range of "world\nNext"
        let range = str.index(str.startIndex, offsetByCharacters: 14) ..< str.index(str.startIndex, offsetByCharacters: 24)
        
        var copy = str
        copy[range].testParagraphConstrained = 2
        verify(string: copy, matches: [("Before\n", 1), ("Hello, world\n", 2), ("Next Paragraph\n", 2), ("After", 1)], for: \.testParagraphConstrained)
        
        copy = str
        var substr = copy[range]
        substr.testParagraphConstrained = 2
        copy[range] = substr
        verify(string: copy, matches: [("Before\n", 1), ("Hello, world\n", 2), ("Next Paragraph\n", 2), ("After", 1)], for: \.testParagraphConstrained)
        
        copy = str
        copy.replaceSubrange(range, with: AttributedString("not world\nNext", attributes: .init().testParagraphConstrained(2)))
        verify(string: copy, matches: [("Before\n", 1), ("Hello, not world\n", 1), ("Next Paragraph\n", 2), ("After", 1)], for: \.testParagraphConstrained)
        
    }
    
    // MARK: - Character Constrained Tests
    
    func testCharacterAttributeApply() {
        let str = AttributedString("*__*__**__*")
        
        var result = str
        result.testCharacterConstrained = 2
        verify(string: result, matches: [("*", 2), ("__", nil), ("*", 2), ("__", nil), ("*", 2), ("*", 2), ("__", nil), ("*", 2)], for: \.testCharacterConstrained)
        
        result[result.index(result.endIndex, offsetByCharacters: -2) ..< result.endIndex].testCharacterConstrained = nil
        verify(string: result, matches: [("*", 2), ("__", nil), ("*", 2), ("__", nil), ("*", 2), ("*", 2), ("__", nil), ("*", nil)], for: \.testCharacterConstrained)
        
        result = str
        result[result.index(result.endIndex, offsetByCharacters: -2) ..< result.endIndex].testCharacterConstrained = 3
        verify(string: result, matches: [("*", nil), ("__", nil), ("*", nil), ("__", nil), ("*", nil), ("*", nil), ("__", nil), ("*", 3)], for: \.testCharacterConstrained)
        
        result.testInt = 1
        verify(string: result, matches: [("*", nil, 1), ("__", nil, 1), ("*", nil, 1), ("__", nil, 1), ("*", nil, 1), ("*", nil, 1), ("__", nil, 1), ("*", 3, 1)], for: \.testCharacterConstrained, \.testInt)
    }
    
    func testCharacterAttributeSubCharacterApply() {
        let str = AttributedString("ABC \u{FFFD} DEF")

        var result = str
        result.testUnicodeScalarConstrained = 2
        verify(string: result, matches: [("ABC ", nil), ("\u{FFFD}", 2), (" DEF", nil)], for: \.testUnicodeScalarConstrained)

        result = str
        result[result.startIndex ..< result.unicodeScalars.index(result.startIndex, offsetBy: 5)].testUnicodeScalarConstrained = 2
        verify(string: result, matches: [("ABC ", nil), ("\u{FFFD}", 2), (" DEF", nil)], for: \.testUnicodeScalarConstrained)

        result = str
        result[result.startIndex ..< result.unicodeScalars.index(result.startIndex, offsetBy: 4)].testUnicodeScalarConstrained = 2
        verify(string: result, matches: [("ABC ", nil), ("\u{FFFD}", nil), (" DEF", nil)], for: \.testUnicodeScalarConstrained)

        result = str
        result.testUnicodeScalarConstrained = 2
        result[result.unicodeScalars.index(result.startIndex, offsetBy: 5) ..< result.endIndex].testUnicodeScalarConstrained = nil
        verify(string: result, matches: [("ABC ", nil), ("\u{FFFD}", 2), (" DEF", nil)], for: \.testUnicodeScalarConstrained)

        result = str
        result.testUnicodeScalarConstrained = 2
        result[result.unicodeScalars.index(result.startIndex, offsetBy: 4) ..< result.endIndex].testUnicodeScalarConstrained = nil
        verify(string: result, matches: [("ABC ", nil), ("\u{FFFD}", nil), (" DEF", nil)], for: \.testUnicodeScalarConstrained)

        let str2 = AttributedString("ABC \u{FFFD}\u{301} DEF") // U+FFFD Replacement Character, U+301 Combining Acute Accent
        result = str2
        result.testUnicodeScalarConstrained = 2
        verify(string: result, matches: [("ABC ", nil), ("\u{FFFD}", 2), ("\u{301} DEF", nil)], for: \.testUnicodeScalarConstrained)

    }

    func testCharacterAttributeContainerReplacing() {
        var str = AttributedString("*__*__**__*")
        let range = str.index(afterCharacter: str.startIndex) ..< str.index(str.startIndex, offsetByCharacters: 4)
        str[range].testInt = 2
        
        var result = str.transformingAttributes(\.testInt) {
            if $0.value == 2 {
                $0.replace(with: \.testCharacterConstrained, value: 3)
            }
        }
        verify(string: result, matches: [("*", nil, nil), ("__", nil, nil), ("*", 3, nil), ("__", nil, nil), ("*", nil, nil), ("*", nil, nil), ("__", nil, nil), ("*", nil, nil)], for: \.testCharacterConstrained, \.testInt)
        
        result = str.replacingAttributes(.init().testInt(2), with: .init().testCharacterConstrained(3).testBool(true))
        verify(string: result, matches: [("*", nil, nil, nil), ("__", nil, nil, true), ("*", 3, nil, true), ("__", nil, nil, nil), ("*", nil, nil, nil), ("*", nil, nil, nil), ("__", nil, nil, nil), ("*", nil, nil, nil)], for: \.testCharacterConstrained, \.testInt, \.testBool)
        
        str.testInt = 2
        result = str
        result[range].replaceAttributes(.init().testInt(2), with: .init().testCharacterConstrained(3).testBool(true))
        verify(string: result, matches: [("*", nil, 2, nil), ("__", nil, nil, true), ("*", 3, nil, true), ("__", nil, 2, nil), ("*", nil, 2, nil), ("*", nil, 2, nil), ("__", nil, 2, nil), ("*", nil, 2, nil)], for: \.testCharacterConstrained, \.testInt, \.testBool)
    }
    
    func testCharacterTextMutation() {
        let str = AttributedString("*__*__**__*", attributes: .init().testCharacterConstrained(2))
        
        var result = str
        result.characters.insert(contentsOf: "_", at: result.index(result.startIndex, offsetByCharacters: 1))
        verify(string: result, matches: [("*", 2), ("___", nil), ("*", 2), ("__", nil), ("*", 2), ("*", 2), ("__", nil), ("*", 2)], for: \.testCharacterConstrained)
        
        result = str
        result.characters.insert(contentsOf: "*", at: result.index(result.startIndex, offsetByCharacters: 1))
        verify(string: result, matches: [("*", 2), ("*", 2), ("__", nil), ("*", 2), ("__", nil), ("*", 2), ("*", 2), ("__", nil), ("*", 2)], for: \.testCharacterConstrained)

        result = str
        result.characters.append(contentsOf: "_")
        verify(string: result, matches: [("*", 2), ("__", nil), ("*", 2), ("__", nil), ("*", 2), ("*", 2), ("__", nil), ("*", 2), ("_", nil)], for: \.testCharacterConstrained)

        result = str
        result.characters.insert(contentsOf: "_", at: result.startIndex)
        verify(string: result, matches: [("_", nil), ("*", 2), ("__", nil), ("*", 2), ("__", nil), ("*", 2), ("*", 2), ("__", nil), ("*", 2)], for: \.testCharacterConstrained)

        result = str
        result.characters.replaceSubrange(result.index(result.startIndex, offsetByCharacters: 3) ..< result.index(result.startIndex, offsetByCharacters: 5), with: "Test")
        verify(string: result, matches: [("*", 2), ("__Test_", nil), ("*", 2), ("*", 2), ("__", nil), ("*", 2)], for: \.testCharacterConstrained)

        result = str
        result.characters[result.index(result.startIndex, offsetByCharacters: 3)] = "_"
        verify(string: result, matches: [("*", 2), ("_____", nil), ("*", 2), ("*", 2), ("__", nil), ("*", 2)], for: \.testCharacterConstrained)
    }
    
#if FOUNDATION_FRAMEWORK
    func testCharacterFromUntrustedRuns() throws {
        let str = NSMutableAttributedString(string: "*__*__**__*", attributes: [.testCharacterConstrained : NSNumber(2)])
        str.append(NSAttributedString(string: "_*"))
        
        let attrStr = try AttributedString(str, including: \.test)
        verify(string: attrStr, matches: [("*", 2), ("__", nil), ("*", 2), ("__", nil), ("*", 2), ("*", 2), ("__", nil), ("*", 2), ("_", nil), ("*", nil)], for: \.testCharacterConstrained)
    }
#endif // FOUNDATION_FRAMEWORK
    
    // MARK: Invalidation Tests
    
    func testInvalidationAttributeChange() {
        let str = AttributedString("Hello, world", attributes: .init().testInt(1).testAttributeDependent(2))
        
        var result = str
        result.testString = "Foundation"
        verify(string: result, matches: [("Hello, world", 1, 2, "Foundation")], for: \.testInt, \.testAttributeDependent, \.testString)
        
        result = str
        result.testInt = 1
        verify(string: result, matches: [("Hello, world", 1, 2)], for: \.testInt, \.testAttributeDependent)
        
        result = str
        result.testInt = 2
        verify(string: result, matches: [("Hello, world", 2, nil)], for: \.testInt, \.testAttributeDependent)
        
        result = str
        let range = str.index(afterCharacter: str.startIndex) ..< str.index(beforeCharacter: str.endIndex)
        result[range].testInt = 2
        verify(string: result, matches: [("H", 1, 2), ("ello, worl", 2, nil), ("d", 1, 2)], for: \.testInt, \.testAttributeDependent)
        
        result = str
        result[range].mergeAttributes(.init().testInt(2))
        verify(string: result, matches: [("H", 1, 2), ("ello, worl", 2, nil), ("d", 1, 2)], for: \.testInt, \.testAttributeDependent)
        
        result = str
        result[range].replaceAttributes(.init().testInt(1), with: .init().testString("Foundation"))
        verify(string: result, matches: [("H", 1, 2, nil), ("ello, worl", nil, nil, "Foundation"), ("d", 1, 2, nil)], for: \.testInt, \.testAttributeDependent, \.testString)
        
        result = str.transformingAttributes(\.testInt) {
            $0.value = ($0.value ?? 0) + 1
        }
        verify(string: result, matches: [("Hello, world", 2, nil)], for: \.testInt, \.testAttributeDependent)
    }
    
    func testInvalidationCharacterChange() {
        let str = AttributedString("Hello, world", attributes: .init().testInt(1).testCharacterDependent(2))
        
        var result = str
        result.testString = "Foundation"
        verify(string: result, matches: [("Hello, world", 1, 2, "Foundation")], for: \.testInt, \.testCharacterDependent, \.testString)
        
        result = str
        result.characters.replaceSubrange(result.startIndex ..< result.endIndex, with: "ABC")
        verify(string: result, matches: [("ABC", 1, nil)], for: \.testInt, \.testCharacterDependent)
        
        result = str
        result.characters.replaceSubrange(result.startIndex ..< result.index(afterCharacter: result.startIndex), with: "AB")
        verify(string: result, matches: [("ABello, world", 1, nil)], for: \.testInt, \.testCharacterDependent)
        
        result = str
        result.characters.append(contentsOf: "ABC")
        verify(string: result, matches: [("Hello, world", 1, 2), ("ABC", 1, nil)], for: \.testInt, \.testCharacterDependent)
        
        result = str
        result.characters.removeSubrange(result.index(afterCharacter: result.startIndex) ..< result.index(beforeCharacter: result.endIndex))
        verify(string: result, matches: [("Hd", 1, nil)], for: \.testInt, \.testCharacterDependent)

        // Replacing a character with an independent instance of the same character should still
        // count as changing the character data, so it needs to invalidate character-dependent
        // attributes.
        result = str
        result.characters[result.startIndex] = "H"
        verify(string: result, matches: [("Hello, world", 1, nil)], for: \.testInt, \.testCharacterDependent)

        do {
            // The same is true when assigning a sub-view back to itself. Even though this doesn't
            // touch text data at all, and we can quickly determine that we're in this case, we still
            // want the operation to treat this as an edit. (Unlike the similar operation on
            // `AttributedString` itself.)
            result = str
            let range = result.startIndex ..< result.index(afterCharacter: result.startIndex)
            result.characters[range] = result.characters[range]
            verify(string: result, matches: [("Hello, world", 1, nil)], for: \.testInt, \.testCharacterDependent)
        }

        result = str
        result.unicodeScalars.replaceSubrange(result.startIndex ..< result.endIndex, with: ["A", "🎺", "C"])
        verify(string: result, matches: [("A🎺C", 1, nil)], for: \.testInt, \.testCharacterDependent)
        
        result = str
        result.unicodeScalars.replaceSubrange(result.startIndex ..< result.index(afterCharacter: result.startIndex), with: ["A", "🎺"])
        verify(string: result, matches: [("A🎺ello, world", 1, nil)], for: \.testInt, \.testCharacterDependent)
        
        result = str
        result.unicodeScalars.append(contentsOf: ["A", "🎺", "C"])
        verify(string: result, matches: [("Hello, world", 1, 2), ("A🎺C", 1, nil)], for: \.testInt, \.testCharacterDependent)
        
        result = str
        result.unicodeScalars.removeSubrange(result.index(afterUnicodeScalar: result.startIndex) ..< result.index(beforeUnicodeScalar: result.endIndex))
        verify(string: result, matches: [("Hd", 1, nil)], for: \.testInt, \.testCharacterDependent)
        
        var replacement = AttributedString("ABC", attributes: .init().testString("Hello"))
        result = str
        result.replaceSubrange(result.startIndex ..< result.endIndex, with: replacement)
        verify(string: result, matches: [("ABC", nil, nil, "Hello")], for: \.testInt, \.testCharacterDependent, \.testString)
        
        result = str
        result.replaceSubrange(result.startIndex ..< result.index(afterCharacter: result.startIndex), with: replacement)
        verify(string: result, matches: [("ABC", nil, nil, "Hello"), ("ello, world", 1, nil, nil)], for: \.testInt, \.testCharacterDependent, \.testString)
        
        result = str
        result.append(replacement)
        verify(string: result, matches: [("Hello, world", 1, 2, nil), ("ABC", nil, nil, "Hello")], for: \.testInt, \.testCharacterDependent, \.testString)

        // Replacing a substring with a different substring of the same contents
        // still counts as a text change, so it should invalidate character-dependent attributes.
        result = str
        replacement = AttributedString("HBC", attributes: .init().testString("Hello"))
        result[result.startIndex ..< result.index(afterCharacter: result.startIndex)] = replacement[replacement.startIndex ..< replacement.index(afterCharacter: str.startIndex)]
        verify(string: result, matches: [("H", nil, nil, "Hello"), ("ello, world", 1, nil, nil)], for: \.testInt, \.testCharacterDependent, \.testString)
    }

}
