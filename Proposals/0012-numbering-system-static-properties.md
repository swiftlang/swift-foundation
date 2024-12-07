# Feature name

* Proposal: [SF-0012](0012-numbering-system-static-properties.md)
* Authors: [Gleb Fandeev](https://github.com/glebfann)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [apple/swift-foundation#1055](https://github.com/swiftlang/swift-foundation/pull/1055)
* Review: ([pitch](https://forums.swift.org/t/pitch-add-static-properties-for-locale-numberingsystem/76203))

## Introduction

This proposal adds static properties to `Locale.NumberingSystem` for all standard numbering systems defined in [Unicode CLDR](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/number.xml), making it easier to work with different numbering systems in Swift.

## Motivation

Currently, to use a specific numbering system, developers need to create instances using string identifiers:
```swift
let arabic = Locale.NumberingSystem("arab")
```
This approach has several drawbacks:
- Lack of Discoverability: Developers may not be aware of all available numbering systems or their corresponding identifiers.
- Error-Prone: Manually typing string identifiers increases the risk of typos and mistakes.
- Reduced Readability: String literals provide less context compared to well-named constants.
- Inconsistency: Other Locale components like `Locale.LanguageCode`, `Locale.Region`, and `Locale.Script` already provide static properties for common identifiers, but `Locale.NumberingSystem` does not.

By introducing predefined static properties for each numbering system, we can improve code safety, discoverability, readability, and maintain consistency across the Locale API.

## Proposed solution

Extend `Locale.NumberingSystem` to include static properties for each numbering system defined in the Unicode CLDR.

Example usage:
```swift
let numberingSystem = Locale.NumberingSystem.arabicIndic
```
This allows developers to:

- Use autocomplete features to discover available numbering systems.
- Reduce typos and mistakes by avoiding manually typed strings: `let numberingSystem = Locale.NumberingSystem("arabic") // Incorrect identifier`
- Improve code clarity with descriptive property names. For example, `Locale.NumberingSystem.simplifiedChinese` instead of `Locale.NumberingSystem("hans")`

## Detailed design

Add an extension to `Locale.NumberingSystem` containing static properties for each numbering system. The identifiers are sourced from the Unicode CLDR's numbering systems registry.

```swift
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.NumberingSystem {
    /// Adlam digits.
    /// - Identifier: `"adlm"`.
    @_alwaysEmitIntoClient
    public static var adlam: Locale.NumberingSystem { Locale.NumberingSystem("adlm") }

    /// Ahom digits.
    /// - Identifier: `"ahom"`.
    @_alwaysEmitIntoClient
    public static var ahom: Locale.NumberingSystem { Locale.NumberingSystem("ahom") }

    /// Arabic-Indic digits.
    /// - Identifier: `"arab"`.
    @_alwaysEmitIntoClient
    public static var arabicIndic: Locale.NumberingSystem { Locale.NumberingSystem("arab") }

    /// Extended Arabic-Indic digits.
    /// - Identifier: `"arabext"`.
    @_alwaysEmitIntoClient
    public static var arabicIndicExtended: Locale.NumberingSystem { Locale.NumberingSystem("arabext") }

    // ... all other numbering systems
}
```
The full list can be viewed in the [implementation pull request](https://github.com/swiftlang/swift-foundation/pull/1055). Variable names are assigned based on the descriptions provided in the [Unicode CLDR](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/number.xml).

## Source compatibility

These changes are additive only and are not expected to have an impact on source compatibility.

## Implications on adoption

This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility.

## Acknowledgments

Thanks to [Alobaili](https://forums.swift.org/u/alobaili/summary) for highlighting this issue in their [comment](https://forums.swift.org/t/fou-locale-components-language-and-language-components/54084/17) on the Swift forums, which inspired this proposal.
