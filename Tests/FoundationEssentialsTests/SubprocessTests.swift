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

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

#if canImport(TestSupport)
import TestSupport
#endif

import SystemPackage

final class SubprocessTests: XCTestCase {
    func testSimple() async throws {
        let ls = try await Subprocess.run(.named("ls"))
        let result = String(data: ls.standardOutput, encoding: .utf8)!
        XCTAssert(ls.terminationStatus.isSuccess)
        XCTAssert(!result.isEmpty)
        print(result)
    }

    func testInteractive() async throws {
        let su = try await Subprocess.run(.at("/Users/icharleshu/Developer/super.sh"), input: .readFrom(.standardInput, closeWhenDone: false))
        XCTAssert(!su.terminationStatus.isSuccess)
    }

    func testChained() async throws {
        let (readFd, writeFd) = try FileDescriptor.pipe()
        try await Subprocess.run(
            .named("ls"), output: .writeTo(writeFd, closeWhenDone: true), error: .discard)
        let grep = try await Subprocess.run(.named("grep"), arguments: ["com"], input: .readFrom(readFd, closeWhenDone: true))
        var output = String(data: grep.standardOutput, encoding: .utf8) ?? "Failed to decode"
        print("Output: \(output)")
    }

    func testLongText() async throws {
        let cat = try await Subprocess.run(
            .named("cat"),
            arguments: ["/Users/icharleshu/Downloads/PaP.txt"],
            output: .collect(limit: 1024 * 1024),
            error: .discard
        )
        print("after")
        print("Result: \(cat.standardOutput.count)")
    }

    func testComplex() async throws {
        struct Address: Codable {
            let ip: String
        }

        let result = try await Subprocess.run(
            .named("curl"),
            arguments: ["http://ip.jsontest.com/"]
        ) { execution in
            let output: [UInt8] = try await Array(execution.standardOutput)
            print("Output2: \(output)")
            let decoder = FoundationEssentials.JSONDecoder()
            return try decoder.decode(Address.self, from: Data(output))
        }
        XCTAssert(result.terminationStatus.isSuccess)
    }

    func testShell() async throws {
        let result = try await Subprocess.run(.named("sh")) { subprocess, writer in
            try await writer.write("ls | grep 'apple'\n".utf8)
            try await writer.finish()
            // Stream outputs
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    // Stream output line by line
                    let lineSequence = AsyncLineSequence(underlyingSequence: subprocess.standardOutput)
                    for try await line in lineSequence {
                        print("> \(line)")
                    }
                }
                try await group.waitForAll()
            }
        }
        XCTAssert(result.terminationStatus.isSuccess)
    }
}
