# Introducing Swift Subprocess

* Proposal: [SF-0007](0007-swift-subprocess.md)
* Authors: [Charles Hu](https://github.com/iCharlesHu)
* Review Manager: [Tina Liu](https://github.com/itingliu)
* Status: **3nd Review, Active: Feb 24, 2025...March 03, 2025**
* Bugs: [rdar://118127512](rdar://118127512), [apple/swift-foundation#309](https://github.com/apple/swift-foundation/issues/309)
* Review: [Pitch](https://forums.swift.org/t/pitch-swift-subprocess/69805/65), [1st review](https://forums.swift.org/t/review-sf-0007-introducing-swift-subprocess/70337), [2nd review](https://forums.swift.org/t/review-2nd-sf-0007-subprocess/76547)


## Revision History

* **v1**: Initial draft
* **v2**: Minor Updates:
    - Switched `AsyncBytes` to be backed by `DispatchIO`.
    - Introduced `resolveExecutablePath(withEnvironment:)` to enable explicit lookup of the executable path.
    - Added a new option, `closeWhenDone`, to automatically close the file descriptors passed in via `.readFrom` and friends.
    - Introduced a new parameter, `shouldSendToProcessGroup`, in the `send()` function to control whether the signal should be sent to the process or the process group.
    - Introduced a section on "Future Directions."
* **v3**: Minor updates:
    - Added a section describing `Task Cancellation`
    - Clarified for `readFrom()` and `writeTo()` Subprocess will close the passed in file descriptor right after spawning the process when `closeWhenDone` is set to true.
    - Adjusted argument orders in `Arguments`.
    - Added `run(withConfiguration:...)` in favor or `Configuration.run()`.
- **v4**: Minor updates (primarily name changes):
    - Dropped the `executing` label from `.run()`.
    - Removed references to `Subprocess.AsyncBytes`:
        - Instead, we use an opaque type: `some AsyncSequence<UInt8, Error>`.
        - When `typed throws` is ready, we can then update to the actual error type.
    - Updated `.standardOutput` and `.standardError` properties on `Subprocess` and `CollectedResult` to be non-optional (now they use `fatalError` instead).
        - Rationale: These properties can only be `nil` in two cases:
            1. The corresponding `.output`/`.error` was not set to `.redirectToSequence` when `run()` was called.
            2. These properties are accessed multiple times. This is because these `AsyncSequence`s are reading pipes under the hood, and pipes can only be read once.
            - Both cases can’t be resolved until the source code is updated; they are therefore considered programming errors.
    - Updated `StandardInputWriter` to be non-sendable.
    - Renamed `PlatformOptions.additionalAttributeConfigurator` to `Platform.preSpawnAttributeConfigurator`; renamed `PlatformOptions.additionalFileAttributeConfigurator` to `Platform.preSpawnFileAttributeConfigurator`.
    - Updated all `closeWhenDone` parameter labels to `closeAfterSpawningProcess`.
    - Renamed `Subprocess.Result` to `ExecutionResult`.
    - Added `Codable` support to `TerminationStatus` and `ExecutionResult`.
    - Renamed `TerminationStatus.exit`:
        - From `.exit` to `.exited`.
        - From `.wasUnhandledException` to `.isUnhandledException`.
    - Added two sections under `Future Direction`: `Support Launching Long Running Processes` and `Process Piping`.
    - Added Linux-specific `PlatformOptions`: `.closeAllUnknownFileDescriptors`.
        - This option attempts to emulate Darwin’s `POSIX_SPAWN_CLOEXEC_DEFAULT` behavior. It is the default value on Darwin.
        - Unfortunately, `posix_spawn` does not support this flag natively, hence on Linux this behavior is opt-in, and we will fall back to a custom implementation of `fork/exec`.
- **v5**: Platform-specific changes, `Subprocess.runDetached`, and others:
    - Added `Hashable`, `CustomStringConvertable` and `CustomDebugStringConvertible` conformance to `Subprocess.Configuration` and friends
    - `Subprocess.Arguments`:
        - Add an array initializer to `Subprocess.Arguments`:
            - `public init(_ array: [String])`
            - `public init(_ array: [Data])`.
    - `Subprocess.CollectedOutputMethod`:
        - Combined `.collect` and `.collect(upTo:)`
    - `Subprocess.PlatformOptions` (all platforms):
        - Changed from `.default` to using empty initializer `.init()`.
        - Changed to prefer platform native types such as `gid_t` over `Int`.
    - Darwin Changes:
        - Updated `PlatformOptions.createProcessGroup` to `PlatformOptions.processGroupID`.
            - Also changed the public init.
        - Combined `PlatformOptions.preSpawnAttributeConfigurator` and `PlatformOptions.preSpawnFileAttributeConfigurator` into `PlatformOptions.preSpawnProcessConfigurator` to be consistant with other platforms.
    - Linux Changes:
        - Updated `PlatformOptions` for Linux.
        - Introduced `PlatformOptions.preSpawnProcessConfigurator`.
    - Windows Changes:
        - Removed `Arguments` first argument override and non-string support from Windows because Windows does not support either.
        - Introduced `PlatformOptions` for Windows.
        - Replaced `Subprocess.send()` with
            - `Subprocess.terminate(withExitCode:)`
            - `Subprocess.suspend()`
            - `Subprocess.resume()`
    - `Subprocess.runDetached`:
        - Introduced `Subprocess.runDetached` as a top level API and sibling to all `Subprocess.run` methods. This method allows you to spawn a subprocess **WITHOUT** needing to wait for it to finish.
    - Updated `.standardOutput` and `.standardError` properties on `Subprocess` to be `AsyncSequence<Data, any Error>` instead of `AsyncSequence<UInt8, any Error>`.
        - The previous design, while more "traditional", leads to performance problems when the subprocess outputs large amount of data
    - Teardown Sequence support (for Darwin and Linux):
        - Introduced `Subprocess.teardown(using:)` to allow developers to gracefully shutdown a subprocess.
        - Introuuced `PlatformOptions.teardownSequence` that will be used to gracefully shutdown the subprocess if the parent task is cancelled.
- **v6**: String support, minor changes around IO and closure `sending` requirements:
    - Added a `Configuration` based overload for `runDetached`.
    - Updated input types to support: `Sequence<UInt8>`, `Sequence<Data>` and `AsyncSequence<Data>` (dropped `AsyncSequence<UInt8>` in favor of `AsyncSequence<Data>`).
    - Added `isolation` parameter for closure based `.run` methods.
    - Dropped `sending` requirement for closure passed to `.run`.
    - Windows: renamed `ProcessIdentifier.processID` to `ProcessIdentifier.value`.
    - Updated `TeardownStep` to use `Duration` instead of raw nanoseconds.
    - Switched all generic parameters to full words instead of a letter.
    - Introduced String support:
        - Added `some StringProtocol` input overloads for `run()`.
        - Introduced `protocol Subprocess.OutputConvertible`, which allows developers to define their own type as the return type for `CollecedOutput.standard{Output|Error}`.
        - Make `CollectedOutput`, its associated `run()` family of methods, and `CollectedOutputMethod` genric. The entire chain of genrics is ultimately inferred from `CollectedOutputMethod`, which allows developers to specify custom return type for `.standard{Output|Error}`.
- **v7**: Major redesign
    - Instead of `Subprocess.OutputMethod` and `Subprocess.InputMethod`, now IOs are protocol based: `Subprocess.InputProtocol` and `Subprocess.OutputProtocol` with concrete implementations
    - Remove all input overloads of `run()` since now we use concrete instances iof `InputProtocol` to represent them.
    - Renamed package module name to `Subprocess`.
    - Dropped the `struct Subprocess` namespace. Now all `run()`s are free standing functions
    - `Executable`:
        - Renamed `.named` to `.name`.
        - Renamed `.at` to `.path`.
    - Split `Subprocess` into main and `SubprocessFoundation` Traits:
        - `SubprocessFoundation` traits adds `Foundation` dependency and interop.
    - Introduce `struct Buffer`
- **v8**: Removing `ManagedInputProtocol` and `ManagedOutputProtocol`
    - Revise `InputProtocol` and `OutputProtocol` to not expose `FileDescriptor` directly
    - Added `SubprocessSpan` trait
    - Removed the opaque `Pipe`
    - Introduce a cross platform TeardownStep.gracefulShutDown(alloweDurationToNextStep:) and add Windows support

## Introduction

As Swift establishes itself as a general-purpose language for both compiled and scripting use cases, one persistent pain point for developers is process creation. The existing Foundation API for spawning a process, `NSTask`, originated in Objective-C. It was subsequently renamed to `Process` in Swift. As the language has continued to evolve, `Process` has not kept up. It lacks support for `async/await`, makes extensive use of completion handlers, and uses Objective-C exceptions to indicate developer error. This proposal introduces a new package called `Subprocess`, which addresses the ergonomic shortcomings of `Process` and enhances the experience of using Swift for scripting and other areas such as server-side development.

## Motivation

Consider the following shell script that checks the list of changes in the current repository and announces the result:

```bash
#!/usr/bin/env bash

changedFiles=$(git diff --name-only)
if [[ -z "$changedFiles" ]]; then
    # No changed file
    say "No changed files"
else
    # Split changed files into comma-separated text
    changedFiles=$(echo "$changedFiles" | tr "\n" ", ")
    say "These files have changed: ${changedFiles}"
fi
```

If we were to rewrite this example in Swift script today with `Process`, it would look something like this:

```swift
#!/usr/bin/swift

import Foundation

let gitProcess = Process()
let gitProcessPipe = Pipe()                                         // <- 0
gitProcess.currentDirectoryURL = URL(fileURLWithPath: ".")
gitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")     // <- 1
gitProcess.arguments = [
    "diff",
    "--name-only"
]
gitProcess.standardOutput = gitProcessPipe
try gitProcess.run()
let processOutput = gitProcessPipe
    .fileHandleForReading.readDataToEndOfFile()                     // <- 2
gitProcess.waitUntilExit()                                          // <- 3
var changedFiles = String(data: processOutput, encoding: .utf8)!
if changedFiles.isEmpty {
    changedFiles = "No changed files"
} else {
    changedFiles = changedFiles.split(separator: "\n").joined(separator: ", ")
    changedFiles = "These files have changed: \(changedFiles)"
}

let sayProcess = Process()
sayProcess.currentDirectoryURL = URL(fileURLWithPath: ".")
sayProcess.executableURL = URL(fileURLWithPath: "/usr/bin/say")
sayProcess.arguments = [
    changedFiles
]
try sayProcess.run()
```

While the Swift script above is functionally equivalent to the shell script, it is unnecessarily verbose and cumbersome to use. Specifically, we can observe the following issues (the relevant regions are marked in the example above):

0. `Process` requires the user to explicitly set standard output and standard error before being able to access the process output. Furthermore, the standard IO properties, `.standardInput`, `.standardOutput`, `.standardError`, all have the type `Any` because they support both `Pipe` and `FileHandle`. This design can easily lead to confusion because one may attempt to directly access a Process' `standardOutput` without realizing the need to set these properties first.
1. `Process` expects an explicit `URL` to point to its executable instead of trying to resolve the executable path using the `$PATH` variable. This design adds friction in Swift scripting because developers will have to explicitly look up the path to any executable they wish to run.
2. `Process` expects developers to work with `Pipe` directly to read process output. It could be confusing to determine the correct `fileHandle` to read.
3. Instead of `async/await`, `Process` uses blocking methods (`.waitUntilExit()`) and callbacks (`.readabilityHandler`) exclusively. This design leaves developers with the responsibility to manage asynchronicity and can easily introduce a "Pyramid of Doom."


## Proposed solution

We propose a new package, `Subprocess`, that will eventually replace `Process` as the canonical way to launch a process in `Swift`.

Here's the above script rewritten using `Subprocess` package:

```swift
#!/usr/bin/swift

import Subprocess

let gitResult = try await run(             // <- 0
    .name("git"),                          // <- 1
    arguments: ["diff", "--name-only"]
)

let changedFiles = gitResult.standardOutput!
if changedFiles.isEmpty {
    changedFiles = "No changed files"
}
_ = try await run(
    .name("say"),
    arguments: [changedFiles]
)
```

Let's break down the example above:

0. `Subprocess` is constructed entirely on the `async/await` paradigm. The `run()` method utilizes `await` to allow the child process to finish, asynchronously returning an `CollectedResult`. Additionally, there is an closure based overload of `run()` that offers more granulated control, which will be discussed later.
1. There are two primary ways to configure the executable being run:
    - The default approach, recommended for most developers, is `.path(FilePath)`. This allows developers to specify a full path to an executable.
    - Alternatively, developers can use `.name(String)` to instruct `Subprocess` to look up the executable path based on heuristics such as the `$PATH` environment variable.


## Detailed Design

The latest API documentation can be viewed by running the following command:

```
swift package --disable-sandbox preview-documentation --target Subprocess
```

### `SubprocessFoundation` and `SubprocessSpan` Traits

The core `Subprocess` package is designed to only depend the standard library and [swift-system](https://github.com/apple/swift-system) (for `FileDescriptor` and `FilePath`). Starting with Swift 6.1 or later, we propose using the new [`traits` feature](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md) to introduce a `SubprocessFoundation` trait, which will be on by default. When this trait is on, `Subprocess` includes a dependency on `Foundation` and adds extensions on Foundation types like `Data`.

We also propose a `SubprocessSpan` trait that makes Subprocess’ API, mainly `OutputProtocol`, `RawSpan` based. This trait is on whenever `Span` is available and should only be deactivated when `Span` is not available.

For Swift 6.0 and earlier versions, `SubprocessFoundation` is essentially always enabled, and `SubprocessSpan` is essentially always disabled.


### The `run()` Family of Methods

We propose several `run()` functions that allow developers to asynchronously execute a subprocess.

```swift
/// Run a executable with given parameters asynchrously and returns
/// a `CollectedResult` containing the output of the child process.
/// - Parameters:
///   - executable: The executable to run.
///   - arguments: The arguments to pass to the executable.
///   - environment: The environment in which to run the executable.
///   - workingDirectory: The working directory in which to run the executable.
///   - platformOptions: The platform specific options to use
///     when running the executable.
///   - input: The input to send to the executable.
///   - output: The method to use for redirecting the standard output.
///   - error: The method to use for redirecting the standard error.
/// - Returns a CollectedResult containing the result of the run.
#if SubprocessSpan
@available(SubprocessSpan, *)
#endif
public func run<
    Input: InputProtocol,
    Output: OutputProtocol,
    Error: OutputProtocol
>(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    input: Input = .none,
    output: Output = .string,
    error: Error = .discarded
) async throws -> CollectedResult<Output, Error>

/// Run a executable with given parameters asynchrously and returns
/// a `CollectedResult` containing the output of the child process.
/// - Parameters:
///   - executable: The executable to run.
///   - arguments: The arguments to pass to the executable.
///   - environment: The environment in which to run the executable.
///   - workingDirectory: The working directory in which to run the executable.
///   - platformOptions: The platform specific options to use
///     when running the executable.
///   - input: The input to send to the executable.
///   - output: The method to use for redirecting the standard output.
///   - error: The method to use for redirecting the standard error.
/// - Returns a CollectedResult containing the result of the run.
#if SubprocessSpan
@available(SubprocessSpan, *)
public func run<
    InputElement: BitwiseCopyable,
    Output: OutputProtocol,
    Error: OutputProtocol
>(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    input: borrowing Span<InputElement>,
    output: Output = .string,
    error: Error = .discarded
) async throws -> CollectedResult<Output, Error>
#endif

/// Run a executable with given parameters and a custom closure
/// to manage the running subprocess' lifetime and its IOs.
/// - Parameters:
///   - executable: The executable to run.
///   - arguments: The arguments to pass to the executable.
///   - environment: The environment in which to run the executable.
///   - workingDirectory: The working directory in which to run the executable.
///   - platformOptions: The platform specific options to use
///     when running the executable.
///   - input: The input to send to the executable.
///   - output: How to manage the executable standard ouput.
///   - error: How to manager executable standard error.
///   - body: The custom execution body to manually control the running process
/// - Returns a ExecutableResult type containing the return value
///     of the closure.
#if SubprocessSpan
@available(SubprocessSpan, *)
#endif
public func run<Result, Input: InputProtocol, Output: OutputProtocol, Error: OutputProtocol>(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    input: Input = .none,
    output: Output,
    error: Error,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution<Output, Error>) async throws -> Result)
) async throws -> ExecutionResult<Result> where Output.OutputType == Void, Error.OutputType == Void


/// Run a executable with given parameters and a custom closure
/// to manage the running subprocess' lifetime and write to its
/// standard input via `StandardInputWriter`
/// - Parameters:
///   - executable: The executable to run.
///   - arguments: The arguments to pass to the executable.
///   - environment: The environment in which to run the executable.
///   - workingDirectory: The working directory in which to run the executable.
///   - platformOptions: The platform specific options to use
///     when running the executable.
///   - output:How to handle executable's standard output
///   - error: How to handle executable's standard error
///   - body: The custom execution body to manually control the running process
/// - Returns a ExecutableResult type containing the return value
///     of the closure.
#if SubprocessSpan
@available(SubprocessSpan, *)
#endif
public func run<Result, Output: OutputProtocol, Error: OutputProtocol>(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    output: Output,
    error: Error,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution<Output, Error>, StandardInputWriter) async throws -> Result)
) async throws -> ExecutionResult<Result> where Output.OutputType == Void, Error.OutputType == Void

/// Run a `Configuration` asynchrously and returns
/// a `CollectedResult` containing the output of the child process.
/// - Parameters:
///   - configuration: The `Subprocess` configuration to run.
///   - input: The input to send to the executable.
///   - output: The method to use for redirecting the standard output.
///   - error: The method to use for redirecting the standard error.
/// - Returns a CollectedResult containing the result of the run.
#if SubprocessSpan
@available(SubprocessSpan, *)
#endif
public func run<
    Input: InputProtocol,
    Output: OutputProtocol,
    Error: OutputProtocol
>(
    _ configuration: Configuration,
    input: Input = .none,
    output: Output = .string,
    error: Error = .discarded
) async throws -> CollectedResult<Output, Error>

/// Run a executable with given parameters specified by a `Configuration`,
/// redirect its standard output to sequence and discard its standard error.
/// - Parameters:
///   - configuration: The `Subprocess` configuration to run.
///   - body: The custom configuration body to manually control
///       the running process and write to its standard input.
/// - Returns a ExecutableResult type containing the return value
///     of the closure.
#if SubprocessSpan
@available(SubprocessSpan, *)
#endif
public func run<Result>(
    _ configuration: Configuration,
    isolation: isolated (any Actor)? = #isolation,
    body: ((Execution<SequenceOutput, DiscardedOutput>, StandardInputWriter) async throws -> Result)
) async throws -> ExecutionResult<Result>
```

The `run` methods can generally be divided into two categories, each addressing distinctive use cases of `Subprocess`:
- The first category returns a simple `CollectedResult` object, encapsulating information such as `ProcessIdentifier`, `TerminationStatus`, as well as collected standard output and standard error if requested. These methods are designed for straightforward use cases of `Subprocess`, where developers are primarily interested in the output or termination status of a process. Here are some examples:

```swift
// Simple ls with no standard input
let ls = try await run(.name("ls"))
print("Items in current directory: \(ls.standardOutput!)")

// Launch VSCode with arguments
let code = try await run(
    .name("code"),
    arguments: ["/some/directory"]
)
print("Code launched successfully: \(code.terminationStatus.isSuccess)")

// Launch `cat` with sequence written to standardInput
let inputData = Array("Hello SwiftFoundation".utf8)
let cat = try await run(
    .name("cat"),
    input: .array(inputData),
    output: .string
)
print("Cat result: \(cat.standardOutput!)")
```

- Alternatively, developers can leverage the closure-based approach. These methods spawn the child process and invoke the provided `body` closure with an `Execution` object. Developers can send signals to the running subprocess or transform `standardOutput` or `standardError` to the desired result type within the closure. One additional variation of the closure-based methods provides the `body` closure with an additional `StandardInputWriter` object, allowing developers to write to the standard input of the subprocess directly. These methods asynchronously wait for the child process to exit before returning the result.


```swift
// Use curl to call REST API
struct MyType: Codable { ... }

let result = try await run(
    .name("curl"),
    arguments: ["/some/rest/api"]
) {
    var buffer = Data()
    for try await chunk in $0.standardOutput {
        buffer += chunk
    }
    return try JSONDecoder().decode(MyType.self, from: buffer)
}
// Result will have type `MyType`
print("Result: \(result)")

// Perform custom write and write the standard output
let result = try await run(
    .path("/some/executable")
) { subprocess, writer in
    try await writer.write("Hello World".utf8CString)
    try await writer.finish()
    return try await Array(subprocess.standardOutput)
}
```

#### Unmanaged Subprocess

In addition to the managed `run` family of methods, `Subprocess` also supports an unmanaged `runDetached` method that simply spawns the executable and returns its process identifier without awaiting for it to complete. This mode is particularly useful in scripting scenarios where the subprocess being launched requires outlasting the parent process. This setup is essential for programs that function as “trampolines” (e.g., JVM Launcher) to spawn other processes.

Since `Subprocess` is unable to monitor the state of the subprocess or capture and clean up input/output, it requires explicit `FileDescriptor` to bind to the subprocess’ IOs. Developers are responsible for managing the creation and lifetime of the provided file descriptor; if no file descriptor is specified, `Subprocess` binds its standard IOs to `/dev/null`.

```swift
/// Run a executable with given parameters and return its process
/// identifier immediately without monitoring the state of the
/// subprocess nor waiting until it exits.
///
/// This method is useful for launching subprocesses that outlive their
/// parents (for example, daemons and trampolines).
///
/// - Parameters:
///   - executable: The executable to run.
///   - arguments: The arguments to pass to the executable.
///   - environment: The environment to use for the process.
///   - workingDirectory: The working directory for the process.
///   - platformOptions: The platform specific options to use for the process.
///   - input: A file descriptor to bind to the subprocess' standard input.
///   - output: A file descriptor to bind to the subprocess' standard output.
///   - error: A file descriptor to bind to the subprocess' standard error.
/// - Returns: the process identifier for the subprocess.
public func runDetached(
    _ executable: Executable,
    arguments: Arguments = [],
    environment: Environment = .inherit,
    workingDirectory: FilePath? = nil,
    platformOptions: PlatformOptions = PlatformOptions(),
    input: FileDescriptor? = nil,
    output: FileDescriptor? = nil,
    error: FileDescriptor? = nil
) throws -> ProcessIdentifier

/// Run a executable with given configuration and return its process
/// identifier immediately without monitoring the state of the
/// subprocess nor waiting until it exits.
///
/// This method is useful for launching subprocesses that outlive their
/// parents (for example, daemons and trampolines).
///
/// - Parameters:
///   - configuration: The `Subprocess` configuration to run.
///   - input: A file descriptor to bind to the subprocess' standard input.
///   - output: A file descriptor to bind to the subprocess' standard output.
///   - error: A file descriptor to bind to the subprocess' standard error.
/// - Returns: the process identifier for the subprocess.
public func runDetached(
    _ configuration: Configuration,
    input: FileDescriptor? = nil,
    output: FileDescriptor? = nil,
    error: FileDescriptor? = nil
) throws -> ProcessIdentifier
```


### `Execution`

In contrast to the monolithic `Process`, `Subprocess` utilizes two types to model the lifetime of a process. `Configuration` (discussed later) and `Execution`. `Execution` is designed to represent an executed process. This execution could be either in progress or completed. Direct construction of `Execution` instances is not supported; instead, a `Execution` object is passed to the `body` closure of `run()`. This object is only valid within the scope of the closure, and developers may use it to send signals to the child process or retrieve the child's standard I/Os via `AsyncSequence`s.

```swift
/// An object that represents a subprocess that has been
/// executed. You can use this object to send signals to the
/// child process as well as stream its output and error.
public struct Execution<
    Output: OutputProtocol,
    Error: OutputProtocol
>: Sendable {
    /// The process identifier of the current execution
    public let processIdentifier: ProcessIdentifier
}

extension Execution where Output == SequenceOutput {
    /// The standard output of the subprocess.
    /// Accessing this property will **fatalError** if
    /// - `.output` wasn't set to `.redirectToSequence` when the subprocess was spawned;
    /// - This property was accessed multiple times. Subprocess communicates with
    ///   parent process via pipe under the hood and each pipe can only be consumed once.
    public var standardOutput: some AsyncSequence<Buffer, any Swift.Error>
}

extension Execution where Error == SequenceOutput {
    /// The standard error of the subprocess.
    /// Accessing this property will **fatalError** if
    /// - `.error` wasn't set to `.redirectToSequence` when the subprocess was spawned;
    /// - This property was accessed multiple times. Subprocess communicates with
    ///   parent process via pipe under the hood and each pipe can only be consumed once.
    public var standardError: some AsyncSequence<Buffer, any Swift.Error>
}

#if canImport(WinSDK)
/// A platform independent identifier for a subprocess.
public struct ProcessIdentifier: Sendable, Hashable, Codable {
    /// Windows specifc process identifier value
    public let value: DWORD
}
#else
/// A platform independent identifier for a Subprocess.
public struct ProcessIdentifier: Sendable, Hashable, Codable {
    /// The platform specific process identifier value
    public let value: pid_t
}
#endif

```


#### Signals (macOS and Linux)

`Subprocess` uses `struct Signal` to represent the signal that could be sent via `send()` on Unix systems (macOS and Linux). Developers could either initialize `Signal` directly using the raw signal value or use one of the common values defined as static property.

```swift
#if canImport(Glibc) || canImport(Darwin)

/// Signals are standardized messages sent to a running program
/// to trigger specific behavior, such as quitting or error handling.
public struct Signal : Hashable, Sendable {
    /// The underlying platform specific value for the signal
    public let rawValue: Int32

    /// The `.interrupt` signal is sent to a process by its
    /// controlling terminal when a user wishes to interrupt
    /// the process.
    public static var interrupt: Self { get }
    /// The `.terminate` signal is sent to a process to request its
    /// termination. Unlike the `.kill` signal, it can be caught
    /// and interpreted or ignored by the process. This allows
    /// the process to perform nice termination releasing resources
    /// and saving state if appropriate. `.interrupt` is nearly
    /// identical to `.terminate`.
    public static var terminate: Self { get }
    /// The `.suspend` signal instructs the operating system
    /// to stop a process for later resumption.
    public static var suspend: Self { get }
    /// The `resume` signal instructs the operating system to
    /// continue (restart) a process previously paused by the
    /// `.suspend` signal.
    public static var resume: Self { get }
    /// The `.kill` signal is sent to a process to cause it to
    /// terminate immediately (kill). In contrast to `.terminate`
    /// and `.interrupt`, this signal cannot be caught or ignored,
    /// and the receiving process cannot perform any
    /// clean-up upon receiving this signal.
    public static var kill: Self { get }
    /// The `.terminalClosed` signal is sent to a process when
    /// its controlling terminal is closed. In modern systems,
    /// this signal usually means that the controlling pseudo
    /// or virtual terminal has been closed.
    public static var terminalClosed: Self { get }
    /// The `.quit` signal is sent to a process by its controlling
    /// terminal when the user requests that the process quit
    /// and perform a core dump.
    public static var quit: Self { get }
    /// The `.userDefinedOne` signal is sent to a process to indicate
    /// user-defined conditions.
    public static var userDefinedOne: Self { get }
    /// The `.userDefinedTwo` signal is sent to a process to indicate
    /// user-defined conditions.
    public static var userDefinedTwo: Self { get }
    /// The `.alarm` signal is sent to a process when the corresponding
    /// time limit is reached.
    public static var alarm: Self { get }
    /// The `.windowSizeChange` signal is sent to a process when
    /// its controlling terminal changes its size (a window change).
    public static var windowSizeChange: Self { get }

    public init(rawValue: Int32)
}

extension Execution {
    /// Send the given signal to the child process.
    /// - Parameters:
    ///   - signal: The signal to send.
    ///   - shouldSendToProcessGroup: Whether this signal should be sent to
    ///     the entire process group.
    public func send(
        signal: Signal,
        toProcessGroup shouldSendToProcessGroup: Bool = false
    ) throws
}

#endif // canImport(Glibc) || canImport(Darwin)
```

#### Teardown Sequence

`Subprocess` provides a graceful shutdown mechanism for child processes using the `.teardown(using:)` method. This method allows for a sequence of teardown steps to be executed, with the final step always sending a `.kill` signal on Unix or forcefully terminating the process on Windows.

```swift
/// A step in the graceful shutdown teardown sequence.
/// It consists of an action to perform on the child process and the
/// duration allowed for the child process to exit before proceeding
/// to the next step.
public struct TeardownStep: Sendable, Hashable {
#if !os(Windows)
    /// Sends `signal` to the process and allows `allowedDurationToNextStep`
    /// for the process to exit before proceeding to the next step.
    /// The final step in the sequence will always send a `.kill` signal.
    public static func sendSignal(
        _ signal: Signal,
        allowedDurationToNextStep: Duration
    ) -> Self
#endif

    /// Attempt to perform a graceful shutdown and allows
    /// `alloweDurationToNextStep` for the process to exit
    /// before proceeding to the next step:
    /// - On Unix: send `SIGTERM`
    /// - On Windows:
    ///   1. Attempt to send `VM_CLOSE` if the child process is a GUI process;
    ///   2. Attempt to send `CTRL_C_EVENT` to console;
    ///   3. Attempt to send `CTRL_BREAK_EVENT` to process group.
    public static func gracefulShutDown(
        alloweDurationToNextStep: Duration
    ) -> Self
}

extension Execution {
    /// Performs a sequence of teardown steps on the Subprocess.
    /// Teardown sequence always ends with a `.kill` signal
    /// - Parameter sequence: The  steps to perform.
    public func teardown(using sequence: some Sequence<TeardownStep> & Sendable) async
}
```

A teardown sequence involves a set of actions taken on the child process, with a set time limit for it to wrap up before moving on. On platforms like Darwin and Linux, developers can also send signals directly to the child process. For example, it might be wise to start with `.quit` and `.terminate` signals to ensure a smooth shutdown before resorting to `.kill`.

```swift
let result = try await run(
    .path("/bin/bash"),
    arguments: [...]
) { execution in
    // ... more work
    await execution.teardown(using: [
        .sendSignal(.quit, allowedDurationToNextStep: .milliseconds(100)),
        .sendSignal(.terminate, allowedDurationToNextStep: .milliseconds(100)),
    ])
}
```

#### Process Controls (Windows)

The Windows does not have a centralized signaling system similar to Unix. Instead, it provides direct methods to suspend, resume, and terminate the subprocess:


```swift
#if canImport(WinSDK)
extension Execution {
    /// Terminate the current subprocess with the given exit code
    /// - Parameter exitCode: The exit code to use for the subprocess.
    public func terminate(withExitCode exitCode: DWORD) throws
    /// Suspend the current subprocess
    public func suspend() throws
    /// Resume the current subprocess after suspension
    public func resume() throws
}
#endif
```


### `Configuration`

`Configuration` represents the collection of information needed to spawn a process. This type is designed to be very similar to the existing `Process`, enabling you to configure your process in a manner akin to `NSTask`:

```swift
/// A collection of configurations parameters to use when
/// spawning a subprocess.
public struct Configuration : Sendable, Hashable {
    /// The executable to run.
    public var executable: Executable
    /// The arguments to pass to the executable.
    public var arguments: Arguments
    /// The environment to use when running the executable.
    public var environment: Environment
    /// The working directory to use when running the executable.
    public var workingDirectory: FilePath
    /// The platform specifc options to use when
    /// running the subprocess.
    public var platformOptions: PlatformOptions

    public init(
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default
    )
}

extension Configuration : CustomStringConvertible, CustomDebugStringConvertible {}
```

**Note:** the `.workingDirectory` property defaults to the current working directory of the calling process.


### `StandardInputWriter`

`StandardInputWriter` provides developers with direct control over writing to the child process's standard input. Similar to the `Execution` object, developers should use the `StandardInputWriter` object passed to the `body` closure, and this object is only valid within the body of the closure.

**Note**: Developers should call `finish()` when they have completed writing to signal that the standard input file descriptor should be closed.

In the core `Subprocess` module, `StandardInputWriter` offers overrides of `write()` methods for writing `String`s and `UInt8` arrays:

```swift
/// A writer that writes to the standard input of the subprocess.
public final actor StandardInputWriter {
    /// Write an array of UInt8 to the standard input of the subprocess.
    /// - Parameter array: The sequence of bytes to write.
    /// - Returns number of bytes written.
    public func write(
        _ array: [UInt8]
    ) async throws -> Int

    /// Write a `RawSpan` to the standard input of the subprocess.
    /// - Parameter span: The span to write
    /// - Returns number of bytes written
#if SubprocessSpan
    @available(SubprocessSpan, *)
    public func write(
        _ span: borrowing RawSpan
    ) async throws -> Int
#endif

    /// Write a StringProtocol to the standard input of the subprocess.
    /// - Parameters:
    ///   - string: The string to write.
    ///   - encoding: The encoding to use when converting string to bytes
    /// - Returns number of bytes written.
    public func write<Encoding: Unicode.Encoding>(
        _ string: some StringProtocol,
        using encoding: Encoding.Type = UTF8.self
    ) async throws -> Int

    /// Signal all writes are finished
    public func finish() async throws
}
```

`SubprocessFoundation` trait extends `StandardInputWriter` to work with `Data`:

```swift
#if SubprocessFoundation
import Foundation

extension StandardInputWriter {
    /// Write a `Data` to the standard input of the subprocess.
    /// - Parameter data: The sequence of bytes to write.
    /// - Returns number of bytes written.
    public func write(
        _ data: Data
    ) async throws -> Int

    /// Write a AsyncSequence of Data to the standard input of the subprocess.
    /// - Parameter sequence: The sequence of bytes to write.
    /// - Returns number of bytes written.
    public func write<AsyncSendableSequence: AsyncSequence & Sendable>(
        _ asyncSequence: AsyncSendableSequence
    ) async throws -> Int where AsyncSendableSequence.Element == Data
}
#endif
```


### `PlatformOptions` on Darwin

Beyond the configurable parameters exposed by these static run methods, `Configuration` also provides **platform-specific** launch options via `PlatformOptions`. For Darwin, we propose the following `PlatformOptions`:

```swift
#if canImport(Darwin)
/// The collection of platform-specific settings
/// to configure the subprocess when running
public struct PlatformOptions: Sendable, Hashable {
    public var qualityOfService: QualityOfService
    // Set user ID for the subprocess
    public var userID: uid_t?
    /// Set the real and effective group ID and the saved
    /// set-group-ID of the subprocess, equivalent to calling
    /// `setgid()` on the child process.
    /// Group ID is used to control permissions, particularly
    /// for file access.
    public var groupID: gid_t?
    // Set list of supplementary group IDs for the subprocess
    public var supplementaryGroups: [gid_t]?
    /// Set the process group for the subprocess, equivalent to
    /// calling `setpgid()` on the child process.
    /// Process group ID is used to group related processes for
    /// controlling signals.
    public var processGroupID: pid_t? = nil
    // Creates a session and sets the process group ID
    // i.e. Detach from the terminal.
    public var createSession: Bool
    public var launchRequirementData: Data?
    /// An ordered list of steps in order to tear down the child
    /// process in case the parent task is cancelled before
    /// the child proces terminates.
    /// Always ends in sending a `.kill` signal at the end.
    public var teardownSequence: [TeardownStep]
    /// A closure to configure platform-specific
    /// spawning constructs. This closure enables direct
    /// configuration or override of underlying platform-specific
    /// spawn settings that `Subprocess` utilizes internally,
    /// in cases where Subprocess does not provide higher-level
    /// APIs for such modifications.
    ///
    /// On Darwin, Subprocess uses `posix_spawn()` as the
    /// underlying spawning mechanism. This closure allows
    /// modification of the `posix_spawnattr_t` spawn attribute
    /// and file actions `posix_spawn_file_actions_t` before
    /// they are sent to `posix_spawn()`.
    public var preSpawnProcessConfigurator: (
        @Sendable (
            inout posix_spawnattr_t?,
            inout posix_spawn_file_actions_t?
        ) throws -> Void
    )? = nil

    public init() {}
}

extension PlatformOptions : CustomStringConvertible, CustomDebugStringConvertible {}
#endif // canImport(Darwin)
```

`PlatformOptions` also supports “escape hatches” that enable developers to configure the underlying platform-specific objects directly if `Subprocess` lacks corresponding high-level APIs.

For Darwin, we propose a closure `.preSpawnProcessConfigurator: (@Sendable (inout posix_spawnattr_t?, inout posix_spawn_file_actions_t?) throws -> Void` which provides developers with an opportunity to configure `posix_spawnattr_t` and `posix_spawn_file_actions_t` just before they are passed to `posix_spawn()`. For instance, developers can set additional spawn flags:

```swift
var platformOptions = PlatformOptions()
platformOptions.preSpawnProcessConfigurator = { spawnAttr, _ in
    let flags: Int32 = POSIX_SPAWN_CLOEXEC_DEFAULT |
        POSIX_SPAWN_SETSIGMASK |
        POSIX_SPAWN_SETSIGDEF |
        POSIX_SPAWN_START_SUSPENDED
    posix_spawnattr_setflags(&spawnAttr, Int16(flags))
}
```

Similarly, a developer might want to bind child file descriptors, other than standard input (fd 0), standard output (fd 1), and standard error (fd 2), to parent file descriptors:

```swift
var platformOptions = PlatformOptions()
// Bind child fd 4 to a parent fd
platformOptions.preSpawnProcessConfigurator = { _, fileAttr in
    let parentFd: FileDescriptor = …
    posix_spawn_file_actions_adddup2(&fileAttr, parentFd.rawValue, 4)
}
```


### `PlatformOptions` on Linux

For Linux, we propose a similar `PlatformOptions` configuration:

```swift
#if canImport(Glibc)
/// The collection of Linux specific configurations
public struct PlatformOptions: Sendable, Hashable {
    // Set user ID for the subprocess
    public var userID: uid_t?
    /// Set the real and effective group ID and the saved
    /// set-group-ID of the subprocess, equivalent to calling
    /// `setgid()` on the child process.
    /// Group ID is used to control permissions, particularly
    /// for file access.
    public var groupID: gid_t?
    // Set list of supplementary group IDs for the subprocess
    public var supplementaryGroups: [gid_t]?
    /// Set the process group for the subprocess, equivalent to
    /// calling `setpgid()` on the child process.
    /// Process group ID is used to group related processes for
    /// controlling signals.
    public var processGroupID: pid_t?
    // Creates a session and sets the process group ID
    // i.e. Detach from the terminal.
    public var createSession: Bool
    // Whether the subprocess should close all file
    // descriptors except for the ones explicitly passed
    // as `input`, `output`, or `error` when `run` is executed
    // This is equivelent to setting `POSIX_SPAWN_CLOEXEC_DEFAULT`
    // on Darwin. This property is default to be `false`
    // because `POSIX_SPAWN_CLOEXEC_DEFAULT` is a darwin-specific
    // extension and we can only emulate it on Linux.
    public var closeAllUnknownFileDescriptors: Bool
    /// An ordered list of steps in order to tear down the child
    /// process in case the parent task is cancelled before
    /// the child proces terminates.
    /// Always ends in sending a `.kill` signal at the end.
    public var teardownSequence: [TeardownStep] = []
    /// A closure to configure platform-specific
    /// spawning constructs. This closure enables direct
    /// configuration or override of underlying platform-specific
    /// spawn settings that `Subprocess` utilizes internally,
    /// in cases where Subprocess does not provide higher-level
    /// APIs for such modifications.
    ///
    /// On Linux, Subprocess uses `fork/exec` as the
    /// underlying spawning mechanism. This closure is called
    /// after `fork()` but before `exec()`. You may use it to
    /// call any necessary process setup functions.
    public var preSpawnProcessConfigurator: (
        @convention(c) @Sendable () -> Void
    )? = nil

    public init() {}
}

extension PlatformOptions : CustomStringConvertible, CustomDebugStringConvertible {}
#endif // canImport(Glibc)
```

Similar to the Darwin version, the Linux `PlatformOptions` also has an "escape hatch" closure that allows the developers to explicitly configure the subprocess. This closure is run after `fork` but before `exec`. In the example below, `preSpawnProcessConfigurator` can be used to set the group ID for the subprocess:

```swift
var platformOptions: PlatformOptions = .default
// Set Group ID for process
platformOptions.preSpawnProcessConfigurator = {
    setgid(4321)
}
```


### `PlatformOptions` on Windows

On Windows, we propose the following `PlatformOptions`:

```swift
#if canImport(WinSDK)
/// The collection of platform-specific settings
/// to configure the subprocess when running
public struct PlatformOptions: Sendable, Hashable {
    public struct UserCredentials: Sendable, Hashable {
        // The name of the user. This is the name
        // of the user account to run as.
        public var username: String
        // The clear-text password for the account.
        public var password: String
        // The name of the domain or server whose account database
        // contains the account.
        public var domain: String?
    }

    /// `ConsoleBehavior` defines how should the console appear
    /// when spawning a new process
    public struct ConsoleBehavior: Sendable, Hashable {
        /// The subprocess has a new console, instead of
        /// inheriting its parent's console (the default).
        public static let createNew: Self
        /// For console processes, the new process does not
        /// inherit its parent's console (the default).
        /// The new process can call the `AllocConsole`
        /// function at a later time to create a console.
        public static let detatch: Self
        /// The subprocess inherits its parent's console.
        public static let inherit: Self
    }

    /// `ConsoleBehavior` defines how should the window appear
    /// when spawning a new process
    public struct WindowStyle: Sendable, Hashable {
        /// Activates and displays a window of normal size
        public static let normal: Self
        /// Does not activate a new window
        public static let hidden: Self
        /// Activates the window and displays it as a maximized window.
        public static let maximized: Self
        /// Activates the window and displays it as a minimized window.
        public static let minimized: Self
    }

    /// Sets user info when starting the process. If this
    /// property is set, the Subprocess will be run
    /// as the provided user
    public var userCredentials: UserCredentials? = nil
    /// The console behavior of the new process,
    /// default to inheriting the console from parent process
    public var consoleBehavior: ConsoleBehavior = .inherit
    /// Window style to use when the process is started
    public var windowStyle: WindowStyle = .normal
    /// Whether to create a new process group for the new
    /// process. The process group includes all processes
    /// that are descendants of this root process.
    /// The process identifier of the new process group
    /// is the same as the process identifier.
    public var createProcessGroup: Bool = false
    /// An ordered list of steps in order to tear down the child
    /// process in case the parent task is cancelled before
    /// the child proces terminates.
    /// Always ends in forcefully terminate at the end.
    public var teardownSequence: [TeardownStep] = []
    /// A closure to configure platform-specific
    /// spawning constructs. This closure enables direct
    /// configuration or override of underlying platform-specific
    /// spawn settings that `Subprocess` utilizes internally,
    /// in cases where Subprocess does not provide higher-level
    /// APIs for such modifications.
    ///
    /// On Windows, Subprocess uses `CreateProcessW()` as the
    /// underlying spawning mechanism. This closure allows
    /// modification of the `dwCreationFlags` creation flag
    /// and startup info `STARTUPINFOW` before
    /// they are sent to `CreateProcessW()`.
    public var preSpawnProcessConfigurator: (
        @Sendable (
            inout DWORD,
            inout STARTUPINFOW
        ) throws -> Void
    )? = nil

    public init() {}
}

extension PlatformOptions : CustomStringConvertible, CustomDebugStringConvertible {}
#endif // canImport(WinSDK)
```

Windows `PlatformOptions` uses `preSpawnProcessConfigurator` as the "escape hatch". Developers could use this closure to configure `dwCreationFlags` and `lpStartupInfo` that are used by the platform `CreateProcessW` to spawn the process:

```swift
var platformOptions: PlatformOptions = .default
// Set Group ID for process
platformOptions.preSpawnProcessConfigurator = { flag, startupInfo in
    // Set CREATE_NEW_CONSOLE for flag
    flag |= DWORD(CREATE_NEW_CONSOLE)

    // Set the window position
    startupInfo.dwX = 0
    startupInfo.dwY = 0
    startupInfo.dwXSize = 100
    startupInfo.dwYSize = 100
}
```
_(For more information on these values, checkout Microsoft's documentation [here](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw))_


### `InputProtocol`

`InputProtocol` defines the `write(with:)` method that a type must implement to serve as the input source for a subprocess. In most cases, developers should utilize the concrete input types provided by `Subprocess`.

The core `Subprocess` module is distributed with the following concrete input types:

- `NoInput`: indicates there is no input sent to the subprocess.
- `FileDescriptorInput`: reads input from a specified `FileDescriptor` provided by the developer. Subprocess will automatically close the file descriptor after the process is spawned if `closeAfterSpawningProcess` is set to `true`. Note: when `closeAfterSpawningProcess` is `false`, the caller is responsible for closing the file descriptor even if `Subprocess` fails to spawn.
- `StringInput`: reads input from a given type conforming to `StringProtocol`.
- `ArrayInput`: reads input from a given array of `UInt8`.
- `CustomWriteInput`indicates that the Subprocess should read its input from `StandardInputWriter`.


```swift
/// `InputProtocol` defines the `write(with:)` method that a type
/// must implement to serve as the input source for a subprocess.
public protocol InputProtocol: Sendable {
    /// Asynchronously write the input to the subprocess using the
    /// write file descriptor
    func write(with writer: StandardInputWriter) async throws
}

/// A concrete `Input` type for subprocesses that indicates
/// the absence of input to the subprocess. On Unix-like systems,
/// `NoInput` redirects the standard input of the subprocess
/// to `/dev/null`, while on Windows, it does not bind any
/// file handle to the subprocess standard input handle.
public struct NoInput: InputProtocol { }

/// A concrete `Input` type for subprocesses that
/// reads input from a specified `FileDescriptor`.
/// Developers have the option to instruct the `Subprocess` to
/// automatically close the provided `FileDescriptor`
/// after the subprocess is spawned.
public struct FileDescriptorInput: InputProtocol { }

/// A concrete `Input` type for subprocesses that reads input
/// from a given type conforming to `StringProtocol`.
/// Developers can specify the string encoding to use when
/// encoding the string to data, which defaults to UTF-8.
public struct StringInput<
    InputString: StringProtocol & Sendable,
    Encoding: Unicode.Encoding
>: InputProtocol { }

/// A concrete `Input` type for subprocesses that reads input
/// from a given `UInt8` Array.
public struct ArrayInput: InputProtocol { }

/// A concrete `Input` type for subprocess that indicates that
/// the Subprocess should read its input from `StandardInputWriter`.
public struct CustomWriteInput: InputProtocol { }

extension InputProtocol where Self == NoInput {
    /// Create a Subprocess input that specfies there is no input
    public static var none: Self { get }
}

extension InputProtocol where Self == FileDescriptorInput {
    /// Create a Subprocess input from a `FileDescriptor` and
    /// specify whether the `FileDescriptor` should be closed
    /// after the process is spawned.
    public static func fileDescriptor(
        _ fd: FileDescriptor,
        closeAfterSpawningProcess: Bool
    ) -> Self
}

extension InputProtocol {
    /// Create a Subprocess input from a `Array` of `UInt8`.
    public static func array(
        _ array: [UInt8]
    ) -> Self where Self == ArrayInput

    /// Create a Subprocess input from a type that conforms to `StringProtocol`
    public static func string<
        InputString: StringProtocol & Sendable
    >(
        _ string: InputString
    ) -> Self where Self == StringInput<InputString, UTF8>

    /// Create a Subprocess input from a type that conforms to `StringProtocol`
    public static func string<
        InputString: StringProtocol & Sendable,
        Encoding: Unicode.Encoding & Sendable
    >(
        _ string: InputString,
        using encoding: Encoding.Type
    ) -> Self where Self == StringInput<InputString, Encoding>
}
```

`SubprocessFoundation` trait adds the following concrete input types that work with `Data`:

- `DataInput`: reads input from a given `Data`.
- `DataSequenceInput`: reads input from a given sequence of `Data`.
- `DataAsyncSequenceInput`: reads input from a given async sequence of `Data`.

```swift
#if SubprocessFoundation
import Foundation

/// A concrete `Input` type for subprocesses that reads input
/// from a given `Data`.
public struct DataInput: ManagedInputProtocol { }

/// A concrete `Input` type for subprocesses that accepts input
/// from a specified sequence of `Data`. This type should be preferred
/// over `Subprocess.UInt8SequenceInput` when dealing with
/// large amount input data.
public struct DataSequenceInput<
    InputSequence: Sequence & Sendable
>: ManagedInputProtocol where InputSequence.Element == Data { }

/// A concrete `Input` type for subprocesses that reads input
/// from a given async sequence of `Data`.
public struct DataAsyncSequenceInput<
    InputSequence: AsyncSequence & Sendable
>: ManagedInputProtocol where InputSequence.Element == Data { }


extension InputProtocol {
    /// Create a Subprocess input from a `Data`
    public static func data(_ data: Data) -> Self where Self == DataInput

    /// Create a Subprocess input from a `Sequence` of `Data`.
    public static func sequence<InputSequence: Sequence & Sendable>(
        _ sequence: InputSequence
    ) -> Self where Self == DataSequenceInput<InputSequence>

    /// Create a Subprocess input from a `AsyncSequence` of `Data`.
    public static func sequence<InputSequence: AsyncSequence & Sendable>(
        _ asyncSequence: InputSequence
    ) -> Self where Self == DataAsyncSequenceInput<InputSequence>
}
#endif
```

Here are some examples:

```swift
// By default `InputMethod` is set to `.none`
let ls = try await run(.name("ls"))

// Alternatively, developers could pass in a file descriptor
let fd: FileDescriptor = ...
let cat = try await run(
    .name("cat"),
    input: .fileDescriptor(
        fd,
        closeAfterSpawningProcess: true
    )
)

// Pass in a async sequence directly
let sequence: AsyncSequence<Data> = ...
let exe = try await run(.path("/some/executable"), input: .sequence(sequence))
```


### `OutputProtocol`


`OutputProtocol` defines the set of methods that a type must implement to serve as the output target for a subprocess. Similarly to `InputProtocol`, developers should utilize the built-in concrete `Output` types provided with `Subprocess` whenever feasible.

`OutputProtocol` was primarily designed with `RawSpan` as the primary "currency type". When `RawSpan` is not available, or when the `SubprocessSpan` trait is off, `OutputProtocol` falls back to `Sequence<UInt8>`.

The core `Subprocess` module comes with the following concrete output types:

- `DiscardedOutput`: indicates that the `Subprocess` should not collect or redirect output from the child process.
- `FileDescriptorOutput`: writes output to a specified `FileDescriptor`. Developers have the option to instruct the `Subprocess` to automatically close the provided `FileDescriptor` after the subprocess is spawned.
- `StringOutput`: collects output from the subprocess as `String` with the given encoding.
- `BytesOutput`: collects output from subprocess as `[UInt8]`.
- `SequenceOutput`: redirects the child output to the `.standardOutput` or `.standardError` property of `Execution`. This output type is only applicable to the `run()` family that takes a custom closure.


```swift
/// `OutputProtocol` specifies the set of methods that a type
/// must implement to serve as the output target for a subprocess.
/// Instead of developing custom implementations of `OutputProtocol`,
/// it is recommended to utilize the default implementations provided
/// by the `Subprocess` library to specify the output handling requirements.
#if SubprocessSpan
@available(SubprocessSpan, *)
#endif
public protocol OutputProtocol: Sendable {
    associatedtype OutputType: Sendable

#if SubprocessSpan
    /// Convert the output from span to expected output type
    func output(from span: RawSpan) throws -> OutputType
#endif

    /// Convert the output from buffer to expected output type
    func output(from buffer: some Sequence<UInt8>) throws -> OutputType

    /// The max amount of data to collect for this output.
    var maxSize: Int { get }
}

extension OutputProtocol {
    /// Default implementation provided
    public var maxSize: Int { 128 * 1024 }
}

#if SubprocessSpan
extension OutputProtocol {
    // Default implementation provided
    public func output(from buffer: some Sequence<UInt8>) throws -> OutputType { ... }
}
#endif

/// A concrete `Output` type for subprocesses that indicates that
/// the `Subprocess` should not collect or redirect output
/// from the child process. On Unix-like systems, `DiscardedOutput`
/// redirects the standard output of the subprocess to `/dev/null`,
/// while on Windows, it does not bind any file handle to the
/// subprocess standard output handle.
public struct DiscardedOutput: OutputProtocol { }

/// A concrete `Output` type for subprocesses that
/// writes output to a specified `FileDescriptor`.
/// Developers have the option to instruct the `Subprocess` to
/// automatically close the provided `FileDescriptor`
/// after the subprocess is spawned.
public struct FileDescriptorOutput: OutputProtocol { }

/// A concrete `Output` type for subprocesses that collects output
/// from the subprocess as `String` with the given encoding.
/// This option must be used with he `run()` method that
/// returns a `CollectedResult`.
public struct StringOutput<Encoding: Unicode.Encoding>: OutputProtocol { }

/// A concrete `Output` type for subprocesses that collects output
/// from the subprocess as `[UInt8]`. This option must be used with
/// the `run()` method that returns a `CollectedResult`
public struct BytesOutput: OutputProtocol { }

/// A concrete `Output` type for subprocesses that redirects
/// the child output to the `.standardOutput` or `.standardError`
/// property of `Execution`. This output type is
/// only applicable to the `run()` family that takes a custom closure.
public struct SequenceOutput: OutputProtocol { }


extension OutputProtocol where Self == DiscardedOutput {
    /// Create a Subprocess output that discards the output
    public static var discarded: Self { }
}

extension OutputProtocol where Self == FileDescriptorOutput {
    /// Create a Subprocess output that writes output to a `FileDescriptor`
    /// and optionally close the `FileDescriptor` once process spawned.
    public static func fileDescriptor(
        _ fd: FileDescriptor,
        closeAfterSpawningProcess: Bool
    ) -> Self
}

extension OutputProtocol where Self == SequenceOutput {
    /// Create a `Subprocess` output that redirects the output
    /// to the `.standardOutput` (or `.standardError`) property
    /// of `Execution` as `AsyncSequence<Data>`.
    public static var sequence: Self { .init() }
}

extension OutputProtocol where Self == StringOutput<UTF8> {
    /// Create a `Subprocess` output that collects output as
    /// UTF8 String with 128kb limit.
    public static var string: Self
}

extension OutputProtocol {
    /// Create a `Subprocess` output that collects output as
    /// `String` using the given encoding up to limit it bytes.
    public static func string<Encoding: Unicode.Encoding>(
        limit: Int,
        encoding: Encoding.Type
    ) -> Self where Self == StringOutput<Encoding>
}

extension OutputProtocol where Self == BytesOutput {
    /// Create a `Subprocess` output that collects output as
    /// `Buffer` with 128kb limit.
    public static var bytes: Self

    /// Create a `Subprocess` output that collects output as
    /// `Buffer` up to limit it bytes.
    public static func bytes(limit: Int) -> Self
}
```


`SubprocessFoundation` trait adds one additional concrete input:

- `DataOutput`: collects output from the subprocess as `Data`.


```swift
#if SubprocessFoundation
import Foundation

/// A concrete `Output` type for subprocesses that collects output
/// from the subprocess as `Data`. This option must be used with
/// the `run()` method that returns a `CollectedResult`
public struct DataOutput: OutputProtocol { }

extension OutputProtocol where Self == DataOutput {
    /// Create a `Subprocess` output that collects output as `Data`
    /// up to 128kb.
    public static var data: Self {
        return .data(limit: 128 * 1024)
    }

    /// Create a `Subprocess` output that collects output as `Data`
    /// with given max number of bytes to collect.
    public static func data(limit: Int) -> Self  {
        return .init(limit: limit)
    }
}
#endif
```

Here are some examples of using different outputs:

```swift
let ls = try await run(.name("ls"), output: .string)
// The output has been collected as `String`, up to 128kb limit
print("ls output: \(ls.standardOutout!)")

// Increase the default buffer limit to 256kb and collect output as Data
let curl = try await run(
    .name("curl"),
    output: .data(limit: 256 * 1024)
)
print("curl output: \(curl.standardOutput.count)")


// Write to a specific file descriptor
let fd: FileDescriptor = try .open(...)
let result = try await run(
    .path("/some/script"),
    output: .fileDescriptor(fd, closeAfterSpawningProcess: true)
)
```


### `SequenceOutput.Buffer`

When utilizing the closure-based `run()` method with `SequenceOutput`, developers have the option to ‘stream’ the standard output or standard error of the subprocess as an `AsyncSequence`. To enhance performance, it’s more efficient to stream a collection of bytes at once rather than individually. Since the core `Subprocess` module doesn’t rely on `Foundation`, we propose introducing a simple `struct Buffer` to serve as our ‘collection of bytes’. This `Buffer` enables `Subprocess` to reduce the frequency of data copying by maintaining references to internal data types.

```swift
extension SequenceOutput {
    /// A immutable collection of bytes
    public struct Buffer: Sendable, Hashable, Equatable {
        /// Number of bytes stored in the buffer
        public var count: Int { get }

        /// A Boolean value indicating whether the collection is empty.
        public var isEmpty: Bool { get }

        /// Access the raw bytes stored in this buffer
        /// - Parameter body: A closure with an `UnsafeRawBufferPointer` parameter that
        ///   points to the contiguous storage for the type. If no such storage exists,
        ///   the method creates it. If body has a return value, this method also returns
        ///   that value. The argument is valid only for the duration of the
        ///   closure’s execution.
        /// - Returns: The return value, if any, of the body closure parameter.
        public func withUnsafeBytes<ResultType>(
            _ body: (UnsafeRawBufferPointer) throws -> ResultType
        ) rethrows -> ResultType

#if SubprocessSpan
        /// Access the bytes stored in this buffer as `RawSpan`
        @available(SubprocessSpan, *)
        var bytes: RawSpan { get }
#endif
    }
}

```

`Buffer` is designed specifically to meet the specific needs of `Subprocess` rather than serving as a general-purpose byte container. It’s immutable, and the main method to access data from a `Buffer` is through `RawSpan`.

```swift
let catResult = try await Subprocess.run(
    .path("..."),
    output: .sequence,
    error: .discarded
) { execution in
    for try await chunk in execution.standardOutput {
        // Pending String RawSpan support
        let value = String(chunk.bytes, as: UTF8.self)
        if value.contains("Done") {
            await execution.teardown(
                using: [
                    .sendSignal(.quit, allowedDurationToNextStep: .milliseconds(500)),
                ]
            )
            return true
        }
    }
    return false
}
```


### Result Types

`Subprocess` provides two "Result" types corresponding to the two categories of `run` methods: `CollectedResult<Output: OutputProtocol, Error: OutputProtocol>` and `ExecutionResult<Result>`.

`CollectedResult` is essentially a collection of properties that represent the result of an execution after the child process has exited. It is used by the non-closure-based `run` methods. In many ways, `CollectedResult` can be seen as the "synchronous" version of `Subprocess`—instead of the asynchronous `AsyncSequence<Buffer>`, the standard IOs can be retrieved via synchronous `Buffer` or `String?`.

```swift
/// The result of a subprocess execution with its collected
/// standard output and standard error.
public struct CollectedResult<
    Output: OutputProtocol,
    Error: OutputProtocol
>: Sendable {
    /// The process identifier for the executed subprocess
    public let processIdentifier: ProcessIdentifier
    /// The termination status of the executed subprocess
    public let terminationStatus: TerminationStatus
    public let standardOutput: Output.OutputType
    public let standardError: Error.OutputType
}

extension CollectedResult: Equatable where Output.OutputType: Equatable, Error.OutputType: Equatable {}

extension CollectedResult: Hashable where Output.OutputType: Hashable, Error.OutputType: Hashable {}

extension CollectedResult: Codable where Output.OutputType: Codable, Error.OutputType: Codable {}

extension CollectedResult: CustomStringConvertible where Output.OutputType: CustomStringConvertible, Error.OutputType: CustomStringConvertible
```

`ExecutionResult` is a simple wrapper around the generic result returned by the `run` closures with the corresponding `TerminationStatus` of the child process:

```swift
/// A simple wrapper around the generic result returned by the
/// `run` closures with the corresponding `TerminationStatus`
/// of the child process.
public struct ExecutionResult<Result> {
    /// The termination status of the child process
    public let terminationStatus: TerminationStatus
    /// The result returned by the closure passed to `.run` methods
    public let value: Result
}

extension ExecutionResult: Equatable where Result : Equatable {}

extension ExecutionResult : Hashable where Result : Hashable {}

extension ExecutionResult : Codable where Result : Codable {}

extension ExecutionResult: CustomStringConvertible where Result : CustomStringConvertible {}

extension ExecutionResult: CustomDebugStringConvertible where Result : CustomDebugStringConvertible {}
```


### `Executable`

`Subprocess` utilizes `Executable` to configure how the executable is resolved. Developers can create an `Executable` using two static methods: `.name()`, indicating that an executable name is provided, and `Subprocess` should try to automatically resolve the executable path, and `.path()`, signaling that an executable path is provided, and `Subprocess` should use it unmodified.

```swift
/// `Executable` defines how should the executable
/// be looked up for execution.
public struct Executable: Sendable, Hashable {
    /// Locate the executable by its name.
    /// `Subprocess` will use `PATH` value to
    /// determine the full path to the executable.
    public static func name(_ executableName: String) -> Self
    /// Locate the executable by its full path.
    /// `Subprocess` will use this  path directly.
    public static func path(_ filePath: FilePath) -> Self
    /// Returns the full executable path given the environment value.
    public func resolveExecutablePath(in environment: Environment) throws -> FilePath
}

extension Executable : CustomStringConvertible, CustomDebugStringConvertible {}
```


### `Environment`

`struct Environment` is used to configure how should the process being launched receive its environment values:

```swift
public struct Environment: Sendable, Hashable {
    /// Child process should inherit the same environment
    /// values from its parent process.
    public static var inherit: Self { get }
    /// Override the provided `newValue` in the existing `Environment`
    public func updating(
        _ newValue: [String : String]
    ) -> Self
    /// Use custom environment variables
    public static func custom(
        _ newValue: [String : String]
    ) -> Self

#if !os(Windows)
    /// Use custom environment variables of raw bytes
    public static func custom(_ newValue: Array<[UInt8]>) -> Self
#endif // !os(Windows)
}

extension Environment : CustomStringConvertible, CustomDebugStringConvertible {}
```

Developers have the option to:
- Inherit the same environment variables as the launching process by using `.inherit`. This is the default option.
- Inherit the environment variables from the launching process with overrides via `.inherit.updating()`.
- Specify custom values for environment variables using `.custom()`.

```swift
// Override the `PATH` environment value from launching process
let result = try await run(
    .path("/some/executable"),
    environment: .inherit.updating(
        ["PATH" : "/some/new/path"]
    )
)

// Use custom values
let result2 = try await run(
    .path("/at"),
    environment: .custom([
        "PATH" : "/some/path"
        "HOME" : "/Users/Charles"
    ])
)
```

`Environment` is designed to support both `String` and raw bytes for the use case where the environment values might not be valid UTF8 strings *on Unix like systems (macOS and Linux)*. Windows requires environment values to `CreateProcessW` to be valid String and therefore only supports the String variant.


### `Arguments`

`Arguments` is used to configure the spawn arguments sent to the child process. It conforms to `ExpressibleByArrayLiteral`. In most cases, developers can simply pass in an array `[String]` with the desired arguments. However, there might be scenarios where a developer wishes to override the first argument (i.e., the executable path). This is particularly useful because some processes might behave differently based on the first argument provided. The ability to override the executable path can be achieved by specifying the `pathOverride` parameter:


```swift
/// A collection of arguments to pass to the subprocess.
public struct Arguments: Sendable, ExpressibleByArrayLiteral, Hashable {
    public typealias ArrayLiteralElement = String
    /// Creates an Arguments object using the given literal values
    public init(arrayLiteral elements: ArrayLiteralElement...)
    /// Creates an Arguments object using the given array
    public init(_ array: [ArrayLiteralElement])
#if !os(Windows)
    /// Create an `Argument` object using the given values, but
    /// override the first Argument value to `executablePathOverride`.
    /// If `executablePathOverride` is nil,
    /// `Arguments` will automatically use the executable path
    /// as the first argument.
    /// - Parameters:
    ///   - executablePathOverride: the value to override the first argument.
    ///   - remainingValues: the rest of the argument value
    public init(executablePathOverride: String?, remainingValues: [String])
    /// Creates an Arguments object using the given array
    public init(_ array: Array<[UInt8]>)
    /// Create an `Argument` object using the given values, but
    /// override the first Argument value to `executablePathOverride`.
    /// If `executablePathOverride` is nil,
    /// `Arguments` will automatically use the executable path
    /// as the first argument.
    /// - Parameters:
    ///   - executablePathOverride: the value to override the first argument.
    ///   - remainingValues: the rest of the argument value
    public init(executablePathOverride: [UInt8]?, remainingValues: Array<[UInt8]>)
#endif // !os(Windows)

extension Arguments : CustomStringConvertible, CustomDebugStringConvertible {}
```

Similar to `Environment`, `Arguments` also supports raw bytes in addition to `String` *on Unix like systems (macOS and Linux)*. Windows requires argument values passed to `CreateProcessW` to be valid String and therefore only supports the String variant.

```swift
// In most cases, simply pass in an array
let result = try await run(
    .path("/some/executable"),
    arguments: ["arg1", "arg2"]
)

// Override the executable path
let result2 = try await run(
    .path("/some/executable"),
    arguments: .init(
        executablePathOverride: "/new/executable/path",
        remainingValues: ["arg1", "arg2"]
    )
)
```


### `TerminationStatus`

`TerminationStatus` is used to communicate the exit statuses of a process: `exited` and `unhandledException`.

```swift
@frozen
public enum TerminationStatus: Sendable, Hashable, Codable {
#if canImport(WinSDK)
    public typealias Code = DWORD
#else
    public typealias Code = CInt
#endif
    /// The subprocess was existed with the given code
    case exited(Code)
    /// The subprocess was signalled with given exception value
    case unhandledException(Code)

    /// Whether the current TerminationStatus is successful.
    public var isSuccess: Bool
}
extension TerminationStatus : CustomStringConvertible, CustomDebugStringConvertible {}
```

### `SubprocessError`

`Subprocess` provides its own error type, `SubprocessError`, which encapsulates all errors generated by `Subprocess`. These errors are instances of `SubprocessError` with an optional `underlyingError` attribute. On Unix-like systems (including Darwin and Linux), `Subprocess` exposes `SubprocessError.POSIXError` as a straightforward wrapper around `errno` that serve as the `underlyingError`. In contrast, on Windows, `Subprocess` utilizes `WindowsError`, which wraps Windows error codes as the `underlyingError`.

```swift
/// Error thrown from Subprocess
public struct SubprocessError: Swift.Error, Hashable, Sendable {
    /// The error code of this error
    public let code: SubprocessError.Code
    /// The underlying error that caused this error, if any
    public let underlyingError: UnderlyingError?
}

extension Subprocess {
    /// A SubprocessError Code
    public struct Code: Hashable, Sendable {
        public let value: Int
    }
}

extension SubprocessError: CustomStringConvertible, CustomDebugStringConvertible {}

extension SubprocessError {
    /// The underlying error that caused this SubprocessError.
    /// - On Unix-like systems, `UnderlyingError` wraps `errno` from libc;
    /// - On Windows, `UnderlyingError` wraps Windows Error code
    public struct UnderlyingError: Swift.Error, RawRepresentable, Hashable, Sendable {
#if os(Window)
        public typealias RawValue = DWORD
#else
        public typealias RawValue = Int32
#endif

        public let rawValue: RawValue
        public init(rawValue: RawValue)
    }
}
```


### Task Cancellation

If the task running `Subprocess.run` is cancelled while the child process is running, `Subprocess` will attempt to release all the resources it acquired (i.e. file descriptors) and then terminate the child process according to the `TeardownSequence`.


## Impact on Existing Code

No impact on existing code is anticipated. All introduced changes are additive.


## Future Directions

### Automatic Splitting of `Arguments`

Ideally, the `Arguments` feature should automatically split a string, such as "-a -n 1024 -v 'abc'", into an array of arguments. This enhancement would enable `Arguments` to conform to `ExpressibleByStringLiteral`, allowing developers to conveniently pass either a `String` or `[String]` as `Arguments`.

I decided to defer this feature because it turned out to be a "hard problem" -- different platforms handle arguments differently, requiring careful consideration to ensure correctness.

For reference, Python uses [`shlex.split`](https://docs.python.org/3/library/shlex.html), which could serve as a valuable starting point for implementation.

### Combined `stdout` and `stderr`

In Python's `Subprocess`, developers can merge standard output and standard error into a single stream. This is particularly useful when an executable improperly utilizes standard error as standard output (or vice versa). We should explore the most effective way to achieve this enhancement without introducing confusion to existing parameters—perhaps by introducing a new property.


### Process Piping

With the current design, the recommended way to "pipe" the output of one process to another is literally using pipes:

```swift
let pipe = try FileDescriptor.pipe()

async let ls = try await run(
    .name("ls"),
    output: .writeTo(pipe.writeEnd, closeAfterSpawningProcess: true)
)

async let grep = try await run(
    .name("grep"),
    arguments: ["swift"],
    input: .readFrom(pipe.readEnd, closeAfterSpawningProcess: true),
    output: .collectString()
)

let result = await grep.standardOutput
```

This setup is overly complex for such a simple operation in shell script (`ls | grep "swift"`). We should reimagine how piping should work with `Subprocess` next.


## Alternatives Considered

### Improving `Process` vs Creating New Type

We explored improving `Process` itself instead of creating a new type (Subprocess). However, it was found challenging to add all the desired features while preserving binary compatibility with the existing `Process` type.

### Other Naming Schemes

We considered naming this new type `Command` (which is what Rust uses), but ultimately decided to go with the more "familiar" name "Subprocess". "Subprocess" also communicates to the developers that the new process being launch is a child, or "sub" process of the parent, and the parent will `await` the child to finish.

### Considerations Between `URL` and `FilePath`:

While `Process` historically used `URL` to represent both the executable path and the working directory, `Subprocess` has opted for `FilePath`. This choice is made because, in the context of `Subprocess`, the executable is on disk, and `FilePath` aligns more closely reflects this concept.

### Opaque `Environment` and `Arguments` vs Array and Dictionary

We chose to use opaque `Environment` and `Arguments` to represent the environment and argument values passed to subprocess instead of using plain `[String]` and `[String : String]` for two reasons:

- Opaque types allows raw byte support. There are cases where the argument passed to child process isn't a valid UTF8 string and both `Environment` and `Arguments` support this use case
- Opaque types gives us room to support more features in the future.


## Acknowledgments

Special thanks to [@AndrewHoos](https://github.com/AndrewHoos), [@FranzBusch](https://github.com/FranzBusch), [@MaxDesiatov](https://github.com/MaxDesiatov), and [@weissi](https://github.com/weissi) for their prior work on `Process`, which significantly influenced the development of `Subprocess`.
