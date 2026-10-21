# ``FoundationInternationalization/FoundationEssentials``

Extensions to types that the Foundation Essentials module defines.

## Overview

In some cases, FoundationInternationalization extends types from FoundationEssentials by adding properties, methods, supporting types, or other symbols.
These add new functionality to the FoundationEssentials type when you import FoundationInternationalization.
For example, FoundationInternationalization adds types that conform to `FormatStyle` and `ParseStrategy` to FoundationEssentials's ``Calendar``, ``Date``, and ``Decimal`` types.
This allows you to use the `format(_:)` and `formatted()` styling methods with these types.

## Topics

### Formatting dates and times

- ``Calendar``
- ``Date``
- ``TimeZone``

### Formatting numbers

- ``Decimal``

### Supporting types

- ``FormatStyle``
- ``ParseStrategy``
- ``ParseableFormatStyle``
- ``Locale``
