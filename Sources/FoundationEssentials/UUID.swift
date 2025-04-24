//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

internal import _FoundationCShims // uuid.h

public typealias uuid_t = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
public typealias uuid_string_t = (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)

/// Represents UUID strings, which can be used to uniquely identify types, interfaces, and other items.
@available(macOS 10.8, iOS 6.0, tvOS 9.0, watchOS 2.0, *)
public struct UUID : Hashable, Equatable, CustomStringConvertible, Sendable {
    public private(set) var uuid: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

    /* Create a new UUID with RFC 4122 version 4 random bytes */
    public init() {
        withUnsafeMutablePointer(to: &uuid) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<uuid_t>.size) {
                _foundation_uuid_generate_random($0)
            }
        }
    }

    @inline(__always)
    internal func withUUIDBytes<R>(_ work: (UnsafeBufferPointer<UInt8>) throws -> R) rethrows -> R {
        return try withExtendedLifetime(self) {
            try withUnsafeBytes(of: uuid) { rawBuffer in
                return try rawBuffer.withMemoryRebound(to: UInt8.self) { buffer in
                    return try work(buffer)
                }
            }
        }
    }

    /// Create a UUID from a string such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F".
    ///
    /// Returns nil for invalid strings.
    public init?(uuidString string: __shared String) {
        let res = withUnsafeMutablePointer(to: &uuid) {
            $0.withMemoryRebound(to: UInt8.self, capacity: 16) {
                return _foundation_uuid_parse(string, $0)
            }
        }
        if res != 0 {
            return nil
        }
    }

    /// Create a UUID from a `uuid_t`.
    public init(uuid: uuid_t) {
        self.uuid = uuid
    }

    /// Returns a string created from the UUID, such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    public var uuidString: String {
        var bytes: uuid_string_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        return withUUIDBytes { valBuffer in
            withUnsafeMutablePointer(to: &bytes) { strPtr in
                strPtr.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<uuid_string_t>.size) { str in
                    _foundation_uuid_unparse_upper(valBuffer.baseAddress!, str)
                    return String(cString: str)
                }
            }
        }
    }

    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: uuid) { buffer in
            hasher.combine(bytes: buffer)
        }
    }
    
    /// Generates a new random UUID.
    ///
    /// - Parameter generator: The random number generator to use when creating the new random value.
    /// - Returns: A random UUID.
    @available(FoundationPreview 6.2, *)
    public static func random(
        using generator: inout some RandomNumberGenerator
    ) -> UUID {
        let first = UInt64.random(in: .min ... .max, using: &generator)
        let second = UInt64.random(in: .min ... .max, using: &generator)

        var firstBits = first
        var secondBits = second

        // Set the version to 4 (0100 in binary)
        firstBits &= 0xFFFFFFFFFFFF0FFF // Clear the last 12 bits
        firstBits |= 0x0000000000004000 // Set the version bits to '0100' at the correct position
        
        // Set the variant to '10' (RFC9562 variant)
        secondBits &= 0x3FFFFFFFFFFFFFFF // Clear the 2 most significant bits
        secondBits |= 0x8000000000000000 // Set the two MSB to '10'

        let uuidBytes = (
            UInt8(truncatingIfNeeded: firstBits >> 56),
            UInt8(truncatingIfNeeded: firstBits >> 48),
            UInt8(truncatingIfNeeded: firstBits >> 40),
            UInt8(truncatingIfNeeded: firstBits >> 32),
            UInt8(truncatingIfNeeded: firstBits >> 24),
            UInt8(truncatingIfNeeded: firstBits >> 16),
            UInt8(truncatingIfNeeded: firstBits >> 8),
            UInt8(truncatingIfNeeded: firstBits),
            UInt8(truncatingIfNeeded: secondBits >> 56),
            UInt8(truncatingIfNeeded: secondBits >> 48),
            UInt8(truncatingIfNeeded: secondBits >> 40),
            UInt8(truncatingIfNeeded: secondBits >> 32),
            UInt8(truncatingIfNeeded: secondBits >> 24),
            UInt8(truncatingIfNeeded: secondBits >> 16),
            UInt8(truncatingIfNeeded: secondBits >> 8),
            UInt8(truncatingIfNeeded: secondBits)
        )

        return UUID(uuid: uuidBytes)
    }

    public var description: String {
        return uuidString
    }

    public var debugDescription: String {
        return description
    }

    public static func ==(lhs: UUID, rhs: UUID) -> Bool {
        withUnsafeBytes(of: lhs) { lhsPtr in
            withUnsafeBytes(of: rhs) { rhsPtr in
                let lhsTuple = lhsPtr.loadUnaligned(as: (UInt64, UInt64).self)
                let rhsTuple = rhsPtr.loadUnaligned(as: (UInt64, UInt64).self)
                return (lhsTuple.0 ^ rhsTuple.0) | (lhsTuple.1 ^ rhsTuple.1) == 0
            }
        }
    }
}

@available(macOS 10.8, iOS 6.0, tvOS 9.0, watchOS 2.0, *)
extension UUID : CustomReflectable {
    public var customMirror: Mirror {
        let c : [(label: String?, value: Any)] = []
        let m = Mirror(self, children:c, displayStyle: .struct)
        return m
    }
}

@available(macOS 10.8, iOS 6.0, tvOS 9.0, watchOS 2.0, *)
extension UUID : Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uuidString = try container.decode(String.self)

        guard let uuid = UUID(uuidString: uuidString) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath,
                                                                    debugDescription: "Attempted to decode UUID from invalid UUID string."))
        }

        self = uuid
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.uuidString)
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension UUID : Comparable {
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    public static func < (lhs: UUID, rhs: UUID) -> Bool {
        var leftUUID = lhs.uuid
        var rightUUID = rhs.uuid
        var result: Int = 0
        var diff: Int = 0
        withUnsafeBytes(of: &leftUUID) { leftPtr in
            withUnsafeBytes(of: &rightUUID) { rightPtr in
                for offset in (0 ..< MemoryLayout<uuid_t>.size).reversed() {
                    diff = Int(leftPtr.load(fromByteOffset: offset, as: UInt8.self)) -
                        Int(rightPtr.load(fromByteOffset: offset, as: UInt8.self))
                    // Constant time, no branching equivalent of
                    // if (diff != 0) {
                    //     result = diff;
                    // }
                    result = (result & (((diff - 1) & ~diff) >> 8)) | diff
                }
            }
        }

        return result < 0
    }
}
