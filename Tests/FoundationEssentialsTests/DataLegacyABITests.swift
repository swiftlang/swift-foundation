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

#if FOUNDATION_FRAMEWORK
@_spi(FoundationLegacyABI) @testable import Foundation
import Testing

@Suite("Foundation Legacy ABI")
private final class FoundationLegacyABITests {

    @Test func validateDataLegacyABI() {
        var data = Data()

        data._legacy_withUnsafeBytes { _ in }
        data._legacy_withUnsafeMutableBytes { _ in }
    }
}

#endif // FOUNDATION_FRAMEWORK
