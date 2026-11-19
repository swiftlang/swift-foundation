# ``/FoundationInternationalization/KeyPathComparator``


## Topics


### Creating a key path comparator

- ``init(_:comparator:)-(KeyPath<Compared,Value>&Sendable,_)``          <!-- init<Value, Comparator>(_ keyPath: any KeyPath<Compared, Value> & Sendable, comparator: Comparator) where Value == Comparator.Compared, Comparator : SortComparator -->
- ``init(_:comparator:)-(KeyPath<Compared,Value?>&Sendable,_)``         <!-- init<Value, Comparator>(_ keyPath: any KeyPath<Compared, Value?> & Sendable, comparator: Comparator) where Value == Comparator.Compared, Comparator : SortComparator -->
- ``init(_:comparator:order:)-(KeyPath<Compared,Value>&Sendable,_,_)``  <!-- init<Value, Comparator>(_ keyPath: any KeyPath<Compared, Value> & Sendable, comparator: Comparator, order: SortOrder) where Value == Comparator.Compared, Comparator : SortComparator -->
- ``init(_:comparator:order:)-(KeyPath<Compared,Value?>&Sendable,_,_)`` <!-- init<Value, Comparator>(_ keyPath: any KeyPath<Compared, Value?> & Sendable, comparator: Comparator, order: SortOrder) where Value == Comparator.Compared, Comparator : SortComparator -->
- ``init(_:order:)-(KeyPath<Compared,Value>&Sendable,_)``               <!-- init<Value>(_ keyPath: any KeyPath<Compared, Value> & Sendable, order: SortOrder = .forward) where Value : Comparable -->
- ``init(_:order:)-(KeyPath<Compared,Value?>&Sendable,_)``              <!-- init<Value>(_ keyPath: any KeyPath<Compared, Value?> & Sendable, order: SortOrder = .forward) where Value : Comparable -->

### Performing comparison

- ``compare(_:_:)``

### Working with a key path comparator

- ``keyPath``
- ``order``

### Comparing key path comparators

- ``==(_:_:)``

### Hashing

- ``hash(into:)``

