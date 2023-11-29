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

`DateInterval` could offer more APIs to help developers work with ranges of absolute moments in time. For example, a developer might be building a logbook, shift planner, time tracker or implementing a time based feature in a less specialised app. In the more complex cases, an app may require users to enter start and end times for particular activities, arrange them in a particular sequence with some acceptable gap between (e.g. work here for 2 hours, work there for 1.5 hours and rest for 10 minutes with at most five minutes between, no overlaps, etc). This app would need to validate the intervals formed by the dates entered by at least: checking the intersections of intervals, measuring how much those intervals intersect by and/or by measuring the time between them. In the case of a simpler feature, perhaps the duration between some moment and either the start or end of an interval should be displayed.

`DateInterval` would be an intuitive type to begin such implementations with. However, developers would quickly hit a limit with its out-of-the-box utility and become responsible for providing an implementation. Further, the precedent set by other Foundation types have shaped our intuitions about what utility we could expect of it.

## Proposed solution

I would like to propose a set of small but delightful, quality-assured additions to `DateInterval` for computing the time or date interval between two, potentially non-intersecting date intervals: `timeIntervalSince(_:)`, `dateIntervalSince(_:)`. I would propose two overloads for these APIs: one taking `DateInterval` values and another taking `Date` values.

Should a developer find themselves needing to compute these values, the proposed additions should feel intuitive because they bear a family resemblance to existing `Date` APIs (e.g.: `timeIntervalSince(_:)`). These additions build on and complement existing intersection and comparision APIs. By easily indicating if two intervals intersect for a moment at opposing ends, developers can more easily determine special cases of intersection. By indicating if one interval is exclusively relative to another in the past or the future, the comparison offering is enriched. The names for these computations are expressive, promoting clarity and readability, especially when developers may be tempted to settle for terse expressions. With the quality of these APIs assured; the convenience saving developers the cognitive load implementing, naming, testing and maintaining these computations and; the presence of these small additions that congeal with intuitions about Foundation types; I would propose these additions are delightful.

## Detailed design

Consider two date intervals `A` and `B` demarcating moments on this first timeline:
```
1. |--A--| <-- time interval --> |--B--|
```
For the `timeIntervalSince(_:)` APIs, the time interval of `B` since `A` will be zero or positive because `B` demarcates a range of moments later than the range of moments demarcated by `A`. The time interval of `A` since `B` will be zero or negative because the range of moments the range of moments demarcated by `A` are earlier than those demarcated by `B`.

For the `dateIntervalSince(_:)` APIs, the date interval of `B` since `A` will be the same as the date interval of `A` since `B` because `DateInterval` is designed to represent positive intervals only. The time between the earliest end and latest start becomes the duration and the earliest end becomes the start of the resulting `DateInterval`.

Consider two date intervals `C` and `D` demarcating moments on a second timeline:
```
2. |--C--|--D--|
```
The time or date intervals since `C` and `D` and vice-versa are zero because `C` ends where `D` begins. With this, developers can test that two date intervals form an unbroken, continuous range of moments.

Finally, consider two thoroughly intersecting date intervals demarcating these moments on a third timeline:
```
3. |--|—-—-|--|
```
In this case, the time or date intervals since either interval does not exist and the APIs shall return `nil`.

## Source compatibility

Describe the impact of this proposal on source compatibility. As a general rule, all else being equal, Swift code that worked in previous releases of the tools should work in new releases. That means both that it should continue to build and that it should continue to behave dynamically the same as it did before.

Consider the impact on existing clients. If clients provide a similar API, will type-checking find the right one? If the feature overloads an existing API, is it problematic that existing users of that API might start resolving to the new API?

## Implications on adoption

The compatibility sections above are focused on the direct impact of the proposal on existing code. In this section, describe issues that intentional adopters of the proposal should be aware of.

Consider the impact on library adopters of those features. Can adopting this feature in a library break source or ABI compatibility for users of the library? If a library adopts the feature, can it be *un*-adopted later without breaking source compatibility? Will package authors be able to selectively adopt this feature depending on the tools version available, or will it require bumping the minimum tools version required by the package?

If there are no concerns to raise in this section, leave it in with text like "This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility."

## Future directions

Describe any interesting proposals that could build on this proposal in the future. This is especially important when these future directions inform the design of the proposal.

The rest of the proposal should generally not talk about future directions except by referring to this section. It is important not to confuse reviewers about what is covered by this specific proposal. If there's a larger vision that needs to be explained in order to understand this proposal, consider starting a discussion thread on the forums to capture your broader thoughts.

Avoid making affirmative statements in this section, such as "we will" or even "we should". Describe the proposals neutrally as possibilities to be considered in the future.

Consider whether any of these future directions should really just be part of the current proposal. It's important to make focused, self-contained proposals that can be incrementally implemented and reviewed, but it's also good when proposals feel "complete" rather than leaving significant gaps in their design.

## Alternatives considered

Describe alternative approaches to addressing the same problem. This is an important part of most proposal documents. Reviewers are often familiar with other approaches prior to review and may have reasons to prefer them. This section is your first opportunity to try to convince them that your approach is the right one, and even if you don't fully succeed, you can help set the terms of the conversation and make the review a much more productive exchange of ideas.

You should be fair about other proposals, but you do not have to be neutral; after all, you are specifically proposing something else. Describe any advantages these alternatives might have, but also be sure to explain the disadvantages that led you to prefer the approach in this proposal.

You should update this section during the pitch phase to discuss any particularly interesting alternatives raised by the community. You do not need to list every idea raised during the pitch, just the ones you think raise points that are worth discussing. Of course, if you decide the alternative is more compelling than what's in the current proposal, you should change the main proposal; be sure to then discuss your previous proposal in this section and explain why the new idea is better.

## Acknowledgments

If significant changes or improvements suggested by members of the community were incorporated into the proposal as it developed, take a moment here to thank them for their contributions. Swift evolution is a collaborative process, and everyone's input should receive recognition!

Generally, you should not acknowledge anyone who is listed as a co-author or as the review manager.
