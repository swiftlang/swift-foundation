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

#if canImport(Synchronization)
internal import Synchronization
#endif

extension AttributedString.Guts {
    typealias Version = UInt
    
    #if canImport(Synchronization)
    private static let _nextVersion = Atomic<Version>(0)
    #else
    private static let _nextVersion = LockedState<Version>(initialState: 0)
    #endif
    
    static func createNewVersion() -> Version {
        #if canImport(Synchronization)
        _nextVersion.wrappingAdd(1, ordering: .relaxed).oldValue
        #else
        _nextVersion.withLock { value in
            defer {
                value &+= 1
            }
            return value
        }
        #endif
    }
    
    func incrementVersion() {
        self.version = Self.createNewVersion()
    }
}

// MARK: - Public API

@available(FoundationPreview 6.2, *)
extension AttributedString.Index {
    /// Indicates whether the index is valid for use with the provided attributed string.
    /// - Parameter text: An attributed string used to validate the index.
    /// - Returns: `true` when the index is valid for use with the provided attributed string; otherwise, false. An index is valid if it is both within the bounds of the attributed string and was produced from the provided string without any intermediate mutations.
    public func isValid(within text: some AttributedStringProtocol) -> Bool {
        self._version == text.__guts.version &&
        self >= text.startIndex &&
        self < text.endIndex
    }
    
    /// Indicates whether the index is valid for use with the provided discontiguous attributed string.
    /// - Parameter text: A discontiguous attributed string used to validate the index.
    /// - Returns: `true` when the index is valid for use with the provided discontiguous attributed string; otherwise, false. An index is valid if it is both within the bounds of the discontigous attributed string and was produced from the provided string without any intermediate mutations.
    public func isValid(within text: DiscontiguousAttributedSubstring) -> Bool {
        self._version == text._guts.version &&
        text._indices.contains(self._value)
    }
}

@available(FoundationPreview 6.2, *)
extension Range<AttributedString.Index> {
    /// Indicates whether the range is valid for use with the provided attributed string.
    /// - Parameter text: An attributed string used to validate the range.
    /// - Returns: `true` when the range is valid for use with the provided attributed string; otherwise, false. A range is valid if its lower and upper bounds are each either valid in the attributed string or equivalent to the string's `endIndex`.
    public func isValid(within text: some AttributedStringProtocol) -> Bool {
        // Note: By nature of Range's lowerBound <= upperBound requirement, this is also sufficient to determine that lowerBound <= endIndex && upperBound >= startIndex
        self.lowerBound._version == text.__guts.version &&
        self.lowerBound >= text.startIndex &&
        self.upperBound._version == text.__guts.version &&
        self.upperBound <= text.endIndex
    }
    
    /// Indicates whether the range is valid for use with the provided discontiguous attributed string.
    /// - Parameter text: A discontiguous attributed string used to validate the range.
    /// - Returns: `true` when the range is valid for use with the provided discontiguous attributed string; otherwise, false. A range is valid if its lower and upper bounds are each either valid in the discontiguous attributed string or equivalent to the string's `endIndex`.
    public func isValid(within text: DiscontiguousAttributedSubstring) -> Bool {
        let endIndex = text._indices.ranges.last?.upperBound
        return self.lowerBound._version == text._guts.version &&
            (self.lowerBound._value == endIndex || text._indices.contains(self.lowerBound._value)) &&
            self.upperBound._version == text._guts.version &&
            (self.upperBound._value == endIndex || text._indices.contains(self.upperBound._value))
    }
}

@available(FoundationPreview 6.2, *)
extension RangeSet<AttributedString.Index> {
    /// Indicates whether the range set is valid for use with the provided attributed string.
    /// - Parameter text: An attributed string used to validate the range set.
    /// - Returns: `true` when the range set is valid for use with the provided attributed string; otherwise, false. A range set is valid if each of its ranges are valid in the attributed string.
    public func isValid(within text: some AttributedStringProtocol) -> Bool {
        self.ranges.allSatisfy {
            $0.isValid(within: text)
        }
    }
    
    /// Indicates whether the range set is valid for use with the provided discontiguous attributed string.
    /// - Parameter text: A discontigious attributed string used to validate the range set.
    /// - Returns: `true` when the range set is valid for use with the provided discontiguous attributed string; otherwise, false. A range set is valid if each of its ranges are valid in the discontiguous attributed string.
    public func isValid(within text: DiscontiguousAttributedSubstring) -> Bool {
        self.ranges.allSatisfy {
            $0.isValid(within: text)
        }
    }
}
