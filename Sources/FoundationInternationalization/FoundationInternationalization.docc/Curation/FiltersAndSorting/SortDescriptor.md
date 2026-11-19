# ``/FoundationInternationalization/SortDescriptor``


## Topics

### Creating a sort descriptor

- ``init(_:comparator:)-(KeyPath<Compared,String>&Sendable,_)``          <!-- init(_ keyPath: any KeyPath<Compared, String> & Sendable, comparator: String.StandardComparator) -->
- ``init(_:comparator:)-(KeyPath<Compared,String?>&Sendable,_)``         <!-- init(_ keyPath: any KeyPath<Compared, String?> & Sendable, comparator: String.StandardComparator) -->
- ``init(_:comparator:order:)-(KeyPath<Compared,String?>&Sendable,_,_)`` <!-- init(_ keyPath: any KeyPath<Compared, String?> & Sendable, comparator: String.StandardComparator, order: SortOrder) -->
- ``init(_:comparator:order:)-(KeyPath<Compared,String>&Sendable,_,_)``  <!-- init(_ keyPath: any KeyPath<Compared, String> & Sendable, comparator: String.StandardComparator, order: SortOrder) -->
- ``init(_:order:)-(KeyPath<Compared,Value?>&Sendable,_)``               <!-- init<Value>(_ keyPath: any KeyPath<Compared, Value?> & Sendable, order: SortOrder = .forward) where Value : Comparable -->
- ``init(_:order:)-(KeyPath<Compared,Value>&Sendable,_)``                <!-- init<Value>(_ keyPath: any KeyPath<Compared, Value> & Sendable, order: SortOrder = .forward) where Value : Comparable -->

### Performing comparison

- ``compare(_:_:)``

### Working with a sort descriptor

- ``keyPath``
- ``order``

### Comparing strings

- ``stringComparator``

### Hashing

- ``hash(into:)``

### Encoding and decoding

- ``init(from:)``
