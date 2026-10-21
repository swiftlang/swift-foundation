# ``/FoundationEssentials/TimeZone``


## Topics

### Getting the current time zone

- ``autoupdatingCurrent``
- ``current``

### Getting standard time zones

- ``gmt``

### Creating a time zone

- ``init(secondsFromGMT:)``
- ``abbreviationDictionary``
- ``init(abbreviation:)``
- ``init(identifier:)``

### Getting time zone information

- ``identifier``
- ``abbreviation(for:)``
- ``secondsFromGMT(for:)``

### Working with daylight savings

- ``isDaylightSavingTime(for:)``
- ``daylightSavingTimeOffset(for:)``
- ``nextDaylightSavingTimeTransition``
- ``nextDaylightSavingTimeTransition(after:)``

### Describing time zones

- ``localizedName(for:locale:)``

### Comparing time zones

- ``==(_:_:)``

### Hashing

- ``hash(into:)``

### Supporting types

- ``NameStyle``
