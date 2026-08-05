# ``/FoundationEssentials/IndexPath``

<!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->

## Topics

### Creating an index path

- ``init()``
- ``init(index:)``
- ``init(arrayLiteral:)``
- ``init(indexes:)-([IndexPath.Element])`` <!-- init(indexes: Array<IndexPath.Element>) -->
- ``init(indexes:)-(ElementSequence)``     <!-- init<ElementSequence>(indexes: ElementSequence) where ElementSequence : Sequence, ElementSequence.Element == Int -->

### Working with terminal nodes

- ``startIndex``
- ``endIndex``

### Counting nodes in the path

- ``count``

### Selecting nodes

- ``index(before:)``
- ``index(after:)``
- ``subscript(_:)->IndexPath.Element`` <!-- subscript(index: IndexPath.Index) -> IndexPath.Element { get set } -->
- ``subscript(_:)->IndexPath``         <!-- subscript(range: Range<IndexPath.Index>) -> IndexPath { get set } -->


### Appending nodes

- ``+(_:_:)``
- ``appending(_:)-(IndexPath.Element)``   <!-- func appending(_ other: IndexPath.Element) -> IndexPath -->
- ``appending(_:)-([IndexPath.Element])`` <!-- func appending(_ other: Array<IndexPath.Element>) -> IndexPath -->
- ``appending(_:)-(IndexPath)``           <!-- func appending(_ other: IndexPath) -> IndexPath -->
- ``+=(_:_:)``
- ``append(_:)-(IndexPath.Element)``      <!-- mutating func append(_ other: IndexPath.Element) -->
- ``append(_:)-([IndexPath.Element])``    <!-- mutating func append(_ other: Array<IndexPath.Element>) -->
- ``append(_:)-(IndexPath)``              <!-- mutating func append(_ other: IndexPath) -->

### Excluding nodes

- ``dropLast()``

### Iterating over nodes

- ``makeIterator()``

### Comparing index paths

- ``compare(_:)``
- ``==(_:_:)``
- ``<=(_:_:)``
- ``<(_:_:)``
- ``>(_:_:)``
- ``>=(_:_:)``

### Hashing

- ``hash(into:)``

### Supporting types

- ``Element``
- ``Index``
- ``Indices``

