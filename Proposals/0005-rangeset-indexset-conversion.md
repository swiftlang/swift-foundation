# `RangeSet`/`IndexSet` Conversion

* Proposal: SF-0005
* Author(s): [Jeremy Schonfeld](https://github.com/jmschonfeld)
* Review Manager: [Charles Hu](https://github.com/iCharlesHu)
* Status: **Accepted**
* Implementation: _coming soon_

## Introduction/Motivation

With the latest revision of [SE-0270](https://forums.swift.org/t/se-0270-fourth-review-add-collection-operations-on-noncontiguous-elements/68855), we've landed the `RangeSet` type in the standard library. Foundation already has an existing type called `IndexSet` used in various (mainly Objective-C-based) APIs to represent a collection of integer indices. These types are fairly similar in purpose, however `IndexSet` is constrained to non-negative, integer indices (as required by Objective-C collections) whereas `RangeSet` is generic over any `Comparable` index type. There are some cases when developers may wish to convert a set of indices between the `IndexSet` and `RangeSet` representations. For example, library authors writing new swift APIs that wrap or interact with existing Objective-C APIs may wish to expose `RangeSet`-based entry points while occasionally calling to `IndexSet`-based Objective-C APIs as an implementation detail. Additionally, developers may wish to write apps using the new `RangeSet` type while still interfacing with existing SDK APIs that use `IndexSet` from Foundation. Foundation has the opportunity to provide these conversion initializers as a convenience to ensure both correctness and performance while moving between the two types.

## Proposed solution and example

We will add new initializers in Foundation on the `IndexSet` and `RangeSet` types that allow conversion between the two when the `RangeSet`'s `Bound == Int`. For examples, developers could write the following code:

```swift
extension UICollectionView {
	func reloadSections(_ sections: RangeSet<Int>) {
		guard let indexSet = IndexSet(integersIn: sections) else {
			fatalError("Invalid section numbers passed to reloadSections(_:). Sections must be non-negative integers")
		}
		self.reloadSections(indexSet) // Call to existing ObjC API
	}
}
```

## Detailed design

```swift
extension IndexSet {
	@available(FoundationPreview 0.4, *)
	public init?(integersIn indices: RangeSet<Int>)
}

extension RangeSet<Int> {
	@available(FoundationPreview 0.4, *)
	public init(_ indices: IndexSet)
}
```

## Source compatibility

These changes are additive only and are not expected to have an impact on source compatibility.

## Implications on adoption

This new API will have FoundationPreview 0.4 availability.

## Alternatives considered

### Alternative behavior for invalid indices

`IndexSet` not only requires integer indices - it requires that all indices are nonnegative. Unfortunately, we cannot represent this constraint statically in the type system, so we can only detect these invalid indices at runtime. With the current design, the initializer will return `nil` when encountering a `RangeSet` that contains negative indices. We previously discussed providing a non-failable initializer that would abort if given a `RangeSet` with negative indices. However, after discussion we determined that this would likely be more harmful than helpful. These conversion initializers will often be used in connecting Swift APIs that accept input from a caller in order to call through to Objective-C APIs. In these cases, the `RangeSet` will often be caller-controlled and there may be cases when invalid input is provided. Rather than introducing a crash in these cases (which may not be found in testing and could lead to unexpected crashes in the conversion-calling code) we decided it was important to use a failable initializer to indicate the possibility of failure to a developer. Developers that know the indices will be valid can use a force-unwrap to assert that the indices are valid, while other developers may choose to vary the behavior (such as doing nothing, logging a message, or otherwise) in the cases of invalid indices. Overall, this ensures that the behavior here is accounted for by the developer and is an intentional choice rather than a potential oversight that could lead to unexpected crashes.

### Initializer parameter labels

I chose to use the `integersIn:` parameter label for the new `IndexSet` initializer while using no label for the `RangeSet` initializer. We could instead drop the parameter label for the `IndexSet` initializer and/or use a label such as `integersIn:`/`contentsOf:` for the `RangeSet` initializer. However, I chose the current proposed labels to mirror the existing API that we have for `IndexSet` and `RangeSet`:

```swift
struct IndexSet {
	init()
	init(integer: Int)
	init(integersIn: Range<Int>)
	...
}

struct RangeSet<Bound> {
	init()
	init(_ range: Range<Bound>)
	init(_ ranges: some Sequence<Range<Bound>>)
	...
}
```