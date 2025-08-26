#  The `DiscreteFormatStyle` Protocol

* Proposal: [SF-0003](0003-discrete-format-style.md)
* Authors: [Max Obermeier](https://github.com/themomax)
* Review Manager: [Tina Liu](https://github.com/itingliu)
* Status: **Accepted**
* Implementation: [themomax/swift-foundation#2](https://github.com/theMomax/swift-foundation/pull/2)
* Review: [Pitch](https://forums.swift.org/t/fou-formatstyle-enhancements/68858)

## Introduction

Foundation defines the `FormatStyle` protocol making it easy to format all kinds of data. While its API works great for defining a format and formatting static values, re-formatting every time a continuous dynamic input value changes is unnecessary and computationally expensive. Format styles need a mechanism to provide information for what inputs it is actually necessary to update the output.

## Motivation

Often times the input to a `FormatStyle` is not constant, but changes continuously, e.g. if it is dependent on live sensor data or the current time. Meanwhile, textual `FormatOutput`s designed to be read by humans mostly do not represent the `FormatInput` to its full resolution. E.g. while `Date.now` (depending on the absolute value of the date) changes hundreds of thousands of times per second, a formatted output like `"9:41am"` only needs to be updated once a minute. Thus it is generally a lot more efficient to first calculate when the formatted string changes from `"9:41am"` to `"9:42am"`, schedule an update for that point in time, and only format once at the calculated point in time. The alternative would be to update the formatted string at regular intervals, which need to be small enough so the string never appears outdated. Each of these updates would involve calculating the output value and building the output string, often involving memory allocations and string concatenations, which would be a waste of computational resources.

While calculating that discretization boundary (i.e. the input value where the output changes) is relatively easy for a time format that always only shows hours and minutes, it can be very hard to calculate without access to the `FormatStyle`'s internal logic. Furthermore, having that logic separated from the `FormatStyle`'s formatting logic would create major problems for maintainability.

## Proposed solution

To solve this problem, relevant `FormatStyle`s must define functions that provide the discretization boundaries around a given input value.

These functions can be used to determine when to schedule the next update. The listing below shows how the `discreteInput(after:)` function could be used to keep a clock display up to date.

```swift
func updateClock() {
    let style = Date.FormatStyle()

    // the input is the current time
    let currentInput = Date.now
    // format the current input
    let output = style.format(currentInput)
    // render the current output
    render(output)

    // use the `discreteInput(after:)` function to get the next larger input value that
    // might produce an output that is different from `format(currentInput)`
    guard let dateForNextUpdate = style.discreteInput(after: currentInput) else {
        // there is no discrete input after `currentInput` that would yield an output
        // string different from `output` (which would happen if `Date.now` would yield an
        // extremely large date that cannot be represented in `style`'s calendar.
        return
    }

    // schedule this function to be called again when `Date.now == dateForNextUpdate`
    scheduleNextUpdate(at: dateForNextUpdate)
}
```

Without the `discreteInput(after:)` function, we'd have to resort to either:
 * replicate the exact logic `discreteInput(after:)` provides outside the `FormatStyle`, which means reverse engineering the `Date.FormatStyle` implementation and keeping that logic up to date (bad maintainability)
 * use an easier calculation that works for our concrete format style instance, e.g. updating the display once a minute and trying to align those updates to full minutes (which can be very prone to errors if not done carefully)
 * update at a high refresh rate even though most updates will yield the same string (very inefficient)

## Detailed design

The `discreteInput(before:)` and `discreteInput(after:)` functions, which provide the discretization boundaries of a format style, are formalized in the `DiscreteFormatStyle` protocol, which refines `FormatStyle`.

The most basic way to think about these functions is as follows: By calling `discreteInput(before: x)`, we get the highest value smaller than `x` that produces a different formatted output. Conversely, for `discreteInput(after: x)`, we get the smallest value higher than `x` that produces a different formatted output.

```swift
let style = Duration.UnitsFormatStyle(allowedUnits: [.minutes, .seconds], width: .wide)
style.format(.seconds(3)) // "3 seconds"

style.discreteInput(before: .seconds(3)) // .seconds(2.49999999999)
style.format(.seconds(2.49999999999)) // "2 seconds"

style.discreteInput(after: .seconds(3)) // .seconds(3.5)
style.format(.seconds(3.5)) // "4 seconds"
```

We can use this functionality to e.g. build a very basic terminal clock:

```swift
var style: some DiscreteFormatStyle<Date, String> {
    // we don't need to care what's in here
    return Date.FormatStyle() 
}

while true {
    let now = Date.now

    // clear the line and print the formatted date
    print("\u{1B}[1A\u{1B}[K" + style.format(now))
    
    // get the next date that warrants updating the formatted output
    guard let nextDate = style.discreteInput(after: now) else {
        break
    }
    
    // wait until `nextDate`
    usleep(UInt32(nextDate.timeIntervalSince(now) * 1e6))
}
```

The `discreteInput(before:)` and `discreteInput(after:)` functions return an optional value. That is because there are situations where the formatted output won't change or is undefined for larger or smaller inputs. One situation where that happens is when there is no larger/smaller `FormatInput` than the one given, or when the internal representations used for calculating the output cannot handle very large/small `FormatInput`s:

```swift
let style = Date.ComponentsFormatStyle(style: .wide,fields: [.second])
let date = Date.distantPast

style.format(date..<date.advanced(by: TimeInterval(Int32.max)))                 // "2,147,483,647 seconds"
style.format(date..<date.advanced(by: TimeInterval(Int32.max) + 1.0))           // "0 seconds"
style.discreteInput(after: date..<date.advanced(by: TimeInterval(Int32.max)))   // nil
```

However, there are also totally valid reasons beyond limits of data representations for a format style to return `nil`. E.g. a format style could format all negative inputs as zero.

There is one further intricacy of `discreteInput(before:)` and `discreteInput(after:)`, which is that this previous definition does not need to hold for all values `x`, but only for _most_:

> By calling `discreteInput(before: x)`, we get the highest value smaller than `x` that produces a different formatted output. Conversely, for `discreteInput(after: x)`, we get the smallest value higher than `x` that produces a different formatted output.

E.g. when formatting a floating point value as an integer, we can get the next discrete input after `x` by calculating `floor(x + 1)`. However, when rounding toward zero, the whole interval (-1;1) formats as zero. It would be ok for a discrete format style to ignore that edge case and return `0` for the `discreteInput(after:)` a negative value greater than `-1`, even though that still produces the same formatted output.

In the end it's the implementor's responsibility to find a reasonable definition for the term _"most"_. The implementation should provide a performant way of keeping the formatted output up to date and stepping through all discrete inputs.


Beyond `discreteInput(before:)` and `discreteInput(after:)`, `DiscreteFormatStyle` has two more requirements: `input(before:)` and `input(after:)`. While they can be ignored by most developers, they are vital for ensuring correctness and building complex types on top of the `DiscreteFormatStyle` protocol.

The  functions can be used to obtain the closest input in either direction that the format style can differentiate from the original input. Usually, this will be the smallest increment/decrement that can be represented in the `FormatInput`. This enables a number of applications:
 * We can formalize situations where a format style cannot provide precise results for the discretization boundaries in a performant way. For example, all ICU based format styles that work with `Date` cannot calculate the discretization boundaries precisely, because Foundation's reference date for `Date` is different from ICU's `UDate` and both represent the date as a `Double` measuring the offset from their respective reference date, leading to deviations in the floating point math. Thus, even though two `Date` instances might be unequal, they may still round to the same `UDate` and in that case they cannot be differentiated by the format style.
   So, while the bounds provided by `discreteInput(before:)` and `discreteInput(after:)` should be sufficiently close to the actual discretization boundaries implemented by the `format(_:)` method, we can verify that with the `input(before:)`/`input(after:)` methods and manually probe `format(_:)` for the undefined interval at the required refresh rate if really necessary.
   ```swift
   func updateClock() {
       let style = Date.FormatStyle()
    
       let currentInput = Date.now
       let output = style.format(currentInput)
       render(output)
    
       guard let dateForNextUpdate = style.discreteInput(after: currentInput) else {
           return
       }
    
       // we assert that we never update the clock more than a millisecond after the date
       // where it should update    
       assert(dateForNextUpdate.timeIntervalSince(style.input(before: dateForNextUpdate) ?? currentInput) <= 1e-3)
    
       scheduleNextUpdate(at: dateForNextUpdate)
   }
   ```
 * We can implement non-conformance. When a type conforms to `DiscreteFormatStyle`, but also has a configuration where it cannot implement the conformance, it can specify this by always returning `nil` for `input(before:)` and `input(after:)` in said configuration.
 * Given a `FormatInput` `x` that should serve as a decision boundary for determining the formatted output of a `FormatStyle`, we require the `input(before: x)`/`input(after: x)` to implement `discreteInput(before:)`/`discreteInput(after:)` in a generic way.
   E.g. if we wanted to develop a discrete format style where the output is "Invalid input" if the input is smaller than or equal to `x` and the result of a `base` format style otherwise, we could implement the `discreteInput(after:)` function as follows:
    ```swift
    func discreteInput(after input: FormatInput) -> FormatInput? {
        if input <= x {
            return base.input(after: x)
        } else {
            return base.discreteInput(after: input)
        }
    }
    ```

The `DiscreteFormatStyle` protocol is listed below:

```swift
/// A format style that transforms a continuous input into a discrete output and provides
/// information about its discretization boundaries.
///
/// Use this protocol to keep displays up to date if input changes continuously, or to iterate
/// over all possible outputs of a ``FormatStyle`` by obtaining the next discrete input in either direction
/// from ``discreteInput(before:)`` or ``discreteInput(after:)``.
///
/// ## Ordering of Inputs
///
/// The ordering over ``FormatStyle/FormatInput``
/// defined by ``discreteInput(before:)`` / ``discreteInput(after:)`` must be
/// consistent between the two functions. If ``FormatStyle/FormatInput`` conforms to the
/// `Comparable` protocol, the format style's ordering _should_ be consistent with the canonical ordering
/// defined via the `Comparable` conformance, i.e. it should hold that
/// `discreteInput(before: x)! < x < discreteInput(after: x)!` where discrete inputs
/// are not nil.
///
/// ## Stepping through Discrete Input/Output Pairs
///
/// One use case of this protocol is enumerating all discrete inputs of a format style and their respective
/// outputs.
///
/// While the ``discreteInput(before:)`` and ``discreteInput(after:)``
/// functions are the right tool for that, they do not give a guarantee that their respective return values
/// actually produce an output that is different from the output produced by formatting the `input` value
/// used when calling ``discreteInput(before:)`` / ``discreteInput(after:)``, they only
/// provide a value that produces a different output for _most_ inputs. E.g. when formatting a floating point
/// value as an integer, we can get the next discrete input after `x` by calculating `floor(x + 1)`.
/// However, when rounding toward zero, the whole interval (-1;1) formats as zero. It would be ok for a
/// discrete format style to ignore that edge case and return `0` for the ``discreteInput(after:)`` a
/// negative value greater than `-1`. Therefore, to enumerate all discrete input/output pairs, adjacent
/// outputs must be deduplicated in order to guarantee no adjacent outputs are the same.
///
/// The following example produces all discrete input/output pairs for inputs in a given `range` making
/// sure adjacent outputs are unequal:
///
/// ```swift
/// extension DiscreteFormatStyle
///     where FormatInput : Comparable, FormatOutput : Equatable
/// {
///         func enumerated(
///         in range: ClosedRange<FormatInput>
///     ) -> [(input: FormatInput, output: FormatOutput)] {
///         var input = range.lowerBound
///         var output = format(input)
///
///         var pairs = [(input: FormatInput, output: FormatOutput)]()
///         pairs.append((input, output))
///
///         // get the next discretization bound
///         while let nextInput = discreteInput(after: input),
///               // check that it is still in the requested `range`
///               nextInput <= range.upperBound {
///             // get the respective formatted output
///             let nextOutput = format(nextInput)
///             // deduplicate based on the formatted output
///             if nextOutput != output {
///                 pairs.append((nextInput, nextOutput))
///             }
///                 input = nextInput
///             output = nextOutput
///         }
///
///         return pairs
///     }
/// }
/// ```
///
/// ## Imperfect Discretization Boundaries
///
/// In some scenarios, a format style cannot provide precise discretization boundaries in
/// a performant manner. In those cases it must override ``input(before:)`` and
/// ``input(after:)`` to reflect that. For any discretization boundary `x` returned by either
/// ``discreteInput(before:)`` or ``discreteInput(after:)`` based on the
/// original input `y`, all values representable in the ``FormatStyle/FormatInput``strictly  between
/// `x` and the return value of `input(after: x)` or `input(before: x)`, respectively, are not
/// guaranteed to produce the same formatted output as `y`.
///
/// The following schematic shows an overview of the guarantees given by the protocol:
///
///     xB = discreteInput(before: y)       y      xA = discreteInput(after: y)
///           |                             |                             |
///     <-----+---+-------------------------+-------------------------+---+--->
///               |                                                   |
///      zB = input(after: xB)                          zA = input(before: xA)
///
/// - the formatted output for everything in `zB...zA` (including bounds) is **guaranteed** to be equal
///   to `format(y)`
/// - the formatted output for `xB` and lower is **most likely** different from `format(y)`
/// - the formatted output for `xA` and higher is **most likely** different from `format(y)`
/// - the  formatted output between `xB` and `zB`, as well as `zA` and `xA` (excluding bounds) cannot
///   be predicted
@available(FoundationPreview 0.4, *)
public protocol DiscreteFormatStyle<FormatInput, FormatOutput> : FormatStyle {
    /// The next discretization boundary before the given input.
    ///
    /// Use this function to determine the next "smaller" input that warrants updating the formatted output.
    /// The following example prints all possible outputs the format style can produce downwards starting
    /// from the `startInput`:
    ///
    /// ```swift
    /// var previousInput = startInput
    /// while let nextInput = style.discreteInput(before: previousInput) {
    ///     print(style.format(nextInput))
    ///     previousInput = nextInput
    /// }
    /// ```
    ///
    /// - Returns: For most `input`s, the method returns the "greatest" value "smaller" than
    /// `input` for which the style produces a different ``FormatStyle/FormatOutput``, or `nil`
    /// if no such value exists. For some input values, the function may also return a value "smaller" than
    /// `input` for which the style still produces the same ``FormatStyle/FormatOutput`` as for
    /// `input`.
    func discreteInput(before input: FormatInput) -> FormatInput?

    /// The next discretization boundary after the given input.
    ///
    /// Use this function to determine the next "greater" input that warrants updating the formatted output.
    /// The following example prints all possible outputs the format style can produce upwards starting
    /// from the `startInput`:
    ///
    /// ```swift
    /// var previousInput = startInput
    /// while let nextInput = style.discreteInput(after: previousInput) {
    ///     print(style.format(nextInput))
    ///     previousInput = nextInput
    /// }
    /// ```
    ///
    /// - Returns: For most `input`s, the method returns the "smallest" value "greater" than
    /// `input` for which the style produces a different ``FormatStyle/FormatOutput``, or `nil`
    /// if no such value exists. For some input values, the function may also return a value "greater" than
    /// `input` for which the style still produces the same ``FormatStyle/FormatOutput`` as for
    /// `input`.
    func discreteInput(after input: FormatInput) -> FormatInput?

    /// The next input value before the given input.
    ///
    /// Use this function to determine if the return value provided by ``discreteInput(after:)`` is
    /// precise enough for your use case for any input `y`:
    ///
    /// ```swift
    /// guard let x = style.discreteInput(after: y) else {
    ///     return
    /// }
    ///
    /// let z = style.input(before: x) ?? y
    /// ```
    ///
    /// If the distance between `z` and `x` is too large for the precision you require, you may want
    /// to manually probe ``FormatStyle/format(_:)`` at a higher rate in that interval, as there is
    /// no guarantee for what the output will be in that interval.
    ///
    /// - Returns: The next "smalller" input value that can be represented by
    /// ``FormatStyle/FormatInput`` or an underlying representation the format style uses
    /// internally.
    func input(before input: FormatInput) -> FormatInput?

    /// The next input value after the given input.
    ///
    /// Use this function to determine if the return value provided by ``discreteInput(before:)`` is
    /// precise enough for your use case for any input `y`:
    ///
    /// ```swift
    /// guard let x = style.discreteInput(before: y) else {
    ///     return
    /// }
    ///
    /// let z = style.input(after: x) ?? y
    /// ```
    ///
    /// If the distance between `x` and `z` is too large for the precision you require, you may want
    /// to manually probe ``FormatStyle/format(_:)`` at a higher rate in that interval, as there is
    /// no guarantee for what the output will be in that interval.
    ///
    /// - Returns: The next "greater" input value that can be represented by
    /// ``FormatStyle/FormatInput`` or an underlying representation the format style uses
    /// internally.
    func input(after input: FormatInput) -> FormatInput?
}
```

Default implementations of `input(before:)` and `input(after:)` are provided where `FormatInput` is `FloatingPoint`, `FixedWidthInteger`, `Date`, or `Duration`, which return the next larger/smaller instance of the respective data type (`nextUp`/`nextDown`, `+/-1`, `nextUp`/`nextDown` on the `timeIntervalSinceReferenceDate`, and `+/-1 attosecond`, respectively).

The following preexisting Foundation format styles are conformed to the protocol:

- `Duration.UnitsFormatStyle`
- `Duration.TimeFormatStyle`
- `Date.FormatStyle`
- `Date.FormatStyle.Attributed`
- `Date.VerbatimFormatStyle`
- `Date.VerbatimFormatStyle.Attributed`
- `Date.ISO8601FormatStyle`
- `Duration.UnitsFormatStyle.Attributed`
- `Duration.TimeFormatStyle.Attributed`

For all types listed above, the `FormatInput` is `Comparable`, so the behavior of the `discreteInput(before:)`/`discreteInput(after:)` functions is defined via the protocol documentation.

Further types must be discussed in more detail:

### `Date.ComponentsFormatStyle` with `Range<Date>` inputs

`Date.ComponentsFormatStyle.FormatInput` is `Range<Date>`, which of course does not conform to `Comparable`. Further, `Date.ComponentsFormatStyle` can only format "positive" ranges, because `Range` requires `lowerBound <= upperBound`.

With those restrictions, we define `discreteInput(before: x..<y)` as follows:

 * `x..<z` where `x <= z < y` and there exists no `v` in `z..<y` where `v != z` and `format(x..<v) != format(x..<y)`
 * `nil` where no such `z` exists

In words, the discrete input before a range is the range consisting of the same lower bound and the smallest possible upper bound, for which the algorithm can guarantee that no larger value would yield a formatted output different from the original range, or `nil` if this smallest possible upperbound would be less than the lower bound of the original range.

The `discreteInput(after:)` function always returns the range consisting of the same lower bound and the greatest possible upper bound, for which the algorithm can guarantee that no smaller value would yield a formatted output different from the original range, or `nil` if no such date exists.

This definition, however, does not satisfy the use case where the `upperBound` is to remain constant and the `lowerBound` moves. This is generally the case when we display the distance to an event in the future.

To satisfy this use case, we introduce a new mutable boolean property `isPositive`. When set to `false`, the style interpretes the input range as a "negative" range, i.e. it formats the distance from the `upperBound` to the `lowerBound`, not the other way around. This essentially means the formatted output gets a minus prefix. When `isPositive` is `false`, the `DiscreteFormatStyle` methods keep the `upperBound` constant and move the `lowerBound` instead. The `lowerBound` `before` is smaller, growing the distance between `lowerBound` and `upperBound` (the value is considered negative, so the smaller value has the higher absolute value). Conversely, the `lowerBound` `after` is greater, shrinking the distance between `lowerBound` and `upperBound`.

```swift
@available(FoundationPreview 0.4, *)
extension Date.ComponentsFormatStyle : DiscreteFormatStyle {
    /// Controls whether the format input is formatted as a positive or negative range.
    ///
    /// When the range is formatted as a positive value, the returned string describes the time
    /// from `lowerBound` to `upperBound`. When `isPositive` is set to `false`, the
    /// returned string describes the time from `upperBound` to `lowerBound`.
    public var isPositive: Bool { get set }

    /// The next discretization boundary before the given input.
    ///
    /// Use this function to determine the next smaller input that warrants updating the formatted output.
    /// If ``isPositive`` is true, the returned range has the same `lowerBound` as the `input`,
    /// but reduces the `upperBound` so that the returned range produces the next smaller output.
    /// If ``isPositive`` is false, the returned range has the same `upperBound` as the
    /// `input` and a smaller `lowerBound`.
    ///
    ///      let style = Date.ComponentsFormatStyle(style: .wide)
    ///      print(style.format(start..<end)) // "1 hour"
    ///      guard let next = style.discreteInput(before: start..<end) else {
    ///          return
    ///      }
    ///      print(style.format(next)) // "59 minutes, 59 seconds"
    ///
    /// - Returns: If ``isPositve`` is true, the range `input.lowerBound..<x`, where `x` is
    /// the greatest date that is smaller than `input.upperBound` for which this style might produce a
    /// different ``FormatStyle/FormatOutput``. The function may return `nil` if there is no such
    /// value greater or equal to `input.lowerBound`. If ``isPositive`` is false, the range
    /// `x..<input.upperBound`, where `x` is the greatest date that is smaller than
    /// `input.lowerBound` for which this style might produce a different
    /// ``FormatStyle/FormatOutput``.
    public func discreteInput(before input: Range<Date>) -> Range<Date>?

    /// The next discretization boundary after the given input.
    ///
    /// Use this function to determine the next greater input that warrants updating the formatted output.
    /// If ``isPositive`` is true, the returned range has the same `lowerBound` as the `input`,
    /// but increases the `upperBound` so that the returned range produces the next greater output.
    /// If ``isPositive`` is false, the returned range has the same `upperBound` as the `input`
    /// and a greater `lowerBound`.
    ///
    ///     let style = Date.ComponentsFormatStyle(style: .wide)
    ///     print(style.format(start..<end)) // "1 hour"
    ///     guard let next = style.discreteInput(after: start..<end) else {
    ///         return
    ///     }
    ///     print(style.format(next)) // "1 hour, 1 second"
    ///
    /// - Returns: If ``isPositive`` is true, the range `input.lowerBound..<x`, where `x` is
    /// the greatest date that is smaller than `input.upperBound` for which this style might produce a
    /// different ``FormatStyle/FormatOutput``. If ``isPositive`` is false, the range
    /// `x..<input.upperBound`, where `x` is the smallest date that is greater than
    /// `input.lowerBound` for which this style might produce a different
    /// ``FormatStyle/FormatOutput``. The function may return `nil` if there is no such
    /// value smaller or equal to `input.upperBound`.
    public func discreteInput(after input: Range<Date>) -> Range<Date>?

    /// The next input value before the given input.
    ///
    /// If ``isPositive`` is true, the next input value maintains the same `lowerBound` as
    /// `input`, but has a different`upperBound`. If ``isPositive`` is false, the next input value
    /// maintains the same `upperBound` as `input`, but as a different `lowerBound`.
    ///
    /// Use this function to determine if the return value provided by ``discreteInput(after:)`` is
    /// precise enough for your use case for any input `y`:
    ///
    ///     guard let x = style.discreteInput(after: y) else {
    ///         return
    ///     }
    ///
    ///     let z = style.input(before: x) ?? y
    ///
    /// If the distance between the `upperBound`s of `z` and `x` is too large for the precision you
    /// require, you may want to manually probe ``format(_:)`` at a higher rate in that interval, as
    /// there is no guarantee for what the output will be in that interval.
    ///
    /// - Returns: If ``isPositive`` is true, the range `input.lowerBound..<x`, where `x` is
    /// the next smaller date that this style can differentiate, or `nil` if there is no such `x` greater or
    /// equal to `input.lowerBound`. If ``isPositive`` is false, the range
    /// `x..<input.upperBound`, where `x` is the next smaller date this style can differentiate.
    public func input(before input: Range<Date>) -> Range<Date>?

    /// The next input value after the given input.
    ///
    /// If ``isPositive`` is true, the next input value maintains the same `lowerBound` as
    /// `input`, but has a different`upperBound`. If ``isPositive`` is false, the next input value
    /// maintains the same `upperBound` as `input`, but as a different `lowerBound`.
    ///
    /// Use this function to determine if the return value provided by ``discreteInput(before:)`` is
    /// precise enough for your use case for any input `y`:
    ///
    ///     guard let x = style.discreteInput(before: y) else {
    ///         return
    ///     }
    ///
    ///     let z = style.input(after: x) ?? y
    ///
    /// If the distance between the `upperBound`s of `x` and `z` is too large for the precision you
    /// require, you may want to manually probe ``format(_:)`` at a higher rate in that interval, as
    /// there is no guarantee for what the output will be in that interval.
    ///
    /// - Returns: If ``isPositive`` is true, the range `input.lowerBound..<x`, where `x` is
    /// the next larger date that this style can differentiate. If ``isPositive`` is false, the range
    /// `x..<input.upperBound`, where `x` is the next higher date this style can differentiate, or
    /// `nil` if there is no such `x`.
    public func input(after input: Range<Date>) -> Range<Date>?
}
```
 
### `Date.RelativeFormatStyle` with dependence on `Date.now`

`Date.RelativeFormatStyle` has a dependence on `Date.now` as it essentially formats the input date relative to the current time. This makes a conformance to `DiscreteFormatStyle` basically impossible as `format(_:)` is no longer a pure function of the input and the format style's configuration.

We mitigate this using a new format style that allows for producing relative references just like `Date.RelativeFormatStyle`, but without the implicit dependence on `Date.now`. The following calls produce the same output string:

```swift
launchDate.formatted(.relative(presentation: .named))
Date.now.formatted(.relativeReference(to: launchDate))
```

For the new `Date.AnchoredRelativeFormatStyle`, the format input is the reference date, whereas the date passed to its initializer is the date one is referring to. This definition makes sense for the `DiscreteFormatStyle` conformance, as the reference date is usually the dynamic component, whereas the anchor date is fixed. That is, when we want to show a relative date on a display, it is not the time that we refer to (i.e. the `anchor`) that changes, but the date _from which_ we are referring to the `anchor` (i.e. the reference date). Thus, the reference date needs to be the format input as that is the value that the `DiscreteFormatStyle` API provides information about.

Independently of the `DiscreteFormatStyle` protocol, this new style also allows developers to produce strings to be displayed at a certain point in the future, which is not possible with `Date.RelativeFormatStyle`.

```swift
func stringToBeDisplayedNow() -> String {
    // current API is sufficient
    return Date.RelativeFormatStyle().format(anchor)
}

func stringToBeDisplayed(at referenceDate: Date) -> String {
    // current API is not sufficient; we need the new API
    return Date.AnchoredRelativeFormatStyle(anchor: anchor).format(referenceDate)
}
```

The following listing contains the full declaration of the new style.

```swift
@available(FoundationPreview 0.4, *)
extension Date {
    /// A relative format style that is detached from the system time, and instead
    /// formats an anchor date relative to the format input.
    public struct AnchoredRelativeFormatStyle : Codable, Hashable, Sendable {
        public typealias Presentation = Date.RelativeFormatStyle.Presentation
        public typealias UnitsStyle = Date.RelativeFormatStyle.UnitsStyle
        public typealias Field = Date.RelativeFormatStyle.Field

        /// The date the formatted output refers to from the perspective of the input values.
        public var anchor: Date { get set }

        public var presentation: Presentation { get set }
        public var unitsStyle: UnitsStyle { get set }
        public var capitalizationContext: FormatStyleCapitalizationContext { get set }
        public var locale: Locale { get set }
        public var calendar: Calendar { get set }
        /// The fields that can be used in the formatted output.
        public var allowedFields: Set<Field> { get set }

        /// Create a relative format style that is detached from the system time, and instead
        /// formats an anchor date relative to the format input.
        ///
        /// - Parameter anchor: The date the formatted output is referring to.
        public init(anchor: Date, presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown)

        /// Create a relative format style that is detached from the system time, and instead
        /// formats an anchor date relative to the format input.
        ///
        /// - Parameter anchor: The date the formatted output is referring to.
        public init(anchor: Date, allowedFields: Set<Field>, presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown)

        public func format(_ input: Date) -> String

        public func locale(_ locale: Locale) -> Self
    }
}

@available(FoundationPreview 0.4, *)
extension Date.AnchoredRelativeFormatStyle : DiscreteFormatStyle {
    public func discreteInput(before input: Date) -> Date?
    
    public func discreteInput(after input: Date) -> Date?
}
```

## Source compatibility

This proposal is purely additive and all changes are source and ABI compatible.

## Implications on adoption

This feature can be freely adopted where the required tools version is available, without the need to bump the minimum tools version. Unadoption is not possible for libraries that use this feature as part of their public API without breaking ABI as usual.

## Future directions

### Conforming styles based on `NumberFormatStyleConfiguration` to `DiscreteFormatStyle`

Many of the `FormatStyle`s defined on Foundation are based on the same configuration and logic, `NumberFormatStyleConfiguration`. Implementing `DiscreteFormatStyle` conformances for all format styles based on this type would be relatively easy (as the logic is the same for all of them) and would benefit many use cases. Even though the format styles based on this type are not related to time, there may still be contexts where they are used to format dynamic inputs that change continuously (e.g. live sensor data).

## Alternatives considered

### Alternative naming for `DiscreteFormatStyle`

* Alternative naming schemes for the member functions: `nextDiscreteInput(after:)`, `discreteInput(following:)`, `nextDiscreteInput(for:)`/`priorDiscreteInput(for:)`

* `DynamicFormatStyle` (because it is designed to be used in UIs with non-static, i.e. dynamic input):
  
  * `upperBound(for:)` instead of `discreteInput(after:)`
  
  * `lowerBound(for:)` instead of `discreteInput(before:)`

* `StridingFormatStyle` (progressive form does not really make sense, but `StrideableFormatStyle` has way too strong of a connection to `Strideable`)

* `SteppingFormatStyle`/`SteppableFormatStyle` (difficult to find naming for member functions that is somewhat self-explanatory as "step" already takes the place of the noun and is rather abstract on its own)

### Adding a `Comparable` requirement to the `FormatInput` of `DiscreteFormatStyle`

One could argue that `DiscreteFormatStyle` should require the `FormatInput` to be `Comparable` as otherwise the concept of having a lower and upper discretization boundary is somewhat ill defined. However, with this restriction we would basically deny any format styles with multi-dimensional inputs (such as `Date.ComponentsFormatStyle`, or postentially also `ListFormatStyle`) to conform to the `DiscreteFormatStyle` protocol. Instead each of these types would have to provide its own variant with one-dimensional `FormatInput`. While there is some advantage in having the `Comparable` requirement on `FormatInput` for building generic algorithms (see e.g. the `DiscreteFormatStyleSequence` used for testing `DiscreteFormatStyle` implementations), that can easily be added manually where needed.

### Adding a `referenceDate` property to `Date.RelativeFormatStyle` instead of introducing `Date.AnchoredRelativeFormatStyle`

Instead of introducing `Date.AnchoredRelativeFormatStyle`, one could argue adding a `referenceDate` property to the existing `Date.RelativeFormatStyle` is sufficient:

```swift
@available(FoundationPreview 0.4, *)
extension Date.RelativeFormatStyle {
    public var referenceDate: Date? { get set }
}
```

When formatting, `Date.RelativeFormatStyle` would then use `referenceDate ?? Date.now` as the reference date for the formatted output and continue to use the format input as the target date.

Developers could use this API to format a string to be displayed in the future:

```swift
func stringToBeDisplayed(at referenceDate: Date) -> String {
    var style = Date.RelativeFormatStyle()
    style.referenceDate = referenceDate
    return style.format(target)
}
```

The problem with this approach is that the `DiscreteFormatStyle` conformance wouldn't help us to keep the formatted output up to date, because it would describe what the next `target` date would be that warrants updating the formatted output. Instead we want to know what the next `referenceDate` is that warrants updating the formatted output. Note that these are two very different calculations that are not symmetric. One minute before midnight on the 31st of a month, a shift by two minutes on the reference date might change the output from "next month" to "in 15 days", but shifting the target date by two minutes in the same scenario still produces "next month".

### Adding a `target` property to `Date.RelativeFormatStyle` instead of introducing `Date.AnchoredRelativeFormatStyle`

Instead of introducing `Date.AnchoredRelativeFormatStyle`, one could argue adding a `target` property to the existing `Date.RelativeFormatStyle` is sufficient:

```swift
@available(FoundationPreview 0.4, *)
extension Date.RelativeFormatStyle {
    public var target: Date? { get set }
}
```

When formatting and `target` is set to a date, `Date.RelativeFormatStyle` would then use the format input as the reference date for the formatted output and use the `target` as the target date. If `target` were `nil`, it would behave just as the current version, i.e. it would use the format input as the target date and `Date.now` as the reference date.

Developers could use this API to format a string to be displayed in the future:

```swift
func stringToBeDisplayed(at referenceDate: Date) -> String {
    var style = Date.RelativeFormatStyle()
    style.target = target
    return style.format(referenceDate)
}
```

Further, once `target` is set, the `DiscreteFormatStyle` conformance could provide exactly the information developers need, i.e. the next reference date that warrants updating the formatted output.

The downside to this approach is that the type still conforms to `DiscreteFormatStyle` when `target` is set to `nil`. In that case we cannot provide a meaningful implementation as the `format(_:)` method is not a pure function with its dependence on `Date.now`. Instead we'd have to implement non-conformance by returning `nil` for all `DiscreteFormatStyle` requirements. Therefore, with this approach, the compiler cannot protect developers from passing a misconfigured instance (i.e. one where `target` is `nil`) into an API that expects a working `DiscreteFormatStyle`, resulting in undefined behavior.

A second downside of this approach is that setting `target` reverses the role of the format input from reference date to target date, which might be confusing for developers.

### Making `Date.AnchoredRelativeFormatStyle` a nested subtype of `Date.RelativeFormatStyle`

Today, `Date.AnchoredRelativeFormatStyle` and `Date.RelativeFormatStyle` share the same styling and configuration API. One could argue this code duplication is unnecessary and a solution would be preferrable where `Date.AnchoredRelativeFormatStyle` can be obtained from an existing `Date.RelativeFormatStyle` instance as shown below:

```swift
Date.now.formatted(.relative(presentation: .named).reference(to: launchDate))
```

Where `Date.RelativeFormatStyle.reference(to:)` would return a `Date.RelativeFormatStyle.Reference`. However, similar to the approach discussed under _"Adding a `target` property to `Date.RelativeFormatStyle` instead of introducing `Date.AnchoredRelativeFormatStyle`"_, this modifier would reverse the role of the format input from reference date to target date, which might be confusing for developers.

### Alternative naming for `Date.AnchoredRelativeFormatStyle`

 * `Date.TargetedRelativeFormatStyle` with property `target` instead of `anchor`: rejected because "anchor" expresses better that this date does not change, whereas the format input is variable.
 * `Date.RelativeReferenceFormatStyle` with a static factory method `.referenceDate(referringTo: anchorDate)`: rejected because factory method is verbose and the word "reference" is very overloaded in Computer Science

### A static factory function for `Date.AnchoredRelativeFormatStyle`

Most format styles provide a static extension to `FormatStyle where Self == TYPE`, allowing for APIs that have a more natural spelling, e.g. `myDate.formatted(.relative(presentation: .named))`.

We explicitly decided against adding such function for `Date.AnchoredRelativeFormatStyle` as that style always formats its `anchor` date, and only uses the actual format input as the reference date. Thus any spelling that starts with `Date.now.formatted` is ultimately misleading or very verbose.

## Acknowledgments

Thanks to [@parkera](https://github.com/parkera), [@spanage](https://github.com/spanage), and [@itingliu](https://github.com/itingliu) for helping me shape this API and polish the proposal.