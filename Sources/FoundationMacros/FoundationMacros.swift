//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if !FOUNDATION_FRAMEWORK && !FOUNDATION_MACROS_LIBRARY

import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct FoundationMacros: CompilerPlugin {
    var providingMacros: [Macro.Type] = [
        PredicateMacro.self,
        ExpressionMacro.self,
        BundleMacro.self
    ]
}

#endif
