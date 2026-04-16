// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//

import Testing

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#elseif canImport(FoundationEssentials)
@testable import FoundationEssentials
#endif

// MARK: - Test Suite

@Suite("PropertyListEncoder")
private struct PropertyListEncoderTests {
    // MARK: - Encoding Top-Level Empty Types
    @Test func encodingTopLevelEmptyStruct() {
        let empty = EmptyStruct()
        _testRoundTrip(of: empty, in: .binary, expectedPlist: _plistEmptyDictionaryBinary)
        _testRoundTrip(of: empty, in: .xml, expectedPlist: _plistEmptyDictionaryXML)
    }

    @Test func encodingTopLevelEmptyClass() {
        let empty = EmptyClass()
        _testRoundTrip(of: empty, in: .binary, expectedPlist: _plistEmptyDictionaryBinary)
        _testRoundTrip(of: empty, in: .xml, expectedPlist: _plistEmptyDictionaryXML)
    }

    // MARK: - Encoding Top-Level Single-Value Types
    @Test func encodingTopLevelSingleValueEnum() {
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

    @Test func encodingTopLevelSingleValueStruct() {
        let t = Timestamp(3141592653)
        _testEncodeFailure(of: t, in: .binary)
        _testEncodeFailure(of: t, in: .xml)
        _testRoundTrip(of: TopLevelWrapper(t), in: .binary)
        _testRoundTrip(of: TopLevelWrapper(t), in: .xml)
    }

    @Test func encodingTopLevelSingleValueClass() {
        let c = Counter()
        _testEncodeFailure(of: c, in: .binary)
        _testEncodeFailure(of: c, in: .xml)
        _testRoundTrip(of: TopLevelWrapper(c), in: .binary)
        _testRoundTrip(of: TopLevelWrapper(c), in: .xml)
    }

    // MARK: - Encoding Top-Level Structured Types
    @Test func encodingTopLevelStructuredStruct() {
        // Address is a struct type with multiple fields.
        let address = Address.testValue
        _testRoundTrip(of: address, in: .binary)
        _testRoundTrip(of: address, in: .xml)
    }

    @Test func encodingTopLevelStructuredClass() {
        // Person is a class with multiple fields.
        let person = Person.testValue
        _testRoundTrip(of: person, in: .binary)
        _testRoundTrip(of: person, in: .xml)
    }

    @Test func encodingTopLevelStructuredSingleStruct() {
        // Numbers is a struct which encodes as an array through a single value container.
        let numbers = Numbers.testValue
        _testRoundTrip(of: numbers, in: .binary)
        _testRoundTrip(of: numbers, in: .xml)
    }

    @Test func encodingTopLevelStructuredSingleClass() {
        // Mapping is a class which encodes as a dictionary through a single value container.
        let mapping = Mapping.testValue
        _testRoundTrip(of: mapping, in: .binary)
        _testRoundTrip(of: mapping, in: .xml)
    }

    @Test func encodingTopLevelDeepStructuredType() {
        // Company is a type with fields which are Codable themselves.
        let company = Company.testValue
        _testRoundTrip(of: company, in: .binary)
        _testRoundTrip(of: company, in: .xml)
    }

    @Test func encodingClassWhichSharesEncoderWithSuper() {
        // Employee is a type which shares its encoder & decoder with its superclass, Person.
        let employee = Employee.testValue
        _testRoundTrip(of: employee, in: .binary)
        _testRoundTrip(of: employee, in: .xml)
    }

    @Test func encodingTopLevelNullableType() {
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

    @Test func encodingTopLevelWithConfiguration() throws {
        // CodableTypeWithConfiguration is a struct that conforms to CodableWithConfiguration
        let value = CodableTypeWithConfiguration.testValue
        let encoder = PropertyListEncoder()
        let decoder = PropertyListDecoder()

        var decoded = try decoder.decode(CodableTypeWithConfiguration.self, from: try encoder.encode(value, configuration: .init(1)), configuration: .init(1))
        #expect(decoded == value)
        decoded = try decoder.decode(CodableTypeWithConfiguration.self, from: try encoder.encode(value, configuration: CodableTypeWithConfiguration.ConfigProviding.self), configuration: CodableTypeWithConfiguration.ConfigProviding.self)
        #expect(decoded == value)
    }

    @Test func encodingMultipleNestedContainersWithTheSameTopLevelKey() {
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
        let expectedXML = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n\t<key>top</key>\n\t<dict>\n\t\t<key>first</key>\n\t\t<string>Johnny Appleseed</string>\n\t\t<key>second</key>\n\t\t<string>appleseed@apple.com</string>\n\t</dict>\n</dict>\n</plist>\n".data(using: .utf8)!
        _testRoundTrip(of: model, in: .xml, expectedPlist: expectedXML)
    }

#if FOUNDATION_EXIT_TESTS
    @Test func encodingConflictedTypeNestedContainersWithTheSameTopLevelKey() async {
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

        await #expect(processExitsWith: .failure) {
            let model = Model.testValue
            // This following test would fail as it attempts to re-encode into already encoded container is invalid. This will always fail
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            let _ = try encoder.encode(model)
        }
    }
#endif

    // MARK: - Encoder Features
    @Test func nestedContainerCodingPaths() {
        let encoder = PropertyListEncoder()
        #expect(throws: Never.self) {
            try encoder.encode(NestedContainersTestType())
        }
    }

    @Test func superEncoderCodingPaths() {
        let encoder = PropertyListEncoder()
        #expect(throws: Never.self) {
            try encoder.encode(NestedContainersTestType(testSuperEncoder: true))
        }
    }

#if FOUNDATION_FRAMEWORK
    // requires PropertyListSerialization, JSONSerialization
    
    @Test func encodingTopLevelData() throws {
        let data = try JSONSerialization.data(withJSONObject: [String](), options: [])
        _testRoundTrip(of: data, in: .binary, expectedPlist: try PropertyListSerialization.data(fromPropertyList: data, format: .binary, options: 0))
        _testRoundTrip(of: data, in: .xml, expectedPlist: try PropertyListSerialization.data(fromPropertyList: data, format: .xml, options: 0))
    }

    @Test func interceptData() throws {
        let data = try JSONSerialization.data(withJSONObject: [String](), options: [])
        let topLevel = TopLevelWrapper(data)
        let plist = ["value": data]
        _testRoundTrip(of: topLevel, in: .binary, expectedPlist: try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0))
        _testRoundTrip(of: topLevel, in: .xml, expectedPlist: try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0))
    }

    @Test func interceptDate() throws {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let topLevel = TopLevelWrapper(date)
        let plist = ["value": date]
        _testRoundTrip(of: topLevel, in: .binary, expectedPlist: try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0))
        _testRoundTrip(of: topLevel, in: .xml, expectedPlist: try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0))
    }
#endif // FOUNDATION_FRAMEWORK

    // MARK: - Type coercion
    @Test func typeCoercion() throws {
        func _testRoundTripTypeCoercionFailure<T,U>(of value: T, as type: U.Type, sourceLocation: SourceLocation = #_sourceLocation) throws where T : Codable, U : Codable {
            let encoder = PropertyListEncoder()

            encoder.outputFormat = .xml
            let xmlData = try encoder.encode(value)
            #expect(throws: (any Error).self, "Coercion from \(T.self) to \(U.self) was expected to fail.", sourceLocation: sourceLocation) {
                try PropertyListDecoder().decode(U.self, from: xmlData)
            }

            encoder.outputFormat = .binary
            let binaryData = try encoder.encode(value)
            #expect(throws: (any Error).self, "Coercion from \(T.self) to \(U.self) was expected to fail.", sourceLocation: sourceLocation) {
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

    @Test func integerRealCoercion() throws {
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

    @Test func decodingConcreteTypeParameter() throws {
        let encoder = PropertyListEncoder()
        let plist = try encoder.encode(Employee.testValue)

        let decoder = PropertyListDecoder()
        let decoded = try decoder.decode(Employee.self as Person.Type, from: plist)

        #expect(type(of: decoded) == Employee.self, "Expected decoded value to be of type Employee; got \(type(of: decoded)) instead.")
    }

    // MARK: - Encoder State
    // SR-6078
    @Test func encoderStateThrowOnEncode() {
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
    @Test func decoderStateThrowOnDecode() {
        #expect(throws: Never.self) {
            let plist = try PropertyListEncoder().encode([1,2,3])
            let _ = try PropertyListDecoder().decode(EitherDecodable<[String], [Int]>.self, from: plist)
        }
    }

#if FOUNDATION_FRAMEWORK
    // MARK: - NSKeyedArchiver / NSKeyedUnarchiver integration
    @Test func archiving() throws {
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
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict/>\n</plist>\n".data(using: .utf8)!
    }

    private func _testEncodeFailure<T : Encodable>(of value: T, in format: PropertyListDecoder.PropertyListFormat, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(throws: (any Error).self, "Encode of top-level \(T.self) was expected to fail.", sourceLocation: sourceLocation) {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = format
            let _ = try encoder.encode(value)
        }
    }

    @discardableResult
    private func _testRoundTrip<T>(of value: T, in format: PropertyListDecoder.PropertyListFormat, expectedPlist plist: Data? = nil, sourceLocation: SourceLocation = #_sourceLocation) -> T? where T : Codable, T : Equatable {
        var payload: Data! = nil
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = format
            payload = try encoder.encode(value)
        } catch {
            Issue.record("Failed to encode \(T.self) to plist: \(error)")
        }

        if let expectedPlist = plist {
            #expect(expectedPlist == payload, "Produced plist not identical to expected plist.")
        }

        do {
            var decodedFormat: PropertyListDecoder.PropertyListFormat = format
            let decoded = try PropertyListDecoder().decode(T.self, from: payload, format: &decodedFormat)
            #expect(format == decodedFormat, "Encountered plist format differed from requested format.")
            #expect(decoded == value, "\(T.self) did not round-trip to an equal value.")
            return decoded
        } catch {
            Issue.record("Failed to decode \(T.self) from plist: \(error)")
            return nil
        }
    }

    private func _forEachEncodingFormat(_ body: (PropertyListDecoder.PropertyListFormat) throws -> Void) rethrows {
        try body(.xml)
        try body(.binary)
    }

    // MARK: - Other tests
    @Test func unkeyedContainerContainingNulls() throws {
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
    
    @Test func invalidNSDataKey_82142612() {
        let data = testData(forResource: "Test_82142612", withExtension: "bad")!

        let decoder = PropertyListDecoder()
        #expect(throws: (any Error).self) {
            try decoder.decode([String:String].self, from: data)
        }

        // Repeat something similar with XML.
        let xmlData = "<plist><dict><data>abcd</data><string>xyz</string></dict></plist>".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try decoder.decode([String:String].self, from: xmlData)
        }
    }

#if FOUNDATION_FRAMEWORK
    // TODO: Depends on data's range(of:) implementation
    @Test func nonStringDictionaryKey() throws {
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

        let xmlData = "<plist><dict><string>abcd</string><string>xyz</string></dict></plist>".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try decoder.decode([String:String].self, from: xmlData)
        }
    }
#endif

    struct GenericProperties : Decodable {
        var assertionFailure: String?

        enum CodingKeys: String, CodingKey {
            case array1, item1, item2
        }

        mutating func assertEqual<T: Equatable>(_ t1: T, _ t2: T) {
            if t1 != t2 {
                assertionFailure = "Values are not equal: \(t1) != \(t2)"
            }
        }

        init(from decoder: Decoder) throws {
            let keyed = try decoder.container(keyedBy: CodingKeys.self)

            var arrayContainer = try keyed.nestedUnkeyedContainer(forKey: .array1)
            assertEqual(try arrayContainer.decode(String.self), "arr0")
            assertEqual(try arrayContainer.decode(Int.self), 42)
            assertEqual(try arrayContainer.decode(Bool.self), false)

            let comps = DateComponents(calendar: .init(identifier: .gregorian), timeZone: .init(secondsFromGMT: 0), year: 1976, month: 04, day: 01, hour: 12, minute: 00, second: 00)
            let date = comps.date!
            assertEqual(try arrayContainer.decode(Date.self), date)

            let someData = Data([0xaa, 0xbb, 0xcc, 0xdd, 0x00, 0x11, 0x22, 0x33])
            assertEqual(try arrayContainer.decode(Data.self), someData)

            assertEqual(try keyed.decode(String.self, forKey: .item1), "value1")
            assertEqual(try keyed.decode(String.self, forKey: .item2), "value2")
        }
    }

    @Test func issue5616259() throws {
        let plistData = testData(forResource: "Test_5616259", withExtension: "bad")!
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String].self, from: plistData)
        }
    }

    @Test func genericProperties_XML() throws {
        let data = testData(forResource: "Generic_XML_Properties", withExtension: "plist")!

        let props = try PropertyListDecoder().decode(GenericProperties.self, from: data)
        #expect(props.assertionFailure == nil)
    }

    @Test func genericProperties_binary() throws {
        let data = testData(forResource: "Generic_XML_Properties_Binary", withExtension: "plist")!

        let props = try PropertyListDecoder().decode(GenericProperties.self, from: data)
        #expect(props.assertionFailure == nil)
    }

    // <rdar://problem/5877417> Binary plist parser should parse any version 'bplist0?'
    @Test func issue5877417() throws {
        var data = testData(forResource: "Generic_XML_Properties_Binary", withExtension: "plist")!

        // Modify the data so the header starts with bplist0x
        data[7] = UInt8(ascii: "x")

        let props = try PropertyListDecoder().decode(GenericProperties.self, from: data)
        #expect(props.assertionFailure == nil)
    }

    @Test func xmlErrors() {
        let data = testData(forResource: "Generic_XML_Properties", withExtension: "plist")!
        let originalXML = String(data: data, encoding: .utf8)!

        // Try an empty plist
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode(GenericProperties.self, from: Data())
        }
        // We'll modify this string in all kinds of nasty ways to introduce errors
        // ---
        /*
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>array1</key>
    <array>
        <string>arr0</string>
        <integer>42</integer>
        <false/>
        <date>1976-04-01T12:00:00Z</date>
        <data>
        qrvM3QARIjM=
        </data>
    </array>
    <key>item1</key>
    <string>value1</string>
    <key>item2</key>
    <string>value2</string>
</dict>
</plist>
        */

        var errorPlists = [String : String]()

        errorPlists["Deleted leading <"] = String(originalXML[originalXML.index(after: originalXML.startIndex)...])
        errorPlists["Unterminated comment"] = originalXML.replacing("<dict>", with: "<-- unending comment\n<dict>")
        errorPlists["Mess with DOCTYPE"] = originalXML.replacing("DOCTYPE", with: "foobar")

        let range = originalXML.firstRange(of: "//EN")!
        errorPlists["Early EOF"] = String(originalXML[originalXML.startIndex ..< range.lowerBound])

        errorPlists["MalformedDTD"] = originalXML.replacing("<!DOCTYPE", with: "<?DOCTYPE")
        errorPlists["Mismathed close tag"] = originalXML.replacing("</array>", with: "</somethingelse>")
        errorPlists["Bad open tag"] = originalXML.replacing("<array>", with: "<invalidtag>")
        errorPlists["Extra plist object"] = originalXML.replacing("</plist>", with: "<string>hello</string>\n</plist>")
        errorPlists["Non-key inside dict"] = originalXML.replacing("<key>array1</key>", with: "<string>hello</string>\n<key>array1</key>")
        errorPlists["Missing value for key"] = originalXML.replacing("<string>value1</string>", with: "")
        errorPlists["Malformed real tag"] = originalXML.replacing("<integer>42</integer>", with: "<real>abc123</real>")
        errorPlists["Empty int tag"] = originalXML.replacing("<integer>42</integer>", with: "<integer></integer>")
        errorPlists["Strange int tag"] = originalXML.replacing("<integer>42</integer>", with: "<integer>42q</integer>")
        errorPlists["Hex digit in non-hex int"] = originalXML.replacing("<integer>42</integer>", with: "<integer>42A</integer>")
        errorPlists["Enormous int"] = originalXML.replacing("<integer>42</integer>", with: "<integer>99999999999999999999999999999999999999999</integer>")
        errorPlists["Empty plist"] = "<plist></plist>"
        errorPlists["Empty date"] = originalXML.replacing("<date>1976-04-01T12:00:00Z</date>", with: "<date></date>")
        errorPlists["Empty real"] = originalXML.replacing("<integer>42</integer>", with: "<real></real>")
        errorPlists["Fake inline DTD"] = originalXML.replacing("PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"", with: "[<!ELEMENT foo (#PCDATA)>]")
        for (name, badPlist) in errorPlists {
            let data = badPlist.data(using: .utf8)!
            #expect(throws: (any Error).self, "Case \(name) did not fail as expected") {
                try PropertyListDecoder().decode(GenericProperties.self, from: data)
            }
        }

    }

    @Test func issue6164184() throws {
        let xml = "<plist><array><integer>0x721B</integer><integer>0x1111</integer><integer>-0xFFFF</integer></array></plist>"
        let array = try PropertyListDecoder().decode([Int].self, from: xml.data(using: .utf8)!)
        #expect([0x721B, 0x1111, -0xFFFF] == array)
    }

    @Test func xmlIntegerEdgeCases() throws {
        func checkValidEdgeCase<T: Decodable & Equatable>(_ xml: String, type: T.Type, expected: T, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let value = try PropertyListDecoder().decode(type, from: xml.data(using: .utf8)!)
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

        func checkInvalidEdgeCase<T: Decodable>(_ xml: String, type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(throws: (any Error).self, sourceLocation: sourceLocation) {
                try PropertyListDecoder().decode(type, from: xml.data(using: .utf8)!)
            }
        }

        checkInvalidEdgeCase("<integer>128</integer>", type: Int8.self)
        checkInvalidEdgeCase("<integer>-129</integer>", type: Int8.self)
        checkInvalidEdgeCase("<integer>32768</integer>", type: Int16.self)
        checkInvalidEdgeCase("<integer>-32769</integer>", type: Int16.self)
        checkInvalidEdgeCase("<integer>2147483648</integer>", type: Int32.self)
        checkInvalidEdgeCase("<integer>-2147483649</integer>", type: Int32.self)
        checkInvalidEdgeCase("<integer>9223372036854775808</integer>", type: Int64.self)
        checkInvalidEdgeCase("<integer>-9223372036854775809</integer>", type: Int64.self)

        checkInvalidEdgeCase("<integer>0x80</integer>", type: Int8.self)
        checkInvalidEdgeCase("<integer>-0x81</integer>", type: Int8.self)
        checkInvalidEdgeCase("<integer>0x8000</integer>", type: Int16.self)
        checkInvalidEdgeCase("<integer>-0x8001</integer>", type: Int16.self)
        checkInvalidEdgeCase("<integer>0x80000000</integer>", type: Int32.self)
        checkInvalidEdgeCase("<integer>-0x80000001</integer>", type: Int32.self)
        checkInvalidEdgeCase("<integer>0x8000000000000000</integer>", type: Int64.self)
        checkInvalidEdgeCase("<integer>-0x8000000000000001</integer>", type: Int64.self)

        checkInvalidEdgeCase("<integer>256</integer>", type: UInt8.self)
        checkInvalidEdgeCase("<integer>65536</integer>", type: UInt16.self)
        checkInvalidEdgeCase("<integer>4294967296</integer>", type: UInt32.self)
        checkInvalidEdgeCase("<integer>18446744073709551616</integer>", type: UInt64.self)
    }
    
    @Test func xmlIntegerWhitespace() throws {
        let xml = "<array><integer> +\t42</integer><integer>\t-   99</integer><integer> -\t0xFACE</integer></array>"
        
        let value = try PropertyListDecoder().decode([Int].self, from: xml.data(using: .utf8)!)
        #expect(value == [42, -99, -0xFACE])
    }

    @Test func binaryNumberEdgeCases() throws {
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
    
    @Test func binaryReals() throws {
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
        
        func test<T: BinaryFloatingPoint & Codable>(_ type: T.Type) throws {
            let (data, expected) = try encode(type)
            let result = try PropertyListDecoder().decode([T].self, from: data)
            #expect(result == expected, "Type: \(type)")
        }
        
        try test(Float.self)
        try test(Double.self)
    }

    @Test func xmlReals() throws {
        let xml = "<plist><array><real>1.5</real><real>2</real><real>  -3.14</real><real>1.000000000000000000000001</real><real>31415.9e-4</real><real>-iNf</real><real>infInItY</real></array></plist>"
        let array = try PropertyListDecoder().decode([Float].self, from: xml.data(using: .utf8)!)
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
        let arrayNAN = try PropertyListDecoder().decode([Float].self, from: xmlNAN.data(using: .utf8)!)
        for val in arrayNAN {
            #expect(val.isNaN)
        }
    }

    @Test(arguments: [
        "<real>0x10</real>",
        "<real>notanumber</real>",
        "<real>infinite</real>",
        "<real>1.2.3</real>",
        "<real>1.e</real>",
        "<real>1.5  </real>", // Trailing whitespace is rejected, unlike leading whitespace.
        "<real></real>",
    ])
    func bad_XMLReals(xml: String) {
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode(Float.self, from: xml.data(using: .utf8)!)
        }
    }


    @Test func oldStylePlist_invalid() {
        let data = "goodbye cruel world".data(using: .utf16)!
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode(String.self, from: data)
        }
    }

    @Test func oldStylePlist_errors() {
        let oldStyleWithErrors = "{ hello = there; }\r\nextra stuff at end"

        let data = oldStyleWithErrors.data(using: .ascii)!

        struct Thing : Decodable {
            var hello: String
        }
        let plistDecoder = PropertyListDecoder()

        #expect {
            try plistDecoder.decode(Thing.self, from: data)
        } throws: {
            String(describing: $0).contains("Junk after plist at line 2")
        }
    }

    // <rdar://problem/34321354> Microsoft: Microsoft vso 1857102 : High Sierra regression that caused data loss : CFBundleCopyLocalizedString returns incorrect string
    // Escaped octal chars can be shorter than 3 chars long; i.e. \5 ≡ \05 ≡ \005.
    @Test func oldStylePlist_getSlashedChars_octal() throws {
        // ('\0', '\00', '\000', '\1', '\01', '\001', ..., '\777')
        let data = testData(forResource: "test_oldStylePlist_getSlashedChars_octal", withExtension: "plist")!
        let actualStrings = try PropertyListDecoder().decode([String].self, from: data)

        let expectedData = testData(forResource: "test_oldStylePlist_getSlashedChars_octal_expected", withExtension: "plist")!
        let expectedStrings = try PropertyListDecoder().decode([String].self, from: expectedData)

        #expect(actualStrings == expectedStrings)
    }

    // Old-style plists support Unicode literals via \U syntax. They can be 1–4 characters wide.
    @Test func oldStylePlist_getSlashedChars_unicode() throws {
        // ('\U0', '\U00', '\U000', '\U0000', '\U1', ..., '\UFFFF')
        let data = testData(forResource: "test_oldStylePlist_getSlashedChars_unicode", withExtension: "plist")!
        let actualStrings = try PropertyListDecoder().decode([String].self, from: data)

        let expectedData = testData(forResource: "test_oldStylePlist_getSlashedChars_unicode_expected", withExtension: "plist")!
        let expectedStrings = try PropertyListDecoder().decode([String].self, from: expectedData)

        #expect(actualStrings == expectedStrings)
    }

    @Test func oldStylePlist_getSlashedChars_literals() throws {
        let literals = ["\u{7}", "\u{8}", "\u{12}", "\n", "\r", "\t", "\u{11}", "\"", "\\n"]
        let data = "('\\a', '\\b', '\\f', '\\n', '\\r', '\\t', '\\v', '\\\"', '\\\\n')".data(using: .utf8)!

        let strings = try PropertyListDecoder().decode([String].self, from: data)
        #expect(strings == literals)
    }
    
    @Test func oldStylePlist_dictionary() {
        let data = """
{ "test key" = value;
  testData = <feed face>;
  "nested array" = (a, b, c); }
""".data(using: .utf16)!

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
        do {
            let decoded = try PropertyListDecoder().decode(Values.self, from: data)
            #expect(decoded.testKey == "value")
            #expect(decoded.testData == Data([0xfe, 0xed, 0xfa, 0xce]))
            #expect(decoded.nestedArray == ["a", "b", "c"])
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func oldStylePlist_stringsFileFormat() {
        let data = """
string1 = "Good morning";
string2 = "Good afternoon";
string3 = "Good evening";
""".data(using: .utf16)!

        do {
            let decoded = try PropertyListDecoder().decode([String:String].self, from: data)
            let expected = [
                "string1": "Good morning",
                "string2": "Good afternoon",
                "string3": "Good evening"
            ]
            #expect(decoded == expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
        
    @Test func oldStylePlist_comments() {
        let data = """
// Initial comment */
string1 = /*Test*/ "Good morning";  // Test
string2 = "Good afternoon" /*Test// */;
string3 = "Good evening"; // Test
""".data(using: .utf16)!

        do {
            let decoded = try PropertyListDecoder().decode([String:String].self, from: data)
            let expected = [
                "string1": "Good morning",
                "string2": "Good afternoon",
                "string3": "Good evening"
            ]
            #expect(decoded == expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    
#if FOUNDATION_FRAMEWORK
    // Requires __PlistDictionaryDecoder
    
    @Test func oldStylePlist_data() {
        let data = """
data1 = <7465
73 74
696E67                31

323334>;
""".data(using: .utf16)!
        
        do {
            let decoded = try PropertyListDecoder().decode([String:Data].self, from: data)
            let expected = ["data1" : "testing1234".data(using: .utf8)!]
            #expect(decoded == expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
#endif

#if FOUNDATION_FRAMEWORK
    // Requires PropertyListSerialization
    
    @Test func bplistCollectionReferences() throws {
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
        #expect(decoded.a == a as? [[[String]]])
        #expect(decoded.b == b as? [[String]])
        #expect(decoded.c == c as? [String])
    }
#endif


    @Test func reallyOldDates_5842198() throws {
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<date>0009-09-15T23:16:13Z</date>\n</plist>"
        let data = plist.data(using: .utf8)!

        #expect(throws: Never.self) {
            try PropertyListDecoder().decode(Date.self, from: data)
        }
    }

    @Test func badDates() throws {
        let timeInterval = TimeInterval(-63145612800) // This is the equivalent of an all-zero gregorian date.
        let date = Date(timeIntervalSinceReferenceDate: timeInterval)
        
        _testRoundTrip(of: [date], in: .xml)
        _testRoundTrip(of: [date], in: .binary)
    }

    @Test func badDate_encode() throws {
        let date = Date(timeIntervalSinceReferenceDate: -63145612800) // 0000-01-02 AD

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode([date])
        let str = String(data: data, encoding: String.Encoding.utf8)
        #expect(str == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<array>\n\t<date>0000-01-02T00:00:00Z</date>\n</array>\n</plist>\n")
    }

    @Test func badDate_decode() throws {
        // Test that we can correctly decode a distant date in the past
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<date>0000-01-02T00:00:00Z</date>\n</plist>"
        let data = plist.data(using: .utf8)!

        let d = try PropertyListDecoder().decode(Date.self, from: data)
        #expect(d.timeIntervalSinceReferenceDate == -63145612800)
    }

    @Test func realEncodeRemoveZeroSuffix() throws {
        // Tests that we encode "whole-value reals" (such as `2.0`, `-5.0`, etc)
        // **without** the `.0` for backwards compactability
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let template = "\(_XMLPlistEncodingFormat.Writer.header)<array>\n\t<real><%EXPECTED%></real>\n</array>\n</plist>\n"

        let wholeFloat: Float = 2.0
        var data = try encoder.encode([wholeFloat])
        var str = try #require(String(data: data, encoding: String.Encoding.utf8))
        var expected = template.replacing(
            "<%EXPECTED%>", with: "2")
        #expect(str == expected)

        let wholeDouble: Double = -5.0
        data = try encoder.encode([wholeDouble])
        str = try #require(String(data: data, encoding: String.Encoding.utf8))
        expected = template.replacing(
            "<%EXPECTED%>", with: "-5")
        #expect(str == expected)

        // Make sure other reals are not affacted
        let notWholeDouble = 0.5
        data = try encoder.encode([notWholeDouble])
        str = try #require(String(data: data, encoding: String.Encoding.utf8))
        expected = template.replacing(
            "<%EXPECTED%>", with: "0.5")
        #expect(str == expected)
    }

    @Test func farFutureDates() throws {
        let date = Date(timeIntervalSince1970: 999999999999.0)

        _testRoundTrip(of: [date], in: .xml)
    }

    @Test func encode_122065123() throws {
        let date = Date(timeIntervalSinceReferenceDate: 728512994) // 2024-02-01 20:43:14 UTC

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode([date])
        let str = String(data: data, encoding: String.Encoding.utf8)
        #expect(str == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<array>\n\t<date>2024-02-01T20:43:14Z</date>\n</array>\n</plist>\n") // Previously encoded as "2024-01-32T20:43:14Z"
    }

    @Test func decodingCompatibility_122065123() throws {
        // Test that we can correctly decode an invalid date
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<date>2024-01-32T20:43:14Z</date>\n</plist>"
        let data = plist.data(using: .utf8)!

        let d = try PropertyListDecoder().decode(Date.self, from: data)
        #expect(d.timeIntervalSinceReferenceDate == 728512994) // 2024-02-01T20:43:14Z
    }

    @Test func multibyteCharacters_escaped_noencoding() throws {
        let plistData = "<plist><string>These are copyright signs &#169; &#xA9; blah blah blah.</string></plist>".data(using: .utf8)!
        let result = try PropertyListDecoder().decode(String.self, from: plistData)
        #expect("These are copyright signs © © blah blah blah." == result)
    }

    @Test func escapedCharacters() throws {
        let plistData = "<plist><string>&amp;&apos;&lt;&gt;&quot;</string></plist>".data(using: .utf8)!
        let result = try PropertyListDecoder().decode(String.self, from: plistData)
        #expect("&'<>\"" == result)
    }

    @Test func dataWithBOM_utf8() throws {
        let bom = Data([0xef, 0xbb, 0xbf])
        let plist = bom + "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<string>hello</string>\n</plist>".data(using: .utf8)!

        let result = try PropertyListDecoder().decode(String.self, from: plist)
        #expect(result == "hello")
    }
    
    @Test func dataWithBOM_utf32be() throws {
        let bom = Data([0x00, 0x00, 0xfe, 0xff])
        let plist = bom + "<?xml version=\"1.0\" encoding=\"UTF-32BE\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<string>hello</string>\n</plist>".data(using: .utf32BigEndian)!

        let result = try PropertyListDecoder().decode(String.self, from: plist)
        #expect(result == "hello")
    }

    @Test func dataWithBOM_utf32le() throws {
        let bom = Data([0xff, 0xfe])
        let plist = bom + "<?xml version=\"1.0\" encoding=\"UTF-16LE\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<string>hello</string>\n</plist>".data(using: .utf16LittleEndian)!

        let result = try PropertyListDecoder().decode(String.self, from: plist)
        #expect(result == "hello")
    }

    @Test func plistWithBadUTF8() throws {
        let data = testData(forResource: "bad_plist", withExtension: "bad")!

        #expect(throws: (any Error).self) {
    try PropertyListDecoder().decode([String].self, from: data)
}    }

    @Test func plistWithEscapedCharacters() throws {
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>com.apple.security.temporary-exception.sbpl</key><string>(allow mach-lookup (global-name-regex #&quot;^[0-9]+$&quot;))</string></dict></plist>".data(using: .utf8)!
        let result = try PropertyListDecoder().decode([String:String].self, from: plist)
        #expect(result == ["com.apple.security.temporary-exception.sbpl" : "(allow mach-lookup (global-name-regex #\"^[0-9]+$\"))"])
    }

#if FOUNDATION_FRAMEWORK
    // OpenStep format is not supported in Essentials
    @Test func returnRightFormatFromParse() throws {
        let plist = "{ CFBundleDevelopmentRegion = en; }".data(using: .utf8)!

        var format : PropertyListDecoder.PropertyListFormat = .binary
        let _ = try PropertyListDecoder().decode([String:String].self, from: plist, format: &format)
        #expect(format == .openStep)
    }
#endif

    @Test func decodingEmoji() throws {
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>emoji</key><string>&#128664;</string></dict></plist>".data(using: .utf8)!

        let result = try PropertyListDecoder().decode([String:String].self, from: plist)
        let expected = "\u{0001F698}"
        #expect(expected == result["emoji"])
    }

    @Test func decodingTooManyCharactersError() throws {
        // Try a plist with too many characters to be a unicode escape sequence
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>emoji</key><string>&#12341234128664;</string></dict></plist>".data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String:String].self, from: plist)
        }
        // Try a plist with an invalid unicode escape sequence
        let plist2 = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>emoji</key><string>&#12866411;</string></dict></plist>".data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String:String].self, from: plist2)
        }
    }
    
    @Test func roundTripEmoji() throws {
        let strings = ["🚘", "👩🏻‍❤️‍👨🏿", "🏋🏽‍♂️🕺🏼🥌"]
        
        _testRoundTrip(of: strings, in: .xml)
        _testRoundTrip(of: strings, in: .binary)
    }
    
    @Test func roundTripEscapedStrings() {
        let strings = ["&", "<", ">"]
        _testRoundTrip(of: strings, in: .xml)
    }

    @Test func unterminatedComment() {
        let plist = "<array><!-- comment -->".data(using: .utf8)!
        #expect(throws: (any Error).self) {
    try PropertyListDecoder().decode([String].self, from: plist)
}    }

    @Test func incompleteOpenTag() {
        let plist = "<array".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String].self, from: plist)
        }
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String].self, from: plist)
        }
    }

    @Test func CDATA_section() throws {
        let plist = "<string><![CDATA[Test &amp; &33; <![CDATA[]]]> outside</string>".data(using: .utf8)!
        let result = try PropertyListDecoder().decode(String.self, from: plist)
        let expected = "Test &amp; &33; <![CDATA[] outside"
        #expect(result == expected)
    }
    
    @Test func supers() throws {
        struct UsesSupers : Codable, Equatable {
            var assertionFailure: String?
            
            mutating func assertEqual<T: Equatable>(_ t1: T, _ t2: T) {
                if t1 != t2 {
                    assertionFailure = "Values are not equal: \(t1) != \(t2)"
                }
            }
            
            mutating func assertTrue( _ res: Bool) {
                if !res {
                    assertionFailure = "Expected true result"
                }
            }
            
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
                assertTrue(try keyed.decodeNil(forKey: .a))
                
                let superB = try keyed.superDecoder(forKey: .b)
                let bSVC = try superB.singleValueContainer()
                assertEqual("b", try bSVC.decode(String.self))
                
                let s = try keyed.superDecoder()
                let sSVC = try s.singleValueContainer()
                assertEqual("super", try sSVC.decode(String.self))
                
                let superUnkeyed = try keyed.superDecoder(forKey: .unkeyed)
                var unkeyed = try superUnkeyed.unkeyedContainer()
                
                let gotNil = try unkeyed.decodeNil()
                assertTrue(gotNil)
                
                let superInUnkeyed = try unkeyed.superDecoder()
                let sIUSVC = try superInUnkeyed.singleValueContainer()
                assertEqual("middle", try sIUSVC.decode(String.self))
                
                assertEqual("final", try unkeyed.decode(String.self))
            }
            
            init() { }
        }
        
        let result1 = try #require(_testRoundTrip(of: UsesSupers(), in: .xml))
        #expect(result1.assertionFailure == nil)
        let result2 = try #require(_testRoundTrip(of: UsesSupers(), in: .binary))
        #expect(result2.assertionFailure == nil)
    }
    
    @Test func badReferenceIndex() {
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
    
    @Test func badTopObjectIndex() {
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
    
    @Test func outOfBoundsObjectOffset() {
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
    
    @Test func outOfBoundsOffsetTableStart() {
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
    
    @Test func tooLargeObjectCount() {
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
    
    @Test func tooLargeOffset() {
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
    
    @Test func tooLargeIndex() {
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
    
    @Test func uid() throws {
        // There's no public interface where an NSKeyedArchiver UID value will correctly decode through PropertyListDecoder. This test ensures that it isn't mistaken for some other type.
        
        let xml = "<plist><dict><key>CF$UID</key><integer>1</integer></dict></plist>"
        let xmlData = xml.data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String:Int32].self, from: xmlData)
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
    
    @Test func fauxStability_struct() throws {
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
    
    @Test func fauxStability_dict() throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        
        let encoding = try encoder.encode(["a":"a", "z":"z", "n":"n"])
        for _ in 0..<1000 {
            let reencoding = try encoder.encode(["a":"a", "z":"z", "n":"n"])
            #expect(encoding == reencoding)
        }
    }
    
    @Test func multipleDecodeOptions() throws {
        let cases = [
            MultipleDecodeOptionsTestType("1", .int),
            MultipleDecodeOptionsTestType("1.2", .float),
            MultipleDecodeOptionsTestType("foo", .string)
        ]
        for input in cases {
            _testRoundTrip(of: input, in: .binary)
            _testRoundTrip(of: input, in: .xml)
        }
    }
    
    @Test func customSubclass() throws {
        // verify we consult the subclass for the output format
        let encodeMe = ["hello":"world"]
        let encoder = XMLOnlyEncoder()
        let data = try encoder.encode(encodeMe)
        let dataAsStr = String(data: data, encoding: .utf8)!
        #expect(dataAsStr.hasPrefix("<?xml"))
    }

    @Test func decodeIfPresent() throws {
        try _forEachEncodingFormat { format in
            let encoder = PropertyListEncoder()
            encoder.outputFormat = format

            let emptyDictEncoding = try encoder.encode(DecodeIfPresentAllTypes<KeyedEncodeWithoutNulls>.allNils)
            let testEmptyDict = try PropertyListDecoder().decode(DecodeIfPresentAllTypes<UseKeyed>.self, from: emptyDictEncoding)
            #expect(testEmptyDict == .allNils)

            let allNullDictEncoding = try encoder.encode(DecodeIfPresentAllTypes<KeyedEncodeWithNulls>.allNils)
            let testAllNullDict = try PropertyListDecoder().decode(DecodeIfPresentAllTypes<UseKeyed>.self, from: allNullDictEncoding)
            #expect(testAllNullDict == .allNils)

            let allOnesDictEncoding = try encoder.encode(DecodeIfPresentAllTypes<UseKeyed>.allOnes)
            let testAllOnesDict = try PropertyListDecoder().decode(DecodeIfPresentAllTypes<UseKeyed>.self, from: allOnesDictEncoding)
            #expect(testAllOnesDict == .allOnes)

            let emptyArrayEncoding = try encoder.encode(DecodeIfPresentAllTypes<UnkeyedEncodeWithoutNulls>.allNils)
            let testEmptyArray = try PropertyListDecoder().decode(DecodeIfPresentAllTypes<UseUnkeyed>.self, from: emptyArrayEncoding)
            #expect(testEmptyArray == .allNils)

            let allNullArrayEncoding = try encoder.encode(DecodeIfPresentAllTypes<UnkeyedEncodeWithNulls>.allNils)
            let testAllNullArray = try PropertyListDecoder().decode(DecodeIfPresentAllTypes<UseUnkeyed>.self, from: allNullArrayEncoding)
            #expect(testAllNullArray == .allNils)

            let allOnesArrayEncoding = try encoder.encode(DecodeIfPresentAllTypes<UseUnkeyed>.allOnes)
            let testAllOnesArray = try PropertyListDecoder().decode(DecodeIfPresentAllTypes<UseUnkeyed>.self, from: allOnesArrayEncoding)
            #expect(testAllOnesArray == .allOnes)
        }

    }
    
    @Test func garbageCharactersAfterXMLTagName() throws {
        let garbage = "<plist><dict><key>bar</key><stringGARBAGE>foo</string></dict></plist>".data(using: .utf8)!
        
        #expect(throws: (any Error).self) {
            try PropertyListDecoder().decode([String:String].self, from: garbage)
        }
        // Historical behavior allows for whitespace to immediately follow tag names
        let acceptable = "<plist><dict><key>bar</key><string      >foo</string></dict></plist>".data(using: .utf8)!
        
        #expect(try PropertyListDecoder().decode([String:String].self, from: acceptable) == ["bar":"foo"])
    }
}
            

// MARK: - Helper Global Functions
func AssertEqualPaths(_ lhs: [CodingKey], _ rhs: [CodingKey], _ prefix: String, sourceLocation: SourceLocation = #_sourceLocation) {
    if lhs.count != rhs.count {
        Issue.record("\(prefix) [CodingKey].count mismatch: \(lhs.count) != \(rhs.count)", sourceLocation: sourceLocation)
        return
    }

    for (key1, key2) in zip(lhs, rhs) {
        switch (key1.intValue, key2.intValue) {
        case (.none, .none): break
        case (.some(let i1), .none):
            Issue.record("\(prefix) CodingKey.intValue mismatch: \(type(of: key1))(\(i1)) != nil", sourceLocation: sourceLocation)
            return
        case (.none, .some(let i2)):
            Issue.record("\(prefix) CodingKey.intValue mismatch: nil != \(type(of: key2))(\(i2))", sourceLocation: sourceLocation)
            return
        case (.some(let i1), .some(let i2)):
            guard i1 == i2 else {
                Issue.record("\(prefix) CodingKey.intValue mismatch: \(type(of: key1))(\(i1)) != \(type(of: key2))(\(i2))", sourceLocation: sourceLocation)
                return
            }

            break
        }

        #expect(key1.stringValue == key2.stringValue, "\(prefix) CodingKey.stringValue mismatch: \(type(of: key1))('\(key1.stringValue)') != \(type(of: key2))('\(key2.stringValue)')", sourceLocation: sourceLocation)
    }
}

// MARK: - Test Types

// MARK: - Empty Types
fileprivate struct EmptyStruct : Codable, Equatable {
    static func ==(_ lhs: EmptyStruct, _ rhs: EmptyStruct) -> Bool {
        return true
    }
}

fileprivate class EmptyClass : Codable, Equatable {
    static func ==(_ lhs: EmptyClass, _ rhs: EmptyClass) -> Bool {
        return true
    }
}

// MARK: - Single-Value Types
/// A simple on-off switch type that encodes as a single Bool value.
fileprivate enum Switch : Codable {
    case off
    case on

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(Bool.self) {
        case false: self = .off
        case true:  self = .on
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .off: try container.encode(false)
        case .on:  try container.encode(true)
        }
    }
}

/// A simple timestamp type that encodes as a single Double value.
fileprivate struct Timestamp : Codable, Equatable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(Double.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }

    static func ==(_ lhs: Timestamp, _ rhs: Timestamp) -> Bool {
        return lhs.value == rhs.value
    }
}

/// A simple referential counter type that encodes as a single Int value.
fileprivate final class Counter : Codable, Equatable {
    var count: Int = 0

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        count = try container.decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.count)
    }

    static func ==(_ lhs: Counter, _ rhs: Counter) -> Bool {
        return lhs === rhs || lhs.count == rhs.count
    }
}

private struct CodableTypeWithConfiguration : CodableWithConfiguration, Equatable {
    struct Config {
        let num: Int
        
        init(_ num: Int) {
            self.num = num
        }
    }
    
    struct ConfigProviding : EncodingConfigurationProviding, DecodingConfigurationProviding {
        static var encodingConfiguration: Config { Config(2) }
        static var decodingConfiguration: Config { Config(2) }
    }
    
    typealias EncodingConfiguration = Config
    typealias DecodingConfiguration = Config
    
    static let testValue = Self(3)
    
    let num: Int
    
    init(_ num: Int) {
        self.num = num
    }
    
    func encode(to encoder: Encoder, configuration: Config) throws {
        var container = encoder.singleValueContainer()
        try container.encode(num + configuration.num)
    }
    
    init(from decoder: Decoder, configuration: Config) throws {
        let container = try decoder.singleValueContainer()
        num = try container.decode(Int.self) - configuration.num
    }
}

// MARK: - Structured Types
/// A simple address type that encodes as a dictionary of values.
fileprivate struct Address : Codable, Equatable {
    let street: String
    let city: String
    let state: String
    let zipCode: Int
    let country: String

    init(street: String, city: String, state: String, zipCode: Int, country: String) {
        self.street = street
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.country = country
    }

    static func ==(_ lhs: Address, _ rhs: Address) -> Bool {
        return lhs.street == rhs.street &&
        lhs.city == rhs.city &&
        lhs.state == rhs.state &&
        lhs.zipCode == rhs.zipCode &&
        lhs.country == rhs.country
    }

    static var testValue: Address {
        return Address(street: "1 Infinite Loop",
                       city: "Cupertino",
                       state: "CA",
                       zipCode: 95014,
                       country: "United States")
    }
}

/// A simple person class that encodes as a dictionary of values.
fileprivate class Person : Codable, Equatable {
    let name: String
    let email: String
    let website: String?

    init(name: String, email: String, website: String? = nil) {
        self.name = name
        self.email = email
        self.website = website
    }

    func isEqual(_ other: Person) -> Bool {
        return self.name == other.name &&
        self.email == other.email &&
        self.website == other.website
    }

    static func ==(_ lhs: Person, _ rhs: Person) -> Bool {
        return lhs.isEqual(rhs)
    }

    class var testValue: Person {
        return Person(name: "Johnny Appleseed", email: "appleseed@apple.com")
    }
}

/// A class which shares its encoder and decoder with its superclass.
fileprivate class Employee : Person {
    let id: Int

    init(name: String, email: String, website: String? = nil, id: Int) {
        self.id = id
        super.init(name: name, email: email, website: website)
    }

    enum CodingKeys : String, CodingKey {
        case id
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try super.encode(to: encoder)
    }

    override func isEqual(_ other: Person) -> Bool {
        if let employee = other as? Employee {
            guard self.id == employee.id else { return false }
        }

        return super.isEqual(other)
    }

    override class var testValue: Employee {
        return Employee(name: "Johnny Appleseed", email: "appleseed@apple.com", id: 42)
    }
}

/// A simple company struct which encodes as a dictionary of nested values.
fileprivate struct Company : Codable, Equatable {
    let address: Address
    var employees: [Employee]

    init(address: Address, employees: [Employee]) {
        self.address = address
        self.employees = employees
    }

    static func ==(_ lhs: Company, _ rhs: Company) -> Bool {
        return lhs.address == rhs.address && lhs.employees == rhs.employees
    }

    static var testValue: Company {
        return Company(address: Address.testValue, employees: [Employee.testValue])
    }
}

/// An enum type which decodes from Bool?.
fileprivate enum EnhancedBool : Codable {
    case `true`
    case `false`
    case fileNotFound

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .fileNotFound
        } else {
            let value = try container.decode(Bool.self)
            self = value ? .true : .false
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .true: try container.encode(true)
        case .false: try container.encode(false)
        case .fileNotFound: try container.encodeNil()
        }
    }
}

/// A type which encodes as an array directly through a single value container.
private struct Numbers : Codable, Equatable {
    let values = [4, 8, 15, 16, 23, 42]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decodedValues = try container.decode([Int].self)
        guard decodedValues == values else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "The Numbers are wrong!"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    static func ==(_ lhs: Numbers, _ rhs: Numbers) -> Bool {
        return lhs.values == rhs.values
    }

    static var testValue: Numbers {
        return Numbers()
    }
}

/// A type which encodes as a dictionary directly through a single value container.
fileprivate final class Mapping : Codable, Equatable {
    let values: [String : String]

    init(values: [String : String]) {
        self.values = values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        values = try container.decode([String : String].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    static func ==(_ lhs: Mapping, _ rhs: Mapping) -> Bool {
        return lhs === rhs || lhs.values == rhs.values
    }

    static var testValue: Mapping {
        return Mapping(values: ["Apple": "http://apple.com",
                                "localhost": "http://127.0.0.1"])
    }
}

private struct NestedContainersTestType : Encodable {
    let testSuperEncoder: Bool

    init(testSuperEncoder: Bool = false) {
        self.testSuperEncoder = testSuperEncoder
    }

    enum TopLevelCodingKeys : Int, CodingKey {
        case a
        case b
        case c
    }

    enum IntermediateCodingKeys : Int, CodingKey {
        case one
        case two
    }

    func encode(to encoder: Encoder) throws {
        if self.testSuperEncoder {
            var topLevelContainer = encoder.container(keyedBy: TopLevelCodingKeys.self)
            AssertEqualPaths(encoder.codingPath, [], "Top-level Encoder's codingPath changed.")
            AssertEqualPaths(topLevelContainer.codingPath, [], "New first-level keyed container has non-empty codingPath.")

            let superEncoder = topLevelContainer.superEncoder(forKey: .a)
            AssertEqualPaths(encoder.codingPath, [], "Top-level Encoder's codingPath changed.")
            AssertEqualPaths(topLevelContainer.codingPath, [], "First-level keyed container's codingPath changed.")
            AssertEqualPaths(superEncoder.codingPath, [TopLevelCodingKeys.a], "New superEncoder had unexpected codingPath.")
            _testNestedContainers(in: superEncoder, baseCodingPath: [TopLevelCodingKeys.a])
        } else {
            _testNestedContainers(in: encoder, baseCodingPath: [])
        }
    }

    func _testNestedContainers(in encoder: Encoder, baseCodingPath: [CodingKey]) {
        AssertEqualPaths(encoder.codingPath, baseCodingPath, "New encoder has non-empty codingPath.")

        // codingPath should not change upon fetching a non-nested container.
        var firstLevelContainer = encoder.container(keyedBy: TopLevelCodingKeys.self)
        AssertEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
        AssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "New first-level keyed container has non-empty codingPath.")

        // Nested Keyed Container
        do {
            // Nested container for key should have a new key pushed on.
            var secondLevelContainer = firstLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self, forKey: .a)
            AssertEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            AssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            AssertEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "New second-level keyed container had unexpected codingPath.")

            // Inserting a keyed container should not change existing coding paths.
            let thirdLevelContainerKeyed = secondLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self, forKey: .one)
            AssertEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            AssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            AssertEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "Second-level keyed container's codingPath changed.")
            AssertEqualPaths(thirdLevelContainerKeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.a, IntermediateCodingKeys.one], "New third-level keyed container had unexpected codingPath.")

            // Inserting an unkeyed container should not change existing coding paths.
            let thirdLevelContainerUnkeyed = secondLevelContainer.nestedUnkeyedContainer(forKey: .two)
            AssertEqualPaths(encoder.codingPath, baseCodingPath + [], "Top-level Encoder's codingPath changed.")
            AssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath + [], "First-level keyed container's codingPath changed.")
            AssertEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "Second-level keyed container's codingPath changed.")
            AssertEqualPaths(thirdLevelContainerUnkeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.a, IntermediateCodingKeys.two], "New third-level unkeyed container had unexpected codingPath.")
        }

        // Nested Unkeyed Container
        do {
            // Nested container for key should have a new key pushed on.
            var secondLevelContainer = firstLevelContainer.nestedUnkeyedContainer(forKey: .b)
            AssertEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            AssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            AssertEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "New second-level keyed container had unexpected codingPath.")

            // Appending a keyed container should not change existing coding paths.
            let thirdLevelContainerKeyed = secondLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self)
            AssertEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            AssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            AssertEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "Second-level unkeyed container's codingPath changed.")
            AssertEqualPaths(thirdLevelContainerKeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.b, _TestKey(index: 0)], "New third-level keyed container had unexpected codingPath.")

            // Appending an unkeyed container should not change existing coding paths.
            let thirdLevelContainerUnkeyed = secondLevelContainer.nestedUnkeyedContainer()
            AssertEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            AssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            AssertEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "Second-level unkeyed container's codingPath changed.")
            AssertEqualPaths(thirdLevelContainerUnkeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.b, _TestKey(index: 1)], "New third-level unkeyed container had unexpected codingPath.")
        }
    }
}

// MARK: - Helper Types

/// A key type which can take on any string or integer value.
/// This needs to mirror _PlistKey.
fileprivate struct _TestKey : CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }
}

/// Wraps a type T so that it can be encoded at the top level of a payload.
fileprivate struct TopLevelWrapper<T> : Codable, Equatable where T : Codable, T : Equatable {
    let value: T

    init(_ value: T) {
        self.value = value
    }

    static func ==(_ lhs: TopLevelWrapper<T>, _ rhs: TopLevelWrapper<T>) -> Bool {
        return lhs.value == rhs.value
    }
}

fileprivate enum EitherDecodable<T : Decodable, U : Decodable> : Decodable {
    case t(T)
    case u(U)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let t = try? container.decode(T.self) {
            self = .t(t)
        } else if let u = try? container.decode(U.self) {
            self = .u(u)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Data was neither \(T.self) nor \(U.self).")
        }
    }
}

private struct MultipleDecodeOptionsTestType : Codable, Equatable {
    enum EncodingOption: Equatable {
        case string
        case int
        case float
    }
    
    let value: String
    let encodingOption: EncodingOption
    
    init(_ value: String, _ encodingOption: EncodingOption) {
        self.value = value
        self.encodingOption = encodingOption
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch encodingOption {
        case .string: try container.encode(value)
        case .int: try container.encode(Int(value)!)
        case .float: try container.encode(Float(value)!)
        }
        
    }
    
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        if let int = try? container.decode(Int.self) {
            value = "\(int)"
            encodingOption = .int
        } else if let float = try? container.decode(Float.self) {
            value = "\(float)"
            encodingOption = .float
        } else {
            value = try container.decode(String.self)
            encodingOption = .string
        }
    }
}

// MARK: - Helper Class

class XMLOnlyEncoder : PropertyListEncoder, @unchecked Sendable {
    override var outputFormat: PropertyListDecoder.PropertyListFormat {
        get { return .xml }
        set { }
    }
}
