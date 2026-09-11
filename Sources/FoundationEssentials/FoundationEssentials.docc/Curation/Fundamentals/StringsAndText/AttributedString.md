# ``FoundationEssentials/AttributedString``

## Topics

### Creating an attributed string

- ``init()``
- ``init(_:)-(AttributedSubstring)``              <!-- init(_ substring: AttributedSubstring) -->
- ``init(_:)-(DiscontiguousAttributedSubstring)`` <!-- init(_ substring: DiscontiguousAttributedSubstring) -->
- ``DiscontiguousAttributedSubstring``
- ``init(_:attributes:)-(S,_)``                   <!-- init<S>(_ elements: S, attributes: AttributeContainer = .init()) where S : Sequence, S.Element == Character -->
- ``init(_:attributes:)-(String,_)``              <!-- init(_ string: String, attributes: AttributeContainer = .init()) -->
- ``init(_:attributes:)-(Substring,_)``           <!-- init(_ substring: Substring, attributes: AttributeContainer = .init()) -->

### Creating an attributed string from a literal value

- ``init(stringLiteral:)``

### Applying and modifying attributes

- ``setAttributes(_:)``
- ``AttributeContainer``
- ``mergeAttributes(_:mergePolicy:)``
- ``AttributeMergePolicy``
- ``replaceAttributes(_:with:)``
- ``AttributedStringAttributeMutation``

### Using defined attributes

- ``AttributeScope``
- ``AttributeScopes``
- ``AttributeDynamicLookup``
- ``ScopedAttributeContainer``

### Creating an attributed string from Markdown

- ``MarkdownDecodableAttributedStringKey``

### Accessing views into the attributed string

- ``characters``
- ``CharacterView``
- ``unicodeScalars``
- ``UnicodeScalarView``
- ``runs``
- ``Runs-swift.struct``

### Modifying an attributed string

- ``insert(_:at:)``
- ``Index``
- ``removeSubrange(_:)``
- ``replaceSubrange(_:with:)``
- ``removeSubranges(_:)``

### Transforming attributes

- ``transform(updating:body:)->Range<AttributedString.Index>?``                           <!-- mutating func transform<E>(updating range: Range<AttributedString.Index>, body: (inout AttributedString) throws(E) -> Void) throws(E) -> Range<AttributedString.Index>? where E : Error -->
- ``transform(updating:body:)->[Range<AttributedString.Index>]?``                         <!-- mutating func transform<E>(updating ranges: [Range<AttributedString.Index>], body: (inout AttributedString) throws(E) -> Void) throws(E) -> [Range<AttributedString.Index>]? where E : Error -->
- ``transform(updating:body:)-5wkgb``
- ``transform(updating:body:)-7z9ns``
- ``transformingAttributes(_:_:)-(K.Type,_)``                                             <!-- @preconcurrency func transformingAttributes<K>(_ k: K.Type, _ c: (inout AttributedString.SingleAttributeTransformer<K>) -> Void) -> AttributedString where K : AttributedStringKey, K.Value : Sendable -->
- ``transformingAttributes(_:_:)-(KeyPath<AttributeDynamicLookup,K>,_)``                  <!-- @preconcurrency func transformingAttributes<K>(_ k: KeyPath<AttributeDynamicLookup, K>, _ c: (inout AttributedString.SingleAttributeTransformer<K>) -> Void) -> AttributedString where K : AttributedStringKey, K.Value : Sendable -->
- ``transformingAttributes(_:_:_:)-(K1.Type,_,_)``                                        <!-- @preconcurrency func transformingAttributes<K1, K2>(_ k: K1.Type, _ k2: K2.Type, _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>) -> Void) -> AttributedString where K1 : AttributedStringKey, K2 : AttributedStringKey, K1.Value : Sendable, K2.Value : Sendable -->
- ``transformingAttributes(_:_:_:)-(KeyPath<AttributeDynamicLookup,K1>,_,_)``             <!-- @preconcurrency func transformingAttributes<K1, K2>(_ k: KeyPath<AttributeDynamicLookup, K1>, _ k2: KeyPath<AttributeDynamicLookup, K2>, _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>) -> Void) -> AttributedString where K1 : AttributedStringKey, K2 : AttributedStringKey, K1.Value : Sendable, K2.Value : Sendable -->
- ``transformingAttributes(_:_:_:_:)-(KeyPath<AttributeDynamicLookup,K1>,_,_,_)``         <!-- @preconcurrency func transformingAttributes<K1, K2, K3>(_ k: KeyPath<AttributeDynamicLookup, K1>, _ k2: KeyPath<AttributeDynamicLookup, K2>, _ k3: KeyPath<AttributeDynamicLookup, K3>, _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>, inout AttributedString.SingleAttributeTransformer<K3>) -> Void) -> AttributedString where K1 : AttributedStringKey, K2 : AttributedStringKey, K3 : AttributedStringKey, K1.Value : Sendable, K2.Value : Sendable, K3.Value : Sendable -->
- ``transformingAttributes(_:_:_:_:)-(K1.Type,_,_,_)``                                    <!-- @preconcurrency func transformingAttributes<K1, K2, K3>(_ k: K1.Type, _ k2: K2.Type, _ k3: K3.Type, _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>, inout AttributedString.SingleAttributeTransformer<K3>) -> Void) -> AttributedString where K1 : AttributedStringKey, K2 : AttributedStringKey, K3 : AttributedStringKey, K1.Value : Sendable, K2.Value : Sendable, K3.Value : Sendable -->
- ``transformingAttributes(_:_:_:_:_:)-(KeyPath<AttributeDynamicLookup,K1>,_,_,_,_)``     <!-- @preconcurrency func transformingAttributes<K1, K2, K3, K4>(_ k: KeyPath<AttributeDynamicLookup, K1>, _ k2: KeyPath<AttributeDynamicLookup, K2>, _ k3: KeyPath<AttributeDynamicLookup, K3>, _ k4: KeyPath<AttributeDynamicLookup, K4>, _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>, inout AttributedString.SingleAttributeTransformer<K3>, inout AttributedString.SingleAttributeTransformer<K4>) -> Void) -> AttributedString where K1 : AttributedStringKey, K2 : AttributedStringKey, K3 : AttributedStringKey, K4 : AttributedStringKey, K1.Value : Sendable, K2.Value : Sendable, K3.Value : Sendable, K4.Value : Sendable -->
- ``transformingAttributes(_:_:_:_:_:)-(K1.Type,_,_,_,_)``                                <!-- @preconcurrency func transformingAttributes<K1, K2, K3, K4>(_ k: K1.Type, _ k2: K2.Type, _ k3: K3.Type, _ k4: K4.Type, _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>, inout AttributedString.SingleAttributeTransformer<K3>, inout AttributedString.SingleAttributeTransformer<K4>) -> Void) -> AttributedString where K1 : AttributedStringKey, K2 : AttributedStringKey, K3 : AttributedStringKey, K4 : AttributedStringKey, K1.Value : Sendable, K2.Value : Sendable, K3.Value : Sendable, K4.Value : Sendable -->
- ``transformingAttributes(_:_:_:_:_:_:)-(K1.Type,_,_,_,_,_)``                            <!-- @preconcurrency func transformingAttributes<K1, K2, K3, K4, K5>(_ k: K1.Type, _ k2: K2.Type, _ k3: K3.Type, _ k4: K4.Type, _ k5: K5.Type, _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>, inout AttributedString.SingleAttributeTransformer<K3>, inout AttributedString.SingleAttributeTransformer<K4>, inout AttributedString.SingleAttributeTransformer<K5>) -> Void) -> AttributedString where K1 : AttributedStringKey, K2 : AttributedStringKey, K3 : AttributedStringKey, K4 : AttributedStringKey, K5 : AttributedStringKey, K1.Value : Sendable, K2.Value : Sendable, K3.Value : Sendable, K4.Value : Sendable, K5.Value : Sendable -->
- ``transformingAttributes(_:_:_:_:_:_:)-(KeyPath<AttributeDynamicLookup,K1>,_,_,_,_,_)`` <!-- @preconcurrency func transformingAttributes<K1, K2, K3, K4, K5>(_ k: KeyPath<AttributeDynamicLookup, K1>, _ k2: KeyPath<AttributeDynamicLookup, K2>, _ k3: KeyPath<AttributeDynamicLookup, K3>, _ k4: KeyPath<AttributeDynamicLookup, K4>, _ k5: KeyPath<AttributeDynamicLookup, K5>, _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>, inout AttributedString.SingleAttributeTransformer<K3>, inout AttributedString.SingleAttributeTransformer<K4>, inout AttributedString.SingleAttributeTransformer<K5>) -> Void) -> AttributedString where K1 : AttributedStringKey, K2 : AttributedStringKey, K3 : AttributedStringKey, K4 : AttributedStringKey, K5 : AttributedStringKey, K1.Value : Sendable, K2.Value : Sendable, K3.Value : Sendable, K4.Value : Sendable, K5.Value : Sendable -->
- ``SingleAttributeTransformer``


### Accessing whole-string attributes

- ``subscript(_:)-6no6u``
- ``subscript(_:)-87fzh``
- ``subscript(_:)-622ch`` <!-- subscript(indices: RangeSet<AttributedString.Index>) -> DiscontiguousAttributedSubstring { get set } -->
- ``subscript(dynamicMember:)-3epmh``
- ``subscript(dynamicMember:)-1o7kw``
- ``AttributeDynamicLookup``
- ``ScopedAttributeContainer``

### Combining attributed strings

- ``append(_:)``
- ``+(_:_:)-1m4m5``
- ``+(_:_:)-8pfmv``
- ``+=(_:_:)-hi02``
- ``+=(_:_:)-mcpi``

### Performing automatic grammar agreement

### Comparing attributed strings

- ``==(_:_:)``

### Encoding and decoding

- <doc:EncodingAndDecodingAttributedStringKeys>

### Describing an attributed string

- ``description``

### Supporting types

- ``AttributeInvalidationCondition``
- ``UTF16View``
- ``UTF8View``
- ``AttributeRunBoundaries``
- ``WritingDirection``
