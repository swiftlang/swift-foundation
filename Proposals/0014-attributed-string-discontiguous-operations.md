# `AttributedString` Discontiguous Operations

* Proposal: [SF-0014](0014-attributed-string-discontiguous-operations.md)
* Authors: [Jeremy Schonfeld](https://github.com/jmschonfeld)
* Review Manager: [Tina Liu](https://github.com/itingliu)
* Status: **Accepted**
* Review: ([Pitch](https://forums.swift.org/t/pitch-attributedstring-discontiguous-operations/76574)) 

## Introduction

In [SE-0270](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0270-rangeset-and-collection-operations.md), we added a new `RangeSet` type to Swift (representing a sorted, noncontiguous set of ranges in a collection) along with collection APIs that perform operations over referenced noncontiguous elements. These APIs have proved beneficial for use in a variety of collections to easily locate, identify, and mutate multiple ranges of elements in single expressions. `AttributedString` has already benefitted from these generic collection APIs that are available via the character, unicode scalar, and runs view. However, as `AttributedString` does not conform to `Collection` itself, it lacks proper, fully integrated support for operations over discontiguous segments.

## Motivation

Using `RangeSet`-based APIs provided on the `AttributedString` type directly instead of its individual collection views can be very beneficial. In particular, full support for discontiguous representations of an `AttributedString` are critical for modeling concepts such as an `AttributedString`'s selection from a UI (either multiple, discontiguous visual collections or a singular visual selection that maps to discontiguous ranges in the logical text storage due to mixed RTL/LTR text). Discontiguous operations would allow for not only iterating over discontiguous contents but will also add the ability to mutate attributes over these discontiguous ranges (which is not possible today with the immutable `runs` view). We feel that providing these tools will improve the parity between `AttributedString` and other standard collection types (like `String`) and will set up `AttributedString` for success as the best model representation of rich text.

## Proposed solution

Developers can use APIs provided by the standard library today to create `RangeSet`s representing indices:

```swift
var text = AttributedString("Hello, world!")
let indicesOfL: RangeSet<AttributedString.Index> = text.characters.indices(of: "l")
```

These new APIs will allow developers to use those indices on `AttributedString` operations, such as the following:

```swift
// Make all "l"s blue
text[indicesOfL].foregroundColor = .blue

print(text[indicesOfL]) // "lll { SwiftUI.ForegroundColor = ... }"

// Iterate all foreground colors on the "l"s
for (range, color) in text[indicesOfL].runs[\.foregroundColor] {
    // ...
}
```

## Detailed design

We propose adding the following APIs which will allow usage of `AttributedString` with `RangeSet` in addition to the existing `Range` based APIs. These APIs mirror those APIs available on `Collection` and `MutableCollection` that are applicable to `AttributedString`.

```swift
@dynamicMemberLookup
@available(FoundationPreview 6.2, *)
public struct DiscontiguousAttributedSubstring : AttributedStringAttributeMutation, CustomStringConvertible, Sendable, Hashable {
    public var base: AttributedString { get }
    
    // Implementations from AttributedStringAttributeMutation
    // (setAttributes, mergeAttributes, replaceAttributes, attribute subscripting)
    
    public subscript(bounds: Range<AttributedString.Index>) -> DiscontiguousAttributedSubstring { get }
    public subscript(bounds: RangeSet<AttributedString.Index>) -> DiscontiguousAttributedSubstring { get }
    
    public var characters: DiscontiguousSlice<AttributedString.CharacterView> { get }
    public var unicodeScalars: DiscontiguousSlice<AttributedString.UnicodeScalarView> { get }
    public var utf8: DiscontiguousSlice<AttributedString.UTF8View> { get }
    public var utf16: DiscontiguousSlice<AttributedString.UTF16View> { get }
    public var runs: AttributedString.Runs { get }
}

@available(FoundationPreview 6.2, *)
extension AttributedString {
    public init(_ substring: DiscontiguousAttributedSubstring)
    
    public subscript(_ indices: RangeSet<AttributedString.Index>) -> DiscontiguousAttributedSubstring { get set }
    
    public mutating func removeSubranges(_ subranges: RangeSet<Index>)
}

@available(FoundationPreview 6.2, *)
extension AttributedStringProtocol {
    public subscript(_ indices: RangeSet<AttributedString.Index>) -> DiscontiguousAttributedSubstring { get }
}
```

The `AttributedString.Runs.Index` conformance to `Strideable` unfortunately does not work with a discontiguous slice of runs (since calculating following indices from a given index *must* use the collection when discontiguous chunks of the same run could be sliced). To support discontiguous slices of runs, we will deprecate the strideable conformance of `AttributedString.Runs.Index`:

```swift
@available(macOS, introduced: 12, deprecated: 9999, message: "AttributedString.Runs.Index should not be used as Strideable and should instead be offset using the API provided by AttributedString.Runs")
@available(iOS, introduced: 15, deprecated: 9999, message: "AttributedString.Runs.Index should not be used as Strideable and should instead be offset using the API provided by AttributedString.Runs")
@available(tvOS, introduced: 15, deprecated: 9999, message: "AttributedString.Runs.Index should not be used as Strideable and should instead be offset using the API provided by AttributedString.Runs")
@available(watchOS, introduced: 8, deprecated: 9999, message: "AttributedString.Runs.Index should not be used as Strideable and should instead be offset using the API provided by AttributedString.Runs")
@available(visionOS, introduced: 1, deprecated: 9999, message: "AttributedString.Runs.Index should not be used as Strideable and should instead be offset using the API provided by AttributedString.Runs")
@available(*, deprecated, message: "AttributedString.Runs.Index should not be used as Strideable and should instead be offset using the API provided by AttributedString.Runs")
extension AttributedString.Runs.Index : Strideable {}
```

_Note: These will be deprecated in the `FoundationPreview 6.2`-aligned release but are annotated as `9999` above as deprecation availability is not compatible with the `FoundationPreview 6.2` syntax_

## Source compatibility

Almost all new APIs are additive only and do not break source compatibility for any prior APIs. The only non-additive change is the deprecation of `AttributedString.Runs.Index`'s conformance to `Stridable`, but I don’t foresee that having a wide impact and the `Runs` collection itself still provides the ability to increment/decrement an index via an offset in a correct manner.

## Implications on adoption

These new APIs will be annotated with `FoundationPreview 6.2` availability. Clients that back-deploy code to previous versions and/or need to compile with older versions of the SDK/toolchain will need to check for availability before using these new APIs.

## Future directions

### Further adoption of `RangeSet`-based APIs

We could envision future APIs that use `RangeSet` to mirror some `Range`-based APIs. For example, a `ranges(of: some StringProtocol)` API to mirror our `range(of:)` API could be useful to find all ranges of a particular substring. While I feel these APIs are definitely worth considering, I'm leaving them as a future direction at this time since we do not currently have similar `RangeSet` APIs for other collection types like `String`. This proposal focuses on bringing `AttributedString` up to parity with other collections, but I think there is room for improvement regarding `RangeSet` interoperability with `String`/`AttributedString` as a whole moving forward.

## Alternatives considered

### `DiscontiguousAttributedSubstring` conformance to `AttributedStringProtocol`

For a time I had considered whether `DiscontiguousAttributedSubstring` should conform to `AttributedStringProtcol` so that it can be provided to existing APIs that are defined in terms of `AttributedStringProtocol`. However, there are some requirements that cannot be implemented for `DiscontiguousAttributedString`, namely:

```swift
subscript<R: RangeExpression>(bounds: R) -> AttributedSubstring where R.Bound == AttributedString.Index { get }
```

This API would require that slicing a `DiscontiguousAttributedSubstring` would produce a contiguous `AttributedSubstring`. However, this is not guaranteed to be the case. It is possible that the provided `bounds` may span multiple discontiguous ranges of the `DiscontiguousAttributedSubstring` meaning that this API must produce a `DiscontiguousAttributedString` instead.

For that reason (as well as the added effects this would have on the slicing issues mentioned below), `DiscontiguousAttributedSubstring` does not conform to `AttributedStringProtocol`, but rather solely conforms to `AttributedStringAttributeMutation`.

### Function mutations rather than slicing via `DiscontiguousAttributedSubstring`

This proposal suggests adding a new `DiscontiguousAttributedSubstring` type to use as the return value for slicing an attributed string with a discontiguous range (via `someAttrStr[someRangeSet]`). This approach follows the convention used by `AttributedSubstring` via slicing an attributed string, as well as slicing other collections such as `String`/`Array`. This allows writing simple syntax such as `someAttrStr[someRangeSet].foregroundColor = .blue` to easily express setting an attribute over a particular range. However, this approach does have some complicated semantics:


1. The presence of a mutating subscript requires the presence of a wholesale `set` accessor allowing syntax such as `someAttrStr[someRangeSet] = someOtherAttrStr[someOtherRangeSet]` (in other words, performing a `set` with a distinct discontiguous substring rather than a `_modify` access). This operation could be perceived as ill-defined as it's not immediately clear what the behavior should be when the sizes of these two collections do not match.*

2. The behavior of `_modify`-based mutations may be unexecpected. For example, `someAttrStr[someRangeSet].foregroundColor = .blue` performs an in-place mutation of the underlying `someAttrStr` to update the foregound color. It is also possible to call a function like `someAttrStr[someRangeSet].myCustomFunction()` where `myCustomFunction` is a `mutating` function that assigns to `self`. This results in an out-of-place mutation that attempt to re-assign a `DiscontiguousAttributedSubstring` back to the `someAttrStr` akin to a call to `replaceSubrange`. In other collection types, this has proven problematic (for example, `someArray[someRange].sort()` which appears to perform an in-place sort, but in practice does not) and this has proven especially problematic in the `CharacterView`/`UnicodeScalarView` implementation where these sorts of operations have no choice but to `fatalError`.

The alternative to prevent these issues is to use mutating functions rather than a mutating subscript to allow for slicing. For example, we could choose to not expose a `DiscontiguousAttributedSubstring` type and provide `getAttributeValueForSubranges(_:)`/`setAttributeValueForSubranges(_:)`-style APIs to `AttributedString`. These APIs would have guaranteed expected semantics, but diverge from the known ergonomic APIs that `AttributedString` already uses with `AttributedSubstring`. Despite these potential issues, I feel that the current approach can mitigate them to the best of our ability:


* The only default provided, mutating operations on `DiscontiguousAttributedSubstring` are the set/merge/replace attribute functions, and the attribute subscript syntax (`.foregroundColor`). These all have the expected in-place mutation semantics and do not provide the same breadth of issues as other collections since `DiscontiguousAttributedSubstring` does not conform to `MutableCollection` and therefore does not inherit many mutating operations.
* We can define clear and consistent behavior for the `set` operation of this subscript to be equivalent to calling `replaceSubranges` on the provided `AttributedString`.

It is still possible to write a `mutating` function in an extension on `DiscontiguousAttributedSubstring` that replaces `self` / performs an out-of-place mutation, but it's my opinion that designing an alternative API to avoid this that diverges from the known patterns that `AttributedSubstring` uses would be a less ergonomic and harder to grasp choice than doing our best to make the semantics as expected/consistent as possible knowing that there may be some gaps.
