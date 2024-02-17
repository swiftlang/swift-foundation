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

#if FOUNDATION_FRAMEWORK
// For Logger
@_implementationOnly import os
@_implementationOnly import _ForSwiftFoundation
@_implementationOnly import _CShims
#endif

internal func logFileIOErrno(_ err: Int32, at place: String) {
#if FOUNDATION_FRAMEWORK && !os(bridgeOS)
    let errnoDesc = String(cString: strerror(err))
    Logger(_NSOSLog()).error("Encountered \(place) failure \(err) \(errnoDesc)")
#endif
}
