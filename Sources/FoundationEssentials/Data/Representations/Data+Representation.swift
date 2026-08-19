//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if !DATA_LEGACY_ABI

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {
    // The actual storage for Data's various representations.
    // Inlinability strategy: almost everything should be inlinable as forwarding the underlying implementations. (Inlining can also help avoid retain-release traffic around pulling values out of enums.)
    @usableFromInline
    @frozen
    internal struct _Representation : Sendable {
        @export(implementation) @inline(__always)
        static var empty: _Representation {
            _Representation(.empty, count: 0)
        }

        @usableFromInline var _storage: __DataStorage
        @usableFromInline var _slice: Range<Int>

        @export(implementation) @inline(__always)
        init(_ buffer: UnsafeRawBufferPointer) {
            let count = buffer.count
            guard let address = buffer.baseAddress, count > 0 else {
                self = .empty
                return
            }
            self.init(__DataStorage(bytes: address, length: count), count: count)
        }
        
        @export(implementation) @inline(__always)
        init(_ buffer: UnsafeRawBufferPointer, owner: AnyObject) {
            let count = buffer.count
            let storage = __DataStorage(bytes: UnsafeMutableRawPointer(mutating: buffer.baseAddress), length: count, copy: false, deallocator: { _, _ in
                _fixLifetime(owner)
            }, offset: 0)
            self.init(storage, count: count)
        }
        
        @export(implementation) @inline(__always)
        init(capacity: Int) {
            guard capacity > 0 else {
                self = .empty
                return
            }
            self.init(__DataStorage(capacity: capacity), count: 0)
        }
        
        @export(implementation) @inline(__always)
        init(count: Int) {
            guard count > 0 else {
                self = .empty
                return
            }
            self.init(__DataStorage(length: count), count: count)
        }
        
        @export(implementation) @inline(__always)
        init(_ storage: __DataStorage, count: Int) {
            _storage = storage
            _slice = 0 ..< count
        }

        @export(implementation) @inline(__always)
        mutating func ensureUniqueReference() {
            if !isKnownUniquelyReferenced(&_storage) {
                _storage = _storage.mutableCopy(_slice)
            }
        }
        
        @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
        @export(implementation)
        init<E: Error>(
            capacity: Int, _ initializer: (inout OutputRawSpan) throws(E) -> Void
        ) throws(E) {
            assert(capacity >= 0)
            guard capacity > 0 else {
                self = .empty
                return
            }
            let storage = __DataStorage(capacity: capacity)
            var appendedCount = 0
            try storage.withUninitializedBytes(extraCapacity: capacity, location: 0, &appendedCount, initializer)
            self.init(storage, count: appendedCount)
        }

        mutating func stabilizeAddresses() {
            reserveCapacity(1)
        }

        @export(implementation)
        mutating func reserveCapacity(_ minimumCapacity: Int) {
            ensureUniqueReference()
            // the current capacity can be zero (representing externally owned buffer), and count can be greater than the capacity
            // Capacity of the storage is relative to the start of the allocation, not start of the slice, so offset by the prefix before the slice
            let prefixLength = startIndex - _storage._offset
            _storage.ensureUniqueBufferReference(growingTo: prefixLength + Swift.max(minimumCapacity, count))
        }
        
        @export(implementation)
        var count: Int {
            @inline(__always)
            get {
                _assumeNonNegative(_slice.upperBound &- _slice.lowerBound)
            }
            set(newValue) {
                guard newValue != 0 else {
                    self = .empty
                    return
                }

                ensureUniqueReference()
                let difference = newValue - count
                if difference > 0 {
                    let additionalRange = Int(_slice.upperBound) ..< Int(_slice.upperBound) + difference
                    _storage.resetBytes(in: additionalRange) // Already sets the length
                } else {
                    _storage.length += difference
                }
                _slice = _slice.lowerBound..<(_slice.lowerBound + newValue)
            }
        }

        @export(implementation)
        @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
        mutating func edit<E: Error, R: ~Copyable>(_ body: (inout OutputRawSpan) throws(E) -> R) throws(E) -> R {
            self.ensureUniqueReference()
            return try _storage.edit(range: &_slice, body)
        }

        @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
        @export(implementation)
        mutating func append<E: Error>(
            addingCount newBytesCount: Int,
            _ initializer: (inout OutputRawSpan) throws(E) -> Void
        ) throws(E) {
            reserveCapacity(count + newBytesCount)
            var appendedCount = 0
            defer {
                let newUpperBound = _slice.upperBound + appendedCount
                if newUpperBound == 0 {
                    self = .empty
                } else {
                    _slice = _slice.lowerBound..<newUpperBound
                }
            }
            try _storage.withUninitializedBytes(extraCapacity: newBytesCount, location: endIndex, &appendedCount, initializer)
        }
        
        @export(implementation) @inline(__always)
        func withUnsafeBytes<Result: ~Copyable, E>(_ apply: (UnsafeRawBufferPointer) throws(E) -> Result) throws(E) -> Result {
            try _storage.withUnsafeBytes(in: _slice, apply: apply)
        }
        
        @export(implementation) @inline(__always)
        mutating func withUnsafeMutableBytes<Result: ~Copyable, E>(_ apply: (UnsafeMutableRawBufferPointer) throws(E) -> Result) throws(E) -> Result {
            ensureUniqueReference()
            return try _storage.withUnsafeMutableBytes(in: _slice, apply: apply)
        }
        
        @export(implementation) @inline(__always)
        func enumerateBytes(_ block: (_ buffer: UnsafeBufferPointer<UInt8>, _ byteIndex: Index, _ stop: inout Bool) -> Void) {
            _storage.enumerateBytes(in: _slice, block)
        }
        
        @export(implementation)
        mutating func append(contentsOf buffer: UnsafeRawBufferPointer) {
            guard let address = buffer.baseAddress, buffer.count > 0 else { return }
            ensureUniqueReference()
            _storage.replaceBytes(
                in: (
                    location: _slice.upperBound,
                    length: _storage.length - (_slice.upperBound - _storage._offset)),
                with: address,
                length: buffer.count)
            _slice = _slice.lowerBound..<_slice.upperBound + buffer.count
        }
        
        @export(implementation)
        mutating func resetBytes(in range: Range<Index>) {
            precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            ensureUniqueReference()
            _storage.resetBytes(in: range)
            if _slice.upperBound < range.upperBound {
                _slice = _slice.lowerBound..<range.upperBound
            }
        }
        
        @usableFromInline
        mutating func replaceSubrange(_ subrange: Range<Index>, with bytes: UnsafeRawPointer?, count cnt: Int) {
            precondition(startIndex <= subrange.lowerBound, "index \(subrange.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(subrange.upperBound <= endIndex, "index \(subrange.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")

            if subrange.isEmpty && cnt == 0 { return }

            ensureUniqueReference()
            let upper = _slice.upperBound
            let nsRange = (
                location: subrange.lowerBound,
                length: subrange.upperBound - subrange.lowerBound)
            _storage.replaceBytes(in: nsRange, with: bytes, length: cnt)
            let resultingUpper = upper - (subrange.upperBound - subrange.lowerBound) + cnt
            _slice = _slice.lowerBound..<resultingUpper
        }

        @export(implementation)
        @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
        mutating func replaceSubrange<E: Error>(
            _ subrange: Range<Int>,
            addingCount newBytesCount: Int,
            initializingWith initializer: (inout OutputRawSpan) throws(E) -> Void
        ) throws(E) -> Void {
            precondition(startIndex <= subrange.lowerBound, "index \(subrange.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(subrange.upperBound <= endIndex, "index \(subrange.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")

            if subrange.isEmpty && newBytesCount == 0 { return }

            ensureUniqueReference()
            var endIndex = endIndex
            defer {
                _slice = _slice.lowerBound ..< endIndex
                if _slice.lowerBound == 0 && endIndex == 0 {
                    _storage = .empty
                }
            }
            try _storage.replaceSubrange(subrange, endIndex: &endIndex, addingCount: newBytesCount, initializingWith: initializer)
        }

        @export(implementation)
        subscript(index: Index) -> UInt8 {
            get {
                precondition(startIndex <= index, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                precondition(index < endIndex, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                return _storage.get(index)
            }
            set(newValue) {
                precondition(startIndex <= index, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                precondition(index < endIndex, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                ensureUniqueReference()
                _storage.set(index, to: newValue)
            }
        }
        
        @export(implementation)
        subscript(bounds: Range<Index>) -> Data {
            get {
                precondition(_slice.startIndex <= bounds.lowerBound, "Range \(bounds) out of bounds \(_slice)")
                precondition(bounds.upperBound <= _slice.endIndex, "Range \(bounds) out of bounds \(_slice)")
                if bounds.lowerBound == 0 && bounds.upperBound == 0 {
                    return Data()
                } else {
                    var newSlice = self
                    newSlice._slice = bounds
                    return Data(representation: newSlice)
                }
            }
        }
        
        @export(implementation) @inline(__always)
        var startIndex: Int {
            _assumeNonNegative(_slice.lowerBound)
        }
        
        @export(implementation) @inline(__always)
        var endIndex: Int {
            _assumeNonNegative(_slice.upperBound)
        }
        
        @export(implementation)
        func copyBytes(to pointer: UnsafeMutableRawPointer, from range: Range<Int>) {
            precondition(startIndex <= range.lowerBound, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(range.upperBound <= endIndex, "index \(range.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            _storage.copyBytes(to: pointer, from: range)
        }
        
        @inline(__always) // This should always be inlined into Data.hash(into:).
        func hash(into hasher: inout Hasher) {
            hasher.combine(count)

            self.withUnsafeBytes { bytes in
                hasher.combine(bytes: bytes)
            }
        }

        @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
        @export(implementation)
        var bytes: RawSpan {
            let buffer = unsafe UnsafeRawBufferPointer(
                start: _storage.mutableBytes?.advanced(by: _slice.startIndex), count: _slice.count
            )
            let span = unsafe RawSpan(_unsafeBytes: buffer)
            return unsafe _overrideLifetime(span, borrowing: self)
        }

        @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
        @export(implementation)
        public var mutableBytes: MutableRawSpan {
            @_lifetime(&self)
            mutating get {
                ensureUniqueReference()
                let buffer = unsafe UnsafeMutableRawBufferPointer(
                  start: _storage.mutableBytes?.advanced(by: _slice.startIndex), count: _slice.count
                )
                let span = unsafe MutableRawSpan(_unsafeBytes: buffer)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
        }
    }
}

#endif
