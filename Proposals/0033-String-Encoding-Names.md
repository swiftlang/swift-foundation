# String Encoding Names

* Proposal: FOU-0033
* Author(s): [YOCKOW](https://GitHub.com/YOCKOW)
* Review Manager: TBD
* Status: **Review: 2025-09-04...2025-09-11**
<!-- * Bug: *if applicable* [apple/swift#NNNN](https://github.com/apple/swift-foundation/issues/NNNNN) -->
* Implementation: [swiftlang/swift-foundation#1286](https://github.com/swiftlang/swift-foundation/pull/1286)
<!-- * Previous Proposal: *if applicable* [FOU-XXXX](XXXX-filename.md) -->
<!-- * Previous Revision: *if applicable* [1](https://github.com/apple/swift-evolution/blob/...commit-ID.../proposals/NNNN-filename.md) -->
* Review: ([Pitch](https://forums.swift.org/t/pitch-foundation-string-encoding-names/74623))


## Revision History

### [Pitch#1](https://gist.github.com/YOCKOW/f5a385e3c9e2d0c97f3340a889f57a16/d76651bf4375164f6a46df792fccd74955a4733a)

- Features
  * Fully compatible with CoreFoundation.
    + Planned to add static properties corresponding to `kCFStringEncoding*`.
  * Spelling of getter/initializer was `ianaCharacterSetName`.
- Pros
  * Easy to migrate from CoreFoundation.
- Cons
  * Propagating undesirable legacy conversions into current Swift Foundation.
  * Including string encodings which might not be supported by Swift Foundation.


### [Pitch#2](https://gist.github.com/YOCKOW/f5a385e3c9e2d0c97f3340a889f57a16/215404d620b41119a8a03ec1a51e725eb09be4b6)

- Features
  * Consulting both [IANA Character Sets](https://www.iana.org/assignments/character-sets/character-sets.xhtml) and [WHATWG Encoding Standard](https://encoding.spec.whatwg.org/).
    + Making a compromise between them.
  * Spelling of getter/initializer was `name`.
- Pros
  * Easy to communicate with API.
- Cons
  * Hard for users to comprehend conversions.
  * Difficult to maintain the API in a consistant way.

### [Pitch#3](https://github.com/YOCKOW/SF-StringEncodingNameImpl/blob/0.1.0/proposal/NNNN-String-Encoding-Names.md), [Pitch#4](https://github.com/YOCKOW/SF-StringEncodingNameImpl/blob/0.2.1/proposal/NNNN-String-Encoding-Names.md)

- Features
  * Consulting both [IANA Character Sets](https://www.iana.org/assignments/character-sets/character-sets.xhtml) and [WHATWG Encoding Standard](https://encoding.spec.whatwg.org/).
  * Following ["Charset Alias Matching"](https://www.unicode.org/reports/tr22/tr22-8.html#Charset_Alias_Matching) rule defined in UTS#22  to parse IANA Charset Names.
  * Separated getters/initializers for them.
    + #3: `charsetName` and `standardName` respectively.
    + #4: `name(.iana)` and `name(.whatwg)` for getters; `init(iana:)` and `init(whatwg:)` for initializers.
- Pros
  * Users can recognize what kind of conversions is used.
- Cons
  * Not reflecting the fact that WHATWG's Encoding Standard doesn't provide only string encoding names but also implementations to encode/decode data.

### [Pitch#5](https://github.com/YOCKOW/SF-StringEncodingNameImpl/blob/0.3.1/proposal/NNNN-String-Encoding-Names.md)

- Features
  * Withdrew support for [WHATWG Encoding Standard](https://encoding.spec.whatwg.org/).
  * Following ["Charset Alias Matching"](https://www.unicode.org/reports/tr22/tr22-8.html#Charset_Alias_Matching) rule defined in UTS#22  to parse IANA Charset Names.
  * Spelling of getter/initializer was `name`.
  * "Fixed" some behaviour of parsing, which differs from CoreFoundation.
- Pros
  * Simple API to use.
- Cons
  * It was unclear that IANA names were used.
  * The parsing behavior was complex and unpredictable.


### [Pitch#6](https://github.com/YOCKOW/SF-StringEncodingNameImpl/blob/0.4.0/proposal/NNNN-String-Encoding-Names.md), Proposal#1

This version.


## Introduction

This proposal allows `String.Encoding` to be converted to and from various names.

For example:

```swift
print(String.Encoding.utf8.ianaName!) // Prints "UTF-8"
print(String.Encoding(ianaName: "ISO_646.irv:1991") == .ascii) // Prints "true"
```


## Motivation

String encoding names are widely used in computer networking and other areas. For instance, you often see them in HTTP headers such as `Content-Type: text/plain; charset=UTF-8` or in XML documents with declarations such as `<?xml version="1.0" encoding="Shift_JIS"?>`.

Therefore, it is necessary to parse and generate such names.


### Current solution

Swift lacks the necessary APIs, requiring the use of `CoreFoundation` (hereinafter called "CF") as described below.

```swift
extension String.Encoding {
  var nameInLegacyWay: String? {
    // 1. Convert `String.Encoding` value to the `CFStringEncoding` value.
    //    NOTE: The raw value of `String.Encoding` is the same as the value of `NSStringEncoding`,
    //          while it is not equal to the value of `CFStringEncoding`.
    let cfStrEncValue: CFStringEncoding = CFStringConvertNSStringEncodingToEncoding(self.rawValue)

    // 2. Convert it to the name where its type is `CFString?`
    let cfStrEncName: CFString? = CFStringConvertEncodingToIANACharSetName(cfStrEncValue)

    // 3. Convert `CFString` to Swift's `String`.
    //    NOTE: Unfortunately they can not be implicitly casted on Linux.
    let charsetName: String? = cfStrEncName.flatMap {
      let bufferSize = CFStringGetMaximumSizeForEncoding(
        CFStringGetLength($0),
        kCFStringEncodingASCII
      ) + 1
      let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
      defer {
        buffer.deallocate()
      }
      guard CFStringGetCString($0, buffer, bufferSize, kCFStringEncodingASCII) else {
        return nil
      }
      return String(utf8String: buffer)
    }
    return charsetName
  }

  init?(fromNameInLegacyWay charsetName: String) {
    // 1. Convert `String` to `CFString`
    let cfStrEncName: CFString = charsetName.withCString { (cString: UnsafePointer<CChar>) -> CFString in
      return CFStringCreateWithCString(nil, cString, kCFStringEncodingASCII)
    }

    // 2. Convert it to `CFStringEncoding`
    let cfStrEncValue: CFStringEncoding = CFStringConvertIANACharSetNameToEncoding(cfStrEncName)

    // 3. Check whether or not it's valid
    guard cfStrEncValue != kCFStringEncodingInvalidId else {
      return nil
    }

    // 4. Convert `CFStringEncoding` value to `String.Encoding` value
    self.init(rawValue: CFStringConvertEncodingToNSStringEncoding(cfStrEncValue))
  }
}
```


### What's the problem of the current solution?

- It is complicated to use multiple CF functions to get a simple value. That's not *Swifty*.
- CF functions are legacy APIs that do not always meet modern requirements.
- CF APIs are not officially intended to be called directly from Swift on non-Darwin platforms.


## Proposed solution

The solution is straightforward.
We introduce a computed property that returns the name, and the initializer that creates an instance from a name as shown below.

```swift
extension String.Encoding {
  /// The name of this encoding that is compatible with the one of the IANA registry "charset".
  @available(FoundationPreview 6.2, *)
  public var ianaName: String?

  /// Creates an instance from the name of the IANA registry "charset".
  @available(FoundationPreview 6.2, *)
  public init?(ianaName: String)
}
```

## Detailed design

This proposal refers to "[Character Sets](https://www.iana.org/assignments/character-sets/character-sets.xhtml)" published by IANA.

One of the reasons for this is that The World Wide Web Consortium (W3C) recommends using IANA "charset" names in XML[^XML-IANA-charset-names] and they assert that any IANA "charset" names are available in HTTP header[^HTTP-IANA-charset-names].

[^XML-IANA-charset-names]: https://www.w3.org/TR/xml11/#charencoding
[^HTTP-IANA-charset-names]: https://www.w3.org/International/articles/http-charset/index#charset

Another reason is that CF claims that IANA "charset" names are used, as implied by its function names[^CF-IANA-function-names].

[^CF-IANA-function-names]: [`CFStringConvertIANACharSetNameToEncoding`](https://developer.apple.com/documentation/corefoundation/cfstringconvertianacharsetnametoencoding(_:)) and [`CFStringConvertEncodingToIANACharSetName`](https://developer.apple.com/documentation/corefoundation/cfstringconvertencodingtoianacharsetname(_:))

However, as mentioned above, CF APIs are sometimes outdated.
Furthermore, CF parses "charset" names inconsistently[^CF-inconsistent-parse].
Therefore, we shouldn't adopt CF-like behavior without modifications. Nevertheless, adjusting it to some extent can be unpredictable and complex.

[^CF-inconsistent-parse]: https://forums.swift.org/t/pitch-foundation-string-encoding-names/74623/53

Accordingly, this proposal suggests just simple correspondence between `String.Encoding` instances and IANA names:


| `String.Encoding`    | IANA "charset" Name |
|----------------------|---------------------|
| `.ascii`             | US-ASCII            |
| `.iso2022JP`         | ISO-2022-JP         |
| `.isoLatin1`         | ISO-8859-1          |
| `.isoLatin2`         | ISO-8859-2          |
| `.japaneseEUC`       | EUC-JP              |
| `.macOSRoman`        | macintosh           |
| `.nextstep`          | *n/a*               |
| `.nonLossyASCII`     | *n/a*               |
| `.shiftJIS`          | Shift_JIS           |
| `.symbol`            | *n/a*               |
| `.unicode`/`.utf16`  | UTF-16              |
| `.utf16BigEndian`    | UTF-16BE            |
| `.utf16LittleEndian` | UTF-16LE            |
| `.utf32`             | UTF-32              |
| `.utf32BigEndian`    | UTF-32BE            |
| `.utf32LittleEndian` | UTF-32LE            |
| `.utf8`              | UTF-8               |
| `.windowsCP1250`     | windows-1250        |
| `.windowsCP1251`     | windows-1251        |
| `.windowsCP1252`     | windows-1252        |
| `.windowsCP1253`     | windows-1253        |
| `.windowsCP1254`     | windows-1254        |


### `String.Encoding` to Name

- Upper-case letters may be used unlike CF.
  * `var ianaName` returns *Preferred MIME Name* or *Name* of the encoding defined in "IANA Character Sets".


### Name to `String.Encoding`

- `init(ianaName:)` adopts ASCII case-insensitive comparison with *Preferred MIME Name*, *Name*, and *Aliases*.


## Source compatibility

These changes proposed here are only additive. However, care must be taken if migrating from CF APIs.


## Implications on adoption

This feature can be freely adopted and un-adopted in source code without affecting source compatibility.


## Future directions

This feature will make more programs easy to parse string encoding names so that (e.g.) Web apps written in Swift won't need to implement such parser on their own.

We already have the string converter in `FoundationInternationalization` that wraps ICU APIs, but that requires IANA Charset Names to create an instance of naive ICU converter[^icu-string-converter].
Once this feature is adopted, it will become easier to implement other string encoding conversions that are unavailable yet.

[^icu-string-converter]: https://github.com/swiftlang/swift-foundation/blob/a8bee5bfc71210168fa1b973fb1a1deb8bde2047/Sources/FoundationInternationalization/ICU/ICU%2BStringConverter.swift#L18-L37


### Longer-term perspective

Hopefully, happening some cascades like below might be expected in the longer term.

- General string decoders/encoders and their protocols (for example, as suggested in "[Unicode Processing APIs](https://forums.swift.org/t/pitch-unicode-processing-apis/69294)") could be implemented.

- Some types which provide their names and decoders/encoders could be implemented for the purpose of tightness between names and implementations.
  * There would be a type for WHATWG Encoding Standard which defines both names and implementations.

<details><summary>They would look like...</summary><div>

```swift
public protocol StrawmanStringEncodingProtocol {
  static func encoding(for name: String) -> Self?
  var name: String? { get }
  var encoder: (any StringToByteStreamEncoder)? { get }
  var decoder: (any ByteStreamToUnicodeScalarsDecoder)? { get }
}

public struct IANACharset: StrawmanStringEncodingProtocol {
  public static let utf8: IANACharset = ...
  public static let shiftJIS: IANACharset = ...
  :
  :
}

public struct WHATWGEncoding: StrawmanStringEncodingProtocol {
  public static let utf8: WHATWGEncoding = ...
  public static let eucJP: WHATWGEncoding = ...
  :
  :
}
```

</div></details>


## Alternatives considered

### Following "Charset Alias Matching"

[UTS#22](https://www.unicode.org/reports/tr22/tr22-8.html) defines "Charset Alias Matching" rule.
ICU adopts that rule and CF partially depends on ICU.
On the other hand, there doesn't seem to be any specifications that require "Charset Alias Matching".
Moreover, some risks may be inherent in such a tolerant rule.

One possible solution may be letting users choose which rule should be used:
```swift
extension String.Encoding {
  public enum NameParsingStrategy {
    case uts22
    case caseInsensitiveComparison
  }

  public init?(ianaName: String, strategy: NameParsingStrategy = .caseInsensitiveComparison) {
    ...
  }
}
```


### Adopting the WHATWG Encoding Standard (as well)

There is another standard for string encodings which is published by WHATWG: "[Encoding Standard](https://encoding.spec.whatwg.org/)".
While it may claim the IANA's Character Sets could be replaced with it, it entirely focuses on Web browsers and their JavaScript APIs.
Furthermore it binds tightly names with implementations.
Since `String.Encoding` is just a `RawRepresentable` type where its `RawValue` is `UInt`, it is more universal but is more loosely bound to implementations.
As a result, WHATWG Encoding Standard doesn't easily align with `String.Encoding`. So it is just mentioned in "Future Directions".


## Acknowledgments

Thanks to everyone who gave me advices on the pitch thread; especially to [@benrimmington](https://github.com/benrimmington) and [@xwu](https://github.com/xwu) who could channel their concerns into this proposal in the very early stage.
