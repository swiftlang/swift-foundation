# ``/FoundationEssentials/Locale``

<!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->

## Topics


### Creating a locale by identifier

- ``init(identifier:)``

### Creating a locale by components

- ``init(components:)``
- ``Components``
- ``init(languageCode:script:languageRegion:)``
- ``init(languageComponents:)``
- ``Language/Components``




<!-- divide -->



### Structures

- ``Collation``
- ``Components``
- ``Currency``
- ``Language``
- ``LanguageCode``
- ``MeasurementSystem``
- ``NumberingSystem``
- ``Region``
- ``Script``
- ``Subdivision``
- ``Variant``

### Operators

- ``==(_:_:)``


### Instance Properties

- ``alternateQuotationBeginDelimiter``
- ``alternateQuotationEndDelimiter``
- ``availableNumberingSystems``
- ``calendar``
- ``collation``
- ``collationIdentifier``
- ``collatorIdentifier``
- ``currency``
- ``currencyCode``
- ``currencySymbol``
- ``decimalSeparator``
- ``firstDayOfWeek``
- ``groupingSeparator``
- ``hourCycle``
- ``identifier``
- ``language``
- ``languageCode``
- ``measurementSystem``
- ``numberingSystem``
- ``quotationBeginDelimiter``
- ``quotationEndDelimiter``
- ``region``
- ``regionCode``
- ``scriptCode``
- ``subdivision``
- ``timeZone``
- ``usesMetricSystem``
- ``variant``
- ``variantCode``

### Instance Methods

- ``hash(into:)``
- ``identifier(_:)``
- ``localizedString(for:)``
- ``localizedString(forCollationIdentifier:)``
- ``localizedString(forCollatorIdentifier:)``
- ``localizedString(forCurrencyCode:)``
- ``localizedString(forIdentifier:)``
- ``localizedString(forLanguageCode:)``
- ``localizedString(forRegionCode:)``
- ``localizedString(forScriptCode:)``
- ``localizedString(forVariantCode:)``

### Type Properties

- ``autoupdatingCurrent``
- ``availableIdentifiers``
- ``commonISOCurrencyCodes``
- ``current``
- ``preferredLanguages``
- ``preferredLocales``

### Type Methods

- ``canonicalIdentifier(from:)``
- ``canonicalLanguageIdentifier(from:)``
- ``identifier(_:from:)``
- ``identifier(fromComponents:)``
- ``identifier(fromWindowsLocaleCode:)``
- ``windowsLocaleCode(fromIdentifier:)``

### Enumerations

- ``HourCycle``
- ``IdentifierType``
- ``LanguageDirection``
- ``Weekday``
