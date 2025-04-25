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
/// Returns the bundle most likely to contain resources for the calling code.
///
/// Code in an app, app extension, framework, etc. will return the bundle associated with that target.
/// Code in a Swift Package target will return the resource bundle associated with that target.
@available(macOS 10.0, iOS 2.0, tvOS 9.0, watchOS 2.0, *)
@freestanding(expression)
public macro bundle() -> Bundle = #externalMacro(module: "FoundationMacros", type: "BundleMacro")
#endif

