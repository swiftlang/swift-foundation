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

//===--- ContiguousBytes --------------------------------------------------===//

/// Indicates that the conforming type is a contiguous collection of raw bytes
/// whose underlying storage is directly accessible by calling withBytes.
///
/// This protocol predates the introduction of the `RawSpan` type in the
/// standard library. Types that conform to this protocol will generally provide
/// a property (often called `bytes`) that produces a `RawSpan`, which is easier
/// to use than the closure-based APIs in this protocol. Therefore, new code
/// should generally be written to use `RawSpan` rather than `ContiguousBytes`.
///
/// Existing functions that use `ContiguousBytes` to accept raw bytes can be
/// generalized to also support directly passing a `RawSpan` or `Span<UInt8>` by
/// suppressing the implicit `Copyable` and `Escapable` requirements:
///
///     func encrypt<Bytes: ContiguousBytes>(_ bytes: Bytes) -> [UInt8]
///             where Bytes: ~Copyable, Bytes: ~Escapable {
///         return bytes.withBytes { rawSpan in ... }
///     }
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public protocol ContiguousBytes: ~Escapable, ~Copyable {
#if !hasFeature(Embedded)
    /// Calls the given closure with the contents of underlying storage.
    ///
    /// - note: Calling `withUnsafeBytes` multiple times does not guarantee that
    ///         the same buffer pointer will be passed in every time.
    /// - warning: The buffer argument to the body should not be stored or used
    ///            outside of the lifetime of the call to the closure.
    ///
    /// Clients should prefer the `withBytes` function to this one, because
    /// `withBytes` uses the non-escapable type `RawSpan` to ensure that the
    /// buffer argument is not stored outside of the closure.
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
#else
    /// Calls the given closure with the contents of underlying storage.
    ///
    /// - note: Calling `withUnsafeBytes` multiple times does not guarantee that
    ///         the same buffer pointer will be passed in every time.
    /// - warning: The buffer argument to the body should not be stored or used
    ///            outside of the lifetime of the call to the closure.
    ///
    /// Clients should prefer the `withBytes` function to this one, because
    /// `withBytes` uses the non-escapable type `RawSpan` to ensure that the
    /// buffer argument is not stored outside of the closure.
    func withUnsafeBytes<R, E>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R
#endif

    /// Calls the given closure with the contents of underlying storage.
    ///
    /// - note: Calling `withBytes` multiple times does not guarantee that
    ///         the same span will be passed in every time.
    @available(FoundationPreview 6.4, *)
    func withBytes<R, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R
}

extension ContiguousBytes where Self: ~Escapable, Self: ~Copyable {
    /// Calls the given closure with the contents of underlying storage.
    ///
    /// - note: Calling `withBytes` multiple times does not guarantee that
    ///         the same span will be passed in every time.
    @_alwaysEmitIntoClient
    public func withBytes<R, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
#if !hasFeature(Embedded)
        do {
            return try withUnsafeBytes { (buffer) in
                try body(buffer.bytes)
            }
        } catch let error {
            // Note: withUnsafeBytes is rethrowing, so we have an "any Error" here that needs casting.
            throw error as! E
        }
#else
        return try withUnsafeBytes { (buffer) throws(E) in
            try body(buffer.bytes)
        }
#endif
    }
}

//===--- Collection Conformances ------------------------------------------===//

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Array : ContiguousBytes where Element == UInt8 {
    // FIXME: Generalize to R: ~Copyable when withUnsafeBufferPointer does
    @_alwaysEmitIntoClient
    public func withBytes<R, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        try withUnsafeBufferPointer { (buffer) throws(E) in
            try body(buffer.span.bytes)
        }
    }
}

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension ArraySlice : ContiguousBytes where Element == UInt8 {
    // FIXME: Generalize to R: ~Copyable when withUnsafeBufferPointer does
    @_alwaysEmitIntoClient
    public func withBytes<R, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        try withUnsafeBufferPointer { (buffer) throws(E) in
            try body(buffer.span.bytes)
        }
    }
}

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension ContiguousArray : ContiguousBytes where Element == UInt8 {
    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        return try body(span.bytes)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data : ContiguousBytes { }

//===--- Pointer Conformances ---------------------------------------------===//

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension UnsafeRawBufferPointer : ContiguousBytes {
    #if !hasFeature(Embedded)
    // Historical ABI
    @usableFromInline
    @abi(func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R)
    func __abi__withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        return try body(self)
    }
    #endif

    @_alwaysEmitIntoClient
    public func withUnsafeBytes<R, E>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        return try body(self)
    }

    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        return try body(bytes)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension UnsafeMutableRawBufferPointer : ContiguousBytes {
#if !hasFeature(Embedded)
    // Historical ABI
    @usableFromInline
    @abi(func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R)
    func __abi__withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        return try body(UnsafeRawBufferPointer(self))
    }
#endif

    @_alwaysEmitIntoClient
    public func withUnsafeBytes<R, E>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        return try body(UnsafeRawBufferPointer(self))
    }

    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        return try body(bytes)
    }
}

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension UnsafeBufferPointer : ContiguousBytes where Element == UInt8 {
#if !hasFeature(Embedded)
    @usableFromInline
    @abi(func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R)
    func __abi__withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        return try body(UnsafeRawBufferPointer(self))
    }
#endif

    @_alwaysEmitIntoClient
    public func withUnsafeBytes<R, E>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        return try body(UnsafeRawBufferPointer(self))
    }

    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        return try body(span.bytes)
    }
}

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension UnsafeMutableBufferPointer : ContiguousBytes where Element == UInt8 {
#if !hasFeature(Embedded)
    @usableFromInline
    @abi(func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R)
    func __abi__withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        return try body(UnsafeRawBufferPointer(self))
    }
#endif

    @_alwaysEmitIntoClient
    public func withUnsafeBytes<R, E>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        return try body(UnsafeRawBufferPointer(self))
    }

    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        return try body(span.bytes)
    }
}

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension EmptyCollection : ContiguousBytes where Element == UInt8 {
#if !hasFeature(Embedded)
    @usableFromInline
    @abi(func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R)
    func __abi__withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        return try body(UnsafeRawBufferPointer(start: nil, count: 0))
    }
#endif

    @_alwaysEmitIntoClient
    public func withUnsafeBytes<R, E>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        return try body(UnsafeRawBufferPointer(start: nil, count: 0))
    }

    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        return try body(RawSpan())
    }
}

// FIXME: When possible, expand conformance to `where Element : Trivial`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension CollectionOfOne : ContiguousBytes where Element == UInt8 {
#if !hasFeature(Embedded)
    @usableFromInline
    @abi(func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R)
    func __abi__withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        let element = self.first!
        return try Swift.withUnsafeBytes(of: element) {
            return try body($0)
        }
    }
#endif

    @_alwaysEmitIntoClient
    public func withUnsafeBytes<R, E>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        let element = self.first!
        return try Swift.withUnsafeBytes(of: element) { (buffer) throws(E) in
            return try body(buffer)
        }
    }

    // FIXME: Generalize to R: ~Copyable when withUnsafeBufferPointer does
    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        let element = self.first!
        return try Swift.withUnsafeBytes(of: element) { (buffer) throws(E) in
            return try body(buffer.bytes)
        }
    }
}

//===--- Conditional Conformances -----------------------------------------===//

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Slice : ContiguousBytes where Base : ContiguousBytes {
#if !hasFeature(Embedded)
    @usableFromInline
    @abi(func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R)
    func __abi__withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        let offset = base.distance(from: base.startIndex, to: self.startIndex)
        return try base.withUnsafeBytes { ptr in
            let slicePtr = ptr.baseAddress?.advanced(by: offset)
            let sliceBuffer = UnsafeRawBufferPointer(start: slicePtr, count: self.count)
            return try body(sliceBuffer)
        }
    }
#endif

    @_alwaysEmitIntoClient
    public func withUnsafeBytes<ResultType, ErrorType>(_ body: (UnsafeRawBufferPointer) throws(ErrorType) -> ResultType) throws(ErrorType) -> ResultType {
        let offset = base.distance(from: base.startIndex, to: self.startIndex)

#if !hasFeature(Embedded)
        do {
            return try base.withUnsafeBytes { (ptr) in
                let slicePtr = ptr.baseAddress?.advanced(by: offset)
                let sliceBuffer = UnsafeRawBufferPointer(start: slicePtr, count: self.count)
                return try body(sliceBuffer)
            }
        } catch let error {
            // Note: withUnsafeBytes is rethrowing, so we have an "any Error" here that needs casting.
            throw error as! ErrorType
        }
#else
        return try base.withUnsafeBytes { (ptr) throws(ErrorType) in
            let slicePtr = ptr.baseAddress?.advanced(by: offset)
            let sliceBuffer = UnsafeRawBufferPointer(start: slicePtr, count: self.count)
            return try body(sliceBuffer)
        }
#endif
    }
}

//===--- Span Conformances -----------------------------------------===//

@available(FoundationPreview 6.4, *)
extension RawSpan: ContiguousBytes { }

extension RawSpan {
    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        return try body(self)
    }
}

@available(FoundationPreview 6.4, *)
extension MutableRawSpan: ContiguousBytes { }

extension MutableRawSpan {
    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        return try body(bytes)
    }
}

@available(FoundationPreview 6.4, *)
extension OutputRawSpan: ContiguousBytes { }

extension OutputRawSpan {
    @_alwaysEmitIntoClient
    public func withUnsafeBytes<R, E>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        try bytes.withUnsafeBytes(body)
    }

    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        try body(bytes)
    }
}

@available(FoundationPreview 6.4, *)
extension UTF8Span: ContiguousBytes { }

extension UTF8Span {
    @_alwaysEmitIntoClient
    public func withUnsafeBytes<R, E>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        try span.withUnsafeBytes(body)
    }

    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        return try body(span.bytes)
    }
}

@available(FoundationPreview 6.4, *)
extension Span: ContiguousBytes where Element == UInt8 { }

extension Span where Element == UInt8 {
    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        try body(bytes)
    }
}

@available(FoundationPreview 6.4, *)
extension MutableSpan: ContiguousBytes where Element == UInt8 { }

extension MutableSpan where Element == UInt8 {
    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        try body(bytes)
    }
}

@available(FoundationPreview 6.4, *)
extension OutputSpan: ContiguousBytes where Element == UInt8 { }

extension OutputSpan where Element == UInt8 {
    @_alwaysEmitIntoClient
    public func withUnsafeBytes<R, E>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        try span.withUnsafeBytes(body)
    }

    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        try body(span.bytes)
    }
}

@available(FoundationPreview 6.4, *)
extension InlineArray: ContiguousBytes where Element == UInt8 { }

extension InlineArray where Element == UInt8 {
    @_alwaysEmitIntoClient
    public func withUnsafeBytes<R, E>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        return try span.withUnsafeBytes(body)
    }

    @_alwaysEmitIntoClient
    public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        try body(span.bytes)
    }
}
