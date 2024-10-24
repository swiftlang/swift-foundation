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

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

#if FOUNDATION_FRAMEWORK
@testable @_spi(AttributedString) import Foundation
// For testing default attribute scope conversion
#if canImport(Accessibility)
import Accessibility
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
#endif // FOUNDATION_FRAMEWORK

/// Regression and coverage tests for `AttributedString` and its associated objects
final class TestAttributedString: XCTestCase {
    // MARK: - Enumeration Tests

    func testEmptyEnumeration() {
        for _ in AttributedString().runs {
            XCTFail("Empty AttributedString should not enumerate any attributes")
        }
        
        do {
            let str = AttributedString("Foo")
            for _ in str[str.startIndex ..< str.startIndex].runs {
                XCTFail("Empty AttributedSubstring should not enumerate any attributes")
            }
        }
        
        do {
            let str = AttributedString("Foo", attributes: AttributeContainer.testInt(2))
            let i = str.index(afterCharacter: str.startIndex)
            for _ in str[i ..< i].runs {
                XCTFail("Empty AttributedSubstring should not enumerate any attributes")
            }
        }
    }

    func verifyAttributes<T>(_ runs: AttributedString.Runs.AttributesSlice1<T>, string: AttributedString, expectation: [(String, T.Value?)]) where T.Value : Sendable {
        // Test that the attribute is correct when iterating through attribute runs
        var expectIterator = expectation.makeIterator()
        for (attribute, range) in runs {
            let expected = expectIterator.next()!
            XCTAssertEqual(String(string[range].characters), expected.0, "Substring of AttributedString characters for range of run did not match expectation")
            XCTAssertEqual(attribute, expected.1, "Attribute of run did not match expectation")
        }
        XCTAssertNil(expectIterator.next(), "Additional runs expected but not found")

        // Test that the attribute is correct when iterating through reversed attribute runs
        expectIterator = expectation.reversed().makeIterator()
        for (attribute, range) in runs.reversed() {
            let expected = expectIterator.next()!
            XCTAssertEqual(String(string[range].characters), expected.0, "Substring of AttributedString characters for range of run did not match expectation")
            XCTAssertEqual(attribute, expected.1, "Attribute of run did not match expectation")
        }
        XCTAssertNil(expectIterator.next(), "Additional runs expected but not found")
    }

    func verifyAttributes<T, U>(_ runs: AttributedString.Runs.AttributesSlice2<T, U>, string: AttributedString, expectation: [(String, T.Value?, U.Value?)]) where T.Value : Sendable, U.Value : Sendable {
        // Test that the attributes are correct when iterating through attribute runs
        var expectIterator = expectation.makeIterator()
        for (attribute, attribute2, range) in runs {
            let expected = expectIterator.next()!
            XCTAssertEqual(String(string[range].characters), expected.0, "Substring of AttributedString characters for range of run did not match expectation")
            XCTAssertEqual(attribute, expected.1, "Attribute of run did not match expectation")
            XCTAssertEqual(attribute2, expected.2, "Attribute of run did not match expectation")
        }
        XCTAssertNil(expectIterator.next(), "Additional runs expected but not found")

        // Test that the attributes are correct when iterating through reversed attribute runs
        expectIterator = expectation.reversed().makeIterator()
        for (attribute, attribute2, range) in runs.reversed() {
            let expected = expectIterator.next()!
            XCTAssertEqual(String(string[range].characters), expected.0, "Substring of AttributedString characters for range of run did not match expectation")
            XCTAssertEqual(attribute, expected.1, "Attribute of run did not match expectation")
            XCTAssertEqual(attribute2, expected.2, "Attribute of run did not match expectation")
        }
        XCTAssertNil(expectIterator.next(), "Additional runs expected but not found")
    }
    
#if FOUNDATION_FRAMEWORK
    func verifyAttributes(_ runs: AttributedString.Runs.NSAttributesSlice, string: AttributedString, expectation: [(String, AttributeContainer)], file: StaticString = #filePath, line: UInt = #line) {
        // Test that the attribute is correct when iterating through attribute runs
        var expectIterator = expectation.makeIterator()
        for (attribute, range) in runs {
            let expected = expectIterator.next()!
            XCTAssertEqual(String(string[range].characters), expected.0, "Substring of AttributedString characters for range of run did not match expectation", file: file, line: line)
            XCTAssertEqual(attribute, expected.1, "Attribute of run did not match expectation", file: file, line: line)
        }
        XCTAssertNil(expectIterator.next(), "Additional runs expected but not found", file: file, line: line)

        // Test that the attribute is correct when iterating through reversed attribute runs
        expectIterator = expectation.reversed().makeIterator()
        for (attribute, range) in runs.reversed() {
            let expected = expectIterator.next()!
            XCTAssertEqual(String(string[range].characters), expected.0, "Substring of AttributedString characters for range of run did not match expectation", file: file, line: line)
            XCTAssertEqual(attribute, expected.1, "Attribute of run did not match expectation", file: file, line: line)
        }
        XCTAssertNil(expectIterator.next(), "Additional runs expected but not found", file: file, line: line)
    }
#endif // FOUNDATION_FRAMEWORK

    func testSimpleEnumeration() {
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testInt(1))
        attrStr += " "
        attrStr += AttributedString("World", attributes: AttributeContainer().testDouble(2.0))

        let expectation = [("Hello", 1, nil), (" ", nil, nil), ("World", nil, 2.0)]
        var expectationIterator = expectation.makeIterator()
        for run in attrStr.runs {
            let expected = expectationIterator.next()!
            XCTAssertEqual(String(attrStr[run.range].characters), expected.0)
            XCTAssertEqual(run.testInt, expected.1)
            XCTAssertEqual(run.testDouble, expected.2)
            XCTAssertNil(run.testString)
        }
        XCTAssertNil(expectationIterator.next())

        expectationIterator = expectation.reversed().makeIterator()
        for run in attrStr.runs.reversed() {
            let expected = expectationIterator.next()!
            XCTAssertEqual(String(attrStr[run.range].characters), expected.0)
            XCTAssertEqual(run.testInt, expected.1)
            XCTAssertEqual(run.testDouble, expected.2)
            XCTAssertNil(run.testString)
        }
        XCTAssertNil(expectationIterator.next())

        let attrView = attrStr.runs
        verifyAttributes(attrView[\.testInt], string: attrStr, expectation: [("Hello", 1), (" World", nil)])
        verifyAttributes(attrView[\.testDouble], string: attrStr, expectation: [("Hello ", nil), ("World", 2.0)])
        verifyAttributes(attrView[\.testString], string: attrStr, expectation: [("Hello World", nil)])
        verifyAttributes(attrView[\.testInt, \.testDouble], string: attrStr, expectation: [("Hello", 1, nil), (" ", nil, nil), ("World", nil, 2.0)])
    }

    func testSliceEnumeration() {
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testInt(1))
        attrStr += AttributedString(" ")
        attrStr += AttributedString("World", attributes: AttributeContainer().testDouble(2.0))

        let attrStrSlice = attrStr[attrStr.characters.index(attrStr.startIndex, offsetBy: 3) ..< attrStr.characters.index(attrStr.endIndex, offsetBy: -3)]

        let expectation = [("lo", 1, nil), (" ", nil, nil), ("Wo", nil, 2.0)]
        var expectationIterator = expectation.makeIterator()
        for run in attrStrSlice.runs {
            let expected = expectationIterator.next()!
            XCTAssertEqual(String(attrStr[run.range].characters), expected.0)
            XCTAssertEqual(run.testInt, expected.1)
            XCTAssertEqual(run.testDouble, expected.2)
            XCTAssertNil(run.testString)
        }
        XCTAssertNil(expectationIterator.next())

        expectationIterator = expectation.reversed().makeIterator()
        for run in attrStrSlice.runs.reversed() {
            let expected = expectationIterator.next()!
            XCTAssertEqual(String(attrStr[run.range].characters), expected.0)
            XCTAssertEqual(run.testInt, expected.1)
            XCTAssertEqual(run.testDouble, expected.2)
            XCTAssertNil(run.testString)
        }
        XCTAssertNil(expectationIterator.next())

        let attrView = attrStrSlice.runs
        verifyAttributes(attrView[\.testInt], string: attrStr, expectation: [("lo", 1), (" Wo", nil)])
        verifyAttributes(attrView[\.testDouble], string: attrStr, expectation: [("lo ", nil), ("Wo", 2.0)])
        verifyAttributes(attrView[\.testString], string: attrStr, expectation: [("lo Wo", nil)])
        verifyAttributes(attrView[\.testInt, \.testDouble], string: attrStr, expectation: [("lo", 1, nil), (" ", nil, nil), ("Wo", nil, 2.0)])
    }
    
#if FOUNDATION_FRAMEWORK
    func testNSSliceEnumeration() {
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testInt(1))
        attrStr += AttributedString(" ")
        attrStr += AttributedString("World", attributes: AttributeContainer().testDouble(2.0))

        let middleRange = attrStr.characters.index(attrStr.startIndex, offsetBy: 3) ..< attrStr.characters.index(attrStr.endIndex, offsetBy: -3)
        let view = attrStr[middleRange].runs
        verifyAttributes(view[nsAttributedStringKeys: .testInt], string: attrStr, expectation: [("lo", .init().testInt(1)), (" Wo", .init())])
        verifyAttributes(view[nsAttributedStringKeys: .testDouble], string: attrStr, expectation: [("lo ", .init()), ("Wo", .init().testDouble(2.0))])
        verifyAttributes(view[nsAttributedStringKeys: .testString], string: attrStr, expectation: [("lo Wo", .init())])
        verifyAttributes(view[nsAttributedStringKeys: .testInt, .testDouble], string: attrStr, expectation: [("lo", .init().testInt(1)), (" ", .init()), ("Wo", .init().testDouble(2.0))])
        
        attrStr[middleRange].testString = "Test"
        verifyAttributes(attrStr.runs[nsAttributedStringKeys: .testInt], string: attrStr, expectation: [("Hello", .init().testInt(1)), (" World", .init())])
        verifyAttributes(attrStr.runs[nsAttributedStringKeys: .testDouble], string: attrStr, expectation: [("Hello ", .init()), ("World", .init().testDouble(2.0))])
        verifyAttributes(attrStr.runs[nsAttributedStringKeys: .testString], string: attrStr, expectation: [("Hel", .init()), ("lo Wo", .init().testString("Test")), ("rld", .init())])
        verifyAttributes(attrStr.runs[nsAttributedStringKeys: .testInt, .testDouble, .testString], string: attrStr, expectation: [
            ("Hel", .init().testInt(1)),
            ("lo", .init().testInt(1).testString("Test")),
            (" ", .init().testString("Test")),
            ("Wo", .init().testDouble(2.0).testString("Test")),
            ("rld", .init().testDouble(2.0))
        ])
    }
#endif // FOUNDATION_FRAMEWORK

    // MARK: - Attribute Tests

    func testSimpleAttribute() {
        let attrStr = AttributedString("Foo", attributes: AttributeContainer().testInt(42))
        let (value, range) = attrStr.runs[\.testInt][attrStr.startIndex]
        XCTAssertEqual(value, 42)
        XCTAssertEqual(range, attrStr.startIndex ..< attrStr.endIndex)
    }

    func testConstructorAttribute() {
        // TODO: Re-evaluate whether we want these.
        let attrStr = AttributedString("Hello", attributes: AttributeContainer().testString("Helvetica").testInt(2))
        var expected = AttributedString("Hello")
        expected.testString = "Helvetica"
        expected.testInt = 2
        XCTAssertEqual(attrStr, expected)
    }

    func testAddAndRemoveAttribute() {
        let attr : Int = 42
        let attr2 : Double = 1.0
        var attrStr = AttributedString("Test")
        attrStr.testInt = attr
        attrStr.testDouble = attr2

        let expected1 = AttributedString("Test", attributes: AttributeContainer().testInt(attr).testDouble(attr2))
        XCTAssertEqual(attrStr, expected1)

        attrStr.testDouble = nil

        let expected2 = AttributedString("Test", attributes: AttributeContainer().testInt(attr))
        XCTAssertEqual(attrStr, expected2)
    }

    func testAddingAndRemovingAttribute() {
        let container = AttributeContainer().testInt(1).testDouble(2.2)
        let attrStr = AttributedString("Test").mergingAttributes(container)
        let expected = AttributedString("Test", attributes: AttributeContainer().testInt(1).testDouble(2.2))
        XCTAssertEqual(attrStr, expected)
        var doubleRemoved = attrStr
        doubleRemoved.testDouble = nil
        XCTAssertEqual(doubleRemoved, AttributedString("Test", attributes: AttributeContainer().testInt(1)))
    }
    
    func testScopedAttributes() {
        var str = AttributedString("Hello, world", attributes: AttributeContainer().testInt(2).testDouble(3.4))
        XCTAssertEqual(str.test.testInt, 2)
        XCTAssertEqual(str.test.testDouble, 3.4)
        XCTAssertEqual(str.runs[str.runs.startIndex].test.testInt, 2)
        
        str.test.testInt = 4
        XCTAssertEqual(str, AttributedString("Hello, world", attributes: AttributeContainer.testInt(4).testDouble(3.4)))
        
        let range = str.startIndex ..< str.characters.index(after: str.startIndex)
        str[range].test.testBool = true
        XCTAssertNil(str.test.testBool)
        XCTAssertNotNil(str[range].test.testBool)
        XCTAssertTrue(str[range].test.testBool!)
    }

    func testRunAttributes() {
        var str = AttributedString("String", attributes: .init().testString("test1"))
        str += "None"
        str += AttributedString("String+Int", attributes: .init().testString("test2").testInt(42))

        let attributes = str.runs.map { $0.attributes }
        XCTAssertEqual(attributes.count, 3)
        XCTAssertEqual(attributes[0], .init().testString("test1"))
        XCTAssertEqual(attributes[1], .init())
        XCTAssertEqual(attributes[2], .init().testString("test2").testInt(42))
    }

    // MARK: - Comparison Tests

    func testAttributedStringEquality() {
        XCTAssertEqual(AttributedString(), AttributedString())
        XCTAssertEqual(AttributedString("abc"), AttributedString("abc"))
        XCTAssertEqual(AttributedString("abc", attributes: AttributeContainer().testInt(1)), AttributedString("abc", attributes: AttributeContainer().testInt(1)))
        XCTAssertNotEqual(AttributedString("abc", attributes: AttributeContainer().testInt(1)), AttributedString("abc", attributes: AttributeContainer().testInt(2)))
        XCTAssertNotEqual(AttributedString("abc", attributes: AttributeContainer().testInt(1)), AttributedString("def", attributes: AttributeContainer().testInt(1)))

        var a = AttributedString("abc", attributes: AttributeContainer().testInt(1))
        a += AttributedString("def", attributes: AttributeContainer().testInt(1))
        XCTAssertEqual(a, AttributedString("abcdef", attributes: AttributeContainer().testInt(1)))

        a = AttributedString("ab", attributes: AttributeContainer().testInt(1))
        a += AttributedString("cdef", attributes: AttributeContainer().testInt(2))
        var b = AttributedString("abcd", attributes: AttributeContainer().testInt(1))
        b += AttributedString("ef", attributes: AttributeContainer().testInt(2))
        XCTAssertNotEqual(a, b)

        a = AttributedString("abc")
        a += AttributedString("defghi", attributes: AttributeContainer().testInt(2))
        a += "jkl"
        b = AttributedString("abc")
        b += AttributedString("def", attributes: AttributeContainer().testInt(2))
        b += "ghijkl"
        XCTAssertNotEqual(a, b)


        let a1 = AttributedString("Café", attributes: AttributeContainer().testInt(1))
        let a2 = AttributedString("Cafe\u{301}", attributes: AttributeContainer().testInt(1))
        XCTAssertEqual(a1, a2)

        let a3 = (AttributedString("Cafe", attributes: AttributeContainer().testInt(1))
                  + AttributedString("\u{301}", attributes: AttributeContainer().testInt(2)))
        XCTAssertNotEqual(a1, a3)
        XCTAssertNotEqual(a2, a3)
        XCTAssertTrue(a1.characters.elementsEqual(a3.characters))
        XCTAssertTrue(a2.characters.elementsEqual(a3.characters))
    }

    func testAttributedSubstringEquality() {
        let emptyStr = AttributedString("01234567890123456789")

        let index0 = emptyStr.characters.startIndex
        let index5 = emptyStr.characters.index(index0, offsetBy: 5)
        let index10 = emptyStr.characters.index(index0, offsetBy: 10)
        let index20 = emptyStr.characters.index(index0, offsetBy: 20)

        var singleAttrStr = emptyStr
        singleAttrStr[index0 ..< index10].testInt = 1

        var halfhalfStr = emptyStr
        halfhalfStr[index0 ..< index10].testInt = 1
        halfhalfStr[index10 ..< index20].testDouble = 2.0

        XCTAssertEqual(emptyStr[index0 ..< index0], emptyStr[index0 ..< index0])
        XCTAssertEqual(emptyStr[index0 ..< index5], emptyStr[index0 ..< index5])
        XCTAssertEqual(emptyStr[index0 ..< index20], emptyStr[index0 ..< index20])
        XCTAssertEqual(singleAttrStr[index0 ..< index20], singleAttrStr[index0 ..< index20])
        XCTAssertEqual(halfhalfStr[index0 ..< index20], halfhalfStr[index0 ..< index20])

        XCTAssertEqual(emptyStr[index0 ..< index10], singleAttrStr[index10 ..< index20])
        XCTAssertEqual(halfhalfStr[index0 ..< index10], singleAttrStr[index0 ..< index10])

        XCTAssertNotEqual(emptyStr[index0 ..< index10], singleAttrStr[index0 ..< index10])
        XCTAssertNotEqual(emptyStr[index0 ..< index10], singleAttrStr[index0 ..< index20])

        XCTAssertTrue(emptyStr[index0 ..< index5] == AttributedString("01234"))
    }
    
    func testRunEquality() {
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testInt(1))
        attrStr += AttributedString(" ")
        attrStr += AttributedString("World", attributes: AttributeContainer().testInt(2))
        
        var attrStr2 = AttributedString("Hello", attributes: AttributeContainer().testInt(2))
        attrStr2 += AttributedString("_")
        attrStr2 += AttributedString("World", attributes: AttributeContainer().testInt(2))
        attrStr2 += AttributedString("Hello", attributes: AttributeContainer().testInt(1))
        
        var attrStr3 = AttributedString("Hel", attributes: AttributeContainer().testInt(1))
        attrStr3 += AttributedString("lo W")
        attrStr3 += AttributedString("orld", attributes: AttributeContainer().testInt(2))
        
        func run(_ num: Int, in str: AttributedString) -> AttributedString.Runs.Run {
            return str.runs[str.runs.index(str.runs.startIndex, offsetBy: num)]
        }
        
        // Same string, same range, different attributes
        XCTAssertNotEqual(run(0, in: attrStr), run(0, in: attrStr2))
        
        // Different strings, same range, same attributes
        XCTAssertEqual(run(1, in: attrStr), run(1, in: attrStr2))
        
        // Same string, same range, same attributes
        XCTAssertEqual(run(2, in: attrStr), run(2, in: attrStr2))
        
        // Different string, different range, same attributes
        XCTAssertEqual(run(2, in: attrStr), run(0, in: attrStr2))
        
        // Same string, different range, same attributes
        XCTAssertEqual(run(0, in: attrStr), run(3, in: attrStr2))
        
        // A runs collection of the same order but different run lengths
        XCTAssertNotEqual(attrStr.runs, attrStr3.runs)
    }
    
    func testSubstringRunEquality() {
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testInt(1))
        attrStr += AttributedString(" ")
        attrStr += AttributedString("World", attributes: AttributeContainer().testInt(2))
        
        var attrStr2 = AttributedString("Hello", attributes: AttributeContainer().testInt(2))
        attrStr2 += AttributedString("_")
        attrStr2 += AttributedString("World", attributes: AttributeContainer().testInt(2))
        
        XCTAssertEqual(attrStr[attrStr.runs.last!.range].runs, attrStr2[attrStr2.runs.first!.range].runs)
        XCTAssertEqual(attrStr[attrStr.runs.last!.range].runs, attrStr2[attrStr2.runs.last!.range].runs)
        
        let rangeA = attrStr.runs.first!.range.upperBound ..< attrStr.endIndex
        let rangeB = attrStr2.runs.first!.range.upperBound ..< attrStr.endIndex
        let rangeC = attrStr.startIndex ..< attrStr.runs.last!.range.lowerBound
        let rangeD = attrStr.runs.first!.range
        XCTAssertEqual(attrStr[rangeA].runs, attrStr2[rangeB].runs)
        XCTAssertNotEqual(attrStr[rangeC].runs, attrStr2[rangeB].runs)
        XCTAssertNotEqual(attrStr[rangeD].runs, attrStr2[rangeB].runs)
        
        // Test starting/ending runs that only differ outside of the range do not prevent equality
        attrStr2[attrStr.runs.first!.range].testInt = 1
        attrStr2.characters.insert(contentsOf: "123", at: attrStr.startIndex)
        attrStr2.characters.append(contentsOf: "45")
        let rangeE = attrStr.startIndex ..< attrStr.endIndex
        let rangeF = attrStr2.characters.index(attrStr2.startIndex, offsetBy: 3) ..< attrStr2.characters.index(attrStr2.startIndex, offsetBy: 14)
        XCTAssertEqual(attrStr[rangeE].runs, attrStr2[rangeF].runs)
    }

    // MARK: - Mutation Tests

    func testDirectMutationCopyOnWrite() {
        var attrStr = AttributedString("ABC")
        let copy = attrStr
        attrStr += "D"

        XCTAssertEqual(copy, AttributedString("ABC"))
        XCTAssertNotEqual(attrStr, copy)
    }

    func testAttributeMutationCopyOnWrite() {
        var attrStr = AttributedString("ABC")
        let copy = attrStr
        attrStr.testInt = 1

        XCTAssertNotEqual(attrStr, copy)
    }

    func testSliceAttributeMutation() {
        let attr : Int = 42
        let attr2 : Double = 1.0

        var attrStr = AttributedString("Hello World", attributes: AttributeContainer().testInt(attr))
        let copy = attrStr

        let chars = attrStr.characters
        let start = chars.startIndex
        let end = chars.index(start, offsetBy: 5)
        attrStr[start ..< end].testDouble = attr2

        var expected = AttributedString("Hello", attributes: AttributeContainer().testInt(attr).testDouble(attr2))
        expected += AttributedString(" World", attributes: AttributeContainer().testInt(attr))
        XCTAssertEqual(attrStr, expected)

        XCTAssertNotEqual(copy, attrStr)
    }

    func testEnumerationAttributeMutation() {
        var attrStr = AttributedString("A", attributes: AttributeContainer().testInt(1))
        attrStr += AttributedString("B", attributes: AttributeContainer().testDouble(2.0))
        attrStr += AttributedString("C", attributes: AttributeContainer().testInt(3))

        for (attr, range) in attrStr.runs[\.testInt] {
            if let _ = attr {
                attrStr[range].testInt = nil
            }
        }

        var expected = AttributedString("A")
        expected += AttributedString("B", attributes: AttributeContainer().testDouble(2.0))
        expected += "C"
        XCTAssertEqual(expected, attrStr)
    }

    func testMutateMultipleAttributes() {
        var attrStr = AttributedString("A", attributes: AttributeContainer().testInt(1).testBool(true))
        attrStr += AttributedString("B", attributes: AttributeContainer().testInt(1).testDouble(2))
        attrStr += AttributedString("C", attributes: AttributeContainer().testDouble(2).testBool(false))

        // Test removal
        let removal1 = attrStr.transformingAttributes(\.testInt, \.testDouble, \.testBool) {
            $0.value = nil
            $1.value = nil
            $2.value = nil
        }
        let removal1expected = AttributedString("ABC")
        XCTAssertEqual(removal1expected, removal1)

        // Test change value, same attribute.
        let changeSame1 = attrStr.transformingAttributes(\.testInt, \.testDouble, \.testBool) {
            if let _ = $0.value {
                $0.value = 42
            }
            if let _ = $1.value {
                $1.value = 3
            }
            if let boolean = $2.value {
                $2.value = !boolean
            }
        }
        var changeSame1expected = AttributedString("A", attributes: AttributeContainer().testInt(42).testBool(false))
        changeSame1expected += AttributedString("B", attributes: AttributeContainer().testInt(42).testDouble(3))
        changeSame1expected += AttributedString("C", attributes: AttributeContainer().testDouble(3).testBool(true))
        XCTAssertEqual(changeSame1expected, changeSame1)

        // Test change value, different attribute
        let changeDifferent1 = attrStr.transformingAttributes(\.testInt, \.testDouble, \.testBool) {
            if let _ = $0.value {
                $0.replace(with: AttributeScopes.TestAttributes.TestDoubleAttribute.self, value: 2)
            }
            if let _ = $1.value {
                $1.replace(with: AttributeScopes.TestAttributes.TestBoolAttribute.self, value: false)
            }
            if let _ = $2.value {
                $2.replace(with: AttributeScopes.TestAttributes.TestIntAttribute.self, value: 42)
            }
        }

        var changeDifferent1expected = AttributedString("A", attributes: AttributeContainer().testDouble(2).testInt(42))
        changeDifferent1expected += AttributedString("B", attributes: AttributeContainer().testDouble(2).testBool(false))
        changeDifferent1expected += AttributedString("C", attributes: AttributeContainer().testBool(false).testInt(42))
        XCTAssertEqual(changeDifferent1expected, changeDifferent1)

        // Test change range
        var changeRange1First = true
        let changeRange1 = attrStr.transformingAttributes(\.testInt, \.testDouble, \.testBool) {
            if changeRange1First {
                let range = $0.range
                let extendedRange = range.lowerBound ..< attrStr.characters.index(after: range.upperBound)
                $0.range = extendedRange
                $1.range = extendedRange
                $2.range = extendedRange
                changeRange1First = false
            }
        }
        var changeRange1expected = AttributedString("A", attributes: AttributeContainer().testInt(1).testBool(true))
        changeRange1expected += AttributedString("B", attributes: AttributeContainer().testInt(1).testBool(true))
        changeRange1expected += AttributedString("C", attributes: AttributeContainer().testDouble(2).testBool(false))
        XCTAssertEqual(changeRange1expected, changeRange1)
    }

    func testMutateAttributes() {
        var attrStr = AttributedString("A", attributes: AttributeContainer().testInt(1).testBool(true))
        attrStr += AttributedString("B", attributes: AttributeContainer().testInt(1).testDouble(2))
        attrStr += AttributedString("C", attributes: AttributeContainer().testDouble(2).testBool(false))
        
        // Test removal
        let removal1 = attrStr.transformingAttributes(\.testInt) {
            $0.value = nil
        }
        var removal1expected = AttributedString("A", attributes: AttributeContainer().testBool(true))
        removal1expected += AttributedString("B", attributes: AttributeContainer().testDouble(2))
        removal1expected += AttributedString("C", attributes: AttributeContainer().testDouble(2).testBool(false))
        XCTAssertEqual(removal1expected, removal1)

        // Test change value, same attribute.
        let changeSame1 = attrStr.transformingAttributes(\.testBool) {
            if let boolean = $0.value {
                $0.value = !boolean
            }
        }
        var changeSame1expected = AttributedString("A", attributes: AttributeContainer().testInt(1).testBool(false))
        changeSame1expected += AttributedString("B", attributes: AttributeContainer().testInt(1).testDouble(2))
        changeSame1expected += AttributedString("C", attributes: AttributeContainer().testDouble(2).testBool(true))
        XCTAssertEqual(changeSame1expected, changeSame1)

        // Test change value, different attribute
        let changeDifferent1 = attrStr.transformingAttributes(\.testBool) {
            if let value = $0.value {
                $0.replace(with: AttributeScopes.TestAttributes.TestDoubleAttribute.self, value: (value ? 42 : 43))
            }
        }
        var changeDifferent1expected = AttributedString("A", attributes: AttributeContainer().testInt(1).testDouble(42))
        changeDifferent1expected += AttributedString("B", attributes: AttributeContainer().testInt(1).testDouble(2))
        changeDifferent1expected += AttributedString("C", attributes: AttributeContainer().testDouble(43))
        XCTAssertEqual(changeDifferent1expected, changeDifferent1)

        // Test change range
        let changeRange1 = attrStr.transformingAttributes(\.testInt) {
            if let _ = $0.value {
                // Shorten the range by one.
                $0.range = $0.range.lowerBound ..< attrStr.characters.index(before: $0.range.upperBound)
            }
        }
        var changeRange1expected = AttributedString("A", attributes: AttributeContainer().testInt(1).testBool(true))
        changeRange1expected += AttributedString("B", attributes: AttributeContainer().testDouble(2))
        changeRange1expected += AttributedString("C", attributes: AttributeContainer().testDouble(2).testBool(false))
        XCTAssertEqual(changeRange1expected, changeRange1)

        // Now try extending it
        let changeRange2 = attrStr.transformingAttributes(\.testInt) {
            if let _ = $0.value {
                // Extend the range by one.
                $0.range = $0.range.lowerBound ..< attrStr.characters.index(after: $0.range.upperBound)
            }
        }
        var changeRange2expected = AttributedString("A", attributes: AttributeContainer().testInt(1).testBool(true))
        changeRange2expected += AttributedString("B", attributes: AttributeContainer().testInt(1).testDouble(2))
        changeRange2expected += AttributedString("C", attributes: AttributeContainer().testInt(1).testDouble(2).testBool(false))
        XCTAssertEqual(changeRange2expected, changeRange2)
    }

    func testReplaceAttributes() {
        var attrStr = AttributedString("A", attributes: AttributeContainer().testInt(1).testBool(true))
        attrStr += AttributedString("B", attributes: AttributeContainer().testInt(1).testDouble(2))
        attrStr += AttributedString("C", attributes: AttributeContainer().testDouble(2).testBool(false))

        // Test removal
        let removal1Find = AttributeContainer().testInt(1)
        let removal1Replace = AttributeContainer()
        var removal1 = attrStr
        removal1.replaceAttributes(removal1Find, with: removal1Replace)
        
        var removal1expected = AttributedString("A", attributes: AttributeContainer().testBool(true))
        removal1expected += AttributedString("B", attributes: AttributeContainer().testDouble(2))
        removal1expected += AttributedString("C", attributes: AttributeContainer().testDouble(2).testBool(false))
        XCTAssertEqual(removal1expected, removal1)
        
        // Test change value, same attribute.
        let changeSame1Find = AttributeContainer().testBool(false)
        let changeSame1Replace = AttributeContainer().testBool(true)
        var changeSame1 = attrStr
        changeSame1.replaceAttributes(changeSame1Find, with: changeSame1Replace)
    
        var changeSame1expected = AttributedString("A", attributes: AttributeContainer().testInt(1).testBool(true))
        changeSame1expected += AttributedString("B", attributes: AttributeContainer().testInt(1).testDouble(2))
        changeSame1expected += AttributedString("C", attributes: AttributeContainer().testDouble(2).testBool(true))
        XCTAssertEqual(changeSame1expected, changeSame1)
        
        // Test change value, different attribute
        let changeDifferent1Find = AttributeContainer().testBool(false)
        let changeDifferent1Replace = AttributeContainer().testDouble(43)
        var changeDifferent1 = attrStr
        changeDifferent1.replaceAttributes(changeDifferent1Find, with: changeDifferent1Replace)
        
        var changeDifferent1expected = AttributedString("A", attributes: AttributeContainer().testInt(1).testBool(true))
        changeDifferent1expected += AttributedString("B", attributes: AttributeContainer().testInt(1).testDouble(2))
        changeDifferent1expected += AttributedString("C", attributes: AttributeContainer().testDouble(43))
        XCTAssertEqual(changeDifferent1expected, changeDifferent1)
    }
 
    
    func testSliceMutation() {
        var attrStr = AttributedString("Hello World", attributes: AttributeContainer().testInt(1))
        let start = attrStr.characters.index(attrStr.startIndex, offsetBy: 6)
        attrStr.replaceSubrange(start ..< attrStr.characters.index(start, offsetBy:5), with: AttributedString("Goodbye", attributes: AttributeContainer().testInt(2)))

        var expected = AttributedString("Hello ", attributes: AttributeContainer().testInt(1))
        expected += AttributedString("Goodbye", attributes: AttributeContainer().testInt(2))
        XCTAssertEqual(attrStr, expected)
        XCTAssertNotEqual(attrStr, AttributedString("Hello Goodbye", attributes: AttributeContainer().testInt(1)))
    }
    
    func testOverlappingSliceMutation() {
        var attrStr = AttributedString("Hello, world!")
        attrStr[attrStr.range(of: "Hello")!].testInt = 1
        attrStr[attrStr.range(of: "world")!].testInt = 2
        attrStr[attrStr.range(of: "o, wo")!].testBool = true
        
        var expected = AttributedString("Hell", attributes: AttributeContainer().testInt(1))
        expected += AttributedString("o", attributes: AttributeContainer().testInt(1).testBool(true))
        expected += AttributedString(", ", attributes: AttributeContainer().testBool(true))
        expected += AttributedString("wo", attributes: AttributeContainer().testBool(true).testInt(2))
        expected += AttributedString("rld", attributes: AttributeContainer().testInt(2))
        expected += AttributedString("!")
        XCTAssertEqual(attrStr, expected)
    }

    func testCharacters_replaceSubrange() {
        var attrStr = AttributedString("Hello World", attributes: AttributeContainer().testInt(1))
        attrStr.characters.replaceSubrange(attrStr.range(of: " ")!, with: " Good ")

        let expected = AttributedString("Hello Good World", attributes: AttributeContainer().testInt(1))
        XCTAssertEqual(expected, attrStr)
    }

    func testCharactersMutation_append() {
        var attrStr = AttributedString("Hello World", attributes: AttributeContainer().testInt(1))
        attrStr.characters.append(contentsOf: " Goodbye")

        let expected = AttributedString("Hello World Goodbye", attributes: AttributeContainer().testInt(1))
        XCTAssertEqual(expected, attrStr)
    }

    func testUnicodeScalars_replaceSubrange() {
        var attrStr = AttributedString("La Cafe\u{301}", attributes: AttributeContainer().testInt(1))
        let unicode = attrStr.unicodeScalars
        attrStr.unicodeScalars.replaceSubrange(unicode.index(unicode.startIndex, offsetBy: 3) ..< unicode.index(unicode.startIndex, offsetBy: 7), with: "Ole".unicodeScalars)

        let expected = AttributedString("La Ole\u{301}", attributes: AttributeContainer().testInt(1))
        XCTAssertEqual(expected, attrStr)
    }

    func testUnicodeScalarsMutation_append() {
        var attrStr = AttributedString("Cafe", attributes: AttributeContainer().testInt(1))
        attrStr.unicodeScalars.append("\u{301}")

        let expected = AttributedString("Cafe\u{301}", attributes: AttributeContainer().testInt(1))
        XCTAssertEqual(expected, attrStr)
    }

    func testSubCharacterAttributeSetting() {
        var attrStr = AttributedString("Cafe\u{301}", attributes: AttributeContainer().testInt(1))
        let cafRange = attrStr.characters.startIndex ..< attrStr.characters.index(attrStr.characters.startIndex, offsetBy: 3)
        let eRange = cafRange.upperBound ..< attrStr.unicodeScalars.index(after: cafRange.upperBound)
        let accentRange = eRange.upperBound ..< attrStr.unicodeScalars.endIndex
        attrStr[cafRange].testDouble = 1.5
        attrStr[eRange].testDouble = 2.5
        attrStr[accentRange].testDouble = 3.5

        var expected = AttributedString("Caf", attributes: AttributeContainer().testInt(1).testDouble(1.5))
        expected += AttributedString("e", attributes: AttributeContainer().testInt(1).testDouble(2.5))
        expected += AttributedString("\u{301}", attributes: AttributeContainer().testInt(1).testDouble(3.5))
        XCTAssertEqual(expected, attrStr)
    }
    
    func testReplaceSubrange_rangeExpression() {
        var attrStr = AttributedString("Hello World", attributes: AttributeContainer().testInt(1))
        
        // Test with PartialRange, which conforms to RangeExpression but is not a Range
        let rangeOfHello = ...attrStr.characters.index(attrStr.startIndex, offsetBy: 4)
        attrStr.replaceSubrange(rangeOfHello, with: AttributedString("Goodbye"))
        
        var expected = AttributedString("Goodbye")
        expected += AttributedString(" World", attributes: AttributeContainer().testInt(1))
        XCTAssertEqual(attrStr, expected)
    }
    
    func testSettingAttributes() {
        var attrStr = AttributedString("Hello World", attributes: .init().testInt(1))
        attrStr += AttributedString(". My name is Foundation!", attributes: .init().testBool(true))
        
        let result = attrStr.settingAttributes(.init().testBool(false))
        
        let expected = AttributedString("Hello World. My name is Foundation!", attributes: .init().testBool(false))
        XCTAssertEqual(result, expected)
    }
    
    func testAddAttributedString() {
        let attrStr = AttributedString("Hello ", attributes: .init().testInt(1))
        let attrStr2 = AttributedString("World", attributes: .init().testInt(2))
        let original = attrStr
        let original2 = attrStr2
        
        var concat = AttributedString("Hello ", attributes: .init().testInt(1))
        concat += AttributedString("World", attributes: .init().testInt(2))
        let combine = attrStr + attrStr2
        XCTAssertEqual(attrStr, original)
        XCTAssertEqual(attrStr2, original2)
        XCTAssertEqual(String(combine.characters), "Hello World")
        XCTAssertEqual(String(concat.characters), "Hello World")
        
        let testInts = [1, 2]
        for str in [concat, combine] {
            var i = 0
            for run in str.runs {
                XCTAssertEqual(run.testInt, testInts[i])
                i += 1
            }
        }
    }

    func testReplaceSubrangeWithSubstrings() {
        let baseString = AttributedString("A", attributes: .init().testInt(1))
        + AttributedString("B", attributes: .init().testInt(2))
        + AttributedString("C", attributes: .init().testInt(3))
        + AttributedString("D", attributes: .init().testInt(4))
        + AttributedString("E", attributes: .init().testInt(5))

        let substring = baseString[ baseString.characters.index(after: baseString.startIndex) ..< baseString.characters.index(before: baseString.endIndex) ]

        var targetString = AttributedString("XYZ", attributes: .init().testString("foo"))
        targetString.replaceSubrange(targetString.characters.index(after: targetString.startIndex) ..< targetString.characters.index(before: targetString.endIndex), with: substring)

        var expected = AttributedString("X", attributes: .init().testString("foo"))
        + AttributedString("B", attributes: .init().testInt(2))
        + AttributedString("C", attributes: .init().testInt(3))
        + AttributedString("D", attributes: .init().testInt(4))
        + AttributedString("Z", attributes: .init().testString("foo"))

        XCTAssertEqual(targetString, expected)

        targetString = AttributedString("XYZ", attributes: .init().testString("foo"))
        targetString.append(substring)
        expected = AttributedString("XYZ", attributes: .init().testString("foo"))
        + AttributedString("B", attributes: .init().testInt(2))
        + AttributedString("C", attributes: .init().testInt(3))
        + AttributedString("D", attributes: .init().testInt(4))

        XCTAssertEqual(targetString, expected)
    }
    
    func assertStringIsCoalesced(_ str: AttributedString) {
        var prev: AttributedString.Runs.Run?
        for run in str.runs {
            if let prev = prev {
                XCTAssertNotEqual(prev.attributes, run.attributes)
            }
            prev = run
        }
    }
    
    func testCoalescing() {
        let str = AttributedString("Hello", attributes: .init().testInt(1))
        let appendSame = str + AttributedString("World", attributes: .init().testInt(1))
        let appendDifferent = str + AttributedString("World", attributes: .init().testInt(2))
        
        assertStringIsCoalesced(str)
        assertStringIsCoalesced(appendSame)
        assertStringIsCoalesced(appendDifferent)
        XCTAssertEqual(appendSame.runs.count, 1)
        XCTAssertEqual(appendDifferent.runs.count, 2)
        
        // Ensure replacing whole string keeps coalesced
        var str2 = str
        str2.replaceSubrange(str2.startIndex ..< str2.endIndex, with: AttributedString("Hello", attributes: .init().testInt(2)))
        assertStringIsCoalesced(str2)
        XCTAssertEqual(str2.runs.count, 1)
        
        // Ensure replacing subranges splits runs and doesn't coalesce when not equal
        var str3 = str
        str3.replaceSubrange(str3.characters.index(after: str3.startIndex) ..< str3.endIndex, with: AttributedString("ello", attributes: .init().testInt(2)))
        assertStringIsCoalesced(str3)
        XCTAssertEqual(str3.runs.count, 2)
        
        var str4 = str
        str4.replaceSubrange(str4.startIndex ..< str4.characters.index(before: str4.endIndex), with: AttributedString("Hell", attributes: .init().testInt(2)))
        assertStringIsCoalesced(str4)
        XCTAssertEqual(str4.runs.count, 2)
        
        var str5 = str
        str5.replaceSubrange(str5.characters.index(after: str5.startIndex) ..< str5.characters.index(before: str4.endIndex), with: AttributedString("ell", attributes: .init().testInt(2)))
        assertStringIsCoalesced(str5)
        XCTAssertEqual(str5.runs.count, 3)
        
        // Ensure changing attributes back to match bordering runs coalesces with edge of subrange
        var str6 = str5
        str6.replaceSubrange(str6.characters.index(after: str6.startIndex) ..< str6.endIndex, with: AttributedString("ello", attributes: .init().testInt(1)))
        assertStringIsCoalesced(str6)
        XCTAssertEqual(str6.runs.count, 1)
        
        var str7 = str5
        str7.replaceSubrange(str7.startIndex ..< str7.characters.index(before: str7.endIndex), with: AttributedString("Hell", attributes: .init().testInt(1)))
        assertStringIsCoalesced(str7)
        XCTAssertEqual(str7.runs.count, 1)
        
        var str8 = str5
        str8.replaceSubrange(str8.characters.index(after: str8.startIndex) ..< str8.characters.index(before: str8.endIndex), with: AttributedString("ell", attributes: .init().testInt(1)))
        assertStringIsCoalesced(str8)
        XCTAssertEqual(str8.runs.count, 1)
        
        var str9 = str5
        str9.testInt = 1
        assertStringIsCoalesced(str9)
        XCTAssertEqual(str9.runs.count, 1)
        
        var str10 = str5
        str10[str10.characters.index(after: str10.startIndex) ..< str10.characters.index(before: str10.endIndex)].testInt = 1
        assertStringIsCoalesced(str10)
        XCTAssertEqual(str10.runs.count, 1)
    }
    
    func testReplaceWithEmptyElements() {
        var str = AttributedString("Hello, world")
        let range = str.startIndex ..< str.characters.index(str.startIndex, offsetBy: 5)
        str.characters.replaceSubrange(range, with: [])
        
        XCTAssertEqual(str, AttributedString(", world"))
    }
    
    func testDescription() {
        let string = AttributedString("A", attributes: .init().testInt(1))
        + AttributedString("B", attributes: .init().testInt(2))
        + AttributedString("C", attributes: .init().testInt(3))
        + AttributedString("D", attributes: .init().testInt(4))
        + AttributedString("E", attributes: .init().testInt(5))
        
        let desc = String(describing: string)
        let expected = """
A {
\tTestInt = 1
}
B {
\tTestInt = 2
}
C {
\tTestInt = 3
}
D {
\tTestInt = 4
}
E {
\tTestInt = 5
}
"""
        XCTAssertEqual(desc, expected)
        
        let runsDesc = String(describing: string.runs)
        XCTAssertEqual(runsDesc, expected)
    }
    
    func testContainerDescription() {
        let cont = AttributeContainer().testBool(false).testInt(1).testDouble(2.0).testString("3")
        
        let desc = String(describing: cont)
        
        // Don't get bitten by any potential changes in the hashing algorithm.
        XCTAssertTrue(desc.hasPrefix("{\n"))
        XCTAssertTrue(desc.hasSuffix("\n}"))
        XCTAssertTrue(desc.contains("\tTestDouble = 2.0\n"))
        XCTAssertTrue(desc.contains("\tTestInt = 1\n"))
        XCTAssertTrue(desc.contains("\tTestString = 3\n"))
        XCTAssertTrue(desc.contains("\tTestBool = false\n"))
    }
    
    func testRunAndSubstringDescription() {
        let string = AttributedString("A", attributes: .init().testInt(1))
        + AttributedString("B", attributes: .init().testInt(2))
        + AttributedString("C", attributes: .init().testInt(3))
        + AttributedString("D", attributes: .init().testInt(4))
        + AttributedString("E", attributes: .init().testInt(5))
        
        let runsDescs = string.runs.map() { String(describing: $0) }
        let expected = [ """
A {
\tTestInt = 1
}
""", """
B {
\tTestInt = 2
}
""", """
C {
\tTestInt = 3
}
""", """
D {
\tTestInt = 4
}
""", """
E {
\tTestInt = 5
}
"""]
        XCTAssertEqual(runsDescs, expected)
        
        let subDescs = string.runs.map() { String(describing: string[$0.range]) }
        XCTAssertEqual(subDescs, expected)
    }
    
    func testReplacingAttributes() {
        var str = AttributedString("Hello", attributes: .init().testInt(2))
        str += AttributedString("World", attributes: .init().testString("Test"))
        
        var result = str.replacingAttributes(.init().testInt(2).testString("NotTest"), with: .init().testBool(false))
        XCTAssertEqual(result, str)
        
        result = str.replacingAttributes(.init().testInt(2), with: .init().testBool(false))
        var expected = AttributedString("Hello", attributes: .init().testBool(false))
        expected += AttributedString("World", attributes: .init().testString("Test"))
        XCTAssertEqual(result, expected)
    }
    
    func testScopedAttributeContainer() {
        var str = AttributedString("Hello, world")
        
        XCTAssertNil(str.test.testInt)
        XCTAssertNil(str.testInt)
        str.test.testInt = 2
        XCTAssertEqual(str.test.testInt, 2)
        XCTAssertEqual(str.testInt, 2)
        str.test.testInt = nil
        XCTAssertNil(str.test.testInt)
        XCTAssertNil(str.testInt)
        
        let range = str.startIndex ..< str.index(str.startIndex, offsetByCharacters: 5)
        let otherRange = range.upperBound ..< str.endIndex
        
        str[range].test.testBool = true
        XCTAssertEqual(str[range].test.testBool, true)
        XCTAssertEqual(str[range].testBool, true)
        XCTAssertNil(str.test.testBool)
        XCTAssertNil(str.testBool)
        str[range].test.testBool = nil
        XCTAssertNil(str[range].test.testBool)
        XCTAssertNil(str[range].testBool)
        XCTAssertNil(str.test.testBool)
        XCTAssertNil(str.testBool)
        
        str.test.testBool = true
        str[range].test.testBool = nil
        XCTAssertNil(str[range].test.testBool)
        XCTAssertNil(str[range].testBool)
        XCTAssertNil(str.test.testBool)
        XCTAssertNil(str.testBool)
        XCTAssertEqual(str[otherRange].test.testBool, true)
        XCTAssertEqual(str[otherRange].testBool, true)
    }
    
    func testMergeAttributes() {
        let originalAttributes = AttributeContainer.testInt(2).testBool(true)
        let newAttributes = AttributeContainer.testString("foo")
        let overlappingAttributes = AttributeContainer.testInt(3).testDouble(4.3)
        let str = AttributedString("Hello, world", attributes: originalAttributes)
        
        XCTAssertEqual(str.mergingAttributes(newAttributes, mergePolicy: .keepNew), AttributedString("Hello, world", attributes: newAttributes.testInt(2).testBool(true)))
        XCTAssertEqual(str.mergingAttributes(newAttributes, mergePolicy: .keepCurrent), AttributedString("Hello, world", attributes: newAttributes.testInt(2).testBool(true)))
        XCTAssertEqual(str.mergingAttributes(overlappingAttributes, mergePolicy: .keepNew), AttributedString("Hello, world", attributes: overlappingAttributes.testBool(true)))
        XCTAssertEqual(str.mergingAttributes(overlappingAttributes, mergePolicy: .keepCurrent), AttributedString("Hello, world", attributes: originalAttributes.testDouble(4.3)))
    }
    
    func testMergeAttributeContainers() {
        let originalAttributes = AttributeContainer.testInt(2).testBool(true)
        let newAttributes = AttributeContainer.testString("foo")
        let overlappingAttributes = AttributeContainer.testInt(3).testDouble(4.3)
        
        XCTAssertEqual(originalAttributes.merging(newAttributes, mergePolicy: .keepNew), newAttributes.testInt(2).testBool(true))
        XCTAssertEqual(originalAttributes.merging(newAttributes, mergePolicy: .keepCurrent), newAttributes.testInt(2).testBool(true))
        XCTAssertEqual(originalAttributes.merging(overlappingAttributes, mergePolicy: .keepNew), overlappingAttributes.testBool(true))
        XCTAssertEqual(originalAttributes.merging(overlappingAttributes, mergePolicy: .keepCurrent), originalAttributes.testDouble(4.3))
    }
    
    func testChangingSingleCharacterUTF8Length() {
        var attrstr = AttributedString("\u{1F3BA}\u{1F3BA}") // UTF-8 Length of 8
        attrstr.characters[attrstr.startIndex] = "A" // Changes UTF-8 Length to 5
        XCTAssertEqual(attrstr.runs.count, 1)
        let runRange = attrstr.runs.first!.range
        let substring = String(attrstr[runRange].characters)
        XCTAssertEqual(substring, "A\u{1F3BA}")
    }
    
    // MARK: - Substring Tests
    
    func testSubstringBase() {
        let str = AttributedString("Hello World", attributes: .init().testInt(1))
        var substr = str[str.startIndex ..< str.characters.index(str.startIndex, offsetBy: 5)]
        XCTAssertEqual(substr.base, str)
        substr.testInt = 3
        XCTAssertNotEqual(substr.base, str)
        
        var str2 = AttributedString("Hello World", attributes: .init().testInt(1))
        let range = str2.startIndex ..< str2.characters.index(str2.startIndex, offsetBy: 5)
        XCTAssertEqual(str2[range].base, str2)
        str2[range].testInt = 3
        XCTAssertEqual(str2[range].base, str2)
    }
    
    func testSubstringGetAttribute() {
        let str = AttributedString("Hello World", attributes: .init().testInt(1))
        let range = str.startIndex ..< str.characters.index(str.startIndex, offsetBy: 5)
        XCTAssertEqual(str[range].testInt, 1)
        XCTAssertNil(str[range].testString)
        
        var str2 = AttributedString("Hel", attributes: .init().testInt(1))
        str2 += AttributedString("lo World", attributes: .init().testInt(2).testBool(true))
        let range2 = str2.startIndex ..< str2.characters.index(str2.startIndex, offsetBy: 5)
        XCTAssertNil(str2[range2].testInt)
        XCTAssertNil(str2[range2].testBool)
    }
    
    func testSubstringDescription() {
        var str = AttributedString("Hello", attributes: .init().testInt(2))
        str += " "
        str += AttributedString("World", attributes: .init().testInt(3))
        
        for run in str.runs {
            let desc = str[run.range].description
            XCTAssertFalse(desc.isEmpty)
        }
    }
    
    func testSubstringReplaceAttributes() {
        var str = AttributedString("Hello", attributes: .init().testInt(2).testString("Foundation"))
        str += " "
        str += AttributedString("World", attributes: .init().testInt(3))
        
        let range = str.index(str.startIndex, offsetByCharacters: 2) ..< str.index(str.startIndex, offsetByCharacters: 8)
        str[range].replaceAttributes(.init().testInt(2).testString("Foundation"), with: .init().testBool(true))
        
        var expected = AttributedString("He", attributes: .init().testInt(2).testString("Foundation"))
        expected += AttributedString("llo", attributes: .init().testBool(true))
        expected += " "
        expected += AttributedString("World", attributes: .init().testInt(3))
        XCTAssertEqual(str, expected)
    }
    
    func testSubstringEquality() {
        let str = AttributedString("")
        let range = str.startIndex ..< str.endIndex
        XCTAssertEqual(str[range], str[range])
        
        let str2 = "A" + AttributedString("A", attributes: .init().testInt(2))
        let substringA = str2[str2.startIndex ..< str2.index(afterCharacter: str2.startIndex)]
        let substringB = str2[str2.index(afterCharacter: str2.startIndex) ..< str2.endIndex]
        XCTAssertNotEqual(substringA, substringB)
        XCTAssertEqual(substringA, substringA)
        XCTAssertEqual(substringB, substringB)
    }
    
    func testInitializationFromSubstring() {
        var attrStr = AttributedString("yolo^+1 result<:s>^", attributes: AttributeContainer.testInt(2).testString("Hello"))
        attrStr.replaceSubrange(attrStr.range(of: "<:s>")!, with: AttributedString(""))
        attrStr[attrStr.range(of: "1 result")!].testInt = 3

        let range = attrStr.range(of: "+1 result")!
        let subFinal = attrStr[range]
        let attrFinal = AttributedString(subFinal)
        XCTAssertTrue(attrFinal.characters.elementsEqual(subFinal.characters))
        XCTAssertEqual(attrFinal.runs, subFinal.runs)
        
        var attrStr2 = AttributedString("xxxxxxxx", attributes: .init().testInt(1))
        attrStr2 += AttributedString("y", attributes: .init().testInt(2))
        attrStr2 += AttributedString("zzzzzzzz", attributes: .init().testInt(3))

        let subrange = attrStr2.index(attrStr2.startIndex, offsetByCharacters: 5) ..< attrStr2.endIndex
        let substring2 = attrStr2[subrange]
        let recreated = AttributedString(substring2)
        XCTAssertEqual(recreated.runs.count, 3)
    }

#if FOUNDATION_FRAMEWORK
    // MARK: - Coding Tests
    // TODO: Support AttributedString codable conformance in FoundationPreview
    struct CodableType : Codable {
        // One of potentially many different values being encoded:
        @CodableConfiguration(from: \.test)
        var attributedString = AttributedString()
    }

    func testJSONEncoding() throws {
        let encoder = JSONEncoder()
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testBool(true).testString("blue").testInt(1))
        attrStr += AttributedString(" World", attributes: AttributeContainer().testInt(2).testDouble(3.0).testString("http://www.apple.com"))

        let c = CodableType(attributedString: attrStr)
        let json = try encoder.encode(c)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CodableType.self, from: json)
        XCTAssertEqual(decoded.attributedString, attrStr)
    }
    
    func testDecodingThenConvertingToNSAttributedString() throws {
        let encoder = JSONEncoder()
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testBool(true))
        attrStr += AttributedString(" World", attributes: AttributeContainer().testInt(2))
        let c = CodableType(attributedString: attrStr)
        let json = try encoder.encode(c)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CodableType.self, from: json)
        let decodedns = try NSAttributedString(decoded.attributedString, including: AttributeScopes.TestAttributes.self)
        let ns = try NSAttributedString(attrStr, including: AttributeScopes.TestAttributes.self)
        XCTAssertEqual(ns, decodedns)
    }
    
    func testCustomAttributeCoding() throws {
        struct MyAttributes : AttributeScope {
            var customCodable : AttributeScopes.TestAttributes.CustomCodableAttribute
        }
        
        struct CodableType : Codable {
            @CodableConfiguration(from: MyAttributes.self)
            var attributedString = AttributedString()
        }
        
        let encoder = JSONEncoder()
        var attrStr = AttributedString("Hello")
        attrStr[AttributeScopes.TestAttributes.CustomCodableAttribute.self] = .init(inner: 42)
        
        let c = CodableType(attributedString: attrStr)
        let json = try encoder.encode(c)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CodableType.self, from: json)
        XCTAssertEqual(decoded.attributedString, attrStr)
    }
    
    func testCustomCodableTypeWithCodableAttributedString() throws {
        struct MyType : Codable, Equatable {
            var other: NonCodableType
            var str: AttributedString
            
            init(other: NonCodableType, str: AttributedString) {
                self.other = other
                self.str = str
            }
            
            enum Keys : CodingKey {
                case other
                case str
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: Keys.self)
                other = NonCodableType(inner: try container.decode(Int.self, forKey: .other))
                str = try container.decode(AttributedString.self, forKey: .str, configuration: AttributeScopes.TestAttributes.self)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: Keys.self)
                try container.encode(other.inner, forKey: .other)
                try container.encode(str, forKey: .str, configuration: AttributeScopes.TestAttributes.self)
            }
        }
        
        var container = AttributeContainer()
        container.testInt = 3
        let type = MyType(other: NonCodableType(inner: 2), str: AttributedString("Hello World", attributes: container))
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(type)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MyType.self, from: data)
        XCTAssertEqual(type, decoded)
    }
    
    func testCodingErrorsPropagateUpToCallSite() {
        enum CustomAttribute : CodableAttributedStringKey {
            typealias Value = String
            static let name = "CustomAttribute"
            
            static func encode(_ value: Value, to encoder: Encoder) throws {
                throw TestError.encodingError
            }
            
            static func decode(from decoder: Decoder) throws -> Value {
                throw TestError.decodingError
            }
        }
        
        struct CustomScope : AttributeScope {
            var custom: CustomAttribute
        }
        
        struct Obj : Codable {
            @CodableConfiguration(from: CustomScope.self) var str = AttributedString()
        }
        
        var str = AttributedString("Hello, world")
        str[CustomAttribute.self] = "test"
        let encoder = JSONEncoder()
        XCTAssertThrowsError(try encoder.encode(Obj(str: str)), "Attribute encoding error did not throw at call site") { err in
            XCTAssert(err is TestError, "Encoding did not throw the proper error")
        }
    }
    
    func testEncodeWithPartiallyCodableScope() throws {
        enum NonCodableAttribute : AttributedStringKey {
            typealias Value = Int
            static let name = "NonCodableAttributes"
        }
        struct PartialCodableScope : AttributeScope {
            var codableAttr : AttributeScopes.TestAttributes.TestIntAttribute
            var nonCodableAttr : NonCodableAttribute
        }
        struct Obj : Codable {
            @CodableConfiguration(from: PartialCodableScope.self) var str = AttributedString()
        }
        
        var str = AttributedString("Hello, world")
        str[AttributeScopes.TestAttributes.TestIntAttribute.self] = 2
        str[NonCodableAttribute.self] = 3
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(Obj(str: str))
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Obj.self, from: data)
        
        var expected = str
        expected[NonCodableAttribute.self] = nil
        XCTAssertEqual(decoded.str, expected)
    }

    func testAutomaticCoding() throws {
        struct Obj : Codable, Equatable {
            @CodableConfiguration(from: AttributeScopes.TestAttributes.self) var attrStr = AttributedString()
            @CodableConfiguration(from: AttributeScopes.TestAttributes.self) var optAttrStr : AttributedString? = nil
            @CodableConfiguration(from: AttributeScopes.TestAttributes.self) var attrStrArr = [AttributedString]()
            @CodableConfiguration(from: AttributeScopes.TestAttributes.self) var optAttrStrArr = [AttributedString?]()

            public init(testValueWithNils: Bool) {
                attrStr = AttributedString("Test")
                attrStr.testString = "TestAttr"

                attrStrArr = [attrStr, attrStr]
                if testValueWithNils {
                    optAttrStr = nil
                    optAttrStrArr = [nil, attrStr, nil]
                } else {
                    optAttrStr = attrStr
                    optAttrStrArr = [attrStr, attrStr]
                }
            }
        }

        // nil
        do {
            let val = Obj(testValueWithNils: true)
            let encoder = JSONEncoder()
            let data = try encoder.encode(val)
            print(String(data: data, encoding: .utf8)!)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Obj.self, from: data)

            XCTAssertEqual(decoded, val)
        }

        // non-nil
        do {
            let val = Obj(testValueWithNils: false)
            let encoder = JSONEncoder()
            let data = try encoder.encode(val)
            print(String(data: data, encoding: .utf8)!)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Obj.self, from: data)

            XCTAssertEqual(decoded, val)
        }

    }


    func testManualCoding() throws {
        struct Obj : Codable, Equatable {
            var attrStr : AttributedString
            var optAttrStr : AttributedString?
            var attrStrArr : [AttributedString]
            var optAttrStrArr : [AttributedString?]

            public init(testValueWithNils: Bool) {
                attrStr = AttributedString("Test")
                attrStr.testString = "TestAttr"

                attrStrArr = [attrStr, attrStr]
                if testValueWithNils {
                    optAttrStr = nil
                    optAttrStrArr = [nil, attrStr, nil]
                } else {
                    optAttrStr = attrStr
                    optAttrStrArr = [attrStr, attrStr]
                }
            }

            enum Keys : CodingKey {
                case attrStr
                case optAttrStr
                case attrStrArr
                case optAttrStrArr
            }

            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(attrStr, forKey: .attrStr, configuration: AttributeScopes.TestAttributes.self)
                try c.encodeIfPresent(optAttrStr, forKey: .optAttrStr, configuration: AttributeScopes.TestAttributes.self)
                try c.encode(attrStrArr, forKey: .attrStrArr, configuration: AttributeScopes.TestAttributes.self)
                try c.encode(optAttrStrArr, forKey: .optAttrStrArr, configuration: AttributeScopes.TestAttributes.self)
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: Keys.self)
                attrStr = try c.decode(AttributedString.self, forKey: .attrStr, configuration: AttributeScopes.TestAttributes.self)
                optAttrStr = try c.decodeIfPresent(AttributedString.self, forKey: .optAttrStr, configuration: AttributeScopes.TestAttributes.self)
                attrStrArr = try c.decode([AttributedString].self, forKey: .attrStrArr, configuration: AttributeScopes.TestAttributes.self)
                optAttrStrArr = try c.decode([AttributedString?].self, forKey: .optAttrStrArr, configuration: AttributeScopes.TestAttributes.self)
            }
        }

        // nil
        do {
            let val = Obj(testValueWithNils: true)
            let encoder = JSONEncoder()
            let data = try encoder.encode(val)
            print(String(data: data, encoding: .utf8)!)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Obj.self, from: data)

            XCTAssertEqual(decoded, val)
        }

        // non-nil
        do {
            let val = Obj(testValueWithNils: false)
            let encoder = JSONEncoder()
            let data = try encoder.encode(val)
            print(String(data: data, encoding: .utf8)!)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Obj.self, from: data)

            XCTAssertEqual(decoded, val)
        }
        
    }
    
    func testDecodingCorruptedData() throws {
        let jsonStrings = [
            "{\"attributedString\": 2}",
            "{\"attributedString\": []}",
            "{\"attributedString\": [\"Test\"]}",
            "{\"attributedString\": [\"Test\", 0]}",
            "{\"attributedString\": [\"\", {}, \"Test\", {}]}",
            "{\"attributedString\": [\"Test\", {}, \"\", {}]}",
            "{\"attributedString\": [\"\", {\"TestInt\": 1}]}",
            "{\"attributedString\": {}}",
            "{\"attributedString\": {\"attributeTable\": []}}",
            "{\"attributedString\": {\"runs\": []}}",
            "{\"attributedString\": {\"runs\": [], \"attributeTable\": []}}",
            "{\"attributedString\": {\"runs\": [\"\"], \"attributeTable\": []}}",
            "{\"attributedString\": {\"runs\": [\"\", 1], \"attributeTable\": []}}",
            "{\"attributedString\": {\"runs\": [\"\", {}, \"Test\", {}], \"attributeTable\": []}}",
            "{\"attributedString\": {\"runs\": \"Test\", {}, \"\", {}, \"attributeTable\": []}}",
        ]
        
        let decoder = JSONDecoder()
        for string in jsonStrings {
            XCTAssertThrowsError(try decoder.decode(CodableType.self, from: string.data(using: .utf8)!), "Corrupt data did not throw error for json data: \(string)") { err in
                XCTAssertTrue(err is DecodingError, "Decoding threw an error that was not a DecodingError")
            }
        }
    }
    
    func testCodableRawRepresentableAttribute() throws {
        struct Attribute : CodableAttributedStringKey {
            static let name = "MyAttribute"
            enum Value: String, Codable, Hashable {
                case one = "one"
                case two = "two"
                case three = "three"
            }
        }
        
        struct Scope : AttributeScope {
            let attribute: Attribute
        }
        
        struct Object : Codable {
            @CodableConfiguration(from: Scope.self)
            var str = AttributedString()
        }
        
        var str = AttributedString("Test")
        str[Attribute.self] = .two
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(Object(str: str))
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Object.self, from: encoded)
        XCTAssertEqual(decoded.str[Attribute.self], .two)
    }

    func testContainerEncoding() throws {
        struct ContainerContainer : Codable {
            @CodableConfiguration(from: AttributeScopes.TestAttributes.self) var container = AttributeContainer()
        }
        let obj = ContainerContainer(container: AttributeContainer().testInt(1).testBool(true))
        let encoder = JSONEncoder()
        let data = try encoder.encode(obj)
        print(String(data: data, encoding: .utf8)!)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ContainerContainer.self, from: data)

        XCTAssertEqual(obj.container, decoded.container)
    }
    
    func testDefaultAttributesCoding() throws {
        struct DefaultContainer : Codable, Equatable {
            var str : AttributedString
        }
        
        let cont = DefaultContainer(str: AttributedString("Hello", attributes: .init().link(URL(string: "http://apple.com")!)))
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(cont)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DefaultContainer.self, from: encoded)
        XCTAssertEqual(cont, decoded)
    }
    
    func testDecodingMultibyteCharacters() throws {
        let json = "{\"str\": [\"🎺ABC\", {\"TestInt\": 2}]}"
        struct Object : Codable {
            @CodableConfiguration(from: AttributeScopes.TestAttributes.self) var str: AttributedString = AttributedString()
        }
        let decoder = JSONDecoder()
        let str = try decoder.decode(Object.self, from: json.data(using: .utf8)!).str
        XCTAssertEqual(str.runs.count, 1)
        XCTAssertEqual(str.testInt, 2)
        let idx = str.index(beforeCharacter: str.endIndex)
        XCTAssertEqual(str.runs[idx].testInt, 2)
    }
    
    // MARK: - Conversion Tests
    
    func testConversionToObjC() throws {
        var ourString = AttributedString("Hello", attributes: AttributeContainer().testInt(2))
        ourString += AttributedString(" ")
        ourString += AttributedString("World", attributes: AttributeContainer().testString("Courier"))
        let ourObjCString = try NSAttributedString(ourString, including: AttributeScopes.TestAttributes.self)
        let theirString = NSMutableAttributedString(string: "Hello World")
        theirString.addAttributes([.testInt: NSNumber(value: 2)], range: NSMakeRange(0, 5))
        theirString.addAttributes([.testString: "Courier"], range: NSMakeRange(6, 5))
        XCTAssertEqual(theirString, ourObjCString)
    }
    
    func testConversionFromObjC() throws {
        let nsString = NSMutableAttributedString(string: "Hello!")
        let rangeA = NSMakeRange(0, 3)
        let rangeB = NSMakeRange(3, 3)
        nsString.addAttribute(.testString, value: "Courier", range: rangeA)
        nsString.addAttribute(.testBool, value: NSNumber(value: true), range: rangeB)
        let convertedString = try AttributedString(nsString, including: AttributeScopes.TestAttributes.self)
        var string = AttributedString("Hel")
        string.testString = "Courier"
        string += AttributedString("lo!", attributes: AttributeContainer().testBool(true))
        XCTAssertEqual(string, convertedString)
    }
    
    func testRoundTripConversion_boxed() throws {
        struct MyCustomType : Hashable {
            var num: Int
            var str: String
        }
        
        enum MyCustomAttribute : AttributedStringKey {
            typealias Value = MyCustomType
            static let name = "MyCustomAttribute"
        }
        
        struct MyCustomScope : AttributeScope {
            let attr : MyCustomAttribute
        }
        
        let customVal = MyCustomType(num: 2, str: "test")
        var attrString = AttributedString("Hello world")
        attrString[MyCustomAttribute.self] = customVal
        let nsString = try NSAttributedString(attrString, including: MyCustomScope.self)
        let converted = try AttributedString(nsString, including: MyCustomScope.self)
        
        XCTAssertEqual(converted[MyCustomAttribute.self], customVal)
    }

    func testRoundTripConversion_customConversion() throws {
        struct MyCustomType : Hashable { }

        enum MyCustomAttribute : ObjectiveCConvertibleAttributedStringKey {
            typealias Value = MyCustomType
            static let name = "MyCustomAttribute"

            static func objectiveCValue(for value: Value) throws -> NSUUID { NSUUID() }
            static func value(for object: NSUUID) throws -> Value { MyCustomType() }
        }

        struct MyCustomScope : AttributeScope {
            let attr : MyCustomAttribute
        }

        let customVal = MyCustomType()
        var attrString = AttributedString("Hello world")
        attrString[MyCustomAttribute.self] = customVal
        let nsString = try NSAttributedString(attrString, including: MyCustomScope.self)

        XCTAssertTrue(nsString.attribute(.init(MyCustomAttribute.name), at: 0, effectiveRange: nil) is NSUUID)

        let converted = try AttributedString(nsString, including: MyCustomScope.self)
        XCTAssertEqual(converted[MyCustomAttribute.self], customVal)
    }

    func testIncompleteConversionFromObjC() throws {
        struct TestStringAttributeOnly : AttributeScope {
            var testString: AttributeScopes.TestAttributes.TestStringAttribute // Missing TestBoolAttribute
        }

        let nsString = NSMutableAttributedString(string: "Hello!")
        let rangeA = NSMakeRange(0, 3)
        let rangeB = NSMakeRange(3, 3)
        nsString.addAttribute(.testString, value: "Courier", range: rangeA)
        nsString.addAttribute(.testBool, value: NSNumber(value: true), range: rangeB)
        let converted = try AttributedString(nsString, including: TestStringAttributeOnly.self)
        
        var expected = AttributedString("Hel", attributes: AttributeContainer().testString("Courier"))
        expected += AttributedString("lo!")
        XCTAssertEqual(converted, expected)
    }
    
    func testIncompleteConversionToObjC() throws {
        struct TestStringAttributeOnly : AttributeScope {
            var testString: AttributeScopes.TestAttributes.TestStringAttribute // Missing TestBoolAttribute
        }

        var attrStr = AttributedString("Hello ", attributes: .init().testBool(false))
        attrStr += AttributedString("world", attributes: .init().testString("Testing"))
        let converted = try NSAttributedString(attrStr, including: TestStringAttributeOnly.self)
        
        let attrs = converted.attributes(at: 0, effectiveRange: nil)
        XCTAssertFalse(attrs.keys.contains(.testBool))
    }
    
    func testConversionNestedScope() throws {
        struct SuperScope : AttributeScope {
            var subscope : SubScope
            var testString: AttributeScopes.TestAttributes.TestStringAttribute
        }
        
        struct SubScope : AttributeScope {
            var testBool : AttributeScopes.TestAttributes.TestBoolAttribute
        }
        
        let nsString = NSMutableAttributedString(string: "Hello!")
        let rangeA = NSMakeRange(0, 3)
        let rangeB = NSMakeRange(3, 3)
        nsString.addAttribute(.testString, value: "Courier", range: rangeA)
        nsString.addAttribute(.testBool, value: NSNumber(value: true), range: rangeB)
        let converted = try AttributedString(nsString, including: SuperScope.self)
        
        var expected = AttributedString("Hel", attributes: AttributeContainer().testString("Courier"))
        expected += AttributedString("lo!", attributes: AttributeContainer().testBool(true))
        XCTAssertEqual(converted, expected)
    }
    
    func testConversionAttributeContainers() throws {
        let container = AttributeContainer.testInt(2).testDouble(3.1).testString("Hello")
        
        let dictionary = try Dictionary(container, including: \.test)
        let expected: [NSAttributedString.Key: Any] = [
                .testInt: 2,
                .testDouble: 3.1,
                .testString: "Hello"
        ]
        XCTAssertEqual(dictionary.keys, expected.keys)
        XCTAssertEqual(dictionary[.testInt] as! Int, expected[.testInt] as! Int)
        XCTAssertEqual(dictionary[.testDouble] as! Double, expected[.testDouble] as! Double)
        XCTAssertEqual(dictionary[.testString] as! String, expected[.testString] as! String)
        
        let container2 = try AttributeContainer(dictionary, including: \.test)
        XCTAssertEqual(container, container2)
    }
    
    func testConversionFromInvalidObjectiveCValueTypes() throws {
        let nsStr = NSAttributedString(string: "Hello", attributes: [.testInt : "I am not an Int"])
        XCTAssertThrowsError(try AttributedString(nsStr, including: AttributeScopes.TestAttributes.self))
        
        struct ConvertibleAttribute: ObjectiveCConvertibleAttributedStringKey {
            struct Value : Hashable {
                var subValue: String
            }
            typealias ObjectiveCValue = NSString
            static let name = "Convertible"
            
            static func objectiveCValue(for value: Value) throws -> NSString {
                return value.subValue as NSString
            }
            
            static func value(for object: NSString) throws -> Value {
                return Value(subValue: object as String)
            }
        }
        struct Scope : AttributeScope {
            let convertible: ConvertibleAttribute
        }
        
        let nsStr2 = NSAttributedString(string: "Hello", attributes: [NSAttributedString.Key(ConvertibleAttribute.name) : 12345])
        XCTAssertThrowsError(try AttributedString(nsStr2, including: Scope.self))
    }
    
    func testConversionToUTF16() throws {
        // Ensure that we're correctly using UTF16 offsets with NSAS and UTF8 offsets with AS without mixing the two
        let multiByteCharacters = ["\u{2029}", "\u{1D11E}", "\u{1D122}", "\u{1F91A}\u{1F3FB}"]
        
        for str in multiByteCharacters {
            let attrStr = AttributedString(str, attributes: .init().testInt(2))
            let nsStr = NSAttributedString(string: str, attributes: [.testInt: 2])
            
            let convertedAttrStr = try AttributedString(nsStr, including: AttributeScopes.TestAttributes.self)
            XCTAssertEqual(str.utf8.count, convertedAttrStr._guts.runs.first!.length)
            XCTAssertEqual(attrStr, convertedAttrStr)
            
            let convertedNSStr = try NSAttributedString(attrStr, including: AttributeScopes.TestAttributes.self)
            XCTAssertEqual(nsStr, convertedNSStr)
        }
    }
    
    func testConversionWithoutScope() throws {
        // Ensure simple conversion works (no errors when loading AppKit/UIKit/SwiftUI)
        let attrStr = AttributedString()
        let nsStr = NSAttributedString(attrStr)
        XCTAssertEqual(nsStr, NSAttributedString())
        let attrStrReverse = AttributedString(nsStr)
        XCTAssertEqual(attrStrReverse, attrStr)
        
        // Ensure foundation attributes are converted
        let attrStr2 = AttributedString("Hello", attributes: .init().link(URL(string: "http://apple.com")!))
        let nsStr2 = NSAttributedString(attrStr2)
        XCTAssertEqual(nsStr2, NSAttributedString(string: "Hello", attributes: [.link : URL(string: "http://apple.com")! as NSURL]))
        let attrStr2Reverse = AttributedString(nsStr2)
        XCTAssertEqual(attrStr2Reverse, attrStr2)
        
        // Ensure attributes that throw are dropped
        enum Attribute : ObjectiveCConvertibleAttributedStringKey {
            static let name = "TestAttribute"
            typealias Value = Int
            typealias ObjectiveCValue = NSString
            
            static func objectiveCValue(for value: Int) throws -> NSString {
                throw TestError.conversionError
            }
            
            static func value(for object: NSString) throws -> Int {
                throw TestError.conversionError
            }
        }
        
        struct Scope : AttributeScope {
            var test: Attribute
            var other: AttributeScopes.TestAttributes
        }
        
        var container = AttributeContainer()
        container.testInt = 2
        container[Attribute.self] = 3
        let str = AttributedString("Hello", attributes: container)
        let result = try? NSAttributedString(str, attributeTable: Scope.attributeKeyTypes(), options: .dropThrowingAttributes) // The same call that the no-scope initializer will make
        XCTAssertEqual(result, NSAttributedString(string: "Hello", attributes: [NSAttributedString.Key("TestInt") : 2]))
    }
    
    func testConversionWithoutScope_Accessibility() throws {
#if !canImport(Accessibility)
        throw XCTSkip("Unable to import the Accessibility framework")
#else
        let attributedString = AttributedString("Hello", attributes: .init().accessibilityTextCustom(["ABC"]))
        let nsAttributedString = NSAttributedString(attributedString)
        #if os(macOS)
        let attribute = NSAttributedString.Key.accessibilityCustomText
        #else
        let attribute = NSAttributedString.Key.accessibilityTextCustom
        #endif
        XCTAssertEqual(nsAttributedString, NSAttributedString(string: "Hello", attributes: [attribute : ["ABC"]]))
        let attributedStringReverse = AttributedString(nsAttributedString)
        XCTAssertEqual(attributedStringReverse, attributedString)
#endif
    }
    
    func testConversionWithoutScope_AppKit() throws {
#if !canImport(AppKit)
        throw XCTSkip("Unable to import the AppKit framework")
#else
        var container = AttributeContainer()
        container.appKit.kern = 2.3
        let attributedString = AttributedString("Hello", attributes: container)
        let nsAttributedString = NSAttributedString(attributedString)
        XCTAssertEqual(nsAttributedString, NSAttributedString(string: "Hello", attributes: [.kern : CGFloat(2.3)]))
        let attributedStringReverse = AttributedString(nsAttributedString)
        XCTAssertEqual(attributedStringReverse, attributedString)
#endif
    }
    
    func testConversionWithoutScope_UIKit() throws {
#if !canImport(UIKit)
        throw XCTSkip("Unable to import the UIKit framework")
#else
        var container = AttributeContainer()
        container.uiKit.kern = 2.3
        let attributedString = AttributedString("Hello", attributes: container)
        let nsAttributedString = NSAttributedString(attributedString)
        XCTAssertEqual(nsAttributedString, NSAttributedString(string: "Hello", attributes: [.kern : CGFloat(2.3)]))
        let attributedStringReverse = AttributedString(nsAttributedString)
        XCTAssertEqual(attributedStringReverse, attributedString)
#endif
    }
    
    func testConversionWithoutScope_SwiftUI() throws {
#if !canImport(SwiftUI)
        throw XCTSkip("Unable to import the SwiftUI framework")
#else
        var container = AttributeContainer()
        container.swiftUI.kern = 2.3
        let attributedString = AttributedString("Hello", attributes: container)
        let nsAttributedString = NSAttributedString(attributedString)
        XCTAssertEqual(nsAttributedString, NSAttributedString(string: "Hello", attributes: [.init("SwiftUI.Kern") : CGFloat(2.3)]))
        let attributedStringReverse = AttributedString(nsAttributedString)
        XCTAssertEqual(attributedStringReverse, attributedString)
#endif
    }
    
    func testConversionCoalescing() throws {
        let nsStr = NSMutableAttributedString("Hello, world")
        nsStr.setAttributes([.link : NSURL(string: "http://apple.com")!, .testInt : NSNumber(integerLiteral: 2)], range: NSRange(location: 0, length: 6))
        nsStr.setAttributes([.testInt : NSNumber(integerLiteral: 2)], range: NSRange(location: 6, length: 6))
        let attrStr = try AttributedString(nsStr, including: \.test)
        XCTAssertEqual(attrStr.runs.count, 1)
        XCTAssertEqual(attrStr.runs.first!.range, attrStr.startIndex ..< attrStr.endIndex)
        XCTAssertEqual(attrStr.testInt, 2)
        XCTAssertNil(attrStr.link)
    }
    
    func testUnalignedConversion() throws {
        let tests: [(NSRange, Int)] = [
            (NSRange(location: 0, length: 12), 1),
            (NSRange(location: 5, length: 2), 3),
            (NSRange(location: 0, length: 6), 2),
            (NSRange(location: 5, length: 1), 3),
            (NSRange(location: 6, length: 1), 1),
            (NSRange(location: 6, length: 2), 3),
            (NSRange(location: 6, length: 6), 2)
        ]
        
        for test in tests {
            // U+1F3BA Trumpet (represented by a UTF-16 surrogate pair)
            let nsAttributedString = NSMutableAttributedString("Test \u{1F3BA} Test")
            nsAttributedString.addAttribute(.testInt, value: NSNumber(1), range: test.0)
            let attrStr = try AttributedString(nsAttributedString, including: \.test)
            XCTAssertEqual(attrStr.runs.count, test.1, "Replacement of range \(NSStringFromRange(test.0)) caused a run count of \(attrStr.runs.count)")
        }
    }
    
#endif // FOUNDATION_FRAMEWORK

    // MARK: - View Tests

    func testCharViewIndexing_backwardsFromEndIndex() {
        let testString = AttributedString("abcdefghi")
        let testChars = testString.characters
        let testIndex = testChars.index(testChars.endIndex, offsetBy: -1)
        XCTAssertEqual(testChars[testIndex], "i")
    }

    func testAttrViewIndexing() {
        var attrStr = AttributedString("A")
        attrStr += "B"
        attrStr += "C"
        attrStr += "D"

        let attrStrRuns = attrStr.runs

        var i = 0
        var curIdx = attrStrRuns.startIndex
        while curIdx < attrStrRuns.endIndex {
            i += 1
            curIdx = attrStrRuns.index(after: curIdx)
        }
        XCTAssertEqual(i, 1)
        XCTAssertEqual(attrStrRuns.count, 1)
    }
    
    func testUnicodeScalarsViewIndexing() {
        let attrStr = AttributedString("Cafe\u{301}", attributes: AttributeContainer().testInt(1))
        let unicode = attrStr.unicodeScalars
        XCTAssertEqual(unicode[unicode.index(before: unicode.endIndex)], "\u{301}")
        XCTAssertEqual(unicode[unicode.index(unicode.endIndex, offsetBy: -2)], "e")
    }

    func testCharacterSlicing() {
        let a: AttributedString = "\u{1f1fa}\u{1f1f8}" // Regional indicators U & S
        let i = a.unicodeScalars.index(after: a.startIndex)
        let b = a.characters[..<i]
        XCTAssertEqual(a.characters.count, 1)
        XCTAssertEqual(b.startIndex, a.startIndex)
        XCTAssertEqual(b.endIndex, a.startIndex)
        XCTAssertEqual(b.count, 0)
    }

    func testCharacterSlicing_RangeExpressions() {
        // Make sure `AttributedString` and `String` produce consistent results when slicing,
        // for every range expression, whether or not the bounds fall on `Character` boundaries.
        //
        // (SE-0180 mistakenly prevented `String` from rounding down indices to Character boundaries
        // when slicing, and `AttributedString` has to emulate that choice. However,
        // `AttributedSubstring` (intentionally, and unavoidably) has to round down the boundaries
        // of its character view -- so we expect some differences when comparing `characters`.
        // The substring's `unicodeScalars` view always gives us the precise original boundaries.)

        let str = "F\u{301}a\u{308}n\u{303}c\u{327}y\u{30a}" // "F́äñçẙ"
        let astr = AttributedString(str)

        func check<T: Equatable>(
            _ a: some Sequence<T>,
            _ b: some Sequence<T>,
            file: StaticString = #file, line: UInt = #line
        ) {
            XCTAssertTrue(
                a.elementsEqual(b),
                "'\(Array(a))' does not equal '\(Array(b))'",
                file: file, line: line)
        }

        check(str, astr.characters)
        check(str.unicodeScalars, astr.unicodeScalars)

        // Go through all valid range expressions within the two strings and compare slicing
        // results.
        var i1 = str.unicodeScalars.startIndex
        var i2 = astr.unicodeScalars.startIndex
        while true {
            check(str[..<i1].unicodeScalars, astr[..<i2].unicodeScalars)
            check(str[i1...].unicodeScalars, astr[i2...].unicodeScalars)

            var j1 = i1
            var j2 = i2
            while true {
                check(str[i1..<j1].unicodeScalars, astr[i2..<j2].unicodeScalars)

                if j1 == str.endIndex { break }

                check(str[i1...j1].unicodeScalars, astr[i2...j2].unicodeScalars)

                str.unicodeScalars.formIndex(after: &j1)
                j2 = astr.index(afterUnicodeScalar: j2)
            }

            if i1 == str.endIndex { break }

            check(str[...i1].unicodeScalars, astr[...i2].unicodeScalars)

            str.unicodeScalars.formIndex(after: &i1)
            i2 = astr.index(afterUnicodeScalar: i2)
        }
    }

    func testUnicodeScalarsSlicing() {
        let attrStr = AttributedString("Cafe\u{301}", attributes: AttributeContainer().testInt(1))
        let range = attrStr.startIndex ..< attrStr.endIndex
        let substringScalars = attrStr[range].unicodeScalars
        let slicedScalars = attrStr.unicodeScalars[range]
        
        let expected: [UnicodeScalar] = ["C", "a", "f", "e", "\u{301}"]
        XCTAssertEqual(substringScalars.count, expected.count)
        XCTAssertEqual(slicedScalars.count, expected.count)
        var indexA = substringScalars.startIndex
        var indexB = slicedScalars.startIndex
        var indexExpect = expected.startIndex
        while indexA != substringScalars.endIndex && indexB != slicedScalars.endIndex {
            XCTAssertEqual(substringScalars[indexA], expected[indexExpect])
            XCTAssertEqual(slicedScalars[indexB], expected[indexExpect])
            indexA = substringScalars.index(after: indexA)
            indexB = slicedScalars.index(after: indexB)
            indexExpect = expected.index(after: indexExpect)
        }
    }
    
    func testProtocolRunIndexing() {
        var str = AttributedString("Foo", attributes: .init().testInt(1))
        str += AttributedString("Bar", attributes: .init().testInt(2))
        str += AttributedString("Baz", attributes: .init().testInt(3))

        let runIndices = str.runs.map(\.range.lowerBound) + [str.endIndex]
        
        for (i, index) in runIndices.enumerated().dropLast() {
            XCTAssertEqual(str.index(afterRun: index), runIndices[i + 1])
        }
        
        for (i, index) in runIndices.enumerated().reversed().dropLast() {
            XCTAssertEqual(str.index(beforeRun: index), runIndices[i - 1])
        }
        
        for (i, a) in runIndices.enumerated() {
            for (j, b) in runIndices.enumerated() {
                XCTAssertEqual(str.index(a, offsetByRuns: j - i), b)
            }
        }
    }

    // MARK: - Other Tests
    
    func testInitWithSequence() {
        let expected = AttributedString("Hello World", attributes: AttributeContainer().testInt(2))
        let sequence: [Character] = ["H", "e", "l", "l", "o", " ", "W", "o", "r", "l", "d"]
        
        let container = AttributeContainer().testInt(2)
        let attrStr = AttributedString(sequence, attributes: container)
        XCTAssertEqual(attrStr, expected)
        
        let attrStr2 = AttributedString(sequence, attributes: AttributeContainer().testInt(2))
        XCTAssertEqual(attrStr2, expected)
        
        let attrStr3 = AttributedString(sequence, attributes: AttributeContainer().testInt(2))
        XCTAssertEqual(attrStr3, expected)
    }
    
    func testLongestEffectiveRangeOfAttribute() {
        var str = AttributedString("Abc")
        str += AttributedString("def", attributes: AttributeContainer.testInt(2).testString("World"))
        str += AttributedString("ghi", attributes: AttributeContainer.testInt(2).testBool(true))
        str += AttributedString("jkl", attributes: AttributeContainer.testInt(2).testDouble(3.0))
        str += AttributedString("mno", attributes: AttributeContainer.testString("Hello"))
        
        let idx = str.characters.index(str.startIndex, offsetBy: 7)
        let expectedRange = str.characters.index(str.startIndex, offsetBy: 3) ..< str.characters.index(str.startIndex, offsetBy: 12)
        let (value, range) = str.runs[\.testInt][idx]
        
        XCTAssertEqual(value, 2)
        XCTAssertEqual(range, expectedRange)
    }
    
    func testAttributeContainer() {
        var container = AttributeContainer().testBool(true).testInt(1)
        XCTAssertEqual(container.testBool, true)
        XCTAssertNil(container.testString)

        let attrString = AttributedString("Hello", attributes: container)
        for run in attrString.runs {
            XCTAssertEqual("Hello", String(attrString.characters[run.range]))
            XCTAssertEqual(run.testBool, true)
            XCTAssertEqual(run.testInt, 1)
        }

        container.testBool = nil
        XCTAssertNil(container.testBool)
    }
    
    func testAttributeContainerEquality() {
        let containerA = AttributeContainer().testInt(2).testString("test")
        let containerB = AttributeContainer().testInt(2).testString("test")
        let containerC = AttributeContainer().testInt(3).testString("test")
        let containerD = AttributeContainer.testInt(4)
        var containerE = AttributeContainer()
        containerE.testInt = 4
        
        XCTAssertEqual(containerA, containerB)
        XCTAssertNotEqual(containerB, containerC)
        XCTAssertNotEqual(containerC, containerD)
        XCTAssertEqual(containerD, containerE)
    }

    func testAttributeContainerSetOnSubstring() {
        let container = AttributeContainer().testBool(true).testInt(1)

        var attrString = AttributedString("Hello world", attributes: container)

        let container2 = AttributeContainer().testString("yellow")
        attrString[attrString.startIndex..<attrString.characters.index(attrString.startIndex, offsetBy: 4)].setAttributes(container2)

        let runs = attrString.runs
        let run = runs[ runs.startIndex ]
        XCTAssertEqual(String(attrString.characters[run.range]), "Hell")
        XCTAssertEqual(run.testString, "yellow")
    }

    func testSlice() {
        let attrStr = AttributedString("Hello World")
        let chars = attrStr.characters
        let start = chars.index(chars.startIndex, offsetBy: 6)
        let slice = attrStr[start ..< chars.index(start, offsetBy:5)]
        XCTAssertEqual(AttributedString(slice), AttributedString("World"))
    }

    func testCreateStringsFromCharactersWithUnicodeScalarIndexes() {
        var attrStr = AttributedString("Caf", attributes: AttributeContainer().testString("a"))
        attrStr += AttributedString("e", attributes: AttributeContainer().testString("b"))
        attrStr += AttributedString("\u{301}", attributes: AttributeContainer().testString("c"))

        // We can use the Unicode scalars view to process sub-character range boundaries.
        let strs1 = attrStr.runs.map {
            String(String.UnicodeScalarView(attrStr.unicodeScalars[$0.range]))
        }
        XCTAssertEqual(strs1, ["Caf", "e", "\u{301}"])

        // The characters view rounds indices down to the nearest character boundary.
        let strs2 = attrStr.runs.map { String(attrStr.characters[$0.range]) }
        XCTAssertEqual(strs2, ["Caf", "", "e\u{301}"])
    }

    func testSettingAttributeOnSlice() throws {
        var attrString = AttributedString("This is a string.")
        var range = attrString.startIndex ..< attrString.characters.index(attrString.startIndex, offsetBy: 1)
        var myInt = 1
        while myInt < 6 {
            // ???: Do we want .set(_: KeyValuePair)?
            // Do it twice to force both the set and replace paths.
            attrString[range].testInt = myInt
            attrString[range].testInt = myInt + 7
            myInt += 1
            range = range.upperBound ..< attrString.characters.index(after: range.upperBound)
        }

        myInt = 8
        for (attribute, _) in attrString.runs[\.testInt] {
            if let value = attribute {
                XCTAssertEqual(myInt, value)
                myInt += 1
            }
        }

        var newAttrString = attrString
        newAttrString.testInt = nil

        for (attribute, _) in newAttrString.runs[\.testInt] {
            XCTAssertEqual(attribute, nil)
        }

        let startIndex = attrString.startIndex
        attrString.characters[startIndex] = "D"
        XCTAssertEqual(attrString.characters[startIndex], "D")
    }

    func testExpressibleByStringLiteral() {
        let variable : AttributedString = "Test"
        XCTAssertEqual(variable, AttributedString("Test"))

        func takesAttrStr(_ str: AttributedString) {
            XCTAssertEqual(str, AttributedString("Test"))
        }
        takesAttrStr("Test")
    }
    
    func testHashing() {
        let attrStr = AttributedString("Hello, world.", attributes: .init().testInt(2).testBool(false))
        let attrStr2 = AttributedString("Hello, world.", attributes: .init().testInt(2).testBool(false))
        
        var dictionary = [
            attrStr : 123
        ]
        
        dictionary[attrStr2] = 456
        
        XCTAssertEqual(attrStr, attrStr2)
        XCTAssertEqual(dictionary[attrStr], 456)
        XCTAssertEqual(dictionary[attrStr2], 456)
    }
    
    func testHashingSubstring() {
        let a: AttributedString = "aXa"
        let b: AttributedString = "bXb"

        let i1 = a.characters.index(a.startIndex, offsetBy: 1)
        let i2 = a.characters.index(a.startIndex, offsetBy: 2)

        let j1 = b.characters.index(b.startIndex, offsetBy: 1)
        let j2 = b.characters.index(b.startIndex, offsetBy: 2)

        let substrA = a[i1 ..< i2]
        let substrB = b[j1 ..< j2]

        XCTAssertEqual(substrA, substrB)
        
        var hasherA = Hasher()
        hasherA.combine(substrA)
        var hasherB = Hasher()
        hasherB.combine(substrB)
        XCTAssertEqual(hasherA.finalize(), hasherB.finalize())
    }
    
    func testHashingContainer() {
        let containerA = AttributeContainer.testInt(2).testBool(false)
        let containerB = AttributeContainer.testInt(2).testBool(false)
        
        var dictionary = [
            containerA : 123
        ]
        
        dictionary[containerB] = 456
        
        XCTAssertEqual(containerA, containerB)
        XCTAssertEqual(dictionary[containerA], 456)
        XCTAssertEqual(dictionary[containerB], 456)
    }
    
    func testUTF16String() {
        let multiByteCharacters = ["\u{2029}", "\u{1D11E}", "\u{1D122}", "\u{1F91A}\u{1F3FB}"]
        
        for str in multiByteCharacters {
            var attrStr = AttributedString("A" + str)
            attrStr += AttributedString("B", attributes: .init().testInt(2))
            attrStr += AttributedString("C", attributes: .init().testInt(3))
            XCTAssertTrue(attrStr == attrStr)
            XCTAssertTrue(attrStr.runs == attrStr.runs)
        }
    }

    func testPlusOperators() {
        let ab = AttributedString("a") + AttributedString("b")
        XCTAssertEqual(ab, AttributedString("ab"))

        let ab_sub = AttributedString("a") + ab[ab.characters.index(before: ab.endIndex) ..< ab.endIndex]
        XCTAssertEqual(ab_sub, ab)

        let ab_lit = AttributedString("a") + "b"
        XCTAssertEqual(ab_lit, ab)

        var abc = ab
        abc += AttributedString("c")
        XCTAssertEqual(abc, AttributedString("abc"))

        var abc_sub = ab
        abc_sub += abc[abc.characters.index(before: abc.endIndex) ..< abc.endIndex]
        XCTAssertEqual(abc_sub, abc)

        var abc_lit = ab
        abc_lit += "c"
        XCTAssertEqual(abc_lit, abc)
    }

    func testSearch() {
        let testString = AttributedString("abcdefghi")
        XCTAssertNil(testString.range(of: "baba"))

        let abc = testString.range(of: "abc")!
        XCTAssertEqual(abc.lowerBound, testString.startIndex)
        XCTAssertEqual(String(testString[abc].characters), "abc")

        let def = testString.range(of: "def")!
        XCTAssertEqual(def.lowerBound, testString.index(testString.startIndex, offsetByCharacters: 3))
        XCTAssertEqual(String(testString[def].characters), "def")

        let ghi = testString.range(of: "ghi")!
        XCTAssertEqual(ghi.lowerBound, testString.index(testString.startIndex, offsetByCharacters: 6))
        XCTAssertEqual(String(testString[ghi].characters), "ghi")

        XCTAssertNil(testString.range(of: "ghij"))

        let substring = testString[testString.index(afterCharacter: testString.startIndex)..<testString.endIndex]
        XCTAssertNil(substring.range(of: "abc"))

        let BcD = testString.range(of: "BcD", options: [.caseInsensitive])!
        XCTAssertEqual(BcD.lowerBound, testString.index(testString.startIndex, offsetByCharacters: 1))
        XCTAssertEqual(String(testString[BcD].characters), "bcd");

        let ghi_backwards = testString.range(of: "ghi", options: [.backwards])!
        XCTAssertEqual(ghi_backwards.lowerBound, testString.index(testString.startIndex, offsetByCharacters: 6))
        XCTAssertEqual(String(testString[ghi_backwards].characters), "ghi")

        let abc_backwards = testString.range(of: "abc", options: [.backwards])!
        XCTAssertEqual(abc_backwards.lowerBound, testString.startIndex)
        XCTAssertEqual(String(testString[abc_backwards].characters), "abc")

        let abc_anchored = testString.range(of: "abc", options: [.anchored])!
        XCTAssertEqual(abc_anchored.lowerBound, testString.startIndex)
        XCTAssertEqual(String(testString[abc_anchored].characters), "abc")

        let ghi_anchored = testString.range(of: "ghi", options: [.backwards, .anchored])!
        XCTAssertEqual(ghi_anchored.lowerBound, testString.index(testString.startIndex, offsetByCharacters: 6))
        XCTAssertEqual(String(testString[ghi_anchored].characters), "ghi")

        XCTAssertNil(testString.range(of: "bcd", options: [.anchored]))
        XCTAssertNil(testString.range(of: "abc", options: [.anchored, .backwards]))
    }

    func testSubstringSearch() {
        let fullString = AttributedString("___abcdefghi___")
        let testString = fullString[ fullString.range(of: "abcdefghi")! ]
        XCTAssertNil(testString.range(of: "baba"))

        let abc = testString.range(of: "abc")!
        XCTAssertEqual(abc.lowerBound, testString.startIndex)
        XCTAssertEqual(String(testString[abc].characters), "abc")

        let def = testString.range(of: "def")!
        XCTAssertEqual(def.lowerBound, testString.index(testString.startIndex, offsetByCharacters: 3))
        XCTAssertEqual(String(testString[def].characters), "def")

        let ghi = testString.range(of: "ghi")!
        XCTAssertEqual(ghi.lowerBound, testString.index(testString.startIndex, offsetByCharacters: 6))
        XCTAssertEqual(String(testString[ghi].characters), "ghi")

        XCTAssertNil(testString.range(of: "ghij"))

        let substring = testString[testString.index(afterCharacter: testString.startIndex)..<testString.endIndex]
        XCTAssertNil(substring.range(of: "abc"))

        let BcD = testString.range(of: "BcD", options: [.caseInsensitive])!
        XCTAssertEqual(BcD.lowerBound, testString.index(testString.startIndex, offsetByCharacters: 1))
        XCTAssertEqual(String(testString[BcD].characters), "bcd");

        let ghi_backwards = testString.range(of: "ghi", options: [.backwards])!
        XCTAssertEqual(ghi_backwards.lowerBound, testString.index(testString.startIndex, offsetByCharacters: 6))
        XCTAssertEqual(String(testString[ghi_backwards].characters), "ghi")

        let abc_backwards = testString.range(of: "abc", options: [.backwards])!
        XCTAssertEqual(abc_backwards.lowerBound, testString.startIndex)
        XCTAssertEqual(String(testString[abc_backwards].characters), "abc")

        let abc_anchored = testString.range(of: "abc", options: [.anchored])!
        XCTAssertEqual(abc_anchored.lowerBound, testString.startIndex)
        XCTAssertEqual(String(testString[abc_anchored].characters), "abc")

        let ghi_anchored = testString.range(of: "ghi", options: [.backwards, .anchored])!
        XCTAssertEqual(ghi_anchored.lowerBound, testString.index(testString.startIndex, offsetByCharacters: 6))
        XCTAssertEqual(String(testString[ghi_anchored].characters), "ghi")

        XCTAssertNil(testString.range(of: "bcd", options: [.anchored]))
        XCTAssertNil(testString.range(of: "abc", options: [.anchored, .backwards]))
    }

    func testIndexConversion() {
        let attrStr = AttributedString("ABCDE")
        let str = "ABCDE"

        let attrStrIdx = attrStr.index(attrStr.startIndex, offsetByCharacters: 2)
        XCTAssertEqual(attrStr.characters[attrStrIdx], "C")

        let strIdx = String.Index(attrStrIdx, within: str)!
        XCTAssertEqual(str[strIdx], "C")

        let reconvertedAttrStrIdex = AttributedString.Index(strIdx, within: attrStr)!
        XCTAssertEqual(attrStr.characters[reconvertedAttrStrIdex], "C")
    }
    
#if FOUNDATION_FRAMEWORK

    func testRangeConversion() {
        let attrStr = AttributedString("ABCDE")
        let nsAS = NSAttributedString("ABCDE")
        let str = "ABCDE"

        let attrStrR = attrStr.range(of: "BCD")!
        let strR = Range(attrStrR, in: str)!
        let nsASR = NSRange(attrStrR, in: attrStr)

        XCTAssertEqual(nsAS.attributedSubstring(from: nsASR).string, "BCD")
        XCTAssertEqual(str[strR], "BCD")

        let attrStrR_reconverted1 = Range(strR, in: attrStr)!
        let attrStrR_reconverted2 = Range(nsASR, in: attrStr)!
        XCTAssertEqual(String(attrStr[attrStrR_reconverted1].characters), "BCD")
        XCTAssertEqual(String(attrStr[attrStrR_reconverted2].characters), "BCD")
    }
    
    func testUnalignedRangeConversion() {
        do {
            // U+0301 Combining Acute Accent (one unicode scalar, one UTF-16)
            let str = "Test Cafe\u{301} Test"
            let attrStr = AttributedString(str)
            let nsRange = NSRange(location: 8, length: 1) // Just the "e" without the accent
            
            let strRange = Range<String.Index>(nsRange, in: str)
            XCTAssertNotNil(strRange)
            XCTAssertEqual(strRange, str.unicodeScalars.index(str.startIndex, offsetBy: 8) ..< str.unicodeScalars.index(str.startIndex, offsetBy: 9))
            XCTAssertEqual(str[strRange!], "e")
            
            var attrStrRange = Range<AttributedString.Index>(nsRange, in: attrStr)
            XCTAssertNotNil(attrStrRange)
            XCTAssertEqual(attrStrRange, attrStr.unicodeScalars.index(attrStr.startIndex, offsetBy: 8) ..< attrStr.unicodeScalars.index(attrStr.startIndex, offsetBy: 9))
            XCTAssertEqual(AttributedString(attrStr[attrStrRange!]), AttributedString("e"))
            
            attrStrRange = Range<AttributedString.Index>(strRange!, in: attrStr)
            XCTAssertNotNil(attrStrRange)
            XCTAssertEqual(attrStrRange, attrStr.unicodeScalars.index(attrStr.startIndex, offsetBy: 8) ..< attrStr.unicodeScalars.index(attrStr.startIndex, offsetBy: 9))
            XCTAssertEqual(AttributedString(attrStr[attrStrRange!]), AttributedString("e"))
            
            XCTAssertEqual(NSRange(strRange!, in: str), nsRange)
            XCTAssertEqual(NSRange(attrStrRange!, in: attrStr), nsRange)
            XCTAssertEqual(Range<String.Index>(attrStrRange!, in: str), strRange!)
        }
        
        do {
            // U+1F3BA Trumpet (one unicode scalar, two UTF-16)
            let str = "Test \u{1F3BA}\u{1F3BA} Test"
            let attrStr = AttributedString(str)
            let nsRange = NSRange(location: 5, length: 3) // The whole first U+1F3BA and the leading surrogate character of the second U+1F3BA
            
            let strRange = Range<String.Index>(nsRange, in: str)
            XCTAssertNotNil(strRange)
            XCTAssertEqual(str[strRange!], "\u{1F3BA}")
            
            var attrStrRange = Range<AttributedString.Index>(nsRange, in: attrStr)
            XCTAssertNotNil(attrStrRange)
            XCTAssertEqual(AttributedString(attrStr[attrStrRange!]), AttributedString("\u{1F3BA}"))
            
            attrStrRange = Range<AttributedString.Index>(strRange!, in: attrStr)
            XCTAssertNotNil(attrStrRange)
            XCTAssertEqual(AttributedString(attrStr[attrStrRange!]), AttributedString("\u{1F3BA}"))
            
            XCTAssertEqual(NSRange(strRange!, in: str), nsRange)
            XCTAssertEqual(NSRange(attrStrRange!, in: attrStr), nsRange)
            XCTAssertEqual(Range<String.Index>(attrStrRange!, in: str), strRange!)
        }
    }
    
#endif // FOUNDATION_FRAMEWORK
    
    func testOOBRangeConversion() {
        let attrStr = AttributedString("")
        let str = "Hello"
        let range = str.index(before: str.endIndex) ..< str.endIndex
        XCTAssertNil(Range<AttributedString.Index>(range, in: attrStr))
    }
    
#if FOUNDATION_FRAMEWORK
    // TODO: Support scope-specific AttributedString initialization in FoundationPreview
    func testScopedCopy() {
        var str = AttributedString("A")
        str += AttributedString("B", attributes: .init().testInt(2))
        str += AttributedString("C", attributes: .init().link(URL(string: "http://apple.com")!))
        str += AttributedString("D", attributes: .init().testInt(3).link(URL(string: "http://apple.com")!))
        
        struct FoundationAndTest : AttributeScope {
            let foundation: AttributeScopes.FoundationAttributes
            let test: AttributeScopes.TestAttributes
        }
        XCTAssertEqual(AttributedString(str, including: FoundationAndTest.self), str)
        
        struct None : AttributeScope {
            
        }
        XCTAssertEqual(AttributedString(str, including: None.self), AttributedString("ABCD"))
        
        var expected = AttributedString("AB")
        expected += AttributedString("CD", attributes: .init().link(URL(string: "http://apple.com")!))
        XCTAssertEqual(AttributedString(str, including: \.foundation), expected)
        
        expected = AttributedString("A")
        expected += AttributedString("B", attributes: .init().testInt(2))
        expected += "C"
        expected += AttributedString("D", attributes: .init().testInt(3))
        XCTAssertEqual(AttributedString(str, including: \.test), expected)
        
        let range = str.index(afterCharacter: str.startIndex) ..< str.index(beforeCharacter: str.endIndex)
        expected = AttributedString("B", attributes: .init().testInt(2)) + "C"
        XCTAssertEqual(AttributedString(str[range], including: \.test), expected)
        
        expected = "B" + AttributedString("C", attributes: .init().link(URL(string: "http://apple.com")!))
        XCTAssertEqual(AttributedString(str[range], including: \.foundation), expected)
        
        XCTAssertEqual(AttributedString(str[range], including: None.self), AttributedString("BC"))
    }
#endif // FOUNDATION_FRAMEWORK

    func testAssignDifferentSubstring() {
        var attrStr1 = AttributedString("ABCDE")
        let attrStr2 = AttributedString("XYZ")

        attrStr1[ attrStr1.range(of: "BCD")! ] = attrStr2[ attrStr2.range(of: "X")! ]

        XCTAssertEqual(attrStr1, "AXE")
    }

    func testCOWDuringSubstringMutation() {
        func frobnicate(_ sub: inout AttributedSubstring) {
            var new = sub
            new.testInt = 2
            new.testString = "Hello"
            sub = new
        }
        var attrStr = AttributedString("ABCDE")
        frobnicate(&attrStr[ attrStr.range(of: "BCD")! ])

        let expected = AttributedString("A") + AttributedString("BCD", attributes: .init().testInt(2).testString("Hello")) + AttributedString("E")
        XCTAssertEqual(attrStr, expected)
    }

#if false // This causes an intentional fatalError(), which we can't test for yet, so unfortunately this test can't be enabled.
    func testReassignmentDuringMutation() {
        func frobnicate(_ sub: inout AttributedSubstring) {
            let other = AttributedString("XYZ")
            sub = other[ other.range(of: "X")! ]
        }
        var attrStr = AttributedString("ABCDE")
        frobnicate(&attrStr[ attrStr.range(of: "BCD")! ])

        XCTAssertEqual(attrStr, "AXE")
    }
#endif

    func testAssignDifferentCharacterView() {
        var attrStr1 = AttributedString("ABC", attributes: .init().testInt(1)) + AttributedString("DE", attributes: .init().testInt(3))
        let attrStr2 = AttributedString("XYZ", attributes: .init().testInt(2))

        attrStr1.characters = attrStr2.characters
        XCTAssertEqual(attrStr1, AttributedString("XYZ", attributes: .init().testInt(1)))
    }

    func testCOWDuringCharactersMutation() {
        func frobnicate(_ chars: inout AttributedString.CharacterView) {
            var new = chars
            new.replaceSubrange(chars.startIndex ..< chars.endIndex, with: "XYZ")
            chars = new
        }
        var attrStr = AttributedString("ABCDE", attributes: .init().testInt(1))
        frobnicate(&attrStr.characters)

        XCTAssertEqual(attrStr, AttributedString("XYZ", attributes: .init().testInt(1)))
    }

    func testAssignDifferentUnicodeScalarView() {
        var attrStr1 = AttributedString("ABC", attributes: .init().testInt(1)) + AttributedString("DE", attributes: .init().testInt(3))
        let attrStr2 = AttributedString("XYZ", attributes: .init().testInt(2))

        attrStr1.unicodeScalars = attrStr2.unicodeScalars
        XCTAssertEqual(attrStr1, AttributedString("XYZ", attributes: .init().testInt(1)))
    }

    func testCOWDuringUnicodeScalarsMutation() {
        func frobnicate(_ chars: inout AttributedString.CharacterView) {
            var new = chars
            new.replaceSubrange(chars.startIndex ..< chars.endIndex, with: "XYZ")
            chars = new
        }
        var attrStr = AttributedString("ABCDE", attributes: .init().testInt(1))
        frobnicate(&attrStr.characters)

        XCTAssertEqual(attrStr, AttributedString("XYZ", attributes: .init().testInt(1)))
    }
}
