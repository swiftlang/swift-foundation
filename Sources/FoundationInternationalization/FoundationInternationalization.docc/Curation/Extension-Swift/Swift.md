# ``FoundationInternationalization/Swift``

Extensions to types that the Swift Standard Library defines.

## Overview

In some cases, FoundationInternationalization extends Swift standard library types by adding properties, methods, or other symbols.
These add new functionality to the standard library type when you import FoundationInternationalization.
For example, you can use FoundationInternationalization's conformances of standard library types to the `FormatStyle` and `ParseStrategy` protocols from FoundationEssentials to format and parse binary numbers, durations, and more.

Other times, a type appears in this list only because FoundationInternationalization extends the type to add conformance to protocol, such as ``FloatingPointRoundingRule`` gaining a conformance to `Codable`.

## Topics

### Formatting numbers

- ``BinaryInteger``
- ``BinaryFloatingPoint``

### Formatting strings

- ``String``
- ``StringProtocol``

### Formatting sequences and ranges

- ``Sequence``
- ``Range``

### Formatting durations

- ``Duration``

### Working with codability

- ``FloatingPointRoundingRule``
