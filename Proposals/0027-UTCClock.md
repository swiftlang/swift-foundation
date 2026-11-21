# UTCClock and Epochs

* Proposal: [SF-0027](0027-UTCClock.md)
* Authors: [Philippe Hausler](https://github.com/phausler)
* Review Manager: [Tina L](https://github.com/itingliu)
* Status: Review: Jun 10...Jun 17, 2025
* Implementation: [Pull request](https://github.com/swiftlang/swift-foundation/pull/1344)
* Review: [Pitch](https://forums.swift.org/t/pitch-utcclock/78018) 

 ## Introduction

[The proposal for Clock, Instant and Duration](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0329-clock-instant-duration.md) was left with a future direction to address feedback for the need of clocks based upon the time measured by interacting with the user displayed clock, otherwise known as the "wall clock".

This proposal introduces a new clock type for interacting with the user displayed clock, transacts in instants that are representations of offsets from an epoch and defined by the advancement from a UTC time.

## Motivation

Clocks in general can express many different mechanisms for time. That time can be strictly increasing, increasing but paused when the computer is not active, or in a clock in the traditional non-computing sense that one schedules according to a given time of day. The latter one must have some sort of mechanism to interact with calendarical and localized calculations.

All three of the aforementioned clocks all have a concept of a starting point of reference. This is not a distinct requirement for creating a clock, but all three share this additional convention of a property.

## Proposed solution and example

In short, a new clock will be added: `UTCClock`. This clock will have its `Instant` type defined as `Date`. There will also be affordances added for calculations that account for the edge cases of [leap seconds](https://en.wikipedia.org/wiki/Leap_second) (which currently `Date` on its own does not currently offer any sort of mechanism either on itself or via `Calendar`). `Date` has facilities for expressing a starting point from an epoch, however that mechanism is not shared to `ContinuousClock.Instant` or `SuspendingClock.Instant`. All three types will have an added new static property for fetching the `epoch` - and it is suggested that any adopters of `InstantProtocol` should add a new property to their types to match this convention where it fits.

Usage of this `UTCClock` can be illustrated by awaiting to perform a task at a given coordinated time. This has a number of interesting wrinkles that the `SuspendingClock` and `ContinousClock` wouldn't be able to handle. Example usages include server side coordination between machines or processes to execute work at a given time. In the following example a server workload is scheduled to synchronize at 18:00 every Sunday.

```swift
func synchronization() async throws {
  while true {
    let nextSunday = DateComponents(hour: 18, minute: 0, weekday: 1)
    if let when = Calendar(identifier: .iso8601).nextDate(after: Date(), matching: nextSunday, matchingPolicy: .nextTime) {
      try await UTCClock().sleep(until: when)
      try await synchronize()
    }
  }
}
```

The applications for which span from mobile to desktop to server environments and have a wide but specific set of use cases. It is worth noting that this new type should not be viewed as a replacement to the SuspendingClock or ContinuousClock, since those others have key functionality for representing behavior where the concept of time would be inappropriate to be non-monotonic. Further construction around the Date and the behavior after the suspension can accommodate for other uses and it can be a part of a composition to offer a civil/human alarm system - however that concept is well beyond the scope of the UTCClock itself (and this proposal). 


## Detailed design

These additions can be broken down into three categories; the `UTCClock` definition, the conformance of `Date` to `InstantProtocol`, and the extensions for vending epochs. All of these will live along side Date in the Foundation essentials module.

The structure of the `UTCClock` is trivially sendable since it houses no specific state and has the defined typealias of its `Instant` as `Date`. The minimum feasible resolution of `Date` is 1 nanosecond. The sleep method may respond to host system time adjustments; e.g. if a system has it's time changed manually or if the system adjusts the time drift via ntp updates so the sleep method, unlike ContinuousClock, is not strictly monotonic. However, since UTC itself is the root definition of timezones[^timezones] there is no daylight savings time adjustment; any calculation for accounting to DST must be done before hand by interacting with the Calendar and deriving a Date accordingly.

```swift
@available(FoundationPreview 6.3, *)
public struct UTCClock: Sendable {
  public typealias Instant = Date
  public init()
}

@available(FoundationPreview 6.3, *)
extension UTCClock: Clock {
    public func sleep(until deadline: Date, tolerance: Duration? = nil) async throws
    public var now: Date { get }
    public var minimumResolution: Duration { get }
}
```

The extension of `Date` conforms it to `InstantProtocol` and adds one addition "near miss" of the protocol as an additional function that in practice feels like a default parameter. This `duration(to:includingLeapSeconds:)` function provides the calculation of the duration from one point in time to another and calculates if the span between the two points includes a leap second or not. This calculation can be used for historical astronomical data since the irregularity of the rotation causes variation in the observed solar time. Those points are historically fixed and are a known series of events at specific dates (in UTC)[^utclist].

```swift
@available(FoundationPreview 6.3, *)
extension Date: InstantProtocol {
    public func advanced(by duration: Duration) -> Date
    public func duration(to other: Date) -> Duration
}

@available(FoundationPreview 6.3, *)
extension Date {
    public static func leapSeconds(from start: Date, to end: Date) -> Duration
}
```

Usage of the `duration(to:)` and `leapSeconds(from:to:)` works as follows to calculate the total number of leap seconds:

```swift
let start = Calendar.current.date(from: DateComponents(timeZone: .gmt, year: 1971, month: 1, day: 1))!
let end = Calendar.current.date(from: DateComponents(timeZone: .gmt, year: 2017, month: 1, day: 1))!
let leaps = Date.leapSeconds(from: start, to: end)
print(leaps) // prints 27.0 seconds
print(start.duration(to: end) + leaps) // prints 1451692827.0 seconds
```

It is worth noting that the usages of leap seconds for a given range is not a common use in most every-day computing; this is intended for special cases where data-sets or historical leap second including durations are strictly needed. The general usages should only require the normal `duration(to:)` api without adding any additional values. Documentation of this function will reflect that more "niche" use case.

An extension to `UTCClock` will be made in `Foundation` for exposing an `systemEpoch` similarly to the properties proposed for the `SuspendingClock` and `ContinousClock`. This epoch will be defined as the `Date(timeIntervalSinceReferenceDate: 0)` which is Jan 1 2001. The naming is set forth by the proposal [SE-0473](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0473-clock-epochs.md) and the system in the name `systemEpoch` refers to Foundation as the system and not the host system since Foundation's premise is to provide a common abstraction to any host platform.

```swift

@available(FoundationPreview 6.3, *)
extension UTCClock {
    public static var systemEpoch: Date { get }
}
```

## Impact on existing code

This is a purely additive set of changes. 

## Alternatives considered

It was considered to add a protocol joining the epochs as a "EpochClock" but that offers no real algorithmic advantage worth introducing a new protocol. Specialization of functions should likely just use where clauses to the specific instant or clock types.

It was considered to add a new `Instant` type instead of depending on `Date` however this was rejected since it would mean re-implementing a vast swath of the supporting APIs for `Calendar` and such. The advantage of this is minimal and does not counteract the additional API complexity. This consideration did delve into the idea of moving Date to a lower scope and also changing it's storage, however due to the complexity of that; it is considered a non-goal of this proposal and squarely in the out of scope territory. The beneifit of scheduling and appropriate calculations with regards to leap seconds are valueable on their own and distinctly seperable tasks to any sort of re-orgnaization of Date et al.

It was considered to add a near-miss overload for `duration(to:)` that had an additional parameter of `includingLeapSeconds` this was dismissed because it was considered to be too confusing and may lead to bugs where that data was not intended to be used. 

[^utclist] If there are any updates to the list that will be considered a data table update and require a change to Foundation.
[^timezones] Time zones and daylight savings times are defined as a reference from UTC offsets. For example Pacific Standard Time is defined as UTC -8, and Pacific Daylight Time is defined as UTC -7.