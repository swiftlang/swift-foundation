# ``/FoundationEssentials/Locale``


## Topics


### Creating a locale by identifier

- ``init(identifier:)``

### Creating a locale by components

- ``init(components:)``
- ``Components``
- ``init(languageCode:script:languageRegion:)``
- ``init(languageComponents:)``
- ``Language/Components``

### Working with the current locale

- ``autoupdatingCurrent``
- ``current``

### Working with identifiers

- ``identifier(fromComponents:)``
- ``IdentifierType``
- ``canonicalIdentifier(from:)``
- ``canonicalLanguageIdentifier(from:)``

### Working with locale components

- ``Components``

### Working with language components

- ``language``
- ``Language``

### Working with date and time components

- ``firstDayOfWeek``
- ``Weekday``
- ``hourCycle``
- ``HourCycle``
- ``timeZone``

### Working with measurement and counting components

- ``currency``
- ``Currency``
- ``measurementSystem``
- ``MeasurementSystem``
- ``numberingSystem``
- ``availableNumberingSystems``
- ``NumberingSystem``

### Working with region components

- ``region``
- ``Region``
- ``subdivision``
- ``Subdivision``
- ``variant``
- ``Variant``

### Working with ordering components

- ``collation``
- ``Collation``

### Working with information about a locale

- ``identifier``
- ``identifier(_:)``
- ``IdentifierType``
- ``calendar``
- ``regionCode``
- ``languageCode``
- ``LanguageCode``
- ``scriptCode``
- ``variantCode``
- ``collationIdentifier``
- ``collatorIdentifier``
- ``usesMetricSystem``
- ``decimalSeparator``
- ``groupingSeparator``
- ``currencyCode``
- ``currencySymbol``
- ``quotationBeginDelimiter``
- ``quotationEndDelimiter``
- ``alternateQuotationBeginDelimiter``
- ``alternateQuotationEndDelimiter``

### Working with display information about a locale

- ``localizedString(for:)``
- ``localizedString(forCollationIdentifier:)``
- ``localizedString(forCollatorIdentifier:)``
- ``localizedString(forCurrencyCode:)``
- ``localizedString(forIdentifier:)``
- ``localizedString(forLanguageCode:)``
- ``localizedString(forRegionCode:)``
- ``localizedString(forScriptCode:)``
- ``localizedString(forVariantCode:)``

### Working with preferred languages and locales

- ``preferredLanguages``
- ``preferredLocales``

### Comparing locales

- ``==(_:_:)``

### Hashing

- ``hash(into:)``

### Supporting types

- ``LanguageDirection-enum``
- ``Script``
