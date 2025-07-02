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
#endif

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
#endif

/// Regression and coverage tests for `AttributedString` and its associated objects
@Suite("AttributedString")
private struct  AttributedStringTests {
    // MARK: - Enumeration Tests

    @available(FoundationAttributedString 5.5, *)
    @Test func emptyEnumeration() {
        for _ in AttributedString().runs {
            Issue.record("Empty AttributedString should not enumerate any attributes")
        }
        
        do {
            let str = AttributedString("Foo")
            for _ in str[str.startIndex ..< str.startIndex].runs {
                Issue.record("Empty AttributedSubstring should not enumerate any attributes")
            }
        }
        
        do {
            let str = AttributedString("Foo", attributes: AttributeContainer.testInt(2))
            let i = str.index(afterCharacter: str.startIndex)
            for _ in str[i ..< i].runs {
                Issue.record("Empty AttributedSubstring should not enumerate any attributes")
            }
        }
    }

    @available(FoundationAttributedString 5.5, *)
    func verifyAttributes<T>(_ runs: AttributedString.Runs.AttributesSlice1<T>, string: AttributedString, expectation: [(String, T.Value?)], sourceLocation: SourceLocation = #_sourceLocation) where T.Value : Sendable {
        // Test that the attribute is correct when iterating through attribute runs
        var expectIterator = expectation.makeIterator()
        for (attribute, range) in runs {
            guard let expected = expectIterator.next() else {
                Issue.record("Additional runs found but not expected", sourceLocation: sourceLocation)
                break
            }
            #expect(String(string[range].characters) == expected.0, "Substring of AttributedString characters for range of run did not match expectation", sourceLocation: sourceLocation)
            #expect(attribute == expected.1, "Attribute of run did not match expectation", sourceLocation: sourceLocation)
        }
        #expect(expectIterator.next() == nil, "Additional runs expected but not found", sourceLocation: sourceLocation)

        // Test that the attribute is correct when iterating through reversed attribute runs
        expectIterator = expectation.reversed().makeIterator()
        for (attribute, range) in runs.reversed() {
            guard let expected = expectIterator.next() else {
                Issue.record("Additional reversed runs found but not expected", sourceLocation: sourceLocation)
                break
            }
            #expect(String(string[range].characters) == expected.0, "Substring of AttributedString characters for range of run did not match expectation", sourceLocation: sourceLocation)
            #expect(attribute == expected.1, "Attribute of run did not match expectation", sourceLocation: sourceLocation)
        }
        #expect(expectIterator.next() == nil, "Additional runs expected but not found", sourceLocation: sourceLocation)
    }

    @available(FoundationAttributedString 5.5, *)
    func verifyAttributes<T, U>(_ runs: AttributedString.Runs.AttributesSlice2<T, U>, string: AttributedString, expectation: [(String, T.Value?, U.Value?)], sourceLocation: SourceLocation = #_sourceLocation) where T.Value : Sendable, U.Value : Sendable {
        // Test that the attributes are correct when iterating through attribute runs
        var expectIterator = expectation.makeIterator()
        for (attribute, attribute2, range) in runs {
            guard let expected = expectIterator.next() else {
                Issue.record("Additional runs found but not expected", sourceLocation: sourceLocation)
                break
            }
            #expect(String(string[range].characters) == expected.0, "Substring of AttributedString characters for range of run did not match expectation", sourceLocation: sourceLocation)
            #expect(attribute == expected.1, "Attribute of run did not match expectation", sourceLocation: sourceLocation)
            #expect(attribute2 == expected.2, "Attribute of run did not match expectation", sourceLocation: sourceLocation)
        }
        #expect(expectIterator.next() == nil, "Additional runs expected but not found", sourceLocation: sourceLocation)

        // Test that the attributes are correct when iterating through reversed attribute runs
        expectIterator = expectation.reversed().makeIterator()
        for (attribute, attribute2, range) in runs.reversed() {
            guard let expected = expectIterator.next() else {
                Issue.record("Additional reversed runs found but not expected", sourceLocation: sourceLocation)
                break
            }
            #expect(String(string[range].characters) == expected.0, "Substring of AttributedString characters for range of run did not match expectation", sourceLocation: sourceLocation)
            #expect(attribute == expected.1, "Attribute of run did not match expectation", sourceLocation: sourceLocation)
            #expect(attribute2 == expected.2, "Attribute of run did not match expectation", sourceLocation: sourceLocation)
        }
        #expect(expectIterator.next() == nil, "Additional runs expected but not found", sourceLocation: sourceLocation)
    }
    
#if FOUNDATION_FRAMEWORK
    func verifyAttributes(_ runs: AttributedString.Runs.NSAttributesSlice, string: AttributedString, expectation: [(String, AttributeContainer)], sourceLocation: SourceLocation = #_sourceLocation) {
        // Test that the attribute is correct when iterating through attribute runs
        var expectIterator = expectation.makeIterator()
        for (attribute, range) in runs {
            guard let expected = expectIterator.next() else {
                Issue.record("Additional runs found but not expected", sourceLocation: sourceLocation)
                break
            }
            #expect(String(string[range].characters) == expected.0, "Substring of AttributedString characters for range of run did not match expectation", sourceLocation: sourceLocation)
            #expect(attribute == expected.1, "Attribute of run did not match expectation", sourceLocation: sourceLocation)
        }
        #expect(expectIterator.next() == nil, "Additional runs expected but not found", sourceLocation: sourceLocation)

        // Test that the attribute is correct when iterating through reversed attribute runs
        expectIterator = expectation.reversed().makeIterator()
        for (attribute, range) in runs.reversed() {
            guard let expected = expectIterator.next() else {
                Issue.record("Additional reversed runs found but not expected", sourceLocation: sourceLocation)
                break
            }
            #expect(String(string[range].characters) == expected.0, "Substring of AttributedString characters for range of run did not match expectation", sourceLocation: sourceLocation)
            #expect(attribute == expected.1, "Attribute of run did not match expectation", sourceLocation: sourceLocation)
        }
        #expect(expectIterator.next() == nil, "Additional runs expected but not found", sourceLocation: sourceLocation)
    }
#endif // FOUNDATION_FRAMEWORK

    @available(FoundationAttributedString 5.5, *)
    @Test func simpleEnumeration() throws {
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testInt(1))
        attrStr += " "
        attrStr += AttributedString("World", attributes: AttributeContainer().testDouble(2.0))

        let expectation = [("Hello", 1, nil), (" ", nil, nil), ("World", nil, 2.0)]
        var expectationIterator = expectation.makeIterator()
        for run in attrStr.runs {
            guard let expected = expectationIterator.next() else {
                Issue.record("Found extra unexpected runs")
                break
            }
            #expect(String(attrStr[run.range].characters) == expected.0)
            #expect(run.testInt == expected.1)
            #expect(run.testDouble == expected.2)
            #expect(run.testString == nil)
        }
        #expect(expectationIterator.next() == nil)

        expectationIterator = expectation.reversed().makeIterator()
        for run in attrStr.runs.reversed() {
            guard let expected = expectationIterator.next() else {
                Issue.record("Found extra unexpected runs")
                break
            }
            #expect(String(attrStr[run.range].characters) == expected.0)
            #expect(run.testInt == expected.1)
            #expect(run.testDouble == expected.2)
            #expect(run.testString == nil)
        }
        #expect(expectationIterator.next() == nil)

        let attrView = attrStr.runs
        verifyAttributes(attrView[\.testInt], string: attrStr, expectation: [("Hello", 1), (" World", nil)])
        verifyAttributes(attrView[\.testDouble], string: attrStr, expectation: [("Hello ", nil), ("World", 2.0)])
        verifyAttributes(attrView[\.testString], string: attrStr, expectation: [("Hello World", nil)])
        verifyAttributes(attrView[\.testInt, \.testDouble], string: attrStr, expectation: [("Hello", 1, nil), (" ", nil, nil), ("World", nil, 2.0)])
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func sliceEnumeration() throws {
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testInt(1))
        attrStr += AttributedString(" ")
        attrStr += AttributedString("World", attributes: AttributeContainer().testDouble(2.0))

        let attrStrSlice = attrStr[attrStr.characters.index(attrStr.startIndex, offsetBy: 3) ..< attrStr.characters.index(attrStr.endIndex, offsetBy: -3)]

        let expectation = [("lo", 1, nil), (" ", nil, nil), ("Wo", nil, 2.0)]
        var expectationIterator = expectation.makeIterator()
        for run in attrStrSlice.runs {
            guard let expected = expectationIterator.next() else {
                Issue.record("Found extra unexpected runs")
                break
            }
            #expect(String(attrStr[run.range].characters) == expected.0)
            #expect(run.testInt == expected.1)
            #expect(run.testDouble == expected.2)
            #expect(run.testString == nil)
        }
        #expect(expectationIterator.next() == nil)

        expectationIterator = expectation.reversed().makeIterator()
        for run in attrStrSlice.runs.reversed() {
            guard let expected = expectationIterator.next() else {
                Issue.record("Found extra unexpected runs")
                break
            }
            #expect(String(attrStr[run.range].characters) == expected.0)
            #expect(run.testInt == expected.1)
            #expect(run.testDouble == expected.2)
            #expect(run.testString == nil)
        }
        #expect(expectationIterator.next() == nil)

        let attrView = attrStrSlice.runs
        verifyAttributes(attrView[\.testInt], string: attrStr, expectation: [("lo", 1), (" Wo", nil)])
        verifyAttributes(attrView[\.testDouble], string: attrStr, expectation: [("lo ", nil), ("Wo", 2.0)])
        verifyAttributes(attrView[\.testString], string: attrStr, expectation: [("lo Wo", nil)])
        verifyAttributes(attrView[\.testInt, \.testDouble], string: attrStr, expectation: [("lo", 1, nil), (" ", nil, nil), ("Wo", nil, 2.0)])
    }
    
#if FOUNDATION_FRAMEWORK
    @available(FoundationAttributedString 5.5, *)
    @Test func nsSliceEnumeration() {
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testInt(1))
        attrStr += AttributedString(" ")
        attrStr += AttributedString("World", attributes: AttributeContainer().testDouble(2.0))

        let middleRange = attrStr.characters.index(attrStr.startIndex, offsetBy: 3) ..< attrStr.characters.index(attrStr.endIndex, offsetBy: -3)
        let view = attrStr[middleRange].runs
        verifyAttributes(view[nsAttributedStringKeys: [.testInt]], string: attrStr, expectation: [("lo", .init().testInt(1)), (" Wo", .init())])
        verifyAttributes(view[nsAttributedStringKeys: [.testDouble]], string: attrStr, expectation: [("lo ", .init()), ("Wo", .init().testDouble(2.0))])
        verifyAttributes(view[nsAttributedStringKeys: [.testString]], string: attrStr, expectation: [("lo Wo", .init())])
        verifyAttributes(view[nsAttributedStringKeys: [.testInt, .testDouble]], string: attrStr, expectation: [("lo", .init().testInt(1)), (" ", .init()), ("Wo", .init().testDouble(2.0))])
        
        attrStr[middleRange].testString = "Test"
        verifyAttributes(attrStr.runs[nsAttributedStringKeys: [.testInt]], string: attrStr, expectation: [("Hello", .init().testInt(1)), (" World", .init())])
        verifyAttributes(attrStr.runs[nsAttributedStringKeys: [.testDouble]], string: attrStr, expectation: [("Hello ", .init()), ("World", .init().testDouble(2.0))])
        verifyAttributes(attrStr.runs[nsAttributedStringKeys: [.testString]], string: attrStr, expectation: [("Hel", .init()), ("lo Wo", .init().testString("Test")), ("rld", .init())])
        verifyAttributes(attrStr.runs[nsAttributedStringKeys: [.testInt, .testDouble, .testString]], string: attrStr, expectation: [
            ("Hel", .init().testInt(1)),
            ("lo", .init().testInt(1).testString("Test")),
            (" ", .init().testString("Test")),
            ("Wo", .init().testDouble(2.0).testString("Test")),
            ("rld", .init().testDouble(2.0))
        ])
    }
#endif // FOUNDATION_FRAMEWORK

    // MARK: - Attribute Tests

    @available(FoundationAttributedString 5.5, *)
    @Test func simpleAttribute() {
        let attrStr = AttributedString("Foo", attributes: AttributeContainer().testInt(42))
        let (value, range) = attrStr.runs[\.testInt][attrStr.startIndex]
        #expect(value == 42)
        #expect(range == attrStr.startIndex ..< attrStr.endIndex)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func constructorAttribute() {
        // TODO: Re-evaluate whether we want these.
        let attrStr = AttributedString("Hello", attributes: AttributeContainer().testString("Helvetica").testInt(2))
        var expected = AttributedString("Hello")
        expected.testString = "Helvetica"
        expected.testInt = 2
        #expect(attrStr == expected)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func addAndRemoveAttribute() {
        let attr : Int = 42
        let attr2 : Double = 1.0
        var attrStr = AttributedString("Test")
        attrStr.testInt = attr
        attrStr.testDouble = attr2

        let expected1 = AttributedString("Test", attributes: AttributeContainer().testInt(attr).testDouble(attr2))
        #expect(attrStr == expected1)

        attrStr.testDouble = nil

        let expected2 = AttributedString("Test", attributes: AttributeContainer().testInt(attr))
        #expect(attrStr == expected2)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func addingAndRemovingAttribute() {
        let container = AttributeContainer().testInt(1).testDouble(2.2)
        let attrStr = AttributedString("Test").mergingAttributes(container)
        let expected = AttributedString("Test", attributes: AttributeContainer().testInt(1).testDouble(2.2))
        #expect(attrStr == expected)
        var doubleRemoved = attrStr
        doubleRemoved.testDouble = nil
        #expect(doubleRemoved == AttributedString("Test", attributes: AttributeContainer().testInt(1)))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func scopedAttributes() {
        var str = AttributedString("Hello, world", attributes: AttributeContainer().testInt(2).testDouble(3.4))
        #expect(str.test.testInt == 2)
        #expect(str.test.testDouble == 3.4)
        #expect(str.runs[str.runs.startIndex].test.testInt == 2)
        
        str.test.testInt = 4
        #expect(str == AttributedString("Hello, world", attributes: AttributeContainer.testInt(4).testDouble(3.4)))
        
        let range = str.startIndex ..< str.characters.index(after: str.startIndex)
        str[range].test.testBool = true
        #expect(str.test.testBool == nil)
        #expect(str[range].test.testBool != nil)
        #expect(str[range].test.testBool == true)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func runAttributes() {
        var str = AttributedString("String", attributes: .init().testString("test1"))
        str += "None"
        str += AttributedString("String+Int", attributes: .init().testString("test2").testInt(42))

        let attributes = str.runs.map { $0.attributes }
        #expect(attributes.count == 3)
        #expect(attributes[0] == .init().testString("test1"))
        #expect(attributes[1] == .init())
        #expect(attributes[2] == .init().testString("test2").testInt(42))
    }

    // MARK: - Comparison Tests

    @available(FoundationAttributedString 5.5, *)
    @Test func attributedStringEquality() {
        #expect(AttributedString() == AttributedString())
        #expect(AttributedString("abc") == AttributedString("abc"))
        #expect(AttributedString("abc", attributes: AttributeContainer().testInt(1)) == AttributedString("abc", attributes: AttributeContainer().testInt(1)))
        #expect(AttributedString("abc", attributes: AttributeContainer().testInt(1)) != AttributedString("abc", attributes: AttributeContainer().testInt(2)))
        #expect(AttributedString("abc", attributes: AttributeContainer().testInt(1)) != AttributedString("def", attributes: AttributeContainer().testInt(1)))

        var a = AttributedString("abc", attributes: AttributeContainer().testInt(1))
        a += AttributedString("def", attributes: AttributeContainer().testInt(1))
        #expect(a == AttributedString("abcdef", attributes: AttributeContainer().testInt(1)))

        a = AttributedString("ab", attributes: AttributeContainer().testInt(1))
        a += AttributedString("cdef", attributes: AttributeContainer().testInt(2))
        var b = AttributedString("abcd", attributes: AttributeContainer().testInt(1))
        b += AttributedString("ef", attributes: AttributeContainer().testInt(2))
        #expect(a != b)

        a = AttributedString("abc")
        a += AttributedString("defghi", attributes: AttributeContainer().testInt(2))
        a += "jkl"
        b = AttributedString("abc")
        b += AttributedString("def", attributes: AttributeContainer().testInt(2))
        b += "ghijkl"
        #expect(a != b)


        let a1 = AttributedString("Café", attributes: AttributeContainer().testInt(1))
        let a2 = AttributedString("Cafe\u{301}", attributes: AttributeContainer().testInt(1))
        #expect(a1 == a2)

        let a3 = (AttributedString("Cafe", attributes: AttributeContainer().testInt(1))
                  + AttributedString("\u{301}", attributes: AttributeContainer().testInt(2)))
        #expect(a1 != a3)
        #expect(a2 != a3)
        #expect(a1.characters.elementsEqual(a3.characters))
        #expect(a2.characters.elementsEqual(a3.characters))
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func attributedSubstringEquality() {
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

        #expect(emptyStr[index0 ..< index0] == emptyStr[index0 ..< index0])
        #expect(emptyStr[index0 ..< index5] == emptyStr[index0 ..< index5])
        #expect(emptyStr[index0 ..< index20] == emptyStr[index0 ..< index20])
        #expect(singleAttrStr[index0 ..< index20] == singleAttrStr[index0 ..< index20])
        #expect(halfhalfStr[index0 ..< index20] == halfhalfStr[index0 ..< index20])

        #expect(emptyStr[index0 ..< index10] == singleAttrStr[index10 ..< index20])
        #expect(halfhalfStr[index0 ..< index10] == singleAttrStr[index0 ..< index10])

        #expect(emptyStr[index0 ..< index10] != singleAttrStr[index0 ..< index10])
        #expect(emptyStr[index0 ..< index10] != singleAttrStr[index0 ..< index20])

        #expect(emptyStr[index0 ..< index5] == AttributedString("01234"))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func runEquality() {
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
        #expect(run(0, in: attrStr) != run(0, in: attrStr2))
        
        // Different strings, same range, same attributes
        #expect(run(1, in: attrStr) == run(1, in: attrStr2))
        
        // Same string, same range, same attributes
        #expect(run(2, in: attrStr) == run(2, in: attrStr2))
        
        // Different string, different range, same attributes
        #expect(run(2, in: attrStr) == run(0, in: attrStr2))
        
        // Same string, different range, same attributes
        #expect(run(0, in: attrStr) == run(3, in: attrStr2))
        
        // A runs collection of the same order but different run lengths
        #expect(attrStr.runs != attrStr3.runs)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func substringRunEquality() {
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testInt(1))
        attrStr += AttributedString(" ")
        attrStr += AttributedString("World", attributes: AttributeContainer().testInt(2))
        
        var attrStr2 = AttributedString("Hello", attributes: AttributeContainer().testInt(2))
        attrStr2 += AttributedString("_")
        attrStr2 += AttributedString("World", attributes: AttributeContainer().testInt(2))
        
        #expect(attrStr[attrStr.runs.last!.range].runs == attrStr2[attrStr2.runs.first!.range].runs)
        #expect(attrStr[attrStr.runs.last!.range].runs == attrStr2[attrStr2.runs.last!.range].runs)
        
        let rangeA = attrStr.runs.first!.range.upperBound ..< attrStr.endIndex
        let rangeB = attrStr2.runs.first!.range.upperBound ..< attrStr.endIndex
        let rangeC = attrStr.startIndex ..< attrStr.runs.last!.range.lowerBound
        let rangeD = attrStr.runs.first!.range
        #expect(attrStr[rangeA].runs == attrStr2[rangeB].runs)
        #expect(attrStr[rangeC].runs != attrStr2[rangeB].runs)
        #expect(attrStr[rangeD].runs != attrStr2[rangeB].runs)
        
        // Test starting/ending runs that only differ outside of the range do not prevent equality
        attrStr2[attrStr.runs.first!.range].testInt = 1
        attrStr2.characters.insert(contentsOf: "123", at: attrStr.startIndex)
        attrStr2.characters.append(contentsOf: "45")
        let rangeE = attrStr.startIndex ..< attrStr.endIndex
        let rangeF = attrStr2.characters.index(attrStr2.startIndex, offsetBy: 3) ..< attrStr2.characters.index(attrStr2.startIndex, offsetBy: 14)
        #expect(attrStr[rangeE].runs == attrStr2[rangeF].runs)
    }

    // MARK: - Mutation Tests

    @available(FoundationAttributedString 5.5, *)
    @Test func directMutationCopyOnWrite() {
        var attrStr = AttributedString("ABC")
        let copy = attrStr
        attrStr += "D"

        #expect(copy == AttributedString("ABC"))
        #expect(attrStr != copy)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func attributeMutationCopyOnWrite() {
        var attrStr = AttributedString("ABC")
        let copy = attrStr
        attrStr.testInt = 1

        #expect(attrStr != copy)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func sliceAttributeMutation() {
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
        #expect(attrStr == expected)

        #expect(copy != attrStr)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func enumerationAttributeMutation() {
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
        #expect(expected == attrStr)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func mutateMultipleAttributes() {
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
        #expect(removal1expected == removal1)

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
        #expect(changeSame1expected == changeSame1)

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
        #expect(changeDifferent1expected == changeDifferent1)

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
        #expect(changeRange1expected == changeRange1)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func mutateAttributes() {
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
        #expect(removal1expected == removal1)

        // Test change value, same attribute.
        let changeSame1 = attrStr.transformingAttributes(\.testBool) {
            if let boolean = $0.value {
                $0.value = !boolean
            }
        }
        var changeSame1expected = AttributedString("A", attributes: AttributeContainer().testInt(1).testBool(false))
        changeSame1expected += AttributedString("B", attributes: AttributeContainer().testInt(1).testDouble(2))
        changeSame1expected += AttributedString("C", attributes: AttributeContainer().testDouble(2).testBool(true))
        #expect(changeSame1expected == changeSame1)

        // Test change value, different attribute
        let changeDifferent1 = attrStr.transformingAttributes(\.testBool) {
            if let value = $0.value {
                $0.replace(with: AttributeScopes.TestAttributes.TestDoubleAttribute.self, value: (value ? 42 : 43))
            }
        }
        var changeDifferent1expected = AttributedString("A", attributes: AttributeContainer().testInt(1).testDouble(42))
        changeDifferent1expected += AttributedString("B", attributes: AttributeContainer().testInt(1).testDouble(2))
        changeDifferent1expected += AttributedString("C", attributes: AttributeContainer().testDouble(43))
        #expect(changeDifferent1expected == changeDifferent1)

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
        #expect(changeRange1expected == changeRange1)

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
        #expect(changeRange2expected == changeRange2)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func replaceAttributes() {
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
        #expect(removal1expected == removal1)
        
        // Test change value, same attribute.
        let changeSame1Find = AttributeContainer().testBool(false)
        let changeSame1Replace = AttributeContainer().testBool(true)
        var changeSame1 = attrStr
        changeSame1.replaceAttributes(changeSame1Find, with: changeSame1Replace)
    
        var changeSame1expected = AttributedString("A", attributes: AttributeContainer().testInt(1).testBool(true))
        changeSame1expected += AttributedString("B", attributes: AttributeContainer().testInt(1).testDouble(2))
        changeSame1expected += AttributedString("C", attributes: AttributeContainer().testDouble(2).testBool(true))
        #expect(changeSame1expected == changeSame1)
        
        // Test change value, different attribute
        let changeDifferent1Find = AttributeContainer().testBool(false)
        let changeDifferent1Replace = AttributeContainer().testDouble(43)
        var changeDifferent1 = attrStr
        changeDifferent1.replaceAttributes(changeDifferent1Find, with: changeDifferent1Replace)
        
        var changeDifferent1expected = AttributedString("A", attributes: AttributeContainer().testInt(1).testBool(true))
        changeDifferent1expected += AttributedString("B", attributes: AttributeContainer().testInt(1).testDouble(2))
        changeDifferent1expected += AttributedString("C", attributes: AttributeContainer().testDouble(43))
        #expect(changeDifferent1expected == changeDifferent1)
    }
 
    
    @available(FoundationAttributedString 5.5, *)
    @Test func sliceMutation() {
        var attrStr = AttributedString("Hello World", attributes: AttributeContainer().testInt(1))
        let start = attrStr.characters.index(attrStr.startIndex, offsetBy: 6)
        attrStr.replaceSubrange(start ..< attrStr.characters.index(start, offsetBy:5), with: AttributedString("Goodbye", attributes: AttributeContainer().testInt(2)))

        var expected = AttributedString("Hello ", attributes: AttributeContainer().testInt(1))
        expected += AttributedString("Goodbye", attributes: AttributeContainer().testInt(2))
        #expect(attrStr == expected)
        #expect(attrStr != AttributedString("Hello Goodbye", attributes: AttributeContainer().testInt(1)))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func overlappingSliceMutation() throws {
        var attrStr = AttributedString("Hello, world!")
        attrStr[try #require(attrStr.range(of: "Hello"))].testInt = 1
        attrStr[try #require(attrStr.range(of: "world"))].testInt = 2
        attrStr[try #require(attrStr.range(of: "o, wo"))].testBool = true
        
        var expected = AttributedString("Hell", attributes: AttributeContainer().testInt(1))
        expected += AttributedString("o", attributes: AttributeContainer().testInt(1).testBool(true))
        expected += AttributedString(", ", attributes: AttributeContainer().testBool(true))
        expected += AttributedString("wo", attributes: AttributeContainer().testBool(true).testInt(2))
        expected += AttributedString("rld", attributes: AttributeContainer().testInt(2))
        expected += AttributedString("!")
        #expect(attrStr == expected)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func characters_replaceSubrange() throws {
        var attrStr = AttributedString("Hello World", attributes: AttributeContainer().testInt(1))
        attrStr.characters.replaceSubrange(try #require(attrStr.range(of: " ")), with: " Good ")

        let expected = AttributedString("Hello Good World", attributes: AttributeContainer().testInt(1))
        #expect(expected == attrStr)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func charactersMutation_append() {
        var attrStr = AttributedString("Hello World", attributes: AttributeContainer().testInt(1))
        attrStr.characters.append(contentsOf: " Goodbye")

        let expected = AttributedString("Hello World Goodbye", attributes: AttributeContainer().testInt(1))
        #expect(expected == attrStr)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func unicodeScalars_replaceSubrange() {
        var attrStr = AttributedString("La Cafe\u{301}", attributes: AttributeContainer().testInt(1))
        let unicode = attrStr.unicodeScalars
        attrStr.unicodeScalars.replaceSubrange(unicode.index(unicode.startIndex, offsetBy: 3) ..< unicode.index(unicode.startIndex, offsetBy: 7), with: "Ole".unicodeScalars)

        let expected = AttributedString("La Ole\u{301}", attributes: AttributeContainer().testInt(1))
        #expect(expected == attrStr)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func unicodeScalarsMutation_append() {
        var attrStr = AttributedString("Cafe", attributes: AttributeContainer().testInt(1))
        attrStr.unicodeScalars.append("\u{301}")

        let expected = AttributedString("Cafe\u{301}", attributes: AttributeContainer().testInt(1))
        #expect(expected == attrStr)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func subCharacterAttributeSetting() {
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
        #expect(expected == attrStr)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func replaceSubrange_rangeExpression() {
        var attrStr = AttributedString("Hello World", attributes: AttributeContainer().testInt(1))
        
        // Test with PartialRange, which conforms to RangeExpression but is not a Range
        let rangeOfHello = ...attrStr.characters.index(attrStr.startIndex, offsetBy: 4)
        attrStr.replaceSubrange(rangeOfHello, with: AttributedString("Goodbye"))
        
        var expected = AttributedString("Goodbye")
        expected += AttributedString(" World", attributes: AttributeContainer().testInt(1))
        #expect(attrStr == expected)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func settingAttributes() {
        var attrStr = AttributedString("Hello World", attributes: .init().testInt(1))
        attrStr += AttributedString(". My name is Foundation!", attributes: .init().testBool(true))
        
        let result = attrStr.settingAttributes(.init().testBool(false))
        
        let expected = AttributedString("Hello World. My name is Foundation!", attributes: .init().testBool(false))
        #expect(result == expected)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func addAttributedString() {
        let attrStr = AttributedString("Hello ", attributes: .init().testInt(1))
        let attrStr2 = AttributedString("World", attributes: .init().testInt(2))
        let original = attrStr
        let original2 = attrStr2
        
        var concat = AttributedString("Hello ", attributes: .init().testInt(1))
        concat += AttributedString("World", attributes: .init().testInt(2))
        let combine = attrStr + attrStr2
        #expect(attrStr == original)
        #expect(attrStr2 == original2)
        #expect(String(combine.characters) == "Hello World")
        #expect(String(concat.characters) == "Hello World")
        
        let testInts = [1, 2]
        for str in [concat, combine] {
            var i = 0
            for run in str.runs {
                #expect(run.testInt == testInts[i])
                i += 1
            }
        }
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func replaceSubrangeWithSubstrings() {
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

        #expect(targetString == expected)

        targetString = AttributedString("XYZ", attributes: .init().testString("foo"))
        targetString.append(substring)
        expected = AttributedString("XYZ", attributes: .init().testString("foo"))
        + AttributedString("B", attributes: .init().testInt(2))
        + AttributedString("C", attributes: .init().testInt(3))
        + AttributedString("D", attributes: .init().testInt(4))

        #expect(targetString == expected)
    }
    
    @available(FoundationAttributedString 5.5, *)
    func assertStringIsCoalesced(_ str: AttributedString) {
        var prev: AttributedString.Runs.Run?
        for run in str.runs {
            if let prev = prev {
                #expect(prev.attributes != run.attributes)
            }
            prev = run
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func coalescing() {
        let str = AttributedString("Hello", attributes: .init().testInt(1))
        let appendSame = str + AttributedString("World", attributes: .init().testInt(1))
        let appendDifferent = str + AttributedString("World", attributes: .init().testInt(2))
        
        assertStringIsCoalesced(str)
        assertStringIsCoalesced(appendSame)
        assertStringIsCoalesced(appendDifferent)
        #expect(appendSame.runs.count == 1)
        #expect(appendDifferent.runs.count == 2)
        
        // Ensure replacing whole string keeps coalesced
        var str2 = str
        str2.replaceSubrange(str2.startIndex ..< str2.endIndex, with: AttributedString("Hello", attributes: .init().testInt(2)))
        assertStringIsCoalesced(str2)
        #expect(str2.runs.count == 1)
        
        // Ensure replacing subranges splits runs and doesn't coalesce when not equal
        var str3 = str
        str3.replaceSubrange(str3.characters.index(after: str3.startIndex) ..< str3.endIndex, with: AttributedString("ello", attributes: .init().testInt(2)))
        assertStringIsCoalesced(str3)
        #expect(str3.runs.count == 2)
        
        var str4 = str
        str4.replaceSubrange(str4.startIndex ..< str4.characters.index(before: str4.endIndex), with: AttributedString("Hell", attributes: .init().testInt(2)))
        assertStringIsCoalesced(str4)
        #expect(str4.runs.count == 2)
        
        var str5 = str
        str5.replaceSubrange(str5.characters.index(after: str5.startIndex) ..< str5.characters.index(before: str4.endIndex), with: AttributedString("ell", attributes: .init().testInt(2)))
        assertStringIsCoalesced(str5)
        #expect(str5.runs.count == 3)
        
        // Ensure changing attributes back to match bordering runs coalesces with edge of subrange
        var str6 = str5
        str6.replaceSubrange(str6.characters.index(after: str6.startIndex) ..< str6.endIndex, with: AttributedString("ello", attributes: .init().testInt(1)))
        assertStringIsCoalesced(str6)
        #expect(str6.runs.count == 1)
        
        var str7 = str5
        str7.replaceSubrange(str7.startIndex ..< str7.characters.index(before: str7.endIndex), with: AttributedString("Hell", attributes: .init().testInt(1)))
        assertStringIsCoalesced(str7)
        #expect(str7.runs.count == 1)
        
        var str8 = str5
        str8.replaceSubrange(str8.characters.index(after: str8.startIndex) ..< str8.characters.index(before: str8.endIndex), with: AttributedString("ell", attributes: .init().testInt(1)))
        assertStringIsCoalesced(str8)
        #expect(str8.runs.count == 1)
        
        var str9 = str5
        str9.testInt = 1
        assertStringIsCoalesced(str9)
        #expect(str9.runs.count == 1)
        
        var str10 = str5
        str10[str10.characters.index(after: str10.startIndex) ..< str10.characters.index(before: str10.endIndex)].testInt = 1
        assertStringIsCoalesced(str10)
        #expect(str10.runs.count == 1)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func replaceWithEmptyElements() {
        var str = AttributedString("Hello, world")
        let range = str.startIndex ..< str.characters.index(str.startIndex, offsetBy: 5)
        str.characters.replaceSubrange(range, with: [])
        
        #expect(str == AttributedString(", world"))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func description() {
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
        #expect(desc == expected)
        
        let runsDesc = String(describing: string.runs)
        #expect(runsDesc == expected)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func containerDescription() {
        let cont = AttributeContainer().testBool(false).testInt(1).testDouble(2.0).testString("3")
        
        let desc = String(describing: cont)
        
        // Don't get bitten by any potential changes in the hashing algorithm.
        #expect(desc.hasPrefix("{\n"))
        #expect(desc.hasSuffix("\n}"))
        #expect(desc.contains("\tTestDouble = 2.0\n"))
        #expect(desc.contains("\tTestInt = 1\n"))
        #expect(desc.contains("\tTestString = 3\n"))
        #expect(desc.contains("\tTestBool = false\n"))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func runAndSubstringDescription() {
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
        #expect(runsDescs == expected)
        
        let subDescs = string.runs.map() { String(describing: string[$0.range]) }
        #expect(subDescs == expected)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func replacingAttributes() {
        var str = AttributedString("Hello", attributes: .init().testInt(2))
        str += AttributedString("World", attributes: .init().testString("Test"))
        
        var result = str.replacingAttributes(.init().testInt(2).testString("NotTest"), with: .init().testBool(false))
        #expect(result == str)
        
        result = str.replacingAttributes(.init().testInt(2), with: .init().testBool(false))
        var expected = AttributedString("Hello", attributes: .init().testBool(false))
        expected += AttributedString("World", attributes: .init().testString("Test"))
        #expect(result == expected)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func scopedAttributeContainer() {
        var str = AttributedString("Hello, world")
        
        #expect(str.test.testInt == nil)
        #expect(str.testInt == nil)
        str.test.testInt = 2
        #expect(str.test.testInt == 2)
        #expect(str.testInt == 2)
        str.test.testInt = nil
        #expect(str.test.testInt == nil)
        #expect(str.testInt == nil)
        
        let range = str.startIndex ..< str.index(str.startIndex, offsetByCharacters: 5)
        let otherRange = range.upperBound ..< str.endIndex
        
        str[range].test.testBool = true
        #expect(str[range].test.testBool == true)
        #expect(str[range].testBool == true)
        #expect(str.test.testBool == nil)
        #expect(str.testBool == nil)
        str[range].test.testBool = nil
        #expect(str[range].test.testBool == nil)
        #expect(str[range].testBool == nil)
        #expect(str.test.testBool == nil)
        #expect(str.testBool == nil)
        
        str.test.testBool = true
        str[range].test.testBool = nil
        #expect(str[range].test.testBool == nil)
        #expect(str[range].testBool == nil)
        #expect(str.test.testBool == nil)
        #expect(str.testBool == nil)
        #expect(str[otherRange].test.testBool == true)
        #expect(str[otherRange].testBool == true)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func mergeAttributes() {
        let originalAttributes = AttributeContainer.testInt(2).testBool(true)
        let newAttributes = AttributeContainer.testString("foo")
        let overlappingAttributes = AttributeContainer.testInt(3).testDouble(4.3)
        let str = AttributedString("Hello, world", attributes: originalAttributes)
        
        #expect(str.mergingAttributes(newAttributes, mergePolicy: .keepNew) == AttributedString("Hello, world", attributes: newAttributes.testInt(2).testBool(true)))
        #expect(str.mergingAttributes(newAttributes, mergePolicy: .keepCurrent) == AttributedString("Hello, world", attributes: newAttributes.testInt(2).testBool(true)))
        #expect(str.mergingAttributes(overlappingAttributes, mergePolicy: .keepNew) == AttributedString("Hello, world", attributes: overlappingAttributes.testBool(true)))
        #expect(str.mergingAttributes(overlappingAttributes, mergePolicy: .keepCurrent) == AttributedString("Hello, world", attributes: originalAttributes.testDouble(4.3)))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func mergeAttributeContainers() {
        let originalAttributes = AttributeContainer.testInt(2).testBool(true)
        let newAttributes = AttributeContainer.testString("foo")
        let overlappingAttributes = AttributeContainer.testInt(3).testDouble(4.3)
        
        #expect(originalAttributes.merging(newAttributes, mergePolicy: .keepNew) == newAttributes.testInt(2).testBool(true))
        #expect(originalAttributes.merging(newAttributes, mergePolicy: .keepCurrent) == newAttributes.testInt(2).testBool(true))
        #expect(originalAttributes.merging(overlappingAttributes, mergePolicy: .keepNew) == overlappingAttributes.testBool(true))
        #expect(originalAttributes.merging(overlappingAttributes, mergePolicy: .keepCurrent) == originalAttributes.testDouble(4.3))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func changingSingleCharacterUTF8Length() throws {
        var attrstr = AttributedString("\u{1F3BA}\u{1F3BA}") // UTF-8 Length of 8
        attrstr.characters[attrstr.startIndex] = "A" // Changes UTF-8 Length to 5
        #expect(attrstr.runs.count == 1)
        let runRange = try #require(attrstr.runs.first).range
        let substring = String(attrstr[runRange].characters)
        #expect(substring == "A\u{1F3BA}")
    }
    
    // MARK: - Substring Tests
    
    @available(FoundationAttributedString 5.5, *)
    @Test func substringBase() {
        let str = AttributedString("Hello World", attributes: .init().testInt(1))
        var substr = str[str.startIndex ..< str.characters.index(str.startIndex, offsetBy: 5)]
        #expect(substr.base == str)
        substr.testInt = 3
        #expect(substr.base != str)
        
        var str2 = AttributedString("Hello World", attributes: .init().testInt(1))
        let range = str2.startIndex ..< str2.characters.index(str2.startIndex, offsetBy: 5)
        #expect(str2[range].base == str2)
        str2[range].testInt = 3
        #expect(str2[range].base == str2)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func substringGetAttribute() {
        let str = AttributedString("Hello World", attributes: .init().testInt(1))
        let range = str.startIndex ..< str.characters.index(str.startIndex, offsetBy: 5)
        #expect(str[range].testInt == 1)
        #expect(str[range].testString == nil)
        
        var str2 = AttributedString("Hel", attributes: .init().testInt(1))
        str2 += AttributedString("lo World", attributes: .init().testInt(2).testBool(true))
        let range2 = str2.startIndex ..< str2.characters.index(str2.startIndex, offsetBy: 5)
        #expect(str2[range2].testInt == nil)
        #expect(str2[range2].testBool == nil)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func substringDescription() {
        var str = AttributedString("Hello", attributes: .init().testInt(2))
        str += " "
        str += AttributedString("World", attributes: .init().testInt(3))
        
        for run in str.runs {
            let desc = str[run.range].description
            #expect(!desc.isEmpty)
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func substringReplaceAttributes() {
        var str = AttributedString("Hello", attributes: .init().testInt(2).testString("Foundation"))
        str += " "
        str += AttributedString("World", attributes: .init().testInt(3))
        
        let range = str.index(str.startIndex, offsetByCharacters: 2) ..< str.index(str.startIndex, offsetByCharacters: 8)
        str[range].replaceAttributes(.init().testInt(2).testString("Foundation"), with: .init().testBool(true))
        
        var expected = AttributedString("He", attributes: .init().testInt(2).testString("Foundation"))
        expected += AttributedString("llo", attributes: .init().testBool(true))
        expected += " "
        expected += AttributedString("World", attributes: .init().testInt(3))
        #expect(str == expected)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func substringEquality() {
        let str = AttributedString("")
        let range = str.startIndex ..< str.endIndex
        #expect(str[range] == str[range])
        
        let str2 = "A" + AttributedString("A", attributes: .init().testInt(2))
        let substringA = str2[str2.startIndex ..< str2.index(afterCharacter: str2.startIndex)]
        let substringB = str2[str2.index(afterCharacter: str2.startIndex) ..< str2.endIndex]
        #expect(substringA != substringB)
        #expect(substringA == substringA)
        #expect(substringB == substringB)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func initializationFromSubstring() throws {
        var attrStr = AttributedString("yolo^+1 result<:s>^", attributes: AttributeContainer.testInt(2).testString("Hello"))
        attrStr.replaceSubrange(try #require(attrStr.range(of: "<:s>")), with: AttributedString(""))
        attrStr[try #require(attrStr.range(of: "1 result"))].testInt = 3

        let range = try #require(attrStr.range(of: "+1 result"))
        let subFinal = attrStr[range]
        let attrFinal = AttributedString(subFinal)
        #expect(attrFinal.characters.elementsEqual(subFinal.characters))
        #expect(attrFinal.runs == subFinal.runs)
        
        var attrStr2 = AttributedString("xxxxxxxx", attributes: .init().testInt(1))
        attrStr2 += AttributedString("y", attributes: .init().testInt(2))
        attrStr2 += AttributedString("zzzzzzzz", attributes: .init().testInt(3))

        let subrange = attrStr2.index(attrStr2.startIndex, offsetByCharacters: 5) ..< attrStr2.endIndex
        let substring2 = attrStr2[subrange]
        let recreated = AttributedString(substring2)
        #expect(recreated.runs.count == 3)
    }

#if FOUNDATION_FRAMEWORK
    // MARK: - Coding Tests
    // TODO: Support AttributedString codable conformance in FoundationPreview
    struct CodableType : Codable {
        // One of potentially many different values being encoded:
        @CodableConfiguration(from: \.test)
        var attributedString = AttributedString()
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func jsonEncoding() throws {
        let encoder = JSONEncoder()
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testBool(true).testString("blue").testInt(1))
        attrStr += AttributedString(" World", attributes: AttributeContainer().testInt(2).testDouble(3.0).testString("http://www.apple.com"))

        let c = CodableType(attributedString: attrStr)
        let json = try encoder.encode(c)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CodableType.self, from: json)
        #expect(decoded.attributedString == attrStr)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func decodingThenConvertingToNSAttributedString() throws {
        let encoder = JSONEncoder()
        var attrStr = AttributedString("Hello", attributes: AttributeContainer().testBool(true))
        attrStr += AttributedString(" World", attributes: AttributeContainer().testInt(2))
        let c = CodableType(attributedString: attrStr)
        let json = try encoder.encode(c)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CodableType.self, from: json)
        let decodedns = try NSAttributedString(decoded.attributedString, including: AttributeScopes.TestAttributes.self)
        let ns = try NSAttributedString(attrStr, including: AttributeScopes.TestAttributes.self)
        #expect(ns == decodedns)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func customAttributeCoding() throws {
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
        #expect(decoded.attributedString == attrStr)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func customCodableTypeWithCodableAttributedString() throws {
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
        #expect(type == decoded)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func codingErrorsPropagateUpToCallSite() {
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
        #expect(throws: TestError.self) {
            try encoder.encode(Obj(str: str))
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func encodeWithPartiallyCodableScope() throws {
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
        #expect(decoded.str == expected)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func automaticCoding() throws {
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

            #expect(decoded == val)
        }

        // non-nil
        do {
            let val = Obj(testValueWithNils: false)
            let encoder = JSONEncoder()
            let data = try encoder.encode(val)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Obj.self, from: data)

            #expect(decoded == val)
        }

    }


    @available(FoundationAttributedString 5.5, *)
    @Test func manualCoding() throws {
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
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Obj.self, from: data)

            #expect(decoded == val)
        }

        // non-nil
        do {
            let val = Obj(testValueWithNils: false)
            let encoder = JSONEncoder()
            let data = try encoder.encode(val)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Obj.self, from: data)

            #expect(decoded == val)
        }
        
    }
    
    @Test(arguments: [
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
    ])
    func decodingCorruptedData(string: String) throws {
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            try decoder.decode(CodableType.self, from: string.data(using: .utf8)!)
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func codableRawRepresentableAttribute() throws {
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
        #expect(decoded.str[Attribute.self] == .two)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func containerEncoding() throws {
        struct ContainerContainer : Codable {
            @CodableConfiguration(from: AttributeScopes.TestAttributes.self) var container = AttributeContainer()
        }
        let obj = ContainerContainer(container: AttributeContainer().testInt(1).testBool(true))
        let encoder = JSONEncoder()
        let data = try encoder.encode(obj)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ContainerContainer.self, from: data)

        #expect(obj.container == decoded.container)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func defaultAttributesCoding() throws {
        struct DefaultContainer : Codable, Equatable {
            var str : AttributedString
        }
        
        let cont = DefaultContainer(str: AttributedString("Hello", attributes: .init().link(URL(string: "http://apple.com")!)))
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(cont)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DefaultContainer.self, from: encoded)
        #expect(cont == decoded)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func decodingMultibyteCharacters() throws {
        let json = "{\"str\": [\"🎺ABC\", {\"TestInt\": 2}]}"
        struct Object : Codable {
            @CodableConfiguration(from: AttributeScopes.TestAttributes.self) var str: AttributedString = AttributedString()
        }
        let decoder = JSONDecoder()
        let str = try decoder.decode(Object.self, from: json.data(using: .utf8)!).str
        #expect(str.runs.count == 1)
        #expect(str.testInt == 2)
        let idx = str.index(beforeCharacter: str.endIndex)
        #expect(str.runs[idx].testInt == 2)
    }
    
    // MARK: - Conversion Tests
    
    @available(FoundationAttributedString 5.5, *)
    @Test func conversionToObjC() throws {
        var ourString = AttributedString("Hello", attributes: AttributeContainer().testInt(2))
        ourString += AttributedString(" ")
        ourString += AttributedString("World", attributes: AttributeContainer().testString("Courier"))
        let ourObjCString = try NSAttributedString(ourString, including: AttributeScopes.TestAttributes.self)
        let theirString = NSMutableAttributedString(string: "Hello World")
        theirString.addAttributes([.testInt: NSNumber(value: 2)], range: NSMakeRange(0, 5))
        theirString.addAttributes([.testString: "Courier"], range: NSMakeRange(6, 5))
        #expect(theirString == ourObjCString)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func conversionFromObjC() throws {
        let nsString = NSMutableAttributedString(string: "Hello!")
        let rangeA = NSMakeRange(0, 3)
        let rangeB = NSMakeRange(3, 3)
        nsString.addAttribute(.testString, value: "Courier", range: rangeA)
        nsString.addAttribute(.testBool, value: NSNumber(value: true), range: rangeB)
        let convertedString = try AttributedString(nsString, including: AttributeScopes.TestAttributes.self)
        var string = AttributedString("Hel")
        string.testString = "Courier"
        string += AttributedString("lo!", attributes: AttributeContainer().testBool(true))
        #expect(string == convertedString)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func roundTripConversion_boxed() throws {
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
        
        #expect(converted[MyCustomAttribute.self] == customVal)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func roundTripConversion_customConversion() throws {
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

        #expect(nsString.attribute(.init(MyCustomAttribute.name), at: 0, effectiveRange: nil) is NSUUID)

        let converted = try AttributedString(nsString, including: MyCustomScope.self)
        #expect(converted[MyCustomAttribute.self] == customVal)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func incompleteConversionFromObjC() throws {
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
        #expect(converted == expected)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func incompleteConversionToObjC() throws {
        struct TestStringAttributeOnly : AttributeScope {
            var testString: AttributeScopes.TestAttributes.TestStringAttribute // Missing TestBoolAttribute
        }

        var attrStr = AttributedString("Hello ", attributes: .init().testBool(false))
        attrStr += AttributedString("world", attributes: .init().testString("Testing"))
        let converted = try NSAttributedString(attrStr, including: TestStringAttributeOnly.self)
        
        let attrs = converted.attributes(at: 0, effectiveRange: nil)
        #expect(!attrs.keys.contains(.testBool))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func conversionNestedScope() throws {
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
        #expect(converted == expected)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func conversionAttributeContainers() throws {
        let container = AttributeContainer.testInt(2).testDouble(3.1).testString("Hello")
        
        let dictionary = try Dictionary(container, including: \.test)
        let expected: [NSAttributedString.Key: Any] = [
                .testInt: 2,
                .testDouble: 3.1,
                .testString: "Hello"
        ]
        #expect(dictionary.keys == expected.keys)
        #expect(dictionary[.testInt] as? Int == expected[.testInt] as? Int)
        #expect(dictionary[.testDouble] as? Double == expected[.testDouble] as? Double)
        #expect(dictionary[.testString] as? String == expected[.testString] as? String)
        
        let container2 = try AttributeContainer(dictionary, including: \.test)
        #expect(container == container2)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func conversionFromInvalidObjectiveCValueTypes() throws {
        let nsStr = NSAttributedString(string: "Hello", attributes: [.testInt : "I am not an Int"])
        #expect(throws: (any Error).self) {
            try AttributedString(nsStr, including: AttributeScopes.TestAttributes.self)
        }
        
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
        #expect(throws: (any Error).self) {
            try AttributedString(nsStr2, including: Scope.self)
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func conversionToUTF16() throws {
        // Ensure that we're correctly using UTF16 offsets with NSAS and UTF8 offsets with AS without mixing the two
        let multiByteCharacters = ["\u{2029}", "\u{1D11E}", "\u{1D122}", "\u{1F91A}\u{1F3FB}"]
        
        for str in multiByteCharacters {
            let attrStr = AttributedString(str, attributes: .init().testInt(2))
            let nsStr = NSAttributedString(string: str, attributes: [.testInt: 2])
            
            let convertedAttrStr = try AttributedString(nsStr, including: AttributeScopes.TestAttributes.self)
            #expect(str.utf8.count == convertedAttrStr._guts.runs.first!.length)
            #expect(attrStr == convertedAttrStr)
            
            let convertedNSStr = try NSAttributedString(attrStr, including: AttributeScopes.TestAttributes.self)
            #expect(nsStr == convertedNSStr)
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func conversionWithoutScope() throws {
        // Ensure simple conversion works (no errors when loading AppKit/UIKit/SwiftUI)
        let attrStr = AttributedString()
        let nsStr = NSAttributedString(attrStr)
        #expect(nsStr == NSAttributedString())
        let attrStrReverse = AttributedString(nsStr)
        #expect(attrStrReverse == attrStr)
        
        // Ensure foundation attributes are converted
        let attrStr2 = AttributedString("Hello", attributes: .init().link(URL(string: "http://apple.com")!))
        let nsStr2 = NSAttributedString(attrStr2)
        #expect(nsStr2 == NSAttributedString(string: "Hello", attributes: [.link : URL(string: "http://apple.com")! as NSURL]))
        let attrStr2Reverse = AttributedString(nsStr2)
        #expect(attrStr2Reverse == attrStr2)
        
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
        #expect(result == NSAttributedString(string: "Hello", attributes: [NSAttributedString.Key("TestInt") : 2]))
    }
    
    #if canImport(Accessibility)
    @available(FoundationAttributedString 5.5, *)
    @Test func conversionWithoutScope_Accessibility() throws {
        let attributedString = AttributedString("Hello", attributes: .init().accessibilityTextCustom(["ABC"]))
        let nsAttributedString = NSAttributedString(attributedString)
        #if os(macOS)
        let attribute = NSAttributedString.Key.accessibilityCustomText
        #else
        let attribute = NSAttributedString.Key.accessibilityTextCustom
        #endif
        #expect(nsAttributedString == NSAttributedString(string: "Hello", attributes: [attribute : ["ABC"]]))
        let attributedStringReverse = AttributedString(nsAttributedString)
        #expect(attributedStringReverse == attributedString)
    }
    #endif
    
    #if canImport(AppKit)
    @available(FoundationAttributedString 5.5, *)
    @Test func conversionWithoutScope_AppKit() throws {
        var container = AttributeContainer()
        container.appKit.kern = 2.3
        let attributedString = AttributedString("Hello", attributes: container)
        let nsAttributedString = NSAttributedString(attributedString)
        #expect(nsAttributedString == NSAttributedString(string: "Hello", attributes: [.kern : CGFloat(2.3)]))
        let attributedStringReverse = AttributedString(nsAttributedString)
        #expect(attributedStringReverse == attributedString)
    }
    #endif
    
    #if canImport(UIKit)
    @available(FoundationAttributedString 5.5, *)
    @Test func conversionWithoutScope_UIKit() throws {
        var container = AttributeContainer()
        container.uiKit.kern = 2.3
        let attributedString = AttributedString("Hello", attributes: container)
        let nsAttributedString = NSAttributedString(attributedString)
        #expect(nsAttributedString == NSAttributedString(string: "Hello", attributes: [.kern : CGFloat(2.3)]))
        let attributedStringReverse = AttributedString(nsAttributedString)
        #expect(attributedStringReverse == attributedString)
    }
    #endif
    
    #if canImport(SwiftUI)
    @available(FoundationAttributedString 5.5, *)
    @Test func conversionWithoutScope_SwiftUI() throws {
        var container = AttributeContainer()
        container.swiftUI.kern = 2.3
        let attributedString = AttributedString("Hello", attributes: container)
        let nsAttributedString = NSAttributedString(attributedString)
        #expect(nsAttributedString == NSAttributedString(string: "Hello", attributes: [.init("SwiftUI.Kern") : CGFloat(2.3)]))
        let attributedStringReverse = AttributedString(nsAttributedString)
        #expect(attributedStringReverse == attributedString)
    }
    #endif
    
    @available(FoundationAttributedString 5.5, *)
    @Test func conversionCoalescing() throws {
        let nsStr = NSMutableAttributedString("Hello, world")
        nsStr.setAttributes([.link : NSURL(string: "http://apple.com")!, .testInt : NSNumber(integerLiteral: 2)], range: NSRange(location: 0, length: 6))
        nsStr.setAttributes([.testInt : NSNumber(integerLiteral: 2)], range: NSRange(location: 6, length: 6))
        let attrStr = try AttributedString(nsStr, including: \.test)
        #expect(attrStr.runs.count == 1)
        #expect(attrStr.runs.first!.range == attrStr.startIndex ..< attrStr.endIndex)
        #expect(attrStr.testInt == 2)
        #expect(attrStr.link == nil)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func unalignedConversion() throws {
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
            #expect(attrStr.runs.count == test.1, "Replacement of range \(NSStringFromRange(test.0)) caused a run count of \(attrStr.runs.count)")
        }
    }
    
#endif // FOUNDATION_FRAMEWORK

    // MARK: - View Tests

    @available(FoundationAttributedString 5.5, *)
    @Test func charViewIndexing_backwardsFromEndIndex() {
        let testString = AttributedString("abcdefghi")
        let testChars = testString.characters
        let testIndex = testChars.index(testChars.endIndex, offsetBy: -1)
        #expect(testChars[testIndex] == "i")
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func attrViewIndexing() {
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
        #expect(i == 1)
        #expect(attrStrRuns.count == 1)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func unicodeScalarsViewIndexing() {
        let attrStr = AttributedString("Cafe\u{301}", attributes: AttributeContainer().testInt(1))
        let unicode = attrStr.unicodeScalars
        #expect(unicode[unicode.index(before: unicode.endIndex)] == "\u{301}")
        #expect(unicode[unicode.index(unicode.endIndex, offsetBy: -2)] == "e")
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func characterSlicing() {
        let a: AttributedString = "\u{1f1fa}\u{1f1f8}" // Regional indicators U & S
        let i = a.unicodeScalars.index(after: a.startIndex)
        let b = a.characters[..<i]
        #expect(a.characters.count == 1)
        #expect(b.startIndex == a.startIndex)
        #expect(b.endIndex == a.startIndex)
        #expect(b.count == 0)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func characterSlicing_RangeExpressions() {
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
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            #expect(
                a.elementsEqual(b),
                "'\(Array(a))' does not equal '\(Array(b))'",
                sourceLocation: sourceLocation)
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

    @available(FoundationAttributedString 5.5, *)
    @Test func unicodeScalarsSlicing() {
        let attrStr = AttributedString("Cafe\u{301}", attributes: AttributeContainer().testInt(1))
        let range = attrStr.startIndex ..< attrStr.endIndex
        let substringScalars = attrStr[range].unicodeScalars
        let slicedScalars = attrStr.unicodeScalars[range]
        
        let expected: [UnicodeScalar] = ["C", "a", "f", "e", "\u{301}"]
        #expect(substringScalars.count == expected.count)
        #expect(slicedScalars.count == expected.count)
        var indexA = substringScalars.startIndex
        var indexB = slicedScalars.startIndex
        var indexExpect = expected.startIndex
        while indexA != substringScalars.endIndex && indexB != slicedScalars.endIndex {
            #expect(substringScalars[indexA] == expected[indexExpect])
            #expect(slicedScalars[indexB] == expected[indexExpect])
            indexA = substringScalars.index(after: indexA)
            indexB = slicedScalars.index(after: indexB)
            indexExpect = expected.index(after: indexExpect)
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func protocolRunIndexing() {
        var str = AttributedString("Foo", attributes: .init().testInt(1))
        str += AttributedString("Bar", attributes: .init().testInt(2))
        str += AttributedString("Baz", attributes: .init().testInt(3))

        let runIndices = str.runs.map(\.range.lowerBound) + [str.endIndex]
        
        for (i, index) in runIndices.enumerated().dropLast() {
            #expect(str.index(afterRun: index) == runIndices[i + 1])
        }
        
        for (i, index) in runIndices.enumerated().reversed().dropLast() {
            #expect(str.index(beforeRun: index) == runIndices[i - 1])
        }
        
        for (i, a) in runIndices.enumerated() {
            for (j, b) in runIndices.enumerated() {
                #expect(str.index(a, offsetByRuns: j - i) == b)
            }
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func runSliceSubscripting() {
        var str = AttributedString("Foo", attributes: .init().testInt(1))
        str += AttributedString("Bar", attributes: .init().testInt(2))
        str += AttributedString("Baz", attributes: .init().testInt(3))
        
        do {
            let runsSlice = str.runs[\.testInt]
            for (value, range) in runsSlice {
                for idx in str.utf8[range].indices {
                    let subscriptResult = runsSlice[idx]
                    #expect(subscriptResult.0 == value, "Subscript index \(idx) did not produce same value as runs slice")
                    #expect(subscriptResult.1 == range, "Subscript index \(idx) did not produce same range as runs slice")
                }
            }
        }
        
        do {
            let runsSlice = str[str.index(afterCharacter: str.startIndex) ..< str.index(beforeCharacter: str.endIndex)].runs[\.testInt]
            for (value, range) in runsSlice {
                for idx in str.utf8[range].indices {
                    let subscriptResult = runsSlice[idx]
                    #expect(subscriptResult.0 == value, "Subscript index \(idx) did not produce same value as runs slice")
                    #expect(subscriptResult.1 == range, "Subscript index \(idx) did not produce same range as runs slice")
                }
            }
        }
    }

    // MARK: - Other Tests
    
    @available(FoundationAttributedString 5.5, *)
    @Test func initWithSequence() {
        let expected = AttributedString("Hello World", attributes: AttributeContainer().testInt(2))
        let sequence: [Character] = ["H", "e", "l", "l", "o", " ", "W", "o", "r", "l", "d"]
        
        let container = AttributeContainer().testInt(2)
        let attrStr = AttributedString(sequence, attributes: container)
        #expect(attrStr == expected)
        
        let attrStr2 = AttributedString(sequence, attributes: AttributeContainer().testInt(2))
        #expect(attrStr2 == expected)
        
        let attrStr3 = AttributedString(sequence, attributes: AttributeContainer().testInt(2))
        #expect(attrStr3 == expected)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func longestEffectiveRangeOfAttribute() {
        var str = AttributedString("Abc")
        str += AttributedString("def", attributes: AttributeContainer.testInt(2).testString("World"))
        str += AttributedString("ghi", attributes: AttributeContainer.testInt(2).testBool(true))
        str += AttributedString("jkl", attributes: AttributeContainer.testInt(2).testDouble(3.0))
        str += AttributedString("mno", attributes: AttributeContainer.testString("Hello"))
        
        let idx = str.characters.index(str.startIndex, offsetBy: 7)
        let expectedRange = str.characters.index(str.startIndex, offsetBy: 3) ..< str.characters.index(str.startIndex, offsetBy: 12)
        let (value, range) = str.runs[\.testInt][idx]
        
        #expect(value == 2)
        #expect(range == expectedRange)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func attributeContainer() {
        var container = AttributeContainer().testBool(true).testInt(1)
        #expect(container.testBool == true)
        #expect(container.testString == nil)

        let attrString = AttributedString("Hello", attributes: container)
        for run in attrString.runs {
            #expect("Hello" == String(attrString.characters[run.range]))
            #expect(run.testBool == true)
            #expect(run.testInt == 1)
        }

        container.testBool = nil
        #expect(container.testBool == nil)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func attributeContainerEquality() {
        let containerA = AttributeContainer().testInt(2).testString("test")
        let containerB = AttributeContainer().testInt(2).testString("test")
        let containerC = AttributeContainer().testInt(3).testString("test")
        let containerD = AttributeContainer.testInt(4)
        var containerE = AttributeContainer()
        containerE.testInt = 4
        
        #expect(containerA == containerB)
        #expect(containerB != containerC)
        #expect(containerC != containerD)
        #expect(containerD == containerE)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func attributeContainerSetOnSubstring() {
        let container = AttributeContainer().testBool(true).testInt(1)

        var attrString = AttributedString("Hello world", attributes: container)

        let container2 = AttributeContainer().testString("yellow")
        attrString[attrString.startIndex..<attrString.characters.index(attrString.startIndex, offsetBy: 4)].setAttributes(container2)

        let runs = attrString.runs
        let run = runs[ runs.startIndex ]
        #expect(String(attrString.characters[run.range]) == "Hell")
        #expect(run.testString == "yellow")
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func slice() {
        let attrStr = AttributedString("Hello World")
        let chars = attrStr.characters
        let start = chars.index(chars.startIndex, offsetBy: 6)
        let slice = attrStr[start ..< chars.index(start, offsetBy:5)]
        #expect(AttributedString(slice) == AttributedString("World"))
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func createStringsFromCharactersWithUnicodeScalarIndexes() {
        var attrStr = AttributedString("Caf", attributes: AttributeContainer().testString("a"))
        attrStr += AttributedString("e", attributes: AttributeContainer().testString("b"))
        attrStr += AttributedString("\u{301}", attributes: AttributeContainer().testString("c"))

        // We can use the Unicode scalars view to process sub-character range boundaries.
        let strs1 = attrStr.runs.map {
            String(String.UnicodeScalarView(attrStr.unicodeScalars[$0.range]))
        }
        #expect(strs1 == ["Caf", "e", "\u{301}"])

        // The characters view rounds indices down to the nearest character boundary.
        let strs2 = attrStr.runs.map { String(attrStr.characters[$0.range]) }
        #expect(strs2 == ["Caf", "", "e\u{301}"])
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func settingAttributeOnSlice() throws {
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
                #expect(myInt == value)
                myInt += 1
            }
        }

        var newAttrString = attrString
        newAttrString.testInt = nil

        for (attribute, _) in newAttrString.runs[\.testInt] {
            #expect(attribute == nil)
        }

        let startIndex = attrString.startIndex
        attrString.characters[startIndex] = "D"
        #expect(attrString.characters[startIndex] == "D")
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func expressibleByStringLiteral() {
        let variable : AttributedString = "Test"
        #expect(variable == AttributedString("Test"))

        func takesAttrStr(_ str: AttributedString) {
            #expect(str == AttributedString("Test"))
        }
        takesAttrStr("Test")
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func hashing() {
        let attrStr = AttributedString("Hello, world.", attributes: .init().testInt(2).testBool(false))
        let attrStr2 = AttributedString("Hello, world.", attributes: .init().testInt(2).testBool(false))
        
        var dictionary = [
            attrStr : 123
        ]
        
        dictionary[attrStr2] = 456
        
        #expect(attrStr == attrStr2)
        #expect(dictionary[attrStr] == 456)
        #expect(dictionary[attrStr2] == 456)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func hashingSubstring() {
        let a: AttributedString = "aXa"
        let b: AttributedString = "bXb"

        let i1 = a.characters.index(a.startIndex, offsetBy: 1)
        let i2 = a.characters.index(a.startIndex, offsetBy: 2)

        let j1 = b.characters.index(b.startIndex, offsetBy: 1)
        let j2 = b.characters.index(b.startIndex, offsetBy: 2)

        let substrA = a[i1 ..< i2]
        let substrB = b[j1 ..< j2]

        #expect(substrA == substrB)
        
        var hasherA = Hasher()
        hasherA.combine(substrA)
        var hasherB = Hasher()
        hasherB.combine(substrB)
        #expect(hasherA.finalize() == hasherB.finalize())
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func hashingContainer() {
        let containerA = AttributeContainer.testInt(2).testBool(false)
        let containerB = AttributeContainer.testInt(2).testBool(false)
        
        var dictionary = [
            containerA : 123
        ]
        
        dictionary[containerB] = 456
        
        #expect(containerA == containerB)
        #expect(dictionary[containerA] == 456)
        #expect(dictionary[containerB] == 456)
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func utf16String() {
        let multiByteCharacters = ["\u{2029}", "\u{1D11E}", "\u{1D122}", "\u{1F91A}\u{1F3FB}"]
        
        for str in multiByteCharacters {
            var attrStr = AttributedString("A" + str)
            attrStr += AttributedString("B", attributes: .init().testInt(2))
            attrStr += AttributedString("C", attributes: .init().testInt(3))
            #expect(attrStr == attrStr)
            #expect(attrStr.runs == attrStr.runs)
        }
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func plusOperators() {
        let ab = AttributedString("a") + AttributedString("b")
        #expect(ab == AttributedString("ab"))

        let ab_sub = AttributedString("a") + ab[ab.characters.index(before: ab.endIndex) ..< ab.endIndex]
        #expect(ab_sub == ab)

        let ab_lit = AttributedString("a") + "b"
        #expect(ab_lit == ab)

        var abc = ab
        abc += AttributedString("c")
        #expect(abc == AttributedString("abc"))

        var abc_sub = ab
        abc_sub += abc[abc.characters.index(before: abc.endIndex) ..< abc.endIndex]
        #expect(abc_sub == abc)

        var abc_lit = ab
        abc_lit += "c"
        #expect(abc_lit == abc)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func search() throws {
        let testString = AttributedString("abcdefghi")
        #expect(testString.range(of: "baba") == nil)

        let abc = try #require(testString.range(of: "abc"))
        #expect(abc.lowerBound == testString.startIndex)
        #expect(String(testString[abc].characters) == "abc")

        let def = try #require(testString.range(of: "def"))
        #expect(def.lowerBound == testString.index(testString.startIndex, offsetByCharacters: 3))
        #expect(String(testString[def].characters) == "def")

        let ghi = try #require(testString.range(of: "ghi"))
        #expect(ghi.lowerBound == testString.index(testString.startIndex, offsetByCharacters: 6))
        #expect(String(testString[ghi].characters) == "ghi")

        #expect(testString.range(of: "ghij") == nil)

        let substring = testString[testString.index(afterCharacter: testString.startIndex)..<testString.endIndex]
        #expect(substring.range(of: "abc") == nil)

        let BcD = try #require(testString.range(of: "BcD", options: [.caseInsensitive]))
        #expect(BcD.lowerBound == testString.index(testString.startIndex, offsetByCharacters: 1))
        #expect(String(testString[BcD].characters) == "bcd")

        let ghi_backwards = try #require(testString.range(of: "ghi", options: [.backwards]))
        #expect(ghi_backwards.lowerBound == testString.index(testString.startIndex, offsetByCharacters: 6))
        #expect(String(testString[ghi_backwards].characters) == "ghi")

        let abc_backwards = try #require(testString.range(of: "abc", options: [.backwards]))
        #expect(abc_backwards.lowerBound == testString.startIndex)
        #expect(String(testString[abc_backwards].characters) == "abc")

        let abc_anchored = try #require(testString.range(of: "abc", options: [.anchored]))
        #expect(abc_anchored.lowerBound == testString.startIndex)
        #expect(String(testString[abc_anchored].characters) == "abc")

        let ghi_anchored = try #require(testString.range(of: "ghi", options: [.backwards, .anchored]))
        #expect(ghi_anchored.lowerBound == testString.index(testString.startIndex, offsetByCharacters: 6))
        #expect(String(testString[ghi_anchored].characters) == "ghi")

        #expect(testString.range(of: "bcd", options: [.anchored]) == nil)
        #expect(testString.range(of: "abc", options: [.anchored, .backwards]) == nil)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func substringSearch() throws {
        let fullString = AttributedString("___abcdefghi___")
        let testString = fullString[try #require(fullString.range(of: "abcdefghi"))]
        #expect(testString.range(of: "baba") == nil)

        let abc = try #require(testString.range(of: "abc"))
        #expect(abc.lowerBound == testString.startIndex)
        #expect(String(testString[abc].characters) == "abc")

        let def = try #require(testString.range(of: "def"))
        #expect(def.lowerBound == testString.index(testString.startIndex, offsetByCharacters: 3))
        #expect(String(testString[def].characters) == "def")

        let ghi = try #require(testString.range(of: "ghi"))
        #expect(ghi.lowerBound == testString.index(testString.startIndex, offsetByCharacters: 6))
        #expect(String(testString[ghi].characters) == "ghi")

        #expect(testString.range(of: "ghij") == nil)

        let substring = testString[testString.index(afterCharacter: testString.startIndex)..<testString.endIndex]
        #expect(substring.range(of: "abc") == nil)

        let BcD = try #require(testString.range(of: "BcD", options: [.caseInsensitive]))
        #expect(BcD.lowerBound == testString.index(testString.startIndex, offsetByCharacters: 1))
        #expect(String(testString[BcD].characters) == "bcd")

        let ghi_backwards = try #require(testString.range(of: "ghi", options: [.backwards]))
        #expect(ghi_backwards.lowerBound == testString.index(testString.startIndex, offsetByCharacters: 6))
        #expect(String(testString[ghi_backwards].characters) == "ghi")

        let abc_backwards = try #require(testString.range(of: "abc", options: [.backwards]))
        #expect(abc_backwards.lowerBound == testString.startIndex)
        #expect(String(testString[abc_backwards].characters) == "abc")

        let abc_anchored = try #require(testString.range(of: "abc", options: [.anchored]))
        #expect(abc_anchored.lowerBound == testString.startIndex)
        #expect(String(testString[abc_anchored].characters) == "abc")

        let ghi_anchored = try #require(testString.range(of: "ghi", options: [.backwards, .anchored]))
        #expect(ghi_anchored.lowerBound == testString.index(testString.startIndex, offsetByCharacters: 6))
        #expect(String(testString[ghi_anchored].characters) == "ghi")

        #expect(testString.range(of: "bcd", options: [.anchored]) == nil)
        #expect(testString.range(of: "abc", options: [.anchored, .backwards]) == nil)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func indexConversion() throws {
        let attrStr = AttributedString("ABCDE")
        let str = "ABCDE"

        let attrStrIdx = attrStr.index(attrStr.startIndex, offsetByCharacters: 2)
        #expect(attrStr.characters[attrStrIdx] == "C")

        let strIdx = try #require(String.Index(attrStrIdx, within: str))
        #expect(str[strIdx] == "C")

        let reconvertedAttrStrIdex = AttributedString.Index(strIdx, within: attrStr)!
        #expect(attrStr.characters[reconvertedAttrStrIdex] == "C")
    }
    
#if FOUNDATION_FRAMEWORK

    @available(FoundationAttributedString 5.5, *)
    @Test func rangeConversion() throws {
        let attrStr = AttributedString("ABCDE")
        let nsAS = NSAttributedString("ABCDE")
        let str = "ABCDE"

        let attrStrR = try #require(attrStr.range(of: "BCD"))
        let strR = try #require(Range(attrStrR, in: str))
        let nsASR = NSRange(attrStrR, in: attrStr)

        #expect(nsAS.attributedSubstring(from: nsASR).string == "BCD")
        #expect(str[strR] == "BCD")

        let attrStrR_reconverted1 = Range(strR, in: attrStr)!
        let attrStrR_reconverted2 = Range(nsASR, in: attrStr)!
        #expect(String(attrStr[attrStrR_reconverted1].characters) == "BCD")
        #expect(String(attrStr[attrStrR_reconverted2].characters) == "BCD")
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func unalignedRangeConversion() {
        do {
            // U+0301 Combining Acute Accent (one unicode scalar, one UTF-16)
            let str = "Test Cafe\u{301} Test"
            let attrStr = AttributedString(str)
            let nsRange = NSRange(location: 8, length: 1) // Just the "e" without the accent
            
            let strRange = Range<String.Index>(nsRange, in: str)
            #expect(strRange != nil)
            #expect(strRange == str.unicodeScalars.index(str.startIndex, offsetBy: 8) ..< str.unicodeScalars.index(str.startIndex, offsetBy: 9))
            #expect(str[strRange!] == "e")
            
            var attrStrRange = Range<AttributedString.Index>(nsRange, in: attrStr)
            #expect(attrStrRange != nil)
            #expect(attrStrRange == attrStr.unicodeScalars.index(attrStr.startIndex, offsetBy: 8) ..< attrStr.unicodeScalars.index(attrStr.startIndex, offsetBy: 9))
            #expect(AttributedString(attrStr[attrStrRange!]) == AttributedString("e"))
            
            attrStrRange = Range<AttributedString.Index>(strRange!, in: attrStr)
            #expect(attrStrRange != nil)
            #expect(attrStrRange == attrStr.unicodeScalars.index(attrStr.startIndex, offsetBy: 8) ..< attrStr.unicodeScalars.index(attrStr.startIndex, offsetBy: 9))
            #expect(AttributedString(attrStr[attrStrRange!]) == AttributedString("e"))
            
            #expect(NSRange(strRange!, in: str) == nsRange)
            #expect(NSRange(attrStrRange!, in: attrStr) == nsRange)
            #expect(Range<String.Index>(attrStrRange!, in: str) == strRange!)
        }
        
        do {
            // U+1F3BA Trumpet (one unicode scalar, two UTF-16)
            let str = "Test \u{1F3BA}\u{1F3BA} Test"
            let attrStr = AttributedString(str)
            let nsRange = NSRange(location: 5, length: 3) // The whole first U+1F3BA and the leading surrogate character of the second U+1F3BA
            
            let strRange = Range<String.Index>(nsRange, in: str)
            #expect(strRange != nil)
            #expect(str[strRange!] == "\u{1F3BA}")
            
            var attrStrRange = Range<AttributedString.Index>(nsRange, in: attrStr)
            #expect(attrStrRange != nil)
            #expect(AttributedString(attrStr[attrStrRange!]) == AttributedString("\u{1F3BA}"))
            
            attrStrRange = Range<AttributedString.Index>(strRange!, in: attrStr)
            #expect(attrStrRange != nil)
            #expect(AttributedString(attrStr[attrStrRange!]) == AttributedString("\u{1F3BA}"))
            
            #expect(NSRange(strRange!, in: str) == nsRange)
            #expect(NSRange(attrStrRange!, in: attrStr) == nsRange)
            #expect(Range<String.Index>(attrStrRange!, in: str) == strRange!)
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func nsRangeConversionOnSlice() throws {
        let str = AttributedString("012345")
        let slice = str[str.index(str.startIndex, offsetByCharacters: 3) ..< str.endIndex]
        let nsRange = NSRange(location: 0, length: 2)
        let range = try #require(Range(nsRange, in: slice))
        #expect(String(slice[range].characters) == "34")
    }
    
#endif // FOUNDATION_FRAMEWORK
    
    @available(FoundationAttributedString 5.5, *)
    @Test func oobRangeConversion() {
        let attrStr = AttributedString("")
        let str = "Hello"
        let range = str.index(before: str.endIndex) ..< str.endIndex
        #expect(Range<AttributedString.Index>(range, in: attrStr) == nil)
    }
    
#if FOUNDATION_FRAMEWORK
    // TODO: Support scope-specific AttributedString initialization in FoundationPreview
    @available(FoundationAttributedString 5.5, *)
    @Test func scopedCopy() {
        var str = AttributedString("A")
        str += AttributedString("B", attributes: .init().testInt(2))
        str += AttributedString("C", attributes: .init().link(URL(string: "http://apple.com")!))
        str += AttributedString("D", attributes: .init().testInt(3).link(URL(string: "http://apple.com")!))
        
        struct FoundationAndTest : AttributeScope {
            let foundation: AttributeScopes.FoundationAttributes
            let test: AttributeScopes.TestAttributes
        }
        #expect(AttributedString(str, including: FoundationAndTest.self) == str)
        
        struct None : AttributeScope {
            
        }
        #expect(AttributedString(str, including: None.self) == AttributedString("ABCD"))
        
        var expected = AttributedString("AB")
        expected += AttributedString("CD", attributes: .init().link(URL(string: "http://apple.com")!))
        #expect(AttributedString(str, including: \.foundation) == expected)
        
        expected = AttributedString("A")
        expected += AttributedString("B", attributes: .init().testInt(2))
        expected += "C"
        expected += AttributedString("D", attributes: .init().testInt(3))
        #expect(AttributedString(str, including: \.test) == expected)
        
        let range = str.index(afterCharacter: str.startIndex) ..< str.index(beforeCharacter: str.endIndex)
        expected = AttributedString("B", attributes: .init().testInt(2)) + "C"
        #expect(AttributedString(str[range], including: \.test) == expected)
        
        expected = "B" + AttributedString("C", attributes: .init().link(URL(string: "http://apple.com")!))
        #expect(AttributedString(str[range], including: \.foundation) == expected)
        
        #expect(AttributedString(str[range], including: None.self) == AttributedString("BC"))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func scopeIterationAPI() {
        struct TestScope : AttributeScope {
            let testInt: AttributeScopes.TestAttributes.TestIntAttribute
            let testBool: AttributeScopes.TestAttributes.TestBoolAttribute
        }
        
        let testNames = TestScope.attributeKeys.map { $0.name }.sorted()
        #expect(testNames == [AttributeScopes.TestAttributes.TestBoolAttribute.name, AttributeScopes.TestAttributes.TestIntAttribute.name].sorted())
        
        struct EmptyScope : AttributeScope {
            
        }
        for key in EmptyScope.attributeKeys {
            Issue.record("Empty scope should not have produced key \(key)")
        }
    }
#endif // FOUNDATION_FRAMEWORK

    @available(FoundationAttributedString 5.5, *)
    @Test func assignDifferentSubstring() {
        var attrStr1 = AttributedString("ABCDE")
        let attrStr2 = AttributedString("XYZ")

        attrStr1[ attrStr1.range(of: "BCD")! ] = attrStr2[ attrStr2.range(of: "X")! ]

        #expect(attrStr1 == "AXE")
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func cowDuringSubstringMutation() {
        func frobnicate(_ sub: inout AttributedSubstring) {
            var new = sub
            new.testInt = 2
            new.testString = "Hello"
            sub = new
        }
        var attrStr = AttributedString("ABCDE")
        frobnicate(&attrStr[ attrStr.range(of: "BCD")! ])

        let expected = AttributedString("A") + AttributedString("BCD", attributes: .init().testInt(2).testString("Hello")) + AttributedString("E")
        #expect(attrStr == expected)
    }

    #if FOUNDATION_EXIT_TESTS
    @available(FoundationAttributedString 5.5, *)
    @Test func reassignmentDuringMutation() async {
        await #expect(processExitsWith: .failure) {
            func frobnicate(_ sub: inout AttributedSubstring) {
                let other = AttributedString("XYZ")
                sub = other[ other.range(of: "X")! ]
            }
            var attrStr = AttributedString("ABCDE")
            frobnicate(&attrStr[ attrStr.range(of: "BCD")! ])
        }
    }
    #endif

    @available(FoundationAttributedString 5.5, *)
    @Test func assignDifferentCharacterView() {
        var attrStr1 = AttributedString("ABC", attributes: .init().testInt(1)) + AttributedString("DE", attributes: .init().testInt(3))
        let attrStr2 = AttributedString("XYZ", attributes: .init().testInt(2))

        attrStr1.characters = attrStr2.characters
        #expect(attrStr1 == AttributedString("XYZ", attributes: .init().testInt(1)))
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func cowDuringCharactersMutation() {
        func frobnicate(_ chars: inout AttributedString.CharacterView) {
            var new = chars
            new.replaceSubrange(chars.startIndex ..< chars.endIndex, with: "XYZ")
            chars = new
        }
        var attrStr = AttributedString("ABCDE", attributes: .init().testInt(1))
        frobnicate(&attrStr.characters)

        #expect(attrStr == AttributedString("XYZ", attributes: .init().testInt(1)))
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func assignDifferentUnicodeScalarView() {
        var attrStr1 = AttributedString("ABC", attributes: .init().testInt(1)) + AttributedString("DE", attributes: .init().testInt(3))
        let attrStr2 = AttributedString("XYZ", attributes: .init().testInt(2))

        attrStr1.unicodeScalars = attrStr2.unicodeScalars
        #expect(attrStr1 == AttributedString("XYZ", attributes: .init().testInt(1)))
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func cowDuringUnicodeScalarsMutation() {
        func frobnicate(_ chars: inout AttributedString.CharacterView) {
            var new = chars
            new.replaceSubrange(chars.startIndex ..< chars.endIndex, with: "XYZ")
            chars = new
        }
        var attrStr = AttributedString("ABCDE", attributes: .init().testInt(1))
        frobnicate(&attrStr.characters)

        #expect(attrStr == AttributedString("XYZ", attributes: .init().testInt(1)))
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func utf88View() {
        let testStrings = [
            "Hello, world",
            "🎺😄abc🎶def",
            "¡Hola! ¿Cómo estás?",
            "שָׁלוֹם"
        ]
        
        for string in testStrings {
            let attrStr = AttributedString(string)
            #expect(attrStr.utf8.count == string.utf8.count, "Counts are not equal for string \(string)")
            #expect(attrStr.utf8.elementsEqual(string.utf8), "Full elements are not equal for string \(string)")
            for offset in 0 ..< string.utf8.count {
                let idxInString = string.utf8.index(string.startIndex, offsetBy: offset)
                let idxInAttrStr = attrStr.utf8.index(attrStr.startIndex, offsetBy: offset)
                #expect(
                    string.utf8.distance(from: string.startIndex, to: idxInString) ==
                    attrStr.utf8.distance(from: attrStr.startIndex, to: idxInAttrStr),
                    "Offsets to \(idxInString) are not equal for string \(string)"
                )
                #expect(string.utf8[idxInString] == attrStr.utf8[idxInAttrStr], "Elements at offset \(offset) are not equal for string \(string)")
                #expect(string.utf8[..<idxInString].elementsEqual(attrStr.utf8[..<idxInAttrStr]), "Slices up to \(offset) are not equal for string \(string)")
                #expect(string.utf8[idxInString...].elementsEqual(attrStr.utf8[idxInAttrStr...]), "Slices from \(offset) are not equal for string \(string)")
                #expect(string[..<idxInString].utf8.elementsEqual(attrStr[..<idxInAttrStr].utf8), "Slices up to \(offset) are not equal for string \(string)")
                #expect(string[idxInString...].utf8.elementsEqual(attrStr[idxInAttrStr...].utf8), "Slices from \(offset) are not equal for string \(string)")
            }
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func utf16View() {
        let testStrings = [
            "Hello, world",
            "🎺😄abc🎶def",
            "¡Hola! ¿Cómo estás?",
            "שָׁלוֹם"
        ]
        
        for string in testStrings {
            let attrStr = AttributedString(string)
            #expect(attrStr.utf16.count == string.utf16.count, "Counts are not equal for string \(string)")
            #expect(attrStr.utf16.elementsEqual(string.utf16), "Full elements are not equal for string \(string)")
            for offset in 0 ..< string.utf16.count {
                let idxInString = string.utf16.index(string.startIndex, offsetBy: offset)
                let idxInAttrStr = attrStr.utf16.index(attrStr.startIndex, offsetBy: offset)
                #expect(
                    string.utf16.distance(from: string.startIndex, to: idxInString) ==
                    attrStr.utf16.distance(from: attrStr.startIndex, to: idxInAttrStr),
                    "Offsets to \(idxInString) are not equal for string \(string)"
                )
                #expect(string.utf16[idxInString] == attrStr.utf16[idxInAttrStr], "Elements at offset \(offset) are not equal for string \(string)")
                #expect(string.utf16[..<idxInString].elementsEqual(attrStr.utf16[..<idxInAttrStr]), "Slices up to \(offset) are not equal for string \(string)")
                #expect(string.utf16[idxInString...].elementsEqual(attrStr.utf16[idxInAttrStr...]), "Slices from \(offset) are not equal for string \(string)")
                #expect(string[..<idxInString].utf16.elementsEqual(attrStr[..<idxInAttrStr].utf16), "Slices up to \(offset) are not equal for string \(string)")
                #expect(string[idxInString...].utf16.elementsEqual(attrStr[idxInAttrStr...].utf16), "Slices from \(offset) are not equal for string \(string)")
            }
        }
    }
    
    @available(FoundationAttributedString 5.5, *)
    @Test func attributeContainerFiltering() {
        #expect(AttributeContainer().filter(runBoundaries: nil) == AttributeContainer())
        #expect(AttributeContainer().filter(runBoundaries: .paragraph) == AttributeContainer())
        #expect(AttributeContainer().filter(inheritedByAddedText: true) == AttributeContainer())
        #expect(AttributeContainer().filter(inheritedByAddedText: false) == AttributeContainer())
        
        let testContainer = AttributeContainer.testInt(2).testBool(true).testString("Hello")
        #expect(testContainer.filter(runBoundaries: nil) == testContainer)
        #expect(testContainer.filter(runBoundaries: .paragraph) == AttributeContainer())
        #expect(testContainer.filter(inheritedByAddedText: true) == testContainer)
        #expect(testContainer.filter(inheritedByAddedText: false) == AttributeContainer())
        
        let testConstrainedContainer = AttributeContainer.testInt(2).testParagraphConstrained(3).testCharacterConstrained(4).testNonExtended(5)
        #expect(testConstrainedContainer.filter(runBoundaries: nil) == AttributeContainer.testInt(2).testNonExtended(5))
        #expect(testConstrainedContainer.filter(runBoundaries: .paragraph) == AttributeContainer.testParagraphConstrained(3))
        #expect(testConstrainedContainer.filter(runBoundaries: .character("A")) == AttributeContainer())
        #expect(testConstrainedContainer.filter(runBoundaries: .character("*")) == AttributeContainer.testCharacterConstrained(4))
        #expect(testConstrainedContainer.filter(inheritedByAddedText: true) == AttributeContainer.testInt(2).testParagraphConstrained(3).testCharacterConstrained(4))
        #expect(testConstrainedContainer.filter(inheritedByAddedText: false) == AttributeContainer.testNonExtended(5))
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func writingDirectionBehavior() throws {
        // Indicate that this sentence is primarily right to left, because the English term "Swift" is embedded into an Arabic sentence.
        var string = AttributedString("Swift مذهل!", attributes: .init().writingDirection(.rightToLeft))

        #expect(string.writingDirection == .rightToLeft)

        // To remove the information about the writing direction, set it to `nil`:
        string.writingDirection = nil

        #expect(string.writingDirection == nil)

        let range = try #require(string.range(of: "Swift"))

        // When setting or removing the value from a certain range, the value will always be applied to the entire paragraph(s) that intersect with that range:
        string[range].writingDirection = .leftToRight
        #expect(string.runs[\.writingDirection].count == 1)

        string.append(AttributedString(" It is awesome for working with strings!"))
        #expect(string.runs[\.writingDirection].count == 1)
        #expect(string.writingDirection == .leftToRight)

        string.append(AttributedString("\nThe new paragraph does not inherit the writing direction."))
        #expect(string.runs[\.writingDirection].count == 2)
        #expect(string.runs.last?.writingDirection == nil)
    }
}
