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

extension Span<UInt8> {
    func firstIndex(of byte: UInt8) -> Int? {
        guard !isEmpty else {
            return nil
        }

        var i = 0
        while i < count {
            if self[i] == byte {
                return i
            }
            i += 1
        }

        return nil
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

    func elementsEqual(_ other: Span<UInt8>) -> Bool {
        guard count == other.count else {
            return false
        }

        var i = 0
        while i < count {
            if self[i] != other[i] {
                return false
            }
            i += 1
        }

        return true
    }

    @inline(__always)
    var first: UInt8? {
        guard count > 0 else {
            return nil
        }
        return self[0]
    }

    @inline(__always)
    var last: UInt8? {
        guard count > 0 else {
            return nil
        }
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

extension OutputRawSpan {
    @export(implementation)
    mutating func _append(copying span: RawSpan) {
        precondition(self.freeCapacity >= span.byteCount, "Insufficient space to copy the provided span (have \(self.freeCapacity) bytes for writing \(span.byteCount) bytes)")
        self.withUnsafeMutableBytes { buffer, initializedCount in
            let dest = UnsafeMutableRawBufferPointer(rebasing: buffer.suffix(from: initializedCount))
            span.withUnsafeBytes { src in
                dest.copyMemory(from: src)
                initializedCount += src.count
            }
        }
    }
}

extension String {
    // String's may not be able to vend a span on 32-bit watchOS (and the property is marked unavailable)
    // In order to get a span on 32-bit watchOS, we must first guarantee that it is contiguous UTF-8
    package var utf8SpanMakingContiguous: UTF8Span {
        mutating get {
            #if FOUNDATION_FRAMEWORK && os(watchOS) && _pointerBitWidth(_32)
            self.makeContiguousUTF8()
            guard let span = self._utf8Span else {
                preconditionFailure("Internal Inconsistency: A contiguous UTF-8 String produced nil for _utf8Span")
            }
            return span
            #else
            self.utf8Span
            #endif
        }
    }
}

extension Substring {
    // String's may not be able to vend a span on 32-bit watchOS (and the property is marked unavailable)
    // In order to get a span on 32-bit watchOS, we must first guarantee that it is contiguous UTF-8
    package var utf8SpanMakingContiguous: UTF8Span {
        mutating get {
            #if FOUNDATION_FRAMEWORK && os(watchOS) && _pointerBitWidth(_32)
            self.makeContiguousUTF8()
            guard let span = self._utf8Span else {
                preconditionFailure("Internal Inconsistency: A contiguous UTF-8 String produced nil for _utf8Span")
            }
            return span
            #else
            self.utf8Span
            #endif
        }
    }
}
