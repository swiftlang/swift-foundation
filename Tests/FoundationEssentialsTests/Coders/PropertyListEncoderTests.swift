// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//

import Testing

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

// MARK: - Test Suite

struct TestPropertyListEncoder {
    // MARK: - Encoding Top-Level Empty Types
#if FIXED_64141381
    @Test func testEncodingTopLevelEmptyStruct() {
        let empty = EmptyStruct()
        _testRoundTrip(of: empty, in: .binary, expectedPlist: _plistEmptyDictionaryBinary)
        _testRoundTrip(of: empty, in: .xml, expectedPlist: _plistEmptyDictionaryXML)
    }

    @Test func testEncodingTopLevelEmptyClass() {
        let empty = EmptyClass()
        _testRoundTrip(of: empty, in: .binary, expectedPlist: _plistEmptyDictionaryBinary)
        _testRoundTrip(of: empty, in: .xml, expectedPlist: _plistEmptyDictionaryXML)
    }
#endif

    // MARK: - Encoding Top-Level Single-Value Types
    @Test func testEncodingTopLevelSingleValueEnum() {
        let s1 = Switch.off
        _testEncodeFailure(of: s1, in: .binary)
        _testEncodeFailure(of: s1, in: .xml)
        _testRoundTrip(of: TopLevelWrapper(s1), in: .binary)
        _testRoundTrip(of: TopLevelWrapper(s1), in: .xml)

        let s2 = Switch.on
        _testEncodeFailure(of: s2, in: .binary)
        _testEncodeFailure(of: s2, in: .xml)
        _testRoundTrip(of: TopLevelWrapper(s2), in: .binary)
        _testRoundTrip(of: TopLevelWrapper(s2), in: .xml)
    }

    @Test func testEncodingTopLevelSingleValueStruct() {
        let t = Timestamp(3141592653)
        _testEncodeFailure(of: t, in: .binary)
        _testEncodeFailure(of: t, in: .xml)
        _testRoundTrip(of: TopLevelWrapper(t), in: .binary)
        _testRoundTrip(of: TopLevelWrapper(t), in: .xml)
    }

    @Test func testEncodingTopLevelSingleValueClass() {
        let c = Counter()
        _testEncodeFailure(of: c, in: .binary)
        _testEncodeFailure(of: c, in: .xml)
        _testRoundTrip(of: TopLevelWrapper(c), in: .binary)
        _testRoundTrip(of: TopLevelWrapper(c), in: .xml)
    }

    // MARK: - Encoding Top-Level Structured Types
    @Test func testEncodingTopLevelStructuredStruct() {
        // Address is a struct type with multiple fields.
        let address = Address.testValue
        _testRoundTrip(of: address, in: .binary)
        _testRoundTrip(of: address, in: .xml)
    }

    @Test func testEncodingTopLevelStructuredClass() {
        // Person is a class with multiple fields.
        let person = Person.testValue
        _testRoundTrip(of: person, in: .binary)
        _testRoundTrip(of: person, in: .xml)
    }

    @Test func testEncodingTopLevelStructuredSingleStruct() {
        // Numbers is a struct which encodes as an array through a single value container.
        let numbers = Numbers.testValue
        _testRoundTrip(of: numbers, in: .binary)
        _testRoundTrip(of: numbers, in: .xml)
    }

    @Test func testEncodingTopLevelStructuredSingleClass() {
        // Mapping is a class which encodes as a dictionary through a single value container.
        let mapping = Mapping.testValue
        _testRoundTrip(of: mapping, in: .binary)
        _testRoundTrip(of: mapping, in: .xml)
    }

    @Test func testEncodingTopLevelDeepStructuredType() {
        // Company is a type with fields which are Codable themselves.
        let company = Company.testValue
        _testRoundTrip(of: company, in: .binary)
        _testRoundTrip(of: company, in: .xml)
    }

    @Test func testEncodingClassWhichSharesEncoderWithSuper() {
        // Employee is a type which shares its encoder & decoder with its superclass, Person.
        let employee = Employee.testValue
        _testRoundTrip(of: employee, in: .binary)
        _testRoundTrip(of: employee, in: .xml)
    }

    @Test func testEncodingTopLevelNullableType() {
        // EnhancedBool is a type which encodes either as a Bool or as nil.
        _testEncodeFailure(of: EnhancedBool.true, in: .binary)
        _testEncodeFailure(of: EnhancedBool.true, in: .xml)
        _testEncodeFailure(of: EnhancedBool.false, in: .binary)
        _testEncodeFailure(of: EnhancedBool.false, in: .xml)
        _testEncodeFailure(of: EnhancedBool.fileNotFound, in: .binary)
        _testEncodeFailure(of: EnhancedBool.fileNotFound, in: .xml)

        _testRoundTrip(of: TopLevelWrapper(EnhancedBool.true), in: .binary)
        _testRoundTrip(of: TopLevelWrapper(EnhancedBool.true), in: .xml)
        _testRoundTrip(of: TopLevelWrapper(EnhancedBool.false), in: .binary)
        _testRoundTrip(of: TopLevelWrapper(EnhancedBool.false), in: .xml)
        _testRoundTrip(of: TopLevelWrapper(EnhancedBool.fileNotFound), in: .binary)
        _testRoundTrip(of: TopLevelWrapper(EnhancedBool.fileNotFound), in: .xml)
    }

    @Test func testEncodingTopLevelWithConfiguration() throws {
        // CodableTypeWithConfiguration is a struct that conforms to CodableWithConfiguration
        let value = CodableTypeWithConfiguration.testValue
        let encoder = PropertyListEncoder()
        let decoder = PropertyListDecoder()

        var decoded = try decoder.decode(CodableTypeWithConfiguration.self, from: try encoder.encode(value, configuration: .init(1)), configuration: .init(1))
        #expect(decoded == value)
        decoded = try decoder.decode(CodableTypeWithConfiguration.self, from: try encoder.encode(value, configuration: CodableTypeWithConfiguration.ConfigProviding.self), configuration: CodableTypeWithConfiguration.ConfigProviding.self)
        #expect(decoded == value)
    }

#if FIXED_64141381
    @Test func testEncodingMultipleNestedContainersWithTheSameTopLevelKey() {
        struct Model : Codable, Equatable {
            let first: String
            let second: String

            init(from coder: Decoder) throws {
                let container = try coder.container(keyedBy: TopLevelCodingKeys.self)

                let firstNestedContainer = try container.nestedContainer(keyedBy: FirstNestedCodingKeys.self, forKey: .top)
                self.first = try firstNestedContainer.decode(String.self, forKey: .first)

                let secondNestedContainer = try container.nestedContainer(keyedBy: SecondNestedCodingKeys.self, forKey: .top)
                self.second = try secondNestedContainer.decode(String.self, forKey: .second)
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: TopLevelCodingKeys.self)

                var firstNestedContainer = container.nestedContainer(keyedBy: FirstNestedCodingKeys.self, forKey: .top)
                try firstNestedContainer.encode(self.first, forKey: .first)

                var secondNestedContainer = container.nestedContainer(keyedBy: SecondNestedCodingKeys.self, forKey: .top)
                try secondNestedContainer.encode(self.second, forKey: .second)
            }

            init(first: String, second: String) {
                self.first = first
                self.second = second
            }

            static var testValue: Model {
                return Model(first: "Johnny Appleseed",
                             second: "appleseed@apple.com")
            }
            enum TopLevelCodingKeys : String, CodingKey {
                case top
            }

            enum FirstNestedCodingKeys : String, CodingKey {
                case first
            }
            enum SecondNestedCodingKeys : String, CodingKey {
                case second
            }
        }

        let model = Model.testValue
        let expectedXML = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n\t<key>top</key>\n\t<dict>\n\t\t<key>first</key>\n\t\t<string>Johnny Appleseed</string>\n\t\t<key>second</key>\n\t\t<string>appleseed@apple.com</string>\n\t</dict>\n</dict>\n</plist>\n".data(using: String._Encoding.utf8)!
        _testRoundTrip(of: model, in: .xml, expectedPlist: expectedXML)
    }
#endif

#if false // FIXME: XCTest doesn't support crash tests yet rdar://20195010&22387653
    @Test func testEncodingConflictedTypeNestedContainersWithTheSameTopLevelKey() {
        struct Model : Encodable, Equatable {
            let first: String

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: TopLevelCodingKeys.self)

                var firstNestedContainer = container.nestedContainer(keyedBy: FirstNestedCodingKeys.self, forKey: .top)
                try firstNestedContainer.encode(self.first, forKey: .first)

                // The following line would fail as it attempts to re-encode into already encoded container is invalid. This will always fail
                var secondNestedContainer = container.nestedUnkeyedContainer(forKey: .top)
                try secondNestedContainer.encode("second")
            }

            init(first: String) {
                self.first = first
            }

            static var testValue: Model {
                return Model(first: "Johnny Appleseed")
            }
            enum TopLevelCodingKeys : String, CodingKey {
                case top
            }

            enum FirstNestedCodingKeys : String, CodingKey {
                case first
            }
        }

        let model = Model.testValue
        // This following test would fail as it attempts to re-encode into already encoded container is invalid. This will always fail
        expectCrashLater()
        _testEncodeFailure(of: model, in: .xml)
    }
#endif

    // MARK: - Encoder Features
    @Test func testNestedContainerCodingPaths() {
        let encoder = PropertyListEncoder()
        #expect(throws: Never.self) {
            try encoder.encode(NestedContainersTestType())
        }
    }

    @Test func testSuperEncoderCodingPaths() {
        let encoder = PropertyListEncoder()
        #expect(throws: Never.self) {
            try encoder.encode(NestedContainersTestType(testSuperEncoder: true))
        }
    }

#if FOUNDATION_FRAMEWORK
    // requires PropertyListSerialization, JSONSerialization
    
    @Test func testEncodingTopLevelData() throws {
        let data = try JSONSerialization.data(withJSONObject: [String](), options: [])
        _testRoundTrip(of: data, in: .binary, expectedPlist: try PropertyListSerialization.data(fromPropertyList: data, format: .binary, options: 0))
        _testRoundTrip(of: data, in: .xml, expectedPlist: try PropertyListSerialization.data(fromPropertyList: data, format: .xml, options: 0))
    }

    @Test func testInterceptData() throws {
        let data = try JSONSerialization.data(withJSONObject: [String](), options: [])
        let topLevel = TopLevelWrapper(data)
        let plist = ["value": data]
        _testRoundTrip(of: topLevel, in: .binary, expectedPlist: try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0))
        _testRoundTrip(of: topLevel, in: .xml, expectedPlist: try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0))
    }

    @Test func testInterceptDate() throws {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let topLevel = TopLevelWrapper(date)
        let plist = ["value": date]
        _testRoundTrip(of: topLevel, in: .binary, expectedPlist: try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0))
        _testRoundTrip(of: topLevel, in: .xml, expectedPlist: try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0))
    }
#endif // FOUNDATION_FRaMEWORK

    // MARK: - Type coercion
    @Test func testTypeCoercion() throws {
        func _testRoundTripTypeCoercionFailure<T,U>(of value: T, as type: U.Type, sourceLocation: SourceLocation = #_sourceLocation) throws where T : Codable, U : Codable {
            let encoder = PropertyListEncoder()

            encoder.outputFormat = .xml
            let xmlData = try encoder.encode(value)
            #expect(throws: (any Error).self, "Coercion from \(T.self) to \(U.self) for xml plist was expected to fail.", sourceLocation: sourceLocation) {
                try PropertyListDecoder().decode(U.self, from: xmlData)
            }

            encoder.outputFormat = .binary
            let binaryData = try encoder.encode(value)
            #expect(throws: (any Error).self, "Coercion from \(T.self) to \(U.self) for binary plist was expected to fail.", sourceLocation: sourceLocation) {
                try PropertyListDecoder().decode(U.self, from: binaryData)
            }
        }

        try _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int].self)
        try _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int8].self)
        try _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int16].self)
        try _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int32].self)
        try _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int64].self)
        try _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt].self)
        try _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt8].self)
        try _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt16].self)
        try _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt32].self)
        try _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt64].self)
        try _testRoundTripTypeCoercionFailure(of: [false, true], as: [Float].self)
        try _testRoundTripTypeCoercionFailure(of: [false, true], as: [Double].self)
        try _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int], as: [Bool].self)
        try _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int8], as: [Bool].self)
        try _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int16], as: [Bool].self)
        try _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int32], as: [Bool].self)
        try _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int64], as: [Bool].self)
        try _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt], as: [Bool].self)
        try _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt8], as: [Bool].self)
        try _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt16], as: [Bool].self)
        try _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt32], as: [Bool].self)
        try _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt64], as: [Bool].self)
        try _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Float], as: [Bool].self)
        try _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Double], as: [Bool].self)

        // Real -> Integer coercions that are impossible.
        try _testRoundTripTypeCoercionFailure(of: [256] as [Double], as: [UInt8].self)
        try _testRoundTripTypeCoercionFailure(of: [-129] as [Double], as: [Int8].self)
        try _testRoundTripTypeCoercionFailure(of: [-1.0] as [Double], as: [UInt64].self)
        try _testRoundTripTypeCoercionFailure(of: [3.14159] as [Double], as: [UInt64].self)
        try _testRoundTripTypeCoercionFailure(of: [.infinity] as [Double], as: [UInt64].self)
        try _testRoundTripTypeCoercionFailure(of: [.nan] as [Double], as: [UInt64].self)

        // Especially for binary plist, ensure we maintain different encoded representations of special values like Int64(-1) and UInt64.max, which have the same 8 byte representation.
        try _testRoundTripTypeCoercionFailure(of: [Int64(-1)], as: [UInt64].self)
        try _testRoundTripTypeCoercionFailure(of: [UInt64.max], as: [Int64].self)
    }

    @Test func testIntegerRealCoercion() throws {
        func _testRoundTripTypeCoercion<T: Codable, U: Codable & Equatable>(of value: T, expectedCoercedValue: U, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let encoder = PropertyListEncoder()

            encoder.outputFormat = .xml

            let xmlData = try encoder.encode([value])
            var decoded = try PropertyListDecoder().decode([U].self, from: xmlData)
            #expect(decoded.first == expectedCoercedValue, sourceLocation: sourceLocation)

            encoder.outputFormat = .binary
            let binaryData = try encoder.encode([value])

            decoded = try PropertyListDecoder().decode([U].self, from: binaryData)
            #expect(decoded.first == expectedCoercedValue, sourceLocation: sourceLocation)
        }

        try _testRoundTripTypeCoercion(of: 1 as UInt64, expectedCoercedValue: 1.0 as Double)
        try _testRoundTripTypeCoercion(of: -1 as Int64, expectedCoercedValue: -1.0 as Float)
        try _testRoundTripTypeCoercion(of: UInt64.max, expectedCoercedValue: Double(UInt64.max))
        try _testRoundTripTypeCoercion(of: Int64.min, expectedCoercedValue: Double(Int64.min))

        try _testRoundTripTypeCoercion(of: 1.0 as Double, expectedCoercedValue: 1 as UInt8)
        try _testRoundTripTypeCoercion(of: 1.0 as Double, expectedCoercedValue: 1 as UInt64)
        try _testRoundTripTypeCoercion(of: 1.0 as Double, expectedCoercedValue: 1 as Int32)
        try _testRoundTripTypeCoercion(of: -1.0 as Double, expectedCoercedValue: -1 as Int8)
        try _testRoundTripTypeCoercion(of: 255.0 as Double, expectedCoercedValue: 255 as UInt8)
        try _testRoundTripTypeCoercion(of: -127.0 as Double, expectedCoercedValue: -127 as Int8)
        try _testRoundTripTypeCoercion(of: 2.99792458e8 as Double, expectedCoercedValue: 299792458)
    }

    @Test func testDecodingConcreteTypeParameter() throws {
        let encoder = PropertyListEncoder()
        let plist = try encoder.encode(Employee.testValue)

        let decoder = PropertyListDecoder()
        let decoded = try decoder.decode(Employee.self as Person.Type, from: plist)

        #expect(type(of: decoded) == Employee.self, "Expected decoded value to be of type Employee")
    }

    // MARK: - Encoder State
    // SR-6078
    @Test func testEncoderStateThrowOnEncode() {
        struct Wrapper<T : Encodable> : Encodable {
            let value: T
            init(_ value: T) { self.value = value }

            func encode(to encoder: Encoder) throws {
                // This approximates a subclass calling into its superclass, where the superclass encodes a value that might throw.
                // The key here is that getting the superEncoder creates a referencing encoder.
                var container = encoder.unkeyedContainer()
                let superEncoder = container.superEncoder()

                // Pushing a nested container on leaves the referencing encoder with multiple containers.
                var nestedContainer = superEncoder.unkeyedContainer()
                try nestedContainer.encode(value)
            }
        }

        struct Throwing : Encodable {
            func encode(to encoder: Encoder) throws {
                enum EncodingError : Error { case foo }
                throw EncodingError.foo
            }
        }

        // The structure that would be encoded here looks like
        //
        //   <array>
        //     <array>
        //       <array>
        //         [throwing]
        //       </array>
        //     </array>
        //   </array>
        //
        // The wrapper asks for an unkeyed container ([^]), gets a super encoder, and creates a nested container into that ([[^]]).
        // We then encode an array into that ([[[^]]]), which happens to be a value that causes us to throw an error.
        //
        // The issue at hand reproduces when you have a referencing encoder (superEncoder() creates one) that has a container on the stack (unkeyedContainer() adds one) that encodes a value going through box_() (Array does that) that encodes something which throws (Throwing does that).
        // When reproducing, this will cause a test failure via fatalError().
        _ = try? PropertyListEncoder().encode(Wrapper([Throwing()]))
    }

    // MARK: - Decoder State
    // SR-6048
    @Test func testDecoderStateThrowOnDecode() {
        #expect(throws: Never.self) {
            let plist = try PropertyListEncoder().encode([1,2,3])
            let _ = try PropertyListDecoder().decode(EitherDecodable<[String], [Int]>.self, from: plist)
        }
    }

#if FOUNDATION_FRAMEWORK
    // MARK: - NSKeyedArchiver / NSKeyedUnarchiver integration
    @Test func testArchiving() throws {
        struct CodableType: Codable, Equatable {
            let willBeNil: String?
            let arrayOfOptionals: [String?]
            let dictionaryOfArrays: [String: [Data]]
        }


        let keyedArchiver = NSKeyedArchiver(requiringSecureCoding: false)
        keyedArchiver.outputFormat = .xml

        let value = CodableType(willBeNil: nil,
                                arrayOfOptionals: ["a", "b", nil, "c"],
                                dictionaryOfArrays: [ "data" : [Data([0xfe, 0xed, 0xfa, 0xce]), Data([0xba, 0xaa, 0xaa, 0xad])]])

        try keyedArchiver.encodeEncodable(value, forKey: "strings")
        keyedArchiver.finishEncoding()
        let data = keyedArchiver.encodedData

        let keyedUnarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        let unarchived = try keyedUnarchiver.decodeTopLevelDecodable(CodableType.self, forKey: "strings")

        #expect(unarchived == value)
    }
#endif
    
    // MARK: - Helper Functions
    private var _plistEmptyDictionaryBinary: Data {
        return Data(base64Encoded: "YnBsaXN0MDDQCAAAAAAAAAEBAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAJ")!
    }

    private var _plistEmptyDictionaryXML: Data {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict/>\n</plist>\n".data(using: String._Encoding.utf8)!
    }

    private func _testEncodeFailure<T : Encodable>(of value: T, in format: PropertyListDecoder.PropertyListFormat, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(throws: (any Error).self, "Encode of top-level \(T.self) was expected to fail.", sourceLocation: sourceLocation) {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = format
            let _ = try encoder.encode(value)
        }
    }

    // MARK: - Other tests
    @Test func testUnkeyedContainerContainingNulls() throws {
        struct UnkeyedContainerContainingNullTestType : Codable, Equatable {
            var array = [String?]()
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                // We want to test this with explicit encodeNil calls.
                for value in array {
                    if value == nil {
                        try container.encodeNil()
                    } else {
                        try container.encode(value!)
                    }
                }
            }
            
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                while !container.isAtEnd {
                    if try container.decodeNil() {
                        array.append(nil)
                    } else {
                        array.append(try container.decode(String.self))
                    }
                }
            }
            
            init(array: [String?]) { self.array = array }
        }
        
        let array = [nil, "test", nil]
        _testRoundTrip(of: UnkeyedContainerContainingNullTestType(array: array), in: .xml)
        _testRoundTrip(of: UnkeyedContainerContainingNullTestType(array: array), in: .binary)
    }
    
    @Test func test_invalidNSDataKey_82142612() throws {
        let data = try testData(forResource: "Test_82142612", withExtension: "bad")

        let decoder = PropertyListDecoder()
        #expect(throws: (any Error).self) {
            try decoder.decode([String:String].self, from: data)
        }

        // Repeat something similar with XML.
        let xmlData = "<plist><dict><data>abcd</data><string>xyz</string></dict></plist>".data(using: String._Encoding.utf8)!
        #expect(throws: (any Error).self) {
            try decoder.decode([String:String].self, from: xmlData)
        }
    }

#if FOUNDATION_FRAMEWORK
    // TODO: Depends on data's range(of:) implementation
    @Test func test_nonStringDictionaryKey() throws {
        let decoder = PropertyListDecoder()
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        var data = try encoder.encode(["abcd":"xyz"])

        // Replace the tag for the ASCII string (0101) that is length 4 ("abcd" => length: 0100) with a boolean "true" tag (0000_1001)
        let range = data.range(of: Data([0b0101_0100]))!
        data.replaceSubrange(range, with: Data([0b000_1001]))
        #expect(throws: (any Error).self) {
            try decoder.decode([String:String].self, from: data)
        }

        let xmlData = "<plist><dict><string>abcd</string><string>xyz</string></dict></plist>".data(using: String._Encoding.utf8)!
        #expect(throws: (any Error).self) {
            try decoder.decode([String:String].self, from: xmlData)
        }
    }
#endif

    @Test func test_5616259() throws {
        let plistData = try testData(forResource: "Test_5616259", withExtension: "bad")
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String].self, from: plistData)
        }
    }

    @Test func test_6164184() throws {
        let xml = "<plist><array><integer>0x721B</integer><integer>0x1111</integer><integer>-0xFFFF</integer></array></plist>"
        let array = try PropertyListDecoder().decode([Int].self, from: xml.data(using: String._Encoding.utf8)!)
        #expect([0x721B, 0x1111, -0xFFFF] == array)
    }

    @Test func test_xmlIntegerEdgeCases() throws {
        func checkValidEdgeCase<T: Decodable & Equatable>(_ xml: String, type: T.Type, expected: T, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let data = try #require(xml.data(using: String._Encoding.utf8), sourceLocation: sourceLocation)
            let value = try PropertyListDecoder().decode(type, from: data)
            #expect(value == expected, sourceLocation: sourceLocation)
        }

        try checkValidEdgeCase("<integer>127</integer>", type: Int8.self, expected: .max)
        try checkValidEdgeCase("<integer>-128</integer>", type: Int8.self, expected: .min)
        try checkValidEdgeCase("<integer>32767</integer>", type: Int16.self, expected: .max)
        try checkValidEdgeCase("<integer>-32768</integer>", type: Int16.self, expected: .min)
        try checkValidEdgeCase("<integer>2147483647</integer>", type: Int32.self, expected: .max)
        try checkValidEdgeCase("<integer>-2147483648</integer>", type: Int32.self, expected: .min)
        try checkValidEdgeCase("<integer>9223372036854775807</integer>", type: Int64.self, expected: .max)
        try checkValidEdgeCase("<integer>-9223372036854775808</integer>", type: Int64.self, expected: .min)

        try checkValidEdgeCase("<integer>0x7f</integer>", type: Int8.self, expected: .max)
        try checkValidEdgeCase("<integer>-0x80</integer>", type: Int8.self, expected: .min)
        try checkValidEdgeCase("<integer>0x7fff</integer>", type: Int16.self, expected: .max)
        try checkValidEdgeCase("<integer>-0x8000</integer>", type: Int16.self, expected: .min)
        try checkValidEdgeCase("<integer>0x7fffffff</integer>", type: Int32.self, expected: .max)
        try checkValidEdgeCase("<integer>-0x80000000</integer>", type: Int32.self, expected: .min)
        try checkValidEdgeCase("<integer>0x7fffffffffffffff</integer>", type: Int64.self, expected: .max)
        try checkValidEdgeCase("<integer>-0x8000000000000000</integer>", type: Int64.self, expected: .min)

        try checkValidEdgeCase("<integer>255</integer>", type: UInt8.self, expected: .max)
        try checkValidEdgeCase("<integer>65535</integer>", type: UInt16.self, expected: .max)
        try checkValidEdgeCase("<integer>4294967295</integer>", type: UInt32.self, expected: .max)
        try checkValidEdgeCase("<integer>18446744073709551615</integer>", type: UInt64.self, expected: .max)

        func checkInvalidEdgeCase<T: Decodable>(_ xml: String, type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let data = try #require(xml.data(using: String._Encoding.utf8))
            #expect(throws: (any Error).self) {
                try PropertyListDecoder().decode(type, from: data)
            }
        }

        try checkInvalidEdgeCase("<integer>128</integer>", type: Int8.self)
        try checkInvalidEdgeCase("<integer>-129</integer>", type: Int8.self)
        try checkInvalidEdgeCase("<integer>32768</integer>", type: Int16.self)
        try checkInvalidEdgeCase("<integer>-32769</integer>", type: Int16.self)
        try checkInvalidEdgeCase("<integer>2147483648</integer>", type: Int32.self)
        try checkInvalidEdgeCase("<integer>-2147483649</integer>", type: Int32.self)
        try checkInvalidEdgeCase("<integer>9223372036854775808</integer>", type: Int64.self)
        try checkInvalidEdgeCase("<integer>-9223372036854775809</integer>", type: Int64.self)

        try checkInvalidEdgeCase("<integer>0x80</integer>", type: Int8.self)
        try checkInvalidEdgeCase("<integer>-0x81</integer>", type: Int8.self)
        try checkInvalidEdgeCase("<integer>0x8000</integer>", type: Int16.self)
        try checkInvalidEdgeCase("<integer>-0x8001</integer>", type: Int16.self)
        try checkInvalidEdgeCase("<integer>0x80000000</integer>", type: Int32.self)
        try checkInvalidEdgeCase("<integer>-0x80000001</integer>", type: Int32.self)
        try checkInvalidEdgeCase("<integer>0x8000000000000000</integer>", type: Int64.self)
        try checkInvalidEdgeCase("<integer>-0x8000000000000001</integer>", type: Int64.self)

        try checkInvalidEdgeCase("<integer>256</integer>", type: UInt8.self)
        try checkInvalidEdgeCase("<integer>65536</integer>", type: UInt16.self)
        try checkInvalidEdgeCase("<integer>4294967296</integer>", type: UInt32.self)
        try checkInvalidEdgeCase("<integer>18446744073709551616</integer>", type: UInt64.self)
    }
    
    @Test func test_xmlIntegerWhitespace() throws {
        let xml = "<array><integer> +\t42</integer><integer>\t-   99</integer><integer> -\t0xFACE</integer></array>"
        let data = try #require(xml.data(using: String._Encoding.utf8))
        let value = try PropertyListDecoder().decode([Int].self, from: data)
        #expect(value == [42, -99, -0xFACE])
    }

    @Test func test_binaryNumberEdgeCases() throws {
        _testRoundTrip(of: [Int8.max], in: .binary)
        _testRoundTrip(of: [Int8.min], in: .binary)
        _testRoundTrip(of: [Int16.max], in: .binary)
        _testRoundTrip(of: [Int16.min], in: .binary)
        _testRoundTrip(of: [Int32.max], in: .binary)
        _testRoundTrip(of: [Int32.min], in: .binary)
        _testRoundTrip(of: [Int64.max], in: .binary)
        _testRoundTrip(of: [Int64.max], in: .binary)

        _testRoundTrip(of: [UInt8.max], in: .binary)
        _testRoundTrip(of: [UInt16.max], in: .binary)
        _testRoundTrip(of: [UInt32.max], in: .binary)
        _testRoundTrip(of: [UInt64.max], in: .binary)

        _testRoundTrip(of: [Float.greatestFiniteMagnitude], in: .binary)
        _testRoundTrip(of: [-Float.greatestFiniteMagnitude], in: .binary)
//        _testRoundTrip(of: [Float.nan], in: .binary) // NaN can't be equated.
        _testRoundTrip(of: [Float.infinity], in: .binary)
        _testRoundTrip(of: [-Float.infinity], in: .binary)

        _testRoundTrip(of: [Double.greatestFiniteMagnitude], in: .binary)
        _testRoundTrip(of: [-Double.greatestFiniteMagnitude], in: .binary)
//        _testRoundTrip(of: [Double.nan], in: .binary) // NaN can't be equated.
        _testRoundTrip(of: [Double.infinity], in: .binary)
        _testRoundTrip(of: [-Double.infinity], in: .binary)
    }
    
    @Test func test_binaryReals() throws {
        func encode<T: BinaryFloatingPoint & Encodable>(_: T.Type) throws -> (data: Data, expected: [T]) {
            let expected: [T] = [
                1.5,
                2,
                -3.14,
                1.000000000000000000000001,
                31415.9e-4,
                -.infinity,
                .infinity
            ]
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(expected)
            return (data, expected)
        }
        
        func test<T: BinaryFloatingPoint & Codable>(_ type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let (data, expected) = try encode(type)
            let result = try PropertyListDecoder().decode([T].self, from: data)
            #expect(result == expected, "Type: \(type)", sourceLocation: sourceLocation)
        }
        
        try test(Float.self)
        try test(Double.self)
    }

    @Test func test_XMLReals() throws {
        let xml = "<plist><array><real>1.5</real><real>2</real><real>  -3.14</real><real>1.000000000000000000000001</real><real>31415.9e-4</real><real>-iNf</real><real>infInItY</real></array></plist>"
        let data = try #require(xml.data(using: String._Encoding.utf8))
        let array = try PropertyListDecoder().decode([Float].self, from: data)
        let expected: [Float] = [
            1.5,
            2,
            -3.14,
            1.000000000000000000000001,
            31415.9e-4,
            -.infinity,
            .infinity
        ]
        #expect(array == expected)

        // nan doesn't work with equality.
        let xmlNAN = "<array><real>nAn</real><real>NAN</real><real>nan</real></array>"
        let dataNAN = try #require(xmlNAN.data(using: String._Encoding.utf8))
        let arrayNAN = try PropertyListDecoder().decode([Float].self, from: dataNAN)
        for val in arrayNAN {
            #expect(val.isNaN)
        }
    }

    @Test func test_bad_XMLReals() throws {
        let badRealXMLs = [
            "<real>0x10</real>",
            "<real>notanumber</real>",
            "<real>infinite</real>",
            "<real>1.2.3</real>",
            "<real>1.e</real>",
            "<real>1.5  </real>", // Trailing whitespace is rejected, unlike leading whitespace.
            "<real></real>",
        ]
        for xml in badRealXMLs {
            let data = try #require(xml.data(using: String._Encoding.utf8))
            #expect(throws: (any Error).self, "Input: \(xml)") {
                try PropertyListDecoder().decode(Float.self, from: data)
            }
        }
    }

#if FOUNDATION_FRAMEWORK
    // Requires old style plist support
    // Requires "NEXTStep" decoding in String(bytes:encoding:) for decoding the octal characters

    @Test func test_oldStylePlist_invalid() {
        let data = "goodbye cruel world".data(using: String._Encoding.utf16)!
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode(String.self, from: data)
        }
    }

    // <rdar://problem/34321354> Microsoft: Microsoft vso 1857102 : High Sierra regression that caused data loss : CFBundleCopyLocalizedString returns incorrect string
    // Escaped octal chars can be shorter than 3 chars long; i.e. \5 ≡ \05 ≡ \005.
    @Test func test_oldStylePlist_getSlashedChars_octal() throws {
        // ('\0', '\00', '\000', '\1', '\01', '\001', ..., '\777')
        let data = try testData(forResource: "test_oldStylePlist_getSlashedChars_octal", withExtension: "plist")
        let actualStrings = try PropertyListDecoder().decode([String].self, from: data)

        let expectedData = try testData(forResource: "test_oldStylePlist_getSlashedChars_octal_expected", withExtension: "plist")
        let expectedStrings = try PropertyListDecoder().decode([String].self, from: expectedData)

        #expect(actualStrings == expectedStrings)
    }

    // Old-style plists support Unicode literals via \U syntax. They can be 1–4 characters wide.
    @Test func test_oldStylePlist_getSlashedChars_unicode() throws {
        // ('\U0', '\U00', '\U000', '\U0000', '\U1', ..., '\UFFFF')
        let data = try testData(forResource: "test_oldStylePlist_getSlashedChars_unicode", withExtension: "plist")
        let actualStrings = try PropertyListDecoder().decode([String].self, from: data)

        let expectedData = try testData(forResource: "test_oldStylePlist_getSlashedChars_unicode_expected", withExtension: "plist")
        let expectedStrings = try PropertyListDecoder().decode([String].self, from: expectedData)

        #expect(actualStrings == expectedStrings)
    }

    @Test func test_oldStylePlist_getSlashedChars_literals() throws {
        let literals = ["\u{7}", "\u{8}", "\u{12}", "\n", "\r", "\t", "\u{11}", "\"", "\\n"]
        let data = "('\\a', '\\b', '\\f', '\\n', '\\r', '\\t', '\\v', '\\\"', '\\\\n')".data(using: String._Encoding.utf8)!

        let strings = try PropertyListDecoder().decode([String].self, from: data)
        #expect(strings == literals)
    }
    
    @Test func test_oldStylePlist_dictionary() throws {
        let data = """
{ "test key" = value;
  testData = <feed face>;
  "nested array" = (a, b, c); }
""".data(using: String._Encoding.utf16)!

        struct Values: Decodable {
            let testKey: String
            let testData: Data
            let nestedArray: [String]

            enum CodingKeys: String, CodingKey {
                case testKey = "test key"
                case testData
                case nestedArray = "nested array"
            }
        }
        let decoded = try PropertyListDecoder().decode(Values.self, from: data)
        #expect(decoded.testKey == "value")
        #expect(decoded.testData == Data([0xfe, 0xed, 0xfa, 0xce]))
        #expect(decoded.nestedArray == ["a", "b", "c"])
    }

    @Test func test_oldStylePlist_stringsFileFormat() throws {
        let data = """
string1 = "Good morning";
string2 = "Good afternoon";
string3 = "Good evening";
""".data(using: String._Encoding.utf16)!

        let decoded = try PropertyListDecoder().decode([String:String].self, from: data)
        let expected = [
            "string1": "Good morning",
            "string2": "Good afternoon",
            "string3": "Good evening"
        ]
        #expect(decoded == expected)
    }
        
    @Test func test_oldStylePlist_comments() throws {
        let data = """
// Initial comment */
string1 = /*Test*/ "Good morning";  // Test
string2 = "Good afternoon" /*Test// */;
string3 = "Good evening"; // Test
""".data(using: String._Encoding.utf16)!

        let decoded = try PropertyListDecoder().decode([String:String].self, from: data)
        let expected = [
            "string1": "Good morning",
            "string2": "Good afternoon",
            "string3": "Good evening"
        ]
        #expect(decoded == expected)
    }
#endif
    
#if FOUNDATION_FRAMEWORK
    // Requires __PlistDictionaryDecoder
    
    @Test func test_oldStylePlist_data() throws {
        let data = """
data1 = <7465
73 74
696E67                31

323334>;
""".data(using: String._Encoding.utf16)!
        
        let decoded = try PropertyListDecoder().decode([String:Data].self, from: data)
        let expected = ["data1" : "testing1234".data(using: String._Encoding.utf8)!]
        #expect(decoded == expected)
    }
#endif

#if FOUNDATION_FRAMEWORK
    // Requires PropertyListSerialization
    
    @Test func test_BPlistCollectionReferences() throws {
        // Use NSArray/NSDictionary and PropertyListSerialization so that we get a bplist with internal references.
        let c: NSArray = [ "a", "a", "a" ]
        let b: NSArray = [ c, c, c ]
        let a: NSArray = [ b, b, b ]
        let d: NSDictionary = ["a" : a, "b" : b, "c" : c]
        let data = try PropertyListSerialization.data(fromPropertyList: d, format: .binary, options: 0)

        struct DecodedReferences: Decodable {
            let a: [[[String]]]
            let b: [[String]]
            let c: [String]
        }
        
        let decoded = try PropertyListDecoder().decode(DecodedReferences.self, from: data)
        #expect(decoded.a == a as! [[[String]]])
        #expect(decoded.b == b as! [[String]])
        #expect(decoded.c == c as! [String])
    }
#endif

    @Test func test_realEncodeRemoveZeroSuffix() throws {
        // Tests that we encode "whole-value reals" (such as `2.0`, `-5.0`, etc)
        // **without** the `.0` for backwards compactability
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let template = "\(_XMLPlistEncodingFormat.Writer.header)<array>\n\t<real><%EXPECTED%></real>\n</array>\n</plist>\n"

        let wholeFloat: Float = 2.0
        var data = try encoder.encode([wholeFloat])
        var str = try #require(String(data: data, encoding: String.Encoding.utf8))
        var expected = template.replacingOccurrences(
            of: "<%EXPECTED%>", with: "2")
        #expect(str == expected)

        let wholeDouble: Double = -5.0
        data = try encoder.encode([wholeDouble])
        str = try #require(String(data: data, encoding: String.Encoding.utf8))
        expected = template.replacingOccurrences(
            of: "<%EXPECTED%>", with: "-5")
        #expect(str == expected)

        // Make sure other reals are not affacted
        let notWholeDouble = 0.5
        data = try encoder.encode([notWholeDouble])
        str = try #require(String(data: data, encoding: String.Encoding.utf8))
        expected = template.replacingOccurrences(
            of: "<%EXPECTED%>", with: "0.5")
        #expect(str == expected)
    }

    @Test func test_multibyteCharacters_escaped_noencoding() throws {
        let plistData = "<plist><string>These are copyright signs &#169; &#xA9; blah blah blah.</string></plist>".data(using: String._Encoding.utf8)!
        let result = try PropertyListDecoder().decode(String.self, from: plistData)
        #expect("These are copyright signs © © blah blah blah." == result)
    }

    @Test func test_escapedCharacters() throws {
        let plistData = "<plist><string>&amp;&apos;&lt;&gt;&quot;</string></plist>".data(using: String._Encoding.utf8)!
        let result = try PropertyListDecoder().decode(String.self, from: plistData)
        #expect("&'<>\"" == result)
    }

    @Test func test_dataWithBOM_utf8() throws {
        let bom = Data([0xef, 0xbb, 0xbf])
        let plist = bom + "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<string>hello</string>\n</plist>".data(using: String._Encoding.utf8)!

        let result = try PropertyListDecoder().decode(String.self, from: plist)
        #expect(result == "hello")
    }

#if FOUNDATION_FRAMEWORK
    // TODO: Depends on UTF32 encoding on non-Darwin platforms
    
    @Test func test_dataWithBOM_utf32be() throws {
        let bom = Data([0x00, 0x00, 0xfe, 0xff])
        let plist = bom + "<?xml version=\"1.0\" encoding=\"UTF-32BE\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<string>hello</string>\n</plist>".data(using: String._Encoding.utf32BigEndian)!

        let result = try PropertyListDecoder().decode(String.self, from: plist)
        #expect(result == "hello")
    }

    @Test func test_dataWithBOM_utf32le() throws {
        let bom = Data([0xff, 0xfe])
        let plist = bom + "<?xml version=\"1.0\" encoding=\"UTF-16LE\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<string>hello</string>\n</plist>".data(using: String._Encoding.utf16LittleEndian)!

        let result = try PropertyListDecoder().decode(String.self, from: plist)
        #expect(result == "hello")
    }
#endif

    @Test func test_plistWithBadUTF8() throws {
        let data = try testData(forResource: "bad_plist", withExtension: "bad")

        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String].self, from: data)
        }
    }

    @Test func test_plistWithEscapedCharacters() throws {
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>com.apple.security.temporary-exception.sbpl</key><string>(allow mach-lookup (global-name-regex #&quot;^[0-9]+$&quot;))</string></dict></plist>".data(using: String._Encoding.utf8)!
        let result = try PropertyListDecoder().decode([String:String].self, from: plist)
        #expect(result == ["com.apple.security.temporary-exception.sbpl" : "(allow mach-lookup (global-name-regex #\"^[0-9]+$\"))"])
    }

#if FOUNDATION_FRAMEWORK
    // OpenStep format is not supported in Essentials
    @Test func test_returnRightFormatFromParse() throws {
        let plist = "{ CFBundleDevelopmentRegion = en; }".data(using: String._Encoding.utf8)!

        var format : PropertyListDecoder.PropertyListFormat = .binary
        let _ = try PropertyListDecoder().decode([String:String].self, from: plist, format: &format)
        #expect(format == .openStep)
    }
#endif

    @Test func test_decodingEmoji() throws {
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>emoji</key><string>&#128664;</string></dict></plist>".data(using: String._Encoding.utf8)!

        let result = try PropertyListDecoder().decode([String:String].self, from: plist)
        let expected = "\u{0001F698}"
        #expect(expected == result["emoji"])
    }

    @Test func test_decodingTooManyCharactersError() throws {
        // Try a plist with too many characters to be a unicode escape sequence
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>emoji</key><string>&#12341234128664;</string></dict></plist>".data(using: String._Encoding.utf8)!

        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String:String].self, from: plist)
        }

        // Try a plist with an invalid unicode escape sequence
        let plist2 = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>emoji</key><string>&#12866411;</string></dict></plist>".data(using: String._Encoding.utf8)!

        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String:String].self, from: plist2)
        }
    }
    
    @Test func test_roundTripEmoji() throws {
        let strings = ["🚘", "👩🏻‍❤️‍👨🏿", "🏋🏽‍♂️🕺🏼🥌"]
        
        _testRoundTrip(of: strings, in: .xml)
        _testRoundTrip(of: strings, in: .binary)
    }
    
    @Test func test_roundTripEscapedStrings() {
        let strings = ["&", "<", ">"]
        _testRoundTrip(of: strings, in: .xml)
    }

    @Test func test_unterminatedComment() {
        let plist = "<array><!-- comment -->".data(using: String._Encoding.utf8)!
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String].self, from: plist)
        }
    }

    @Test func test_incompleteOpenTag() {
        let plist = "<array".data(using: String._Encoding.utf8)!
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String].self, from: plist)
        }
    }

    @Test func test_CDATA_section() throws {
        let plist = "<string><![CDATA[Test &amp; &33; <![CDATA[]]]> outside</string>".data(using: String._Encoding.utf8)!
        let result = try PropertyListDecoder().decode(String.self, from: plist)
        let expected = "Test &amp; &33; <![CDATA[] outside"
        #expect(result == expected)
    }
    
    @Test func test_supers() throws {
        struct UsesSupers : Codable, Equatable {
            enum CodingKeys: String, CodingKey {
                case a, b, unkeyed
            }
            
            func encode(to encoder: Encoder) throws {
                var keyed = encoder.container(keyedBy: CodingKeys.self)
                try keyed.encodeNil(forKey: .a)
                
                let superB = keyed.superEncoder(forKey: .b)
                var bSVC = superB.singleValueContainer()
                try bSVC.encode("b")
                
                let s = keyed.superEncoder()
                var sSVC = s.singleValueContainer()
                try sSVC.encode("super")
                
                let superUnkeyed = keyed.superEncoder(forKey: .unkeyed)
                var unkeyed = superUnkeyed.unkeyedContainer()
                
                try unkeyed.encodeNil()
                
                let superInUnkeyed = unkeyed.superEncoder()
                
                try unkeyed.encode("final")
                
                var sIUSVC = superInUnkeyed.singleValueContainer()
                try sIUSVC.encode("middle")
            }
            
            init(from decoder: Decoder) throws {
                let keyed = try decoder.container(keyedBy: CodingKeys.self)
                #expect(try keyed.decodeNil(forKey: .a))
                
                let superB = try keyed.superDecoder(forKey: .b)
                let bSVC = try superB.singleValueContainer()
                #expect(try "b" == bSVC.decode(String.self))
                
                let s = try keyed.superDecoder()
                let sSVC = try s.singleValueContainer()
                #expect(try "super" == sSVC.decode(String.self))
                
                let superUnkeyed = try keyed.superDecoder(forKey: .unkeyed)
                var unkeyed = try superUnkeyed.unkeyedContainer()
                
                let gotNil = try unkeyed.decodeNil()
                #expect(gotNil)
                
                let superInUnkeyed = try unkeyed.superDecoder()
                let sIUSVC = try superInUnkeyed.singleValueContainer()
                #expect(try "middle" == sIUSVC.decode(String.self))
                
                #expect(try "final" == unkeyed.decode(String.self))
            }
            
            init() { }
        }
        
        #expect(_testRoundTrip(of: UsesSupers(), in: .xml) != nil)
        #expect(_testRoundTrip(of: UsesSupers(), in: .binary) != nil)
    }
    
    @Test func test_badReferenceIndex() {
        // The following is the bplist representation of `[42, 314, 0xFF]` that has been corrupted.
        let bplist = [
            0x62, 0x70, 0x6c, 0x69, 0x73, 0x74, 0x30, 0x30, // bplist00
            0xa3, 0x01, 0x02, /*0x03*/0xBD, // 3 elements array: indexes([42, 314, 0xFF]) -- BUT third index replaced with an invalid one (0xBD) which should throw an error intead of crashing.
            0x10, 0x2a, // integer 42
            0x11, 0x01, 0x3a, // integer 314
            0x10, 0xff, // integer 0xFF
            0x08, 0x0c, 0x0e, 0x11, // object offset table: offsets([array, 42, 314, 0xFF])
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x13 // trailer
        ] as [UInt8]
        let data = Data(bplist)
        
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([Int].self, from: data)
        }
    }
    
    @Test func test_badTopObjectIndex() {
        // The following is the bplist representation of `[42, 314, 0xFF]` that has been corrupted.
        let bplist = [
            0x62, 0x70, 0x6c, 0x69, 0x73, 0x74, 0x30, 0x30, // bplist00
            0xa3, 0x01, 0x02, 0x03, // 3 elements array: indexes([42, 314, 0xFF])
            0x10, 0x2a, // integer 42
            0x11, 0x01, 0x3a, // integer 314
            0x10, 0xff, // integer 0xFF
            0x08, 0x0c, 0x0e, 0x11, // object offset table: offsets([array, 42, 314, 0xFF])
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04,
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // Top object index -- CORRUPTED
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x13 // trailer
        ] as [UInt8]
        let data = Data(bplist)
        
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([Int].self, from: data)
        }
    }
    
    @Test func test_outOfBoundsObjectOffset() {
        // The following is the bplist representation of `[42, 314, 0xFF]` that has been corrupted.
        let bplist = [
            0x62, 0x70, 0x6c, 0x69, 0x73, 0x74, 0x30, 0x30, // bplist00
            0xa3, 0x01, 0x02, 0x03, // 3 elements array: indexes([42, 314, 0xFF])
            0x10, 0x2a, // integer 42
            0x11, 0x01, 0x3a, // integer 314
            0x10, 0xff, // integer 0xFF
            0x08, 0x0c, 0x0e, /*0x11*/ 0xEE, // object offset table: offsets([array, 42, 314, 0xFF]) -- BUT one offset is out of range.
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x13 // trailer
        ] as [UInt8]
        let data = Data(bplist)
        
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([Int].self, from: data)
        }
    }
    
    @Test func test_outOfBoundsOffsetTableStart() {
        // The following is the bplist representation of `[42, 314, 0xFF]` that has been corrupted.
        let bplist = [
            0x62, 0x70, 0x6c, 0x69, 0x73, 0x74, 0x30, 0x30, // bplist00
            0xa3, 0x01, 0x02, 0x03, // 3 elements array: indexes([42, 314, 0xFF])
            0x10, 0x2a, // integer 42
            0x11, 0x01, 0x3a, // integer 314
            0x10, 0xff, // integer 0xFF
            0x08, 0x0c, 0x0e, 0x11, // object offset table: offsets([array, 42, 314, 0xFF])
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF // trailer -- CORRUPTED with out of bounds offset table start offset
        ] as [UInt8]
        let data = Data(bplist)
        
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([Int].self, from: data)
        }
    }
    
    @Test func test_tooLargeObjectCount() {
        // The following is the bplist representation of `[42, 314, 0xFF]` that has been corrupted.
        let bplist = [
            0x62, 0x70, 0x6c, 0x69, 0x73, 0x74, 0x30, 0x30, // bplist00
            0xa3, 0x01, 0x02, 0x03, // 3 elements array: indexes([42, 314, 0xFF])
            0x10, 0x2a, // integer 42
            0x11, 0x01, 0x3a, // integer 314
            0x10, 0xff, // integer 0xFF
            0x08, 0x0c, 0x0e, 0x11, // object offset table: offsets([array, 42, 314, 0xFF])
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01,
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // object count -- CORRUPTED
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x13 // trailer
        ] as [UInt8]
        let data = Data(bplist)
        
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([Int].self, from: data)
        }
    }
    
    @Test func test_tooLargeOffset() {
        // The following is the bplist representation of `[42, 314, 0xFF]` that has been corrupted.
        let bplist = [
            0x62, 0x70, 0x6c, 0x69, 0x73, 0x74, 0x30, 0x30, // bplist00
            0xa3, 0x01, 0x02, 0x03, // 3 elements array: indexes([42, 314, 0xFF])
            0x10, 0x2a, // integer 42
            0x11, 0x01, 0x3a, // integer 314
            0x10, 0xff, // integer 0xFF
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, // offset(array)
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, // offset(42)
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // offset(314) -- CORRUPTED
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x11, // offset(0xFF)
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x01, // MODIFIED to make object offsets be 8 bytes instead of 1
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x13 // trailer -- MODIFIED to accommodate larger object index size
        ] as [UInt8]
        let data = Data(bplist)
        
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([Int].self, from: data)
        }
    }
    
    @Test func test_tooLargeIndex() {
        // The following is the bplist representation of `[42, 314, 0xFF]` that has been corrupted.
        let bplist = [
            0x62, 0x70, 0x6c, 0x69, 0x73, 0x74, 0x30, 0x30, // bplist00
            0xa3, // 3 element array
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, // index(42)
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // index(314) -- CORRUPTED to a very large value
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, // index(0xFF)
            0x10, 0x2a, // integer 42
            0x11, 0x01, 0x3a, // integer 314
            0x10, 0xff, // integer 0xFF
            0x08, 0x21, 0x23, 0x26, // object offset table: offsets([array, 42, 314, 0xFF])
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x08, // MODIFIED to make object offsets be 8 bytes instead of 1
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x28 // trailer -- MODIFIED to accommodate larger object index size
        ] as [UInt8]
        let data = Data(bplist)
        
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([Int].self, from: data)
        }
    }
    
    @Test func test_uid() throws {
        // There's no public interface where an NSKeyedArchiver UID value will correctly decode through PropertyListDecoder. This test ensures that it isn't mistaken for some other type.
        
        let xml = "<plist><dict><key>CF$UID</key><integer>1</integer></dict></plist>"
        let xmlData = xml.data(using: String._Encoding.utf8)!
        
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([Int32].self, from: xmlData)
        }

        let bplist = [
            0x62, 0x70, 0x6c, 0x69, 0x73, 0x74, 0x30, 0x30, // bplist00
            0xa1, 0x01, // 1 element array: indexes([cfuid])
            0x80, 0x01, // cfuid: 1
            0x08, 0x0a, // object offset table: offsets([array, cfuid])
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c // trailer
        ] as [UInt8]
        let bplistData = Data(bplist)
        
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([Int32].self, from: bplistData)
        }
    }
    
    @Test func test_fauxStability_struct() throws {
        struct FauxStable: Encodable {
            let a = "a"
            let z = "z"
            let n = "n"
        }
        
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        
        let encoding = try encoder.encode(FauxStable())
        for _ in 0..<1000 {
            let reencoding = try encoder.encode(FauxStable())
            #expect(encoding == reencoding)
        }
    }
    
    @Test func test_fauxStability_dict() throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        
        let encoding = try encoder.encode(["a":"a", "z":"z", "n":"n"])
        for _ in 0..<1000 {
            let reencoding = try encoder.encode(["a":"a", "z":"z", "n":"n"])
            #expect(encoding == reencoding)
        }
    }
    
    @Test(arguments: [
        MultipleDecodeOptionsTestType("1", .int),
        MultipleDecodeOptionsTestType("1.2", .float),
        MultipleDecodeOptionsTestType("foo", .string)
    ])
    func testMultipleDecodeOptions(input: MultipleDecodeOptionsTestType) {
        _testRoundTrip(of: input, in: .binary)
        _testRoundTrip(of: input, in: .xml)
    }
}
