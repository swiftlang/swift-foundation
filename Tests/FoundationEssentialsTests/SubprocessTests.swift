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

final class SubprocessTests: XCTestCase {
    func testSimple() async throws {
        let ls = try await Subprocess.run(executing: .named("ls"), output: .collect, error: .discard)
        let result = String(data: ls.standardOutput!, encoding: .utf8)!
        XCTAssert(ls.terminationStatus.isSuccess)
        XCTAssert(!result.isEmpty)
    }

    func testComplex() async throws {
        struct Address: Codable {
            let ip: String
        }

        let result = try await Subprocess.run(
            executing: .named("curl"),
            arguments: ["http://ip.jsontest.com/"]
        ) { execution in
            let output: [UInt8] = try await Array(execution.standardOutput!)
            let decoder = FoundationEssentials.JSONDecoder()
            return try decoder.decode(Address.self, from: Data(output))
        }
        XCTAssert(result.terminationStatus.isSuccess)
    }

    func testShell() async throws {
        let result = try await Subprocess.run(executing: .named("sh")) { subprocess, writer in
            // Stream all outputs
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    // Stream output line by line
                    guard let stream = subprocess.standardOutput else {
                        return
                    }
                    let lineSequence = AsyncLineSequence(underlyingSequence: stream)
                    for try await line in lineSequence {
                        print("> \(line)")
                    }
                }
                group.addTask {
                    try await writer.write("ls\n".utf8)
                    try await writer.finish()
                }
                try await group.waitForAll()
            }
        }
        XCTAssert(result.terminationStatus.isSuccess)
    }
}
