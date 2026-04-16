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
import NewCodable

protocol CommonTopLevelEncoder: ~Copyable {
    func encode(_ value: borrowing some CommonEncodable & ~Copyable) throws(CodingError.Encoding) -> Data
}

protocol JSONTopLevelEncoder: ~Copyable {
    func encode(_ value: borrowing some JSONEncodable & ~Copyable) throws(CodingError.Encoding) -> Data
}

protocol CommonTopLevelDecoder: ~Copyable {
    func decode<T: CommonDecodable>(_ type: T.Type, from data: Data) throws(CodingError.Decoding) -> T
}

protocol JSONTopLevelDecoder: ~Copyable {
    func decode<T: JSONDecodable>(_ type: T.Type, from data: Data) throws(CodingError.Decoding) -> T
}

extension NewJSONEncoder: CommonTopLevelEncoder { }
extension NewJSONEncoder: JSONTopLevelEncoder { }
extension NewJSONDecoder: CommonTopLevelDecoder { }
extension NewJSONDecoder: JSONTopLevelDecoder { }


struct NewCodableTests {
    @Test func arbitraryPrecisionNumbers() throws {
        let data = Data("1234567890.000000000000000001e9999999999999999".utf8)
        struct Test: JSONDecodable {
            let numberStr: String

            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Test {
                let number = try decoder.decodeNumber()
                return .init(numberStr: number.extendedPrecisionRepresentation)
            }
        }
        
        let decoder = NewJSONDecoder()
        let result = try decoder.decode(Test.self, from: data)
        #expect(result.numberStr == "1234567890.000000000000000001e9999999999999999")
    }
    
    @Test func dataDecoding() throws {
        let json = Data("[0, 1, 2, 3]".utf8)
        let decoder = NewJSONDecoder()
        let data = try decoder.decode(Data.self, from: json)
        #expect(data == Data([0, 1, 2, 3]))
    }
     
    @Test func embeddedCodable() throws {
        let json = Data("""
            {
                "name": "John",
                "address": { "city": "Cupertino", "state": "CA" }
            }
            """.utf8)
        
        struct Person: JSONDecodable, Equatable {
            let name: String
            let address: Address
            
            enum CodingFields: Int, JSONOptimizedDecodingField, EncodingField {
                case name
                case address
                
                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Self {
                    switch UTF8SpanComparator(key) {
                    case "name": .name
                    case "address": .address
                    default: throw CodingError.unknownKey(key)
                    }
                }
                
                @inline(__always)
                var staticString: StaticString {
                    switch self {
                    case .name: "name"
                    case .address: "address"
                    }
                }
            }
            
            struct Address: Decodable, Equatable {
                let city: String
                let state: String
            }
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Person {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var name: String?
                    var address: Address?
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "name": 
                            name = try valueDecoder.decode(String.self)
                        case "address": 
                            address = try valueDecoder.decode(Address.self)
                        default: 
                            break // Skip unknown keys
                        }
                        return false
                    }
                    
                    guard let name, let address else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                    }
                    return Person(name: name, address: address)
                }
            }
        }
        
        let decoder = NewJSONDecoder()
        let person = try decoder.decode(Person.self, from: json)
        
        let expected = Person(
            name: "John", 
            address: .init(city: "Cupertino", state: "CA")
        )
        #expect(person == expected)
    }
    
    @Test func standardDecodableInteroperability() throws {
        let json = Data("""
            {
                "title": "My Blog Post",
                "author": { "name": "Alice", "email": "alice@example.com" },
                "metadata": { "wordCount": 1500, "readTime": 5 },
                "comments": [
                    { "author": "Bob", "text": "Great post!" },
                    { "author": "Charlie", "text": "Very helpful, thanks!" }
                ]
            }
            """.utf8)
        
        // Standard Decodable types that don't conform to CommonDecodable
        struct Author: Decodable, Equatable {
            let name: String
            let email: String
        }
        
        struct Metadata: Decodable, Equatable {
            let wordCount: Int
            let readTime: Int
        }
        
        struct Comment: Decodable, Equatable {
            let author: String
            let text: String
        }
        
        // A CommonDecodable type that contains standard Decodable types
        struct BlogPost: CommonDecodable, Equatable {
            let title: String
            let author: Author
            let metadata: Metadata
            let comments: [Comment]
            
            static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> BlogPost {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var title: String?
                    var author: Author?
                    var metadata: Metadata?
                    var comments: [Comment]?
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "title":
                            title = try valueDecoder.decode(String.self)
                        case "author":
                            // This should use our new decode<D: Decodable> method!
                            author = try valueDecoder.decode(Author.self)
                        case "metadata":
                            // This should use our new decode<D: Decodable> method!
                            metadata = try valueDecoder.decode(Metadata.self)
                        case "comments":
                            // This should use our new decode<D: Decodable> method for the array elements!
                            comments = try valueDecoder.decode([Comment].self)
                        default:
                            break // Skip unknown keys
                        }
                        return false
                    }
                    
                    guard let title, let author, let metadata, let comments else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                    }
                    return BlogPost(title: title, author: author, metadata: metadata, comments: comments)
                }
            }
        }
        
        let decoder = NewJSONDecoder()
        let blogPost = try decoder.decode(BlogPost.self, from: json)
        
        let expectedPost = BlogPost(
            title: "My Blog Post",
            author: Author(name: "Alice", email: "alice@example.com"),
            metadata: Metadata(wordCount: 1500, readTime: 5),
            comments: [
                Comment(author: "Bob", text: "Great post!"),
                Comment(author: "Charlie", text: "Very helpful, thanks!")
            ]
        )
        
        #expect(blogPost == expectedPost)
    }
    
    @Test func standardDecodableWithPrimitives() throws {
        let json = Data("""
            {
                "user": { "id": 42, "active": true },
                "scores": [98.5, 87.2, 92.1],
                "settings": { "notifications": true, "theme": "dark" }
            }
            """.utf8)
        
        // Standard Decodable types with various primitive types
        struct User: Decodable, Equatable {
            let id: Int
            let active: Bool
        }
        
        struct Settings: Decodable, Equatable {
            let notifications: Bool
            let theme: String
        }
        
        struct Report: CommonDecodable, Equatable {
            let user: User
            let scores: [Double]
            let settings: Settings
            
            static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Report {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var user: User?
                    var scores: [Double]?
                    var settings: Settings?
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "user":
                            user = try valueDecoder.decode(User.self)
                        case "scores":
                            scores = try valueDecoder.decode([Double].self, sizeHint: 0)
                        case "settings":
                            settings = try valueDecoder.decode(Settings.self)
                        default:
                            break
                        }
                        return false
                    }
                    
                    guard let user, let scores, let settings else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                    }
                    return Report(user: user, scores: scores, settings: settings)
                }
            }
        }
        
        let decoder = NewJSONDecoder()
        let report = try decoder.decode(Report.self, from: json)
        
        let expectedReport = Report(
            user: User(id: 42, active: true),
            scores: [98.5, 87.2, 92.1],
            settings: Settings(notifications: true, theme: "dark")
        )
        
        #expect(report == expectedReport)
    }
    
    @Test func testFlatten() throws {
        /*
         @Codable
         struct Person {
             let name: String
             
             @CodingDirective(.flatten)
             let address: Address
             
             @Codable
             struct Address {
                 let city: String
                 let state: String
             }
         }
         => { "name" : "Joe", "city" : "Cupertino", "state": "CA" }
         */
        struct Person: JSONDecodable, Equatable {
            let name: String
            let address: Address
            
            struct Address: JSONDecodable, Equatable {
                let city: String
                let state: String
                
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Address {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var city: String?
                        var state: String?
                        
                        try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                            switch key {
                            case "city": city = try valueDecoder.decode(String.self)
                            case "state": state = try valueDecoder.decode(String.self)
                            default: return // SKip unknown.
                            }
                        }
                        guard let city, let state else { throw CodingError.dataCorrupted(debugDescription: "Missing required fields") }
                        return Person.Address(city: city, state: state)
                    }
                }
            }
                        
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Person {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    let requiredFields = 1
                    var requiredFieldsSeen = 0
                    
                    var name: String?
                    var intermediateStorage = structDecoder.prepareIntermediateValueStorage()

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "name":
                            name = try valueDecoder.decode(String.self)
                            requiredFieldsSeen += 1
                        default:
                            intermediateStorage.append((key: key, value: try valueDecoder.decodeJSONPrimitive()))
                        }
                        // Stop if we've parsed only the fields needed for this type.
                        return requiredFieldsSeen == requiredFields && intermediateStorage.isEmpty
                    }
                    guard let name else { throw CodingError.dataCorrupted(debugDescription: "Missing 'name' field") }
                    
                    let address: Address
                    if requiredFields == requiredFieldsSeen, intermediateStorage.isEmpty {
                        address = try structDecoder.withWrappingDecoder { wrappingDecoder throws(CodingError.Decoding) in
                            try wrappingDecoder.decode(Address.self)
                        }
                    } else {
                        var decoder = JSONPrimitiveDecoder(keysAndValues: intermediateStorage, codingPath: structDecoder.codingPath)
                        address = try decoder.decode(Address.self)
                    }
                    
                    return Person(name: name, address: address)
                }
            }
        }
        
        let json = Data("""
            { "name" : "Joe", "city" : "Cupertino", "state": "CA" }
            """.utf8)
        let decoder = NewJSONDecoder()
        let result = try decoder.decode(Person.self, from: json)
        
        let expectation = Person(name: "Joe", address: .init(city: "Cupertino", state: "CA"))
        #expect(result == expectation)
                
        let json_outOfOrder = Data("""
            { "city" : "Cupertino", "state": "CA", "name" : "Joe" }
            """.utf8)
        let result_outOfOrder = try decoder.decode(Person.self, from: json_outOfOrder)
        #expect(result_outOfOrder == expectation)
    }
    
    // TODO: Update with New CommonDecodable conformance.
    @Test func testEnums() throws {
        enum Tests: Codable, JSONDecodable/*, CommonDecodable*/, Equatable {
            case allUntagged(Int, Int, Int)
            case someTagged(first: Int, Int, Int)
            case allTagged(first: Int, second: Int, third: Int)
            case singleUntagged(Int)
            
            enum AllUntaggedFields: Int, JSONOptimizedDecodingField {
                case _0 = 0
                case _1
                case _2
                
                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Self {
                    switch UTF8SpanComparator(key) {
                    case "_0": ._0
                    case "_1": ._1
                    case "_2": ._2
                    default: throw CodingError.unknownKey(key)
                    }
                }
                
                @inline(__always)
                var staticString: StaticString {
                    switch self {
                    case ._0: "_0"
                    case ._1: "_1"
                    case ._2: "_2"
                    }
                }
            }
            
            enum SomeTaggedFields: Int, JSONOptimizedDecodingField {
                case first = 0
                case _1
                case _2
                
                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Self {
                    switch UTF8SpanComparator(key) {
                    case "first": .first
                    case "_1": ._1
                    case "_2": ._2
                    default: throw CodingError.unknownKey(key)
                    }
                }
                
                @inline(__always)
                var staticString: StaticString {
                    switch self {
                    case .first: "first"
                    case ._1: "_1"
                    case ._2: "_2"
                    }
                }
            }
            
            enum AllTaggedFields: Int, JSONOptimizedDecodingField {
                case first = 0
                case second
                case third
                
                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Self {
                    switch UTF8SpanComparator(key) {
                    case "first": .first
                    case "second": .second
                    case "third": .third
                    default: throw CodingError.unknownKey(key)
                    }
                }
                
                @inline(__always)
                var staticString: StaticString {
                    switch self {
                    case .first: "first"
                    case .second: "second"
                    case .third: "third"
                    }
                }
            }
            
            enum SingleUntaggedFields: Int, JSONOptimizedDecodingField {
                case _0 = 0
                
                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Self {
                    switch UTF8SpanComparator(key) {
                    case "_0": ._0
                    default: throw CodingError.unknownKey(key)
                    }
                }
                
                @inline(__always)
                var staticString: StaticString {
                    switch self {
                    case ._0: "_0"
                    }
                }
            }
            
            enum CodingFields: Int, JSONOptimizedDecodingField, EncodingField {
                case allUntagged
                case someTagged
                case allTagged
                case singleUntagged
                
                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Self {
                    switch UTF8SpanComparator(key) {
                    case "allUntagged": .allUntagged
                    case "someTagged": .someTagged
                    case "allTagged": .allTagged
                    case "singleUntagged": .singleUntagged
                    default: throw CodingError.unknownKey(key)
                    }
                }
                
                @inline(__always)
                var staticString: StaticString {
                    switch self {
                    case .allUntagged: "allUntagged"
                    case .someTagged: "someTagged"
                    case .allTagged: "allTagged"
                    case .singleUntagged: "singleUntagged"
                    }
                }
            }
            
            static func decodeAllUntagged(from decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> Tests {
                var _0: Int?
                var _1: Int?
                var _2: Int?
                var key: AllUntaggedFields?
                try decoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                    key = try fieldDecoder.decode(AllUntaggedFields.self)
                } andValue: { valueDecoder throws(CodingError.Decoding) in
                    switch key! {
                    case ._0: _0 = try valueDecoder.decode(Int.self)
                    case ._1: _1 = try valueDecoder.decode(Int.self)
                    case ._2: _2 = try valueDecoder.decode(Int.self)
                    }
                }
                guard let _0, let _1, let _2 else {
                    throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                }
                return .allUntagged(_0, _1, _2)
            }
            
            static func decodeSomeTagged(from decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> Tests {
                var first: Int?
                var _1: Int?
                var _2: Int?
                var key: SomeTaggedFields?
                try decoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                    key = try fieldDecoder.decode(SomeTaggedFields.self)
                } andValue: { valueDecoder throws(CodingError.Decoding) in
                    switch key! {
                    case .first: first = try valueDecoder.decode(Int.self)
                    case ._1: _1 = try valueDecoder.decode(Int.self)
                    case ._2: _2 = try valueDecoder.decode(Int.self)
                    }
                }
                guard let first, let _1, let _2 else {
                    throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                }
                return .someTagged(first: first, _1, _2)
            }
            
            static func decodeAllTagged(from decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> Tests {
                var first: Int?
                var second: Int?
                var third: Int?
                var key: AllTaggedFields?
                try decoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                    key = try fieldDecoder.decode(AllTaggedFields.self)
                } andValue: { valueDecoder throws(CodingError.Decoding) in
                    switch key! {
                    case .first: first = try valueDecoder.decode(Int.self)
                    case .second: second = try valueDecoder.decode(Int.self)
                    case .third: third = try valueDecoder.decode(Int.self)
                    }
                }
                guard let first, let second, let third else {
                    throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                }
                return .allTagged(first: first, second: second, third: third)
            }
            
            static func decodeSingleUntagged(from decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> Tests {
                var _0: Int?
                var key: SingleUntaggedFields?
                try decoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                    key = try fieldDecoder.decode(SingleUntaggedFields.self)
                } andValue: { valueDecoder throws(CodingError.Decoding) in
                    switch key! {
                    case ._0: _0 = try valueDecoder.decode(Int.self)
                    }
                }
                guard let _0 else {
                    throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                }
                return .singleUntagged(_0)
            }
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Tests {
                return try decoder.decodeEnumCase { fieldDecoder, valuesDecoder throws(CodingError.Decoding) in
                    let field = try fieldDecoder.decode(CodingFields.self)
                    return switch field {
                    case .allUntagged: try decodeAllUntagged(from: &valuesDecoder)
                    case .someTagged: try decodeSomeTagged(from: &valuesDecoder)
                    case .allTagged: try decodeAllTagged(from: &valuesDecoder)
                    case .singleUntagged: try decodeSingleUntagged(from: &valuesDecoder)
                    }
                }
            }
        }
        
        let tests = [
            Tests.allUntagged(1, 2, 3),
            Tests.someTagged(first: 1, 2, 3),
            Tests.allTagged(first: 1, second: 2, third: 3),
            Tests.singleUntagged(42),
        ]
        
        let enc = JSONEncoder()
        let result = try enc.encode(tests)
        
        let decoder = NewJSONDecoder()
        let decoded = try decoder.decode([Tests].self, from: result)
        #expect(decoded == tests)
        
        // TODO: Exercise the CommonDecodable implementation.
        let commonDecoded = try decoder.decode([Tests].self, from: result)
        #expect(commonDecoded == tests)
        
        enum NoAssociatedType: Codable, JSONDecodable, Equatable {
            case one
            case two
            case three
            
            enum CodingFields: Int, JSONOptimizedDecodingField {
                case one
                case two
                case three
                
                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Self {
                    switch UTF8SpanComparator(key) {
                    case "one": .one
                    case "two": .two
                    case "three": .three
                    default: throw CodingError.unknownKey(key)
                    }
                }
                
                @inline(__always)
                var staticString: StaticString {
                    switch self {
                    case .one: "one"
                    case .two: "two"
                    case .three: "three"
                    }
                }
            }
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> NoAssociatedType {
                try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                    let field = try fieldDecoder.decode(CodingFields.self)
                    return switch field {
                    case .one: .one
                    case .two: .two
                    case .three: .three
                    }
                }
            }
        }
        let tests2 = [NoAssociatedType.one, NoAssociatedType.two, NoAssociatedType.three]
        let result2 = try enc.encode(tests2)
        #expect(String(data: result2, encoding: .utf8)! == #"[{"one":{}},{"two":{}},{"three":{}}]"#)
        
        enum NoAssociatedType_String: String, Codable, JSONCodable {
            case one
            case two
            case three
        }
        let result3 = try enc.encode([NoAssociatedType_String.one])
        #expect(String(data: result3, encoding: .utf8)! == #"["one"]"#)
        
        enum NoAssociatedType_Int: Int, Codable, JSONCodable {
            case one = 1
            case two
            case three
        }
        let result4 = try enc.encode([NoAssociatedType_Int.one])
        #expect(String(data: result4, encoding: .utf8)! == #"[1]"#)
    }
    
    @Test func testInternallyTaggedEnum() throws {
        /*
         @Codable
         @CodingDirective(.internallyTagged(key: "case"))
         enum InternallyTagged {
         case foo(label: String)
         }
         */
        
        enum InternallyTagged: JSONDecodable, Equatable {
            case foo(label: String)
            case bar(other: String)
            
            static func decodeFoo(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> InternallyTagged {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var label: String?
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        guard key == "label" else { throw CodingError.unknownKey(key.utf8Span) }
                        label = try valueDecoder.decode(String.self)
                        return ()
                    }
                    guard let label else { throw CodingError.dataCorrupted(debugDescription: "Missing enum associated values") }
                    return .foo(label: label)
                }
            }
            
            static func decodeBar(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> InternallyTagged {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var other: String?
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        guard key == "other" else { throw CodingError.unknownKey(key.utf8Span) }
                        other = try valueDecoder.decode(String.self)
                        return ()
                    }
                    guard let other else { throw CodingError.dataCorrupted(debugDescription: "Missing enum associated values") }
                    return .bar(other: other)
                }
            }
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> InternallyTagged {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var decodedCase: String?
                    var contents = structDecoder.prepareIntermediateValueStorage()
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "case":
                            decodedCase = try valueDecoder.decode(String.self)
                            return contents.isEmpty // If it's empty, then we can reuse the decoder.
                        default:
                            contents.append((key: key, value: try valueDecoder.decodeJSONPrimitive()))
                            return false // Keep going.
                        }
                    }
                    guard let decodedCase else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing enum case")
                    }
                    let unknownError = CodingError.unknownKey(decodedCase.utf8Span)
                    // TODO: It'd be nice to figure out how to encapsulate this.
                    if contents.isEmpty {
                        return try structDecoder.withWrappingDecoder { wrappingDecoder throws(CodingError.Decoding) in
                            switch decodedCase {
                            case "foo":
                                try decodeFoo(from: &wrappingDecoder)
                            case "bar":
                                try decodeBar(from: &wrappingDecoder)
                            default:
                                throw unknownError
                            }
                        }
                    } else {
                        var valueDecoder = JSONPrimitiveDecoder(keysAndValues: contents, codingPath: structDecoder.codingPath)
                        switch decodedCase {
                        case "foo":
                            return try decodeFoo(from: &valueDecoder)
                        case "bar":
                            return try decodeBar(from: &valueDecoder)
                        default:
                            throw unknownError
                        }
                    }
                }
            }
        }
        let expected = [InternallyTagged.foo(label: "hello"), .bar(other: "42")]
        
        let json_inOrder = Data("""
[ { "case" : "foo", "label" : "hello" }, { "case" : "bar", "other" : "42" } ]
""".utf8)
        let decoder = NewJSONDecoder()
        let inOrder = try decoder.decode([InternallyTagged].self, from: json_inOrder)
        #expect(inOrder == expected)
        
        let json_outOfOrder = Data("""
[ { "label" : "hello", "case" : "foo" }, { "other" : "42", "case" : "bar" } ]
""".utf8)
        let outOfOrder = try decoder.decode([InternallyTagged].self, from: json_outOfOrder)
        #expect(outOfOrder == expected)
    }
    
    @Test func testDefaultValue() throws {
        let emptyJSON = Data("{}".utf8)
        let decoder = NewJSONDecoder()
        let result = try decoder.decode(CodableStructWithDefaultedProperty.self, from: emptyJSON)
        #expect(result.bar == "hello")
    }
    
    @Test func testAliases() throws {
        let qux = Data("{ \"qux\" : \"hello\" }".utf8)
        let decoder = NewJSONDecoder()
        let result = try decoder.decode(CodableStructWithAliasedProperty.self, from: qux)
        #expect(result.bar == "hello")
    }

    @JSONCodable
    struct Person: Equatable {
        let name: String
        let address: Address
        
        struct Address: Codable, Equatable {
            let city: String
            let state: String
            let zip: Int
        }
    }
    
    @Test func testEmbeddedEncodableForJSON() throws {
        let testValue = Person(
            name: "John",
            address: .init(city: "Cupertino", state: "CA", zip: 95014)
        )
        
        let data = try NewJSONEncoder().encode(testValue)
        let redecoded = try NewJSONDecoder().decode(Person.self, from: data)
        #expect(testValue == redecoded)
    }
    
    @Test func testEmbeddedEncodableForCommon() throws {
        struct PersonCommon: CommonCodable, Equatable {
            let name: String
            let address: Address
            
            struct Address: Codable, Equatable {
                let city: String
                let state: String
                let zip: Int
            }
            
            func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                try encoder.encodeDictionary(elementCount: 2) { dictEncoder throws(CodingError.Encoding) in
                    try dictEncoder.encode(key: "name", value: name)
                    try dictEncoder.encode(key: "address", value: address)
                }
            }
            
            static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> PersonCommon {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var name: String?
                    var address: Address?
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "name":
                            name = try valueDecoder.decode(String.self)
                        case "address":
                            address = try valueDecoder.decode(Address.self)
                        default:
                            break // Skip unknown keys
                        }
                        return false
                    }
                    
                    guard let name, let address else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                    }
                    return PersonCommon(name: name, address: address)
                }
            }
        }
        
        let testValue = PersonCommon(
            name: "John",
            address: .init(city: "Cupertino", state: "CA", zip: 95014)
        )
        
        let data = try NewJSONEncoder().encode(testValue)
        let redecoded = try NewJSONDecoder().decode(PersonCommon.self, from: data)
        #expect(testValue == redecoded)
    }
    
    @Test func testEncodeEnums() throws {
        enum Tests: JSONEncodable, Decodable, Equatable {
            enum CaseDecodingFields: Int, JSONOptimizedEncodingField {
                case allUntagged
                case someTagged
                case allTagged
                case singleUntagged
                
                var staticString: StaticString {
                    switch self {
                    case .allUntagged: "allUntagged"
                    case .someTagged: "someTagged"
                    case .allTagged: "allTagged"
                    case .singleUntagged: "singleUntagged"
                    }
                }
            }
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                switch self {
                case .allUntagged(let _0, let _1, let _2):
                    enum DecodingFields: Int, JSONOptimizedEncodingField {
                        case _0
                        case _1
                        case _2
                        
                        var staticString: StaticString {
                            switch self {
                            case ._0: "_0"
                            case ._1: "_1"
                            case ._2: "_2"
                            }
                        }
                    }
                    // TODO: Bring back the ability to encode the field directly?
                    try encoder.encodeEnumCase(CaseDecodingFields.allUntagged, associatedValueCount: 3) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(field: DecodingFields._0, value: _0)
                        try valueEncoder.encode(field: DecodingFields._1, value: _1)
                        try valueEncoder.encode(field: DecodingFields._2, value: _2)
                    }
                case .someTagged(let first, let _1, let _2):
                    enum DecodingFields: Int, JSONOptimizedEncodingField {
                        case first
                        case _1
                        case _2
                        
                        var staticString: StaticString {
                            switch self {
                            case .first: "first"
                            case ._1: "_1"
                            case ._2: "_2"
                            }
                        }
                    }
                    try encoder.encodeEnumCase(CaseDecodingFields.someTagged, associatedValueCount: 3) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(field: DecodingFields.first, value: first)
                        try valueEncoder.encode(field: DecodingFields._1, value: _1)
                        try valueEncoder.encode(field: DecodingFields._2, value: _2)
                    }
                case .allTagged(let first, let second, let third):
                    enum DecodingFields: Int, JSONOptimizedEncodingField {
                        case first
                        case second
                        case third
                        
                        var staticString: StaticString {
                            switch self {
                            case .first: "first"
                            case .second: "second"
                            case .third: "third"
                            }
                        }
                    }
                    try encoder.encodeEnumCase(CaseDecodingFields.allTagged, associatedValueCount: 3) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(field: DecodingFields.first, value: first)
                        try valueEncoder.encode(field: DecodingFields.second, value: second)
                        try valueEncoder.encode(field: DecodingFields.third, value: third)
                    }
                case .singleUntagged(let _0):
                    enum DecodingFields: Int, JSONOptimizedEncodingField {
                        case _0
                        var staticString: StaticString { "_0" }
                    }
                    try encoder.encodeEnumCase(CaseDecodingFields.singleUntagged, associatedValueCount: 1) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(field: DecodingFields._0, value: _0)
                    }
                }
            }
            
            case allUntagged(Int, Int, Int)
            case someTagged(first: Int, Int, Int)
            case allTagged(first: Int, second: Int, third: Int)
            case singleUntagged(Int)
        }
        
        let tests = [
            Tests.allUntagged(1, 2, 3),
            Tests.someTagged(first: 1, 2, 3),
            Tests.allTagged(first: 1, second: 2, third: 3),
            Tests.singleUntagged(42),
        ]
        
        let encoder = NewJSONEncoder()
        let data = try encoder.encode(tests)
        
        let decoded = try JSONDecoder().decode([Tests].self, from: data)
        #expect(decoded == tests)
    }
    
    @Test func testIntegerKeyDictionary() throws {
        let dict = [42:42]
        let expected = """
        {"42":42}
        """
        
        let encoded = try NewJSONEncoder().encode(dict)
        #expect(expected == String(data: encoded, encoding: .utf8)!)
        
        let decoded = try NewJSONDecoder().decode([Int:Int].self, from: encoded)
        #expect(dict == decoded)
    }
    
    @Test func testCodingStringKeyRepresentableDictionary() throws {
        enum Foo: CodingStringKeyRepresentable, Equatable {
            case foo
            
            struct KeyDecodingVisitor: DecodingStringVisitor {
                typealias DecodedValue = Foo
                func visitUTF8Bytes(_ span: UTF8Span) throws(CodingError.Decoding) -> Foo {
                    #expect(String(copying: span) == "foo")
                    return .foo
                }
            }
            
            static var codingStringKeyVisitor: KeyDecodingVisitor { .init() }
            
            func withCodingStringUTF8Span<R, E>(_ body: (UTF8Span) throws(E) -> R) throws(E) -> R where E : Error {
                try body("foo".utf8Span)
            }
        }
        
        let dict = [Foo.foo:42]
        let expected = """
        {"foo":42}
        """
        
        let encoded = try NewJSONEncoder().encode(dict)
        #expect(expected == String(data: encoded, encoding: .utf8)!)
        
        let decoded = try NewJSONDecoder().decode([Foo:Int].self, from: encoded)
        #expect(dict == decoded)
    }
    
    @Test func testJSONPrimitiveNumber() throws {
        let decoder = NewJSONDecoder()
        
        // Test positive integer
        let positiveInt = Data("42".utf8)
        let positiveValue = try decoder.decode(JSONPrimitive.self, from: positiveInt)
        guard case .number(let positiveNumber) = positiveValue else {
            Issue.record("Expected number")
            return
        }
        #expect(try positiveNumber[Int64.self] == 42)
        #expect(try positiveNumber[UInt64.self] == 42)
        #expect(try positiveNumber[Int.self] == 42)
        #expect(try positiveNumber[Double.self] == 42.0)
        #expect(positiveNumber.extendedPrecisionRepresentation == "42")
        
        // Test negative integer
        let negativeInt = Data("-42".utf8)
        let negativeValue = try decoder.decode(JSONPrimitive.self, from: negativeInt)
        guard case .number(let negativeNumber) = negativeValue else {
            Issue.record("Expected number")
            return
        }
        #expect(try negativeNumber[Int64.self] == -42)
        #expect(try negativeNumber[Int.self] == -42)
        #expect(try negativeNumber[Double.self] == -42.0)
        #expect(negativeNumber.extendedPrecisionRepresentation == "-42")
        
        // Test Int64.max
        let int64Max = Data("9223372036854775807".utf8)
        let int64MaxValue = try decoder.decode(JSONPrimitive.self, from: int64Max)
        guard case .number(let int64MaxNumber) = int64MaxValue else {
            Issue.record("Expected number")
            return
        }
        #expect(try int64MaxNumber[Int64.self] == Int64.max)
        #expect(try int64MaxNumber[UInt64.self] == UInt64(Int64.max))
        #expect(int64MaxNumber.extendedPrecisionRepresentation == "9223372036854775807")
        
        // Test Int64.min
        let int64Min = Data("-9223372036854775808".utf8)
        let int64MinValue = try decoder.decode(JSONPrimitive.self, from: int64Min)
        guard case .number(let int64MinNumber) = int64MinValue else {
            Issue.record("Expected number")
            return
        }
        #expect(try int64MinNumber[Int64.self] == Int64.min)
        #expect(int64MinNumber.extendedPrecisionRepresentation == "-9223372036854775808")
        
        // Test UInt64.max
        let uint64Max = Data("18446744073709551615".utf8)
        let uint64MaxValue = try decoder.decode(JSONPrimitive.self, from: uint64Max)
        guard case .number(let uint64MaxNumber) = uint64MaxValue else {
            Issue.record("Expected number")
            return
        }
        #expect(try uint64MaxNumber[UInt64.self] == UInt64.max)
        #expect(uint64MaxNumber.extendedPrecisionRepresentation == "18446744073709551615")
        
        // Test floating point (with space workaround for EOF issue)
        let floatingPoint = Data("3.14159 ".utf8)
        let floatingValue = try decoder.decode(JSONPrimitive.self, from: floatingPoint)
        guard case .number(let floatingNumber) = floatingValue else {
            Issue.record("Expected number")
            return
        }
        let floatValue = try floatingNumber[Double.self]
        #expect(abs(floatValue - 3.14159) < 0.00001)
        #expect(floatingNumber.extendedPrecisionRepresentation == "3.14159")
        
        // Test zero
        let zero = Data("0".utf8)
        let zeroValue = try decoder.decode(JSONPrimitive.self, from: zero)
        guard case .number(let zeroNumber) = zeroValue else {
            Issue.record("Expected number")
            return
        }
        #expect(try zeroNumber[Int64.self] == 0)
        #expect(try zeroNumber[UInt64.self] == 0)
        #expect(try zeroNumber[Double.self] == 0.0)
        #expect(zeroNumber.extendedPrecisionRepresentation == "0")
        
        // Test scientific notation
        let scientific = Data("1.5e2 ".utf8)
        let scientificValue = try decoder.decode(JSONPrimitive.self, from: scientific)
        guard case .number(let scientificNumber) = scientificValue else {
            Issue.record("Expected number")
            return
        }
        let sciValue = try scientificNumber[Double.self]
        #expect(abs(sciValue - 150.0) < 0.00001)
        #expect(scientificNumber.extendedPrecisionRepresentation == "1.5e2")
        
        // Test negative scientific notation
        let negativeScientific = Data("-2.5e-3 ".utf8)
        let negativeScientificValue = try decoder.decode(JSONPrimitive.self, from: negativeScientific)
        guard case .number(let negativeScientificNumber) = negativeScientificValue else {
            Issue.record("Expected number")
            return
        }
        let negSciValue = try negativeScientificNumber[Double.self]
        #expect(abs(negSciValue - (-0.0025)) < 0.000001)
        #expect(negativeScientificNumber.extendedPrecisionRepresentation == "-2.5e-3")
        
        // Test arbitrary precision (very large exponent)
        let arbitraryPrecision = Data("1234567890.000000000000000001e9999999999999999".utf8)
        let arbitraryValue = try decoder.decode(JSONPrimitive.self, from: arbitraryPrecision)
        guard case .number(let arbitraryNumber) = arbitraryValue else {
            Issue.record("Expected number")
            return
        }
        #expect(arbitraryNumber.extendedPrecisionRepresentation == "1234567890.000000000000000001e9999999999999999")
        
        // Test negative zero
        let negativeZero = Data("-0".utf8)
        let negativeZeroValue = try decoder.decode(JSONPrimitive.self, from: negativeZero)
        guard case .number(let negativeZeroNumber) = negativeZeroValue else {
            Issue.record("Expected number")
            return
        }
        #expect(try negativeZeroNumber[Int64.self] == 0)
        #expect(negativeZeroNumber.extendedPrecisionRepresentation == "-0")
        
        // Test very small decimal
        let verySmall = Data("0.0000000001 ".utf8)
        let verySmallValue = try decoder.decode(JSONPrimitive.self, from: verySmall)
        guard case .number(let verySmallNumber) = verySmallValue else {
            Issue.record("Expected number")
            return
        }
        let smallValue = try verySmallNumber[Double.self]
        #expect(abs(smallValue - 0.0000000001) < 0.00000000001)
        #expect(verySmallNumber.extendedPrecisionRepresentation == "0.0000000001")
        
        // Test large scientific notation positive exponent
        let largeScientific = Data("1.23e10 ".utf8)
        let largeScientificValue = try decoder.decode(JSONPrimitive.self, from: largeScientific)
        guard case .number(let largeScientificNumber) = largeScientificValue else {
            Issue.record("Expected number")
            return
        }
        let largeSciValue = try largeScientificNumber[Double.self]
        #expect(abs(largeSciValue - 12300000000.0) < 1.0)
        #expect(largeScientificNumber.extendedPrecisionRepresentation == "1.23e10")
    }
    
    @Test func testNumberVisitor() throws {
        // Test visitor that tracks which number type was visited
        struct NumberTypeVisitor: JSONDecodingVisitor {
            enum NumberType: Equatable {
                case int64(Int64)
                case uint64(UInt64)
                case double(Double)
            }
            
            typealias DecodedValue = NumberType
            
            var prefersArbitraryPrecisionNumbers: Bool { false }
            
            // DecodingNumberVisitor requirements
            func visit(_ integer: Int64) throws(CodingError.Decoding) -> NumberType {
                .int64(integer)
            }
            
            func visit(_ integer: UInt64) throws(CodingError.Decoding) -> NumberType {
                .uint64(integer)
            }
            
            func visit(_ double: Double) throws(CodingError.Decoding) -> NumberType {
                .double(double)
            }
            
            // DecodingBoolVisitor requirement
            func visit(_ bool: Bool) throws(CodingError.Decoding) -> NumberType {
                fatalError("Not testing booleans")
            }
            
            // DecodingStringVisitor requirement
            func visitUTF8Bytes(_ span: UTF8Span) throws(CodingError.Decoding) -> NumberType {
                fatalError("Not testing strings")
            }
            
            // JSONDecodingVisitor requirements
            func visit(decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> NumberType {
                fatalError("Not testing dictionaries")
            }
            
            func visit(decoder: inout some JSONArrayDecoder & ~Escapable) throws(CodingError.Decoding) -> NumberType {
                fatalError("Not testing sequences")
            }
            
            func visitArbitraryPrecisionNumber(_ span: UTF8Span) throws(CodingError.Decoding) -> NumberType {
                fatalError("Not testing arbitrary precision")
            }
            
            func visitArbitraryPrecisionNumber(_ string: String) throws(CodingError.Decoding) -> NumberType {
                fatalError("Not testing arbitrary precision")
            }
            
            func visitNone() throws(CodingError.Decoding) -> NumberType {
                fatalError("Not testing null")
            }
        }
        
        // Wrapper type to decode using the visitor
        struct VisitorWrapper: JSONDecodable {
            let result: NumberTypeVisitor.NumberType
            
            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> VisitorWrapper {
                let result = try decoder.decodeAny(NumberTypeVisitor())
                return VisitorWrapper(result: result)
            }
        }
        
        let decoder = NewJSONDecoder()
        
        // Test positive integer
        let positiveInt = Data("42".utf8)
        let positiveResult = try decoder.decode(VisitorWrapper.self, from: positiveInt)
        #expect(positiveResult.result == .uint64(42))
        
        // Test negative integer
        let negativeInt = Data("-42".utf8)
        let negativeResult = try decoder.decode(VisitorWrapper.self, from: negativeInt)
        #expect(negativeResult.result == .int64(-42))
        
        // Test large positive integer
        let largePositive = Data("9223372036854775807".utf8) // Int64.max
        let largePositiveResult = try decoder.decode(VisitorWrapper.self, from: largePositive)
        #expect(largePositiveResult.result == .uint64(UInt64(Int64.max)))
        
        // Test large negative integer
        let largeNegative = Data("-9223372036854775808".utf8) // Int64.min
        let largeNegativeResult = try decoder.decode(VisitorWrapper.self, from: largeNegative)
        #expect(largeNegativeResult.result == .int64(Int64.min))

        // Test very large unsigned integer (UInt64)
        let veryLargeUnsigned = Data("18446744073709551615".utf8) // UInt64.max
        let veryLargeResult = try decoder.decode(VisitorWrapper.self, from: veryLargeUnsigned)
        #expect(veryLargeResult.result == .uint64(UInt64.max))

        
        // TODO: Deal with EOF problem with floating parsing. Ideally need alternative not based on strtod, but may need to explicitly copy and pad when the top decoded value is a number, like classic JSONDecoder.
        // Test floating point
        let floatingPoint = Data("3.14159 ".utf8)
        let floatingPointResult = try decoder.decode(VisitorWrapper.self, from: floatingPoint)
        if case .double(let value) = floatingPointResult.result {
            #expect(abs(value - 3.14159) < 0.00001)
        } else {
            Issue.record("Expected double")
        }
        
        // Test zero
        let zero = Data("0".utf8)
        let zeroResult = try decoder.decode(VisitorWrapper.self, from: zero)
        #expect(zeroResult.result == .uint64(0))
        
        // Test scientific notation
        let scientific = Data("1.5e2 ".utf8)
        let scientificResult = try decoder.decode(VisitorWrapper.self, from: scientific)
        if case .double(let value) = scientificResult.result {
            #expect(abs(value - 1.5e2) < 0.00001)
        } else {
            Issue.record("Expected double")
        }
        
        // Test negative scientific notation
        let negativeScientific = Data("-2.5e-3 ".utf8)
        let negativeScientificResult = try decoder.decode(VisitorWrapper.self, from: negativeScientific)
        if case .double(let value) = negativeScientificResult.result {
            #expect(abs(value - (-2.5e-3)) < 0.000001)
        } else {
            Issue.record("Expected double")
        }
        
        // Test arbitrary precision number that exceeds all primitive types
        // This number is beyond UInt64.max and beyond Double's precision
        struct ArbitraryPrecisionVisitor: JSONDecodingVisitor {
            typealias DecodedValue = String
            
            var prefersArbitraryPrecisionNumbers: Bool { true }
            
            func visitArbitraryPrecisionNumber(_ span: UTF8Span) throws(CodingError.Decoding) -> String {
                String(copying: span)
            }
            
            func visitArbitraryPrecisionNumber(_ string: String) throws(CodingError.Decoding) -> String {
                string
            }
            
            func visit(_ integer: Int64) throws(CodingError.Decoding) -> String {
                fatalError("Should prefer arbitrary precision")
            }
            
            func visit(_ integer: UInt64) throws(CodingError.Decoding) -> String {
                fatalError("Should prefer arbitrary precision")
            }
            
            func visit(_ double: Double) throws(CodingError.Decoding) -> String {
                fatalError("Should prefer arbitrary precision")
            }
            
            func visit(_ bool: Bool) throws(CodingError.Decoding) -> String {
                fatalError("Not testing booleans")
            }
            
            func visitUTF8Bytes(_ span: UTF8Span) throws(CodingError.Decoding) -> String {
                fatalError("Not testing strings")
            }
            
            func visit(decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> String {
                fatalError("Not testing dictionaries")
            }
            
            func visit(decoder: inout some JSONArrayDecoder & ~Escapable) throws(CodingError.Decoding) -> String {
                fatalError("Not testing sequences")
            }
            
            func visitNone() throws(CodingError.Decoding) -> String {
                fatalError("Not testing null")
            }
        }
        
        struct ArbitraryWrapper: JSONDecodable {
            let representation: String
            
            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> ArbitraryWrapper {
                let representation = try decoder.decodeAny(ArbitraryPrecisionVisitor())
                return ArbitraryWrapper(representation: representation)
            }
        }
        
        // Number far beyond UInt64.max with high precision
        let hugeNumber = Data("99999999999999999999999999999999999999999999999999.123456789123456789".utf8)
        let hugeResult = try decoder.decode(ArbitraryWrapper.self, from: hugeNumber)
        #expect(hugeResult.representation == "99999999999999999999999999999999999999999999999999.123456789123456789")
        
        // Number with massive exponent
        let massiveExponent = Data("1.23456789e308".utf8)
        let massiveResult = try decoder.decode(ArbitraryWrapper.self, from: massiveExponent)
        #expect(massiveResult.representation == "1.23456789e308")
    }
    
    @Test func testContext() throws {
        struct Aggregate: JSONDecodable, Equatable {
            let count: Int
            let suffixedStrings: [String]
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Aggregate {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var count: Int?
                    var suffixedStrings: [String]?
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "integers":
                            var counter = CounterContext()
                            _ = try valueDecoder.decode(IntArraySum.self, context: &counter)
                            count = counter.count
                        case "strings":
                            var suffixer = StringSuffixerContext(suffix: "-foo")
                            let result = try valueDecoder.decode(SuffixedStringArray.self, context: &suffixer)
                            suffixedStrings = result.strings
                        default:
                            return false // Keep going.
                        }
                        return false
                    }
                    
                    guard let count, let suffixedStrings else { throw CodingError.dataCorrupted(debugDescription: "Missing required fields") }
                    return .init(count: count, suffixedStrings: suffixedStrings)
                }
            }
        }
            
        struct CounterContext {
            var count: Int = 0
        }
        
        struct IntArraySum: JSONDecodableWithContext {
            typealias JSONDecodingContext = CounterContext
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable, context: inout CounterContext) throws(CodingError.Decoding) -> IntArraySum {
                try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
                    try arrayDecoder.decodeEachElement { elementDecoder throws(CodingError.Decoding) in
                        let next = try elementDecoder.decode(Int.self)
                        context.count += next
                    }
                }
                return IntArraySum()
            }
        }
        
        struct StringSuffixerContext {
            let suffix: String
        }
        
        struct SuffixedStringArray: JSONDecodableWithContext {
            typealias JSONDecodingContext = StringSuffixerContext
            
            let strings: [String]
            
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable, context: inout StringSuffixerContext) throws(CodingError.Decoding) -> SuffixedStringArray {
                var strings: [String] = []
                try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
                    try arrayDecoder.decodeEachElement { elementDecoder throws(CodingError.Decoding) in
                        let next = try elementDecoder.decode(String.self)
                        strings.append(next + context.suffix)
                    }
                }
                return SuffixedStringArray(strings: strings)
            }
        }
        
        let data = """
{
    "integers":  [1, 2, 3, 4, 5],
    "strings": ["a", "b", "c", "d" ]
}
""".data(using: .utf8)!
        
        let decoded = try NewJSONDecoder().decode(Aggregate.self, from: data)
        let expected = Aggregate(count: 15, suffixedStrings: ["a-foo", "b-foo", "c-foo", "d-foo"])
        #expect(decoded == expected)
    }
    
    @Test func jsonNonConformingFloat() throws {
        // TODO: Restore CommonE/D implementations.
        struct Test: JSONEncodable, JSONDecodable, Equatable {
            struct OldCodable: Codable, Equatable {
                let doubles: [Double]

                static func == (lhs: Self, rhs: Self) -> Bool {
                    return [Double].nanAllowableEqual(lhs: lhs.doubles, rhs: rhs.doubles)
                }
            }
            let array: [Double]
            let old: OldCodable
            
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(key: "array", value: array)
                    try structEncoder.encode(key: "old", value: old)
                }
            }
            
            static func decode<D>(from decoder: inout D) throws(CodingError.Decoding) -> Test where D : JSONDecoderProtocol, D : ~Escapable {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var array: [Double]?
                    var old: OldCodable?
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "array": array = try valueDecoder.decode([Double].self)
                        case "old": old = try valueDecoder.decode(OldCodable.self)
                        default: throw CodingError.unknownKey(key.utf8Span)
                        }
                    }
                    return .init(array: array!, old: old!)
                }
            }
            
            static func == (lhs: Self, rhs: Self) -> Bool {
                [Double].nanAllowableEqual(lhs: lhs.array, rhs: rhs.array) /*&& lhs.old == rhs.old*/
            }
        }
        
        let test = Test(array: [.infinity, -.infinity, .nan, 100], old: .init(doubles: [.infinity, -.infinity, .nan, 100]))
        
        let encoder = NewJSONEncoder(options: .init(nonConformingFloatEncodingStrategy: .convertToString(positiveInfinity: "POSINF", negativeInfinity: "NEGINF", nan: "NANEINF")))
        let data = try encoder.encode(test)

        let expectedData = """
            {"array":["POSINF","NEGINF","NANEINF",100],"old":{"doubles":["POSINF","NEGINF","NANEINF",100]}}
            """.data(using: .utf8)

        #expect(data == expectedData)
        
        let decoder = NewJSONDecoder(options: .init(nonConformingFloatDecodingStrategy: .convertFromString(positiveInfinity: "POSINF", negativeInfinity: "NEGINF", nan: "NANEINF")))
        let decoded = try decoder.decode(Test.self, from: data)
        
        #expect(decoded == test)
        
        #expect(throws: CodingError.Encoding.self) {
            try NewJSONEncoder().encode(test)
        }
        
        #expect(throws: CodingError.Decoding.self) {
            try NewJSONDecoder().decode(Test.self, from: data)
        }
    }
    
    @Test func testPrettyEncoding() throws {
        // TODO: More extensive testing.
        struct Test: JSONEncodable {
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(key: "foo", value: "bar")
                    try structEncoder.encode(key: "num", value: 42)
                    try structEncoder.encode(key: "dict", value: ["A":"B"])
                }
            }
        }
        let expected = #"""
            {
              "foo" : "bar",
              "num" : 42,
              "dict" : {
                "A" : "B"
              }
            }
            """#
        let encoder = NewJSONEncoder(options: .init(pretty: true))
        let data = try encoder.encode(Test())
        #expect(String(data: data, encoding: .utf8)! == expected)
    }
    
    // TODO: Increased coverage of coding paths over all the variations of methods.
    
    @Test func testBasicCodingPaths() throws {
        struct CodingPathCapture: JSONDecodable {
            let capturedPaths: [String]
            
            static func decode<D: JSONDecoderProtocol & ~Escapable>(
                from decoder: inout D
            ) throws(CodingError.Decoding) -> CodingPathCapture {
                var paths: [String] = []
                paths.append(decoder.codingPath.description)
                
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    paths.append(structDecoder.codingPath.description)
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        paths.append("key(\(key)): \(valueDecoder.codingPath.description)")
                        return false
                    }
                }
                
                return CodingPathCapture(capturedPaths: paths)
            }
        }
        
        let json = """
            {
                "name": "Alice",
                "age": 30
            }
            """
        
        let expectedPaths = [
            "",  // root path
            "",  // struct decoder path  
            "key(name): name",
            "key(age): age"
        ]
        
        // Test JSONParserDecoder
        let jsonData = Data(json.utf8)
        let parserDecoder = NewJSONDecoder()
        let parserResult = try parserDecoder.decode(CodingPathCapture.self, from: jsonData)
        
        #expect(parserResult.capturedPaths == expectedPaths)
        
        // Test JSONPrimitiveDecoder
        let jsonValue = try parserDecoder.decode(JSONPrimitive.self, from: jsonData)
        var valueDecoder = JSONPrimitiveDecoder(value: jsonValue)
        let valueResult = try valueDecoder.decode(CodingPathCapture.self)
        
        #expect(valueResult.capturedPaths == expectedPaths)
    }
    
    @Test func testNestedStructCodingPaths() throws {
        struct CodingPathCapture: JSONDecodable {
            let capturedPaths: [String]
            
            static func decode<D: JSONDecoderProtocol & ~Escapable>(
                from decoder: inout D
            ) throws(CodingError.Decoding) -> CodingPathCapture {
                var paths: [String] = []
                paths.append("root: \(decoder.codingPath.description)")
                
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    paths.append("struct: \(structDecoder.codingPath.description)")
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        paths.append("key(\(key)): \(valueDecoder.codingPath.description)")
                        
                        switch key {
                        case "person":
                            try valueDecoder.decodeStruct { personDecoder throws(CodingError.Decoding) in
                                paths.append("person struct: \(personDecoder.codingPath.description)")
                                
                                try personDecoder.decodeEachKeyAndValue { personKey, personValueDecoder throws(CodingError.Decoding) in
                                    paths.append("person key(\(personKey)): \(personValueDecoder.codingPath.description)")
                                    
                                    switch personKey {
                                    case "name": 
                                        _ = try personValueDecoder.decode(String.self)
                                    case "address":
                                        try personValueDecoder.decodeStruct { addressDecoder throws(CodingError.Decoding) in
                                            paths.append("address struct: \(addressDecoder.codingPath.description)")
                                            
                                            try addressDecoder.decodeEachKeyAndValue { addressKey, addressValueDecoder throws(CodingError.Decoding) in
                                                paths.append("address key(\(addressKey)): \(addressValueDecoder.codingPath.description)")
                                                _ = try addressValueDecoder.decode(String.self)
                                                return false
                                            }
                                        }
                                    default:
                                        break
                                    }
                                    return false
                                }
                            }
                        default:
                            break
                        }
                        return false
                    }
                }
                
                return CodingPathCapture(capturedPaths: paths)
            }
        }
        
        let json = """
            {
                "person": {
                    "name": "Bob",
                    "address": {
                        "street": "123 Main St",
                        "city": "Springfield"
                    }
                }
            }
            """
        
        let expectedPaths = [
            "root: ",
            "struct: ",
            "key(person): person",
            "person struct: person",
            "person key(name): person.name",
            "person key(address): person.address",
            "address struct: person.address",
            "address key(street): person.address.street",
            "address key(city): person.address.city"
        ]
        
        // Test JSONParserDecoder
        let jsonData = Data(json.utf8)
        let parserDecoder = NewJSONDecoder()
        let parserResult = try parserDecoder.decode(CodingPathCapture.self, from: jsonData)
        
        #expect(parserResult.capturedPaths == expectedPaths)
        
        // Test JSONPrimitiveDecoder
        let jsonValue = try parserDecoder.decode(JSONPrimitive.self, from: jsonData)
        var valueDecoder = JSONPrimitiveDecoder(value: jsonValue)
        let valueResult = try valueDecoder.decode(CodingPathCapture.self)
        
        #expect(valueResult.capturedPaths == expectedPaths)
    }
    
    @Test func testArrayCodingPaths() throws {
        struct CodingPathCapture: JSONDecodable {
            let capturedPaths: [String]
            
            static func decode<D: JSONDecoderProtocol & ~Escapable>(
                from decoder: inout D
            ) throws(CodingError.Decoding) -> CodingPathCapture {
                var paths: [String] = []
                paths.append("root: \(decoder.codingPath.description)")
                
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    paths.append("struct: \(structDecoder.codingPath.description)")
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        paths.append("key(\(key)): \(valueDecoder.codingPath.description)")
                        
                        switch key {
                        case "items":
                            try valueDecoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
                                paths.append("array: \(arrayDecoder.codingPath.description)")
                                
                                try arrayDecoder.decodeEachElement { elementDecoder throws(CodingError.Decoding) in
                                    paths.append("array element: \(elementDecoder.codingPath.description)")
                                    
                                    try elementDecoder.decodeStruct { itemStructDecoder throws(CodingError.Decoding) in
                                        paths.append("item struct: \(itemStructDecoder.codingPath.description)")
                                        
                                        try itemStructDecoder.decodeEachKeyAndValue { itemKey, itemValueDecoder throws(CodingError.Decoding) in
                                            paths.append("item key(\(itemKey)): \(itemValueDecoder.codingPath.description)")
                                            _ = try itemValueDecoder.decode(String.self)
                                            return false
                                        }
                                    }
                                }
                            }
                        default:
                            break
                        }
                        return false
                    }
                }
                
                return CodingPathCapture(capturedPaths: paths)
            }
        }
        
        let json = """
            {
                "items": [
                    {"id": "item1", "name": "First"},
                    {"id": "item2", "name": "Second"}
                ]
            }
            """
        
        let expectedPaths = [
            "root: ",
            "struct: ",
            "key(items): items",
            "array: items",
            "array element: items[0]",
            "item struct: items[0]",
            "item key(id): items[0].id",
            "item key(name): items[0].name",
            "array element: items[1]",
            "item struct: items[1]",
            "item key(id): items[1].id",
            "item key(name): items[1].name"
        ]
        
        // Test JSONParserDecoder
        let jsonData = Data(json.utf8)
        let parserDecoder = NewJSONDecoder()
        let parserResult = try parserDecoder.decode(CodingPathCapture.self, from: jsonData)
        
        #expect(parserResult.capturedPaths == expectedPaths)
        
        // Test JSONPrimitiveDecoder
        let jsonValue = try parserDecoder.decode(JSONPrimitive.self, from: jsonData)
        var valueDecoder = JSONPrimitiveDecoder(value: jsonValue)
        let valueResult = try valueDecoder.decode(CodingPathCapture.self)
        
        #expect(valueResult.capturedPaths == expectedPaths)
    }
    
    @Test func testMixedNestedCodingPaths() throws {
        struct CodingPathCapture: JSONDecodable {
            let capturedPaths: [String]
            
            static func decode<D: JSONDecoderProtocol & ~Escapable>(
                from decoder: inout D
            ) throws(CodingError.Decoding) -> CodingPathCapture {
                var paths: [String] = []
                paths.append("root: \(decoder.codingPath.description)")
                
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        paths.append("key(\(key)): \(valueDecoder.codingPath.description)")
                        
                        switch key {
                        case "company":
                            try valueDecoder.decodeStruct { companyDecoder throws(CodingError.Decoding) in
                                try companyDecoder.decodeEachKeyAndValue { companyKey, companyValueDecoder throws(CodingError.Decoding) in
                                    paths.append("company key(\(companyKey)): \(companyValueDecoder.codingPath.description)")
                                    
                                    switch companyKey {
                                    case "name":
                                        _ = try companyValueDecoder.decode(String.self)
                                    case "employees":
                                        try companyValueDecoder.decodeArray { employeesDecoder throws(CodingError.Decoding) in
                                            try employeesDecoder.decodeEachElement { employeeDecoder throws(CodingError.Decoding) in
                                                paths.append("employee: \(employeeDecoder.codingPath.description)")
                                                
                                                try employeeDecoder.decodeStruct { employeeStructDecoder throws(CodingError.Decoding) in
                                                    try employeeStructDecoder.decodeEachKeyAndValue { empKey, empValueDecoder throws(CodingError.Decoding) in
                                                        paths.append("emp key(\(empKey)): \(empValueDecoder.codingPath.description)")
                                                        
                                                        switch empKey {
                                                        case "name":
                                                            _ = try empValueDecoder.decode(String.self)
                                                        case "projects":
                                                            try empValueDecoder.decodeArray { projectsDecoder throws(CodingError.Decoding) in
                                                                try projectsDecoder.decodeEachElement { projectDecoder throws(CodingError.Decoding) in
                                                                    paths.append("project: \(projectDecoder.codingPath.description)")
                                                                    _ = try projectDecoder.decode(String.self)
                                                                }
                                                            }
                                                        default:
                                                            break
                                                        }
                                                        return false
                                                    }
                                                }
                                            }
                                        }
                                    default:
                                        break
                                    }
                                    return false
                                }
                            }
                        default:
                            break
                        }
                        return false
                    }
                }
                
                return CodingPathCapture(capturedPaths: paths)
            }
        }
        
        let json = """
            {
                "company": {
                    "name": "Tech Corp",
                    "employees": [
                        {
                            "name": "Alice",
                            "projects": ["ProjectA", "ProjectB"]
                        },
                        {
                            "name": "Bob", 
                            "projects": ["ProjectC"]
                        }
                    ]
                }
            }
            """
        
        let expectedPaths = [
            "root: ",
            "key(company): company",
            "company key(name): company.name",
            "company key(employees): company.employees",
            "employee: company.employees[0]",
            "emp key(name): company.employees[0].name",
            "emp key(projects): company.employees[0].projects",
            "project: company.employees[0].projects[0]",
            "project: company.employees[0].projects[1]",
            "employee: company.employees[1]",
            "emp key(name): company.employees[1].name",
            "emp key(projects): company.employees[1].projects",
            "project: company.employees[1].projects[0]"
        ]
        
        // Test JSONParserDecoder
        let jsonData = Data(json.utf8)
        let parserDecoder = NewJSONDecoder()
        let parserResult = try parserDecoder.decode(CodingPathCapture.self, from: jsonData)
        
        #expect(parserResult.capturedPaths == expectedPaths)
        
        // Test JSONPrimitiveDecoder
        let jsonValue = try parserDecoder.decode(JSONPrimitive.self, from: jsonData)
        var valueDecoder = JSONPrimitiveDecoder(value: jsonValue)
        let valueResult = try valueDecoder.decode(CodingPathCapture.self)
        
        #expect(valueResult.capturedPaths == expectedPaths)
    }
    
    @Test func testCodingPathOfEmbeddedDecodable() throws {
        struct ArrayContainer: CommonDecodable {
            let items: [DecodableItem]
            
            static func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var decodableItems: [DecodableItem] = []
                    
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        if key == "items" {
                            decodableItems = try valueDecoder.decode([DecodableItem].self)
                        }
                        return false
                    }
                    
                    return ArrayContainer(items: decodableItems)
                }
            }
        }
        
        struct DecodableItem: Decodable {
            let id: Int
            let capturedCodingPath: [any CodingKey]
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.capturedCodingPath = decoder.codingPath
                self.id = try container.decode(Int.self, forKey: .id)
            }
            
            enum CodingKeys: String, CodingKey {
                case id
            }
        }
        
        let jsonString = """
        {
            "items": [
                { "id": 100 },
                { "id": 200 },
                { "id": 300 }
            ]
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = NewJSONDecoder()
        let result = try decoder.decode(ArrayContainer.self, from: jsonData)
        
        #expect(result.items.count == 3)
        
        // Verify each item has the correct coding path with array indices
        Testing.__checkBinaryOperation(result.items[0].capturedCodingPath.count,{ $0 == $1() },2,expression: .__fromBinaryOperation(.__fromSyntaxNode("result.items[0].capturedCodingPath.count"),"==",.__fromSyntaxNode("2")),comments: [.__line("// Verify each item has the correct coding path with array indices")],isRequired: false,sourceLocation: Testing.SourceLocation.__here()).__expected()
        #expect(result.items[0].capturedCodingPath[0].stringValue == "items")
        #expect(result.items[0].capturedCodingPath[1].intValue == 0)
        #expect(result.items[0].id == 100)
        
        #expect(result.items[1].capturedCodingPath.count == 2)
        #expect(result.items[1].capturedCodingPath[0].stringValue == "items")
        #expect(result.items[1].capturedCodingPath[1].intValue == 1)
        #expect(result.items[1].id == 200)
        
        #expect(result.items[2].capturedCodingPath.count == 2)
        #expect(result.items[2].capturedCodingPath[0].stringValue == "items")
        #expect(result.items[2].capturedCodingPath[1].intValue == 2)
        #expect(result.items[2].id == 300)
    }
}

extension Array where Element: BinaryFloatingPoint {
    static func nanAllowableEqual(lhs: Element, rhs: Element) -> Bool {
        if lhs.isNaN && rhs.isNaN { return true }
        return lhs == rhs
    }
    
    static func nanAllowableEqual(lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var i1 = lhs.makeIterator()
        var i2 = rhs.makeIterator()
        while let e1 = i1.next(), let e2 = i2.next() {
            if !nanAllowableEqual(lhs: e1, rhs: e2) { return false }
        }
        return true
    }
}
