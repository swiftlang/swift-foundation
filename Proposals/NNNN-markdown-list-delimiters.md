# Markdown List Item Delimiters

* Proposal: [SF-NNNN](NNNN-markdown-list-delimiters.md)
* Authors: [Jeremy Schonfeld](https://github.com/jmschonfeld)
* Review Manager: TBD
* Status: **Pitch**

## Revision history

* **v1** Initial version

## Introduction/Motivation

The markdown spec supports two types of lists: bullet lists and ordered lists. In Foundation's API today, we refer to them as unordered and ordered lists respectively via `PresentationIntent.Kind.unorderedList`/`PresentationIntent.Kind.orderedList`. Every item in a list begins with a "list item marker". For ordered lists, the list item marker is an ordinal number followed by a "." (U+002E Full Stop) or ")" (U+0029 Right Parenthesis) delimiter character (ex. "1." or "2)"). For unordered lists, the list item marker is one of three possible characters: "-" (U+002D Hyphen-Minus), "+" (U+002B Plus Sign), or "*" (U+002A Asterisk). Note that lists must use a consistent list marker for every item in the list.

Today, an ordered list item's ordinal number is exposed via Foundation's APIs via the `.listItem(ordinal: Int)` `PresentationIntent.Kind` case for Swift and the `ordinal` property on the `NSPresentationIntent` type for Objective-C. However, we do not currently expose which list item marker a parsed unordered list used or which delimiter follows the ordinal numbers in an ordered list. It's reasonable that some markdown rendering views may wish to render the produced `AttributedString`'s list using the same list item characters in the original source text (or a comparible symbol to the original item) in which case it is important that the produced `AttributedString` provides which list item marker was used to denote items in a list.

## Proposed solution and example

To solve this, we propose adding a new attributed string attribute that will expose the list item delimiter for the current list in the produced attributed string. The value of this attribute will be a "." or ")" for ordered lists and a "-", "+", or "*" for unordered lists. Developers will be able to access this value like the following:

```swift
let attrStr = try AttributedString(markdown: /* ... some markdown string ... */)

for (intent, range) in attrStr.runs[\.presentationIntent] {
    guard let component = intent.components.last else { continue }
    
    switch component.kind {
    case .listItem(let ordinal):
        let isOrdered = intent.components[intent.components.count - 2] == .orderedList
        let listItemDelimiter = attrStr[range].listItemDelimiter
        // Process list item using isOrdered, ordinal, and listItemDelimiter...
    }
}
```

## Detailed design

```swift
extension AttributeScopes.FoundationAttributes {
    @available(FoundationPreview 6.2, *)
    public let listItemDelimiter: ListItemDelimiterAttribute
    
    @frozen
    @available(FoundationPreview 6.2, *)
    public enum ListItemDelimiterAttribute : AttributedStringKey, CodableAttributedStringKey, ObjectiveCConvertibleAttributedStringKey {
        public typealias Value = Character
        public static let name = "NSListItemDelimiter"
    }
}

@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.ListItemDelimiterAttribute : Sendable {}
```

## Source Compatibility / Impact on Existing Code

All changes are additive, existing code is not impacted. Existing clients initializing `AttributedString`s from markdown will start receiving `AttributedString`s that contain this new attribute, but (by `AttributedString`'s design) this should not have an impact on clients.

## Implications on Adoption

These new APIs will come with FoundationPreview 6.2-aligned availability so adopting code must set an appropriate minimum deployment target or dynamically check availability before using these APIs.

## Alternatives considered

### Storing the list item delimiters in `PresentationIntent.Kind`

In an ideal world, we might have expressed this delimiter in the existing `presentationIntent` attribute by amending the `unorderedList` and `orderedList` kinds to include the Delimiter via `unorderedList(bulletCharacter: Character)` and `orderedList(delimiter: Character)`. However, it is not source compatible to add associated values to an existing enum case. Alternatively we could deprecated the existing cases and replace with new cases that contain the associated values, however this comes with two major drawbacks. First, we would need to come up with new names for the new cases to ensure that they are not ambiguous with the old cases (and there are not any obvious choices for such a name). Second, it would be incompatible with existing apps for `AttributedString`s produced from markdown to solely contain the new kinds instead of the old kinds (and we cannot provide two enum cases for the same value) so we would need to introduce a new markdown parsing option that clients can enable to switch to the new enum cases in the output. While this wouldn't be a showstopper, it definitely makes the API harder to use especially when availability checking is involved.

### Storing the list item delimiters in `PresentationIntent.IntentType`

We could also choose to store this new information in the `IntentType` struct that contains the `Kind` and a unique integer identity. Since it's a non-frozen `struct`, it can easily be extended to have a new property. However, storing the information here also has a few drawbacks. First, the property would be present regardless of what the `Kind` is, meaning it would need to be optional and have a `nil` value for any instance where the `kind` is not a list. Additionally, it would feel a bit out of place here. Most of the other information comes from the `kind` and it would feel awkward at the call site to reach back to the intent type instance while switching over the `kind.

### `listItemDelimiter` attribute naming

There are a few terms of art that the cmark-gfm spec introduces concerning these values:

- **List**: One or more items of the same *list marker* type. Two list markers are of the same type if (a) they are *bullet list markers* using the same character (-, +, or *) or (b) they are ordered list numbers with the same delimiter (either . or )).
- **List Marker**: Either a *bullet list marker* or an *ordered list marker*
- **Bullet List Marker**: a "-", "*", or "+" character
- **Ordered List Marker**: a sequence of 1-9 arabic digits (0-9) followed by either a "." or ")" character

Additionally, the cmark C APIs refer to an ordered list's "." or ")" character as a "delimiter" character (ex. `cmark_node_get_list_delim`). I felt that the term "list marker" for the attribute name did not quite reflect the nature of the attribute as, based on the definition, an ordered list's marker also includes the number preceding the "." or ")" character. Instead I chose the term "delimiter" (prefixing with "list item" which matches the presentation intent API that exists today in Foundation) to mean either the delimiter character that follows an ordered list item's number or the delimiter character that begins an unordered list item. The term "delimiter" is also a term of art used throughout the markdown specification as the notion of what starts or ends a particular inline presentation intent (ex. "delimiter runs" such as "**" or "link delimeters" such as "[" vs "![") and I feel that continuing to use the term "delimiter" here fits well with these definitions.

### Attribute value types

The current design proposes that the API will use a `Character` value for its attribute. Based on the cmark spec today, this value is always guaranteed to be a single ASCII character. We could choose to represent this attribute value using a single UTF-8 byte which would work in practice. However, I chose to use `Character` here to make it more ergnomic for developers to interface between this attribute value and the underlying text that they are working with. `AttributedString` could support exposing this value as a UTF-8 scalar (i.e. a `UInt8`) or as a full `String`. However, it felt best to expose this value as a `Character` instead since in Swift the default element of a string is a `Character` (so a character can be easily used in a variety of `String` or `AttributedString.CharacterView` APIs) and we have the ability to express that this will always be a single character rather than a multi-character string via this type.
