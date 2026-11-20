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

package struct StringContents: ~Escapable {
    package enum Encoding {
        case utf8
        case utf16
        case ascii

        package var stringEncoding: String.Encoding {
            switch self {
            case .utf8: .utf8
            case .utf16: .utf16
            case.ascii: .ascii
            }
        }

        package var codeUnitSize: Int {
            switch self {
            case .utf8, .ascii: 1
            case .utf16: 2
            }
        }
    }

    package let bytes: RawSpan
    package let encoding: Encoding

    package var count: Int { bytes.byteCount / encoding.codeUnitSize }

    @_lifetime(copy bytes)
    package init(_ bytes: RawSpan, encoding: Encoding) {
        self.bytes = bytes
        self.encoding = encoding
    }

    @_lifetime(copy codeUnits)
    package init(_ codeUnits: Span<UInt8>, isKnownASCII: Bool = false) {
        self.init(codeUnits.bytes, encoding: isKnownASCII ? .ascii : .utf8)
    }

    @_lifetime(copy codeUnits)
    package init(_ codeUnits: Span<UInt16>) {
        self.init(codeUnits.bytes, encoding: .utf16)
    }

    // Slices using code unit offsets
    @_lifetime(copy self)
    package func extracting(_ range: Range<Int>) -> StringContents {
        let size = encoding.codeUnitSize
        return StringContents(bytes.extracting((range.lowerBound * size) ..< (range.upperBound * size)), encoding: encoding)
    }

    // Slices using a code unit offset
    @_lifetime(copy self)
    package func extracting(droppingFirst count: Int) -> StringContents {
        StringContents(bytes.extracting(droppingFirst: count * encoding.codeUnitSize), encoding: encoding)
    }

    package func count(of byte: UInt8) -> Int {
        switch encoding {
        case .utf8, .ascii:
            Span<UInt8>(viewing: bytes).count(of: byte)
        case .utf16:
            Span<UInt16>(viewing: bytes).count(of: UInt16(byte))
        }
    }
}

#if FOUNDATION_FRAMEWORK
internal import Foundation_Private.NSString

extension NSString {
    func withContents<T: ~Copyable, E>(
        _ body: (StringContents) throws(E) -> T
    ) throws(E) -> T {
        var utf8Length = 0
        if let ptr = self._fastCharacterContents() {
            let length = self.length
            return try body(StringContents(Span(_unsafeStart: ptr, count: length)))
        } else if let ptr = self._fastUTF8StringContents(false, utf8Length: &utf8Length) {
            let ascii = self.fastestEncoding == String.Encoding.ascii.rawValue
            return try body(StringContents(Span(_unsafeStart: ptr, count: utf8Length), isKnownASCII: ascii))
        } else {
            return try withTemporaryAllocation(of: UInt16.self, capacity: length) { buffer throws(E) in
                buffer.withUnsafeMutableBufferPointer { bufferPointer, initializedCount in
                    if let base = bufferPointer.baseAddress {
                        self.getCharacters(base)
                    }
                    initializedCount = bufferPointer.count
                }

                return try body(StringContents(buffer.span))
            }
        }
    }

    convenience init?(copying contents: StringContents) {
        let other = contents.bytes.withUnsafeBytes {
            if let ptr = $0.baseAddress {
                NSString(bytes: ptr, length: $0.count, encoding: contents.encoding.stringEncoding.rawValue)
            } else {
                NSString()
            }
        }
        guard let other else { return nil }
        self.init(string: other)
    }
}

extension StringContents {
    func withNSStringBorrow<R: ~Copyable, E>(_ body: (NSString) throws(E) -> R) throws(E) -> R {
        return try self.bytes.withUnsafeBytes { buffer throws(E) in
            let string: NSString
            if let ptr = buffer.baseAddress {
                string = NSString(bytesNoCopy: UnsafeMutableRawPointer(mutating: ptr), length: buffer.count, encoding: self.encoding.stringEncoding.rawValue, freeWhenDone: false)!
            } else {
                string = NSString()
            }
            return try body(string)
        }
    }
}
#endif

extension String {
    package func withContents<T: ~Copyable, E>(
        _ body: (StringContents) throws(E) -> T
    ) throws(E) -> T {
        #if FOUNDATION_FRAMEWORK
        if !self.isContiguousUTF8 {
            return try (self as NSString).withContents(body)
        }
        #endif
        return try body(StringContents(self.utf8Span.span, isKnownASCII: self.utf8Span.isKnownASCII))
    }

    package init(copying contents: StringContents) {
        switch contents.encoding {
        case .ascii:
            self = Span<UInt8>(viewing: contents.bytes).withUnsafeBufferPointer { String(decoding: $0, as: Unicode.ASCII.self) }
        case .utf8:
            self = Span<UInt8>(viewing: contents.bytes).withUnsafeBufferPointer { String(decoding: $0, as: UTF8.self) }
        case .utf16:
            self = Span<UInt16>(viewing: contents.bytes).withUnsafeBufferPointer { String(decoding: $0, as: UTF16.self) }
        }
    }
}
