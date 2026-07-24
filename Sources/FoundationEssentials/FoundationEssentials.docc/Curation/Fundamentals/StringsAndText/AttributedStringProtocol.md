# ``/FoundationEssentials/AttributedStringProtocol``


## Topics

### Applying Attributes

- ``settingAttributes(_:)``
- ``mergingAttributes(_:mergePolicy:)``
- ``AttributedString/AttributeMergePolicy``
- ``replacingAttributes(_:with:)``

### Searching for a Substring

- ``range(of:options:locale:)``

### Accessing a Range

- ``subscript(_:)->AttributedSubstring``                     <!-- subscript<R>(bounds: R) -> AttributedSubstring where R : RangeExpression, R.Bound == AttributedString.Index { get } -->

### Accessing Indices

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

### Accessing Views into the Attributed String

- ``characters``
- ``unicodeScalars``
- ``runs``
- ``utf8``
- ``AttributedString/UTF8View``
- ``utf16``
- ``AttributedString/UTF16View``

### Accessing Whole-String Attributes

- ``subscript(_:)->K.Value?``                                <!-- @preconcurrency subscript<K>(_: K.Type) -> K.Value? where K : AttributedStringKey, K.Value : Sendable { get set } -->
- ``subscript(dynamicMember:)->K.Value?``                    <!-- @preconcurrency subscript<K>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? where K : AttributedStringKey, K.Value : Sendable { get set } -->
- ``AttributeDynamicLookup``
- ``subscript(dynamicMember:)->ScopedAttributeContainer<S>`` <!-- subscript<S>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> where S : AttributeScope { get set } -->
- ``ScopedAttributeContainer``

### Comparing Attributed Strings or Substrings

- ``==(_:_:)``

