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

struct CoordinateFormat : Codable, Equatable {
    struct CoordinateDescription : Codable, Equatable {
        struct Coordinate : Codable, Equatable {
            let lat : Double
            let long : Double
            init(lat: Double, long: Double) {
                self.lat = lat
                self.long = long
            }

            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                lat = try container.decode(Double.self)
                long = try container.decode(Double.self)
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode(lat)
                try container.encode(long)
            }
        }

        let coordinateLists : [[Coordinate]]
        init(coordinateLists: [[Coordinate]]) {
            self.coordinateLists = coordinateLists
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var result = [[Coordinate]]()
            while !container.isAtEnd {
                try result.append(container.decode([Coordinate].self))
            }
            self.coordinateLists = result
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            for coordinateList in coordinateLists {
                try container.encode(coordinateList)
            }
        }
    }
    struct CoordinateGeometry : Codable, Equatable {
        let coordinates: CoordinateDescription
        init(coordinates: CoordinateDescription) {
            self.coordinates = coordinates
        }
    }
    struct CoordinateFeature : Codable, Equatable {
        let geometry : CoordinateGeometry
        init(geometry: CoordinateGeometry) {
            self.geometry = geometry
        }
    }

    let features : [CoordinateFeature]
    init(features: [CoordinateFeature]) {
        self.features = features
    }
}

extension CoordinateFormat: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case features
        case unknown
        
        var staticString: StaticString {
            switch self {
            case .features: "features"
            case .unknown: "unknown"
            }
        }
        
        static func field(for key: UTF8Span) -> Self {
            switch UTF8SpanComparator(key) {
            case "features" : .features
            default: .unknown
            }
        }
    }
    
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var features: [CoordinateFeature]? = nil
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                field = try fieldDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .features: features = try valueDecoder.decode([CoordinateFeature].self)
                default: return
                }
            }
            guard let features else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(features: features)
        }
    }
}

extension CoordinateFormat: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.features) { valueEncoder throws(CodingError.Encoding) in
                try valueEncoder.encode(features)
            }
        }
    }
}

extension CoordinateFormat.CoordinateFeature: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case geometry
        case unknown
        
        var staticString: StaticString {
            switch self {
            case .geometry: "geometry"
            case .unknown: "unknown"
            }
        }
        
        static func field(for key: UTF8Span) -> Self {
            switch UTF8SpanComparator(key) {
            case "geometry" : .geometry
            default: .unknown
            }
        }
    }
    
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var geometry: CoordinateFormat.CoordinateGeometry? = nil
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                field = try fieldDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .geometry: geometry = try valueDecoder.decode(CoordinateFormat.CoordinateGeometry.self)
                default: return
                }
            }
            guard let geometry else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(geometry: geometry)
        }
    }
}

extension CoordinateFormat.CoordinateFeature: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.geometry) { valueEncoder throws(CodingError.Encoding) in
                try valueEncoder.encode(geometry)
            }
        }
    }
}

extension CoordinateFormat.CoordinateGeometry: JSONDecodable {
    enum Field: Int, JSONOptimizedCodingField {
        case coordinates
        case unknown
        
        var staticString: StaticString {
            switch self {
            case .coordinates: "coordinates"
            case .unknown: "unknown"
            }
        }
        
        static func field(for key: UTF8Span) -> Self {
            switch UTF8SpanComparator(key) {
            case "coordinates" : .coordinates
            default: .unknown
            }
        }
    }
    
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var coordinates: CoordinateFormat.CoordinateDescription? = nil
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                field = try fieldDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .coordinates: coordinates = try valueDecoder.decode(CoordinateFormat.CoordinateDescription.self)
                default: return
                }
            }
            guard let coordinates else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(coordinates: coordinates)
        }
    }
}

extension CoordinateFormat.CoordinateGeometry: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            try dictEncoder.encode(field: Field.coordinates) { valueEncoder throws(CodingError.Encoding) in
                try valueEncoder.encode(coordinates)
            }
        }
    }
}

extension CoordinateFormat.CoordinateDescription: JSONDecodable {
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        let coordinateLists = try decoder.decode([[Coordinate]].self)
        return .init(coordinateLists: coordinateLists)
    }
}

extension CoordinateFormat.CoordinateDescription: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(coordinateLists)
    }
}

extension CoordinateFormat.CoordinateDescription.Coordinate: JSONDecodable {
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        let coords = try decoder.decode(InlineArray<2, Double>.self)
        return .init(lat: coords[0], long: coords[1])
    }
}

extension CoordinateFormat.CoordinateDescription.Coordinate: JSONEncodable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeArray(elementCount: 2) { arrayEncoder throws(CodingError.Encoding) in
            try arrayEncoder.encode(lat)
            try arrayEncoder.encode(long)
        }
    }
}




