# Generalize closure-based functions of `Data`

* Proposal: [SF-NNNN](nnnn-generalize-closure-based-functions-in-Data.md)
* Authors: [Guillaume Lessard](https://github.com/glessard)
* Review Manager: TBD
* Status: **Awaiting implementation** or **Awaiting review**
* Bug: *if applicable* [swiftlang/swift-foundation#1638](https://github.com/swiftlang/swift-foundation/issues/1638)

Implementation: [swiftlang/swift-foundation#1622](https://github.com/swiftlang/swift-foundation/pull/1622)

* Review: ([pitch](https://forums.swift.org/...))

## Introduction

We propose to generalize the closure-taking API of `Data` for typed throws and for noncopyable return values, making them able to accept a greater variety of closures.

## Motivation

Since [SE-0427], noncopyable types can participate in Swift generics, but `Data` has not been adapted to allow working with noncopyable values. [SE-0437] paved the way by generalizing low-level constructs such as `UnsafeBufferPointer<T>`, and as a result the community of Swift systems programmers now expects that generic functions such as `withUnsafeBytes()` can return noncopyable values.

In [SE-0413], we also added the ability for functions to throw typed errors. This ability is important in high-performance contexts such as embedded Swift, and functions such as `withUnsafeBytes()` should support closures with typed errors.

`Data`'s current closure-based functions such as `withUnsafeBytes()` cannot take advantage of either of these newer features:

```swift
extension Data {
    public func withUnsafeBytes<ResultType>(
    _ apply: (UnsafeRawBufferPointer) throws -> ResultType
  ) rethrows -> ResultType
}
```



## Proposed solution

We will add support for typed throws and noncopyable return values to the functions of `Data` that take closure arguments with generic types.

## Detailed design

The signatures of `Data`'s three closure-based functions will become:

```swift
extension Data {
  public func withUnsafeBytes<E: Error, ResultType: ~Copyable>(
    _ apply: (UnsafeRawBufferPointer) throws(E) -> ResultType
  ) throws(E) -> ResultType

  public func withContiguousStorageIfAvailable<E: Error, ResultType: ~Copyable>(
    _ body: (_ buffer: UnsafeBufferPointer<UInt8>) throws(E) -> ResultType
  ) throws(E) -> ResultType?

  public mutating func withUnsafeMutableBytes<E: Error, ResultType: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) throws(E) -> ResultType
  ) throws(E) -> ResultType
}
```

These are new functions that replace existing functions in a source-compatible way. The older signature required `ResultType` type to be `Copyable`, allowing it to also satisfy the `~Copyable` constraint. The untyped errors thrown by existing closures are a special case of the typed error case, where `E == any Error`.

## Source compatibility

This change is source-compatible with existing call sites.

## Implications on adoption

On ABI-stable platforms, the existing ABI will be preserved. The new entry points will be declared `@_alwaysEmitIntoClient` in order to help the compiler specialize use sites in practice.

## Alternatives considered

(none)

