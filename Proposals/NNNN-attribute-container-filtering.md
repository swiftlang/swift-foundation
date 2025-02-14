# `AttributeContainer` Filtering

* Proposal: [SF-NNNN](NNNN-attribute-container-filtering.md)
* Authors: [Jeremy Schonfeld](https://github.com/jmschonfeld)
* Review Manager: TBD
* Status: **Pitch**
* Implementation: _Awaiting Implementation_
* Review: ([pitch](https://forums.swift.org/t/pitch-attributecontainer-filtering/77890))

## Introduction/Motivation

In [a prior pitch](https://forums.swift.org/t/fou-attributedstring-advanced-attribute-behaviors/55057) we added new advanced attribute behaviors to `AttributedString` which allow attributes to declare how they behave/change across various `AttributedString` operations. Today these behaviors include:

1. Declaring attributes bound to the full length of paragraphs/characters (ensuring consistent values across the full range of the paragraph/character)
2. Declaring attributes that are invalidated and removed when other attributes or text content change
3. Declaring attributes that should not be included when adding new text to the end of a run

Developers define these behaviors on each attribute's `AttributedStringKey` type, but once the attribute values are stored in an `AttributedString`/`AttributeContainer`, developers do not have the ability to inspect the behaviors of the stored attributes dynamically. When using `AttributedString` to store text for more advanced applications such as a text editor, it becomes necessary to create higher level APIs (in modules beyond Foundation) that require knowledge of these behaviors. For example, a text editor that provides APIs for retrieving the "typing attributes" (attributes at the current cursor position) might want to exclude attributes that aren't inherited by additional text. Additionally, an app may wish to provide an API that exposes just the paragraph-bound attributes at a particular location. To support these use cases, we propose adding new APIs to `AttributeContainer` in order to create a "filtered" container with a subset of its attributes based on these behaviors.

## Proposed solution

Given the example above of a text editor getting the "typing attributes" at a current location, the developer might use these new APIs like the following:

```swift
func typingAttributes(in text: AttributedString, selection: UserTextSelection) -> AttributeContainer {
    if selection.isSingleCursor {
        return text.runs[selection.index].attributes.filter(inheritedByAddedText: true)
    } else {
        return text.runs[selection.startIndex].attributes.filter(inheritedByAddedText: true)
    }
}

```

_Note: `UserTextSelection` here is for demonstration purposes only (not proposed API) and represents a simplified selection that could be at a single location or a range of locations._

In this case, the developer's API finds the specified run based on a provided user selection and retrieves its attributes via the `.attributes` property on `AttributedString.Runs.Run`. The developer can now use this new API to filter that `AttributeContainer` to only those attributes that should be inherited by added text (and thus are attributes that you might see in the text editor's selection UI). The developer could similarly call an API like `.filter(runBoundaries: .paragraph)` to filter to only paragraph-level attributes

## Detailed design

We propose adding the following API to `AttributeContainer`:

```swift
@available(FoundationPreview 6.2, *)
extension AttributeContainer {
    /// Returns an attribute container storing only the attributes in `self` with the `inheritedByAddedText` property set to `true`
    public func filter(inheritedByAddedText: Bool) -> AttributeContainer
    
    /// Returns an attribute container storing only the attributes in `self` with a matching run boundary property
    ///
    /// Note: if `nil` is provided then only attributes not bound to any particular boundary will be returned
    public func filter(runBoundaries: AttributedString.AttributeRunBoundaries?) -> AttributeContainer
}
```

## Source compatibility

These changes are additive-only and do not impact the source compatibility of existing apps.

## Implications on adoption

These new APIs will be annotated with `FoundationPreview 6.2` availability.

## Future directions

No specific future directions are considered at this time, however if we add additional applicable attribute key beahviors in the future we can choose to add additional "filtering" APIs to `AttributeContainer` to support filtering by those behaviors.

## Alternatives considered

### Filtering APIs based on invalidation conditions

The only other current attribute key behavior is an attributes invalidation conditions which specify when attributes should be removed (for example, when another specific attribute changes value). I chose not to add `AttributeContainer` APIs to filter based on invalidation conditions mainly because invalidation conditions are already themselves "filters" in a sense as they filter attributes automatically when mutations happen. I could not find a real world use case where you might want to find all attribute values that depend on a particular other attribute value because Foundation already handles the invalidation/filtering of the dependent attributes automatically.

### Generic filtering (ex. a closure based approach)

I had also considered the merit of making a more general, closure-based approach that matches the `Collection` type's `filter(_:)` API which takes a `Bool`-returning closure. However, this approach did not seem feasible because unlike a `Collection` of a known element type, the `AttributeContainer` is a heterogeneous collection of many different value types (declared by many different key types). The closure could be established in such a way that it accepts a generic attributed string key type / value, however I found that it had minimal utility (as it proved no more useful than the APIs proposed here) and put significant constraints on the underlying representation of `AttributeContainer` (since `AttributeContainer` would need to store all of the `AttributedStringKey` types for each attribute value - it does not do so today - so that it can provide them in case a filter call is made). Therefore I felt that while a more generic approach might be more "future proof" with additional filtering APIs, the significant downsides made the approach unappealing compared to the specific filtering APIs proposed here.

### Computed properties rather than `func filter(...)`

Originally, I had investigated whether computed properties such as `AttributeContainer.attributesInheritedByAddedText` would be better than overloads of the `filter(...)` naming scheme. However, the inconsistent naming would make these properties hard to find, it required repeating words for clarity (like "attributes"), and it didn't extend to all filtering options (like the run boundaries which needs to be a function in order to support providing which boundary to filter). In the end, we determined that a consistent `filter` name with varying overloads for each property to filter by would be best for discoverability and consistency.

### A single `filter(...)` function with multiple parameters

I had also considered whether `AttributeContainer.filter(...)` should be a single function with multiple parameters each with a default value. This would allow for filtering based on multiple constraints at once. However, this approach proved nonideal for a few reasons:

- With a single overload, calling `filter()` with no arguments would be possible and this would be undesirable as it would effectively be a no-op
- It's unclear what the default value for the run boundary filter parameter should be as `nil` could be taken to mean either "no filtering based on run boundaries" or "filter to attributes without any run boundaries". Ideally we'd provide a way to perform both, but that isn't quite feasible with this approach
- As more properties are added in the future that developers may want to filter by, it requires a combinatorial explosion of overloads for various combinations of attributes

Instead, we decided that `filter` overload with a single parameter for each filter parameter would be ideal to avoid an explosion of future overloads and ensure the behavior of this function is clear and well defined.
