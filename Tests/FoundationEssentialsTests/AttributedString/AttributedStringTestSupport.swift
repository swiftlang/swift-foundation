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
extension NSAttributedString.Key {
    static let testInt = NSAttributedString.Key("TestInt")
    static let testString = NSAttributedString.Key("TestString")
    static let testDouble = NSAttributedString.Key("TestDouble")
    static let testBool = NSAttributedString.Key("TestBool")
    static let testParagraphConstrained = NSAttributedString.Key("TestParagraphConstrained")
    static let testSecondParagraphConstrained = NSAttributedString.Key("TestSecondParagraphConstrained")
    static let testCharacterConstrained = NSAttributedString.Key("TestCharacterConstrained")
}
#endif

extension AttributeScopes.TestAttributes {

    enum TestIntAttribute: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestInt"
    }

    enum TestStringAttribute: CodableAttributedStringKey {
        typealias Value = String
        static let name = "TestString"
    }

    enum TestDoubleAttribute: CodableAttributedStringKey {
        typealias Value = Double
        static let name = "TestDouble"
    }

    enum TestBoolAttribute: CodableAttributedStringKey {
        typealias Value = Bool
        static let name = "TestBool"
    }

    enum TestNonExtended: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestNonExtended"
        static let inheritedByAddedText: Bool = false
    }

    enum TestParagraphConstrained: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestParagraphConstrained"
        static let runBoundaries: AttributedString.AttributeRunBoundaries? = .paragraph
    }

    enum TestSecondParagraphConstrained: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestSecondParagraphConstrained"
        static let runBoundaries: AttributedString.AttributeRunBoundaries? = .paragraph
    }

    enum TestCharacterConstrained: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestCharacterConstrained"
        static let runBoundaries: AttributedString.AttributeRunBoundaries? = .character("*")
    }

    enum TestUnicodeCharacterConstrained: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestUnicodeCharacterConstrained"
        static let runBoundaries: AttributedString.AttributeRunBoundaries? = .character("👍🏻") // U+1F44D Thumbs Up Sign + U+1F3FB Emoji Modifier Fitzpatrick Type-1-2
    }

    enum TestAttributeDependent: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestAttributeDependent"
        static let invalidationConditions: Set<AttributedString.AttributeInvalidationCondition>? = [.attributeChanged(\.testInt)]
    }

    enum TestCharacterDependent: CodableAttributedStringKey {
        typealias Value = Int
        static let name = "TestCharacterDependent"
        static let invalidationConditions: Set<AttributedString.AttributeInvalidationCondition>? = [.textChanged]
    }

    enum NonCodableAttribute: AttributedStringKey {
        typealias Value = NonCodableType
        static let name = "NonCodable"
    }

    enum CustomCodableAttribute: CodableAttributedStringKey {
        typealias Value = NonCodableType
        static let name = "NonCodableConvertible"

        static func encode(_ value: NonCodableType, to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            try c.encode(value.inner)
        }

        static func decode(from decoder: Decoder) throws -> NonCodableType {
            let c = try decoder.singleValueContainer()
            let inner = try c.decode(Int.self)
            return NonCodableType(inner: inner)
        }
    }
}

#if FOUNDATION_FRAMEWORK
extension AttributeScopes.TestAttributes.TestIntAttribute: MarkdownDecodableAttributedStringKey {}
extension AttributeScopes.TestAttributes.TestStringAttribute: MarkdownDecodableAttributedStringKey {}
extension AttributeScopes.TestAttributes.TestBoolAttribute: MarkdownDecodableAttributedStringKey {}
extension AttributeScopes.TestAttributes.TestDoubleAttribute: MarkdownDecodableAttributedStringKey {}
#endif // FOUNDATION_FRAMEWORK

struct NonCodableType: Hashable {
    var inner: Int
}

extension AttributeScopes {
    var test: TestAttributes.Type { TestAttributes.self }

    struct TestAttributes: AttributeScope {
        var testInt: TestIntAttribute
        var testString: TestStringAttribute
        var testDouble: TestDoubleAttribute
        var testBool: TestBoolAttribute
        var testNonExtended: TestNonExtended
        var testParagraphConstrained: TestParagraphConstrained
        var testSecondParagraphConstrained: TestSecondParagraphConstrained
        var testCharacterConstrained: TestCharacterConstrained
        var testUnicodeCharacterConstrained: TestUnicodeCharacterConstrained
        var testAttributeDependent: TestAttributeDependent
        var testCharacterDependent: TestCharacterDependent
    }
}

extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.TestAttributes, T>) -> T {
        get { self[T.self] }
    }
}

enum TestError: Error {
    case encodingError
    case decodingError
    case conversionError
    case markdownError
}

#if !FOUNDATION_FRAMEWORK

extension AttributedStringProtocol {
    func range(of other: String) -> Range<AttributedString.Index>? {
        let str = String(characters)
        guard let strRange = str.firstRange(of: other) else { return nil }
        let start = str.unicodeScalars.distance(from: str.startIndex, to: strRange.lowerBound)
        let end = str.unicodeScalars.distance(from: str.startIndex, to: strRange.upperBound)
        return unicodeScalars.index(startIndex, offsetBy: start) ..< unicodeScalars.index(startIndex, offsetBy: end)
    }
}

#endif // !FOUNDATION_FRAMEWORK
