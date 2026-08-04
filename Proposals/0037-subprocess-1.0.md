# Subprocess 1.0 Update

* Proposal: [SF-0037](0037-subprocess-1.0.md)
* Authors: [Charles Hu](https://github.com/iCharlesHu)
* Review Manager: [Tina Liu](https://github.com/itingliu)
* Status: **Second review: 2026-07-10...2026-07-17**
* Implementation: https://github.com/swiftlang/swift-subprocess

## Introduction

We introduced Subprocess with SF-0007 and shipped swift-subprocess as a public beta in Spring 2025. Since then, we've received a considerable amount of feedback from the community and updated the Subprocess API to address it. This proposal covers all API changes made since SF-0007 and proposes them for inclusion in the Subprocess 1.0 API.


## Collapse the `run()` Overloads Behind a Generic `Execution` Type

In SF-0007, `Execution` is generic over its `Output` and `Error` types, exposing `standardOutput` and `standardError` as conditional properties available only when the corresponding stream is redirected to a sequence. Writing to the child's standard input, however, is handled differently: it requires a *separate* family of `run()` overloads whose body closure receives an extra `StandardInputWriter` argument. This means standard input is handled out of step with the other two streams, and every combination of "writes to standard input or not" needs its own closure-based overload. This design created a combinatory explosion of `run()` overloads.

We propose unifying all three standard streams by making `Execution` generic over its `Input` type as well. The body closure now receives a single `Execution<Input, Output, Error>` value, and type-conditional extensions expose `standardInputWriter`, `standardOutput`, and `standardError` only for the matching stream types:

```swift
/// A running subprocess.
///
/// The three generic parameters determine which streaming properties are
/// available. The ``standardInputWriter`` property is available when `Input`
/// is ``CustomWriteInput``, the ``standardOutput`` property is available
/// when `Output` is ``SequenceOutput``, and the ``standardError`` property
/// is available when `Error` is ``SequenceOutput``.
public struct Execution<
    Input: InputProtocol,
    Output: OutputProtocol,
    Error: OutputProtocol
>: Sendable {
    /// The process identifier of this subprocess.
    public let processIdentifier: ProcessIdentifier
}

extension Execution where Input == CustomWriteInput {
    /// A writer that sends data to the subprocess's standard input.
    public var standardInputWriter: StandardInputWriter { get }
}

extension Execution where Output == SequenceOutput {
    /// The standard output of the subprocess as an asynchronous sequence of buffers.
    public var standardOutput: SubprocessOutputSequence { get }
}

extension Execution where Error == SequenceOutput {
    /// The standard error of the subprocess as an asynchronous sequence of buffers.
    public var standardError: SubprocessOutputSequence { get }
}
```

To support this, the previously internal `CustomWriteInput` and `SequenceOutput` types, along with their `.inputWriter` and `.sequence` factories, are now public. Callers opt in to each stream independently:

- `input: .inputWriter` allows you to use `execution.standardInputWriter`;
- `output: .sequence` allows you to use `execution.standardOutput`;
- `error: .sequence` allows you to use `execution.standardError`.

This also lets the closure-based `run()` overloads collapse to a single closure form per `Executable` and `Configuration`:

```swift
// Before (SF-0007): writing to standard input required a dedicated overload
// whose closure took an extra `StandardInputWriter`.
let result = try await run(.path("/bin/cat"), output: .sequence) { execution, writer in
    _ = try await writer.write("Hello, world")
    try await writer.finish()
    for try await chunk in execution.standardOutput { ... }
}

// After: a single closure form. Opt in with `input: .inputWriter` and reach
// the writer through `execution.standardInputWriter`.
let result = try await run(
    .path("/bin/cat"),
    input: .inputWriter,
    output: .sequence,
    error: .discarded
) { execution in
    _ = try await execution.standardInputWriter.write("Hello, world")
    try await execution.standardInputWriter.finish()
    for try await chunk in execution.standardOutput { ... }
}
```

Because SF-0007 already exposed `standardOutput` and `standardError` as conditional properties on `Execution`, this restructuring leaves most call sites untouched: reading a subprocess's output or error still means iterating `execution.standardOutput` (or `execution.standardError`), exactly as before. The visible change is concentrated on standard *input*. Where SF-0007 made you choose the dedicated overload that passed a `StandardInputWriter` as a second closure argument, you now opt in with `input: .inputWriter` and reach the same writer through `execution.standardInputWriter`. A call site that only reads output and error needs no changes at all.

The complete `run()` family is now:

```swift
// MARK: - Executable based

/// Runs an executable asynchronously and returns the collected output
/// of the child process.
public func run<
    Input: InputProtocol,
    Output: OutputProtocol,
    Error: ErrorOutputProtocol
>(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    input: Input = .none,
    output: Output,
    error: Error = .discarded
) async throws -> ExecutionResult<Void, Output, Error>

/// Runs an executable asynchronously, writing the given `Span` to its
/// standard input, and returns the collected output of the child process.
public func run<
    InputElement: BitwiseCopyable,
    Output: OutputProtocol,
    Error: ErrorOutputProtocol
>(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    input: borrowing Span<InputElement>,
    output: Output,
    error: Error = .discarded
) async throws -> ExecutionResult<Void, Output, Error>

/// Runs an executable asynchronously and lets a closure manage the running
/// subprocess. The subprocess must terminate before this method returns.
public func run<
    Result: ~Copyable,
    Input: InputProtocol,
    Output: OutputProtocol,
    Error: ErrorOutputProtocol
>(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    input: Input,
    output: Output,
    error: Error,
    body: (Execution<Input, Output, Error>) async throws -> Result
) async throws -> ExecutionResult<Result, Output, Error>

// MARK: - Configuration based

/// Runs a configuration asynchronously and returns the collected output
/// of the child process.
public func run<
    Input: InputProtocol,
    Output: OutputProtocol,
    Error: ErrorOutputProtocol
>(
    _ configuration: Configuration,
    input: Input = .none,
    output: Output,
    error: Error = .discarded
) async throws -> ExecutionResult<Void, Output, Error>

/// Runs a configuration asynchronously, writing the given `Span` to its
/// standard input, and returns the collected output of the child process.
public func run<
    InputElement: BitwiseCopyable,
    Output: OutputProtocol,
    Error: ErrorOutputProtocol
>(
    _ configuration: Configuration,
    input: borrowing Span<InputElement>,
    output: Output,
    error: Error = .discarded
) async throws -> ExecutionResult<Void, Output, Error>

/// Runs a configuration asynchronously and lets a closure manage the running
/// subprocess. The subprocess must terminate before this method returns.
public func run<
    Result: ~Copyable,
    Input: InputProtocol,
    Output: OutputProtocol,
    Error: ErrorOutputProtocol
>(
    _ configuration: Configuration,
    input: Input,
    output: Output,
    error: Error,
    body: (Execution<Input, Output, Error>) async throws -> Result
) async throws -> ExecutionResult<Result, Output, Error>
```

Note that the closure-based overloads require explicit `input`, `output`, and `error` arguments (they have no default values) so the compiler can determine which streaming properties the `Execution` value exposes. The collected overloads keep the familiar `input: .none` and `error: .discarded` defaults.


## Unify Result Types into `ExecutionResult`

SF-0007 exposes two distinct result types: `CollectedResult<Output, Error>` for the non-closure `run()` methods, and `ExecutionResult<Result>` for the closure-based ones. Now that `Execution` is generic over its `Input`, `Output`, and `Error` types, both result shapes can be represented by a single generic type. We propose removing `CollectedResult` and folding everything into `ExecutionResult`:

```swift
/// The result of running a subprocess, including the closure's return value,
/// collected standard output, and collected standard error.
public struct ExecutionResult<
    ClosureResult: Sendable & ~Copyable,
    Output: OutputProtocol,
    Error: OutputProtocol
>: Sendable, ~Copyable {
    /// The process identifier of the subprocess.
    public let processIdentifier: ProcessIdentifier
    /// The termination status of the subprocess.
    public let terminationStatus: TerminationStatus

    /// The collected standard output of the subprocess.
    public let standardOutput: Output.OutputType
    /// The collected standard error of the subprocess.
    public let standardError: Error.OutputType

    /// The value returned by the body closure passed to `run`.
    public let closureResult: ClosureResult
}

extension ExecutionResult where ClosureResult: ~Copyable {
    /// Consumes this result and returns the value produced by the `run` body closure.
    public consuming func takeClosureResult() -> ClosureResult
}

extension ExecutionResult: Copyable where ClosureResult: Copyable {}

extension ExecutionResult: Equatable
where Output.OutputType: Equatable, Error.OutputType: Equatable, ClosureResult: Equatable {}

extension ExecutionResult: Hashable
where Output.OutputType: Hashable, Error.OutputType: Hashable, ClosureResult: Hashable {}

extension ExecutionResult: CustomStringConvertible
where Output.OutputType: CustomStringConvertible, Error.OutputType: CustomStringConvertible {}

extension ExecutionResult: CustomDebugStringConvertible
where Output.OutputType: CustomDebugStringConvertible, Error.OutputType: CustomDebugStringConvertible {}
```

The `ClosureResult` generic parameter is `Void` when you call a collected `run()` overload that doesn't take a `body` closure, and is the closure's return type otherwise. You read the closure's return value through the `closureResult` property. Because the closure's return value is already required to be `Sendable`, `ExecutionResult` is unconditionally `Sendable`.

This change, combined with collapsed `run()` functions mentioned above, allowed us to drastically reduce the number of `run()` overloads because we no longer have a combinatorial explosion problem. It also enabled developers to collect and stream child process output at the same time, which was previously not possible due to the two "result" type separation:

```swift
let result = try await run(
    .path("/my/app"),
    input: .none,
    output: .sequence,
    error: .string(limit: 4096)
) { execution in
    var lineCount = 0
    for try await _ in execution.standardOutput.strings() {
        lineCount += 1
    }
    return lineCount
}

print(result.closureResult)  // The line count returned from the closure (streaming output).
print(result.standardError)  // The captured standard error (collected output).
```


## Allow `run()` Body Closures to Return Noncopyable Values

In SF-0007, the value returned by a `run()` body closure had to be `Copyable`. We propose relaxing this so a closure can hand back a *noncopyable* (`~Copyable`) value. The `Result` type parameter of the closure-based `run()` overloads is therefore now `~Copyable`:

```swift
public func run<
    Result: ~Copyable,
    Input: InputProtocol,
    Output: OutputProtocol,
    Error: ErrorOutputProtocol
>(
    _ executable: Executable,
    ...
    body: (Execution<Input, Output, Error>) async throws -> Result
) async throws -> ExecutionResult<Result, Output, Error>
```

`ExecutionResult` carries the closure's return value in its `closureResult` property, so `ExecutionResult` itself is `~Copyable` and is `Copyable` exactly when its `ClosureResult` is. Code that returns ordinary copyable values is unaffected. When the closure returns a noncopyable value, move it out of the result with the consuming `takeClosureResult()` method:

```swift
struct MoveOnlyResource: ~Copyable { /* ... */ }

let result = try await run(
    .path("/usr/bin/my-tool"),
    input: .none,
    output: .discarded,
    error: .discarded
) { execution -> MoveOnlyResource in
    // ... build a move-only resource from the running subprocess
    return MoveOnlyResource()
}

// `result` is noncopyable because `MoveOnlyResource` is.
let resource = result.takeClosureResult()
```


## Introduce `SubprocessOutputSequence`

In SF-0007, `Execution.standardOutput` and `Execution.standardError` return an opaque `some AsyncSequence<Buffer, any Swift.Error>`, where the element type is nested as `SequenceOutput.Buffer`. We propose replacing the opaque return type with a concrete, public `SubprocessOutputSequence`, and re-nesting the element type under it as `SubprocessOutputSequence.Buffer`. Exposing a concrete type lets us attach higher-level helpers, such as the line-based string decoding described in the next section, directly to the output stream.

```swift
/// An asynchronous sequence of buffers that streams output from a subprocess.
public struct SubprocessOutputSequence: AsyncSequence, Sendable {
    /// The failure type for the asynchronous sequence.
    public typealias Failure = any Swift.Error
    /// The element type for the asynchronous sequence.
    public typealias Element = Buffer

    /// An iterator for ``SubprocessOutputSequence``.
    public struct Iterator: AsyncIteratorProtocol {
        /// The element type for the iterator.
        public typealias Element = Buffer

        /// Retrieves the next buffer in the sequence, or `nil` if the sequence ended.
        public mutating func next(isolation actor: isolated (any Actor)?) async throws -> Buffer?
        /// Retrieves the next buffer in the sequence, or `nil` if the sequence ended.
        public mutating func next() async throws -> Buffer?
    }

    /// Creates an iterator for this asynchronous sequence.
    public func makeAsyncIterator() -> Iterator
}

@available(*, unavailable)
extension SubprocessOutputSequence.Iterator: Sendable {}
```

`SubprocessOutputSequence` owns the underlying OS pipe, so it is single-pass: calling `makeAsyncIterator()` more than once traps. The buffer size used when reading from the pipe is derived automatically from the platform's pipe buffer size.

The element type, `Buffer`, remains an immutable collection of bytes whose primary accessor is a `RawSpan`:

```swift
extension SubprocessOutputSequence {
    /// An immutable collection of bytes.
    public struct Buffer: Sendable {
        /// The number of bytes in the buffer.
        public var count: Int { get }

        /// A Boolean value indicating whether the collection is empty.
        public var isEmpty: Bool { get }

        /// Accesses the raw bytes stored in this buffer.
        public func withUnsafeBytes<ResultType, Error: Swift.Error>(
            _ body: (UnsafeRawBufferPointer) throws(Error) -> ResultType
        ) throws(Error) -> ResultType

        /// Accesses the bytes stored in this buffer as a `RawSpan`.
        public var bytes: RawSpan { get }
    }
}
```

When the `SubprocessFoundation` trait is enabled, `Data` gains an initializer that copies from a buffer:

```swift
#if SubprocessFoundation
extension Data {
    /// Creates a `Data` value from a buffer.
    public init(buffer: SubprocessOutputSequence.Buffer)
}
#endif
```


## Introduce `SubprocessOutputSequence.StringSequence`

SF-0007 only includes a way to stream a sequence of `Buffer`s. This makes streaming text difficult since naively converting each `Buffer` to a `String` may not always succeed if the `Buffer` happens to split a multi-byte character. Since streaming text is one of the most common use cases for `Subprocess`, we propose introducing a new `SubprocessOutputSequence.StringSequence` specifically designed to parse and partition an asynchronous sequence of buffers into Strings. Developers have the option to split the buffers into Strings by line breaks or by a custom sequence of Unicode scalars. Developers can also optionally specify a `String` encoding and a `BufferingPolicy` to control how `StringSequence` handles the exhaustion of a buffer's capacity.

```swift
extension SubprocessOutputSequence {
    /// An asynchronous sequence of strings parsed from a buffer
    /// sequence.
    ///
    /// By default, the sequence splits on Unicode line break
    /// characters. You can supply a custom separator with the
    /// ``Separator/unicodeScalarSequence(_:)`` factory method.
    ///
    /// The following Unicode characters are recognized as line
    /// breaks:
    /// ```
    /// LF:    Line Feed, U+000A
    /// VT:    Vertical Tab, U+000B
    /// FF:    Form Feed, U+000C
    /// CR:    Carriage Return, U+000D
    /// CR+LF: CR (U+000D) followed by LF (U+000A)
    /// NEL:   Next Line, U+0085
    /// LS:    Line Separator, U+2028
    /// PS:    Paragraph Separator, U+2029
    /// ```
    ///
    /// The separator characters aren't included in the returned
    /// strings, similar to how `.split(separator:)` works.
    ///
    /// When you use a custom separator created with
    /// ``Separator/unicodeScalarSequence(_:)``, the sequence performs a
    /// code-unit-level comparison without Unicode normalization.
    /// See ``Separator/unicodeScalarSequence(_:)`` for details.
    public struct StringSequence<Encoding: _UnicodeEncoding & Sendable>: AsyncSequence, Sendable {
        /// The element type for the asynchronous sequence.
        public typealias Element = String

         /// The iterator for line sequence.
        public struct AsyncIterator: AsyncIteratorProtocol {
            /// The element type for this Iterator.
            public typealias Element = String

            /// Retrieves the next line, or returns nil if the sequence ends.
            public mutating func next(isolation actor: isolated (any Actor)?) async throws -> String?
            /// Retrieves the next line, or returns nil if the sequence ends.
            public mutating func next() async throws -> String?
        }

        /// Creates an iterator for this line sequence.
        public func makeAsyncIterator() -> AsyncIterator
    }
}

@available(*, unavailable)
extension SubprocessOutputSequence.StringSequence.AsyncIterator: Sendable {}

extension SubprocessOutputSequence.StringSequence {
    /// A strategy that handles the exhaustion of a buffer’s capacity.
    public enum BufferingPolicy: Sendable {
        /// Continue to add to the buffer, without imposing a limit
        /// on the number of buffered elements (line length).
        case unbounded
        /// Impose a max buffer size (line length) limit.
        /// Subprocess **will throw an error** if the number of buffered
        /// elements (line length) exceeds the limit
        case maxLineLength(Int)
    }

    /// A delimiter that determines where a ``StringSequence``
    /// splits its input.
    public struct Separator: Sendable, Hashable {
        /// Splits on Unicode line break characters.
        /// The following Unicode characters are recognized as line
        /// breaks:
        /// ```
        /// LF:    Line Feed, U+000A
        /// VT:    Vertical Tab, U+000B
        /// FF:    Form Feed, U+000C
        /// CR:    Carriage Return, U+000D
        /// CR+LF: CR (U+000D) followed by LF (U+000A)
        /// NEL:   Next Line, U+0085
        /// LS:    Line Separator, U+2028
        /// PS:    Paragraph Separator, U+2029
        /// ```
        public static var lineBreaks: Self

        /// Splits on a custom sequence of Unicode scalars.
        ///
        /// ``StringSequence`` encodes the scalars into their code unit
        /// representation and matches against the raw bytes in the
        /// buffer. Unlike `String` comparison, this match doesn't
        /// apply Unicode normalization. For example, "é" encoded
        /// as U+00E9 (precomposed) doesn't match "é" encoded as
        /// U+0065 U+0301 (decomposed). Make sure the separator
        /// scalars use the same representation as the input data.
        ///
        /// - Parameter separators: The scalars that form
        ///   the delimiter.
        /// - Returns: A separator that matches the given
        ///   scalar sequence.
        public static func unicodeScalarSequence(
            _ separators: some Sequence<Unicode.Scalar>
        ) -> Self

        /// Splits on a custom sequence of Unicode scalars.
        ///
        /// ``StringSequence`` encodes the scalars into their code unit
        /// representation and matches against the raw bytes in the
        /// buffer. Unlike `String` comparison, this match doesn't
        /// apply Unicode normalization. For example, "é" encoded
        /// as U+00E9 (precomposed) doesn't match "é" encoded as
        /// U+0065 U+0301 (decomposed). Make sure the separator
        /// scalars use the same representation as the input data.
        ///
        /// - Parameter separators: The scalars that form
        ///   the delimiter.
        /// - Returns: A separator that matches the given
        ///   scalar sequence.
        public static func unicodeScalarSequence(
            _ separators: Array<Unicode.Scalar>
        ) -> Self
    }
}

extension SubprocessOutputSequence {
    /// Splits the buffer into strings using the specified separator.
    ///
    /// - Parameters:
    ///   - separator: The delimiter to split on. The default
    ///     value is `.lineBreaks`.
    ///   - bufferingPolicy: The strategy for handling
    ///     back-pressure. The default value is
    ///     `.maxLineLength(128 * 1024)`.
    /// - Returns: A ``StringSequence`` that iterates through
    ///   the buffer contents as strings.
    public func strings(
        separatedBy separator: StringSequence<UTF8>.Separator = .lineBreaks,
        bufferingPolicy: StringSequence<UTF8>.BufferingPolicy = .maxLineLength(128 * 1024),
    ) -> StringSequence<UTF8>

    /// Splits the buffer into strings with the given encoding
    /// and separator.
    ///
    /// - Parameters:
    ///   - separator: The delimiter to split on. The default
    ///     value is `.lineBreaks`.
    ///   - bufferingPolicy: The strategy for handling
    ///     back-pressure. The default value is
    ///     `.maxLineLength(128 * 1024)`.
    ///   - encoding: The Unicode encoding to decode with.
    /// - Returns: A ``StringSequence`` that iterates through
    ///   the buffer contents as strings.
    public func strings<Encoding: _UnicodeEncoding & Sendable>(
        separatedBy separator: StringSequence<Encoding>.Separator = .lineBreaks,
        bufferingPolicy: StringSequence<Encoding>.BufferingPolicy = .maxLineLength(128 * 1024),
        as encoding: Encoding.Type,
    ) -> StringSequence<Encoding>
}
```

`StringSequence` is created by calling `.strings()` on `execution.standardOutput` or `execution.standardError`.

```swift
// Monitor Nginx log via `tail -f`
let monitorResult = try await Subprocess.run(
    .path("/usr/bin/tail"),
    arguments: ["-f", "/path/to/nginx.log"],
    output: .sequence,
    error: .discarded
) { execution in
    for try await line in execution.standardOutput.strings() {
        // Parse the log text line by line
        if line.contains("500") {
            // Oh no, 500 error
        }
    }
}
```


## Narrow `StringOutput` to a Non-Optional `String`

In SF-0007, the `StringOutput` type declared its `OutputType` as an *optional* `String?`, since converting raw bytes to String may not always succeed due to invalid bytes. This design decision meant that developers would always have to pay the cost of unwrapping the collected string value, even if it succeeds most of the time. We propose narrowing `StringOutput` to a non-optional `String` and using `String(decoding:as:)` as the underlying method to construct the `String`s:

```swift
public struct StringOutput<Encoding: Unicode.Encoding>: OutputProtocol, ErrorOutputProtocol {
    public typealias OutputType = String
    ...
}
```

`String(decoding:as:)` always succeeds and replaces invalid bytes with the Unicode replacement character (U+FFFD). Developers could still detect the replacement character if they wish to, while the majority of use cases no longer have to pay the price of unwrapping.

```swift
// Before (SF-0007): `standardOutput` is `String?`, so every access unwraps first.
let result = try await run(
    .path("/bin/echo"),
    arguments: ["Hello, world!"],
    output: .string(limit: 1024)
)
guard let output = result.standardOutput else { return }
print(output.trimmingCharacters(in: .whitespacesAndNewlines))
// ...or the equally common `(result.standardOutput ?? "").trimming...`
// and `result.standardOutput?.trimming...` idioms.

// After: `standardOutput` is a non-optional `String`.
let result = try await run(
    .path("/bin/echo"),
    arguments: ["Hello, world!"],
    output: .string(limit: 1024)
)
print(result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines))
```


## Adopt `NonisolatedNonsendingByDefault`

We propose adopting the new Swift upcoming feature `NonisolatedNonsendingByDefault`, which allows us to remove all existing `#isolation` parameters from the closure-based `run()` overloads:

```diff
 public func run<
     Result: ~Copyable,
     Input: InputProtocol,
     Output: OutputProtocol,
     Error: ErrorOutputProtocol
 >(
     _ executable: Executable,
     ...
     input: Input,
     output: Output,
     error: Error,
-    isolation: isolated (any Actor)? = #isolation,
     body: (Execution<Input, Output, Error>) async throws -> Result
 ) async throws -> ExecutionResult<Result, Output, Error>
```


## Introduce `Environment.Key`

Environment keys have different case sensitivity requirements on different platforms. For example, keys are case-insensitive on Windows and case-sensitive on other platforms. We propose replacing raw `String` environment keys with a dedicated `Environment.Key` type. `Environment.Key` is designed to correctly respect each platform's case sensitivity requirements; it is also `ExpressibleByStringLiteral` for easy initialization.

```swift
extension Environment {
    /// A key used to access values in an ``Environment``.
    ///
    /// This type respects the compiled platform's case sensitivity requirements.
    public struct Key: Codable, Hashable, ExpressibleByStringLiteral, Sendable {
        public var rawValue: String
    }
}

extension Environment.Key: CodingKeyRepresentable, Comparable, RawRepresentable, CustomStringConvertible { }
```

As a result, the `Environment` methods that previously took `[String: String]` now take `[Key: ...]`. `updating(_:)` additionally accepts `nil` values so an inherited variable can be removed before it's passed to the child process:

```swift
public struct Environment: Sendable, Hashable {
    public static var inherit: Self { get }
    /// A `nil` value removes the corresponding key from the inherited environment.
    public func updating(_ newValue: [Key: String?]) -> Self
    public static func custom(_ newValue: [Key: String]) -> Self
#if !os(Windows)
    public static func custom(_ newValue: [[UInt8]]) -> Self
#endif
}
```


## Introduce `CombinedErrorOutput` and `ErrorOutputProtocol`

Merging standard output and standard error into one stream, like shell redirection `2>&1`, is a common use case for Subprocess. We propose introducing a new concrete `CombinedErrorOutput` type that merges the standard error and standard output streams.

The original design uses one protocol, `OutputProtocol`, to define the child process's standard output and standard error behavior. This worked because up until now, all concrete output types could be used for either output or error. `CombinedErrorOutput`, as its name implies, can only be used with standard error to combine it with standard output. Consequently, we expanded the `OutputProtocol` hierarchy by introducing a new `ErrorOutputProtocol`. `ErrorOutputProtocol` conforms to `OutputProtocol` and introduces no new requirements. The `error:` parameter of `run()` is constrained to `ErrorOutputProtocol`. All of the built-in output types conform to both protocols, so they can still be used for either stream; only `CombinedErrorOutput` is error-only.

```swift
/// Error output protocol specifies the set of methods that a type must implement to
/// serve as the error output target for a subprocess.
///
/// Instead of developing custom implementations of `ErrorOutputProtocol`, use the
/// default implementations provided by the `Subprocess` library to specify the
/// output handling requirements.
public protocol ErrorOutputProtocol: OutputProtocol {}

/// A concrete error output type for subprocesses that combines the standard error
/// output with the standard output stream.
///
/// When `CombinedErrorOutput` is used as the error output for a subprocess, both
/// standard output and standard error from the child process are merged into a
/// single output stream. This is equivalent to using shell redirection like `2>&1`.
///
/// This output type is useful when you want to capture or redirect both output
/// streams together, making it possible to process all subprocess output as a unified
/// stream rather than handling standard output and standard error separately.
public struct CombinedErrorOutput: ErrorOutputProtocol {
    public typealias OutputType = Void
}

extension ErrorOutputProtocol where Self == CombinedErrorOutput {
    /// Creates an error output that combines standard error with standard output.
    ///
    /// When using `combinedWithOutput`, both standard output and standard error from
    /// the child process are merged into a single output stream. This is equivalent
    /// to using shell redirection like `2>&1`.
    ///
    /// This is useful when you want to capture or redirect both output streams
    /// together, making it possible to process all subprocess output as a unified
    /// stream rather than handling standard output and standard error separately
    ///
    /// - Returns: A `CombinedErrorOutput` instance that merges standard error
    ///   with standard output.
    public static var combinedWithOutput: Self
}
```

You can use `CombinedErrorOutput` like this:

```swift
let result = try await run(
    .path("/bin/sh"),
    arguments: ["-c", "echo Hello Stdout; echo Hello Stderr 1>&2"],
    output: .string(limit: 1024),
    error: .combinedWithOutput
)
```

`result.standardOutput` will print `Hello Stdout\nHello Stderr`.


## Expand `FileDescriptorOutput` and `FileDescriptorInput`

We propose expanding `FileDescriptorOutput` with two additional static properties, `.currentStandardOutput` and `.currentStandardError`, that redirect the child process's output to the parent process's standard output or standard error. This is useful when you want to follow along with the process output rather than capturing it.

```swift
extension OutputProtocol where Self == FileDescriptorOutput {
    /// Create a Subprocess output that writes output to the standard output of
    /// current process.
    ///
    /// The file descriptor isn't closed afterwards.
    public static var currentStandardOutput: Self

    /// Create a Subprocess output that writes output to the standard error of
    /// current process.
    ///
    /// The file descriptor isn't closed afterwards.
    public static var currentStandardError: Self
}
```

Symmetrically, `FileDescriptorInput` gains a `.standardInput` property that feeds the child the parent process's standard input:

```swift
extension InputProtocol where Self == FileDescriptorInput {
    /// Create a Subprocess input that reads from the standard input of
    /// the current process.
    ///
    /// The file descriptor isn't closed afterwards.
    public static var standardInput: Self
}
```


## Refine the Teardown Sequence

We propose two refinements to `TeardownStep`. First, we rename `.sendSignal(_:allowedDurationToNextStep:)` to `.send(signal:toProcessGroup:allowedDurationToNextStep:)`, adding a `toProcessGroup` parameter so a step can target the entire process group rather than just the child process. Second, we add the same `toProcessGroup` parameter to `.gracefulShutDown(...)` (and correct the misspelled `alloweDurationToNextStep` label).

```swift
public struct TeardownStep: Sendable, Hashable {
#if !os(Windows)
    /// Sends a signal to the process and waits for the specified duration
    /// before proceeding to the next step. The final step always sends `.kill`.
    public static func send(
        signal: Signal,
        toProcessGroup: Bool = false,
        allowedDurationToNextStep: Duration
    ) -> Self
#endif

    /// Attempts a graceful shutdown, waiting for the specified duration before
    /// proceeding to the next step.
    /// - On Unix: sends `SIGTERM`.
    /// - On Windows: sends `WM_CLOSE`, then `CTRL_C_EVENT`, then `CTRL_BREAK_EVENT`.
    public static func gracefulShutDown(
        toProcessGroup: Bool = false,
        allowedDurationToNextStep: Duration
    ) -> Self
}
```

When a teardown sequence targets the process group, the implicit final `.kill` step inherits `toProcessGroup` from the last explicit step, so descendants don't leak after teardown.

```swift
let result = try await run(
    .path("/bin/bash"),
    arguments: [...],
    output: .discarded,
    error: .discarded
) { execution in
    // ... more work
    await execution.teardown(using: [
        .send(signal: .quit, allowedDurationToNextStep: .milliseconds(100)),
        .send(signal: .terminate, allowedDurationToNextStep: .milliseconds(100)),
    ])
}
```


## Refine `PlatformOptions`

We propose several changes to `PlatformOptions` across platforms.

On all platforms, `PlatformOptions` no longer conforms to `Hashable`; it is now only `Sendable` (plus `CustomStringConvertible`/`CustomDebugStringConvertible`). The closure-valued "escape hatch" properties never had a meaningful `Hashable` implementation, so this conformance was misleading.

On Darwin, we remove the `launchRequirementData` property, which was never wired up to a supported launch path.

On Linux (and other non-Darwin Unix platforms), we remove `preSpawnProcessConfigurator` (`@convention(c) @Sendable () -> Void`) escape hatch, since we can't safely offer this API as it requires async-signal-safety. As a result, the non-Darwin Unix `PlatformOptions` is now:

```swift
public struct PlatformOptions: Sendable {
    public var userID: uid_t? = nil
    public var groupID: gid_t? = nil
    public var supplementaryGroups: [gid_t]? = nil
    public var processGroupID: pid_t? = nil
    public var createSession: Bool = false
    public var teardownSequence: [TeardownStep] = []

    public init() {}
}
```

The `preSpawnProcessConfigurator` escape hatch remains available on Darwin (operating on `posix_spawnattr_t`/`posix_spawn_file_actions_t`) and on Windows (operating on `dwCreationFlags`/`STARTUPINFOW`).

On Windows, the `UserCredentials` type and the `userCredentials` property are marked `internal` for the 1.0 release while their behavior is finalized. We also rename the misspelled `ConsoleBehavior.detatch` to `.detach`.


## Remove `runDetached` API

`runDetached()` was initially pitched as an "escape hatch" for spawning processes synchronously on systems where concurrency might not be available. Consequently, `runDetached()` doesn't perform any async IO or async process state monitoring; instead, it acts as a convenient wrapper around `posix_spawn` and simply returns the child process ID to the caller.

While this design works conceptually, in practice we found that it's impossible to safely vend this API due to PID reuse. Specifically, on Windows a PID does NOT have the concept of `wait()` and reaping and the PID can be reused as soon as the process terminates. This creates a TOCTOU race condition: the PID may not be valid by the time `runDetached()` returns. Rather than designing an elaborate workaround for these race conditions, we elected to simply remove the `runDetached` API since it was never a core part of Subprocess.


## Expand Platform-Specific `ProcessIdentifier` on Windows and Linux

To address the potential TOCTOU issue with PIDs described above, we propose exposing platform-specific process file descriptors via `ProcessIdentifier` on Windows and Linux:

```swift
// For Linux, Android, and FreeBSD
public struct ProcessIdentifier: Sendable, Hashable {
    /// The platform specific process identifier value
    public let value: pid_t

    #if os(Linux) || os(Android) || os(FreeBSD)
    /// The process file descriptor for the running execution. For example, pidfd on Linux
    public let processDescriptor: CInt
    #endif
}

// For Windows
public struct ProcessIdentifier: Sendable, Hashable {
    /// Windows specific process identifier value
    public let value: DWORD
    /// Process handle for current execution.
    ///
    /// `HANDLE` is imported as `UnsafeMutableRawPointer`, which is not
    /// `Sendable`. However, a Windows `HANDLE` is an opaque kernel object
    /// identifier, it is never dereferenced as a pointer in user space.
    /// Copying the value across threads is equivalent to copying an integer,
    /// and the kernel serializes access to the underlying object. Because
    /// this is an immutable `let`, there is no data race on the value itself,
    /// making `nonisolated(unsafe)` safe here.
    public nonisolated(unsafe) let processDescriptor: HANDLE
    /// Main thread handle for current execution.
    ///
    /// `HANDLE` is imported as `UnsafeMutableRawPointer`, which is not
    /// `Sendable`. However, a Windows `HANDLE` is an opaque kernel object
    /// identifier, it is never dereferenced as a pointer in user space.
    /// Copying the value across threads is equivalent to copying an integer,
    /// and the kernel serializes access to the underlying object. Because
    /// this is an immutable `let`, there is no data race on the value itself,
    /// making `nonisolated(unsafe)` the safe here.
    public nonisolated(unsafe) let threadHandle: HANDLE
}
```

On Darwin, `ProcessIdentifier` continues to wrap just the `pid_t` `value`. On all platforms, `ProcessIdentifier` is now `Sendable, Hashable`; its SF-0007 `Codable` conformance is removed, since process descriptors are process-local and not meaningfully serializable.

According to Linux documentation:

>  Even if the child has already terminated by the time of the pidfd_open() call, its PID will not have been recycled and the returned file descriptor will refer to the resulting zombie process.

We recommend using this property instead of the raw PID value due to its safety guarantees.


## Redesign `TerminationStatus` on Windows

The original `TerminationStatus` included two cases: `.exited()` and `.unhandledException()`. While these two cases make sense on Unix systems, where `wait(2)` returns a packed bitfield that distinguishes normal exits from unhandled signals, they do not translate well to Windows. Windows's `GetExitCodeProcess()` returns a single `DWORD` value, making it impossible to reliably distinguish between a normal exit code and an unhandled exception code.

We propose two changes to `TerminationStatus`:

1. Remove `.unhandledException()` on Windows, since `TerminationStatus` cannot reliably determine whether the exit code represents a normal exit or an unhandled exception.
2. Rename `.unhandledException()` to `.signaled()` on Unix systems, since the underlying mechanism is signal delivery, not exception handling.

```swift
/// An exit status of a subprocess.
public enum TerminationStatus: Sendable, Hashable {
    #if os(Windows)
    /// The type of the status code.
    public typealias Code = DWORD
    #else
    /// The type of the status code.
    public typealias Code = CInt
    #endif

    /// The subprocess exited with the given code.
    case exited(Code)

    #if !os(Windows)
    /// The subprocess was terminated by the given signal.
    case signaled(Code)
    #endif

    /// Whether the current TerminationStatus is successful.
    public var isSuccess: Bool
}
```

Like `ProcessIdentifier`, `TerminationStatus` is now `Sendable, Hashable` and its SF-0007 `Codable` conformance is removed.


## Drop Swift 6.1 Support

Subprocess was designed from the start to use `Span` as the performant currency type for file IO. At the same time, we wanted to support `Swift 6.1` when we launched the public beta so more developers could try it out. This resulted in some shims and workarounds for Swift 6.1 when `Span` was not available, gated behind a `SubprocessSpan` trait.

As we prepare for the 1.0 release, we want to remove these workarounds from the official API since `Swift 6.2` has been available for more than a year now. The package now requires `swift-tools-version: 6.2`. Our plan is to drop `Swift 6.1` support on `main` and future releases while tagging `0.4` as the "final version" of Subprocess that supports `Swift 6.1` for developers that need it.

This change removes the `SubprocessSpan` trait and the `Sequence<UInt8>`-based fallback on `OutputProtocol`, leaving `RawSpan` as the single currency type. `OutputProtocol` and `InputProtocol` also gain a `~Copyable` relaxation, so non-copyable types can conform.

```diff
-public protocol OutputProtocol: Sendable {
+public protocol OutputProtocol: Sendable, ~Copyable {
     associatedtype OutputType: Sendable

     /// Convert the output from span to expected output type
     func output(from span: RawSpan) throws -> OutputType
-
-    /// Convert the output from buffer to expected output type
-    func output(from buffer: some Sequence<UInt8>) throws -> OutputType

     var maxSize: Int { get }
 }
```


## Error Overhaul

`SubprocessError` in the original proposal has two shortcomings:

1. `SubprocessError.Code` was an opaque `Int` value. Developers had to "remember" what different numeric values represent.
2. `Subprocess` didn't formalize how errors are thrown or how they should be handled, leaving developers to figure it out on their own.

We propose a new design for `SubprocessError` to address these issues and also provide guidance on how errors should be handled:


```swift
/// Error thrown from Subprocess. `SubprocessError` may wrap an
/// `underlyingError` to represent what caused this error
public struct SubprocessError: Swift.Error, Sendable, Hashable {
    #if os(Windows)
    public typealias UnderlyingError = WindowsError
    #else
    public typealias UnderlyingError = Errno
    #endif

    /// The error code of this error
    public let code: SubprocessError.Code
    /// The underlying error that caused this error
    public let underlyingError: UnderlyingError?
}

extension SubprocessError {
    /// A SubprocessError Code
    public struct Code: Hashable, Sendable { }
}

extension SubprocessError.Code {
    /// Error code indicating process spawning failed
    public static var spawnFailed: Self
    /// Error code indicating target executable is not found
    public static var executableNotFound: Self
    /// Error code indicating working directory is not valid or subprocess
    /// failed to change working directory when spawning child process
    public static var failedToChangeWorkingDirectory: Self
    /// Error code indicating subprocess has failed to monitor the exit status of child process.
    public static var failedToMonitorProcess: Self

    /// Error code indicating subprocess failed to read data from the child process
    public static var failedToReadFromSubprocess: Self
    /// Error code indicating subprocess failed to write data to the child process
    public static var failedToWriteToSubprocess: Self
    /// Error code indicating child process output has exceeded the set limit
    public static var outputLimitExceeded: Self
    /// Error code indicating platform specific AsyncIO failed
    public static var asyncIOFailed: Self

    /// Error code indicating subprocess failed to control the child process such as
    /// sending signal and terminating process
    public static var processControlFailed: Self
}

#if os(Windows)
extension SubprocessError {
    /// Represents an error originating from one of the underlying Windows subsystems.
    public enum WindowsError: Error, Hashable {
        /// An error returned by the Windows NT kernel or Native API.
        case ntStatus(NTSTATUS)
        /// A Win32 subsystem error, such as the `DWORD` returned by `GetLastError()`.
        case win32(DWORD)
        /// A Component Object Model (COM) or Windows Runtime (WinRT) error.
        case hresult(HRESULT)
        /// A C Runtime (CRT) or POSIX-style error from `errno`.
        case cRuntime(errno_t)

        public init(ntStatus: NTSTATUS)
        public init(win32Error: DWORD)
        public init(hresult: HRESULT)
        public init(cRuntimeError: errno_t)
    }
}
#endif
```

In the new design, we exposed static properties on `SubprocessError.Code` to represent different error codes. Developers can now check their error code against this list instead of relying on an `Int`.

On Windows, `WindowsError` is no longer a thin wrapper around a single `GetLastError()` `DWORD`. Windows surfaces errors through several distinct subsystems, so `WindowsError` is now an `enum` that can represent an `NTSTATUS`, a Win32 error, an `HRESULT`, or a C runtime `errno`.

We also formalized Subprocess's error throwing behavior: `Subprocess` now only throws `SubprocessError` internally, since most internal functions now use typed throws. The only exception is that developers can throw any `Error` from within the execution body closure or `.preSpawnProcessConfigurator`. With this newly defined behavior, we recommend writing Subprocess error handling code as follows:

```swift
do {
    let result = try await run(...) { execution in
        // Developers could throw any error from this closure
        throw MyError()
        ...
        throw MyOtherError()
    }
} catch let subprocessError as SubprocessError {
    // Handle errors thrown from within Subprocess itself.
    // These errors usually indicate some issue with the environment
    // or a bug within Subprocess itself.
    switch subprocessError.code {
    case .spawnFailed:
    ...
    }
} catch let myError as MyError {
    // Handle custom errors thrown from the closure
} catch let myOtherError as MyOtherError {
    // Handle custom errors thrown from the closure
}
```


## Additional Refinements

Beyond the changes above, a number of smaller refinements bring the rest of the API in line with the 1.0 design:

- **`Configuration` is no longer `Hashable`/`Equatable`.** It is now `Sendable` (plus `CustomStringConvertible`/`CustomDebugStringConvertible`), consistent with `PlatformOptions`. Its initializer label changes from `init(executing:)` to `init(executable:)`, and `workingDirectory` becomes an `Optional<FilePath>` stored property (a `nil` value inherits the parent's working directory).

- **`Executable.resolveExecutablePath(in:)` is now `async`** and uses typed throws (`async throws(SubprocessError) -> FilePath`), since resolving a path may touch the filesystem on a background thread.

- **Output factories now require an explicit limit.** The zero-argument convenience properties `.string`, `.bytes`, and `.data` from SF-0007 (which silently capped collection at 128 KB) are replaced by `.string(limit:)`, `.string(limit:encoding:)`, `.bytes(limit:)`, and `.data(limit:)`. Because the default `.string` output is gone, the collected `run()` overloads now require an explicit `output:` argument. This makes the maximum amount of memory a `run()` call may allocate explicit at the call site; Subprocess throws `outputLimitExceeded` when a process produces more than the limit.

- **`StandardInputWriter` write methods adopt typed throws** (`throws(SubprocessError)`), and the `RawSpan` overload is now unconditionally available (it is no longer gated on the removed `SubprocessSpan` trait).
