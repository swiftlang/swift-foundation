# ``/FoundationEssentials/Date/ISO8601FormatStyle``


## Topics

### Creating an ISO 8601 Format Style

- ``init(dateSeparator:dateTimeSeparator:timeZone:)``
- ``init(dateSeparator:dateTimeSeparator:timeSeparator:timeZoneSeparator:includingFractionalSeconds:timeZone:)``
- ``iso8601-1r3n2``
- ``iso8601-2pdq6``
- ``iso8601-5gh6l``
- ``iso8601-6848a``

### Modifying an ISO 8601 Format Style

- ``locale(_:)``
- ``dateSeparator``
- ``DateSeparator``
- ``dateTimeSeparator``
- ``DateTimeSeparator``
- ``timeZone``
- ``dateTimeSeparator(_:)``

### Modifying Dates in an ISO 8601 Format Style

- ``dateSeparator(_:)``
- ``DateSeparator``
- ``year()``
- ``month()``
- ``weekOfYear()``
- ``day()``
- ``includingFractionalSeconds``

### Modifying Times in an ISO 8601 Format Style

- ``time(includingFractionalSeconds:)``
- ``timeSeparator``
- ``timeSeparator(_:)``
- ``TimeSeparator``
- ``timeZone(separator:)``
- ``timeZoneSeparator``
- ``TimeZoneSeparator``
- ``timeZoneSeparator(_:)``

### Parsing an ISO 8601 Format Style

- ``parse(_:)``
- ``parseStrategy``

### Applying an ISO 8601 Format Style

- ``format(_:)``

### Comparing ISO 8601 Format Styles

- ``!=(_:_:)``
- ``==(_:_:)``

### Coding and decoding

- ``init(from:)``
- ``encode(to:)``

### Hashing

- ``hash(into:)``


