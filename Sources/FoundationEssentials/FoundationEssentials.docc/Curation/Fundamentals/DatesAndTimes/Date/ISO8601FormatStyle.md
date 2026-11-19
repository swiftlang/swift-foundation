# ``/FoundationEssentials/Date/ISO8601FormatStyle``


## Topics

### Creating an ISO 8601 format style

- ``init(dateSeparator:dateTimeSeparator:timeZone:)``
- ``init(dateSeparator:dateTimeSeparator:timeSeparator:timeZoneSeparator:includingFractionalSeconds:timeZone:)``
- ``iso8601-1r3n2``
- ``iso8601-2pdq6``
- ``iso8601-5gh6l``
- ``iso8601-6848a``

### Modifying an ISO 8601 format style

- ``locale(_:)``
- ``dateSeparator``
- ``DateSeparator``
- ``dateTimeSeparator``
- ``DateTimeSeparator``
- ``timeZone``
- ``dateTimeSeparator(_:)``

### Modifying dates in an ISO 8601 format style

- ``dateSeparator(_:)``
- ``DateSeparator``
- ``year()``
- ``month()``
- ``weekOfYear()``
- ``day()``
- ``includingFractionalSeconds``

### Modifying times in an ISO 8601 format style

- ``time(includingFractionalSeconds:)``
- ``timeSeparator``
- ``timeSeparator(_:)``
- ``TimeSeparator``
- ``timeZone(separator:)``
- ``timeZoneSeparator``
- ``TimeZoneSeparator``
- ``timeZoneSeparator(_:)``

### Parsing an ISO 8601 format style

- ``parse(_:)``
- ``parseStrategy``

### Applying an ISO 8601 format style

- ``format(_:)``

### Comparing ISO 8601 format styles

- ``!=(_:_:)``
- ``==(_:_:)``

### Coding and decoding

- ``init(from:)``
- ``encode(to:)``

### Hashing

- ``hash(into:)``


