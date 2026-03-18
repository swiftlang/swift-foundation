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

@inline(__always)
private func isSeparator(_ byte: UInt8) -> Bool {
    #if os(Windows)
    byte == ._backslash || byte == ._slash
    #else
    byte == ._slash
    #endif
}

extension Span<UInt8> {

    /// - Note: Returns an empty range `1..<1` for a path of all separators
    var urlLastPathComponentRange: Range<Int> {
        // Skip trailing slashes
        var componentEnd = count
        while componentEnd > 1 && isSeparator(self[componentEnd - 1]) {
            componentEnd -= 1
        }
        // Scan backwards for the preceding slash
        var componentStart = componentEnd
        while componentStart > 0 && !isSeparator(self[componentStart - 1]) {
            componentStart -= 1
        }
        return componentStart..<componentEnd
    }

    func mapPathComponents<R>(
        root: (borrowing Span<UInt8>) throws -> R,
        component: (borrowing Span<UInt8>) throws -> R,
        trailingSeparator: (() -> R)? = nil
    ) rethrows -> [R] {
        var result: [R] = []
        var start = 0

        // Append result for the root if present
        // TODO: Enhancement to handle Windows roots
        if start < count, isSeparator(self[start]) {
            try result.append(root(extracting(first: 1)))
            repeat { start += 1 } while start < count && isSeparator(self[start])
        }

        // Append results for non-empty components
        var i = start // `start` tracks the beginning of the current component
        while i < count {
            if isSeparator(self[i]) {
                if start < i {
                    try result.append(component(extracting(start..<i)))
                }
                start = i + 1
            }
            i += 1
        }
        if start < count {
            try result.append(component(extracting(start..<count)))
        }

        // Append result for the presence of a trailing separator
        if let trailingSeparator, count > 1, isSeparator(self[count - 1]) {
            result.append(trailingSeparator())
        }
        return result
    }

    // Unused, for reference only
    private static let invalidExtensionScalars = Set<Unicode.Scalar>([
        " ",
        "/",
        "\u{061C}", // ARABIC LETTER MARK
        "\u{200E}", // LEFT-TO-RIGHT MARK
        "\u{200F}", // RIGHT-TO-LEFT MARK
        "\u{202A}", // LEFT-TO-RIGHT EMBEDDING
        "\u{202B}", // RIGHT-TO-LEFT EMBEDDING
        "\u{202C}", // POP DIRECTIONAL FORMATTING
        "\u{202D}", // LEFT-TO-RIGHT OVERRIDE
        "\u{202E}", // RIGHT-TO-LEFT OVERRIDE
        "\u{2066}", // LEFT-TO-RIGHT ISOLATE
        "\u{2067}", // RIGHT-TO-LEFT ISOLATE
        "\u{2068}", // FIRST STRONG ISOLATE
        "\u{2069}", // POP DIRECTIONAL ISOLATE
    ])

    private func containsInvalidPathExtensionScalar() -> Bool {
        var i = 0
        while i < count {
            // Compiler has trouble verifying bounds and no overflow
            let b0 = self[unchecked: i]
            if b0 < 0x80 {
                if b0 == 0x20 || b0 == 0x2F {
                    return true // ASCII " " or "/"
                }
                #if os(Windows)
                if b0 == 0x5C {
                    return true // ASCII "\"
                }
                #endif
                i &+= 1
            } else if b0 < 0xC0 {
                // Skip invalid lead byte
                i &+= 1
            } else if b0 < 0xE0 {
                // 2-byte sequence
                if b0 == 0xD8, i &+ 1 < count, self[unchecked: i &+ 1] == 0x9C {
                    return true // U+061C ARABIC LETTER MARK
                }
                i &+= 2
            } else if b0 < 0xF0 {
                // 3-byte sequence
                if b0 == 0xE2, i &+ 2 < count {
                    let b1 = self[unchecked: i &+ 1]
                    let b2 = self[unchecked: i &+ 2]
                    if b1 == 0x80, (b2 == 0x8E || b2 == 0x8F || (b2 >= 0xAA && b2 <= 0xAE)) {
                        return true // U+200E/F, U+202A-202E
                    }
                    if b1 == 0x81, (b2 >= 0xA6 && b2 <= 0xA9) {
                        return true // U+2066-2069
                    }
                }
                i &+= 3
            } else {
                // 4-byte sequence
                i &+= 4
            }
        }
        return false
    }

    /// Returns `true` if the span is a valid path extension, or `false` in the following cases:
    /// - The span ends with `"."`
    /// - A path separator appears before the last `"."`
    /// - The final extension contains an invalid scalar such as `"/"` or `LEFT-TO-RIGHT OVERRIDE`
    var isValidPathExtension: Bool {
        guard let lastDot = lastIndex(of: ._dot) else {
            return !containsInvalidPathExtensionScalar()
        }
        guard lastDot != count - 1 else {
            // Don't allow an extension to end with "."
            return false
        }
        // Don't allow a separator before the last dot
        var i = 0
        while i < lastDot {
            if isSeparator(self[i]) {
                return false
            }
            i += 1
        }
        // Don't allow an invalid extension scalar after the last dot
        return !extracting((lastDot + 1)...).containsInvalidPathExtensionScalar()
    }

    /// Returns the index of the last path extension dot, or `nil` in the following cases:
    /// - The last path component does not contain `"."`
    /// - The last `"."` appears to start a hidden file name
    /// - `"."` is the last character of the component
    /// - Removing `".<ext>"` would leave `"."` or `".."` as the file name
    /// - The extension contains an invalid scalar such as `LEFT-TO-RIGHT OVERRIDE`
    var pathExtensionDotIndex: Int? {
        var i = count - 1
        // Skip past trailing slashes
        while i >= 0, isSeparator(self[i]) {
            i -= 1
        }
        // Last non-separator index, or -1 if the path is all separators
        let componentEndInclusive = i
        while i >= 0 {
            if self[i] == ._dot {
                break
            } else if isSeparator(self[i]) {
                return nil // Last component does not contain "."
            }
            i -= 1
        }
        guard i > 0 && i < componentEndInclusive else {
            // i < 0: No extension found
            // i == 0: Hidden file name
            // i == componentEndInclusive: Trailing dot/empty extension
            return nil
        }
        guard !isSeparator(self[i - 1]) else {
            // "." appears to start a hidden file name
            return nil
        }
        let lastDot = i
        // Guard against "." and ".." file names
        let badFileName = (
            (lastDot == 1 && self[0] == ._dot) ||
            (lastDot == 2 && self[0] == ._dot && self[1] == ._dot)
        )
        guard !badFileName else {
            return nil
        }
        guard !extracting((lastDot + 1)...componentEndInclusive).containsInvalidPathExtensionScalar() else {
            return nil
        }
        return lastDot
    }

    func lastIndex(of byte: UInt8) -> Int? {
        lastIndex { $0 == byte }
    }

    func lastIndex(where predicate: (UInt8) throws -> Bool) rethrows -> Int? {
        guard !isEmpty else {
            return nil
        }

        var i = count - 1
        while i >= 0 {
            if try predicate(self[i]) {
                return i
            }
            i -= 1
        }

        return nil
    }

    @inline(__always)
    func starts(with prefix: StaticString) -> Bool {
        let prefixLength = prefix.utf8CodeUnitCount
        guard prefixLength > 0 else { return true }
        guard self.count >= prefixLength else { return false }
        // Precondition: self.count > 0
        return withUnsafeBufferPointer { buffer in
            memcmp(buffer.baseAddress.unsafelyUnwrapped, prefix.utf8Start, prefixLength) == 0
        }
    }

    @inline(__always)
    var first: UInt8? {
        guard count > 0 else { return nil }
        return self[0]
    }

    @inline(__always)
    var last: UInt8? {
        guard count > 0 else { return nil }
        return self[count - 1]
    }

    func contains(_ byte: UInt8) -> Bool {
        for i in indices {
            if self[i] == byte {
                return true
            }
        }
        return false
    }

}
