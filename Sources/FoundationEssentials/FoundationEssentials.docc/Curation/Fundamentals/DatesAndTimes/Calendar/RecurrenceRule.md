# ``/FoundationEssentials/Calendar/RecurrenceRule``

<!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->

## Topics

### Creating a recurrence rule

- ``init(calendar:frequency:interval:end:matchingPolicy:repeatedTimePolicy:months:daysOfTheYear:daysOfTheMonth:weeks:weekdays:hours:minutes:seconds:setPositions:)``

### Working with recurrence rule properties 

- ``calendar``
- ``frequency``
- ``interval``
- ``end``
- ``matchingPolicy``
- ``repeatedTimePolicy``
- ``setPositions``

### Working with recurrence rule date components
- ``daysOfTheMonth``
- ``daysOfTheYear``
- ``hours``
- ``weekdays``
- ``weeks``
- ``seconds``
- ``minutes``
- ``months``


### Finding common recurrences

- ``yearly(calendar:interval:end:matchingPolicy:repeatedTimePolicy:months:daysOfTheYear:daysOfTheMonth:weeks:weekdays:hours:minutes:seconds:setPositions:)``
- ``monthly(calendar:interval:end:matchingPolicy:repeatedTimePolicy:months:daysOfTheMonth:weekdays:hours:minutes:seconds:setPositions:)``
- ``weekly(calendar:interval:end:matchingPolicy:repeatedTimePolicy:months:weekdays:hours:minutes:seconds:setPositions:)``
- ``daily(calendar:interval:end:matchingPolicy:repeatedTimePolicy:months:daysOfTheMonth:weekdays:hours:minutes:seconds:setPositions:)``
- ``hourly(calendar:interval:end:matchingPolicy:repeatedTimePolicy:months:daysOfTheYear:daysOfTheMonth:weekdays:hours:minutes:seconds:setPositions:)``
- ``minutely(calendar:interval:end:matchingPolicy:repeatedTimePolicy:months:daysOfTheYear:daysOfTheMonth:weekdays:hours:minutes:seconds:setPositions:)``


### Finding general recurrences

- ``recurrences(of:in:)-(_,Range<Date>?)``              <!-- func recurrences(of start: Date, in range: Range<Date>? = nil) -> some Sendable & Sequence<Date> -->
- ``recurrences(of:in:)-(_,PartialRangeThrough<Date>)`` <!-- func recurrences(of start: Date, in range: PartialRangeThrough<Date>) -> some Sendable & Sequence<Date> -->
- ``recurrences(of:in:)-(_,PartialRangeFrom<Date>)``    <!-- func recurrences(of start: Date, in range: PartialRangeFrom<Date>) -> some Sendable & Sequence<Date> -->
- ``recurrences(of:in:)-(_,PartialRangeUpTo<Date>)``    <!-- func recurrences(of start: Date, in range: PartialRangeUpTo<Date>) -> some Sendable & Sequence<Date> -->
- ``recurrences(of:in:)-(_,ClosedRange<Date>)``         <!-- func recurrences(of start: Date, in range: ClosedRange<Date>) -> some Sendable & Sequence<Date> -->

### Supporting types

- ``Frequency``
- ``End``
- ``Weekday``
- ``Month``
