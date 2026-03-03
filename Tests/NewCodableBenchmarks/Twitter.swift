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


#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(ucrt)
import ucrt
#elseif canImport(WASILibc)
@preconcurrency import WASILibc
#endif

import NewCodable

public struct Indices {
    let _0: UInt8
    let _1: UInt8
}

extension Indices: Encodable, Decodable {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        guard container.count == 2 else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Wrong number of elements")) }
        let (first, second) = try (container.decode(UInt8.self), container.decode(UInt8.self))
        self = .init(_0: first, _1: second)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(_0)
        try container.encode(_1)
    }
}

extension Indices: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeArray(elementCount: 2) { arrayEncoder throws(CodingError.Encoding) in
            try arrayEncoder.encode(_0)
            try arrayEncoder.encode(_1)
        }
    }
}

extension Indices: JSONDecodable {
    public static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Self {
        let arr = try decoder.decode(InlineArray<2, UInt8>.self)
        return .init(_0: arr[0], _1: arr[1])
    }
}

struct IntString<T: FixedWidthInteger> {
    let integer: T
}

extension IntString: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let i = T(string) else {
            throw CodingError.dataCorrupted(debugDescription: "Bad integer string")
        }
        self.integer = i
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(integer.description)
    }
}

extension IntString: JSONDecodable {
    struct JSONVisitor: DecodingStringVisitor {
        typealias DecodedValue = IntString
        
        func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> DecodedValue {
            buffer.span.withUnsafeBytes {
                var end: UnsafeMutablePointer<CChar>? = UnsafeMutablePointer(mutating: $0.baseAddress!.assumingMemoryBound(to: CChar.self) + $0.count)
                return .init(integer: T(strtol($0.baseAddress!, &end, 10)))
            }
        }
    }
    
//    @_specialize(where D == JSONParserDecoder, T == ShortId)
//    @_specialize(where D == JSONParserDecoder, T == LongId)
//    @_specialize(where D == JSONPrimitiveDecoder, T == ShortId)
//    @_specialize(where D == JSONPrimitiveDecoder, T == LongId)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeString(JSONVisitor())
    }
}

extension IntString: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try integer.withDecimalDescriptionSpan { span throws(CodingError.Encoding) in
            try encoder.encodeString(UTF8Span(unchecked: span, isKnownASCII: true))
        }
    }
}

struct Twitter: Decodable, Encodable {
    let statuses: [Status]
    let search_metadata: SearchMetadata

    init(statuses: [Status], search_metadata: SearchMetadata) {
        self.statuses = statuses
        self.search_metadata = search_metadata
    }
}

extension Twitter: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case statuses
        case search_metadata
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .statuses: "statuses"
            case .search_metadata: "search_metadata"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "statuses": .statuses
            case "search_metadata": .search_metadata
            default: throw CodingError.unknownKey(key)
            }
        }
    }
    
    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Twitter {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var statuses: [Status]?
            var search_metadata: SearchMetadata?
            var field: Field?
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .statuses: statuses = try valueDecoder.decode([Status].self)
                case .search_metadata: search_metadata = try valueDecoder.decode(SearchMetadata.self)
                }
            }
            guard let statuses, let search_metadata else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return Twitter(statuses: statuses, search_metadata: search_metadata)
        }
    }
}

extension Twitter: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.statuses, value: statuses)
            try dictEncoder.encode(field: Field.search_metadata, value: search_metadata)
        }
    }
}

typealias LongId = UInt64
typealias ShortId = UInt32
typealias Color = String

final class Status: Decodable, Encodable {
    let metadata: Metadata
    let created_at: String
    let id: LongId
    let id_str: IntString<LongId>
    let text: String
    let source: String
    let truncated: Bool
    let in_reply_to_status_id: LongId?
    let in_reply_to_status_id_str: IntString<LongId>?
    let in_reply_to_user_id: ShortId?
    let in_reply_to_user_id_str: IntString<ShortId>?
    let in_reply_to_screen_name: String?
    let user: User
//    let geo: ()
//    let coordinates: ()
//    let place: ()
//    let contributors: ()
    let retweeted_status: Status?
    let retweet_count: UInt32
    let favorite_count: UInt32
    let entities: StatusEntities
    let favorited: Bool
    let retweeted: Bool
    let possibly_sensitive: Bool?
    let lang: LanguageCode

    init(metadata: Metadata, created_at: String, id: LongId, id_str: IntString<LongId>, text: String, source: String, truncated: Bool, in_reply_to_status_id: LongId?, in_reply_to_status_id_str: IntString<LongId>?, in_reply_to_user_id: ShortId?, in_reply_to_user_id_str: IntString<ShortId>?, in_reply_to_screen_name: String?, user: User, retweeted_status: Status?, retweet_count: UInt32, favorite_count: UInt32, entities: StatusEntities, favorited: Bool, retweeted: Bool, possibly_sensitive: Bool?, lang: LanguageCode) {
        self.metadata = metadata
        self.created_at = created_at
        self.id = id
        self.id_str = id_str
        self.text = text
        self.source = source
        self.truncated = truncated
        self.in_reply_to_status_id = in_reply_to_status_id
        self.in_reply_to_status_id_str = in_reply_to_status_id_str
        self.in_reply_to_user_id = in_reply_to_user_id
        self.in_reply_to_user_id_str = in_reply_to_user_id_str
        self.in_reply_to_screen_name = in_reply_to_screen_name
        self.user = user
        self.retweeted_status = retweeted_status
        self.retweet_count = retweet_count
        self.favorite_count = favorite_count
        self.entities = entities
        self.favorited = favorited
        self.retweeted = retweeted
        self.possibly_sensitive = possibly_sensitive
        self.lang = lang
    }
}

extension Status: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case metadata
        case created_at
        case id
        case id_str
        case text
        case source
        case truncated
        case in_reply_to_status_id
        case in_reply_to_status_id_str
        case in_reply_to_user_id
        case in_reply_to_user_id_str
        case in_reply_to_screen_name
        case user
        case retweeted_status
        case retweet_count
        case favorite_count
        case entities
        case favorited
        case retweeted
        case possibly_sensitive
        case lang
        case unknown
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .metadata: "metadata"
            case .created_at: "created_at"
            case .id: "id"
            case .id_str: "id_str"
            case .text: "text"
            case .source: "source"
            case .truncated: "truncated"
            case .in_reply_to_status_id: "in_reply_to_status_id"
            case .in_reply_to_status_id_str: "in_reply_to_status_id_str"
            case .in_reply_to_user_id: "in_reply_to_user_id"
            case .in_reply_to_user_id_str: "in_reply_to_user_id_str"
            case .in_reply_to_screen_name: "in_reply_to_screen_name"
            case .user: "user"
            case .retweeted_status: "retweeted_status"
            case .retweet_count: "retweet_count"
            case .favorite_count: "favorite_count"
            case .entities: "entities"
            case .favorited: "favorited"
            case .retweeted: "retweeted"
            case .possibly_sensitive: "possibly_sensitive"
            case .lang: "lang"
            case .unknown: "unknown"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            return switch UTF8SpanComparator(key) {
            case "metadata": .metadata
            case "created_at": .created_at
            case "id": .id
            case "id_str": .id_str
            case "text": .text
            case "source": .source
            case "truncated": .truncated
            case "in_reply_to_status_id": .in_reply_to_status_id
            case "in_reply_to_status_id_str": .in_reply_to_status_id_str
            case "in_reply_to_user_id": .in_reply_to_user_id
            case "in_reply_to_user_id_str": .in_reply_to_user_id_str
            case "in_reply_to_screen_name": .in_reply_to_screen_name
            case "user": .user
            case "retweeted_status": .retweeted_status
            case "retweet_count": .retweet_count
            case "favorite_count": .favorite_count
            case "entities": .entities
            case "favorited": .favorited
            case "retweeted": .retweeted
            case "possibly_sensitive": .possibly_sensitive
            case "lang": .lang
            default: .unknown
            }
        }
    }
    
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Status {
        if D.self == JSONParserDecoder.self {
            var parserDecoder = decoder as! JSONParserDecoder
            let result = try decode(from: &parserDecoder)
            decoder = parserDecoder as! D
            return result
        }
        
        return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var metadata: Metadata?
            var created_at: String?
            var id: LongId?
            var id_str: IntString<LongId>?
            var text: String?
            var source: String?
            var truncated: Bool?
            var in_reply_to_status_id: LongId?
            var in_reply_to_status_id_str: IntString<LongId>?
            var in_reply_to_user_id: ShortId?
            var in_reply_to_user_id_str: IntString<ShortId>?
            var in_reply_to_screen_name: String?
            var user: User?
            var retweeted_status: Status?
            var retweet_count: UInt32?
            var favorite_count: UInt32?
            var entities: StatusEntities?
            var favorited: Bool?
            var retweeted: Bool?
            var possibly_sensitive: Bool?
            var lang: LanguageCode?
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .metadata:
                    metadata = try valueDecoder.decode(Metadata.self)
                case .created_at:
                    created_at = try valueDecoder.decode(String.self)
                case .id:
                    id = try valueDecoder.decode(LongId.self)
                case .id_str:
                    id_str = try valueDecoder.decode(IntString<LongId>.self)
                case .text:
                    text = try valueDecoder.decode(String.self)
                case .source:
                    source = try valueDecoder.decode(String.self)
                case .truncated:
                    truncated = try valueDecoder.decode(Bool.self)
                case .in_reply_to_status_id:
                    in_reply_to_status_id = try valueDecoder.decode(LongId?.self)
                case .in_reply_to_status_id_str:
                    in_reply_to_status_id_str = try valueDecoder.decode(IntString<LongId>?.self)
                case .in_reply_to_user_id:
                    in_reply_to_user_id = try valueDecoder.decode(ShortId?.self)
                case .in_reply_to_user_id_str:
                    in_reply_to_user_id_str = try valueDecoder.decode(IntString<ShortId>?.self)
                case .in_reply_to_screen_name:
                    in_reply_to_screen_name = try valueDecoder.decode(String?.self)
                case .user:
                    user = try valueDecoder.decode(User?.self)
                case .retweeted_status:
                    retweeted_status = try valueDecoder.decode(Status?.self)
                case .retweet_count:
                    retweet_count = try valueDecoder.decode(UInt32.self)
                case .favorite_count:
                    favorite_count = try valueDecoder.decode(UInt32.self)
                case .entities:
                    entities = try valueDecoder.decode(StatusEntities.self)
                case .favorited:
                    favorited = try valueDecoder.decode(Bool.self)
                case .retweeted:
                    retweeted = try valueDecoder.decode(Bool.self)
                case .possibly_sensitive:
                    possibly_sensitive = try valueDecoder.decode(Bool?.self)
                case .lang:
                    lang = try valueDecoder.decode(LanguageCode.self)
                default:
                    //                        print("Unknown key: \(key)")
                    break
                }
            }
            guard let id, let id_str, let lang, let text, let source, let metadata, let user, let created_at, let retweet_count, let favorite_count, let entities, let truncated, let favorited, let retweeted else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return Status(metadata: metadata, created_at: created_at, id: id, id_str: id_str, text: text, source: source, truncated: truncated, in_reply_to_status_id: in_reply_to_status_id, in_reply_to_status_id_str: in_reply_to_status_id_str, in_reply_to_user_id: in_reply_to_user_id, in_reply_to_user_id_str: in_reply_to_user_id_str, in_reply_to_screen_name: in_reply_to_screen_name, user: user, retweeted_status: retweeted_status, retweet_count: retweet_count, favorite_count: favorite_count, entities: entities, favorited: favorited, retweeted: retweeted, possibly_sensitive: possibly_sensitive, lang: lang)
        }
    }
    
    @usableFromInline
    struct JSONBuilder: ~Copyable, ~Escapable {
        var metadata: Exclusive<Metadata>?
        var created_at: Exclusive<String>?
        var id: LongId?
        var id_str: IntString<LongId>?
        var text: Exclusive<String>?
        var source: Exclusive<String>?
        var truncated: Bool?
        var in_reply_to_status_id: LongId?
        var in_reply_to_status_id_str: IntString<LongId>?
        var in_reply_to_user_id: ShortId?
        var in_reply_to_user_id_str: IntString<ShortId>?
        var in_reply_to_screen_name: Exclusive<String>?
        var user: Exclusive<User>?
        var retweeted_status: Exclusive<Status>?
        var retweet_count: UInt32?
        var favorite_count: UInt32?
        var entities: Exclusive<StatusEntities>?
        var favorited: Bool?
        var retweeted: Bool?
        var possibly_sensitive: Bool?
        var lang: LanguageCode?
        
        @inline(__always)
        @_lifetime(copy structDecoder)
        init(structDecoder: JSONParserDecoder.StructDecoder) { }
        
        enum ExtraFields: Int, JSONOptimizedDecodingField {
            case geo
            case coordinates
            case place
            case contributors
            case unknown
            
            @_transparent
            var staticString: StaticString {
                switch self {
                case .geo: "geo"
                case .coordinates: "coordinates"
                case .place: "place"
                case .contributors: "contributors"
                case .unknown: "unknown"
                }
            }
            
            static func field(for key: UTF8Span) -> ExtraFields {
                return switch UTF8SpanComparator(key) {
                case "geo": .geo
                case "coordinates": .coordinates
                case "place": .place
                case "contributors": .contributors
                default: .unknown
                }
            }
        }
        
        struct NullMatcher: JSONDecodable {
            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                guard try decoder.decodeNil() else {
                    throw CodingError.dataCorrupted(debugDescription: "Expected null")
                }
                return .init()
            }
        }
        
        @inline(__always)
        @_lifetime(self: copy self)
        mutating func tryExpectedOrder(using structDecoder: inout JSONParserDecoder.StructDecoder) throws(CodingError.Decoding) {
            var inOrder = true
            try structDecoder.decodeExpectedOrderField(Field.metadata, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.metadata = Exclusive(try vd.decode(Metadata.self)) }
            try structDecoder.decodeExpectedOrderField(Field.created_at, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.created_at = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.id, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.id = try vd.decode(LongId.self) }
            try structDecoder.decodeExpectedOrderField(Field.id_str, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.id_str = try vd.decode(IntString<LongId>.self) }
            try structDecoder.decodeExpectedOrderField(Field.text, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.text = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.source, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.source = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.truncated, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.truncated = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.in_reply_to_status_id, inOrder: &inOrder, required: false) { vd throws(CodingError.Decoding) in self.in_reply_to_status_id = try vd.decode(LongId?.self) }
            try structDecoder.decodeExpectedOrderField(Field.in_reply_to_status_id_str, inOrder: &inOrder, required: false) { vd throws(CodingError.Decoding) in self.in_reply_to_status_id_str = try vd.decode(IntString<LongId>?.self) }
            try structDecoder.decodeExpectedOrderField(Field.in_reply_to_user_id, inOrder: &inOrder, required: false) { vd throws(CodingError.Decoding) in self.in_reply_to_user_id = try vd.decode(ShortId?.self) }
            try structDecoder.decodeExpectedOrderField(Field.in_reply_to_user_id_str, inOrder: &inOrder, required: false) { vd throws(CodingError.Decoding) in self.in_reply_to_user_id_str = try vd.decode(IntString<ShortId>?.self) }
            try structDecoder.decodeExpectedOrderField(Field.in_reply_to_screen_name, inOrder: &inOrder, required: false) { vd throws(CodingError.Decoding) in self.in_reply_to_screen_name = try vd.decode(String?.self).exclusive() }
            try structDecoder.decodeExpectedOrderField(Field.user, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.user = try vd.decode(User?.self).exclusive() }
            try structDecoder.decodeExpectedOrderField(ExtraFields.geo, inOrder: &inOrder) { vd throws(CodingError.Decoding) in _ = try vd.decode(NullMatcher.self) }
            try structDecoder.decodeExpectedOrderField(ExtraFields.coordinates, inOrder: &inOrder) { vd throws(CodingError.Decoding) in _ = try vd.decode(NullMatcher.self) }
            try structDecoder.decodeExpectedOrderField(ExtraFields.place, inOrder: &inOrder) { vd throws(CodingError.Decoding) in _ = try vd.decode(NullMatcher.self) }
            try structDecoder.decodeExpectedOrderField(ExtraFields.contributors, inOrder: &inOrder) { vd throws(CodingError.Decoding) in _ = try vd.decode(NullMatcher.self) }
            try structDecoder.decodeExpectedOrderField(Field.retweeted_status, inOrder: &inOrder, required: false) { vd throws(CodingError.Decoding) in self.retweeted_status = try vd.decode(Status?.self).exclusive() }
            try structDecoder.decodeExpectedOrderField(Field.retweet_count, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.retweet_count = try vd.decode(UInt32.self) }
            try structDecoder.decodeExpectedOrderField(Field.favorite_count, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.favorite_count = try vd.decode(UInt32.self) }
            try structDecoder.decodeExpectedOrderField(Field.entities, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.entities = Exclusive(try vd.decode(StatusEntities.self)) }
            try structDecoder.decodeExpectedOrderField(Field.favorited, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.favorited = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.retweeted, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.retweeted = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.possibly_sensitive, inOrder: &inOrder, required: false) { vd throws(CodingError.Decoding) in self.possibly_sensitive = try vd.decode(Bool?.self) }
            try structDecoder.decodeExpectedOrderField(Field.lang, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.lang = try vd.decode(LanguageCode.self) }
            
            if !inOrder {
                var field: Field = .unknown
                try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                    field = try keyDecoder.decode(Field.self)
                } andValue: { valueDecoder throws(CodingError.Decoding) in
                    _ = try self.accept(field: field, decoder: &valueDecoder)
                }
            }
        }
        
        @inline(never)
        @_lifetime(self: copy self)
        mutating func accept(field: Field, decoder valueDecoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Bool {
            switch field {
            case .metadata:
                metadata = Exclusive(try valueDecoder.decode(Metadata.self))
            case .created_at:
                created_at = Exclusive(try valueDecoder.decode(String.self))
            case .id:
                id = try valueDecoder.decode(LongId.self)
            case .id_str:
                id_str = try valueDecoder.decode(IntString<LongId>.self)
            case .text:
                text = Exclusive(try valueDecoder.decode(String.self))
            case .source:
                source = Exclusive(try valueDecoder.decode(String.self))
            case .truncated:
                truncated = try valueDecoder.decode(Bool.self)
            case .in_reply_to_status_id:
                in_reply_to_status_id = try valueDecoder.decode(LongId?.self)
            case .in_reply_to_status_id_str:
                in_reply_to_status_id_str = try valueDecoder.decode(IntString<LongId>?.self)
            case .in_reply_to_user_id:
                in_reply_to_user_id = try valueDecoder.decode(ShortId?.self)
            case .in_reply_to_user_id_str:
                in_reply_to_user_id_str = try valueDecoder.decode(IntString<ShortId>?.self)
            case .in_reply_to_screen_name:
                in_reply_to_screen_name = try valueDecoder.decode(String?.self).exclusive()
            case .user:
                user = try valueDecoder.decode(User?.self).exclusive()
            case .retweeted_status:
                retweeted_status = try valueDecoder.decode(Status?.self).exclusive()
            case .retweet_count:
                retweet_count = try valueDecoder.decode(UInt32.self)
            case .favorite_count:
                favorite_count = try valueDecoder.decode(UInt32.self)
            case .entities:
                entities = Exclusive(try valueDecoder.decode(StatusEntities.self))
            case .favorited:
                favorited = try valueDecoder.decode(Bool.self)
            case .retweeted:
                retweeted = try valueDecoder.decode(Bool.self)
            case .possibly_sensitive:
                possibly_sensitive = try valueDecoder.decode(Bool?.self)
            case .lang:
                lang = try valueDecoder.decode(LanguageCode.self)
            default:
                //                        print("Unknown key: \(key)")
                return false
            }
            return true
        }
        
        consuming func build() throws(CodingError.Decoding) -> Status {
            guard let id, let id_str, let lang, let text, let source, let metadata, let user, let created_at, let retweet_count, let favorite_count, let entities, let truncated, let favorited, let retweeted else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return Status(metadata: metadata.take(), created_at: created_at.take(), id: id, id_str: id_str, text: text.take(), source: source.take(), truncated: truncated, in_reply_to_status_id: in_reply_to_status_id, in_reply_to_status_id_str: in_reply_to_status_id_str, in_reply_to_user_id: in_reply_to_user_id, in_reply_to_user_id_str: in_reply_to_user_id_str, in_reply_to_screen_name: in_reply_to_screen_name?.take(), user: user.take(), retweeted_status: retweeted_status?.take(), retweet_count: retweet_count, favorite_count: favorite_count, entities: entities.take(), favorited: favorited, retweeted: retweeted, possibly_sensitive: possibly_sensitive, lang: lang)
        }
    }

    static func decode(from decoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Status {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var builder = JSONBuilder(structDecoder: structDecoder)
//            try withUnsafeMutablePointer(to: &builder) { bptr in
//                var field: Field = .unknown
//                try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
//                    field = try keyDecoder.decode(Field.self)
//                } andValue: { valueDecoder throws(CodingError.Decoding) in
//                    _ = try bptr.pointee.accept(field: field, decoder: &valueDecoder)
//                }
//            }
//            return try builder.build()
            try builder.tryExpectedOrder(using: &structDecoder)
            return try builder.build()
        }
    }
}

extension Status: JSONEncodable {
    
    func encode(to dictionary: inout JSONDirectEncoder.DictionaryEncoder) throws(CodingError.Encoding) {
        try dictionary.encode(field: Field.metadata, value: metadata)
        try dictionary.encode(field: Field.created_at, value: created_at)
        try dictionary.encode(field: Field.id, value: id)
        try dictionary.encode(field: Field.id_str, value: id_str)
        try dictionary.encode(field: Field.text, value: text)
        try dictionary.encode(field: Field.source, value: source)
        try dictionary.encode(field: Field.truncated, value: truncated)
        try dictionary.encode(field: Field.in_reply_to_status_id, value: in_reply_to_status_id)
        try dictionary.encode(field: Field.in_reply_to_status_id_str, value: in_reply_to_status_id_str)
        try dictionary.encode(field: Field.in_reply_to_user_id, value: in_reply_to_user_id)
        try dictionary.encode(field: Field.in_reply_to_user_id_str, value: in_reply_to_user_id_str)
        try dictionary.encode(field: Field.in_reply_to_screen_name, value: in_reply_to_screen_name)
        try dictionary.encode(field: Field.user, value: user)
        try dictionary.encode(field: Field.retweeted_status, value: retweeted_status)
        try dictionary.encode(field: Field.retweet_count, value: retweet_count)
        try dictionary.encode(field: Field.favorite_count, value: favorite_count)
        try dictionary.encode(field: Field.entities, value: entities)
        try dictionary.encode(field: Field.favorited, value: favorited)
        try dictionary.encode(field: Field.retweeted, value: retweeted)
        try dictionary.encode(field: Field.possibly_sensitive, value: possibly_sensitive)
        try dictionary.encode(field: Field.lang, value: lang)
    }
    
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try self.encode(to: &dictEncoder)
        }
    }
}


struct Metadata: Decodable, Encodable {
    let result_type: ResultType
    let iso_language_code: LanguageCode

    init(result_type: ResultType, iso_language_code: LanguageCode) {
        self.result_type = result_type
        self.iso_language_code = iso_language_code
    }
}

extension Metadata: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case result_type
        case iso_language_code
        case unknown
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .result_type: "result_type"
            case .iso_language_code: "iso_language_code"
            case .unknown: "unknown"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "result_type": .result_type
            case "iso_language_code": .iso_language_code
            default: .unknown
            }
        }
    }
    
    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var result_type: ResultType?
            var iso_language_code: LanguageCode?
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .result_type: result_type = try valueDecoder.decode(ResultType.self)
                case .iso_language_code: iso_language_code = try valueDecoder.decode(LanguageCode.self)
                default: break
                }
            }
            guard let result_type, let iso_language_code else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return Metadata(result_type: result_type, iso_language_code: iso_language_code)
        }
    }
}

extension Metadata: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.result_type, value: result_type)
            try dictEncoder.encode(field: Field.iso_language_code, value: iso_language_code)
        }
    }
}


struct User: Decodable, Encodable {
    let id: ShortId
    let id_str: IntString<ShortId>
    let name: String
    let screen_name: String
    let location: String
    let description: String
    let url: String?
    let entities: UserEntities
    let protected: Bool
    let followers_count: UInt32
    let friends_count: UInt32
    let listed_count: UInt32
    let created_at: String
    let favourites_count: UInt32
    let utc_offset: Int32?
    let time_zone: String?
    let geo_enabled: Bool
    let verified: Bool
    let statuses_count: UInt32
    let lang: LanguageCode
    let contributors_enabled: Bool
    let is_translator: Bool
    let is_translation_enabled: Bool
    let profile_background_color: Color
    let profile_background_image_url: String
    let profile_background_image_url_https: String
    let profile_background_tile: Bool
    let profile_image_url: String
    let profile_image_url_https: String
    let profile_banner_url: String?
    let profile_link_color: Color
    let profile_sidebar_border_color: Color
    let profile_sidebar_fill_color: Color
    let profile_text_color: Color
    let profile_use_background_image: Bool
    let default_profile: Bool
    let default_profile_image: Bool
    let following: Bool
    let follow_request_sent: Bool
    let notifications: Bool

    init(id: ShortId, id_str: IntString<ShortId>, name: String, screen_name: String, location: String, description: String, url: String?, entities: UserEntities, protected: Bool, followers_count: UInt32, friends_count: UInt32, listed_count: UInt32, created_at: String, favourites_count: UInt32, utc_offset: Int32?, time_zone: String?, geo_enabled: Bool, verified: Bool, statuses_count: UInt32, lang: LanguageCode, contributors_enabled: Bool, is_translator: Bool, is_translation_enabled: Bool, profile_background_color: Color, profile_background_image_url: String, profile_background_image_url_https: String, profile_background_tile: Bool, profile_image_url: String, profile_image_url_https: String, profile_banner_url: String?, profile_link_color: Color, profile_sidebar_border_color: Color, profile_sidebar_fill_color: Color, profile_text_color: Color, profile_use_background_image: Bool, default_profile: Bool, default_profile_image: Bool, following: Bool, follow_request_sent: Bool, notifications: Bool) {
        self.id = id
        self.id_str = id_str
        self.name = name
        self.screen_name = screen_name
        self.location = location
        self.description = description
        self.url = url
        self.entities = entities
        self.protected = protected
        self.followers_count = followers_count
        self.friends_count = friends_count
        self.listed_count = listed_count
        self.created_at = created_at
        self.favourites_count = favourites_count
        self.utc_offset = utc_offset
        self.time_zone = time_zone
        self.geo_enabled = geo_enabled
        self.verified = verified
        self.statuses_count = statuses_count
        self.lang = lang
        self.contributors_enabled = contributors_enabled
        self.is_translator = is_translator
        self.is_translation_enabled = is_translation_enabled
        self.profile_background_color = profile_background_color
        self.profile_background_image_url = profile_background_image_url
        self.profile_background_image_url_https = profile_background_image_url_https
        self.profile_background_tile = profile_background_tile
        self.profile_image_url = profile_image_url
        self.profile_image_url_https = profile_image_url_https
        self.profile_banner_url = profile_banner_url
        self.profile_link_color = profile_link_color
        self.profile_sidebar_border_color = profile_sidebar_border_color
        self.profile_sidebar_fill_color = profile_sidebar_fill_color
        self.profile_text_color = profile_text_color
        self.profile_use_background_image = profile_use_background_image
        self.default_profile = default_profile
        self.default_profile_image = default_profile_image
        self.following = following
        self.follow_request_sent = follow_request_sent
        self.notifications = notifications
    }
}

extension User: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case id
        case id_str
        case name
        case screen_name
        case location
        case description
        case url
        case entities
        case protected
        case followers_count
        case friends_count
        case listed_count
        case created_at
        case favourites_count
        case utc_offset
        case time_zone
        case geo_enabled
        case verified
        case statuses_count
        case lang
        case contributors_enabled
        case is_translator
        case is_translation_enabled
        case profile_background_color
        case profile_background_image_url
        case profile_background_image_url_https
        case profile_background_tile
        case profile_image_url
        case profile_image_url_https
        case profile_banner_url
        case profile_link_color
        case profile_sidebar_border_color
        case profile_sidebar_fill_color
        case profile_text_color
        case profile_use_background_image
        case default_profile
        case default_profile_image
        case following
        case follow_request_sent
        case notifications
        case unknown
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .id: "id"
            case .id_str: "id_str"
            case .name: "name"
            case .screen_name: "screen_name"
            case .location: "location"
            case .description: "description"
            case .url: "url"
            case .entities: "entities"
            case .protected: "protected"
            case .followers_count: "followers_count"
            case .friends_count: "friends_count"
            case .listed_count: "listed_count"
            case .created_at: "created_at"
            case .favourites_count: "favourites_count"
            case .utc_offset: "utc_offset"
            case .time_zone: "time_zone"
            case .geo_enabled: "geo_enabled"
            case .verified: "verified"
            case .statuses_count: "statuses_count"
            case .lang: "lang"
            case .contributors_enabled: "contributors_enabled"
            case .is_translator: "is_translator"
            case .is_translation_enabled: "is_translation_enabled"
            case .profile_background_color: "profile_background_color"
            case .profile_background_image_url: "profile_background_image_url"
            case .profile_background_image_url_https: "profile_background_image_url_https"
            case .profile_background_tile: "profile_background_tile"
            case .profile_image_url: "profile_image_url"
            case .profile_image_url_https: "profile_image_url_https"
            case .profile_banner_url: "profile_banner_url"
            case .profile_link_color: "profile_link_color"
            case .profile_sidebar_border_color: "profile_sidebar_border_color"
            case .profile_sidebar_fill_color: "profile_sidebar_fill_color"
            case .profile_text_color: "profile_text_color"
            case .profile_use_background_image: "profile_use_background_image"
            case .default_profile: "default_profile"
            case .default_profile_image: "default_profile_image"
            case .following: "following"
            case .follow_request_sent: "follow_request_sent"
            case .notifications: "notifications"
            case .unknown: "unknown"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "id": .id
            case "id_str": .id_str
            case "name": .name
            case "screen_name": .screen_name
            case "location": .location
            case "description": .description
            case "url": .url
            case "entities": .entities
            case "protected": .protected
            case "followers_count": .followers_count
            case "friends_count": .friends_count
            case "listed_count": .listed_count
            case "created_at": .created_at
            case "favourites_count": .favourites_count
            case "utc_offset": .utc_offset
            case "time_zone": .time_zone
            case "geo_enabled": .geo_enabled
            case "verified": .verified
            case "statuses_count": .statuses_count
            case "lang": .lang
            case "contributors_enabled": .contributors_enabled
            case "is_translator": .is_translator
            case "is_translation_enabled": .is_translation_enabled
            case "profile_background_color": .profile_background_color
            case "profile_background_image_url": .profile_background_image_url
            case "profile_background_image_url_https": .profile_background_image_url_https
            case "profile_background_tile": .profile_background_tile
            case "profile_image_url": .profile_image_url
            case "profile_image_url_https": .profile_image_url_https
            case "profile_banner_url": .profile_banner_url
            case "profile_link_color": .profile_link_color
            case "profile_sidebar_border_color": .profile_sidebar_border_color
            case "profile_sidebar_fill_color": .profile_sidebar_fill_color
            case "profile_text_color": .profile_text_color
            case "profile_use_background_image": .profile_use_background_image
            case "default_profile": .default_profile
            case "default_profile_image": .default_profile_image
            case "following": .following
            case "follow_request_sent": .follow_request_sent
            case "notifications": .notifications
            default: .unknown
            }
        }
    }
    
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        if D.self == JSONParserDecoder.self {
            var parserDecoder = decoder as! JSONParserDecoder
            let result = try decode(from: &parserDecoder)
            decoder = parserDecoder as! D
            return result
        }
        
        return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var id: ShortId?
            var id_str: IntString<ShortId>?
            var name: String?
            var screen_name: String?
            var location: String?
            var description: String?
            var url: String?
            var entities: UserEntities?
            var protected: Bool?
            var followers_count: UInt32?
            var friends_count: UInt32?
            var listed_count: UInt32?
            var created_at: String?
            var favourites_count: UInt32?
            var utc_offset: Int32?
            var time_zone: String?
            var geo_enabled: Bool?
            var verified: Bool?
            var statuses_count: UInt32?
            var lang: LanguageCode?
            var contributors_enabled: Bool?
            var is_translator: Bool?
            var is_translation_enabled: Bool?
            var profile_background_color: Color?
            var profile_background_image_url: String?
            var profile_background_image_url_https: String?
            var profile_background_tile: Bool?
            var profile_image_url: String?
            var profile_image_url_https: String?
            var profile_banner_url: String?
            var profile_link_color: Color?
            var profile_sidebar_border_color: Color?
            var profile_sidebar_fill_color: Color?
            var profile_text_color: Color?
            var profile_use_background_image: Bool?
            var default_profile: Bool?
            var default_profile_image: Bool?
            var following: Bool?
            var follow_request_sent: Bool?
            var notifications: Bool?

            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .id: id = try valueDecoder.decode(ShortId.self)
                case .id_str: id_str = try valueDecoder.decode(IntString<ShortId>.self)
                case .name: name = try valueDecoder.decode(String.self)
                case .screen_name: screen_name = try valueDecoder.decode(String.self)
                case .location: location = try valueDecoder.decode(String.self)
                case .description: description = try valueDecoder.decode(String.self)
                case .url: url = try valueDecoder.decode(String?.self)
                case .entities: entities = try valueDecoder.decode(UserEntities.self)
                case .protected: protected = try valueDecoder.decode(Bool.self)
                case .followers_count: followers_count = try valueDecoder.decode(UInt32.self)
                case .friends_count: friends_count = try valueDecoder.decode(UInt32.self)
                case .listed_count: listed_count = try valueDecoder.decode(UInt32.self)
                case .created_at: created_at = try valueDecoder.decode(String.self)
                case .favourites_count: favourites_count = try valueDecoder.decode(UInt32.self)
                case .utc_offset: utc_offset = try valueDecoder.decode(Int32?.self)
                case .time_zone: time_zone = try valueDecoder.decode(String?.self)
                case .geo_enabled: geo_enabled = try valueDecoder.decode(Bool.self)
                case .verified: verified = try valueDecoder.decode(Bool.self)
                case .statuses_count: statuses_count = try valueDecoder.decode(UInt32.self)
                case .lang: lang = try valueDecoder.decode(LanguageCode.self)
                case .contributors_enabled: contributors_enabled = try valueDecoder.decode(Bool.self)
                case .is_translator: is_translator = try valueDecoder.decode(Bool.self)
                case .is_translation_enabled: is_translation_enabled = try valueDecoder.decode(Bool.self)
                case .profile_background_color: profile_background_color = try valueDecoder.decode(String.self)
                case .profile_background_image_url: profile_background_image_url = try valueDecoder.decode(String.self)
                case .profile_background_image_url_https: profile_background_image_url_https = try valueDecoder.decode(String.self)
                case .profile_background_tile: profile_background_tile = try valueDecoder.decode(Bool.self)
                case .profile_image_url: profile_image_url = try valueDecoder.decode(String?.self)
                case .profile_image_url_https: profile_image_url_https = try valueDecoder.decode(String?.self)
                case .profile_banner_url: profile_banner_url = try valueDecoder.decode(String?.self)
                case .profile_link_color: profile_link_color = try valueDecoder.decode(String.self)
                case .profile_sidebar_border_color: profile_sidebar_border_color = try valueDecoder.decode(String.self)
                case .profile_sidebar_fill_color: profile_sidebar_fill_color = try valueDecoder.decode(String.self)
                case .profile_text_color: profile_text_color = try valueDecoder.decode(String.self)
                case .profile_use_background_image: profile_use_background_image = try valueDecoder.decode(Bool.self)
                case .default_profile: default_profile = try valueDecoder.decode(Bool.self)
                case .default_profile_image: default_profile_image = try valueDecoder.decode(Bool.self)
                case .following: following = try valueDecoder.decode(Bool.self)
                case .follow_request_sent: follow_request_sent = try valueDecoder.decode(Bool.self)
                case .notifications: notifications = try valueDecoder.decode(Bool.self)
                default:
                    //                        print("Unknown key: \(key)")
                    break
                }

            }
            guard let created_at, let default_profile, let description, let favourites_count, let followers_count, let friends_count, let id, let id_str, let lang, let name, let profile_background_color, let profile_background_image_url, let profile_use_background_image, let screen_name, let statuses_count, let verified, let entities, let protected, let listed_count, let contributors_enabled, let profile_link_color, let profile_background_image_url_https, let default_profile_image, let follow_request_sent, let notifications, let following, let profile_text_color, let profile_sidebar_fill_color, let profile_sidebar_border_color, let profile_image_url_https, let profile_background_tile, let profile_image_url, let is_translation_enabled, let is_translator, let geo_enabled, let location else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return User(id: id, id_str: id_str, name: name, screen_name: screen_name, location: location, description: description, url: url, entities: entities, protected: protected, followers_count: followers_count, friends_count: friends_count, listed_count: listed_count, created_at: created_at, favourites_count: favourites_count, utc_offset: utc_offset, time_zone: time_zone, geo_enabled: geo_enabled, verified: verified, statuses_count: statuses_count, lang: lang, contributors_enabled: contributors_enabled, is_translator: is_translator, is_translation_enabled: is_translation_enabled, profile_background_color: profile_background_color, profile_background_image_url: profile_background_image_url, profile_background_image_url_https: profile_background_image_url_https, profile_background_tile: profile_background_tile, profile_image_url: profile_image_url, profile_image_url_https: profile_image_url_https, profile_banner_url: profile_banner_url, profile_link_color: profile_link_color, profile_sidebar_border_color: profile_sidebar_border_color, profile_sidebar_fill_color: profile_sidebar_fill_color, profile_text_color: profile_text_color, profile_use_background_image: profile_use_background_image, default_profile: default_profile, default_profile_image: default_profile_image, following: following, follow_request_sent: follow_request_sent, notifications: notifications)
        }

    }
    
    struct JSONBuilder: ~Copyable, ~Escapable {
        var id: ShortId?
        var id_str: IntString<ShortId>?
        var name: Exclusive<String>?
        var screen_name: Exclusive<String>?
        var location: Exclusive<String>?
        var description: Exclusive<String>?
        var url: Exclusive<String>?
        var entities: Exclusive<UserEntities>?
        var protected: Bool?
        var followers_count: UInt32?
        var friends_count: UInt32?
        var listed_count: UInt32?
        var created_at: Exclusive<String>?
        var favourites_count: UInt32?
        var utc_offset: Int32?
        var time_zone: Exclusive<String>?
        var geo_enabled: Bool?
        var verified: Bool?
        var statuses_count: UInt32?
        var lang: LanguageCode?
        var contributors_enabled: Bool?
        var is_translator: Bool?
        var is_translation_enabled: Bool?
        var profile_background_color: Exclusive<Color>?
        var profile_background_image_url: Exclusive<String>?
        var profile_background_image_url_https: Exclusive<String>?
        var profile_background_tile: Bool?
        var profile_image_url: Exclusive<String>?
        var profile_image_url_https: Exclusive<String>?
        var profile_banner_url: Exclusive<String>?
        var profile_link_color: Exclusive<Color>?
        var profile_sidebar_border_color: Exclusive<Color>?
        var profile_sidebar_fill_color: Exclusive<Color>?
        var profile_text_color: Exclusive<Color>?
        var profile_use_background_image: Bool?
        var default_profile: Bool?
        var default_profile_image: Bool?
        var following: Bool?
        var follow_request_sent: Bool?
        var notifications: Bool?

//        @inline(__always)
        @inline(never)
        @_lifetime(copy structDecoder)
        init(structDecoder: JSONParserDecoder.StructDecoder) { }
        
        @inline(never)
        @_lifetime(self: copy self)
        mutating func tryExpectedOrder(using structDecoder: inout JSONParserDecoder.StructDecoder) throws(CodingError.Decoding) {
            var inOrder = true
            try structDecoder.decodeExpectedOrderField(Field.id, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.id = try vd.decode(ShortId.self) }
            try structDecoder.decodeExpectedOrderField(Field.id_str, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.id_str = try vd.decode(IntString<ShortId>.self) }
            try structDecoder.decodeExpectedOrderField(Field.name, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.name = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.screen_name, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.screen_name = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.location, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.location = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.description, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.description = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.url, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.url = try vd.decode(String?.self).exclusive() }
            try structDecoder.decodeExpectedOrderField(Field.entities, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.entities = Exclusive(try vd.decode(UserEntities.self)) }
            try structDecoder.decodeExpectedOrderField(Field.protected, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.protected = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.followers_count, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.followers_count = try vd.decode(UInt32.self) }
            try structDecoder.decodeExpectedOrderField(Field.friends_count, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.friends_count = try vd.decode(UInt32.self) }
            try structDecoder.decodeExpectedOrderField(Field.listed_count, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.listed_count = try vd.decode(UInt32.self) }
            try structDecoder.decodeExpectedOrderField(Field.created_at, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.created_at = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.favourites_count, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.favourites_count = try vd.decode(UInt32.self) }
            try structDecoder.decodeExpectedOrderField(Field.utc_offset, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.utc_offset = try vd.decode(Int32?.self) }
            try structDecoder.decodeExpectedOrderField(Field.time_zone, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.time_zone = try vd.decode(String?.self).exclusive() }
            try structDecoder.decodeExpectedOrderField(Field.geo_enabled, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.geo_enabled = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.verified, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.verified = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.statuses_count, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.statuses_count = try vd.decode(UInt32.self) }
            try structDecoder.decodeExpectedOrderField(Field.lang, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.lang = try vd.decode(LanguageCode.self) }
            try structDecoder.decodeExpectedOrderField(Field.contributors_enabled, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.contributors_enabled = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.is_translator, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.is_translator = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.is_translation_enabled, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.is_translation_enabled = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.profile_background_color, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.profile_background_color = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.profile_background_image_url, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.profile_background_image_url = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.profile_background_image_url_https, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.profile_background_image_url_https = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.profile_background_tile, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.profile_background_tile = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.profile_image_url, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.profile_image_url = try vd.decode(String?.self).exclusive() }
            try structDecoder.decodeExpectedOrderField(Field.profile_image_url_https, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.profile_image_url_https = try vd.decode(String?.self).exclusive() }
            try structDecoder.decodeExpectedOrderField(Field.profile_banner_url, inOrder: &inOrder, required: false) { vd throws(CodingError.Decoding) in self.profile_banner_url = try vd.decode(String?.self).exclusive() }
            try structDecoder.decodeExpectedOrderField(Field.profile_link_color, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.profile_link_color = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.profile_sidebar_border_color, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.profile_sidebar_border_color = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.profile_sidebar_fill_color, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.profile_sidebar_fill_color = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.profile_text_color, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.profile_text_color = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.profile_use_background_image, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.profile_use_background_image = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.default_profile, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.default_profile = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.default_profile_image, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.default_profile_image = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.following, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.following = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.follow_request_sent, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.follow_request_sent = try vd.decode(Bool.self) }
            try structDecoder.decodeExpectedOrderField(Field.notifications, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.notifications = try vd.decode(Bool.self) }
            
            if !inOrder {
                var field: Field = .unknown
                try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                    field = try keyDecoder.decode(Field.self)
                } andValue: { valueDecoder throws(CodingError.Decoding) in
                    _ = try self.accept(field: field, decoder: &valueDecoder)
                }
            }
        }
        
        @inline(never)
        @_lifetime(self: copy self)
        mutating func accept(field: Field, decoder valueDecoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Bool {
            switch field {
            case .id: id = try valueDecoder.decode(ShortId.self)
            case .id_str: id_str = try valueDecoder.decode(IntString<ShortId>.self)
            case .name: name = Exclusive(try valueDecoder.decode(String.self))
            case .screen_name: screen_name = Exclusive(try valueDecoder.decode(String.self))
            case .location: location = Exclusive(try valueDecoder.decode(String.self))
            case .description: description = Exclusive(try valueDecoder.decode(String.self))
            case .url: url = try valueDecoder.decode(String?.self).exclusive()
            case .entities: entities = Exclusive(try valueDecoder.decode(UserEntities.self))
            case .protected: protected = try valueDecoder.decode(Bool.self)
            case .followers_count: followers_count = try valueDecoder.decode(UInt32.self)
            case .friends_count: friends_count = try valueDecoder.decode(UInt32.self)
            case .listed_count: listed_count = try valueDecoder.decode(UInt32.self)
            case .created_at: created_at = Exclusive(try valueDecoder.decode(String.self))
            case .favourites_count: favourites_count = try valueDecoder.decode(UInt32.self)
            case .utc_offset: utc_offset = try valueDecoder.decode(Int32?.self)
            case .time_zone: time_zone = try valueDecoder.decode(String?.self).exclusive()
            case .geo_enabled: geo_enabled = try valueDecoder.decode(Bool.self)
            case .verified: verified = try valueDecoder.decode(Bool.self)
            case .statuses_count: statuses_count = try valueDecoder.decode(UInt32.self)
            case .lang: lang = try valueDecoder.decode(LanguageCode.self)
            case .contributors_enabled: contributors_enabled = try valueDecoder.decode(Bool.self)
            case .is_translator: is_translator = try valueDecoder.decode(Bool.self)
            case .is_translation_enabled: is_translation_enabled = try valueDecoder.decode(Bool.self)
            case .profile_background_color: profile_background_color = Exclusive(try valueDecoder.decode(String.self))
            case .profile_background_image_url: profile_background_image_url = Exclusive(try valueDecoder.decode(String.self))
            case .profile_background_image_url_https: profile_background_image_url_https = Exclusive(try valueDecoder.decode(String.self))
            case .profile_background_tile: profile_background_tile = try valueDecoder.decode(Bool.self)
            case .profile_image_url: profile_image_url = try valueDecoder.decode(String?.self).exclusive()
            case .profile_image_url_https: profile_image_url_https = try valueDecoder.decode(String?.self).exclusive()
            case .profile_banner_url: profile_banner_url = try valueDecoder.decode(String?.self).exclusive()
            case .profile_link_color: profile_link_color = Exclusive(try valueDecoder.decode(String.self))
            case .profile_sidebar_border_color: profile_sidebar_border_color = Exclusive(try valueDecoder.decode(String.self))
            case .profile_sidebar_fill_color: profile_sidebar_fill_color = Exclusive(try valueDecoder.decode(String.self))
            case .profile_text_color: profile_text_color = Exclusive(try valueDecoder.decode(String.self))
            case .profile_use_background_image: profile_use_background_image = try valueDecoder.decode(Bool.self)
            case .default_profile: default_profile = try valueDecoder.decode(Bool.self)
            case .default_profile_image: default_profile_image = try valueDecoder.decode(Bool.self)
            case .following: following = try valueDecoder.decode(Bool.self)
            case .follow_request_sent: follow_request_sent = try valueDecoder.decode(Bool.self)
            case .notifications: notifications = try valueDecoder.decode(Bool.self)
            default:
                //                        print("Unknown key: \(key)")
                return false
            }
            return true
        }
        
//        @inline(__always)
        @inline(never)
        consuming func build() throws(CodingError.Decoding) -> User {
            guard let created_at, let default_profile, let description, let favourites_count, let followers_count, let friends_count, let id, let id_str, let lang, let name, let profile_background_color, let profile_background_image_url, let profile_use_background_image, let screen_name, let statuses_count, let verified, let entities, let protected, let listed_count, let contributors_enabled, let profile_link_color, let profile_background_image_url_https, let default_profile_image, let follow_request_sent, let notifications, let following, let profile_text_color, let profile_sidebar_fill_color, let profile_sidebar_border_color, let profile_image_url_https, let profile_background_tile, let profile_image_url, let is_translation_enabled, let is_translator, let geo_enabled, let location else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return User(id: id, id_str: id_str, name: name.take(), screen_name: screen_name.take(), location: location.take(), description: description.take(), url: url?.take(), entities: entities.take(), protected: protected, followers_count: followers_count, friends_count: friends_count, listed_count: listed_count, created_at: created_at.take(), favourites_count: favourites_count, utc_offset: utc_offset, time_zone: time_zone?.take(), geo_enabled: geo_enabled, verified: verified, statuses_count: statuses_count, lang: lang, contributors_enabled: contributors_enabled, is_translator: is_translator, is_translation_enabled: is_translation_enabled, profile_background_color: profile_background_color.take(), profile_background_image_url: profile_background_image_url.take(), profile_background_image_url_https: profile_background_image_url_https.take(), profile_background_tile: profile_background_tile, profile_image_url: profile_image_url.take(), profile_image_url_https: profile_image_url_https.take(), profile_banner_url: profile_banner_url?.take(), profile_link_color: profile_link_color.take(), profile_sidebar_border_color: profile_sidebar_border_color.take(), profile_sidebar_fill_color: profile_sidebar_fill_color.take(), profile_text_color: profile_text_color.take(), profile_use_background_image: profile_use_background_image, default_profile: default_profile, default_profile_image: default_profile_image, following: following, follow_request_sent: follow_request_sent, notifications: notifications)
        }
    }
    
    @inline(never)
    static func decode(from decoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var builder = JSONBuilder(structDecoder: structDecoder)
            try builder.tryExpectedOrder(using: &structDecoder)
            return try builder.build()
        }
    }
}


extension User: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.id, value: id)
            try dictEncoder.encode(field: Field.id_str, value: id_str)
            try dictEncoder.encode(field: Field.name, value: name)
            try dictEncoder.encode(field: Field.screen_name, value: screen_name)
            try dictEncoder.encode(field: Field.location, value: location)
            try dictEncoder.encode(field: Field.description, value: description)
            try dictEncoder.encode(field: Field.url, value: url)
            try dictEncoder.encode(field: Field.entities, value: entities)
            try dictEncoder.encode(field: Field.protected, value: protected)
            try dictEncoder.encode(field: Field.followers_count, value: followers_count)
            try dictEncoder.encode(field: Field.friends_count, value: friends_count)
            try dictEncoder.encode(field: Field.listed_count, value: listed_count)
            try dictEncoder.encode(field: Field.created_at, value: created_at)
            try dictEncoder.encode(field: Field.favourites_count, value: favourites_count)
            try dictEncoder.encode(field: Field.utc_offset, value: utc_offset)
            try dictEncoder.encode(field: Field.time_zone, value: time_zone)
            try dictEncoder.encode(field: Field.geo_enabled, value: geo_enabled)
            try dictEncoder.encode(field: Field.verified, value: verified)
            try dictEncoder.encode(field: Field.statuses_count, value: statuses_count)
            try dictEncoder.encode(field: Field.lang, value: lang)
            try dictEncoder.encode(field: Field.contributors_enabled, value: contributors_enabled)
            try dictEncoder.encode(field: Field.is_translator, value: is_translator)
            try dictEncoder.encode(field: Field.is_translation_enabled, value: is_translation_enabled)
            try dictEncoder.encode(field: Field.profile_background_color, value: profile_background_color)
            try dictEncoder.encode(field: Field.profile_background_image_url, value: profile_background_image_url)
            try dictEncoder.encode(field: Field.profile_background_image_url_https, value: profile_background_image_url_https)
            try dictEncoder.encode(field: Field.profile_background_tile, value: profile_background_tile)
            try dictEncoder.encode(field: Field.profile_image_url, value: profile_image_url)
            try dictEncoder.encode(field: Field.profile_image_url_https, value: profile_image_url_https)
            try dictEncoder.encode(field: Field.profile_banner_url, value: profile_banner_url)
            try dictEncoder.encode(field: Field.profile_link_color, value: profile_link_color)
            try dictEncoder.encode(field: Field.profile_sidebar_border_color, value: profile_sidebar_border_color)
            try dictEncoder.encode(field: Field.profile_sidebar_fill_color, value: profile_sidebar_fill_color)
            try dictEncoder.encode(field: Field.profile_text_color, value: profile_text_color)
            try dictEncoder.encode(field: Field.profile_use_background_image, value: profile_use_background_image)
            try dictEncoder.encode(field: Field.default_profile, value: default_profile)
            try dictEncoder.encode(field: Field.default_profile_image, value: default_profile_image)
            try dictEncoder.encode(field: Field.following, value: following)
            try dictEncoder.encode(field: Field.follow_request_sent, value: follow_request_sent)
            try dictEncoder.encode(field: Field.notifications, value: notifications)
        }
    }
}


struct UserEntities: Decodable, Encodable {
    let url: UserUrl?
    let description: UserEntitiesDescription

    init(url: UserUrl?, description: UserEntitiesDescription) {
        self.url = url
        self.description = description
    }
}

extension UserEntities: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case url
        case description
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .url: "url"
            case .description: "description"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "url": .url
            case "description": .description
            default: throw CodingError.unknownKey(key)
            }
        }
    }
    
    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var urls: UserUrl?
            var description: UserEntitiesDescription?

            var field: Field?
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .url: urls = try valueDecoder.decode(UserUrl?.self)
                case .description: description = try valueDecoder.decode(UserEntitiesDescription.self)
                }
            }
            guard let description else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return UserEntities(url: urls, description: description)
        }
    }

}

extension UserEntities: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.url, value: url)
            try dictEncoder.encode(field: Field.description, value: description)
        }
    }
}


struct UserUrl: Decodable, Encodable {
    let urls: [Url]

    init(urls: [Url]) {
        self.urls = urls
    }
}

extension UserUrl: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case urls
        case unknown
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .urls: "urls"
            default: fatalError()
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "urls": .urls
            default: .unknown
            }
        }
    }
    
    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var urls: [Url]?
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .urls: urls = try valueDecoder.decode([Url].self)
                default:
                    break
                }
            }
            guard let urls else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return UserUrl(urls: urls)
        }
    }
}

extension UserUrl: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.urls, value: urls)
        }
    }
}

struct Url: Decodable, Encodable {
    let url: String
    let expanded_url: String
    let display_url: String
    let indices: Indices

    init(url: String, expanded_url: String, display_url: String, indices: Indices) {
        self.url = url
        self.expanded_url = expanded_url
        self.display_url = display_url
        self.indices = indices
    }
}

extension Url: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case url
        case expanded_url
        case display_url
        case indices
        case unknown
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .url: "url"
            case .expanded_url: "expanded_url"
            case .display_url: "display_url"
            case .indices: "indices"
            case .unknown: fatalError()
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "url": .url
            case "expanded_url": .expanded_url
            case "display_url": .display_url
            case "indices": .indices
            default: .unknown
            }
        }
    }
    
    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var url: String?
            var expanded_url: String?
            var display_url: String?
            var indices: Indices?
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .url: url = try valueDecoder.decode(String.self)
                case .expanded_url: expanded_url = try valueDecoder.decode(String.self)
                case .display_url: display_url = try valueDecoder.decode(String.self)
                case .indices: indices = try valueDecoder.decode(Indices.self)
                default:
                    break
                }
            }
            guard let url, let expanded_url, let display_url, let indices else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return Url(url: url, expanded_url: expanded_url, display_url: display_url, indices: indices)
        }
    }
}

extension Url: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.url, value: url)
            try dictEncoder.encode(field: Field.expanded_url, value: expanded_url)
            try dictEncoder.encode(field: Field.display_url, value: display_url)
            try dictEncoder.encode(field: Field.indices, value: indices)
        }
    }
}

struct UserEntitiesDescription: Decodable, Encodable {
    let urls: [Url]

    init(urls: [Url]) {
        self.urls = urls
    }
}

extension UserEntitiesDescription: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case urls
        case unknown
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .urls: "urls"
            case .unknown: fatalError()
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "urls": .urls
            default: .unknown
            }
        }
    }
    
    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var urls: [Url]?
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .urls: urls = try valueDecoder.decode([Url].self)
                default:
                    break
                }
            }
            guard let urls else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return UserEntitiesDescription(urls: urls)
        }
    }
}

extension UserEntitiesDescription: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.urls, value: urls)
        }
    }
}

struct StatusEntities: Decodable, Encodable {
    let hashtags: [Hashtag]
    let symbols: [String]
    let urls: [Url]
    let user_mentions: [UserMention]
    let media: [Media]?

    init(hashtags: [Hashtag], symbols: [String], urls: [Url], user_mentions: [UserMention], media: [Media]?) {
        self.hashtags = hashtags
        self.symbols = symbols
        self.urls = urls
        self.user_mentions = user_mentions
        self.media = media
    }
}

extension StatusEntities: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case hashtags
        case symbols
        case urls
        case user_mentions
        case media
        case unknown
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .hashtags: "hashtags"
            case .symbols: "symbols"
            case .urls: "urls"
            case .user_mentions: "user_mentions"
            case .media: "media"
            case .unknown: fatalError()
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "hashtags": .hashtags
            case "symbols": .symbols
            case "urls": .urls
            case "user_mentions": .user_mentions
            case "media": .media
            default: .unknown
            }
        }
    }
    
    @usableFromInline
    struct JSONBuilder: ~Copyable, ~Escapable {
        var hashtags: Exclusive<[Hashtag]>?
        var symbols: Exclusive<[String]>?
        var urls: Exclusive<[Url]>?
        var user_mentions: Exclusive<[UserMention]>?
        var media: Exclusive<[Media]>?

        @inline(__always)
        @_lifetime(copy structDecoder)
        init(structDecoder: JSONParserDecoder.StructDecoder) { }
        
        @inline(__always)
        @_lifetime(self: copy self)
        mutating func tryExpectedOrder(using structDecoder: inout JSONParserDecoder.StructDecoder) throws(CodingError.Decoding) {
            var inOrder = true
            try structDecoder.decodeExpectedOrderField(Field.hashtags, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.hashtags = Exclusive(try vd.decode([Hashtag].self)) }
            try structDecoder.decodeExpectedOrderField(Field.symbols, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.symbols = Exclusive(try vd.decode([String].self)) }
            try structDecoder.decodeExpectedOrderField(Field.urls, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.urls = Exclusive(try vd.decode([Url].self)) }
            try structDecoder.decodeExpectedOrderField(Field.user_mentions, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.user_mentions = Exclusive(try vd.decode([UserMention].self)) }
            try structDecoder.decodeExpectedOrderField(Field.media, inOrder: &inOrder, required: false) { vd throws(CodingError.Decoding) in self.media = try vd.decode([Media]?.self).exclusive() }
            
            if !inOrder {
                var field: Field = .unknown
                try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                    field = try keyDecoder.decode(Field.self)
                } andValue: { valueDecoder throws(CodingError.Decoding) in
                    _ = try self.accept(field: field, decoder: &valueDecoder)
                }
            }
        }
        
        @inline(never)
        @_lifetime(self: copy self)
        mutating func accept(field: Field, decoder valueDecoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Bool {
            switch field {
            case .hashtags: hashtags = Exclusive(try valueDecoder.decode([Hashtag].self))
            case .symbols: symbols = Exclusive(try valueDecoder.decode([String].self))
            case .urls: urls = Exclusive(try valueDecoder.decode([Url].self))
            case .user_mentions: user_mentions = Exclusive(try valueDecoder.decode([UserMention].self))
            case .media: media = try valueDecoder.decode([Media]?.self).exclusive()
            default:
                return false
            }
            return true
        }
        
        @inline(__always)
        consuming func build() throws(CodingError.Decoding) -> StatusEntities {
            guard let hashtags, let symbols, let urls, let user_mentions else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return StatusEntities(hashtags: hashtags.take(), symbols: symbols.take(), urls: urls.take(), user_mentions: user_mentions.take(), media: media?.take())
        }
    }

    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        if D.self == JSONParserDecoder.self {
            var parserDecoder = decoder as! JSONParserDecoder
            let result = try decode(from: &parserDecoder)
            decoder = parserDecoder as! D
            return result
        }
        
        return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var hashtags: [Hashtag]?
            var symbols: [String]?
            var urls: [Url]?
            var user_mentions: [UserMention]?
            var media: [Media]?
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .hashtags: hashtags = try valueDecoder.decode([Hashtag].self)
                case .symbols: symbols = try valueDecoder.decode([String].self)
                case .urls: urls = try valueDecoder.decode([Url].self)
                case .user_mentions: user_mentions = try valueDecoder.decode([UserMention].self)
                case .media: media = try valueDecoder.decode([Media]?.self)
                default:
                    break
                }
            }
            guard let hashtags, let symbols, let urls, let user_mentions else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return StatusEntities(hashtags: hashtags, symbols: symbols, urls: urls, user_mentions: user_mentions, media: media)
        }
    }
    
    static func decode(from decoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var builder = JSONBuilder(structDecoder: structDecoder)
            try builder.tryExpectedOrder(using: &structDecoder)
            return try builder.build()
        }
    }
}

extension StatusEntities: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.hashtags, value: hashtags)
            try dictEncoder.encode(field: Field.symbols, value: symbols)
            try dictEncoder.encode(field: Field.urls, value: urls)
            try dictEncoder.encode(field: Field.user_mentions, value: user_mentions)
            try dictEncoder.encode(field: Field.media, value: media)
        }
    }
}


struct Hashtag: Decodable, Encodable {
    let text: String
    let indices: Indices

    init(text: String, indices: Indices) {
        self.text = text
        self.indices = indices
    }
}

extension Hashtag: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case text
        case indices
        case unknown
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .text: "text"
            case .indices: "indices"
            case .unknown: fatalError()
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "text": .text
            case "indices": .indices
            default: .unknown
            }
        }
    }
    
    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var text: String?
            var indices: Indices?

            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .text: text = try valueDecoder.decode(String.self)
                case .indices: indices = try valueDecoder.decode(Indices.self)
                default: break
                }
            }
            guard let text, let indices else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return Hashtag(text: text, indices: indices)
        }
    }
}

extension Hashtag: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.text, value: text)
            try dictEncoder.encode(field: Field.indices, value: indices)
        }
    }
}

struct UserMention: Decodable, Encodable {
    let screen_name: String
    let name: String
    let id: ShortId
    let id_str: IntString<ShortId>
    let indices: Indices

    init(screen_name: String, name: String, id: ShortId, id_str: IntString<ShortId>, indices: Indices) {
        self.screen_name = screen_name
        self.name = name
        self.id = id
        self.id_str = id_str
        self.indices = indices
    }
}

extension UserMention: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case screen_name
        case name
        case id
        case id_str
        case indices
        case unknown
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .screen_name: "screen_name"
            case .name: "name"
            case .id: "id"
            case .id_str: "id_str"
            case .indices: "indices"
            case .unknown: fatalError()
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "screen_name": .screen_name
            case "name": .name
            case "id": .id
            case "id_str": .id_str
            case "indices": .indices
            default: .unknown
            }
        }
    }
    
//    @_specialize(where D == JSONParserDecoder)
//    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var screen_name: String?
            var name: String?
            var id: ShortId?
            var id_str: IntString<ShortId>?
            var indices: Indices?

            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .screen_name: screen_name = try valueDecoder.decode(String.self)
                case .name: name = try valueDecoder.decode(String.self)
                case .id: id = try valueDecoder.decode(ShortId.self)
                case .id_str: id_str = try valueDecoder.decode(IntString<ShortId>.self)
                case .indices: indices = try valueDecoder.decode(Indices.self)
                default: break
                }
            }
            guard let screen_name, let name, let id, let id_str, let indices else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return UserMention(screen_name: screen_name, name: name, id: id, id_str: id_str, indices: indices)
        }
    }
}

extension UserMention: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.screen_name, value: screen_name)
            try dictEncoder.encode(field: Field.name, value: name)
            try dictEncoder.encode(field: Field.id, value: id)
            try dictEncoder.encode(field: Field.id_str, value: id_str)
            try dictEncoder.encode(field: Field.indices, value: indices)
        }
    }
}

struct Media: Decodable, Encodable {
    let id: LongId
    let id_str: IntString<LongId>
    let indices: Indices
    let media_url: String
    let media_url_https: String
    let url: String
    let display_url: String
    let expanded_url: String
    let type: String
    let sizes: Sizes
    let source_status_id: LongId?
    let source_status_id_str: IntString<LongId>?

    init(id: LongId, id_str: IntString<LongId>, indices: Indices, media_url: String, media_url_https: String, url: String, display_url: String, expanded_url: String, type: String, sizes: Sizes, source_status_id: LongId?, source_status_id_str: IntString<LongId>?) {
        self.id = id
        self.id_str = id_str
        self.indices = indices
        self.media_url = media_url
        self.media_url_https = media_url_https
        self.url = url
        self.display_url = display_url
        self.expanded_url = expanded_url
        self.type = type
        self.sizes = sizes
        self.source_status_id = source_status_id
        self.source_status_id_str = source_status_id_str
    }
}

extension Media: JSONDecodable {
    enum Field: Int, JSONOptimizedDecodingField {
        case id
        case id_str
        case indices
        case media_url
        case media_url_https
        case url
        case display_url
        case expanded_url
        case type
        case sizes
        case source_status_id
        case source_status_id_str
        case unknown
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .id: "id"
            case .id_str: "id_str"
            case .indices: "indices"
            case .media_url: "media_url"
            case .media_url_https: "media_url_https"
            case .url: "url"
            case .display_url: "display_url"
            case .expanded_url: "expanded_url"
            case .type: "type"
            case .sizes: "sizes"
            case .source_status_id: "source_status_id"
            case .source_status_id_str: "source_status_id_str"
            case .unknown: fatalError()
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "id": .id
            case "id_str": .id_str
            case "indices": .indices
            case "media_url": .media_url
            case "media_url_https": .media_url_https
            case "url": .url
            case "display_url": .display_url
            case "expanded_url": .expanded_url
            case "type": .type
            case "sizes": .sizes
            case "source_status_id": .source_status_id
            case "source_status_id_str": .source_status_id_str
            default: .unknown
            }
        }
    }
    
    @usableFromInline
    struct JSONBuilder: ~Copyable, ~Escapable {
        var id: LongId?
        var id_str: IntString<LongId>?
        var indices: Indices?
        var media_url: Exclusive<String>?
        var media_url_https: Exclusive<String>?
        var url: Exclusive<String>?
        var display_url: Exclusive<String>?
        var expanded_url: Exclusive<String>?
        var type: Exclusive<String>?
        var sizes: Sizes?
        var source_status_id: LongId?
        var source_status_id_str: IntString<LongId>?

        @inline(__always)
        @_lifetime(copy structDecoder)
        init(structDecoder: JSONParserDecoder.StructDecoder) { }
        
        @inline(__always)
        @_lifetime(self: copy self)
        mutating func tryExpectedOrder(using structDecoder: inout JSONParserDecoder.StructDecoder) throws(CodingError.Decoding) {
            var inOrder = true
            try structDecoder.decodeExpectedOrderField(Field.id, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.id = try vd.decode(LongId.self) }
            try structDecoder.decodeExpectedOrderField(Field.id_str, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.id_str = try vd.decode(IntString<LongId>.self) }
            try structDecoder.decodeExpectedOrderField(Field.indices, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.indices = try vd.decode(Indices.self) }
            try structDecoder.decodeExpectedOrderField(Field.media_url, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.media_url = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.media_url_https, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.media_url_https = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.url, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.url = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.display_url, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.display_url = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.expanded_url, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.expanded_url = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.type, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.type = Exclusive(try vd.decode(String.self)) }
            try structDecoder.decodeExpectedOrderField(Field.sizes, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.sizes = try vd.decode(Sizes.self) }
            try structDecoder.decodeExpectedOrderField(Field.source_status_id, inOrder: &inOrder, required: false) { vd throws(CodingError.Decoding) in self.source_status_id = try vd.decode(LongId?.self) }
            try structDecoder.decodeExpectedOrderField(Field.source_status_id_str, inOrder: &inOrder, required: false) { vd throws(CodingError.Decoding) in self.source_status_id_str = try vd.decode(IntString<LongId>?.self) }
            
            if !inOrder {
                var field: Field = .unknown
                try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                    field = try keyDecoder.decode(Field.self)
                } andValue: { valueDecoder throws(CodingError.Decoding) in
                    _ = try self.accept(field: field, decoder: &valueDecoder)
                }
            }
        }
        
        @inline(never)
        @_lifetime(self: copy self)
        mutating func accept(field: Field, decoder valueDecoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Bool {
            switch field {
            case .id: id = try valueDecoder.decode(LongId.self)
            case .id_str: id_str = try valueDecoder.decode(IntString<LongId>.self)
            case .indices: indices = try valueDecoder.decode(Indices.self)
            case .media_url: media_url = Exclusive(try valueDecoder.decode(String.self))
            case .media_url_https: media_url_https = Exclusive(try valueDecoder.decode(String.self))
            case .url: url = Exclusive(try valueDecoder.decode(String.self))
            case .display_url: display_url = Exclusive(try valueDecoder.decode(String.self))
            case .expanded_url: expanded_url = Exclusive(try valueDecoder.decode(String.self))
            case .type: type = Exclusive(try valueDecoder.decode(String.self))
            case .sizes: sizes = try valueDecoder.decode(Sizes.self)
            case .source_status_id: source_status_id = try valueDecoder.decode(LongId?.self)
            case .source_status_id_str: source_status_id_str = try valueDecoder.decode(IntString<LongId>?.self)
            default:
                //                        print("Unknown key: \(key)")
                return false
            }
            return true
        }
        
        @inline(__always)
        consuming func build() throws(CodingError.Decoding) -> Media {
            guard let id, let id_str, let indices, let media_url, let media_url_https, let url, let display_url, let expanded_url, let type, let sizes else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return Media(id: id, id_str: id_str, indices: indices, media_url: media_url.take(), media_url_https: media_url_https.take(), url: url.take(), display_url: display_url.take(), expanded_url: expanded_url.take(), type: type.take(), sizes: sizes, source_status_id: source_status_id, source_status_id_str: source_status_id_str)
        }
    }

    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        if D.self == JSONParserDecoder.self {
            var parserDecoder = decoder as! JSONParserDecoder
            let result = try decode(from: &parserDecoder)
            decoder = parserDecoder as! D
            return result
        }
        
        return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var id: LongId?
            var id_str: IntString<LongId>?
            var indices: Indices?
            var media_url: String?
            var media_url_https: String?
            var url: String?
            var display_url: String?
            var expanded_url: String?
            var type: String?
            var sizes: Sizes?
            var source_status_id: LongId?
            var source_status_id_str: IntString<LongId>?
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .id: id = try valueDecoder.decode(LongId.self)
                case .id_str: id_str = try valueDecoder.decode(IntString<LongId>.self)
                case .indices: indices = try valueDecoder.decode(Indices.self)
                case .media_url: media_url = try valueDecoder.decode(String.self)
                case .media_url_https: media_url_https = try valueDecoder.decode(String.self)
                case .url: url = try valueDecoder.decode(String.self)
                case .display_url: display_url = try valueDecoder.decode(String.self)
                case .expanded_url: expanded_url = try valueDecoder.decode(String.self)
                case .type: type = try valueDecoder.decode(String.self)
                case .sizes: sizes = try valueDecoder.decode(Sizes.self)
                case .source_status_id: source_status_id = try valueDecoder.decode(LongId?.self)
                case .source_status_id_str: source_status_id_str = try valueDecoder.decode(IntString<LongId>?.self)
                default: break
                }
            }
            
            guard let id, let id_str, let indices, let media_url, let media_url_https, let url, let display_url, let expanded_url, let type, let sizes else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return Media(id: id, id_str: id_str, indices: indices, media_url: media_url, media_url_https: media_url_https, url: url, display_url: display_url, expanded_url: expanded_url, type: type, sizes: sizes, source_status_id: source_status_id, source_status_id_str: source_status_id_str)
        }
    }
    
    static func decode(from decoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var builder = JSONBuilder(structDecoder: structDecoder)
            try builder.tryExpectedOrder(using: &structDecoder)
            return try builder.build()
        }
    }
}

extension Media: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.id) { ve throws(CodingError.Encoding) in try ve.encode(id) }
            try dictEncoder.encode(field: Field.id_str) { ve throws(CodingError.Encoding) in try ve.encode(id_str) }
            try dictEncoder.encode(field: Field.indices) { ve throws(CodingError.Encoding) in try ve.encode(indices) }
            try dictEncoder.encode(field: Field.media_url) { ve throws(CodingError.Encoding) in try ve.encode(media_url) }
            try dictEncoder.encode(field: Field.media_url_https) { ve throws(CodingError.Encoding) in try ve.encode(media_url_https) }
            try dictEncoder.encode(field: Field.url) { ve throws(CodingError.Encoding) in try ve.encode(url) }
            try dictEncoder.encode(field: Field.display_url) { ve throws(CodingError.Encoding) in try ve.encode(display_url) }
            try dictEncoder.encode(field: Field.expanded_url) { ve throws(CodingError.Encoding) in try ve.encode(expanded_url) }
            try dictEncoder.encode(field: Field.type) { ve throws(CodingError.Encoding) in try ve.encode(type) }
            try dictEncoder.encode(field: Field.sizes) { ve throws(CodingError.Encoding) in try ve.encode(sizes) }
            try dictEncoder.encode(field: Field.source_status_id) { ve throws(CodingError.Encoding) in try ve.encode(source_status_id) }
            try dictEncoder.encode(field: Field.source_status_id_str) { ve throws(CodingError.Encoding) in try ve.encode(source_status_id_str) }
        }
    }
}

struct Sizes: Codable, Equatable {
    let medium: Size
    let small: Size
    let thumb: Size
    let large: Size
    
    init(medium: Size, small: Size, thumb: Size, large: Size) {
        self.medium = medium
        self.small = small
        self.thumb = thumb
        self.large = large
    }
}

extension Sizes: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case medium
        case small
        case thumb
        case large
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .medium: "medium"
            case .small: "small"
            case .thumb: "thumb"
            case .large: "large"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "medium": .medium
            case "small": .small
            case "thumb": .thumb
            case "large": .large
            default: throw CodingError.unknownKey(key)
            }
        }
    }
    
    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var medium: Size?
            var small: Size?
            var thumb: Size?
            var large: Size?

            var field: Field?
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .medium: medium = try valueDecoder.decode(Size.self)
                case .small: small = try valueDecoder.decode(Size.self)
                case .thumb: thumb = try valueDecoder.decode(Size.self)
                case .large: large = try valueDecoder.decode(Size.self)
                }
            }
            guard let medium, let small, let thumb, let large else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return Sizes(medium: medium, small: small, thumb: thumb, large: large)
        }
    }
}

extension Sizes: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary(elementCount: 4) { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.medium) { ve throws(CodingError.Encoding) in try ve.encode(medium) }
            try dictEncoder.encode(field: Field.small) { ve throws(CodingError.Encoding) in try ve.encode(small) }
            try dictEncoder.encode(field: Field.thumb) { ve throws(CodingError.Encoding) in try ve.encode(thumb) }
            try dictEncoder.encode(field: Field.large) { ve throws(CodingError.Encoding) in try ve.encode(large) }
        }
    }
}

struct Size : Codable, Equatable {
    let h : UInt64
    let w : UInt64
    let resize : Resize

    init(h: UInt64, w: UInt64, resize: Resize) {
        self.h = h
        self.w = w
        self.resize = resize
    }
}

extension Size: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case h
        case w
        case resize
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .h: "h"
            case .w: "w"
            case .resize: "resize"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "h": .h
            case "w": .w
            case "resize": .resize
            default: throw CodingError.unknownKey(key)
            }
        }
    }
    
    @usableFromInline
    struct JSONBuilder: ~Copyable, ~Escapable {
        var h: UInt64?
        var w: UInt64?
        var resize: Resize?

        @inline(__always)
        @_lifetime(copy structDecoder)
        init(structDecoder: JSONParserDecoder.StructDecoder) { }
        
        @inline(__always)
        @_lifetime(self: copy self)
        mutating func buildTryingExpectedOrder(using structDecoder: inout JSONParserDecoder.StructDecoder) throws(CodingError.Decoding) -> Size {
            var inOrder = true
            try structDecoder.decodeExpectedOrderField(Field.w, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.w = try vd.decode(UInt64.self) }
            try structDecoder.decodeExpectedOrderField(Field.h, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.h = try vd.decode(UInt64.self) }
            try structDecoder.decodeExpectedOrderField(Field.resize, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.resize = try vd.decode(Resize.self) }
            
            if !inOrder {
                var field: Field?
                try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                    field = try keyDecoder.decode(Field.self)
                } andValue: { valueDecoder throws(CodingError.Decoding) in
                    _ = try self.accept(field: field!, decoder: &valueDecoder)
                }
            }
            
            return try self.build()
        }
        
        @inline(__always)
        @_lifetime(self: copy self)
        mutating func accept(field: Field, decoder valueDecoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Bool {
            switch field {
            case .h: h = try valueDecoder.decode(UInt64.self)
            case .w: w = try valueDecoder.decode(UInt64.self)
            case .resize: resize = try valueDecoder.decode(Resize.self)
            }
            return true
        }
        
        @inline(__always)
        func build() throws(CodingError.Decoding) -> Size {
            guard let h, let w, let resize else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return Size(h: h, w: w, resize: resize)
        }
    }

    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        if D.self == JSONParserDecoder.self {
            var parserDecoder = decoder as! JSONParserDecoder
            let result = try decode(from: &parserDecoder)
            decoder = parserDecoder as! D
            return result
        }
        
        return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var h: UInt64?
            var w: UInt64?
            var resize: Resize?

            var field: Field?
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .h: h = try valueDecoder.decode(UInt64.self)
                case .w: w = try valueDecoder.decode(UInt64.self)
                case .resize: resize = try valueDecoder.decode(Resize.self)
                }
            }
            guard let h, let w, let resize else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return Size(h: h, w: w, resize: resize)
        }
    }
    
    static func decode(from decoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var builder = JSONBuilder(structDecoder: structDecoder)
            return try builder.buildTryingExpectedOrder(using: &structDecoder)
        }
    }
}

extension Size: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary(elementCount: 3) { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.h) { ve throws(CodingError.Encoding) in try ve.encode(h) }
            try dictEncoder.encode(field: Field.w) { ve throws(CodingError.Encoding) in try ve.encode(w) }
            try dictEncoder.encode(field: Field.resize) { ve throws(CodingError.Encoding) in try ve.encode(resize) }
        }
    }
}

enum Resize: Equatable {
    // All known values. Matches json-benchmark definition.
    case fit
    case crop
}

extension Resize: Codable {
    init(from decoder: any Decoder) throws {
        let cont = try decoder.singleValueContainer()
        let str = try cont.decode(String.self)
        self = switch str {
        case "fit": .fit
        case "crop": .crop
        default: throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unexpected value"))
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var cont = encoder.singleValueContainer()
        switch self {
        case .fit: try cont.encode("fit")
        case .crop: try cont.encode("crop")
        }
    }
}

extension Resize: JSONDecodable {
    struct JSONVisitor: DecodingStringVisitor {
        typealias DecodedValue = Resize
        
        func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> DecodedValue {
            switch DecodingFieldUTF8SpanRawByteEquivalanceComparator(buffer) {
            case "fit": .fit
            case "crop": .crop
            default: throw CodingError.unknownKey(buffer)
            }
        }
    }
    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeString(JSONVisitor())
    }
}

extension Resize: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        switch self {
        case .fit: try encoder.encode("fit")
        case .crop: try encoder.encode("crop")
        }
    }
}

struct SearchMetadata: Decodable, Encodable {
    let completed_in: Float
    let max_id: LongId
    let max_id_str: IntString<LongId>
    let next_results: String
    let query: String
    let refresh_url: String
    let count: UInt8
    let since_id: LongId
    let since_id_str: IntString<LongId>

    init(completed_in: Float, max_id: LongId, max_id_str: IntString<LongId>, next_results: String, query: String, refresh_url: String, count: UInt8, since_id: LongId, since_id_str: IntString<LongId>) {
        self.completed_in = completed_in
        self.max_id = max_id
        self.max_id_str = max_id_str
        self.next_results = next_results
        self.query = query
        self.refresh_url = refresh_url
        self.count = count
        self.since_id = since_id
        self.since_id_str = since_id_str
    }
}

extension SearchMetadata: JSONDecodable {
    enum Field: Int, JSONOptimizedDecodingField {
        case completed_in
        case max_id
        case max_id_str
        case next_results
        case query
        case refresh_url
        case count
        case since_id
        case since_id_str
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .completed_in: "completed_in"
            case .max_id: "max_id"
            case .max_id_str: "max_id_str"
            case .next_results: "next_results"
            case .query: "query"
            case .refresh_url: "refresh_url"
            case .count: "count"
            case .since_id: "since_id"
            case .since_id_str: "since_id_str"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "completed_in": .completed_in
            case "max_id": .max_id
            case "max_id_str": .max_id_str
            case "next_results": .next_results
            case "query": .query
            case "refresh_url": .refresh_url
            case "count": .count
            case "since_id": .since_id
            case "since_id_str": .since_id_str
            default: throw CodingError.unknownKey(key)
            }
        }
    }
    
    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var completed_in: Float?
            var max_id: LongId?
            var max_id_str: IntString<LongId>?
            var next_results: String?
            var query: String?
            var refresh_url: String?
            var count: UInt8?
            var since_id: LongId?
            var since_id_str: IntString<LongId>?
            
            var field: Field?
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .completed_in: completed_in = try valueDecoder.decode(Float.self)
                case .max_id: max_id = try valueDecoder.decode(LongId.self)
                case .max_id_str: max_id_str = try valueDecoder.decode(IntString<LongId>.self)
                case .next_results: next_results = try valueDecoder.decode(String.self)
                case .query: query = try valueDecoder.decode(String.self)
                case .refresh_url: refresh_url = try valueDecoder.decode(String.self)
                case .count: count = try valueDecoder.decode(UInt8.self)
                case .since_id: since_id = try valueDecoder.decode(LongId.self)
                case .since_id_str: since_id_str = try valueDecoder.decode(IntString<LongId>.self)
                }
            }
            guard let completed_in, let max_id, let max_id_str, let next_results, let query, let refresh_url, let count, let since_id, let since_id_str else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return SearchMetadata(completed_in: completed_in, max_id: max_id, max_id_str: max_id_str, next_results: next_results, query: query, refresh_url: refresh_url, count: count, since_id: since_id, since_id_str: since_id_str)
        }
    }
}

extension SearchMetadata: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.completed_in) { ve throws(CodingError.Encoding) in try ve.encode(completed_in) }
            try dictEncoder.encode(field: Field.max_id) { ve throws(CodingError.Encoding) in try ve.encode(max_id) }
            try dictEncoder.encode(field: Field.max_id_str) { ve throws(CodingError.Encoding) in try ve.encode(max_id_str) }
            try dictEncoder.encode(field: Field.next_results) { ve throws(CodingError.Encoding) in try ve.encode(next_results) }
            try dictEncoder.encode(field: Field.query) { ve throws(CodingError.Encoding) in try ve.encode(query) }
            try dictEncoder.encode(field: Field.refresh_url) { ve throws(CodingError.Encoding) in try ve.encode(refresh_url) }
            try dictEncoder.encode(field: Field.count) { ve throws(CodingError.Encoding) in try ve.encode(count) }
            try dictEncoder.encode(field: Field.since_id) { ve throws(CodingError.Encoding) in try ve.encode(since_id) }
            try dictEncoder.encode(field: Field.since_id_str) { ve throws(CodingError.Encoding) in try ve.encode(since_id_str) }
        }
    }
}

enum LanguageCode: Equatable {
    // All known values. Matches json-benchmark definition.
    case zh_cn
    case en
    case es
    case it
    case ja
    case zh
}

extension LanguageCode: Codable {
    init(from decoder: any Decoder) throws {
        let cont = try decoder.singleValueContainer()
        let str = try cont.decode(String.self)
        self = switch str {
        case "zh-cn": .zh_cn
        case "en": .en
        case "es": .es
        case "it": .it
        case "ja": .ja
        case "zh": .zh
        default: throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unexpected value"))
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var cont = encoder.singleValueContainer()
        let str = switch self {
        case .zh_cn: "zh-cn"
        case .en: "en"
        case .es: "es"
        case .it: "it"
        case .ja: "ja"
        case .zh: "zh"
        }
        try cont.encode(str)
    }
}

extension LanguageCode: JSONDecodable {
    struct JSONVisitor: DecodingStringVisitor {
        typealias DecodedValue = LanguageCode
        
        func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> DecodedValue {
            switch DecodingFieldUTF8SpanRawByteEquivalanceComparator(buffer) {
            case "zh-cn": .zh_cn
            case "en": .en
            case "es": .es
            case "it": .it
            case "ja": .ja
            case "zh": .zh
            default: throw CodingError.unknownKey(buffer)
            }
        }
    }
    
    //    @_specialize(where D == JSONParserDecoder)
    //    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeString(JSONVisitor())
    }
}

extension LanguageCode: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        let str = switch self {
        case .zh_cn: "zh-cn"
        case .en: "en"
        case .es: "es"
        case .it: "it"
        case .ja: "ja"
        case .zh: "zh"
        }
        try encoder.encode(str)
    }
}

enum ResultType: Equatable {
    // All known values. Matches json-benchmark definition.
    case recent
}

extension ResultType: Codable {
    init(from decoder: any Decoder) throws {
        let cont = try decoder.singleValueContainer()
        let str = try cont.decode(String.self)
        guard str == "recent" else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unexpected value"))
        }
        self = .recent
    }
    
    func encode(to encoder: any Encoder) throws {
        var cont = encoder.singleValueContainer()
        try cont.encode("recent")
    }
}

extension ResultType: JSONDecodable {
    struct JSONVisitor: DecodingStringVisitor {
        typealias DecodedValue = ResultType
        
        func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> DecodedValue {
            switch DecodingFieldUTF8SpanRawByteEquivalanceComparator(buffer) {
            case "recent": return .recent
            default: throw CodingError.unknownKey(buffer)
            }
        }
    }
    
//    @_specialize(where D == JSONParserDecoder)
//    @_specialize(where D == JSONPrimitiveDecoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeString(JSONVisitor())
    }
}

extension ResultType: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode("recent")
    }
}
