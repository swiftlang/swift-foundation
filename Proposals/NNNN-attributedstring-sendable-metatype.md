# `AttributedString` & `SendableMetatype`

* Proposal: [SF-NNNN](NNNN-attributedstring-sendable-metatype.md)
* Authors: [Jeremy Schonfeld](https://github.com/jmschonfeld)
* Review Manager: TBD
* Status: **Pitch**



## Introduction/Motivation

[SE-0470 Global-actor isolated conformances](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md) introduced the concept of a conformance isolated to a global actor. This in turn introduced the ability for metatypes to be non-`Sendable` as a generic metatype's conformance to a protocol may be isolated to a global actor. Since metatypes are not guaranteed to be `Sendable`, generic functions that pass metatypes across isolation boundaries now need to specify that they require `Sendable` metatypes (i.e. the conformance to the specified protocol must be nonisolated). One common API in Foundation that needs to pass metatypes across actor isolations is `AttributedString` via its `AttributedStringKey` and `AttributeScope` protocols. `AttributedString` contains a variety of APIs that accept generic metatypes constrained to these protocols. In many cases, these metatypes need to be passed across actor isolations (such as storing the contents of a scope in a cache, storing attribute keys in `Sendable` `AttributedString`s and related types, etc.). We need to update Foundation's APIs to ensure that these assumptions around `Sendable` `AttributedStringKey` and `AttributeScope` metatypes still hold.

## Proposed solution and example

Since Foundation needs to pass these metatypes across isolation boundaries and there is no benefit to providing an isolated conformance to `AttributeScope`/`AttributedStringKey` as the types themselves should never access global state and are never initialized, I propose annotating `AttributedStringKey` and `AttributeScope` as conforming to `SendableMetatype` to prevent isolated conformances to these protocols. Developers that do not bind their keys/scopes to global actors will see no impact, but developers that declare isolated conformances to either of these protocols will now see a compilation warning/error:

```swift
struct MyAttributeKey : @MainActor AttributedStringKey {
    typealias Value = Int
    static let name = "MyFramework.MyAttributeKey"
}

var myString = AttributedString()
myString[MyAttributeKey.self] = 2 // Main actor-isolated conformance of 'MyAttributeKey' to 'AttributedStringKey' cannot satisfy conformance requirement for a 'Sendable' type parameter 
```

## Detailed design

The `SendableMetatype` conformance will be added to the pre-existing `AttributedStringKey` and `AttributeScope` protocols:

```swift
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol AttributedStringKey : SendableMetatype {
    // ...
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol AttributeScope : DecodingConfigurationProviding, EncodingConfigurationProviding, SendableMetatype {
    // ...
}
```

## Source compatibility

Isolated conformances are new to Swift 6.2 and therefore all existing code (which must use nonisolated conformances) will not be impacted. Any code that has already adopted an isolated conformance here in Swift 6.2 will now see a warning (or error in Swift 6 mode) when providing these key/scope types to `AttributedString` APIs.

Since `SendableMetatype` is a marker protocol, this change does not impact ABI and does not require availability adjustments.

## Implications on adoption

Modules that define conformances to `AttributedStringKey` or `AttributeScope` will not be able to define them as isolated conformances. The conformances must be nonisolated.

## Future directions

None.

## Alternatives considered

### Adding a `SendableMetatype` annotation to all applicable `AttributedString` APIs

Instead, we could add the conformance to every `AttributedString` API that accepts a key or scope in case these keys/scope types are used in other APIs that do not require a nonisolated conformance. I chose to not pursue this route as it required more complex changes, it has mostly the same effect, and I don't expect any client to realistically require an isolated conformance to these protocols.
