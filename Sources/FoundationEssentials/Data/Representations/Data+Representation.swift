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
        @_alwaysEmitIntoClient @inline(__always)
        static var empty: _Representation {
            _Representation(.empty, count: 0)
        }

        @usableFromInline var _storage: __DataStorage
        @usableFromInline var _slice: Range<Int>

        @_alwaysEmitIntoClient @inline(__always)
        init(_ buffer: UnsafeRawBufferPointer) {
            let count = buffer.count
            guard let address = buffer.baseAddress, count > 0 else {
                self = .empty
                return
            }
            self.init(__DataStorage(bytes: address, length: count), count: count)
        }
        
        @_alwaysEmitIntoClient @inline(__always)
        init(_ buffer: UnsafeRawBufferPointer, owner: AnyObject) {
            let count = buffer.count
            let storage = __DataStorage(bytes: UnsafeMutableRawPointer(mutating: buffer.baseAddress), length: count, copy: false, deallocator: { _, _ in
                _fixLifetime(owner)
            }, offset: 0)
            self.init(storage, count: count)
        }
        
        @_alwaysEmitIntoClient @inline(__always)
        init(capacity: Int) {
            guard capacity > 0 else {
                self = .empty
                return
            }
            self.init(__DataStorage(capacity: capacity), count: 0)
        }
        
        @_alwaysEmitIntoClient @inline(__always)
        init(count: Int) {
            guard count > 0 else {
                self = .empty
                return
            }
            self.init(__DataStorage(length: count), count: count)
        }
        
        @_alwaysEmitIntoClient @inline(__always)
        init(_ storage: __DataStorage, count: Int) {
            _storage = storage
            _slice = 0 ..< count
        }

        @_alwaysEmitIntoClient @inline(__always)
        mutating func ensureUniqueReference() {
            if !isKnownUniquelyReferenced(&_storage) {
                _storage = _storage.mutableCopy(_slice)
            }
        }
        
        @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
        @_alwaysEmitIntoClient
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

        @_alwaysEmitIntoClient
        mutating func reserveCapacity(_ minimumCapacity: Int) {
            ensureUniqueReference()
            // the current capacity can be zero (representing externally owned buffer), and count can be greater than the capacity
            // Capacity of the storage is relative to the start of the allocation, not start of the slice, so offset by the prefix before the slice
            let prefixLength = startIndex - _storage._offset
            _storage.ensureUniqueBufferReference(growingTo: prefixLength + Swift.max(minimumCapacity, count))
        }
        
        @_alwaysEmitIntoClient
        var count: Int {
            @inline(__always)
            get {
                _slice.count
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

        @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
        @_alwaysEmitIntoClient
        mutating func append<E: Error>(
            addingCapacity uninitializedCount: Int,
            _ initializer: (inout OutputRawSpan) throws(E) -> Void
        ) throws(E) {
            reserveCapacity(count + uninitializedCount)
            var appendedCount = 0
            defer {
                let newUpperBound = _slice.upperBound + appendedCount
                if newUpperBound == 0 {
                    self = .empty
                } else {
                    _slice = _slice.lowerBound..<newUpperBound
                }
            }
            try _storage.withUninitializedBytes(extraCapacity: uninitializedCount, location: endIndex, &appendedCount, initializer)
        }
        
        @_alwaysEmitIntoClient @inline(__always)
        func withUnsafeBytes<Result>(_ apply: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
            try _storage.withUnsafeBytes(in: _slice, apply: apply)
        }
        
        @_alwaysEmitIntoClient @inline(__always)
        mutating func withUnsafeMutableBytes<Result>(_ apply: (UnsafeMutableRawBufferPointer) throws -> Result) rethrows -> Result {
            ensureUniqueReference()
            return try _storage.withUnsafeMutableBytes(in: _slice, apply: apply)
        }
        
        @_alwaysEmitIntoClient @inline(__always)
        func enumerateBytes(_ block: (_ buffer: UnsafeBufferPointer<UInt8>, _ byteIndex: Index, _ stop: inout Bool) -> Void) {
            _storage.enumerateBytes(in: _slice, block)
        }
        
        @_alwaysEmitIntoClient
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
        
        @_alwaysEmitIntoClient
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
            precondition(subrange.lowerBound <= endIndex, "index \(subrange.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(startIndex <= subrange.upperBound, "index \(subrange.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(subrange.upperBound <= endIndex, "index \(subrange.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")

            ensureUniqueReference()
            let upper = _slice.upperBound
            let nsRange = (
                location: subrange.lowerBound,
                length: subrange.upperBound - subrange.lowerBound)
            _storage.replaceBytes(in: nsRange, with: bytes, length: cnt)
            let resultingUpper = upper - (subrange.upperBound - subrange.lowerBound) + cnt
            _slice = _slice.lowerBound..<resultingUpper
        }
        
        @_alwaysEmitIntoClient
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
        
        @_alwaysEmitIntoClient
        subscript(bounds: Range<Index>) -> Data {
            get {
                precondition(_slice.startIndex <= bounds.lowerBound, "Range \(bounds) out of bounds \(_slice)")
                precondition(bounds.lowerBound <= _slice.endIndex, "Range \(bounds) out of bounds \(_slice)")
                precondition(_slice.startIndex <= bounds.upperBound, "Range \(bounds) out of bounds \(_slice)")
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
        
        @_alwaysEmitIntoClient @inline(__always)
        var startIndex: Int {
            _slice.lowerBound
        }
        
        @_alwaysEmitIntoClient @inline(__always)
        var endIndex: Int {
            _slice.upperBound
        }
        
        @_alwaysEmitIntoClient
        func copyBytes(to pointer: UnsafeMutableRawPointer, from range: Range<Int>) {
            precondition(startIndex <= range.lowerBound, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(startIndex <= range.upperBound, "index \(range.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
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
        @_alwaysEmitIntoClient
        var bytes: RawSpan {
            let buffer = unsafe UnsafeRawBufferPointer(
                start: _storage.mutableBytes?.advanced(by: _slice.startIndex), count: _slice.count
            )
            let span = unsafe RawSpan(_unsafeBytes: buffer)
            return unsafe _overrideLifetime(span, borrowing: self)
        }

        @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
        @_alwaysEmitIntoClient
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
