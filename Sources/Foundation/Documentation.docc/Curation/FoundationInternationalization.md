# Foundation Internationalization

Manage and represent locale-specific information like dates, currencies, measurements, and numeric values.

## Overview

The FoundationInternationalization package serves as the basis for apps that need to model and represent values in a locale-specific way. At the heart of the package is the ``Locale`` type, which represents a conventional combination of language and region. APIs in the package use the locale to:

* Model dates and times as represented in various calendaring systems.
* Format numeric values, currencies, measurements, dates and times, and other values in a locale-appopriate way.
* Parse these same values from string representations into their native types.

Formatting works with both the `String` type from the Swift standard library and the `AttributedString` provided by the FoundationEssentials package.

## Topics

### Representing locales

- ``Locale``

### Calendrical calculations

- ``DateComponents``
- ``Calendar``
- ``TimeZone``

### Data formatting

- ``FormatStyle``
- ``FormatStyleCapitalizationContext``
- ``IntegerFormatStyle``
- ``FloatingPointFormatStyle``
- ``ListFormatStyle``
- ``StringStyle``
- ``ByteCountFormatStyle``
- ``CurrencyFormatStyleConfiguration``
- ``DescriptiveNumberFormatConfiguration``
- ``NumberFormatStyleConfiguration``


### Data parsing

- ``ParseStrategy``
- ``ParseableFormatStyle``
- ``IntegerParseStrategy``
- ``FloatingPointParseStrategy``

### Supporting types

- ``ComparisonResult-881ui``
