# ``/FoundationEssentials/DateComponents``


## Topics

### Initializing date components from units

- ``init(calendar:timeZone:era:year:month:day:hour:minute:second:nanosecond:weekday:weekdayOrdinal:quarter:weekOfMonth:weekOfYear:yearForWeekOfYear:)``

### Parsing date components

- ``init(_:strategy:)-(T.ParseInput,_)``                                                                                                                <!-- init<T>(_ value: T.ParseInput, strategy: T) throws where T : ParseStrategy, T.ParseOutput == DateComponents -->
- ``init(_:strategy:)-(Value,_)``                                                                                                                       <!-- init<T, Value>(_ value: Value, strategy: T) throws where T : ParseStrategy, Value : StringProtocol, T.ParseInput == String, T.ParseOutput == DateComponents -->

### Working with fundamental properties

- ``calendar``
- ``timeZone``

### Validating a date

- ``isValidDate``
- ``isValidDate(in:)``
- ``date``

### Working with months and years

- ``era``
- ``year``
- ``yearForWeekOfYear``
- ``quarter``
- ``month``
- ``isLeapMonth``

### Working with weeks and days

- ``weekOfMonth``
- ``weekOfYear``
- ``weekday``
- ``weekdayOrdinal``
- ``day``
- ``dayOfYear``
- ``isRepeatedDay``

### Working with hours and seconds

- ``hour``
- ``minute``
- ``second``
- ``nanosecond``

### Working with calendar components

- ``value(for:)``
- ``setValue(_:for:)``
- ``Calendar/Component``

### Formatting a date components instance

- ``formatted(_:)``


### Comparing date components

- ``!=(_:_:)``

### Supporting types

- ``HTTPFormatStyle``
- ``ISO8601FormatStyle``

### Operators

- ``==(_:_:)``

### Hashing

- ``hash(into:)``
