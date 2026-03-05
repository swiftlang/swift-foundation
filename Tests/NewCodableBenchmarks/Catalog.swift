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

import NewCodable

struct Catalog : Codable, Equatable {
    let areaNames : [String:String]
    let audienceSubCategoryNames : [String:String]
    let blockNames : [String:String]
    let events : [String:Event]
    let performances : [Performance]
    let seatCategoryNames : [String:String]
    let subTopicNames : [String:String]
    let subjectNames : [String:String]
    let topicNames : [String:String]
    let topicSubTopics : [String:[UInt64]]
    let venueNames : [String:String]

    init(areaNames: [String:String], audienceSubCategoryNames: [String:String], blockNames: [String:String], events: [String:Event], performances: [Performance], seatCategoryNames: [String:String], subTopicNames: [String:String], subjectNames: [String:String], topicNames: [String:String], topicSubTopics: [String:[UInt64]], venueNames: [String:String]) {
        self.areaNames = areaNames
        self.audienceSubCategoryNames = audienceSubCategoryNames
        self.blockNames = blockNames
        self.events = events
        self.performances = performances
        self.seatCategoryNames = seatCategoryNames
        self.subTopicNames = subTopicNames
        self.subjectNames = subjectNames
        self.topicNames = topicNames
        self.topicSubTopics = topicSubTopics
        self.venueNames = venueNames
    }

    struct Event : Codable, Equatable {
        let description : String?
        let id : UInt64
        let logo : String?
        let name : String?
        let subTopicIds : [UInt64]
        let subjectCode : String?
        let subtitle: String?
        let topicIDs : [UInt64]?

        internal init(description: String? = nil, id: UInt64, logo: String? = nil, name: String? = nil, subTopicIds: [UInt64], subjectCode: String? = nil, subtitle: String? = nil, topicIDs: [UInt64]? = nil) {
            self.description = description
            self.id = id
            self.logo = logo
            self.name = name
            self.subTopicIds = subTopicIds
            self.subjectCode = subjectCode
            self.subtitle = subtitle
            self.topicIDs = topicIDs
        }
    }

    struct Performance : Codable, Equatable {
        let eventId : UInt64
        let id : UInt64
        let logo : String?
        let name : String?
        let prices : [Price]
        let seatCategories : [SeatCategory]
        let seatMapImage : String?
        let start : UInt64
        let venueCode : String

        init(eventId: UInt64, id: UInt64, logo: String? = nil, name: String? = nil, prices: [Price], seatCategories: [SeatCategory], seatMapImage: String? = nil, start: UInt64, venueCode: String) {
            self.eventId = eventId
            self.id = id
            self.logo = logo
            self.name = name
            self.prices = prices
            self.seatCategories = seatCategories
            self.seatMapImage = seatMapImage
            self.start = start
            self.venueCode = venueCode
        }
        
        struct SeatCategory : Codable, Equatable {
            let seatCategoryId : UInt64
            let areas : [SeatArea]

            init(seatCategoryId: UInt64, areas: [SeatArea]) {
                self.seatCategoryId = seatCategoryId
                self.areas = areas
            }
        }

        struct SeatArea : Codable, Equatable {
            let areaId : UInt64
            let blockIds : [UInt64]

            init(areaId: UInt64, blockIds: [UInt64]) {
                self.areaId = areaId
                self.blockIds = blockIds
            }
        }
        
        struct Price : Codable, Equatable {
            let amount: UInt32
            let audienceSubCategoryId: UInt32
            let seatCategoryId: UInt32
            
            init(amount: UInt32, audienceSubCategoryId: UInt32, seatCategoryId: UInt32) {
                self.amount = amount
                self.audienceSubCategoryId = audienceSubCategoryId
                self.seatCategoryId = seatCategoryId
            }
        }
    }
}

extension Catalog: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case areaNames
        case audienceSubCategoryNames
        case blockNames
        case events
        case performances
        case seatCategoryNames
        case subTopicNames
        case subjectNames
        case topicNames
        case topicSubTopics
        case venueNames
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .areaNames: "areaNames"
            case .audienceSubCategoryNames: "audienceSubCategoryNames"
            case .blockNames: "blockNames"
            case .events: "events"
            case .performances: "performances"
            case .seatCategoryNames: "seatCategoryNames"
            case .subTopicNames: "subTopicNames"
            case .subjectNames: "subjectNames"
            case .topicNames: "topicNames"
            case .topicSubTopics: "topicSubTopics"
            case .venueNames: "venueNames"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "areaNames": .areaNames
            case "audienceSubCategoryNames": .audienceSubCategoryNames
            case "blockNames": .blockNames
            case "events": .events
            case "performances": .performances
            case "seatCategoryNames": .seatCategoryNames
            case "subTopicNames": .subTopicNames
            case "subjectNames": .subjectNames
            case "topicNames": .topicNames
            case "topicSubTopics": .topicSubTopics
            case "venueNames": .venueNames
            default: throw CodingError.unknownKey(key)
            }
        }
    }
    
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var areaNames : [String:String]?
            var audienceSubCategoryNames : [String:String]?
            var blockNames : [String:String]?
            var events : [String:Event]?
            var performances : [Performance]?
            var seatCategoryNames : [String:String]?
            var subTopicNames : [String:String]?
            var subjectNames : [String:String]?
            var topicNames : [String:String]?
            var topicSubTopics : [String:[UInt64]]?
            var venueNames : [String:String]?
            
            var field: Field?
            try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                field = try fieldDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .areaNames: areaNames = try valueDecoder.decode([String:String].self)
                case .audienceSubCategoryNames: audienceSubCategoryNames = try valueDecoder.decode([String:String].self)
                case .blockNames: blockNames = try valueDecoder.decode([String:String].self)
                case .events: events = try valueDecoder.decode([String:Event].self)
                case .performances: performances = try valueDecoder.decode([Performance].self)
                case .seatCategoryNames: seatCategoryNames = try valueDecoder.decode([String:String].self)
                case .subTopicNames: subTopicNames = try valueDecoder.decode([String:String].self)
                case .subjectNames: subjectNames = try valueDecoder.decode([String:String].self)
                case .topicNames: topicNames = try valueDecoder.decode([String:String].self)
                case .topicSubTopics: topicSubTopics = try valueDecoder.decode([String:[UInt64]].self)
                case .venueNames: venueNames = try valueDecoder.decode([String:String].self)
                }
            }
            guard let areaNames, let audienceSubCategoryNames, let blockNames, let events, let performances, let seatCategoryNames, let subTopicNames, let subjectNames, let topicNames, let topicSubTopics, let venueNames else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(areaNames: areaNames, audienceSubCategoryNames: audienceSubCategoryNames, blockNames: blockNames, events: events, performances: performances, seatCategoryNames: seatCategoryNames, subTopicNames: subTopicNames, subjectNames: subjectNames, topicNames: topicNames, topicSubTopics: topicSubTopics, venueNames: venueNames)
        }
    }
}

extension Catalog: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.areaNames) { ve throws(CodingError.Encoding) in try ve.encode(areaNames) }
            try dictEncoder.encode(field: Field.audienceSubCategoryNames) { ve throws(CodingError.Encoding) in try ve.encode(audienceSubCategoryNames) }
            try dictEncoder.encode(field: Field.blockNames) { ve throws(CodingError.Encoding) in try ve.encode(blockNames) }
            try dictEncoder.encode(field: Field.events) { ve throws(CodingError.Encoding) in try ve.encode(events) }
            try dictEncoder.encode(field: Field.performances) { ve throws(CodingError.Encoding) in try ve.encode(performances) }
            try dictEncoder.encode(field: Field.seatCategoryNames) { ve throws(CodingError.Encoding) in try ve.encode(seatCategoryNames) }
            try dictEncoder.encode(field: Field.subTopicNames) { ve throws(CodingError.Encoding) in try ve.encode(subTopicNames) }
            try dictEncoder.encode(field: Field.subjectNames) { ve throws(CodingError.Encoding) in try ve.encode(subjectNames) }
            try dictEncoder.encode(field: Field.topicNames) { ve throws(CodingError.Encoding) in try ve.encode(topicNames) }
            try dictEncoder.encode(field: Field.topicSubTopics) { ve throws(CodingError.Encoding) in try ve.encode(topicSubTopics) }
            try dictEncoder.encode(field: Field.venueNames) { ve throws(CodingError.Encoding) in try ve.encode(venueNames) }
        }
    }
}

extension Catalog.Event: JSONDecodable {
    enum Field: Int, JSONOptimizedDecodingField {
        case description
        case id
        case logo
        case name
        case subTopicIds
        case subjectCode
        case subtitle
        case topicIds

        var staticString: StaticString {
            switch self {
            case .description: "description"
            case .id: "id"
            case .logo: "logo"
            case .name: "name"
            case .subTopicIds: "subTopicIds"
            case .subjectCode: "subjectCode"
            case .subtitle: "subtitle"
            case .topicIds: "topicIds"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "description": .description
            case "id": .id
            case "logo": .logo
            case "name": .name
            case "subTopicIds": .subTopicIds
            case "subjectCode": .subjectCode
            case "subtitle": .subtitle
            case "topicIds": .topicIds
            default: throw CodingError.unknownKey(key)
            }
        }
    }
    
    @usableFromInline
    struct JSONBuilder: ~Copyable, ~Escapable {
        var description : String?
        var id : UInt64?
        var logo : String?
        var name : String?
        var subTopicIds : [UInt64]?
        var subjectCode : String?
        var subtitle: String?
        var topicIds : [UInt64]?

        @inline(__always)
        @_lifetime(copy structDecoder)
        init(structDecoder: JSONParserDecoder.StructDecoder) { }
        
        @inline(__always)
        @_lifetime(self: copy self)
        mutating func buildTryingExpectedOrder(using structDecoder: inout JSONParserDecoder.StructDecoder) throws(CodingError.Decoding) -> Catalog.Event {
            var inOrder = true
            try structDecoder.decodeExpectedOrderField(Field.description, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.description = try vd.decode(String?.self) }
            try structDecoder.decodeExpectedOrderField(Field.id, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.id = try vd.decode(UInt64.self) }
            try structDecoder.decodeExpectedOrderField(Field.logo, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.logo = try vd.decode(String?.self) }
            try structDecoder.decodeExpectedOrderField(Field.name, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.name = try vd.decode(String?.self) }
            try structDecoder.decodeExpectedOrderField(Field.subTopicIds, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.subTopicIds = try vd.decode([UInt64].self) }
            try structDecoder.decodeExpectedOrderField(Field.subjectCode, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.subjectCode = try vd.decode(String?.self) }
            try structDecoder.decodeExpectedOrderField(Field.subtitle, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.subtitle = try vd.decode(String?.self) }
            try structDecoder.decodeExpectedOrderField(Field.topicIds, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.topicIds = try vd.decode([UInt64]?.self) }
            if !inOrder {
                var field: Field? = nil
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
            case .description: description = try valueDecoder.decode(String?.self)
            case .id: id = try valueDecoder.decode(UInt64.self)
            case .logo: logo = try valueDecoder.decode(String?.self)
            case .name: name = try valueDecoder.decode(String?.self)
            case .subTopicIds: subTopicIds = try valueDecoder.decode([UInt64].self)
            case .subjectCode: subjectCode = try valueDecoder.decode(String?.self)
            case .subtitle: subtitle = try valueDecoder.decode(String?.self)
            case .topicIds: topicIds = try valueDecoder.decode([UInt64]?.self)
            }
            return true
        }
        
        @inline(__always)
        func build() throws(CodingError.Decoding) -> Catalog.Event {
            guard let id, let subTopicIds else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(description: description, id: id, logo: logo, name: name, subTopicIds: subTopicIds, subjectCode: subjectCode, subtitle: subtitle, topicIDs: topicIds)
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
            var description : String?
            var id : UInt64?
            var logo : String?
            var name : String?
            var subTopicIds : [UInt64]?
            var subjectCode : String?
            var subtitle: String?
            var topicIds : [UInt64]?
            
            var field: Field?
            try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                field = try fieldDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .description: description = try valueDecoder.decode(String?.self)
                case .id: id = try valueDecoder.decode(UInt64.self)
                case .logo: logo = try valueDecoder.decode(String?.self)
                case .name: name = try valueDecoder.decode(String?.self)
                case .subTopicIds: subTopicIds = try valueDecoder.decode([UInt64].self)
                case .subjectCode: subjectCode = try valueDecoder.decode(String?.self)
                case .subtitle: subtitle = try valueDecoder.decode(String?.self)
                case .topicIds: topicIds = try valueDecoder.decode([UInt64]?.self)
                }
            }
            guard let id, let subTopicIds else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(description: description, id: id, logo: logo, name: name, subTopicIds: subTopicIds, subjectCode: subjectCode, subtitle: subtitle, topicIDs: topicIds)
        }
    }
    
    static func decode(from decoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var builder = JSONBuilder(structDecoder: structDecoder)
            return try builder.buildTryingExpectedOrder(using: &structDecoder)
        }
    }
}

extension Catalog.Event: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.description) { ve throws(CodingError.Encoding) in try ve.encode(description) }
            try dictEncoder.encode(field: Field.id) { ve throws(CodingError.Encoding) in try ve.encode(id) }
            try dictEncoder.encode(field: Field.logo) { ve throws(CodingError.Encoding) in try ve.encode(logo) }
            try dictEncoder.encode(field: Field.name) { ve throws(CodingError.Encoding) in try ve.encode(name) }
            try dictEncoder.encode(field: Field.subTopicIds) { ve throws(CodingError.Encoding) in try ve.encode(subTopicIds) }
            try dictEncoder.encode(field: Field.subjectCode) { ve throws(CodingError.Encoding) in try ve.encode(subjectCode) }
            try dictEncoder.encode(field: Field.subtitle) { ve throws(CodingError.Encoding) in try ve.encode(subtitle) }
            try dictEncoder.encode(field: Field.topicIds) { ve throws(CodingError.Encoding) in try ve.encode(topicIDs) }
        }
    }
}

extension Catalog.Performance: JSONDecodable {
    enum Field: Int, JSONOptimizedDecodingField {
        case eventId
        case id
        case logo
        case name
        case prices
        case seatCategories
        case seatMapImage
        case start
        case venueCode
        
        var staticString: StaticString {
            switch self {
            case .eventId: "eventId"
            case .id: "id"
            case .logo: "logo"
            case .name: "name"
            case .prices: "prices"
            case .seatCategories: "seatCategories"
            case .seatMapImage: "seatMapImage"
            case .start: "start"
            case .venueCode: "venueCode"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "eventId": .eventId
            case "id": .id
            case "logo": .logo
            case "name": .name
            case "prices": .prices
            case "seatCategories": .seatCategories
            case "seatMapImage": .seatMapImage
            case "start": .start
            case "venueCode": .venueCode
            default: throw CodingError.unknownKey(key)
            }
        }
    }
    
    @usableFromInline
    struct JSONBuilder: ~Copyable, ~Escapable {
        var eventId : UInt64?
        var id : UInt64?
        var logo : String?
        var name : String?
        var prices : [Price]?
        var seatCategories : [SeatCategory]?
        var seatMapImage : String?
        var start : UInt64?
        var venueCode : String?

        @inline(__always)
        @_lifetime(copy structDecoder)
        init(structDecoder: JSONParserDecoder.StructDecoder) { }
        
        @inline(__always)
        @_lifetime(self: copy self)
        mutating func buildTryingExpectedOrder(using structDecoder: inout JSONParserDecoder.StructDecoder) throws(CodingError.Decoding) -> Catalog.Performance {
            var inOrder = true
            try structDecoder.decodeExpectedOrderField(Field.eventId, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.eventId = try vd.decode(UInt64.self) }
            try structDecoder.decodeExpectedOrderField(Field.id, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.id = try vd.decode(UInt64.self) }
            try structDecoder.decodeExpectedOrderField(Field.logo, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.logo = try vd.decode(String?.self) }
            try structDecoder.decodeExpectedOrderField(Field.name, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.name = try vd.decode(String?.self) }
            try structDecoder.decodeExpectedOrderField(Field.prices, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.prices = try vd.decode([Price].self) }
            try structDecoder.decodeExpectedOrderField(Field.seatCategories, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.seatCategories = try vd.decode([SeatCategory].self) }
            try structDecoder.decodeExpectedOrderField(Field.seatMapImage, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.seatMapImage = try vd.decode(String?.self) }
            try structDecoder.decodeExpectedOrderField(Field.start, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.start = try vd.decode(UInt64.self) }
            try structDecoder.decodeExpectedOrderField(Field.venueCode, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.venueCode = try vd.decode(String.self) }
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
            case .eventId: eventId = try valueDecoder.decode(UInt64.self)
            case .id: id = try valueDecoder.decode(UInt64.self)
            case .logo: logo = try valueDecoder.decode(String?.self)
            case .name: name = try valueDecoder.decode(String?.self)
            case .prices: prices = try valueDecoder.decode([Price].self)
            case .seatCategories: seatCategories = try valueDecoder.decode([SeatCategory].self)
            case .seatMapImage: seatMapImage = try valueDecoder.decode(String?.self)
            case .start: start = try valueDecoder.decode(UInt64.self)
            case .venueCode: venueCode = try valueDecoder.decode(String.self)
            }
            return true
        }
        
        @inline(__always)
        func build() throws(CodingError.Decoding) -> Catalog.Performance {
            guard let eventId, let id, let prices, let seatCategories, let start, let venueCode else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(eventId: eventId, id: id, logo: logo, name: name, prices: prices, seatCategories: seatCategories, seatMapImage: seatMapImage, start: start, venueCode: venueCode)
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
            var eventId : UInt64?
            var id : UInt64?
            var logo : String?
            var name : String?
            var prices : [Price]?
            var seatCategories : [SeatCategory]?
            var seatMapImage : String?
            var start : UInt64?
            var venueCode : String?
            
            var field: Field?
            try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                field = try fieldDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .eventId: eventId = try valueDecoder.decode(UInt64.self)
                case .id: id = try valueDecoder.decode(UInt64.self)
                case .logo: logo = try valueDecoder.decode(String?.self)
                case .name: name = try valueDecoder.decode(String?.self)
                case .prices: prices = try valueDecoder.decode([Price].self)
                case .seatCategories: seatCategories = try valueDecoder.decode([SeatCategory].self)
                case .seatMapImage: seatMapImage = try valueDecoder.decode(String?.self)
                case .start: start = try valueDecoder.decode(UInt64.self)
                case .venueCode: venueCode = try valueDecoder.decode(String.self)
                }
            }
            guard let eventId, let id, let prices, let seatCategories, let start, let venueCode else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(eventId: eventId, id: id, logo: logo, name: name, prices: prices, seatCategories: seatCategories, seatMapImage: seatMapImage, start: start, venueCode: venueCode)
        }
    }
    
    static func decode(from decoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var builder = JSONBuilder(structDecoder: structDecoder)
            return try builder.buildTryingExpectedOrder(using: &structDecoder)
        }
    }
}

extension Catalog.Performance: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.eventId) { ve throws(CodingError.Encoding) in try ve.encode(eventId) }
            try dictEncoder.encode(field: Field.id) { ve throws(CodingError.Encoding) in try ve.encode(id) }
            try dictEncoder.encode(field: Field.logo) { ve throws(CodingError.Encoding) in try ve.encode(logo) }
            try dictEncoder.encode(field: Field.name) { ve throws(CodingError.Encoding) in try ve.encode(name) }
            try dictEncoder.encode(field: Field.prices) { ve throws(CodingError.Encoding) in try ve.encode(prices) }
            try dictEncoder.encode(field: Field.seatCategories) { ve throws(CodingError.Encoding) in try ve.encode(seatCategories) }
            try dictEncoder.encode(field: Field.seatMapImage) { ve throws(CodingError.Encoding) in try ve.encode(seatMapImage) }
            try dictEncoder.encode(field: Field.start) { ve throws(CodingError.Encoding) in try ve.encode(start) }
            try dictEncoder.encode(field: Field.venueCode) { ve throws(CodingError.Encoding) in try ve.encode(venueCode) }
        }
    }
}

extension Catalog.Performance.SeatCategory: JSONDecodable {
    enum Field: Int, JSONOptimizedDecodingField {
        case seatCategoryId
        case areas
        
        var staticString: StaticString {
            switch self {
            case .seatCategoryId: "seatCategoryId"
            case .areas: "areas"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "seatCategoryId": .seatCategoryId
            case "areas": .areas
            default: throw CodingError.unknownKey(key)
            }
        }
    }
    
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var seatCategoryId : UInt64?
            var areas : [Catalog.Performance.SeatArea]?
            
            var field: Field?
            try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                field = try fieldDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .seatCategoryId: seatCategoryId = try valueDecoder.decode(UInt64.self)
                case .areas: areas = try valueDecoder.decode([Catalog.Performance.SeatArea].self)
                }
            }
            guard let seatCategoryId, let areas else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(seatCategoryId: seatCategoryId, areas: areas)
        }
    }
}

extension Catalog.Performance.SeatCategory: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.seatCategoryId) { ve throws(CodingError.Encoding) in try ve.encode(seatCategoryId) }
            try dictEncoder.encode(field: Field.areas) { ve throws(CodingError.Encoding) in try ve.encode(areas) }
        }
    }
}

extension Catalog.Performance.SeatArea: JSONDecodable {
    enum Field: Int, JSONOptimizedDecodingField {
        case areaId
        case blockIds
        
        var staticString: StaticString {
            switch self {
            case .areaId: "areaId"
            case .blockIds: "blockIds"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "areaId": .areaId
            case "blockIds": .blockIds
            default: throw CodingError.unknownKey(key)
            }
        }
    }
    
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var areaId : UInt64?
            var blockIds : [UInt64]?
            
            var field: Field?
            try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                field = try fieldDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .areaId: areaId = try valueDecoder.decode(UInt64.self)
                case .blockIds: blockIds = try valueDecoder.decode([UInt64].self)
                }
            }
            guard let areaId, let blockIds else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(areaId: areaId, blockIds: blockIds)
        }
    }
}

extension Catalog.Performance.SeatArea: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.areaId) { ve throws(CodingError.Encoding) in try ve.encode(areaId) }
            try dictEncoder.encode(field: Field.blockIds) { ve throws(CodingError.Encoding) in try ve.encode(blockIds) }
        }
    }
}

extension Catalog.Performance.Price: JSONDecodable {
    enum Field: Int, JSONOptimizedDecodingField {
        case amount
        case audienceSubCategoryId
        case seatCategoryId
        
        var staticString: StaticString {
            switch self {
            case .amount: "amount"
            case .audienceSubCategoryId: "audienceSubCategoryId"
            case .seatCategoryId: "seatCategoryId"
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Field {
            switch UTF8SpanComparator(key) {
            case "amount": .amount
            case "audienceSubCategoryId": .audienceSubCategoryId
            case "seatCategoryId": .seatCategoryId
            default: throw CodingError.unknownKey(key)
            }
        }
    }
    
    @usableFromInline
    struct JSONBuilder: ~Copyable, ~Escapable {
        var amount: UInt32?
        var audienceSubCategoryId: UInt32?
        var seatCategoryId: UInt32?

        @inline(__always)
        @_lifetime(copy structDecoder)
        init(structDecoder: JSONParserDecoder.StructDecoder) { }
        
        @inline(__always)
        @_lifetime(self: copy self)
        mutating func buildTryingExpectedOrder(using structDecoder: inout JSONParserDecoder.StructDecoder) throws(CodingError.Decoding) -> Catalog.Performance.Price {
            var inOrder = true
            try structDecoder.decodeExpectedOrderField(Field.amount, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.amount = try vd.decode(UInt32.self) }
            try structDecoder.decodeExpectedOrderField(Field.audienceSubCategoryId, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.audienceSubCategoryId = try vd.decode(UInt32.self) }
            try structDecoder.decodeExpectedOrderField(Field.seatCategoryId, inOrder: &inOrder) { vd throws(CodingError.Decoding) in self.seatCategoryId = try vd.decode(UInt32.self) }
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
            case .amount: amount = try valueDecoder.decode(UInt32.self)
            case .audienceSubCategoryId: audienceSubCategoryId = try valueDecoder.decode(UInt32.self)
            case .seatCategoryId: seatCategoryId = try valueDecoder.decode(UInt32.self)
            }
            return true
        }
        
        @inline(__always)
        func build() throws(CodingError.Decoding) -> Catalog.Performance.Price {
            guard let amount, let audienceSubCategoryId, let seatCategoryId else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(amount: amount, audienceSubCategoryId: audienceSubCategoryId, seatCategoryId: seatCategoryId)

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
            var amount: UInt32?
            var audienceSubCategoryId: UInt32?
            var seatCategoryId: UInt32?
            
            var field: Field?
            try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                field = try fieldDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .amount: amount = try valueDecoder.decode(UInt32.self)
                case .audienceSubCategoryId: audienceSubCategoryId = try valueDecoder.decode(UInt32.self)
                case .seatCategoryId: seatCategoryId = try valueDecoder.decode(UInt32.self)
                }
            }
            guard let amount, let audienceSubCategoryId, let seatCategoryId else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(amount: amount, audienceSubCategoryId: audienceSubCategoryId, seatCategoryId: seatCategoryId)
        }
    }

    static func decode(from decoder: inout JSONParserDecoder) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var builder = JSONBuilder(structDecoder: structDecoder)
            return try builder.buildTryingExpectedOrder(using: &structDecoder)
        }
    }

}
extension Catalog.Performance.Price: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary(elementCount: 3) { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.amount) { ve throws(CodingError.Encoding) in try ve.encode(amount) }
            try dictEncoder.encode(field: Field.audienceSubCategoryId) { ve throws(CodingError.Encoding) in try ve.encode(audienceSubCategoryId) }
            try dictEncoder.encode(field: Field.seatCategoryId) { ve throws(CodingError.Encoding) in try ve.encode(seatCategoryId) }
        }
    }
}
