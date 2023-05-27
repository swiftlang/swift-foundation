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

#if !FOUNDATION_FRAMEWORK

public struct Bundle: Hashable, Equatable, Sendable {
    public static let main: Bundle = Bundle()

    public var localizations: [String] { [] }

    public var infoDictionary: [String : Any]? { [:] }

    public static func preferredLocalizations(
        from localizationsArray: [String],
        forPreferences preferencesArray: [String]?) -> [String] {
        return []
    }
}

#endif
