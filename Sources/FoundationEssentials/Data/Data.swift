//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if os(Windows)
@usableFromInline let calloc = ucrt.calloc
@usableFromInline let malloc = ucrt.malloc
@usableFromInline let free = ucrt.free
@usableFromInline let memset = ucrt.memset
@usableFromInline let memcpy = ucrt.memcpy
@usableFromInline let memcmp = ucrt.memcmp
#elseif canImport(Bionic)
@preconcurrency import Bionic
@usableFromInline let calloc = Bionic.calloc
@usableFromInline let malloc = Bionic.malloc
@usableFromInline let free = Bionic.free
@usableFromInline let memset = Bionic.memset
@usableFromInline let memcpy = Bionic.memcpy
@usableFromInline let memcmp = Bionic.memcmp
#elseif canImport(Glibc)
@usableFromInline let calloc = Glibc.calloc
@usableFromInline let malloc = Glibc.malloc
@usableFromInline let free = Glibc.free
@usableFromInline let memset = Glibc.memset
@usableFromInline let memcpy = Glibc.memcpy
@usableFromInline let memcmp = Glibc.memcmp
#elseif canImport(Musl)
@usableFromInline let calloc = Musl.calloc
@usableFromInline let malloc = Musl.malloc
@usableFromInline let free = Musl.free
@usableFromInline let memset = Musl.memset
@usableFromInline let memcpy = Musl.memcpy
@usableFromInline let memcmp = Musl.memcmp
#elseif canImport(WASILibc)
@usableFromInline let calloc = WASILibc.calloc
@usableFromInline let malloc = WASILibc.malloc
@usableFromInline let free = WASILibc.free
@usableFromInline let memset = WASILibc.memset
@usableFromInline let memcpy = WASILibc.memcpy
@usableFromInline let memcmp = WASILibc.memcmp
#endif

#if !NO_CSHIMS
internal import _FoundationCShims
#endif
import Builtin

#if canImport(Darwin)
import Darwin

internal func __DataInvokeDeallocatorVirtualMemory(_ mem: UnsafeMutableRawPointer, _ length: Int) {
    guard vm_deallocate(
        _platform_mach_task_self(),
        vm_address_t(UInt(bitPattern: mem)),
        vm_size_t(length)) == ERR_SUCCESS else {
        fatalError("*** __DataInvokeDeallocatorVirtualMemory(\(mem), \(length)) failed")
    }
}
#endif

#if !canImport(Darwin)
@inlinable // This is @inlinable as trivially computable.
internal func malloc_good_size(_ size: Int) -> Int {
    return size
}
#endif

#if canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(ucrt)
import ucrt
#elseif canImport(WASILibc)
@preconcurrency import WASILibc
#endif

#if os(Windows)
import func WinSDK.UnmapViewOfFile
#endif

internal func __DataInvokeDeallocatorUnmap(_ mem: UnsafeMutableRawPointer, _ length: Int) {
#if os(Windows)
    _ = UnmapViewOfFile(mem)
#elseif canImport(C)
    free(mem)
#else
    munmap(mem, length)
#endif
}

internal func __DataInvokeDeallocatorFree(_ mem: UnsafeMutableRawPointer, _ length: Int) {
    free(mem)
}


@_alwaysEmitIntoClient
internal func _withStackOrHeapBuffer(capacity: Int, _ body: (UnsafeMutableBufferPointer<UInt8>) -> Void) {
    guard capacity > 0 else {
        body(UnsafeMutableBufferPointer(start: nil, count: 0))
        return
    }
    // Use an inline allocation for 32 bytes or fewer
    if capacity <= 32 {
        withUnsafeTemporaryAllocation(of: UInt8.self, capacity: capacity) { buffer in
            body(buffer)
        }
        return
    }

    let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: capacity)
    defer { buffer.deallocate() }
    body(buffer)
}

@frozen
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
#if compiler(>=6.2)
@_addressableForDependencies
#endif
public struct Data : RandomAccessCollection, MutableCollection, RangeReplaceableCollection, Sendable, Hashable {
    public typealias Index = Int
    public typealias Indices = Range<Int>

    @usableFromInline internal var _representation: _Representation

    // A standard or custom deallocator for `Data`.
    ///
    /// When creating a `Data` with the no-copy initializer, you may specify a `Data.Deallocator` to customize the behavior of how the backing store is deallocated.
    public enum Deallocator {
        /// Use a virtual memory deallocator.
#if canImport(Darwin)
        case virtualMemory
#endif // canImport(Darwin)

        /// Use `munmap`.
        case unmap

        /// Use `free`.
        case free

        /// Do nothing upon deallocation.
        case none

        /// A custom deallocator.
        case custom((UnsafeMutableRawPointer, Int) -> Void)

        @usableFromInline internal var _deallocator : ((UnsafeMutableRawPointer, Int) -> Void) {
            switch self {
            case .unmap:
                return { __DataInvokeDeallocatorUnmap($0, $1) }
            case .free:
                return { __DataInvokeDeallocatorFree($0, $1) }
            case .none:
                return { _, _ in }
            case .custom(let b):
                return b
#if canImport(Darwin)
            case .virtualMemory:
                return { __DataInvokeDeallocatorVirtualMemory($0, $1) }
#endif // canImport(Darwin)
            }
        }
    }

    // MARK: -
    // MARK: Init methods

    /// Initialize a `Data` with copied memory content.
    ///
    /// - parameter bytes: A pointer to the memory. It will be copied.
    /// - parameter count: The number of bytes to copy.
    @inlinable // This is @inlinable as a trivial initializer.
    public init(bytes: UnsafeRawPointer, count: Int) {
        _representation = _Representation(UnsafeRawBufferPointer(start: bytes, count: count))
    }

    /// Initialize a `Data` with copied memory content.
    ///
    /// - parameter buffer: A buffer pointer to copy. The size is calculated from `SourceType` and `buffer.count`.
    @inlinable // This is @inlinable as a trivial, generic initializer.
    public init<SourceType>(buffer: UnsafeBufferPointer<SourceType>) {
        _representation = _Representation(UnsafeRawBufferPointer(buffer))
    }

    /// Initialize a `Data` with copied memory content.
    ///
    /// - parameter buffer: A buffer pointer to copy. The size is calculated from `SourceType` and `buffer.count`.
    @inlinable // This is @inlinable as a trivial, generic initializer.
    public init<SourceType>(buffer: UnsafeMutableBufferPointer<SourceType>) {
        _representation = _Representation(UnsafeRawBufferPointer(buffer))
    }

    /// Initialize a `Data` with a repeating byte pattern
    ///
    /// - parameter repeatedValue: A byte to initialize the pattern
    /// - parameter count: The number of bytes the data initially contains initialized to the repeatedValue
    @inlinable // This is @inlinable as a convenience initializer.
    public init(repeating repeatedValue: UInt8, count: Int) {
        self.init(count: count)
        withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> Void in
            _ = memset(buffer.baseAddress!, Int32(repeatedValue), buffer.count)
        }
    }

    /// Initialize a `Data` with the specified size.
    ///
    /// This initializer doesn't necessarily allocate the requested memory right away. `Data` allocates additional memory as needed, so `capacity` simply establishes the initial capacity. When it does allocate the initial memory, though, it allocates the specified amount.
    ///
    /// This method sets the `count` of the data to 0.
    ///
    /// If the capacity specified in `capacity` is greater than four memory pages in size, this may round the amount of requested memory up to the nearest full page.
    ///
    /// - parameter capacity: The size of the data.
    @inlinable // This is @inlinable as a trivial initializer.
    public init(capacity: Int) {
        _representation = _Representation(capacity: capacity)
    }

    /// Initialize a `Data` with the specified count of zeroed bytes.
    ///
    /// - parameter count: The number of bytes the data initially contains.
    @inlinable // This is @inlinable as a trivial initializer.
    public init(count: Int) {
        _representation = _Representation(count: count)
    }

    /// Initialize an empty `Data`.
    @inlinable // This is @inlinable as a trivial initializer.
    public init() {
        _representation = .empty
    }


    /// Initialize a `Data` without copying the bytes.
    ///
    /// If the result is mutated and is not a unique reference, then the `Data` will still follow copy-on-write semantics. In this case, the copy will use its own deallocator. Therefore, it is usually best to only use this initializer when you either enforce immutability with `let` or ensure that no other references to the underlying data are formed.
    /// - parameter bytes: A pointer to the bytes.
    /// - parameter count: The size of the bytes.
    /// - parameter deallocator: Specifies the mechanism to free the indicated buffer, or `.none`.
    @inlinable // This is @inlinable as a trivial initializer.
    public init(bytesNoCopy bytes: UnsafeMutableRawPointer, count: Int, deallocator: Deallocator) {
        let whichDeallocator = deallocator._deallocator
        if count == 0 {
            deallocator._deallocator(bytes, count)
            _representation = .empty
        } else {
            let storage = __DataStorage(bytes: bytes, length: count, copy: false, deallocator: whichDeallocator, offset: 0)
            switch deallocator {
            // technically .custom can potential cause this too but there is a potential chance this is expected behavior
            // commented out for now... revisit later
            // case .custom: fallthrough
            case .none:
                storage._copyWillRetain = false
            default:
                break
            }
            _representation = _Representation(storage, count: count)
        }
    }

    // slightly faster paths for common sequences
    @inlinable // This is @inlinable as an important generic funnel point, despite being a non-trivial initializer.
    public init<S: Sequence>(_ elements: S) where S.Element == UInt8 {
        // If the sequence is already contiguous, access the underlying raw memory directly.
        if let contiguous = elements as? ContiguousBytes {
            _representation = contiguous.withUnsafeBytes { return _Representation($0) }
            return
        }

        // The sequence might still be able to provide direct access to typed memory.
        // NOTE: It's safe to do this because we're already guarding on S's element as `UInt8`. This would not be safe on arbitrary sequences.
        let representation = elements.withContiguousStorageIfAvailable {
            _Representation(UnsafeRawBufferPointer($0))
        }
        if let representation = representation {
            _representation = representation
            return
        }

        // Copy as much as we can in one shot from the sequence.
        let underestimatedCount = elements.underestimatedCount
        _representation = _Representation(count: underestimatedCount)
        var (iter, endIndex): (S.Iterator, Int) = _representation.withUnsafeMutableBytes { buffer in
            buffer.withMemoryRebound(to: UInt8.self) {
                elements._copyContents(initializing: $0)
            }
        }
        guard endIndex == _representation.count else {
            // We can't trap here. We have to allow an underfilled buffer
            // to emulate the previous implementation.
            _representation.replaceSubrange(endIndex ..< _representation.endIndex, with: nil, count: 0)
            return
        }

        // Append the rest byte-wise, buffering through an InlineData.
        var buffer = InlineData()
        while let element = iter.next() {
            buffer.append(byte: element)
            if buffer.count == buffer.capacity {
                buffer.withUnsafeBytes { _representation.append(contentsOf: $0) }
                buffer.count = 0
            }
        }

        // If we've still got bytes left in the buffer (i.e. the loop ended before we filled up the buffer and cleared it out), append them.
        if buffer.count > 0 {
            buffer.withUnsafeBytes { _representation.append(contentsOf: $0) }
            buffer.count = 0
        }
    }

    @inlinable // This is @inlinable as a trivial initializer.
    internal init(representation: _Representation) {
        _representation = representation
    }
    
    // -----------------------------------
    // MARK: - Properties and Functions

    @inlinable // This is @inlinable as trivially forwarding.
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        _representation.reserveCapacity(minimumCapacity)
    }

    mutating func stabilizeAddresses() {
        reserveCapacity(InlineData.maximumCapacity + 1)
    }

    /// The number of bytes in the data.
    @inlinable // This is @inlinable as trivially forwarding.
    public var count: Int {
        get {
            return _representation.count
        }
        set(newValue) {
            precondition(newValue >= 0, "count must not be negative")
            _representation.count = newValue
        }
    }

    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    public func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        return try _representation.withUnsafeBytes(body)
    }

    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    @_alwaysEmitIntoClient
    public var bytes: RawSpan {
        @lifetime(borrow self)
        borrowing get {
            let buffer: UnsafeRawBufferPointer
            switch _representation {
            case .empty:
                buffer = UnsafeRawBufferPointer(start: nil, count: 0)
            case .inline(let inline):
                buffer = unsafe UnsafeRawBufferPointer(
                  start: UnsafeRawPointer(Builtin.addressOfBorrow(self)),
                  count: inline.count
                )
            case .large(let slice):
                buffer = unsafe UnsafeRawBufferPointer(
                  start: slice.storage.mutableBytes?.advanced(by: slice.startIndex), count: slice.count
                )
            case .slice(let slice):
                buffer = unsafe UnsafeRawBufferPointer(
                  start: slice.storage.mutableBytes?.advanced(by: slice.startIndex), count: slice.count
                )
            }
            let span = unsafe RawSpan(_unsafeBytes: buffer)
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    @_alwaysEmitIntoClient
    public var span: Span<UInt8> {
        @lifetime(borrow self)
        borrowing get {
            let span = unsafe bytes._unsafeView(as: UInt8.self)
            return _overrideLifetime(span, borrowing: self)
        }
    }

    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    @_alwaysEmitIntoClient
    public var mutableBytes: MutableRawSpan {
        @lifetime(&self)
        mutating get {
            let buffer: UnsafeMutableRawBufferPointer
            switch _representation {
            case .empty:
                buffer = UnsafeMutableRawBufferPointer(start: nil, count: 0)
            case .inline(let inline):
                buffer = unsafe UnsafeMutableRawBufferPointer(
                  start: UnsafeMutableRawPointer(Builtin.addressOfBorrow(self)),
                  count: inline.count
                )
            case .large(var slice):
                // Clear _representation during the unique check to avoid double counting the reference, and assign the mutated slice back to _representation afterwards
                _representation = .empty
                slice.ensureUniqueReference()
                _representation = .large(slice)
                buffer = unsafe UnsafeMutableRawBufferPointer(
                  start: slice.storage.mutableBytes?.advanced(by: slice.startIndex), count: slice.count
                )
            case .slice(var slice):
                // Clear _representation during the unique check to avoid double counting the reference, and assign the mutated slice back to _representation afterwards
                _representation = .empty
                slice.ensureUniqueReference()
                _representation = .slice(slice)
                buffer = unsafe UnsafeMutableRawBufferPointer(
                  start: slice.storage.mutableBytes?.advanced(by: slice.startIndex), count: slice.count
                )
            }
            let span = unsafe MutableRawSpan(_unsafeBytes: buffer)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
    }

    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    @_alwaysEmitIntoClient
    public var mutableSpan: MutableSpan<UInt8> {
        @lifetime(&self)
        mutating get {
#if false // see https://github.com/swiftlang/swift/issues/81218
            var bytes = mutableBytes
            let span = unsafe bytes._unsafeMutableView(as: UInt8.self)
            return _overrideLifetime(span, mutating: &self)
#else
            let buffer: UnsafeMutableRawBufferPointer
            switch _representation {
            case .empty:
                buffer = UnsafeMutableRawBufferPointer(start: nil, count: 0)
            case .inline(let inline):
                buffer = unsafe UnsafeMutableRawBufferPointer(
                  start: UnsafeMutableRawPointer(Builtin.addressOfBorrow(self)),
                  count: inline.count
                )
            case .large(var slice):
                // Clear _representation during the unique check to avoid double counting the reference, and assign the mutated slice back to _representation afterwards
                _representation = .empty
                slice.ensureUniqueReference()
                _representation = .large(slice)
                buffer = unsafe UnsafeMutableRawBufferPointer(
                  start: slice.storage.mutableBytes?.advanced(by: slice.startIndex), count: slice.count
                )
            case .slice(var slice):
                // Clear _representation during the unique check to avoid double counting the reference, and assign the mutated slice back to _representation afterwards
                _representation = .empty
                slice.ensureUniqueReference()
                _representation = .slice(slice)
                buffer = unsafe UnsafeMutableRawBufferPointer(
                  start: slice.storage.mutableBytes?.advanced(by: slice.startIndex), count: slice.count
                )
            }
            let span = unsafe MutableSpan<UInt8>(_unsafeBytes: buffer)
            return unsafe _overrideLifetime(span, mutating: &self)
#endif
        }
    }

    @_alwaysEmitIntoClient
    public func withContiguousStorageIfAvailable<ResultType>(_ body: (_ buffer: UnsafeBufferPointer<UInt8>) throws -> ResultType) rethrows -> ResultType? {
        return try _representation.withUnsafeBytes {
            return try $0.withMemoryRebound(to: UInt8.self, body)
        }
    }

    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    public mutating func withUnsafeMutableBytes<ResultType>(_ body: (UnsafeMutableRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        return try _representation.withUnsafeMutableBytes(body)
    }

    // MARK: -

    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    internal mutating func _append<SourceType>(_ buffer : UnsafeBufferPointer<SourceType>) {
        if buffer.isEmpty { return }
        _representation.append(contentsOf: UnsafeRawBufferPointer(buffer))
    }

    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    public mutating func append(_ bytes: UnsafePointer<UInt8>, count: Int) {
        if count == 0 { return }
        _append(UnsafeBufferPointer(start: bytes, count: count))
    }

    public mutating func append(_ other: Data) {
        guard !other.isEmpty else { return }
        other.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            _representation.append(contentsOf: buffer)
        }
    }

    /// Append a buffer of bytes to the data.
    ///
    /// - parameter buffer: The buffer of bytes to append. The size is calculated from `SourceType` and `buffer.count`.
    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    public mutating func append<SourceType>(_ buffer : UnsafeBufferPointer<SourceType>) {
        _append(buffer)
    }

    @inlinable // This is @inlinable as trivially forwarding.
    public mutating func append(contentsOf bytes: [UInt8]) {
        bytes.withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<UInt8>) -> Void in
            _append(buffer)
        }
    }

    @inlinable // This is @inlinable as an important generic funnel point, despite being non-trivial.
    public mutating func append<S: Sequence>(contentsOf elements: S) where S.Element == Element {
        // If the sequence is already contiguous, access the underlying raw memory directly.
        if let contiguous = elements as? ContiguousBytes {
            contiguous.withUnsafeBytes {
                _representation.append(contentsOf: $0)
            }

            return
        }

        // The sequence might still be able to provide direct access to typed memory.
        // NOTE: It's safe to do this because we're already guarding on S's element as `UInt8`. This would not be safe on arbitrary sequences.
        let appended: Void? = elements.withContiguousStorageIfAvailable {
            _representation.append(contentsOf: UnsafeRawBufferPointer($0))
        }
        guard appended == nil else { return }

        // The sequence is really not contiguous.
        // Copy as much as we can in one shot.
        let underestimatedCount = elements.underestimatedCount
        let originalCount = _representation.count
        resetBytes(in: self.endIndex ..< self.endIndex + underestimatedCount)
        var (iter, copiedCount): (S.Iterator, Int) = _representation.withUnsafeMutableBytes { buffer in
            assert(buffer.count == originalCount + underestimatedCount)
            let start = buffer.baseAddress?.advanced(by: originalCount)
            let b = UnsafeMutableRawBufferPointer(start: start, count: buffer.count - originalCount)
            return b.withMemoryRebound(to: UInt8.self, elements._copyContents(initializing:))
        }
        guard copiedCount == underestimatedCount else {
            // We can't trap here. We have to allow an underfilled buffer
            // to emulate the previous implementation.
            _representation.replaceSubrange(startIndex + originalCount + copiedCount ..< endIndex, with: nil, count: 0)
            return
        }

        // Append the rest byte-wise, buffering through an InlineData.
        var buffer = InlineData()
        while let element = iter.next() {
            buffer.append(byte: element)
            if buffer.count == buffer.capacity {
                buffer.withUnsafeBytes { _representation.append(contentsOf: $0) }
                buffer.count = 0
            }
        }

        // If we've still got bytes left in the buffer (i.e. the loop ended before we filled up the buffer and cleared it out), append them.
        if buffer.count > 0 {
            buffer.withUnsafeBytes { _representation.append(contentsOf: $0) }
            buffer.count = 0
        }
    }

    // MARK: -

    /// Set a region of the data to `0`.
    ///
    /// If `range` exceeds the bounds of the data, then the data is resized to fit.
    /// - parameter range: The range in the data to set to `0`.
    @inlinable // This is @inlinable as trivially forwarding.
    public mutating func resetBytes(in range: Range<Index>) {
        // it is worth noting that the range here may be out of bounds of the Data itself (which triggers a growth)
        precondition(range.lowerBound >= 0, "Ranges must not be negative bounds")
        precondition(range.upperBound >= 0, "Ranges must not be negative bounds")
        _representation.resetBytes(in: range)
    }

    /// Replace a region of bytes in the data with new data.
    ///
    /// This will resize the data if required, to fit the entire contents of `data`.
    ///
    /// - precondition: The bounds of `subrange` must be valid indices of the collection.
    /// - parameter subrange: The range in the data to replace. If `subrange.lowerBound == data.count && subrange.count == 0` then this operation is an append.
    /// - parameter data: The replacement data.
    @inlinable // This is @inlinable as trivially forwarding.
    public mutating func replaceSubrange(_ subrange: Range<Index>, with data: Data) {
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            _representation.replaceSubrange(subrange, with: buffer.baseAddress, count: buffer.count)
        }
    }

    /// Replace a region of bytes in the data with new bytes from a buffer.
    ///
    /// This will resize the data if required, to fit the entire contents of `buffer`.
    ///
    /// - precondition: The bounds of `subrange` must be valid indices of the collection.
    /// - parameter subrange: The range in the data to replace.
    /// - parameter buffer: The replacement bytes.
    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    public mutating func replaceSubrange<SourceType>(_ subrange: Range<Index>, with buffer: UnsafeBufferPointer<SourceType>) {
        replaceSubrange(subrange, with: UnsafeRawBufferPointer(buffer))
    }

    /// Replace a region of bytes in the data with new bytes from a collection.
    ///
    /// This will resize the data if required, to fit the entire contents of `newElements`.
    ///
    /// - precondition: The bounds of `subrange` must be valid indices of the collection.
    /// - parameter subrange: The range in the data to replace.
    /// - parameter newElements: The replacement bytes.
    @inlinable // This is @inlinable as generic and reasonably small.
    public mutating func replaceSubrange<ByteCollection : Collection>(_ subrange: Range<Index>, with newElements: ByteCollection) where ByteCollection.Iterator.Element == Data.Iterator.Element {
        // If the collection is already contiguous, access the underlying raw memory directly.
        if let contiguous = newElements as? ContiguousBytes {
            contiguous.withUnsafeBytes { buffer in
                _representation.replaceSubrange(subrange, with: buffer.baseAddress, count: buffer.count)
            }
            return
        }
        // The collection might still be able to provide direct access to typed memory.
        // NOTE: It's safe to do this because we're already guarding on ByteCollection's element as `UInt8`. This would not be safe on arbitrary collections.
        let replaced: Void? = newElements.withContiguousStorageIfAvailable { buffer in
            _representation.replaceSubrange(subrange, with: buffer.baseAddress, count: buffer.count)
        }
        guard replaced == nil else { return }

        let totalCount = Int(newElements.count)
        _withStackOrHeapBuffer(capacity: totalCount) { buffer in
            var (iterator, index) = newElements._copyContents(initializing: buffer)
            precondition(index == buffer.endIndex, "Collection has less elements than its count")
            precondition(iterator.next() == nil, "Collection has more elements than its count")
            _representation.replaceSubrange(subrange, with: buffer.baseAddress, count: totalCount)
        }
    }

    @inlinable // This is @inlinable as trivially forwarding.
    public mutating func replaceSubrange(_ subrange: Range<Index>, with bytes: UnsafeRawPointer, count cnt: Int) {
        _representation.replaceSubrange(subrange, with: bytes, count: cnt)
    }

    /// Return a new copy of the data in a specified range.
    ///
    /// - parameter range: The range to copy.
    public func subdata(in range: Range<Index>) -> Data {
        if isEmpty || range.upperBound - range.lowerBound == 0 {
            return Data()
        }
        let slice = self[range]

        return slice.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Data in
            return Data(bytes: buffer.baseAddress!, count: buffer.count)
        }
    }

    // MARK: -
    //

    public func advanced(by amount: Int) -> Data {
        precondition(amount >= 0)
        let start = self.index(self.startIndex, offsetBy: amount)
        precondition(start <= self.endIndex)
        return Data(self[start...])
    }
    
    // MARK: -
    // MARK: Index and Subscript

    /// Sets or returns the byte at the specified index.
    @inlinable // This is @inlinable as trivially forwarding.
    public subscript(index: Index) -> UInt8 {
        get {
            return _representation[index]
        }
        set(newValue) {
            _representation[index] = newValue
        }
    }

    @inlinable // This is @inlinable as trivially forwarding.
    public subscript(bounds: Range<Index>) -> Data {
        get {
            return _representation[bounds]
        }
        set {
            replaceSubrange(bounds, with: newValue)
        }
    }

    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    public subscript<R: RangeExpression>(_ rangeExpression: R) -> Data
        where R.Bound: FixedWidthInteger {
        get {
            let lower = R.Bound(startIndex)
            let upper = R.Bound(endIndex)
            let range = rangeExpression.relative(to: lower..<upper)
            let start = Int(range.lowerBound)
            let end = Int(range.upperBound)
            let r: Range<Int> = start..<end
            return _representation[r]
        }
        set {
            let lower = R.Bound(startIndex)
            let upper = R.Bound(endIndex)
            let range = rangeExpression.relative(to: lower..<upper)
            let start = Int(range.lowerBound)
            let end = Int(range.upperBound)
            let r: Range<Int> = start..<end
            replaceSubrange(r, with: newValue)
        }

    }

    /// The start `Index` in the data.
    @inlinable // This is @inlinable as trivially forwarding.
    public var startIndex: Index {
        get {
            return _representation.startIndex
        }
    }

    /// The end `Index` into the data.
    ///
    /// This is the "one-past-the-end" position, and will always be equal to the `count`.
    @inlinable // This is @inlinable as trivially forwarding.
    public var endIndex: Index {
        get {
            return _representation.endIndex
        }
    }

    @inlinable // This is @inlinable as trivially computable.
    public func index(before i: Index) -> Index {
        return i - 1
    }

    @inlinable // This is @inlinable as trivially computable.
    public func index(after i: Index) -> Index {
        return i + 1
    }

    @inlinable // This is @inlinable as trivially computable.
    public var indices: Range<Int> {
        get {
            return startIndex..<endIndex
        }
    }

    @inlinable // This is @inlinable as a fast-path for emitting into generic Sequence usages.
    public func _copyContents(initializing buffer: UnsafeMutableBufferPointer<UInt8>) -> (Iterator, UnsafeMutableBufferPointer<UInt8>.Index) {
        guard !isEmpty else { return (makeIterator(), buffer.startIndex) }
        let cnt = Swift.min(count, buffer.count)

        withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            _ = memcpy(UnsafeMutableRawPointer(buffer.baseAddress!), bytes.baseAddress!, cnt)
        }

        return (Iterator(self, at: startIndex + cnt), buffer.index(buffer.startIndex, offsetBy: cnt))
    }
}

@available(macOS, unavailable, introduced: 10.10)
@available(iOS, unavailable, introduced: 8.0)
@available(tvOS, unavailable, introduced: 9.0)
@available(watchOS, unavailable, introduced: 2.0)
@available(*, unavailable)
extension Data.Deallocator : Sendable {}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {
    /// The hash value for the data.
    @inline(never) // This is not inlinable as emission into clients could cause cross-module inconsistencies if they are not all recompiled together.
    public func hash(into hasher: inout Hasher) {
        _representation.hash(into: &hasher)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {
    /// Returns `true` if the two `Data` arguments are equal.
    @inlinable // This is @inlinable as emission into clients is safe -- the concept of equality on Data will not change.
    public static func ==(d1 : Data, d2 : Data) -> Bool {
        // See if both are empty
        switch (d1._representation, d2._representation) {
        case (.empty, .empty):
            return true
        default:
            // Continue on to checks below
            break
        }
        
        let length1 = d1.count
        let length2 = d2.count
        
        // Unequal length data can never be equal
        guard length1 == length2 else {
            return false
        }
        
        if length1 > 0 {
            return d1.withUnsafeBytes { (b1: UnsafeRawBufferPointer) in
                return d2.withUnsafeBytes { (b2: UnsafeRawBufferPointer) in
                    // If they have the same base address and same count, it is equal
                    let b1Address = b1.baseAddress!
                    let b2Address = b2.baseAddress!
                    
                    guard b1Address != b2Address else {
                        return true
                    }

                    // Compare the contents
                    assert(length1 == b2.count)
                    return memcmp(b1Address, b2Address, length1) == 0
                }
            }
        }
        return true
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data : CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// A human-readable description for the data.
    public var description: String {
        return "\(self.count) bytes"
    }

    /// A human-readable debug description for the data.
    public var debugDescription: String {
        return self.description
    }

    public var customMirror: Mirror {
        let nBytes = self.count
        var children: [(label: String?, value: Any)] = []
        children.append((label: "count", value: nBytes))

        self.withUnsafeBytes { (bytes : UnsafeRawBufferPointer) in
            children.append((label: "pointer", value: bytes.baseAddress!))
        }

        // Minimal size data is output as an array
        if nBytes < 256 {
            children.append((label: "bytes", value: Array(self)))
        }

        let m = Mirror(self, children:children, displayStyle: Mirror.DisplayStyle.struct)
        return m
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data : Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        // It's more efficient to pre-allocate the buffer if we can.
        if let count = container.count {
            self.init(count: count)

            // Loop only until count, not while !container.isAtEnd, in case count is underestimated (this is misbehavior) and we haven't allocated enough space.
            // We don't want to write past the end of what we allocated.
            for i in 0 ..< count {
                let byte = try container.decode(UInt8.self)
                self[i] = byte
            }
        } else {
            self.init()
        }

        while !container.isAtEnd {
            var byte = try container.decode(UInt8.self)
            self.append(&byte, count: 1)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            try container.encode(contentsOf: buffer)
        }
    }
}
