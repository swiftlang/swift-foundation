# How the fixed month calendars work

A guide to `_CalendarFixedMonth` and `FixedMonthArithmetic` in `Calendar_FixedMonth.swift`. It covers five calendars: Coptic, Ethiopic Amete Mihret, Ethiopic Amete Alem, Persian and Indian.

## What "fixed month" means

Each of these calendars has a fixed number of months in every year. Each month has a known length, and at most one month changes length in a leap year. A date comes from a formula. There is no astronomy, no table of months and no search.

This is the opposite of the Chinese calendar. Read `Chinese_Calendar_Math.md` and `Chinese_Family_Calendars.md` for that group.

## One class, one enum

* `_CalendarFixedMonth` is the class. It implements `_CalendarProtocol`, like `_CalendarHebrew`. It does the work that all five calendars share: `dateComponents`, `date(from:)`, add and roll, intervals, ranges and week fields. It has no `nextDate`, so `Calendar` uses its generic search for dates that match components.
* `FixedMonthArithmetic` is an enum with one case for each calendar. It holds only the numbers that differ: month lengths, leap years, where a year starts, and how a day number becomes a year, a month and a day.
* The class stores one value of the enum. It chooses the case from the calendar identifier when it is created.

A new calendar of this kind adds one case to the enum and one branch to each `switch`. It does not need a new class. The compiler checks that every `switch` handles every case. The identifier also needs a `case` in `_calendarClass` in `Calendar_Cache.swift`, which sends it to the class.

The routing is behind `foundation_swift_additional_calendars_feature_enabled()`. This flag is separate from the flag of the other Swift calendars. In the package build it is on. In the framework build it is off for now, so all five calendars use ICU there. Amete Alem has a `case` in the framework build only. The package ICU does not have that calendar, so its formatted text would not match the fields of the Swift calendar.

## The rules

A **rata die** is a count of days. Day 1 is 0001-01-01 in the proleptic Gregorian calendar. The **extended year** counts years in one run across all eras. Every function in the enum works on the extended year.

| | Coptic and Ethiopic (3 calendars) | Persian | Indian |
|---|---|---|---|
| Months | 13 | 12 | 12 |
| Month lengths | Months 1 to 12 have 30 days. Month 13 has 5 days, or 6 in a leap year | Months 1 to 6 have 31 days. Months 7 to 11 have 30. Month 12 has 29 days, or 30 in a leap year | Month 1 has 30 days, or 31 in a leap year. Months 2 to 6 have 31. Months 7 to 12 have 30 |
| Leap year | Every fourth year | 8 leap years in every 33, with corrections after year 1502 | The Gregorian year 78 years later is a leap year |
| Year 1 starts on | See below | Gregorian 21 March 622 | Gregorian 22 March 79 |

The three Coptic and Ethiopic calendars use the same rules. They differ in where year 1 starts and in how they count eras:

* **Coptic:** year 1 starts on 29 August 284 in the Julian calendar. Era 1 counts forward. Era 0 counts backward from the year before year 1.
* **Amete Mihret:** year 1 starts on 29 August 8 in the Julian calendar. Era 1 is Amete Mihret. Years before it belong to era 0, which is Amete Alem.
* **Amete Alem:** year 1 is 5500 years before Amete Mihret year 1, so Amete Mihret year 1 is Amete Alem year 5501. It has one era.

## From a date to a day number

The start of a year is a formula in `startOfYear(_:)`:

* Coptic and Ethiopic: a fixed start, plus 365 days for each year, plus one day for each fourth year.
* Persian: the 33 year cycle, `_CalendarUtility.floorDiv(8 * year + 21, 33)`, then the correction below.
* Indian: 22 March of the Gregorian year `year + 78`, or 21 March if that year is a leap year.

The days before a month come from `daysBeforeMonth(year:month:)`. The day number is the start of the year, plus the days before the month, plus the day.

## From a day number to a date

`fields(rataDie:)` works backward.

* **Coptic and Ethiopic:** four years make a cycle of 1461 days. The last year in a cycle is the long one. Division gives the cycle, the year in the cycle, the month and the day.
* **Persian:** the 33 year rule gives a year that can be wrong by one. The code checks it against `startOfYear` and moves it up or down.
* **Indian:** the year is the Gregorian year minus 78, moved down by one if the date is before the start of that year. A subtraction then gives the month and the day.

## The Persian correction table

The 33 year rule is an approximation. The official calendar of Iran starts the year on the day of the March equinox in Tehran. The rule drifts away from the equinox slowly.

A table of 78 years, from 1502 to 2987, moves the start of some years by one day. For each year in the table, that year is not a leap year, and the next year is one. So the next year starts one day earlier. The first change is Persian year 1503, which starts on 20 March 2124 and not on 21 March.

Years before 1502 need one comparison only. Dates in use today cost nothing extra. The table is one `static let` array of `Int16`, 156 bytes.

## Eras, quarters and limits

* **Era and year:** `eraAndYear(extendedYear:)` and `extendedYear(era:year:)` map between the two views. Persian, Indian and Amete Alem have one era. Their years can go below 1 without a change of era, except for Amete Alem.
* **Quarters:** the fourth quarter takes the thirteenth month of the Coptic and Ethiopic calendars.
* **Era intervals:** era 1 and the one era of Amete Alem, Persian and Indian run for the longest interval that Foundation allows, from day 1 of year 1. Era 0 of Coptic and Amete Mihret ends where era 1 starts. For Persian and Indian, the years before year 1 are in no era interval.
* **Limits:** inside the class a year can be as large as 5 million, but `Calendar` caps dates near year 506,000 (the date limit of Foundation). The code checks for overflow where a `DateComponents` value can be near `Int.max`.
* **Dates before 4713 BCE:** `Calendar` caps them for every calendar before the class runs.
