//===----------------------------------------------------------------------===//
 //
 // This source file is part of the Swift.org open source project
 //
 // Copyright (c) 2022 Apple Inc. and the Swift project authors
 // Licensed under Apache License v2.0 with Runtime Library Exception
 //
 // See https://swift.org/LICENSE.txt for license information
 //
 //===----------------------------------------------------------------------===//

#if os(Windows)
import WinSDK

internal struct Win32Error: Error {
    public typealias Code = DWORD
    public let code: Code

    public static var errorDomain: String {
        return "NSWin32ErrorDomain"
    }

    public init(_ code: Code) {
        self.code = code
    }
}

extension Win32Error: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
}
#endif
