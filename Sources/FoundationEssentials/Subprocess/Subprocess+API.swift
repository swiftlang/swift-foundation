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
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: InputMethod = .noInput,
        output: CollectedOutputMethod = .collect,
        error: CollectedOutputMethod = .collect
    ) async throws -> CollectedResult {
        let result = try await self.run(
            executing: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            platformOptions: platformOptions,
            input: input,
            output: .init(method: output.method),
            error: .init(method: error.method)
        ) { subprocess in
            return (
                processIdentifier: subprocess.processIdentifier,
                standardOutput: try subprocess.captureStandardOutput(),
                standardError: try subprocess.captureStandardError()
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
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: some Sequence<UInt8>,
        output: CollectedOutputMethod = .collect,
        error: CollectedOutputMethod = .collect
    ) async throws -> CollectedResult {
        let result = try await self.run(
            executing: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            platformOptions: platformOptions,
            output: .init(method: output.method),
            error: .init(method: output.method)
        ) { execution, writer in
            try await writer.write(input)
            try await writer.finish()
            return (
                processIdentifier: execution.processIdentifier,
                standardOutput: try execution.captureStandardOutput(),
                standardError: try execution.captureStandardError()
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
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: S,
        output: CollectedOutputMethod = .collect,
        error: CollectedOutputMethod = .collect
    ) async throws -> CollectedResult where S.Element == UInt8 {
        let result =  try await self.run(
            executing: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            platformOptions: platformOptions,
            output: .init(method: output.method),
            error: .init(method: output.method)
        ) { execution, writer in
            try await writer.write(input)
            try await writer.finish()
            return (
                processIdentifier: execution.processIdentifier,
                standardOutput: try execution.captureStandardOutput(),
                standardError: try execution.captureStandardError()
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
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: InputMethod = .noInput,
        output: RedirectedOutputMethod = .redirect,
        error: RedirectedOutputMethod = .discard,
        _ body: (@Sendable @escaping (Subprocess) async throws -> R)
    ) async throws -> Result<R> {
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
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions,
        input: some Sequence<UInt8>,
        output: RedirectedOutputMethod = .redirect,
        error: RedirectedOutputMethod = .discard,
        _ body: (@Sendable @escaping (Subprocess) async throws -> R)
    ) async throws -> Result<R> {
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
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        input: S,
        output: RedirectedOutputMethod = .redirect,
        error: RedirectedOutputMethod = .discard,
        _ body: (@Sendable @escaping (Subprocess) async throws -> R)
    ) async throws -> Result<R> where S.Element == UInt8 {
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
        executing executable: Executable,
        arguments: Arguments = [],
        environment: Environment = .inherit,
        workingDirectory: FilePath? = nil,
        platformOptions: PlatformOptions = .default,
        output: RedirectedOutputMethod = .redirect,
        error: RedirectedOutputMethod = .discard,
        _ body: (@Sendable @escaping (Subprocess, StandardInputWriter) async throws -> R)
    ) async throws -> Result<R> {
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
        withConfiguration configuration: Configuration,
        output: RedirectedOutputMethod = .redirect,
        error: RedirectedOutputMethod = .redirect,
        _ body: (@Sendable @escaping (Subprocess, StandardInputWriter) async throws -> R)
    ) async throws -> Result<R> {
        return try await configuration.run(output: output, error: error, body)
    }
}

