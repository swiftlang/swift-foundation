# Introducing Swift Subprocess

* Proposal: [SF-NNNN](NNNN-swift-subprocess.md)
* Authors: [Charles Hu](https://github.com/iCharlesHu)
* Review Manager: TBD
* Status: **Draft**
* Bugs: [rdar://118127512](rdar://118127512), [apple/swift-foundation#309](https://github.com/apple/swift-foundation/issues/309)


## Revision History

* **v1**: Initial draft
* **v2**: Minor Updates:
    - Switched `AsyncBytes` to be backed by `DispatchIO`.
    - Introduced `resolveExecutablePath(withEnvironment:)` to enable explicit lookup of the executable path.
    - Added a new option, `closeWhenDone`, to automatically close the file descriptors passed in via `.readFrom` and friends.
    - Introduced a new parameter, `shouldSendToProcessGroup`, in the `sendSignal` function to control whether the signal should be sent to the process or the process group.
    - Introduced a section on "Future Directions."
* **v3**: Minor updates:
    - Added a section describing `Task Cancellation`
    - Clarified for `readFrom()` and `writeTo()` Subprocess will close the passed in file descriptor right after spawning the process when `closeWhenDone` is set to true.
    - Adjusted argument orders in `Arguments`.
    - Added `Subprocess.run(withConfiguration:...)` in favor or `Configuration.run()`.

## Introduction

As Swift establishes itself as a general-purpose language for both compiled and scripting use cases, one persistent pain point for developers is process creation. The existing Foundation API for spawning a process, `NSTask`, originated in Objective-C. It was subsequently renamed to `Process` in Swift. As the language has continued to evolve, `Process` has not kept up. It lacks support for `async/await`, makes extensive use of completion handlers, and uses Objective-C exceptions to indicate developer error. This proposal introduces a new type called `Subprocess`, which addresses the ergonomic shortcomings of `Process` and enhances the experience of using Swift for scripting.

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
    executing: .named("git"),               // <- 1
    arguments: ["diff", "--name-only"]
)

var changedFiles = String(
    data: gitResult.standardOutput!,
    encoding: .utf8)!
if changedFiles.isEmpty {
    changedFiles = "No changed files"
}
_ = try await Subprocess.run(
    executing: .named("say"),
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
    public static func run(
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: InputMethod = .noInput,
        output: CollectedOutputMethod = .collect,
        error: CollectedOutputMethod = .collect
    ) async throws -> CollectedResult

    public static func run(
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: some Sequence<UInt8>,
        output: CollectedOutputMethod = .collect,
        error: CollectedOutputMethod = .collect
    ) async throws -> CollectedResult

    public static func run<S: AsyncSequence>(
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: S,
        output: CollectedOutputMethod = .collect,
        error: CollectedOutputMethod = .collect
    ) async throws -> CollectedResult where S.Element == UInt8
}

// MARK: - Custom Execution Body
extension Subprocess {
    public static func run<R>(
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: InputMethod = .noInput,
        output: RedirectedOutputMethod = .redirect,
        error: RedirectedOutputMethod = .discard,
        _ body: (@Sendable @escaping (Subprocess) async throws -> R)
    ) async throws -> Result<R>

    public static func run<R>(
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        platformOptions: PlatformOptions = .default,
        input: some Sequence<UInt8>,
        output: RedirectedOutputMethod = .redirect,
        error: RedirectedOutputMethod = .discard,
        _ body: (@Sendable @escaping (Subprocess) async throws -> R)
    ) async throws -> Result<R>

    public static func run<R, S: AsyncSequence>(
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: S,
        output: RedirectedOutputMethod = .redirect,
        error: RedirectedOutputMethod = .discard,
        _ body: (@Sendable @escaping (Subprocess) async throws -> R)
    ) async throws -> Result<R> where S.Element == UInt8

    public static func run<R>(
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        output: RedirectedOutputMethod = .redirect,
        error: RedirectedOutputMethod = .discard,
        _ body: (@Sendable @escaping (Subprocess, StandardInputWriter) async throws -> R)
    ) async throws -> Result<R>

    public static func run<R>(
        withConfiguration configuration: Configuration,
        output: RedirectedOutputMethod = .redirect,
        error: RedirectedOutputMethod = .redirect,
        _ body: (@Sendable @escaping (Subprocess, StandardInputWriter) async throws -> R)
    ) async throws -> Result<R>
}
```

The `run` methods can generally be divided into two categories, each addressing distinctive use cases of `Subprocess`:
- The first category returns a simple `CollectedResult` object, encapsulating information such as `ProcessIdentifier`, `TerminationStatus`, as well as collected standard output and standard error if requested. These methods are designed for straightforward use cases of `Subprocess`, where developers are primarily interested in the output or termination status of a process. Here are some examples:

```swift
// Simple ls with no standard input
let ls = try await Subprocess.run(
    executing: .named("ls"),
    output: .collect)
print("Items in current directory: \(String(data: ls.standardOutput!, encoding: .utf8)!)")

// Launch VSCode with arguments
let code = try await Subprocess.run(
    executing: .named("code"),
    arguments: ["/some/directory"])
print("Code launched successfully: \(result.terminationStatus.isSuccess)")

// Launch `cat` with sequence written to standardInput
let inputData = "Hello SwiftFoundation".utf8CString.map { UInt8($0) }
let cat = try await Subprocess.run(
    executing: .named("cat"),
    input: inputData,
    output: .collect
)
print("Cat result: \(String(data: cat.standardOutput!, encoding: .utf8)!)")
```

- Alternatively, developers can leverage the closure-based approach. These methods spawn the child process and invoke the provided `body` closure with a `Subprocess` object. Developers can send signals to the running subprocess or transform `standardOutput` or `standardError` to the desired result type within the closure. One additional variation of the closure-based methods provides the `body` closure with an additional `Subprocess.StandardInputWriter` object, allowing developers to write to the standard input of the subprocess directly. These methods asynchronously wait for the child process to exit before returning the result.


```swift
// Use curl to call REST API
struct MyType: Codable { ... }

let result = try await Subprocess.run(
    executing: .named("curl"),
    arguments: ["/some/rest/api"],
    output: .redirect) {
        let output = try await Array($0.standardOutput!)
        return try JSONDecoder().decode(MyType.self, from: Data(output))
}
// Result will have type `MyType`
print("Result: \(result)")

// Perform custom write and write the standard output
let result = try await Subprocess.run(
    executing: .at("/some/executable"),
    output: .redirect) { subprocess, writer in
    try await writer.write("Hello World".utf8CString)
    try await writer.finish()
    return try await Array(subprocess.standardOutput!.lines)
}
```

Both styles of the `run` methods provide convenient overloads that allow developers to pass a `Sequence<UInt8>` or `AsyncSequence<UInt8>` to the standard input of the subprocess.

The `Subprocess` object itself is designed to represent an executed process. This execution could be either in progress or completed. Direct construction of `Subprocess` instances is not supported; instead, a `Subprocess` object is passed to the `body` closure of `run()`. This object is only valid within the scope of the closure, and developers may use it to send signals to the child process or retrieve the child's standard I/Os via `AsyncSequence`s.

```swift
@available(FoundationPreview 0.4, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct Subprocess: Sendable {
    public let processIdentifier: ProcessIdentifier
    // The standard output of the child process, expressed as AsyncSequence<UInt8>
    // This property is `nil` if the standard output is discarded or written to disk
    public var standardOutput: AsyncBytes? { get }
    // The standard error of the child process, expressed as AsyncSequence<UInt8>
    // This property is `nil` if the standard error is discarded or written to disk
    public var standardError: AsyncBytes? { get }
    // If `shouldSendToProcessGroup` is `true`, the signal will be send to the entire process
    // group instead of the current process.
    public func sendSignal(_ signal: Signal, toProcessGroup shouldSendToProcessGroup: Bool) throws
}

extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct ProcessIdentifier: Sendable, Hashable {
        let value: pid_t

        public init(value: pid_t) {
            self.value = value
        }
    }
}
```


### Signals

`Subprocess` uses `struct Subprocess.Signal` to represent the signal that could be sent via `sendSignal()`. Developers could either initialize `Signal` directly using the raw signal value or use one of the common values defined as static property.

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct Signal : Hashable, Sendable {
        public let rawValue: Int32

        public static var interrupt: Self { get }
        public static var terminate: Self { get }
        public static var suspend: Self { get }
        public static var resume: Self { get }
        public static var kill: Self { get }
        public static var terminalClosed: Self { get }
        public static var quit: Self { get }
        public static var userDefinedOne: Self { get }
        public static var userDefinedTwo: Self { get }
        public static var alarm: Self { get }
        public static var windowSizeChange: Self { get }

        public init(rawValue: Int32)
    }
}
```


### `Subprocess.StandardInputWriter`

`StandardInputWriter` provides developers with direct control over writing to the child process's standard input. Similar to the `Subprocess` object itself, developers should use the `StandardInputWriter` object passed to the `body` closure, and this object is only valid within the body of the closure.

**Note**: Developers must call `finish()` when they have completed writing to signal that the standard input file descriptor should be closed.

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct StandardInputWriter: Sendable {
        public func write<S>(_ sequence: S) async throws where S : Sequence, S.Element == UInt8
        public func write<S>(_ sequence: S) async throws where S : Sequence, S.Element == CChar

        public func write<S: AsyncSequence>(_ asyncSequence: S) async throws where S.Element == CChar
        public func write<S: AsyncSequence>(_ asyncSequence: S) async throws where S.Element == UInt8

        public func finish() async throws
    }
}
```


### `Subprocess.Configuration`

In contrast to the monolithic `Process`, `Subprocess` utilizes various types to model the lifetime of a process. `Subprocess.Configuration` represents the collection of information needed to spawn a process. This type is designed to be very similar to the existing `Process`, enabling you to configure your process in a manner akin to `NSTask`:

```swift
public extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct Configuration : Sendable {
        // Configurable properties
        public var executable: Executable
        public var arguments: Arguments
        public var environment: Environment
        public var workingDirectory: FilePath
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
```

**Note:**

- The `.workingDirectory` property defaults to the current working directory of the calling process.

The static methods on `Subprocess` are simply syntactic sugar for calling `Configuration().run()`. Beyond the configurable parameters exposed by these static run methods, `Subprocess.Configuration` also provides **platform-specific** launch options via `PlatformOptions`.


### `Subprocess.PlatformOptions`

While `Subprocess.Configuration` provides configuration options to the essential launch parameters such as arguments and environment, `PlatformOptions` provides additional options to configure platform-specific behavior.

```swift
extension Subprocess {
    /// The collection of platform-specific configurations
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct PlatformOptions: Sendable {
        public var qualityOfService: QualityOfService
        // Set user ID for the subprocess
        public var userID: Int?
        // Set group ID for the subprocess
        public var groupID: Int?
        // Set list of supplementary group IDs for the subprocess
        public var supplementaryGroups: [Int]?
        // Creates a session and sets the process group ID
        // i.e. Detach from the terminal.
        public var createSession: Bool
        // Create a new process group
        public var createProcessGroup: Bool
        public var launchRequirementData: Data?
        public var additionalSpawnAttributeConfigurator: (@Sendable (inout posix_spawnattr_t?) throws -> Void)?
        public var additionalFileAttributeConfigurator: (@Sendable (inout posix_spawn_file_actions_t?) throws -> Void)?

        public init(
            qualityOfService: QualityOfService,
            userID: Int? = nil,
            groupID: Int? = nil,
            supplementaryGroups: [Int]?,
            createSession: Bool,
            createProcessGroup: Bool,
            launchRequirementData: Data?
        )

        public static var `default`: Self
    }
}
```

`PlatformOptions` also supports "escape hatches" that enable developers to configure the underlying platform-specific objects directly if `Subprocess` lacks corresponding high-level APIs.

For Darwin, we are proposing two such APIs:

- `.additionalSpawnAttributeConfigurator: (@Sendable (inout posix_spawnattr_t?) throws -> Void)?` gives developers an opportunity to configure the `posix_spawnattr_t` object just before it's passed to `posix_spawn()`. For instance, developers can set additional spawn flags:

```swift
let config = Subprocess.Configuration(executing: .at("/my/executable"))
config.additionalSpawnAttributeConfigurator = { spawnAttr in
    let flags: Int32 = POSIX_SPAWN_CLOEXEC_DEFAULT |
        POSIX_SPAWN_SETSIGMASK |
        POSIX_SPAWN_SETSIGDEF |
        POSIX_SPAWN_START_SUSPENDED
    posix_spawnattr_setflags(&spawnAttr, Int16(flags))
}
```

- Similarly, `.additionalFileAttributeConfigurator: (@Sendable (inout posix_spawn_file_actions_t?) throws -> Void)` allows developers to customize `posix_spawn_file_actions_t`. For instance, a developer might want to bind child file descriptors, other than standard input (fd 0), standard output (fd 1), and standard error (fd 2), to parent file descriptors:

```swift
let config = Subprocess.Configuration(executing: .at("/my/executable"))
// Bind child fd 4 to a parent fd
config.additionalFileAttributeConfigurator = { fileAttr in
    let parentFd: FileDescriptor = ...
    posix_spawn_file_actions_adddup2(&fileAttr, parentFd.rawValue, 4)
} 
```

_(We welcome community input on which Linux and Windows "escape hatches" we should add)_


### `Subprocess.InputMethod`

In addition to supporting the direct passing of `Sequence<UInt8>` and `AsyncSequence<UInt8>` as the standard input to the child process, `Subprocess` also provides a `Subprocess.InputMethod` type that includes two additional input options:
- `.noInput`: Specifies that the subprocess does not require any standard input. This is the default value.
- `.readFrom`: Specifies that the subprocess should read its standard input from a file descriptor provided by the developer. Subprocess will automatically close the file descriptor after the process is spawned if `closeWhenDone` is set to `true`.

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct InputMethod: Sendable, Hashable {
        public static var noInput: Self
        public static func readFrom(_ fd: FileDescriptor, closeWhenDone: Bool) -> Self
    }
}
```

Here are some examples:

```swift
// By default `InputMethod` is set to `.noInput`
let ls = try await Subprocess.run(executing: .named("ls"))

// Alteratively, developers could pass in a file descriptor
let fd: FileDescriptor = ...
let cat = try await Subprocess.run(executing: .named("cat"), input: .readFrom(fd, closeWhenDone: true))

// Pass in a async sequence directly
let sequence: AsyncSequence = ...
let exe = try await Subprocess.run(executing: .at("/some/executable"), input: sequence)
```


### `Subprocess` Output Methods

`Subprocess` uses two types to describe where the standard output and standard error of the child process should be redirected. These two types, `Subprocess.collectOutputMethod` and `Subprocess.redirectOutputMethod`, correspond to the two general categories of `run` methods mentioned above. Similar to `InputMethod`, both `OutputMethod`s add two general output destinations:
- `.discard`: Specifies that the child process's output should be discarded, effectively written to `/dev/null`.
- `.writeTo`: Specifies that the child process should write its output to a file descriptor provided by the developer. Subprocess will automatically close the file descriptor after the process is spawned if `closeWhenDone` is set to `true`.

`CollectedOutMethod` adds one more option to non-closure-based `run` methods that return a `CollectedResult`: `.collect` and its variation `.collect(limit:)`. This option specifies that `Subprocess` should collect the output as `Data`. Since the output of a child process could be arbitrarily large, `Subprocess` imposes a limit on how many bytes it will collect. By default, this limit is 16kb (when specifying `.collect`). Developers can override this limit by specifying `.collect(limit: newLimit)`:

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct CollectedOutputMethod: Sendable, Hashable {
        // Discard the output (write to /dev/null)
        public static var discard: Self
        // Collect the output as Data with the default 16kb limit
        public static var collect: Self
        // Write the output directly to a FileDescriptor
        public static func writeTo(_ fd: FileDescriptor, closeWhenDone: Bool) -> Self
        // Collect the output as Data with modified limit (in bytes).
        public static func collect(limit limit: Int) -> Self
    }
}
```

On the other hand, `RedirectedOutputMethod` adds one more option, `.redirect`, to the closure-based `run` methods to signify that output should be redirected to the `.standardOutput` or `.standardError` property of `Subprocess` passed to the closure as `AsyncSequence`. Since `AsyncSequence` is not push-based, there is no byte limit for this option:

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct RedirectedOutputMethod: Sendable, Hashable {
        // Discard the output (write to /dev/null)
        public static var discard: Self
        // Redirect the output as AsyncSequence
        public static var redirect: Self
        // Write the output directly to a FileDescriptor
        public static func writeTo(_ fd: FileDescriptor, closeWhenDone: Bool) -> Self
    }
}
```

Here are some examples of using both output methods:

```swift
let ls = try await Subprocess.run(executing: .named("ls"), output: .collect)
// The output has been collected as `Data`, up to 16kb limit
print("ls output: \(String(data: ls.standardOutput!, encoding: .utf8)!)")

// Increase the default buffer limit to 256kb
let curl = try await Subprocess.run(
    executing: .named("curl"),
    output: .collect(limit: 256 * 1024)
)
print("curl output: \(String(data: curl.standardOutput!, encoding: .utf8)!)")

// Write to a specific file descriptor
let fd: FileDescriptor = try .open(...)
let result = try await Subprocess.run(
    executing: .at("/some/script"), output: .writeTo(fd, closeWhenDone: true))

// Redirect the output as AsyncSequence
let result2 = try await Subprocess.run(executing: .named("/some/script"), output: .redirect) { subprocess in
    // Output can be access via `subprocess.standardOutput` here
    for try await item in subprocess.standardOutput! {
        print(item)
    }
    return "Done"
}
```


### Result Types

`Subprocess` provides two "Result" types corresponding to the two categories of `run` methods: `Subprocess.CollectedResult` and `Subprocess.Result<T>`.

`Subprocess.collectResult` is essentially a collection of properties that represent the result of an execution after the child process has exited. It is used by the non-closure-based `run` methods. In many ways, `CollectedResult` can be seen as the "synchronous" version of `Subprocess`—instead of the asynchronous `AsyncSequence<UInt8>`, the standard IOs can be retrieved via synchronous `Data`.

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct CollectedResult: Sendable, Hashable {
        public let processIdentifier: ProcessIdentifier
        public let terminationStatus: TerminationStatus
        public let standardOutput: Data?
        public let standardError: Data?
    }
}
```

`Subprocess.Result` is a simple wrapper around the generic result returned by the `run` closures with the corresponding `TerminationStatus` of the child process:

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct Result<T: Sendable>: Sendable {
        public let terminationStatus: TerminationStatus
        public let value: T
    }
}

@available(FoundationPreview 0.4, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Subprocess.Result: Equatable where T : Equatable {}

@available(FoundationPreview 0.4, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Subprocess.Result : Hashable where T : Hashable {}
```


### `Subprocess.Executable`

`Subprocess` utilizes `Executable` to configure how the executable is resolved. Developers can create an `Executable` using two static methods: `.named()`, indicating that an executable name is provided, and `Subprocess` should try to automatically resolve the executable path, and `.at()`, signaling that an executable path is provided, and `Subprocess` should use it unmodified.

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct Executable: Sendable, Hashable {
        /// Create an `Executable` with an executable name such as `ls`
        public static func named(_ executableName: String) -> Self
        /// Create an `Executable` with an executable path
        /// such as `/bin/ls`
        public static func at(_ filePath: FilePath) -> Self
        // Resolves the executable path with the given `Environment` value
        public func resolveExecutablePath(in environment: Environment) -> FilePath?
    }
}
```


### `Subprocess.Environment`

`struct Environment` is used to configure how should the process being launched receive its environment values:

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct Environment: Sendable {
        /// A copy of the current environment value of the launching process
        public static var inherit: Self { get }
        /// Update or insert the environment values of self with
        /// the supplied values
        public func updating(
            _ newValue: [String : String]) -> Self
        public func updating(
            _ newValue: [Data : Data]) -> Self
        /// Use the supplied values directly
        public static func custom(
            _ newValue: [String : String]) -> Self
        public static func custom(
            _ newValue: [Data : Data]) -> Self
    }
}
```

Developers have the option to:
- Inherit the same environment variables as the launching process by using `.inherit`. This is the default option.
- Inherit the environment variables from the launching process with overrides via `.inherit.updating()`.
- Specify custom values for environment variables using `.custom()`.

```swift
// Override the `PATH` environment value from launching process
let result = try await Subprocess.run(
    executing: .at("/some/executable"),
    environment: .inherit.updating(
        ["PATH" : "/some/new/path"]
    )
)

// Use custom values
let result2 = try await Subprocess.run(
    executing: .at("/at"),
    environment: .custom([
        "PATH" : "/some/path"
        "HOME" : "/Users/Charles"
    ])
)
```

`Environment` is designed to support both `String` and raw bytes for the use case where the environment values might not be valid UTF8 strings.


### `Subprocess.Arguments`

`Subprocess.Arguments` is used to configure the spawn arguments sent to the child process. It conforms to `ExpressibleByArrayLiteral`. In most cases, developers can simply pass in an array `[String]` with the desired arguments. However, there might be scenarios where a developer wishes to override the first argument (i.e., the executable path). This is particularly useful because some processes might behave differently based on the first argument provided. The ability to override the executable path can be achieved by specifying the `pathOverride` parameter:


```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct Arguments: Sendable, ExpressibleByArrayLiteral {
        public typealias ArrayLiteralElement = String
        /// Creates an Arguments object using the given literal values
        public init(arrayLiteral elements: ArrayLiteralElement...)
        /// Overrides the first arguments (aka the executable path)
        /// with the given value. If `executablePathOverride` is nil,
        /// `Arguments` will automatically use the executable path
        /// as the first argument.
        public init(executablePathOverride: String?, remainingValues: [String])
        /// Overrides the first arguments (aka the executable path)
        /// with the given value. If `executablePathOverride` is nil,
        /// `Arguments` will automatically use the executable path
        /// as the first argument.
        public init(executablePathOverride: Data?, remainingValues: [Data])
    }
}
```

Similar to `Environment`, `Arguments` also supports raw bytes in addition to `String`.

```swift
// In most cases, simply pass in an array
let result = try await Subprocess.run(
    executing: .at("/some/executable"),
    arguments: ["arg1", "arg2"]
)

// Override the executable path
let result2 = try await Subprocess.run(
    executing: .at("/some/executable"),
    arguments: .init(["arg1", "arg2"], overrideExecutablePathWith: "/new/executable/path")
)
```


### `Subprocess.TerminationStatus`

`Subprocess.TerminationStatus` is used to communicate the exit statuses of a process: `exited`, `signalled`, or `stillActive` on Windows. 

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public enum TerminationStatus: Sendable, Hashable {
    #if canImport(WinSDK)
        public typealias Code = DWORD
    #else
        public typealias Code = CInt
    #endif

    #if canImport(WinSDK)
        case stillActive
    #endif
        case exit(Code)
        case unhandledException(Code)
        // A process is terminated successfully when it exited 0
        public var isSuccess: Bool
        public var wasUnhandledException: Bool
    }
}
```


### `Subprocess.AsyncBytes`

`Subprocess` vends `AsyncBytes` as the concrete implementation of `AsyncSequence<UInt8>`, used by `Subprocess` as the `standardOutput` and `standardError` properties.

```swift
extension Subprocess {
    @available(FoundationPreview 0.4, *)
    @available(iOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public struct AsyncBytes: AsyncSequence, Sendable {
        public typealias Element = UInt8
        public typealias AsyncIterator = Iterator

        public func makeAsyncIterator() -> Iterator

        @_nonSendable
        public struct Iterator: AsyncIteratorProtocol {
            public typealias Element = UInt8

            public mutating func next() async throws -> UInt8?
        }
    }
}
```


### Task Cancellation

If the task running `Subprocess.run` is cancelled while the child process is running, `Subprocess` will attempt to release all the resources it acquired (i.e. file descriptors) and then terminate the child process via `SIGKILL`.


## Impact on Existing Code

No impact on existing code is anticipated. All introduced changes are additive.


## Future Directions

### Automatic Splitting of `Arguments`

Ideally, the `Arguments` feature should automatically split a string, such as "-a -n 1024 -v 'abc'", into an array of arguments. This enhancement would enable `Arguments` to conform to `ExpressibleByStringLiteral`, allowing developers to conveniently pass either a `String` or `[String]` as `Arguments`.

I decided to defer this feature because it turned out to be a "hard problem" -- different platforms handle arguments differently, requiring careful consideration to ensure correctness.

For reference, Python uses [`shlex.split`](https://docs.python.org/3/library/shlex.html), which could serve as a valuable starting point for implementation.

## Combined `stdout` and `stderr`

In Python's `Subprocess`, developers can merge standard output and standard error into a single stream. This is particularly useful when an executable improperly utilizes standard error as standard output (or vice versa). We should explore the most effective way to achieve this enhancement without introducing confusion to existing parameters—perhaps by introducing a new property.


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
