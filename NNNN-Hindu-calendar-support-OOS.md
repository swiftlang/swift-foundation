# Expanded calendar support

* Proposal: SF-017
* Authors: [Dragan Besevic](dragan@unicode.org)
* Review Manager: Tina Liu
* Status: **Accepted**


## Revision history

* **v1** Initial version

## Introduction



This proposal is for adding expanded support for several calendars used in South Asia, lunisolar and solar calendars used in regions in India, as well as Thai, Vietnamese and Korean calendars based on the Chinese lunisolar calendar. Swift-foundation-icu repository will support these too, so users of Foundation on any platform will get these new calendars.

Some of these calendars are astronomical calendars, which means they are using true positions of sun (solar) or both sun and moon. For that reason, when specific set of events happen, the dates in these calendars can have both leap months and leap days.  

Foundation will add support for these new identifiers, and all Foundation Calendar API that takes an identifier will be extended to support them.  

## Proposed solution and example

Foundation will add constants to support the new calendar types.

Some calendars added by this proposal have a unique feature of "leap days", where two consecutive days can have the same numeric value. This new feature will have impact on APIs that search/match dates.

This property will be called isAdhikaDay, to indicate it is used in Hindu calendars which are the only calendars that has this feature. More details about the naming is provided in the section `Alternatives considered` at the end of the document.

## Detailed design


Foundation will add new string constants for new calendar identifiers for NSCalendarIdentifier.


**Calendar.swift**

```swift
  // ...
  extension Calendar.Identifier {
      // Bangla solar calendar
      @available(FoundationPreview 6.2, *)
      case bangla

      // Gujarati lunisolar calendar
      @available(FoundationPreview 6.2, *)
      case gujarati

      // Kannada lunisolar calendar
      @available(FoundationPreview 6.2, *)
      case kannada

      // Malayalam solar calendar
      @available(FoundationPreview 6.2, *)
      case malayalam

      // Marathi lunisolar calendar
      @available(FoundationPreview 6.2, *)
      case marathi

      // Odia solar calendar
      @available(FoundationPreview 6.2, *)
      case odia

      // Tamil solar calendar
      @available(FoundationPreview 6.2, *)
      case tamil

      // Telugu lunisolar calendar
      @available(FoundationPreview 6.2, *)
      case telugu

      // Vikram lunisolar calendar
      @available(FoundationPreview 6.2, *)
      case vikram

      // Thai lunisolar calendar
      @available(FoundationPreview 6.2, *)
      case thai

      // Vietnamese lunisolar calendar
      @available(FoundationPreview 6.2, *)
      case vietnamese

      // Korean lunisolar calendar
      @available(FoundationPreview 6.2, *)
      case korean
  }
```

Following are the code changes required to support new calendar property isAdhikaDay


**Calendar.swift**

```swift
// ...
public enum Component : Sendable {
  // ...
  @available(FoundationPreview 6.2, *)
  case isAdhikaDay
  // ....
}
```

## Impact on existing code

Thai, Vietnamese and Korean calendars have no special considerations.

Calendars used in India are introducing the new field for the leap day. Clients using existing calendars won't be affected by this change. For new clients that use these calendars, we will handle the newly added leap day in the following places:

**First**, it will be set to false when a new `DateComponents` object is created.

```swift
var components = DateComponents()
```

**Second**, the comparison for calendar dates will account for this field. Two dates differs if they don't have the same value for isAdhikaDay

For example, the clients may currently use following check

```swift
cal.compare(d1, d2)
```

For Hindu calendars, this would only compare equal if they're both Adhika day or if they are both not. For non-Hindu calendars, isAdhikaDay property will be ignored.

**Third**, the calendar date arithmetic will be updated to correctly calculate the dates regarding `adhikaDay`. When working with Hindu calendars, as the leap days can occur at any position, looking for next day would have to involve recalculation.

As a general rule, behavior of `isAdhikaDay` will replicate `isLeapMonth` in APIs doing matching and searching.

For example, let's explain what is the expected behavior in this API that enumerate the next date

```swift
public func nextDate(after date: Date, matching components: DateComponents, matchingPolicy: MatchingPolicy, repeatedTimePolicy: RepeatedTimePolicy = .first, direction: SearchDirection = .forward) -> Date? {
    var result: Date?
    enumerateDates(startingAfter: date, matching: components, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction) { date, exactMatch, stop in
        result = date
        stop = true
    }
    return result
}
```

Clients using this function to enumerate the next date after `date`, matching the given date components, based on the `MatchingPolicy`, would get the following behavior depending on whether `date` is a leap day or not:

* If start is on a leap day

* `strict`: If components.isAdhikaDay is true, this gives you the next date that is also a leap day that shares the same day, month, year number (i.e. all those specified with the comps argument) as start. If only a subset of `DateComponents` is specified, for example only the month, this gives you the next date which is a leap day with same month. If no arguments are given for `DateComponents`, this gives the next date that is also a leap day. If components.isAdhikaDay is false, this function gives you the next date that matches the day/month/year number but one that is not a leap day.

* If start is not on a leap day

* `strict`: If components.isAdhikaDay is true, this gives you the next date that is a leap day that shares the same day, month, year number (i.e. all those specified with the comps argument) as start but a leap day. If components.isAdhikaDay is false, this function gives you the next date that matches the day/month/year number that is not a leap day.

For the `direction` and `repeatedTimePolicy`:

* `backward`: This flag does not affect how leap day search is handled, but merely changes the search direction so that it finds the match before start rather than after start.

* `first`: If there are two or more matching dates, and all their components are the same, including isAdhikaDay, the function returns the first date.

* `last`: Similar to `first`, but the function returns the last match.


Following APIs for searching/matching/adding would follow the same logic

```swift
public func dates(byMatching components: DateComponents,
                  startingAt start: Date,
                  in range: Range<Date>? = nil,
                  matchingPolicy: MatchingPolicy = .nextTime,
                  repeatedTimePolicy: RepeatedTimePolicy = .first,
                  direction: SearchDirection = .forward) -> some (Sequence<Date> & Sendable)
public func dates(byAdding components: DateComponents,
                  startingAt start: Date,
                  in range: Range<Date>? = nil,
                  wrappingComponents: Bool = false) -> some (Sequence<Date> & Sendable)
```

## Alternatives considered

As mentioned before, the leap day is a unique feature of some of new calendars. It appears when a certain astronomical position of Sun and Moon happens which means it can appear on any date. That differs from Gregorian leap day of February 29th, which happens every four years (approximately) and it is always on the same day.

This property will be called isAdhikaDay to clearly indicate it is related to Hindu lunisolar calendars. The alternative was to call it isLeapDay, but that may lead to confusion with Gregorian calendar

Another point of discussion was whether to use Bengali vs Bangla and Oriya vs Odia. There has been an effort to stop using the older colloquial names Bengali and Oriya and to switch to the now-accepted names Bangla and Odia. While most of the attention has gone to the language names, the same naming should also be used for the calendar names, despite them receiving less attention.
