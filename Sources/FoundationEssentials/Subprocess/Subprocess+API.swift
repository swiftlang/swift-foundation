//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import SystemPackage

extension Subprocess {
    public static func run(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: InputMethod = .noInput,
        output: CollectedOutputMethod = .collect,
        error: CollectedOutputMethod = .collect
    ) async throws -> CollectedResult {
        let result = try await self.run(
            executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            platformOptions: platformOptions,
            input: input,
            output: .init(method: output.method),
            error: .init(method: error.method)
        ) { subprocess in
            let (standardOutput, standardError) = try await subprocess.captureIOs()
            return (
                processIdentifier: subprocess.processIdentifier,
                standardOutput: standardOutput,
                standardError: standardError
            )
        }
        return CollectedResult(
            processIdentifier: result.value.processIdentifier,
            terminationStatus: result.terminationStatus,
            standardOutput: result.value.standardOutput,
            standardError: result.value.standardError
        )
    }

    public static func run(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: some Sequence<UInt8>,
        output: CollectedOutputMethod = .collect,
        error: CollectedOutputMethod = .collect
    ) async throws -> CollectedResult {
        let result = try await self.run(
            executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            platformOptions: platformOptions,
            output: .init(method: output.method),
            error: .init(method: output.method)
        ) { subprocess, writer in
            try await writer.write(input)
            try await writer.finish()
            let (standardOutput, standardError) = try await subprocess.captureIOs()
            return (
                processIdentifier: subprocess.processIdentifier,
                standardOutput: standardOutput,
                standardError: standardError
            )
        }
        return CollectedResult(
            processIdentifier: result.value.processIdentifier,
            terminationStatus: result.terminationStatus,
            standardOutput: result.value.standardOutput,
            standardError: result.value.standardError
        )
    }

    public static func run<S: AsyncSequence>(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: S,
        output: CollectedOutputMethod = .collect,
        error: CollectedOutputMethod = .collect
    ) async throws -> CollectedResult where S.Element == UInt8 {
        let result =  try await self.run(
            executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            platformOptions: platformOptions,
            output: .init(method: output.method),
            error: .init(method: output.method)
        ) { subprocess, writer in
            try await writer.write(input)
            try await writer.finish()
            let (standardOutput, standardError) = try await subprocess.captureIOs()
            return (
                processIdentifier: subprocess.processIdentifier,
                standardOutput: standardOutput,
                standardError: standardError
            )
        }
        return CollectedResult(
            processIdentifier: result.value.processIdentifier,
            terminationStatus: result.terminationStatus,
            standardOutput: result.value.standardOutput,
            standardError: result.value.standardError
        )
    }
}

// MARK: Custom Execution Body
extension Subprocess {
    public static func run<R>(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: InputMethod = .noInput,
        output: RedirectedOutputMethod = .redirectToSequence,
        error: RedirectedOutputMethod = .redirectToSequence,
        _ body: (@Sendable @escaping (Subprocess) async throws -> R)
    ) async throws -> ExecutionResult<R> {
        return try await Configuration(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            platformOptions: platformOptions
        )
        .run(input: input, output: output, error: error, body)
    }

    public static func run<R>(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions,
        input: some Sequence<UInt8>,
        output: RedirectedOutputMethod = .redirectToSequence,
        error: RedirectedOutputMethod = .redirectToSequence,
        _ body: (@Sendable @escaping (Subprocess) async throws -> R)
    ) async throws -> ExecutionResult<R> {
        return try await Configuration(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            platformOptions: platformOptions
        )
        .run(output: output, error: error) { execution, writer in
            try await writer.write(input)
            try await writer.finish()
            return try await body(execution)
        }
    }

    public static func run<R, S: AsyncSequence>(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: S,
        output: RedirectedOutputMethod = .redirectToSequence,
        error: RedirectedOutputMethod = .redirectToSequence,
        _ body: (@Sendable @escaping (Subprocess) async throws -> R)
    ) async throws -> ExecutionResult<R> where S.Element == UInt8 {
        return try await Configuration(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            platformOptions: platformOptions
        )
        .run(output: output, error: error) { execution, writer in
            try await writer.write(input)
            try await writer.finish()
            return try await body(execution)
        }
    }

    public static func run<R>(
        _ executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        output: RedirectedOutputMethod = .redirectToSequence,
        error: RedirectedOutputMethod = .redirectToSequence,
        _ body: (@Sendable @escaping (Subprocess, StandardInputWriter) async throws -> R)
    ) async throws -> ExecutionResult<R> {
        return try await Configuration(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            platformOptions: platformOptions
        )
        .run(output: output, error: error, body)
    }
}

// MARK: - Configuration Based
extension Subprocess {
    public static func run<R>(
        using configuration: Configuration,
        output: RedirectedOutputMethod = .redirectToSequence,
        error: RedirectedOutputMethod = .redirectToSequence,
        _ body: (@Sendable @escaping (Subprocess, StandardInputWriter) async throws -> R)
    ) async throws -> ExecutionResult<R> {
        return try await configuration.run(output: output, error: error, body)
    }
}

