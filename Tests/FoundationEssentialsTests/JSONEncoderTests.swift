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

#if canImport(Darwin)
import Darwin
#elseif canImport(Bionic)
@preconcurrency import Bionic
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(CRT)
import CRT
#elseif os(WASI)
@preconcurrency import WASILibc
#endif

#if canImport(FoundationEssentials)
@_spi(SwiftCorelibsFoundation)
import FoundationEssentials
#endif

#if FOUNDATION_FRAMEWORK
import Foundation
#endif

// MARK: - Test Suite

@Suite("JSONEncoder")
private struct JSONEncoderTests {
    // MARK: - Encoding Top-Level Empty Types
    @Test func encodingTopLevelEmptyStruct() {
        let empty = EmptyStruct()
        _testRoundTrip(of: empty, expectedJSON: _jsonEmptyDictionary)
    }

    @Test func encodingTopLevelEmptyClass() {
        let empty = EmptyClass()
        _testRoundTrip(of: empty, expectedJSON: _jsonEmptyDictionary)
    }

    // MARK: - Encoding Top-Level Single-Value Types
    @Test func encodingTopLevelSingleValueEnum() {
        _testRoundTrip(of: Switch.off)
        _testRoundTrip(of: Switch.on)
    }

    @Test func encodingTopLevelSingleValueStruct() {
        _testRoundTrip(of: Timestamp(3141592653))
    }

    @Test func encodingTopLevelSingleValueClass() {
        _testRoundTrip(of: Counter())
    }

    // MARK: - Encoding Top-Level Structured Types
    @Test func encodingTopLevelStructuredStruct() {
        // Address is a struct type with multiple fields.
        let address = Address.testValue
        _testRoundTrip(of: address)
    }

    @Test func encodingTopLevelStructuredSingleStruct() {
        // Numbers is a struct which encodes as an array through a single value container.
        let numbers = Numbers.testValue
        _testRoundTrip(of: numbers)
    }

    @Test func encodingTopLevelStructuredSingleClass() {
        // Mapping is a class which encodes as a dictionary through a single value container.
        let mapping = Mapping.testValue
        _testRoundTrip(of: mapping)
    }

    @Test func encodingTopLevelDeepStructuredType() {
        // Company is a type with fields which are Codable themselves.
        let company = Company.testValue
        _testRoundTrip(of: company)
    }

    @Test func encodingClassWhichSharesEncoderWithSuper() {
        // Employee is a type which shares its encoder & decoder with its superclass, Person.
        let employee = Employee.testValue
        _testRoundTrip(of: employee)
    }

    @Test func encodingTopLevelNullableType() {
        // EnhancedBool is a type which encodes either as a Bool or as nil.
        _testRoundTrip(of: EnhancedBool.true, expectedJSON: "true".data(using: .utf8)!)
        _testRoundTrip(of: EnhancedBool.false, expectedJSON: "false".data(using: .utf8)!)
        _testRoundTrip(of: EnhancedBool.fileNotFound, expectedJSON: "null".data(using: .utf8)!)
    }
    
    @Test func encodingTopLevelArrayOfInt() throws {
        let a = [1,2,3]
        let result1 = String(data: try JSONEncoder().encode(a), encoding: .utf8)
        #expect(result1 == "[1,2,3]")
        
        let b : [Int] = []
        let result2 = String(data: try JSONEncoder().encode(b), encoding: .utf8)
        #expect(result2 == "[]")
    }
    
    @Test func encodingTopLevelWithConfiguration() throws {
        // CodableTypeWithConfiguration is a struct that conforms to CodableWithConfiguration
        let value = CodableTypeWithConfiguration.testValue
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        var decoded = try decoder.decode(CodableTypeWithConfiguration.self, from: try encoder.encode(value, configuration: .init(1)), configuration: .init(1))
        #expect(decoded == value)
        decoded = try decoder.decode(CodableTypeWithConfiguration.self, from: try encoder.encode(value, configuration: CodableTypeWithConfiguration.ConfigProviding.self), configuration: CodableTypeWithConfiguration.ConfigProviding.self)
        #expect(decoded == value)
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
            _ = try JSONEncoder().encode(model)
        }
    }
    #endif

    // MARK: - Date Strategy Tests

    @Test func encodingDateSecondsSince1970() {
        // Cannot encode an arbitrary number of seconds since we've lost precision since 1970.
        let seconds = 1000.0
        let expectedJSON = "1000".data(using: .utf8)!

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

    @Test func encodingDateMillisecondsSince1970() {
        // Cannot encode an arbitrary number of seconds since we've lost precision since 1970.
        let seconds = 1000.0
        let expectedJSON = "1000000".data(using: .utf8)!

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

    fileprivate struct TopLevelArrayWrapper<T> : Codable, Equatable where T : Codable, T : Equatable {
        let value: T

        init(_ value: T) {
            self.value = value
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(value)
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            value = try container.decode(T.self)
            assert(container.isAtEnd)
        }

        static func ==(_ lhs: TopLevelArrayWrapper<T>, _ rhs: TopLevelArrayWrapper<T>) -> Bool {
            return lhs.value == rhs.value
        }
    }

    @Test func encodingDateCustom() {
        let timestamp = Date()

        // We'll encode a number instead of a date.
        let encode = { @Sendable (_ data: Date, _ encoder: Encoder) throws -> Void in
            var container = encoder.singleValueContainer()
            try container.encode(42)
        }
        let decode = { @Sendable (_: Decoder) throws -> Date in return timestamp }

        let expectedJSON = "42".data(using: .utf8)!
        _testRoundTrip(of: timestamp,
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .custom(encode),
                       dateDecodingStrategy: .custom(decode))

        // Optional dates should encode the same way.
        _testRoundTrip(of: Optional(timestamp),
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .custom(encode),
                       dateDecodingStrategy: .custom(decode))

        // So should wrapped dates.
        let expectedJSON_array = "[42]".data(using: .utf8)!
        _testRoundTrip(of: TopLevelArrayWrapper(timestamp),
                       expectedJSON: expectedJSON_array,
                       dateEncodingStrategy: .custom(encode),
                       dateDecodingStrategy: .custom(decode))
    }

    @Test func encodingDateCustomEmpty() {
        let timestamp = Date()

        // Encoding nothing should encode an empty keyed container ({}).
        let encode = { @Sendable (_: Date, _: Encoder) throws -> Void in }
        let decode = { @Sendable (_: Decoder) throws -> Date in return timestamp }

        let expectedJSON = "{}".data(using: .utf8)!
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
    @Test func encodingData() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])

        let expectedJSON = "[222,173,190,239]".data(using: .utf8)!
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

    @Test func encodingDataCustom() {
        // We'll encode a number instead of data.
        let encode = { @Sendable (_ data: Data, _ encoder: Encoder) throws -> Void in
            var container = encoder.singleValueContainer()
            try container.encode(42)
        }
        let decode = { @Sendable (_: Decoder) throws -> Data in return Data() }

        let expectedJSON = "42".data(using: .utf8)!
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

    @Test func encodingDataCustomEmpty() {
        // Encoding nothing should encode an empty keyed container ({}).
        let encode = { @Sendable (_: Data, _: Encoder) throws -> Void in }
        let decode = { @Sendable (_: Decoder) throws -> Data in return Data() }

        let expectedJSON = "{}".data(using: .utf8)!
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
    @Test func encodingNonConformingFloats() {
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

    @Test func encodingNonConformingFloatStrings() {
        let encodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN")
        let decodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN")

        _testRoundTrip(of: Float.infinity,
                       expectedJSON: "\"INF\"".data(using: .utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
        _testRoundTrip(of: -Float.infinity,
                       expectedJSON: "\"-INF\"".data(using: .utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)

        // Since Float.nan != Float.nan, we have to use a placeholder that'll encode NaN but actually round-trip.
        _testRoundTrip(of: FloatNaNPlaceholder(),
                       expectedJSON: "\"NaN\"".data(using: .utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)

        _testRoundTrip(of: Double.infinity,
                       expectedJSON: "\"INF\"".data(using: .utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
        _testRoundTrip(of: -Double.infinity,
                       expectedJSON: "\"-INF\"".data(using: .utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)

        // Since Double.nan != Double.nan, we have to use a placeholder that'll encode NaN but actually round-trip.
        _testRoundTrip(of: DoubleNaNPlaceholder(),
                       expectedJSON: "\"NaN\"".data(using: .utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)

        // Optional Floats and Doubles should encode the same way.
        _testRoundTrip(of: Optional(Float.infinity),
                       expectedJSON: "\"INF\"".data(using: .utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
        _testRoundTrip(of: Optional(-Float.infinity),
                       expectedJSON: "\"-INF\"".data(using: .utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
        _testRoundTrip(of: Optional(Double.infinity),
                       expectedJSON: "\"INF\"".data(using: .utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
        _testRoundTrip(of: Optional(-Double.infinity),
                       expectedJSON: "\"-INF\"".data(using: .utf8)!,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
    }

    // MARK: - Directly Encoded Array Tests

    @Test func directlyEncodedArrays() {
        let encodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN")
        let decodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN")

        struct Arrays: Codable, Equatable {
            let integers: [Int]
            let doubles: [Double]
            let strings: [String]
        }

        let value = Arrays(
            integers: [.min, 0, 42, .max],
            doubles: [42.0, 3.14, .infinity, -.infinity],
            strings: ["Hello", "World", "true", "0\n1", "\u{0008}"]
        )
        _testRoundTrip(of: value,
                       nonConformingFloatEncodingStrategy: encodingStrategy,
                       nonConformingFloatDecodingStrategy: decodingStrategy)
        _testRoundTrip(of: value,
                       outputFormatting: .prettyPrinted,
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

    @Test func encodingKeyStrategyCustom() {
        let expected = "{\"QQQhello\":\"test\"}"
        let encoded = EncodeMe(keyName: "hello")

        let encoder = JSONEncoder()
        let customKeyConversion = { @Sendable (_ path : [CodingKey]) -> CodingKey in
            let key = _TestKey(stringValue: "QQQ" + path.last!.stringValue)!
            return key
        }
        encoder.keyEncodingStrategy = .custom(customKeyConversion)
        let resultData = try! encoder.encode(encoded)
        let resultString = String(bytes: resultData, encoding: .utf8)

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

    @Test func encodingKeyStrategyPath() throws {
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
        let resultData = try encoder.encode(encoded)
        let resultString = String(bytes: resultData, encoding: .utf8)

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

    @Test func decodingKeyStrategyCustom() throws {
        let input = "{\"----hello\":\"test\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let customKeyConversion = { @Sendable (_ path: [CodingKey]) -> CodingKey in
            // This converter removes the first 4 characters from the start of all string keys, if it has more than 4 characters
            let string = path.last!.stringValue
            guard string.count > 4 else { return path.last! }
            let newString = String(string.dropFirst(4))
            return _TestKey(stringValue: newString)!
        }
        decoder.keyDecodingStrategy = .custom(customKeyConversion)
        let result = try decoder.decode(DecodeMe2.self, from: input)

        #expect("test" == result.hello)
    }

    @Test func decodingDictionaryStringKeyConversionUntouched() throws {
        let input = "{\"leave_me_alone\":\"test\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decoder.decode([String: String].self, from: input)

        #expect(["leave_me_alone": "test"] == result)
    }
    
    @Test func decodingDictionaryCodingKeyRepresentableKeyConversionUntouched() throws {
        struct Key: RawRepresentable, CodingKeyRepresentable, Hashable, Codable {
            let rawValue: String
        }

        let input = "{\"leave_me_alone\":\"test\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decoder.decode([Key: String].self, from: input)

        #expect(result[Key(rawValue: "leave_me_alone")] == "test")
    }

    @Test func decodingDictionaryFailureKeyPath() {
        let input = "{\"leave_me_alone\":\"test\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        #expect {
            try decoder.decode([String: Int].self, from: input)
        } throws: {
            guard case DecodingError.typeMismatch(_, let context) = $0 else {
                return false
            }
            return (1 == context.codingPath.count) && ("leave_me_alone" == context.codingPath[0].stringValue)
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

    @Test func keyStrategyDuplicateKeys() throws {
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
        let input = "{\"unused key 1\":\"test1\",\"unused key 2\":\"test2\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom(customKeyConversion)

        let decodingResult = try decoder.decode(DecodeMe5.self, from: input)
        // There will be only one result for oneTwo.
        #expect(1 == decodingResult.numberOfKeys)
        // While the order in which these values should be taken is NOT defined by the JSON spec in any way, the historical behavior has been to select the *first* value for a given key.
        #expect(decodingResult.oneTwo == "test1")

        // Encoding
        let encoded = DecodeMe5()
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .custom(customKeyConversion)
        let decodingResultData = try encoder.encode(encoded)
        let decodingResultString = String(bytes: decodingResultData, encoding: .utf8)

        // There will be only one value in the result (the second one encoded)
        #expect("{\"oneTwo\":\"test2\"}" == decodingResultString)
    }

    // MARK: - Encoder Features
    @Test func nestedContainerCodingPaths() {
        let encoder = JSONEncoder()
        #expect(throws: Never.self) {
            try encoder.encode(NestedContainersTestType())
        }
    }

    @Test func superEncoderCodingPaths() {
        let encoder = JSONEncoder()
        #expect(throws: Never.self) {
            try encoder.encode(NestedContainersTestType(testSuperEncoder: true))
        }
    }

    // MARK: - Type coercion
    @Test func typeCoercion() {
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int8].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int16].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int32].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int64].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int128].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt8].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt16].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt32].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt64].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt128].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Float].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Double].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int8], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int16], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int32], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int64], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int128], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt8], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt16], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt32], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt64], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt128], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Float], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Double], as: [Bool].self)
    }

    @Test func decodingConcreteTypeParameter() throws {
        let encoder = JSONEncoder()
        let json = try encoder.encode(Employee.testValue)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Employee.self as Person.Type, from: json)

        #expect(type(of: decoded) == Employee.self, "Expected decoded value to be of type Employee; got \(type(of: decoded)) instead.")
    }

    // MARK: - Encoder State
    // SR-6078
    @Test func encoderStateThrowOnEncode() {
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

    @Test func encoderStateThrowOnEncodeCustomDate() {
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

    @Test func encoderStateThrowOnEncodeCustomData() {
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

    @Test func issue106506794() throws {
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
    @Test func decoderStateThrowOnDecode() throws {
        // The container stack here starts as [[1,2,3]]. Attempting to decode as [String] matches the outer layer (Array), and begins decoding the array.
        // Once Array decoding begins, 1 is pushed onto the container stack ([[1,2,3], 1]), and 1 is attempted to be decoded as String. This throws a .typeMismatch, but the container is not popped off the stack.
        // When attempting to decode [Int], the container stack is still ([[1,2,3], 1]), and 1 fails to decode as [Int].
        let json = "[1,2,3]".data(using: .utf8)!
        let _ = try JSONDecoder().decode(EitherDecodable<[String], [Int]>.self, from: json)
    }

    @Test func decoderStateThrowOnDecodeCustomDate() throws {
        // This test is identical to testDecoderStateThrowOnDecode, except we're going to fail because our closure throws an error, not because we hit a type mismatch.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom({ decoder in
            enum CustomError : Error { case foo }
            throw CustomError.foo
        })

        let json = "1".data(using: .utf8)!
        let _ = try decoder.decode(EitherDecodable<Date, Int>.self, from: json)
    }

    @Test func decoderStateThrowOnDecodeCustomData() throws {
        // This test is identical to testDecoderStateThrowOnDecode, except we're going to fail because our closure throws an error, not because we hit a type mismatch.
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .custom({ decoder in
            enum CustomError : Error { case foo }
            throw CustomError.foo
        })

        let json = "1".data(using: .utf8)!
        let _ = try decoder.decode(EitherDecodable<Data, Int>.self, from: json)
    }


    @Test func decodingFailure() {
        struct DecodeFailure : Decodable {
            var invalid: String
        }
        let toDecode = "{\"invalid\": json}";
        _testDecodeFailure(of: DecodeFailure.self, data: toDecode.data(using: .utf8)!)
    }

    @Test func decodingFailureThrowInInitKeyedContainer() {
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
        _testDecodeFailure(of: DecodeFailure.self, data: toDecode.data(using: .utf8)!)
    }

    @Test func decodingFailureThrowInInitSingleContainer() {
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
        _testDecodeFailure(of: DecodeFailure.self, data: toDecode.data(using: .utf8)!)
    }

    @Test func invalidFragment() {
        struct DecodeFailure: Decodable {
            var foo: String
        }
        let toDecode = "\"foo"
        _testDecodeFailure(of: DecodeFailure.self, data: toDecode.data(using: .utf8)!)
    }

    @Test func repeatedFailedNilChecks() {
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
        let json = "[1, 2, 3]".data(using: .utf8)!
        #expect(throws: Never.self) {
            try JSONDecoder().decode(RepeatNilCheckDecodable.self, from: json)
        }
    }

    @Test func delayedDecoding() throws {

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
        return "{}".data(using: .utf8)!
    }

    private func _testEncodeFailure<T : Encodable>(of value: T, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(throws: (any Error).self, "Encode of top-level \(T.self) was expected to fail.", sourceLocation: sourceLocation) {
            try JSONEncoder().encode(value)
        }
    }

    private func _testDecodeFailure<T: Decodable>(of value: T.Type, data: Data, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(throws: (any Error).self, "Decode of top-level \(value) was expected to fail.", sourceLocation: sourceLocation) {
            try JSONDecoder().decode(value, from: data)
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
                                   sourceLocation: SourceLocation = #_sourceLocation) where T : Codable, T : Equatable {
        var payload: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = outputFormatting
            encoder.dateEncodingStrategy = dateEncodingStrategy
            encoder.dataEncodingStrategy = dataEncodingStrategy
            encoder.nonConformingFloatEncodingStrategy = nonConformingFloatEncodingStrategy
            encoder.keyEncodingStrategy = keyEncodingStrategy
            payload = try encoder.encode(value)
        } catch {
            Issue.record("Failed to encode \(T.self) to JSON: \(error)", sourceLocation: sourceLocation)
            return
        }

        if let expectedJSON = json {
            let expected = String(data: expectedJSON, encoding: .utf8)!
            let actual = String(data: payload, encoding: .utf8)!
            #expect(expected == actual, "Produced JSON not identical to expected JSON.", sourceLocation: sourceLocation)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = dateDecodingStrategy
            decoder.dataDecodingStrategy = dataDecodingStrategy
            decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
            decoder.keyDecodingStrategy = keyDecodingStrategy
            let decoded = try decoder.decode(T.self, from: payload)
            #expect(decoded == value, "\(T.self) did not round-trip to an equal value.", sourceLocation: sourceLocation)
        } catch {
            Issue.record("Failed to decode \(T.self) from JSON: \(error)", sourceLocation: sourceLocation)
        }
    }

    private func _testRoundTripTypeCoercionFailure<T,U>(of value: T, as type: U.Type, sourceLocation: SourceLocation = #_sourceLocation) where T : Codable, U : Codable {
        #expect(throws: (any Error).self, "Coercion from \(T.self) to \(U.self) was expected to fail.", sourceLocation: sourceLocation) {
            let data = try JSONEncoder().encode(value)
            let _ = try JSONDecoder().decode(U.self, from: data)
        }
    }

    private func _test<T : Equatable & Decodable>(JSONString: String, to object: T, sourceLocation: SourceLocation = #_sourceLocation) {
        let encs : [String.Encoding] = [.utf8, .utf16BigEndian, .utf16LittleEndian, .utf32BigEndian, .utf32LittleEndian]
        let decoder = JSONDecoder()
        for enc in encs {
            let data = JSONString.data(using: enc)!
            let parsed : T
            do {
                parsed = try decoder.decode(T.self, from: data)
            } catch {
                Issue.record("Failed to decode \(JSONString) with encoding \(enc): Error: \(error)", sourceLocation: sourceLocation)
                continue
            }
            #expect(object == parsed, sourceLocation: sourceLocation)
        }
    }

    @Test func jsonEscapedSlashes() {
        _test(JSONString: "\"\\/test\\/path\"", to: "/test/path")
        _test(JSONString: "\"\\\\/test\\\\/path\"", to: "\\/test\\/path")
    }

    @Test func jsonEscapedForwardSlashes() {
        _testRoundTrip(of: ["/":1], expectedJSON:
"""
{"\\/":1}
""".data(using: .utf8)!)
    }

    @Test func jsonUnicodeCharacters() {
        // UTF8:
        // E9 96 86 E5 B4 AC EB B0 BA EB 80 AB E9 A2 92
        // 閆崬밺뀫颒
        _test(JSONString: "[\"閆崬밺뀫颒\"]", to: ["閆崬밺뀫颒"])
        _test(JSONString: "[\"本日\"]", to: ["本日"])
    }

    @Test func jsonUnicodeEscapes() throws {
        let testCases = [
            // e-acute and greater-than-or-equal-to
            "\"\\u00e9\\u2265\"" : "é≥",

            // e-acute and greater-than-or-equal-to, surrounded by 42
            "\"42\\u00e942\\u226542\"" : "42é42≥42",

            // e-acute with upper-case hex
            "\"\\u00E9\"" : "é",

            // G-clef (UTF16 surrogate pair) 0x1D11E
            "\"\\uD834\\uDD1E\"" : "𝄞",
        ]
        for (input, expectedOutput) in testCases {
            _test(JSONString: input, to: expectedOutput)
        }
    }
    
    @Test func encodingJSONHexUnicodeEscapes() throws {
        let testCases = [
            "\u{0001}\u{0002}\u{0003}": "\"\\u0001\\u0002\\u0003\"",
            "\u{0010}\u{0018}\u{001f}": "\"\\u0010\\u0018\\u001f\"",
        ]
        for (string, json) in testCases {
            _testRoundTrip(of: string, expectedJSON: Data(json.utf8))
        }
    }

    @Test(arguments: [
        "\\uD834", "\\uD834hello", "hello\\uD834", "\\uD834\\u1221", "\\uD8", "\\uD834x\\uDD1E"
    ])
    func jsonBadUnicodeEscapes(str: String) {
        let data = str.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(String.self, from: data)
        }
    }
    
    @Test func nullByte() throws {
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

    @Test func superfluouslyEscapedCharacters() {
        let json = "[\"\\h\\e\\l\\l\\o\"]"
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode([String].self, from: json.data(using: .utf8)!)
        }
    }

    @Test func equivalentUTF8Sequences() throws {
        let json =
"""
{
  "caf\\u00e9" : true,
  "cafe\\u0301" : false
}
""".data(using: .utf8)!

        let dict = try JSONDecoder().decode([String:Bool].self, from: json)
        #expect(dict.count == 1)
    }

    @Test func jsonControlCharacters() {
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

    @Test func jsonNumberFragments() {
        let array = ["0 ", "1.0 ", "0.1 ", "1e3 ", "-2.01e-3 ", "0", "1.0", "1e3", "-2.01e-3", "0e-10"]
        let expected = [0, 1.0, 0.1, 1000, -0.00201, 0, 1.0, 1000, -0.00201, 0]
        for (json, expected) in zip(array, expected) {
            _test(JSONString: json, to: expected)
        }
    }

    @Test func invalidJSONNumbersFailAsExpected() {
        let array = ["0.", "1e ", "-2.01e- ", "+", "2.01e-1234", "+2.0q", "2s", "NaN", "nan", "Infinity", "inf", "-", "0x42", "1.e2"]
        for json in array {
            let data = json.data(using: .utf8)!
            #expect(throws: (any Error).self, "Expected error for input \"\(json)\"") {
                _ = try JSONDecoder().decode(Float.self, from: data)
            }
        }
    }

    func _checkExpectedThrownDataCorruptionUnderlyingError(contains substring: String, sourceLocation: SourceLocation = #_sourceLocation, closure: () throws -> Void) {
        do {
            try closure()
            Issue.record("Expected failure containing string: \"\(substring)\"", sourceLocation: sourceLocation)
        } catch let error as DecodingError {
            guard case let .dataCorrupted(context) = error else {
                Issue.record("Unexpected DecodingError type: \(error)", sourceLocation: sourceLocation)
                return
            }
#if FOUNDATION_FRAMEWORK
            let nsError = context.underlyingError! as NSError
            #expect(nsError.debugDescription.contains(substring), "Description \"\(nsError.debugDescription)\" doesn't contain substring \"\(substring)\"", sourceLocation: sourceLocation)
#endif
        } catch {
            Issue.record("Unexpected error type: \(error)", sourceLocation: sourceLocation)
        }
    }

    @Test func topLevelFragmentsWithGarbage() {
        _checkExpectedThrownDataCorruptionUnderlyingError(contains: "Unexpected character") {
            let _ = try JSONDecoder().decode(Bool.self, from: "tru_".data(using: .utf8)!)
            let _ = try json5Decoder.decode(Bool.self, from: "tru_".data(using: .utf8)!)
        }
        _checkExpectedThrownDataCorruptionUnderlyingError(contains: "Unexpected character") {
            let _ = try JSONDecoder().decode(Bool.self, from: "fals_".data(using: .utf8)!)
            let _ = try json5Decoder.decode(Bool.self, from: "fals_".data(using: .utf8)!)
        }
        _checkExpectedThrownDataCorruptionUnderlyingError(contains: "Unexpected character") {
            let _ = try JSONDecoder().decode(Bool?.self, from: "nul_".data(using: .utf8)!)
            let _ = try json5Decoder.decode(Bool?.self, from: "nul_".data(using: .utf8)!)
        }
    }

    @Test func topLevelNumberFragmentsWithJunkDigitCharacters() throws {
        let fullData = "3.141596".data(using: .utf8)!
        let partialData = fullData[0..<4]

        #expect(try 3.14 == JSONDecoder().decode(Double.self, from: partialData))
    }

    @Test
    @MainActor // Deeply recursive tests which requires running on the main thread which has a higher stack size limit
    func depthTraversal() {
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
            try JSONDecoder().decode(SuperNestedArray.self, from: jsonGood.data(using: .utf8)!)
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(SuperNestedArray.self, from: jsonBad.data(using: .utf8)!)
        }

    }

    @Test func jsonPermitsTrailingCommas() throws {
        // Trailing commas aren't valid JSON and should never be emitted, but are syntactically unambiguous and are allowed by
        // most parsers for ease of use.
        let json = "{\"key\" : [ true, ],}"
        let data = json.data(using: .utf8)!

        let result = try JSONDecoder().decode([String:[Bool]].self, from: data)
        let expected = ["key" : [true]]
        #expect(result == expected)
    }

    @Test func whitespaceOnlyData() {
        let data = " ".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Int.self, from: data)
        }
    }

    @Test func smallFloatNumber() {
        _testRoundTrip(of: [["magic_number" : 7.45673334164903e-115]])
    }

    @Test func largeIntegerNumber() throws {
        let num : UInt64 = 6032314514195021674
        let json = "{\"a\":\(num)}"
        let data = json.data(using: .utf8)!

        let result = try JSONDecoder().decode([String:UInt64].self, from: data)
        let number = try #require(result["a"])
        #expect(number == num)
    }
    
    @Test func largeIntegerNumberIsNotRoundedToNearestDoubleWhenDecodingAsAnInteger() {
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
                let result = try? decoder.decode(Int64.self, from: json.data(using: .utf8)!)
                #expect(result == value, "Unexpected \(decoder) result for input \"\(json)\"")
            }
            
            for (json, value) in uint64s {
                let result = try? decoder.decode(UInt64.self, from: json.data(using: .utf8)!)
                #expect(result == value, "Unexpected \(decoder) result for input \"\(json)\"")
            }
        }
    }

    @Test func roundTrippingExtremeValues() {
        struct Numbers : Codable, Equatable {
            let floats : [Float]
            let doubles : [Double]
        }
        let testValue = Numbers(floats: [.greatestFiniteMagnitude, .leastNormalMagnitude], doubles: [.greatestFiniteMagnitude, .leastNormalMagnitude])
        _testRoundTrip(of: testValue)
    }
  
    @Test func roundTrippingInt128() {
        for i128 in [Int128.min,
                        Int128.min + 1,
                        -0x1_0000_0000_0000_0000,
                        0x0_8000_0000_0000_0000,
                        -1,
                        0,
                        0x7fff_ffff_ffff_ffff,
                        0x8000_0000_0000_0000,
                        0xffff_ffff_ffff_ffff,
                        0x1_0000_0000_0000_0000,
                     .max] {
            _testRoundTrip(of: i128)
        }
    }
    
    @Test func int128SlowPath() throws {
        let decoder = JSONDecoder()
        let work: [Int128] = [18446744073709551615, -18446744073709551615]
        for value in work {
            // force the slow-path by appending ".0"
            let json = "\(value).0".data(using: .utf8)!
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
            let json = "\(value).0".data(using: .utf8)!
            #expect(throws: (any Error).self) {
                try decoder.decode(Int128.self, from: json)
            }
        }
    }
    
    @Test func roundTrippingUInt128() {
        for u128 in [UInt128.zero,
                     1,
                     0x0000_0000_0000_0000_7fff_ffff_ffff_ffff,
                     0x0000_0000_0000_0000_8000_0000_0000_0000,
                     0x0000_0000_0000_0000_ffff_ffff_ffff_ffff,
                     0x0000_0000_0000_0001_0000_0000_0000_0000,
                     0x7fff_ffff_ffff_ffff_ffff_ffff_ffff_ffff,
                     0x8000_0000_0000_0000_0000_0000_0000_0000,
                     .max] {
            _testRoundTrip(of: u128)
        }
    }
    
    @Test func uint128SlowPath() throws {
        let decoder = JSONDecoder()
        let work: [UInt128] = [18446744073709551615]
        for value in work {
            // force the slow-path by appending ".0"
            let json = "\(value).0".data(using: .utf8)!
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
            let json = "\(value).0".data(using: .utf8)!
            #expect(throws: (any Error).self) {
                try decoder.decode(UInt128.self, from: json)
            }
        }
    }

    @Test func roundTrippingDoubleValues() {
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

    @Test func decodeLargeDoubleAsInteger() throws {
        let data = try JSONEncoder().encode(Double.greatestFiniteMagnitude)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(UInt64.self, from: data)
        }
    }

    @Test func localeDecimalPolicyIndependence() throws {
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

    @Test func whitespace() {
        let tests : [(json: String, expected: [String:Bool])] = [
            ("{\"v\"\n : true}",   ["v":true]),
            ("{\"v\"\r\n : true}", ["v":true]),
            ("{\"v\"\r : true}",   ["v":true])
        ]
        for test in tests {
            let data = test.json.data(using: .utf8)!
            let decoded = try! JSONDecoder().decode([String:Bool].self, from: data)
            #expect(test.expected == decoded)
        }
    }

    @Test func assumesTopLevelDictionary() throws {
        let decoder = JSONDecoder()
        decoder.assumesTopLevelDictionary = true

        let json = "\"x\" : 42"
        var result = try decoder.decode([String:Int].self, from: json.data(using: .utf8)!)
        #expect(result == ["x" : 42])

        let jsonWithBraces = "{\"x\" : 42}"
        result = try decoder.decode([String:Int].self, from: jsonWithBraces.data(using: .utf8)!)
        #expect(result == ["x" : 42])

        result = try decoder.decode([String:Int].self, from: Data())
        #expect(result == [:])

        let jsonWithEndBraceOnly = "\"x\" : 42}"
        #expect(throws: (any Error).self) {
            try decoder.decode([String:Int].self, from: jsonWithEndBraceOnly.data(using: .utf8)!)
        }

        let jsonWithStartBraceOnly = "{\"x\" : 42"
        #expect(throws: (any Error).self) {
            try decoder.decode([String:Int].self, from: jsonWithStartBraceOnly.data(using: .utf8)!)
        }

    }

    @Test func bomPrefixes() throws {
        let json = "\"👍🏻\""
        let decoder = JSONDecoder()

        // UTF-8 BOM
        let utf8_BOM = Data([0xEF, 0xBB, 0xBF])
        #expect(try "👍🏻" == decoder.decode(String.self, from: utf8_BOM + json.data(using: .utf8)!))

        // UTF-16 BE
        let utf16_BE_BOM = Data([0xFE, 0xFF])
        #expect(try "👍🏻" == decoder.decode(String.self, from: utf16_BE_BOM + json.data(using: .utf16BigEndian)!))

        // UTF-16 LE
        let utf16_LE_BOM = Data([0xFF, 0xFE])
        #expect(try "👍🏻" == decoder.decode(String.self, from: utf16_LE_BOM + json.data(using: .utf16LittleEndian)!))

        // UTF-32 BE
        let utf32_BE_BOM = Data([0x0, 0x0, 0xFE, 0xFF])
        #expect(try "👍🏻" == decoder.decode(String.self, from: utf32_BE_BOM + json.data(using: .utf32BigEndian)!))

        // UTF-32 LE
        let utf32_LE_BOM = Data([0xFE, 0xFF, 0, 0])
        #expect(try "👍🏻" == decoder.decode(String.self, from: utf32_LE_BOM + json.data(using: .utf32LittleEndian)!))

        // Try some mismatched BOMs
        #expect(throws: (any Error).self) {
            try decoder.decode(String.self, from: utf32_LE_BOM + json.data(using: .utf32BigEndian)!)
        }
        
        #expect(throws: (any Error).self) {
            try decoder.decode(String.self, from: utf16_BE_BOM + json.data(using: .utf32LittleEndian)!)
        }
        
        #expect(throws: (any Error).self) {
            try decoder.decode(String.self, from: utf8_BOM + json.data(using: .utf16BigEndian)!)
        }
    }
    
    @Test func invalidKeyUTF8() {
        // {"key[255]":"value"}
        // The invalid UTF-8 byte sequence in the key should trigger a thrown error, not a crash.
        let data = Data([123, 34, 107, 101, 121, 255, 34, 58, 34, 118, 97, 108, 117, 101, 34, 125])
        struct Example: Decodable {
            let key: String
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Example.self, from: data)
        }
    }

    @Test func valueNotFoundError() {
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
        let json = "{\"a\":true}".data(using: .utf8)!

        // The expected valueNotFound error is swalled by the init(from:) implementation.
        #expect(throws: Never.self) {
            try JSONDecoder().decode(ValueNotFound.self, from: json)
        }
    }

    @Test func infiniteDate() {
        let date = Date(timeIntervalSince1970: .infinity)

        let encoder = JSONEncoder()

        encoder.dateEncodingStrategy = .deferredToDate
        #expect(throws: (any Error).self) {
            try encoder.encode([date])
        }

        encoder.dateEncodingStrategy = .secondsSince1970
        #expect(throws: (any Error).self) {
            try encoder.encode([date])
        }

        encoder.dateEncodingStrategy = .millisecondsSince1970
        #expect(throws: (any Error).self) {
            try encoder.encode([date])
        }
    }

    @Test func typeEncodesNothing() {
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

        let arrayData = try! enc.encode([EncodesNothing()])
        #expect("[{}]" == String(data: arrayData, encoding: .utf8))

        let objectData = try! enc.encode(["test" : EncodesNothing()])
        #expect("{\"test\":{}}" == String(data: objectData, encoding: .utf8))
    }

    @Test func superEncoders() throws {
        struct SuperEncoding : Encodable {
            enum CodingKeys: String, CodingKey {
                case firstSuper
                case secondSuper
                case unkeyed
                case direct
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

                let directSuper = keyed.superEncoder(forKey: .direct)
                try ["direct":"super"].encode(to: directSuper)

                // NOTE!!! At present, the order in which the values in the unkeyed container's superEncoders above get inserted into the resulting array depends on the order in which the superEncoders are deinit'd!! This can result in some very unexpected results, and this pattern is not recommended. This test exists just to verify compatibility.
            }
        }
        let data = try JSONEncoder().encode(SuperEncoding())
        let string = String(data: data, encoding: .utf8)!

        #expect(string.contains("\"firstSuper\":\"First\""))
        #expect(string.contains("\"secondSuper\":\"Second\""))
        #expect(string.contains("[0,\"First\",\"Second\",42]"))
        #expect(string.contains("{\"direct\":\"super\"}"))
    }

    @Test func redundantKeys() throws {
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
        #expect(String(data: data, encoding: .utf8) == ("{\"key\":42}"))

        data = try JSONEncoder().encode(RedundantEncoding(replacedType: .keyedContainer, useSuperEncoder: false))
        #expect(String(data: data, encoding: .utf8) == ("{\"key\":42}"))

        data = try JSONEncoder().encode(RedundantEncoding(replacedType: .keyedContainer, useSuperEncoder: true))
        #expect(String(data: data, encoding: .utf8) == ("{\"key\":42}"))

        data = try JSONEncoder().encode(RedundantEncoding(replacedType: .unkeyedContainer, useSuperEncoder: false))
        #expect(String(data: data, encoding: .utf8) == ("{\"key\":42}"))

        data = try JSONEncoder().encode(RedundantEncoding(replacedType: .unkeyedContainer, useSuperEncoder: true))
        #expect(String(data: data, encoding: .utf8) == ("{\"key\":42}"))
    }

    @Test func SR17581_codingEmptyDictionaryWithNonstringKeyDoesRoundtrip() throws {
        struct Something: Codable {
            struct Key: Codable, Hashable {
                var x: String
            }

            var dict: [Key: String]

            enum CodingKeys: String, CodingKey {
                case dict
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.dict = try container.decode([Key: String].self, forKey: .dict)
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(dict, forKey: .dict)
            }

            init(dict: [Key: String]) {
                self.dict = dict
            }
        }

        let toEncode = Something(dict: [:])
        let data = try JSONEncoder().encode(toEncode)
        let result = try JSONDecoder().decode(Something.self, from: data)
        #expect(result.dict.count == 0)
    }

    #if FOUNDATION_EXIT_TESTS
    @Test func preconditionFailuresForContainerReplacement() async {
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
        await #expect(processExitsWith: .failure) {
            let _ = try JSONEncoder().encode(RedundantEncoding(subcase: .replaceValueWithKeyedContainer))
        }
        await #expect(processExitsWith: .failure) {
            let _ = try JSONEncoder().encode(RedundantEncoding(subcase: .replaceValueWithUnkeyedContainer))
        }
        await #expect(processExitsWith: .failure) {
            let _ = try JSONEncoder().encode(RedundantEncoding(subcase: .replaceKeyedContainerWithUnkeyed))
        }
        await #expect(processExitsWith: .failure) {
            let _ = try JSONEncoder().encode(RedundantEncoding(subcase: .replaceUnkeyedContainerWithKeyed))
        }
    }
    #endif

    @Test func decodeIfPresent() throws {
        let emptyDictJSON = try JSONEncoder().encode(DecodeIfPresentAllTypes<KeyedEncodeWithoutNulls>.allNils)
        let testEmptyDict = try JSONDecoder().decode(DecodeIfPresentAllTypes<UseKeyed>.self, from: emptyDictJSON)
        #expect(testEmptyDict == .allNils)

        let allNullDictJSON = try JSONEncoder().encode(DecodeIfPresentAllTypes<KeyedEncodeWithNulls>.allNils)
        let testAllNullDict = try JSONDecoder().decode(DecodeIfPresentAllTypes<UseKeyed>.self, from: allNullDictJSON)
        #expect(testAllNullDict == .allNils)

        let allOnesDictJSON = try JSONEncoder().encode(DecodeIfPresentAllTypes<UseKeyed>.allOnes)
        let testAllOnesDict = try JSONDecoder().decode(DecodeIfPresentAllTypes<UseKeyed>.self, from: allOnesDictJSON)
        #expect(testAllOnesDict == .allOnes)

        let emptyArrayJSON = try JSONEncoder().encode(DecodeIfPresentAllTypes<UnkeyedEncodeWithoutNulls>.allNils)
        let testEmptyArray = try JSONDecoder().decode(DecodeIfPresentAllTypes<UseUnkeyed>.self, from: emptyArrayJSON)
        #expect(testEmptyArray == .allNils)

        let allNullArrayJSON = try JSONEncoder().encode(DecodeIfPresentAllTypes<UnkeyedEncodeWithNulls>.allNils)
        let testAllNullArray = try JSONDecoder().decode(DecodeIfPresentAllTypes<UseUnkeyed>.self, from: allNullArrayJSON)
        #expect(testAllNullArray == .allNils)

        let allOnesArrayJSON = try JSONEncoder().encode(DecodeIfPresentAllTypes<UseUnkeyed>.allOnes)
        let testAllOnesArray = try JSONDecoder().decode(DecodeIfPresentAllTypes<UseUnkeyed>.self, from: allOnesArrayJSON)
        #expect(testAllOnesArray == .allOnes)
    }
}

// MARK: - SnakeCase Tests
extension JSONEncoderTests {
    var json5Decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        return decoder
    }

    @Test func json5Numbers() {
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
                let val = try decoder.decode(Int.self, from: json.data(using: .utf8)!)
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
                let val = try decoder.decode(Double.self, from: json.data(using: .utf8)!)
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
            #expect(throws: (any Error).self, "Expected failure for input \"\(json)\"") {
                try decoder.decode(Int.self, from: json.data(using: .utf8)!)
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
            #expect(throws: (any Error).self, "Expected failure for input \"\(json)\"") {
                try decoder.decode(Double.self, from: json.data(using: .utf8)!)
            }
        }
    }

    @Test func json5Null() {
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
            try json5Decoder.decode(NullReader.self, from: validJSON.data(using: .utf8)!)
        }

        for json in invalidJSON {
            #expect(throws: (any Error).self, "Expected failure while decoding input \"\(json)\"") {
                try json5Decoder.decode(NullReader.self, from: json.data(using: .utf8)!)
            }
        }
    }

    @Test func json5EsotericErrors() {
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
                try json5Decoder.decode([String].self, from: json.data(using: .utf8)!)
            }
        }
        for json in objectStrings {
            #expect(throws: (any Error).self, "Expected error for input \(json)") {
                try json5Decoder.decode([String:Bool].self, from: json.data(using: .utf8)!)
            }
        }
        for json in objectCharacterArrays {
            #expect(throws: (any Error).self, "Expected error for input \(json)") {
                try json5Decoder.decode([String:Bool].self, from: Data(json))
            }
        }
    }

    @Test func json5Strings() {
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
                try json5Decoder.decode([String:Bool].self, from: json.data(using: .utf8)!)
            }
        }
        for (json, expected) in stringsToStrings {
            do {
                let decoded = try json5Decoder.decode([String:String].self, from: json.data(using: .utf8)!)
                #expect(expected == decoded["v"])
            } catch {
                if let expected {
                    Issue.record("Expected \(expected) for input \"\(json)\", but failed with \(error)")
                }
            }
        }
    }

    @Test func json5AssumedDictionary() {
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
                let decoded = try decoder.decode([String:String].self, from: json.data(using: .utf8)!)
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
            #expect(throws: Never.self, "Unexpected error for input \"\(json)\"") {
                let decoded = try decoder.decode(HelloGoodbye.self, from: json.data(using: .utf8)!)
                #expect(helloGoodbyeExpectedValue == decoded)
            }
        }

        let arrayJSON = "[1,2,3]".data(using: .utf8)! // Assumed dictionary can't be an array
        #expect(throws: (any Error).self) {
            try decoder.decode([Int].self, from: arrayJSON)
        }

        let strFragmentJSON = "fragment".data(using: .utf8)! // Assumed dictionary can't be a fragment
        #expect(throws: (any Error).self) {
            try decoder.decode(String.self, from: strFragmentJSON)
        }

        let numFragmentJSON = "42".data(using: .utf8)! // Assumed dictionary can't be a fragment
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
    @Test func decodingKeyStrategyCamel() throws {
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
            let input = "{\"camelCaseKey\":\"\(test.1)\",\"\(test.0)\":true}".data(using: .utf8)!

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let result = try decoder.decode(DecodeMe.self, from: input)

            #expect(result.found)
        }
    }

    @Test func encodingDictionaryStringKeyConversionUntouched() throws {
        let expected = "{\"leaveMeAlone\":\"test\"}"
        let toEncode: [String: String] = ["leaveMeAlone": "test"]

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let resultData = try encoder.encode(toEncode)
        let resultString = String(bytes: resultData, encoding: .utf8)

        #expect(expected == resultString)
    }
    
    @Test func encodingDictionaryCodingKeyRepresentableKeyConversionUntouched() throws {
        struct Key: RawRepresentable, CodingKeyRepresentable, Hashable, Codable {
            let rawValue: String
        }
        
        let expected = "{\"leaveMeAlone\":\"test\"}"
        let toEncode: [Key: String] = [Key(rawValue: "leaveMeAlone"): "test"]

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let resultData = try encoder.encode(toEncode)
        let resultString = String(bytes: resultData, encoding: .utf8)

        #expect(expected == resultString)
    }

    @Test func keyStrategySnakeGeneratedAndCustom() throws {
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
        let input = "{\"foo_bar\":\"test\",\"this_is_camel_case_too\":\"test2\"}".data(using: .utf8)!
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
        let encodingResultString = try #require(String(bytes: encodingResultData, encoding: .utf8))
        #expect(encodingResultString.contains("foo_bar"))
        #expect(encodingResultString.contains("this_is_camel_case_too"))
    }

    @Test func decodingDictionaryFailureKeyPathNested() {
        let input = "{\"top_level\": {\"sub_level\": {\"nested_value\": {\"int_value\": \"not_an_int\"}}}}".data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            _ = try decoder.decode([String: [String : DecodeFailureNested]].self, from: input)
        } catch DecodingError.typeMismatch(_, let context) {
            #expect(4 == context.codingPath.count)
            #expect("top_level" == context.codingPath[0].stringValue)
            #expect("sub_level" == context.codingPath[1].stringValue)
            #expect("nestedValue" == context.codingPath[2].stringValue)
            #expect("intValue" == context.codingPath[3].stringValue)
        } catch {
            Issue.record("Unexpected error: \(String(describing: error))")
        }
    }

    @Test func decodingKeyStrategyCamelGenerated() throws {
        let encoded = DecodeMe3(thisIsCamelCase: "test")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let resultData = try encoder.encode(encoded)
        let resultString = String(bytes: resultData, encoding: .utf8)
        #expect("{\"this_is_camel_case\":\"test\"}" == resultString)
    }

    @Test func decodingStringExpectedType() {
        let input = #"{"thisIsCamelCase": null}"#.data(using: .utf8)!
        #expect {
            _ = try JSONDecoder().decode(DecodeMe3.self, from: input)
        } throws: {
            guard let decodingError = $0 as? DecodingError,
                  case let DecodingError.valueNotFound(expected, _) = decodingError else {
                return false
            }
            return expected == String.self
        }
    }

    @Test func encodingKeyStrategySnakeGenerated() throws {
        // Test that this works with a struct that has automatically generated keys
        let input = "{\"this_is_camel_case\":\"test\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decoder.decode(DecodeMe3.self, from: input)

        #expect("test" == result.thisIsCamelCase)
    }

    @Test func encodingDictionaryFailureKeyPath() {
        let toEncode: [String: EncodeFailure] = ["key": EncodeFailure(someValue: Double.nan)]

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        do {
            _ = try encoder.encode(toEncode)
        } catch EncodingError.invalidValue(_, let context) {
            #expect(2 == context.codingPath.count)
            #expect("key" == context.codingPath[0].stringValue)
            #expect("someValue" == context.codingPath[1].stringValue)
        } catch {
            Issue.record("Unexpected error: \(String(describing: error))")
        }
    }

    @Test func encodingDictionaryFailureKeyPathNested() {
        let toEncode: [String: [String: EncodeFailureNested]] = ["key": ["sub_key": EncodeFailureNested(nestedValue: EncodeFailure(someValue: Double.nan))]]

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        do {
            _ = try encoder.encode(toEncode)
        } catch EncodingError.invalidValue(_, let context) {
            #expect(4 == context.codingPath.count)
            #expect("key" == context.codingPath[0].stringValue)
            #expect("sub_key" == context.codingPath[1].stringValue)
            #expect("nestedValue" == context.codingPath[2].stringValue)
            #expect("someValue" == context.codingPath[3].stringValue)
        } catch {
            Issue.record("Unexpected error: \(String(describing: error))")
        }
    }

    @Test func encodingKeyStrategySnake() throws {
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
            let resultString = String(bytes: resultData, encoding: .utf8)

            #expect(expected == resultString)
        }
    }
    
    @Test func twoByteUTF16Inputs() throws {
        let json = "7"
        let decoder = JSONDecoder()

        #expect(try 7 == decoder.decode(Int.self, from: json.data(using: .utf16BigEndian)!))
        #expect(try 7 == decoder.decode(Int.self, from: json.data(using: .utf16LittleEndian)!))
    }
    
    private func _run_passTest<T:Codable & Equatable>(name: String, json5: Bool = false, type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) {
        let jsonData = testData(forResource: name, withExtension: json5 ? "json5" : "json" , subdirectory: json5 ? "JSON5/pass" : "JSON/pass")!

        let plistData = testData(forResource: name, withExtension: "plist", subdirectory: "JSON/pass")
        let decoder = json5Decoder

        let decoded: T
        do {
            decoded = try decoder.decode(T.self, from: jsonData)
        } catch {
            Issue.record("Pass test \"\(name)\" failed with error: \(error)", sourceLocation: sourceLocation)
            return
        }

        let prettyPrintEncoder = JSONEncoder()
        prettyPrintEncoder.outputFormatting = .prettyPrinted

        for encoder in [JSONEncoder(), prettyPrintEncoder] {
            #expect(throws: Never.self, sourceLocation: sourceLocation) {
                let reencodedData = try encoder.encode(decoded)
                let redecodedObjects = try decoder.decode(T.self, from: reencodedData)
                #expect(decoded == redecodedObjects)
            }

            if let plistData {
                #expect(throws: Never.self, sourceLocation: sourceLocation) {
                    let decodedPlistObjects = try PropertyListDecoder().decode(T.self, from: plistData)
                    #expect(decoded == decodedPlistObjects)
                }
            }
        }
    }

    @Test func jsonPassTests() {
        _run_passTest(name: "pass1-utf8", type: JSONPass.Test1.self)
        _run_passTest(name: "pass1-utf16be", type: JSONPass.Test1.self)
        _run_passTest(name: "pass1-utf16le", type: JSONPass.Test1.self)
        _run_passTest(name: "pass1-utf32be", type: JSONPass.Test1.self)
        _run_passTest(name: "pass1-utf32le", type: JSONPass.Test1.self)
        _run_passTest(name: "pass2", type: JSONPass.Test2.self)
        _run_passTest(name: "pass3", type: JSONPass.Test3.self)
        _run_passTest(name: "pass4", type: JSONPass.Test4.self)
        _run_passTest(name: "pass5", type: JSONPass.Test5.self)
        _run_passTest(name: "pass6", type: JSONPass.Test6.self)
        _run_passTest(name: "pass7", type: JSONPass.Test7.self)
        _run_passTest(name: "pass8", type: JSONPass.Test8.self)
        _run_passTest(name: "pass9", type: JSONPass.Test9.self)
        _run_passTest(name: "pass10", type: JSONPass.Test10.self)
        _run_passTest(name: "pass11", type: JSONPass.Test11.self)
        _run_passTest(name: "pass12", type: JSONPass.Test12.self)
        _run_passTest(name: "pass13", type: JSONPass.Test13.self)
        _run_passTest(name: "pass14", type: JSONPass.Test14.self)
        _run_passTest(name: "pass15", type: JSONPass.Test15.self)
    }

    @Test func json5PassJSONFiles() {
        _run_passTest(name: "example", json5: true, type: JSON5Pass.Example.self)
        _run_passTest(name: "hex", json5: true, type: JSON5Pass.Hex.self)
        _run_passTest(name: "numbers", json5: true, type: JSON5Pass.Numbers.self)
        _run_passTest(name: "strings", json5: true, type: JSON5Pass.Strings.self)
        _run_passTest(name: "whitespace", json5: true, type: JSON5Pass.Whitespace.self)
    }

    private func _run_failTest<T:Decodable>(name: String, type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) {
        let jsonData = testData(forResource: name, withExtension: "json", subdirectory: "JSON/fail")!

        let decoder = JSONDecoder()
        decoder.assumesTopLevelDictionary = true
        #expect(throws: (any Error).self, "Decoding should have failed for invalid JSON data (test name: \(name))", sourceLocation: sourceLocation) {
            try decoder.decode(T.self, from: jsonData)
        }
    }

    @Test func jsonFailTests() {
        _run_failTest(name: "fail1", type: JSONFail.Test1.self)
        _run_failTest(name: "fail2", type: JSONFail.Test2.self)
        _run_failTest(name: "fail3", type: JSONFail.Test3.self)
        _run_failTest(name: "fail4", type: JSONFail.Test4.self)
        _run_failTest(name: "fail5", type: JSONFail.Test5.self)
        _run_failTest(name: "fail6", type: JSONFail.Test6.self)
        _run_failTest(name: "fail7", type: JSONFail.Test7.self)
        _run_failTest(name: "fail8", type: JSONFail.Test8.self)
        _run_failTest(name: "fail9", type: JSONFail.Test9.self)
        _run_failTest(name: "fail10", type: JSONFail.Test10.self)
        _run_failTest(name: "fail11", type: JSONFail.Test11.self)
        _run_failTest(name: "fail12", type: JSONFail.Test12.self)
        _run_failTest(name: "fail13", type: JSONFail.Test13.self)
        _run_failTest(name: "fail14", type: JSONFail.Test14.self)
        _run_failTest(name: "fail15", type: JSONFail.Test15.self)
        _run_failTest(name: "fail16", type: JSONFail.Test16.self)
        _run_failTest(name: "fail17", type: JSONFail.Test17.self)
        _run_failTest(name: "fail18", type: JSONFail.Test18.self)
        _run_failTest(name: "fail19", type: JSONFail.Test19.self)
        _run_failTest(name: "fail21", type: JSONFail.Test21.self)
        _run_failTest(name: "fail22", type: JSONFail.Test22.self)
        _run_failTest(name: "fail23", type: JSONFail.Test23.self)
        _run_failTest(name: "fail24", type: JSONFail.Test24.self)
        _run_failTest(name: "fail25", type: JSONFail.Test25.self)
        _run_failTest(name: "fail26", type: JSONFail.Test26.self)
        _run_failTest(name: "fail27", type: JSONFail.Test27.self)
        _run_failTest(name: "fail28", type: JSONFail.Test28.self)
        _run_failTest(name: "fail29", type: JSONFail.Test29.self)
        _run_failTest(name: "fail30", type: JSONFail.Test30.self)
        _run_failTest(name: "fail31", type: JSONFail.Test31.self)
        _run_failTest(name: "fail32", type: JSONFail.Test32.self)
        _run_failTest(name: "fail33", type: JSONFail.Test33.self)
        _run_failTest(name: "fail34", type: JSONFail.Test34.self)
        _run_failTest(name: "fail35", type: JSONFail.Test35.self)
        _run_failTest(name: "fail36", type: JSONFail.Test36.self)
        _run_failTest(name: "fail37", type: JSONFail.Test37.self)
        _run_failTest(name: "fail38", type: JSONFail.Test38.self)
        _run_failTest(name: "fail39", type: JSONFail.Test39.self)
        _run_failTest(name: "fail40", type: JSONFail.Test40.self)
        _run_failTest(name: "fail41", type: JSONFail.Test41.self)

    }

    func _run_json5SpecTest<T:Decodable>(_ category: String, _ name: String, testType: JSON5SpecTestType, type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) {
        let subdirectory = "/JSON5/spec/\(category)"
        let ext = testType.fileExtension
        guard let jsonData = testData(forResource: name, withExtension: ext, subdirectory: subdirectory) else {
            Issue.record("Failed to load test data forResource: \(name), withExtension: \(ext), subdirectory: \(subdirectory)", sourceLocation: sourceLocation)
            return
        }

        let json5 = json5Decoder
        let json = JSONDecoder()

        switch testType {
        case .json, .json5_foundationPermissiveJSON:
            // Valid JSON should remain valid JSON5
            #expect(throws: Never.self, sourceLocation: sourceLocation) {
                _ = try json5.decode(type, from: jsonData)
            }

            // Repeat with non-JSON5-compliant decoder.
            #expect(throws: Never.self, sourceLocation: sourceLocation) {
                _ = try json.decode(type, from: jsonData)
            }
        case .json5:
            #expect(throws: Never.self, sourceLocation: sourceLocation) {
                _ = try json5.decode(type, from: jsonData)
            }

            // Regular JSON decoder should throw.
            do {
                let val = try json.decode(type, from: jsonData)
                Issue.record("Expected decode failure (original JSON)for test \(name).\(ext), but got: \(val)", sourceLocation: sourceLocation)
            } catch { }
        case .js:
            // Valid ES5 that's explicitly disallowed by JSON5 is also invalid JSON.
            do {
                let val = try json5.decode(type, from: jsonData)
                Issue.record("Expected decode failure (JSON5) for test \(name).\(ext), but got: \(val)", sourceLocation: sourceLocation)
            } catch { }

            // Regular JSON decoder should also throw.
            do {
                let val = try json.decode(type, from: jsonData)
                Issue.record("Expected decode failure (original JSON) for test \(name).\(ext), but got: \(val)", sourceLocation: sourceLocation)
            } catch { }
        case .malformed:
            // Invalid ES5 should remain invalid JSON5
            do {
                let val = try json5.decode(type, from: jsonData)
                Issue.record("Expected decode failure (JSON5) for test \(name).\(ext), but got: \(val)", sourceLocation: sourceLocation)
            } catch { }

            // Regular JSON decoder should also throw.
            do {
                let val = try json.decode(type, from: jsonData)
                Issue.record("Expected decode failure (original JSON) for test \(name).\(ext), but got: \(val)", sourceLocation: sourceLocation)
            } catch { }
        }
    }

    // Also tests non-JSON5 decoder against the non-JSON5 tests in this test suite.
    @Test func json5Spec() {
        // Expected successes:
        _run_json5SpecTest("arrays", "empty-array", testType: .json, type: [Bool].self)
        _run_json5SpecTest("arrays", "regular-array", testType: .json, type: [Bool?].self)
        _run_json5SpecTest("arrays", "trailing-comma-array", testType: .json5_foundationPermissiveJSON, type: [NullReader].self)

        _run_json5SpecTest("comments", "block-comment-following-array-element", testType: .json5, type: [Bool].self)
        _run_json5SpecTest("comments", "block-comment-following-top-level-value", testType: .json5, type: NullReader.self)
        _run_json5SpecTest("comments", "block-comment-in-string", testType: .json, type: String.self)
        _run_json5SpecTest("comments", "block-comment-preceding-top-level-value", testType: .json5, type: NullReader.self)
        _run_json5SpecTest("comments", "block-comment-with-asterisks", testType: .json5, type: Bool.self)
        _run_json5SpecTest("comments", "inline-comment-following-array-element", testType: .json5, type: [Bool].self)
        _run_json5SpecTest("comments", "inline-comment-following-top-level-value", testType: .json5, type: NullReader.self)
        _run_json5SpecTest("comments", "inline-comment-in-string", testType: .json, type: String.self)
        _run_json5SpecTest("comments", "inline-comment-preceding-top-level-value", testType: .json5, type: NullReader.self)

        _run_json5SpecTest("misc", "npm-package", testType: .json, type: JSON5Spec.NPMPackage.self)
        _run_json5SpecTest("misc", "npm-package", testType: .json5, type: JSON5Spec.NPMPackage.self)
        _run_json5SpecTest("misc", "readme-example", testType: .json5, type: JSON5Spec.ReadmeExample.self)
        _run_json5SpecTest("misc", "valid-whitespace", testType: .json5, type: [String:Bool].self)

        _run_json5SpecTest("new-lines", "comment-cr", testType: .json5, type: [String:String].self)
        _run_json5SpecTest("new-lines", "comment-crlf", testType: .json5, type: [String:String].self)
        _run_json5SpecTest("new-lines", "comment-lf", testType: .json5, type: [String:String].self)
        _run_json5SpecTest("new-lines", "escaped-cr", testType: .json5, type: [String:String].self)
        _run_json5SpecTest("new-lines", "escaped-crlf", testType: .json5, type: [String:String].self)
        _run_json5SpecTest("new-lines", "escaped-lf", testType: .json5, type: [String:String].self)

        _run_json5SpecTest("numbers", "float-leading-decimal-point", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "float-leading-zero", testType: .json, type: Double.self)
        _run_json5SpecTest("numbers", "float-trailing-decimal-point-with-integer-exponent", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "float-trailing-decimal-point", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "float-with-integer-exponent", testType: .json, type: Double.self)
        _run_json5SpecTest("numbers", "float", testType: .json, type: Double.self)
        _run_json5SpecTest("numbers", "hexadecimal-lowercase-letter", testType: .json5, type: UInt.self)
        _run_json5SpecTest("numbers", "hexadecimal-uppercase-x", testType: .json5, type: UInt.self)
        _run_json5SpecTest("numbers", "hexadecimal-with-integer-exponent", testType: .json5, type: UInt.self)
        _run_json5SpecTest("numbers", "hexadecimal", testType: .json5, type: UInt.self)
        _run_json5SpecTest("numbers", "infinity", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "integer-with-integer-exponent", testType: .json, type: Double.self)
        _run_json5SpecTest("numbers", "integer-with-negative-integer-exponent", testType: .json, type: Double.self)
        _run_json5SpecTest("numbers", "integer-with-negative-zero-integer-exponent", testType: .json, type: Int.self)
        _run_json5SpecTest("numbers", "integer-with-positive-integer-exponent", testType: .json, type: Int.self)
        _run_json5SpecTest("numbers", "integer-with-positive-zero-integer-exponent", testType: .json, type: Int.self)
        _run_json5SpecTest("numbers", "integer-with-zero-integer-exponent", testType: .json, type: Int.self)
        _run_json5SpecTest("numbers", "integer", testType: .json, type: Int.self)
        _run_json5SpecTest("numbers", "nan", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "negative-float-leading-decimal-point", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "negative-float-leading-zero", testType: .json, type: Double.self)
        _run_json5SpecTest("numbers", "negative-float-trailing-decimal-point", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "negative-float", testType: .json, type: Double.self)
        _run_json5SpecTest("numbers", "negative-hexadecimal", testType: .json5, type: Int.self)
        _run_json5SpecTest("numbers", "negative-infinity", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "negative-integer", testType: .json, type: Int.self)
        _run_json5SpecTest("numbers", "negative-zero-float-leading-decimal-point", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "negative-zero-float-trailing-decimal-point", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "negative-zero-hexadecimal", testType: .json5, type: Int.self)
        _run_json5SpecTest("numbers", "negative-zero-integer", testType: .json, type: Int.self)
        _run_json5SpecTest("numbers", "positive-integer", testType: .json5, type: Int.self)
        _run_json5SpecTest("numbers", "positive-zero-float-leading-decimal-point", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "positive-zero-float-trailing-decimal-point", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "positive-zero-float", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "positive-zero-hexadecimal", testType: .json5, type: Int.self)
        _run_json5SpecTest("numbers", "positive-zero-integer", testType: .json5, type: Int.self)
        _run_json5SpecTest("numbers", "zero-float-leading-decimal-point", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "zero-float-trailing-decimal-point", testType: .json5, type: Double.self)
        _run_json5SpecTest("numbers", "zero-float", testType: .json, type: Double.self)
        _run_json5SpecTest("numbers", "zero-hexadecimal", testType: .json5, type: Int.self)
        _run_json5SpecTest("numbers", "zero-integer-with-integer-exponent", testType: .json, type: Int.self)
        _run_json5SpecTest("numbers", "zero-integer", testType: .json, type: Int.self)

        _run_json5SpecTest("objects", "duplicate-keys", testType: .json, type: [String:Bool].self)
        _run_json5SpecTest("objects", "empty-object", testType: .json, type: [String:Bool].self)
        _run_json5SpecTest("objects", "reserved-unquoted-key", testType: .json5, type: [String:Bool].self)
        _run_json5SpecTest("objects", "single-quoted-key", testType: .json5, type: [String:String].self)
        _run_json5SpecTest("objects", "trailing-comma-object", testType: .json5_foundationPermissiveJSON, type: [String:String].self)
        _run_json5SpecTest("objects", "unquoted-keys", testType: .json5, type: [String:String].self)

        _run_json5SpecTest("strings", "escaped-single-quoted-string", testType: .json5, type: String.self)
        _run_json5SpecTest("strings", "multi-line-string", testType: .json5, type: String.self)
        _run_json5SpecTest("strings", "single-quoted-string", testType: .json5, type: String.self)

        _run_json5SpecTest("todo", "unicode-escaped-unquoted-key", testType: .json5, type: [String:String].self)
        _run_json5SpecTest("todo", "unicode-unquoted-key", testType: .json5, type: [String:String].self)

        // Expected failures:
        _run_json5SpecTest("arrays", "leading-comma-array", testType: .js, type: [Bool].self)
        _run_json5SpecTest("arrays", "lone-trailing-comma-array", testType: .js, type: [Bool].self)
        _run_json5SpecTest("arrays", "no-comma-array", testType: .malformed, type: [Bool].self)

        _run_json5SpecTest("comments", "top-level-block-comment", testType: .malformed, type: Bool.self)
        _run_json5SpecTest("comments", "top-level-inline-comment", testType: .malformed, type: Bool.self)
        _run_json5SpecTest("comments", "unterminated-block-comment", testType: .malformed, type: Bool.self)

        _run_json5SpecTest("misc", "empty", testType: .malformed, type: Bool.self)

        _run_json5SpecTest("numbers", "hexadecimal-empty", testType: .malformed, type: UInt.self)
        _run_json5SpecTest("numbers", "integer-with-float-exponent", testType: .malformed, type: Double.self)
        _run_json5SpecTest("numbers", "integer-with-hexadecimal-exponent", testType: .malformed, type: Double.self)
        _run_json5SpecTest("numbers", "integer-with-negative-float-exponent", testType: .malformed, type: Double.self)
        _run_json5SpecTest("numbers", "integer-with-negative-hexadecimal-exponent", testType: .malformed, type: Double.self)
        _run_json5SpecTest("numbers", "integer-with-positive-float-exponent", testType: .malformed, type: Double.self)
        _run_json5SpecTest("numbers", "integer-with-positive-hexadecimal-exponent", testType: .malformed, type: Double.self)
        _run_json5SpecTest("numbers", "lone-decimal-point", testType: .malformed, type: Double.self)
        _run_json5SpecTest("numbers", "negative-noctal", testType: .js, type: Int.self)
        _run_json5SpecTest("numbers", "negative-octal", testType: .malformed, type: Int.self)
        _run_json5SpecTest("numbers", "noctal-with-leading-octal-digit", testType: .js, type: Int.self)
        _run_json5SpecTest("numbers", "noctal", testType: .js, type: Int.self)
        _run_json5SpecTest("numbers", "octal", testType: .malformed, type: Int.self)
        _run_json5SpecTest("numbers", "positive-noctal", testType: .js, type: Int.self)
        _run_json5SpecTest("numbers", "positive-octal", testType: .malformed, type: Int.self)
        _run_json5SpecTest("numbers", "positive-zero-octal", testType: .malformed, type: Int.self)
        _run_json5SpecTest("numbers", "zero-octal", testType: .malformed, type: Int.self)

        _run_json5SpecTest("objects", "illegal-unquoted-key-number", testType: .malformed, type: [String:String].self)

        // The spec test disallows this case, but historically NSJSONSerialization has allowed it. Our new implementation is more up-to-spec.
        _run_json5SpecTest("objects", "illegal-unquoted-key-symbol", testType: .malformed, type: [String:String].self)

        _run_json5SpecTest("objects", "leading-comma-object", testType: .malformed, type: [String:String].self)
        _run_json5SpecTest("objects", "lone-trailing-comma-object", testType: .malformed, type: [String:String].self)
        _run_json5SpecTest("objects", "no-comma-object", testType: .malformed, type: [String:String].self)

        _run_json5SpecTest("strings", "unescaped-multi-line-string", testType: .malformed, type: String.self)

    }

    @Test func encodingDateISO8601() {
        let timestamp = Date(timeIntervalSince1970: 1000)
        let expectedJSON = "\"\(timestamp.formatted(.iso8601))\"".data(using: .utf8)!
  
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
    
    @Test func encodingDataBase64() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])

        let expectedJSON = "\"3q2+7w==\"".data(using: .utf8)!
        _testRoundTrip(of: data, expectedJSON: expectedJSON)

        // Optional data should encode the same way.
        _testRoundTrip(of: Optional(data), expectedJSON: expectedJSON)
    }
}

// MARK: - Decimal Tests
extension JSONEncoderTests {
    @Test func interceptDecimal() {
        let expectedJSON = "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".data(using: .utf8)!

        // Want to make sure we write out a JSON number, not the keyed encoding here.
        // 1e127 is too big to fit natively in a Double, too, so want to make sure it's encoded as a Decimal.
        let decimal = Decimal(sign: .plus, exponent: 127, significand: Decimal(1))
        _testRoundTrip(of: decimal, expectedJSON: expectedJSON)

        // Optional Decimals should encode the same way.
        _testRoundTrip(of: Optional(decimal), expectedJSON: expectedJSON)
    }

    @Test func hugeNumbers() throws {
        let json = "23456789012000000000000000000000000000000000000000000000000000000000000000000 "
        let data = json.data(using: .utf8)!

        let decimal = try JSONDecoder().decode(Decimal.self, from: data)
        let expected = Decimal(string: json)
        #expect(decimal == expected)
    }

    @Test func interceptLargeDecimal() {
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

    @Test func overlargeDecimal() {
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
    @Test func encodingDateFormatted() {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = .gmt

        let timestamp = Date(timeIntervalSince1970: 1000)
        let expectedJSON = "\"\(formatter.string(from: timestamp))\"".data(using: .utf8)!

        _testRoundTrip(of: timestamp,
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .formatted(formatter),
                       dateDecodingStrategy: .formatted(formatter))

        // Optional dates should encode the same way.
        _testRoundTrip(of: Optional(timestamp),
                       expectedJSON: expectedJSON,
                       dateEncodingStrategy: .formatted(formatter),
                       dateDecodingStrategy: .formatted(formatter))

        // So should wrapped dates.
        let expectedJSON_array = "[\"\(formatter.string(from: timestamp))\"]".data(using: .utf8)!
        _testRoundTrip(of: TopLevelArrayWrapper(timestamp),
                       expectedJSON: expectedJSON_array,
                       dateEncodingStrategy: .formatted(formatter),
                       dateDecodingStrategy: .formatted(formatter))
    }
}
#endif

// MARK: - .sortedKeys Tests
extension JSONEncoderTests {
    @Test func encodingTopLevelStructuredClass() {
        // Person is a class with multiple fields.
        let expectedJSON = "{\"email\":\"appleseed@apple.com\",\"name\":\"Johnny Appleseed\"}".data(using: .utf8)!
        let person = Person.testValue
        _testRoundTrip(of: person, expectedJSON: expectedJSON, outputFormatting: [.sortedKeys])
    }

    @Test func encodingOutputFormattingSortedKeys() {
        let expectedJSON = "{\"email\":\"appleseed@apple.com\",\"name\":\"Johnny Appleseed\"}".data(using: .utf8)!
        let person = Person.testValue
        _testRoundTrip(of: person, expectedJSON: expectedJSON, outputFormatting: [.sortedKeys])
    }

    @Test func encodingOutputFormattingPrettyPrintedSortedKeys() {
        let expectedJSON = "{\n  \"email\" : \"appleseed@apple.com\",\n  \"name\" : \"Johnny Appleseed\"\n}".data(using: .utf8)!
        let person = Person.testValue
        _testRoundTrip(of: person, expectedJSON: expectedJSON, outputFormatting: [.prettyPrinted, .sortedKeys])
    }

    @Test func encodingSortedKeys() {
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

        _testRoundTrip(of: dict, expectedJSON: #"{"FOO":2,"Foo":1,"Foo11":8,"Foo2":5,"bar":10,"foo":3,"foo1":4,"foo12":7,"foo3":6,"føo":9}"#.data(using: .utf8)!, outputFormatting: [.sortedKeys])
    }

    @Test func encodingSortedKeysStableOrdering() {
        // We want to make sure that keys of different length (but with identical prefixes) always sort in a stable way, regardless of their hash ordering.
        var dict = ["AAA" : 1, "AAAAAAB" : 2]
        var expectedJSONString = "{\"AAA\":1,\"AAAAAAB\":2}"
        _testRoundTrip(of: dict, expectedJSON: expectedJSONString.data(using: .utf8)!, outputFormatting: [.sortedKeys])

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

        _testRoundTrip(of: dict, expectedJSON: expectedJSONString.data(using: .utf8)!, outputFormatting: [.sortedKeys])
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
        let expectedJSON = "{\"top\":{\"first\":\"Johnny Appleseed\",\"second\":\"appleseed@apple.com\"}}".data(using: .utf8)!
        _testRoundTrip(of: model, expectedJSON: expectedJSON, outputFormatting: [.sortedKeys])
    }

    @Test func redundantKeyedContainer() throws {
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

    @Test func singleValueDictionaryAmendedByContainer() throws {
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
    @Test func interceptURL() {
        // Want to make sure JSONEncoder writes out single-value URLs, not the keyed encoding.
        let expectedJSON = "\"http:\\/\\/swift.org\"".data(using: .utf8)!
        let url = URL(string: "http://swift.org")!
        _testRoundTrip(of: url, expectedJSON: expectedJSON)

        // Optional URLs should encode the same way.
        _testRoundTrip(of: Optional(url), expectedJSON: expectedJSON)
    }

    @Test func interceptURLWithoutEscapingOption() {
        // Want to make sure JSONEncoder writes out single-value URLs, not the keyed encoding.
        let expectedJSON = "\"http://swift.org\"".data(using: .utf8)!
        let url = URL(string: "http://swift.org")!
        _testRoundTrip(of: url, expectedJSON: expectedJSON, outputFormatting: [.withoutEscapingSlashes])

        // Optional URLs should encode the same way.
        _testRoundTrip(of: Optional(url), expectedJSON: expectedJSON, outputFormatting: [.withoutEscapingSlashes])
    }
}

// MARK: - Helper Global Functions
func expectEqualPaths(_ lhs: [CodingKey], _ rhs: [CodingKey], _ prefix: String, sourceLocation: SourceLocation = #_sourceLocation) {
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
    }

    #expect(key1.stringValue == key2.stringValue, "\(prefix) CodingKey.stringValue mismatch: \(type(of: key1))('\(key1.stringValue)') != \(type(of: key2))('\(key2.stringValue)')", sourceLocation: sourceLocation)
    }
}

// MARK: - Test Types
/* FIXME: Import from %S/Inputs/Coding/SharedTypes.swift somehow. */

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
  let website: URL?


  init(name: String, email: String, website: URL? = nil) {
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

  init(name: String, email: String, website: URL? = nil, id: Int) {
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
  let values: [String : Int]

  init(values: [String : Int]) {
    self.values = values
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    values = try container.decode([String : Int].self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(values)
  }

  static func ==(_ lhs: Mapping, _ rhs: Mapping) -> Bool {
    return lhs === rhs || lhs.values == rhs.values
  }

  static var testValue: Mapping {
    return Mapping(values: ["Apple": 42,
                            "localhost": 127])
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
      expectEqualPaths(encoder.codingPath, [], "Top-level Encoder's codingPath changed.")
      expectEqualPaths(topLevelContainer.codingPath, [], "New first-level keyed container has non-empty codingPath.")

      let superEncoder = topLevelContainer.superEncoder(forKey: .a)
      expectEqualPaths(encoder.codingPath, [], "Top-level Encoder's codingPath changed.")
      expectEqualPaths(topLevelContainer.codingPath, [], "First-level keyed container's codingPath changed.")
      expectEqualPaths(superEncoder.codingPath, [TopLevelCodingKeys.a], "New superEncoder had unexpected codingPath.")
      _testNestedContainers(in: superEncoder, baseCodingPath: [TopLevelCodingKeys.a])
    } else {
      _testNestedContainers(in: encoder, baseCodingPath: [])
    }
  }

  func _testNestedContainers(in encoder: Encoder, baseCodingPath: [CodingKey]) {
    expectEqualPaths(encoder.codingPath, baseCodingPath, "New encoder has non-empty codingPath.")

    // codingPath should not change upon fetching a non-nested container.
    var firstLevelContainer = encoder.container(keyedBy: TopLevelCodingKeys.self)
    expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
    expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "New first-level keyed container has non-empty codingPath.")

    // Nested Keyed Container
    do {
      // Nested container for key should have a new key pushed on.
      var secondLevelContainer = firstLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self, forKey: .a)
      expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
      expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
      expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "New second-level keyed container had unexpected codingPath.")

      // Inserting a keyed container should not change existing coding paths.
      let thirdLevelContainerKeyed = secondLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self, forKey: .one)
      expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
      expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
      expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "Second-level keyed container's codingPath changed.")
      expectEqualPaths(thirdLevelContainerKeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.a, IntermediateCodingKeys.one], "New third-level keyed container had unexpected codingPath.")

      // Inserting an unkeyed container should not change existing coding paths.
      let thirdLevelContainerUnkeyed = secondLevelContainer.nestedUnkeyedContainer(forKey: .two)
      expectEqualPaths(encoder.codingPath, baseCodingPath + [], "Top-level Encoder's codingPath changed.")
      expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath + [], "First-level keyed container's codingPath changed.")
      expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "Second-level keyed container's codingPath changed.")
      expectEqualPaths(thirdLevelContainerUnkeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.a, IntermediateCodingKeys.two], "New third-level unkeyed container had unexpected codingPath.")
    }

    // Nested Unkeyed Container
    do {
      // Nested container for key should have a new key pushed on.
      var secondLevelContainer = firstLevelContainer.nestedUnkeyedContainer(forKey: .b)
      expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
      expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
      expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "New second-level keyed container had unexpected codingPath.")

      // Appending a keyed container should not change existing coding paths.
      let thirdLevelContainerKeyed = secondLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self)
      expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
      expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
      expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "Second-level unkeyed container's codingPath changed.")
      expectEqualPaths(thirdLevelContainerKeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.b, _TestKey(index: 0)], "New third-level keyed container had unexpected codingPath.")

      // Appending an unkeyed container should not change existing coding paths.
      let thirdLevelContainerUnkeyed = secondLevelContainer.nestedUnkeyedContainer()
      expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
      expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
      expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "Second-level unkeyed container's codingPath changed.")
      expectEqualPaths(thirdLevelContainerUnkeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.b, _TestKey(index: 1)], "New third-level unkeyed container had unexpected codingPath.")
    }
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

// MARK: - Helper Types

/// A key type which can take on any string or integer value.
/// This needs to mirror _CodingKey.
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

fileprivate struct FloatNaNPlaceholder : Codable, Equatable {
  init() {}

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(Float.nan)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let float = try container.decode(Float.self)
    if !float.isNaN {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Couldn't decode NaN."))
    }
  }

  static func ==(_ lhs: FloatNaNPlaceholder, _ rhs: FloatNaNPlaceholder) -> Bool {
    return true
  }
}

fileprivate struct DoubleNaNPlaceholder : Codable, Equatable {
  init() {}

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(Double.nan)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let double = try container.decode(Double.self)
    if !double.isNaN {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Couldn't decode NaN."))
    }
  }

  static func ==(_ lhs: DoubleNaNPlaceholder, _ rhs: DoubleNaNPlaceholder) -> Bool {
    return true
  }
}

internal protocol DecodeIfPresentAllTypesConfig {
    static var useKeyed: Bool { get }
    static var encodeNulls: Bool { get }
}
internal struct UseKeyed: DecodeIfPresentAllTypesConfig {
    static let useKeyed = true
    static let encodeNulls = true
}
internal struct UseUnkeyed: DecodeIfPresentAllTypesConfig {
    static let useKeyed = false
    static let encodeNulls = true
}
internal typealias KeyedEncodeWithNulls = UseKeyed
internal typealias UnkeyedEncodeWithNulls = UseUnkeyed
internal struct KeyedEncodeWithoutNulls: DecodeIfPresentAllTypesConfig {
    static let useKeyed = true
    static let encodeNulls = false
}
internal struct UnkeyedEncodeWithoutNulls: DecodeIfPresentAllTypesConfig {
    static let useKeyed = false
    static let encodeNulls = false
}

internal struct DecodeIfPresentAllTypes<Config: DecodeIfPresentAllTypesConfig>: Codable, Equatable {
    let bool: Bool?
    let string: String?
    let i: Int?
    let i8: Int8?
    let i16: Int16?
    let i32: Int32?
    let i64: Int64?
    let u: UInt?
    let u8: UInt8?
    let u16: UInt16?
    let u32: UInt32?
    let u64: UInt64?
    let float: Float?
    let double: Double?
    let other: [Int]?

    init(bool: Bool?, string: String?, i: Int?, i8: Int8?, i16: Int16?, i32: Int32?, i64: Int64?, u: UInt?, u8: UInt8?, u16: UInt16?, u32: UInt32?, u64: UInt64?, float: Float?, double: Double?, other: [Int]?) {
        self.bool = bool
        self.string = string
        self.i = i
        self.i8 = i8
        self.i16 = i16
        self.i32 = i32
        self.i64 = i64
        self.u = u
        self.u8 = u8
        self.u16 = u16
        self.u32 = u32
        self.u64 = u64
        self.float = float
        self.double = double
        self.other = other
    }

    enum CodingKeys: String, CodingKey {
        case bool
        case string
        case i
        case i8
        case i16
        case i32
        case i64
        case u
        case u8
        case u16
        case u32
        case u64
        case float
        case double
        case other
    }

    func encode(to encoder: Encoder) throws {
        switch (Config.useKeyed, Config.encodeNulls) {
        case (true, true):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(bool, forKey: .bool)
            try container.encode(string, forKey: .string)
            try container.encode(i, forKey: .i)
            try container.encode(i8, forKey: .i8)
            try container.encode(i16, forKey: .i16)
            try container.encode(i32, forKey: .i32)
            try container.encode(i64, forKey: .i64)
            try container.encode(u, forKey: .u)
            try container.encode(u8, forKey: .u8)
            try container.encode(u16, forKey: .u16)
            try container.encode(u32, forKey: .u32)
            try container.encode(u64, forKey: .u64)
            try container.encode(float, forKey: .float)
            try container.encode(double, forKey: .double)
            try container.encode(other, forKey: .other)
        case (true, false):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(bool, forKey: .bool)
            try container.encodeIfPresent(string, forKey: .string)
            try container.encodeIfPresent(i, forKey: .i)
            try container.encodeIfPresent(i8, forKey: .i8)
            try container.encodeIfPresent(i16, forKey: .i16)
            try container.encodeIfPresent(i32, forKey: .i32)
            try container.encodeIfPresent(i64, forKey: .i64)
            try container.encodeIfPresent(u, forKey: .u)
            try container.encodeIfPresent(u8, forKey: .u8)
            try container.encodeIfPresent(u16, forKey: .u16)
            try container.encodeIfPresent(u32, forKey: .u32)
            try container.encodeIfPresent(u64, forKey: .u64)
            try container.encodeIfPresent(float, forKey: .float)
            try container.encodeIfPresent(double, forKey: .double)
            try container.encodeIfPresent(other, forKey: .other)
        case (false, true):
            var container = encoder.unkeyedContainer()
            try container.encode(bool)
            try container.encode(string)
            try container.encode(i)
            try container.encode(i8)
            try container.encode(i16)
            try container.encode(i32)
            try container.encode(i64)
            try container.encode(u)
            try container.encode(u8)
            try container.encode(u16)
            try container.encode(u32)
            try container.encode(u64)
            try container.encode(float)
            try container.encode(double)
            try container.encode(other)
        case (false, false):
            var container = encoder.unkeyedContainer()
            if let bool { try container.encode(bool) }
            if let string { try container.encode(string) }
            if let i { try container.encode(i) }
            if let i8 { try container.encode(i8) }
            if let i16 { try container.encode(i16) }
            if let i32 { try container.encode(i32) }
            if let i64 { try container.encode(i64) }
            if let u { try container.encode(u) }
            if let u8 { try container.encode(u8) }
            if let u16 { try container.encode(u16) }
            if let u32 { try container.encode(u32) }
            if let u64 { try container.encode(u64) }
            if let float { try container.encode(float) }
            if let double { try container.encode(double) }
            if let other { try container.encode(other) }
        }
    }

    init(from decoder: Decoder) throws {
        switch Config.useKeyed {
        case true:
            let container = try decoder.container(keyedBy: CodingKeys.self)
            bool = try container.decodeIfPresent(Bool.self, forKey: .bool)
            string = try container.decodeIfPresent(String.self, forKey: .string)
            i = try container.decodeIfPresent(Int.self, forKey: .i)
            i8 = try container.decodeIfPresent(Int8.self, forKey: .i8)
            i16 = try container.decodeIfPresent(Int16.self, forKey: .i16)
            i32 = try container.decodeIfPresent(Int32.self, forKey: .i32)
            i64 = try container.decodeIfPresent(Int64.self, forKey: .i64)
            u = try container.decodeIfPresent(UInt.self, forKey: .u)
            u8 = try container.decodeIfPresent(UInt8.self, forKey: .u8)
            u16 = try container.decodeIfPresent(UInt16.self, forKey: .u16)
            u32 = try container.decodeIfPresent(UInt32.self, forKey: .u32)
            u64 = try container.decodeIfPresent(UInt64.self, forKey: .u64)
            float = try container.decodeIfPresent(Float.self, forKey: .float)
            double = try container.decodeIfPresent(Double.self, forKey: .double)
            other = try container.decodeIfPresent([Int].self, forKey: .other)
        case false:
            var container = try decoder.unkeyedContainer()
            bool = try container.decodeIfPresent(Bool.self)
            string = try container.decodeIfPresent(String.self)
            i = try container.decodeIfPresent(Int.self)
            i8 = try container.decodeIfPresent(Int8.self)
            i16 = try container.decodeIfPresent(Int16.self)
            i32 = try container.decodeIfPresent(Int32.self)
            i64 = try container.decodeIfPresent(Int64.self)
            u = try container.decodeIfPresent(UInt.self)
            u8 = try container.decodeIfPresent(UInt8.self)
            u16 = try container.decodeIfPresent(UInt16.self)
            u32 = try container.decodeIfPresent(UInt32.self)
            u64 = try container.decodeIfPresent(UInt64.self)
            float = try container.decodeIfPresent(Float.self)
            double = try container.decodeIfPresent(Double.self)
            other = try container.decodeIfPresent([Int].self)
        }
    }

    static var allOnes: Self { .init(bool: true, string: "1", i: 1, i8: 1, i16: 1, i32: 1, i64: 1, u: 1, u8: 1, u16: 1, u32: 1, u64: 1, float: 1, double: 1, other: [1]) }
    static var allNils: Self { .init(bool: nil, string: nil, i: nil, i8: nil, i16: nil, i32: nil, i64: nil, u: nil, u8: nil, u16: nil, u32: nil, u64: nil, float: nil, double: nil, other: nil) }
}

fileprivate enum EitherDecodable<T : Decodable, U : Decodable> : Decodable {
  case t(T)
  case u(U)

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    do {
      self = .t(try container.decode(T.self))
    } catch {
      self = .u(try container.decode(U.self))
    }
  }
}

struct NullReader : Decodable, Equatable {
    enum NullError : String, Error {
        case expectedNull = "Expected a null value"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        guard c.decodeNil() else {
            throw NullError.expectedNull
        }
    }
}

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
