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

import SwiftSyntax
import SwiftSyntaxMacros
internal import SwiftSyntaxBuilder

public struct BundleMacro: SwiftSyntaxMacros.ExpressionMacro, Sendable {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
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
    }
}
