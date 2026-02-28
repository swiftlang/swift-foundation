//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//


// MARK: - Component validation

internal func validate<T: UnsignedInteger & FixedWidthInteger>(
    span: borrowing Span<T>,
    component allowedSet: URLComponentAllowedSet
) -> Bool {
    var i = span.indices.startIndex
    while i < span.indices.endIndex {
        // Compiler has trouble verifying bounds with the += 3 below,
        // so unchecked: reduces the loop from 12 to 8 instructions.
        let codeUnit = span[unchecked: i]
        if allowedSet.contains(codeUnit) {
            i += 1
        } else if codeUnit == UInt8(ascii: "%") {
            guard i + 2 < span.indices.endIndex,
                  isHexDigit(span[i + 1]),
                  isHexDigit(span[i + 2]) else {
                return false
            }
            i += 3
        } else {
            return false
        }
    }
    return true
}

internal func containsInvalidASCII<T: UnsignedInteger & FixedWidthInteger>(
    host: borrowing Span<T>
) -> Bool {
    let allowedSet = URLComponentAllowedSet.host
    for i in host.indices {
        let codeUnit = host[i]
        if codeUnit < 128 && !allowedSet.contains(codeUnit) {
            return true
        }
    }
    return false
}

// Validates the IP literal host portion inside the "[" and "]"
// A return value of false can be encoded, nil means reject entirely
@inline(__always)
internal func validateIPLiteral<T: UnsignedInteger & FixedWidthInteger>(
    innerHost: borrowing Span<T>,
    useModernParsing: Bool
) -> Bool? {
    var i = 0
    while i < innerHost.count && URLComponentAllowedSet.hostIPvFuture.contains(innerHost[i]) {
        i += 1
    }
    if i == innerHost.count {
        return true
    }
    // We found a character that's not allowed in .hostIPvFuture
    guard useModernParsing else {
        // For CFURL, allow arbitrary percent-encoding
        return validate(span: innerHost.extracting(i...), component: .hostIPvFuture)
    }
    // Otherwise, only a zone ID (starting at "%") can be percent-encoded
    guard innerHost[i] == UInt8(ascii: "%") else {
        // The IP portion contained an invalid character that was
        // not the start of a zone ID, so return nil.
        return nil
    }
    // "%25" is the correctly-encoded zone ID delimiter for a URL
    let isValidZoneID = (
        i + 2 < innerHost.count
        && innerHost[i + 1] == UInt8(ascii: "2")
        && innerHost[i + 2] == UInt8(ascii: "5")
        && validate(
            span: innerHost.extracting((i + 3)...),
            component: .hostZoneID
        )
    )
    return isValidZoneID
}

// Don't allow percent-escape sequences when validating certain paths
@inline(__always)
internal func strictValidate(path: borrowing Span<UInt8>) -> Bool {
    let allowedSet = URLComponentAllowedSet.path
    for i in path.indices {
        guard allowedSet.contains(path[i]) else {
            return false
        }
    }
    return true
}

private func isHexDigit<T: UnsignedInteger & FixedWidthInteger>(
    _ codeUnit: T
) -> Bool {
    codeUnit < 128 && UInt8(truncatingIfNeeded: codeUnit).isValidHexDigit
}

internal struct URLComponentAllowedSet: RawRepresentable {
    let rawValue: UInt16

    static var scheme: Self { Self(rawValue: UInt16(1) << 0) }

    // user, password, and hostIPvFuture use the same allowed character set.
    static var user:          Self { Self(rawValue: UInt16(1) << 1) }
    static var password:      Self { Self(rawValue: UInt16(1) << 1) }
    static var hostIPvFuture: Self { Self(rawValue: UInt16(1) << 1) }

    static var host: Self { Self(rawValue: UInt16(1) << 2) }
    static var path: Self { Self(rawValue: UInt16(1) << 3) }

    // query and fragment use the same allowed character set.
    static var query:    Self { Self(rawValue: UInt16(1) << 4) }
    static var fragment: Self { Self(rawValue: UInt16(1) << 4) }

    // hostZoneID uses the `unreserved` character set from RFC 3986.
    static var hostZoneID: Self { Self(rawValue: UInt16(1) << 5) }
    static var unreserved: Self { Self(rawValue: UInt16(1) << 5) }

    // `unreserved` + `reserved` character sets from RFC 3986.
    static var anyValid: Self { Self(rawValue: UInt16(1) << 6) }

    func contains<T: UnsignedInteger & FixedWidthInteger>(
        _ codeUnit: T
    ) -> Bool {
        codeUnit < 128 && (Self.allowedTable[Int(codeUnit)] & rawValue) != 0
    }

    #if FOUNDATION_FRAMEWORK
    private typealias AllowedTable = [128 of UInt16]
    #else
    private typealias AllowedTable = ContiguousArray<UInt16>
    #endif

    private static let allowedTable: AllowedTable = [
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b0000000,
        0b1011110,
        0b0000000,
        0b1000000,
        0b1011110,
        0b0000000,
        0b1011110,
        0b1011110,
        0b1011110,
        0b1011110,
        0b1011110,
        0b1011111,
        0b1011110,
        0b1111111,
        0b1111111,
        0b1011000,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1011010,
        0b1011110,
        0b0000000,
        0b1011110,
        0b0000000,
        0b1010000,
        0b1011000,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1011000, // "[" allowed in path, query, and fragment
        0b0000000,
        0b1011000, // "]" allowed in path, query, and fragment
        0b0000000,
        0b1111110,
        0b0000000,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b1111111,
        0b0000000,
        0b0000000,
        0b0000000,
        0b1111110,
        0b0000000,
    ]
}
