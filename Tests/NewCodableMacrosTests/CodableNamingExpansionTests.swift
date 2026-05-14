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

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftSyntaxMacrosGenericTestSupport
import Testing
import NewCodableMacros

@Suite("CodableNaming Macro Expansion")
struct CodableNamingExpansionTests {

    // MARK: - Struct fieldNaming Tests

    @Test func structFieldNamingSnakeCase() {
        AssertMacroExpansion(
            """
            @JSONCodable(fieldNaming: .snake_case)
            struct User {
                let userName: String
                let imageURL: String
                let parseHTTPResponse: Int
            }
            """,
            expandedSource: """
            struct User {
                let userName: String
                let imageURL: String
                let parseHTTPResponse: Int
            }

            extension User {
                enum JSONCodingFields: JSONOptimizedCodingField {
                    case userName
                    case imageURL
                    case parseHTTPResponse
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .userName:
                            "user_name"
                        case .imageURL:
                            "image_url"
                        case .parseHTTPResponse:
                            "parse_http_response"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "user_name":
                            .userName
                        case "image_url":
                            .imageURL
                        case "parse_http_response":
                            .parseHTTPResponse
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension User: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 3) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.userName, value: self.userName)
                        try structEncoder.encode(field: JSONCodingFields.imageURL, value: self.imageURL)
                        try structEncoder.encode(field: JSONCodingFields.parseHTTPResponse, value: self.parseHTTPResponse)
                    }
                }
            }

            extension User: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> User {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var userName: String?
                        var imageURL: String?
                        var parseHTTPResponse: Int?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .userName:
                                userName = try valueDecoder.decode(String.self)
                            case .imageURL:
                                imageURL = try valueDecoder.decode(String.self)
                            case .parseHTTPResponse:
                                parseHTTPResponse = try valueDecoder.decode(Int.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let userName else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'user_name'")
                        }
                        guard let imageURL else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'image_url'")
                        }
                        guard let parseHTTPResponse else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'parse_http_response'")
                        }
                        return User(userName: userName, imageURL: imageURL, parseHTTPResponse: parseHTTPResponse)
                    }
                }
            }
            """,
            macros: namingTestMacros
        )
    }

    @Test func structFieldNamingPascalCase() {
        AssertMacroExpansion(
            """
            @JSONCodable(fieldNaming: .PascalCase)
            struct User {
                let userName: String
                let imageURL: String
                let parseHTTPResponse: Int
            }
            """,
            expandedSource: """
            struct User {
                let userName: String
                let imageURL: String
                let parseHTTPResponse: Int
            }

            extension User {
                enum JSONCodingFields: JSONOptimizedCodingField {
                    case userName
                    case imageURL
                    case parseHTTPResponse
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .userName:
                            "UserName"
                        case .imageURL:
                            "ImageUrl"
                        case .parseHTTPResponse:
                            "ParseHttpResponse"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "UserName":
                            .userName
                        case "ImageUrl":
                            .imageURL
                        case "ParseHttpResponse":
                            .parseHTTPResponse
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension User: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 3) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.userName, value: self.userName)
                        try structEncoder.encode(field: JSONCodingFields.imageURL, value: self.imageURL)
                        try structEncoder.encode(field: JSONCodingFields.parseHTTPResponse, value: self.parseHTTPResponse)
                    }
                }
            }

            extension User: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> User {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var userName: String?
                        var imageURL: String?
                        var parseHTTPResponse: Int?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .userName:
                                userName = try valueDecoder.decode(String.self)
                            case .imageURL:
                                imageURL = try valueDecoder.decode(String.self)
                            case .parseHTTPResponse:
                                parseHTTPResponse = try valueDecoder.decode(Int.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let userName else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'UserName'")
                        }
                        guard let imageURL else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'ImageUrl'")
                        }
                        guard let parseHTTPResponse else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'ParseHttpResponse'")
                        }
                        return User(userName: userName, imageURL: imageURL, parseHTTPResponse: parseHTTPResponse)
                    }
                }
            }
            """,
            macros: namingTestMacros
        )
    }

    // MARK: - Struct fieldNaming with @CodingKey Override

    @Test func structFieldNamingWithCodingKeyOverride() {
        AssertMacroExpansion(
            """
            @JSONCodable(fieldNaming: .snake_case)
            struct User {
                let userName: String
                let imageURL: String
                @CodingKey("custom_email") let emailAddress: String
            }
            """,
            expandedSource: """
            struct User {
                let userName: String
                let imageURL: String
                let emailAddress: String
            }

            extension User {
                enum JSONCodingFields: JSONOptimizedCodingField {
                    case userName
                    case imageURL
                    case emailAddress
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .userName:
                            "user_name"
                        case .imageURL:
                            "image_url"
                        case .emailAddress:
                            "custom_email"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "user_name":
                            .userName
                        case "image_url":
                            .imageURL
                        case "custom_email":
                            .emailAddress
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension User: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 3) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.userName, value: self.userName)
                        try structEncoder.encode(field: JSONCodingFields.imageURL, value: self.imageURL)
                        try structEncoder.encode(field: JSONCodingFields.emailAddress, value: self.emailAddress)
                    }
                }
            }

            extension User: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> User {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var userName: String?
                        var imageURL: String?
                        var emailAddress: String?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .userName:
                                userName = try valueDecoder.decode(String.self)
                            case .imageURL:
                                imageURL = try valueDecoder.decode(String.self)
                            case .emailAddress:
                                emailAddress = try valueDecoder.decode(String.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let userName else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'user_name'")
                        }
                        guard let imageURL else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'image_url'")
                        }
                        guard let emailAddress else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'custom_email'")
                        }
                        return User(userName: userName, imageURL: imageURL, emailAddress: emailAddress)
                    }
                }
            }
            """,
            macros: namingTestMacros
        )
    }

    // MARK: - Struct fieldNaming with @DecodableAlias

    @Test func structFieldNamingWithDecodableAlias() {
        AssertMacroExpansion(
            """
            @JSONCodable(fieldNaming: .snake_case)
            struct User {
                @DecodableAlias("legacyUserName") let userName: String
                let imageURL: String
            }
            """,
            expandedSource: """
            struct User {
                let userName: String
                let imageURL: String
            }

            extension User {
                enum JSONCodingFields: JSONOptimizedCodingField {
                    case userName
                    case imageURL
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .userName:
                            "user_name"
                        case .imageURL:
                            "image_url"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "user_name":
                            .userName
                        case "legacyUserName":
                            .userName
                        case "image_url":
                            .imageURL
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension User: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.userName, value: self.userName)
                        try structEncoder.encode(field: JSONCodingFields.imageURL, value: self.imageURL)
                    }
                }
            }

            extension User: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> User {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var userName: String?
                        var imageURL: String?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .userName:
                                userName = try valueDecoder.decode(String.self)
                            case .imageURL:
                                imageURL = try valueDecoder.decode(String.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let userName else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'user_name'")
                        }
                        guard let imageURL else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'image_url'")
                        }
                        return User(userName: userName, imageURL: imageURL)
                    }
                }
            }
            """,
            macros: namingTestMacros
        )
    }

    // MARK: - Enum caseNaming Tests

    @Test func enumCaseNamingSnakeCase() {
        AssertMacroExpansion(
            """
            @JSONCodable(caseNaming: .snake_case)
            enum Status {
                case inProgress
                case parseHTTPError
            }
            """,
            expandedSource: """
            enum Status {
                case inProgress
                case parseHTTPError
            }

            extension Status {
                enum JSONCodingFields: JSONOptimizedCodingField {
                    case inProgress
                    case parseHTTPError

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .inProgress:
                            "in_progress"
                        case .parseHTTPError:
                            "parse_http_error"
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "in_progress":
                            .inProgress
                        case "parse_http_error":
                            .parseHTTPError
                        default:
                            throw CodingError.unknownKey(key)
                        }
                    }
                }
            }

            extension Status: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    switch self {
                    case .inProgress:
                        try encoder.encodeEnumCase(JSONCodingFields.inProgress)
                    case .parseHTTPError:
                        try encoder.encodeEnumCase(JSONCodingFields.parseHTTPError)
                    }
                }
            }

            extension Status: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Status {
                    var _codingField: JSONCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                        return switch _codingField! {
                        case .inProgress:
                            .inProgress
                        case .parseHTTPError:
                            .parseHTTPError
                        }
                    }
                }
            }
            """,
            macros: namingTestMacros
        )
    }

    // MARK: - Enum caseNaming + associatedValueLabelNaming

    @Test func enumCaseAndAssociatedValueNaming() {
        AssertMacroExpansion(
            """
            @JSONCodable(caseNaming: .snake_case, associatedValueLabelNaming: .snake_case)
            enum Event {
                case userLoggedIn(sessionID: String, Int)
                case parseHTTPError
            }
            """,
            expandedSource: """
            enum Event {
                case userLoggedIn(sessionID: String, Int)
                case parseHTTPError
            }

            extension Event {
                enum JSONCodingFields: JSONOptimizedCodingField {
                    case userLoggedIn
                    case parseHTTPError

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .userLoggedIn:
                            "user_logged_in"
                        case .parseHTTPError:
                            "parse_http_error"
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "user_logged_in":
                            .userLoggedIn
                        case "parse_http_error":
                            .parseHTTPError
                        default:
                            throw CodingError.unknownKey(key)
                        }
                    }

                    enum UserLoggedInFields: JSONOptimizedCodingField {
                        case session_id
                        case _1

                        @_transparent
                        var staticString: StaticString {
                            switch self {
                            case .session_id:
                                "session_id"
                            case ._1:
                                "_1"
                            }
                        }

                        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> UserLoggedInFields {
                            switch UTF8SpanComparator(key) {
                            case "session_id":
                                .session_id
                            case "_1":
                                ._1
                            default:
                                throw CodingError.unknownKey(key)
                            }
                        }

                        static func decode(from decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> Event {
                            var session_id: String?
                            var _1: Int?
                            var _field: UserLoggedInFields?
                            try decoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                                _field = try fieldDecoder.decode(UserLoggedInFields.self)
                            } andValue: { valueDecoder throws(CodingError.Decoding) in
                                switch _field! {
                                case .session_id:
                                    session_id = try valueDecoder.decode(String.self)
                                case ._1:
                                    _1 = try valueDecoder.decode(Int.self)
                                }
                            }
                            guard let session_id, let _1 else {
                                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                            }
                            return .userLoggedIn(sessionID: session_id, _1)
                        }
                    }
                }
            }

            extension Event: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    switch self {
                    case .userLoggedIn(let session_id, let _1):
                        try encoder.encodeEnumCase(JSONCodingFields.userLoggedIn, associatedValueCount: 2) { valueEncoder throws(CodingError.Encoding) in
                            try valueEncoder.encode(field: JSONCodingFields.UserLoggedInFields.session_id, value: session_id)
                            try valueEncoder.encode(field: JSONCodingFields.UserLoggedInFields._1, value: _1)
                        }
                    case .parseHTTPError:
                        try encoder.encodeEnumCase(JSONCodingFields.parseHTTPError)
                    }
                }
            }

            extension Event: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Event {
                    var _codingField: JSONCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                        return switch _codingField! {
                        case .userLoggedIn:
                            try JSONCodingFields.UserLoggedInFields.decode(from: &valuesDecoder)
                        case .parseHTTPError:
                            .parseHTTPError
                        }
                    }
                }
            }
            """,
            macros: namingTestMacros
        )
    }
}

private let namingTestMacros: [String: Macro.Type] = [
    "JSONCodable": JSONCodableMacro.self,
    "CodingKey": CodingKeyMacro.self,
    "DecodableAlias": DecodableAliasMacro.self,
]
