//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

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

@available(FoundationPreview 0.4, *)
extension DiscreteFormatStyle where FormatInput : FloatingPoint {
    public func input(before input: FormatInput) -> FormatInput? {
        guard input > -FormatInput.infinity else {
            return nil
        }

        return input.nextDown
    }

    public func input(after input: FormatInput) -> FormatInput? {
        guard input < FormatInput.infinity else {
            return nil
        }

        return input.nextUp
    }
}

@available(FoundationPreview 0.4, *)
extension DiscreteFormatStyle where FormatInput : FixedWidthInteger {
    public func input(before input: FormatInput) -> FormatInput? {
        guard input > FormatInput.min else {
            return nil
        }

        return input - 1
    }

    public func input(after input: FormatInput) -> FormatInput? {
        guard input < FormatInput.max else {
            return nil
        }

        return input + 1
    }
}

@available(FoundationPreview 0.4, *)
extension DiscreteFormatStyle where FormatInput == Date {
    public func input(before input: FormatInput) -> FormatInput? {
        guard input > Date.distantPast else {
            return nil
        }

        return input.nextDown
    }

    public func input(after input: FormatInput) -> FormatInput? {
        guard input < Date.distantFuture else {
            return nil
        }

        return input.nextUp
    }
}

extension Date {
    package var nextDown: Date {
        .init(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.nextDown)
    }

    package var nextUp: Date {
        .init(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.nextUp)
    }
}

@available(FoundationPreview 0.4, *)
extension DiscreteFormatStyle where FormatInput == Duration {
    public func input(before input: FormatInput) -> FormatInput? {
        guard input > .seconds(Int64.min) else {
            return nil
        }

        return input.nextDown
    }

    public func input(after input: FormatInput) -> FormatInput? {
        guard input < .seconds(Int64.max) else {
            return nil
        }

        return input.nextUp
    }
}

extension Duration {
    package var nextDown: Duration {
        self - .init(secondsComponent: 0, attosecondsComponent: 1)
    }

    package var nextUp: Duration {
        self + .init(secondsComponent: 0, attosecondsComponent: 1)
    }
}
