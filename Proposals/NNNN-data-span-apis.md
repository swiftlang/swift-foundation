# Data Manipulation with Spans

* Proposal: [SF-NNNN](NNNN-data-span-apis.md)
* Authors: [Jeremy Schonfeld](https://github.com/jmschonfeld)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: TBD
* Review: ([pitch](https://forums.swift.org/t/pitch-data-manipulation-with-spans/87952))

## Introduction/Motivation

`Data` is a container type that represents a contiguous region of untyped memory. Today, `Data` conforms to `RangeReplaceableCollection` and therefore inherits many APIs that manipulate the data by providing a `Sequence<UInt8>`. However, libraries are beginning to provide APIs that provide lifetime bound spans to represent contiguous memory for their performance characteristics and lifetime guarantees. As more APIs adopt span types for their interfaces, it's important that `Data` gains APIs to interface with them directly. Just like `Data` provides a `bytes` property to easily access the initialized portion of a `Data`, `Data` should directly provide additional APIs to initialize and mutate the `Data` through spans.


## Proposed solution and example

Now that [SE-0527](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0527-rigidarray-uniquearray.md) has been approved and solidified the naming convention of span-based, `RangeReplaceableCollection`-like APIs, we can adopt those naming conventions for new `Data` APIs to achieve this goal. I am proposing introducing new APIs that mirror those on `UniqueArray` and but use `RawSpan` instead of `Span<Element>`. I propose using `RawSpan` here rather than `Span<UInt8>` because `RawSpan` more closely aligns with `Data`'s intended semantic purpose (a contiguous region of untyped memory). Using [SE-0525](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0525-rawspan-safe-loading-api.md), developers can easily interface these raw span APIs with a typed span of any (safe) element type of their choosing.

```swift
var someBytes: RawSpan = /* receive some bytes from a span-vending API */
var data = Data(copying: someBytes)
data.insert(addingCount: 2, at: 0) { outputRawSpan in
   insertHeaderBytes(&outputRawSpan) // call an API that inserts some bytes at the front
}
```

This allows developers to use a `Data` as their owned storage type while easily interfacing with more generic (while still performant) APIs that use span types to provide/write bytes.

## Detailed design

### New APIs

I propose adding the following new APIs to `Data`:

```swift
extension Data {
    /// Creates a new data with the specified capacity, holding a copy of the bytes of the given span.
    ///
    /// - Parameters:
    ///   - capacity: The storage capacity of the new data, or nil to allocate just enough capacity to store the bytes of the span.
    ///   - span: The span whose bytes to copy into the new data. The span must not contain more than `capacity` bytes.
    @export(implementation)
    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    public init(
        capacity: Int? = nil,
        copying span: RawSpan
    )
    
    /// Arbitrarily edit the storage underlying this data by invoking a user-supplied closure with a mutable `OutputRawSpan` view over it. This method calls its function argument at most once, allowing it to arbitrarily modify the contents of the output span it is given. The argument is free to add, remove or reorder any items; however, it is not allowed to replace the span or change its capacity.
    ///
    /// When the function argument finishes (whether by returning or throwing an error) the data instance is updated to match the final contents of the output span.
    ///
    /// - Parameter body: A function that edits the contents of this data through an `OutputRawSpan` argument. This method invokes this function at most once.
    /// - Returns: This method returns the result of its function argument.
    @export(implementation)
    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    public mutating func edit<E: Error, R: ~Copyable>(
        _ body: (inout OutputRawSpan) throws(E) -> R
    ) throws(E) -> R
    
    /// Copies the bytes of a raw span to the end of this data.
    ///
    /// If the capacity of the data isn't sufficient to perform the append, then this reallocates the data's storage to extend its capacity.
    ///
    /// - Parameters:
    ///    - newBytes: A raw span whose contents to copy into the data.
    @export(implementation)
    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    public mutating func append(copying newBytes: RawSpan)
    
    /// Inserts a given number of new bytes into this data at the specified position, using a callback to directly initialize data storage by populating an output raw span.
    ///
    /// Existing bytes in the data's storage are moved towards the back as needed to make room for the new bytes.
    ///
    /// If the capacity of the data isn't sufficient to perform the insertion, then this reallocates the data's storage to extend its capacity.
    ///
    ///     var prefix: RawSpan = /* a raw span containing the bytes 11, 99 */
    ///     var buffer = Data(capacity: 20, copying: prefix)
    ///     var i: UInt8 = 0
    ///     buffer.insert(addingCount: 3, at: 1) { target in
    ///       while !target.isFull {
    ///         target.append(i)
    ///         i += 1
    ///       }
    ///     }
    ///     // `buffer` now contains the bytes 11, 0, 1, 2, and 99
    ///
    /// If the callback fails to fully populate its output raw span or if it throws an error, then the data keeps all items that were successfully initialized before the callback terminated the insertion.
    ///
    /// Partial insertions create a gap in data storage that needs to be closed by moving already inserted bytes to their correct positions given
    /// the adjusted count. This adds some overhead compared to adding exactly as many items as promised.
    ///
    /// - Parameters:
    ///    - newBytesCount: The maximum number of bytes to insert into the data.
    ///    - index: The position at which to insert the new items. `index` must be a valid index in the data, or equal to the data's `endIndex` (in which case the new bytes are appended to the end of the data).
    ///    - initializer: A callback that gets called at most once to directly populate newly reserved storage within the data. The function is always called with an empty output span.
    @export(implementation)
    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    public mutating func insert<E: Error>(
        addingCount newBytesCount: Int,
        at index: Int,
        initializingWith initializer: (inout OutputRawSpan) throws(E) -> Void
    ) throws(E)
    
    /// Copies the bytes of a raw span into this data at the specified position.
    ///
    /// The new bytes are inserted before the byte currently at the specified index. If you pass the data's `endIndex` as the `index` parameter, then the new bytes are appended to the end of the data.
    ///
    /// All existing bytes at or following the specified position are moved to make room for the new bytes.
    ///
    /// If the capacity of the data isn't sufficient to perform the insertion, then this reallocates the data's storage to extend its capacity.
    ///
    /// - Parameters:
    ///    - newBytes: The new bytes to insert into the data.
    ///    - index: The position at which to insert the new bytes. It must be a valid index of the data.
    @export(implementation)
    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    public mutating func insert(
        copying newBytes: RawSpan, at index: Int
    )
    
    /// Replaces the specified range of bytes by a given count of new bytes, using a callback to directly initialize data storage by populating
    /// an output raw span.
    ///
    /// The number of new bytes need not match the number of bytes being removed.
    ///
    /// This method has the same overall effect as calling
    ///
    ///     try data.removeSubrange(subrange)
    ///     try data.insert(
    ///       addingCount: newBytesCount,
    ///       at: subrange.lowerBound,
    ///       initializingWith: initializer)
    ///
    /// However, it performs faster (by a constant factor) by avoiding moving some bytes in the data twice.
    ///
    /// If the capacity of the data isn't sufficient to perform the replacement, then this reallocates the data's storage to extend its capacity.
    ///
    /// If the callback fails to fully populate its output raw span or if it throws an error, then the data keeps all bytes that were successfully initialized before the callback terminated the replacement.
    ///
    /// Partial replacements create a gap in data storage that needs to be closed by moving subsequent bytes to their correct positions given the adjusted count. This adds some overhead compared to adding exactly as many bytes as promised.
    ///
    /// - Parameters:
    ///   - subrange: The subrange of the data to replace. The bounds of the range must be valid indices in the data.
    ///   - newBytesCount: The maximum number of new bytes to insert in place of the old subrange.
    ///   - initializer: A callback that gets called at most once to directly populate newly reserved storage within the data. The function is always called with an empty output raw span.
    @export(implementation)
    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    public mutating func replaceSubrange<E: Error>(
        _ subrange: Range<Int>,
        addingCount newBytesCount: Int,
        initializingWith initializer: (inout OutputRawSpan) throws(E) -> Void
    ) throws(E) -> Void

    /// Replaces the specified subrange of bytes by copying the bytes of the given raw span.
    ///
    /// This method has the effect of removing the specified range of bytes from the data and inserting the new bytes starting at the same location. The number of new bytes need not match the number of bytes being removed.
    ///
    /// If the capacity of the data isn't sufficient to perform the replacement, then this reallocates the data's storage to extend its capacity.
    ///
    /// If you pass a zero-length range as the `subrange` parameter, this method inserts the bytes of `newBytes` at `subrange.lowerBound`. Calling the `insert(copying:at:)` method instead is preferred in this case.
    ///
    /// Likewise, if you pass a zero-length raw span as the `newBytes` parameter, this method removes the bytes in the given subrange without replacement. Calling the `removeSubrange(_:)` method instead is preferred in this case.
    ///
    /// - Parameters:
    ///   - subrange: The subrange of the data to replace. The bounds of the range must be valid indices in the data.
    ///   - newBytes: The new bytes to copy into the data.
    @export(implementation)
    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    public mutating func replaceSubrange(
        _ subrange: Range<Int>,
        copying newBytes: RawSpan
    )
}
```

### Amendments to Existing API

Additionally, I propose that we amend the previously-approved span-based append and init functions on `Data` to the following:

```swift
extension Data {
    /// Creates a new data with the specified capacity, directly initializing its storage using an output raw span.
    ///
    /// - Parameters:
    ///   - capacity: The storage capacity of the new data.
    ///   - initializer: A callback that gets called at most once to directly populate newly reserved storage within the data. The function is allowed to add fewer than `capacity` bytes. The data is initialized with however many bytes the callback adds to the output raw span before it returns (or before it throws an error).
    @export(implementation)
    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    public init<E: Error>(
        capacity: Int,
        initializingWith initializer: (inout OutputRawSpan) throws(E) -> Void
    ) throws(E)
    
    /// Append a given number of bytes to the end of this data by populating output raw span.
    ///
    /// If the capacity of the data isn't sufficient to perform the append, then this reallocates the data's storage to extend its capacity.
    ///
    /// If the callback fails to fully populate its output raw span or if it throws an error, then the data keeps all items that were successfully initialized before the callback terminated the operation.
    ///
    /// - Parameters:
    ///    - newByteCount: The number of bytes to append to the data.
    ///    - initializer: A callback that gets called at most once to directly populate newly reserved storage within the data. The function is allowed to initialize fewer than `newByteCount` bytes. The data is extended by however many bytes the callback appends to the output raw span before it returns (or throws an error).
    @export(implementation)
    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, *)
    public mutating func append<E: Error>(
        addingCount newByteCount: Int,
        initializingWith initializer: (inout OutputRawSpan) throws(E) -> Void
    ) throws(E)
}
```

Notably, the previously-approved `Data(rawCapacity:initializingWith:)` and `Data.append(addingRawCapacity:initializingWith:)` APIs will be removed entirely. The previously-approved `Data(capacity:initializingWith:)` and `Data.append(addingCapacity:initializingWith:)` APIs will be updated to take an `OutputRawSpan` (in place of `OutputSpan<UInt8>`), and the latter will be renamed to `Data.append(addingCount:initializingWith:)` to follow the naming convention established by [SE-0527](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0527-rigidarray-uniquearray.md). This consolidates `Data`'s span-based APIs on the raw span types (rather than requiring duplicated APIs for raw and `UInt8`-bound operations on `Data`). For clients wishing to use a `Span` of some element type, they can use the APIs approved in [SE-0525](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0525-rawspan-safe-loading-api.md) to easily convert between `RawSpan`/`Span<T>` and `OutputRawSpan`/`OutputSpan<T>`.

## Source compatibility

The new APIs are additive only and have no impact on source compatibility.

The amended APIs are recently approved but have not officially shipped yet, so we are still able to change them without breaking any stable clients.

## Implications on adoption

All APIs will have availability that matches the availability of the span types. Clients may backdeploy callers as far back as span types are backdeployed.

## Alternatives considered

### Provide both `RawSpan`- and `Span<UInt8>`-based APIs

Previous proposals added APIs to `Data` that offered both untyped and `UInt8`-bound variants. However, in this proposal I have chosen to simplify the API surface to only use the raw span types. With the introduction of [SE-0525](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0525-rawspan-safe-loading-api.md) clients have the tools needed to move between raw and typed spans, so providing both isn't critical. This move also emphasizes the semantic promise of `Data` that the stored bytes are viewed as untyped memory and clients are free to interpret the bytes as any safely loadable/storeable element type.

Providing separate untyped and typed APIs on `Data` would also allow `Data` to conform to the future `Iterable` (`BorrowingSequence`) protocol. Without the separation, `Data` could not conform because `Data`'s `RawSpan` APIs would create overload ambiguities with `Iterable`'s `Span` APIs. However I don't feel that we would actually want to introduce this conformance. I've found that most cases where clients use a `Data` as a generic `Sequence` suffer from performance or correctness issues and clients are better off operating on the span types instead. The span types are also expected to conform to future non-copyable iteration protocols, so clients will be able to easily retrieve a span (for any element type `T`) and use that as an `Iterable` interface to pass to other APIs.

