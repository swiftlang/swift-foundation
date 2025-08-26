# `AttributedString` Tracking Indices

* Proposal: [SF-0015](0015-attributedstring-tracking-indices.md)
* Authors: [Jeremy Schonfeld](https://github.com/jmschonfeld)
* Review Manager: [Tina Liu](https://github.com/itingliu)
* Status: **Accepted**
* Review: ([Pitch](https://forums.swift.org/t/pitch-attributedstring-tracking-indices/76578/3)) 
* Implementation: [swiftlang/swift-foundation#1109](https://github.com/swiftlang/swift-foundation/pull/1109)

## Revision History

* **v1**: Initial Version
* **v2**: Minor Updates:
    - Added an alternatives considered section about the naming of `transform(updating:_:)`
    - Added a clarification around the impacts of lossening index acceptance behavior
* **v3**: Separate `inout` and returning-`Optional` variants of transformation function

## Introduction

Similar to many other `Collection` types in Swift, `AttributedString` uses an opaque index type (`AttributedString.Index`) to represent locations within the storage of the text. `AttributedString` uses an opaque type instead of a trivial type like an integer in order to store a more complex representation of the location within the text. Specifically, `AttributedString` uses its index to store not only a raw UTF-8 offset into the text storage, but also a "path" through the rope structure that backs the `AttributedString`. This allows `AttributedString` to quickly find a location within the text storage given an index without performing linear scans of the underlying text on each access or mutation. However, because this opaque index type stores more complex information, it must be handled very carefully and kept in-sync with the `AttributedString` itself. Unlike an integer offset (which can often still be a valid index into a collection like `Array` after a mutation even if it points to a different semantic location), `AttributedString.Index` currently makes no guarantees about its validity after any mutation to the `AttributedString` and in many cases will (intentionally) crash when used improperly. As `AttributedString` is adopted in more advanced use cases throughout our platforms, we'd like to improve upon this developer experience for some common use cases of stored `AttributedString.Index`s.

## Motivation

In many cases, developers may wish to use these index types to store "pointers" to locations in the `AttributedString` separately from the text itself. For example, a text editor that uses an `AttributedString` as its underlying storage would likely want to store a `RangeSet<AttributedString.Index>` at the view or view model layer to represent a user's selection in the text while still allowing mutations of the text. Alternatively, complex, in-place, mutating operations that process an `AttributedString` in chunks may wish to temporarily store an `AttributedString.Index` representing the current processing location while it performs mutations on the text. In these scenarios, it is currently challenging (or in some cases not possible) to keep an opaque `AttributedString.Index` in-sync with a separate `AttributedString` while mutations are occuring since every mutation invalidates every previously produced index value. With more complex `AttributedString`-based APIs, it's important that we provide a mechanism for developers to keep these indices not only valid to prevent unexpected applications crashes but also correctly positioned to ensure they achieve expected end user behavior.

## Proposed solution

To accomplish this goal, we will provide a few new APIs to make `AttributedString` index management and synchronization easy to use. First, we will propose a new API that allows `AttributedString` to update an index, range, or list of ranges while a mutation is being performed to ensure the indices remain valid and correct post-mutation. Developers will use a new proposed `transform(updating:_:)` API to do so like the following:

```swift
var attrStr = AttributedString("The quick brown fox jumped over the lazy dog")
guard let rangeOfJumped = attrStr.range(of: "jumped") else { ... }
attrStr.transform(updating: &rangeOfJumped) {
    $0.insert("Wow!", at: $0.startIndex)
}

if let updatedRangeOfJumped {
    print(attrStr[updatedRangeOfJumped]) // "jumped"
}
```

Note that in the above sample code, the updated `Range` references the range of "jumped" which is valid for use with the mutated `attrStr` (it will not crash) and it locates the same text - it does not represent the range of "fox ju" (a range offset by the 4 characters that were inserted at the beginning of the string). We will provide overloads that accept an `inout` range (or list of ranges) to update in-place as well as overloads that return an optional range (or list of ranges) to update out-of-place in order to provide fallback behavior when tracking fails.

Additionally, we will provide a set of APIs and guarantees to reduce the frequency of crashes caused by invalid indices and allow for dynamically determining whether an index has become out-of-sync with a given `AttributedString`. For example:

```swift
var attrStr = AttributedString("The quick brown fox jumped over the lazy dog")
guard var rangeOfJumped = attrStr.range(of: "jumped") else { ... }

// ... some additional processing ...

guard rangeOfJumped.isValid(within: attrStr) else {
    // A mutation has ocurred without correctly updating `rangeOfJumped` - we should not use this range as it may crash or represent the wrong location
}
// `rangeOfJumped` has been correctly kept in-sync with `attrStr` as it has changed, we can use it freely
```

## Detailed design

To support the proposed design, we will introduce the following APIs to keep indices in-sync during mutations:

```swift
@available(FoundationPreview 6.2, *)
extension AttributedString {
    /// Tracks the location of the provided range throughout the mutation closure, updating the provided range to one that represents the same effective locations after the mutation. If updating the provided range is not possible (tracking failed) then this function will fatal error. Use the Optional-returning variants to provide custom fallback behavior.
    /// - Parameters:
    ///   - range: a range to track throughout the `body` closure
    ///   - body: a mutating operation, or set of operations, to perform on the value of `self`. The value of `self` is provided to the closure as an `inout AttributedString` that the closure should mutate directly. Do not capture the value of `self` in the provided closure - the closure should mutate the provided `inout` copy.
    public mutating func transform<E>(updating range: inout Range<Index>, body: (inout AttributedString) throws(E) -> Void) throws(E) -> Void
    
    /// Tracks the location of the provided ranges throughout the mutation closure, updating them to new ranges that represent the same effective locations after the mutation. If updating the provided ranges is not possible (tracking failed) then this function will fatal error. Use the Optional-returning variants to provide custom fallback behavior.
    /// - Parameters:
    ///   - ranges: a list of ranges to track throughout the `body` closure. The updated array (after the function is called) is guaranteed to be the same size as the provided array. Updated ranges are located at the same indices as their respective original ranges in the input `ranges` array.
    ///   - body: a mutating operation, or set of operations, to perform on the value of `self`. The value of `self` is provided to the closure as an `inout AttributedString` that the closure should mutate directly. Do not capture the value of `self` in the provided closure - the closure should mutate the provided `inout` copy.
    public mutating func transform<E>(updating ranges: inout [Range<Index>], body: (inout AttributedString) throws(E) -> Void) throws(E) -> Void
    
    /// Tracks the location of the provided range throughout the mutation closure, returning a new, updated range that represents the same effective locations after the mutation
    /// - Parameters:
    ///   - range: a range to track throughout the `body` closure
    ///   - body: a mutating operation, or set of operations, to perform on the value of `self`. The value of `self` is provided to the closure as an `inout AttributedString` that the closure should mutate directly. Do not capture the value of `self` in the provided closure - the closure should mutate the provided `inout` copy.
    /// - Returns: the updated `Range` that is valid after the mutation has been performed, or `nil` if the mutation performed does not allow for tracking to succeed (such as replacing the provided inout variable with an entirely different AttributedString)
    public mutating func transform<E>(updating range: Range<Index>, body: (inout AttributedString) throws(E) -> Void) throws(E) -> Range<Index>?
    
    /// Tracks the location of the provided ranges throughout the mutation closure, returning new, updated ranges that represents the same effective locations after the mutation
    /// - Parameters:
    ///   - ranges: a list of ranges to track throughout the `body` closure
    ///   - body: a mutating operation, or set of operations, to perform on the value of `self`. The value of `self` is provided to the closure as an `inout AttributedString` that the closure should mutate directly. Do not capture the value of `self` in the provided closure - the closure should mutate the provided `inout` copy.
    /// - Returns: the updated `Range`s that are valid after the mutation has been performed, or `nil` if the mutation performed does not allow for tracking to succeed (such as replacing the provided inout variable with an entirely different AttributedString). When the return value is non-nil, the returned array is guaranteed to be the same size as the provided array. Updated ranges are located at the same indices as their respective original ranges in the input `ranges` array.
    public mutating func transform<E>(updating ranges: [Range<Index>], body: (inout AttributedString) throws(E) -> Void) throws(E) -> [Range<Index>]?
}
```

### Notable Behavior of `transform(updating:_:)`

#### Returning `nil` / crashing

Non-`inout` variants of `transform(updating:_:)` have optional return values because it is possible (although expected to be rare) that `AttributedString` may lose tracking of indices during a mutation. Tracking is lost if the `AttributedString` is completely replaced by another `AttributedString`, for example:

```swift
myAttrStr.transform(updating: someRange) {
    $0 = AttributedString("foo")
}
```

In this case, the `AttributedString` at the end of the mutation closure is an entirely different `AttributedString` than the original provided (not mutated, but rather completely replaced) and therefore it is not possible to keep track of the provided indices. In this situation, `inout` variants of `transform(updating:_:)` will `fatalError` and non-`inout` variants will return `nil` to indicate that the caller should perform fallback behavior appropriate to the caller's situation.

#### Diagnostics for incorrect variant usage

It's possible that a developer may accidentally use the incorrect variant of the `transform(updating:)` function (for example, passing a non-`inout` parameter an expecting it to update in-place or passing an `inout` parameter but also expecting a return value). In these situations, the compiler warns the developer that while the syntax is technically valid it likely isn't what the developer meant:

```swift
var str: AttributedString
var range: Range<AttributedString.Index>

// Providing non-inout range without reading return value
str.transform(updating: range) { // warning: Result of call to 'transform(updating:_:)' is unused
    $0.insert("Wow!", at: $0.startIndex)
}

// Providing inout range while attempting to read return value
let updatedRange = str.transform(updating: &range) { // warning: Constant 'updatedRange' inferred to have type '()', which may be unexpected
    $0.insert("Wow!", at: $0.startIndex)
}
```

These warnings will indicate to the developer that their usage of the function may be incorrect so that the developer can update their code accordingly.

#### Collapsing ranges

`transform(updating:_:)` can in some cases collapse a provided `Range` into a zero-length range indicating a location within the string. For example:

```swift
var myAttrStr = AttributedString("Hello World")
let rangeOfHello = myAttrStr.range(of: "Hello")!
myAttrStr.transform(updating: &rangeOfHello) {
    $0.removeSubrange(rangeOfHello)
}
```

In this case, the mutation removed the range of "Hello" and therefore the returned range will be a zero-length range at a location located just before `startIndex`. Therefore, `transform(updating:_:)` would update the range to `myAttrStr.startIndex ..< myAttrStr.startIndex`. Callers can use this to find the location in the string where removed text used to exist relative to the still-existing surrounding text. Tracking these types of mutations is important for use cases like a user's selection which may be a single cursor position that does not select any ranges of text (which is distinct from a range selecting a single character).

### `AttributedString.Index` Validity

Additionally, we will introduce the following new API and guarantees to assist developers with dynamically checking index validity after possible mutations:

```swift
@available(FoundationPreview 6.2, *)
extension AttributedString.Index {
    public func isValid(within text: some AttributedStringProtocol) -> Bool
    public func isValid(within text: DiscontiguousAttributedSubstring) -> Bool
}

@available(FoundationPreview 6.2, *)
extension Range<AttributedString.Index> {
    public func isValid(within text: some AttributedStringProtocol) -> Bool
    public func isValid(within text: DiscontiguousAttributedSubstring) -> Bool
}

@available(FoundationPreview 6.2, *)
extension RangeSet<AttributedString.Index> {
    public func isValid(within text: some AttributedStringProtocol) -> Bool
    public func isValid(within text: DiscontiguousAttributedSubstring) -> Bool
}
```

_Note: The `DiscontiguousAttributedSubstring` APIs are conditional on the approval of the proposal that introduces `DiscontiguousAttributedSubstring`._

**New API Guarantees**

1. If a particular `AttributedString.Index` lies within the bounds of an `AttributedString` (i.e. `startIndex <= someIndex < endIndex`), then that index will not crash when used to slice an `AttributedString`
    - When the index contains a rope path that does not match the provided `AttributedString`, index usage will fall back to using the (less performant) raw UTF-8 offset
    - Note: This index may not be _the_ semantically equivalent location that was desired (if a mutation has occurred), but it is still _a_ subscript-able location
2. If a particular `AttributedString.Index` returns `true` for `isValid(within:)` given a particular `AttributedString`, then that index will not only meet the guarantee above but is also guaranteed to have been produced by an equivalent `AttributedString` without any intermediate mutations (i.e. the index still represents the semantically equivalent location as when it was created)

## Source compatibility

All of these additions are additive and have no impact on source compatibility.

The change in behavior related to the new API Guarantees mentioned above (concerning `AttributedString.Index` acceptance) could change the behavior of an app in certain situations. Previously, apps passing invalid indices were not guaranteed to perform correctly and may crash, whereas now apps running against a newer version of Foundation will be guaranteed to not crash in some of these situations. While there could be edge cases where this is a change in behavior, we don't believe this to be problematic as this new guarantee has actually been the behavior of `AttributedString` in most circumstances for the past few years. `AttributedString.Index` already stores the UTF-8 offset in addition to the path through the rope structure and will fallback to the UTF-8 offset when the rope path is invalid. Therefore in most circumstances we expect this will not be a behavior change but rather just an additional documented guarantee of pre-existing behavior, and I don't believe that any complex use of these indices that would hit an edge case where the application previously crashed would be problematic if the app now continues execution falling back to the known UTF-8 offset when it is in-bounds.

## Implications on adoption

These new APIs will be annotated with `FoundationPreview 6.2` availability.

## Future directions

### Composite `AttributedString` + tracked indices type

One interesting future direction would be a composite type that utilized the `transform(updating:_:)` API to keep a stored `AttributedString` and set of indices in-sync consistently. Such a type might look like:

```swift
struct TrackedAttributedString {
    var text: AttributedString { get }
    var selectedIndices: RangeSet<AttributedString.Index> { get set }
    
    func transformText<E, R>(_ body: (inout AttributedString) throws(E) -> R) throws(E) -> R
}
```

where `mutatingText(_:)` would be a wrapper around `text.transform(updating:_:)`. Since `text` has no public setter, it forces all mutations to go through `mutatingText(_:)` and therefore preventing the possibility that text is mutated without also updating `selectedIndices`. This is an interesting direction and is worth a future investigation, but I think this might be better investigated for addition at a higher level than Foundation. For example, a text editor could expose a similar type that stores the user's selection alongside an `AttributedString` ensuring the selection is always in-sync with the `AttributedString`. This kind of API would be best added to the user's view model and is likely best defined by the UI framework level rather than at the Foundation model level.

## Alternatives considered

### Permanently storing tracked indices within the `AttributedString` model

Our first approach to keeping indices such as a text editor's selection in-sync with the `AttributedString` was to "simply" store those indices within the `AttributedString` itself. This approach involved adding a new view to `AttributedString` that could be specific to user selections or generalized to "tracking indices". This approach had a variety of benefits; namely, it ensures it's not possible for the indices to be left stale after a mutation since `AttributedString` would always update its stored indices on each mutation. It also avoided a lot of the problems with the alternatives discussed below. However, this approach had a few downsides that we determined were not acceptable:

- These indices would effectively become a part of the model object introducing the concept of a user interface selection at the Foundation level for all `AttributedString`s, even those not bound for a UI
- These indices may have unexpected affects on clients that don't operate at the UI layer, affecting whether two `AttributedString`s were equal via its `Equatable` conformance and bringing up questions about whether they should be included in `AttributedString`'s `Codable` conformance

For these reasons, we decided we needed to investigate alternative approaches where these indices are not permanently stored within the `AttributedString` model. This prompted the investigation into the following other alternatives before settling on the currently proposed approach.

### Storing tracked indices as an attribute within the `AttributedString`

One of the common ways to "mark" a range of text within an `AttributedString` is to apply an attribute. I previously investigated whether index tracking could be accomplished via setting/reading an attribute on the attributed string (which would also be automatically updated during mutations). This was deemed more acceptable as it was expected that attribute values would impact the `Equatable` conformance and the attribute could be defined at a higher level UI framework. However, this approach was limited by two main factors:

- It's possible to have multiple overlapping ranges that need to be tracked at the same time (for example, multiple editors each with their own selection based on the same `AttributedString`). This would require either N different attribute keys to support overlapping ranges or for `AttributedString` to have special knowledge about how to manage overlapping ranges of a value of this specific attribute
- In these tracking scenarios, it's important to be able to track an index after it has been "collapsed" (i.e. after its text has been removed). `AttributedString` cannot fundamentally store an attribute run with a length of zero (indicating a location without any text present) due to a variety of constraints in the API surface, which makes this concept infeasible

For those reasons, we determined that this concept was not able to be fully represented by attributes on the text.

### Allowing callers to register "hooks"/delegates/callbacks with an `AttributedString` to listen for mutations

Another approach I investigated involved allowing `AttributedString` to update/synchronize these indices stored elsewhere from afar. This approach took a few different forms including a delegate pattern, closure-based hooks/callbacks, global thread-safe storage, or the usage of reference types. However in the end, all of these variants of this approach proved infeasible for a few reasons:

- All of these approaches effectively add reference type semantics to `AttributedString`. Any provided delegate/closure/reference to the storage would be a reference type, and therefore it breaks the assumption that `AttributedString` is a value type and each copy is distinct. This can be demonstrated via the code example below in which two copies of the `AttributedString` would effectively reference the same external index storage:

```swift
var str1 = AttributedString("Hello, world")
// ... attach delegate/callback/hooks/references to str1 ...
var str2 = str1
str1.append("Hello")
str2.append("Goodbye") // Calls the same hook as the above mutation, updating the same delegate twice
```

- AttributedString equivalence is unclear: it's questionable whether two `AttributedString`s with different hooks should compare equal and leads to similar `Equatable` concerns as the first alternative considered
- Arbitrary callouts can lead to serious performance issues: this would require `AttributedString` to callout to arbitrary code potentially in third party clients during every mutation. It would be potentially expensive to perform these callouts, the external code could easily become very expensive to perform on every mutation, and `AttributedString` is no longer able to reason about whether its internal state has changed if we call arbitrary code during an active mutation
- The lifetime of these hooks is unclear as it's possible for these hooks to escape the UI layer and still be called even when `AttributedString`s are processed elsewhere in the background.

For those reasons, we deemed this approach intractable as well.

### Creating a composite type representing `AttributedString` with indices

I also investigated an alternative approach that involved created a composite `AttributedString` + tracked indices type that could ensure the two pieces are always kept in-sync. However, to guarantee that these two are always kept in-sync, this would require that the entire mutating API surface of `AttributedString` be duplicated on this composite type so that it could both perform the mutation and update the stored indices. We found duplicating this API surface to be unmaintainable and therefore chose an approach in which the indices are updated as part of the mutation itself rather than having the mutation performed on a composite type.

_Note: we could choose to create a version of a composite type that uses a mutating closure like the currently proposed API. This has a few benefits and is discussed as a future direction above. This alternative considered is a non-closure based approach where the composite type would need to be mutated directly so that the indices are never stored within the `AttributedString`, even temporarily._

### Calculating index updates based on "diffing" two `AttributedString`s

Lastly, we investigated a variety of approaches that involved requiring the caller to update the index values by calculating a difference between the previous and current states of an `AttributedString`. This approach took a variety of forms which have some additional detail below, but in general we found this approach to be unappealing for two main reasons:

- Correctness: with a post-mutation difference calculation, it's not possible for us to determine (in every scenario) how the indices should be updated to reference the correct locations. It's possible that two different mutations (which may move indices in different manners as text is removed and inserted) would produce the same calculated difference between the start and end state resulting in the updated indices being "valid" but not at the correct locations
- Performance: in order to perform this type of calculation, we would need to calculate an extremely detailed difference at unicode scalar level precision. This type of calculation would be quite expensive and needing to perform this every time a stored index needs to be updated (for example, whenever a view reloads and needs to show an updated selection) would not be feasible

#### Calculating index updates based on stored mutation history within an `AttributedString`

To alleviate concerns about the correctness of the calculation, we could instead store a history of the differences between each state in an `AttributedString`. This way, mutations could be re-played with full precision to update indices. However, this approach fell into the problematic scenarios of a few other approaches previously discussed: the lifetime/equatability of these differences is ambiguous and may adversely impact clients not expecting to use this change history and there are performance concerns around the storage of each mutation of an `AttributedString` which would cause the model (or some external storage) to grow steadily over time.

#### Calculating index updates based on stored mutation history within a type that wraps an `AttributedString`

We also investigated the difference tracking approach, but storing the differences in a composite type that stored both an `AttributedString` and its change history. This alleviated the concerns about the lifetime of the change tracking and the `Equatable` impact (since it's very clear where usage of `TrackedAttributedString` ends and `AttributedString` begins). However, this had similar problems as the composite approach mentioned above because it requires duplicating the mutating API surface of `AttributedString` since mutations would need to be performed on the composite type rather than on the `AttributedString` so that the mutation history could be recorded.

### `transform(updating: RangeSet<Index>)` instead of `transform(updating: [Range<Index>])`

Previously, I designed the `transform(updating:_:)` API to use a `RangeSet` instead of an `Array<Range>` as `RangeSet` is the common currency type used to represent a set of indices backed by a collection of ranges. Additionally, `RangeSet` is the currency type used for user selections in text editors which are likely to use this API. However, the usage of `RangeSet` here posed a few issues. In particular, collapsing ranges into single points is not feasible. When a range is removed, it is important to be able to return a location in the mutated string where that range used to exist. However, as a `RangeSet` is semantically a set of indices and not strictly a list of ranges it does not allow for the representation of an empty range or a point between two indices. This required the use of an `enum` with cases for a single `AttributedString.Index` and a `RangeSet`, however we found this a bit inflexible and unable to provide the desired behavior of remembering the unique location of every collapsed subrange.

Additionally, we found the semantics of `Array<Range>` to align closer to the desired behavior of this function over `RangeSet`. For example, if a string contains the text "Hello world" where you are tracking the range of the word "Hello", you might mutate the string by inserting characters in between the two Ls. Since a `RangeSet` semantically represents a set of indices, you might expect the resulting `RangeSet` to represent the same set of indices (i.e. the indices of "H", "e", "l", "l", and "o"). However, when modeling concepts like user selection and locations in the string, we actually want to track the full range from the start to end point. In other words, the return value of this API should return the range "Hel_lo" instead of the discontiguous ranges "Hel" and "lo" (where _ represents inserted characters) and I feel that using an array of `Range` better aligns with this behavior than `RangeSet` which represents a collection of individual indices.

### `transform(updating: AttributedString.Index, _:)` in addition to `Range`-based APIs

Originally I had considered whether we should offer a third overload to `transform(updating:_:)` that accepts an `Index` instead of a `Range`. However, we found this to be potentially ambiguous in regards to whether this was equivalent to tracking the location just before this index (i.e. `idx ..< idx` - an empty range indicating a location just before `idx`) or equivalent to tracking a range that contained this index (i.e. `idx ..< indexAfterIdx`). Furthermore, the latter behavior is still ambiguous as to whether the created range should encapsulate the full grapheme cluster at `idx`, just the first unicode scalar, or a single UTF-8 scalar as `AttributedString` is not a collection itself. To avoid this ambiguity without introducing a very verbose, explicitly-named overload, I chose not to offer this API and instead direct callers to create a range themselves (either empty or containing a single character/unicode scalar as desired).

### Naming of `transform(updating:_:)`

During Foundation evolution review, we had discussed the naming of `transform(updating:_:)` to determine whether it was a suitable name. I had originally proposed this naming for the following reasons:

- "transform": indicates that the receiver (the `AttributedString`) is being mutated, aligns with existing APIs such as `transformingAttributes` to indicate a mutation, and does not use the -ing suffix to indicate that the mutation is done in-place
- "updating": indicates that the provided value is going to be updated to a new value (either returning a new copy or in-place via the combination with `&` indicating the parameter is `inout` depending on the caller)

We considered additional names for this api such as `tracking:` and `reindexing:` instead of `updating:` for added clarity and to avoid confusion with other usages of the word "updating" in Foundation such as the "autoupdating" locale/timezone/etc. However I believe that `updating:` is still the right choice of name for this label because words like "tracking"/"reindexing" are not sufficiently clearer in my opinion and do not have precedent in existing APIs to rely on whereas "updating" has precedent in existing APIs and can be differentiated from other different Foundation APIs due to the lack of the "auto" prefix indicating that the update is performed automatically without additional API calls. I also considered whether the non-`inout` variant should not use the -ing suffix, however I felt that `transform(update:)` presented the word "update" as a noun rather than a verb describing what was happening, and I think the presence or lack thereof of the `&` token indicating whether the value is `inout` along with the compiler warnings for incorrect usage are significant enough to discern between an in-place, `inout` update vs. a returned, updated value.

## Acknowledgments

Special thanks to all those who contributed to the direction of this proposal, especially Max Obermeier and Jacob Refstrup for providing a lot of helpful insight!
