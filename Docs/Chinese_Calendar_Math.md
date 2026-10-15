# How the Chinese calendar math works

A guide to the astronomy behind `_CalendarAstronomy` and the rules in `Calendar_Chinese.swift`. Everything here comes from published formulas; the sources are listed at the end.

## Why there is astronomy at all

Most calendars are arithmetic: you can compute any date with integer arithmetic on a fixed pattern of month lengths and leap rules. The Chinese calendar is not. Its months and its leap months are defined by two real astronomical events:

- A month begins on the day of a **new moon** (the instant the moon and sun share the same celestial longitude).
- The year is anchored to the **winter solstice**, and whether a year has a leap month depends on how the new moons fall relative to the sun's position.

So to produce a Chinese date you have to know when new moons happen and where the sun is, to the accuracy of a day. That is what the astronomy layer computes.

Two practical notes before the math:

- For Gregorian years 1901 through 2100 we do not run any of this at runtime. That range is a baked table of packed month lengths, so a date lookup is an array index and a bit extraction. The astronomy runs only outside that range.
- The astronomy is calendar-agnostic. It answers "when is the next new moon" and "what is the sun's longitude", with no Chinese-specific logic. The Chinese rules sit on top.

## How time is represented

Everything is a **moment**: a `Double` counting days since the same epoch as `rataDie` day numbers, where day 1 is January 1 of year 1 CE in the proleptic Gregorian calendar. The integer part is the day, the fraction is the time within it. So `730120.5` is noon on a particular day, and moments can be compared and subtracted directly.

Integer `rataDie` values are plain day indices with no time zone attached.

## Two time scales, and why the code converts between them

This is the part that needs explaining, because it is the one piece of the astronomy that is not obvious from the formulas.

Astronomical theory is written in **dynamical time**, a uniform time scale where a second is always the same length. It is what the equations of motion need.

Civil time is **universal time**, which is tied to the Earth's rotation. The Earth is not a perfect clock: its rotation is gradually slowing and it wobbles unpredictably, so a day is not exactly 86,400 uniform seconds and the discrepancy accumulates.

The difference between the two scales is called **delta-T**. It is not derivable from theory; it is measured from historical observations and extrapolated. It is small today (tens of seconds) but large in the distant past (hours, millennia ago).

That gives the two conversions in the code:

- `ephemerisCorrection(moment)` returns delta-T as a fraction of a day, using the Espenak and Meeus polynomial expressions published by NASA Goddard. Which polynomial applies depends on the era, so the function is a series of ranges.
- `julianCenturies(moment)` converts a universal-time moment into the dynamical-time argument the series expect, measured in Julian centuries from J2000: `(moment + delta-T - j2000) / 36525`.
- `universalFromDynamical(dynamical)` goes the other way, subtracting delta-T, and is applied to the raw result of the new-moon series so callers get a universal-time answer.

The practical effect: every astronomical result is computed in dynamical time and handed back in universal time, so the rest of the calendar never has to think about the distinction. Skipping this step would put events tens of seconds off today and hours off in antiquity, which is enough to move a date across a day boundary.

## Where the sun is: solar longitude

`solarLongitude(at:)` returns the sun's apparent longitude in degrees, 0 to 360. It is a periodic series of 49 terms (Bretagnon and Simon, as presented by Reingold and Dershowitz):

```
lambda = sum over 49 terms of  coefficient * sin(addend + multiplier * c)
```

where `c` is the time in Julian centuries. Each term is a stored triple `(coefficient, addend, multiplier)`. The sum is scaled, then a linear mean-longitude term (`282.7771834 + 36000.76953744 * c`) is added, and finally two small corrections:

- **aberration**, the apparent shift in the sun's position caused by the Earth's own motion (light takes time to arrive, so we see the sun slightly displaced along our direction of travel).
- **nutation**, a small periodic wobble of the Earth's rotation axis, mostly driven by the moon.

The result is reduced into 0 to 360 degrees. Longitude is the useful output because the Chinese rules care about specific solar longitudes: 270 degrees is the winter solstice, and every 30-degree step marks a solar term.

## When the moon is new

`nthNewMoon(n)` returns the moment of the nth new moon, counting from a fixed reference lunation. It follows Meeus:

1. Start with a **mean** estimate. New moons repeat on average every `meanSynodicMonth = 29.530588861` days, so a low-order polynomial in the lunation number gives a first approximation.
2. Add **corrections**, because the real moon is not uniform: its orbit is elliptical and perturbed by the sun. This is a 24-term periodic series in three arguments (the sun's mean anomaly, the moon's mean anomaly, and the moon's argument of latitude), plus 13 further small terms and one extra correction. The 24-term series is also scaled by powers of the orbital eccentricity.
3. Convert the result from dynamical to universal time.

Two helpers wrap it:

- `numberOfNewMoonAtOrAfter(moment)` estimates the lunation number by dividing by the mean synodic month, then steps up or down until it is exactly the first new moon at or after the given moment. The stepping is needed because the mean estimate can be off by one near a boundary.
- `newMoonAtOrAfter` and `newMoonBefore` return the moment itself.

## From a moment to a day

The astronomy returns moments in universal time. The Chinese calendar needs to know which *day* an event fell on, which means choosing where a day starts.

The Chinese calendar reckons this at a fixed **UTC+8** offset, with no daylight saving and no historical time-zone changes. Two small functions do the conversion:

- `chineseMidnight(rataDie)` gives the universal-time moment of that day's midnight at UTC+8.
- `chineseLocalDay(moment)` gives the day containing a moment, as `floor(moment + 8/24)`.

This fixed offset is what decides which day a new moon falls on, and therefore where months begin. It is deliberately unrelated to the calendar's own `timeZone`, which is applied separately when mapping a `Date` to a day. That means the month structure is identical for every caller: a user anywhere in the world sees the same Chinese months, because they are defined by when new moons occur in China.

## The calendar rules built on top

With "where is the sun" and "when is the new moon" available, the Chinese rules are short.

**Winter solstice.** `chineseWinterSolstice(year)` scans forward from around December 10 for the first day whose UTC+8 midnight has solar longitude at or past 270 degrees. That day anchors the year.

**Major solar terms.** The ecliptic is divided into twelve 30-degree sectors. `chineseMajorSolarTerm(day)` reports which sector the sun is in, as `floor(longitude / 30)` mapped into 1 to 12. A month "contains a major solar term" if the sun crosses into a new sector during it.

**New Year.** `chineseNewYear(year)` takes the solstice before and the solstice after, finds the new moons around them, and counts the months in between. If that span holds 12 months, New Year is the second new moon after the earlier solstice. If it holds 13, the year contains a leap month, and which new moon starts the year depends on whether the candidate months contain a major solar term.

**The leap month.** In a 13-month year, the leap month is the first month that contains **no** major solar term. That is what `chineseHasNoMajorSolarTerm` tests: it compares the solar term at a month's start with the term at the next month's start, and if they are the same the sun never crossed a sector boundary during that month. A leap month does not get its own number; it repeats the preceding month's number and is flagged as leap. This is the `leapMonthNumber` field, and why `isLeapMonth` exists in `DateComponents`.

**Assembling a year.** For a year outside the baked table, `year(relatedISOYear:)` finds this year's New Year and the next one, walks the new moons between them to get each month's first day, records each month as 29 or 30 days in a bitmask, and marks the leap month if there is one.

## Precision

All of this runs in `Double`. Two questions come up.

**Is `Double` accurate enough to pick the right day?** Yes, with a wide margin. We compared the `Double` implementation of the new-moon series against the same formulas evaluated in roughly 32-digit arithmetic, over 100,000 lunations spanning about 8,000 years. The largest accumulated difference was about **80 microseconds**. For that to change which day an event falls on, a new moon would have to land within 80 microseconds of midnight; the closest approach in that whole span was about **1.3 seconds**, which is roughly 15,000 times larger. Independently, the baked table for 1901 to 2100 was generated by this code and agrees with the reference tables across the whole range, so the accumulated error demonstrably flips no real day assignments.

**Would a decimal type be better?** No. The series are built on sine and cosine, which decimal types do not provide, so the trigonometry would have to run in binary floating point regardless. More importantly, there is no higher-precision answer to converge on: the published series are themselves empirical fits with a stated accuracy, and delta-T in the distant past is an extrapolation with uncertainty measured in minutes. Model uncertainty dominates arithmetic precision by orders of magnitude.

**What the astronomy cannot promise.** Far from the present the series degrade, because they are fits over a bounded interval and delta-T becomes guesswork. Results thousands of years out are self-consistent and reproducible, but they are not a claim about what observers would have recorded.

## Sources

All published, no proprietary material:

- Edward M. Reingold and Nachum Dershowitz, *Calendrical Calculations*. The overall structure of the solar and lunar routines and the Chinese calendar rules follow this presentation.
- Jean Meeus, *Astronomical Algorithms*. The new-moon periodic-term series.
- Pierre Bretagnon and Jean-Louis Simon, *Planetary Programs and Tables*. The 49-term solar longitude series.
- Fred Espenak and Jean Meeus, delta-T polynomial expressions, published by NASA Goddard Space Flight Center.
