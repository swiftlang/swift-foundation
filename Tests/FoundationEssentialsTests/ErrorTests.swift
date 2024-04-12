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

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif

struct ErrorTests {
    func thisThrows() throws {
        throw CocoaError(CocoaError.Code(rawValue: 42), userInfo: ["hi" : "there"])
    }
    
    @Test func test_throwCocoaError() {
        let code: CocoaError.Code
        do {
            try thisThrows()
            code = .featureUnsupported
        } catch {
            if let error = error as? CocoaError {
                code = error.code
            } else {
                code = .featureUnsupported
            }
        }
        
        #expect(code.rawValue == 42)
    }
}
