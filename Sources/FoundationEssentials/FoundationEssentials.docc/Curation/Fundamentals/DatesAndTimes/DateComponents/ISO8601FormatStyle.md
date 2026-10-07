# ``/FoundationEssentials/DateComponents/ISO8601FormatStyle``

## Topics

### Creating a format style

- ``init(dateSeparator:dateTimeSeparator:timeSeparator:timeZoneSeparator:includingFractionalSeconds:timeZone:)``

### Working with formatting properties

- ``dateSeparator``
- ``dateTimeSeparator``
- ``timeSeparator``
- ``timeZoneSeparator``
- ``includingFractionalSeconds``

### Working with the time zone

- ``timeZone``

### Modifying formatting properties

- ``dateSeparator(_:)``
- ``dateTimeSeparator(_:)``
- ``timeSeparator(_:)``
- ``timeZoneSeparator(_:)``
- ``timeZone(separator:)``

### Modfying date formatting

- ``year()``
- ``month()``
- ``weekOfYear()``
- ``day()``


### Modifying time formatting

- ``time(includingFractionalSeconds:)``

### Comparing format styles

- ``==(_:_:)``

### Encoding and decoding

- ``init(from:)``
- ``encode(to:)``

### Hashing 

- ``hash(into:)``
