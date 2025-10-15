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

#if canImport(RegexBuilder)
import RegexBuilder
#endif

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

// MARK: - Regex Support

#if canImport(RegexBuilder)
import RegexBuilder

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension UUID: RegexComponent {
    /// The regex pattern that matches UUID strings.
    ///
    /// Matches UUIDs in the standard format: `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`
    /// where X represents a hexadecimal digit (0-9, A-F, a-f).
    ///
    /// Example usage:
    /// ```swift
    /// let text = "User ID: E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    /// let regex = Regex {
    ///     "User ID: "
    ///     Capture { UUID.regex }
    /// }
    /// if let match = text.firstMatch(of: regex) {
    ///     let uuidString = String(match.1)
    ///     let uuid = UUID(uuidString: uuidString)
    /// }
    /// ```
    public var regex: Regex<Substring> {
        Regex {
            // 8 hex digits
            Repeat(count: 8) {
                CharacterClass(.hexDigit)
            }
            "-"
            // 4 hex digits
            Repeat(count: 4) {
                CharacterClass(.hexDigit)
            }
            "-"
            // 4 hex digits
            Repeat(count: 4) {
                CharacterClass(.hexDigit)
            }
            "-"
            // 4 hex digits
            Repeat(count: 4) {
                CharacterClass(.hexDigit)
            }
            "-"
            // 12 hex digits
            Repeat(count: 12) {
                CharacterClass(.hexDigit)
            }
        }
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == UUID {
    /// A regex component that matches UUID strings.
    ///
    /// This component matches UUID strings in the standard format:
    /// `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX` where X represents a hexadecimal digit.
    ///
    /// Example usage:
    /// ```swift
    /// let text = "Session: E621E1F8-C36C-495A-93FC-0C247A3E6E5F active"
    /// let regex = Regex {
    ///     "Session: "
    ///     Capture { UUID.regex }
    ///     " active"
    /// }
    /// if let match = text.firstMatch(of: regex) {
    ///     let uuidString = String(match.1)
    ///     let uuid = UUID(uuidString: uuidString)
    /// }
    /// ```
    public static var regex: UUID { UUID() }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension UUID {
    /// A regex component that captures and parses UUID strings into UUID instances.
    ///
    /// This parser matches UUID strings in the standard format: `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`
    /// where X is a hexadecimal digit (0-9, A-F, a-f). If the input does not match this format,
    /// or is not a valid UUID string, the parser returns `nil`.
    ///
    /// Example usage:
    /// ```swift
    /// let text = "User ID: E621E1F8-C36C-495A-93FC-0C247A3E6E5F end"
    /// let regex = Regex {
    ///     "User ID: "
    ///     Capture { UUID.parser }
    ///     " end"
    /// }
    /// if let match = text.firstMatch(of: regex) {
    ///     let uuid: UUID = match.1 // Direct UUID instance
    ///     print("Found UUID: \(uuid)")
    /// }
    public static var parser: some RegexComponent<UUID> {
        TryCapture {
            Repeat(count: 8) { .hexDigit }
            "-"
            Repeat(count: 4) { .hexDigit }
            "-"
            Repeat(count: 4) { .hexDigit }
            "-"
            Repeat(count: 4) { .hexDigit }
            "-"
            Repeat(count: 12) { .hexDigit }
        } transform: { (match: Substring) -> UUID? in
            // match is the captured substring; convert to UUID
            UUID(uuidString: String(match))
        }
    }

    /// A case-insensitive regex component that captures and parses UUID strings into UUID instances.
    ///
    /// This parser matches UUID strings in both uppercase and lowercase format:
    /// `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX` or `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
    /// where X is a hexadecimal digit (0-9, A-F, a-f). If the input does not match this format,
    /// or is not a valid UUID string, the parser returns `nil`.
    ///
    /// Example usage:
    /// ```swift
    /// let text = "User ID: e621e1f8-c36c-495a-93fc-0c247a3e6e5f end"
    /// let regex = Regex {
    ///     "User ID: "
    ///     Capture { UUID.caseInsensitiveParser }
    ///     " end"
    /// }
    /// if let match = text.firstMatch(of: regex) {
    ///     let uuid: UUID = match.1 // Direct UUID instance
    ///     print("Found UUID: \(uuid)")
    /// }
    public static var caseInsensitiveParser: some RegexComponent<UUID> {
        TryCapture {
            Repeat(count: 8) { .hexDigit }
            "-"
            Repeat(count: 4) { .hexDigit }
            "-"
            Repeat(count: 4) { .hexDigit }
            "-"
            Repeat(count: 4) { .hexDigit }
            "-"
            Repeat(count: 12) { .hexDigit }
        } transform: { (match: Substring) -> UUID? in
            // match is the captured substring; convert to UUID
            UUID(uuidString: String(match))
        }
    }
}
#endif
