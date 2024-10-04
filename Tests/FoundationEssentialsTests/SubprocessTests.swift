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
        let pwd = try await Subprocess.run(.named("pwd"))
        let result = String(data: pwd.standardOutput, encoding: .utf8)!
        XCTAssert(pwd.terminationStatus.isSuccess)
        XCTAssert(!result.isEmpty)
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

    func testLongText() async throws {
        let textURL = testResourcePath(for: "PrideAndPrejudice", withExtension: "txt")!
        let cat = try await Subprocess.run(.named("cat"), arguments: [textURL], output: .collect(limit: 1024 * 1024))
        XCTAssertTrue(cat.terminationStatus.isSuccess)
        let fileLength = try Data(contentsOfFile: textURL).count
        // Make sure we actually read all bytes
        XCTAssertEqual(cat.standardOutput.count, fileLength)
    }
}
