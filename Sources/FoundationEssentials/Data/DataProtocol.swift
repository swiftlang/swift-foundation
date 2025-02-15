//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2018 Apple Inc. and the Swift project authors
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
#endif

//===--- DataProtocol -----------------------------------------------------===//

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public protocol DataProtocol : RandomAccessCollection where Element == UInt8, SubSequence : DataProtocol {
    // FIXME: Remove in favor of opaque type on `regions`.
    associatedtype Regions: BidirectionalCollection where Regions.Element : DataProtocol & ContiguousBytes, Regions.Element.SubSequence : ContiguousBytes

    /// A `BidirectionalCollection` of `DataProtocol` elements which compose a
    /// discontiguous buffer of memory.  Each region is a contiguous buffer of
    /// bytes.
    ///
    /// The sum of the lengths of the associated regions must equal `self.count`
    /// (such that iterating `regions` and iterating `self` produces the same
    /// sequence of indices in the same number of index advancements).
    var regions: Regions { get }

    /// Returns the first found range of the given data buffer.
    ///
    /// A default implementation is given in terms of `self.regions`.
    func firstRange<D: DataProtocol, R: RangeExpression>(of: D, in: R) -> Range<Index>? where R.Bound == Index

    /// Returns the last found range of the given data buffer.
    ///
    /// A default implementation is given in terms of `self.regions`.
    func lastRange<D: DataProtocol, R: RangeExpression>(of: D, in: R) -> Range<Index>? where R.Bound == Index

    /// Copies `count` bytes from the start of the buffer to the destination
    /// buffer.
    ///
    /// A default implementation is given in terms of `copyBytes(to:from:)`.
    @discardableResult
    func copyBytes(to: UnsafeMutableRawBufferPointer, count: Int) -> Int

    /// Copies `count` bytes from the start of the buffer to the destination
    /// buffer.
    ///
    /// A default implementation is given in terms of `copyBytes(to:from:)`.
    @discardableResult
    func copyBytes<DestinationType>(to: UnsafeMutableBufferPointer<DestinationType>, count: Int) -> Int

    /// Copies the bytes from the given range to the destination buffer.
    ///
    /// A default implementation is given in terms of `self.regions`.
    @discardableResult
    func copyBytes<R: RangeExpression>(to: UnsafeMutableRawBufferPointer, from: R) -> Int where R.Bound == Index

    /// Copies the bytes from the given range to the destination buffer.
    ///
    /// A default implementation is given in terms of `self.regions`.
    @discardableResult
    func copyBytes<DestinationType, R: RangeExpression>(to: UnsafeMutableBufferPointer<DestinationType>, from: R) -> Int where R.Bound == Index
}

//===--- MutableDataProtocol ----------------------------------------------===//

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public protocol MutableDataProtocol : DataProtocol, MutableCollection, RangeReplaceableCollection {
    /// Replaces the contents of the buffer at the given range with zeroes.
    ///
    /// A default implementation is given in terms of
    /// `replaceSubrange(_:with:)`.
    mutating func resetBytes<R: RangeExpression>(in range: R) where R.Bound == Index
}

//===--- DataProtocol Extensions ------------------------------------------===//

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension DataProtocol {
    public func firstRange<D: DataProtocol>(of data: D) -> Range<Index>? {
        return self.firstRange(of: data, in: self.startIndex ..< self.endIndex)
    }

    public func lastRange<D: DataProtocol>(of data: D) -> Range<Index>? {
        return self.lastRange(of: data, in: self.startIndex ..< self.endIndex)
    }

    @discardableResult
    public func copyBytes(to ptr: UnsafeMutableRawBufferPointer) -> Int {
        return copyBytes(to: ptr, from: self.startIndex ..< self.endIndex)
    }

    @discardableResult
    public func copyBytes<DestinationType>(to ptr: UnsafeMutableBufferPointer<DestinationType>) -> Int {
        return copyBytes(to: ptr, from: self.startIndex ..< self.endIndex)
    }

    @discardableResult
    public func copyBytes(to ptr: UnsafeMutableRawBufferPointer, count: Int) -> Int {
        return copyBytes(to: ptr, from: self.startIndex ..< self.index(self.startIndex, offsetBy: count))
    }

    @discardableResult
    public func copyBytes<DestinationType>(to ptr: UnsafeMutableBufferPointer<DestinationType>, count: Int) -> Int {
        return copyBytes(to: ptr, from: self.startIndex ..< self.index(self.startIndex, offsetBy: count))
    }

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
    public mutating func resetBytes<R: RangeExpression>(in range: R) where R.Bound == Index {
        let r = range.relative(to: self)
        let count = distance(from: r.lowerBound, to: r.upperBound)
        replaceSubrange(r, with: repeatElement(UInt8(0), count: count))
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
