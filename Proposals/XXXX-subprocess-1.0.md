# Subprocess 1.0 Update

* Proposal: [SF-00XX](XXXX-subprocess-1.0.md)
* Authors: [Charles Hu](https://github.com/iCharlesHu)
* Review Manager: [Tina Liu](https://github.com/itingliu)
* Status: **Post Review Update**
* Implementation: https://github.com/swiftlang/swift-subprocess

## Introduction

We introduced Subprocess with SF-0007 and shipped swift-subprocess as a public beta in Spring 2025. Since then, we've received a considerable amount of feedback from the community and updated the Subprocess API to address it. This proposal covers all API changes made since SF-0007 and proposes them for inclusion in the Subprocess 1.0 API.

## Rename `ExecutionResult` and `CollectedResult`

We propose renaming `ExecutionResult` to `ExecutionOutcome`, to avoid confusion with Swift's `Result` type (since neither are a `Result`). `ExecutionOutcome` indicates that we are presenting the outcome (termination status) of the child process. We also want add the missing `Sendable` conformances to `ExecutionOutcome`, since the wrapped `value` already has to be `Sendable`.

Similarly, we propose renaming `CollectedResult` to `ExecutionRecord`. `ExecutionRecord` indicates that we are presenting the recorded data of the child process.

## Remove `.standardOutput` and `.standardError` Properties from `Execution`

We propose moving `.standardOutput` and `.standardError` properties from `Execution` to the `run()` closure parameter alongside `Execution`:

```swift
// Before
public func run<Result>(
    ...
    body: (Execution) async throws -> Result
) async throws -> ExecutionOutcome<Result> { ... }

_ = try await run(...) { execution in
    for try await item in execution.standardOutput { ... }
}

// After
public func run<Result>(
    ...
    body: (Execution, StandardInputWriter, AsyncBufferSequence, AsyncBufferSequence) async throws -> Result
) async throws -> ExecutionOutcome<Result> { ... }

_ = try await run(...) { execution, standardInput, standardOutput, standardError in
    for await item in standardOutput { ... }
}
```

This change eliminates the need for `Atomic` and `AtomicBox` within `Execution`, and more importantly, makes these two variables semantically closer to the correct mental model of how output streaming works.

In the original design, since `.standardOutput` and `.standardError` are properties on `Execution`, it creates the illusion that you can repeatedly call these properties and create different output streams:

```swift
_ = try await run(...) { execution in
    for try await item1 in execution.standardOutput { ... }
    for try await item2 in execution.standardOutput { ... }
}
```

However, this is not the case. Once you create an `AsyncBufferSequence` by calling `execution.standardOutput`, the returned sequence effectively "owns" the underlying OS pipe used to read data from. This means calling `execution.standardOutput` multiple times is undefined behavior, and we had to use an internal `Atomic` value to guard against it.

The new design eliminates this problem entirely by "promoting" the output `AsyncBufferSequence`s to be sibling parameters of `Execution`. Since by definition you can't "get" a function parameter multiple times, this eliminates the possibility of the aforementioned undefined behavior. This change also simplified `Execution`'s design by making it non-generic.

The full list of closure-based `run()` overloads is listed below:

```swift
/// Run an executable with given parameters and a custom closure
/// to manage the running subprocess’ lifetime.
/// - Parameters:
///   - executable: The executable to run.
///   - arguments: The arguments to pass to the executable.
///   - environment: The environment in which to run the executable.
///   - workingDirectory: The working directory in which to run the executable.
///   - platformOptions: The platform-specific options to use when running the executable.
///   - input: The input to send to the executable.
///   - output: How to manage executable standard output.
///   - error: How to manage executable standard error.
///   - isolation: the isolation context to run the body closure.
///   - body: The custom execution body to manually control the running process
/// - Returns: an `ExecutableResult` type containing the return value of the closure.
public func run<
    Result,
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
    output: Output = .discarded,
    error: Error = .discarded,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution) async throws -> Result)
) async throws -> ExecutionOutcome<Result> where Error.OutputType == Void

/// Run an executable with given parameters and a custom closure to manage the
/// running subprocess' lifetime and stream its standard output.
/// - Parameters:
///   - executable: The executable to run.
///   - arguments: The arguments to pass to the executable.
///   - environment: The environment in which to run the executable.
///   - workingDirectory: The working directory in which to run the executable.
///   - platformOptions: The platform-specific options to use when running the executable.
///   - input: The input to send to the executable.
///   - error: How to manage executable standard error.
///   - preferredBufferSize: The preferred size in bytes for the buffer used when reading
///     from the subprocess's standard error stream. If `nil`, uses the system page size
///     as the default buffer size. Larger buffer sizes may improve performance for
///     subprocesses that produce large amounts of output, while smaller buffer sizes
///     may reduce memory usage and improve responsiveness for interactive applications.
///   - isolation: the isolation context to run the body closure.
///   - body: The custom execution body to manually control the running process.
/// - Returns: an `ExecutableResult` type containing the return value of the closure.
public func run<Result, Input: InputProtocol, Error: ErrorOutputProtocol>(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    input: Input = .none,
    error: Error = .discarded,
    preferredBufferSize: Int? = nil,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution, AsyncBufferSequence) async throws -> Result)
) async throws -> ExecutionOutcome<Result> where Error.OutputType == Void

/// Run an executable with given parameters and a custom closure to manage the
/// running subprocess' lifetime and stream its standard error.
/// - Parameters:
///   - executable: The executable to run.
///   - arguments: The arguments to pass to the executable.
///   - environment: The environment in which to run the executable.
///   - workingDirectory: The working directory in which to run the executable.
///   - platformOptions: The platform-specific options to use when running the executable.
///   - input: The input to send to the executable.
///   - output: How to manage executable standard output.
///   - preferredBufferSize: The preferred size in bytes for the buffer used when reading
///     from the subprocess's standard error stream. If `nil`, uses the system page size
///     as the default buffer size. Larger buffer sizes may improve performance for
///     subprocesses that produce large amounts of output, while smaller buffer sizes
///     may reduce memory usage and improve responsiveness for interactive applications.
///   - isolation: the isolation context to run the body closure.
///   - body: The custom execution body to manually control the running process
/// - Returns: an `ExecutableResult` type containing the return value of the closure.
public func run<Result, Input: InputProtocol, Output: OutputProtocol>(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    input: Input = .none,
    output: Output,
    preferredBufferSize: Int? = nil,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution, AsyncBufferSequence) async throws -> Result)
) async throws -> ExecutionOutcome<Result> where Output.OutputType == Void

/// Run an executable with given parameters and a custom closure to manage the
/// running subprocess' lifetime, write to its standard input, and stream its standard output.
/// - Parameters:
///   - executable: The executable to run.
///   - arguments: The arguments to pass to the executable.
///   - environment: The environment in which to run the executable.
///   - workingDirectory: The working directory in which to run the executable.
///   - platformOptions: The platform-specific options to use when running the executable.
///   - error: How to manage executable standard error.
///   - preferredBufferSize: The preferred size in bytes for the buffer used when reading
///     from the subprocess's standard output stream. If `nil`, uses the system page size
///     as the default buffer size. Larger buffer sizes may improve performance for
///     subprocesses that produce large amounts of output, while smaller buffer sizes
///     may reduce memory usage and improve responsiveness for interactive applications.
///   - isolation: the isolation context to run the body closure.
///   - body: The custom execution body to manually control the running process
/// - Returns: An `ExecutableResult` type containing the return value of the closure.
public func run<Result, Error: ErrorOutputProtocol>(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    error: Error = .discarded,
    preferredBufferSize: Int? = nil,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution, StandardInputWriter, AsyncBufferSequence) async throws -> Result)
) async throws -> ExecutionOutcome<Result> where Error.OutputType == Void

/// Run an executable with given parameters and a custom closure to manage the
/// running subprocess' lifetime, write to its standard input, and stream its standard error.
/// - Parameters:
///   - executable: The executable to run.
///   - arguments: The arguments to pass to the executable.
///   - environment: The environment in which to run the executable.
///   - workingDirectory: The working directory in which to run the executable.
///   - platformOptions: The platform-specific options to use when running the executable.
///   - output: How to manage executable standard output.
///   - preferredBufferSize: The preferred size in bytes for the buffer used when reading
///     from the subprocess's standard error stream. If `nil`, uses the system page size
///     as the default buffer size. Larger buffer sizes may improve performance for
///     subprocesses that produce large amounts of output, while smaller buffer sizes
///     may reduce memory usage and improve responsiveness for interactive applications.
///   - isolation: the isolation context to run the body closure.
///   - body: The custom execution body to manually control the running process
/// - Returns: An `ExecutableResult` type containing the return value of the closure.
public func run<Result, Output: OutputProtocol>(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    output: Output,
    preferredBufferSize: Int? = nil,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution, StandardInputWriter, AsyncBufferSequence) async throws -> Result)
) async throws -> ExecutionOutcome<Result> where Output.OutputType == Void

/// Run an executable with given parameters and a custom closure
/// to manage the running subprocess’ lifetime, write to its
/// standard input, and stream its standard output and standard error.
/// - Parameters:
///   - executable: The executable to run.
///   - arguments: The arguments to pass to the executable.
///   - environment: The environment in which to run the executable.
///   - workingDirectory: The working directory in which to run the executable.
///   - platformOptions: The platform-specific options to use when running the executable.
///   - preferredBufferSize: The preferred size in bytes for the buffer used when reading
///     from the subprocess's standard output and error stream. If `nil`, uses the system page size
///     as the default buffer size. Larger buffer sizes may improve performance for
///     subprocesses that produce large amounts of output, while smaller buffer sizes
///     may reduce memory usage and improve responsiveness for interactive applications.
///   - isolation: the isolation context to run the body closure.
///   - body: The custom execution body to manually control the running process
/// - Returns: an `ExecutableResult` type containing the return value of the closure.
public func run<Result>(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    preferredBufferSize: Int? = nil,
    isolation: isolated (any Actor)? = #isolation,
    body: (
        (
            Execution,
            StandardInputWriter,
            AsyncBufferSequence,
            AsyncBufferSequence
        ) async throws -> Result
    )
) async throws -> ExecutionOutcome<Result>

/// Run an executable with given `Configuration` and a custom closure
/// to manage the running subprocess' lifetime.
/// - Parameters:
///   - configuration: The configuration to run.
///   - input: The input to send to the executable.
///   - output: How to manager executable standard output.
///   - error: How to manager executable standard error.
///   - isolation: the isolation context to run the body closure.
///   - body: The custom execution body to manually control the running process
/// - Returns an executableResult type containing the return value
///     of the closure.
public func run<
    Result,
    Input: InputProtocol,
    Output: OutputProtocol,
    Error: ErrorOutputProtocol
>(
    _ configuration: Configuration,
    input: Input = .none,
    output: Output = .discarded,
    error: Error = .discarded,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution) async throws -> Result)
) async throws -> ExecutionOutcome<Result> where Error.OutputType == Void

/// Run an executable with given `Configuration` and a custom closure
/// to manage the running subprocess' lifetime and stream its standard output.
/// - Parameters:
///   - configuration: The configuration to run.
///   - input: The input to send to the executable.
///   - error: How to manager executable standard error.
///   - preferredBufferSize: The preferred size in bytes for the buffer used when reading
///     from the subprocess's standard output stream. If `nil`, uses the system page size
///     as the default buffer size. Larger buffer sizes may improve performance for
///     subprocesses that produce large amounts of output, while smaller buffer sizes
///     may reduce memory usage and improve responsiveness for interactive applications.
///   - isolation: the isolation context to run the body closure.
///   - body: The custom execution body to manually control the running process
/// - Returns an executableResult type containing the return value
///     of the closure.
public func run<
    Result,
    Input: InputProtocol,
    Error: ErrorOutputProtocol
>(
    _ configuration: Configuration,
    input: Input = .none,
    error: Error = .discarded,
    preferredBufferSize: Int? = nil,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution, AsyncBufferSequence) async throws -> Result)
) async throws -> ExecutionOutcome<Result> where Error.OutputType == Void

/// Run an executable with given `Configuration` and a custom closure
/// to manage the running subprocess' lifetime and stream its standard error.
/// - Parameters:
///   - configuration: The configuration to run.
///   - input: The input to send to the executable.
///   - output: How to manager executable standard output.
///   - preferredBufferSize: The preferred size in bytes for the buffer used when reading
///     from the subprocess's standard error stream. If `nil`, uses the system page size
///     as the default buffer size. Larger buffer sizes may improve performance for
///     subprocesses that produce large amounts of output, while smaller buffer sizes
///     may reduce memory usage and improve responsiveness for interactive applications.
///   - isolation: the isolation context to run the body closure.
///   - body: The custom execution body to manually control the running process
/// - Returns an executableResult type containing the return value
///     of the closure.
public func run<Result, Input: InputProtocol, Output: OutputProtocol>(
    _ configuration: Configuration,
    input: Input = .none,
    output: Output,
    preferredBufferSize: Int? = nil,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution, AsyncBufferSequence) async throws -> Result)
) async throws -> ExecutionOutcome<Result> where Output.OutputType == Void

/// Run an executable with given `Configuration` and a custom closure
/// to manage the running subprocess' lifetime, write to its
/// standard input, and stream its standard output.
/// - Parameters:
///   - configuration: The `Configuration` to run.
///   - error: How to manager executable standard error.
///   - preferredBufferSize: The preferred size in bytes for the buffer used when reading
///     from the subprocess's standard output stream. If `nil`, uses the system page size
///     as the default buffer size. Larger buffer sizes may improve performance for
///     subprocesses that produce large amounts of output, while smaller buffer sizes
///     may reduce memory usage and improve responsiveness for interactive applications.
///   - isolation: the isolation context to run the body closure.
///   - body: The custom execution body to manually control the running process
/// - Returns an executableResult type containing the return value
///     of the closure.
public func run<Result, Error: ErrorOutputProtocol>(
    _ configuration: Configuration,
    error: Error = .discarded,
    preferredBufferSize: Int? = nil,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution, StandardInputWriter, AsyncBufferSequence) async throws -> Result)
) async throws -> ExecutionOutcome<Result> where Error.OutputType == Void

/// Run an executable with given `Configuration` and a custom closure
/// to manage the running subprocess' lifetime, write to its
/// standard input, and stream its standard error.
/// - Parameters:
///   - configuration: The `Configuration` to run.
///   - output: How to manager executable standard output.
///   - preferredBufferSize: The preferred size in bytes for the buffer used when reading
///     from the subprocess's standard error stream. If `nil`, uses the system page size
///     as the default buffer size. Larger buffer sizes may improve performance for
///     subprocesses that produce large amounts of output, while smaller buffer sizes
///     may reduce memory usage and improve responsiveness for interactive applications.
///   - isolation: the isolation context to run the body closure.
///   - body: The custom execution body to manually control the running process
/// - Returns an executableResult type containing the return value
///     of the closure.
public func run<Result, Output: OutputProtocol>(
    _ configuration: Configuration,
    output: Output,
    preferredBufferSize: Int? = nil,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution, StandardInputWriter, AsyncBufferSequence) async throws -> Result)
) async throws -> ExecutionOutcome<Result> where Output.OutputType == Void

/// Run an executable with given parameters specified by a `Configuration`
/// and a custom closure to manage the running subprocess' lifetime, write to its
/// standard input, and stream its standard output and standard error.
/// - Parameters:
///   - configuration: The `Subprocess` configuration to run.
///   - preferredBufferSize: The preferred size in bytes for the buffer used when reading
///     from the subprocess's standard output and error stream. If `nil`, uses the system page size
///     as the default buffer size. Larger buffer sizes may improve performance for
///     subprocesses that produce large amounts of output, while smaller buffer sizes
///     may reduce memory usage and improve responsiveness for interactive applications.
///   - isolation: the isolation context to run the body closure.
///   - body: The custom configuration body to manually control
///       the running process, write to its standard input, stream
///       the standard output and standard error.
/// - Returns: an `ExecutableResult` type containing the return value of the closure.
public func run<Result>(
    _ configuration: Configuration,
    preferredBufferSize: Int? = nil,
    isolation: isolated (any Actor)? = #isolation,
    body: (
        (
            Execution,
            StandardInputWriter,
            AsyncBufferSequence,
            AsyncBufferSequence
        ) async throws -> Result
    )
) async throws -> ExecutionOutcome<Result>
```


## Introduce `AsyncBufferSequence`

One "side effect" of moving `.standardOutput` and `.standardError` to closure parameters is that we can no longer use `some AsyncSequence` as their type. Therefore, we propose exposing the previously internal `AsyncBufferSequence` as the concrete streaming type.

```swift
/// An asynchronous sequence of buffers used to stream output from subprocess.
public struct AsyncBufferSequence: AsyncSequence, Sendable {
    /// The failure type for the asynchronous sequence.
    public typealias Failure = any Swift.Error
    /// The element type for the asynchronous sequence.
    public typealias Element = Buffer

    /// Iterator for `AsyncBufferSequence`.
    @_nonSendable
    public struct Iterator: AsyncIteratorProtocol {
        /// The element type for the iterator.
        public typealias Element = Buffer

        /// Retrieve the next buffer in the sequence, or `nil` if
        /// the sequence has ended.
        public mutating func next() async throws -> Buffer?
    }

    /// Creates an iterator for this asynchronous sequence.
    public func makeAsyncIterator() -> Iterator
}
```

## Introduce `preferredBufferSize` Parameter

We propose adding a `preferredBufferSize: Int?` parameter to the `run()` overloads whose execution body closure allows standard output and/or error streaming. By default, Subprocess chooses the platform page size as the buffer size when creating `AsyncBufferSequence` for output streaming. This default buffer size might not be suitable for all use cases. In particular, when the child process output is sparse, Subprocess might appear stuck because it's waiting for the child process to write more bytes while the child process might be expecting more input. `preferredBufferSize` allows developers to choose the buffer size most suitable for their particular scenario.

```swift
public func run<Result, Input: InputProtocol, Error: ErrorOutputProtocol>(
    _ executable: Executable,
    arguments: Arguments = [],
    ...
    preferredBufferSize: Int? = nil,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution, AsyncBufferSequence) async throws -> Result)
) async throws -> ExecutionOutcome<Result> where Error.OutputType == Void
```

## Introduce `AsyncBufferSequence.LineSequence`

The original proposal only included a way to stream a list of `Buffer`s. This makes streaming text difficult since naively converting each `Buffer` to `String` may not always succeed if the `Buffer` happens to break within a grapheme cluster. Since streaming text is one of the most common use cases for `Subprocess`, we propose introducing a new `AsyncBufferSequence.LineSequence` specifically designed to parse and partition an asynchronous sequence of buffers into text lines. Developers can optionally specify a String encoding and a `BufferingPolicy` to control how `LineSequence` handles the exhaustion of a buffer’s capacity.

```swift
extension AsyncBufferSequence {
    /// Line sequence parses and splits an asynchronous sequence of buffers into lines.
    ///
    /// It is the preferred method to convert `Buffer` to `String`
    public struct LineSequence<Encoding: _UnicodeEncoding>: AsyncSequence, Sendable {
        /// The element type for the asynchronous sequence.
        public typealias Element = String

         /// The iterator for line sequence.
        public struct AsyncIterator: AsyncIteratorProtocol {
            /// The element type for this Iterator.
            public typealias Element = String

            /// Retrieves the next line, or returns nil if the sequence ends.
            public mutating func next() async throws -> String?
        }

        /// Creates an iterator for this line sequence.
        public func makeAsyncIterator() -> AsyncIterator
    }
}

extension AsyncBufferSequence.LineSequence {
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
}

extension AsyncBufferSequence {
    /// Creates a line sequence to iterate through this `AsyncBufferSequence` line by line with a default 128k max line length and UTF8 encoding
    public func lines() -> LineSequence<UTF8>

    /// Creates a line sequence to iterate through a `AsyncBufferSequence` line by line.
    /// - Parameters:
    ///   - encoding: The target encoding to encode Strings to
    ///   - bufferingPolicy: How should back-pressure be handled
    /// - Returns: A `LineSequence` to iterate though this `AsyncBufferSequence` line by line
    public func lines<Encoding: _UnicodeEncoding>(
        encoding: Encoding.Type,
        bufferingPolicy: LineSequence<Encoding>.BufferingPolicy = .maxLineLength(128 * 1024)
    ) -> LineSequence<Encoding>
}
```

`LineSequence` is created by calling `.lines()` on `AsyncBufferSequence`.

```swift
// Monitor Nginx log via `tail -f`
async let monitorResult = try await Subprocess.run(
    .path("/usr/bin/tail"),
    arguments: ["-f", "/path/to/nginx.log"]
) { execution, standardOutput in
    for try await line in standardOutput.lines() {
        // Parse the log text line by line
        if line.contains("500") {
            // Oh no, 500 error
        }
    }
}
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

extension Environment.Key: CodingKeyRepresentable, Comparable, RawRepresentable,CustomStringConvertible { }
```

## Introduce `CombinedErrorOutput` and `ErrorOutputProtocol`

Merging standard output and standard error into one stream — like shell redirection `2>&1` — is a common use case for Subprocess. We propose introducing a new concrete `CombinedErrorOutput` type that merges the standard error and standard output streams.

The original design uses one protocol, `OutputProtocol`, to define the child process's standard output and standard error behavior. This worked because up until now, all concrete output types could be used for either output or error. `CombinedErrorOutput`, as its name implies, can only be used with standard error to combine it with standard output. Consequently, we expanded the `OutputProtocol` hierarchy by introducing a new `ErrorOutputProtocol`. `ErrorOutputProtocol` conforms to `OutputProtocol` and introduces no new requirements. Only `CombinedErrorOutput` conforms to `ErrorOutputProtocol`.

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
    /// When using `combineWithOutput`, both standard output and standard error from
    /// the child process are merged into a single output stream. This is equivalent
    /// to using shell redirection like `2>&1`.
    ///
    /// This is useful when you want to capture or redirect both output streams
    /// together, making it possible to process all subprocess output as a unified
    /// stream rather than handling standard output and standard error separately
    ///
    /// - Returns: A `CombinedErrorOutput` instance that merges standard error
    ///   with standard output.
    public static var combineWithOutput: Self
}
```

You can use `CombinedErrorOutput` like this:

```swift
let result = try await run(
    .path("/bin/sh"),
    arguments: ["-c", "echo Hello Stdout; echo Hello Stderr 1>&2"],
    output: .string(limit: 1024),
    error: .combineWithOutput
)
```

`result.standardOutput` will print `Hello Stdout;\nHello Stderr`.


## Remove `runDetached` API

`runDetached()` was initially pitched as an "escape hatch" for spawning processes synchronously on systems where concurrency might not be available. Consequently, `runDetached()` doesn't perform any async IO or async process state monitoring; instead, it acts as a convenient wrapper around `posix_spawn` and simply returns the child process ID to the caller.

While this design works conceptually, in practice we found that it's impossible to safely vend this API due to PID reuse. Specifically, on Windows a PID does NOT have the concept of `wait()` and reaping — the PID can be reused as soon as the process terminates. This creates a TOCTOU race condition: the PID may not be valid by the time `runDetached()` returns. Rather than designing an elaborate workaround for these race conditions, we elected to simply remove the `runDetached` API since it was never a core part of Subprocess.


## Expand Platform-Specific `ProcessIdentifier` on Windows and Linux

To address the potential TOCTOU issue with PIDs described above, we propose exposing platform-specific process file descriptors via `ProcessIdentifier` on Windows and Linux:

```swift
// For Linux
public struct ProcessIdentifier: Sendable, Hashable {
    /// The platform specific process identifier value
    public let value: pid_t

    #if os(Linux) || os(Android) || os(FreeBSD)
    /// The process file descriptor (pidfd) for the running execution.
    public let processDescriptor: CInt
    #endif
}

// For Windows
public struct ProcessIdentifier: Sendable, Hashable {
    /// Windows specific process identifier value
    public let value: DWORD
    /// Process handle for current execution.
    public nonisolated(unsafe) let processDescriptor: HANDLE
    /// Main thread handle for current execution.
    public nonisolated(unsafe) let threadHandle: HANDLE
}
```

According to Linux documentation:

>  Even if the child has already terminated by the time of the pidfd_open() call, its PID will not have been recycled and the returned file descriptor will refer to the resulting zombie process.

We recommend using this property instead of the raw PID value due to its safety guarantees.


## Expand `FileDescriptorOutput`

We propose expanding `FileDescriptorOutput` with two additional static properties, `.standardOutput` and `.standardError`, that redirect the child process's output to the parent process's standard output or standard error. This is useful when you want to follow along with the process output rather than capturing it.

```swift
extension OutputProtocol where Self == FileDescriptorOutput {
    /// Create a Subprocess output that writes output to the standard output of
    /// current process.
    ///
    /// The file descriptor isn't closed afterwards.
    public static var standardOutput: Self

    /// Create a Subprocess output that write output to the standard error of
    /// current process.
    ///
    /// The file descriptor isn't closed afterwards.
    public static var standardError: Self
}
```


## Redesign `TerminationStatus` on Windows

The original `TerminationStatus` included two cases: `.exited()` and `.unhandledException()`. While these two cases make sense on Unix systems — where `wait(2)` returns a packed bitfield that distinguishes normal exits from unhandled signals — they do not translate well to Windows. Windows's `GetExitCodeProcess()` returns a single `DWORD` value, making it impossible to reliably distinguish between a normal exit code and an unhandled exception code.

We propose two changes to `TerminationStatus`:

1. Remove `.unhandledException()` on Windows, since `TerminationStatus` cannot reliably determine whether the exit code represents a normal exit or an unhandled exception.
2. Rename `.unhandledException()` to `.signaled()` on Unix systems, since the underlying mechanism is signal delivery, not exception handling.

```swift
/// An exit status of a subprocess.
public enum TerminationStatus: Sendable, Hashable {
    #if canImport(WinSDK)
    /// The type of the status code.
    public typealias Code = DWORD
    #else
    /// The type of the status code.
    public typealias Code = CInt
    #endif

    /// The subprocess exited with the given code.
    case exited(Code)

    #if !canImport(WinSDK)
    /// The subprocess was terminated by the given signal.
    case signaled(Code)
    #endif

    /// Whether the current TerminationStatus is successful.
    public var isSuccess: Bool
}
```


## Drop Swift 6.1 Support

Subprocess was designed from the start to use `Span` as the performant currency type for file IO. At the same time, we wanted to support `Swift 6.1` when we launched the public beta so more developers could try it out. This resulted in some shims and workarounds for Swift 6.1 when `Span` was not available.

As we prepare for the 1.0 release, we want to remove these workarounds from the official API since `Swift 6.2` has been available for more than a year now. Our plan is to drop `Swift 6.1` support on `main` and future releases while tagging a "final version" of Subprocess that supports `Swift 6.1` for developers that need it.

This change removes the `SubprocessSpan` trait and the following workarounds:

```diff
public protocol OutputProtocol {
    ...
-    /// Convert the output from buffer to expected output type
-    func output(from buffer: some Sequence<UInt8>) throws(SubprocessError) -> OutputType
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
    /// An error that represents a Windows error code returned by `GetLastError`
    public struct WindowsError: Error, RawRepresentable, Hashable {
        public let rawValue: DWORD

        public init(rawValue: DWORD)
    }
}
#endif
```

In the new design, we exposed static properties on `SubprocessError.Code` to represent different error codes. Developers can now check their error code against this list instead of relying on an `Int`.

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
