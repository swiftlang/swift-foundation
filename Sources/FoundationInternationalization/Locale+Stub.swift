//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
#if !FOUNDATION_FRAMEWORK

// Stub implementation for Locale
public struct Locale : Hashable, Equatable, Sendable, Codable {
    public var identifier: String

    public static var autoupdatingCurrent: Locale { Locale(identifier: "") }

    public init(identifier: String) {
        self.identifier = identifier
    }
}

#endif
