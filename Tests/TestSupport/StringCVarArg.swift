//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
// In Foundation.framework, String conforms to CVarArg itself
public typealias CVarArgString = String
#else
public final class CVarArgString: CustomStringConvertible, ExpressibleByStringLiteral, CVarArg {
    private let string: String

    public init(_ string: String) {
        self.string = string
    }

    public init(stringLiteral: String) {
        self.string = stringLiteral
    }

    public var description: String {
        string
    }

    public var _cVarArgEncoding: [Int] {
        return _encodeBitsAsWords(self)
    }
}
#endif

