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

public struct CharacterSet : Equatable, Hashable {
    public init() {}

    public func union(_ other: CharacterSet) -> CharacterSet { CharacterSet() }
    public mutating func formUnion(_ other: CharacterSet) {}
    public func intersection(_ other: CharacterSet) -> CharacterSet { CharacterSet() }
    public mutating func formIntersection(_ other: CharacterSet) {}
    public func symmetricDifference(_ other: CharacterSet) -> CharacterSet { CharacterSet() }
    public mutating func formSymmetricDifference(_ other: CharacterSet) {}

    public mutating func insert(charactersIn string: String) {}
    public mutating func insert(charactersIn range: Range<Unicode.Scalar>) {}
    public mutating func insert(charactersIn range: ClosedRange<Unicode.Scalar>) {}

    public func contains(_ member: Unicode.Scalar) -> Bool { return false }
}

// MARK: - Exported Character Sets
extension CharacterSet {
    public static let uppercaseLetters: CharacterSet = CharacterSet()
    public static let lowercaseLetters: CharacterSet = CharacterSet()
}

#endif
