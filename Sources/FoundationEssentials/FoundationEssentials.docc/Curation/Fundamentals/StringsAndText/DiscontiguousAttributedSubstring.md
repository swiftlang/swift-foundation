# ``/FoundationEssentials/DiscontiguousAttributedSubstring``

## Topics

### Accessing the source attributed string

- ``base``

### Working with views into the string

- ``runs``
- ``characters``
- ``unicodeScalars``

### Accessing attribute values

- ``subscript(_:)->K.Value?``                                 <!-- subscript<K>(_: K.Type) -> K.Value? where K : AttributedStringKey, K.Value : Sendable { get set } -->
- ``subscript(dynamicMember:)->K.Value?``                     <!-- subscript<K>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? where K : AttributedStringKey, K.Value : Sendable { get set } -->

### Accessing substrings of the substring

- ``subscript(_:)-(RangeExpression<AttributedString.Index>)`` <!-- subscript(bounds: some RangeExpression<AttributedString.Index>) -> DiscontiguousAttributedSubstring { get } -->
- ``subscript(_:)-(RangeSet<AttributedString.Index>)``        <!-- subscript(bounds: RangeSet<AttributedString.Index>) -> DiscontiguousAttributedSubstring { get } -->

### Accessing attribute containers

- ``subscript(dynamicMember:)->ScopedAttributeContainer<S>``  <!-- subscript<S>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> where S : AttributeScope { get set } -->
