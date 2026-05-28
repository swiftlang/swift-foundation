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

// Structs borrowed from NewCodableTests

/// A JSON-specific decoding strategy that extracts the JSONPrimtivie.Number
/// of a JSON number using `decodeNumber()` on `JSONDecoderProtocol`.
struct JSONNumberDecodingStrategy: JSONDecodingStrategy {
    typealias Value = JSONPrimitive.Number

    func decode(from decoder: inout some (JSONDecoderProtocol & ~Escapable)) throws(CodingError.Decoding) -> JSONPrimitive.Number {
        return try decoder.decodeNumber()
    }
}

@JSONDecodable
struct DecodableByJSONNumberAsString {
    @DecodableBy(JSONNumberDecodingStrategy())
    let price: JSONPrimitive.Number
    let name: String
}

@JSONCodable
struct CodableByDictionaryWithLosslessKey {
    @CodableBy([.losslessStringConversion : .pass])
    let scores: [Int:String]
}

@JSONCodable
enum SimpleStatus: Equatable {
    case active
    case inactive
}

@JSONCodable
enum TaskStatus: Equatable {
    @CodingKey("in_progress") case inProgress
    case done
}

@JSONCodable
enum FlexibleStatus: Equatable {
    @DecodableAlias("in-progress") @CodingKey("in_progress") case inProgress
    case done
}

@JSONCodable
enum Shape: Equatable {
    case circle(radius: Double)
    case point
}

@JSONCodable
enum Wrapper: Equatable {
    case single(Int)
    case pair(String, Int)
}
