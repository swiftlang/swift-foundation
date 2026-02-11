//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
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

#if canImport(TestSupport)
import TestSupport
#endif

@Suite("UUID")
private struct UUIDTests {
    @Test func equality() {
        let uuidA = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        let uuidB = UUID(uuidString: "e621e1f8-c36c-495a-93fc-0c247a3e6e5f")
        let uuidC = UUID(uuid: (0xe6,0x21,0xe1,0xf8,0xc3,0x6c,0x49,0x5a,0x93,0xfc,0x0c,0x24,0x7a,0x3e,0x6e,0x5f))
        let uuidD = UUID()

        #expect(uuidA == uuidB, "String case must not matter.")
        #expect(uuidA == uuidC, "A UUID initialized with a string must be equal to the same UUID initialized with its UnsafePointer<UInt8> equivalent representation.")
        #expect(uuidC != uuidD, "Two different UUIDs must not be equal.")
    }

    @Test func invalidString() {
        let invalid = UUID(uuidString: "Invalid UUID")
        #expect(invalid == nil, "The convenience initializer `init?(uuidString string:)` must return nil for an invalid UUID string.")
    }

    // `uuidString` should return an uppercase string
    // See: https://bugs.swift.org/browse/SR-865
    @Test func uuidString() {
        let uuid = UUID(uuid: (0xe6,0x21,0xe1,0xf8,0xc3,0x6c,0x49,0x5a,0x93,0xfc,0x0c,0x24,0x7a,0x3e,0x6e,0x5f))
        #expect(uuid.uuidString == "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "The uuidString representation must be uppercase.")
    }

    @Test func description() {
        let uuid = UUID()
        let description: String = uuid.description
        let uuidString: String = uuid.uuidString
        #expect(description == uuidString, "The description must be the same as the uuidString.")
    }

    @Test func hash() {
        let values: [UUID] = [
            // This list takes a UUID and tweaks every byte while
            // leaving the version/variant intact.
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a63baa1c-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53caa1c-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53bab1c-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1d-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b5f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f6-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-49db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48dc-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9567-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9468-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9886b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9787b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b86b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b76c256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b76b266c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b76b256d")!,
        ]
        checkHashable(values, equalityOracle: { $0 == $1 })
    }

    @Test func anyHashableContainingUUID() {
        let values: [UUID] = [
            UUID(uuidString: "e621e1f8-c36c-495a-93fc-0c247a3e6e5f")!,
            UUID(uuidString: "f81d4fae-7dec-11d0-a765-00a0c91e6bf6")!,
            UUID(uuidString: "f81d4fae-7dec-11d0-a765-00a0c91e6bf6")!,
        ]
        let anyHashables = values.map(AnyHashable.init)
        #expect(UUID.self == type(of: anyHashables[0].base))
        #expect(UUID.self == type(of: anyHashables[1].base))
        #expect(UUID.self == type(of: anyHashables[2].base))
        #expect(anyHashables[0] != anyHashables[1])
        #expect(anyHashables[1] == anyHashables[2])
    }

    // rdar://71190003 (UUID has no customMirror)
    @Test func customMirror() throws {
        let uuid = try #require(UUID(uuidString: "89E90DC6-5EBA-41A8-A64D-81D3576EE46E"))
        #expect(String(reflecting: uuid) == "89E90DC6-5EBA-41A8-A64D-81D3576EE46E")
    }

    @Test func comparable() throws {
        var uuid1 = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        var uuid2 = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        #expect(uuid1 < uuid2)
        #expect(uuid2 >= uuid1)
        #expect(uuid2 != uuid1)
        
        uuid1 = try #require(UUID(uuidString: "9707CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        uuid2 = try #require(UUID(uuidString: "9807CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        #expect(uuid1 < uuid2)
        #expect(uuid2 >= uuid1)
        #expect(uuid2 != uuid1)
        
        uuid1 = try #require(UUID(uuidString: "9707CE8D-261F-4858-8BF9-C9EC3D690FCE"))
        uuid2 = try #require(UUID(uuidString: "9707CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        #expect(uuid1 > uuid2)
        #expect(uuid2 <= uuid1)
        #expect(uuid2 != uuid1)
        
        uuid1 = try #require(UUID(uuidString: "9707CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        uuid2 = try #require(UUID(uuidString: "9707CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        #expect(uuid1 <= uuid2)
        #expect(uuid2 <= uuid1)
        #expect(uuid2 == uuid1)
    }
    
    @Test func randomVersionAndVariant() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<10000 {
            let uuid = UUID.random(using: &generator)
            #expect(uuid.versionNumber == 0b0100)
            #expect(uuid.varint == 0b10)
        }
    }
    


    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test func regexComponentParsesUUID() throws {
        let input = "prefix E621E1F8-C36C-495A-93FC-0C247A3E6E5F suffix"
        let match = try #require(input.firstMatch(of: /prefix \(.uuid) suffix/))
        #expect(match.1 == UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"))
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test func regexComponentRejectsInvalidUUID() throws {
        let input = "prefix E621E1F8-C36C-495A-93FC-0C247A3E6E5Z suffix"
        let match = try input.firstMatch(of: /prefix \(.uuid) suffix/)
        #expect(match == nil)
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test func regexComponentCanBeUsedDirectly() throws {
        let input = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
        let match = try #require(input.wholeMatch(of: UUID.RegexComponent()))
        #expect(match.output == UUID(uuidString: input))
    }
    @Test func deterministicRandomGeneration() {
        var generator = PCGRandomNumberGenerator(seed: 123456789)
        
        let firstUUID = UUID.random(using: &generator)
        #expect(firstUUID ==  UUID(uuidString: "9492BAC4-F353-49E7-ACBB-A40941CA65DE"))
        
        let secondUUID = UUID.random(using: &generator)
        #expect(secondUUID == UUID(uuidString: "392C44E5-EB3E-4455-85A7-AF9556722B9A"))
        
        let thirdUUID = UUID.random(using: &generator)
        #expect(thirdUUID ==  UUID(uuidString: "9ABFCCE9-AA85-485C-9CBF-C62F0C8D1D1A"))
        
        let fourthUUID = UUID.random(using: &generator)
        #expect(fourthUUID == UUID(uuidString: "2B29542E-F719-4D58-87B9-C6291ADD4541"))
    }
}

extension UUID {
    fileprivate var versionNumber: Int {
        Int(self.uuid.6 >> 4)
    }
    
    fileprivate var varint: Int {
        Int(self.uuid.8 >> 6 & 0b11)
    }
}

fileprivate struct PCGRandomNumberGenerator: RandomNumberGenerator {
    private static let multiplier: UInt128 = 47_026_247_687_942_121_848_144_207_491_837_523_525
    private static let increment: UInt128 = 117_397_592_171_526_113_268_558_934_119_004_209_487

    private var state: UInt128

    fileprivate init(seed: UInt64) {
        self.state = UInt128(seed)
    }

    fileprivate mutating func next() -> UInt64 {
        self.state = self.state &* Self.multiplier &+ Self.increment

        return rotr64(
            value: UInt64(truncatingIfNeeded: self.state &>> 64) ^ UInt64(truncatingIfNeeded: self.state),
            rotation: UInt64(truncatingIfNeeded: self.state &>> 122)
        )
    }

    private func rotr64(value: UInt64, rotation: UInt64) -> UInt64 {
        (value &>> rotation) | value &<< ((~rotation &+ 1) & 63)
    }
}

