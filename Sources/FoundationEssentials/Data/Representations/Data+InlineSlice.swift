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

#if DATA_LEGACY_ABI

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {
#if _pointerBitWidth(_64)
    @usableFromInline internal typealias HalfInt = Int32
#elseif _pointerBitWidth(_32)
    @usableFromInline internal typealias HalfInt = Int16
#else
#error ("Unsupported architecture: a definition of half of the pointer sized Int needs to be defined for this architecture")
#endif
    
    // A buffer of bytes too large to fit in an InlineData, but still small enough to fit a storage pointer + range in two words.
    // Inlinability strategy: everything here should be easily inlinable as large _DataStorage methods should not inline into here.
    @usableFromInline
    @frozen
    internal struct InlineSlice : Sendable {
        // ***WARNING***
        // These ivars are specifically laid out so that they cause the enum _Representation to be 16 bytes on 64 bit platforms. This means we _MUST_ have the class type thing last
        @usableFromInline var slice: Range<HalfInt>
        @usableFromInline var storage: __DataStorage
        
        @inlinable @inline(__always) // This is @inlinable as trivially computable.
        static func canStore(count: Int) -> Bool {
            return count < HalfInt.max
        }
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(_ buffer: UnsafeRawBufferPointer) {
            assert(buffer.count < HalfInt.max)
            self.init(__DataStorage(bytes: buffer.baseAddress, length: buffer.count), count: buffer.count)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(capacity: Int) {
            assert(capacity < HalfInt.max)
            self.init(__DataStorage(capacity: capacity), count: 0)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(count: Int) {
            assert(count < HalfInt.max)
            self.init(__DataStorage(length: count), count: count)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(_ inline: InlineData) {
            assert(inline.count < HalfInt.max)
            self.init(inline.withUnsafeBytes { return __DataStorage(bytes: $0.baseAddress, length: $0.count) }, count: inline.count)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(_ inline: InlineData, range: Range<Int>) {
            assert(range.lowerBound < HalfInt.max)
            assert(range.upperBound < HalfInt.max)
            self.init(inline.withUnsafeBytes { return __DataStorage(bytes: $0.baseAddress, length: $0.count) }, range: range)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(_ large: LargeSlice) {
            assert(large.range.lowerBound < HalfInt.max)
            assert(large.range.upperBound < HalfInt.max)
            self.init(large.storage, range: large.range)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(_ large: LargeSlice, range: Range<Int>) {
            assert(range.lowerBound < HalfInt.max)
            assert(range.upperBound < HalfInt.max)
            self.init(large.storage, range: range)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a trivial initializer.
        init(_ storage: __DataStorage, count: Int) {
            assert(count < HalfInt.max)
            self.storage = storage
            slice = 0..<HalfInt(count)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a trivial initializer.
        init(_ storage: __DataStorage, range: Range<Int>) {
            assert(range.lowerBound < HalfInt.max)
            assert(range.upperBound < HalfInt.max)
            self.storage = storage
            slice = HalfInt(range.lowerBound)..<HalfInt(range.upperBound)
        }
        
        @inlinable // This is @inlinable as trivially computable (and inlining may help avoid retain-release traffic).
        mutating func ensureUniqueReference() {
            if !isKnownUniquelyReferenced(&storage) {
                storage = storage.mutableCopy(self.range)
            }
        }
        
        @inlinable // This is @inlinable as trivially computable.
        var startIndex: Int {
            return Int(slice.lowerBound)
        }
        
        @inlinable // This is @inlinable as trivially computable.
        var endIndex: Int {
            return Int(slice.upperBound)
        }
        
        @inlinable // This is @inlinable as trivially computable.
        var capacity: Int {
            return storage.capacity
        }

        #if FOUNDATION_FRAMEWORK
        // Legacy ABI entry point for clients built against an older @inlinable reserveCapacity
        @usableFromInline
        @abi(mutating func reserveCapacity(_ minimumCapacity: Int))
        mutating func __legacy_reserveCapacity(_ minimumCapacity: Int) {
            reserveCapacity(minimumCapacity)
        }
        #endif

        #if FOUNDATION_FRAMEWORK
        @abi(mutating func __implementation_reserveCapacity(_ minimumCapacity: Int))
        #endif
        @_alwaysEmitIntoClient // Ensures that newer clients who may be using `__DataStorage.withUninitializedBytes` always use a new copy of reserveCapacity
        mutating func reserveCapacity(_ minimumCapacity: Int) {
            ensureUniqueReference()
            // the current capacity can be zero (representing externally owned buffer), and count can be greater than the capacity
            // Capacity of the storage is relative to the start of the allocation, not start of the slice, so offset by the prefix before the slice
            let prefixLength = startIndex - storage._offset
            storage.ensureUniqueBufferReference(growingTo: prefixLength + Swift.max(minimumCapacity, count))
        }
        
        @inlinable // This is @inlinable as trivially computable.
        var count: Int {
            get {
                // The upper bound is guaranteed to be greater than or equal to the lower bound, and the lower bound must be non-negative so subtraction can never overflow
                return Int(slice.upperBound &- slice.lowerBound)
            }
            set(newValue) {
                assert(newValue < HalfInt.max)
                ensureUniqueReference()
                
                let difference = newValue - count
                if difference > 0 {
                    let additionalRange = Int(slice.upperBound) ..< Int(slice.upperBound) + difference
                    storage.resetBytes(in: additionalRange) // Also extends storage length
                } else {
                    storage.length += difference
                }
                slice = slice.lowerBound..<(slice.lowerBound + HalfInt(newValue))
            }
        }
        
        @inlinable // This is @inlinable as trivially computable.
        var range: Range<Int> {
            get {
                return Int(slice.lowerBound)..<Int(slice.upperBound)
            }
            set(newValue) {
                assert(newValue.lowerBound < HalfInt.max)
                assert(newValue.upperBound < HalfInt.max)
                slice = HalfInt(newValue.lowerBound)..<HalfInt(newValue.upperBound)
            }
        }
        
        @inlinable // This is @inlinable as a generic, trivially forwarding function.
        func withUnsafeBytes<Result>(_ apply: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
            return try storage.withUnsafeBytes(in: range, apply: apply)
        }
        
        @inlinable // This is @inlinable as a generic, trivially forwarding function.
        mutating func withUnsafeMutableBytes<Result>(_ apply: (UnsafeMutableRawBufferPointer) throws -> Result) rethrows -> Result {
            ensureUniqueReference()
            return try storage.withUnsafeMutableBytes(in: range, apply: apply)
        }
        
        @inlinable // This is @inlinable as reasonably small.
        mutating func append(contentsOf buffer: UnsafeRawBufferPointer) {
            assert(endIndex + buffer.count < HalfInt.max)
            ensureUniqueReference()
            storage.replaceBytes(
                in: (
                    location: range.upperBound,
                    length: storage.length - (range.upperBound - storage._offset)),
                with: buffer.baseAddress,
                length: buffer.count)
            slice = slice.lowerBound..<HalfInt(Int(slice.upperBound) + buffer.count)
        }
        
        @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
        @_alwaysEmitIntoClient
        mutating func append<E: Error>(
            _ extraCapacity: Int, _ initializer: (inout OutputRawSpan) throws(E) -> Void
        ) throws(E) {
            assert(count + extraCapacity < HalfInt.max)
            reserveCapacity(count + extraCapacity)
            var appendedCount = 0
            defer {
                slice = slice.lowerBound..<(slice.upperBound + HalfInt(appendedCount))
            }
            try storage.withUninitializedBytes(extraCapacity: extraCapacity, location: endIndex, &appendedCount, initializer)
        }

        @inlinable // This is @inlinable as reasonably small.
        subscript(index: Index) -> UInt8 {
            get {
                assert(index < HalfInt.max)
                precondition(startIndex <= index, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                precondition(index < endIndex, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                return storage.get(index)
            }
            set(newValue) {
                assert(index < HalfInt.max)
                precondition(startIndex <= index, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                precondition(index < endIndex, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                ensureUniqueReference()
                storage.set(index, to: newValue)
            }
        }
        
        @inlinable // This is @inlinable as reasonably small.
        mutating func resetBytes(in range: Range<Index>) {
            assert(range.lowerBound < HalfInt.max)
            assert(range.upperBound < HalfInt.max)
            precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            ensureUniqueReference()
            storage.resetBytes(in: range)
            if slice.upperBound < range.upperBound {
                slice = slice.lowerBound..<HalfInt(range.upperBound)
            }
        }
        
        @inlinable // This is @inlinable as reasonably small.
        mutating func replaceSubrange(_ subrange: Range<Index>, with bytes: UnsafeRawPointer?, count cnt: Int) {
            precondition(startIndex <= subrange.lowerBound, "index \(subrange.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(subrange.lowerBound <= endIndex, "index \(subrange.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(startIndex <= subrange.upperBound, "index \(subrange.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(subrange.upperBound <= endIndex, "index \(subrange.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            
            ensureUniqueReference()
            let upper = range.upperBound
            let nsRange = (
                location: subrange.lowerBound,
                length: subrange.upperBound - subrange.lowerBound)
            storage.replaceBytes(in: nsRange, with: bytes, length: cnt)
            let resultingUpper = upper - (subrange.upperBound - subrange.lowerBound) + cnt
            slice = slice.lowerBound..<HalfInt(resultingUpper)
        }
        
        @inlinable // This is @inlinable as reasonably small.
        func copyBytes(to pointer: UnsafeMutableRawPointer, from range: Range<Int>) {
            precondition(startIndex <= range.lowerBound, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(startIndex <= range.upperBound, "index \(range.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(range.upperBound <= endIndex, "index \(range.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            storage.copyBytes(to: pointer, from: range)
        }
        
        @inline(__always) // This should always be inlined into _Representation.hash(into:).
        func hash(into hasher: inout Hasher) {
            hasher.combine(count)
            
            self.withUnsafeBytes { bytes in
                hasher.combine(bytes: bytes)
            }
        }
    }
}

#endif
