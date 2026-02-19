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

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {
    /// An iterator over the contents of the data.
    ///
    /// The iterator will increment byte-by-byte.
    @inlinable // This is @inlinable as trivially computable.
    public func makeIterator() -> Data.Iterator {
        return Iterator(self, at: startIndex)
    }
    
    public struct Iterator : IteratorProtocol, Sendable {
        @usableFromInline
        internal typealias Buffer = (
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
        
        @usableFromInline internal let _data: Data
        @usableFromInline internal var _buffer: Buffer
        @usableFromInline internal var _idx: Data.Index
        @usableFromInline internal let _endIdx: Data.Index
        
        @usableFromInline // This is @usableFromInline as a non-trivial initializer.
        internal init(_ data: Data, at loc: Data.Index) {
            // The let vars prevent this from being marked as @inlinable
            _data = data
            _buffer = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
            _idx = loc
            _endIdx = data.endIndex
            
            let bufferSize = MemoryLayout<Buffer>.size
            Swift.withUnsafeMutableBytes(of: &_buffer) {
                $0.withMemoryRebound(to: UInt8.self) { [endIndex = data.endIndex] buf in
                    let bufferIdx = (loc - data.startIndex) % bufferSize
                    let end = (endIndex - (loc - bufferIdx) > bufferSize) ? (loc - bufferIdx + bufferSize) : endIndex
                    data.copyBytes(to: buf, from: (loc - bufferIdx)..<end)
                }
            }
        }
        
        public mutating func next() -> UInt8? {
            let idx = _idx
            let bufferSize = MemoryLayout<Buffer>.size
            
            guard idx < _endIdx else { return nil }
            _idx += 1
            
            let bufferIdx = (idx - _data.startIndex) % bufferSize
            
            
            if bufferIdx == 0 {
                var buffer = _buffer
                Swift.withUnsafeMutableBytes(of: &buffer) {
                    $0.withMemoryRebound(to: UInt8.self) {
                        // populate the buffer
                        _data.copyBytes(to: $0, from: idx..<(_endIdx - idx > bufferSize ? idx + bufferSize : _endIdx))
                    }
                }
                _buffer = buffer
            }
            
            return Swift.withUnsafeMutableBytes(of: &_buffer) {
                $0.load(fromByteOffset: bufferIdx, as: UInt8.self)
            }
        }
    }
}
