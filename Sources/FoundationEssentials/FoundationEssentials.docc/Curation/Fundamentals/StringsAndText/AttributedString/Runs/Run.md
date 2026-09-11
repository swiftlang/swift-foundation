# ``/FoundationEssentials/AttributedString/Runs/Run``


## Topics

### Working with run properties

- ``attributes``
- ``range``

### Accessing attributes with subscripts

- ``subscript(_:)``
- ``subscript(dynamicMember:)->ScopedAttributeContainer<S>`` <!-- subscript<S>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> where S : AttributeScope { get } -->
- ``subscript(dynamicMember:)->K.Value?``                    <!-- @preconcurrency subscript<K>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? where K : AttributedStringKey, K.Value : Sendable { get } -->
