# ``/FoundationEssentials/AttributedString/Runs/Run``

<!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->

## Topics

### Working with run properties

- ``attributes``
- ``range``

### Accessing attributes with subscripts

- ``subscript(_:)``
- ``subscript(dynamicMember:)->ScopedAttributeContainer<S>`` <!-- subscript<S>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> where S : AttributeScope { get } -->
- ``subscript(dynamicMember:)->K.Value?``                    <!-- @preconcurrency subscript<K>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? where K : AttributedStringKey, K.Value : Sendable { get } -->
