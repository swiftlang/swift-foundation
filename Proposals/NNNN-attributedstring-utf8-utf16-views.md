# `AttributedString` UTF-8 and UTF-16 Views

* Proposal: [SF-NNNN](NNNN-attributedstring-utf8-utf16-views.md)
* Authors: [Jeremy Schonfeld](https://github.com/jmschonfeld)
* Review Manager: TBD
* Status: **Pitch**
* Implementation: [swiftlang/swift-foundation#1066](https://github.com/swiftlang/swift-foundation/pull/1066)

## Introduction/Motivation

In macOS 12-aligned releases, Foundation added the `AttributedString` type as a new API representing rich/attributed text. `AttributedString` itself is not a collection, but rather a type that offers various views into its contents where each view represents a `Collection` over a different type of element. Today, `AttributedString` offers three views: the character view (`.characters`) which provides a collection of grapheme clusters using the `Character` element type, the unicode scalar view (`.unicodeScalars`) which provides a collection of `Unicode.Scalar`s, and the attribute runs view (`.runs`) which provides a collection of attribute runs present across the text using the `AttributedString.Runs.Run` element type. These three views form the critical APIs required to interact with an `AttributedString` via its text (either at the visual, grapheme cluster level or the underlying scalar level) and its runs. However, more advanced use cases require other ways to view an `AttributedString`'s text.

When working with the text content of an `AttributedString`, sometimes it is necessary to view not only the characters or unicode scalars, but the underlying UTF-8 or UTF-16 contents that make up that text. This can be especially useful when interoperating with other types that use UTF-8 or UTF-16 encoded units as their currency types (for example, `NSAttributedString` and `NSString` which use UTF-16 offsets and UTF-16 scalars as their index and element types). Today, `String` itself has a UTF-8 and UTF-16 view that can be used to perform these encoding-specific operations, however `AttributedString` offers no equivalent. This proposal seeks to remedy this by adding equivalent UTF-8 and UTF-16 views to `AttributedString`, offering easy access to the encoded forms of the text.

## Proposed solution

Just like `String`, `AttributedString` will offer new, immutable UTF-8 and UTF-16 character views via the `.utf8` and `.utf16` properties. Developers will be able to use these new views like the following example:

```swift
var attrStr: AttributedString

// Iterate over the UTF-8 scalars
for scalar in attrStr.utf8 {
    print(scalar)
}

// Determine the UTF-8 offset of a particular index
let offset = attrStr.utf8.distance(from: attrStr.startIndex, to: someOtherIndex)
```

## Detailed design

We propose adding the following API surface:

```swift
@available(FoundationPreview 6.2, *)
extension AttributedString {
    public struct UTF8View : BidirectionalCollection, CustomStringConvertible, Sendable {
        public typealias Element = UTF8.CodeUnit
        public typealias Index = AttributedString.Index
        public typealias SubSequence = AttributedString.UTF8View
    }
    
    public struct UTF16View : BidirectionalCollection, CustomStringConvertible, Sendable {
        public typealias Element = UTF16.CodeUnit
        public typealias Index = AttributedString.Index
        public typealias SubSequence = AttributedString.UTF16View
    }
    
    public var utf8: UTF8View { get }
    public var utf16: UTF16View { get }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
protocol AttributedStringProtocol {
    // ...
    
    @available(FoundationPreview 6.2, *)
    var utf8: AttributedString.UTF8View { get }
    @available(FoundationPreview 6.2, *)
    var utf16: AttributedString.UTF16View { get }
}

@available(FoundationPreview 6.2, *)
extension AttributedSubstring {
    public var utf8: AttributedString.UTF8View { get }
    public var utf16: AttributedString.UTF16View { get }
}
```

_Note: omitted here for brevity, `AttributedString.UTF8View` and `AttributedString.UTF16View` must implement all relevant, optional protocol requirements from `BidirectionalCollection` and `RangeReplaceableCollection` to ensure efficient operations over the underlying storage_

## Source compatibility

All of these changes are additive and have no impact on source compatibility except for the addition to `AttributedStringProtocol`. The added requirements to `AttributedStringProtocol` are both source and ABI breaking changes for any clients that have types conforming to this protocol. However, as declared by `AttributedStringProtocol`'s documentation, only Foundation is allowed to conform types to this protocol and other libraries outside of Foundation may not declare a conformance. Therefore, I feel that this is a suitable change to make as we will ensure that Foundation itself does not break and any clients that have declared conformances themselves are in violation of this type's API contract.

## Implications on adoption

These new views will be annotated with `FoundationPreview 6.2` availability. On platforms where availability is relevant, these APIs may only be used on versions where these new views are present.

## Future directions

No future directions are considered at this time.

## Alternatives considered

No alternatives are considered at this time.
