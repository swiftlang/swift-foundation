//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// RUN: %target-run-simple-swift
// REQUIRES: executable_test
// REQUIRES: objc_interop
// REQUIRES: rdar49634697
// REQUIRES: rdar55727144

#if canImport(TestSupport)
import TestSupport
#endif // canImport(TestSupport)

#if canImport(FoundationEssentials)
@_spi(SwiftCorelibsFoundation)
@testable import FoundationEssentials
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

// MARK: - Test Suite

final class Issue1176Tests: XCTestCase {
  struct Thing: Codable, Equatable {
    var nestedArray: [Thing]

    init(_ nestedArray: [Thing] = []) {
      self.nestedArray = nestedArray
    }

    var depth: Int {
      var depth = 0
      var current: Thing = self
      while let next = current.nestedArray.first {
        depth += 1
        current = next
      }
      return depth
    }
  }

  private func _generateJSON(depth: Int) -> Data {
    let head = #"{"nestedArray":["#
    let tail = #"]}"#
    var json = ""
    for _ in 0...depth {
      json = head + json + tail
    }
    return Data(json.utf8)
  }

  func test_deepType() {
    var theThing = Thing()
    for depth in 0..<(JSONWriter.maximumRecursionDepth / 2 + 1) {
      XCTAssertEqual(theThing.depth, depth, "Expected depth: \(depth)")
      theThing = Thing([theThing])
    }
  }

  func testDecoding() {
    defer { fflush(stdout) }

    let decoder = JSONDecoder()
    for depth in 0..<(JSONScanner.maximumRecursionDepth / 2 + 1) {
      let json = _generateJSON(depth: depth)
      do {
        let decoded = try decoder.decode(Thing.self, from: json)
        XCTAssertEqual(decoded.depth, depth, "Unexpected object. Depth: \(depth)")
        print("✅ Decoding succeeded; Depth: \(depth)")
      } catch {
        print("❌ Decoding error is thrown at depth \(depth): \(error)")
        break
      }
    }
  }

  func testEncoding() {
    defer { fflush(stdout) }

    let encoder = JSONEncoder()
    var theThing = Thing()
    for depth in 0..<(JSONWriter.maximumRecursionDepth / 2 + 1) {
      let expectedJSON = _generateJSON(depth: depth)
      do {
        let encoded = try encoder.encode(theThing)
        XCTAssertEqual(expectedJSON, encoded, "Unexpected JSON; Depth: \(depth)")
        print("✅ Encoding succeeded; Depth: \(depth)")
        theThing = Thing([theThing])
      } catch {
        print("❌ Encoding error is thrown at depth \(depth): \(error)")
        break
      }
    }
  }
}
