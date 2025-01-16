# Foundation Evolution Process

All new public types, functions, and other APIs must go through an API review process. Foundation uses an API process inspired by the [Swift Evolution review process](https://github.com/swiftlang/swift-evolution/blob/main/process.md).

A group of core contributors and stakeholders form the _Foundation Workgroup_, which runs reviews for community API proposals and makes decisions about which to accept.

### How to propose a change

*This section outlines the general process for features with a larger scope. For minor API proposals, please refer to the [Abbreviated review for minor proposals](#abbreviated-review-for-minor-proposals) section.*

* **Consider the goal**: Before proposing a change, please consider how your idea fits into the goals and themes for the upcoming release. 
* **Socialize the idea**: Propose a rough sketch of the idea in the "pitches" section of the Swift forums, the problems it solves, what the solution looks like, etc., to gauge interest from the community.
* **Develop the proposal**: Expand the rough sketch into a complete proposal, using the [proposal template](Proposals/0000-template.md), and continue to refine the proposal on the forums. Prototyping an implementation and its uses along with the proposal is required because it helps ensure both technical feasibility of the proposal as well as validating that the proposal solves the problems it is meant to solve.
* **Request a review**: Initiate a pull request to the swift-foundation repository to indicate to the workgroup that you would like the proposal to be reviewed. When the proposal is sufficiently detailed and clear, and addresses feedback from earlier discussions of the idea, the pull request will be accepted. The proposal will be assigned a proposal number as well as a Foundation Workgroup member to manage the review.
* **Address feedback**: In general, and especially during the review period, be responsive to questions and feedback about the proposal.

### The review process

*This section outlines the review process for features with a larger scope. For minor API proposals, please refer to the [Abbreviated review for minor proposals](#abbreviated-review-for-minor-proposals) section.*

The review process for a particular proposal begins when a member of the Foundation Workgroup accepts a pull request of a new or updated proposal into the repository. That Foundation Workgroup member becomes the review manager for the proposal. The proposal is assigned a proposal number (if it is a new proposal), and then enters the review queue.

The review manager will work with the proposal authors to schedule the review. Reviews usually last a single week, but can run longer for particularly large or complex proposals.

When the scheduled review period arrives, the review manager will post the proposal to the Swift forums with the proposal title. To avoid delays, it is important that the proposal authors be available to answer questions, address feedback, and clarify their intent during the review period.

After the review has completed, the Foundation Workgroup will make a decision on the proposal. The review manager is responsible for determining consensus among the Foundation Workgroup members, then reporting their decision to the proposal authors and forums. The review manager will update the proposal's state in the repository to reflect that decision.

### Abbreviated review for minor proposals

Minor API enhancement ideas that have gained community interest through GitHub issues or forum threads may take a shorter review process. Examples include extending existing types with new functions or variables, or adding new `case` to `enum`. Instead of requiring both a pitch thread and a review, these changes can be proposed directly with a proposal document on a pitch thread. The workgroup has appointed an API champion (currently @itingliu) to oversee this process. Here's what you would do:

* **Develop the proposal**: Prepare the proposal using the [proposal template](Proposals/0000-template.md) with a prototype.
* **Request an abbreviated review**: Initiate a pull request to the swift-foundation repository to indicate to the workgroup that you would like the proposal to be reviewed. Meanwhile, post the pull request on the "pitches" section of the Swift forums. Upon seeing the pitch on the forum, a workgroup member will be assigned to manage the review. 
* **Address feedback**: Be responsive to questions and feedback and continue to refine the proposal as needed.

At the end of the review period, the review manager will accept the proposal if there is a broad agreement among workgroup members and the community.


### Appendix: Review Announcement Template

(Credit: This section is adapted from [Swift-Evolution's announcement template](https://github.com/apple/swift-evolution/blob/main/process.md#review-announcement))

When a proposal enters review, a new topic will be posted to the [Foundation project of the Swift forums](https://forums.swift.org/c/related-projects/foundation/) using the following template.

<details>
    <summary> Template </summary>

---
Hello Swift community,

The review of [\<\<PROPOSAL NAME>>]\(\<\<LINK TO PROPOSAL>>) begins now and runs through \<\<REVIEW END DATE>>

Reviews are an important part of the Swift-Foundation evolution process. All review feedback should be either on this forum thread or, if you would like to keep your feedback private, directly to me as the review manager by \<\<CONTACT METHOD>>. When contacting the review manager directly, please include proposal name in the subject line.


##### Trying it out

If you'd like to try this proposal out, you can check out \<\<LINK TO IMPLEMENTATION>>.

##### What goes into a review?

The goal of the review process is to improve the proposal under review
through constructive criticism and, eventually, determine the direction of
Swift-Foundation. When writing your review, here are some questions you might want to
answer in your review:

* What is your evaluation of the proposal?
* Does this proposal fit well with the feel and direction of Swift-Foundation?
* If you have used other languages or libraries with a similar
  feature, how do you feel that this proposal compares to those?
* How much effort did you put into your review? A glance, a quick
  reading, or an in-depth study?

More information about Swift-Foundation review process is available at

> <https://github.com/apple/swift-foundation/blob/main/CONTRIBUTING.md>

Thank you,

-\<\<REVIEW MANAGER NAME>>

Review Manager
