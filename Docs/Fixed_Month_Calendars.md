# How the fixed month calendars work

A guide to the arithmetic of eight calendars: Coptic, Ethiopic Amete Mihret, Ethiopic Amete Alem, Persian, Indian, and the Islamic civil, tabular and Umm al-Qura calendars.

## What "fixed month" means

Each of these calendars has a fixed number of months in every year. Each month has a known length, and at most one month changes length in a leap year. A date comes from a formula. Umm al-Qura also uses a table of months. There is no astronomy.

This is the opposite of the Chinese calendar. Read `Chinese_Calendar_Math.md` and `Chinese_Family_Calendars.md` for that group.

## The rules

A **rata die** is a count of days. Day 1 is 0001-01-01 in the proleptic Gregorian calendar. The **extended year** counts years in one run across all eras. The arithmetic below works on the extended year.

| | Coptic and Ethiopic (3 calendars) | Persian | Indian | Islamic (3 calendars) |
|---|---|---|---|---|
| Months | 13 | 12 | 12 | 12 |
| Month lengths | Months 1 to 12 have 30 days. Month 13 has 5 days, or 6 in a leap year | Months 1 to 6 have 31 days. Months 7 to 11 have 30. Month 12 has 29 days, or 30 in a leap year | Month 1 has 30 days, or 31 in a leap year. Months 2 to 6 have 31. Months 7 to 12 have 30 | The odd months have 30 days and the even months have 29. Month 12 has 30 days in a leap year |
| Leap year | Every fourth year | 8 leap years in every 33, with corrections after year 1502 | The Gregorian year 78 years later is a leap year | 11 leap years in every 30 |
| Year 1 starts on | See below | Gregorian 21 March 622 | Gregorian 22 March 79 | Gregorian 19 July 622, or 18 July 622 for tabular |

The three Coptic and Ethiopic calendars use the same rules. They differ in where year 1 starts and in how they count eras:

* **Coptic:** year 1 starts on 29 August 284 in the Julian calendar. Era 1 counts forward. Era 0 counts backward from the year before year 1.
* **Amete Mihret:** year 1 starts on 29 August 8 in the Julian calendar. Era 1 is Amete Mihret. Years before it belong to era 0, which is Amete Alem.
* **Amete Alem:** year 1 is 5500 years before Amete Mihret year 1, so Amete Mihret year 1 is Amete Alem year 5501. It has one era.

## From a date to a day number

The start of a year is a formula:

* Coptic and Ethiopic: a fixed start, plus 365 days for each year, plus one day for each fourth year.
* Persian: the 33 year cycle, which adds the whole part of (8 × year + 21) / 33 leap days, then the correction below.
* Indian: 22 March of the Gregorian year `year + 78`, or 21 March if that year is a leap year.
* Islamic: 354 days for each year, plus the whole part of (11 × year + 3) / 30 leap days.

The day number is the start of the year, plus the days of the months before, plus the day.

## From a day number to a date

The way back:

* **Coptic and Ethiopic:** four years make a cycle of 1461 days. The last year in a cycle is the long one. Division gives the cycle, the year in the cycle, the month and the day.
* **Persian:** the average length of 33 years (12,053 days) gives the year. Near a year start it can be one year off, so it is checked against the start of the year and moved up or down.
* **Indian:** the year is the Gregorian year minus 78, moved down by one if the date is before the start of that year. A subtraction then gives the month and the day.
* **Islamic:** the average length of 30 years (10,631 days) gives the year, which is checked and moved as for Persian. The months of 30 and 29 days in turn give the month and the day. In an Umm al-Qura table year, the month lengths of the table give them.

## The Persian correction table

The 33 year rule is an approximation. The official calendar of Iran starts the year on the day of the March equinox in Tehran. The rule drifts away from the equinox slowly.

A table of 78 years, from 1502 to 2987, moves the start of some years by one day. For each year in the table, that year is not a leap year, and the next year is one. So the next year starts one day earlier. The first change is Persian year 1503, which starts on 20 March 2124 and not on 21 March.

## The Islamic calendars

The civil and tabular calendars use the same 30 year cycle. In each cycle, the years 2, 5, 7, 10, 13, 16, 18, 21, 24, 26 and 29 are leap years. The tabular calendar starts one day earlier, so the same year, month and day is one day earlier.

Umm al-Qura is the calendar of Saudi Arabia. For the years 1300 to 1600 AH, a table gives the length of each month and the start of each year. The values come from the ICU table. In these years, a month has 29 or 30 days with no fixed pattern. Outside these years, Umm al-Qura uses the civil rules.

## Eras and quarters

* **Era and year:** each era and year names one extended year. Persian, Indian, Amete Alem and the Islamic calendars have one era. Their years can go below 1 without a change of era, except for Amete Alem.
* **Quarters:** the fourth quarter takes the thirteenth month of the Coptic and Ethiopic calendars.
* **Era start:** era 1 of Coptic and Amete Mihret, and the one era of Amete Alem, Persian, Indian and the Islamic calendars, start on day 1 of year 1. Era 0 of Coptic and Amete Mihret ends where era 1 starts. For Persian, Indian and the Islamic calendars, the years before year 1 belong to no era interval.
