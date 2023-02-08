//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

@_implementationOnly import _CShims

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
                uuid_generate_random($0)
            }
        }
    }

    /// Create a UUID from a string such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F".
    ///
    /// Returns nil for invalid strings.
    public init?(uuidString string: __shared String) {
        let res = withUnsafeMutablePointer(to: &uuid) {
            $0.withMemoryRebound(to: UInt8.self, capacity: 16) {
                return uuid_parse(string, $0)
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
        return withUnsafePointer(to: uuid) { valPtr in
            valPtr.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<uuid_t>.size) { val in
                withUnsafeMutablePointer(to: &bytes) { strPtr in
                    strPtr.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<uuid_string_t>.size) { str in
                        uuid_unparse_upper(val, str)
                        return String(cString: str)
                    }
                }
            }
        }
    }

    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: uuid) { buffer in
            hasher.combine(bytes: buffer)
        }
    }

    public var description: String {
        return uuidString
    }

    public var debugDescription: String {
        return description
    }

    public static func ==(lhs: UUID, rhs: UUID) -> Bool {
        return lhs.uuid.0 == rhs.uuid.0 &&
            lhs.uuid.1 == rhs.uuid.1 &&
            lhs.uuid.2 == rhs.uuid.2 &&
            lhs.uuid.3 == rhs.uuid.3 &&
            lhs.uuid.4 == rhs.uuid.4 &&
            lhs.uuid.5 == rhs.uuid.5 &&
            lhs.uuid.6 == rhs.uuid.6 &&
            lhs.uuid.7 == rhs.uuid.7 &&
            lhs.uuid.8 == rhs.uuid.8 &&
            lhs.uuid.9 == rhs.uuid.9 &&
            lhs.uuid.10 == rhs.uuid.10 &&
            lhs.uuid.11 == rhs.uuid.11 &&
            lhs.uuid.12 == rhs.uuid.12 &&
            lhs.uuid.13 == rhs.uuid.13 &&
            lhs.uuid.14 == rhs.uuid.14 &&
            lhs.uuid.15 == rhs.uuid.15
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

@available(Future, *)
extension UUID : Comparable {
    @available(Future, *)
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
