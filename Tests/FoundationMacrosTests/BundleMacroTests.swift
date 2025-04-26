//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import XCTest
import FoundationMacros

final class BundleMacroTests: XCTestCase {

    func testSimple() {
        AssertMacroExpansion(
            macros: ["bundle": BundleMacro.self],
            """
            #bundle
            """,
            """
            {
                #if SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE
                    return Bundle.module
                #elseif SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE
                    #error("No resource bundle is available for this module. If resources are included elsewhere, specify the bundle manually.")
                #else
                    return Bundle(_dsoHandle: #dsohandle) ?? .main
                #endif
            }()
            """
        )
    }

    func testUsingParenthesis() {
        AssertMacroExpansion(
            macros: ["bundle": BundleMacro.self],
            """
            #bundle()
            """,
            """
            {
                #if SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE
                    return Bundle.module
                #elseif SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE
                    #error("No resource bundle is available for this module. If resources are included elsewhere, specify the bundle manually.")
                #else
                    return Bundle(_dsoHandle: #dsohandle) ?? .main
                #endif
            }()
            """
        )
    }
}
