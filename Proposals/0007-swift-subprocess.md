# Introducing Swift Subprocess

* Proposal: [SF-0007](0007-swift-subprocess.md)
* Authors: [Charles Hu](https://github.com/iCharlesHu)
* Review Manager: [Tina Liu](https://github.com/itingliu)
* Status: **2nd Review, Active: Dec 12, 2024...Dec 19, 2024**
* Bugs: [rdar://118127512](rdar://118127512), [apple/swift-foundation#309](https://github.com/apple/swift-foundation/issues/309)


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
    - Added `Subprocess.run(withConfiguration:...)` in favor or `Configuration.run()`.
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
    - Renamed `Subprocess.Result` to `Subprocess.ExecutionResult`.
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
        - Changed `CollectedResult.standard{Output|Error}` to `OutputWrapper`, which offers convenient views to the outputs as Data and String with UTF8 encoding 

## Introduction

As Swift establishes itself as a general-purpose language for both compiled and scripting use cases, one persistent pain point for developers is process creation. The existing Foundation API for spawning a process, `NSTask`, originated in Objective-C. It was subsequently renamed to `Process` in Swift. As the language has continued to evolve, `Process` has not kept up. It lacks support for `async/await`, makes extensive use of completion handlers, and uses Objective-C exceptions to indicate developer error. This proposal introduces a new type called `Subprocess`, which addresses the ergonomic shortcomings of `Process` and enhances the experience of using Swift for scripting and other areas such as server-side development.

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

We propose a new type, `struct Subprocess`, that will eventually replace `Process` as the canonical way to launch a process in `Swift`.

Here's the above script rewritten using `Subprocess`:

```swift
#!/usr/bin/swift

import FoundationEssentials

let gitResult = try await Subprocess.run(   // <- 0
    .named("git"),                          // <- 1
    arguments: ["diff", "--name-only"]
)

let changedFiles = gitResult.standardOutput.stringUsingUTF8!
if changedFiles.isEmpty {
    changedFiles = "No changed files"
}
_ = try await Subprocess.run(
    .named("say"),
    arguments: [changedFiles]
)
```

Let's break down the example above:

0. `Subprocess` is constructed entirely on the `async/await` paradigm. The `run()` method utilizes `await` to allow the child process to finish, asynchronously returning an `ExecutionResult`. Additionally, there is an closure based overload of `run()` that offers more granulated control, which will be discussed later.
1. There are two primary ways to configure the executable being run:
    - The default approach, recommended for most developers, is `.at(FilePath)`. This allows developers to specify a full path to an executable.
    - Alternatively, developers can use `.named(String)` to instruct `Subprocess` to look up the executable path based on heuristics such as the `$PATH` environment variable.


## Detailed Design

### The New `Subprocess` Type

We propose a new `struct Subprocess`. Developers primarily interact with `Subprocess` via the static `run` methods which asynchronously executes a subprocess.

```swift
@available(FoundationPreview 0.4, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Subprocess {
    /// Run a executable with given parameters and capture its
    /// standard output and standard error.
    /// - Parameters:
    ///   - executable: The executable to run.
    ///   - arguments: The arguments to pass to the executable.
    ///   - environment: The environment to use for the process.
    ///   - workingDirectory: The working directory to use for the subprocess.
    ///   - platformOptions: The platform specific options to use
    ///     when running the executable.
    ///   - input: The input to send to the executable.
    ///   - output: The method to use for collecting the standard output.
    ///   - error: The method to use for collecting the standard error.
    /// - Returns: `CollectedResult` which contains process identifier,
    ///     termination status, captured standard output and standard error.
    public static func run(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: InputMethod = .noInput,
        output: CollectedOutputMethod = .collect(),
        error: CollectedOutputMethod = .collect()
    ) async throws -> CollectedResult

    /// Run a executable with given parameters and capture its
    /// standard output and standard error.
    /// - Parameters:
    ///   - executable: The executable to run.
    ///   - arguments: The arguments to pass to the executable.
    ///   - environment: The environment to use for the process.
    ///   - workingDirectory: The working directory to use for the subprocess.
    ///   - platformOptions: The platform specific options to use
    ///     when running the executable.
    ///   - input: The input to send to the executable.
    ///   - output: The method to use for collecting the standard output.
    ///   - error: The method to use for collecting the standard error.
    /// - Returns: `CollectedResult` which contains process identifier,
    ///     termination status, captured standard output and standard error.
    public static func run(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: some Sequence<UInt8> & Sendable,
        output: CollectedOutputMethod = .collect(),
        error: CollectedOutputMethod = .collect()
    ) async throws -> CollectedResult

    /// Run a executable with given parameters and capture its
    /// standard output and standard error.
    /// - Parameters:
    ///   - executable: The executable to run.
    ///   - arguments: The arguments to pass to the executable.
    ///   - environment: The environment to use for the process.
    ///   - workingDirectory: The working directory to use for the subprocess.
    ///   - platformOptions: The platform specific options to use
    ///     when running the executable.
    ///   - input: The input to send to the executable.
    ///   - output: The method to use for collecting the standard output.
    ///   - error: The method to use for collecting the standard error.
    /// - Returns: `CollectedResult` which contains process identifier,
    ///     termination status, captured standard output and standard error.
    public static func run(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = PlatformOptions(),
        input: some StringProtocol,
        output: CollectedOutputMethod = .collect(),
        error: CollectedOutputMethod = .collect()
    ) async throws -> CollectedResult

    /// Run a executable with given parameters and capture its
    /// standard output and standard error.
    /// - Parameters:
    ///   - executable: The executable to run.
    ///   - arguments: The arguments to pass to the executable.
    ///   - environment: The environment to use for the process.
    ///   - workingDirectory: The working directory to use for the subprocess.
    ///   - platformOptions: The platform specific options to use
    ///     when running the executable.
    ///   - input: The input to send to the executable.
    ///   - output: The method to use for collecting the standard output.
    ///   - error: The method to use for collecting the standard error.
    /// - Returns: `CollectedResult` which contains process identifier,
    ///     termination status, captured standard output and standard error.
    public static func run(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = PlatformOptions(),
        input: some Sequence<Data> & Sendable,
        output: CollectedOutputMethod = .collect(),
        error: CollectedOutputMethod = .collect()
    ) async throws -> CollectedResult

    /// Run a executable with given parameters and capture its
    /// standard output and standard error.
    /// - Parameters:
    ///   - executable: The executable to run.
    ///   - arguments: The arguments to pass to the executable.
    ///   - environment: The environment to use for the process.
    ///   - workingDirectory: The working directory to use for the subprocess.
    ///   - platformOptions: The platform specific options to use
    ///     when running the executable.
    ///   - input: The input to send to the executable.
    ///   - output: The method to use for collecting the standard output.
    ///   - error: The method to use for collecting the standard error.
    /// - Returns: `CollectedResult` which contains process identifier,
    ///     termination status, captured standard output and standard error.
    public static func run<AsyncSendableSequence: AsyncSequence & Sendable>(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: AsyncSendableSequence,
        output: CollectedOutputMethod = .collect(),
        error: CollectedOutputMethod = .collect()
    ) async throws -> CollectedResult where AsyncSendableSequence.Element == Data
}

// MARK: - Custom Execution Body
extension Subprocess {
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
    ///   - output: The method to use for redirecting the standard output.
    ///   - error: The method to use for redirecting the standard error.
    ///   - body: The custom execution body to manually control the running process
    /// - Returns a `ExecutableResult` type containing the return value
    ///     of the closure.
    public static func run<Result>(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: InputMethod = .noInput,
        output: RedirectedOutputMethod = .redirectToSequence,
        error: RedirectedOutputMethod = .redirectToSequence,
        isolation: isolated (any Actor)? = #isolation,
        _ body: (@escaping (Subprocess) async throws -> Result)
    ) async throws -> ExecutionResult<Result>

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
    ///   - output: The method to use for redirecting the standard output.
    ///   - error: The method to use for redirecting the standard error.
    ///   - body: The custom execution body to manually control the running process
    /// - Returns a `ExecutableResult` type containing the return value
    ///     of the closure.
    public static func run<Result>(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        platformOptions: PlatformOptions = .default,
        input: some Sequence<UInt8> & Sendable,
        output: RedirectedOutputMethod = .redirectToSequence,
        error: RedirectedOutputMethod = .redirectToSequence,
        isolation: isolated (any Actor)? = #isolation,
        _ body: (@escaping (Subprocess) async throws -> Result)
    ) async throws -> ExecutionResult<Result>

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
    ///   - output: The method to use for redirecting the standard output.
    ///   - error: The method to use for redirecting the standard error.
    ///   - body: The custom execution body to manually control the running process
    /// - Returns a ExecutableResult type containing the return value
    ///     of the closure.
    public static func run<Result>(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = PlatformOptions(),
        input: some StringProtocol,
        output: RedirectedOutputMethod = .redirectToSequence,
        error: RedirectedOutputMethod = .redirectToSequence,
        isolation: isolated (any Actor)? = #isolation,
        _ body: (@escaping (Subprocess) async throws -> Result)
    ) async throws -> ExecutionResult<Result>

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
    ///   - output: The method to use for redirecting the standard output.
    ///   - error: The method to use for redirecting the standard error.
    ///   - body: The custom execution body to manually control the running process
    /// - Returns a `ExecutableResult` type containing the return value
    ///     of the closure.
    public static func run<Result>(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = PlatformOptions(),
        input: some Sequence<Data> & Sendable,
        output: RedirectedOutputMethod = .redirectToSequence,
        error: RedirectedOutputMethod = .redirectToSequence,
        isolation: isolated (any Actor)? = #isolation,
        _ body: (@escaping (Subprocess) async throws -> Result)
    ) async throws -> ExecutionResult<Result>

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
    ///   - output: The method to use for redirecting the standard output.
    ///   - error: The method to use for redirecting the standard error.
    ///   - body: The custom execution body to manually control the running process
    /// - Returns a `ExecutableResult` type containing the return value
    ///     of the closure.
    public static func run<Result, AsyncSendableSequence: AsyncSequence & Sendable>(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: AsyncSendableSequence,
        output: RedirectedOutputMethod = .redirectToSequence,
        error: RedirectedOutputMethod = .redirectToSequence,
        isolation: isolated (any Actor)? = #isolation,
        _ body: (@escaping (Subprocess) async throws -> Result)
    ) async throws -> ExecutionResult<Result> where AsyncSendableSequence.Element == Data

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
    ///   - output: The method to use for redirecting the standard output.
    ///   - error: The method to use for redirecting the standard error.
    ///   - body: The custom execution body to manually control the running process
    /// - Returns the custom result type returned by the closure
    public static func run<Result>(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        output: RedirectedOutputMethod = .redirectToSequence,
        error: RedirectedOutputMethod = .redirectToSequence,
        isolation: isolated (any Actor)? = #isolation,
        _ body: (@escaping (Subprocess, StandardInputWriter) async throws -> Result)
    ) async throws -> ExecutionResult<Result>

    /// Run a executable with given parameters specified by a
    /// `Subprocess.Configuration`
    /// - Parameters:
    ///   - configuration: The `Subprocess` configuration to run.
    ///   - output: The method to use for redirecting the standard output.
    ///   - error: The method to use for redirecting the standard error.
    ///   - body: The custom configuration body to manually control
    ///       the running process and write to its standard input.
    /// - Returns a ExecutableResult type containing the return value
    ///     of the closure.
    public static func run<Result>(
        _ configuration: Configuration,
        output: RedirectedOutputMethod = .redirectToSequence,
        error: RedirectedOutputMethod = .redirectToSequence,
        isolation: isolated (any Actor)? = #isolation,
        _ body: (@escaping (Subprocess, StandardInputWriter) async throws -> Result)
    ) async throws -> ExecutionResult<Result>
}
```

The `run` methods can generally be divided into two categories, each addressing distinctive use cases of `Subprocess`:
- The first category returns a simple `CollectedResult` object, encapsulating information such as `ProcessIdentifier`, `TerminationStatus`, as well as collected standard output and standard error if requested. These methods are designed for straightforward use cases of `Subprocess`, where developers are primarily interested in the output or termination status of a process. Here are some examples:

```swift
// Simple ls with no standard input
let ls = try await Subprocess.run(
    .named("ls"),
    output: .collect
)
print("Items in current directory: \(ls.standardOutput.stringUsingUTF8!)")

// Launch VSCode with arguments
let code = try await Subprocess.run(
    .named("code"),
    arguments: ["/some/directory"]
)
print("Code launched successfully: \(code.terminationStatus.isSuccess)")

// Launch `cat` with sequence written to standardInput
let inputData = "Hello SwiftFoundation".utf8CString.map { UInt8($0) }
let cat = try await Subprocess.run(
    .named("cat"),
    input: inputData,
    output: .collect
)
print("Cat result: \(cat.standardOutput.stringUsingUTF8!)")
```

- Alternatively, developers can leverage the closure-based approach. These methods spawn the child process and invoke the provided `body` closure with a `Subprocess` object. Developers can send signals to the running subprocess or transform `standardOutput` or `standardError` to the desired result type within the closure. One additional variation of the closure-based methods provides the `body` closure with an additional `Subprocess.StandardInputWriter` object, allowing developers to write to the standard input of the subprocess directly. These methods asynchronously wait for the child process to exit before returning the result.


```swift
// Use curl to call REST API
struct MyType: Codable { ... }

let result = try await Subprocess.run(
    .named("curl"),
    arguments: ["/some/rest/api"],
    output: .redirect
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
let result = try await Subprocess.run(
    .at("/some/executable"),
    output: .redirect
) { subprocess, writer in
    try await writer.write("Hello World".utf8CString)
    try await writer.finish()
    return try await Array(subprocess.standardOutput)
}
```

Both styles of the `run` methods provide convenient overloads that allow developers to pass the following types to the standard input of the subprocess:
- `Sequence<UInt8>` (which `Data` conforms to)
- `Sequence<Data>`
- `AsyncSequence<Data>`

The `Subprocess` object itself is designed to represent an executed process. This execution could be either in progress or completed. Direct construction of `Subprocess` instances is not supported; instead, a `Subprocess` object is passed to the `body` closure of `run()`. This object is only valid within the scope of the closure, and developers may use it to send signals to the child process or retrieve the child's standard I/Os via `AsyncSequence`s.

```swift
/// An object that represents a subprocess of the current process.
///
/// Using `Subprocess`, your program can run another program as a subprocess
/// and can monitor that program’s execution. A `Subprocess` object creates a
/// **separate executable** entity; it’s different from `Thread` because it doesn’t
/// share memory space with the process that creates it.
@available(FoundationPreview 0.4, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct Subprocess: Sendable {
    /// The process identifier of the current subprocess
    public let processIdentifier: ProcessIdentifier
    /// The standard output of the subprocess.
    /// Accessing this property will **fatalError** if:
    /// - `.output` was NOT set to `.redirectToSequence` when the subprocess was spawned;
    /// - This property was accessed multiple times. Subprocess communicates with
    ///   parent process via pipe under the hood and each pipe can only be consumed ones.
    public var standardOutput: some AsyncSequence<Data, any Error> { get }
    /// The standard error of the subprocess.
    /// Accessing this property will **fatalError** if
    /// - `.error` was NOT set to `.redirectToSequence` when the subprocess was spawned;
    /// - This property was accessed multiple times. Subprocess communicates with
    ///   parent process via pipe under the hood and each pipe can only be consumed ones.
    public var standardError: some AsyncSequence<Data, any Error> { get }
}

#if canImport(Glibc) || canImport(Darwin)
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    /// A platform independent identifier for a subprocess.
    public struct ProcessIdentifier: Sendable, Hashable, Codable {
        /// The platform specific process identifier value
        public let value: pid_t

        public init(value: pid_t)
    }
}
#elseif canImport(WinSDK)
extension Subprocess {
    /// A platform independent identifier for a subprocess.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct ProcessIdentifier: Sendable, Hashable, Codable {
        /// Windows specifc process identifier value
        public let value: DWORD
        /// Windows specific thread identifier associated with process
        public let threadID: DWORD

        public init(value: DWORD, threadID: DWORD)
    }
}
#endif // canImport(WinSDK)

extension Subprocess.ProcessIdentifier : CustomStringConvertible, CustomDebugStringConvertible {}
```

#### Unmanaged Subprocess

In addition to the managed `run` family of methods, `Subprocess` also supports an unmanaged `runDetached` method that simply spawns the executable and returns its process identifier without awaiting for it to complete. This mode is particularly useful in scripting scenarios where the subprocess being launched requires outlasting the parent process. This setup is essential for programs that function as “trampolines” (e.g., JVM Launcher) to spawn other processes.

Since `Subprocess` is unable to monitor the state of the subprocess or capture and clean up input/output, it requires explicit `FileDescriptor` to bind to the subprocess’ IOs. Developers are responsible for managing the creation and lifetime of the provided file descriptor; if no file descriptor is specified, `Subprocess` binds its standard IOs to `/dev/null`.

```swift
@available(FoundationPreview 0.4, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Subprocess {
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
    public static func runDetached(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
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
    public static func runDeatched(
        _ configuration: Configuration,
        input: FileDescriptor? = nil,
        output: FileDescriptor? = nil,
        error: FileDescriptor? = nil
    ) throws -> ProcessIdentifier
}
```


### Signals (macOS and Linux)

`Subprocess` uses `struct Subprocess.Signal` to represent the signal that could be sent via `send()` on Unix systems (macOS and Linux). Developers could either initialize `Signal` directly using the raw signal value or use one of the common values defined as static property.

```swift
#if canImport(Glibc) || canImport(Darwin)
extension Subprocess {
    /// Signals are standardized messages sent to a running program
    /// to trigger specific behavior, such as quitting or error handling.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
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

    /// Send the given signal to the child process.
    /// - Parameters:
    ///   - signal: The signal to send.
    ///   - shouldSendToProcessGroup: Whether this signal should be sent to
    ///     the entire process group.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public func send(signal: Signal, toProcessGroup shouldSendToProcessGroup: Bool = false) throws
}
#endif // canImport(Glibc) || canImport(Darwin)
```

### Teardown Sequence (macOS and Linux)

`Subprocess` provides a graceful shutdown mechanism for child processes using the `.teardown(using:)` method. This method allows for a sequence of teardown steps to be executed, with the final step always sending a `.kill` signal.

```swift
#if canImport(Glibc) || canImport(Darwin)
extension Subprocses {
    /// Performs a sequence of teardown steps on the Subprocess.
    /// Teardown sequence always ends with a `.kill` signal
    /// - Parameter sequence: The  steps to perform.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public func teardown(using sequence: [TeardownStep]) async

    /// A step in the graceful shutdown teardown sequence.
    /// It consists of a signal to send to the child process and the
    /// duration allowed for the child process to exit before proceeding
    /// to the next step.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct TeardownStep: Sendable, Hashable {
        /// Sends `signal` to the process and allows `allowedDurationToExit`
        /// for the process to exit before proceeding to the next step.
        /// The final step in the sequence will always send a `.kill` signal.
        public static func sendSignal(
            _ signal: Signal,
            allowedDurationToExit: Duration
        ) -> Self
    }
}
#endif // canImport(Glibc) || canImport(Darwin)
```

A teardown sequence is a series of signals sent to the child process, accompanied by a specified time limit for the child process to terminate before proceeding to the next step. For instance, it may be appropriate to initially send `.quit` and `.terminate` signals to the child process to facilitate a graceful shutdown before sending `.kill`.

```swift
let result = try await Subprocess.run(
    .at("/bin/bash"),
    arguments: [...]
) { subprocess in
    // ... more work
    await subprocess.teardown(using: [
        .sendSignal(.quit, allowedDurationToExit: .milliseconds(100)),
        .sendSignal(.terminate, allowedDurationToExit: .milliseconds(100)),
    ])
}
```

### Process Controls (Windows)

The Windows does not have a centralized signaling system similar to Unix. Instead, it provides direct methods to suspend, resume, and terminate the subprocess:


```swift
#if canImport(WinSDK)
@available(FoundationPreview 0.4, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Subprocess {
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


### `Subprocess.StandardInputWriter`

`StandardInputWriter` provides developers with direct control over writing to the child process's standard input. Similar to the `Subprocess` object itself, developers should use the `StandardInputWriter` object passed to the `body` closure, and this object is only valid within the body of the closure.

**Note**: Developers should call `finish()` when they have completed writing to signal that the standard input file descriptor should be closed.

```swift
extension Subprocess {
    /// A writer that writes to the standard input of the subprocess.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public final actor StandardInputWriter {
        /// Write a sequence of UInt8 to the standard input of the subprocess.
        /// - Parameter sequence: The sequence of bytes to write.
        public func write<SendableSequence: Sequence<UInt8> & Sendable>(
            _ sequence: SendableSequence
        ) async throws
        /// Write a String to the standard input of the subprocess.
        /// - Parameter sequence: The string write.
        public func write(
            _ string: some StringProtocol
        ) async throws

        /// Write a AsyncSequence of Data to the standard input of the subprocess.
        /// - Parameter sequence: The sequence of bytes to write.
        public func write<AsyncSendableSequence: AsyncSequence & Sendable>(
            _ asyncSequence: AsyncSendableSequence
        ) async throws where AsyncSendableSequence.Element == Data
        /// Signal all writes are finished
        public func finish() async throws
    }
}
```


### `Subprocess.Configuration`

In contrast to the monolithic `Process`, `Subprocess` utilizes various types to model the lifetime of a process. `Subprocess.Configuration` represents the collection of information needed to spawn a process. This type is designed to be very similar to the existing `Process`, enabling you to configure your process in a manner akin to `NSTask`:

```swift
public extension Subprocess {
    /// A collection of configurations parameters to use when
    /// spawning a subprocess.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
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
}

extension Subprocess.Configuration : CustomStringConvertible, CustomDebugStringConvertible {}
```

**Note:**

- The `.workingDirectory` property defaults to the current working directory of the calling process.

Beyond the configurable parameters exposed by these static run methods, `Subprocess.Configuration` also provides **platform-specific** launch options via `PlatformOptions`.


### `Subprocess.PlatformOptions` on Darwin

For Darwin, we propose the following `PlatformOptions`:

```swift
#if canImport(Darwin)
extension Subprocess {
    /// The collection of platform-specific settings
    /// to configure the subprocess when running
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
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
}

extension Subprocess.PlatformOptions : CustomStringConvertible, CustomDebugStringConvertible {}
#endif // canImport(Darwin)
```

`PlatformOptions` also supports “escape hatches” that enable developers to configure the underlying platform-specific objects directly if `Subprocess` lacks corresponding high-level APIs.

For Darwin, we propose a closure `.preSpawnProcessConfigurator: (@Sendable (inout posix_spawnattr_t?, inout posix_spawn_file_actions_t?) throws -> Void` which provides developers with an opportunity to configure `posix_spawnattr_t` and `posix_spawn_file_actions_t` just before they are passed to `posix_spawn()`. For instance, developers can set additional spawn flags:

```swift
var platformOptions: Subprocess.PlatformOptions = .default
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
var platformOptions: Subprocess.PlatformOptions = .default
// Bind child fd 4 to a parent fd
platformOptions.preSpawnProcessConfigurator = { _, fileAttr in
    let parentFd: FileDescriptor = …
    posix_spawn_file_actions_adddup2(&fileAttr, parentFd.rawValue, 4)
}
```


### `Subprocess.PlatformOptions` on Linux

For Linux, we propose a similar `PlatformOptions` configuration:

```swift
#if canImport(Glibc)
extension Subprocess {
    /// The collection of Linux specific configurations
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
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
}

extension Subprocess.PlatformOptions : CustomStringConvertible, CustomDebugStringConvertible {}
#endif // canImport(Glibc)
```

Similar to the Darwin version, the Linux `PlatformOptions` also has an "escape hatch" closure that allows the developers to explicitly configure the subprocess. This closure is run after `fork` but before `exec`. In the example below, `preSpawnProcessConfigurator` can be used to set the group ID for the subprocess:

```swift
var platformOptions: Subprocess.PlatformOptions = .default
// Set Group ID for process
platformOptions.preSpawnProcessConfigurator = {
    setgid(4321)
}
```


### `Subprocess.PlatformOptions` on Windows

On Windows, we propose the following `PlatformOptions`:

```swift
#if canImport(WinSDK)
extension Subprocess {
    /// The collection of platform-specific settings
    /// to configure the subprocess when running
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
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
}

extension Subprocess.PlatformOptions : CustomStringConvertible, CustomDebugStringConvertible {}
#endif // canImport(WinSDK)
```

Windows `PlatformOptions` uses `preSpawnProcessConfigurator` as the "escape hatch". Developers could use this closure to configure `dwCreationFlags` and `lpStartupInfo` that are used by the platform `CreateProcessW` to spawn the process:

```swift
var platformOptions: Subprocess.PlatformOptions = .default
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


### `Subprocess.InputMethod`

In addition to supporting the direct passing of `Sequence` and `AsyncSequence` as the standard input to the child process, `Subprocess` also provides a `Subprocess.InputMethod` type that includes two additional input options:
- `.noInput`: Specifies that the subprocess does not require any standard input. This is the default value.
- `.readFrom`: Specifies that the subprocess should read its standard input from a file descriptor provided by the developer. Subprocess will automatically close the file descriptor after the process is spawned if `closeAfterSpawningProcess` is set to `true`. Note: when `closeAfterSpawningProcess` is `false`, the caller is responsible for closing the file descriptor even if `Subprocess` fails to spawn.

```swift
extension Subprocess {
    /// `InputMethod` defines how should the standard input
    /// of the subprocess receive inputs.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct InputMethod: Sendable, Hashable {
        /// Subprocess should read no input. This option is equivalent
        /// to bind the stanard input to `/dev/null`.
        public static var noInput: Self
        /// Subprocess should read input from a given file descriptor.
        /// - Parameters:
        ///   - fd: the file descriptor to read from
        ///   - closeAfterSpawningProcess: whether the file descriptor
        ///     should be automatically closed after subprocess is spawned.
        ///     If `false`, caller is responsible for closing `fd` even if
        ///     subprocess fails to spawn.
        public static func readFrom(_ fd: FileDescriptor, closeAfterSpawningProcess: Bool) -> Self
    }
}
```

Here are some examples:

```swift
// By default `InputMethod` is set to `.noInput`
let ls = try await Subprocess.run(.named("ls"))

// Alternatively, developers could pass in a file descriptor
let fd: FileDescriptor = ...
let cat = try await Subprocess.run(.named("cat"), input: .readFrom(fd, closeAfterSpawningProcess: true))

// Pass in a async sequence directly
let sequence: AsyncSequence = ...
let exe = try await Subprocess.run(.at("/some/executable"), input: sequence)
```


### `Subprocess` Output Methods

`Subprocess` uses two types to describe where the standard output and standard error of the child process should be redirected. These two types, `Subprocess.CollectOutputMethod` and `Subprocess.RedirectOutputMethod`, correspond to the two general categories of `run` methods mentioned above. Similar to `InputMethod`, both `OutputMethod`s add two general output destinations:
- `.discard`: Specifies that the child process's output should be discarded, effectively written to `/dev/null`.
- `.writeTo`: Specifies that the child process should write its output to a file descriptor provided by the developer. Subprocess will automatically close the file descriptor after the process is spawned if `closeAfterSpawningProcess` is set to `true`.

`CollectedOutMethod` adds one more option to non-closure-based `run` methods that return a `CollectedResult`: `.collect(upTo:)`. This option specifies that `Subprocess` should collect the output as `Data`. Since the output of a child process could be arbitrarily large, `Subprocess` imposes a limit on how many bytes it will collect. By default, this limit is 128kb.

```swift
extension Subprocess {
    /// `CollectedOutputMethod` defines how should Subprocess collect
    /// output from child process' standard output and standard error
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct CollectedOutputMethod: Sendable, Hashable {
        /// Subprocess shold dicard the child process output.
        /// This option is equivalent to binding the child process
        /// output to `/dev/null`.
        public static var discard: Self
        /// Subprocess should collect the child process output
        /// as `Data` with the given limit in bytes.
        /// The default limit is 128kb
        public static func collect(upTo limit: Int = 128 * 1024) -> Self
        /// Subprocess should write the child process output
        /// to the file descriptor specified.
        /// - Parameters:
        ///   - fd: the file descriptor to write to
        ///   - closeAfterSpawningProcess: whether to close the
        ///     file descriptor once the process is spawned.
        public static func writeTo(_ fd: FileDescriptor, closeAfterSpawningProcess: Bool) -> Self
    }
}
```

On the other hand, `RedirectedOutputMethod` adds one more option, `.redirectToSequence`, to the closure-based `run` methods to signify that output should be redirected to the `.standardOutput` or `.standardError` property of `Subprocess` passed to the closure as `AsyncSequence`. Since `AsyncSequence` is not push-based, there is no byte limit for this option:

```swift
extension Subprocess {
    /// `CollectedOutputMethod` defines how should Subprocess redirect
    /// output from child process' standard output and standard error.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct RedirectedOutputMethod: Sendable, Hashable {
        /// Subprocess shold dicard the child process output.
        /// This option is equivalent to binding the child process
        /// output to `/dev/null`.
        public static var discard: Self
        /// Subprocess should redirect the child process output
        /// to `Subprocess.standardOutput` or `Subprocess.standardError`
        /// so they can be consumed as an AsyncSequence
        public static var redirectToSequence: Self
        /// Subprocess shold write the child process output
        /// to the file descriptor specified.
        /// - Parameters:
        ///   - fd: the file descriptor to write to
        ///   - closeAfterSpawningProcess: whether to close the
        ///     file descriptor once the process is spawned.
        public static func writeTo(_ fd: FileDescriptor, closeAfterSpawningProcess: Bool) -> Self
    }
}
```

Here are some examples of using both output methods:

```swift
let ls = try await Subprocess.run(.named("ls"), output: .collect())
// The output has been collected as `Data`, up to 16kb limit
print("ls output: \(ls.standardOutout.stringUsingUTF8!)")

// Increase the default buffer limit to 256kb
let curl = try await Subprocess.run(
    .named("curl"),
    output: .collect(upTo: 256 * 1024)
)
print("curl output: \(curl.standardOutput.stringUsingUTF8!)")

// Write to a specific file descriptor
let fd: FileDescriptor = try .open(...)
let result = try await Subprocess.run(
    .at("/some/script"), output: .writeTo(fd, closeAfterSpawningProcess: true))

// Redirect the output as AsyncSequence
let result2 = try await Subprocess.run(
    .named("/some/script"), output: .redirectToSequence
) { subprocess in
    // Output can be access via `subprocess.standardOutput` here
    for try await item in subprocess.standardOutput {
        print(item)
    }
    return "Done"
}
```

**Note**: Accessing `.standardOutput` or `.standardError` on `Subprocess` or `CollectedResult` (described below) without setting the corresponding `OutputMethod` to `.redirectToSequence` or `.collect` will result in a **fatalError**. This is considered a programmer error because source code changes are needed to fix it.


### Result Types

`Subprocess` provides two "Result" types corresponding to the two categories of `run` methods: `Subprocess.CollectedResult` and `Subprocess.ExecutionResult<T>`.

`Subprocess.CollectedResult` is essentially a collection of properties that represent the result of an execution after the child process has exited. It is used by the non-closure-based `run` methods. In many ways, `CollectedResult` can be seen as the "synchronous" version of `Subprocess`—instead of the asynchronous `AsyncSequence<Data>`, the standard IOs can be retrieved via synchronous `Data` or `String`.

```swift
extension Subprocess {
    /// The result of a subprocess execution with its collected
    /// standard output and standard error.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct CollectedResult: Sendable, Hashable, Codable {
        /// The process identifier for the executed subprocess
        public let processIdentifier: ProcessIdentifier
        /// The termination status of the executed subprocess
        public let terminationStatus: TerminationStatus
        /// The collected standard output value for the subprocess.
        /// Accessing this property will *fatalError* if the
        /// corresponding `CollectedOutputMethod` is not set to
        /// `.collect` or `.collect(upTo:)`
        public let standardOutput: OutputWrapper
        /// The collected standard error value for the subprocess.
        /// Accessing this property will *fatalError* if the
        /// corresponding `CollectedOutputMethod` is not set to
        /// `.collect` or `.collect(upTo:)`
        public let standardError: OutputWrapper
    }
}

extension Subprocess.CollectedResult : CustomStringConvertible, CustomDebugStringConvertible {}

extension Subprocess.CollectedResult {
    /// A simple wrapper that offers a convinent way to access
    /// the Subprocess output as Data or String assuming UTF8
    /// encoding.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct OutputWrapper: Sendable, Hashable, Codable {
        public let data: Data
        public var stringUsingUTF8: String? { get }
    }
}
```

`Subprocess.ExecutionResult` is a simple wrapper around the generic result returned by the `run` closures with the corresponding `TerminationStatus` of the child process:

```swift
extension Subprocess {
    /// A simple wrapper around the generic result returned by the
    /// `run` closures with the corresponding `TerminationStatus`
    /// of the child process.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct ExecutionResult<Result> {
        /// The termination status of the child process
        public let terminationStatus: TerminationStatus
        /// The result returned by the closure passed to `.run` methods
        public let value: Result
    }
}

@available(FoundationPreview 0.4, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Subprocess.ExecutionResult: Equatable where Result : Equatable {}

@available(FoundationPreview 0.4, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Subprocess.ExecutionResult : Hashable where Result : Hashable {}

@available(FoundationPreview 0.4, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Subprocess.ExecutionResult : Codable where Result : Codable {}

@available(FoundationPreview 0.4, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Subprocess.ExecutionResult: CustomStringConvertible where Result : CustomStringConvertible {}

@available(FoundationPreview 0.4, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Subprocess.ExecutionResult: CustomDebugStringConvertible where Result : CustomDebugStringConvertible {}
```


### `Subprocess.Executable`

`Subprocess` utilizes `Executable` to configure how the executable is resolved. Developers can create an `Executable` using two static methods: `.named()`, indicating that an executable name is provided, and `Subprocess` should try to automatically resolve the executable path, and `.at()`, signaling that an executable path is provided, and `Subprocess` should use it unmodified.

```swift
extension Subprocess {
    /// `Subprocess.Executable` defines how should the executable
    /// be looked up for execution.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct Executable: Sendable, Hashable {
        /// Locate the executable by its name.
        /// `Subprocess` will use `PATH` value to
        /// determine the full path to the executable.
        public static func named(_ executableName: String) -> Self
        /// Locate the executable by its full path.
        /// `Subprocess` will use this  path directly.
        public static func at(_ filePath: FilePath) -> Self
        /// Returns the full executable path given the environment value.
        public func resolveExecutablePath(in environment: Environment) -> FilePath?
    }
}

extension Subprocess.Executable : CustomStringConvertible, CustomDebugStringConvertible {}
```


### `Subprocess.Environment`

`struct Environment` is used to configure how should the process being launched receive its environment values:

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
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
        /// Override the provided `newValue` in the existing `Environment`
        public func updating(
            _ newValue: [Data : Data]
        ) -> Self
        /// Use custom environment variables
        public static func custom(
            _ newValue: [Data : Data]
        ) -> Self
#endif // !os(Windows)
    }
}

extension Subprocess.Environment : CustomStringConvertible, CustomDebugStringConvertible {}
```

Developers have the option to:
- Inherit the same environment variables as the launching process by using `.inherit`. This is the default option.
- Inherit the environment variables from the launching process with overrides via `.inherit.updating()`.
- Specify custom values for environment variables using `.custom()`.

```swift
// Override the `PATH` environment value from launching process
let result = try await Subprocess.run(
    .at("/some/executable"),
    environment: .inherit.updating(
        ["PATH" : "/some/new/path"]
    )
)

// Use custom values
let result2 = try await Subprocess.run(
    .at("/at"),
    environment: .custom([
        "PATH" : "/some/path"
        "HOME" : "/Users/Charles"
    ])
)
```

`Environment` is designed to support both `String` and raw bytes for the use case where the environment values might not be valid UTF8 strings *on Unix like systems (macOS and Linux)*. Windows requires environment values to `CreateProcessW` to be valid String and therefore only supports the String variant.


### `Subprocess.Arguments`

`Subprocess.Arguments` is used to configure the spawn arguments sent to the child process. It conforms to `ExpressibleByArrayLiteral`. In most cases, developers can simply pass in an array `[String]` with the desired arguments. However, there might be scenarios where a developer wishes to override the first argument (i.e., the executable path). This is particularly useful because some processes might behave differently based on the first argument provided. The ability to override the executable path can be achieved by specifying the `pathOverride` parameter:


```swift
extension Subprocess {
    /// A collection of arguments to pass to the subprocess.
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
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
        public init(_ array: [Data])
        /// Create an `Argument` object using the given values, but
        /// override the first Argument value to `executablePathOverride`.
        /// If `executablePathOverride` is nil,
        /// `Arguments` will automatically use the executable path
        /// as the first argument.
        /// - Parameters:
        ///   - executablePathOverride: the value to override the first argument.
        ///   - remainingValues: the rest of the argument value
        public init(executablePathOverride: Data?, remainingValues: [Data])
#endif // !os(Windows)
    }
}

extension Subprocess.Arguments : CustomStringConvertible, CustomDebugStringConvertible {}
```

Similar to `Environment`, `Arguments` also supports raw bytes in addition to `String` *on Unix like systems (macOS and Linux)*. Windows requires argument values passed to `CreateProcessW` to be valid String and therefore only supports the String variant.

```swift
// In most cases, simply pass in an array
let result = try await Subprocess.run(
    .at("/some/executable"),
    arguments: ["arg1", "arg2"]
)

// Override the executable path
let result2 = try await Subprocess.run(
    .at("/some/executable"),
    arguments: .init(
        executablePathOverride: "/new/executable/path",
        remainingValues: ["arg1", "arg2"]
    )
)
```


### `Subprocess.TerminationStatus`

`Subprocess.TerminationStatus` is used to communicate the exit statuses of a process: `exited` and `unhandledException`.

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
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
}
extension Subprocess.TerminationStatus : CustomStringConvertible, CustomDebugStringConvertible {}
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

async let ls = try await Subprocess.run(
    .named("ls"),
    output: .writeTo(pipe.writeEnd, closeAfterSpawningProcess: true)
)

async let grep = try await Subprocess.run(
    .named("grep"),
    arguments: ["swift"],
    input: .readFrom(pipe.readEnd, closeAfterSpawningProcess: true)
)

let result = await grep.standardOutput.stringUsingUTF8
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
