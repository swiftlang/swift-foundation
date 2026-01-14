# Adopting Span in ContiguousBytes

* Proposal: [SF-0034](0034-ContiguousBytes-Span.md)
* Authors: [Doug Gregor](https://github.com/DougGregor)
* Review Manager: Tina L
* Status: **Review: 2026-01-13...2026-01-21**
* Bug: *if applicable* [swiftlang/swift-foundation#NNNNN](https://github.com/swiftlang/swift-foundation/issues/NNNNN)
* Implementation: https://github.com/swiftlang/swift-foundation/pull/1565
* Review: ([pitch](https://forums.swift.org/t/pitch-generalize-contiguousbytes-to-support-span-et-al/83082))

## Introduction

The `ContiguousBytes` protocol provides access to contiguous raw storage for various types that can provide it, including the various `UnsafeBufferPointer` types and arrays of `UInt8`. However, the current design of `ContiguousBytes` does not work with the `Span` family of types, because it assumes that the `Self` type is both `Copyable` and `Escapable`. This proposal generalizes `ContiguousBytes` to support non-copyable and non-escapable types, makes `InlineArray` and the various `Span` types conform to it, and provides a safe counterpart to the `withUnsafeBytes` requirement of `ContiguousBytes`.

## Motivation

[SE-0447](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md) introduced the new `Span` type that provides memory-safe access to a contiguous block of memory. `Span` (and its various `Raw` and `Mutable` versions) is intended to replace most uses of `Unsafe(Mutable)(Raw)BufferPointer`. The `ContiguousBytes` protocol is meant to abstract over various types that can produce a raw buffer of bytes, so it should be updated to work with the `Span` family of types.

## Proposed solution

Updating `ContiguousBytes` involves three related changes:

* The `ContiguousBytes` protocol becomes `~Copyable` and `~Escapable`, so non-copyable and non-escapable types can conform to it.
* The `ContiguousBytes` protocol gains a new `withBytes` function that provides a safe counterpart to the existing `withUnsafeBytes`.
* The `Span`, `MutableSpan`, `RawSpan`, `MutableRawSpan`, `UTF8Span`, `OutputSpan`, `OutputRawSpan`, and `InlineArray` types are made to conform to `ContiguousBytes`.

## Detailed design

The `ContiguousBytes` protocol is updated to be `~Escapable` and `~Copyable`, and well as gaining a `withBytes` counterpart to `withUnsafeBytes`, as follows:

```swift
public protocol ContiguousBytes: ~Escapable, ~Copyable {
    /// Calls the given closure with the contents of underlying storage.
    ///
    /// - note: Calling `withUnsafeBytes` multiple times does not guarantee that
    ///         the same buffer pointer will be passed in every time.
    /// - warning: The buffer argument to the body should not be stored or used
    ///            outside of the lifetime of the call to the closure.
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R

    /// Calls the given closure with the contents of underlying storage.
    ///
    /// - note: Calling `withBytes` multiple times does not guarantee that
    ///         the same span will be passed in every time.
    func withBytes<R, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R
}
```

The `withBytes` operation retains the same form as the existing `withUnsafeBytes`. However, it provides a `RawSpan` to the provided closure, which ensures that the buffer argument does not outlive the call. Additionally it uses [typed throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md) instead of `rethrows` to provide more accurate thrown errors and better support Embedded Swift.

### Default implementation of `withBytes`

To provide source compatibility for existing types that conform to `ContiguousBytes`, there is a default implementation of `withBytes` that calls into `withUnsafeBytes` and extracts a span from the provided buffer:

```swift
extension ContiguousBytes where Self: ~Escapable, Self: ~Copyable {
    /// Calls the given closure with the contents of underlying storage.
    ///
    /// - note: Calling `withBytes` multiple times does not guarantee that
    ///         the same span will be passed in every time.
    public func withBytes<R, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R { ... }
}
```

### New conformances to `ContiguousBytes`

The `RawSpan` , `MutableRawSpan`, `OutputRawSpan`, and `UTF8Span` types will all conform to `ContiguousBytes`:

```swift
extension RawSpan: ContiguousBytes { }

extension MutableRawSpan: ContiguousBytes { }

extension OutputRawSpan: ContiguousBytes { }

extension UTF8Span: ContiguousBytes {
  public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { ... }
}
```

The `Span`, `MutableSpan`, `OutputSpan`, and `InlineArray` types will conditionally conform to `ContiguousBytes` when the element type is `UInt8`, just like `Array` and `Unsafe(Mutable)BufferPointer` already do:

```swift
extension Span: ContiguousBytes where Element == UInt8 { }

extension MutableSpan: ContiguousBytes where Element == UInt8 { }

extension OutputSpan: ContiguousBytes where Element == UInt8 { }

extension InlineArray: ContiguousBytes where Element == UInt8 {
    public func withUnsafeBytes<R, E>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R { ... }
}
```

### Implementation of `withBytes` for each concrete type

Each concrete type described above as conforming to `ContiguousBytes` , as well as existing standard-library types (such as the unsafe buffer pointer types) that conform to the protocol, will also get an implementation of `withBytes` with the following signature:

```swift
public func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R
```

The concrete implementations of `withBytes` support a non-copyable result type `R`, making them slightly more general than `withUnsafeBytes` or the protocol requirement.

## Source compatibility

The generalization of a protocol to support non-copyable and non-escapable types does not have any impact on source compatibility, because any use of the protocol that does not suppress the `Copyable` or `Escapable` requirement will get them by default. 

The addition of the `withBytes` requirement to the `ContiguousBytes` protocol is paired with a default implementation in terms of the existing `withUnsafeBytes` to maintain source compatibility with existing types that conform to the `ContiguousBytes` protocol.

## Implications on adoption

Making `ContiguousBytes` non-copyable and non-escapable doesn't immediately help with existing APIs based on the protocol. However, existing APIs can often be generalized to work with `Span` et al without breaking source or binary compatibility. As an example, consider an API like this:

```swift
func encrypt<Bytes: ContiguousBytes>(_ bytes: Bytes) -> [UInt8] { ... }
```

This API can be generalized to work with `Span` et al by suppressing the `Copyable` and `Escapable` constraints on the `Bytes` generic parameter, like this:

```swift
func encrypt<Bytes: ContiguousBytes>(_ bytes: Bytes) -> [UInt8] 
    where Bytes: ~Copyable, Bytes: ~Escapable {
 ... 
}
```

Now this API supports callers using `Span` et al directly, while still working for all existing calls. To make this change while retaining the same ABI, one can use the `@abi` attribute introduced in [SE-0476](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0476-abi-attr.md). For example:

```swift
@abi(func encrypt<Bytes: ContiguousBytes>(_ bytes: Bytes) -> [UInt8])
func encrypt<Bytes: ContiguousBytes>(_ bytes: Bytes) -> [UInt8] 
    where Bytes: ~Copyable, Bytes: ~Escapable {
 ... 
}
```

Note that the `@abi` attribute should only be used in this manner when the implementation of the function avoids making copies or escaping the values of type `Bytes`. The escaping requirement was always a semantic requirement for the buffer passed into the closure, but copies could have been implicitly generated in existing versions of the `encrypt` function. Correctly verifying that there are no copies in an existing function would require inspecting the compiler's output for any already-shipped implementation of the `encrypt` function, and any that do produce copies would cause crashes at runtime when provided with a non-copyable type. Therefore, it is safer for ABI-stable APIs like this to generalize only to permit non-escapable types but retain the implicit `Copyable` requirement:

```swift
@abi(func encrypt<Bytes: ContiguousBytes>(_ bytes: Bytes) -> [UInt8])
func encrypt<Bytes: ContiguousBytes>(_ bytes: Bytes) -> [UInt8]
    where Bytes: ~Escapable {
 ...
}
```

This means that the `encrypt` function will not be usable with non-copyable types like `MutableSpan`, rather than potentially crashing with such types.

Ideally, Swift code bases using `ContiguousBytes` would move from using `withUnsafeBytes` to using the safer `withBytes` introduced by this proposal. This can be helped somewhat by the opt-in strict memory safety mode introduced in [SE-0458](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md), which will identify uses of unsafe buffer pointers and require them to be marked `unsafe`.

## Alternatives considered

### Replace `withBytes` with a property

An alternative to the new `withBytes` requirement of `ContiguousBytes` is to provide a property

```swift
var bytes: RawSpan { get }
```

in the protocol. This has various benefits over the `withBytes` API proposed here, including:

* One does not need to nest all code that accesses these bytes within a closure, eliminating a level of indentation and extra ceremony around the calls.
* The property will work within `async` functions, whereas `withBytes` does not have an `async` counterpart.
* Captures of non-copyable types within closures aren't currently available, so they cannot be used well when calling `withBytes`.
* The `withBytes` function is a generic protocol requirement, which limits the use of the protocol in Embedded Swift, which cannot call into generic protocol requirements from existentials.

However, not all types that currently conform to the `ContiguousBytes` protocol can provide a `bytes` property that satisfies this requirement. For example, a type that needs to materialize data into a buffer to pass to the closure provided to `with(Unsafe)Bytes` would not be able to implement this property, which depends on having the lifetime of the resulting `RawSpan` tied to that of its enclosing type. [SE-0456](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md) describes some of the changes required in the implementations of `String.UTF8View` and `Array` that were needed to provide `span` properties and which might not be possible for other types. Therefore, while adding this property would provide more ergonomic access to the contiguous bytes of a type, doing so necessarily breaks source compatibility. This property can only be introduced as part of a new protocol.

### Allow the result of `withBytes` to be non-copyable

The `withBytes` requirement of `ContiguousBytes` could be generalized slightly to allow the result type to be noncopyable, e.g.,

```swift
    /// Calls the given closure with the contents of underlying storage.
    ///
    /// - note: Calling `withBytes` multiple times does not guarantee that
    ///         the same span will be passed in every time.
    func withBytes<R: ~Copyable, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R
```

However, doing so on the protocol itself would break source compatibility, because one cannot correctly implement `withBytes` for a non-copyable result type `R` in terms of the existing `withUnsafeBytes`. Therefore, we settle for only supporting non-copyable result types in the concrete `withBytes` implementations.

### Use an `Element: BitwiseCopyable` requirement instead of `Element == UInt8`

The various generic types conditionally conform to `ContiguousBytes` when they store `UInt8` (byte) elements. Conceptually, it would be more general to allow the element to be any `BitwiseCopyable` type (as defined be [SE-0426](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0426-bitwise-copyable.md)). However, SE-0426 defines limitations on the use of `BitwiseCopyable` that prohibit it from being used for the conditional conformance.

It would be possible to generalize the `withBytes` operations on `Span` et al to work on `BitwiseCopyable`element types, but doing so does not seem worth it: the `withBytes` functions aren't particularly useful when you already have a concrete type in the `Span` family, because they already provide `bytes` properties.

## Future directions

### Deprecating `withUnsafeBytes`

In the future, we could consider deprecating `withUnsafeBytes` in favor of `withBytes`: aside from source and backward compatibility, there is no reason to use `withUnsafeBytes` instead of `withBytes`, and the latter is safer.

### Sinking `ContiguousBytes` into the standard library

The notion of a type that stores contiguous bytes is fairly general, and most of the types that conform to this protocol are in the standard library itself. With the introduction of `Span` et al into the standard library, there is more of an emphasis on safe access to contiguous regions of memory. It is possible to move the `ContiguousBytes` protocol into the standard library while maintaining source and binary compatibility.

However, even with the changes in this proposal, `ContiguousBytes` does not provide an ideal abstraction for types that can provide access to their contiguous storage. As noted in the "Alternatives considered" section, a better interface would involve a `bytes` property, but that cannot be added to `ContiguousBytes` in a source-compatible manner:

```swift
var bytes: RawSpan { get }
```

Given that `ContiguousBytes` is not and cannot become the ideal abstraction for contiguous storage in the standard library, the standard library would likely gain another protocol. One design for such a protocol would be as a refinement of `ContiguousBytes` (if both were in the standard library), e.g.,

```swift
protocol RawBytes: ContiguousBytes {
  @_lifetime(self)
  var bytes: RawSpan { get }
}
```

with default implementations that satisfy the `ContiguousBytes` requirements based on `bytes`:

```swift
extension ContiguousBytes where Self: RawBytes {
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
      try bytes.withUnsafeBytes { try body($0) } }
    }

    public func withBytes<R, E>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
      try body(bytes)
    }
}
```

New APIs would be expressed in terms of `RawBytes`, while existing APIs could still use `ContiguousBytes` for compatibility reasons. This may provide a smoother evolution path than adding `RawBytes` or similar to the standard library independently of `ContiguousBytes`, but at the cost of adding an effectively deprecated protocol (`ContiguousBytes`) to the standard library itself.