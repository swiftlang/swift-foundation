# ``FoundationEssentials/Swift``

Extensions to types that the Swift Standard Library defines.

## Overview

In some cases, FoundationEssentials extends Swift standard library types with properties, methods, or other symbols. These add new functionality to the standard library type when you import FoundationEssentials.

Other times, a type appears in this list only because FoundationEssentials extends the type to add conformance to a FoundationEssentials protocol, such as ``ContiguousBytes`` or ``DataProtocol``.

## Topics

### Strings

- ``String``
- ``StringProtocol``

### Sequences and collections

- ``Sequence``
- ``EmptyCollection``
- ``CollectionOfOne``
- ``MutableCollection``
- ``Repeated``
- ``Slice``
- ``Array``
- ``ArraySlice``
- ``ContiguousArray``
- ``InlineArray``

### Ranges

- ``Range``
- ``RangeSet``

### Spans

- ``Span``
- ``RawSpan``
- ``OutputRawSpan``
- ``OutputSpan``
- ``UTF8Span``
- ``MutableSpan``
- ``MutableRawSpan``

### Unsafe pointers

- ``UnsafeBufferPointer``
- ``UnsafeMutableBufferPointer``
- ``UnsafeMutableRawBufferPointer``
- ``UnsafeRawBufferPointer``

### Encoding and decoding

- ``KeyedEncodingContainer``
- ``KeyedDecodingContainer``
- ``UnkeyedEncodingContainer``
- ``UnkeyedDecodingContainer``
- ``EncodingError``
- ``DecodingError``

### Special types

- ``Optional``
- ``Never``
