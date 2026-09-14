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

extension OutputSpan where Element : ConvertibleToBytes & ConvertibleFromBytes {
    mutating func _append(copying span: Span<Element>) {
        precondition(self.freeCapacity >= span.count, "Insufficient space to copy the provided span (have space for \(self.freeCapacity) but writing \(span.count))")
        guard !span.isEmpty else { return }
        self.withUnsafeMutableBufferPointer { buffer, initializedCount in
            span.withUnsafeBufferPointer { src in
                let dstPtr = buffer.baseAddress.unsafelyUnwrapped.advanced(by: initializedCount)
                dstPtr.initialize(from: src.baseAddress.unsafelyUnwrapped, count: src.count)
                initializedCount += src.count
            }
        }
    }

    mutating func _append<S: Sequence<Element>>(copying elements: S) {
        let early: Void? = elements.withContiguousStorageIfAvailable { buffer in
            self._append(copying: buffer.span)
        }

        if early == nil {
            self.withUnsafeMutableBufferPointer { buffer, initializedCount in
                let uninitialized = UnsafeMutableBufferPointer(rebasing: buffer.suffix(from: initializedCount))
                var (iterator, idx) = elements._copyContents(initializing: uninitialized)
                precondition(iterator.next() == nil, "Insufficient space to store contents in OutputSpan")
                initializedCount += idx - uninitialized.startIndex
            }
        }
    }
}
