# `AttributedString` Scope Enumeration

* Proposal: [SF-NNNN](NNNN-attributedstring-scope-enumeration.md)
* Authors: [Jeremy Schonfeld](https://github.com/jmschonfeld)
* Review Manager: TBD
* Status: **Pitch**

## Introduction/Motivation

`AttributeScope`s are a concept used by `AttributedString` to create a list of statically-defined attributes (or `AttributedStringKey`s). These are most commonly used in serialization/conversion APIs to specify which attributes should be included in the operation. This can be a security measure (such as in deserialization when it is used to limit the types of objects deserialized from an archive) or it can be used for extensibility (to allow clients to specify third party defined attributes to Foundation to use). One place where we commonly see the use of `AttributeScope`s is for "glue" code between Swift and Objective-C that converts between `NSAttributedString` APIs and `AttributedString` APIs. Foundation already provides some helper functions in this area to convert between `NSAttributedString` and `AttributedString` as well as between `Dictionary<NSAttributedString.Key, Any>` and `AttributeContainer`. However, there are some `NSAttributedString` APIs throughout the SDK that don't use a collection of concrete attribute values, but rather a set of attribute keys very similar to an `AttributeScope`. These are most commonly represented by `Set<NSAttributedString.Key>` in API surfaces. An example of this API might be an API to limit the set of attributes that can be applied in a text field. However, Foundation currently offers no way for clients providing `AttributedString`/`AttributeScope` APIs to interface with existing, Objective-C based `Set<NSAttributedString.Key>` APIs.

## Proposed solution

We will provide a new API on `AttributeScope` that will allow clients to enumerate the attribute keys contained within a scope. This will allow clients to create a `Set<NSAttributedString.Key>` from an `AttributeScope` like the following:

```swift
public func someAPI<S: AttributeScope>(_ scope: S.Type) {
    let nsKeys = scope.attributeKeys.map {
        NSAttributeString.Key($0.name)
    }
    
    // ... use nsKeys
}
```

Clients can also use the APIs on `AttributedStringKey` to filter the keys as necessary. For example, another API might want to create a `Set<NSAttributedString.Key>` of just keys that have the `inhertedByAddedText` property set to `true`:

```swift
public func someAPI<S: AttributeScope>(_ scope: S.Type) {
    let nsKeys = scope.attributeKeys.filter {
        $0.inheritedByAddedText
    }.map {
        NSAttributeString.Key($0.name)
    }
    
    // ... use nsKeys
}
```

## Detailed design

We propose adding the following API:

```swift
@available(FoundationPreview 6.2, *)
extension AttributeScope {
    public static var attributeKeys: some Sequence<any AttributedStringKey.Type> { get }
}
```

### Performance Considerations

In the past, scope lookup and iteration has been a known point of suboptimal performance so it's important to consider the performance implications of this API when evaluating its shape. Known or potential poor performance around scope iteration typically stems from 3 main areas:

1. The dynamic lookup of "default scopes" in the SDK when no scope is specified
    - This does not apply to this API as a concrete scope is required and it does not cause Foundation to dynamically determine which scopes are currently loaded in the process
2. The use of existentials such as `any AttributedStringKey.Type`
    - Usually, using existentials can become quite expensive due to the potential allocations/indirections. In this case, however, we are using an existential of a metatype which is not inherently any more expensive than using an unspecialized generic argument without an existential and therefore does not have the same level of performance concerns
3. Dynamically forming and iterating keypaths to properties of an `AttributeScope` struct
    - In this API we use an opaque `some Sequence` as a return value which allows us to not only directly/efficiently iterate the cache contents of a traversed scope to ensure quick access to the attribute keys but also ensure that Foundation has the flexibility to change the traversal/cacheing implementation at a future time without breaking API/ABI

For these reasons, I don't see this API as a large source of performance concerns. We still expect that developers performing "simple" conversion or serialization via `AttributeScope`s will use the existing `Codable`/conversion APIs which inherently traverse the scope in their implementations. However, this API will provide an extension point for developers to implement similar APIs while preserving future flexibility and the best performance that we currently offer.

## Source compatibility

These changes are additive only and have no impact on source compatibility

## Implications on adoption

This new API will have `FoundationPreview 6.2` availability. Clients that backdeploy to prior OS versions where availability is relevant will need to surround uses of this API with `#available` checks.

## Future directions

None are considered at this time.

## Alternatives considered

### Requiring clients to use existing `Dictionary`/`NSAttributedString` conversion APIs

Originally I had considered whether we should find a way to have clients use existing conversion APIs to prevent iterating an attribute scope on the client side. However, we determined that there are a few behaviors that we'd like clients to be able to implement (such as the example in the motivation about limiting `NSAttributedString.Key`s in an Objective-C based text field via new `AttributeScope` APIs) that cannot be achieved by converting a `Dictionary` or `NSAttributedString` itself but rather must convert the key values. It became clear that interoperability with `Set<NSAttributedString.Key>` was a clear, missing component that can't be achieved with the existing conversion APIs

### Providing direct conversion to `Set<NSAttributedString.Key>` instead

We could instead choose to expose direct conversion to `Set<NSAttributedString.Key>` instead. This would have the benefit of keeping the "scope traversing" code within Foundation (to allow for future performance improvements and prevent accidentally expensive code in clients). However, it also means that clients would only be able to convert an entire scope without filtering. There are some use cases where clients may want to filter keys based on their behaviors/properties, such as determining a set of `NSAttributedString.Key`s for "typing attributes" (or attributes that extend when typing at a cursor). For this reason, I decided on an API that exposes the full `AttributedStringKey` API to the client while keeping it vended via an opaque `some Sequence` so that the representation of this sequence may change in future releases if Foundation changes how we traverse a scope.

