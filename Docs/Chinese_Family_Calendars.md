# How the Chinese family calendars work

A guide to the three calendars that share `_CalendarChinese` in `Calendar_Chinese.swift`: Chinese, Dangi and Vietnamese. Read `Chinese_Calendar_Math.md` first. It explains the astronomy that all three use. This guide explains what differs between them.

## One class, three variants

Dangi (Korean) and Vietnamese are lunisolar calendars with the same structure as the Chinese calendar. A month starts on the day of a new moon. The year is tied to the winter solstice. A leap month keeps the calendar in step with the sun.

They differ in one physical way: the time zone that decides on which day a new moon falls. A new moon is one moment in universal time. A moment that is 23:30 in one time zone is already the next day in a time zone one hour ahead. When a new moon or a solar term falls within one hour of midnight, the two calendars put it on different days. The month then starts on a different day, and in some years the leap month moves.

`ChineseCalendarVariant` is an enum with three cases: `chinese`, `dangi` and `vietnamese`. The class stores one value and chooses it from the identifier. The variant supplies three things:

* the day boundary, as an offset from universal time
* the baked table for 1901 to 2100
* the number that `.yearForWeekOfYear` reports

Chinese reaches `_CalendarChinese` through `foundation_swift_calendar_feature_enabled()`. Dangi, and Vietnamese in the framework build only, reach it through `foundation_swift_additional_calendars_feature_enabled()`. That flag is off in the framework build for now. The package ICU does not have a Vietnamese calendar.

## The day boundary

| Calendar | Offset from universal time |
|---|---|
| Chinese | UTC+8, always |
| Dangi | UTC+8 before 1897, UTC+7 in 1897, UTC+8 from 1898 to 1911, UTC+9 from 1912 |
| Vietnamese | UTC+8 before 1968, UTC+7 from 1968 |

The code counts 365 days for each year since 1970 and ignores leap days, so each change falls after the start of the listed year. The changes are at local midnight of the earlier offset, on 1897-01-18, 1898-01-18 and 1912-01-16 for Dangi and 1968-01-02 for Vietnamese. This is a choice in the code, and it keeps the months the same as the ICU based calendar. The offset does not depend on the `timeZone` of the `Calendar`. The `timeZone` only maps a `Date` to a day. The months are the same for every caller.

All the astronomy functions in `Calendar_Chinese.swift` take the variant and use its offset in `utcOffsetHours(atMoment:)`.

## The tables

For Gregorian years 1901 to 2100, each variant has its own table of 200 entries. Each entry is a `UInt32` that packs one year:

* bits 0 to 12: the month lengths, one bit for each month, set for a 30 day month
* bits 13 to 16: the number of the leap month, or 0 if the year has none
* bits 17 to 22: the offset of the New Year from 19 January

A lookup is one array read and a few bit operations. Each table is 800 bytes.

Outside 1901 to 2100, the code computes the months from the astronomy with the variant's offset. The years next to the tables use the New Year of the table, so the computed years and the baked years join without a gap.

The tables are generated data. A program finds the first day of every month from 1901 to 2100, then packs the result. The month starts in the three tables equal those of the ICU based calendar for every day in the range, with these differences. The ICU based calendar numbers one day "day 0" on Dangi 2097-01-13 and on Vietnamese 2054-05-07, 2077-11-15 and 2085-10-18, and our class has no day 0. Vietnamese 1984 differs on purpose: the class flags the second month 11 as a leap month.

## How much the tables differ

Most of each table is the same as the Chinese table. Of the 200 years:

* Dangi differs from Chinese in 83 years. The first one is 1914. The years from 1912 to 1913 happen to agree.
* Vietnamese differs from Chinese in 58 years. The first one is 1967, because the lunar year that ends in 1968 starts under UTC+8 and ends under UTC+7.

In a year that differs, at most 4 month lengths change and the New Year moves by at most one day. The years look random. A year differs only when a new moon or a solar term falls within one hour of local midnight, and no formula predicts that.

The leap month moves in 3 Dangi years (2012, 2017 and 2099) and in 2 Vietnamese years (1984 and 1987), compared with the Chinese calendar.

One year needs a note. In Vietnamese 1984 the day boundary makes the year have two months numbered 11. The class flags the second one as a leap month.

## Year numbers

All three calendars count the era and the year from the Chinese epoch, 2637 BCE. The era is the number of the 60 year cycle. The year is 1 to 60 within the cycle.

The class keeps one internal year key, the related Gregorian year plus 2637, for all three. The key is correct for the era and the year of every variant.

`.yearForWeekOfYear` is the one number that differs. The class converts the key to it and back where it reads or writes that component:

| Calendar | `.yearForWeekOfYear` |
|---|---|
| Chinese | related Gregorian year plus 2637 |
| Dangi | related Gregorian year plus 2333, the year of the Dangun epoch |
| Vietnamese | related Gregorian year plus 2637 |

## The supported years

Outside 1901 to 2100 the months come from the astronomy, not from a table. The class supports the Gregorian years from -46,999 to 46,999 and no others.

* **Why:** the astronomy first gives a month of 28 or 31 days in the year 47,240 (and in the year -51,001). In some years from 12,868 (and from -17,832) the leap month is lost.
* **Reported ranges:** `minimumRange` and `maximumRange` of `.yearForWeekOfYear` stay at the ICU limits of -5,000,000 and 5,000,000. They say which numbers the field can hold. They do not say where the astronomy is right.
* **A date past the limit:** it has no answer. `dateComponents` gives an empty `DateComponents`. `range`, `ordinality` and `dateInterval` give `nil`. An add that starts or ends there gives `nil`.
* **A date from components past the limit:** `date(from:)` gives `nil`.
* **Agreement with the ICU based calendar:** it is about 100% inside the tables, 94 to 99% until the year 2999, and falls to half by the year 6000. Beyond that both calendars are models and nobody knows the right answer.

## Adding another variant

A new variant is a new case in `ChineseCalendarVariant`. It needs a day boundary function, a baked table, and a week year offset. Pass the variant as a value to the rule functions. Do not use a closure, because the Chinese path must stay fast.
