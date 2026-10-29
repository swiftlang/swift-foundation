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

extension Span where Element: ~Copyable {
    func lastIndex(where predicate: (borrowing Element) throws -> Bool) rethrows -> Int? {
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
}

extension Span where Element: Copyable {
    @inline(__always)
    package var first: Element? {
        guard count > 0 else {
            return nil
        }
        return self[0]
    }

    @inline(__always)
    var last: Element? {
        guard count > 0 else {
            return nil
        }
        return self[count - 1]
    }
}

extension Span where Element: Equatable & ~Copyable {
    package func firstIndex(of element: borrowing Element) -> Int? {
        guard !isEmpty else {
            return nil
        }

        var i = 0
        while i < count {
            if self[i] == element {
                return i
            }
            i += 1
        }

        return nil
    }

    func lastIndex(of element: borrowing Element) -> Int? {
        lastIndex { $0 == element }
    }

    func elementsEqual(_ other: Span<Element>) -> Bool {
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

    func contains(_ element: borrowing Element) -> Bool {
        for i in indices {
            if self[i] == element {
                return true
            }
        }
        return false
    }

    package func firstRange(of needle: Span<Element>) -> Range<Int>? {
        let m = needle.count
        guard m > 0 else {
            return 0..<0
        }
        guard m <= count else {
            return nil
        }

        for i in 0...(count - m) {
            var j = 0
            while j < m, self[i &+ j] == needle[j] {
                j &+= 1
            }

            if j == m {
                return i ..< (i &+ m)
            }
        }

        return nil
    }

    func count(of element: borrowing Element) -> Int {
        var num = 0
        for i in indices {
            if self[i] == element {
                num += 1
            }
        }
        return num
    }
}

extension Span where Element == UInt8 {
    /// Comparison against a prefix StaticString literal. The comparison is literal, not Unicode canonical.
    @inline(__always)
    func starts(with prefix: StaticString) -> Bool {
        let prefixLength = prefix.utf8CodeUnitCount
        guard prefixLength > 0 else { return true }
        guard self.count >= prefixLength else { return false }
        // Precondition: self.count > 0
        return withUnsafeBufferPointer { buffer in
            Platform.memcmp(buffer.baseAddress.unsafelyUnwrapped, prefix.utf8Start, prefixLength) == 0
        }
    }

    /// Whole-span comparison against a StaticString literal. The comparison is literal, not Unicode canonical.
    @inline(__always)
    func equals(_ other: StaticString) -> Bool {
        count == other.utf8CodeUnitCount && starts(with: other)
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

    mutating func _append<S: Sequence<Element>, Element: ConvertibleToBytes & ConvertibleFromBytes>(copying elements: S) {
        let early: Void? = elements.withContiguousStorageIfAvailable { buffer in
            self._append(copying: buffer.span.bytes)
        }

        if early == nil {
            self.withUnsafeMutableBytes { buffer, initializedCount in
                let uninitialized = UnsafeMutableRawBufferPointer(rebasing: buffer.suffix(from: initializedCount))
                var (iterator, idx) = elements._copyContents(initializing: uninitialized.assumingMemoryBound(to: Element.self))
                precondition(iterator.next() == nil, "Insufficient space to store contents in OutputRawSpan")
                initializedCount += idx - uninitialized.startIndex
            }
        }
    }

    mutating func _replaceSubrange(_ subrange: Range<Int>, copying span: RawSpan) {
        precondition(self.freeCapacity >= span.byteCount - subrange.count, "Insufficient space to copy the provided span (have space for \(self.freeCapacity) but writing \(span.byteCount))")
        precondition(subrange.lowerBound >= 0 && subrange.upperBound <= self.byteCount, "Invalid index")
        guard subrange.count > 0 || span.byteCount > 0 else { return }
        self.withUnsafeMutableBytes { buffer, initializedCount in
            let outputBase = buffer.baseAddress.unsafelyUnwrapped

            let originalSrc = outputBase.advanced(by: subrange.upperBound)
            if subrange.upperBound < initializedCount && subrange.count != span.byteCount {
                let originalDst = outputBase.advanced(by: subrange.lowerBound + span.byteCount)
                originalDst.copyMemory(from: originalSrc, byteCount: initializedCount - subrange.upperBound)
            }

            span.withUnsafeBytes { src in
                let newDst = outputBase.advanced(by: subrange.lowerBound)
                newDst.copyMemory(from: src.baseAddress.unsafelyUnwrapped, byteCount: src.count)
                initializedCount += src.count - subrange.count
            }
        }
    }

    package mutating func withOutputSpan<T: ConvertibleToBytes & ConvertibleFromBytes, E: Error, R: ~Copyable>(
        of type: T.Type,
        _ body: (inout OutputSpan<T>) throws(E) -> R
    ) throws(E) -> R {
        let stride = MemoryLayout<T>.stride
        return try self.withUnsafeMutableBytes { buffer, initializedCount throws(E) in
            precondition(initializedCount % stride == 0, "Initialized prefix of \(initializedCount) bytes is not a whole number of \(T.self)")
            let typedBuffer = buffer.bindMemory(to: T.self)
            var output = OutputSpan<T>(buffer: typedBuffer, initializedCount: initializedCount / stride)
            defer {
                initializedCount = output.finalize(for: typedBuffer) * stride
                output = OutputSpan<T>()
            }
            return try body(&output)
        }
    }
}

extension OutputSpan where Element : ConvertibleToBytes & ConvertibleFromBytes {
    package mutating func _append(copying span: Span<Element>) {
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

extension OutputSpan<UInt8> {
    @inline(__always)
    mutating func _append(copying source: StaticString) {
        source.withUTF8Buffer { _append(copying: $0.span) }
    }
}

extension OutputSpan where Element: Copyable {
    @inline(__always)
    var last: Element? {
        guard count > 0 else {
            return nil
        }
        return self[count - 1]
    }
}

extension OutputSpan where Element: ~Copyable {
    package mutating func removeSubrange(_ range: Range<Int>) {
        guard !range.isEmpty else { return }

        precondition(range.lowerBound >= 0, "Range lower bound must be non-negative")
        precondition(range.upperBound <= count, "Range upper bound out of bounds")
        do {
            var bytes = mutableSpan
            for i in range.upperBound..<bytes.count {
                bytes.swapAt(i - range.count, i)
            }
        }
        removeLast(range.count)
    }
}


extension String {
    package init<E>(_capacity capacity: Int, initializingWith body: (inout OutputSpan<UTF8.CodeUnit>) throws(E) -> Void) throws(E) {
        try self.init(unsafeUninitializedCapacity: capacity) { buffer throws(E) in
            var outputSpan = OutputSpan(buffer: buffer, initializedCount: 0)
            try body(&outputSpan)
            return outputSpan.finalize(for: buffer)
        }
    }
}
