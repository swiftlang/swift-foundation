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

// Data.WritingOptions is not a true OptionSet - the file protection constants act as an enum (exactly zero or one must be used)
// while the remaining options (.atomic, .withoutOverwriting) act as an option set (any number - or none - may be selected).
// Note: .atomic and .withoutOverwriting are mutually exclusive in practice, but that is enforced by receivers of Data.WritingOptions and not enforced in the option set itself as this may not apply to future options and is supported by their raw values
// Below are implementations for all SetAlgebra functions that implement correct logic for the file protection enum.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data.WritingOptions {

    @inline(__always)
    @_alwaysEmitIntoClient
    private var fileProtectionPart: RawValue {
        self.rawValue & 0xf0000000
    }

    // All non-file protection options use the remaining bits
    @inline(__always)
    @_alwaysEmitIntoClient
    private var optionsPart: RawValue {
        self.rawValue & ~0xf0000000
    }

    @inline(__always)
    @_alwaysEmitIntoClient
    public func contains(_ member: Data.WritingOptions) -> Bool {
        if member.fileProtectionPart != 0 {
            // If member specifies a file protection level, self must have the exact same level
            return self.fileProtectionPart == member.fileProtectionPart && (self.optionsPart & member.optionsPart) == member.optionsPart
        } else {
            // No file protection in member: check only the option bits
            return (self.optionsPart & member.optionsPart) == member.optionsPart
        }
    }

    @discardableResult
    @_alwaysEmitIntoClient
    public mutating func insert(_ newMember: Data.WritingOptions) -> (inserted: Bool, memberAfterInsert: Data.WritingOptions) {
        let inserted = !self.contains(newMember)
        self.formUnion(newMember)
        return (inserted, newMember)
    }

    @discardableResult
    @_alwaysEmitIntoClient
    public mutating func remove(_ member: Data.WritingOptions) -> Data.WritingOptions? {
        // Remove the file protection if self has the same protection level as member
        let removeProtection = self.fileProtectionPart == member.fileProtectionPart

        let result = (removeProtection ? self.fileProtectionPart : 0) | (self.optionsPart & member.optionsPart)
        self = Self(rawValue: (removeProtection ? 0 : self.fileProtectionPart) | (self.optionsPart & ~member.optionsPart))
        if result != 0 {
            return Self(rawValue: result)
        } else {
            return nil
        }
    }

    @_alwaysEmitIntoClient
    public mutating func formUnion(_ other: Data.WritingOptions) {
        // It is not possible to combine two different file protection levels; we must select one to keep.
        // To preserve the invariant that x.contains(e) implies x.union(y).contains(e), we keep self's protection.
        // If self has no protection, use other's.
        let newProtection = self.fileProtectionPart != 0 ? self.fileProtectionPart : other.fileProtectionPart
        self = Self(rawValue: newProtection | (self.optionsPart | other.optionsPart))
    }

    @_alwaysEmitIntoClient
    public mutating func formIntersection(_ other: Data.WritingOptions) {
        let newProtection: RawValue
        if self.fileProtectionPart == other.fileProtectionPart {
            // Same protection (or both unspecified): keep it
            newProtection = self.fileProtectionPart
        } else {
            // Different protection levels with no common value: drop the protection
            newProtection = 0
        }
        self = Self(rawValue: newProtection | (self.optionsPart & other.optionsPart))
    }

    @_alwaysEmitIntoClient
    public mutating func formSymmetricDifference(_ other: Data.WritingOptions) {
        var newProtection: RawValue
        if self.fileProtectionPart == other.fileProtectionPart {
            // Same protection (or both unspecified): remove it
            newProtection = 0
        } else if self.fileProtectionPart == 0 {
            // File protection only present in other, use that value
            newProtection = other.fileProtectionPart
        } else if other.fileProtectionPart == 0 {
            // File protection only present in self, use that value
            newProtection = self.fileProtectionPart
        } else {
            // Two concrete file protection values. We cannot preserve both, so we drop both
            newProtection = 0
        }
        self = Self(rawValue: newProtection | (self.optionsPart ^ other.optionsPart))
    }

    @_alwaysEmitIntoClient
    public func isSubset(of other: Data.WritingOptions) -> Bool {
        // If self specifies a file protection, other must have the exact same protection
        // (a specific protection level is not a subset of a different protection level)
        if self.fileProtectionPart != 0 && self.fileProtectionPart != other.fileProtectionPart {
            return false
        }

        return (self.optionsPart & ~other.optionsPart) == 0
    }
}
