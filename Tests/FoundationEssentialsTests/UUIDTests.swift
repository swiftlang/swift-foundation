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

    @available(FoundationPreview 6.4, *)
    @Test func lowercasedUUIDString() {
        let uuid = UUID(uuid: (0xe6,0x21,0xe1,0xf8,0xc3,0x6c,0x49,0x5a,0x93,0xfc,0x0c,0x24,0x7a,0x3e,0x6e,0x5f))
        #expect(uuid.lowercasedUUIDString == "e621e1f8-c36c-495a-93fc-0c247a3e6e5f")
    }

    @available(FoundationPreview 6.4, *)
    @Test func lowercasedUUIDStringMatchesUpperCaseContent() {
        let uuid = UUID()
        #expect(uuid.lowercasedUUIDString == uuid.uuidString.lowercased())
    }

    @available(FoundationPreview 6.4, *)
    @Test func lowercasedUUIDStringNilAndMax() {
        #expect(UUID.nil.lowercasedUUIDString == "00000000-0000-0000-0000-000000000000")
        #expect(UUID.max.lowercasedUUIDString == "ffffffff-ffff-ffff-ffff-ffffffffffff")
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

    @available(FoundationPreview 6.3, *)
    @Test func randomVersionAndVariant() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<10000 {
            let uuid = UUID.random(using: &generator)
            #expect(uuid.versionNumber == 0b0100)
            #expect(uuid.varint == 0b10)
        }
    }

    @available(FoundationPreview 6.4, *)
    @Test func nilUUID() {
        let nilUUID = UUID.nil
        #expect(nilUUID.uuidString == "00000000-0000-0000-0000-000000000000")
        let s = nilUUID.span
        for i in 0..<16 {
            #expect(s[i] == 0)
        }
    }

    @available(FoundationPreview 6.4, *)
    @Test func maxUUID() {
        let maxUUID = UUID.max
        #expect(maxUUID.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
        let s = maxUUID.span
        for i in 0..<16 {
            #expect(s[i] == 0xFF)
        }
    }

    @available(FoundationPreview 6.4, *)
    @Test func nilAndMaxOrdering() {
        let nilUUID = UUID.nil
        let maxUUID = UUID.max
        let randomUUID = UUID()
        #expect(nilUUID < randomUUID)
        #expect(randomUUID < maxUUID)
        #expect(nilUUID < maxUUID)
    }

    @available(FoundationPreview 6.4, *)
    @Test func spanProperty() {
        let uuid = UUID(uuid: (0xe6, 0x21, 0xe1, 0xf8, 0xc3, 0x6c, 0x49, 0x5a, 0x93, 0xfc, 0x0c, 0x24, 0x7a, 0x3e, 0x6e, 0x5f))
        let s = uuid.span
        #expect(s.count == 16)
        #expect(s[0] == 0xe6)
        #expect(s[1] == 0x21)
        #expect(s[6] == 0x49)
        #expect(s[15] == 0x5f)
    }

    @available(FoundationPreview 6.4, *)
    @Test func spanMatchesUUIDBytes() {
        let uuid = UUID()
        let s = uuid.span
        let t = uuid.uuid
        #expect(s[0] == t.0)
        #expect(s[1] == t.1)
        #expect(s[6] == t.6)
        #expect(s[8] == t.8)
        #expect(s[15] == t.15)
    }

    @available(FoundationPreview 6.4, *)
    @Test func mutableSpan() {
        var uuid = UUID.nil
        var span = uuid.mutableSpan
        span[0] = 0xAB
        span[15] = 0xCD
        #expect(uuid.span[0] == 0xAB)
        #expect(uuid.span[15] == 0xCD)
        // Other bytes remain zero
        for i in 1..<15 {
            #expect(uuid.span[i] == 0)
        }
    }

    @available(FoundationPreview 6.4, *)
    @Test func mutableSpanModifiesUUID() {
        var uuid = UUID(uuid: (0xe6, 0x21, 0xe1, 0xf8, 0xc3, 0x6c, 0x49, 0x5a, 0x93, 0xfc, 0x0c, 0x24, 0x7a, 0x3e, 0x6e, 0x5f))
        // Overwrite version nibble to v7
        let previousValue = uuid.span[6]
        var span = uuid.mutableSpan
        span[6] = (previousValue & 0x0F) | 0x70
        #expect(uuid.version == .timeOrdered)
    }

    @available(FoundationPreview 6.4, *)
    @Test func initializingWithOutputSpan() {
        let uuid = UUID { (output: inout OutputSpan<UInt8>) in
            for i: UInt8 in 0..<16 {
                output.append(i)
            }
        }
        let s = uuid.span
        for i: UInt8 in 0..<16 {
            #expect(s[Int(i)] == i)
        }
    }

    @available(FoundationPreview 6.4, *)
    @Test func initializingWithOutputSpanMatchesUUIDInit() {
        let expected = UUID(uuid: (0xe6, 0x21, 0xe1, 0xf8, 0xc3, 0x6c, 0x49, 0x5a, 0x93, 0xfc, 0x0c, 0x24, 0x7a, 0x3e, 0x6e, 0x5f))
        let bytes: [UInt8] = [0xe6, 0x21, 0xe1, 0xf8, 0xc3, 0x6c, 0x49, 0x5a, 0x93, 0xfc, 0x0c, 0x24, 0x7a, 0x3e, 0x6e, 0x5f]
        let uuid = UUID { (output: inout OutputSpan<UInt8>) in
            for b in bytes {
                output.append(b)
            }
        }
        #expect(uuid == expected)
    }

    @available(FoundationPreview 6.4, *)
    @Test func initFromSpan() {
        let bytes: [UInt8] = [0xe6, 0x21, 0xe1, 0xf8, 0xc3, 0x6c, 0x49, 0x5a, 0x93, 0xfc, 0x0c, 0x24, 0x7a, 0x3e, 0x6e, 0x5f]
        let span = bytes.span
        let uuid = UUID(copying: span)
        let expected = UUID(uuid: (0xe6, 0x21, 0xe1, 0xf8, 0xc3, 0x6c, 0x49, 0x5a, 0x93, 0xfc, 0x0c, 0x24, 0x7a, 0x3e, 0x6e, 0x5f))
        #expect(uuid == expected)
    }

    @available(FoundationPreview 6.4, *)
    @Test func versionProperty() {
        // UUID() creates v4
        let v4 = UUID()
        #expect(v4.version == .random)

        // RFC 9562 Appendix A test vectors
        // A.1: UUIDv1
        let v1 = UUID(uuidString: "C232AB00-9414-11EC-B3C8-9F6BDECED846")!
        #expect(v1.version == .timeBased)

        // A.2: UUIDv3
        let v3 = UUID(uuidString: "5df41881-3aed-3515-88a7-2f4a814cf09e")!
        #expect(v3.version == .nameBasedMD5)

        // A.3: UUIDv4
        let v4rfc = UUID(uuidString: "919108f7-52d1-4320-9bac-f847db4148a8")!
        #expect(v4rfc.version == .random)

        // A.4: UUIDv5
        let v5 = UUID(uuidString: "2ed6657d-e927-568b-95e1-2665a8aea6a2")!
        #expect(v5.version == .nameBasedSHA1)

        // A.5: UUIDv6
        let v6 = UUID(uuidString: "1EC9414C-232A-6B00-B3C8-9F6BDECED846")!
        #expect(v6.version == .reorderedTimeBased)

        // A.6: UUIDv7
        let v7 = UUID(uuidString: "017F22E2-79B0-7CC3-98C4-DC0C0C07398F")!
        #expect(v7.version == .timeOrdered)

        // B.1: UUIDv8
        let v8 = UUID(uuidString: "2489E9AD-2EE2-8E00-8EC9-32D5F69181C0")!
        #expect(v8.version == .custom)
    }

    @available(FoundationPreview 6.4, *)
    @Test func timeOrderedVersionAndVariant() {
        for _ in 0..<10000 {
            let uuid = UUID.timeOrdered()
            #expect(uuid.versionNumber == 0b0111)
            #expect(uuid.varint == 0b10)
        }
    }

    @available(FoundationPreview 6.4, *)
    @Test func timeOrderedUsingGeneratorVersionAndVariant() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<10000 {
            let uuid = UUID.timeOrdered(using: &generator)
            #expect(uuid.versionNumber == 0b0111)
            #expect(uuid.varint == 0b10)
        }
    }

    @available(FoundationPreview 6.4, *)
    @Test func timeOrderedUsingGeneratorTimestamp() throws {
        var generator = SystemRandomNumberGenerator()
        let before = Date()
        let uuid = UUID.timeOrdered(using: &generator)
        let after = Date()

        let timestamp = try #require(uuid.timeOrderedTimestamp)
        #expect(timestamp >= before.addingTimeInterval(-0.1))
        #expect(timestamp <= after.addingTimeInterval(0.1))
    }

    @available(FoundationPreview 6.4, *)
    @Test func timeOrderedUsingDeterministicGenerator() {
        let fixedDate = Date(timeIntervalSince1970: 1645557742.0) // RFC 9562 A.6 timestamp
        var gen1 = PCGRandomNumberGenerator(seed: 42)
        var gen2 = PCGRandomNumberGenerator(seed: 42)
        let uuid1 = UUID.timeOrdered(using: &gen1, at: fixedDate)
        let uuid2 = UUID.timeOrdered(using: &gen2, at: fixedDate)
        // Same seed and same date produces identical UUIDs
        #expect(uuid1 == uuid2)
        // Verify the timestamp round-trips
        #expect(uuid1.timeOrderedTimestamp == fixedDate)
    }

    @available(FoundationPreview 6.4, *)
    @Test func timeOrderedDifferentSeedsSameDate() {
        let fixedDate = Date(timeIntervalSince1970: 1645557742.0)
        var gen1 = PCGRandomNumberGenerator(seed: 42)
        var gen2 = PCGRandomNumberGenerator(seed: 99)
        let uuid1 = UUID.timeOrdered(using: &gen1, at: fixedDate)
        let uuid2 = UUID.timeOrdered(using: &gen2, at: fixedDate)
        // Same date but different seeds produces different UUIDs
        #expect(uuid1 != uuid2)
        // Both should still have the same timestamp
        #expect(uuid1.timeOrderedTimestamp == uuid2.timeOrderedTimestamp)
    }

    @available(FoundationPreview 6.4, *)
    @Test func timeOrderedAtSpecificDate() throws {
        let date = Date(timeIntervalSince1970: 1000.0)
        var generator = SystemRandomNumberGenerator()
        let uuid = UUID.timeOrdered(using: &generator, at: date)
        let timestamp = try #require(uuid.timeOrderedTimestamp)
        #expect(timestamp == date)
        #expect(uuid.version == .timeOrdered)
    }

    @available(FoundationPreview 6.4, *)
    @Test func timeOrderedMonotonicity() async throws {
        var previous = UUID.timeOrdered()
        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(2))
            let current = UUID.timeOrdered()
            #expect(previous < current)
            previous = current
        }
    }

    @available(FoundationPreview 6.4, *)
    @Test func timeOrderedTimestamp() throws {
        let before = Date()
        let uuid = UUID.timeOrdered()
        let after = Date()

        let timestamp = try #require(uuid.timeOrderedTimestamp)
        #expect(timestamp >= before.addingTimeInterval(-0.1))
        #expect(timestamp <= after.addingTimeInterval(0.1))
    }

    // RFC 9562 Appendix A.6: UUIDv7 test vector with known timestamp
    // Tuesday, February 22, 2022 2:22:22.00 PM GMT-05:00 = 1645557742000 ms
    @available(FoundationPreview 6.4, *)
    @Test func timeOrderedTimestampRFCVector() throws {
        let v7 = UUID(uuidString: "017F22E2-79B0-7CC3-98C4-DC0C0C07398F")!
        let timestamp = try #require(v7.timeOrderedTimestamp)
        let expected = Date(timeIntervalSince1970: 1645557742.0)
        #expect(timestamp == expected)
    }

    @available(FoundationPreview 6.4, *)
    @Test func timeOrderedTimestampNilForV4() {
        let uuid = UUID()
        #expect(uuid.timeOrderedTimestamp == nil)
    }

    @available(FoundationPreview 6.4, *)
    @Test func versionRawValue() {
        #expect(UUID.Version(rawValue: 1) == .timeBased)
        #expect(UUID.Version(rawValue: 3) == .nameBasedMD5)
        #expect(UUID.Version(rawValue: 4) == .random)
        #expect(UUID.Version(rawValue: 5) == .nameBasedSHA1)
        #expect(UUID.Version(rawValue: 6) == .reorderedTimeBased)
        #expect(UUID.Version(rawValue: 7) == .timeOrdered)
        #expect(UUID.Version(rawValue: 8) == .custom)
    }

    @available(FoundationPreview 6.4, *)
    @Test func versionForArbitraryBytes() {
        for v: UInt8 in 0..<16 {
            // Construct a UUID with the version nibble set to `v`
            let byte6 = v << 4
            let uuid = UUID(uuid: (0, 0, 0, 0, 0, 0, byte6, 0, 0x80, 0, 0, 0, 0, 0, 0, 0))
            #expect(uuid.version.rawValue == v)
        }
    }

    @available(FoundationPreview 6.3, *)
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

