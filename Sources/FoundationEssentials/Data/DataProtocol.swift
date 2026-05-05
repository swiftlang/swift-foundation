//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2018-2025 Apple Inc. and the Swift project authors
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
#elseif canImport(stdlib_h)
import stdlib_h
#endif

//===--- DataProtocol -----------------------------------------------------===//

/// A protocol that provides consistent data access to the bytes underlying contiguous and noncontiguous data buffers.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public protocol DataProtocol : RandomAccessCollection where Element == UInt8, SubSequence : DataProtocol {
    // FIXME: Remove in favor of opaque type on `regions`.
    /// A type that represents a collection of contiguous parts that make up the type conforming to a data protocol.
    associatedtype Regions: BidirectionalCollection where Regions.Element : DataProtocol & ContiguousBytes, Regions.Element.SubSequence : ContiguousBytes

    /// A collection of buffers that make up the whole of the type conforming to a data protocol.
    var regions: Regions { get }

    /// Returns the first found range of the given data buffer.
    ///
    /// A default implementation is given in terms of `self.regions`.
    ///
    /// - Parameters:
    ///   - of: The data sequence to find.
    ///   - in: A range to limit the scope of the search.
    /// - Returns: The range, if found, of the first match of the provided data sequence.
    func firstRange<D: DataProtocol, R: RangeExpression>(of: D, in: R) -> Range<Index>? where R.Bound == Index

    /// Returns the last found range of the given data buffer.
    ///
    /// A default implementation is given in terms of `self.regions`.
    ///
    /// - Parameters:
    ///   - of: The data sequence to find.
    ///   - in: A range to limit the scope of the search.
    /// - Returns: The range, if found, of the last match of the provided data sequence.
    func lastRange<D: DataProtocol, R: RangeExpression>(of: D, in: R) -> Range<Index>? where R.Bound == Index

    /// Copies `count` bytes from the start of the buffer to the destination
    /// buffer.
    ///
    /// A default implementation is given in terms of `copyBytes(to:from:)`.
    ///
    /// - Parameters:
    ///   - to: A pointer to the raw memory buffer you want to copy the bytes into.
    ///   - count: The number of bytes to copy.
    /// - Returns: The number of bytes copied.
    @discardableResult
    func copyBytes(to: UnsafeMutableRawBufferPointer, count: Int) -> Int

    /// Copies `count` bytes from the start of the buffer to the destination
    /// buffer.
    ///
    /// A default implementation is given in terms of `copyBytes(to:from:)`.
    ///
    /// - Parameters:
    ///   - to: A typed pointer to the buffer you want to copy the bytes into.
    ///   - count: The number of bytes to copy.
    /// - Returns: The number of bytes copied.
    @discardableResult
    func copyBytes<DestinationType>(to: UnsafeMutableBufferPointer<DestinationType>, count: Int) -> Int

    /// Copies the bytes from the given range to the destination buffer.
    ///
    /// A default implementation is given in terms of `self.regions`.
    ///
    /// - Parameters:
    ///   - to: A pointer to the raw memory buffer you want to copy the bytes into.
    ///   - from: The range of bytes to copy.
    /// - Returns: The number of bytes copied.
    @discardableResult
    func copyBytes<R: RangeExpression>(to: UnsafeMutableRawBufferPointer, from: R) -> Int where R.Bound == Index

    /// Copies the bytes from the given range to the destination buffer.
    ///
    /// A default implementation is given in terms of `self.regions`.
    ///
    /// - Parameters:
    ///   - to: A typed pointer to the buffer you want to copy the bytes into.
    ///   - from: The range of bytes to copy.
    /// - Returns: The number of bytes copied.
    @discardableResult
    func copyBytes<DestinationType, R: RangeExpression>(to: UnsafeMutableBufferPointer<DestinationType>, from: R) -> Int where R.Bound == Index
}

//===--- MutableDataProtocol ----------------------------------------------===//

/// A protocol that provides consistent data access to the bytes underlying contiguous and noncontiguous mutable data buffers.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public protocol MutableDataProtocol : DataProtocol, MutableCollection, RangeReplaceableCollection {
    /// Replaces the contents of the data buffer with zeros for the provided range.
    ///
    /// The following example sets the bytes to zero for the bytes identified by
    /// the provided range:
    ///
    /// ```swift
    /// var dest: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
    /// dest.resetBytes(in: 1...3)
    /// // dest = [0xFF, 0x00, 0x00, 0x00, 0xFF, 0xFF]
    /// ```
    ///
    /// A default implementation is given in terms of
    /// `replaceSubrange(_:with:)`.
    ///
    /// - Parameter range: The range of bytes to replace with zeros.
    mutating func resetBytes<R: RangeExpression>(in range: R) where R.Bound == Index
}

//===--- DataProtocol Extensions ------------------------------------------===//

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension DataProtocol {
    /// Returns the first found range of the type's data buffer.
    ///
    /// - Parameter data: The data sequence to find.
    /// - Returns: The range, if found, of the first match of the provided data sequence.
    ///
    /// An example of searching a data buffer converted from a string:
    ///
    /// ```swift
    /// let data = "0123456789".data(using: .utf8)!
    /// let pattern = "456".data(using: .utf8)!
    /// let foundRange = data.firstRange(of: pattern)
    ///
    /// // foundRange == Range(4..<7)
    /// ```
    public func firstRange<D: DataProtocol>(of data: D) -> Range<Index>? {
        return self.firstRange(of: data, in: self.startIndex ..< self.endIndex)
    }

    /// Returns the last found range of the type's data buffer.
    ///
    /// - Parameter data: The data sequence to find.
    /// - Returns: The range, if found, of the last match of the provided data sequence.
    ///
    /// An example of searching a data buffer for the last match:
    ///
    /// ```swift
    /// let data: [UInt8] = [0, 1, 2, 3, 0, 1, 2, 3]
    /// let pattern: [UInt8] = [2, 3]
    ///
    /// let match = data.lastRange(of: pattern)
    /// // match == 6..<8
    /// ```
    public func lastRange<D: DataProtocol>(of data: D) -> Range<Index>? {
        return self.lastRange(of: data, in: self.startIndex ..< self.endIndex)
    }

    /// Copies the bytes of data from the type into a raw memory buffer.
    ///
    /// The following example copies the bytes from the raw memory buffer into the provided
    /// raw memory buffer:
    ///
    /// ```swift
    /// let source: [UInt8] = [0, 1, 2]
    /// var dest: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
    /// dest.withUnsafeMutableBytes { destBufferPtr in
    ///     let count = source.copyBytes(to: destBufferPtr)
    ///     // count == 3
    /// }
    /// // dest = [0x00, 0x01, 0x02, 0xFF, 0xFF, 0xFF]
    /// ```
    ///
    /// - Parameter ptr: A pointer to the raw memory buffer you want to copy the bytes into.
    /// - Returns: The number of bytes copied.
    @discardableResult
    public func copyBytes(to ptr: UnsafeMutableRawBufferPointer) -> Int {
        return copyBytes(to: ptr, from: self.startIndex ..< self.endIndex)
    }

    /// Copies the bytes of data from the type into a typed memory buffer.
    ///
    /// The following example copies the bytes from a typed memory buffer into the provided
    /// typed memory buffer:
    ///
    /// ```swift
    /// let source: [UInt8] = [0, 1, 2]
    /// var dest: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
    /// dest.withUnsafeMutableBufferPointer { typedMemBuffer in
    ///     let count = source.copyBytes(to: typedMemBuffer)
    ///     // count == 3
    /// }
    /// // dest = [0x00, 0x01, 0x02, 0xFF, 0xFF, 0xFF]
    /// ```
    ///
    /// - Parameter ptr: A typed pointer to the buffer you want to copy the bytes into.
    /// - Returns: The number of bytes copied.
    @discardableResult
    public func copyBytes<DestinationType>(to ptr: UnsafeMutableBufferPointer<DestinationType>) -> Int {
        return copyBytes(to: ptr, from: self.startIndex ..< self.endIndex)
    }

    /// Copies the provided number of bytes from the start of the type into a raw memory buffer.
    ///
    /// The following example copies the number of bytes that `count` identified from the
    /// beginning of the raw memory buffer into the provided raw memory buffer:
    ///
    /// ```swift
    /// let source: [UInt8] = [0, 1, 2]
    /// var dest: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
    /// dest.withUnsafeMutableBytes { destBufferPtr in
    ///     let count = source.copyBytes(to: destBufferPtr, count: 2)
    ///     // count == 2
    /// }
    /// // dest = [0x00, 0x01, 0xFF, 0xFF, 0xFF, 0xFF]
    /// ```
    ///
    /// - Parameters:
    ///   - ptr: A pointer to the raw memory buffer you want to copy the bytes into.
    ///   - count: The number of bytes to copy.
    /// - Returns: The number of bytes copied.
    @discardableResult
    public func copyBytes(to ptr: UnsafeMutableRawBufferPointer, count: Int) -> Int {
        return copyBytes(to: ptr, from: self.startIndex ..< self.index(self.startIndex, offsetBy: count))
    }

    /// Copies the provided number of bytes from the start of the type into a typed memory buffer.
    ///
    /// - Parameters:
    ///   - ptr: A typed pointer to the buffer you want to copy the bytes into.
    ///   - count: The number of bytes to copy.
    /// - Returns: The number of bytes copied.
    @discardableResult
    public func copyBytes<DestinationType>(to ptr: UnsafeMutableBufferPointer<DestinationType>, count: Int) -> Int {
        return copyBytes(to: ptr, from: self.startIndex ..< self.index(self.startIndex, offsetBy: count))
    }

    /// Copies a range of the bytes from the type into a raw memory buffer.
    ///
    /// - Parameters:
    ///   - ptr: A pointer to the raw memory buffer you want to copy the bytes into.
    ///   - range: The range of bytes to copy.
    /// - Returns: The number of bytes copied.
    @discardableResult
    public func copyBytes<R: RangeExpression>(to ptr: UnsafeMutableRawBufferPointer, from range: R) -> Int where R.Bound == Index {
        precondition(ptr.baseAddress != nil)

        let concreteRange = range.relative(to: self)
        let slice = self[concreteRange]

        // The type isn't contiguous, so we need to copy one region at a time.
        var offset = 0
        let rangeCount = distance(from: concreteRange.lowerBound, to: concreteRange.upperBound)
        var amountToCopy = Swift.min(ptr.count, rangeCount)
        for region in slice.regions {
            guard amountToCopy > 0 else {
                break
            }

            region.withUnsafeBytes { buffer in
                let offsetPtr = UnsafeMutableRawBufferPointer(rebasing: ptr[offset...])
                let buf = UnsafeRawBufferPointer(start: buffer.baseAddress, count: Swift.min(buffer.count, amountToCopy))
                offsetPtr.copyMemory(from: buf)
                offset += buf.count
                amountToCopy -= buf.count
            }
        }

        return offset
    }

    /// Copies a range of the bytes from the type into a typed memory buffer.
    ///
    /// - Parameters:
    ///   - ptr: A typed pointer to the buffer you want to copy the bytes into.
    ///   - range: The range of bytes to copy.
    /// - Returns: The number of bytes copied.
    @discardableResult
    public func copyBytes<DestinationType, R: RangeExpression>(to ptr: UnsafeMutableBufferPointer<DestinationType>, from range: R) -> Int where R.Bound == Index {
        return self.copyBytes(to: UnsafeMutableRawBufferPointer(start: ptr.baseAddress, count: ptr.count * MemoryLayout<DestinationType>.stride), from: range)
    }

    private func matches<D: DataProtocol>(_ data: D, from index: Index) -> Bool {
        var haystackIndex = index
        var needleIndex = data.startIndex

        while true {
            guard self[haystackIndex] == data[needleIndex] else { return false }

            haystackIndex = self.index(after: haystackIndex)
            needleIndex = data.index(after: needleIndex)
            if needleIndex == data.endIndex {
                // i.e. needle is found.
                return true
            } else if haystackIndex == endIndex {
                return false
            }
        }
    }

    /// Returns the first found range of the type's data buffer within the specified range.
    ///
    /// - Parameters:
    ///   - data: The data sequence to find.
    ///   - range: A range to limit the scope of the search.
    /// - Returns: The range, if found, of the first match of the provided data sequence.
    ///
    /// An example of searching a constrained range within a data buffer for the first match:
    ///
    /// ```swift
    /// let data: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    /// let pattern: [UInt8] = [2, 3, 4]
    ///
    /// let possibleMatch = data.firstRange(of: pattern, in: 5...9)
    /// // possibleMatch == nil
    ///
    /// let match = data.firstRange(of: pattern, in: 2...9)
    /// // match == 2..<5
    /// ```
    public func firstRange<D: DataProtocol, R: RangeExpression>(of data: D, in range: R) -> Range<Index>? where R.Bound == Index {
        let r = range.relative(to: self)
        let length = data.count

        if length == 0 || length > distance(from: r.lowerBound, to: r.upperBound) {
            return nil
        }

        var position = r.lowerBound
        while position < r.upperBound && distance(from: position, to: r.upperBound) >= length {
            if matches(data, from: position) {
                return position..<index(position, offsetBy: length)
            }
            position = index(after: position)
        }
        return nil
    }

    /// Returns the last found range of the type's data buffer within the specified range.
    ///
    /// - Parameters:
    ///   - data: The data sequence to find.
    ///   - range: A range to limit the scope of the search.
    /// - Returns: The range, if found, of the last match of the provided data sequence.
    public func lastRange<D: DataProtocol, R: RangeExpression>(of data: D, in range: R) -> Range<Index>? where R.Bound == Index {
        let r = range.relative(to: self)
        let length = data.count

        if length == 0 || length > distance(from: r.lowerBound, to: r.upperBound) {
            return nil
        }

        var position = index(r.upperBound, offsetBy: -length)
        while position >= r.lowerBound {
            if matches(data, from: position) {
                return position..<index(position, offsetBy: length)
            }
            position = index(before: position)
        }
        return nil
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension DataProtocol where Self : ContiguousBytes {
    /// Copies a range of the bytes from the type into a typed memory buffer.
    ///
    /// This specialization is available when the conforming type also conforms to
    /// `ContiguousBytes`, and copies bytes directly using `memcpy` for better performance.
    ///
    /// - Parameters:
    ///   - ptr: A typed pointer to the buffer you want to copy the bytes into.
    ///   - range: The range of bytes to copy.
    public func copyBytes<DestinationType, R: RangeExpression>(to ptr: UnsafeMutableBufferPointer<DestinationType>, from range: R) where R.Bound == Index {
        precondition(ptr.baseAddress != nil)
        
        let concreteRange = range.relative(to: self)
        withUnsafeBytes { fullBuffer in
            let adv = distance(from: startIndex, to: concreteRange.lowerBound)
            let delta = distance(from: concreteRange.lowerBound, to: concreteRange.upperBound)
            _ = memcpy(ptr.baseAddress!, fullBuffer.baseAddress!.advanced(by: adv), delta)
        }
    }
}

//===--- MutableDataProtocol Extensions -----------------------------------===//

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension MutableDataProtocol {
    /// Replaces the contents of the data buffer with zeros for the provided range.
    ///
    /// - Parameter range: The range of bytes to replace with zeros.
    public mutating func resetBytes<R: RangeExpression>(in range: R) where R.Bound == Index {
        let r = range.relative(to: self)
        let count = distance(from: r.lowerBound, to: r.upperBound)
        replaceSubrange(r, with: repeatElement(UInt8(0), count: count))
    }
}

//===--- DataProtocol Conformances ----------------------------------------===//

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data : MutableDataProtocol {
    @inlinable // This is @inlinable as trivially computable.
    public var regions: CollectionOfOne<Data> {
        return CollectionOfOne(self)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {
    /// Copies the contents of the data to memory.
    ///
    /// - parameter pointer: A pointer to the buffer you wish to copy the bytes into.
    /// - parameter count: The number of bytes to copy.
    /// - warning: This method does not verify that the contents at pointer have enough space to hold `count` bytes.
    @inlinable // This is @inlinable as trivially forwarding.
    public func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, count: Int) {
        precondition(count >= 0, "count of bytes to copy must not be negative")
        if count == 0 { return }
        _copyBytesHelper(to: UnsafeMutableRawPointer(pointer), from: startIndex..<(startIndex + count))
    }
    
    @inlinable // This is @inlinable as trivially forwarding.
    internal func _copyBytesHelper(to pointer: UnsafeMutableRawPointer, from range: Range<Int>) {
        if range.isEmpty { return }
        _representation.copyBytes(to: pointer, from: range)
    }
    
    /// Copies a subset of the contents of the data to memory.
    ///
    /// - parameter pointer: A pointer to the buffer you wish to copy the bytes into.
    /// - parameter range: The range in the `Data` to copy.
    /// - warning: This method does not verify that the contents at pointer have enough space to hold the required number of bytes.
    @inlinable // This is @inlinable as trivially forwarding.
    public func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, from range: Range<Index>) {
        _copyBytesHelper(to: pointer, from: range)
    }
    
    /// Copies the bytes in a range from the data into a buffer.
    ///
    /// This function copies the bytes in `range` from the data into the buffer. If the count of the `range` is greater than `MemoryLayout<DestinationType>.stride * buffer.count` then the first N bytes will be copied into the buffer.
    /// - precondition: The range must be within the bounds of the data. Otherwise `fatalError` is called.
    /// - parameter buffer: A buffer to copy the data into.
    /// - parameter range: A range in the data to copy into the buffer. If the range is empty, this function will return 0 without copying anything. If the range is nil, as much data as will fit into `buffer` is copied.
    /// - returns: Number of bytes copied into the destination buffer.
    @inlinable // This is @inlinable as generic and reasonably small.
    public func copyBytes<DestinationType>(to buffer: UnsafeMutableBufferPointer<DestinationType>, from range: Range<Index>? = nil) -> Int {
        let cnt = count
        guard cnt > 0 else { return 0 }
        
        let copyRange : Range<Index>
        if let r = range {
            guard !r.isEmpty else { return 0 }
            copyRange = r.lowerBound..<(r.lowerBound + Swift.min(buffer.count * MemoryLayout<DestinationType>.stride, r.upperBound - r.lowerBound))
        } else {
            copyRange = startIndex..<(startIndex + Swift.min(buffer.count * MemoryLayout<DestinationType>.stride, cnt))
        }
        
        guard !copyRange.isEmpty else { return 0 }
        
        _copyBytesHelper(to: buffer.baseAddress!, from: copyRange)
        return copyRange.upperBound - copyRange.lowerBound
    }
}

//===--- DataProtocol Conditional Conformances ----------------------------===//

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Slice : DataProtocol where Base : DataProtocol {
    public typealias Regions = [Base.Regions.Element.SubSequence]

    public var regions: [Base.Regions.Element.SubSequence] {
        let sliceLowerBound = startIndex
        let sliceUpperBound = endIndex
        var regionUpperBound = base.startIndex

        return base.regions.compactMap { (region) -> Base.Regions.Element.SubSequence? in
            let regionLowerBound = regionUpperBound
            regionUpperBound = base.index(regionUpperBound, offsetBy: region.count)

            /*
             [------ Region ------]
             [--- Slice ---] =>

                      OR

             [------ Region ------]
                 <= [--- Slice ---]
             */
            if sliceLowerBound >= regionLowerBound && sliceUpperBound <= regionUpperBound {
                let regionRelativeSliceLowerBound = region.index(region.startIndex, offsetBy: base.distance(from: regionLowerBound, to: sliceLowerBound))
                let regionRelativeSliceUpperBound = region.index(region.startIndex, offsetBy: base.distance(from: regionLowerBound, to: sliceUpperBound))
                return region[regionRelativeSliceLowerBound..<regionRelativeSliceUpperBound]
            }

            /*
             [--- Region ---] =>
             [------ Slice ------]

                      OR

               <= [--- Region ---]
             [------ Slice ------]
             */
            if regionLowerBound >= sliceLowerBound && regionUpperBound <= sliceUpperBound {
                return region[region.startIndex..<region.endIndex]
            }

            /*
             [------ Region ------]
                 [------ Slice ------]
             */
            if sliceLowerBound >= regionLowerBound && sliceLowerBound <= regionUpperBound {
                let regionRelativeSliceLowerBound = region.index(region.startIndex, offsetBy: base.distance(from: regionLowerBound, to: sliceLowerBound))
                return region[regionRelativeSliceLowerBound..<region.endIndex]
            }

            /*
                 [------ Region ------]
             [------ Slice ------]
             */
            if regionLowerBound >= sliceLowerBound && regionLowerBound <= sliceUpperBound {
                let regionRelativeSliceUpperBound = region.index(region.startIndex, offsetBy: base.distance(from: regionLowerBound, to: sliceUpperBound))
                return region[region.startIndex..<regionRelativeSliceUpperBound]
            }

            /*
             [--- Region ---]
                              [--- Slice ---]

                      OR

                             [--- Region ---]
             [--- Slice ---]
             */
            return nil
        }
    }
}
