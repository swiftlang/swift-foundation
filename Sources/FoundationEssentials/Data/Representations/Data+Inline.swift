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

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(ucrt)
import ucrt
#elseif canImport(WASILibc)
@preconcurrency import WASILibc
#elseif canImport(Bionic)
@preconcurrency import Bionic
#endif

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {
    // A small inline buffer of bytes suitable for stack-allocation of small data.
    // Inlinability strategy: everything here should be inlined for direct operation on the stack wherever possible.
    @usableFromInline
    @frozen
    internal struct InlineData : Sendable {
#if _pointerBitWidth(_64)
        @usableFromInline typealias Buffer = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                              UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) //len  //enum
        @usableFromInline var bytes: Buffer
#elseif _pointerBitWidth(_32)
        @usableFromInline typealias Buffer = (UInt8, UInt8, UInt8, UInt8,
                                              UInt8, UInt8) //len  //enum
        @usableFromInline var bytes: Buffer
#else
#error ("Unsupported architecture: a definition of Buffer needs to be made with N = (MemoryLayout<(Int, Int)>.size - 2) UInt8 members to a tuple")
#endif
        @usableFromInline var length: UInt8
        
        @inlinable @inline(__always) // This is @inlinable as trivially computable.
        static func canStore(count: Int) -> Bool {
            return count <= MemoryLayout<Buffer>.size
        }
        
        static var maximumCapacity: Int {
            return MemoryLayout<Buffer>.size
        }
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(_ srcBuffer: UnsafeRawBufferPointer) {
            self.init(count: srcBuffer.count)
            if !srcBuffer.isEmpty {
                Swift.withUnsafeMutableBytes(of: &bytes) { dstBuffer in
                    dstBuffer.baseAddress?.copyMemory(from: srcBuffer.baseAddress!, byteCount: srcBuffer.count)
                }
            }
        }
        
        @inlinable @inline(__always) // This is @inlinable as a trivial initializer.
        init(count: Int = 0) {
            assert(count <= MemoryLayout<Buffer>.size)
#if _pointerBitWidth(_64)
            bytes = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
#elseif _pointerBitWidth(_32)
            bytes = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
#else
#error ("Unsupported architecture: initialization for Buffer is required for this architecture")
#endif
            length = UInt8(count)
        }
        
        @_alwaysEmitIntoClient @inline(__always)
        init<E: Error>(
            rawCapacity: Int,
            initializingWith initializer: (inout OutputRawSpan) throws(E) -> Void
        ) throws(E) {
            self.init()
            do throws(E) {
                let count = try Swift.withUnsafeMutableBytes(of: &bytes) {
                    buffer throws(E) in
                    var output = OutputRawSpan(buffer: buffer, initializedCount: 0)
                    try initializer(&output)
                    return output.finalize(for: buffer)
                }
                assert(count <= rawCapacity)
                length = UInt8(count)
            } catch {
                self = .init()
                throw error
            }
        }

        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(_ slice: InlineSlice, count: Int) {
            self.init(count: count)
            Swift.withUnsafeMutableBytes(of: &bytes) { dstBuffer in
                slice.withUnsafeBytes { srcBuffer in
                    dstBuffer.copyMemory(from: UnsafeRawBufferPointer(start: srcBuffer.baseAddress, count: count))
                }
            }
        }
        
        @inlinable @inline(__always) // This is @inlinable as a convenience initializer.
        init(_ slice: LargeSlice, count: Int) {
            self.init(count: count)
            Swift.withUnsafeMutableBytes(of: &bytes) { dstBuffer in
                slice.withUnsafeBytes { srcBuffer in
                    dstBuffer.copyMemory(from: UnsafeRawBufferPointer(start: srcBuffer.baseAddress, count: count))
                }
            }
        }
        
        @inlinable // This is @inlinable as trivially computable.
        var capacity: Int {
            return MemoryLayout<Buffer>.size
        }
        
        @inlinable // This is @inlinable as trivially computable.
        var count: Int {
            get {
                return Int(length)
            }
            set(newValue) {
                assert(newValue <= MemoryLayout<Buffer>.size)
                if newValue > length {
                    resetBytes(in: Int(length) ..< newValue) // Also extends length
                } else {
                    length = UInt8(newValue)
                }
            }
        }
        
        @inlinable // This is @inlinable as trivially computable.
        var startIndex: Int {
            return 0
        }
        
        @inlinable // This is @inlinable as trivially computable.
        var endIndex: Int {
            return count
        }
        
        @inlinable // This is @inlinable as a generic, trivially forwarding function.
        func withUnsafeBytes<Result>(_ apply: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
            let count = Int(length)
            return try Swift.withUnsafeBytes(of: bytes) { (rawBuffer) throws -> Result in
                return try apply(UnsafeRawBufferPointer(start: rawBuffer.baseAddress, count: count))
            }
        }
        
        @inlinable // This is @inlinable as a generic, trivially forwarding function.
        mutating func withUnsafeMutableBytes<Result>(_ apply: (UnsafeMutableRawBufferPointer) throws -> Result) rethrows -> Result {
            let count = Int(length)
            return try Swift.withUnsafeMutableBytes(of: &bytes) { (rawBuffer) throws -> Result in
                return try apply(UnsafeMutableRawBufferPointer(start: rawBuffer.baseAddress, count: count))
            }
        }
        
        @inlinable // This is @inlinable as trivially computable.
        mutating func append(byte: UInt8) {
            let count = self.count
            assert(count + 1 <= MemoryLayout<Buffer>.size)
            Swift.withUnsafeMutableBytes(of: &bytes) { $0[count] = byte }
            self.length += 1
        }
        
        @inlinable // This is @inlinable as trivially computable.
        mutating func append(contentsOf buffer: UnsafeRawBufferPointer) {
            guard !buffer.isEmpty else { return }
            assert(count + buffer.count <= MemoryLayout<Buffer>.size)
            let cnt = count
            _ = Swift.withUnsafeMutableBytes(of: &bytes) { rawBuffer in
                rawBuffer.baseAddress?.advanced(by: cnt).copyMemory(from: buffer.baseAddress!, byteCount: buffer.count)
            }
            
            length += UInt8(buffer.count)
        }
        
        @_alwaysEmitIntoClient
        mutating func append<E: Error>(
            _ newCapacity: Int, _ initializer: (inout OutputRawSpan) throws(E) -> Void
        ) throws(E) {
            assert(newCapacity <= capacity)
            let oldCount = self.count
            var addedCount = 0
            try Swift.withUnsafeMutableBytes(of: &bytes) {
                buffer throws(E) in
                let suffix = buffer.suffix(from: oldCount)
                var span = OutputRawSpan(buffer: suffix, initializedCount: 0)
                defer {
                    addedCount = unsafe span.finalize(for: suffix)
                    assert(oldCount+addedCount <= newCapacity)
                    span = OutputRawSpan()
                }
                try initializer(&span)
            }
            length = UInt8(oldCount+addedCount)
        }

        @inlinable // This is @inlinable as trivially computable.
        subscript(index: Index) -> UInt8 {
            get {
                assert(index <= MemoryLayout<Buffer>.size)
                precondition(index < length, "index \(index) is out of bounds of 0..<\(length)")
                return Swift.withUnsafeBytes(of: bytes) { rawBuffer -> UInt8 in
                    return rawBuffer[index]
                }
            }
            set(newValue) {
                assert(index <= MemoryLayout<Buffer>.size)
                precondition(index < length, "index \(index) is out of bounds of 0..<\(length)")
                Swift.withUnsafeMutableBytes(of: &bytes) { rawBuffer in
                    rawBuffer[index] = newValue
                }
            }
        }
        
        @inlinable // This is @inlinable as trivially computable.
        mutating func resetBytes(in range: Range<Index>) {
            assert(range.lowerBound <= MemoryLayout<Buffer>.size)
            assert(range.upperBound <= MemoryLayout<Buffer>.size)
            precondition(range.lowerBound <= length, "index \(range.lowerBound) is out of bounds of 0..<\(length)")
            if length < range.upperBound {
                length = UInt8(range.upperBound)
            }
            
            let _ = Swift.withUnsafeMutableBytes(of: &bytes) { rawBuffer in
                memset(rawBuffer.baseAddress!.advanced(by: range.lowerBound), 0, range.upperBound - range.lowerBound)
            }
        }
        
        @usableFromInline // This is not @inlinable as it is a non-trivial, non-generic function.
        mutating func replaceSubrange(_ subrange: Range<Index>, with replacementBytes: UnsafeRawPointer?, count replacementLength: Int) {
            assert(subrange.lowerBound <= MemoryLayout<Buffer>.size)
            assert(subrange.upperBound <= MemoryLayout<Buffer>.size)
            assert(count - (subrange.upperBound - subrange.lowerBound) + replacementLength <= MemoryLayout<Buffer>.size)
            precondition(subrange.lowerBound <= length, "index \(subrange.lowerBound) is out of bounds of 0..<\(length)")
            precondition(subrange.upperBound <= length, "index \(subrange.upperBound) is out of bounds of 0..<\(length)")
            let currentLength = count
            let resultingLength = currentLength - (subrange.upperBound - subrange.lowerBound) + replacementLength
            let shift = resultingLength - currentLength
            Swift.withUnsafeMutableBytes(of: &bytes) { mutableBytes in
                /* shift the trailing bytes */
                let start = subrange.lowerBound
                let length = subrange.upperBound - subrange.lowerBound
                if shift != 0 {
                    memmove(mutableBytes.baseAddress!.advanced(by: start + replacementLength), mutableBytes.baseAddress!.advanced(by: start + length), currentLength - start - length)
                }
                if replacementLength != 0 {
                    memmove(mutableBytes.baseAddress!.advanced(by: start), replacementBytes!, replacementLength)
                }
            }
            length = UInt8(resultingLength)
        }
        
        @inlinable // This is @inlinable as trivially computable.
        func copyBytes(to pointer: UnsafeMutableRawPointer, from range: Range<Int>) {
            precondition(startIndex <= range.lowerBound, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(startIndex <= range.upperBound, "index \(range.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(range.upperBound <= endIndex, "index \(range.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            
            Swift.withUnsafeBytes(of: bytes) {
                let cnt = Swift.min($0.count, range.upperBound - range.lowerBound)
                guard cnt > 0 else { return }
                pointer.copyMemory(from: $0.baseAddress!.advanced(by: range.lowerBound), byteCount: cnt)
            }
        }
        
        @inline(__always) // This should always be inlined into _Representation.hash(into:).
        func hash(into hasher: inout Hasher) {
            // **NOTE**: this uses `count` (an Int) and NOT `length` (a UInt8)
            //           Despite having the same value, they hash differently. InlineSlice and LargeSlice both use `count` (an Int); if you combine the same bytes but with `length` over `count`, you can get a different hash.
            //
            // This affects slices, which are InlineSlice and not InlineData:
            //
            //   let d = Data([0xFF, 0xFF])                // InlineData
            //   let s = Data([0, 0xFF, 0xFF]).dropFirst() // InlineSlice
            //   assert(s == d)
            //   assert(s.hashValue == d.hashValue)
            hasher.combine(count)
            
            Swift.withUnsafeBytes(of: bytes) {
                // We have access to the full byte buffer here, but not all of it is meaningfully used (bytes past self.length may be garbage).
                let bytes = UnsafeRawBufferPointer(start: $0.baseAddress, count: self.count)
                hasher.combine(bytes: bytes)
            }
        }
    }
}
