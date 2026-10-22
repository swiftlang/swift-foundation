# How the Chinese family calendars work

A guide to three calendars with the same rules: Chinese, Dangi and Vietnamese. Read `Chinese_Calendar_Math.md` first. It explains the astronomy that all three use. This guide explains what differs between them.

## Three calendars, one set of rules

Dangi (Korean) and Vietnamese are lunisolar calendars with the same structure as the Chinese calendar. A month starts on the day of a new moon. The year is tied to the winter solstice. A leap month keeps the calendar in step with the sun.

They differ in one physical way: the time zone that decides on which day a new moon falls. A new moon is one moment in universal time. A moment that is 23:30 in one time zone is already the next day in a time zone one hour ahead. When a new moon or a solar term falls within one hour of midnight, the two calendars put it on different days. The month then starts on a different day, and in some years the leap month moves.

They also number the year differently in `.yearForWeekOfYear` (see below).

## The day boundary

| Calendar | Offset from universal time |
|---|---|
| Chinese | UTC+8, always |
| Dangi | UTC+8 before 1897, UTC+7 in 1897, UTC+8 from 1898 to 1911, UTC+9 from 1912 |
| Vietnamese | UTC+8 before 1968, UTC+7 from 1968 |

The changes take effect on 1897-01-18, 1898-01-18 and 1912-01-16 for Dangi and on 1968-01-02 for Vietnamese, the same days as in the ICU based calendar. The months do not depend on the time zone of the user. The time zone only decides which day a moment falls on.

## The years 1901 to 2100

For these years each calendar has a table of its months. A program found the first day of every month from 1901 to 2100. The month starts equal those of the ICU based calendar for every day in the range, with these differences. The ICU based calendar numbers one day "day 0" on Dangi 2097-01-13 and on Vietnamese 2054-05-07, 2077-11-15 and 2085-10-18, and there is no day 0 here. Vietnamese 1984 differs on purpose: the second month 11 is the leap month.

Outside 1901 to 2100, the months come from the astronomy, with the day boundary of each calendar. The years next to the tables use the New Year of the table, so the computed years and the table years join without a gap.

## How much the tables differ

Most of each table is the same as the Chinese table. Of the 200 years:

* Dangi differs from Chinese in 83 years. The first one is 1914. The years from 1912 to 1913 happen to agree.
* Vietnamese differs from Chinese in 58 years. The first one is 1967, because the lunar year that ends in 1968 starts under UTC+8 and ends under UTC+7.

In a year that differs, at most 4 month lengths change and the New Year moves by at most one day. The years look random. A year differs only when a new moon or a solar term falls within one hour of local midnight, and no formula predicts that.

The leap month moves in 3 Dangi years (2012, 2017 and 2099) and in 2 Vietnamese years (1984 and 1987), compared with the Chinese calendar.

One year needs a note. In Vietnamese 1984 the day boundary makes the year have two months numbered 11. The second one is the leap month.

## Year numbers

All three calendars count the era and the year from the Chinese epoch, 2637 BCE. The era is the number of the 60 year cycle. The year is 1 to 60 within the cycle.

`.yearForWeekOfYear` is the one number that differs:

| Calendar | `.yearForWeekOfYear` |
|---|---|
| Chinese | related Gregorian year plus 2637 |
| Dangi | related Gregorian year plus 2333, the year of the Dangun epoch |
| Vietnamese | related Gregorian year plus 2637 |

## How far the astronomy goes

The months outside the tables are computed for the Gregorian years -46,999 to 46,999. A date further out has no fields.

Agreement with the ICU based calendar is about 100% inside the tables, 94 to 99% of the months until the year 2999, and about half by the year 6000. Further out both calendars are models, and nobody knows the right answer.
