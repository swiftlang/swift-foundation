# ``FoundationEssentials/Data``


## Topics

### Creating empty data

- ``init()``
- ``init(capacity:)``
- ``init(count:)``
- ``resetBytes(in:)``

### Creating populated data

- ``init()``
- ``init(bytes:count:)``
- ``init(bytesNoCopy:count:deallocator:)``
- ``Deallocator``
- ``init(bytes:)-(S)``                                       <!-- init<S>(bytes elements: S) where S : Sequence, S.Element == UInt8 -->
- ``init(bytes:)-(ArraySlice<UInt8>)``                       <!-- init(bytes: ArraySlice<UInt8>) -->
- ``init(bytes:)-([UInt8])``                                 <!-- init(bytes: Array<UInt8>) -->
- ``init(repeating:count:)``
- ``init(_:)-(Data)``                                        <!-- init(_ data: Data) -->
- ``init(_:)-(Sequence<UInt8>)``                             <!-- @abi(init(fastCheckElements elements: some Sequence<UInt8>)) init(_ elements: some Sequence<UInt8>) -->
- ``init(_:)-(Sequence<UInt8>&ContiguousBytes)``             <!-- init(_ elements: some ContiguousBytes & Sequence<UInt8>) -->

### Creating data from raw memory

- ``init(bytes:count:)``
- ``init(buffer:)-(UnsafeBufferPointer<SourceType>)``        <!-- init<SourceType>(buffer: UnsafeBufferPointer<SourceType>) -->
- ``init(buffer:)-(UnsafeMutableBufferPointer<SourceType>)`` <!-- init<SourceType>(buffer: UnsafeMutableBufferPointer<SourceType>) -->
- ``init(bytesNoCopy:count:deallocator:)``
- ``Deallocator``

### Creating data from the contents of a URL

- ``init(contentsOf:options:)``
- ``ReadingOptions``

### Creating data from base-64 representation

- ``init(base64Encoded:options:)-(Data,_)``                  <!-- init?(base64Encoded base64Data: Data, options: Data.Base64DecodingOptions = []) -->
- ``init(base64Encoded:options:)-(String,_)``                <!-- init?(base64Encoded base64String: String, options: Data.Base64DecodingOptions = []) -->
- ``Base64DecodingOptions``

### Reading and writing data

- ``write(to:options:)``
- ``WritingOptions``

### Base-64 encoding

- ``base64EncodedData(options:)``
- ``base64EncodedString(options:)``
- ``Base64EncodingOptions``

### Counting bytes

- ``isEmpty``

### Accessing bytes

- ``bytes``
- ``mutableBytes``
- ``count``
- ``span``
- ``mutableSpan``
- ``subscript(_:)->UInt8``              <!-- subscript(index: Data.Index) -> UInt8 { get set } -->
- ``subscript(_:)-(R)->Data``           <!-- subscript<R>(rangeExpression: R) -> Data where R : RangeExpression, R.Bound : FixedWidthInteger { get set } -->
- ``subscript(_:)-(Range<Index>)`` <!-- subscript(bounds: Range<Data.Index>) -> Data { get set } -->

### Accessing underlying memory

- ``withUnsafeBytes(_:)-((UnsafePointer<ContentType>)->ResultType)``               <!-- func withUnsafeBytes<ResultType, ContentType>(_ body: (UnsafePointer<ContentType>) throws -> ResultType) rethrows -> ResultType -->
- ``withUnsafeBytes(_:)-((UnsafeRawBufferPointer)->ResultType)``                   <!-- func withUnsafeBytes<E, ResultType>(_ body: (UnsafeRawBufferPointer) throws(E) -> ResultType) throws(E) -> ResultType where E : Error, ResultType : ~Copyable -->
- ``withUnsafeMutableBytes(_:)-((UnsafeMutablePointer<ContentType>)->ResultType)`` <!-- mutating func withUnsafeMutableBytes<ResultType, ContentType>(_ body: (UnsafeMutablePointer<ContentType>) throws -> ResultType) rethrows -> ResultType -->
- ``withUnsafeMutableBytes(_:)-((UnsafeMutableRawBufferPointer)->ResultType)``     <!-- mutating func withUnsafeMutableBytes<E, ResultType>(_ body: (UnsafeMutableRawBufferPointer) throws(E) -> ResultType) throws(E) -> ResultType where E : Error, ResultType : ~Copyable -->
- ``copyBytes(to:count:)``
- ``copyBytes(to:from:)->()``                                                      <!-- func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, from range: Range<Data.Index>) -->
- ``copyBytes(to:from:)->()``                                   <!-- func copyBytes<DestinationType>(to buffer: UnsafeMutableBufferPointer<DestinationType>, from range: Range<Data.Index>? = nil) -> Int -->
- ``copyBytes(to:from:)-7ei1u``
- ``withContiguousStorageIfAvailable(_:)``


### Appending bytes

- ``append(_:count:)``
- ``append(_:)-(UnsafeBufferPointer<SourceType>)``                                 <!-- mutating func append<SourceType>(_ buffer: UnsafeBufferPointer<SourceType>) -->
- ``append(_:)-(UInt8)``                                                           <!-- mutating func append(_ byte: UInt8) -->
- ``append(_:)-(Data)``                                                            <!-- mutating func append(_ other: Data) -->
- ``append(contentsOf:)-(Sequence<UInt8>&ContiguousBytes)``                        <!-- mutating func append(contentsOf elements: some ContiguousBytes & Sequence<UInt8>) -->
- ``append(contentsOf:)-(Sequence<UInt8>)``                                        <!-- @abi(func append(fastContentsof elements: some Sequence<UInt8>)) mutating func append(contentsOf elements: some Sequence<UInt8>) -->
- ``reserveCapacity(_:)``

### Removing bytes

- ``remove(at:)``
- ``removeAll(keepingCapacity:)``
- ``removeSubrange(_:)``

### Replacing a range of bytes

- ``replaceSubrange(_:with:)-(_,Collection<UInt8>&ContiguousBytes)``               <!-- mutating func replaceSubrange(_ subrange: Range<Data.Index>, with newElements: some ContiguousBytes & Collection<UInt8>) -->
- ``replaceSubrange(_:with:)-(_,UnsafeBufferPointer<SourceType>)``                 <!-- mutating func replaceSubrange<SourceType>(_ subrange: Range<Data.Index>, with buffer: UnsafeBufferPointer<SourceType>) -->
- ``replaceSubrange(_:with:)-(_,Collection<UInt8>)``                               <!-- @abi(func repalceSubrangeFast(_ subrange: Range<Data.Index>, with newElements: some Collection<UInt8>)) mutating func replaceSubrange(_ subrange: Range<Data.Index>, with newElements: some Collection<UInt8>) -->
- ``replaceSubrange(_:with:count:)``

### Inserting bytes

- ``insert(_:at:)``


### Finding bytes

- ``first(where:)``
- ``max()``
- ``max(by:)``
- ``min()``
- ``min(by:)``
- ``range(of:options:in:)``
- ``SearchOptions``

### Selecting bytes

- ``filter(_:)``
- ``prefix(_:)``
- ``prefix(through:)``
- ``prefix(upTo:)``
- ``prefix(while:)``
- ``suffix(_:)``
- ``suffix(from:)``

### Excluding bytes

- ``dropLast(_:)``
- ``dropFirst(_:)``
- ``drop(while:)``
- ``advanced(by:)``

### Transforming data

- ``reduce(_:_:)``
- ``lazy``

### Iterating over bytes

- ``forEach(_:)``
- ``enumerated()``
- ``makeIterator()``
- ``Iterator``
- ``enumerateBytes(_:)``

### Sorting bytes

- ``sort(by:)``
- ``sorted()``
- ``sorted(by:)``
- ``reversed()``

### Splitting the buffer

- ``subdata(in:)``
- ``split(maxSplits:omittingEmptySubsequences:whereSeparator:)``
- ``split(separator:maxSplits:omittingEmptySubsequences:)``

### Comparing data

- ``==(_:_:)``
- ``elementsEqual(_:)``
- ``starts(with:)``
- ``lexicographicallyPrecedes(_:)``
- ``lexicographicallyPrecedes(_:by:)``

### Manipulating indexes

- ``startIndex``
- ``endIndex``
- ``index(after:)``
- ``index(before:)``
- ``Index``

### Manipulating index ranges

- ``indices``
- ``Indices``

### Describing data

- ``description``
- ``debugDescription``

