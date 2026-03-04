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
#elseif canImport(Bionic)
import Bionic
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

extension LanguageCode: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> LanguageCode {
        try decoder.decodeString(JSONVisitor())
    }
}

extension IntString: CommonDecodable {
    struct CommonVisitor: DecodingStringVisitor {
        typealias DecodedValue = IntString
        
        func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> DecodedValue {
            buffer.span.withUnsafeBytes {
                var end: UnsafeMutablePointer<CChar>? = UnsafeMutablePointer(mutating: $0.baseAddress!.assumingMemoryBound(to: CChar.self) + $0.count)
                return .init(integer: T(strtol($0.baseAddress!, &end, 10)))
            }
        }
    }
    
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeString(CommonVisitor())
    }
}

extension IntString: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try integer.withDecimalDescriptionSpan { span throws(CodingError.Encoding) in
            try encoder.encodeString(UTF8Span(unchecked: span, isKnownASCII: true))
        }
    }
}

extension Twitter: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Twitter {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var statuses: [Status]?
            var search_metadata: SearchMetadata?
            var field: Field?
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .statuses: statuses = try valueDecoder.decode([Status].self, sizeHint: 0)
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

extension Twitter: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.statuses, value: statuses)
            try structEncoder.encode(field: Field.search_metadata, value: search_metadata)
        }
    }
}

extension Twitter.Field: EncodingField {
}

extension Status: CommonDecodable {
    static func decode(from decoder: inout some NewCodable.CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Status {
        return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var metadata: Metadata?
            var created_at: String?
            var id: UInt64?
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
                    id = try valueDecoder.decode(UInt64.self)
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
}

extension Status.Field: EncodingField {
}

extension Status: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 21) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.metadata, value: metadata)
            try structEncoder.encode(field: Field.created_at, value: created_at)
            try structEncoder.encode(field: Field.id, value: id)
            try structEncoder.encode(field: Field.id_str, value: id_str)
            try structEncoder.encode(field: Field.text, value: text)
            try structEncoder.encode(field: Field.source, value: source)
            try structEncoder.encode(field: Field.truncated, value: truncated)
            try structEncoder.encode(field: Field.in_reply_to_status_id, value: in_reply_to_status_id)
            try structEncoder.encode(field: Field.in_reply_to_status_id_str, value: in_reply_to_status_id_str)
            try structEncoder.encode(field: Field.in_reply_to_user_id, value: in_reply_to_user_id)
            try structEncoder.encode(field: Field.in_reply_to_user_id_str, value: in_reply_to_user_id_str)
            try structEncoder.encode(field: Field.in_reply_to_screen_name, value: in_reply_to_screen_name)
            try structEncoder.encode(field: Field.user, value: user)
            try structEncoder.encode(field: Field.retweeted_status, value: retweeted_status)
            try structEncoder.encode(field: Field.retweet_count, value: retweet_count)
            try structEncoder.encode(field: Field.favorite_count, value: favorite_count)
            try structEncoder.encode(field: Field.entities, value: entities)
            try structEncoder.encode(field: Field.favorited, value: favorited)
            try structEncoder.encode(field: Field.retweeted, value: retweeted)
            try structEncoder.encode(field: Field.possibly_sensitive, value: possibly_sensitive)
            try structEncoder.encode(field: Field.lang, value: lang)
        }
    }
}

extension Metadata: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Self {
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

extension Metadata.Field: EncodingField {
}

extension Metadata: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.result_type, value: result_type)
            try structEncoder.encode(field: Field.iso_language_code, value: iso_language_code)
        }
    }
}

extension User: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Self {
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
}

extension User.Field: EncodingField {
}

extension User: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 40) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.id, value: id)
            try structEncoder.encode(field: Field.id_str, value: id_str)
            try structEncoder.encode(field: Field.name, value: name)
            try structEncoder.encode(field: Field.screen_name, value: screen_name)
            try structEncoder.encode(field: Field.location, value: location)
            try structEncoder.encode(field: Field.description, value: description)
            try structEncoder.encode(field: Field.url, value: url)
            try structEncoder.encode(field: Field.entities, value: entities)
            try structEncoder.encode(field: Field.protected, value: protected)
            try structEncoder.encode(field: Field.followers_count, value: followers_count)
            try structEncoder.encode(field: Field.friends_count, value: friends_count)
            try structEncoder.encode(field: Field.listed_count, value: listed_count)
            try structEncoder.encode(field: Field.created_at, value: created_at)
            try structEncoder.encode(field: Field.favourites_count, value: favourites_count)
            try structEncoder.encode(field: Field.utc_offset, value: utc_offset)
            try structEncoder.encode(field: Field.time_zone, value: time_zone)
            try structEncoder.encode(field: Field.geo_enabled, value: geo_enabled)
            try structEncoder.encode(field: Field.verified, value: verified)
            try structEncoder.encode(field: Field.statuses_count, value: statuses_count)
            try structEncoder.encode(field: Field.lang, value: lang)
            try structEncoder.encode(field: Field.contributors_enabled, value: contributors_enabled)
            try structEncoder.encode(field: Field.is_translator, value: is_translator)
            try structEncoder.encode(field: Field.is_translation_enabled, value: is_translation_enabled)
            try structEncoder.encode(field: Field.profile_background_color, value: profile_background_color)
            try structEncoder.encode(field: Field.profile_background_image_url, value: profile_background_image_url)
            try structEncoder.encode(field: Field.profile_background_image_url_https, value: profile_background_image_url_https)
            try structEncoder.encode(field: Field.profile_background_tile, value: profile_background_tile)
            try structEncoder.encode(field: Field.profile_image_url, value: profile_image_url)
            try structEncoder.encode(field: Field.profile_image_url_https, value: profile_image_url_https)
            try structEncoder.encode(field: Field.profile_banner_url, value: profile_banner_url)
            try structEncoder.encode(field: Field.profile_link_color, value: profile_link_color)
            try structEncoder.encode(field: Field.profile_sidebar_border_color, value: profile_sidebar_border_color)
            try structEncoder.encode(field: Field.profile_sidebar_fill_color, value: profile_sidebar_fill_color)
            try structEncoder.encode(field: Field.profile_text_color, value: profile_text_color)
            try structEncoder.encode(field: Field.profile_use_background_image, value: profile_use_background_image)
            try structEncoder.encode(field: Field.default_profile, value: default_profile)
            try structEncoder.encode(field: Field.default_profile_image, value: default_profile_image)
            try structEncoder.encode(field: Field.following, value: following)
            try structEncoder.encode(field: Field.follow_request_sent, value: follow_request_sent)
            try structEncoder.encode(field: Field.notifications, value: notifications)
        }
    }
}

extension UserEntities: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Self {
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

extension UserEntities.Field: EncodingField {
}

extension UserEntities: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.url, value: url)
            try structEncoder.encode(field: Field.description, value: description)
        }
    }
}

extension UserUrl: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Self {
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

extension UserUrl.Field: EncodingField {
}

extension UserUrl: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.urls, value: urls)
        }
    }
}

extension Url: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Self {
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

extension Url.Field: EncodingField {
}

extension Url: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 4) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.url, value: url)
            try structEncoder.encode(field: Field.expanded_url, value: expanded_url)
            try structEncoder.encode(field: Field.display_url, value: display_url)
            try structEncoder.encode(field: Field.indices, value: indices)
        }
    }
}

extension UserEntitiesDescription: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Self {
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

extension UserEntitiesDescription.Field: EncodingField {
}

extension UserEntitiesDescription: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.urls, value: urls)
        }
    }
}

extension StatusEntities: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
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
}

extension StatusEntities.Field: EncodingField {
}

extension StatusEntities: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 5) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.hashtags, value: hashtags)
            try structEncoder.encode(field: Field.symbols, value: symbols)
            try structEncoder.encode(field: Field.urls, value: urls)
            try structEncoder.encode(field: Field.user_mentions, value: user_mentions)
            try structEncoder.encode(field: Field.media, value: media)
        }
    }
}

extension Hashtag: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Self {
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

extension Hashtag.Field: EncodingField {
}

extension Hashtag: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.text, value: text)
            try structEncoder.encode(field: Field.indices, value: indices)
        }
    }
}

extension UserMention: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Self {
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

extension UserMention.Field: EncodingField {
}

extension UserMention: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 5) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.screen_name, value: screen_name)
            try structEncoder.encode(field: Field.name, value: name)
            try structEncoder.encode(field: Field.id, value: id)
            try structEncoder.encode(field: Field.id_str, value: id_str)
            try structEncoder.encode(field: Field.indices, value: indices)
        }
    }
}

extension Media: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
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
}

extension Media.Field: EncodingField {
}

extension Media: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 11) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.id, value: id)
            try structEncoder.encode(field: Field.id_str, value: id_str)
            try structEncoder.encode(field: Field.indices, value: indices)
            try structEncoder.encode(field: Field.media_url, value: media_url)
            try structEncoder.encode(field: Field.media_url_https, value: media_url_https)
            try structEncoder.encode(field: Field.url, value: url)
            try structEncoder.encode(field: Field.display_url, value: display_url)
            try structEncoder.encode(field: Field.expanded_url, value: expanded_url)
            try structEncoder.encode(field: Field.type, value: type)
//            try structEncoder.encode(field: Field.sizes, value: sizes)
            try structEncoder.encode(field: Field.source_status_id, value: source_status_id)
            try structEncoder.encode(field: Field.source_status_id_str, value: source_status_id_str)
        }
    }
}

extension SearchMetadata: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Self {
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

extension SearchMetadata.Field: EncodingField {
}

extension SearchMetadata: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 9) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.completed_in, value: completed_in)
            try structEncoder.encode(field: Field.max_id, value: max_id)
            try structEncoder.encode(field: Field.max_id_str, value: max_id_str)
            try structEncoder.encode(field: Field.next_results, value: next_results)
            try structEncoder.encode(field: Field.query, value: query)
            try structEncoder.encode(field: Field.refresh_url, value: refresh_url)
            try structEncoder.encode(field: Field.count, value: count)
            try structEncoder.encode(field: Field.since_id, value: since_id)
            try structEncoder.encode(field: Field.since_id_str, value: since_id_str)
        }
    }
}

extension ResultType: CommonDecodable {
    struct CommonVisitor: DecodingStringVisitor {
        typealias DecodedValue = ResultType
        
        func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> DecodedValue {
            switch DecodingFieldUTF8SpanRawByteEquivalanceComparator(buffer) {
            case "recent": return .recent
            default: throw CodingError.unknownKey(buffer)
            }
        }
    }
    
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeString(CommonVisitor())
    }
}

extension ResultType: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode("recent")
    }
}

extension Indices: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeArray(elementCount: 2) { arrayEncoder throws(CodingError.Encoding) in
            try arrayEncoder.encode(_0)
            try arrayEncoder.encode(_1)
        }
    }
}

extension Indices: CommonDecodable {
    public static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Self {
        let arr = try decoder.decode([UInt8].self)
        return .init(_0: arr[0], _1: arr[1])
    }
}

extension Sizes: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
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

extension Sizes: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeDictionary(elementCount: 4) { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(key: "medium") { valueEncoder throws(CodingError.Encoding) in try valueEncoder.encode(medium) }
            try dictEncoder.encode(key: "small") { valueEncoder throws(CodingError.Encoding) in try valueEncoder.encode(small) }
            try dictEncoder.encode(key: "thumb") { valueEncoder throws(CodingError.Encoding) in try valueEncoder.encode(thumb) }
            try dictEncoder.encode(key: "large") { valueEncoder throws(CodingError.Encoding) in try valueEncoder.encode(large) }
        }
    }
}

extension Size: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
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
}

extension Size: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeDictionary(elementCount: 3) { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(key: "h") { valueEncoder throws(CodingError.Encoding) in try valueEncoder.encode(h) }
            try dictEncoder.encode(key: "w") { valueEncoder throws(CodingError.Encoding) in try valueEncoder.encode(w) }
            try dictEncoder.encode(key: "resize") { valueEncoder throws(CodingError.Encoding) in try valueEncoder.encode(resize) }
        }
    }
}

extension Resize: CommonDecodable {
    struct CommonVisitor: DecodingStringVisitor {
        typealias DecodedValue = Resize
        
        func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> DecodedValue {
            switch DecodingFieldUTF8SpanRawByteEquivalanceComparator(buffer) {
            case "fit": .fit
            case "crop": .crop
            default: throw CodingError.unknownKey(buffer)
            }
        }
    }
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeString(CommonVisitor())
    }
}

extension Resize: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        switch self {
        case .fit: try encoder.encode("fit")
        case .crop: try encoder.encode("crop")
        }
    }
}
