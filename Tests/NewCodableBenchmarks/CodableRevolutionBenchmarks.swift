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

#if canImport(CollectionsInternal)
internal import CollectionsInternal
#elseif canImport(BasicContainers)
internal import BasicContainers
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(CRT)
import CRT
#elseif os(WASI)
import WASILibc
#endif

import class Foundation.Bundle

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

@inline(never)
fileprivate func _blackHole<T: ~Copyable & ~Escapable>(_ t: consuming T) {}

func throughput(dur: Double, bytes: Int) -> UInt64 {
    let durAsMicros = dur * 1000 * 1000
    print("duration:", durAsMicros, "ms and bytes:", bytes)
    let megabytes_per_second = Double(bytes) / durAsMicros
    return UInt64(megabytes_per_second)
}

@Suite("New Codable Benchmarks", .serialized)
struct NewCodableBenchmarks {
    static let bundle = Bundle.module
    static let twitterURL: FoundationEssentials.URL = {
        let url = Self.bundle.url(forResource: "twitter", withExtension: "json")!
        return .init(filePath: url.path)
    }()
    
    static let canadaURL: FoundationEssentials.URL = {
        let url = Self.bundle.url(forResource: "canada", withExtension: "json")!
        return .init(filePath: url.path)
    }()
    
    static let catalogURL: FoundationEssentials.URL = {
        let url = Self.bundle.url(forResource: "citm_catalog", withExtension: "json")!
        return .init(filePath: url.path)
    }()

    @Test func twitter_benchmark_json_decodable_old() async throws {
        let data = try! Data(contentsOf: Self.twitterURL)

        let iters = 256
        var min_interval: TimeInterval?
        for _ in 0 ..< iters {
            let start = Date.now
            let decoder = JSONDecoder()
            _blackHole(try decoder.decode(Twitter.self, from: data))
            let end = Date.now
            let this_interval = end.timeIntervalSince(start)

            min_interval = min(min_interval ?? this_interval, this_interval)
        }

        print("Throughput: \(throughput(dur: min_interval!, bytes: data.count)) MB/s")
    }
    
        @Test func twitter_benchmark_json_decodable_new() async throws {
        let decoder = NewJSONDecoder()
        
        @_transparent
        func asJSON<D: JSONTopLevelDecoder & ~Copyable>(_ jsonDecoder: borrowing D) throws {
            let data = try! Data(contentsOf: Self.twitterURL)
            
            let iters = 256
            var min_interval: TimeInterval?
            for _ in 0 ..< iters {
                let start = Date.now
                _blackHole(try jsonDecoder.decode(Twitter.self, from: data))
                let end = Date.now
                let this_interval = end.timeIntervalSince(start)

                min_interval = min(min_interval ?? this_interval, this_interval)
            }

            print("Throughput: \(throughput(dur: min_interval!, bytes: data.count)) MB/s")
        }
        try asJSON(decoder)
    }
    
        @Test func twitter_benchmark_json_common_decodable_new() async throws {
        let decoder = NewJSONDecoder()
        
        @_transparent
        func asCommon<D: CommonTopLevelDecoder & ~Copyable>(_ commonDecoder: borrowing D) throws {
            let data = try! Data(contentsOf: Self.twitterURL)
            
            let iters = 256
            var min_interval: TimeInterval?
            for _ in 0 ..< iters {
                let start = Date.now
                _blackHole(try commonDecoder.decode(Twitter.self, from: data))
                let end = Date.now
                let this_interval = end.timeIntervalSince(start)
                
                min_interval = min(min_interval ?? this_interval, this_interval)
            }
            
            print("Throughput: \(throughput(dur: min_interval!, bytes: data.count)) MB/s")
        }
        try asCommon(decoder)
    }
    
    @Test func twitter_benchmark_json_encodable_old() async throws {
        let data = try! Data(contentsOf: Self.twitterURL)
        let decoder = JSONDecoder()
        let twitter = try decoder.decode(Twitter.self, from: data)
        
        let reencodedData = try JSONEncoder().encode(twitter)
        
        let iters = 256
        var min_interval: TimeInterval?
        for _ in 0 ..< iters {
            let start = Date.now
            let encoder = JSONEncoder()
            _blackHole(try encoder.encode(twitter))
            let end = Date.now
            let this_interval = end.timeIntervalSince(start)

            min_interval = min(min_interval ?? this_interval, this_interval)
        }

        print("Throughput: \(throughput(dur: min_interval!, bytes: reencodedData.count)) MB/s")
    }
    
        @Test func twitter_benchmark_json_encodable_new() async throws {
        let encoder = NewJSONEncoder()
        
        @_transparent
        func asJSON<D: JSONTopLevelEncoder & ~Copyable>(_ jsonEncoder: borrowing D) throws {
            let data = try! Data(contentsOf: Self.twitterURL)
            let decoder = JSONDecoder()
            let twitter = try decoder.decode(Twitter.self, from: data)
            
            let newEncoder = NewJSONEncoder()
            let reencodedData = try newEncoder.encode(twitter)
            
            let iters = 256
            var min_interval: TimeInterval?
            for _ in 0 ..< iters {
                let start = Date.now
                _blackHole(try jsonEncoder.encode(twitter))
                let end = Date.now
                let this_interval = end.timeIntervalSince(start)

                min_interval = min(min_interval ?? this_interval, this_interval)
            }

            print("Throughput: \(throughput(dur: min_interval!, bytes: reencodedData.count)) MB/s")
        }
        try asJSON(encoder)
    }
    
        @Test func twitter_benchmark_json_common_encodable_new() async throws {
        let encoder = NewJSONEncoder()
        
        @_transparent
        func asCommon<D: CommonTopLevelEncoder & ~Copyable>(_ commonEncoder: borrowing D) throws {
            let data = try! Data(contentsOf: Self.twitterURL)
            let twitter = try JSONDecoder().decode(Twitter.self, from: data)

            let newEncoder = NewJSONEncoder()
            let reencodedData = try newEncoder.encode(twitter)
            
            let iters = 256
            var min_interval: TimeInterval?
            for _ in 0 ..< iters {
                let start = Date.now
                _blackHole(try commonEncoder.encode(twitter))
                let end = Date.now
                let this_interval = end.timeIntervalSince(start)
                
                min_interval = min(min_interval ?? this_interval, this_interval)
            }
         
            print("Throughput: \(throughput(dur: min_interval!, bytes: reencodedData.count)) MB/s")
        }
        try asCommon(encoder)
    }
    
        @Test func canada_benchmark_json_decodable_old() async throws {
        let data = try! Data(contentsOf: Self.canadaURL)

        let iters = 256
        var min_interval: TimeInterval?
        for _ in 0 ..< iters {
            let start = Date.now
            let decoder = JSONDecoder()
            _blackHole(try decoder.decode(CoordinateFormat.self, from: data))
            let end = Date.now
            let this_interval = end.timeIntervalSince(start)

            min_interval = min(min_interval ?? this_interval, this_interval)
        }

        print("Throughput: \(throughput(dur: min_interval!, bytes: data.count)) MB/s")
    }

        @Test func canada_benchmark_json_decodable_new() async throws {
        let decoder = NewJSONDecoder()
        
        @_transparent
        func asJSON<D: JSONTopLevelDecoder & ~Copyable>(_ jsonDecoder: borrowing D) throws {
            let data = try! Data(contentsOf: Self.canadaURL)
            
            let iters = 256
            var min_interval: TimeInterval?
            for _ in 0 ..< iters {
                let start = Date.now
                _blackHole(try jsonDecoder.decode(CoordinateFormat.self, from: data))
                let end = Date.now
                let this_interval = end.timeIntervalSince(start)

                min_interval = min(min_interval ?? this_interval, this_interval)
            }

            print("Throughput: \(throughput(dur: min_interval!, bytes: data.count)) MB/s")
        }
        try asJSON(decoder)
    }
    
        @Test func canada_benchmark_json_common_decodable_new() async throws {
        let decoder = NewJSONDecoder()
        
        @_transparent
        func asCommon<D: CommonTopLevelDecoder & ~Copyable>(_ commonDecoder: borrowing D) throws {
            let data = try! Data(contentsOf: Self.canadaURL)
            
            let iters = 256
            var min_interval: TimeInterval?
            for _ in 0 ..< iters {
                let start = Date.now
                _blackHole(try commonDecoder.decode(CoordinateFormat.self, from: data))
                let end = Date.now
                let this_interval = end.timeIntervalSince(start)
                
                min_interval = min(min_interval ?? this_interval, this_interval)
            }
            
            print("Throughput: \(throughput(dur: min_interval!, bytes: data.count)) MB/s")
        }
        try asCommon(decoder)
    }
    
        @Test func canada_benchmark_json_encodable_old() async throws {
        let data = try! Data(contentsOf: Self.canadaURL)
        let decoder = JSONDecoder()
        let canada = try decoder.decode(CoordinateFormat.self, from: data)
        
        let reencodedData = try JSONEncoder().encode(canada)
        
        let iters = 256
        var min_interval: TimeInterval?
        for _ in 0 ..< iters {
            let start = Date.now
            let encoder = JSONEncoder()
            _blackHole(try encoder.encode(canada))
            let end = Date.now
            let this_interval = end.timeIntervalSince(start)

            min_interval = min(min_interval ?? this_interval, this_interval)
        }

        print("Throughput: \(throughput(dur: min_interval!, bytes: reencodedData.count)) MB/s")
    }
    
        @Test func canada_benchmark_json_encodable_new() async throws {
        let encoder = NewJSONEncoder()
        
        @_transparent
        func asJSON<D: JSONTopLevelEncoder & ~Copyable>(_ jsonEncoder: borrowing D) throws {
            
            let data = try! Data(contentsOf: Self.canadaURL)
            let decoder = JSONDecoder()
            let canada = try decoder.decode(CoordinateFormat.self, from: data)
            
            let newEncoder = NewJSONEncoder()
            let reencodedData = try newEncoder.encode(canada)
            
            let iters = 256
            var min_interval: TimeInterval?
            for _ in 0 ..< iters {
                let start = Date.now

                _blackHole(try jsonEncoder.encode(canada))
                let end = Date.now
                let this_interval = end.timeIntervalSince(start)
                
                min_interval = min(min_interval ?? this_interval, this_interval)
            }
            
            print("Throughput: \(throughput(dur: min_interval!, bytes: reencodedData.count)) MB/s")
        }
        try asJSON(encoder)
    }
    
        @Test func canada_benchmark_json_common_encodable_new() async throws {
        let encoder = NewJSONEncoder()
        
        @_transparent
        func asCommon<D: CommonTopLevelEncoder & ~Copyable>(_ commonEncoder: borrowing D) throws {
            let data = try! Data(contentsOf: Self.canadaURL)
            let canada = try JSONDecoder().decode(CoordinateFormat.self, from: data)

            let newEncoder = NewJSONEncoder()
            let reencodedData = try newEncoder.encode(canada)
            
            let iters = 256
            var min_interval: TimeInterval?
            for _ in 0 ..< iters {
                let start = Date.now
                _blackHole(try commonEncoder.encode(canada))
                let end = Date.now
                let this_interval = end.timeIntervalSince(start)
                
                min_interval = min(min_interval ?? this_interval, this_interval)
            }
         
            print("Throughput: \(throughput(dur: min_interval!, bytes: reencodedData.count)) MB/s")
        }
        try asCommon(encoder)
    }

        @Test func catalog_benchmark_json_decodable_old() async throws {
        let data = try! Data(contentsOf: Self.catalogURL)

        let iters = 256
        var min_interval: TimeInterval?
        for _ in 0 ..< iters {
            let start = Date.now
            let decoder = JSONDecoder()
            _blackHole(try decoder.decode(Catalog.self, from: data))
            let end = Date.now
            let this_interval = end.timeIntervalSince(start)

            min_interval = min(min_interval ?? this_interval, this_interval)
        }

        print("Throughput: \(throughput(dur: min_interval!, bytes: data.count)) MB/s")
    }

        @Test func catalog_benchmark_json_decodable_new() async throws {
        let decoder = NewJSONDecoder()
        
        @_transparent
        func asJSON<D: JSONTopLevelDecoder & ~Copyable>(_ jsonDecoder: borrowing D) throws {
            let data = try! Data(contentsOf: Self.catalogURL)
            
            let iters = 256
            var min_interval: TimeInterval?
            for _ in 0 ..< iters {
                let start = Date.now
                _blackHole(try jsonDecoder.decode(Catalog.self, from: data))
                let end = Date.now
                let this_interval = end.timeIntervalSince(start)

                min_interval = min(min_interval ?? this_interval, this_interval)
            }

            print("Throughput: \(throughput(dur: min_interval!, bytes: data.count)) MB/s")
        }
        try asJSON(decoder)
    }
    
        @Test func catalog_benchmark_json_common_decodable_new() async throws {
        let decoder = NewJSONDecoder()
        
        @_transparent
        func asCommon<D: CommonTopLevelDecoder & ~Copyable>(_ commonDecoder: borrowing D) throws {
            let data = try! Data(contentsOf: Self.catalogURL)
            
            let iters = 256
            var min_interval: TimeInterval?
            for _ in 0 ..< iters {
                let start = Date.now
                _blackHole(try commonDecoder.decode(Catalog.self, from: data))
                let end = Date.now
                let this_interval = end.timeIntervalSince(start)
                
                min_interval = min(min_interval ?? this_interval, this_interval)
            }
            
            print("Throughput: \(throughput(dur: min_interval!, bytes: data.count)) MB/s")
        }
        try asCommon(decoder)
    }
    
        @Test func catalog_benchmark_json_encodable_old() async throws {
        let data = try! Data(contentsOf: Self.catalogURL)
        let decoder = JSONDecoder()
        let catalog = try decoder.decode(Catalog.self, from: data)
        
        let reencodedData = try JSONEncoder().encode(catalog)
        
        let iters = 256
        var min_interval: TimeInterval?
        for _ in 0 ..< iters {
            let start = Date.now
            let encoder = JSONEncoder()
            _blackHole(try encoder.encode(catalog))
            let end = Date.now
            let this_interval = end.timeIntervalSince(start)

            min_interval = min(min_interval ?? this_interval, this_interval)
        }

        print("Throughput: \(throughput(dur: min_interval!, bytes: reencodedData.count)) MB/s")
    }
    
        @Test func catalog_benchmark_json_encodable_new() async throws {
        let encoder = NewJSONEncoder()
        
        @_transparent
        func asJSON<D: JSONTopLevelEncoder & ~Copyable>(_ jsonEncoder: borrowing D) throws {
            
            let data = try! Data(contentsOf: Self.catalogURL)
            let decoder = JSONDecoder()
            let catalog = try decoder.decode(Catalog.self, from: data)
            
            let newEncoder = NewJSONEncoder()
            let reencodedData = try newEncoder.encode(catalog)
            
            let iters = 256
            var min_interval: TimeInterval?
            for _ in 0 ..< iters {
                let start = Date.now
                _blackHole(try jsonEncoder.encode(catalog))
                let end = Date.now
                let this_interval = end.timeIntervalSince(start)
                
                min_interval = min(min_interval ?? this_interval, this_interval)
            }
            
            print("Throughput: \(throughput(dur: min_interval!, bytes: reencodedData.count)) MB/s")
        }
        try asJSON(encoder)
    }
    
        @Test func catalog_benchmark_json_common_encodable_new() async throws {
        let encoder = NewJSONEncoder()
        
        @_transparent
        func asCommon<D: CommonTopLevelEncoder & ~Copyable>(_ commonEncoder: borrowing D) throws {
            let data = try! Data(contentsOf: Self.catalogURL)
            let catalog = try JSONDecoder().decode(Catalog.self, from: data)

            let newEncoder = NewJSONEncoder()
            let reencodedData = try newEncoder.encode(catalog)
            
            let iters = 256
            var min_interval: TimeInterval?
            for _ in 0 ..< iters {
                let start = Date.now
                _blackHole(try commonEncoder.encode(catalog))
                let end = Date.now
                let this_interval = end.timeIntervalSince(start)
                
                min_interval = min(min_interval ?? this_interval, this_interval)
            }
         
            print("Throughput: \(throughput(dur: min_interval!, bytes: reencodedData.count)) MB/s")
        }
        try asCommon(encoder)
    }
    
        @Test func matrix_benchmark() async throws {
        let data = Data("""
    [
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,
    0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,
    0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,
    0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    ]
    """.utf8)

        do {
            let decoder = JSONDecoder()
            let start = Date.now
            for _ in 0..<1000 {
                _blackHole(try decoder.decode([UInt8].self, from: data))
            }
            let end = Date.now

            print("(Old) Throughput: \(throughput(dur: (end.timeIntervalSince(start))/1000, bytes: data.count)) MB/s")
        }
                
        do {
            let decoder = NewJSONDecoder()
            let start = Date.now
            for _ in 0..<1000 {
                _blackHole(try decoder.decode([UInt8].self, from: data))
            }
            let end = Date.now

            print("(New - Array) Throughput: \(throughput(dur: (end.timeIntervalSince(start))/1000, bytes: data.count)) MB/s")
        }
                
        do {
            struct ArrayDecoder: JSONDecodable {
                let array: [UInt8]
                
                static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                    var res = [UInt8]()
                    try decoder.decodeArray { seqDecoder throws(CodingError.Decoding) in
                        try seqDecoder.decodeEachElement { elementDecoder throws(CodingError.Decoding) in
                            res.append(try elementDecoder.decode(UInt8.self))
                        }
                    }
                    return .init(array: res)
                }
            }
            
            let decoder = NewJSONDecoder()
            let start = Date.now
            for _ in 0..<1000 {
                _blackHole(try decoder.decode(ArrayDecoder.self, from: data))
            }
            let end = Date.now

            print("(New - Sequence/Each) Throughput: \(throughput(dur: (end.timeIntervalSince(start))/1000, bytes: data.count)) MB/s")
        }
        
        do {
            struct ArrayDecoder: JSONDecodable & ~Copyable {
                let array: UniqueArray<UInt8>
                
                static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                    var res = UniqueArray<UInt8>()
                    try decoder.decodeArray { seqDecoder throws(CodingError.Decoding) in
                        try seqDecoder.decodeEachElement { elementDecoder throws(CodingError.Decoding)in
                            res.append(try elementDecoder.decode(UInt8.self))
                        }
                    }
                    return .init(array: res)
                }
            }
            
            let decoder = NewJSONDecoder()
            let start = Date.now
            for _ in 0..<1000 {
                _blackHole(try decoder.decode(ArrayDecoder.self, from: data))
            }
            let end = Date.now

            print("(New - Sequence/Each/Unique) Throughput: \(throughput(dur: (end.timeIntervalSince(start))/1000, bytes: data.count)) MB/s")
        }
        
        do {
            struct ArrayDecoder: JSONDecodable & ~Copyable {
                let array: InlineArray<1024, UInt8>
                
                static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                    let res = try decoder.decode(InlineArray<1024, UInt8>.self)
                    return .init(array: res)
                }
            }
            
            let decoder = NewJSONDecoder()
            let start = Date.now
            for _ in 0..<1000 {
                _blackHole(try decoder.decode(ArrayDecoder.self, from: data))
            }
            let end = Date.now

            print("(New - Sequence/Inline) Throughput: \(throughput(dur: (end.timeIntervalSince(start))/1000, bytes: data.count)) MB/s")
        }
        
        do {
            struct ArrayDecoder: JSONDecodable & ~Copyable {
                let array: InlineArray<1024, UInt8>
                
                static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                    let res = try InlineArray<1024, UInt8> { span throws(CodingError.Decoding) in
                        try decoder.decodeArray { seqDecoder throws(CodingError.Decoding) in
                            try seqDecoder.decodeEachElement { elementDecoder throws(CodingError.Decoding) in
                                span.append(try elementDecoder.decode(UInt8.self))
                            }
                        }
                    }
                    return .init(array: res)
                }
            }
            
            let decoder = NewJSONDecoder()
            let start = Date.now
            for _ in 0..<1000 {
                _blackHole(try decoder.decode(ArrayDecoder.self, from: data))
            }
            let end = Date.now

            print("(New - Sequence/Each/Inline) Throughput: \(throughput(dur: (end.timeIntervalSince(start))/1000, bytes: data.count)) MB/s")
        }

    }
}
