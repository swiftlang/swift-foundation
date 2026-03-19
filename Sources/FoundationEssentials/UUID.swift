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

public typealias uuid_t = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
public typealias uuid_string_t = (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)

/// Represents UUID strings, which can be used to uniquely identify types, interfaces, and other items.
@available(macOS 10.8, iOS 6.0, tvOS 9.0, watchOS 2.0, *)
public struct UUID : Hashable, Equatable, CustomStringConvertible, Sendable {
    internal var _storage = InlineArray<16, UInt8>(repeating: 0)

    /// The UUID bytes as a `uuid_t` tuple.
    public var uuid: uuid_t {
        get {
            return unsafeBitCast(_storage, to: uuid_t.self)
        }
        set {
            _storage = unsafeBitCast(newValue, to: InlineArray<16, UInt8>.self)
        }
    }

    /* Create a new UUID with RFC 4122 version 4 random bytes */
    public init() {
        var generator = SystemRandomNumberGenerator()
        self = UUID.random(using: &generator)
    }

    /// Create a UUID from a string such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F".
    ///
    /// Returns nil for invalid strings.
    public init?(uuidString string: __shared String) {
        let utf8 = string.utf8Span
        guard utf8.count == 36 else {
            return nil
        }
        
        var charIdx = 0
        var byteIdx = 0
        while charIdx < 36 {
            switch charIdx {
            case 8, 13, 18, 23:
                guard utf8.span[charIdx] == UInt8(ascii: "-") else {
                    return nil
                }
                charIdx += 1
            default:
                // from CodableUtilities.swift
                guard let b1 = utf8.span[charIdx].hexDigitValue else {
                    return nil
                }
                guard let b2 = utf8.span[charIdx + 1].hexDigitValue else {
                    return nil
                }
                _storage[byteIdx] = b1 << 4 | b2
                byteIdx += 1
                charIdx += 2
            }
        }
    }

    /// Create a UUID from a `uuid_t`.
    public init(uuid: uuid_t) {
        self._storage = unsafeBitCast(uuid, to: InlineArray<16, UInt8>.self)
    }

    /// Creates a UUID by copying exactly 16 bytes from a `Span<UInt8>`.
    ///
    /// - Precondition: `span.count` must be exactly 16.
    @available(FoundationPreview 6.4, *)
    public init(copying span: Span<UInt8>) {
        precondition(span.count == 16, "UUID requires exactly 16 bytes, but \(span.count) were provided")
        self.init()
        for i in 0..<16 {
            _storage[i] = span[i]
        }
    }

    /// Creates a UUID by filling its 16 bytes using a closure that
    /// writes into an `OutputRawSpan`.
    ///
    /// The closure must write exactly 16 bytes into the output span.
    ///
    ///     let uuid = UUID { output in
    ///         output.append(myTimestampBytes)
    ///         output.append(myRandomBytes)
    ///     }
    @available(FoundationPreview 6.4, *)
    public init<E: Error>(
        initializingWith initializer: (inout OutputSpan<UInt8>) throws(E) -> ()
    ) throws(E) {
        _storage = try InlineArray<16, UInt8>(initializingWith: { outputSpan throws(E) -> Void in
            try initializer(&outputSpan)
            let count = outputSpan.count
            precondition(count == 16, "UUID requires exactly 16 bytes, but \(count) were provided")
        })
    }

    // Hex lookup tables for UUID string formatting.
    // Each byte is converted to two hex characters via table lookup.
    private static let _upperHex: StaticString = "0123456789ABCDEF"
    private static let _lowerHex: StaticString = "0123456789abcdef"

    /// Writes the UUID as a 36-character hex string into `buffer`
    /// using the given hex digit lookup table. Returns 36.
    private func _unparse(
        into buffer: UnsafeMutableBufferPointer<UInt8>,
        hexTable: StaticString
    ) -> Int {
        hexTable.withUTF8Buffer { hex in
            var o = 0
            for i in 0..<16 {
                // Insert '-' after bytes 4, 6, 8, 10
                switch i {
                case 4, 6, 8, 10:
                    buffer[o] = UInt8(ascii: "-")
                    o &+= 1
                default:
                    break
                }
                let byte = _storage[i]
                buffer[o] = hex[Int(byte &>> 4)]
                buffer[o &+ 1] = hex[Int(byte & 0xF)]
                o &+= 2
            }
            assert(o == 36)
        }
        return 36
    }

    /// Returns a string created from the UUID, such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    public var uuidString: String {
        String(unsafeUninitializedCapacity: 36) { buffer in
            _unparse(into: buffer, hexTable: UUID._upperHex)
        }
    }

    /// Returns a lowercase string created from the UUID, such as "e621e1f8-c36c-495a-93fc-0c247a3e6e5f"
    @available(FoundationPreview 6.4, *)
    public var lowercasedUUIDString: String {
        String(unsafeUninitializedCapacity: 36) { buffer in
            _unparse(into: buffer, hexTable: UUID._lowerHex)
        }
    }

    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: _storage) { buffer in
            hasher.combine(bytes: buffer)
        }
    }
    
    /// Generates a new random UUID.
    ///
    /// - Parameter generator: The random number generator to use when creating the new random value.
    /// - Returns: A random UUID.
    @available(FoundationPreview 6.3, *)
    public static func random(
        using generator: inout some RandomNumberGenerator
    ) -> UUID {
        let first = UInt64.random(in: .min ... .max, using: &generator)
        let second = UInt64.random(in: .min ... .max, using: &generator)

        var firstBits = first
        var secondBits = second

        // Set the version to 4 (0100 in binary)
        firstBits &= 0b11111111_11111111_11111111_11111111_11111111_11111111_00001111_11111111 // Clear bits 48 through 51
        firstBits |= 0b00000000_00000000_00000000_00000000_00000000_00000000_01000000_00000000 // Set the version bits to '0100' at the correct position
        
        // Set the variant to '10' (RFC9562 variant)
        secondBits &= 0b00111111_11111111_11111111_11111111_11111111_11111111_11111111_11111111 // Clear the 2 most significant bits
        secondBits |= 0b10000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000 // Set the two MSB to '10'

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
        // Implementation note: This operation is designed to avoid short-circuited early exits, so that comparison of any two UUID values is done in the same amount of time.
        withUnsafeBytes(of: lhs._storage) { lhsPtr in
            withUnsafeBytes(of: rhs._storage) { rhsPtr in
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

// MARK: - Nil and Max UUIDs

@available(FoundationPreview 6.4, *)
extension UUID {
    /// The `nil` (or minimum) UUID, where all bits are set to zero.
    ///
    /// As defined by [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562#section-5.9),
    /// the nil UUID is a special form where all 128 bits are zero.
    /// It can be used to represent the absence of a UUID value.
    public static let min = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    /// The max UUID, where all bits are set to one.
    ///
    /// As defined by [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562#section-5.10),
    /// the max UUID is a special form where all 128 bits are one.
    /// It can be used as a sentinel value, for example to represent
    /// "the largest possible UUID" in a sorted range.
    public static let max = UUID(uuid: (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF))
}

// MARK: - Span

@available(FoundationPreview 6.4, *)
extension UUID {
    /// A `Span<UInt8>` view of the UUID's 16 bytes.
    public var span: Span<UInt8> {
        @_lifetime(borrow self)
        borrowing get {
            _storage.span
        }
    }

    /// A `MutableSpan<UInt8>` view of the UUID's 16 bytes.
    public var mutableSpan: MutableSpan<UInt8> {
        @_lifetime(&self)
        mutating get {
            _storage.mutableSpan
        }
    }
}

// MARK: - UUID Version

@available(FoundationPreview 6.4, *)
extension UUID {
    /// The version of a UUID, as defined by RFC 9562.
    public struct Version: Sendable, Hashable, Codable, RawRepresentable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        /// Version 1: Gregorian time-based UUID with node identifier.
        public static var timeBased: Version { Version(rawValue: 1) }

        /// Version 3: Name-based UUID using MD5 hashing.
        public static var nameBasedMD5: Version { Version(rawValue: 3) }

        /// Version 4: Random UUID.
        public static var random: Version { Version(rawValue: 4) }

        /// Version 5: Name-based UUID using SHA-1 hashing.
        public static var nameBasedSHA1: Version { Version(rawValue: 5) }

        /// Version 6: Reordered Gregorian time-based UUID.
        public static var reorderedTimeBased: Version { Version(rawValue: 6) }

        /// Version 7: Unix Epoch time-based UUID with random bits.
        public static var timeOrdered: Version { Version(rawValue: 7) }

        /// Version 8: Custom UUID with user-defined layout.
        public static var custom: Version { Version(rawValue: 8) }
    }

    /// The version of this UUID, derived from the version bits
    /// (bits 48–51) as defined by RFC 9562.
    public var version: UUID.Version {
        Version(rawValue: _storage[6] >> 4)
    }

    /// Creates a new UUID with RFC 9562 version 7 layout: a Unix
    /// timestamp in milliseconds in the most significant 48 bits,
    /// followed by random bits. The variant and version fields are
    /// set per the RFC.
    ///
    /// Version 7 UUIDs sort in approximate chronological order
    /// when compared using the standard `<` operator, making them
    /// well-suited as database primary keys. UUIDs created within
    /// the same millisecond are distinguished by random bits and
    /// may not reflect exact creation order.
    public static func timeOrdered() -> UUID {
        var generator = SystemRandomNumberGenerator()
        return timeOrdered(using: &generator)
    }

    /// Creates a new UUID with RFC 9562 version 7 layout using
    /// the specified random number generator for the random bits.
    ///
    /// The most significant 48 bits contain a millisecond-precision
    /// Unix timestamp. The remaining bits (excluding version and
    /// variant fields) are filled using `generator`.
    ///
    /// - Parameter generator: The random number generator to use
    ///   when creating the random portions of the UUID.
    /// - Returns: A version 7 UUID.
    public static func timeOrdered(
        using generator: inout some RandomNumberGenerator,
        at date: Date? = nil
    ) -> UUID {
        let now = date ?? Date.now
        let rawMS = now.timeIntervalSince1970 * 1000.0
        // Clamp to the 48-bit unsigned range (0 ... 0xFFFF_FFFF_FFFF).
        // Below 0 corresponds to dates before 1970-01-01.
        // Above 0xFFFF_FFFF_FFFF corresponds to dates after approximately year 10889.
        let ms = UInt64(clamping: Int64(Swift.max(0, Swift.min(rawMS, Double(0xFFFF_FFFF_FFFF)))))

        var first = UInt64.random(in: .min ... .max, using: &generator)
        var second = UInt64.random(in: .min ... .max, using: &generator)

        // Set bits 0–47 to the millisecond timestamp
        first = (first & 0x0000_0000_0000_FFFF) | (ms << 16)

        // Set the version to 7 (0111) in bits 48–51
        first &= 0xFFFF_FFFF_FFFF_0FFF
        first |= 0x0000_0000_0000_7000

        // Set the variant to '10' in bits 64–65
        second &= 0x3FFF_FFFF_FFFF_FFFF
        second |= 0x8000_0000_0000_0000

        return UUID { span in
            // TODO: when OutputSpan has OutputRawSpan, we can append two UInt64 directly instead of breaking it down into bytes.
            span.append(UInt8(truncatingIfNeeded: first >> 56))
            span.append(UInt8(truncatingIfNeeded: first >> 48))
            span.append(UInt8(truncatingIfNeeded: first >> 40))
            span.append(UInt8(truncatingIfNeeded: first >> 32))
            span.append(UInt8(truncatingIfNeeded: first >> 24))
            span.append(UInt8(truncatingIfNeeded: first >> 16))
            span.append(UInt8(truncatingIfNeeded: first >> 8))
            span.append(UInt8(truncatingIfNeeded: first))
            span.append(UInt8(truncatingIfNeeded: second >> 56))
            span.append(UInt8(truncatingIfNeeded: second >> 48))
            span.append(UInt8(truncatingIfNeeded: second >> 40))
            span.append(UInt8(truncatingIfNeeded: second >> 32))
            span.append(UInt8(truncatingIfNeeded: second >> 24))
            span.append(UInt8(truncatingIfNeeded: second >> 16))
            span.append(UInt8(truncatingIfNeeded: second >> 8))
            span.append(UInt8(truncatingIfNeeded: second))
        }
    }

    /// For version 7 UUIDs, returns the `Date` encoded in the
    /// most significant 48 bits. Returns `nil` for all other versions.
    /// The returned date has millisecond precision, as specified
    /// by RFC 9562.
    public var timeOrderedTimestamp: Date? {
        guard version == .timeOrdered else { return nil }
        let ms: UInt64 = UInt64(_storage[0]) << 40 | UInt64(_storage[1]) << 32
            | UInt64(_storage[2]) << 24 | UInt64(_storage[3]) << 16
            | UInt64(_storage[4]) << 8 | UInt64(_storage[5])
        return Date(timeIntervalSince1970: Double(ms) / 1000.0)
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension UUID : Comparable {
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    public static func < (lhs: UUID, rhs: UUID) -> Bool {
        // Implementation note: This operation is designed to avoid short-circuited early exits, so that comparison of any two UUID values is done in the same amount of time.
        var leftStorage = lhs._storage
        var rightStorage = rhs._storage
        var result: Int = 0
        var diff: Int = 0
        withUnsafeBytes(of: &leftStorage) { leftPtr in
            withUnsafeBytes(of: &rightStorage) { rightPtr in
                for offset in (0 ..< 16).reversed() {
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
