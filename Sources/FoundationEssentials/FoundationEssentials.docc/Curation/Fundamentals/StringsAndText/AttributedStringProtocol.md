# ``/FoundationEssentials/AttributedStringProtocol``


## Topics

### Applying attributes

- ``settingAttributes(_:)``
- ``mergingAttributes(_:mergePolicy:)``
- ``AttributedString/AttributeMergePolicy``
- ``replacingAttributes(_:with:)``

### Searching for a substring

- ``range(of:options:locale:)``

### Accessing a range

- ``subscript(_:)->AttributedSubstring``                     <!-- subscript<R>(bounds: R) -> AttributedSubstring where R : RangeExpression, R.Bound == AttributedString.Index { get } -->

### Accessing indices

- ``startIndex``
- ``endIndex``
- ``index(_:offsetByCharacters:)``
- ``index(_:offsetByRuns:)``
- ``index(_:offsetByUnicodeScalars:)``
- ``index(afterCharacter:)``
- ``index(afterRun:)``
- ``index(afterUnicodeScalar:)``
- ``index(beforeCharacter:)``
- ``index(beforeRun:)``
- ``index(beforeUnicodeScalar:)``
- ``AttributedString/Index``

### Accessing views into the attributed string

- ``characters``
- ``unicodeScalars``
- ``runs``
- ``utf8``
- ``AttributedString/UTF8View``
- ``utf16``
- ``AttributedString/UTF16View``

### Accessing whole-string attributes

- ``subscript(_:)->K.Value?``                                <!-- @preconcurrency subscript<K>(_: K.Type) -> K.Value? where K : AttributedStringKey, K.Value : Sendable { get set } -->
- ``subscript(dynamicMember:)->K.Value?``                    <!-- @preconcurrency subscript<K>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? where K : AttributedStringKey, K.Value : Sendable { get set } -->
- ``AttributeDynamicLookup``
- ``subscript(dynamicMember:)->ScopedAttributeContainer<S>`` <!-- subscript<S>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> where S : AttributeScope { get set } -->
- ``AttributeScopes``
- ``ScopedAttributeContainer``

### Comparing attributed strings or substrings

- ``==(_:_:)``

