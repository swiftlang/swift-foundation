# Locale.preferredLocales

* Proposal: [SF-0026](0026-preferredLocales.md)
* Authors: [करन मिश्र · Karan Miśra](https://github.com/karan-misra)
* Review Manager: TBD
* Status: **Accepted**
* Implementation: https://github.com/swiftlang/swift-foundation/pull/1315
* Review: ([pitch](https://forums.swift.org/t/pitch-introduce-locale-preferredlocales/79900))

## Introduction

Add `Locale.preferredLocales` as an alternative to `Locale.preferredLanguages` that returns `[Locale]` instead of `[String]`.

## Motivation

Currently, `Locale.preferredLanguages` is the only way to retrieve the list of languages that the user has specified in Language & Region settings. This follows its predecessor `+[NSLocale preferredLanguages]` and returns an array of `String`s instead of `Locale`s. Processing and manipulating strings is complex and errorprone for clients.

This proposal introduces `Locale.preferredLocales` as a way to retrieve the same information, but in the form of an array of `Locale`s which will allow clients to use the information more easily and with fewer errors, specifically when used to customize the presentation of data within their apps such that content in the user’s preferred languages is more prominent.

## Proposed solution

We propose adding `preferredLocales` as a static variable on `Locale`, similarly to `preferredLanguages`. One of the primary use cases is to allow apps to build language selection menus in which the user’s preferred locales are bubbled up to the top. This can be achieved with the proposed `preferredLocales` API as follows: 

```swift
// When building a language selection menu, `matchedLocales` would be shown at the top, and `otherLocales` would be shown below, with a visual divider.
var matchedLocales = []
var otherLocales = []
let availableLocales = // ... array of Locale objects ...
for locale in availableLocales {
    var foundMatch = false
    for preferredLocale in preferredLocales {
        if locale.language.isEquivalent(to: preferredLocale.language) {
            matchedLocales.append(locale)
            foundMatch = true
            break
        }
    }
    if !foundMatch {
        otherLocales.append(locale)
    }
}
``` 

## Detailed design

```swift
public struct Locale : Hashable, Equatable, Sendable {

    /// Returns a list of the user’s preferred locales, as specified in Language & Region settings, taking into account any per-app language overrides.
    @available(FoundationPreview 6.2, *)
    public static var preferredLocales: [Locale]
}
```

## Source compatibility

There is no impact on source compatibility or existing code.

## Implications on adoption

This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility.

## Future directions

In order to further support the use case of building language selection UIs, we can consider adding convenience functions on `Locale` that allow sorting and splitting a list of available `Locale`s into `preferred` and `remaining`, which can then be used to directly populate the UI.   

```swift
public static func sorted(_ available: [Locale]) -> (preferred: [Locale], remaining: [Locale]) 
 ```

We can also consider adding APIs that work with `Locale.Language` in addition to `Locale` since in many use cases, the developer is handling a list of languages does not need the additional functionality in `Locale`.

Lastly, we can choose to deprecate `Locale.preferredLanguages` since it returns the same information but using `String` which is not a good container for a language identifier and leads to incorrect usage.

## Alternatives considered

* Naming-wise, another possibility was `Locale.preferred`. However, following the current naming convention, this would be confused as returning `Locale` and not `[Locale]`. Additionally, it would be best to keep `Locale.preferred` open in case we need a way to get the first, most preferred `Locale` in the future.
* Deprecate `preferredLanguages` and encourage developers to only use `preferredLocales`.
