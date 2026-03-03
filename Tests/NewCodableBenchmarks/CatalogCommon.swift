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

// MARK: - Catalog

extension Catalog: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Catalog {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var areaNames: [String:String]?
            var audienceSubCategoryNames: [String:String]?
            var blockNames: [String:String]?
            var events: [String:Event]?
            var performances: [Performance]?
            var seatCategoryNames: [String:String]?
            var subTopicNames: [String:String]?
            var subjectNames: [String:String]?
            var topicNames: [String:String]?
            var topicSubTopics: [String:[UInt64]]?
            var venueNames: [String:String]?
            
            var field: Field?
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
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
            guard let areaNames, let audienceSubCategoryNames, let blockNames, let events, let performances,
                  let seatCategoryNames, let subTopicNames, let subjectNames, let topicNames,
                  let topicSubTopics, let venueNames else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(areaNames: areaNames, audienceSubCategoryNames: audienceSubCategoryNames,
                        blockNames: blockNames, events: events, performances: performances,
                        seatCategoryNames: seatCategoryNames, subTopicNames: subTopicNames,
                        subjectNames: subjectNames, topicNames: topicNames,
                        topicSubTopics: topicSubTopics, venueNames: venueNames)
        }
    }
}

extension Catalog: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 11) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.areaNames, value: areaNames)
            try structEncoder.encode(field: Field.audienceSubCategoryNames, value: audienceSubCategoryNames)
            try structEncoder.encode(field: Field.blockNames, value: blockNames)
            try structEncoder.encode(field: Field.events, value: events)
            try structEncoder.encode(field: Field.performances, value: performances)
            try structEncoder.encode(field: Field.seatCategoryNames, value: seatCategoryNames)
            try structEncoder.encode(field: Field.subTopicNames, value: subTopicNames)
            try structEncoder.encode(field: Field.subjectNames, value: subjectNames)
            try structEncoder.encode(field: Field.topicNames, value: topicNames)
            try structEncoder.encode(field: Field.topicSubTopics, value: topicSubTopics)
            try structEncoder.encode(field: Field.venueNames, value: venueNames)
        }
    }
}

// MARK: - Event

extension Catalog.Event: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var description: String?
            var id: UInt64?
            var logo: String?
            var name: String?
            var subTopicIds: [UInt64]?
            var subjectCode: String?
            var subtitle: String?
            var topicIDs: [UInt64]?
            
            var field: Field?
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field! {
                case .description: description = try valueDecoder.decode(String?.self)
                case .id: id = try valueDecoder.decode(UInt64.self)
                case .logo: logo = try valueDecoder.decode(String?.self)
                case .name: name = try valueDecoder.decode(String?.self)
                case .subTopicIds: subTopicIds = try valueDecoder.decode([UInt64].self)
                case .subjectCode: subjectCode = try valueDecoder.decode(String?.self)
                case .subtitle: subtitle = try valueDecoder.decode(String?.self)
                case .topicIds: topicIDs = try valueDecoder.decode([UInt64]?.self)
                }
            }
            guard let id, let subTopicIds else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(description: description, id: id, logo: logo, name: name,
                        subTopicIds: subTopicIds, subjectCode: subjectCode,
                        subtitle: subtitle, topicIDs: topicIDs)
        }
    }
}

extension Catalog.Event: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 8) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.description, value: description)
            try structEncoder.encode(field: Field.id, value: id)
            try structEncoder.encode(field: Field.logo, value: logo)
            try structEncoder.encode(field: Field.name, value: name)
            try structEncoder.encode(field: Field.subTopicIds, value: subTopicIds)
            try structEncoder.encode(field: Field.subjectCode, value: subjectCode)
            try structEncoder.encode(field: Field.subtitle, value: subtitle)
            try structEncoder.encode(field: Field.topicIds, value: topicIDs)
        }
    }
}

extension Catalog.Event.Field: EncodingField {
}

// MARK: - Performance

extension Catalog.Performance: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var eventId: UInt64?
            var id: UInt64?
            var logo: String?
            var name: String?
            var prices: [Price]?
            var seatCategories: [SeatCategory]?
            var seatMapImage: String?
            var start: UInt64?
            var venueCode: String?
            
            var field: Field?
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
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
            return .init(eventId: eventId, id: id, logo: logo, name: name,
                        prices: prices, seatCategories: seatCategories,
                        seatMapImage: seatMapImage, start: start, venueCode: venueCode)
        }
    }
}

extension Catalog.Performance: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 9) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.eventId, value: eventId)
            try structEncoder.encode(field: Field.id, value: id)
            try structEncoder.encode(field: Field.logo, value: logo)
            try structEncoder.encode(field: Field.name, value: name)
            try structEncoder.encode(field: Field.prices, value: prices)
            try structEncoder.encode(field: Field.seatCategories, value: seatCategories)
            try structEncoder.encode(field: Field.seatMapImage, value: seatMapImage)
            try structEncoder.encode(field: Field.start, value: start)
            try structEncoder.encode(field: Field.venueCode, value: venueCode)
        }
    }
}

extension Catalog.Performance.Field: EncodingField {
}

// MARK: - SeatCategory

extension Catalog.Performance.SeatCategory: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var seatCategoryId: UInt64?
            var areas: [Catalog.Performance.SeatArea]?
            
            var field: Field?
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
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

extension Catalog.Performance.SeatCategory: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.seatCategoryId, value: seatCategoryId)
            try structEncoder.encode(field: Field.areas, value: areas)
        }
    }
}

extension Catalog.Performance.SeatCategory.Field: EncodingField {
}

// MARK: - SeatArea

extension Catalog.Performance.SeatArea: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var areaId: UInt64?
            var blockIds: [UInt64]?
            
            var field: Field?
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .areaId: areaId = try valueDecoder.decode(UInt64.self)
                case .blockIds: blockIds = try valueDecoder.decode([UInt64].self)
                default: break
                }
            }
            guard let areaId, let blockIds else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(areaId: areaId, blockIds: blockIds)
        }
    }
}

extension Catalog.Performance.SeatArea: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.areaId, value: areaId)
            try structEncoder.encode(field: Field.blockIds, value: blockIds)
        }
    }
}

extension Catalog.Performance.SeatArea.Field: EncodingField {
}

// MARK: - Price

extension Catalog.Performance.Price: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var amount: UInt32?
            var audienceSubCategoryId: UInt32?
            var seatCategoryId: UInt32?
            
            var field: Field?
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
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
            return .init(amount: amount, audienceSubCategoryId: audienceSubCategoryId,
                        seatCategoryId: seatCategoryId)
        }
    }
}

extension Catalog.Performance.Price: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 3) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.amount, value: amount)
            try structEncoder.encode(field: Field.audienceSubCategoryId, value: audienceSubCategoryId)
            try structEncoder.encode(field: Field.seatCategoryId, value: seatCategoryId)
        }
    }
}

extension Catalog.Performance.Price.Field: EncodingField {
}
