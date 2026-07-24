# ``/FoundationEssentials/Date``

<!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->

## Topics



### Creating a date

- ``init()``
- ``init(timeIntervalSinceNow:)``
- ``init(timeInterval:since:)``
- ``init(timeIntervalSinceReferenceDate:)``
- ``init(timeIntervalSince1970:)``
- ``init(_:strategy:)-(T.ParseInput,_)``    <!-- init<T>(_ value: T.ParseInput, strategy: T) throws where T : ParseStrategy, T.ParseOutput == Date -->
- ``init(_:strategy:)-(Value,_)``           <!-- init<T, Value>(_ value: Value, strategy: T) throws where T : ParseStrategy, Value : StringProtocol, T.ParseInput == String, T.ParseOutput == Date -->
- ``ParseStrategy``

### Retrieving the current date

- ``now``

### Getting temporal boundaries

- ``distantFuture``
- ``distantPast``

### Comparing dates

- ``==(_:_:)``
- ``!=(_:_:)``
- ``>(_:_:)``
- ``>=(_:_:)``
- ``<(_:_:)``
- ``<=(_:_:)``
- ``compare(_:)``
- ``distance(to:)``

### Getting time intervals

- ``timeIntervalSince(_:)``
- ``timeIntervalSinceNow``
- ``timeIntervalSinceReferenceDate-property``
- ``timeIntervalSince1970``
- ``timeIntervalSinceReferenceDate-type.property``
- ``timeIntervalBetween1970AndReferenceDate``
- ``Stride``

### Adding or subtracting a time interval

- ``addTimeInterval(_:)``
- ``addingTimeInterval(_:)``
- ``advanced(by:)``
- ``+(_:_:)``
- ``+=(_:_:)``
- ``-(_:_:)``
- ``-=(_:_:)``

### Formatting a date

- ``formatted(_:)``
- ``FormatStyle``
- ``ISO8601Format(_:)``
- ``ISO8601FormatStyle``

### Creating date ranges

- ``...(_:_:)``
- ``..<(_:)``
- ``..<(_:_:)``

### Encoding dates

- ``encode(to:)``

### Describing dates

- ``description``
- ``description(with:)``

### Hashing

- ``hash(into:)``

### Supporting types

- ``HTTPFormatStyle``




