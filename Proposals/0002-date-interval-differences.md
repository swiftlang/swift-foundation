# Date Interval Differences

* Proposal: [FOU-0002](0002-date-interval-differences.md)
* Authors: [Kiel Gillard](https://github.com/kielgillard)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [apple/swift-foundation#330](https://github.com/apple/swift-foundation/pull/330)
* Review: ([pitch](https://forums.swift.org/...))

When filling out this template, you should delete or replace all of the text except for the section headers and the header fields above. For example, you should delete everything from this paragraph down to the Introduction section below.

As a proposal author, you should fill out all of the header fields except `Review Manager`. The review manager will set that field and change several others as part of initiating the review. Delete any header fields marked *if applicable* that are not applicable to your proposal.

When sharing a link to the proposal while it is still a PR, be sure to share a live link to the proposal, not an exact commit, so that readers will always see the latest version when you make changes. On GitHub, you can find this link by browsing the PR branch: from the PR page, click the "username wants to merge ... from username:my-branch-name" link and find the proposal file in that branch.

`Status` should reflect the current implementation status while the proposal is still a PR. The proposal cannot be reviewed until an implementation is available, but early readers should see the correct status.

`Bug` should be used when this proposal is fixing a bug with significant discussion in the bug report. It is not necessary to link bugs that do not contain significant discussion or that merely duplicate discussion linked somewhere else. Do not link bugs from private bug trackers.

`Implementation` should link to the PR(s) implementing the feature. If the proposal has not been implemented yet, or if it simply codifies existing behavior, just say that. If the implementation has already been committed to the main branch (as an experimental feature), say that and specify the experimental feature flag. If the implementation is spread across multiple PRs, just link to the most important ones.

`Previous Proposal` should be used when there is a specific line of succession between this proposal and another proposal. For example, this proposal might have been removed from a previous proposal so that it can be reviewed separately, or this proposal might supersede a previous proposal in some way that was felt to exceed the scope of a "revision". Include text briefly explaining the relationship, such as "Supersedes SE-1234" or "Extracted from SE-01234". If possible, link to a post explaining the relationship, such as a review decision that asked for part of the proposal to be split off. Otherwise, you can just link to the previous proposal.

`Previous Revision` should be added after a major substantive revision of a proposal that has undergone review. It links to the previously reviewed revision. It is not necessary to add or update this field after minor editorial changes.

`Review` is a history of all discussion threads about this proposal, in chronological order. Use these standardized link names: `pitch` `review` `revision` `acceptance` `rejection`. If there are multiple such threads, spell the ordinal out: `first pitch` `second review` etc.

## Introduction

A short description of what the feature is. Try to keep it to a single-paragraph "elevator pitch" so the reader understands what problem this proposal is addressing.

Add small but convenient, quality-assured methods on `DateInterval` to compute time and date intervals between date intervals to extend and complement existing comparison and intersection APIs.

## Motivation

Describe the problems that this proposal seeks to address. If the problem is that some common pattern is currently hard to express, show how one can currently get a similar effect and describe its drawbacks. If it's completely new functionality that cannot be emulated, motivate why this new functionality would help Swift developers create better Swift code.

`DateInterval` could offer more API helping developers working with ranges of absolute moments in time. For example, a developer might be building a logbook, employment time planner or implementing a time based feature in a less specialised app. In a more complex case, the app may require users to enter start and end times for particular activities, arrange them in a particular sequence with some acceptable gap between (e.g. work here for 2 hours, work there for 1.5 hours and rest for 10 minutes with at most five minutes between, no overlaps, etc). This app would need to validate the intervals formed by the dates entered by at least: checking the intersections of intervals, measuring how much those intervals intersect by and/or measuring the time between them or by some moment. `DateInterval` would be an intuitive type to begin such an implementation with but developers would quickly hit a limit with its available interface and become responsible for implementing their logic and maintain its quality.

## Proposed solution

Describe your solution to the problem. Provide examples and describe how they work. Show how your solution is better than current workarounds: is it cleaner, safer, or more efficient?

This section doesn't have to be comprehensive. Focus on the most important parts of the proposal and make arguments about why the proposal is better than the status quo.

I would like to suggest a set of small but delightful, quality-assured additions to `DateInterval` for computing the time or date interval between two, potentially non-intersecting date intervals: `timeIntervalSince:`, `dateIntervalSince:`. I would propose two overloads for these APIs: one taking `DateInterval` values and another taking `Date` values.

Should a developer find themselves needing to compute values, these additions should feel intuitive because they bear a family resemblance to existing `Date` APIs. They extend the existing intersection APIs by signalling if two intervals intersect for a moment at opposing ends. They complement the comparison API by providing the past or future time between intervals. Effort has been put into expressively describing the computations — promoting readability — especially when developers may be tempted to settle for terse expressions. With the quality of these APIs assured, their convenience saving developers the cognitive load implementing, naming, testing and maintaining these computations, I would suggest these small but not-so-commonly needed additions would delight developers.

## Detailed design

Describe the design of the solution in detail. Show the full API and its documentation comments detailing what it does. The detail in this section should be sufficient for someone who is *not* one of the authors to be able to reasonably implement the feature.

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
