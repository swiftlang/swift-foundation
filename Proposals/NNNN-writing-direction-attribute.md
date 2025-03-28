# Writing Direction Attribute

* Proposal: [SF-NNNN](NNNN-writing-direction-attribute.md)
* Authors: [Max Obermeier](https://github.com/themomax)
* Review Manager: TBD
* Status: **Awaiting implementation**
* Review: ([pitch](https://forums.swift.org/t/pitch-writing-direction-attribute/78924))

## Introduction

Adds an `AttributedStringKey` for the base writing direction of a paragraph.

## Motivation

`AttributedString` currently has no way to express the base writing direction of a paragraph as a standalone property. Some UI frameworks, such as UIKit or AppKit define a pargraph style property that includes - among other properties - the base writing direction. This attribute originated in the context of `NSAttributedString` and has a couple of disadvantages:

 1. It is impossible to specify only the base writing direction without also specifying values for the remaining paragraph style properties.
 2. The attribute does not utilize advanced `AttributedStringKey` behaviors such as `runBoundaries` or `inheritedByAddedText`.
 3. Writing direction is a fundamental property of strings that is not only relevant in UI frameworks, but needs to be communicated in any context that deals with (potentially) bidirectional strings.

## Proposed solution

This proposal adds a new `AttributedString.WritingDirection` enum with two cases `leftToRight` and `rightToLeft`, along with a new key `WritingDirectionAttribute`, which is included in `AttributeScopes.FoundationAttributes` under the name `writingDirection`.

```swift
// Indicate that this sentence is primarily right to left, because the English term "Swift" is embedded into an Arabic sentence.
var string = AttributedString("Swift مذهل!", attributes: .init().writingDirection(.rightToLeft))

// To remove the information about the writing direction, set it to `nil`:
string.writingDirection = nil
```

Since the base writing direction is defined at a paragraph level, the attribute specifies `runBoundaries = .paragraph`. Since the writing direction of one paragraph is independent of the next, the attribute is not `inheritedByAddedText`.

```swift
let range = string.range(of: "Swift")!

// When setting or removing the value from a certain range, the value will always be applied to the entire paragraph(s) that intersect with that range:
string[range].writingDirection = .leftToRight
assert(string.runs[\.writingDirection].count == 1)

// When adding text to a paragraph, the existing writingDirection is applied to the new text.
string.append(AttributedString(" It is awesome for working with strings!"))
assert(string.runs[\.writingDirection].count == 1)
assert(string.writingDirection == .leftToRight)

// When adding a new paragraph, the new paragraph does not inherit the writing direction of the preceding paragraph.
string.append(AttributedString("\nThe new paragraph does not inherit the writing direction."))
assert(string.runs[\.writingDirection].count == 2)
assert(string.runs.last?.writingDirection == nil)
```

## Detailed design

```swift
extension AttributedString {
    /// The writing direction of a piece of text.
    ///
    /// Writing direction defines the base direction in which bidirectional text
    /// lays out its directional runs. A directional run is a contigous sequence
    /// of characters that all have the same effective directionality, which can
    /// be determined using the Unicode BiDi algorithm. The ``leftToRight``
    /// writing direction puts the directional run that is placed first in the
    /// storage leftmost, and places subsequent directional runs towards the
    /// right. The ``rightToLeft`` writing direction puts the directional run
    /// that is placed first in the storage rightmost, and places subsequent
    /// directional runs towards the left.
    ///
    /// Note that writing direction is a property separate from a text's
    /// alignment, its line layout direction, or its character direction.
    /// However, it is often used to determine the default alignment of a
    /// paragraph. E.g. English (a language with
    /// ``Locale/LanguageDirection-swift.enum/leftToRight``
    /// ``Locale/Language-swift.struct/characterDirection``) is usually aligned
    /// to the left, but may be centered or aligned to the right for special
    /// effect, or to be visually more appealing in a user interface.
    ///
    /// For bidirectional text to be perceived as laid out correctly, make sure
    /// that the writing direction is set to the value equivalent to the
    /// ``Locale/Language-swift.struct/characterDirection`` of the primary
    /// language in the text. E.g. an English sentence that contains some
    /// Arabic (a language with
    /// ``Locale/LanguageDirection-swift.enum/rightToLeft``
    /// ``Locale/Language-swift.struct/characterDirection``) words, should use
    /// a ``leftToRight`` writing direction. An Arabic sentence that contains
    /// some English words, should use a ``rightToLeft`` writing direction.
    ///
    /// Writing direction is always orthogonoal to the line layout direction
    /// chosen to display a certain text. The line layout direction is the
    /// direction in which a sequence of lines is placed in. E.g. English text
    /// is usually displayed with a line layout direction of
    /// ``Locale/LanguageDirection-swift.enum/topToBottom``. While languages do
    /// have an associated line language direction (see
    /// ``Locale/Language-swift.struct/lineLayoutDirection``), not all displays
    /// of text follow the line layout direction of the text's primary language.
    ///
    /// Horizontal script is script with a line layout direction of either
    /// ``Locale/LanguageDirection-swift.enum/topToBottom`` or
    /// ``Locale/LanguageDirection-swift.enum/bottomToTop``. Vertical script
    /// has a ``Locale/LanguageDirection-swift.enum/leftToRight`` or
    /// ``Locale/LanguageDirection-swift.enum/rightToLeft`` line layout
    /// direction. In vertical scripts, a writing direction of ``leftToRight``
    /// is interpreted as top-to-bottom and a writing direction of
    /// ``rightToLeft`` is interpreted as bottom-to-top.
    @available(FoundationPreview 6.2, *)
    @frozen
    public enum WritingDirection: Codable, Hashable, CaseIterable, Sendable {
        /// A left-to-right writing direction in horizontal script.
        ///
        /// - Note: In vertical scripts, this equivalent to a top-to-bottom
        /// writing direction.
        case leftToRight

        /// A right-to-left writing direction in horizontal script.
        ///
        /// - Note: In vertical scripts, this equivalent to a bottom-to-top
        /// writing direction.
        case rightToLeft
    }
}

extension AttributeScopes.FoundationAttributes {
    /// The base writing direction of a paragraph.
    @available(FoundationPreview 6.2, *)
    public let writingDirection: WritingDirectionAttribute

    /// The attribute key for the base writing direction of a paragraph.
    @available(FoundationPreview 6.2, *)
    @frozen
    public enum WritingDirectionAttribute: CodableAttributedStringKey {
        public typealias Value = AttributedString.WritingDirection
        public static let name: String = "Foundation.WritingDirection"

        public static let runBoundaries: AttributedString
            .AttributeRunBoundaries? = .paragraph

        public static let inheritedByAddedText = false
    }
}

@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.WritingDirectionAttribute: Sendable { }
```

## Source compatibility

These changes are additive-only and do not impact the source compatibility of existing apps.

## Implications on adoption

These new APIs will be annotated with `FoundationPreview 6.2` availability.

## Future directions

### Automatically determining the writing direction of text based on string analysis

As detailed in the documentation for `WritingDirection`, for bidirectional text to be perceived as laid out correctly, one should make sure that the writing direction is set to the value equivalent to the character direction of the primary language in the text. Foundation could provide API that automatically determines the appropriate writing direction by analyzing the (strong) directionality of characters in a string or the directionality resulting from applying the BiDi algorithm to the string.

## Alternatives considered

### Adding `natural` or `unknown` `WritingDirection`s

Other definitions of writing direction types, e.g. [UIKit's `NSWritingDirection`](https://developer.apple.com/documentation/uikit/nswritingdirection), include a `natural` case, indicating that the writing direction should be determined through other strategies. The value of any `AttributedStringKey` is optional in an `AttributedString` or `AttributeContainer`, so the absence of the attribute shall be intepreted as `natural` or `unknown`.

If a package, framework, or project offers multiple strategies to determine the effective writing direction of a paragraph, it should define a separate setting - as an `AttributedStringKey` or otherwise - that defines how the absence of the `writingDirection` value is to be interpreted.

### Invalidating `WritingDirection` on text changes

The `AttributeScopes.FoundationAttributes.WritingDirectionAttribute` may be added by an applicaiton or framework as the result of character analysis. In that case it would be great if the writing direction was removed again automatically whenever the characters of the paragraph changed.

This could be accomplished using a simple `invalidationCondition` with value `.textChanged` on the `WritingDirectionAttribute`. However, that would mean that even after explicitly setting the writing direction to a value that was not determined via character analysis, the writing direction attribute would invalidate every time the character changes. Instead, we would only want this behavior in the scenario where the attribute value was actually determined via character analysis.

For the writing direction to behave correctly, both for the case case of an explicit writing direction and one determined via character analysis, a second attribute would be needed:

`AttributeScopes.FoundationAttributes.WritingDirectionAnalysisAttribute` would have `runBoundaries` `paragraph`, `inheritedByAddedText = false`, and `invalidationCondition` `.textChanged`, so it essentially resets to `nil` every time the characters change.

Then, we add a `invalidationCondition = [.attributeChanged(AttributeScopes.FoundationAttributes.WritingDirectionAnalysisAttribute)]` to `WritingDirectionAttribute`. That way, the explicit writing direction should only reset when the text changes _and_ the writing direction was determined via string analysis, which would add `AttributeScopes.FoundationAttributes.WritingDirectionAnalysisAttribute` to the analized ranges.

`AttributedString` currently does not offer a mechanism for determining writing direction based on character analysis. Any future proposals adding such mechanism should consider adding the `WritingDirectionAnalysisAttribute`.

## Acknowledgments

Special thanks to all those who contributed to the direction of this proposal, especially Karan Miśra for providing a lot of helpful insight!
