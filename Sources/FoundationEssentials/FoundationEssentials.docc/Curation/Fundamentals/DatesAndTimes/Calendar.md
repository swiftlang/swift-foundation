# ``/FoundationEssentials/Calendar``


## Topics


### Creating a calendar

- ``init(identifier:)``
- ``init(identifier:timeZone:locale:firstWeekday:minimumDaysInFirstWeek:)``
- ``Identifier``

### Getting the current calendar

- ``autoupdatingCurrent``
- ``current``

### Extracting components

- ``date(_:matchesComponents:)``
- ``component(_:from:)``
- ``dateComponents(_:from:)``
- ``dateComponents(_:from:to:)-(_,Date,_)``                                                     <!-- func dateComponents(_ components: Set<Calendar.Component>, from start: Date, to end: Date) -> DateComponents -->
- ``dateComponents(_:from:to:)-(_,DateComponents,_)``                                           <!-- func dateComponents(_ components: Set<Calendar.Component>, from start: DateComponents, to end: DateComponents) -> DateComponents -->
- ``dateComponents(in:from:)``
- ``Component``

### Getting calendar information

- ``identifier``
- ``locale``
- ``firstWeekday``
- ``minimumDaysInFirstWeek``
- ``timeZone``
- ``maximumRange(of:)``
- ``minimumRange(of:)``
- ``ordinality(of:in:for:)``
- ``range(of:in:for:)``

### Scanning dates

- ``startOfDay(for:)``
- ``enumerateDates(startingAfter:matching:matchingPolicy:repeatedTimePolicy:direction:using:)``
- ``nextDate(after:matching:matchingPolicy:repeatedTimePolicy:direction:)``

### Calculating dates from components

- ``date(from:)``
- ``date(byAdding:to:wrappingComponents:)``
- ``date(byAdding:value:to:wrappingComponents:)``
- ``date(bySetting:value:of:)``
- ``date(bySettingHour:minute:second:of:matchingPolicy:repeatedTimePolicy:direction:)``

### Calculating intervals

- ``dateInterval(of:for:)``
- ``dateInterval(of:start:interval:for:)``
- ``dateIntervalOfWeekend(containing:)``
- ``dateIntervalOfWeekend(containing:start:interval:)``
- ``nextWeekend(startingAfter:direction:)``
- ``nextWeekend(startingAfter:start:interval:direction:)``

### Calculating date sequences

- ``dates(byAdding:startingAt:in:wrappingComponents:)``
- ``dates(byAdding:value:startingAt:in:wrappingComponents:)``
- ``dates(byMatching:startingAt:in:matchingPolicy:repeatedTimePolicy:direction:)``


### Comparing dates

- ``compare(_:to:toGranularity:)``
- ``isDate(_:equalTo:toGranularity:)``
- ``isDate(_:inSameDayAs:)``
- ``isDateInToday(_:)``
- ``isDateInTomorrow(_:)``
- ``isDateInYesterday(_:)``
- ``isDateInWeekend(_:)``

### Comparing calendars

- ``==(_:_:)``

### Hashing

- ``hash(into:)``


### Supporting types

- ``MatchingPolicy``
- ``RepeatedTimePolicy``
- ``RecurrenceRule``
- ``SearchDirection``

