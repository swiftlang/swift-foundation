//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationEssentials)
@_spi(SwiftCorelibsFoundation)
@testable import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(WASI)
import WASILibc
#elseif os(Windows)
import CRT
#endif

// MARK: - Test Suite

struct JSONEncoderTests {
    // MARK: - Encoding Top-Level Empty Types
    @Test func testEncodingTopLevelEmptyStruct() {
        let empty = EmptyStruct()
        _testRoundTrip(of: empty, expectedJSON: _jsonEmptyDictionary)
    }

    @Test func testEncodingTopLevelEmptyClass() {
        let empty = EmptyClass()
        _testRoundTrip(of: empty, expectedJSON: _jsonEmptyDictionary)
    }

    // MARK: - Encoding Top-Level Single-Value Types
    @Test func testEncodingTopLevelSingleValueEnum() {
        _testRoundTrip(of: Switch.off)
        _testRoundTrip(of: Switch.on)
    }

    @Test func testEncodingTopLevelSingleValueStruct() {
        _testRoundTrip(of: Timestamp(3141592653))
    }

    @Test func testEncodingTopLevelSingleValueClass() {
        _testRoundTrip(of: Counter())
    }

    // MARK: - Encoding Top-Level Structured Types
    @Test func testEncodingTopLevelStructuredStruct() {
        // Address is a struct type with multiple fields.
        let address = Address.testValue
        _testRoundTrip(of: address)
    }

    @Test func testEncodingTopLevelStructuredSingleStruct() {
        // Numbers is a struct which encodes as an array through a single value container.
        let numbers = Numbers.testValue
        _testRoundTrip(of: numbers)
    }

    @Test func testEncodingTopLevelStructuredSingleClass() {
        // Mapping is a class which encodes as a dictionary through a single value container.
        let mapping = Mapping.testValue
        _testRoundTrip(of: mapping)
    }

    @Test func testEncodingTopLevelDeepStructuredType() {
        // Company is a type with fields which are Codable themselves.
        let company = Company.testValue
        _testRoundTrip(of: company)
    }

    @Test func testEncodingClassWhichSharesEncoderWithSuper() {
        // Employee is a type which shares its encoder & decoder with its superclass, Person.
        let employee = Employee.testValue
        _testRoundTrip(of: employee)
    }

    @Test func testEncodingTopLevelNullableType() {
        // EnhancedBool is a type which encodes either as a Bool or as nil.
        _testRoundTrip(of: EnhancedBool.true, expectedJSON: "true".data(using: String._Encoding.utf8)!)
        _testRoundTrip(of: EnhancedBool.false, expectedJSON: "false".data(using: String._Encoding.utf8)!)
        _testRoundTrip(of: EnhancedBool.fileNotFound, expectedJSON: "null".data(using: String._Encoding.utf8)!)
    }
    
    @Test func testEncodingTopLevelArrayOfInt() {
        let a = [1,2,3]
        let result1 = String(data: try! JSONEncoder().encode(a), encoding: String._Encoding.utf8)
        #expect(result1 == "[1,2,3]")
        
        let b : [Int] = []
        let result2 = String(data: try! JSONEncoder().encode(b), encoding: String._Encoding.utf8)
        #expect(result2 == "[]")
    }
    
    @available(FoundationPreview 0.1, *)
    @Test func testEncodingTopLevelWithConfiguration() throws {
        // CodableTypeWithConfiguration is a struct that conforms to CodableWithConfiguration
        let value = CodableTypeWithConfiguration.testValue
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        var decoded = try decoder.decode(CodableTypeWithConfiguration.self, from: try encoder.encode(value, configuration: .init(1)), configuration: .init(1))
        #expect(decoded == value)
        decoded = try decoder.decode(CodableTypeWithConfiguration.self, from: try encoder.encode(value, configuration: CodableTypeWithConfiguration.ConfigProviding.self), configuration: CodableTypeWithConfiguration.ConfigProviding.self)
        #expect(decoded == value)
    }

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
        _testEncodeFailure(of: model)
    }
#endif

    // MARK: - Date Strategy Tests

    @Test func testEncodingDateSecondsSince1970() {
        // Cannot encode an arbitrary number of seconds since we've lost precision since 1970.
        let seconds = 1000.0
        let expectedJSON = "1000".data(using: String._Encoding.utf8)!

        _testRoundTrip(of: Date(timeIntervalSince1970: seconds),
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .secondsSince1970,
                       dateDecodingStrategy: .secondsSince1970)

        // Optional dates should encode the same way.
        _testRoundTrip(of: Optional(Date(timeIntervalSince1970: seconds)),
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .secondsSince1970,
                       dateDecodingStrategy: .secondsSince1970)
    }

    @Test func testEncodingDateMillisecondsSince1970() {
        // Cannot encode an arbitrary number of seconds since we've lost precision since 1970.
        let seconds = 1000.0
        let expectedJSON = "1000000".data(using: String._Encoding.utf8)!

        _testRoundTrip(of: Date(timeIntervalSince1970: seconds),
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .millisecondsSince1970,
                       dateDecodingStrategy: .millisecondsSince1970)

        // Optional dates should encode the same way.
        _testRoundTrip(of: Optional(Date(timeIntervalSince1970: seconds)),
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .millisecondsSince1970,
                       dateDecodingStrategy: .millisecondsSince1970)
    }

    @Test func testEncodingDateCustom() {
        let timestamp = Date()

        // We'll encode a number instead of a date.
        let encode = { @Sendable (_ data: Date, _ encoder: Encoder) throws -> Void in
            var container = encoder.singleValueContainer()
            try container.encode(42)
        }
        let decode = { @Sendable (_: Decoder) throws -> Date in return timestamp }

        let expectedJSON = "42".data(using: String._Encoding.utf8)!
        _testRoundTrip(of: timestamp,
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .custom(encode),
                       dateDecodingStrategy: .custom(decode))

        // Optional dates should encode the same way.
        _testRoundTrip(of: Optional(timestamp),
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .custom(encode),
                       dateDecodingStrategy: .custom(decode))
    }

    @Test func testEncodingDateCustomEmpty() {
        let timestamp = Date()

        // Encoding nothing should encode an empty keyed container ({}).
        let encode = { @Sendable (_: Date, _: Encoder) throws -> Void in }
        let decode = { @Sendable (_: Decoder) throws -> Date in return timestamp }

        let expectedJSON = "{}".data(using: String._Encoding.utf8)!
        _testRoundTrip(of: timestamp,
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .custom(encode),
                       dateDecodingStrategy: .custom(decode))

        // Optional dates should encode the same way.
        _testRoundTrip(of: Optional(timestamp),
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .custom(encode),
                       dateDecodingStrategy: .custom(decode))
    }

    // MARK: - Data Strategy Tests
    @Test func testEncodingData() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])

        let expectedJSON = "[222,173,190,239]".data(using: String._Encoding.utf8)!
        _testRoundTrip(of: data,
                       expectedJSON: expectedJSON,
                       dataEncodingStrategy: .deferredToData,
                       dataDecodingStrategy: .deferredToData)

        // Optional data should encode the same way.
        _testRoundTrip(of: Optional(data),
                       expectedJSON: expectedJSON,
                       dataEncodingStrategy: .deferredToData,
                       dataDecodingStrategy: .deferredToData)
    }

    @Test func testEncodingDataCustom() {
        // We'll encode a number instead of data.
        let encode = { @Sendable (_ data: Data, _ encoder: Encoder) throws -> Void in
            var container = encoder.singleValueContainer()
            try container.encode(42)
        }
        let decode = { @Sendable (_: Decoder) throws -> Data in return Data() }

        let expectedJSON = "42".data(using: String._Encoding.utf8)!
        _testRoundTrip(of: Data(),
                       expectedJSON: expectedJSON,
                       dataEncodingStrategy: .custom(encode),
                       dataDecodingStrategy: .custom(decode))

        // Optional data should encode the same way.
        _testRoundTrip(of: Optional(Data()),
                       expectedJSON: expectedJSON,
                       dataEncodingStrategy: .custom(encode),
                       dataDecodingStrategy: .custom(decode))
    }

    @Test func testEncodingDataCustomEmpty() {
        // Encoding nothing should encode an empty keyed container ({}).
        let encode = { @Sendable (_: Data, _: Encoder) throws -> Void in }
        let decode = { @Sendable (_: Decoder) throws -> Data in return Data() }

        let expectedJSON = "{}".data(using: String._Encoding.utf8)!
        _testRoundTrip(of: Data(),
                       expectedJSON: expectedJSON,
                       dataEncodingStrategy: .custom(encode),
                       dataDecodingStrategy: .custom(decode))

        // Optional Data should encode the same way.
        _testRoundTrip(of: Optional(Data()),
                       expectedJSON: expectedJSON,
                       dataEncodingStrategy: .custom(encode),
                       dataDecodingStrategy: .custom(decode))
    }

    // MARK: - Non-Conforming Floating Point Strategy Tests
    @Test func testEncodingNonConformingFloats() {
        _testEncodeFailure(of: Float.infinity)
        _testEncodeFailure(of: Float.infinity)
        _testEncodeFailure(of: -Float.infinity)
        _testEncodeFailure(of: Float.nan)

        _testEncodeFailure(of: Double.infinity)
        _testEncodeFailure(of: -Double.infinity)
        _testEncodeFailure(of: Double.nan)

        // Optional Floats/Doubles should encode the same way.
        _testEncodeFailure(of: Float.infinity)
        _testEncodeFailure(of: -Float.infinity)
        _testEncodeFailure(of: Float.nan)

        _testEncodeFailure(of: Double.infinity)
        _testEncodeFailure(of: -Double.infinity)
        _testEncodeFailure(of: Double.nan)
    }

    @Test func testEncodingNonConformingFloatStrings() {
        let encodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN")
        let decodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN")

        _testRoundTrip(of: Float.infinity,
                       expectedJSON: "\"INF\"".data(using: String._Encoding.utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
        _testRoundTrip(of: -Float.infinity,
                       expectedJSON: "\"-INF\"".data(using: String._Encoding.utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)

        // Since Float.nan != Float.nan, we have to use a placeholder that'll encode NaN but actually round-trip.
        _testRoundTrip(of: FloatNaNPlaceholder(),
                       expectedJSON: "\"NaN\"".data(using: String._Encoding.utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)

        _testRoundTrip(of: Double.infinity,
                       expectedJSON: "\"INF\"".data(using: String._Encoding.utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
        _testRoundTrip(of: -Double.infinity,
                       expectedJSON: "\"-INF\"".data(using: String._Encoding.utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)

        // Since Double.nan != Double.nan, we have to use a placeholder that'll encode NaN but actually round-trip.
        _testRoundTrip(of: DoubleNaNPlaceholder(),
                       expectedJSON: "\"NaN\"".data(using: String._Encoding.utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)

        // Optional Floats and Doubles should encode the same way.
        _testRoundTrip(of: Optional(Float.infinity),
                       expectedJSON: "\"INF\"".data(using: String._Encoding.utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
        _testRoundTrip(of: Optional(-Float.infinity),
                       expectedJSON: "\"-INF\"".data(using: String._Encoding.utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
        _testRoundTrip(of: Optional(Double.infinity),
                       expectedJSON: "\"INF\"".data(using: String._Encoding.utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
        _testRoundTrip(of: Optional(-Double.infinity),
                       expectedJSON: "\"-INF\"".data(using: String._Encoding.utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
    }

    // MARK: - Key Strategy Tests
    private struct EncodeMe : Encodable {
        var keyName: String
        func encode(to coder: Encoder) throws {
            var c = coder.container(keyedBy: _TestKey.self)
            try c.encode("test", forKey: _TestKey(stringValue: keyName)!)
        }
    }

    @Test func testEncodingKeyStrategyCustom() {
        let expected = "{\"QQQhello\":\"test\"}"
        let encoded = EncodeMe(keyName: "hello")

        let encoder = JSONEncoder()
        let customKeyConversion = { @Sendable (_ path : [CodingKey]) -> CodingKey in
            let key = _TestKey(stringValue: "QQQ" + path.last!.stringValue)!
            return key
        }
        encoder.keyEncodingStrategy = .custom(customKeyConversion)
        let resultData = try! encoder.encode(encoded)
        let resultString = String(bytes: resultData, encoding: String._Encoding.utf8)

        #expect(expected == resultString)
    }

    private struct EncodeFailure : Encodable {
        var someValue: Double
    }

    private struct EncodeFailureNested : Encodable {
        var nestedValue: EncodeFailure
    }

    private struct EncodeNested : Encodable {
        let nestedValue: EncodeMe
    }

    private struct EncodeNestedNested : Encodable {
        let outerValue: EncodeNested
    }

    @Test func testEncodingKeyStrategyPath() {
        // Make sure a more complex path shows up the way we want
        // Make sure the path reflects keys in the Swift, not the resulting ones in the JSON
        let expected = "{\"QQQouterValue\":{\"QQQnestedValue\":{\"QQQhelloWorld\":\"test\"}}}"
        let encoded = EncodeNestedNested(outerValue: EncodeNested(nestedValue: EncodeMe(keyName: "helloWorld")))

        let encoder = JSONEncoder()
        // We only will mutate this from one thread as we call the encoder synchronously
        nonisolated(unsafe) var callCount = 0

        let customKeyConversion = { @Sendable (_ path : [CodingKey]) -> CodingKey in
            // This should be called three times:
            // 1. to convert 'outerValue' to something
            // 2. to convert 'nestedValue' to something
            // 3. to convert 'helloWorld' to something
            callCount = callCount + 1

            if path.count == 0 {
                Issue.record("The path should always have at least one entry")
            } else if path.count == 1 {
                #expect(["outerValue"] == path.map { $0.stringValue })
            } else if path.count == 2 {
                #expect(["outerValue", "nestedValue"] == path.map { $0.stringValue })
            } else if path.count == 3 {
                #expect(["outerValue", "nestedValue", "helloWorld"] == path.map { $0.stringValue })
            } else {
                Issue.record("The path mysteriously had more entries")
            }

            let key = _TestKey(stringValue: "QQQ" + path.last!.stringValue)!
            return key
        }
        encoder.keyEncodingStrategy = .custom(customKeyConversion)
        let resultData = try! encoder.encode(encoded)
        let resultString = String(bytes: resultData, encoding: String._Encoding.utf8)

        #expect(expected == resultString)
        #expect(3 == callCount)
    }

    private struct DecodeMe : Decodable {
        let found: Bool
        init(from coder: Decoder) throws {
            let c = try coder.container(keyedBy: _TestKey.self)
            // Get the key that we expect to be passed in (camel case)
            let camelCaseKey = try c.decode(String.self, forKey: _TestKey(stringValue: "camelCaseKey")!)

            // Use the camel case key to decode from the JSON. The decoder should convert it to snake case to find it.
            found = try c.decode(Bool.self, forKey: _TestKey(stringValue: camelCaseKey)!)
        }
    }

    private struct DecodeMe2 : Decodable { var hello: String }

    @Test func testDecodingKeyStrategyCustom() {
        let input = "{\"----hello\":\"test\"}".data(using: String._Encoding.utf8)!
        let decoder = JSONDecoder()
        let customKeyConversion = { @Sendable (_ path: [CodingKey]) -> CodingKey in
            // This converter removes the first 4 characters from the start of all string keys, if it has more than 4 characters
            let string = path.last!.stringValue
            guard string.count > 4 else { return path.last! }
            let newString = String(string.dropFirst(4))
            return _TestKey(stringValue: newString)!
        }
        decoder.keyDecodingStrategy = .custom(customKeyConversion)
        let result = try! decoder.decode(DecodeMe2.self, from: input)

        #expect("test" == result.hello)
    }

    @Test func testDecodingDictionaryStringKeyConversionUntouched() {
        let input = "{\"leave_me_alone\":\"test\"}".data(using: String._Encoding.utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try! decoder.decode([String: String].self, from: input)

        #expect(["leave_me_alone": "test"] == result)
    }

    @Test func testDecodingDictionaryFailureKeyPath() {
        let input = "{\"leave_me_alone\":\"test\"}".data(using: String._Encoding.utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        #expect {
            _ = try decoder.decode([String: Int].self, from: input)
        } throws: {
            guard let decodingError = $0 as? DecodingError, case .typeMismatch(_, let context) = decodingError else {
                return false
            }
            return context.codingPath.map(\.stringValue) == ["leave_me_alone"]
        }
    }

    private struct DecodeFailure : Decodable {
        var intValue: Int
    }

    private struct DecodeFailureNested : Decodable {
        var nestedValue: DecodeFailure
    }

    private struct DecodeMe3 : Codable {
        var thisIsCamelCase : String
    }

    @Test func testKeyStrategyDuplicateKeys() {
        // This test is mostly to make sure we don't assert on duplicate keys
        struct DecodeMe5 : Codable {
            var oneTwo : String
            var numberOfKeys : Int

            enum CodingKeys : String, CodingKey {
                case oneTwo
                case oneTwoThree
            }

            init() {
                oneTwo = "test"
                numberOfKeys = 0
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                oneTwo = try container.decode(String.self, forKey: .oneTwo)
                numberOfKeys = container.allKeys.count
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(oneTwo, forKey: .oneTwo)
                try container.encode("test2", forKey: .oneTwoThree)
            }
        }

        let customKeyConversion = { @Sendable (_ path: [CodingKey]) -> CodingKey in
            // All keys are the same!
            return _TestKey(stringValue: "oneTwo")!
        }

        // Decoding
        // This input has a dictionary with two keys, but only one will end up in the container
        let input = "{\"unused key 1\":\"test1\",\"unused key 2\":\"test2\"}".data(using: String._Encoding.utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom(customKeyConversion)

        let decodingResult = try! decoder.decode(DecodeMe5.self, from: input)
        // There will be only one result for oneTwo.
        #expect(1 == decodingResult.numberOfKeys)
        // While the order in which these values should be taken is NOT defined by the JSON spec in any way, the historical behavior has been to select the *first* value for a given key.
        #expect(decodingResult.oneTwo == "test1")

        // Encoding
        let encoded = DecodeMe5()
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .custom(customKeyConversion)
        let decodingResultData = try! encoder.encode(encoded)
        let decodingResultString = String(bytes: decodingResultData, encoding: String._Encoding.utf8)

        // There will be only one value in the result (the second one encoded)
        #expect("{\"oneTwo\":\"test2\"}" == decodingResultString)
    }

    // MARK: - Encoder Features
    @Test func testNestedContainerCodingPaths() {
        let encoder = JSONEncoder()
        #expect(throws: Never.self, "Caught error during encoding nested container types") {
            let _ = try encoder.encode(NestedContainersTestType())
        }
    }

    @Test func testSuperEncoderCodingPaths() {
        let encoder = JSONEncoder()
        #expect(throws: Never.self, "Caught error during encoding nested container types") {
            let _ = try encoder.encode(NestedContainersTestType(testSuperEncoder: true))
        }
    }

    // MARK: - Type coercion
    @Test func testTypeCoercion() {
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int8].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int16].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int32].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int64].self)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int128].self)
        }
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt8].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt16].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt32].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt64].self)
         if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt128].self)
        }
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Float].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Double].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int8], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int16], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int32], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int64], as: [Bool].self)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
          _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int128], as: [Bool].self)
        }
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt8], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt16], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt32], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt64], as: [Bool].self)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
          _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt128], as: [Bool].self)
        }
        _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Float], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Double], as: [Bool].self)
    }

    @Test func testDecodingConcreteTypeParameter() throws {
        let encoder = JSONEncoder()
        let json = try encoder.encode(Employee.testValue)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Employee.self as Person.Type, from: json)

        #expect(type(of: decoded) == Employee.self, "Expected decoded value to be of type Employee")
    }

    // MARK: - Encoder State
    // SR-6078
    @Test func testEncoderStateThrowOnEncode() {
        struct ReferencingEncoderWrapper<T : Encodable> : Encodable {
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

        // The structure that would be encoded here looks like
        //
        //   [[[Float.infinity]]]
        //
        // The wrapper asks for an unkeyed container ([^]), gets a super encoder, and creates a nested container into that ([[^]]).
        // We then encode an array into that ([[[^]]]), which happens to be a value that causes us to throw an error.
        //
        // The issue at hand reproduces when you have a referencing encoder (superEncoder() creates one) that has a container on the stack (unkeyedContainer() adds one) that encodes a value going through box_() (Array does that) that encodes something which throws (Float.infinity does that).
        // When reproducing, this will cause a test failure via fatalError().
        _ = try? JSONEncoder().encode(ReferencingEncoderWrapper([Float.infinity]))
    }

    @Test func testEncoderStateThrowOnEncodeCustomDate() {
        // This test is identical to testEncoderStateThrowOnEncode, except throwing via a custom Date closure.
        struct ReferencingEncoderWrapper<T : Encodable> : Encodable {
            let value: T
            init(_ value: T) { self.value = value }
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                let superEncoder = container.superEncoder()
                var nestedContainer = superEncoder.unkeyedContainer()
                try nestedContainer.encode(value)
            }
        }

        // The closure needs to push a container before throwing an error to trigger.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom({ _, encoder in
            let _ = encoder.unkeyedContainer()
            enum CustomError : Error { case foo }
            throw CustomError.foo
        })

        _ = try? encoder.encode(ReferencingEncoderWrapper(Date()))
    }

    @Test func testEncoderStateThrowOnEncodeCustomData() {
        // This test is identical to testEncoderStateThrowOnEncode, except throwing via a custom Data closure.
        struct ReferencingEncoderWrapper<T : Encodable> : Encodable {
            let value: T
            init(_ value: T) { self.value = value }
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                let superEncoder = container.superEncoder()
                var nestedContainer = superEncoder.unkeyedContainer()
                try nestedContainer.encode(value)
            }
        }

        // The closure needs to push a container before throwing an error to trigger.
        let encoder = JSONEncoder()
        encoder.dataEncodingStrategy = .custom({ _, encoder in
            let _ = encoder.unkeyedContainer()
            enum CustomError : Error { case foo }
            throw CustomError.foo
        })

        _ = try? encoder.encode(ReferencingEncoderWrapper(Data()))
    }

    @Test func test_106506794() throws {
        struct Level1: Codable, Equatable {
            let level2: Level2

            enum CodingKeys: String, CodingKey {
                case level2
            }

            func encode(to encoder: Encoder) throws {
                var keyed = encoder.container(keyedBy: Self.CodingKeys.self)
                var nested = keyed.nestedUnkeyedContainer(forKey: .level2)
                try nested.encode(level2)
            }

            init(from decoder: Decoder) throws {
                let keyed = try decoder.container(keyedBy: Self.CodingKeys.self)
                var nested = try keyed.nestedUnkeyedContainer(forKey: .level2)
                self.level2 = try nested.decode(Level2.self)
            }

            struct Level2: Codable, Equatable {
                let name : String
            }

            init(level2: Level2) {
                self.level2 = level2
            }
        }

        let value = Level1.init(level2: .init(name: "level2"))
        let data = try JSONEncoder().encode(value)

        let decodedValue = try JSONDecoder().decode(Level1.self, from: data)
        #expect(value == decodedValue)
    }

    // MARK: - Decoder State
    // SR-6048
    @Test func testDecoderStateThrowOnDecode() {
        // The container stack here starts as [[1,2,3]]. Attempting to decode as [String] matches the outer layer (Array), and begins decoding the array.
        // Once Array decoding begins, 1 is pushed onto the container stack ([[1,2,3], 1]), and 1 is attempted to be decoded as String. This throws a .typeMismatch, but the container is not popped off the stack.
        // When attempting to decode [Int], the container stack is still ([[1,2,3], 1]), and 1 fails to decode as [Int].
        let json = "[1,2,3]".data(using: String._Encoding.utf8)!
        #expect(throws: Never.self) {
            let _ = try JSONDecoder().decode(EitherDecodable<[String], [Int]>.self, from: json)
        }
    }

    @Test func testDecoderStateThrowOnDecodeCustomDate() throws {
        // This test is identical to testDecoderStateThrowOnDecode, except we're going to fail because our closure throws an error, not because we hit a type mismatch.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom({ decoder in
            enum CustomError : Error { case foo }
            throw CustomError.foo
        })

        let json = try #require("1".data(using: String._Encoding.utf8))
        #expect(throws: Never.self) {
            let _ = try decoder.decode(EitherDecodable<Date, Int>.self, from: json)
        }
    }

    @Test func testDecoderStateThrowOnDecodeCustomData() throws {
        // This test is identical to testDecoderStateThrowOnDecode, except we're going to fail because our closure throws an error, not because we hit a type mismatch.
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .custom({ decoder in
            enum CustomError : Error { case foo }
            throw CustomError.foo
        })

        let json = try #require("1".data(using: String._Encoding.utf8))
        #expect(throws: Never.self) {
            let _ = try decoder.decode(EitherDecodable<Data, Int>.self, from: json)
        }
    }


    @Test func testDecodingFailure() {
        struct DecodeFailure : Decodable {
            var invalid: String
        }
        let toDecode = "{\"invalid\": json}";
        _testDecodeFailure(of: DecodeFailure.self, data: toDecode.data(using: String._Encoding.utf8)!)
    }

    @Test func testDecodingFailureThrowInInitKeyedContainer() {
        struct DecodeFailure : Decodable {
            private enum CodingKeys: String, CodingKey {
                case checkedString
            }

            private enum Error: Swift.Error {
                case expectedError
            }

            var checkedString: String
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let string = try container.decode(String.self, forKey: .checkedString)
                guard string == "foo" else {
                    throw Error.expectedError
                }
                self.checkedString = string // shouldn't happen
            }
        }

        let toDecode = "{ \"checkedString\" : \"baz\" }"
        _testDecodeFailure(of: DecodeFailure.self, data: toDecode.data(using: String._Encoding.utf8)!)
    }

    @Test func testDecodingFailureThrowInInitSingleContainer() {
        struct DecodeFailure : Decodable {
            private enum Error: Swift.Error {
                case expectedError
            }

            var checkedString: String
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                let string = try container.decode(String.self)
                guard string == "foo" else {
                    throw Error.expectedError
                }
                self.checkedString = string // shouldn't happen
            }
        }

        let toDecode = "{ \"checkedString\" : \"baz\" }"
        _testDecodeFailure(of: DecodeFailure.self, data: toDecode.data(using: String._Encoding.utf8)!)
    }

    @Test func testInvalidFragment() {
        struct DecodeFailure: Decodable {
            var foo: String
        }
        let toDecode = "\"foo"
        _testDecodeFailure(of: DecodeFailure.self, data: toDecode.data(using: String._Encoding.utf8)!)
    }

    @Test func testRepeatedFailedNilChecks() {
        struct RepeatNilCheckDecodable : Decodable {
            enum Failure : Error {
                case badNil
                case badValue(expected: Int, actual: Int)
            }

            init(from decoder: Decoder) throws {
                var unkeyedContainer = try decoder.unkeyedContainer()

                guard try unkeyedContainer.decodeNil() == false else {
                    throw Failure.badNil
                }
                guard try unkeyedContainer.decodeNil() == false else {
                     throw Failure.badNil
                }
                let value = try unkeyedContainer.decode(Int.self)
                guard value == 1 else {
                    throw Failure.badValue(expected: 1, actual: value)
                }

                guard try unkeyedContainer.decodeNil() == false else {
                    throw Failure.badNil
                }
                guard try unkeyedContainer.decodeNil() == false else {
                    throw Failure.badNil
                }
                let value2 = try unkeyedContainer.decode(Int.self)
                guard value2 == 2 else {
                    throw Failure.badValue(expected: 2, actual: value2)
                }

                guard try unkeyedContainer.decodeNil() == false else {
                    throw Failure.badNil
                }
                guard try unkeyedContainer.decodeNil() == false else {
                    throw Failure.badNil
                }
                let value3 = try unkeyedContainer.decode(Int.self)
                guard value3 == 3 else {
                    throw Failure.badValue(expected: 3, actual: value3)
                }
            }
        }
        let json = "[1, 2, 3]".data(using: String._Encoding.utf8)!
        #expect(throws: Never.self) {
            try JSONDecoder().decode(RepeatNilCheckDecodable.self, from: json)
        }
    }

    @Test func testDelayedDecoding() throws {

        // One variation is deferring the use of a container.
        struct DelayedDecodable_ContainerVersion : Codable {
            var _i : Int? = nil
            init(_ i: Int) {
                self._i = i
            }

            func encode(to encoder: Encoder) throws {
                var c = encoder.unkeyedContainer()
                try c.encode(_i!)
            }

            var cont : UnkeyedDecodingContainer? = nil
            init(from decoder: Decoder) throws {
                cont = try decoder.unkeyedContainer()
            }

            var i : Int {
                get throws {
                    if let i = _i {
                        return i
                    }
                    var contCopy = cont!
                    return try contCopy.decode(Int.self)
                }
            }
        }

        let before = DelayedDecodable_ContainerVersion(42)
        let data = try JSONEncoder().encode(before)

        let decoded = try JSONDecoder().decode(DelayedDecodable_ContainerVersion.self, from: data)
        #expect(throws: Never.self) {
            try decoded.i
        }

        // The other variant is deferring the use of the *top-level* decoder. This does NOT work for non-top level decoders.
        struct DelayedDecodable_DecoderVersion : Codable {
            var _i : Int? = nil
            init(_ i: Int) {
                self._i = i
            }

            func encode(to encoder: Encoder) throws {
                var c = encoder.unkeyedContainer()
                try c.encode(_i!)
            }

            var decoder : Decoder? = nil
            init(from decoder: Decoder) throws {
                self.decoder = decoder
            }

            var i : Int {
                get throws {
                    if let i = _i {
                        return i
                    }
                    var unkeyed = try decoder!.unkeyedContainer()
                    return try unkeyed.decode(Int.self)
                }
            }
        }
        // Reuse the same data.
        let decoded2 = try JSONDecoder().decode(DelayedDecodable_DecoderVersion.self, from: data)
        #expect(throws: Never.self) {
            try decoded2.i
        }
    }

    // MARK: - Helper Functions
    private var _jsonEmptyDictionary: Data {
        return "{}".data(using: String._Encoding.utf8)!
    }

    private func _testEncodeFailure<T : Encodable>(of value: T, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(throws: (any Error).self, "Encode of top-level \(T.self) was expected to fail.", sourceLocation: sourceLocation) {
            let _ = try JSONEncoder().encode(value)
        }
    }

    private func _testDecodeFailure<T: Decodable>(of value: T.Type, data: Data, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(throws: (any Error).self, "Decode of top-level \(value) was expected to fail.", sourceLocation: sourceLocation) {
            let _ = try JSONDecoder().decode(value, from: data)
        }
    }

    private func _testRoundTrip<T>(of value: T,
                                   expectedJSON json: Data? = nil,
                                   outputFormatting: JSONEncoder.OutputFormatting = [],
                                   dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
                                   dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
                                   dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64,
                                   dataDecodingStrategy: JSONDecoder.DataDecodingStrategy = .base64,
                                   keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
                                   keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
                                   nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .throw,
                                   nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
                                   sourceLocation: SourceLocation = #_sourceLocation
    ) where T : Codable, T : Equatable {
        var payload: Data? = nil
        #expect(throws: Never.self, "Failed to encode \(T.self) to JSON", sourceLocation: sourceLocation) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = outputFormatting
            encoder.dateEncodingStrategy = dateEncodingStrategy
            encoder.dataEncodingStrategy = dataEncodingStrategy
            encoder.nonConformingFloatEncodingStrategy = nonConformingFloatEncodingStrategy
            encoder.keyEncodingStrategy = keyEncodingStrategy
            payload = try encoder.encode(value)
        }
        
        guard let payload else { return }

        if let expectedJSON = json {
            let expected = String(data: expectedJSON, encoding: .utf8)!
            let actual = String(data: payload, encoding: .utf8)!
            #expect(expected == actual, "Produced JSON not identical to expected JSON.", sourceLocation: sourceLocation)
        }

        #expect(throws: Never.self, "Failed to decode \(T.self) from JSON", sourceLocation: sourceLocation) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = dateDecodingStrategy
            decoder.dataDecodingStrategy = dataDecodingStrategy
            decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
            decoder.keyDecodingStrategy = keyDecodingStrategy
            let decoded = try decoder.decode(T.self, from: payload)
            #expect(decoded == value, "\(T.self) did not round-trip to an equal value.")
        }
    }

    private func _testRoundTripTypeCoercionFailure<T,U>(of value: T, as type: U.Type, sourceLocation: SourceLocation = #_sourceLocation) where T : Codable, U : Codable {
        #expect(throws: (any Error).self, "Coercion from \(T.self) to \(U.self) was expected to fail.", sourceLocation: sourceLocation) {
            let data = try JSONEncoder().encode(value)
            let _ = try JSONDecoder().decode(U.self, from: data)
        }
    }

    private func _test<T : Equatable & Decodable>(JSONString: String, to object: T, sourceLocation: SourceLocation = #_sourceLocation) {
        let encs : [String._Encoding] = [.utf8, .utf16BigEndian, .utf16LittleEndian, .utf32BigEndian, .utf32LittleEndian]
        let decoder = JSONDecoder()
        for enc in encs {
            let data = JSONString.data(using: enc)!
            #expect(throws: Never.self, "Failed to decode \(JSONString) with encoding \(enc)", sourceLocation: sourceLocation) {
                let parsed = try decoder.decode(T.self, from: data)
                #expect(object == parsed, sourceLocation: sourceLocation)
            }
        }
    }

    @Test func test_JSONEscapedSlashes() {
        _test(JSONString: "\"\\/test\\/path\"", to: "/test/path")
        _test(JSONString: "\"\\\\/test\\\\/path\"", to: "\\/test\\/path")
    }

    @Test func test_JSONEscapedForwardSlashes() {
        _testRoundTrip(of: ["/":1], expectedJSON:
"""
{"\\/":1}
""".data(using: String._Encoding.utf8)!)
    }

    @Test func test_JSONUnicodeCharacters() {
        // UTF8:
        // E9 96 86 E5 B4 AC EB B0 BA EB 80 AB E9 A2 92
        // 閆崬밺뀫颒
        _test(JSONString: "[\"閆崬밺뀫颒\"]", to: ["閆崬밺뀫颒"])
        _test(JSONString: "[\"本日\"]", to: ["本日"])
    }

    @Test func test_JSONUnicodeEscapes() throws {
        let testCases = [
            // e-acute and greater-than-or-equal-to
            "\"\\u00e9\\u2265\"" : "é≥",

            // e-acute and greater-than-or-equal-to, surrounded by 42
            "\"42\\u00e942\\u226542\"" : "42é42≥42",

            // e-acute with upper-case hex
            "\"\\u00E9\"" : "é",

            // G-clef (UTF16 surrogate pair) 0x1D11E
            "\"\\uD834\\uDD1E\"" : "𝄞"
        ]
        for (input, expectedOutput) in testCases {
            _test(JSONString: input, to: expectedOutput)
        }
    }

    @Test func test_JSONBadUnicodeEscapes() throws {
        let badCases = ["\\uD834", "\\uD834hello", "hello\\uD834", "\\uD834\\u1221", "\\uD8", "\\uD834x\\uDD1E"]
        for str in badCases {
            let data = try #require(str.data(using: String._Encoding.utf8))
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(String.self, from: data)
            }
        }
    }
    
    @Test func test_nullByte() throws {
        let string = "abc\u{0000}def"
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode([string])
        let decoded = try decoder.decode([String].self, from: data)
        #expect([string] == decoded)
        
        let data2 = try encoder.encode([string:string])
        let decoded2 = try decoder.decode([String:String].self, from: data2)
        #expect([string:string] == decoded2)
        
        struct Container: Codable {
            let s: String
        }
        let data3 = try encoder.encode(Container(s: string))
        let decoded3 = try decoder.decode(Container.self, from: data3)
        #expect(decoded3.s == string)
    }

    @Test func test_superfluouslyEscapedCharacters() {
        let json = "[\"\\h\\e\\l\\l\\o\"]"
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode([String].self, from: json.data(using: String._Encoding.utf8)!)
        }
    }

    @Test func test_equivalentUTF8Sequences() throws {
        let json = try #require(
"""
{
  "caf\\u00e9" : true,
  "cafe\\u0301" : false
}
""".data(using: String._Encoding.utf8))

        let dict = try JSONDecoder().decode([String:Bool].self, from: json)
        #expect(dict.count == 1)
    }

    @Test func test_JSONControlCharacters() {
        let array = [
            "\\u0000", "\\u0001", "\\u0002", "\\u0003", "\\u0004",
            "\\u0005", "\\u0006", "\\u0007", "\\b",     "\\t",
            "\\n",     "\\u000b", "\\f",     "\\r",     "\\u000e",
            "\\u000f", "\\u0010", "\\u0011", "\\u0012", "\\u0013",
            "\\u0014", "\\u0015", "\\u0016", "\\u0017", "\\u0018",
            "\\u0019", "\\u001a", "\\u001b", "\\u001c", "\\u001d",
            "\\u001e", "\\u001f", " "
        ]
        for (ascii, json) in zip(0...0x20, array) {
            let quotedJSON = "\"\(json)\""
            let expectedResult = String(Character(UnicodeScalar(ascii)!))
            _test(JSONString: quotedJSON, to: expectedResult)
        }
    }

    #if os(Windows)
    @Test(.disabled("This test is temporarily disabled on Windows"))
    #else
    @Test
    #endif
    func test_JSONNumberFragments() {
        let array = ["0 ", "1.0 ", "0.1 ", "1e3 ", "-2.01e-3 ", "0", "1.0", "1e3", "-2.01e-3", "0e-10"]
        let expected = [0, 1.0, 0.1, 1000, -0.00201, 0, 1.0, 1000, -0.00201, 0]
        for (json, expected) in zip(array, expected) {
            _test(JSONString: json, to: expected)
        }
    }

    @Test func test_invalidJSONNumbersFailAsExpected() {
        let array = ["0.", "1e ", "-2.01e- ", "+", "2.01e-1234", "+2.0q", "2s", "NaN", "nan", "Infinity", "inf", "-", "0x42", "1.e2"]
        for json in array {
            let data = json.data(using: String._Encoding.utf8)!
            #expect(throws: (any Error).self, "Expected error for input \"\(json)\"") {
                try JSONDecoder().decode(Float.self, from: data)
            }
        }
    }

    func _checkExpectedThrownDataCorruptionUnderlyingError(contains substring: String, sourceLocation: SourceLocation = #_sourceLocation, closure: () throws -> Void) {
        #expect("Expected failure containing string: \"\(substring)\"", sourceLocation: sourceLocation) {
            try closure()
        } throws: { error in
            guard let decodingError = error as? DecodingError,
                  case let .dataCorrupted(context) = decodingError else {
                return false
            }
            #if FOUNDATION_FRAMEWORK
            return (context.underlyingError as? NSError).debugDescription.contains(substring)
            #else
            return true
            #endif
        }
    }

    @Test func test_topLevelFragmentsWithGarbage() {
        _checkExpectedThrownDataCorruptionUnderlyingError(contains: "Unexpected character") {
            let _ = try JSONDecoder().decode(Bool.self, from: "tru_".data(using: String._Encoding.utf8)!)
            let _ = try json5Decoder.decode(Bool.self, from: "tru_".data(using: String._Encoding.utf8)!)
        }
        _checkExpectedThrownDataCorruptionUnderlyingError(contains: "Unexpected character") {
            let _ = try JSONDecoder().decode(Bool.self, from: "fals_".data(using: String._Encoding.utf8)!)
            let _ = try json5Decoder.decode(Bool.self, from: "fals_".data(using: String._Encoding.utf8)!)
        }
        _checkExpectedThrownDataCorruptionUnderlyingError(contains: "Unexpected character") {
            let _ = try JSONDecoder().decode(Bool?.self, from: "nul_".data(using: String._Encoding.utf8)!)
            let _ = try json5Decoder.decode(Bool?.self, from: "nul_".data(using: String._Encoding.utf8)!)
        }
    }

    @Test func test_topLevelNumberFragmentsWithJunkDigitCharacters() throws {
        let fullData = "3.141596".data(using: String._Encoding.utf8)!
        let partialData = fullData[0..<4]

        #expect(try 3.14 == JSONDecoder().decode(Double.self, from: partialData))
    }

    @Test(.disabled("This test can reach the stack limit in some environments, so it is disabled in automated testing but can be enabled manually for local testing"))
    func test_depthTraversal() {
        struct SuperNestedArray : Decodable {
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                while container.count! > 0 {
                    container = try container.nestedUnkeyedContainer()
                }
            }
        }

        let MAX_DEPTH = 512
        let jsonGood = String(repeating: "[", count: MAX_DEPTH / 2) + String(repeating: "]", count: MAX_DEPTH / 2)
        let jsonBad = String(repeating: "[", count: MAX_DEPTH + 1) + String(repeating: "]", count: MAX_DEPTH + 1)

        #expect(throws: Never.self) {
            try JSONDecoder().decode(SuperNestedArray.self, from: jsonGood.data(using: String._Encoding.utf8)!)
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(SuperNestedArray.self, from: jsonBad.data(using: String._Encoding.utf8)!)
        }

    }

    @Test func test_JSONPermitsTrailingCommas() throws {
        // Trailing commas aren't valid JSON and should never be emitted, but are syntactically unambiguous and are allowed by
        // most parsers for ease of use.
        let json = "{\"key\" : [ true, ],}"
        let data = json.data(using: String._Encoding.utf8)!

        let result = try JSONDecoder().decode([String:[Bool]].self, from: data)
        let expected = ["key" : [true]]
        #expect(result == expected)
    }

    @Test func test_whitespaceOnlyData() {
        let data = " ".data(using: String._Encoding.utf8)!
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Int.self, from: data)
        }
    }

    @Test func test_smallFloatNumber() {
        _testRoundTrip(of: [["magic_number" : 7.45673334164903e-115]])
    }

    @Test func test_largeIntegerNumber() throws {
        let num : UInt64 = 6032314514195021674
        let json = "{\"a\":\(num)}"
        let data = json.data(using: String._Encoding.utf8)!

        let result = try JSONDecoder().decode([String:UInt64].self, from: data)
        #expect(result["a"] == num)
    }
    
    @Test func test_largeIntegerNumberIsNotRoundedToNearestDoubleWhenDecodingAsAnInteger() {
        #expect(Double(sign: .plus, exponent: 63, significand: 1).ulp == 2048)
        #expect(Double(sign: .plus, exponent: 64, significand: 1).ulp == 4096)
        
        let int64s: [(String, Int64?)] = [
            ("-9223372036854776833", nil),            // -2^63 - 1025 (Double: -2^63 - 2048)
            ("-9223372036854776832", nil),            // -2^63 - 1024 (Double: -2^63)
            ("-9223372036854775809", nil),            // -2^63 - 1    (Double: -2^63)
            ("-9223372036854775808", Int64.min),      // -2^63        (Double: -2^63)
            
            ( "9223372036854775807", Int64.max),      //  2^63 - 1    (Double:  2^63)
            ( "9223372036854775808", nil),            //  2^63        (Double:  2^63)
            ( "9223372036854776832", nil),            //  2^63 + 1024 (Double:  2^63)
            ( "9223372036854776833", nil),            //  2^63 + 1025 (Double:  2^63 + 2048)
        ]
        
        let uint64s: [(String, UInt64?)] = [
            ( "9223372036854775807", 1 << 63 - 0001), //  2^63 - 1    (Double:  2^63)
            ( "9223372036854775808", 1 << 63 + 0000), //  2^63        (Double:  2^63)
            ( "9223372036854776832", 1 << 63 + 1024), //  2^63 + 1024 (Double:  2^63)
            ( "9223372036854776833", 1 << 63 + 1025), //  2^63 + 1025 (Double:  2^63 + 2048)
            
            ("18446744073709551615", UInt64.max),     //  2^64 - 1    (Double:  2^64)
            ("18446744073709551616", nil),            //  2^64        (Double:  2^64)
            ("18446744073709553664", nil),            //  2^64 + 2048 (Double:  2^64)
            ("18446744073709553665", nil),            //  2^64 + 2049 (Double:  2^64 + 4096)
        ]
        
        for json5 in [true, false] {
            let decoder = JSONDecoder()
            decoder.allowsJSON5 = json5
            
            for (json, value) in int64s {
                let result = try? decoder.decode(Int64.self, from: json.data(using: String._Encoding.utf8)!)
                #expect(result == value, "Unexpected \(decoder) result for input \"\(json)\"")
            }
            
            for (json, value) in uint64s {
                let result = try? decoder.decode(UInt64.self, from: json.data(using: String._Encoding.utf8)!)
                #expect(result == value, "Unexpected \(decoder) result for input \"\(json)\"")
            }
        }
    }

    @Test func test_roundTrippingExtremeValues() {
        struct Numbers : Codable, Equatable {
            let floats : [Float]
            let doubles : [Double]
        }
        let testValue = Numbers(floats: [.greatestFiniteMagnitude, .leastNormalMagnitude], doubles: [.greatestFiniteMagnitude, .leastNormalMagnitude])
        _testRoundTrip(of: testValue)
    }
  
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    @Test func test_roundTrippingInt128() {
        let values = [
            Int128.min,
            Int128.min + 1,
            -0x1_0000_0000_0000_0000,
            0x0_8000_0000_0000_0000,
            -1,
            0,
            0x7fff_ffff_ffff_ffff,
            0x8000_0000_0000_0000,
            0xffff_ffff_ffff_ffff,
            0x1_0000_0000_0000_0000,
            .max
        ]
        for i128 in values {
            _testRoundTrip(of: i128)
        }
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    @Test func test_Int128SlowPath() throws {
        let decoder = JSONDecoder()
        let work: [Int128] = [18446744073709551615, -18446744073709551615]
        for value in work {
            // force the slow-path by appending ".0"
            let json = "\(value).0".data(using: String._Encoding.utf8)!
            #expect(try value == decoder.decode(Int128.self, from: json))
        }
        // These should work, but making them do so probably requires
        // rewriting the slow path to use a dedicated parser. For now,
        // we ensure that they throw instead of returning some bogus
        // result.
        let shouldWorkButDontYet: [Int128] = [
            .min, -18446744073709551616, 18446744073709551616, .max
        ]
        for value in shouldWorkButDontYet {
            // force the slow-path by appending ".0"
            let json = "\(value).0".data(using: String._Encoding.utf8)!
            #expect(throws: (any Error).self) {
                try decoder.decode(Int128.self, from: json)
            }
        }
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    @Test func test_roundTrippingUInt128() {
        let values = [
            UInt128.zero,
            1,
            0x0000_0000_0000_0000_7fff_ffff_ffff_ffff,
            0x0000_0000_0000_0000_8000_0000_0000_0000,
            0x0000_0000_0000_0000_ffff_ffff_ffff_ffff,
            0x0000_0000_0000_0001_0000_0000_0000_0000,
            0x7fff_ffff_ffff_ffff_ffff_ffff_ffff_ffff,
            0x8000_0000_0000_0000_0000_0000_0000_0000,
            .max
        ]
        for u128 in values {
            _testRoundTrip(of: u128)
        }
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    @Test func test_UInt128SlowPath() throws {
        let decoder = JSONDecoder()
        let work: [UInt128] = [18446744073709551615]
        for value in work {
            // force the slow-path by appending ".0"
            let json = "\(value).0".data(using: String._Encoding.utf8)!
            #expect(try value == decoder.decode(UInt128.self, from: json))
        }
        // These should work, but making them do so probably requires
        // rewriting the slow path to use a dedicated parser. For now,
        // we ensure that they throw instead of returning some bogus
        // result.
        let shouldWorkButDontYet: [UInt128] = [
            18446744073709551616, .max
        ]
        for value in shouldWorkButDontYet {
            // force the slow-path by appending ".0"
            let json = "\(value).0".data(using: String._Encoding.utf8)!
            #expect(throws: (any Error).self) {
                try decoder.decode(UInt128.self, from: json)
            }
        }
    }

    @Test func test_roundTrippingDoubleValues() {
        struct Numbers : Codable, Equatable {
            let doubles : [String:Double]
            let decimals : [String:Decimal]
        }
        let testValue = Numbers(
            doubles: [
                "-55.66" : -55.66,
                "-9.81" : -9.81,
                "-0.284" : -0.284,
                "-3.4028234663852886e+38" : Double(-Float.greatestFiniteMagnitude),
                "-1.1754943508222875e-38" : Double(-Float.leastNormalMagnitude),
                "-1.7976931348623157e+308" : -.greatestFiniteMagnitude,
                "-2.2250738585072014e-308" : -.leastNormalMagnitude,
                "0.000001" : 0.000001,
            ],
            decimals: [
                "1.234567891011121314" : Decimal(string: "1.234567891011121314")!,
                "-1.234567891011121314" : Decimal(string: "-1.234567891011121314")!,
                "0.1234567891011121314" : Decimal(string: "0.1234567891011121314")!,
                "-0.1234567891011121314" : Decimal(string: "-0.1234567891011121314")!,
                "123.4567891011121314e-100" : Decimal(string: "123.4567891011121314e-100")!,
                "-123.4567891011121314e-100" : Decimal(string: "-123.4567891011121314e-100")!,
                "11234567891011121314e-100" : Decimal(string: "1234567891011121314e-100")!,
                "-1234567891011121314e-100" : Decimal(string: "-1234567891011121314e-100")!,
                "0.1234567891011121314e-100" : Decimal(string: "0.1234567891011121314e-100")!,
                "-0.1234567891011121314e-100" : Decimal(string: "-0.1234567891011121314e-100")!,
                "3.14159265358979323846264338327950288419" : Decimal(string: "3.14159265358979323846264338327950288419")!,
                "2.71828182845904523536028747135266249775" : Decimal(string: "2.71828182845904523536028747135266249775")!,
                "440474310512876335.18692524723746578303827301433673643795" : Decimal(string: "440474310512876335.18692524723746578303827301433673643795")!
            ]
        )
        _testRoundTrip(of: testValue)
    }

    @Test func test_decodeLargeDoubleAsInteger() throws {
        let data = try JSONEncoder().encode(Double.greatestFiniteMagnitude)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(UInt64.self, from: data)
        }
    }

    @Test func test_localeDecimalPolicyIndependence() throws {
        var currentLocale: UnsafeMutablePointer<CChar>? = nil
        if let localePtr = setlocale(LC_ALL, nil) {
            currentLocale = strdup(localePtr)
        }

        defer {
            if let currentLocale {
                setlocale(LC_ALL, currentLocale)
                free(currentLocale)
            }
        }

        let orig = ["decimalValue" : 1.1]

        setlocale(LC_ALL, "fr_FR")
        let data = try JSONEncoder().encode(orig)

#if os(Windows)
        setlocale(LC_ALL, "en_US")
#else
        setlocale(LC_ALL, "en_US_POSIX")
#endif
        let decoded = try JSONDecoder().decode(type(of: orig).self, from: data)

        #expect(orig == decoded)
    }

    @Test func test_whitespace() throws {
        let tests : [(json: String, expected: [String:Bool])] = [
            ("{\"v\"\n : true}",   ["v":true]),
            ("{\"v\"\r\n : true}", ["v":true]),
            ("{\"v\"\r : true}",   ["v":true])
        ]
        for test in tests {
            let data = test.json.data(using: String._Encoding.utf8)!
            let decoded = try JSONDecoder().decode([String:Bool].self, from: data)
            #expect(test.expected == decoded)
        }
    }

    @Test func test_assumesTopLevelDictionary() throws {
        let decoder = JSONDecoder()
        decoder.assumesTopLevelDictionary = true

        let json = "\"x\" : 42"
        var result = try decoder.decode([String:Int].self, from: json.data(using: String._Encoding.utf8)!)
        #expect(result == ["x" : 42])

        let jsonWithBraces = "{\"x\" : 42}"
        result = try decoder.decode([String:Int].self, from: jsonWithBraces.data(using: String._Encoding.utf8)!)
        #expect(result == ["x" : 42])

        result = try decoder.decode([String:Int].self, from: Data())
        #expect(result == [:])

        let jsonWithEndBraceOnly = "\"x\" : 42}"
        #expect(throws: (any Error).self) {
            try decoder.decode([String:Int].self, from: jsonWithEndBraceOnly.data(using: String._Encoding.utf8)!)
        }

        let jsonWithStartBraceOnly = "{\"x\" : 42"
        #expect(throws: (any Error).self) {
            try decoder.decode([String:Int].self, from: jsonWithStartBraceOnly.data(using: String._Encoding.utf8)!)
        }
    }

    @Test func test_BOMPrefixes() throws {
        let json = "\"👍🏻\""
        let decoder = JSONDecoder()

        // UTF-8 BOM
        let utf8_BOM = Data([0xEF, 0xBB, 0xBF])
        #expect(try "👍🏻" == decoder.decode(String.self, from: utf8_BOM + json.data(using: String._Encoding.utf8)!))

        // UTF-16 BE
        let utf16_BE_BOM = Data([0xFE, 0xFF])
        #expect(try "👍🏻" == decoder.decode(String.self, from: utf16_BE_BOM + json.data(using: String._Encoding.utf16BigEndian)!))

        // UTF-16 LE
        let utf16_LE_BOM = Data([0xFF, 0xFE])
        #expect(try "👍🏻" == decoder.decode(String.self, from: utf16_LE_BOM + json.data(using: String._Encoding.utf16LittleEndian)!))

        // UTF-32 BE
        let utf32_BE_BOM = Data([0x0, 0x0, 0xFE, 0xFF])
        #expect(try "👍🏻" == decoder.decode(String.self, from: utf32_BE_BOM + json.data(using: String._Encoding.utf32BigEndian)!))

        // UTF-32 LE
        let utf32_LE_BOM = Data([0xFE, 0xFF, 0, 0])
        #expect(try "👍🏻" == decoder.decode(String.self, from: utf32_LE_BOM + json.data(using: String._Encoding.utf32LittleEndian)!))

        // Try some mismatched BOMs
        #expect(throws: (any Error).self) {
            try decoder.decode(String.self, from: utf32_LE_BOM + json.data(using: String._Encoding.utf32BigEndian)!)
        }
        
        #expect(throws: (any Error).self) {
            try decoder.decode(String.self, from: utf16_BE_BOM + json.data(using: String._Encoding.utf32LittleEndian)!)
        }
        
        #expect(throws: (any Error).self) {
            try decoder.decode(String.self, from: utf8_BOM + json.data(using: String._Encoding.utf16BigEndian)!)
        }
    }

    @Test func test_valueNotFoundError() {
        struct ValueNotFound : Decodable {
            let a: Bool
            let nope: String?

            enum CodingKeys: String, CodingKey {
                case a, nope
            }

            init(from decoder: Decoder) throws {
                let keyed = try decoder.container(keyedBy: CodingKeys.self)
                self.a = try keyed.decode(Bool.self, forKey: .a)

                do {
                    let sup = try keyed.superDecoder(forKey: .nope)
                    self.nope = try sup.singleValueContainer().decode(String.self)
                } catch DecodingError.valueNotFound {
                    // This is fine.
                    self.nope = nil
                }
            }
        }
        let json = "{\"a\":true}".data(using: String._Encoding.utf8)!

        // The expected valueNotFound error is swalled by the init(from:) implementation.
        #expect(throws: Never.self) {
            try JSONDecoder().decode(ValueNotFound.self, from: json)
        }
    }

    @Test(arguments: [JSONEncoder.DateEncodingStrategy.deferredToDate, .secondsSince1970, .millisecondsSince1970])
    func test_infiniteDate(strategy: JSONEncoder.DateEncodingStrategy) {
        let date = Date(timeIntervalSince1970: .infinity)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = strategy
        
        #expect(throws: (any Error).self) {
            try encoder.encode([date])
        }
    }

    @Test func test_typeEncodesNothing() throws {
        struct EncodesNothing : Encodable {
            func encode(to encoder: Encoder) throws {
                // Intentionally nothing.
            }
        }
        let enc = JSONEncoder()

        #expect(throws: (any Error).self) {
            try enc.encode(EncodesNothing())
        }

        // Unknown if the following behavior is strictly correct, but it's what the prior implementation does, so this test exists to make sure we maintain compatibility.

        let arrayData = try enc.encode([EncodesNothing()])
        #expect("[{}]" == String(data: arrayData, encoding: .utf8))

        let objectData = try enc.encode(["test" : EncodesNothing()])
        #expect("{\"test\":{}}" == String(data: objectData, encoding: .utf8))
    }

    @Test func test_superEncoders() throws {
        struct SuperEncoding : Encodable {
            enum CodingKeys: String, CodingKey {
                case firstSuper
                case secondSuper
                case unkeyed
            }
            func encode(to encoder: Encoder) throws {
                var keyed = encoder.container(keyedBy: CodingKeys.self)

                let keyedSuper1 = keyed.superEncoder(forKey: .firstSuper)
                let keyedSuper2 = keyed.superEncoder(forKey: .secondSuper)
                var keyedSVC1 = keyedSuper1.singleValueContainer()
                var keyedSVC2 = keyedSuper2.singleValueContainer()
                try keyedSVC1.encode("First")
                try keyedSVC2.encode("Second")

                var unkeyed = keyed.nestedUnkeyedContainer(forKey: .unkeyed)
                try unkeyed.encode(0)
                let unkeyedSuper1 = unkeyed.superEncoder()
                let unkeyedSuper2 = unkeyed.superEncoder()
                try unkeyed.encode(42)
                var unkeyedSVC1 = unkeyedSuper1.singleValueContainer()
                var unkeyedSVC2 = unkeyedSuper2.singleValueContainer()
                try unkeyedSVC1.encode("First")
                try unkeyedSVC2.encode("Second")

                // NOTE!!! At present, the order in which the values in the unkeyed container's superEncoders above get inserted into the resulting array depends on the order in which the superEncoders are deinit'd!! This can result in some very unexpected results, and this pattern is not recommended. This test exists just to verify compatibility.
            }
        }
        let data = try JSONEncoder().encode(SuperEncoding())
        let string = try #require(String(data: data, encoding: .utf8))

        #expect(string.contains("\"firstSuper\":\"First\""))
        #expect(string.contains("\"secondSuper\":\"Second\""))
        #expect(string.contains("[0,\"First\",\"Second\",42]"))
    }

    @Test func testRedundantKeys() throws {
        // Last encoded key wins.

        struct RedundantEncoding : Encodable {
            enum ReplacedType {
                case value
                case keyedContainer
                case unkeyedContainer
            }
            let replacedType: ReplacedType
            let useSuperEncoder: Bool

            enum CodingKeys: String, CodingKey {
                case key
            }
            func encode(to encoder: Encoder) throws {
                var keyed = encoder.container(keyedBy: CodingKeys.self)
                switch replacedType {
                case .value:
                    try keyed.encode(0, forKey: .key)
                case .keyedContainer:
                    let _ = keyed.nestedContainer(keyedBy: CodingKeys.self, forKey: .key)
                case .unkeyedContainer:
                    let _ = keyed.nestedUnkeyedContainer(forKey: .key)
                }
                if useSuperEncoder {
                    var svc = keyed.superEncoder(forKey: .key).singleValueContainer()
                    try svc.encode(42)
                } else {
                    try keyed.encode(42, forKey: .key)
                }
            }
        }
        var data = try JSONEncoder().encode(RedundantEncoding(replacedType: .value, useSuperEncoder: false))
        #expect(String(data: data, encoding: .utf8) == ("{\"key\":42}"))

        data = try JSONEncoder().encode(RedundantEncoding(replacedType: .value, useSuperEncoder: true))
        #expect(String(data: data,  encoding: .utf8) == ("{\"key\":42}"))

        data = try JSONEncoder().encode(RedundantEncoding(replacedType: .keyedContainer, useSuperEncoder: false))
        #expect(String(data: data,  encoding: .utf8) == ("{\"key\":42}"))

        data = try JSONEncoder().encode(RedundantEncoding(replacedType: .keyedContainer, useSuperEncoder: true))
        #expect(String(data: data,  encoding: .utf8) == ("{\"key\":42}"))

        data = try JSONEncoder().encode(RedundantEncoding(replacedType: .unkeyedContainer, useSuperEncoder: false))
        #expect(String(data: data,  encoding: .utf8) == ("{\"key\":42}"))

        data = try JSONEncoder().encode(RedundantEncoding(replacedType: .unkeyedContainer, useSuperEncoder: true))
        #expect(String(data: data,  encoding: .utf8) == ("{\"key\":42}"))
    }

    // None of these tests can be run in our automatic test suites right now, because they are expected to hit a preconditionFailure. They can only be verified manually.
    func disabled_testPreconditionFailuresForContainerReplacement() {
        struct RedundantEncoding : Encodable {
            enum Subcase {
                case replaceValueWithKeyedContainer
                case replaceValueWithUnkeyedContainer
                case replaceKeyedContainerWithUnkeyed
                case replaceUnkeyedContainerWithKeyed
            }
            let subcase : Subcase

            enum CodingKeys: String, CodingKey {
                case key
            }
            func encode(to encoder: Encoder) throws {
                switch subcase {
                case .replaceValueWithKeyedContainer:
                    var keyed = encoder.container(keyedBy: CodingKeys.self)
                    try keyed.encode(42, forKey: .key)
                    let _ = keyed.nestedContainer(keyedBy: CodingKeys.self, forKey: .key)
                case .replaceValueWithUnkeyedContainer:
                    var keyed = encoder.container(keyedBy: CodingKeys.self)
                    try keyed.encode(42, forKey: .key)
                    let _ = keyed.nestedUnkeyedContainer(forKey: .key)
                case .replaceKeyedContainerWithUnkeyed:
                    var keyed = encoder.container(keyedBy: CodingKeys.self)
                    let _ = keyed.nestedContainer(keyedBy: CodingKeys.self, forKey: .key)
                    let _ = keyed.nestedUnkeyedContainer(forKey: .key)
                case .replaceUnkeyedContainerWithKeyed:
                    var keyed = encoder.container(keyedBy: CodingKeys.self)
                    let _ = keyed.nestedUnkeyedContainer(forKey: .key)
                    let _ = keyed.nestedContainer(keyedBy: CodingKeys.self, forKey: .key)
                }
            }
        }
        #expect(throws: Never.self) {
            let _ = try JSONEncoder().encode(RedundantEncoding(subcase: .replaceValueWithKeyedContainer))
//          let _ = try JSONEncoder().encode(RedundantEncoding(subcase: .replaceValueWithUnkeyedContainer))
//          let _ = try JSONEncoder().encode(RedundantEncoding(subcase: .replaceKeyedContainerWithUnkeyed))
//          let _ = try JSONEncoder().encode(RedundantEncoding(subcase: .replaceUnkeyedContainerWithKeyed))
        }
    }

    var json5Decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        return decoder
    }

    @Test func test_json5Numbers() {
        let decoder = json5Decoder

        let successfulIntegers: [(String,Int)] = [
            ("1", 1),
            ("11", 11),
            ("99887766", 99887766),
            ("-1", -1),
            ("-10", -10),
            ("0", 0),
            ("+0", +0),
            ("-0", -0),
            ("+1", +1),
            ("+10", +10),
            ("0x1F", 0x1F),
            ("0x0000000E", 0xE),
            ("-0X1f", -0x1f),
            ("+0X1f", +0x1f),
            ("1.", 1),
            ("1.e2", 100),
            ("1e2", 100),
            ("1E2", 100),
            ("1e+2", 100),
            ("1E+2", 100),
            ("1e+02", 100),
            ("1E+02", 100),
        ]
        for (json, expected) in successfulIntegers {
            #expect(throws: Never.self, "Error when parsing input \"\(json)\"") {
                let val = try decoder.decode(Int.self, from: json.data(using: String._Encoding.utf8)!)
                #expect(val == expected, "Wrong value parsed from input \"\(json)\"")
            }
        }

        let successfulDoubles: [(String,Double)] = [
            ("1", 1),
            ("11", 11),
            ("99887766", 99887766),
            ("-1", -1),
            ("-10", -10),
            ("0", 0),
            ("+0", +0),
            ("-0", -0),
            ("+1", +1),
            ("+10", +10),
            ("Infinity", Double.infinity),
            ("-Infinity", -Double.infinity),
            ("+Infinity", Double.infinity),
            ("-NaN", -Double.nan),
            ("+NaN", Double.nan),
            ("NaN", Double.nan),
            (".1", 0.1),
            ("1.", 1.0),
            ("-.1", -0.1),
            ("+.1", +0.1),
            ("1e-2", 1e-2),
            ("1E-2", 1E-2),
            ("1e-02", 1e-02),
            ("1E-02", 1E-02),
            ("1e2", 1e2),
            ("1E2", 1E2),
            ("1e+2", 1e+2),
            ("1E+2", 1E+2),
            ("1e+02", 1e+02),
            ("1E+02", 1E+02),
            ("0x1F", Double(0x1F)),
            ("-0X1f", Double(-0x1f)),
            ("+0X1f", Double(+0x1f)),
        ]
        for (json, expected) in successfulDoubles {
            #expect(throws: Never.self, "Error when parsing input \"\(json)\"") {
                let val = try decoder.decode(Double.self, from: json.data(using: String._Encoding.utf8)!)
                if expected.isNaN {
                    #expect(val.isNaN, "Wrong value \(val) parsed from input \"\(json)\"")
                } else {
                    #expect(val == expected, "Wrong value parsed from input \"\(json)\"")
                }
            }
        }

        let unsuccessfulIntegers = [
            "-", // single -
            "+", // single +
            "-a", // - followed by non-digit
            "+a", // + followed by non-digit
            "-0x",
            "+0x",
            "-0x ",
            "+0x ",
            "-0xAFFFFFAFFFFFAFFFFFAFFFFFAFFFFFAFFFFFAFFFFFAFFFFF",
            "0xABC.DEF",
            "0xABCpD",
            "1e",
            "1E",
            "1e ",
            "1E ",
            "+1e ",
            "+1e",
            "-1e ",
            "-1E ",
        ]
        for json in unsuccessfulIntegers {
            #expect(throws: (any Error).self) {
                let _ = try decoder.decode(Int.self, from: json.data(using: String._Encoding.utf8)!)
            }
        }

        let unsuccessfulDoubles = [
            "-Inf",
            "-Inf       ",
            "+Inf",
            "+Inf       ",
            "+Na",
            "+Na    ",
            "-Na",
            "-Na    ",
            "-infinity",
            "-infinity       ",
            "+infinity",
            "+infinity       ",
            "+NAN",
            "+NA    ",
            "-NA",
            "-NA    ",
            "-NAN",
            "-NAN    ",
            "0x2.",
            "0x2.2",
            ".e1",
            "0xFFFFFFFFFFFFFFFFFFFFFF",
        ];
        for json in unsuccessfulDoubles {
            #expect(throws: (any Error).self) {
                let _ = try decoder.decode(Double.self, from: json.data(using: String._Encoding.utf8)!)
            }
        }
    }

    @Test func test_json5Null() {
        let validJSON = "null"
        let invalidJSON = [
            "Null",
            "nul",
            "nu",
            "n",
            "n    ",
            "nu   "
        ]

        #expect(throws: Never.self) {
            try json5Decoder.decode(NullReader.self, from: validJSON.data(using: String._Encoding.utf8)!)
        }

        for json in invalidJSON {
            #expect(throws: (any Error).self, "Expected failure while decoding input \"\(json)\"") {
                try json5Decoder.decode(NullReader.self, from: json.data(using: String._Encoding.utf8)!)
            }
        }
    }

    @Test func test_json5EsotericErrors() {
        // All of the following should fail
        let arrayStrings = [
            "[",
            "[ ",
            "[\n\n",
            "['hi',",
            "['hi', ",
            "['hi',\n"
        ]
        let objectStrings = [
            "{",
            "{ ",
            "{k ",
            "{k :",
            "{k : ",
            "{k : true",
            "{k : true ",
            "{k : true\n\n",
            "{k : true  ",
            "{k : true   ",
        ]
        let objectCharacterArrays: [[UInt8]] = [
            [.init(ascii: "{"), 0x80],  // Invalid UTF-8: Unexpected continuation byte
            [.init(ascii: "{"), 0xc0],  // Invalid UTF-8: Initial byte of 2-byte sequence without continuation
            [.init(ascii: "{"), 0xe0, 0x80],  // Invalid UTF-8: Initial byte of 3-byte sequence with only one continuation
            [.init(ascii: "{"), 0xf0, 0x80, 0x80],  // Invalid UTF-8: Initial byte of 3-byte sequence with only one continuation
        ]
        for json in arrayStrings {
            #expect(throws: (any Error).self, "Expected error for input \"\(json)\"") {
                try json5Decoder.decode([String].self, from: json.data(using: String._Encoding.utf8)!)
            }
        }
        for json in objectStrings {
            #expect(throws: (any Error).self, "Expected error for input \"\(json)\"") {
                try json5Decoder.decode([String:Bool].self, from: json.data(using: String._Encoding.utf8)!)
            }
        }
        for json in objectCharacterArrays {
            #expect(throws: (any Error).self, "Expected error for input \"\(json)\"") {
                try json5Decoder.decode([String:Bool].self, from: Data(json))
            }
        }
    }

    @Test func test_json5Strings() throws {
        let stringsToTrues = [
            "{v\n : true}",
            "{v \n : true}",
            "{ v \n : true,\nv\n:true,}",
            "{v\r : true}",
            "{v \r : true}",
            "{ v \r : true,\rv\r:true,}",
            "{v\r\n : true}",
            "{v \r\n : true}",
            "{ v \r\n : true,\r\nv\r\n:true,}",
            "{v// comment \n : true}",
            "{v // comment \n : true}",
            "{v/* comment*/ \n : true}",
            "{v/* comment */\n: true}",
            "{v/* comment */:/*comment*/\ntrue}",
            "{v// comment \r : true}",
            "{v // comment \r : true}",
            "{v/* comment*/ \r : true}",
            "{v/* comment */\r: true}",
            "{v/* comment */:/*comment*/\rtrue}",
            "{v// comment \r\n : true}",
            "{v // comment \r\n : true}",
            "{v/* comment*/ \r\n : true}",
            "{v/* comment */\r\n: true}",
            "{v/* comment */:/*comment*/\r\ntrue}",
            "// start with a comment\r\n{v:true}",
        ]

        let stringsToStrings = [
            "{v : \"hi\\x20there\"}" : "hi there",
            "{v : \"hi\\xthere\"}" : nil,
            "{v : \"hi\\x2there\"}" : nil,
            "{v : \"hi\\0there\"}" : nil,
            "{v : \"hi\\x00there\"}" : nil,
            "{v : \"hi\\u0000there\"}" : nil, // disallowed in JSON5 mode only
            "{v:\"hello\\uA\"}" : nil,
            "{v:\"hello\\uA   \"}" : nil
        ]

        for json in stringsToTrues {
            #expect(throws: Never.self, "Failed to parse \"\(json)\"") {
                try json5Decoder.decode([String:Bool].self, from: json.data(using: String._Encoding.utf8)!)
            }
        }
        for (json, expected) in stringsToStrings {
            do {
                let decoded = try json5Decoder.decode([String:String].self, from: json.data(using: String._Encoding.utf8)!)
                #expect(expected == decoded["v"])
            } catch {
                if let expected {
                    Issue.record("Expected \(expected) for input \"\(json)\", but failed with \(error)")
                }
            }
        }
    }

    @Test func test_json5AssumedDictionary() {
        let decoder = json5Decoder
        decoder.assumesTopLevelDictionary = true

        let stringsToString = [
            "hello: \"world\"" : [ "hello" : "world" ],
            "{hello: \"world\"}" : [ "hello" : "world" ], // Still has markers
            "hello: \"world\", goodbye: \"42\"" : [ "hello" : "world", "goodbye" : "42" ],  // more than one value
            "hello: \"world\"," : [ "hello" : "world" ], // Trailing comma
            "hello: \"world\"   " : [ "hello" : "world" ], // Trailing whitespace
            "hello: \"world\",  " : [ "hello" : "world" ], // Trailing whitespace and comma
            "hello: \"world\"  ,  " : [ "hello" : "world" ], // Trailing whitespace and comma
            "   hello   : \"world\"   " : [ "hello" : "world" ], // Before and after whitespace
            "{hello: \"world\"" : nil,    // Partial dictionary 1
            "hello: \"world\"}" : nil, // Partial dictionary 2
            "hello: \"world\" x " : nil, // Junk at end
            "hello: \"world\" x" : nil, // Junk at end
            "hello: \"world\"x" : nil, // Junk at end
            "" : [:], // empty but valid
            " " : [:], // empty but valid
            "{ }" : [:], // empty but valid
            "{}" : [:], // empty but valid
            "," : nil, // Invalid
            " , " : nil, // Invalid
            ", " : nil, // Invalid
            "   ," : nil, // Invalid
        ]
        for (json, expected) in stringsToString {
            do {
                let decoded = try decoder.decode([String:String].self, from: json.data(using: String._Encoding.utf8)!)
                #expect(expected == decoded)
            } catch {
                if let expected {
                    Issue.record("Expected \(expected) for input \"\(json)\", but failed with \(error)")
                }
            }
        }

        struct HelloGoodbye : Decodable, Equatable {
            let hello: String
            let goodbye: [String:String]
        }
        let helloGoodbyeExpectedValue = HelloGoodbye(
            hello: "world",
            goodbye: ["hi" : "there"])
        let stringsToNestedDictionary = [
            "hello: \"world\", goodbye: {\"hi\":\"there\"}", // more than one value, nested dictionary
            "hello: \"world\", goodbye: {\"hi\":\"there\"},", // more than one value, nested dictionary, trailing comma 1
            "hello: \"world\", goodbye: {\"hi\":\"there\",},", // more than one value, nested dictionary, trailing comma 2
        ]
        for json in stringsToNestedDictionary {
            do {
                let decoded = try decoder.decode(HelloGoodbye.self, from: json.data(using: String._Encoding.utf8)!)
                #expect(helloGoodbyeExpectedValue == decoded)
            } catch {
                Issue.record("Expected \(helloGoodbyeExpectedValue) for input \"\(json)\", but failed with \(error)")
            }
        }

        let arrayJSON = "[1,2,3]".data(using: String._Encoding.utf8)! // Assumed dictionary can't be an array
        #expect(throws: (any Error).self) {
            try decoder.decode([Int].self, from: arrayJSON)
        }

        let strFragmentJSON = "fragment".data(using: String._Encoding.utf8)! // Assumed dictionary can't be a fragment
        #expect(throws: (any Error).self) {
            try decoder.decode(String.self, from: strFragmentJSON)
        }

        let numFragmentJSON = "42".data(using: String._Encoding.utf8)! // Assumed dictionary can't be a fragment
        #expect(throws: (any Error).self) {
            try decoder.decode(Int.self, from: numFragmentJSON)
        }
    }

    enum JSON5SpecTestType {
        case json5
        case json5_foundationPermissiveJSON
        case json
        case js
        case malformed

        var fileExtension : String {
            switch self {
            case .json5: return "json5"
            case .json5_foundationPermissiveJSON: return "json5"
            case .json: return "json"
            case .js: return "js"
            case .malformed: return "txt"
            }
        }
    }
}

// MARK: - SnakeCase Tests
extension JSONEncoderTests {
    @Test func testDecodingKeyStrategyCamel() throws {
        let fromSnakeCaseTests = [
            ("", ""), // don't die on empty string
            ("a", "a"), // single character
            ("ALLCAPS", "ALLCAPS"), // If no underscores, we leave the word as-is
            ("ALL_CAPS", "allCaps"), // Conversion from screaming snake case
            ("single", "single"), // do not capitalize anything with no underscore
            ("snake_case", "snakeCase"), // capitalize a character
            ("one_two_three", "oneTwoThree"), // more than one word
            ("one_2_three", "one2Three"), // numerics
            ("one2_three", "one2Three"), // numerics, part 2
            ("snake_Ćase", "snakeĆase"), // do not further modify a capitalized diacritic
            ("snake_ćase", "snakeĆase"), // capitalize a diacritic
            ("alreadyCamelCase", "alreadyCamelCase"), // do not modify already camel case
            ("__this_and_that", "__thisAndThat"),
            ("_this_and_that", "_thisAndThat"),
            ("this__and__that", "thisAndThat"),
            ("this_and_that__", "thisAndThat__"),
            ("this_aNd_that", "thisAndThat"),
            ("_one_two_three", "_oneTwoThree"),
            ("one_two_three_", "oneTwoThree_"),
            ("__one_two_three", "__oneTwoThree"),
            ("one_two_three__", "oneTwoThree__"),
            ("_one_two_three_", "_oneTwoThree_"),
            ("__one_two_three", "__oneTwoThree"),
            ("__one_two_three__", "__oneTwoThree__"),
            ("_test", "_test"),
            ("_test_", "_test_"),
            ("__test", "__test"),
            ("test__", "test__"),
            ("_", "_"),
            ("__", "__"),
            ("___", "___"),
            ("m͉̟̹y̦̳G͍͚͎̳r̤͉̤͕ͅea̲͕t͇̥̼͖U͇̝̠R͙̻̥͓̣L̥̖͎͓̪̫ͅR̩͖̩eq͈͓u̞e̱s̙t̤̺ͅ", "m͉̟̹y̦̳G͍͚͎̳r̤͉̤͕ͅea̲͕t͇̥̼͖U͇̝̠R͙̻̥͓̣L̥̖͎͓̪̫ͅR̩͖̩eq͈͓u̞e̱s̙t̤̺ͅ"), // because Itai wanted to test this
            ("🐧_🐟", "🐧🐟") // fishy emoji example?
        ]

        for test in fromSnakeCaseTests {
            // This JSON contains the camel case key that the test object should decode with, then it uses the snake case key (test.0) as the actual key for the boolean value.
            let input = "{\"camelCaseKey\":\"\(test.1)\",\"\(test.0)\":true}".data(using: String._Encoding.utf8)!

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let result = try decoder.decode(DecodeMe.self, from: input)

            #expect(result.found)
        }
    }

    @Test func testEncodingDictionaryStringKeyConversionUntouched() throws {
        let expected = "{\"leaveMeAlone\":\"test\"}"
        let toEncode: [String: String] = ["leaveMeAlone": "test"]

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let resultData = try encoder.encode(toEncode)
        let resultString = String(bytes: resultData, encoding: String._Encoding.utf8)

        #expect(expected == resultString)
    }

    @Test func testKeyStrategySnakeGeneratedAndCustom() throws {
        // Test that this works with a struct that has automatically generated keys
        struct DecodeMe4 : Codable {
            var thisIsCamelCase : String
            var thisIsCamelCaseToo : String
            private enum CodingKeys : String, CodingKey {
                case thisIsCamelCase = "fooBar"
                case thisIsCamelCaseToo
            }
        }

        // Decoding
        let input = "{\"foo_bar\":\"test\",\"this_is_camel_case_too\":\"test2\"}".data(using: String._Encoding.utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decodingResult = try decoder.decode(DecodeMe4.self, from: input)

        #expect("test" == decodingResult.thisIsCamelCase)
        #expect("test2" == decodingResult.thisIsCamelCaseToo)

        // Encoding
        let encoded = DecodeMe4(thisIsCamelCase: "test", thisIsCamelCaseToo: "test2")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let encodingResultData = try encoder.encode(encoded)
        let encodingResultString = try #require(String(bytes: encodingResultData, encoding: String._Encoding.utf8))
        #expect(encodingResultString.contains("foo_bar"))
        #expect(encodingResultString.contains("this_is_camel_case_too"))
    }

    @Test func testDecodingDictionaryFailureKeyPathNested() {
        let input = "{\"top_level\": {\"sub_level\": {\"nested_value\": {\"int_value\": \"not_an_int\"}}}}".data(using: String._Encoding.utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        #expect {
            _ = try decoder.decode([String: [String : DecodeFailureNested]].self, from: input)
        } throws: {
            guard let decodingError = $0 as? DecodingError, case .typeMismatch(_, let context) = decodingError else {
                return false
            }
            return context.codingPath.map(\.stringValue) == ["top_level", "sub_level", "nestedValue", "intValue"]
        }
    }

    @Test func testDecodingKeyStrategyCamelGenerated() throws {
        let encoded = DecodeMe3(thisIsCamelCase: "test")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let resultData = try encoder.encode(encoded)
        let resultString = String(bytes: resultData, encoding: String._Encoding.utf8)
        #expect("{\"this_is_camel_case\":\"test\"}" == resultString)
    }

    @Test func testDecodingStringExpectedType() {
        let input = #"{"thisIsCamelCase": null}"#.data(using: String._Encoding.utf8)!
        #expect {
            _ = try JSONDecoder().decode(DecodeMe3.self, from: input)
        } throws: {
            guard let decodingError = $0 as? DecodingError, case .valueNotFound(let expected, _) = decodingError else {
                return false
            }
            return expected == String.self
        }
    }

    @Test func testEncodingKeyStrategySnakeGenerated() throws {
        // Test that this works with a struct that has automatically generated keys
        let input = "{\"this_is_camel_case\":\"test\"}".data(using: String._Encoding.utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decoder.decode(DecodeMe3.self, from: input)

        #expect("test" == result.thisIsCamelCase)
    }

    @Test func testEncodingDictionaryFailureKeyPath() {
        let toEncode: [String: EncodeFailure] = ["key": EncodeFailure(someValue: Double.nan)]
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        #expect {
            _ = try encoder.encode(toEncode)
        } throws: {
            guard let encodingError = $0 as? EncodingError, case .invalidValue(_, let context) = encodingError else {
                return false
            }
            return context.codingPath.map(\.stringValue) == ["key", "someValue"]
        }
    }

    @Test func testEncodingDictionaryFailureKeyPathNested() {
        let toEncode: [String: [String: EncodeFailureNested]] = ["key": ["sub_key": EncodeFailureNested(nestedValue: EncodeFailure(someValue: Double.nan))]]

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        #expect {
            _ = try encoder.encode(toEncode)
        } throws: {
            guard let decodingError = $0 as? EncodingError, case .invalidValue(_, let context) = decodingError else {
                return false
            }
            return context.codingPath.map(\.stringValue) == ["key", "sub_key", "nestedValue", "someValue"]
        }
    }

    @Test func testEncodingKeyStrategySnake() throws {
        let toSnakeCaseTests = [
            ("simpleOneTwo", "simple_one_two"),
            ("myURL", "my_url"),
            ("singleCharacterAtEndX", "single_character_at_end_x"),
            ("thisIsAnXMLProperty", "this_is_an_xml_property"),
            ("single", "single"), // no underscore
            ("", ""), // don't die on empty string
            ("a", "a"), // single character
            ("aA", "a_a"), // two characters
            ("version4Thing", "version4_thing"), // numerics
            ("partCAPS", "part_caps"), // only insert underscore before first all caps
            ("partCAPSLowerAGAIN", "part_caps_lower_again"), // switch back and forth caps.
            ("manyWordsInThisThing", "many_words_in_this_thing"), // simple lowercase + underscore + more
            ("asdfĆqer", "asdf_ćqer"),
            ("already_snake_case", "already_snake_case"),
            ("dataPoint22", "data_point22"),
            ("dataPoint22Word", "data_point22_word"),
            ("_oneTwoThree", "_one_two_three"),
            ("oneTwoThree_", "one_two_three_"),
            ("__oneTwoThree", "__one_two_three"),
            ("oneTwoThree__", "one_two_three__"),
            ("_oneTwoThree_", "_one_two_three_"),
            ("__oneTwoThree", "__one_two_three"),
            ("__oneTwoThree__", "__one_two_three__"),
            ("_test", "_test"),
            ("_test_", "_test_"),
            ("__test", "__test"),
            ("test__", "test__"),
            ("m͉̟̹y̦̳G͍͚͎̳r̤͉̤͕ͅea̲͕t͇̥̼͖U͇̝̠R͙̻̥͓̣L̥̖͎͓̪̫ͅR̩͖̩eq͈͓u̞e̱s̙t̤̺ͅ", "m͉̟̹y̦̳_g͍͚͎̳r̤͉̤͕ͅea̲͕t͇̥̼͖_u͇̝̠r͙̻̥͓̣l̥̖͎͓̪̫ͅ_r̩͖̩eq͈͓u̞e̱s̙t̤̺ͅ"), // because Itai wanted to test this
            ("🐧🐟", "🐧🐟") // fishy emoji example?
        ]

        for test in toSnakeCaseTests {
            let expected = "{\"\(test.1)\":\"test\"}"
            let encoded = EncodeMe(keyName: test.0)

            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let resultData = try encoder.encode(encoded)
            let resultString = String(bytes: resultData, encoding: String._Encoding.utf8)

            #expect(expected == resultString)
        }
    }
    
    @Test func test_twoByteUTF16Inputs() throws {
        let json = "7"
        let decoder = JSONDecoder()

        #expect(try 7 == decoder.decode(Int.self, from: json.data(using: .utf16BigEndian)!))
        #expect(try 7 == decoder.decode(Int.self, from: json.data(using: .utf16LittleEndian)!))
    }
    
    private func _run_passTest<T:Codable & Equatable>(name: String, json5: Bool = false, type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let jsonData = try testData(forResource: name, withExtension: json5 ? "json5" : "json" , subdirectory: json5 ? "JSON5/pass" : "JSON/pass")

        let plistData = try? testData(forResource: name, withExtension: "plist", subdirectory: "JSON/pass")
        let decoder = json5Decoder

        var decoded: T?
        #expect(throws: Never.self, "Pass test \"\(name)\" failed to decode", sourceLocation: sourceLocation) {
            decoded = try decoder.decode(T.self, from: jsonData)
        }
        guard let decoded else { return }

        let prettyPrintEncoder = JSONEncoder()
        prettyPrintEncoder.outputFormatting = .prettyPrinted

        for encoder in [JSONEncoder(), prettyPrintEncoder] {
            #expect(throws: Never.self, "Pass test \"\(name)\" failed to round trip", sourceLocation: sourceLocation) {
                let reencodedData = try encoder.encode(decoded)
                let redecodedObjects = try decoder.decode(T.self, from: reencodedData)
                #expect(decoded == redecodedObjects, sourceLocation: sourceLocation)
                
                if let plistData {
                    let decodedPlistObjects = try PropertyListDecoder().decode(T.self, from: plistData)
                    #expect(decoded == decodedPlistObjects, sourceLocation: sourceLocation)
                }
            }
        }
    }

    @Test func test_JSONPassTests() throws {
        try _run_passTest(name: "pass1-utf8", type: JSONPass.Test1.self)
        try _run_passTest(name: "pass1-utf16be", type: JSONPass.Test1.self)
        try _run_passTest(name: "pass1-utf16le", type: JSONPass.Test1.self)
        try _run_passTest(name: "pass1-utf32be", type: JSONPass.Test1.self)
        try _run_passTest(name: "pass1-utf32le", type: JSONPass.Test1.self)
        try _run_passTest(name: "pass2", type: JSONPass.Test2.self)
        try _run_passTest(name: "pass3", type: JSONPass.Test3.self)
        try _run_passTest(name: "pass4", type: JSONPass.Test4.self)
        try _run_passTest(name: "pass5", type: JSONPass.Test5.self)
        try _run_passTest(name: "pass6", type: JSONPass.Test6.self)
        try _run_passTest(name: "pass7", type: JSONPass.Test7.self)
        try _run_passTest(name: "pass8", type: JSONPass.Test8.self)
        try _run_passTest(name: "pass9", type: JSONPass.Test9.self)
        try _run_passTest(name: "pass10", type: JSONPass.Test10.self)
        try _run_passTest(name: "pass11", type: JSONPass.Test11.self)
        try _run_passTest(name: "pass12", type: JSONPass.Test12.self)
        try _run_passTest(name: "pass13", type: JSONPass.Test13.self)
        try _run_passTest(name: "pass14", type: JSONPass.Test14.self)
        try _run_passTest(name: "pass15", type: JSONPass.Test15.self)
    }
    
    @Test func test_json5PassJSONFiles() throws {
        try _run_passTest(name: "example", json5: true, type: JSON5Pass.Example.self)
        try _run_passTest(name: "hex", json5: true, type: JSON5Pass.Hex.self)
        try _run_passTest(name: "numbers", json5: true, type: JSON5Pass.Numbers.self)
        try _run_passTest(name: "strings", json5: true, type: JSON5Pass.Strings.self)
        try _run_passTest(name: "whitespace", json5: true, type: JSON5Pass.Whitespace.self)
    }

    private func _run_failTest<T:Decodable>(name: String, type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let jsonData = try testData(forResource: name, withExtension: "json", subdirectory: "JSON/fail")

        let decoder = JSONDecoder()
        decoder.assumesTopLevelDictionary = true
        #expect(throws: (any Error).self, "Decoding should have failed for invalid JSON data (test name: \(name))", sourceLocation: sourceLocation) {
            try decoder.decode(T.self, from: jsonData)
        }
    }

    @Test func test_JSONFailTests() throws {
        try _run_failTest(name: "fail1", type: JSONFail.Test1.self)
        try _run_failTest(name: "fail2", type: JSONFail.Test2.self)
        try _run_failTest(name: "fail3", type: JSONFail.Test3.self)
        try _run_failTest(name: "fail4", type: JSONFail.Test4.self)
        try _run_failTest(name: "fail5", type: JSONFail.Test5.self)
        try _run_failTest(name: "fail6", type: JSONFail.Test6.self)
        try _run_failTest(name: "fail7", type: JSONFail.Test7.self)
        try _run_failTest(name: "fail8", type: JSONFail.Test8.self)
        try _run_failTest(name: "fail9", type: JSONFail.Test9.self)
        try _run_failTest(name: "fail10", type: JSONFail.Test10.self)
        try _run_failTest(name: "fail11", type: JSONFail.Test11.self)
        try _run_failTest(name: "fail12", type: JSONFail.Test12.self)
        try _run_failTest(name: "fail13", type: JSONFail.Test13.self)
        try _run_failTest(name: "fail14", type: JSONFail.Test14.self)
        try _run_failTest(name: "fail15", type: JSONFail.Test15.self)
        try _run_failTest(name: "fail16", type: JSONFail.Test16.self)
        try _run_failTest(name: "fail17", type: JSONFail.Test17.self)
        try _run_failTest(name: "fail18", type: JSONFail.Test18.self)
        try _run_failTest(name: "fail19", type: JSONFail.Test19.self)
        try _run_failTest(name: "fail21", type: JSONFail.Test21.self)
        try _run_failTest(name: "fail22", type: JSONFail.Test22.self)
        try _run_failTest(name: "fail23", type: JSONFail.Test23.self)
        try _run_failTest(name: "fail24", type: JSONFail.Test24.self)
        try _run_failTest(name: "fail25", type: JSONFail.Test25.self)
        try _run_failTest(name: "fail26", type: JSONFail.Test26.self)
        try _run_failTest(name: "fail27", type: JSONFail.Test27.self)
        try _run_failTest(name: "fail28", type: JSONFail.Test28.self)
        try _run_failTest(name: "fail29", type: JSONFail.Test29.self)
        try _run_failTest(name: "fail30", type: JSONFail.Test30.self)
        try _run_failTest(name: "fail31", type: JSONFail.Test31.self)
        try _run_failTest(name: "fail32", type: JSONFail.Test32.self)
        try _run_failTest(name: "fail33", type: JSONFail.Test33.self)
        try _run_failTest(name: "fail34", type: JSONFail.Test34.self)
        try _run_failTest(name: "fail35", type: JSONFail.Test35.self)
        try _run_failTest(name: "fail36", type: JSONFail.Test36.self)
        try _run_failTest(name: "fail37", type: JSONFail.Test37.self)
        try _run_failTest(name: "fail38", type: JSONFail.Test38.self)
        try _run_failTest(name: "fail39", type: JSONFail.Test39.self)
        try _run_failTest(name: "fail40", type: JSONFail.Test40.self)
        try _run_failTest(name: "fail41", type: JSONFail.Test41.self)

    }

    func _run_json5SpecTest<T:Decodable>(_ category: String, _ name: String, testType: JSON5SpecTestType, type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let subdirectory = "/JSON5/spec/\(category)"
        let ext = testType.fileExtension
        let jsonData = try testData(forResource: name, withExtension: ext, subdirectory: subdirectory)

        let json5 = json5Decoder
        let json = JSONDecoder()

        switch testType {
        case .json, .json5_foundationPermissiveJSON:
            #expect(throws: Never.self, "Valid JSON should remain valid JSON5", sourceLocation: sourceLocation) {
                try json5.decode(type, from: jsonData)
            }

            // Repeat with non-JSON5-compliant decoder.
            
            #expect(throws: Never.self, "Repeating with non-JSON5-compliant decoder should not fail", sourceLocation: sourceLocation) {
                try json.decode(type, from: jsonData)
            }
        case .json5:
            #expect(throws: Never.self, "Valid JSON should remain valid JSON5", sourceLocation: sourceLocation) {
                try json5.decode(type, from: jsonData)
            }

            #expect(throws: (any Error).self, "Expected decode failure (original JSON) for test \(name).\(ext)", sourceLocation: sourceLocation) {
                _ = try json.decode(type, from: jsonData)
            }
        case .js:
            // Valid ES5 that's explicitly disallowed by JSON5 is also invalid JSON.
            #expect(throws: (any Error).self, "Expected decode failure (JSON5) for test \(name).\(ext)", sourceLocation: sourceLocation) {
                _ = try json5.decode(type, from: jsonData)
            }

            // Regular JSON decoder should also throw.
            #expect(throws: (any Error).self, "Expected decode failure (original JSON) for test \(name).\(ext)", sourceLocation: sourceLocation) {
                _ = try json.decode(type, from: jsonData)
            }
        case .malformed:
            // Invalid ES5 should remain invalid JSON5
            #expect(throws: (any Error).self, "Expected decode failure (JSON5) for test \(name).\(ext)", sourceLocation: sourceLocation) {
                _ = try json5.decode(type, from: jsonData)
            }

            // Regular JSON decoder should also throw.
            #expect(throws: (any Error).self, "Expected decode failure (original JSON) for test \(name).\(ext)", sourceLocation: sourceLocation) {
                _ = try json.decode(type, from: jsonData)
            }
        }
    }

    // Also tests non-JSON5 decoder against the non-JSON5 tests in this test suite.
    @Test func test_json5Spec() throws {
        // Expected successes:
        try _run_json5SpecTest("arrays", "empty-array", testType: .json, type: [Bool].self)
        try _run_json5SpecTest("arrays", "regular-array", testType: .json, type: [Bool?].self)
        try _run_json5SpecTest("arrays", "trailing-comma-array", testType: .json5_foundationPermissiveJSON, type: [NullReader].self)

        try _run_json5SpecTest("comments", "block-comment-following-array-element", testType: .json5, type: [Bool].self)
        try _run_json5SpecTest("comments", "block-comment-following-top-level-value", testType: .json5, type: NullReader.self)
        try _run_json5SpecTest("comments", "block-comment-in-string", testType: .json, type: String.self)
        try _run_json5SpecTest("comments", "block-comment-preceding-top-level-value", testType: .json5, type: NullReader.self)
        try _run_json5SpecTest("comments", "block-comment-with-asterisks", testType: .json5, type: Bool.self)
        try _run_json5SpecTest("comments", "inline-comment-following-array-element", testType: .json5, type: [Bool].self)
        try _run_json5SpecTest("comments", "inline-comment-following-top-level-value", testType: .json5, type: NullReader.self)
        try _run_json5SpecTest("comments", "inline-comment-in-string", testType: .json, type: String.self)
        try _run_json5SpecTest("comments", "inline-comment-preceding-top-level-value", testType: .json5, type: NullReader.self)

        try _run_json5SpecTest("misc", "npm-package", testType: .json, type: JSON5Spec.NPMPackage.self)
        try _run_json5SpecTest("misc", "npm-package", testType: .json5, type: JSON5Spec.NPMPackage.self)
        try _run_json5SpecTest("misc", "readme-example", testType: .json5, type: JSON5Spec.ReadmeExample.self)
        try _run_json5SpecTest("misc", "valid-whitespace", testType: .json5, type: [String:Bool].self)

        try _run_json5SpecTest("new-lines", "comment-cr", testType: .json5, type: [String:String].self)
        try _run_json5SpecTest("new-lines", "comment-crlf", testType: .json5, type: [String:String].self)
        try _run_json5SpecTest("new-lines", "comment-lf", testType: .json5, type: [String:String].self)
        try _run_json5SpecTest("new-lines", "escaped-cr", testType: .json5, type: [String:String].self)
        try _run_json5SpecTest("new-lines", "escaped-crlf", testType: .json5, type: [String:String].self)
        try _run_json5SpecTest("new-lines", "escaped-lf", testType: .json5, type: [String:String].self)

        try _run_json5SpecTest("numbers", "float-leading-decimal-point", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "float-leading-zero", testType: .json, type: Double.self)
        try _run_json5SpecTest("numbers", "float-trailing-decimal-point-with-integer-exponent", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "float-trailing-decimal-point", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "float-with-integer-exponent", testType: .json, type: Double.self)
        try _run_json5SpecTest("numbers", "float", testType: .json, type: Double.self)
        try _run_json5SpecTest("numbers", "hexadecimal-lowercase-letter", testType: .json5, type: UInt.self)
        try _run_json5SpecTest("numbers", "hexadecimal-uppercase-x", testType: .json5, type: UInt.self)
        try _run_json5SpecTest("numbers", "hexadecimal-with-integer-exponent", testType: .json5, type: UInt.self)
        try _run_json5SpecTest("numbers", "hexadecimal", testType: .json5, type: UInt.self)
        try _run_json5SpecTest("numbers", "infinity", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "integer-with-integer-exponent", testType: .json, type: Double.self)
        try _run_json5SpecTest("numbers", "integer-with-negative-integer-exponent", testType: .json, type: Double.self)
        try _run_json5SpecTest("numbers", "integer-with-negative-zero-integer-exponent", testType: .json, type: Int.self)
        try _run_json5SpecTest("numbers", "integer-with-positive-integer-exponent", testType: .json, type: Int.self)
        try _run_json5SpecTest("numbers", "integer-with-positive-zero-integer-exponent", testType: .json, type: Int.self)
        try _run_json5SpecTest("numbers", "integer-with-zero-integer-exponent", testType: .json, type: Int.self)
        try _run_json5SpecTest("numbers", "integer", testType: .json, type: Int.self)
        try _run_json5SpecTest("numbers", "nan", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "negative-float-leading-decimal-point", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "negative-float-leading-zero", testType: .json, type: Double.self)
        try _run_json5SpecTest("numbers", "negative-float-trailing-decimal-point", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "negative-float", testType: .json, type: Double.self)
        try _run_json5SpecTest("numbers", "negative-hexadecimal", testType: .json5, type: Int.self)
        try _run_json5SpecTest("numbers", "negative-infinity", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "negative-integer", testType: .json, type: Int.self)
        try _run_json5SpecTest("numbers", "negative-zero-float-leading-decimal-point", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "negative-zero-float-trailing-decimal-point", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "negative-zero-hexadecimal", testType: .json5, type: Int.self)
        try _run_json5SpecTest("numbers", "negative-zero-integer", testType: .json, type: Int.self)
        try _run_json5SpecTest("numbers", "positive-integer", testType: .json5, type: Int.self)
        try _run_json5SpecTest("numbers", "positive-zero-float-leading-decimal-point", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "positive-zero-float-trailing-decimal-point", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "positive-zero-float", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "positive-zero-hexadecimal", testType: .json5, type: Int.self)
        try _run_json5SpecTest("numbers", "positive-zero-integer", testType: .json5, type: Int.self)
        try _run_json5SpecTest("numbers", "zero-float-leading-decimal-point", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "zero-float-trailing-decimal-point", testType: .json5, type: Double.self)
        try _run_json5SpecTest("numbers", "zero-float", testType: .json, type: Double.self)
        try _run_json5SpecTest("numbers", "zero-hexadecimal", testType: .json5, type: Int.self)
        try _run_json5SpecTest("numbers", "zero-integer-with-integer-exponent", testType: .json, type: Int.self)
        try _run_json5SpecTest("numbers", "zero-integer", testType: .json, type: Int.self)

        try _run_json5SpecTest("objects", "duplicate-keys", testType: .json, type: [String:Bool].self)
        try _run_json5SpecTest("objects", "empty-object", testType: .json, type: [String:Bool].self)
        try _run_json5SpecTest("objects", "reserved-unquoted-key", testType: .json5, type: [String:Bool].self)
        try _run_json5SpecTest("objects", "single-quoted-key", testType: .json5, type: [String:String].self)
        try _run_json5SpecTest("objects", "trailing-comma-object", testType: .json5_foundationPermissiveJSON, type: [String:String].self)
        try _run_json5SpecTest("objects", "unquoted-keys", testType: .json5, type: [String:String].self)

        try _run_json5SpecTest("strings", "escaped-single-quoted-string", testType: .json5, type: String.self)
        try _run_json5SpecTest("strings", "multi-line-string", testType: .json5, type: String.self)
        try _run_json5SpecTest("strings", "single-quoted-string", testType: .json5, type: String.self)

        try _run_json5SpecTest("todo", "unicode-escaped-unquoted-key", testType: .json5, type: [String:String].self)
        try _run_json5SpecTest("todo", "unicode-unquoted-key", testType: .json5, type: [String:String].self)

        // Expected failures:
        try _run_json5SpecTest("arrays", "leading-comma-array", testType: .js, type: [Bool].self)
        try _run_json5SpecTest("arrays", "lone-trailing-comma-array", testType: .js, type: [Bool].self)
        try _run_json5SpecTest("arrays", "no-comma-array", testType: .malformed, type: [Bool].self)

        try _run_json5SpecTest("comments", "top-level-block-comment", testType: .malformed, type: Bool.self)
        try _run_json5SpecTest("comments", "top-level-inline-comment", testType: .malformed, type: Bool.self)
        try _run_json5SpecTest("comments", "unterminated-block-comment", testType: .malformed, type: Bool.self)

        try _run_json5SpecTest("misc", "empty", testType: .malformed, type: Bool.self)

        try _run_json5SpecTest("numbers", "hexadecimal-empty", testType: .malformed, type: UInt.self)
        try _run_json5SpecTest("numbers", "integer-with-float-exponent", testType: .malformed, type: Double.self)
        try _run_json5SpecTest("numbers", "integer-with-hexadecimal-exponent", testType: .malformed, type: Double.self)
        try _run_json5SpecTest("numbers", "integer-with-negative-float-exponent", testType: .malformed, type: Double.self)
        try _run_json5SpecTest("numbers", "integer-with-negative-hexadecimal-exponent", testType: .malformed, type: Double.self)
        try _run_json5SpecTest("numbers", "integer-with-positive-float-exponent", testType: .malformed, type: Double.self)
        try _run_json5SpecTest("numbers", "integer-with-positive-hexadecimal-exponent", testType: .malformed, type: Double.self)
        try _run_json5SpecTest("numbers", "lone-decimal-point", testType: .malformed, type: Double.self)
        try _run_json5SpecTest("numbers", "negative-noctal", testType: .js, type: Int.self)
        try _run_json5SpecTest("numbers", "negative-octal", testType: .malformed, type: Int.self)
        try _run_json5SpecTest("numbers", "noctal-with-leading-octal-digit", testType: .js, type: Int.self)
        try _run_json5SpecTest("numbers", "noctal", testType: .js, type: Int.self)
        try _run_json5SpecTest("numbers", "octal", testType: .malformed, type: Int.self)
        try _run_json5SpecTest("numbers", "positive-noctal", testType: .js, type: Int.self)
        try _run_json5SpecTest("numbers", "positive-octal", testType: .malformed, type: Int.self)
        try _run_json5SpecTest("numbers", "positive-zero-octal", testType: .malformed, type: Int.self)
        try _run_json5SpecTest("numbers", "zero-octal", testType: .malformed, type: Int.self)

        try _run_json5SpecTest("objects", "illegal-unquoted-key-number", testType: .malformed, type: [String:String].self)

        // The spec test disallows this case, but historically NSJSONSerialization has allowed it. Our new implementation is more up-to-spec.
        try _run_json5SpecTest("objects", "illegal-unquoted-key-symbol", testType: .malformed, type: [String:String].self)

        try _run_json5SpecTest("objects", "leading-comma-object", testType: .malformed, type: [String:String].self)
        try _run_json5SpecTest("objects", "lone-trailing-comma-object", testType: .malformed, type: [String:String].self)
        try _run_json5SpecTest("objects", "no-comma-object", testType: .malformed, type: [String:String].self)

        try _run_json5SpecTest("strings", "unescaped-multi-line-string", testType: .malformed, type: String.self)

    }

    @Test func testEncodingDateISO8601() {
        let timestamp = Date(timeIntervalSince1970: 1000)
        let expectedJSON = "\"\(timestamp.formatted(.iso8601))\"".data(using: String._Encoding.utf8)!
  
        _testRoundTrip(of: timestamp,
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .iso8601,
                       dateDecodingStrategy: .iso8601)


        // Optional dates should encode the same way.
        _testRoundTrip(of: Optional(timestamp),
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .iso8601,
                       dateDecodingStrategy: .iso8601)
    }
    
    @Test func testEncodingDataBase64() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])

        let expectedJSON = "\"3q2+7w==\"".data(using: String._Encoding.utf8)!
        _testRoundTrip(of: data, expectedJSON: expectedJSON)

        // Optional data should encode the same way.
        _testRoundTrip(of: Optional(data), expectedJSON: expectedJSON)
    }
}

// MARK: - Decimal Tests
extension JSONEncoderTests {
    @Test func testInterceptDecimal() {
        let expectedJSON = "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".data(using: String._Encoding.utf8)!

        // Want to make sure we write out a JSON number, not the keyed encoding here.
        // 1e127 is too big to fit natively in a Double, too, so want to make sure it's encoded as a Decimal.
        let decimal = Decimal(sign: .plus, exponent: 127, significand: Decimal(1))
        _testRoundTrip(of: decimal, expectedJSON: expectedJSON)

        // Optional Decimals should encode the same way.
        _testRoundTrip(of: Optional(decimal), expectedJSON: expectedJSON)
    }

    @Test func test_hugeNumbers() throws {
        let json = "23456789012000000000000000000000000000000000000000000000000000000000000000000 "
        let data = json.data(using: String._Encoding.utf8)!

        let decimal = try JSONDecoder().decode(Decimal.self, from: data)
        let expected = Decimal(string: json)
        #expect(decimal == expected)
    }

    @Test func testInterceptLargeDecimal() {
        struct TestBigDecimal: Codable, Equatable {
            var uint64Max: Decimal = Decimal(UInt64.max)
            var unit64MaxPlus1: Decimal = Decimal(
                _exponent: 0,
                _length: 5,
                _isNegative: 0,
                _isCompact: 1,
                _reserved: 0,
                _mantissa: (0, 0, 0, 0, 1, 0, 0, 0)
            )
            var int64Min: Decimal = Decimal(Int64.min)
            var int64MinMinus1: Decimal = Decimal(
                _exponent: 0,
                _length: 4,
                _isNegative: 1,
                _isCompact: 1,
                _reserved: 0,
                _mantissa: (1, 0, 0, 32768, 0, 0, 0, 0)
            )
        }

        let testBigDecimal = TestBigDecimal()
        _testRoundTrip(of: testBigDecimal)
    }

    @Test func testOverlargeDecimal() {
        // Check value too large fails to decode.
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Decimal.self, from: "100e200".data(using: .utf8)!)
        }
    }
}

// MARK: - Framework-only tests

#if FOUNDATION_FRAMEWORK
extension JSONEncoderTests {
    // This will remain a framework-only test due to dependence on `DateFormatter`.
    @Test func testEncodingDateFormatted() {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full

        let timestamp = Date(timeIntervalSince1970: 1000)
        let expectedJSON = "\"\(formatter.string(from: timestamp))\"".data(using: String._Encoding.utf8)!

        _testRoundTrip(of: timestamp,
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .formatted(formatter),
                       dateDecodingStrategy: .formatted(formatter))

        // Optional dates should encode the same way.
        _testRoundTrip(of: Optional(timestamp),
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .formatted(formatter),
                       dateDecodingStrategy: .formatted(formatter))
    }
}
#endif

// MARK: - .sortedKeys Tests
extension JSONEncoderTests {
    @Test func testEncodingTopLevelStructuredClass() {
        // Person is a class with multiple fields.
        let expectedJSON = "{\"email\":\"appleseed@apple.com\",\"name\":\"Johnny Appleseed\"}".data(using: String._Encoding.utf8)!
        let person = Person.testValue
        _testRoundTrip(of: person, expectedJSON: expectedJSON, outputFormatting: [.sortedKeys])
    }

    @Test func testEncodingOutputFormattingSortedKeys() {
        let expectedJSON = "{\"email\":\"appleseed@apple.com\",\"name\":\"Johnny Appleseed\"}".data(using: String._Encoding.utf8)!
        let person = Person.testValue
        _testRoundTrip(of: person, expectedJSON: expectedJSON, outputFormatting: [.sortedKeys])
    }

    @Test func testEncodingOutputFormattingPrettyPrintedSortedKeys() {
        let expectedJSON = "{\n  \"email\" : \"appleseed@apple.com\",\n  \"name\" : \"Johnny Appleseed\"\n}".data(using: String._Encoding.utf8)!
        let person = Person.testValue
        _testRoundTrip(of: person, expectedJSON: expectedJSON, outputFormatting: [.prettyPrinted, .sortedKeys])
    }

    @Test func testEncodingSortedKeys() {
        // When requesting sorted keys, dictionary keys are sorted prior to being written out.
        // This sort should be stable, numeric, and follow human-readable sorting rules as defined by the system locale.
        let dict = [
            // These three keys should appear in a stable, deterministic ordering relative to one another, regardless of their order in the dictionary.
            // For example, if the sort were naively case-insensitive, these three would be `NSOrderedSame`, and would not swap with one another in the sort, maintaining their relative ordering based on their position in the dictionary. The inclusion of other keys in the dictionary can alter their relative ordering (because of hashing), producing non-stable output.
            "Foo" : 1,
            "FOO" : 2,
            "foo" : 3,

            // These keys should output in numeric order (1, 2, 3, 11, 12) rather than literal string order (1, 11, 12, 2, 3).
            "foo1" : 4,
            "Foo2" : 5,
            "foo3" : 6,
            "foo12" : 7,
            "Foo11" : 8,

            // This key should be sorted in a human-readable way (e.g. among the other "foo" keys, not after them just because the binary value of 'ø' > 'o').
            "føo" : 9,
            "bar" : 10
        ]

        _testRoundTrip(of: dict, expectedJSON: #"{"FOO":2,"Foo":1,"Foo11":8,"Foo2":5,"bar":10,"foo":3,"foo1":4,"foo12":7,"foo3":6,"føo":9}"#.data(using: String._Encoding.utf8)!, outputFormatting: [.sortedKeys])
    }

    @Test func testEncodingSortedKeysStableOrdering() {
        // We want to make sure that keys of different length (but with identical prefixes) always sort in a stable way, regardless of their hash ordering.
        var dict = ["AAA" : 1, "AAAAAAB" : 2]
        var expectedJSONString = "{\"AAA\":1,\"AAAAAAB\":2}"
        _testRoundTrip(of: dict, expectedJSON: expectedJSONString.data(using: String._Encoding.utf8)!, outputFormatting: [.sortedKeys])

        // We don't want this test to rely on the hashing of Strings or how Dictionary uses that hash.
        // We'll insert a large number of keys into this dictionary and guarantee that the ordering of the above keys has indeed not changed.
        // To ensure that we don't accidentally test the same (passing) case every time these keys will be shuffled.
        let testSize = 256
        var Ns = Array(0 ..< testSize)

        // Simple Fisher-Yates shuffle.
        for i in Ns.indices.reversed() {
            let index = Int(Double.random(in: 0.0 ..< Double(i+1)))
            let N = Ns[i]
            Ns[i] = Ns[index]

            // Normally we'd set Ns[index] = N, but since all we need this value for is for inserting into the dictionary later, we can do it right here and not even write back to the source array.
            // No need to do an O(n) loop over Ns again.
            dict["key\(N)"] = N
        }

        let numberKeys = (0 ..< testSize).map { "\($0)" }.sorted()
        for key in numberKeys {
            let insertedKeyJSON = ",\"key\(key)\":\(key)"
            expectedJSONString.insert(contentsOf: insertedKeyJSON, at: expectedJSONString.index(before: expectedJSONString.endIndex))
        }

        _testRoundTrip(of: dict, expectedJSON: expectedJSONString.data(using: String._Encoding.utf8)!, outputFormatting: [.sortedKeys])
    }

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
        let expectedJSON = "{\"top\":{\"first\":\"Johnny Appleseed\",\"second\":\"appleseed@apple.com\"}}".data(using: String._Encoding.utf8)!
        _testRoundTrip(of: model, expectedJSON: expectedJSON, outputFormatting: [.sortedKeys])
    }

    @Test func test_redundantKeyedContainer() throws {
        struct EncodesTwice: Encodable {
            enum CodingKeys: String, CodingKey {
                case container
                case somethingElse
            }

            struct Nested: Encodable {
                let foo = "Test"
            }

            func encode(to encoder: Encoder) throws {
                var topLevel = encoder.container(keyedBy: CodingKeys.self)
                try topLevel.encode("Foo", forKey: .somethingElse)

                // Encode an object-like JSON value for the key "container"
                try topLevel.encode(Nested(), forKey: .container)

                // A nested container for the same "container" key should reuse the previous container, appending to it, instead of asserting. 106648746.
                var secondAgain = topLevel.nestedContainer(keyedBy: CodingKeys.self, forKey: .container)
                try secondAgain.encode("SecondAgain", forKey: .somethingElse)
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(EncodesTwice())
        let string = String(data: data, encoding: .utf8)!

        #expect(string == "{\"container\":{\"foo\":\"Test\",\"somethingElse\":\"SecondAgain\"},\"somethingElse\":\"Foo\"}")
    }

    @Test func test_singleValueDictionaryAmendedByContainer() throws {
        struct Test: Encodable {
            enum CodingKeys: String, CodingKey {
                case a
            }

            func encode(to encoder: Encoder) throws {
                var svc = encoder.singleValueContainer()
                try svc.encode(["a" : "b", "other" : "foo"])

                var keyed = encoder.container(keyedBy: CodingKeys.self)
                try keyed.encode("c", forKey: .a)
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(Test())
        let string = String(data: data, encoding: .utf8)!

        #expect(string == "{\"a\":\"c\",\"other\":\"foo\"}")
    }
}

// MARK: - URL Tests
extension JSONEncoderTests {
    @Test func testInterceptURL() {
        // Want to make sure JSONEncoder writes out single-value URLs, not the keyed encoding.
        let expectedJSON = "\"http:\\/\\/swift.org\"".data(using: String._Encoding.utf8)!
        let url = URL(string: "http://swift.org")!
        _testRoundTrip(of: url, expectedJSON: expectedJSON)

        // Optional URLs should encode the same way.
        _testRoundTrip(of: Optional(url), expectedJSON: expectedJSON)
    }

    @Test func testInterceptURLWithoutEscapingOption() {
        // Want to make sure JSONEncoder writes out single-value URLs, not the keyed encoding.
        let expectedJSON = "\"http://swift.org\"".data(using: String._Encoding.utf8)!
        let url = URL(string: "http://swift.org")!
        _testRoundTrip(of: url, expectedJSON: expectedJSON, outputFormatting: [.withoutEscapingSlashes])

        // Optional URLs should encode the same way.
        _testRoundTrip(of: Optional(url), expectedJSON: expectedJSON, outputFormatting: [.withoutEscapingSlashes])
    }
}

// MARK: - Helper Types

enum JSONPass { }

extension JSONPass {
    struct Test1: Codable, Equatable {
        let glossary: Glossary

        struct Glossary: Codable, Equatable {
            let title: String
            let glossDiv: GlossDiv

            enum CodingKeys: String, CodingKey {
                case title
                case glossDiv = "GlossDiv"
            }
        }

        struct GlossDiv: Codable, Equatable {
            let title: String
            let glossList: GlossList

            enum CodingKeys: String, CodingKey {
                case title
                case glossList = "GlossList"
            }
        }

        struct GlossList: Codable, Equatable {
            let glossEntry: GlossEntry

            enum CodingKeys: String, CodingKey {
                case glossEntry = "GlossEntry"
            }
        }

        struct GlossEntry: Codable, Equatable {
            let id, sortAs, glossTerm, acronym: String
            let abbrev: String
            let glossDef: GlossDef
            let glossSee: String

            enum CodingKeys: String, CodingKey {
                case id = "ID"
                case sortAs = "SortAs"
                case glossTerm = "GlossTerm"
                case acronym = "Acronym"
                case abbrev = "Abbrev"
                case glossDef = "GlossDef"
                case glossSee = "GlossSee"
            }
        }

        struct GlossDef: Codable, Equatable {
            let para: String
            let glossSeeAlso: [String]

            enum CodingKeys: String, CodingKey {
                case para
                case glossSeeAlso = "GlossSeeAlso"
            }
        }
    }
}

extension JSONPass {
    struct Test2: Codable, Equatable {
        let menu: Menu

        struct Menu: Codable, Equatable {
            let id, value: String
            let popup: Popup
        }

        struct Popup: Codable, Equatable {
            let menuitem: [Menuitem]
        }

        struct Menuitem: Codable, Equatable {
            let value, onclick: String
        }
    }
}

extension JSONPass {
    struct Test3: Codable, Equatable {
        let widget: Widget

        struct Widget: Codable, Equatable {
            let debug: String
            let window: Window
            let image: Image
            let text: Text
        }

        struct Image: Codable, Equatable {
            let src, name: String
            let hOffset, vOffset: Int
            let alignment: String
        }

        struct Text: Codable, Equatable {
            let data: String
            let size: Int
            let style, name: String
            let hOffset, vOffset: Int
            let alignment, onMouseUp: String
        }

        struct Window: Codable, Equatable {
            let title, name: String
            let width, height: Int
        }
    }
}

extension JSONPass {
    struct Test4: Codable, Equatable {
        let webApp: WebApp

        enum CodingKeys: String, CodingKey {
            case webApp = "web-app"
        }

        struct WebApp: Codable, Equatable {
            let servlet: [Servlet]
            let servletMapping: ServletMapping
            let taglib: Taglib

            enum CodingKeys: String, CodingKey {
                case servlet
                case servletMapping = "servlet-mapping"
                case taglib
            }
        }

        struct Servlet: Codable, Equatable {
            let servletName, servletClass: String
            let initParam: InitParam?

            enum CodingKeys: String, CodingKey {
                case servletName = "servlet-name"
                case servletClass = "servlet-class"
                case initParam = "init-param"
            }
        }

        struct InitParam: Codable, Equatable {
            let configGlossaryInstallationAt, configGlossaryAdminEmail, configGlossaryPoweredBy, configGlossaryPoweredByIcon: String?
            let configGlossaryStaticPath, templateProcessorClass, templateLoaderClass, templatePath: String?
            let templateOverridePath, defaultListTemplate, defaultFileTemplate: String?
            let useJSP: Bool?
            let jspListTemplate, jspFileTemplate: String?
            let cachePackageTagsTrack, cachePackageTagsStore, cachePackageTagsRefresh, cacheTemplatesTrack: Int?
            let cacheTemplatesStore, cacheTemplatesRefresh, cachePagesTrack, cachePagesStore: Int?
            let cachePagesRefresh, cachePagesDirtyRead: Int?
            let searchEngineListTemplate, searchEngineFileTemplate, searchEngineRobotsDB: String?
            let useDataStore: Bool?
            let dataStoreClass, redirectionClass, dataStoreName, dataStoreDriver: String?
            let dataStoreURL, dataStoreUser, dataStorePassword, dataStoreTestQuery: String?
            let dataStoreLogFile: String?
            let dataStoreInitConns, dataStoreMaxConns, dataStoreConnUsageLimit: Int?
            let dataStoreLogLevel: String?
            let maxURLLength: Int?
            let mailHost, mailHostOverride: String?
            let log: Int?
            let logLocation, logMaxSize: String?
            let dataLog: Int?
            let dataLogLocation, dataLogMaxSize, removePageCache, removeTemplateCache: String?
            let fileTransferFolder: String?
            let lookInContext, adminGroupID: Int?
            let betaServer: Bool?

            enum CodingKeys: String, CodingKey {
                case configGlossaryInstallationAt
                case configGlossaryAdminEmail
                case configGlossaryPoweredBy
                case configGlossaryPoweredByIcon
                case configGlossaryStaticPath
                case templateProcessorClass, templateLoaderClass, templatePath, templateOverridePath, defaultListTemplate, defaultFileTemplate, useJSP, jspListTemplate, jspFileTemplate, cachePackageTagsTrack, cachePackageTagsStore, cachePackageTagsRefresh, cacheTemplatesTrack, cacheTemplatesStore, cacheTemplatesRefresh, cachePagesTrack, cachePagesStore, cachePagesRefresh, cachePagesDirtyRead, searchEngineListTemplate, searchEngineFileTemplate
                case searchEngineRobotsDB
                case useDataStore, dataStoreClass, redirectionClass, dataStoreName, dataStoreDriver
                case dataStoreURL
                case dataStoreUser, dataStorePassword, dataStoreTestQuery, dataStoreLogFile, dataStoreInitConns, dataStoreMaxConns, dataStoreConnUsageLimit, dataStoreLogLevel
                case maxURLLength
                case mailHost, mailHostOverride, log, logLocation, logMaxSize, dataLog, dataLogLocation, dataLogMaxSize, removePageCache, removeTemplateCache, fileTransferFolder, lookInContext, adminGroupID, betaServer
            }
        }

        struct ServletMapping: Codable, Equatable {
            let cofaxCDS, cofaxEmail, cofaxAdmin, fileServlet: String
            let cofaxTools: String
        }

        struct Taglib: Codable, Equatable {
            let taglibURI, taglibLocation: String

            enum CodingKeys: String, CodingKey {
                case taglibURI = "taglib-uri"
                case taglibLocation = "taglib-location"
            }
        }
    }
}

extension JSONPass {
    struct Test5: Codable, Equatable {
        let image: Image

        enum CodingKeys: String, CodingKey {
            case image = "Image"
        }

        struct Image: Codable, Equatable {
            let width, height: Int
            let title: String
            let thumbnail: Thumbnail
            let ids: [Int]

            enum CodingKeys: String,  CodingKey {
                case width = "Width"
                case height = "Height"
                case title = "Title"
                case thumbnail = "Thumbnail"
                case ids = "IDs"
            }
        }

        struct Thumbnail: Codable, Equatable {
            let url: String
            let height: Int
            let width: String

            enum CodingKeys: String, CodingKey {
                case url = "Url"
                case height = "Height"
                case width = "Width"
            }
        }
    }
}

extension JSONPass {
    typealias Test6 = [Test6Element]

    struct Test6Element: Codable, Equatable {
        let precision: String
        let latitude, longitude: Double
        let address, city, state, zip: String
        let country: String

        enum CodingKeys: String, CodingKey {
            case precision
            case latitude = "Latitude"
            case longitude = "Longitude"
            case address = "Address"
            case city = "City"
            case state = "State"
            case zip = "Zip"
            case country = "Country"
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            guard lhs.precision == rhs.precision, lhs.address == rhs.address, lhs.city == rhs.city, lhs.zip == rhs.zip, lhs.country == rhs.country else {
                return false
            }
            guard fabs(lhs.longitude - rhs.longitude) <= 1e-10 else {
                return false
            }
            guard fabs(lhs.latitude - rhs.latitude) <= 1e-10 else {
                return false
            }
            return true
        }
    }
}

extension JSONPass {
    struct Test7: Codable, Equatable {
        let menu: Menu

        struct Menu: Codable, Equatable {
            let header: String
            let items: [Item]
        }

        struct Item: Codable, Equatable {
            let id: String
            let label: String?
        }
    }
}

extension JSONPass {
    typealias Test8 = [[[[[[[[[[[[[[[[[[[String]]]]]]]]]]]]]]]]]]]
}

extension JSONPass {
    struct Test9: Codable, Equatable {
        let objects : [AnyHashable]

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var decodedObjects = [AnyHashable]()

            decodedObjects.append(try container.decode(String.self))
            decodedObjects.append(try container.decode([String:[String]].self))
            decodedObjects.append(try container.decode([String:String].self))
            decodedObjects.append(try container.decode([String].self))
            decodedObjects.append(try container.decode(Int.self))
            decodedObjects.append(try container.decode(Bool.self))
            decodedObjects.append(try container.decode(Bool.self))
            if try container.decodeNil() {
                decodedObjects.append("<null>")
            }
            decodedObjects.append(try container.decode(SpecialCases.self))
            decodedObjects.append(try container.decode(Float.self))
            decodedObjects.append(try container.decode(Float.self))
            decodedObjects.append(try container.decode(Float.self))
            decodedObjects.append(try container.decode(Int.self))
            decodedObjects.append(try container.decode(Double.self))
            decodedObjects.append(try container.decode(Double.self))
            decodedObjects.append(try container.decode(Double.self))
            decodedObjects.append(try container.decode(Double.self))
            decodedObjects.append(try container.decode(Double.self))
            decodedObjects.append(try container.decode(Double.self))
            decodedObjects.append(try container.decode(String.self))

            self.objects = decodedObjects
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            try container.encode(objects[ 0] as! String)
            try container.encode(objects[ 1] as! [String:[String]])
            try container.encode(objects[ 2] as! [String:String])
            try container.encode(objects[ 3] as! [String])
            try container.encode(objects[ 4] as! Int)
            try container.encode(objects[ 5] as! Bool)
            try container.encode(objects[ 6] as! Bool)
            try container.encodeNil()
            try container.encode(objects[ 8] as! SpecialCases)
            try container.encode(objects[ 9] as! Float)
            try container.encode(objects[10] as! Float)
            try container.encode(objects[11] as! Float)
            try container.encode(objects[12] as! Int)
            try container.encode(objects[13] as! Double)
            try container.encode(objects[14] as! Double)
            try container.encode(objects[15] as! Double)
            try container.encode(objects[16] as! Double)
            try container.encode(objects[17] as! Double)
            try container.encode(objects[18] as! Double)
            try container.encode(objects[19] as! String)
        }

        struct SpecialCases : Codable, Hashable {
            let integer : UInt64
            let real : Double
            let e : Double
            let E : Double
            let empty_key : Double
            let zero : UInt8
            let one : UInt8
            let space : String
            let quote : String
            let backslash : String
            let controls : String
            let slash : String
            let alpha : String
            let ALPHA : String
            let digit : String
            let _0123456789 : String
            let special : String
            let hex: String
            let `true` : Bool
            let `false` : Bool
            let null : Bool?
            let array : [String]
            let object : [String:String]
            let address : String
            let url : URL
            let comment : String
            let special_sequences_key : String
            let spaced : [Int]
            let compact : [Int]
            let jsontext : String
            let quotes : String
            let escapedKey : String

            enum CodingKeys: String, CodingKey {
                case integer
                case real
                case e
                case E
                case empty_key = ""
                case zero
                case one
                case space
                case quote
                case backslash
                case controls
                case slash
                case alpha
                case ALPHA
                case digit
                case _0123456789 = "0123456789"
                case special
                case hex
                case `true`
                case `false`
                case null
                case array
                case object
                case address
                case url
                case comment
                case special_sequences_key = "# -- --> */"
                case spaced = " s p a c e d "
                case compact
                case jsontext
                case quotes
                case escapedKey = "/\\\"\u{CAFE}\u{BABE}\u{AB98}\u{FCDE}\u{bcda}\u{ef4A}\u{08}\u{0C}\n\r\t`1~!@#$%^&*()_+-=[]{}|;:',./<>?"
            }
        }
    }
}

extension JSONPass {
    typealias Test10 = [String:[String:String]]
    typealias Test11 = [String:String]
}

extension JSONPass {
    struct Test12: Codable, Equatable {
        let query: Query

        struct Query: Codable, Equatable {
            let pages: Pages
        }

        struct Pages: Codable, Equatable {
            let the80348: The80348

            enum CodingKeys: String, CodingKey {
                case the80348 = "80348"
            }
        }

        struct The80348: Codable, Equatable {
            let pageid, ns: Int
            let title: String
            let langlinks: [Langlink]
        }

        struct Langlink: Codable, Equatable {
            let lang, asterisk: String

            enum CodingKeys: String, CodingKey {
                case lang
                case asterisk = "*"
            }
        }
    }
}

extension JSONPass {
    typealias Test13 = [String:Int]
    typealias Test14 = [String:[String:[String:String]]]
}

extension JSONPass {
    struct Test15: Codable, Equatable {
        let attached: Bool
        let klass: String
        let errors: [String:[String]]
        let gid: Int
        let id: ID
        let mpid, name: String
        let properties: Properties
        let state: State
        let type: String
        let version: Int

        enum CodingKeys: String, CodingKey {
            case attached
            case klass = "class"
            case errors, gid, id, mpid, name, properties, state, type, version
        }

        struct ID: Codable, Equatable {
            let klass: String
            let inc: Int
            let machine: Int
            let new: Bool
            let time: UInt64
            let timeSecond: UInt64

            enum CodingKeys: String, CodingKey {
                case klass = "class"
                case inc, machine, new, time, timeSecond
            }
        }

        class Properties: Codable, Equatable {
            let mpid, type: String
            let dbo: DBO?
            let gid: Int
            let name: String?
            let state: State?
            let apiTimestamp: String?
            let gatewayTimestamp: String?
            let eventData: [String:Float]?

            static func == (lhs: Properties, rhs: Properties) -> Bool {
                return lhs.mpid == rhs.mpid && lhs.type == rhs.type && lhs.dbo == rhs.dbo && lhs.gid == rhs.gid && lhs.name == rhs.name && lhs.state == rhs.state && lhs.apiTimestamp == rhs.apiTimestamp && lhs.gatewayTimestamp == rhs.gatewayTimestamp && lhs.eventData == rhs.eventData
            }
        }

        struct DBO: Codable, Equatable {
            let id: ID
            let gid: Int
            let mpid: String
            let name: String
            let type: String
            let version: Int

            enum CodingKeys: String, CodingKey {
                case id = "_id"
                case gid, mpid, name, type, version
            }
        }

        struct State: Codable, Equatable {
            let apiTimestamp: String
            let attached: Bool
            let klass : String
            let errors: [String:[String]]
            let eventData: [String:Float]
            let gatewayTimestamp: String
            let gid: Int
            let id: ID
            let mpid: String
            let properties: Properties
            let type: String
            let version: Int?

            enum CodingKeys: String, CodingKey {
                case apiTimestamp, attached
                case klass = "class"
                case errors, eventData, gatewayTimestamp, gid, id, mpid, properties, type, version
            }
        }
    }
}

enum JSONFail {
    typealias Test1 = String
    typealias Test2 = [String]
    typealias Test3 = [String:String]
    typealias Test4 = [String]
    typealias Test5 = [String]
    typealias Test6 = [String]
    typealias Test7 = [String]
    typealias Test8 = [String]
    typealias Test9 = [String]
    typealias Test10 = [String:Bool]
    typealias Test11 = [String:Int]
    typealias Test12 = [String:String]
    typealias Test13 = [String:Int]
    typealias Test14 = [String:Int]
    typealias Test15 = [String]
    typealias Test16 = [String]
    typealias Test17 = [String]
    typealias Test18 = [String]
    typealias Test19 = [String:String?]
    typealias Test21 = [String:String?]
    typealias Test22 = [String]
    typealias Test23 = [String]
    typealias Test24 = [String]
    typealias Test25 = [String]
    typealias Test26 = [String]
    typealias Test27 = [String]
    typealias Test28 = [String]
    typealias Test29 = [Float]
    typealias Test30 = [Float]
    typealias Test31 = [Float]
    typealias Test32 = [String:Bool]
    typealias Test33 = [String]
    typealias Test34 = [String]
    typealias Test35 = [String:String]
    typealias Test36 = [String:Int]
    typealias Test37 = [String:Int]
    typealias Test38 = [String:Float]
    typealias Test39 = [String:String]
    typealias Test40 = [String:String]
    typealias Test41 = [String:String]
}

enum JSON5Pass { }

extension JSON5Pass {
    struct Example : Codable, Equatable {
        let unquoted: String
        let singleQuotes: String
        let lineBreaks: String
        let hexadecimal: UInt
        let leadingDecimalPoint: Double
        let andTrailing: Double
        let positiveSign: Int
        let trailingComma: String
        let andIn: [String]
        let backwardsCompatible: String
    }
}

extension JSON5Pass {
    struct Hex : Codable, Equatable {
        let `in`: [Int]
        let out: [Int]
    }
}

extension JSON5Pass {
    struct Numbers : Codable, Equatable {
        let a: Double
        let b: Double
        let c: Double
        let d: Int
    }
}

extension JSON5Pass {
    struct Strings : Codable, Equatable {
        let Hello: String
        let Hello2: String
        let Hello3: String
        let hex1: String
        let hex2: String
    }
}

extension JSON5Pass {
    struct Whitespace : Codable, Equatable {
        let Hello: String
    }
}

enum JSON5Spec { }

extension JSON5Spec {
    struct NPMPackage: Codable {
        let name: String
        let publishConfig: PublishConfig
        let `description`: String
        let keywords: [String]
        let version: String
        let preferGlobal: Bool
        let config: Config
        let homepage: String
        let author: String
        let repository: Repository
        let bugs: Bugs
        let directories: [String:String]
        let main, bin: String
        let dependencies: [String:String]
        let bundleDependencies: [String]
        let devDependencies: [String:String]
        let engines: [String:String]
        let scripts: [String:String]
        let licenses: [License]

        struct PublishConfig: Codable {
            let proprietaryAttribs: Bool

            enum CodingKeys: String, CodingKey {
                case proprietaryAttribs = "proprietary-attribs"
            }
        }

        struct Config: Codable {
            let publishtest: Bool
        }

        struct Repository: Codable {
            let type: String
            let url: String
        }

        struct Bugs: Codable {
            let email: String
            let url: String
        }

        struct License: Codable {
            let type: String
            let url: String
        }
    }
}

extension JSON5Spec {
    struct ReadmeExample: Codable {
        let foo: String
        let `while`: Bool
        let this: String
        let here: String
        let hex: UInt
        let half: Double
        let delta: Int
        let to: Double
        let finally: String
        let oh: [String]
    }
}
