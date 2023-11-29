# Date Interval Differences

* Proposal: [FOU-0002](0002-date-interval-differences.md)
* Authors: [Kiel Gillard](https://github.com/kielgillard)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [apple/swift-foundation#330](https://github.com/apple/swift-foundation/pull/330)
* Review: ([pitch](https://forums.swift.org/...))

## Introduction

Add small but convenient, quality-assured methods on `DateInterval` for computing time and date intervals between other date intervals.

## Motivation

`DateInterval` could offer more APIs to help developers work with ranges of absolute moments in time. For example, a developer might be building a log book, shift planner, time tracker or implementing a time based feature in a less specialised app. In the more complex cases, an app may require users to enter start and end times for particular activities, arrange them in a particular sequence with some acceptable gap between (e.g. work here for 2 hours, work there for 1.5 hours and rest for 10 minutes with at most five minutes between, no overlaps, etc). This app would need to validate the intervals formed by the dates entered by at least: checking the intersections of intervals, measuring how much those intervals intersect by and/or by measuring the time between them. In the case of a simpler feature, displaying the time until or since an event, with different formatting or app behaviour on either side (e.g. a library book due/overdue).

`DateInterval` would be an intuitive type to begin such implementations with. However, developers would quickly hit a limit with its out-of-the-box utility and become responsible for providing what is missing. Further, the precedent set by other Foundation types have shaped our intuitions about what utility we could expect of it.

## Proposed solution

I would like to propose a set of small but delightful, quality-assured additions to `DateInterval` for computing the time or date interval between two, potentially non-intersecting date intervals: `timeIntervalSince(_:)`, `dateIntervalSince(_:)`. I would propose two overloads for these APIs: one taking `DateInterval` values and another taking `Date` values.

Should a developer find themselves needing to compute these values, the proposed additions should feel intuitive because they bear a family resemblance to existing `Date` APIs (e.g.: `timeIntervalSince(_:)`). These additions build on and complement existing intersection and comparision APIs. By easily indicating if two intervals intersect for a moment at opposing ends, developers can more easily determine special cases of intersection. By indicating if one interval is exclusively relative to another in the past or the future, the comparison offering is enriched. The names for these computations are expressive, promoting clarity and readability, especially when developers may be tempted to settle for terse expressions. With the quality of these APIs assured; the convenience saving developers the cognitive load implementing, naming, testing and maintaining these computations and; the presence of these small additions that congeal with intuitions about Foundation types; I would propose these additions are delightful.

## Detailed design

Consider two date intervals `A` and `B` demarcating ascending moments on this first timeline:
```
1. |--A--| <-- time interval --> |--B--|
```
For the `timeIntervalSince(_:)` APIs, the time interval of `B` since `A` will be zero or positive because `B` demarcates a range of moments later than the range of moments demarcated by `A`. The time interval of `A` since `B` will be zero or negative because the range of moments the range of moments demarcated by `A` are earlier than those demarcated by `B`.

For the `dateIntervalSince(_:)` APIs, the date interval of `B` since `A` will be the same as the date interval of `A` since `B` because `DateInterval` is designed to represent positive intervals only. The time between the earliest end and latest start becomes the duration and the earliest end becomes the start of the resulting `DateInterval`.

Next, consider two date intervals `C` and `D` demarcating moments on a second timeline:
```
2. |--C--|--D--|
```
The time or date intervals since `C` and `D` and vice-versa are zero because `C` ends when `D` begins. With this, developers can test that two date intervals form a seamless, continuous range of moments.

Finally, consider two thoroughly intersecting date intervals demarcating these moments on a third timeline:
```
3. |--|—-—-|--|
```
In this case, the time or date intervals since either date interval does not exist, so the APIs shall return `nil`.

## Source compatibility

The proposed changes are additive and no significant impact on existing code is expected.

## Implications on adoption

These additions can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility.

## Future directions

`DateInterval` could gain more API inspired by operations in set theory. I would expect these proposed additions can be subsumed and compatible with such a direction.

## Alternatives considered

An alternative could be to “do nothing”. A motivation for this could be that the additions are “too small”. One problem with this is it would be too permissive, applicable to many existing APIs and discouraging new ones. For example, developers can subtract two time intervals easily enough, so `Date.timeIntervalSince(_:)` is (so the argument permits) regrettable. Another problem with this motivation is that it misses the other merits of readability, convenience etc. 

Another motivation for “doing nothing” could be that it does not seem to solve some “third party date interval redundancy epidemic” within the broader community. One problem with this could be “survivorship bias”: do we really know the computations these additions provide are not solving a more common pain point for developers? Another problem would be that such a high bar for inclusion discourages the community from contributing their small conveniences that in sum make Foundation as a whole convenient, freeing developers to focus on building features rather than algorithms.

## Acknowledgments
