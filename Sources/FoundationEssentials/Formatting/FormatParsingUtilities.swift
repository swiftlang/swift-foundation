//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

package func parseError(_ value: String, exampleFormattedString: String?) -> CocoaError {
    let errorStr: String
    if let exampleFormattedString = exampleFormattedString {
        errorStr = "Cannot parse \(value). String should adhere to the preferred format of the locale, such as \(exampleFormattedString)."
    } else {
        errorStr = "Cannot parse \(value)."
    }
    return CocoaError(CocoaError.formatting, userInfo: [ NSDebugDescriptionErrorKey: errorStr ])
}

