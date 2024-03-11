// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#elseif canImport(FoundationEssentials)
@testable import FoundationEssentials
#endif

// MARK: - Test Suite

class TestPropertyListEncoder : XCTestCase {
    // MARK: - Encoding Top-Level Empty Types
#if FIXED_64141381
    func testEncodingTopLevelEmptyStruct() {
        let empty = EmptyStruct()
        _testRoundTrip(of: empty, in: .binary, expectedPlist: _plistEmptyDictionaryBinary)
        _testRoundTrip(of: empty, in: .xml, expectedPlist: _plistEmptyDictionaryXML)
    }

    func testEncodingTopLevelEmptyClass() {
        let empty = EmptyClass()
        _testRoundTrip(of: empty, in: .binary, expectedPlist: _plistEmptyDictionaryBinary)
        _testRoundTrip(of: empty, in: .xml, expectedPlist: _plistEmptyDictionaryXML)
    }
#endif

    // MARK: - Encoding Top-Level Single-Value Types
    func testEncodingTopLevelSingleValueEnum() {
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

    func testEncodingTopLevelSingleValueStruct() {
        let t = Timestamp(3141592653)
        _testEncodeFailure(of: t, in: .binary)
        _testEncodeFailure(of: t, in: .xml)
        _testRoundTrip(of: TopLevelWrapper(t), in: .binary)
        _testRoundTrip(of: TopLevelWrapper(t), in: .xml)
    }

    func testEncodingTopLevelSingleValueClass() {
        let c = Counter()
        _testEncodeFailure(of: c, in: .binary)
        _testEncodeFailure(of: c, in: .xml)
        _testRoundTrip(of: TopLevelWrapper(c), in: .binary)
        _testRoundTrip(of: TopLevelWrapper(c), in: .xml)
    }

    // MARK: - Encoding Top-Level Structured Types
    func testEncodingTopLevelStructuredStruct() {
        // Address is a struct type with multiple fields.
        let address = Address.testValue
        _testRoundTrip(of: address, in: .binary)
        _testRoundTrip(of: address, in: .xml)
    }

    func testEncodingTopLevelStructuredClass() {
        // Person is a class with multiple fields.
        let person = Person.testValue
        _testRoundTrip(of: person, in: .binary)
        _testRoundTrip(of: person, in: .xml)
    }

    func testEncodingTopLevelStructuredSingleStruct() {
        // Numbers is a struct which encodes as an array through a single value container.
        let numbers = Numbers.testValue
        _testRoundTrip(of: numbers, in: .binary)
        _testRoundTrip(of: numbers, in: .xml)
    }

    func testEncodingTopLevelStructuredSingleClass() {
        // Mapping is a class which encodes as a dictionary through a single value container.
        let mapping = Mapping.testValue
        _testRoundTrip(of: mapping, in: .binary)
        _testRoundTrip(of: mapping, in: .xml)
    }

    func testEncodingTopLevelDeepStructuredType() {
        // Company is a type with fields which are Codable themselves.
        let company = Company.testValue
        _testRoundTrip(of: company, in: .binary)
        _testRoundTrip(of: company, in: .xml)
    }

    func testEncodingClassWhichSharesEncoderWithSuper() {
        // Employee is a type which shares its encoder & decoder with its superclass, Person.
        let employee = Employee.testValue
        _testRoundTrip(of: employee, in: .binary)
        _testRoundTrip(of: employee, in: .xml)
    }

    func testEncodingTopLevelNullableType() {
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

    func testEncodingTopLevelWithConfiguration() throws {
        // CodableTypeWithConfiguration is a struct that conforms to CodableWithConfiguration
        let value = CodableTypeWithConfiguration.testValue
        let encoder = PropertyListEncoder()
        let decoder = PropertyListDecoder()

        var decoded = try decoder.decode(CodableTypeWithConfiguration.self, from: try encoder.encode(value, configuration: .init(1)), configuration: .init(1))
        XCTAssertEqual(decoded, value)
        decoded = try decoder.decode(CodableTypeWithConfiguration.self, from: try encoder.encode(value, configuration: CodableTypeWithConfiguration.ConfigProviding.self), configuration: CodableTypeWithConfiguration.ConfigProviding.self)
        XCTAssertEqual(decoded, value)
    }

#if FIXED_64141381
    func testEncodingMultipleNestedContainersWithTheSameTopLevelKey() {
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
    func testEncodingConflictedTypeNestedContainersWithTheSameTopLevelKey() {
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
    func testNestedContainerCodingPaths() {
        let encoder = PropertyListEncoder()
        do {
            let _ = try encoder.encode(NestedContainersTestType())
        } catch let error as NSError {
            XCTFail("Caught error during encoding nested container types: \(error)")
        }
    }

    func testSuperEncoderCodingPaths() {
        let encoder = PropertyListEncoder()
        do {
            let _ = try encoder.encode(NestedContainersTestType(testSuperEncoder: true))
        } catch let error as NSError {
            XCTFail("Caught error during encoding nested container types: \(error)")
        }
    }

#if FOUNDATION_FRAMEWORK
    // requires PropertyListSerialization, JSONSerialization
    
    func testEncodingTopLevelData() {
        let data = try! JSONSerialization.data(withJSONObject: [String](), options: [])
        _testRoundTrip(of: data, in: .binary, expectedPlist: try! PropertyListSerialization.data(fromPropertyList: data, format: .binary, options: 0))
        _testRoundTrip(of: data, in: .xml, expectedPlist: try! PropertyListSerialization.data(fromPropertyList: data, format: .xml, options: 0))
    }

    func testInterceptData() {
        let data = try! JSONSerialization.data(withJSONObject: [String](), options: [])
        let topLevel = TopLevelWrapper(data)
        let plist = ["value": data]
        _testRoundTrip(of: topLevel, in: .binary, expectedPlist: try! PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0))
        _testRoundTrip(of: topLevel, in: .xml, expectedPlist: try! PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0))
    }

    func testInterceptDate() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let topLevel = TopLevelWrapper(date)
        let plist = ["value": date]
        _testRoundTrip(of: topLevel, in: .binary, expectedPlist: try! PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0))
        _testRoundTrip(of: topLevel, in: .xml, expectedPlist: try! PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0))
    }
#endif // FOUNDATION_FRaMEWORK

    // MARK: - Type coercion
    func testTypeCoercion() {
        func _testRoundTripTypeCoercionFailure<T,U>(of value: T, as type: U.Type) where T : Codable, U : Codable {
            let encoder = PropertyListEncoder()

            encoder.outputFormat = .xml
            let xmlData = try! encoder.encode(value)
            XCTAssertThrowsError(try PropertyListDecoder().decode(U.self, from: xmlData), "Coercion from \(T.self) to \(U.self) was expected to fail.")

            encoder.outputFormat = .binary
            let binaryData = try! encoder.encode(value)
            XCTAssertThrowsError(try PropertyListDecoder().decode(U.self, from: binaryData), "Coercion from \(T.self) to \(U.self) was expected to fail.")
        }

        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int8].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int16].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int32].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int64].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt8].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt16].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt32].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt64].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Float].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Double].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int8], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int16], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int32], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int64], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt8], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt16], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt32], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt64], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Float], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Double], as: [Bool].self)

        // Real -> Integer coercions that are impossible.
        _testRoundTripTypeCoercionFailure(of: [256] as [Double], as: [UInt8].self)
        _testRoundTripTypeCoercionFailure(of: [-129] as [Double], as: [Int8].self)
        _testRoundTripTypeCoercionFailure(of: [-1.0] as [Double], as: [UInt64].self)
        _testRoundTripTypeCoercionFailure(of: [3.14159] as [Double], as: [UInt64].self)
        _testRoundTripTypeCoercionFailure(of: [.infinity] as [Double], as: [UInt64].self)
        _testRoundTripTypeCoercionFailure(of: [.nan] as [Double], as: [UInt64].self)

        // Especially for binary plist, ensure we maintain different encoded representations of special values like Int64(-1) and UInt64.max, which have the same 8 byte representation.
        _testRoundTripTypeCoercionFailure(of: [Int64(-1)], as: [UInt64].self)
        _testRoundTripTypeCoercionFailure(of: [UInt64.max], as: [Int64].self)
    }

    func testIntegerRealCoercion() throws {
        func _testRoundTripTypeCoercion<T: Codable, U: Codable & Equatable>(of value: T, expectedCoercedValue: U) throws {
            let encoder = PropertyListEncoder()

            encoder.outputFormat = .xml

            let xmlData = try encoder.encode([value])
            var decoded = try PropertyListDecoder().decode([U].self, from: xmlData)
            XCTAssertEqual(decoded.first!, expectedCoercedValue)

            encoder.outputFormat = .binary
            let binaryData = try encoder.encode([value])

            decoded = try PropertyListDecoder().decode([U].self, from: binaryData)
            XCTAssertEqual(decoded.first!, expectedCoercedValue)
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

    func testDecodingConcreteTypeParameter() {
        let encoder = PropertyListEncoder()
        guard let plist = try? encoder.encode(Employee.testValue) else {
            XCTFail("Unable to encode Employee.")
            return
        }

        let decoder = PropertyListDecoder()
        guard let decoded = try? decoder.decode(Employee.self as Person.Type, from: plist) else {
            XCTFail("Failed to decode Employee as Person from plist.")
            return
        }

        expectEqual(type(of: decoded), Employee.self, "Expected decoded value to be of type Employee; got \(type(of: decoded)) instead.")
    }

    // MARK: - Encoder State
    // SR-6078
    func testEncoderStateThrowOnEncode() {
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
    func testDecoderStateThrowOnDecode() {
        let plist = try! PropertyListEncoder().encode([1,2,3])
        let _ = try! PropertyListDecoder().decode(EitherDecodable<[String], [Int]>.self, from: plist)
    }

#if FOUNDATION_FRAMEWORK
    // MARK: - NSKeyedArchiver / NSKeyedUnarchiver integration
    func testArchiving() {
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

        do {
            try keyedArchiver.encodeEncodable(value, forKey: "strings")
            keyedArchiver.finishEncoding()
            let data = keyedArchiver.encodedData

            let keyedUnarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            let unarchived = try keyedUnarchiver.decodeTopLevelDecodable(CodableType.self, forKey: "strings")

            XCTAssertEqual(unarchived, value)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
#endif
    
    // MARK: - Helper Functions
    private var _plistEmptyDictionaryBinary: Data {
        return Data(base64Encoded: "YnBsaXN0MDDQCAAAAAAAAAEBAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAJ")!
    }

    private var _plistEmptyDictionaryXML: Data {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict/>\n</plist>\n".data(using: String._Encoding.utf8)!
    }

    private func _testEncodeFailure<T : Encodable>(of value: T, in format: PropertyListDecoder.PropertyListFormat) {
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = format
            let _ = try encoder.encode(value)
            XCTFail("Encode of top-level \(T.self) was expected to fail.")
        } catch {}
    }

    private func _testRoundTrip<T>(of value: T, in format: PropertyListDecoder.PropertyListFormat, expectedPlist plist: Data? = nil) where T : Codable, T : Equatable {
        var payload: Data! = nil
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = format
            payload = try encoder.encode(value)
        } catch {
            XCTFail("Failed to encode \(T.self) to plist: \(error)")
        }

        if let expectedPlist = plist {
            XCTAssertEqual(expectedPlist, payload, "Produced plist not identical to expected plist.")
        }

        do {
            var decodedFormat: PropertyListDecoder.PropertyListFormat = format
            let decoded = try PropertyListDecoder().decode(T.self, from: payload, format: &decodedFormat)
            XCTAssertEqual(format, decodedFormat, "Encountered plist format differed from requested format.")
            XCTAssertEqual(decoded, value, "\(T.self) did not round-trip to an equal value.")
        } catch {
            XCTFail("Failed to decode \(T.self) from plist: \(error)")
        }
    }

    // MARK: - Other tests
    func testUnkeyedContainerContainingNulls() throws {
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
    
    func test_invalidNSDataKey_82142612() {
        let data = testData(forResource: "Test_82142612", withExtension: "bad")!

        let decoder = PropertyListDecoder()
        XCTAssertThrowsError(try decoder.decode([String:String].self, from: data))

        // Repeat something similar with XML.
        let xmlData = "<plist><dict><data>abcd</data><string>xyz</string></dict></plist>".data(using: String._Encoding.utf8)!
        XCTAssertThrowsError(try decoder.decode([String:String].self, from: xmlData))
    }

#if FOUNDATION_FRAMEWORK
    // TODO: Depends on data's range(of:) implementation
    func test_nonStringDictionaryKey() {
        let decoder = PropertyListDecoder()
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        var data = try! encoder.encode(["abcd":"xyz"])

        // Replace the tag for the ASCII string (0101) that is length 4 ("abcd" => length: 0100) with a boolean "true" tag (0000_1001)
        let range = data.range(of: Data([0b0101_0100]))!
        data.replaceSubrange(range, with: Data([0b000_1001]))
        XCTAssertThrowsError(try decoder.decode([String:String].self, from: data))

        let xmlData = "<plist><dict><string>abcd</string><string>xyz</string></dict></plist>".data(using: String._Encoding.utf8)!
        XCTAssertThrowsError(try decoder.decode([String:String].self, from: xmlData))
    }
#endif

    struct GenericProperties : Decodable {
        static var assertionFailure: String?

        enum CodingKeys: String, CodingKey {
            case array1, item1, item2
        }

        static func AssertEqual<T: Equatable>(_ t1: T, _ t2: T) {
            if t1 != t2 {
                assertionFailure = "Values are not equal: \(t1) != \(t2)"
            }
        }

        init(from decoder: Decoder) throws {
            let keyed = try decoder.container(keyedBy: CodingKeys.self)

            var arrayContainer = try keyed.nestedUnkeyedContainer(forKey: .array1)
            Self.AssertEqual(try arrayContainer.decode(String.self), "arr0")
            Self.AssertEqual(try arrayContainer.decode(Int.self), 42)
            Self.AssertEqual(try arrayContainer.decode(Bool.self), false)

            let comps = DateComponents(calendar: .init(identifier: .gregorian), timeZone: .init(secondsFromGMT: 0), year: 1976, month: 04, day: 01, hour: 12, minute: 00, second: 00)
            let date = comps.date!
            Self.AssertEqual(try arrayContainer.decode(Date.self), date)

            let someData = Data([0xaa, 0xbb, 0xcc, 0xdd, 0x00, 0x11, 0x22, 0x33])
            Self.AssertEqual(try arrayContainer.decode(Data.self), someData)

            Self.AssertEqual(try keyed.decode(String.self, forKey: .item1), "value1")
            Self.AssertEqual(try keyed.decode(String.self, forKey: .item2), "value2")
        }
    }

    func test_5616259() throws {
        let plistData = testData(forResource: "Test_5616259", withExtension: "bad")!
        XCTAssertThrowsError(try PropertyListDecoder().decode([String].self, from: plistData))
    }

    func test_genericProperties_XML() throws {
        defer { GenericProperties.assertionFailure = nil }

        let data = testData(forResource: "Generic_XML_Properties", withExtension: "plist")!

        XCTAssertNoThrow(try PropertyListDecoder().decode(GenericProperties.self, from: data))
        XCTAssertNil(GenericProperties.assertionFailure)
    }

    func test_genericProperties_binary() throws {
        let data = testData(forResource: "Generic_XML_Properties_Binary", withExtension: "plist")!

        defer { GenericProperties.assertionFailure = nil }

        XCTAssertNoThrow(try PropertyListDecoder().decode(GenericProperties.self, from: data))
        XCTAssertNil(GenericProperties.assertionFailure)
    }

    // <rdar://problem/5877417> Binary plist parser should parse any version 'bplist0?'
    func test_5877417() {
        var data = testData(forResource: "Generic_XML_Properties_Binary", withExtension: "plist")!

        // Modify the data so the header starts with bplist0x
        data[7] = UInt8(ascii: "x")

        defer { GenericProperties.assertionFailure = nil }

        XCTAssertNoThrow(try PropertyListDecoder().decode(GenericProperties.self, from: data))
        XCTAssertNil(GenericProperties.assertionFailure)
    }

    func test_xmlErrors() {
        let data = testData(forResource: "Generic_XML_Properties", withExtension: "plist")!
        let originalXML = String(data: data, encoding: .utf8)!

        defer { GenericProperties.assertionFailure = nil }

        // Try an empty plist
        XCTAssertThrowsError(try PropertyListDecoder().decode(GenericProperties.self, from: Data()))
        XCTAssertNil(GenericProperties.assertionFailure)
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
        errorPlists["Unterminated comment"] = originalXML.replacingOccurrences(of: "<dict>", with: "<-- unending comment\n<dict>")
        errorPlists["Mess with DOCTYPE"] = originalXML.replacingOccurrences(of: "DOCTYPE", with: "foobar")

        let range = originalXML.range(of: "//EN")!
        errorPlists["Early EOF"] = String(originalXML[originalXML.startIndex ..< range.lowerBound])

        errorPlists["MalformedDTD"] = originalXML.replacingOccurrences(of: "<!DOCTYPE", with: "<?DOCTYPE")
        errorPlists["Mismathed close tag"] = originalXML.replacingOccurrences(of: "</array>", with: "</somethingelse>")
        errorPlists["Bad open tag"] = originalXML.replacingOccurrences(of: "<array>", with: "<invalidtag>")
        errorPlists["Extra plist object"] = originalXML.replacingOccurrences(of: "</plist>", with: "<string>hello</string>\n</plist>")
        errorPlists["Non-key inside dict"] = originalXML.replacingOccurrences(of: "<key>array1</key>", with: "<string>hello</string>\n<key>array1</key>")
        errorPlists["Missing value for key"] = originalXML.replacingOccurrences(of: "<string>value1</string>", with: "")
        errorPlists["Malformed real tag"] = originalXML.replacingOccurrences(of: "<integer>42</integer>", with: "<real>abc123</real>")
        errorPlists["Empty int tag"] = originalXML.replacingOccurrences(of: "<integer>42</integer>", with: "<integer></integer>")
        errorPlists["Strange int tag"] = originalXML.replacingOccurrences(of: "<integer>42</integer>", with: "<integer>42q</integer>")
        errorPlists["Hex digit in non-hex int"] = originalXML.replacingOccurrences(of: "<integer>42</integer>", with: "<integer>42A</integer>")
        errorPlists["Enormous int"] = originalXML.replacingOccurrences(of: "<integer>42</integer>", with: "<integer>99999999999999999999999999999999999999999</integer>")
        errorPlists["Empty plist"] = "<plist></plist>"
        errorPlists["Empty date"] = originalXML.replacingOccurrences(of: "<date>1976-04-01T12:00:00Z</date>", with: "<date></date>")
        errorPlists["Empty real"] = originalXML.replacingOccurrences(of: "<integer>42</integer>", with: "<real></real>")
        errorPlists["Fake inline DTD"] = originalXML.replacingOccurrences(of: "PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"", with: "[<!ELEMENT foo (#PCDATA)>]")
        for (name, badPlist) in errorPlists {
            let data = badPlist.data(using: String._Encoding.utf8)!
            XCTAssertThrowsError(try PropertyListDecoder().decode(GenericProperties.self, from: data), "Case \(name) did not fail as expected")
        }

    }

    func test_6164184() throws {
        let xml = "<plist><array><integer>0x721B</integer><integer>0x1111</integer><integer>-0xFFFF</integer></array></plist>"
        let array = try PropertyListDecoder().decode([Int].self, from: xml.data(using: String._Encoding.utf8)!)
        XCTAssertEqual([0x721B, 0x1111, -0xFFFF], array)
    }

    func test_xmlIntegerEdgeCases() throws {
        func checkValidEdgeCase<T: Decodable & Equatable>(_ xml: String, type: T.Type, expected: T) throws {
            let value = try PropertyListDecoder().decode(type, from: xml.data(using: String._Encoding.utf8)!)
            XCTAssertEqual(value, expected)
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

        func checkInvalidEdgeCase<T: Decodable>(_ xml: String, type: T.Type) {
            XCTAssertThrowsError(try PropertyListDecoder().decode(type, from: xml.data(using: String._Encoding.utf8)!))
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
    
    func test_xmlIntegerWhitespace() throws {
        let xml = "<array><integer> +\t42</integer><integer>\t-   99</integer><integer> -\t0xFACE</integer></array>"
        
        let value = try PropertyListDecoder().decode([Int].self, from: xml.data(using: String._Encoding.utf8)!)
        XCTAssertEqual(value, [42, -99, -0xFACE])
    }

    func test_binaryNumberEdgeCases() throws {
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
    
    func test_binaryReals() throws {
        func encode<T: BinaryFloatingPoint & Encodable>(_: T.Type) -> (data: Data, expected: [T]) {
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
            let data = try! encoder.encode(expected)
            return (data, expected)
        }
        
        func test<T: BinaryFloatingPoint & Codable>(_ type: T.Type) {
            let (data, expected) = encode(type)
            do {
                let result = try PropertyListDecoder().decode([T].self, from: data)
                XCTAssertEqual(result, expected, "Type: \(type)")
            } catch {
                XCTFail("Expected error \(error) for type: \(type)")
            }
        }
        
        test(Float.self)
        test(Double.self)
    }

    func test_XMLReals() throws {
        let xml = "<plist><array><real>1.5</real><real>2</real><real>  -3.14</real><real>1.000000000000000000000001</real><real>31415.9e-4</real><real>-iNf</real><real>infInItY</real></array></plist>"
        let array = try PropertyListDecoder().decode([Float].self, from: xml.data(using: String._Encoding.utf8)!)
        let expected: [Float] = [
            1.5,
            2,
            -3.14,
            1.000000000000000000000001,
            31415.9e-4,
            -.infinity,
            .infinity
        ]
        XCTAssertEqual(array, expected)

        // nan doesn't work with equality.
        let xmlNAN = "<array><real>nAn</real><real>NAN</real><real>nan</real></array>"
        let arrayNAN = try PropertyListDecoder().decode([Float].self, from: xmlNAN.data(using: String._Encoding.utf8)!)
        for val in arrayNAN {
            XCTAssertTrue(val.isNaN)
        }
    }

    func test_bad_XMLReals() {
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
            XCTAssertThrowsError(try PropertyListDecoder().decode(Float.self, from: xml.data(using: String._Encoding.utf8)!), "Input: \(xml)")
        }
    }

#if FOUNDATION_FRAMEWORK
    // Requires old style plist support
    // Requires "NEXTStep" decoding in String(bytes:encoding:) for decoding the octal characters

    func test_oldStylePlist_invalid() {
        let data = "goodbye cruel world".data(using: String._Encoding.utf16)!
        XCTAssertThrowsError(try PropertyListDecoder().decode(String.self, from: data))
    }

    // <rdar://problem/34321354> Microsoft: Microsoft vso 1857102 : High Sierra regression that caused data loss : CFBundleCopyLocalizedString returns incorrect string
    // Escaped octal chars can be shorter than 3 chars long; i.e. \5 ≡ \05 ≡ \005.
    func test_oldStylePlist_getSlashedChars_octal() {
        // ('\0', '\00', '\000', '\1', '\01', '\001', ..., '\777')
        let data = testData(forResource: "test_oldStylePlist_getSlashedChars_octal", withExtension: "plist")!
        let actualStrings = try! PropertyListDecoder().decode([String].self, from: data)

        let expectedData = testData(forResource: "test_oldStylePlist_getSlashedChars_octal_expected", withExtension: "plist")!
        let expectedStrings = try! PropertyListDecoder().decode([String].self, from: expectedData)

        XCTAssertEqual(actualStrings, expectedStrings)
    }

    // Old-style plists support Unicode literals via \U syntax. They can be 1–4 characters wide.
    func test_oldStylePlist_getSlashedChars_unicode() {
        // ('\U0', '\U00', '\U000', '\U0000', '\U1', ..., '\UFFFF')
        let data = testData(forResource: "test_oldStylePlist_getSlashedChars_unicode", withExtension: "plist")!
        let actualStrings = try! PropertyListDecoder().decode([String].self, from: data)

        let expectedData = testData(forResource: "test_oldStylePlist_getSlashedChars_unicode_expected", withExtension: "plist")!
        let expectedStrings = try! PropertyListDecoder().decode([String].self, from: expectedData)

        XCTAssertEqual(actualStrings, expectedStrings)
    }

    func test_oldStylePlist_getSlashedChars_literals() {
        let literals = ["\u{7}", "\u{8}", "\u{12}", "\n", "\r", "\t", "\u{11}", "\"", "\\n"]
        let data = "('\\a', '\\b', '\\f', '\\n', '\\r', '\\t', '\\v', '\\\"', '\\\\n')".data(using: String._Encoding.utf8)!

        let strings = try! PropertyListDecoder().decode([String].self, from: data)
        XCTAssertEqual(strings, literals)
    }
    
    func test_oldStylePlist_dictionary() {
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
        do {
            let decoded = try PropertyListDecoder().decode(Values.self, from: data)
            XCTAssertEqual(decoded.testKey, "value")
            XCTAssertEqual(decoded.testData, Data([0xfe, 0xed, 0xfa, 0xce]))
            XCTAssertEqual(decoded.nestedArray, ["a", "b", "c"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_oldStylePlist_stringsFileFormat() {
        let data = """
string1 = "Good morning";
string2 = "Good afternoon";
string3 = "Good evening";
""".data(using: String._Encoding.utf16)!

        do {
            let decoded = try PropertyListDecoder().decode([String:String].self, from: data)
            let expected = [
                "string1": "Good morning",
                "string2": "Good afternoon",
                "string3": "Good evening"
            ]
            XCTAssertEqual(decoded, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
        
    func test_oldStylePlist_comments() {
        let data = """
// Initial comment */
string1 = /*Test*/ "Good morning";  // Test
string2 = "Good afternoon" /*Test// */;
string3 = "Good evening"; // Test
""".data(using: String._Encoding.utf16)!

        do {
            let decoded = try PropertyListDecoder().decode([String:String].self, from: data)
            let expected = [
                "string1": "Good morning",
                "string2": "Good afternoon",
                "string3": "Good evening"
            ]
            XCTAssertEqual(decoded, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
#endif
    
#if FOUNDATION_FRAMEWORK
    // Requires __PlistDictionaryDecoder
    
    func test_oldStylePlist_data() {
        let data = """
data1 = <7465
73 74
696E67                31

323334>;
""".data(using: String._Encoding.utf16)!
        
        do {
            let decoded = try PropertyListDecoder().decode([String:Data].self, from: data)
            let expected = ["data1" : "testing1234".data(using: String._Encoding.utf8)!]
            XCTAssertEqual(decoded, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
#endif

#if FOUNDATION_FRAMEWORK
    // Requires PropertyListSerialization
    
    func test_BPlistCollectionReferences() {
        // Use NSArray/NSDictionary and PropertyListSerialization so that we get a bplist with internal references.
        let c: NSArray = [ "a", "a", "a" ]
        let b: NSArray = [ c, c, c ]
        let a: NSArray = [ b, b, b ]
        let d: NSDictionary = ["a" : a, "b" : b, "c" : c]
        let data = try! PropertyListSerialization.data(fromPropertyList: d, format: .binary, options: 0)

        do {
            struct DecodedReferences: Decodable {
                let a: [[[String]]]
                let b: [[String]]
                let c: [String]
            }

            let decoded = try PropertyListDecoder().decode(DecodedReferences.self, from: data)
            XCTAssertEqual(decoded.a, a as! [[[String]]])
            XCTAssertEqual(decoded.b, b as! [[String]])
            XCTAssertEqual(decoded.c, c as! [String])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
#endif


    func test_reallyOldDates_5842198() throws {
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<date>0009-09-15T23:16:13Z</date>\n</plist>"
        let data = plist.data(using: String._Encoding.utf8)!

        XCTAssertNoThrow(try PropertyListDecoder().decode(Date.self, from: data))
    }

    func test_badDates() throws {
        let timeInterval = TimeInterval(-63145612800) // This is the equivalent of an all-zero gregorian date.
        let date = Date(timeIntervalSinceReferenceDate: timeInterval)
        
        _testRoundTrip(of: [date], in: .xml)
        _testRoundTrip(of: [date], in: .binary)
    }

    func test_badDate_encode() throws {
        let date = Date(timeIntervalSinceReferenceDate: -63145612800) // 0000-01-02 AD

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode([date])
        let str = String(data: data, encoding: String.Encoding.utf8)
        XCTAssertEqual(str, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<array>\n\t<date>0000-01-02T00:00:00Z</date>\n</array>\n</plist>\n")
    }

    func test_badDate_decode() throws {
        // Test that we can correctly decode a distant date in the past
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<date>0000-01-02T00:00:00Z</date>\n</plist>"
        let data = plist.data(using: String._Encoding.utf8)!

        let d = try PropertyListDecoder().decode(Date.self, from: data)
        XCTAssertEqual(d.timeIntervalSinceReferenceDate, -63145612800)
    }

    func test_farFutureDates() throws {
        let date = Date(timeIntervalSince1970: 999999999999.0)

        _testRoundTrip(of: [date], in: .xml)
    }

    func test_122065123_encode() throws {
        let date = Date(timeIntervalSinceReferenceDate: 728512994) // 2024-02-01 20:43:14 UTC

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode([date])
        let str = String(data: data, encoding: String.Encoding.utf8)
        XCTAssertEqual(str, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<array>\n\t<date>2024-02-01T20:43:14Z</date>\n</array>\n</plist>\n") // Previously encoded as "2024-01-32T20:43:14Z"
    }

    func test_122065123_decodingCompatibility() throws {
        // Test that we can correctly decode an invalid date
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<date>2024-01-32T20:43:14Z</date>\n</plist>"
        let data = plist.data(using: String._Encoding.utf8)!

        let d = try PropertyListDecoder().decode(Date.self, from: data)
        XCTAssertEqual(d.timeIntervalSinceReferenceDate, 728512994) // 2024-02-01T20:43:14Z
    }

    func test_multibyteCharacters_escaped_noencoding() throws {
        let plistData = "<plist><string>These are copyright signs &#169; &#xA9; blah blah blah.</string></plist>".data(using: String._Encoding.utf8)!
        let result = try PropertyListDecoder().decode(String.self, from: plistData)
        XCTAssertEqual("These are copyright signs © © blah blah blah.", result)
    }

    func test_escapedCharacters() throws {
        let plistData = "<plist><string>&amp;&apos;&lt;&gt;&quot;</string></plist>".data(using: String._Encoding.utf8)!
        let result = try PropertyListDecoder().decode(String.self, from: plistData)
        XCTAssertEqual("&'<>\"", result)
    }

    func test_dataWithBOM_utf8() throws {
        let bom = Data([0xef, 0xbb, 0xbf])
        let plist = bom + "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<string>hello</string>\n</plist>".data(using: String._Encoding.utf8)!

        let result = try PropertyListDecoder().decode(String.self, from: plist)
        XCTAssertEqual(result, "hello")
    }

#if FOUNDATION_FRAMEWORK
    // TODO: Depends on UTF32 encoding on non-Darwin platforms
    
    func test_dataWithBOM_utf32be() throws {
        let bom = Data([0x00, 0x00, 0xfe, 0xff])
        let plist = bom + "<?xml version=\"1.0\" encoding=\"UTF-32BE\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<string>hello</string>\n</plist>".data(using: String._Encoding.utf32BigEndian)!

        let result = try PropertyListDecoder().decode(String.self, from: plist)
        XCTAssertEqual(result, "hello")
    }

    func test_dataWithBOM_utf32le() throws {
        let bom = Data([0xff, 0xfe])
        let plist = bom + "<?xml version=\"1.0\" encoding=\"UTF-16LE\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<string>hello</string>\n</plist>".data(using: String._Encoding.utf16LittleEndian)!

        let result = try PropertyListDecoder().decode(String.self, from: plist)
        XCTAssertEqual(result, "hello")
    }
#endif

    func test_plistWithBadUTF8() throws {
        let data = testData(forResource: "bad_plist", withExtension: "bad")!

        XCTAssertThrowsError(try PropertyListDecoder().decode([String].self, from: data))
    }

    func test_plistWithEscapedCharacters() throws {
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>com.apple.security.temporary-exception.sbpl</key><string>(allow mach-lookup (global-name-regex #&quot;^[0-9]+$&quot;))</string></dict></plist>".data(using: String._Encoding.utf8)!
        let result = try PropertyListDecoder().decode([String:String].self, from: plist)
        XCTAssertEqual(result, ["com.apple.security.temporary-exception.sbpl" : "(allow mach-lookup (global-name-regex #\"^[0-9]+$\"))"])
    }

#if FOUNDATION_FRAMEWORK
    // OpenStep format is not supported in Essentials
    func test_returnRightFormatFromParse() throws {
        let plist = "{ CFBundleDevelopmentRegion = en; }".data(using: String._Encoding.utf8)!

        var format : PropertyListDecoder.PropertyListFormat = .binary
        let _ = try PropertyListDecoder().decode([String:String].self, from: plist, format: &format)
        XCTAssertEqual(format, .openStep)
    }
#endif

    func test_decodingEmoji() throws {
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>emoji</key><string>&#128664;</string></dict></plist>".data(using: String._Encoding.utf8)!

        let result = try PropertyListDecoder().decode([String:String].self, from: plist)
        let expected = "\u{0001F698}"
        XCTAssertEqual(expected, result["emoji"])
    }

    func test_decodingTooManyCharactersError() throws {
        // Try a plist with too many characters to be a unicode escape sequence
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>emoji</key><string>&#12341234128664;</string></dict></plist>".data(using: String._Encoding.utf8)!

        XCTAssertThrowsError(try PropertyListDecoder().decode([String:String].self, from: plist))

        // Try a plist with an invalid unicode escape sequence
        let plist2 = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>emoji</key><string>&#12866411;</string></dict></plist>".data(using: String._Encoding.utf8)!

        XCTAssertThrowsError(try PropertyListDecoder().decode([String:String].self, from: plist2))
    }
    
    func test_roundTripEmoji() throws {
        let strings = ["🚘", "👩🏻‍❤️‍👨🏿", "🏋🏽‍♂️🕺🏼🥌"]
        
        _testRoundTrip(of: strings, in: .xml)
        _testRoundTrip(of: strings, in: .binary)
    }
    
    func test_roundTripEscapedStrings() {
        let strings = ["&", "<", ">"]
        _testRoundTrip(of: strings, in: .xml)
    }

    func test_unterminatedComment() {
        let plist = "<array><!-- comment -->".data(using: String._Encoding.utf8)!
        XCTAssertThrowsError(try PropertyListDecoder().decode([String].self, from: plist))
    }

    func test_incompleteOpenTag() {
        let plist = "<array".data(using: String._Encoding.utf8)!
        XCTAssertThrowsError(try PropertyListDecoder().decode([String].self, from: plist))
        XCTAssertThrowsError(try PropertyListDecoder().decode([String].self, from: plist))
    }

    func test_CDATA_section() throws {
        let plist = "<string><![CDATA[Test &amp; &33; <![CDATA[]]]> outside</string>".data(using: String._Encoding.utf8)!
        let result = try PropertyListDecoder().decode(String.self, from: plist)
        let expected = "Test &amp; &33; <![CDATA[] outside"
        XCTAssertEqual(result, expected)
    }
    
    func test_supers() {
        struct UsesSupers : Codable, Equatable {
            static var assertionFailure: String?
            
            static func AssertEqual<T: Equatable>(_ t1: T, _ t2: T) {
                if t1 != t2 {
                    assertionFailure = "Values are not equal: \(t1) != \(t2)"
                }
            }
            
            static func AssertTrue( _ res: Bool) {
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
                Self.AssertTrue(try keyed.decodeNil(forKey: .a))
                
                let superB = try keyed.superDecoder(forKey: .b)
                let bSVC = try superB.singleValueContainer()
                Self.AssertEqual("b", try bSVC.decode(String.self))
                
                let s = try keyed.superDecoder()
                let sSVC = try s.singleValueContainer()
                Self.AssertEqual("super", try sSVC.decode(String.self))
                
                let superUnkeyed = try keyed.superDecoder(forKey: .unkeyed)
                var unkeyed = try superUnkeyed.unkeyedContainer()
                
                let gotNil = try unkeyed.decodeNil()
                Self.AssertTrue(gotNil)
                
                let superInUnkeyed = try unkeyed.superDecoder()
                let sIUSVC = try superInUnkeyed.singleValueContainer()
                Self.AssertEqual("middle", try sIUSVC.decode(String.self))
                
                Self.AssertEqual("final", try unkeyed.decode(String.self))
            }
            
            init() { }
        }
        
        _testRoundTrip(of: UsesSupers(), in: .xml)
        XCTAssertNil(UsesSupers.assertionFailure)
        _testRoundTrip(of: UsesSupers(), in: .binary)
        XCTAssertNil(UsesSupers.assertionFailure)
    }
    
    func test_badReferenceIndex() {
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
        
        XCTAssertThrowsError(try PropertyListDecoder().decode([Int].self, from: data))
    }
    
    func test_badTopObjectIndex() {
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
        
        XCTAssertThrowsError(try PropertyListDecoder().decode([Int].self, from: data))
    }
    
    func test_outOfBoundsObjectOffset() {
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
        
        XCTAssertThrowsError(try PropertyListDecoder().decode([Int].self, from: data))
    }
    
    func test_outOfBoundsOffsetTableStart() {
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
        
        XCTAssertThrowsError(try PropertyListDecoder().decode([Int].self, from: data))
    }
    
    func test_tooLargeObjectCount() {
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
        
        XCTAssertThrowsError(try PropertyListDecoder().decode([Int].self, from: data))
    }
    
    func test_tooLargeOffset() {
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
        
        XCTAssertThrowsError(try PropertyListDecoder().decode([Int].self, from: data))
    }
    
    func test_tooLargeIndex() {
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
        
        XCTAssertThrowsError(try PropertyListDecoder().decode([Int].self, from: data))
    }
    
    func test_uid() throws {
        // There's no public interface where an NSKeyedArchiver UID value will correctly decode through PropertyListDecoder. This test ensures that it isn't mistaken for some other type.
        
        let xml = "<plist><dict><key>CF$UID</key><integer>1</integer></dict></plist>"
        let xmlData = xml.data(using: String._Encoding.utf8)!

        XCTAssertThrowsError(try PropertyListDecoder().decode([String:Int32].self, from: xmlData))

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

        XCTAssertThrowsError(try PropertyListDecoder().decode([Int32].self, from: bplistData))
    }
    
    func test_fauxStability_struct() throws {
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
            XCTAssertEqual(encoding, reencoding)
        }
    }
    
    func test_fauxStability_dict() throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        
        let encoding = try encoder.encode(["a":"a", "z":"z", "n":"n"])
        for _ in 0..<1000 {
            let reencoding = try encoder.encode(["a":"a", "z":"z", "n":"n"])
            XCTAssertEqual(encoding, reencoding)
        }
    }
    
    func testMultipleDecodeOptions() throws {
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
}
            

// MARK: - Helper Global Functions
func XCTAssertEqualPaths(_ lhs: [CodingKey], _ rhs: [CodingKey], _ prefix: String) {
    if lhs.count != rhs.count {
        XCTFail("\(prefix) [CodingKey].count mismatch: \(lhs.count) != \(rhs.count)")
        return
    }

    for (key1, key2) in zip(lhs, rhs) {
        switch (key1.intValue, key2.intValue) {
        case (.none, .none): break
        case (.some(let i1), .none):
            XCTFail("\(prefix) CodingKey.intValue mismatch: \(type(of: key1))(\(i1)) != nil")
            return
        case (.none, .some(let i2)):
            XCTFail("\(prefix) CodingKey.intValue mismatch: nil != \(type(of: key2))(\(i2))")
            return
        case (.some(let i1), .some(let i2)):
            guard i1 == i2 else {
                XCTFail("\(prefix) CodingKey.intValue mismatch: \(type(of: key1))(\(i1)) != \(type(of: key2))(\(i2))")
                return
            }

            break
        }

        XCTAssertEqual(key1.stringValue, key2.stringValue, "\(prefix) CodingKey.stringValue mismatch: \(type(of: key1))('\(key1.stringValue)') != \(type(of: key2))('\(key2.stringValue)')")
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
            XCTAssertEqualPaths(encoder.codingPath, [], "Top-level Encoder's codingPath changed.")
            XCTAssertEqualPaths(topLevelContainer.codingPath, [], "New first-level keyed container has non-empty codingPath.")

            let superEncoder = topLevelContainer.superEncoder(forKey: .a)
            XCTAssertEqualPaths(encoder.codingPath, [], "Top-level Encoder's codingPath changed.")
            XCTAssertEqualPaths(topLevelContainer.codingPath, [], "First-level keyed container's codingPath changed.")
            XCTAssertEqualPaths(superEncoder.codingPath, [TopLevelCodingKeys.a], "New superEncoder had unexpected codingPath.")
            _testNestedContainers(in: superEncoder, baseCodingPath: [TopLevelCodingKeys.a])
        } else {
            _testNestedContainers(in: encoder, baseCodingPath: [])
        }
    }

    func _testNestedContainers(in encoder: Encoder, baseCodingPath: [CodingKey]) {
        XCTAssertEqualPaths(encoder.codingPath, baseCodingPath, "New encoder has non-empty codingPath.")

        // codingPath should not change upon fetching a non-nested container.
        var firstLevelContainer = encoder.container(keyedBy: TopLevelCodingKeys.self)
        XCTAssertEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
        XCTAssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "New first-level keyed container has non-empty codingPath.")

        // Nested Keyed Container
        do {
            // Nested container for key should have a new key pushed on.
            var secondLevelContainer = firstLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self, forKey: .a)
            XCTAssertEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            XCTAssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            XCTAssertEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "New second-level keyed container had unexpected codingPath.")

            // Inserting a keyed container should not change existing coding paths.
            let thirdLevelContainerKeyed = secondLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self, forKey: .one)
            XCTAssertEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            XCTAssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            XCTAssertEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "Second-level keyed container's codingPath changed.")
            XCTAssertEqualPaths(thirdLevelContainerKeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.a, IntermediateCodingKeys.one], "New third-level keyed container had unexpected codingPath.")

            // Inserting an unkeyed container should not change existing coding paths.
            let thirdLevelContainerUnkeyed = secondLevelContainer.nestedUnkeyedContainer(forKey: .two)
            XCTAssertEqualPaths(encoder.codingPath, baseCodingPath + [], "Top-level Encoder's codingPath changed.")
            XCTAssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath + [], "First-level keyed container's codingPath changed.")
            XCTAssertEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "Second-level keyed container's codingPath changed.")
            XCTAssertEqualPaths(thirdLevelContainerUnkeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.a, IntermediateCodingKeys.two], "New third-level unkeyed container had unexpected codingPath.")
        }

        // Nested Unkeyed Container
        do {
            // Nested container for key should have a new key pushed on.
            var secondLevelContainer = firstLevelContainer.nestedUnkeyedContainer(forKey: .b)
            XCTAssertEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            XCTAssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            XCTAssertEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "New second-level keyed container had unexpected codingPath.")

            // Appending a keyed container should not change existing coding paths.
            let thirdLevelContainerKeyed = secondLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self)
            XCTAssertEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            XCTAssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            XCTAssertEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "Second-level unkeyed container's codingPath changed.")
            XCTAssertEqualPaths(thirdLevelContainerKeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.b, _TestKey(index: 0)], "New third-level keyed container had unexpected codingPath.")

            // Appending an unkeyed container should not change existing coding paths.
            let thirdLevelContainerUnkeyed = secondLevelContainer.nestedUnkeyedContainer()
            XCTAssertEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            XCTAssertEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            XCTAssertEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "Second-level unkeyed container's codingPath changed.")
            XCTAssertEqualPaths(thirdLevelContainerUnkeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.b, _TestKey(index: 1)], "New third-level unkeyed container had unexpected codingPath.")
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

