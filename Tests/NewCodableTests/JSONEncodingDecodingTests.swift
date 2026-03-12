//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//


import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(CRT)
import CRT
#elseif os(WASI)
import WASILibc
#endif

import NewCodable

// Temporarily .serailized to try working around a test issue.
@Suite("JSON Encoding/Decoding", .serialized)
struct JSONEncodingDecodingTests {
    
    // MARK: - Test Infrastructure
    
    /// Test round-trip encoding and decoding
    func _testRoundTrip<T>(
        of value: T,
        expectedJSON: Data? = nil,
        encoderOptions: NewJSONEncoder.Options = .init(),
        decoderOptions: NewJSONDecoder.Options = .init(),
        sourceLocation: SourceLocation = #_sourceLocation
    ) where T: JSONEncodable & JSONDecodable & Equatable {
        let data: Data
        do {
            let encoder = NewJSONEncoder(options: encoderOptions)
            data = try encoder.encode(value)
        } catch {
            Issue.record("Failed to encode \(T.self) to JSON: \(error)", sourceLocation: sourceLocation)
            return
        }
        
        if let expectedJSON {
            #expect(data == expectedJSON, sourceLocation: sourceLocation)
        }
        
        let decoded: T
        do {
            let decoder = NewJSONDecoder(options: decoderOptions)
            decoded = try decoder.decode(T.self, from: data)
        } catch {
            Issue.record("Failed to decode \(T.self) from JSON: \(error)", sourceLocation: sourceLocation)
            return
        }
        
        #expect(decoded == value, sourceLocation: sourceLocation)
    }
    
    /// Test encoding only
    func _testEncoding<T>(
        _ value: T,
        expectedJSON: Data,
        encoderOptions: NewJSONEncoder.Options = .init(),
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws where T: JSONEncodable {
        let encoder = NewJSONEncoder(options: encoderOptions)
        let data = try encoder.encode(value)
        #expect(data == expectedJSON, sourceLocation: sourceLocation)
    }
    
    /// Test decoding only
    func _testDecoding<T>(
        _ type: T.Type,
        from json: Data,
        expectedValue: T,
        decoderOptions: NewJSONDecoder.Options = .init(),
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws where T: JSONDecodable & Equatable {
        let decoder = NewJSONDecoder(options: decoderOptions)
        let decoded = try decoder.decode(type, from: json)
        #expect(decoded == expectedValue, sourceLocation: sourceLocation)
    }
    
    /// Test that encoding/decoding throws expected errors
    func _testEncodeFailure<T>(
        of value: T,
        encoderOptions: NewJSONEncoder.Options = .init(),
        sourceLocation: SourceLocation = #_sourceLocation
    ) where T: JSONEncodable {
        let encoder = NewJSONEncoder(options: encoderOptions)
        #expect(throws: CodingError.Encoding.self) {
            try encoder.encode(value)
        }
    }
    
    func _testDecodingFailure<T>(
        _ type: T.Type,
        from json: Data,
        decoderOptions: NewJSONDecoder.Options = .init(),
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws where T: JSONDecodable {
        let decoder = NewJSONDecoder(options: decoderOptions)
        #expect(throws: CodingError.Decoding.self) {
            try decoder.decode(type, from: json)
        }
    }
    
    func _testRoundTripTypeCoercionFailure<T,U>(of value: T, as type: U.Type, sourceLocation: SourceLocation = #_sourceLocation) where T : JSONCodable, U : JSONCodable {
        let error = #expect(throws: CodingError.Decoding.self, "Coercion from \(T.self) to \(U.self) was expected to fail.", sourceLocation: sourceLocation) {
            let data = try NewJSONEncoder().encode(value)
            let _ = try NewJSONDecoder().decode(U.self, from: data)
        }
        if let error {
            // TODO: Fix error type for integers.
            let isTypeMismatch = switch error.kind { case .typeMismatch: true; default: false }
            #expect(isTypeMismatch == true, "error is: \(error)")
        }
    }
    
    // MARK: - Test Structures
    
    struct SimpleStruct: JSONEncodable, JSONDecodable, Equatable {
        let name: String
        let age: Int
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary(elementCount: 2) { dictEncoder throws(CodingError.Encoding) in
                try dictEncoder.encode(key: "name", value: name)
                try dictEncoder.encode(key: "age", value: age)
            }
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> SimpleStruct {
            try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var name: String?
                var age: Int?
                
                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "name": name = try valueDecoder.decode(String.self)
                    case "age": age = try valueDecoder.decode(Int.self)
                    default: break // Skip unknown keys
                    }
                    return false
                }
                
                guard let name, let age else {
                    throw CodingError.Decoding(kind: .dataCorrupted)
                }
                return SimpleStruct(name: name, age: age)
            }
        }
    }
    
    struct NestedStruct: JSONEncodable, JSONDecodable, Equatable {
        let person: SimpleStruct
        let metadata: [String: String]
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary(elementCount: 2) { dictEncoder throws(CodingError.Encoding) in
                try dictEncoder.encode(key: "person", value: person)
                try dictEncoder.encode(key: "metadata", value: metadata)
            }
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> NestedStruct {
            try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var person: SimpleStruct?
                var metadata: [String: String]?
                
                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "person": person = try valueDecoder.decode(SimpleStruct.self)
                    case "metadata": metadata = try valueDecoder.decode([String: String].self)
                    default: break
                    }
                    return false
                }
                
                guard let person, let metadata else {
                    throw CodingError.Decoding(kind: .dataCorrupted)
                }
                return NestedStruct(person: person, metadata: metadata)
            }
        }
    }
    
    struct EmptyStruct: JSONEncodable, JSONDecodable, Equatable {
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary(elementCount: 0) { _ in
                // Empty dictionary
            }
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> EmptyStruct {
            try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                // Consume any fields but ignore them
                try structDecoder.decodeEachKeyAndValue { _, _ in
                    return false // Keep going to consume all fields
                }
                return EmptyStruct()
            }
        }
        
        static func == (lhs: EmptyStruct, rhs: EmptyStruct) -> Bool {
            return true
        }
    }
    
    final class EmptyClass: JSONEncodable, JSONDecodable, Equatable {
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary(elementCount: 0) { _ in
                // Empty dictionary
            }
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> EmptyClass {
            try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                // Consume any fields but ignore them
                try structDecoder.decodeEachKeyAndValue { _, _ in
                    return false // Keep going to consume all fields
                }
                return EmptyClass()
            }
        }
        
        static func == (lhs: EmptyClass, rhs: EmptyClass) -> Bool {
            return true
        }
    }
    
    /// A simple on-off switch type that encodes as a single Bool value.
    enum Switch: JSONEncodable, JSONDecodable, Equatable {
        case off
        case on
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            switch self {
            case .off: try encoder.encode(false)
            case .on: try encoder.encode(true)
            }
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Switch {
            let value = try decoder.decode(Bool.self)
            return value ? .on : .off
        }
    }
    
    /// A simple timestamp type that encodes as a single Double value.
    struct Timestamp: JSONEncodable, JSONDecodable, Equatable {
        let value: Double
        
        init(_ value: Double) {
            self.value = value
        }
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encode(value)
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Timestamp {
            let value = try decoder.decode(Double.self)
            return Timestamp(value)
        }
        
        static func == (lhs: Timestamp, rhs: Timestamp) -> Bool {
            return lhs.value == rhs.value
        }
    }
    
    /// A simple referential counter type that encodes as a single Int value.
    final class Counter: JSONEncodable, JSONDecodable, Equatable {
        var count: Int = 0
        
        init() {}
        
        init(count: Int) {
            self.count = count
        }
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encode(count)
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Counter {
            let count = try decoder.decode(Int.self)
            return Counter(count: count)
        }
        
        static func == (lhs: Counter, rhs: Counter) -> Bool {
            return lhs === rhs || lhs.count == rhs.count
        }
    }
    
    /// A simple address type that encodes as a dictionary of values.
    struct Address: JSONEncodable, JSONDecodable, Equatable {
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
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary(elementCount: 5) { dictEncoder throws(CodingError.Encoding) in
                try dictEncoder.encode(key: "street", value: street)
                try dictEncoder.encode(key: "city", value: city)
                try dictEncoder.encode(key: "state", value: state)
                try dictEncoder.encode(key: "zipCode", value: zipCode)
                try dictEncoder.encode(key: "country", value: country)
            }
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Address {
            try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var street: String?
                var city: String?
                var state: String?
                var zipCode: Int?
                var country: String?
                
                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "street": street = try valueDecoder.decode(String.self)
                    case "city": city = try valueDecoder.decode(String.self)
                    case "state": state = try valueDecoder.decode(String.self)
                    case "zipCode": zipCode = try valueDecoder.decode(Int.self)
                    case "country": country = try valueDecoder.decode(String.self)
                    default: break // Skip unknown keys
                    }
                    return false
                }
                
                guard let street, let city, let state, let zipCode, let country else {
                    throw CodingError.Decoding(kind: .dataCorrupted)
                }
                return Address(street: street, city: city, state: state, zipCode: zipCode, country: country)
            }
        }
        
        static func == (lhs: Address, rhs: Address) -> Bool {
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
    final class Person: JSONEncodable, JSONDecodable, Equatable {
        let name: String
        let email: String
        let website: String?
        
        init(name: String, email: String, website: String? = nil) {
            self.name = name
            self.email = email
            self.website = website
        }
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary(elementCount: 3) { dictEncoder throws(CodingError.Encoding) in
                try dictEncoder.encode(key: "name", value: name)
                try dictEncoder.encode(key: "email", value: email)
                try dictEncoder.encode(key: "website", value: website)
            }
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Person {
            try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var name: String?
                var email: String?
                var website: String? = nil
                
                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "name": name = try valueDecoder.decode(String.self)
                    case "email": email = try valueDecoder.decode(String.self)
                    case "website": website = try valueDecoder.decode(String?.self)
                    default: break
                    }
                    return false
                }
                
                guard let name, let email else {
                    throw CodingError.Decoding(kind: .dataCorrupted)
                }
                return Person(name: name, email: email, website: website)
            }
        }
        
        func isEqual(_ other: Person) -> Bool {
            return self.name == other.name &&
            self.email == other.email &&
            self.website == other.website
        }
        
        static func == (lhs: Person, rhs: Person) -> Bool {
            return lhs.isEqual(rhs)
        }
        
        class var testValue: Person {
            return Person(name: "Johnny Appleseed", email: "appleseed@apple.com")
        }
    }
    
    /// A standalone employee type (flattened from inheritance).
    // Note: This was originally a subclass of Person.
    final class Employee: JSONEncodable, JSONDecodable, Equatable {
        let name: String
        let email: String
        let website: URL?
        let id: Int
        
        init(name: String, email: String, website: URL? = nil, id: Int) {
            self.name = name
            self.email = email
            self.website = website
            self.id = id
        }
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary(elementCount: 4) { dictEncoder throws(CodingError.Encoding) in
                try dictEncoder.encode(key: "name", value: name)
                try dictEncoder.encode(key: "email", value: email)
                try dictEncoder.encode(key: "website", value: website)
                try dictEncoder.encode(key: "id", value: id)
            }
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Employee {
            try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var name: String?
                var email: String?
                var website: URL? = nil
                var id: Int?
                
                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "name": name = try valueDecoder.decode(String.self)
                    case "email": email = try valueDecoder.decode(String.self)
                    case "website": website = try valueDecoder.decode(URL?.self)
                    case "id": id = try valueDecoder.decode(Int.self)
                    default: break
                    }
                    return false
                }
                
                guard let name, let email, let id else {
                    throw CodingError.Decoding(kind: .dataCorrupted)
                }
                return Employee(name: name, email: email, website: website, id: id)
            }
        }
        
        func isEqual(_ other: Employee) -> Bool {
            return self.name == other.name &&
            self.email == other.email &&
            self.website == other.website &&
            self.id == other.id
        }
        
        static func == (lhs: Employee, rhs: Employee) -> Bool {
            return lhs.isEqual(rhs)
        }
        
        class var testValue: Employee {
            return Employee(name: "Johnny Appleseed", email: "appleseed@apple.com", id: 42)
        }
    }
    
    /// A simple company struct which encodes as a dictionary of nested values.
    struct Company: JSONEncodable, JSONDecodable, Equatable {
        let address: Address
        var employees: [Employee]
        
        init(address: Address, employees: [Employee]) {
            self.address = address
            self.employees = employees
        }
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary(elementCount: 2) { dictEncoder throws(CodingError.Encoding) in
                try dictEncoder.encode(key: "address", value: address)
                try dictEncoder.encode(key: "employees", value: employees)
            }
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Company {
            try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var address: Address?
                var employees: [Employee]?
                
                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "address": address = try valueDecoder.decode(Address.self)
                    case "employees": employees = try valueDecoder.decode([Employee].self)
                    default: break
                    }
                    return false
                }
                
                guard let address, let employees else {
                    throw CodingError.Decoding(kind: .dataCorrupted)
                }
                return Company(address: address, employees: employees)
            }
        }
        
        static func == (lhs: Company, rhs: Company) -> Bool {
            return lhs.address == rhs.address && lhs.employees == rhs.employees
        }
        
        static var testValue: Company {
            return Company(address: Address.testValue, employees: [Employee.testValue])
        }
    }
    
    /// An enum type which decodes from Bool?.
    enum EnhancedBool: JSONEncodable, JSONDecodable, Equatable {
        case `true`
        case `false`
        case fileNotFound
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            switch self {
            case .true: try encoder.encode(true)
            case .false: try encoder.encode(false)
            case .fileNotFound: try encoder.encodeNil()
            }
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> EnhancedBool {
            var result: EnhancedBool = .fileNotFound
            try decoder.decodeOptional { valueDecoder throws(CodingError.Decoding) in
                let value = try valueDecoder.decode(Bool.self)
                result = value ? .true : .false
            }
            return result
        }
    }
    
    /// A type which encodes as an array directly through a single value.
    struct Numbers: JSONEncodable, JSONDecodable, Equatable {
        let values = [4, 8, 15, 16, 23, 42]
        
        init() {}
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encode(values)
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Numbers {
            let decodedValues = try decoder.decode([Int].self)
            let expectedValues = [4, 8, 15, 16, 23, 42]
            guard decodedValues == expectedValues else {
                throw CodingError.Decoding(kind: .dataCorrupted)
            }
            return Numbers()
        }
        
        static func == (lhs: Numbers, rhs: Numbers) -> Bool {
            return lhs.values == rhs.values
        }
        
        static var testValue: Numbers {
            return Numbers()
        }
    }
    
    /// A type which encodes as a dictionary directly through a single value.
    final class Mapping: JSONEncodable, JSONDecodable, Equatable {
        let values: [String: Int]
        
        init(values: [String: Int]) {
            self.values = values
        }
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encode(values)
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Mapping {
            let values = try decoder.decode([String: Int].self)
            return Mapping(values: values)
        }
        
        static func == (lhs: Mapping, rhs: Mapping) -> Bool {
            return lhs === rhs || lhs.values == rhs.values
        }
        
        static var testValue: Mapping {
            return Mapping(values: ["Apple": 42,
                                    "localhost": 127])
        }
    }
    
    // MARK: - Helper Functions
    private var _jsonEmptyDictionary: Data {
        return "{}".data(using: .utf8)!
    }
    
    fileprivate struct FloatNaNPlaceholder : JSONEncodable, JSONDecodable, Equatable {
        init() {}
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encode(Float.nan)
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> FloatNaNPlaceholder {
            let float = try decoder.decode(Float.self)
            if !float.isNaN {
                throw CodingError.Decoding(kind: .dataCorrupted)
            }
            return FloatNaNPlaceholder()
        }
        
        static func ==(_ lhs: FloatNaNPlaceholder, _ rhs: FloatNaNPlaceholder) -> Bool {
            return true
        }
    }
    
    fileprivate struct DoubleNaNPlaceholder : JSONEncodable, JSONDecodable, Equatable {
        init() {}
        
        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encode(Double.nan)
        }
        
        static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> DoubleNaNPlaceholder {
            let double = try decoder.decode(Double.self)
            if !double.isNaN {
                throw CodingError.Decoding(kind: .dataCorrupted)
            }
            return DoubleNaNPlaceholder()
        }
        
        static func ==(_ lhs: DoubleNaNPlaceholder, _ rhs: DoubleNaNPlaceholder) -> Bool {
            return true
        }
    }
    
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
        let result1 = String(data: try NewJSONEncoder().encode(a), encoding: .utf8)
        #expect(result1 == "[1,2,3]")
        
        let b : [Int] = []
        let result2 = String(data: try NewJSONEncoder().encode(b), encoding: .utf8)
        #expect(result2 == "[]")
    }
    
    // TODO: Test Configurations
    //    @Test func encodingTopLevelWithConfiguration() throws {
    //        // CodableTypeWithConfiguration is a struct that conforms to CodableWithConfiguration
    //        let value = CodableTypeWithConfiguration.testValue
    //        let encoder = JSONEncoder()
    //        let decoder = JSONDecoder()
    //
    //        var decoded = try decoder.decode(CodableTypeWithConfiguration.self, from: try encoder.encode(value, configuration: .init(1)), configuration: .init(1))
    //        #expect(decoded == value)
    //        decoded = try decoder.decode(CodableTypeWithConfiguration.self, from: try encoder.encode(value, configuration: CodableTypeWithConfiguration.ConfigProviding.self), configuration: CodableTypeWithConfiguration.ConfigProviding.self)
    //        #expect(decoded == value)
    //    }
    
    // MARK: - Date Strategy Tests
    
    // TODO: Date support
    //    @Test func encodingDateSecondsSince1970() {
    //        // Cannot encode an arbitrary number of seconds since we've lost precision since 1970.
    //        let seconds = 1000.0
    //        let expectedJSON = "1000".data(using: .utf8)!
    //
    //        _testRoundTrip(of: Date(timeIntervalSince1970: seconds),
    //                       expectedJSON: expectedJSON,
    //                       encoderOptions: .init(dateEncodingStrategy: .secondsSince1970),
    //                       decoderOptions: .init(dateEncodingStrategy: .secondsSince1970))
    //
    //        // Optional dates should encode the same way.
    //        _testRoundTrip(of: Optional(Date(timeIntervalSince1970: seconds)),
    //                       expectedJSON: expectedJSON,
    //                       encoderOptions: .init(dateEncodingStrategy: .secondsSince1970),
    //                       decoderOptions: .init(dateEncodingStrategy: .secondsSince1970))
    //    }
    //
    //    @Test func encodingDateMillisecondsSince1970() {
    //        // Cannot encode an arbitrary number of seconds since we've lost precision since 1970.
    //        let seconds = 1000.0
    //        let expectedJSON = "1000000".data(using: .utf8)!
    //
    //        _testRoundTrip(of: Date(timeIntervalSince1970: seconds),
    //                       expectedJSON: expectedJSON,
    //                       encoderOptions: .init(dateEncodingStrategy: .millisecondsSince1970),
    //                       decoderOptions: .init(dateEncodingStrategy: .millisecondsSince1970))
    //
    //        // Optional dates should encode the same way.
    //        _testRoundTrip(of: Optional(Date(timeIntervalSince1970: seconds)),
    //                       expectedJSON: expectedJSON,
    //                       encoderOptions: .init(dateEncodingStrategy: .millisecondsSince1970),
    //                       decoderOptions: .init(dateEncodingStrategy: .millisecondsSince1970))
    //
    //    }
    
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
        _testEncodeFailure(of: Optional(Float.infinity))
        _testEncodeFailure(of: Optional(-Float.infinity))
        _testEncodeFailure(of: Optional(Float.nan))
        
        _testEncodeFailure(of: Optional(Double.infinity))
        _testEncodeFailure(of: Optional(-Double.infinity))
        _testEncodeFailure(of: Optional(Double.nan))
    }
    
    @Test func encodingNonConformingFloatStrings() {
        let encodingStrategy: NewJSONEncoder.Options.NonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN")
        let decodingStrategy: NewJSONDecoder.Options.NonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN")
        
        _testRoundTrip(of: Float.infinity,
                       expectedJSON: "\"INF\"".data(using: .utf8)!,
                       encoderOptions: .init(nonConformingFloatEncodingStrategy: encodingStrategy),
                       decoderOptions: .init(nonConformingFloatDecodingStrategy: decodingStrategy))
        _testRoundTrip(of: -Float.infinity,
                       expectedJSON: "\"-INF\"".data(using: .utf8)!,
                       encoderOptions: .init(nonConformingFloatEncodingStrategy: encodingStrategy),
                       decoderOptions: .init(nonConformingFloatDecodingStrategy: decodingStrategy))
        
        // Since Float.nan != Float.nan, we have to use a placeholder that'll encode NaN but actually round-trip.
        _testRoundTrip(of: FloatNaNPlaceholder(),
                       expectedJSON: "\"NaN\"".data(using: .utf8)!,
                       encoderOptions: .init(nonConformingFloatEncodingStrategy: encodingStrategy),
                       decoderOptions: .init(nonConformingFloatDecodingStrategy: decodingStrategy))
        
        _testRoundTrip(of: Double.infinity,
                       expectedJSON: "\"INF\"".data(using: .utf8)!,
                       encoderOptions: .init(nonConformingFloatEncodingStrategy: encodingStrategy),
                       decoderOptions: .init(nonConformingFloatDecodingStrategy: decodingStrategy))
        _testRoundTrip(of: -Double.infinity,
                       expectedJSON: "\"-INF\"".data(using: .utf8)!,
                       encoderOptions: .init(nonConformingFloatEncodingStrategy: encodingStrategy),
                       decoderOptions: .init(nonConformingFloatDecodingStrategy: decodingStrategy))
        
        // Since Double.nan != Double.nan, we have to use a placeholder that'll encode NaN but actually round-trip.
        _testRoundTrip(of: DoubleNaNPlaceholder(),
                       expectedJSON: "\"NaN\"".data(using: .utf8)!,
                       encoderOptions: .init(nonConformingFloatEncodingStrategy: encodingStrategy),
                       decoderOptions: .init(nonConformingFloatDecodingStrategy: decodingStrategy))
        
        // Optional Floats and Doubles should encode the same way.
        _testRoundTrip(of: Optional(Float.infinity),
                       expectedJSON: "\"INF\"".data(using: .utf8)!,
                       encoderOptions: .init(nonConformingFloatEncodingStrategy: encodingStrategy),
                       decoderOptions: .init(nonConformingFloatDecodingStrategy: decodingStrategy))
        _testRoundTrip(of: Optional(-Float.infinity),
                       expectedJSON: "\"-INF\"".data(using: .utf8)!,
                       encoderOptions: .init(nonConformingFloatEncodingStrategy: encodingStrategy),
                       decoderOptions: .init(nonConformingFloatDecodingStrategy: decodingStrategy))
        _testRoundTrip(of: Optional(Double.infinity),
                       expectedJSON: "\"INF\"".data(using: .utf8)!,
                       encoderOptions: .init(nonConformingFloatEncodingStrategy: encodingStrategy),
                       decoderOptions: .init(nonConformingFloatDecodingStrategy: decodingStrategy))
        _testRoundTrip(of: Optional(-Double.infinity),
                       expectedJSON: "\"-INF\"".data(using: .utf8)!,
                       encoderOptions: .init(nonConformingFloatEncodingStrategy: encodingStrategy),
                       decoderOptions: .init(nonConformingFloatDecodingStrategy: decodingStrategy))
    }
    
    // MARK: - Directly Encoded Array Tests
    
    @Test func directlyEncodedArrays() {
        let encodingStrategy: NewJSONEncoder.Options.NonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN")
        let decodingStrategy: NewJSONDecoder.Options.NonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN")
        
        struct Arrays: JSONEncodable, JSONDecodable, Equatable {
            let integers: [Int]
            let doubles: [Double]
            let strings: [String]
            
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary(elementCount: 3) { dictEncoder throws(CodingError.Encoding) in
                    try dictEncoder.encode(key: "integers", value: integers)
                    try dictEncoder.encode(key: "doubles", value: doubles)
                    try dictEncoder.encode(key: "strings", value: strings)
                }
            }
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Arrays {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var integers: [Int]?
                    var doubles: [Double]?
                    var strings: [String]?
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "integers": integers = try valueDecoder.decode([Int].self)
                        case "doubles": doubles = try valueDecoder.decode([Double].self)
                        case "strings": strings = try valueDecoder.decode([String].self)
                        default: break // Skip unknown keys
                        }
                        return false
                    }
                    
                    guard let integers, let doubles, let strings else {
                        throw CodingError.Decoding(kind: .dataCorrupted)
                    }
                    return Arrays(integers: integers, doubles: doubles, strings: strings)
                }
            }
        }
        
        let value = Arrays(
            integers: [.min, 0, 42, .max],
            doubles: [42.0, 3.14, .infinity, -.infinity],
            strings: ["Hello", "World", "true", "0\n1", "\u{0008}"]
        )
        _testRoundTrip(of: value,
                       encoderOptions: .init(nonConformingFloatEncodingStrategy: encodingStrategy),
                       decoderOptions: .init(nonConformingFloatDecodingStrategy: decodingStrategy))
        // TODO: Pretty-printing
        //        _testRoundTrip(of: value,
        //                       outputFormatting: .prettyPrinted,
        //                       encoderOptions: .init(nonConformingFloatEncodingStrategy: encodingStrategy),
        //                       decoderOptions: .init(nonConformingFloatDecodingStrategy: decodingStrategy))
    }
    
    // MARK: - Type coercion
    @Test func typeCoercion() {
        // TODO: (U)Int128 support.
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int8].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int16].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int32].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int64].self)
        //        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int128].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt8].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt16].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt32].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt64].self)
        //        _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt128].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Float].self)
        _testRoundTripTypeCoercionFailure(of: [false, true], as: [Double].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int8], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int16], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int32], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int64], as: [Bool].self)
        //        _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int128], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt8], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt16], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt32], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt64], as: [Bool].self)
        //        _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt128], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Float], as: [Bool].self)
        _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Double], as: [Bool].self)
    }
    
    private func _test<T : Equatable & JSONDecodable>(JSONString: String, to object: T, sourceLocation: SourceLocation = #_sourceLocation) {
        // TODO: Support all encodings.
        //        let encs : [String.Encoding] = [.utf8, .utf16BigEndian, .utf16LittleEndian, .utf32BigEndian, .utf32LittleEndian]
        let enc = String.Encoding.utf8
        let decoder = NewJSONDecoder()
        //        for enc in encs {
        let data = JSONString.data(using: enc)!
        let parsed : T
        do {
            parsed = try decoder.decode(T.self, from: data)
        } catch {
            Issue.record("Failed to decode \(JSONString) with encoding \(enc): Error: \(error)", sourceLocation: sourceLocation)
            //                continue
            return
        }
        #expect(object == parsed, sourceLocation: sourceLocation)
        //        }
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
            try NewJSONDecoder().decode(String.self, from: data)
        }
    }
    
    @Test func nullByte() throws {
        let string = "abc\u{0000}def"
        let encoder = NewJSONEncoder()
        let decoder = NewJSONDecoder()
        
        let data = try encoder.encode([string])
        let decoded = try decoder.decode([String].self, from: data)
        #expect([string] == decoded)
        
        let data2 = try encoder.encode([string:string])
        let decoded2 = try decoder.decode([String:String].self, from: data2)
        #expect([string:string] == decoded2)
        
        struct Container: JSONEncodable, JSONDecodable {
            let s: String
            
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary(elementCount: 1) { dictEncoder throws(CodingError.Encoding) in
                    try dictEncoder.encode(key: "s", value: s)
                }
            }
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Container {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var s: String?
                    
                    _ = try structDecoder.decodeKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        #expect(key == "s")
                        s = try valueDecoder.decode(String.self)
                    }
                    
                    #expect(s != nil)
                    return Container(s: s!)
                }
            }
        }
        
        let data3 = try encoder.encode(Container(s: string))
        let decoded3 = try decoder.decode(Container.self, from: data3)
        #expect(decoded3.s == string)
    }
    
    @Test func superfluouslyEscapedCharacters() {
        let json = "[\"\\h\\e\\l\\l\\o\"]"
        #expect(throws: (any Error).self) {
            try NewJSONDecoder().decode([String].self, from: json.data(using: .utf8)!)
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
        
        let dict = try NewJSONDecoder().decode([String:Bool].self, from: json)
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
    
    // TODO: This is a bit of a mess. 0x42 is a value accepted by strtof. However, the parser currently considers 'x' *not* a number character (because it's not in JSON). So we attempt to pass into into strtof just address of the single "0" byte. It actually parses the "0x42", though it gives an end ptr after the "0" and we reject the result. But then "validateNumber" is confused because the sole "0" looks like a valid JSON number, so it asserts. I wonder if we'll need to consume all input that looks like it could be something that's parsable by strtof.
    // TODO: But the "2s" example is concerning as well.
    @Test(arguments: ["0.", "1e ", "-2.01e- ", "+", "2.01e-1234", "+2.0q", "2s", "NaN", "nan", "Infinity", "inf", "-", /*"0x42",*/ "1.e2"])
    func invalidJSONNumbersFailAsExpected(json: String) {
        let data = json.data(using: .utf8)!
        #expect(throws: (any Error).self, "Expected error for input \"\(json)\"") {
            _ = try NewJSONDecoder().decode(Float.self, from: data)
        }
    }
    
    func _checkExpectedThrownDataCorruptionUnderlyingError(contains substring: String, sourceLocation: SourceLocation = #_sourceLocation, closure: () throws -> Void) {
        do {
            try closure()
            Issue.record("Expected failure containing string: \"\(substring)\"", sourceLocation: sourceLocation)
        } catch let error as CodingError.Decoding {
            guard case .dataCorrupted = error.kind else {
                Issue.record("Unexpected CodingError.Decoding type: \(error)", sourceLocation: sourceLocation)
                return
            }
            #expect(error.debugDescription.contains(substring))
        } catch {
            Issue.record("Unexpected error type: \(error)", sourceLocation: sourceLocation)
        }
    }
    
    @Test func topLevelFragmentsWithGarbage() {
        _checkExpectedThrownDataCorruptionUnderlyingError(contains: "Unexpected character") {
            let _ = try NewJSONDecoder().decode(Bool.self, from: "tru_".data(using: .utf8)!)
            //            let _ = try json5Decoder.decode(Bool.self, from: "tru_".data(using: .utf8)!)
        }
        _checkExpectedThrownDataCorruptionUnderlyingError(contains: "Unexpected character") {
            let _ = try NewJSONDecoder().decode(Bool.self, from: "fals_".data(using: .utf8)!)
            //            let _ = try json5Decoder.decode(Bool.self, from: "fals_".data(using: .utf8)!)
        }
        _checkExpectedThrownDataCorruptionUnderlyingError(contains: "Unexpected character") {
            let _ = try NewJSONDecoder().decode(Bool?.self, from: "nul_".data(using: .utf8)!)
            //            let _ = try json5Decoder.decode(Bool?.self, from: "nul_".data(using: .utf8)!)
        }
    }
    
    @Test func topLevelNumberFragmentsWithJunkDigitCharacters() throws {
        let fullData = "3.141596".data(using: .utf8)!
        let partialData = fullData[0..<4]
        
        #expect(try 3.14 == NewJSONDecoder().decode(Double.self, from: partialData))
    }
    
    @Test
    @MainActor // Deeply recursive tests which requires running on the main thread which has a higher stack size limit
    func depthTraversal() {
        struct SuperNestedArray : JSONDecodable {
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> SuperNestedArray {
                try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
                    try arrayDecoder.decodeNext { elementDecoder throws(CodingError.Decoding) in
                        _ = try elementDecoder.decode(SuperNestedArray.self)
                    }
                }
                return .init()
            }
        }
        
        let MAX_DEPTH = 512
        let jsonGood = String(repeating: "[", count: MAX_DEPTH / 2) + String(repeating: "]", count: MAX_DEPTH / 2)
        let jsonBad = String(repeating: "[", count: MAX_DEPTH + 1) + String(repeating: "]", count: MAX_DEPTH + 1)
        
        #expect(throws: Never.self) {
            try NewJSONDecoder().decode(SuperNestedArray.self, from: jsonGood.data(using: .utf8)!)
        }
        #expect(throws: (any Error).self) {
            try NewJSONDecoder().decode(SuperNestedArray.self, from: jsonBad.data(using: .utf8)!)
        }
        
    }
    
    // MARK: - Trailing Comma Tests
    // Trailing commas aren't valid JSON and should never be emitted, but are syntactically unambiguous and are allowed by
    // most parsers for ease of use. Each test below exercises a distinct code path in JSONParserDecoder.

    // Tests prepareForArrayElement (JSONDecodable path) and prepareForDictKey (CommonDecodable [String:V] path)
    @Test func trailingComma_dictionaryOfArrays() throws {
        let json = "{\"key\" : [ true, ],}"
        let data = Data(json.utf8)

        let result = try NewJSONDecoder().decode([String:[Bool]].self, from: data)
        #expect(result == ["key" : [true]])
    }

    // Tests prepareForArrayElement via decode([Element].Type) with JSONDecodable elements
    @Test func trailingComma_topLevelArray() throws {
        let json = "[1, 2, 3,]"
        let data = Data(json.utf8)

        let result = try NewJSONDecoder().decode([Int].self, from: data)
        #expect(result == [1, 2, 3])
    }

    // Tests prepareForArrayElement via ArrayDecoder.decodeEachElement
    @Test func trailingComma_arrayDecoder() throws {
        struct Counter: JSONDecodable, Equatable {
            let count: Int

            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Counter {
                var count = 0
                try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
                    try arrayDecoder.decodeEachElement { elementDecoder throws(CodingError.Decoding) in
                        _ = try elementDecoder.decode(Int.self)
                        count += 1
                    }
                }
                return Counter(count: count)
            }
        }
        let json = "[10, 20,]"
        let data = Data(json.utf8)

        let result = try NewJSONDecoder().decode(Counter.self, from: data)
        #expect(result == Counter(count: 2))
    }

    // Tests StructDecoder.decodeEachKeyAndValue (the most common struct decoding path)
    @Test func trailingComma_structDecodeEachKeyAndValue() throws {
        let json = "{\"name\" : \"Alice\", \"age\" : 30,}"
        let data = Data(json.utf8)

        let result = try NewJSONDecoder().decode(SimpleStruct.self, from: data)
        #expect(result == SimpleStruct(name: "Alice", age: 30))
    }

    // Tests StructDecoder.decodeExpectedOrderField comma handling
    @Test func trailingComma_structDecodeExpectedOrderField() throws {
        struct Ordered: JSONDecodable, Equatable {
            let x: Int
            let y: Int
            
            enum Field: JSONOptimizedDecodingField {
                case x
                case y
                
                var staticString: StaticString {
                    switch self {
                    case .x: "x"
                    case .y: "y"
                    }
                }
                
                static func field(for key: UTF8Span) throws(NewCodable.CodingError.Decoding) -> Ordered.Field {
                    switch UTF8SpanComparator(key) {
                    case "x": .x
                    case "y": .y
                    default: throw CodingError.unknownKey(key)
                    }
                }
            }

            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Ordered {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var x: Int?
                    var y: Int?

                    var unused = true
                    _ = try structDecoder.decodeExpectedOrderField(Field.x, inOrder: &unused) { valueDecoder throws(CodingError.Decoding) in
                        x = try valueDecoder.decode(Int.self)
                    }
                    _ = try structDecoder.decodeExpectedOrderField(Field.y, inOrder: &unused) { valueDecoder throws(CodingError.Decoding) in
                        y = try valueDecoder.decode(Int.self)
                    }

                    guard let x, let y else {
                        throw CodingError.Decoding(kind: .dataCorrupted)
                    }
                    return Ordered(x: x, y: y)
                }
            }
        }
        let json = "{\"x\": 1, \"y\": 2,}"
        let data = Data(json.utf8)

        let result = try NewJSONDecoder().decode(Ordered.self, from: data)
        #expect(result == Ordered(x: 1, y: 2))
    }

    // Tests StructDecoder.decodeEachField (FieldDecoder path, used by macro-generated code)
    @Test func trailingComma_structDecodeEachField() throws {
        struct FieldBased: JSONDecodable, Equatable {
            let a: Int
            let b: String

            enum Fields: JSONOptimizedDecodingField {
                case a
                case b

                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Self {
                    switch UTF8SpanComparator(key) {
                    case "a": .a
                    case "b": .b
                    default: throw CodingError.unknownKey(key)
                    }
                }

                @inline(__always)
                var staticString: StaticString {
                    switch self {
                    case .a: "a"
                    case .b: "b"
                    }
                }
            }

            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> FieldBased {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var a: Int?
                    var b: String?
                    var key: Fields?

                    try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                        key = try fieldDecoder.decode(Fields.self)
                    } andValue: { valueDecoder throws(CodingError.Decoding) in
                        switch key! {
                        case .a: a = try valueDecoder.decode(Int.self)
                        case .b: b = try valueDecoder.decode(String.self)
                        }
                    }

                    guard let a, let b else {
                        throw CodingError.Decoding(kind: .dataCorrupted)
                    }
                    return FieldBased(a: a, b: b)
                }
            }
        }
        let json = "{\"a\": 42, \"b\": \"hello\",}"
        let data = Data(json.utf8)

        let result = try NewJSONDecoder().decode(FieldBased.self, from: data)
        #expect(result == FieldBased(a: 42, b: "hello"))
    }

    // Tests Data decoded via deferredToData (which uses decode([UInt8].self) -> prepareForArrayElement)
    @Test func trailingComma_dataByteArray() throws {
        let json = "[72, 101, 108, 108, 111,]"
        let data = Data(json.utf8)
        let options = NewJSONDecoder.Options(dataDecodingStrategy: .deferredToData)
        let decoder = NewJSONDecoder(options: options)

        let result = try decoder.decode(Data.self, from: data)
        #expect(result == Data([72, 101, 108, 108, 111]))
    }

    // Tests prepareForDictKey (used by [Key:Value] dictionary decoding for CommonDecodable values)
    @Test func trailingComma_topLevelDictionary() throws {
        let json = "{\"a\": 1, \"b\": 2,}"
        let data = Data(json.utf8)

        let result = try NewJSONDecoder().decode([String: Int].self, from: data)
        #expect(result == ["a": 1, "b": 2])
    }

    // Tests nested trailing commas at multiple levels simultaneously
    @Test func trailingComma_nestedContainers() throws {
        let json = "{\"person\": {\"name\": \"Bob\", \"age\": 25,}, \"metadata\": {\"role\": \"dev\",},}"
        let data = Data(json.utf8)

        let result = try NewJSONDecoder().decode(NestedStruct.self, from: data)
        #expect(result == NestedStruct(
            person: SimpleStruct(name: "Bob", age: 25),
            metadata: ["role": "dev"]
        ))
    }

    // Tests that a trailing comma in an empty container is rejected (not a trailing comma — it's a leading comma)
    @Test func trailingComma_emptyArrayRejects() throws {
        let json = "[,]"
        let data = Data(json.utf8)

        #expect(throws: (any Error).self) {
            try NewJSONDecoder().decode([Int].self, from: data)
        }
    }

    // Tests that a trailing comma in an empty object is rejected
    @Test func trailingComma_emptyObjectRejects() throws {
        let json = "{,}"
        let data = Data(json.utf8)

        #expect(throws: (any Error).self) {
            try NewJSONDecoder().decode([String: Int].self, from: data)
        }
    }
    
    @Test func whitespaceOnlyData() {
        let data = " ".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try NewJSONDecoder().decode(Int.self, from: data)
        }
    }
    
    @Test func smallFloatNumber() {
        _testRoundTrip(of: [["magic_number" : 7.45673334164903e-115]])
    }
    
    @Test func largeIntegerNumber() throws {
        let num : UInt64 = 6032314514195021674
        let json = "{\"a\":\(num)}"
        let data = json.data(using: .utf8)!
        
        let result = try NewJSONDecoder().decode([String:UInt64].self, from: data)
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
        
        // TODO: Enable after json5 support.
        //        for json5 in [true, false] {
        let decoder = NewJSONDecoder()
        //            decoder.allowsJSON5 = json5
        
        for (json, value) in int64s {
            let result = try? decoder.decode(Int64.self, from: json.data(using: .utf8)!)
            #expect(result == value, "Unexpected \(decoder) result for input \"\(json)\"")
        }
        
        for (json, value) in uint64s {
            let result = try? decoder.decode(UInt64.self, from: json.data(using: .utf8)!)
            #expect(result == value, "Unexpected \(decoder) result for input \"\(json)\"")
        }
        //        }
    }
    
    @Test func roundTrippingExtremeValues() {
        struct Numbers : JSONEncodable, JSONDecodable, Equatable {
            let floats : [Float]
            let doubles : [Double]
            
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary(elementCount: 2) { dictEncoder throws(CodingError.Encoding) in
                    try dictEncoder.encode(key: "floats", value: floats)
                    try dictEncoder.encode(key: "doubles", value: doubles)
                }
            }
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Numbers {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var floats: [Float]?
                    var doubles: [Double]?
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "floats": floats = try valueDecoder.decode([Float].self)
                        case "doubles": doubles = try valueDecoder.decode([Double].self)
                        default: break // Skip unknown keys
                        }
                        return false
                    }
                    
                    guard let floats, let doubles else {
                        throw CodingError.Decoding(kind: .dataCorrupted)
                    }
                    return Numbers(floats: floats, doubles: doubles)
                }
            }
        }
        
        let testValue = Numbers(floats: [.greatestFiniteMagnitude, .leastNormalMagnitude], doubles: [.greatestFiniteMagnitude, .leastNormalMagnitude])
        _testRoundTrip(of: testValue)
    }
    
    // TODO: (U)Int128 support + proting.
    //    @Test func roundTrippingInt128() {
    //        for i128 in [Int128.min,
    //                        Int128.min + 1,
    //                        -0x1_0000_0000_0000_0000,
    //                        0x0_8000_0000_0000_0000,
    //                        -1,
    //                        0,
    //                        0x7fff_ffff_ffff_ffff,
    //                        0x8000_0000_0000_0000,
    //                        0xffff_ffff_ffff_ffff,
    //                        0x1_0000_0000_0000_0000,
    //                     .max] {
    //            _testRoundTrip(of: i128)
    //        }
    //    }
    //
    //    @Test func int128SlowPath() throws {
    //        let decoder = JSONDecoder()
    //        let work: [Int128] = [18446744073709551615, -18446744073709551615]
    //        for value in work {
    //            // force the slow-path by appending ".0"
    //            let json = "\(value).0".data(using: .utf8)!
    //            #expect(try value == decoder.decode(Int128.self, from: json))
    //        }
    //        // These should work, but making them do so probably requires
    //        // rewriting the slow path to use a dedicated parser. For now,
    //        // we ensure that they throw instead of returning some bogus
    //        // result.
    //        let shouldWorkButDontYet: [Int128] = [
    //            .min, -18446744073709551616, 18446744073709551616, .max
    //        ]
    //        for value in shouldWorkButDontYet {
    //            // force the slow-path by appending ".0"
    //            let json = "\(value).0".data(using: .utf8)!
    //            #expect(throws: (any Error).self) {
    //                try decoder.decode(Int128.self, from: json)
    //            }
    //        }
    //    }
    //
    //    @Test func roundTrippingUInt128() {
    //        for u128 in [UInt128.zero,
    //                     1,
    //                     0x0000_0000_0000_0000_7fff_ffff_ffff_ffff,
    //                     0x0000_0000_0000_0000_8000_0000_0000_0000,
    //                     0x0000_0000_0000_0000_ffff_ffff_ffff_ffff,
    //                     0x0000_0000_0000_0001_0000_0000_0000_0000,
    //                     0x7fff_ffff_ffff_ffff_ffff_ffff_ffff_ffff,
    //                     0x8000_0000_0000_0000_0000_0000_0000_0000,
    //                     .max] {
    //            _testRoundTrip(of: u128)
    //        }
    //    }
    //
    //    @Test func uint128SlowPath() throws {
    //        let decoder = JSONDecoder()
    //        let work: [UInt128] = [18446744073709551615]
    //        for value in work {
    //            // force the slow-path by appending ".0"
    //            let json = "\(value).0".data(using: .utf8)!
    //            #expect(try value == decoder.decode(UInt128.self, from: json))
    //        }
    //        // These should work, but making them do so probably requires
    //        // rewriting the slow path to use a dedicated parser. For now,
    //        // we ensure that they throw instead of returning some bogus
    //        // result.
    //        let shouldWorkButDontYet: [UInt128] = [
    //            18446744073709551616, .max
    //        ]
    //        for value in shouldWorkButDontYet {
    //            // force the slow-path by appending ".0"
    //            let json = "\(value).0".data(using: .utf8)!
    //            #expect(throws: (any Error).self) {
    //                try decoder.decode(UInt128.self, from: json)
    //            }
    //        }
    //    }
    
    @Test func roundTrippingDoubleValues() {
        struct Numbers : JSONEncodable, JSONDecodable, Equatable {
            let doubles : [String:Double]
            let fullNumbers : [String:JSONPrimitive] // TODO: This was Decimal, but we don't currently have Decimal support built in to NewJSONDecoder.
            
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary(elementCount: 2) { dictEncoder throws(CodingError.Encoding) in
                    try dictEncoder.encode(key: "doubles", value: doubles)
                    try dictEncoder.encode(key: "fullNumbers", value: fullNumbers)
                }
            }
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Numbers {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var doubles: [String:Double]?
                    var fullNumbers: [String:JSONPrimitive]?
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "doubles": doubles = try valueDecoder.decode([String:Double].self)
                        case "fullNumbers": fullNumbers = try valueDecoder.decode([String:JSONPrimitive].self)
                        default: break // Skip unknown keys
                        }
                        return false
                    }
                    
                    guard let doubles, let fullNumbers else {
                        throw CodingError.Decoding(kind: .dataCorrupted)
                    }
                    return Numbers(doubles: doubles, fullNumbers: fullNumbers)
                }
            }
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
            fullNumbers: [
                "1.234567891011121314" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "1.234567891011121314")),
                "-1.234567891011121314" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "-1.234567891011121314")),
                "0.1234567891011121314" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "0.1234567891011121314")),
                "-0.1234567891011121314" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "-0.1234567891011121314")),
                "123.4567891011121314e-100" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "123.4567891011121314e-100")),
                "-123.4567891011121314e-100" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "-123.4567891011121314e-100")),
                "11234567891011121314e-100" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "1234567891011121314e-100")),
                "-1234567891011121314e-100" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "-1234567891011121314e-100")),
                "0.1234567891011121314e-100" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "0.1234567891011121314e-100")),
                "-0.1234567891011121314e-100" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "-0.1234567891011121314e-100")),
                "3.14159265358979323846264338327950288419" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "3.14159265358979323846264338327950288419")),
                "2.71828182845904523536028747135266249775" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "2.71828182845904523536028747135266249775")),
                "440474310512876335.18692524723746578303827301433673643795" : JSONPrimitive.number(.init(extendedPrecisionRepresentation: "440474310512876335.18692524723746578303827301433673643795"))
            ]
        )
        _testRoundTrip(of: testValue)
    }
    
    @Test func decodeLargeDoubleAsInteger() throws {
        let data = try NewJSONEncoder().encode(Double.greatestFiniteMagnitude)
        #expect(throws: (any Error).self) {
            try NewJSONDecoder().decode(UInt64.self, from: data)
        }
    }
    
    // Windows doesn't have thread-specific newlocale/uselocale which are important for running these tests in parallel.
#if !os(Windows)
    
    static func hasLocales() -> Bool {
        // The system must have a non-English, non-POSIX locale to test this behavior.
        guard let frLocale = newlocale(LC_ALL, "fr_FR", nil) else { return false }
        defer { freelocale(frLocale) }
#if os(Windows)
        let enLocale = newlocale(LC_ALL, "en_US", nil)
#else
        let enLocale = newlocale(LC_ALL, "en_US_POSIX", nil)
#endif
        guard let enLocale else { return false }
        defer { freelocale(enLocale) }
        return true
    }
    
    @Test(.enabled(if: hasLocales()))
    func localeDecimalPolicyIndependence() throws {
        guard let frLocale = newlocale(LC_ALL, "fr_FR", nil) else {
            return
        }
        defer { freelocale(frLocale) }
        
#if os(Windows)
        let enLocale = newlocale(LC_ALL, "en_US", nil)
#else
        let enLocale = newlocale(LC_ALL, "en_US_POSIX", nil)
#endif
        guard let enLocale else {
            return
        }
        defer { freelocale(enLocale) }
        
        let orig = ["decimalValue": 1.1]
        
        let prevLocale = uselocale(frLocale)
        defer { uselocale(prevLocale) }
        
        let data = try NewJSONEncoder().encode(orig)
        
        uselocale(enLocale)
        let decoded = try NewJSONDecoder().decode(type(of: orig).self, from: data)
        
        #expect(orig == decoded)
    }
#endif
    
    @Test func whitespace() {
        let tests : [(json: String, expected: [String:Bool])] = [
            ("{\"v\"\n : true}",   ["v":true]),
            ("{\"v\"\r\n : true}", ["v":true]),
            ("{\"v\"\r : true}",   ["v":true])
        ]
        for test in tests {
            let data = test.json.data(using: .utf8)!
            let decoded = try! NewJSONDecoder().decode([String:Bool].self, from: data)
            #expect(test.expected == decoded)
        }
    }
    
    // TODO: Support assumesTopLevelDictionary?
    //    @Test func assumesTopLevelDictionary() throws {
    //        let decoder = JSONDecoder()
    //        decoder.assumesTopLevelDictionary = true
    //
    //        let json = "\"x\" : 42"
    //        var result = try decoder.decode([String:Int].self, from: json.data(using: .utf8)!)
    //        #expect(result == ["x" : 42])
    //
    //        let jsonWithBraces = "{\"x\" : 42}"
    //        result = try decoder.decode([String:Int].self, from: jsonWithBraces.data(using: .utf8)!)
    //        #expect(result == ["x" : 42])
    //
    //        result = try decoder.decode([String:Int].self, from: Data())
    //        #expect(result == [:])
    //
    //        let jsonWithEndBraceOnly = "\"x\" : 42}"
    //        #expect(throws: (any Error).self) {
    //            try decoder.decode([String:Int].self, from: jsonWithEndBraceOnly.data(using: .utf8)!)
    //        }
    //
    //        let jsonWithStartBraceOnly = "{\"x\" : 42"
    //        #expect(throws: (any Error).self) {
    //            try decoder.decode([String:Int].self, from: jsonWithStartBraceOnly.data(using: .utf8)!)
    //        }
    //
    //    }
    
    // TODO: Support BOM/encodings
    //    @Test func bomPrefixes() throws {
    //        let json = "\"👍🏻\""
    //        let decoder = JSONDecoder()
    //
    //        // UTF-8 BOM
    //        let utf8_BOM = Data([0xEF, 0xBB, 0xBF])
    //        #expect(try "👍🏻" == decoder.decode(String.self, from: utf8_BOM + json.data(using: .utf8)!))
    //
    //        // UTF-16 BE
    //        let utf16_BE_BOM = Data([0xFE, 0xFF])
    //        #expect(try "👍🏻" == decoder.decode(String.self, from: utf16_BE_BOM + json.data(using: .utf16BigEndian)!))
    //
    //        // UTF-16 LE
    //        let utf16_LE_BOM = Data([0xFF, 0xFE])
    //        #expect(try "👍🏻" == decoder.decode(String.self, from: utf16_LE_BOM + json.data(using: .utf16LittleEndian)!))
    //
    //        // UTF-32 BE
    //        let utf32_BE_BOM = Data([0x0, 0x0, 0xFE, 0xFF])
    //        #expect(try "👍🏻" == decoder.decode(String.self, from: utf32_BE_BOM + json.data(using: .utf32BigEndian)!))
    //
    //        // UTF-32 LE
    //        let utf32_LE_BOM = Data([0xFE, 0xFF, 0, 0])
    //        #expect(try "👍🏻" == decoder.decode(String.self, from: utf32_LE_BOM + json.data(using: .utf32LittleEndian)!))
    //
    //        // Try some mismatched BOMs
    //        #expect(throws: (any Error).self) {
    //            try decoder.decode(String.self, from: utf32_LE_BOM + json.data(using: .utf32BigEndian)!)
    //        }
    //
    //        #expect(throws: (any Error).self) {
    //            try decoder.decode(String.self, from: utf16_BE_BOM + json.data(using: .utf32LittleEndian)!)
    //        }
    //
    //        #expect(throws: (any Error).self) {
    //            try decoder.decode(String.self, from: utf8_BOM + json.data(using: .utf16BigEndian)!)
    //        }
    //    }
    
    @Test func invalidKeyUTF8() {
        // {"key[255]":"value"}
        // The invalid UTF-8 byte sequence in the key should trigger a thrown error, not a crash.
        let data = Data([123, 34, 107, 101, 121, 255, 34, 58, 34, 118, 97, 108, 117, 101, 34, 125])
        struct Example: JSONDecodable {
            let key: String
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Example {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var key: String?
                    
                    try structDecoder.decodeEachKeyAndValue { keyName, valueDecoder throws(CodingError.Decoding) in
                        switch keyName {
                        case "key": key = try valueDecoder.decode(String.self)
                        default: break // Skip unknown keys
                        }
                        return false
                    }
                    
                    guard let key else {
                        throw CodingError.Decoding(kind: .dataCorrupted)
                    }
                    return Example(key: key)
                }
            }
        }
        #expect(throws: (any Error).self) {
            try NewJSONDecoder().decode(Example.self, from: data)
        }
    }
    
    // TODO: Date support?
    //    @Test func infiniteDate() {
    //        let date = Date(timeIntervalSince1970: .infinity)
    //
    //        let encoder = JSONEncoder()
    //
    //        encoder.dateEncodingStrategy = .deferredToDate
    //        #expect(throws: (any Error).self) {
    //            try encoder.encode([date])
    //        }
    //
    //        encoder.dateEncodingStrategy = .secondsSince1970
    //        #expect(throws: (any Error).self) {
    //            try encoder.encode([date])
    //        }
    //
    //        encoder.dateEncodingStrategy = .millisecondsSince1970
    //        #expect(throws: (any Error).self) {
    //            try encoder.encode([date])
    //        }
    //    }
    
    // TODO: This test does not exemplify desired client behavior and it differs from traditional JSONEncoder behacior. It's unclear whether we will want to tolerate this kind of behavior from clients, or what we should do to prevent it.
    @Test func typeEncodesNothing() {
        struct EncodesNothing : JSONEncodable {
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                // Nothing.
            }
        }
        let enc = NewJSONEncoder()
        
        #expect(throws: Never.self) {
            let nothing = try enc.encode(EncodesNothing())
            #expect(nothing.count == 0)
        }
        
        #expect(throws: Never.self) {
            let nothingArray = try enc.encode([EncodesNothing(), EncodesNothing()])
            #expect("[,]" == String(data: nothingArray, encoding: .utf8))
        }
        
        #expect(throws: Never.self) {
            let nothingDict = try enc.encode(["test" : EncodesNothing()])
            #expect(#"{"test":}"# == String(data: nothingDict, encoding: .utf8))
        }
    }
    
    @Test func redundantKeys() throws {
        // NOTE: This API is different than Encodable. Redundant keys are ALL recorded in the output, unless the given encoder specifically states that it does the additional work to unique keys.
        struct RedundantEncoding : JSONEncodable {
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
                    try dictEncoder.encode(key: "key", value: 42)
                    try dictEncoder.encode(key: "key", value: 67)
                }
            }
        }
        let data = try NewJSONEncoder().encode(RedundantEncoding())
        #expect(String(data: data, encoding: .utf8) == (#"{"key":42,"key":67}"#))
    }
    
    // TODO: This is taken from the existing test suite, but seems very regression-test-y and not likely something I think we'd test for out the gate.
    @Test func codingEmptyDictionaryWithNonstringKeyDoesRoundtrip() throws {
        struct Something: JSONCodable {
            struct Key: Hashable, CodingStringKeyRepresentable {
                struct KeyDecodingVisitor: DecodingStringVisitor {
                    typealias DecodedValue = Key
                    
                    public func visitString(_ string: String) throws(CodingError.Decoding) -> DecodedValue {
                        return .init(x: string)
                    }
                    
                    public func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> DecodedValue {
                        return .init(x: String(copying: buffer))
                    }
                }
                
                static var codingStringKeyVisitor: KeyDecodingVisitor { KeyDecodingVisitor() }
                
                func withCodingStringUTF8Span<R, E>(_ body: (UTF8Span) throws(E) -> R) throws(E) -> R where E : Error {
                    try body(x.utf8Span)
                }
                
                var x: String
            }
            
            var dict: [Key: String]
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Something {
                var dict: [Key: String]?
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    _ = try structDecoder.decodeKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        #expect(key == "dict")
                        dict = try valueDecoder.decode([Key:String].self)
                    }
                }
                #expect(dict != nil)
                return .init(dict: dict!)
            }
            
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(key: "dict", value: self.dict)
                }
            }
        }
        
        let toEncode = Something(dict: [:])
        let data = try NewJSONEncoder().encode(toEncode)
        let result = try NewJSONDecoder().decode(Something.self, from: data)
        #expect(result.dict.count == 0)
    }
    
    @Test func decodingStringExpectedType() {
        struct Test : JSONDecodable {
            var key : String
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Test {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var key: String?
                    
                    try structDecoder.decodeEachKeyAndValue { keyName, valueDecoder throws(CodingError.Decoding) in
                        switch keyName {
                        case "key": key = try valueDecoder.decode(String.self)
                        default: break // Skip unknown keys
                        }
                        return false
                    }
                    
                    guard let key else {
                        throw CodingError.Decoding(kind: .dataCorrupted)
                    }
                    return Test(key: key)
                }
            }
        }
        
        let input = #"{"key": null}"#.data(using: .utf8)!
        #expect {
            _ = try NewJSONDecoder().decode(Test.self, from: input)
        } throws: {
            return ($0 as! CodingError.Decoding).debugDescription.contains("Type mismatch: expected string")
        }
    }
    
    // TODO: Other encodings
    //    @Test func twoByteUTF16Inputs() throws {
    //        let json = "7"
    //        let decoder = JSONDecoder()
    //
    //        #expect(try 7 == decoder.decode(Int.self, from: json.data(using: .utf16BigEndian)!))
    //        #expect(try 7 == decoder.decode(Int.self, from: json.data(using: .utf16LittleEndian)!))
    //    }
    
    private func _run_passTest<T:Codable & JSONCodable & Equatable>(name: String, json5: Bool = false, type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) {
        let jsonData = testData(forResource: name, withExtension: json5 ? "json5" : "json" , subdirectory: json5 ? "JSON5/pass" : "JSON/pass")!
        
        let decoder = NewJSONDecoder()
        //        let decoder = json5Decoder
        
        let decoded: T
        do {
            decoded = try decoder.decode(T.self, from: jsonData)
        } catch {
            Issue.record("Pass test \"\(name)\" failed with error: \(error)", sourceLocation: sourceLocation)
            return
        }
        
        // TODO: Pretty print
        //        let prettyPrintEncoder = JSONEncoder()
        //        prettyPrintEncoder.outputFormatting = .prettyPrinted
        
        for encoder in [NewJSONEncoder()/*, prettyPrintEncoder*/] {
            #expect(throws: Never.self, sourceLocation: sourceLocation) {
                let reencodedData = try encoder.encode(decoded)
                let redecodedObjects = try decoder.decode(T.self, from: reencodedData)
                #expect(decoded == redecodedObjects)
            }
        }
        
        #expect(throws: Never.self, sourceLocation: sourceLocation) {
            // TODO: json5
            let oldDecodedJSON = try NewJSONDecoder().decode(T.self, from: jsonData)
            #expect(oldDecodedJSON == decoded)
        }
    }
    
    @Test func jsonPassTests() {
        _run_passTest(name: "pass1-utf8", type: JSONPass.Test1.self)
        // TODO: Other encodings.
        //        _run_passTest(name: "pass1-utf16be", type: JSONPass.Test1.self)
        //        _run_passTest(name: "pass1-utf16le", type: JSONPass.Test1.self)
        //        _run_passTest(name: "pass1-utf32be", type: JSONPass.Test1.self)
        //        _run_passTest(name: "pass1-utf32le", type: JSONPass.Test1.self)
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
    
    private func _run_failTest<T:JSONDecodable>(name: String, type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) {
        let jsonData = testData(forResource: name, withExtension: "json", subdirectory: "JSON/fail")!
        
        let decoder = NewJSONDecoder()
        //        decoder.assumesTopLevelDictionary = true
        #expect(throws: (any Error).self, "Decoding should have failed for invalid JSON data (test name: \(name))", sourceLocation: sourceLocation) {
            try decoder.decode(T.self, from: jsonData)
        }
    }
    
    @Test func jsonFailTests() {
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
        
        // TODO: We need to fail for post-decode data being left over. That's mainly what's failing here.
        // TODO: fail1 is a little bogus, since we allow decoding fragments. Foundation's version passes this test because it specifies assumesTopLevelDictionary = true, but that's not representative of this test's intent.
        //_run_failTest(name: "fail1", type: JSONFail.Test1.self)
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
    
    // TODO: Date support?
    //    @Test func encodingDateISO8601() {
    //        let timestamp = Date(timeIntervalSince1970: 1000)
    //        let expectedJSON = "\"\(timestamp.formatted(.iso8601))\"".data(using: .utf8)!
    //
    //        _testRoundTrip(of: timestamp,
    //                       expectedJSON: expectedJSON,
    //                       dateEncodingStrategy: .iso8601,
    //                       dateDecodingStrategy: .iso8601)
    //
    //
    //        // Optional dates should encode the same way.
    //        _testRoundTrip(of: Optional(timestamp),
    //                       expectedJSON: expectedJSON,
    //                       dateEncodingStrategy: .iso8601,
    //                       dateDecodingStrategy: .iso8601)
    //    }
    
    @Test func encodingDataBase64() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        
        let expectedJSON = #""3q2+7w==""#.data(using: .utf8)!
        _testRoundTrip(of: data, expectedJSON: expectedJSON)
        
        // Optional data should encode the same way.
        _testRoundTrip(of: Optional(data), expectedJSON: expectedJSON)
    }
}
