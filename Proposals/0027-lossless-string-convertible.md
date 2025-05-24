# Conform `UUID` to `LosslessStringConvertible`

* Proposal: [SF-0027](0027-lossless-string-convertible.md)
* Authors: [Jevon Mao](https://github.com/jevonmao)
* Review Manager: TBD
* Status: **Awaiting Review**
* Implementation: [swiftlang/swift-foundation#1303](https://github.com/swiftlang/swift-foundation/pull/1303)
* Review: ([pitch](https://forums.swift.org/t/pitch-conform-uuid-to-losslessstringconvertible/80084/1))

## Introduction

This proposal adds conformance of `UUID` to the `LosslessStringConvertible` protocol. This enables UUIDs to be created from and converted to their canonical string representations in a lossless and bidirectional way using standard Swift protocols.

## Motivation

Swift's `UUID` type is a commonly used identifier type that already supports converting to and from strings via `uuidString` and `init?(uuidString:)`. However, it does not currently conform to the standard library's `LosslessStringConvertible` protocol, which is surprising given that the conversion is already fully supported and round-trippable.

This omission prevents developers from writing generic code that relies on this protocol. For example, web frameworks like Vapor have implemented their own conformance in order to enable route decoding via string interpolation.

Adding this conformance would standardize this behavior in the Swift Foundation library, remove the need for third-party workarounds, and improve UUID's interoperability in generic APIs.

## Proposed solution

Extend `UUID` to conform to `LosslessStringConvertible` by implementing:

```swift
extension UUID: LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }

    public var description: String {
        return self.uuidString
    }
}
```

This conformance ensures that a valid UUID string can initialize a `UUID`, and that the `description` property returns a string that can reconstitute the same value, satisfying the requirements of `LosslessStringConvertible`.

## Detailed design

A new test was added to validate round-trip conformance and nil-initialization on invalid input:

```swift
func test_UUIDLosslessStringConvertible() {
    let originalString = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    let uuidFromString = UUID(originalString)
    XCTAssertNotNil(uuidFromString)
    XCTAssertEqual(uuidFromString?.description, originalString)

    let uuid = UUID(uuidString: originalString)!
    XCTAssertEqual(uuid, UUID(uuid.description))

    let invalidUUID = UUID("not-a-uuid")
    XCTAssertNil(invalidUUID)
}
```

## Source compatibility

This proposal is purely additive and does not break source compatibility.


## Implications on adoption

Adopting this change is safe and beneficial without ABI stability concerns.

## Future directions

- Consider reviewing similar Foundation types for conformance to `LosslessStringConvertible` where it makes sense.

## Alternatives considered

- **Do nothing:** Keep current API, but will cause inconsistencies across Swift APIs and third-party workarounds.

## Acknowledgments

Thanks to [Stephen Celis](https://forums.swift.org/u/stephencelis) for initiating this discussion on the Swift Forums and [Sindre Sorhus](https://github.com/sindresorhus) for opening an issue on this adoption.



