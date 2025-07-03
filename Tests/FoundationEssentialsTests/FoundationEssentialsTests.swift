//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
import Testing

@Suite("FoundationEssentials")
private struct FoundationEssentialsTests {
    @Test func essentialsDoesNotImportInternationalization() {
        // Ensures that targets that only import FoundationEssentials do not end up calling functionality in FoundationInternationalization
        // We use a non-GMT TimeZone as proxy for whether FoundationInternationalization is loaded at runtime
        #expect(TimeZone(identifier: "America/Los_Angeles") == nil)
    }
}
#endif
