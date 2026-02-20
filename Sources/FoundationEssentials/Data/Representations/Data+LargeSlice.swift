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

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {
    // A reference wrapper around a Range<Int> for when the range of a data buffer is too large to whole in a single word.
    // Inlinability strategy: everything should be inlinable as trivial.
    @usableFromInline
    @_fixed_layout
    internal final class RangeReference : @unchecked Sendable {
        @usableFromInline var range: Range<Int>
        
        @inlinable @inline(__always) // This is @inlinable as trivially forwarding.
        var lowerBound: Int {
            return range.lowerBound
        }
        
        @inlinable @inline(__always) // This is @inlinable as trivially forwarding.
        var upperBound: Int {
            return range.upperBound
        }
        
        @inlinable @inline(__always) // This is @inlinable as trivially computable.
        var count: Int {
            // The upper bound is guaranteed to be greater than or equal to the lower bound, and the lower bound must be non-negative so subtraction can never overflow
            return range.upperBound &- range.lowerBound
        }
        
        @inlinable @inline(__always) // This is @inlinable as a trivial initializer.
        init(_ range: Range<Int>) {
            self.range = range
        }
    }
    
    // A buffer of bytes whose range is too large to fit in a single word. Used alongside a RangeReference to make it fit into _Representation's two-word size.
    // Inlinability strategy: everything here should be easily inlinable as large _DataStorage methods should not inline into here.
    @usableFromInline
    @frozen
    internal struct LargeSlice : Sendable {
        // ***WARNING***
        // These ivars are specifically laid out so that they cause the enum _Representation to be 16 bytes on 64 bit platforms. This means we _MUST_ have the class type thing last
        @usableFromInline var slice: RangeReference
        @usableFromInline var storage: __DataStorage
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(_ buffer: UnsafeRawBufferPointer) {
            self.init(__DataStorage(bytes: buffer.baseAddress, length: buffer.count), count: buffer.count)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(capacity: Int) {
            self.init(__DataStorage(capacity: capacity), count: 0)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(count: Int) {
            self.init(__DataStorage(length: count), count: count)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(_ inline: InlineData) {
            let storage = inline.withUnsafeBytes { return __DataStorage(bytes: $0.baseAddress, length: $0.count) }
            self.init(storage, count: inline.count)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a trivial initializer.
        init(_ slice: InlineSlice) {
            self.storage = slice.storage
            self.slice = RangeReference(slice.range)
        }
        
        @inlinable @inline(__always) // This is @inlinable as a trivial initializer.
        init(_ storage: __DataStorage, count: Int) {
            self.storage = storage
            self.slice = RangeReference(0..<count)
        }
        
        // Not exposed as ABI and only usable by internal, non-inlined code and therefore not @inlinable
        @inline(__always)
        init(_ storage: __DataStorage, range: Range<Int>) {
            self.storage = storage
            self.slice = RangeReference(range)
        }
        
        @inlinable // This is @inlinable as trivially computable (and inlining may help avoid retain-release traffic).
        mutating func ensureUniqueReference() {
            if !isKnownUniquelyReferenced(&storage) {
                storage = storage.mutableCopy(range)
            }
            if !isKnownUniquelyReferenced(&slice) {
                slice = RangeReference(range)
            }
        }
        
        @inlinable // This is @inlinable as trivially forwarding.
        var startIndex: Int {
            return slice.range.lowerBound
        }
        
        @inlinable // This is @inlinable as trivially forwarding.
        var endIndex: Int {
            return slice.range.upperBound
        }
        
        @inlinable // This is @inlinable as trivially forwarding.
        var capacity: Int {
            return storage.capacity
        }
        
        @inlinable // This is @inlinable as trivially computable.
        mutating func reserveCapacity(_ minimumCapacity: Int) {
            ensureUniqueReference()
            // the current capacity can be zero (representing externally owned buffer), and count can be greater than the capacity
            storage.ensureUniqueBufferReference(growingTo: Swift.max(minimumCapacity, count))
        }
        
        @inlinable // This is @inlinable as trivially computable.
        var count: Int {
            get {
                return slice.count
            }
            set(newValue) {
                ensureUniqueReference()
                let difference = newValue - count
                if difference > 0 {
                    let additionalRange = Int(slice.upperBound) ..< Int(slice.upperBound) + difference
                    storage.resetBytes(in: additionalRange) // Already sets the length
                } else {
                    storage.length += difference
                }
                slice.range = slice.range.lowerBound..<(slice.range.lowerBound + newValue)
            }
        }
        
        @inlinable // This is @inlinable as it is trivially forwarding.
        var range: Range<Int> {
            return slice.range
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
            ensureUniqueReference()
            storage.replaceBytes(
                in: (
                    location: range.upperBound,
                    length: storage.length - (range.upperBound - storage._offset)),
                with: buffer.baseAddress,
                length: buffer.count)
            slice.range = slice.range.lowerBound..<slice.range.upperBound + buffer.count
        }
        
        @_alwaysEmitIntoClient
        mutating func append<E: Error>(
            _ newCapacity: Int, _ initializer: (inout OutputRawSpan) throws(E) -> Void
        ) throws(E) {
            reserveCapacity(newCapacity)
            var appendedCount = 0
            defer {
                slice.range = slice.range.lowerBound..<(slice.range.upperBound + appendedCount)
            }
            try storage.withUninitializedBytes(newCapacity, &appendedCount, initializer)
        }

        @inlinable // This is @inlinable as trivially computable.
        subscript(index: Index) -> UInt8 {
            get {
                precondition(startIndex <= index, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                precondition(index < endIndex, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                return storage.get(index)
            }
            set(newValue) {
                precondition(startIndex <= index, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                precondition(index < endIndex, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                ensureUniqueReference()
                storage.set(index, to: newValue)
            }
        }
        
        @inlinable // This is @inlinable as reasonably small.
        mutating func resetBytes(in range: Range<Int>) {
            precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            ensureUniqueReference()
            storage.resetBytes(in: range)
            if slice.range.upperBound < range.upperBound {
                slice.range = slice.range.lowerBound..<range.upperBound
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
            slice.range = slice.range.lowerBound..<resultingUpper
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
