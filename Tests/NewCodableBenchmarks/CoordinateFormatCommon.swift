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

// MARK: - CoordinateFormat

extension CoordinateFormat: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> CoordinateFormat {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var features: [CoordinateFeature]?
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .features: features = try valueDecoder.decode([CoordinateFeature].self)
                default: break
                }
            }
            guard let features else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(features: features)
        }
    }
}

extension CoordinateFormat: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.features, value: features)
        }
    }
}

extension CoordinateFormat.Field: EncodingField {
}

// MARK: - CoordinateFeature

extension CoordinateFormat.CoordinateFeature: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var geometry: CoordinateFormat.CoordinateGeometry?
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .geometry: geometry = try valueDecoder.decode(CoordinateFormat.CoordinateGeometry.self)
                default: break
                }
            }
            guard let geometry else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
            }
            return .init(geometry: geometry)
        }
    }
}

extension CoordinateFormat.CoordinateFeature: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.geometry, value: geometry)
        }
    }
}

extension CoordinateFormat.CoordinateFeature.Field: EncodingField {
}

// MARK: - CoordinateGeometry

extension CoordinateFormat.CoordinateGeometry: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var coordinates: CoordinateFormat.CoordinateDescription?
            
            var field: Field = .unknown
            try structDecoder.decodeEachField { keyDecoder throws(CodingError.Decoding) in
                field = try keyDecoder.decode(Field.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch field {
                case .coordinates: coordinates = try valueDecoder.decode(CoordinateFormat.CoordinateDescription.self)
                default: break
                }
            }
            guard let coordinates else {
                fatalError("Missing required fields")
            }
            return .init(coordinates: coordinates)
        }
    }
}

extension CoordinateFormat.CoordinateGeometry: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: Field.coordinates, value: coordinates)
        }
    }
}

extension CoordinateFormat.CoordinateGeometry.Field: EncodingField {
}

// MARK: - CoordinateDescription

extension CoordinateFormat.CoordinateDescription: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        let coordinateLists = try decoder.decode([[Coordinate]].self)
        return .init(coordinateLists: coordinateLists)
    }
}

extension CoordinateFormat.CoordinateDescription: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try coordinateLists.encode(to: &encoder)
    }
}

// MARK: - Coordinate

extension CoordinateFormat.CoordinateDescription.Coordinate: CommonDecodable {
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        var lat: Double?
        var long: Double?
        
        try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
            lat = try arrayDecoder.decodeNext { valueDecoder throws(CodingError.Decoding) in
                try valueDecoder.decode(Double.self)
            }
            long = try arrayDecoder.decodeNext { valueDecoder throws(CodingError.Decoding) in
                try valueDecoder.decode(Double.self)
            }
        }
        
        guard let lat, let long else {
            throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
        }
        return .init(lat: lat, long: long)
    }
}

extension CoordinateFormat.CoordinateDescription.Coordinate: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeArray(elementCount: 2) { arrayEncoder throws(CodingError.Encoding) in
            try arrayEncoder.encode(lat)
            try arrayEncoder.encode(long)
        }
    }
}
