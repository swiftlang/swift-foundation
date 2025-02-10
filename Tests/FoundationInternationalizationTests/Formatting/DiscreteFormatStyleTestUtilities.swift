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

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#endif

#if canImport(FoundationInternationalization)
@testable import FoundationInternationalization
#endif

extension DiscreteFormatStyle where FormatInput : Comparable {
    /// Produces a sequence that generates all outputs of a discrete format style from a given start to a given end.
    func evaluate(from initialInput: FormatInput, to end: FormatInput, _ advance: @escaping (FormatInput, FormatInput) -> FormatInput? = { prev, next in next }) -> LazySequence<DiscreteFormatStyleSequence<Self>> {
        DiscreteFormatStyleSequence(style: self, input: initialInput, end: end, advance: advance, isLower: <).lazy
    }
}

extension DiscreteFormatStyle {
    /// Produces a sequence that generates all outputs of a discrete format style from a given start to a given end.
    func evaluate(from initialInput: FormatInput, to end: FormatInput, _ advance: @escaping (FormatInput, FormatInput) -> FormatInput? = { prev, next in next }, isLower: @escaping (FormatInput, FormatInput) -> Bool) -> LazySequence<DiscreteFormatStyleSequence<Self>> {
        DiscreteFormatStyleSequence(style: self, input: initialInput, end: end, advance: advance, isLower: isLower).lazy
    }
}

/// A sequence that generates all outputs of a discrete format style from a given start to a given end.
struct DiscreteFormatStyleSequence<Style: DiscreteFormatStyle> : Sequence, IteratorProtocol {
    private let style: Style
    private var input: Style.FormatInput
    private let end: Style.FormatInput
    private let isIncreasing: Bool
    private let advance: (Style.FormatInput, Style.FormatInput) -> Style.FormatInput?
    private var abort: Bool = false
    private let isLower: (Style.FormatInput, Style.FormatInput) -> Bool

    init(style: Style, input: Style.FormatInput, end: Style.FormatInput, advance: @escaping (Style.FormatInput, Style.FormatInput) -> Style.FormatInput?, isLower: @escaping (Style.FormatInput, Style.FormatInput) -> Bool) {
        self.style = style
        self.input = input
        self.end = end
        self.isIncreasing = isLower(input, end)
        self.advance = advance
        self.isLower = isLower
    }

    func makeIterator() -> DiscreteFormatStyleSequence<Style> {
        self
    }

    mutating func next() -> (input: Style.FormatInput, output: Style.FormatOutput)? {
        guard !abort && (isIncreasing
                ? !isLower(end, input)
                : !isLower(input, end)) else {
            return nil
        }

        let input = self.input
        let output = style.format(input)

        guard let next = isIncreasing
                ? style.discreteInput(after: input)
                : style.discreteInput(before: input) else {
            self.abort = true
            return (input, output)
        }

        self.input = advance(input, next) ?? input

        if isIncreasing && !isLower(input, self.input) || !isIncreasing && !isLower(self.input, input) {
            self.abort = true
        }

        return (input, output)
    }
}

/// Verify that `sequence` contains the `expectedExcerpts` as non-overlapping subsequences.
func verify<T: Equatable>(
    sequence: some Sequence<T>,
    contains expectedExcerpts: some Sequence<some Sequence<T>>,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    var iterator = sequence.makeIterator()

    for expectedSequence in expectedExcerpts {
        var potentialMatches: [T] = []

        var expectedIterator = expectedSequence.makeIterator()

        guard let first = expectedIterator.next() else {
            continue
        }

        var next: T?
        while next != first {
            next = iterator.next()

            guard let next = next else {
                XCTFail("Expected '\(first)' but found \(potentialMatches.map { "\($0)" }.joined(separator: ", ")) instead \(message())", file: file, line: line)
                break
            }

            potentialMatches.append(next)
        }

        while let expected = expectedIterator.next() {
            let next = iterator.next()
            XCTAssertEqual(next, expected, message(), file: file, line: line)
            if next != expected {
                return
            }
        }
    }
}

/// Verify that a discrete format style fulfills the protocol requirements.
///
/// Takes random samples and verifies that the given `style` implementation behaves as expected for
/// types conforming to `DiscreteFormatStyle`.
///
/// - Parameter strict: If true, the test also fails if it finds a sample where the bounds provided by
/// `discreteInput(before:)` and `discreteInput(after:)` are shorter than they could
/// be, i.e. `style.format(style.discreteInput(after: sample)) == style.format(sample)`.
/// - Parameter samples: The number of random samples to verify.
func verifyDiscreteFormatStyleConformance<Style: DiscreteFormatStyle>(
    _ style: Style,
    strict: Bool = false,
    samples: Int = 10000,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) throws where Style.FormatOutput : Equatable, Style.FormatInput == Duration {
    try verifyDiscreteFormatStyleConformance(
        style,
        samples: samples,
        randomInput: { range in
            if let range {
                return range.lowerBound + (range.upperBound - range.lowerBound) * Double.random(in: 0..<1)
            } else {
                return .seconds(Double.randomSample(max: Double(Int64.max).nextDown))
            }
        },
        isLower: <,
        min: .seconds(Int64.min),
        max: .seconds(Int64.max),
        codeFormatter: { "Duration(secondsComponent: \($0.components.seconds), attosecondsComponent: \($0.components.attoseconds))" },
        message(),
        file: file,
        line: line
    )
}

/// Verify that a discrete format style fulfills the protocol requirements.
///
/// Takes random samples and verifies that the given `style` implementation behaves as expected for
/// types conforming to `DiscreteFormatStyle`.
///
/// - Parameter strict: If true, the test also fails if it finds a sample where the bounds provided by
/// `discreteInput(before:)` and `discreteInput(after:)` are shorter than they could
/// be, i.e. `style.format(style.discreteInput(after: sample)) == style.format(sample)`.
/// - Parameter samples: The number of random samples to verify.
/// ````
func verifyDiscreteFormatStyleConformance<Style: DiscreteFormatStyle>(
    _ style: Style,
    strict: Bool = false,
    samples: Int = 10000,
    min: Date = Date(timeIntervalSinceReferenceDate: -2000 * 365 * 24 * 3600),
    max: Date = Date(timeIntervalSinceReferenceDate: 2000 * 365 * 24 * 3600),
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) throws where Style.FormatOutput : Equatable, Style.FormatInput == Date {
    try verifyDiscreteFormatStyleConformance(
        style,
        samples: samples,
        randomInput: { range in
            if let range {
                return Date(timeIntervalSinceReferenceDate: Double.random(in: range.lowerBound.timeIntervalSinceReferenceDate..<range.upperBound.timeIntervalSinceReferenceDate))
            } else {
                return Date(timeIntervalSinceReferenceDate: Double.randomSample(max: 2000 * 365 * 24 * 3600))
            }
        },
        isLower: <,
        min: min,
        max: max,
        codeFormatter: { "Date(timeIntervalSinceReferenceDate: \($0.timeIntervalSinceReferenceDate))" },
        message(),
        file: file,
        line: line
    )
}

#if FOUNDATION_FRAMEWORK
/// Verify that a discrete format style fulfills the protocol requirements.
///
/// Takes random samples and verifies that the given `style` implementation behaves as expected for
/// types conforming to `DiscreteFormatStyle`.
///
/// - Parameter strict: If true, the test also fails if it finds a sample where the bounds provided by
/// `discreteInput(before:)` and `discreteInput(after:)` are shorter than they could
/// be, i.e. `style.format(style.discreteInput(after: sample)) == style.format(sample)`.
/// - Parameter samples: The number of random samples to verify.
/// ````
func verifyDiscreteFormatStyleConformance(
    _ style: Date.ComponentsFormatStyle,
    strict: Bool = false,
    samples: Int = 10000,
    now: Date = .now,
    min: Date = Date(timeIntervalSinceReferenceDate: -2000 * 365 * 24 * 3600),
    max: Date = Date(timeIntervalSinceReferenceDate: 2000 * 365 * 24 * 3600),
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    var style = style

    try verifyDiscreteFormatStyleConformance(
        style,
        samples: samples,
        randomInput: { range in
            if let range {
                return Swift.min(range.lowerBound.lowerBound, range.upperBound.lowerBound)..<Date(timeIntervalSinceReferenceDate: Double.random(in: range.lowerBound.upperBound.timeIntervalSinceReferenceDate..<range.upperBound.upperBound.timeIntervalSinceReferenceDate))
            } else {
                let bound = now + abs(Double.randomSample(max: max.timeIntervalSince(now)))

                return now..<bound
            }
        },
        isLower: { $0.upperBound < $1.upperBound },
        min: now..<now,
        max: now..<max,
        codeFormatter: { "Date(timeIntervalSinceReferenceDate: \($0.lowerBound.timeIntervalSinceReferenceDate))..<Date(timeIntervalSinceReferenceDate: \($0.upperBound.timeIntervalSinceReferenceDate))" },
        message() + "\nstyle.isPositive = true",
        file: file,
        line: line
    )

    style.isPositive = false

    try verifyDiscreteFormatStyleConformance(
        style,
        samples: samples,
        randomInput: { range in
            if let range {
                return Date(timeIntervalSinceReferenceDate: Double.random(in: range.lowerBound.lowerBound.timeIntervalSinceReferenceDate..<range.upperBound.lowerBound.timeIntervalSinceReferenceDate))..<Swift.max(range.lowerBound.upperBound, range.upperBound.upperBound)
            } else {
                let bound = now - abs(Double.randomSample(max: now.timeIntervalSince(min)))

                return bound..<now
            }
        },
        isLower: { $0.lowerBound < $1.lowerBound },
        min: min..<now,
        max: now..<now,
        codeFormatter: { "Date(timeIntervalSinceReferenceDate: \($0.lowerBound.timeIntervalSinceReferenceDate))..<Date(timeIntervalSinceReferenceDate: \($0.upperBound.timeIntervalSinceReferenceDate))" },
        message() + "\nstyle.isPositive = false",
        file: file,
        line: line
    )
}
#endif // FOUNDATION_FRAMEWORK

/// Verify that a discrete format style fulfills the protocol requirements.
///
/// Takes random samples and verifies that the given `style` implementation behaves as expected for
/// types conforming to `DiscreteFormatStyle`.
///
/// - Parameter strict: If true, the test also fails if it finds a sample where the bounds provided by
/// `discreteInput(before:)` and `discreteInput(after:)` are shorter than they could
/// be, i.e. `style.format(style.discreteInput(after: sample)) == style.format(sample)`.
/// - Parameter samples: The number of random samples to verify.
func verifyDiscreteFormatStyleConformance<Style: DiscreteFormatStyle>(
    _ style: Style,
    strict: Bool = false,
    samples: Int = 10000,
    randomInput: ((lowerBound: Style.FormatInput, upperBound: Style.FormatInput)?) -> Style.FormatInput,
    isLower: (Style.FormatInput, Style.FormatInput) -> Bool,
    min: Style.FormatInput,
    max: Style.FormatInput,
    codeFormatter: (Style.FormatInput) -> String,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) throws where Style.FormatOutput : Equatable, Style.FormatInput : Equatable {
    func _message(assertion: Assertion, before: Bool, inputValue: Style.FormatInput, expectedValue: Style.FormatInput?, note: String) -> String {
        let message = message()
        let prefix = (message.isEmpty ? "\(note)" : "\(message): \(note)") + "\n"

        let reason: String
        if let expectedValue {
            if assertion == .greaterEqual || assertion == .lowerEqual {
                if let discreteInput = before ? style.discreteInput(before: inputValue) : style.discreteInput(after: inputValue),
                   let nextInput = before ? style.input(after: discreteInput) : style.input(before: discreteInput) {
                    reason = """
                    style.discreteInput(\(before ? "before" : "after"): \(codeFormatter(inputValue))) returned \(codeFormatter(discreteInput)), but
                    \(codeFormatter(expectedValue)), which is a valid input, because style.input(\(before ? "after" : "before"): \(codeFormatter(discreteInput))) = \(codeFormatter(nextInput)),
                    already produces a different formatted output '\(style.format(expectedValue))' compared to style.format(\(codeFormatter(inputValue))), which is '\(style.format(inputValue))'
                    """
                } else {
                    reason = ""
                }
            } else {
                reason = "invalid ordering or short bound"
            }
        } else {
            reason = """
            style.discreteInput(\(before ? "before" : "after"): \(codeFormatter(inputValue))) returned nil, but
            style.format(\(codeFormatter(inputValue))) = '\(style.format(inputValue))', which is different from
            style.format(\(codeFormatter(before ? min : max))) = '\(style.format(before ? min : max))'
            """
        }

        return prefix + """
        XCTAssert\(assertion.rawValue)(try XCTUnwrap(style.discreteInput(\(before ? "before" : "after"): \(codeFormatter(inputValue)))), \(expectedValue == nil ? "nil" : codeFormatter(expectedValue!)))

        \(reason)
        """
    }

    func nextUp(_ input: Style.FormatInput) throws -> Style.FormatInput {
        try XCTUnwrap(style.input(after: input), "\(message().isEmpty ? "" : message() + "\n")XCTAssertNotNil(style.input(after: \(codeFormatter(input))))", file: file, line: line)
    }

    func nextDown(_ input: Style.FormatInput) throws -> Style.FormatInput {
        try XCTUnwrap(style.input(before: input), "\(message().isEmpty ? "" : message() + "\n")XCTAssertNotNil(style.input(before: \(codeFormatter(input))))", file: file, line: line)
    }

    for _ in 0..<samples {
        let input = randomInput(nil)
        let output = style.format(input)

        guard let inputAfter = style.discreteInput(after: input) else {
            // if `inputAfter` is `nil`, we should get the same formatted output everywhere between `input` and `max`
            XCTAssertEqual(style.format(max), output, _message(assertion: .unequal, before: false, inputValue: input, expectedValue: nil, note: "invalid upper bound"), file: file, line: line)
            return
        }

        // check for invalid ordering
        guard isLower(input, inputAfter) else {
            XCTFail(_message(assertion: .greater, before: false, inputValue: input, expectedValue: input, note: "invalid ordering"), file: file, line: line)
            return
        }

        guard let inputBefore = style.discreteInput(before: input) else {
            // if `inputBefore` is `nil`, we should get the same formatted output everywhere between `input` and `min`
            XCTAssertEqual(style.format(min), output, _message(assertion: .unequal, before: true, inputValue: input, expectedValue: nil, note: "invalid lower bound"), file: file, line: line)
            return
        }

        // check for invalid ordering
        guard isLower(inputBefore, input) else {
            XCTFail(_message(assertion: .lower, before: true, inputValue: input, expectedValue: input, note: "invalid ordering"), file: file, line: line)
            return
        }

        // check that all values in `nextUp(inputBefore)...nextDown(inputAfter)` produce the same formatted output as `input`
        let lowerSampleBound = try nextUp(inputBefore)
        let upperSampleBound = try nextDown(inputAfter)
        if !isLower(upperSampleBound, lowerSampleBound), lowerSampleBound != upperSampleBound {
            for check in [lowerSampleBound] + (0..<10).map({ _ in randomInput((lowerSampleBound, upperSampleBound)) }) + [upperSampleBound] {
                if isLower(check, input) {
                    guard style.format(check) == output else {
                        XCTFail(_message(assertion: .greaterEqual, before: true, inputValue: input, expectedValue: check, note: "invalid lower bound"), file: file, line: line)
                        return
                    }
                } else {
                    guard style.format(check) == output else {
                        XCTFail(_message(assertion: .lowerEqual, before: false, inputValue: input, expectedValue: check, note: "invalid upper bound"), file: file, line: line)
                        return
                    }
                }
            }
        }

        // if strict checking is enabled, we also check that the formatted output for `inputAfter` and `inputBefore` is indeed different from `format(input)`
        if strict {
            guard style.format(inputAfter) != output else {
                XCTFail(_message(assertion: .greater, before: false, inputValue: input, expectedValue: inputAfter, note: "short upper bound (strict)"), file: file, line: line)
                return
            }

            guard style.format(inputBefore) != output else {
                XCTFail(_message(assertion: .lower, before: true, inputValue: input, expectedValue: inputBefore, note: "short lower bound (strict)"), file: file, line: line)
                return
            }
        }
    }
}

private enum Assertion: String {
    case equal = "Equal"
    case unequal = "NotEqual"
    case lower = "LessThan"
    case greater = "GreaterThan"
    case greaterEqual = "GreaterThanOrEqual"
    case lowerEqual = "LessThanOrEqual"
}

private extension Double {
    // Produces random samples between -max and +max with an approximately uniform
    // distribution over the number's _magnitude_, i.e. it will produce approximately
    // the same number of samples in the range 0..<1 as in the range 1000..<10000.
    static func randomSample(max: Double) -> Double {
        let d = 10.0
        let r = pow(d, Double.random(in: 0..<((log(max) + log(1 + (1.0/max))) / log(d)))) - 1
        return Bool.random() ? r : -r
    }
}
