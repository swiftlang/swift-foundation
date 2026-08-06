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

import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

@Suite("Error")
private struct ErrorTests {
    func thisThrows() throws {
        throw CocoaError(CocoaError.Code(rawValue: 42), userInfo: ["hi" : "there"])
    }
    
    @Test func throwCocoaError() {
        #expect {
            try thisThrows()
        } throws: {
            ($0 as? CocoaError)?.code.rawValue == 42
        }
    }
}
