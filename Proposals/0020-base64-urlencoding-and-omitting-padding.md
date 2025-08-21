# Adding base64 urlencoding and omitting padding option to base64 encoding and decoding

* Proposal: [SF-0020](0020-base64-urlencoding-and-omitting-padding.md)
* Authors: [Fabian Fett](https://github.com/fabianfett)
* Review Manager: TBD
* Status: **Accepted**
* Implementation: [apple/swift-foundation#1195](https://github.com/swiftlang/swift-foundation/pull/1195) [apple/swift-foundation#1196](https://github.com/swiftlang/swift-foundation/pull/1196)
* Review: [pitch](https://forums.swift.org/t/pitch-adding-base64-urlencoding-and-omitting-padding-options-to-base64-encoding-and-decoding/77659)

## Revision history

* **v1** Initial version

## Introduction

Introducing base64 encoding and decoding options to support the base64url alphabet as defined in [RFC4648] and to allow the omission of padding characters.

## Motivation

Foundation offers APIs to encode data in the base64 format and to decode base64 encoded data. Multiple RFCs that define cryptography for the web use the base64url encoding and strip the padding characters in the end. Examples for this are: 

- [RFC7519 - JSON Web Token (JWT)][RFC7519]
- [RFC8291 - Message Encryption for Web Push][RFC8291]

Since Foundation is not offering an API to support the base64url alphabet and omitting the padding characters, users create wrappers around the existing APIs using `replacingOccurrences(of:, with:)`. While this approach works it is very inefficient. The data has to be iterated three times, where one time could have been sufficient.

## Solution

We propose to add additional options to `Data.Base64EncodingOptions`:

```swift
extension Data.Base64EncodingOptions {
    /// Use the base64url alphabet to encode the data
    @available(FoundationPreview 6.3, *)
    public static var base64URLAlphabet: Base64EncodingOptions { get }

    /// Omit the `=` padding characters in the end of the base64 encoded result
    @available(FoundationPreview 6.3, *)
    public static var omitPaddingCharacter: Base64EncodingOptions { get }
}
```

Simultaneously we will add the same options to `Data.Base64DecodingOptions` and an additional `ignoreWhitespaceCharacters` option. Please note that we show the existing `ignoreUnknownCharacters` option in the code snippet below, as we intend to change its documentation to better explains its tradeoffs.

```swift
extension Data.Base64DecodingOptions {
    /// Modify the decoding algorithm so that it ignores unknown non-Base-64 bytes, including line ending characters.
    /// 
    /// - Warning: Using `ignoreUnknownCharacters` might allow the decoding of base64url data, even when the 
    ///            `base64URLAlphabet` is not selected. It might also allow using the base64 alphabet when the
    ///            `base64URLAlphabet` is selected.
    ///            Consider using the `ignoreWhitespaceCharacters` option if possible.
    public static let ignoreUnknownCharacters = Base64DecodingOptions(rawValue: 1 << 0)

    /// Modify the decoding algorithm so that it ignores whitespace characters (CR LF Tab and Space). 
    ///
    /// The decoding will fail if any other invalid character is found in the encoded data. 
    @available(FoundationPreview 6.3, *)
    public static var ignoreWhitespaceCharacters: Base64DecodingOptions { get }

    /// Modify the decoding algorithm so that it expects base64 encoded data that uses base64url alphabet.
    @available(FoundationPreview 6.3, *)
    public static var base64URLAlphabet: Base64EncodingOptions { get }

    /// Modify the decoding algorithm so that it expects no padding characters at the end of the encoded data.
    ///
    /// The decoding will fail if the padding character `=` is used at the end of the encoded data.
    /// 
    /// - Warning: This option is ignored if `ignoreUnknownCharacters` is used at the same time. Consider 
    ///            using `ignoreWhitespaceCharacters` if possible.
    @available(FoundationPreview 6.3, *)
    public static var omitPaddingCharacter: Base64EncodingOptions { get }
}
```

## Impact on existing code

None. This is an additive change.

[RFC4648]: https://datatracker.ietf.org/doc/html/rfc4648
[RFC7519]: https://datatracker.ietf.org/doc/html/rfc7519
[RFC8291]: https://datatracker.ietf.org/doc/html/rfc8291
