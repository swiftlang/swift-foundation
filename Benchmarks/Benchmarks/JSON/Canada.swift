//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// Swift port of [Native-JSON Benchmark](https://github.com/miloyip/nativejson-benchmark)
/*
The MIT License (MIT)

Copyright (c) 2014 Milo Yip

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

enum ObjType : String, Codable {
    case featureCollection = "FeatureCollection"
    case feature = "Feature"
    case polygon = "Polygon"
}

struct Feature : Codable {
    var type: ObjType
    var properties: [String: String]
    var geometry: Geometry
}

struct Geometry : Codable {
    struct Coordinate : Codable {
        var latitude: Double
        var longitude: Double

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()
            latitude = try container.decode(Double.self)
            longitude = try container.decode(Double.self)
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(latitude)
            try container.encode(longitude)
        }
    }

    var type: ObjType
    var coordinates: [[Coordinate]]
}

struct FeatureCollection : Codable {
    var type: ObjType
    var features: [Feature]
}

