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

//===--- ContiguousBytes --------------------------------------------------===//

/// Indicates that the conforming type is a contiguous collection of raw bytes
/// whose underlying storage is directly accessible by withUnsafeBytes.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public protocol ContiguousBytes {
    /// Calls the given closure with the contents of underlying storage.
    ///
    /// - note: Calling `withUnsafeBytes` multiple times does not guarantee that
    ///         the same buffer pointer will be passed in every time.
    /// - warning: The buffer argument to the body should not be stored or used
    ///            outside of the lifetime of the call to the closure.
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
}

//===--- Collection Conformances ------------------------------------------===//

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Array : ContiguousBytes where Element == UInt8 { }

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension ArraySlice : ContiguousBytes where Element == UInt8 { }

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension ContiguousArray : ContiguousBytes where Element == UInt8 { }

//===--- Pointer Conformances ---------------------------------------------===//

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension UnsafeRawBufferPointer : ContiguousBytes {
    @inlinable
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(self)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension UnsafeMutableRawBufferPointer : ContiguousBytes {
    @inlinable
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(UnsafeRawBufferPointer(self))
    }
}

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension UnsafeBufferPointer : ContiguousBytes where Element == UInt8 {
    @inlinable
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(UnsafeRawBufferPointer(self))
    }
}

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension UnsafeMutableBufferPointer : ContiguousBytes where Element == UInt8 {
    @inlinable
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(UnsafeRawBufferPointer(self))
    }
}

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension EmptyCollection : ContiguousBytes where Element == UInt8 {
    @inlinable
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(UnsafeRawBufferPointer(start: nil, count: 0))
    }
}

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension CollectionOfOne : ContiguousBytes where Element == UInt8 {
    @inlinable
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        let element = self.first!
        return try Swift.withUnsafeBytes(of: element) {
            return try body($0)
        }
    }
}

//===--- Conditional Conformances -----------------------------------------===//

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Slice : ContiguousBytes where Base : ContiguousBytes {
    public func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        let offset = base.distance(from: base.startIndex, to: self.startIndex)
        return try base.withUnsafeBytes { ptr in
            let slicePtr = ptr.baseAddress?.advanced(by: offset)
            let sliceBuffer = UnsafeRawBufferPointer(start: slicePtr, count: self.count)
            return try body(sliceBuffer)
        }
    }
}
