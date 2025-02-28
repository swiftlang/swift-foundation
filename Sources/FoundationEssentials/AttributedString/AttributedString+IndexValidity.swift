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
    public func isValid(within text: some AttributedStringProtocol) -> Bool {
        self._version == text.__guts.version &&
        self >= text.startIndex &&
        self < text.endIndex
    }
    
    public func isValid(within text: DiscontiguousAttributedSubstring) -> Bool {
        self._version == text._guts.version &&
        text._indices.contains(self._value)
    }
}

@available(FoundationPreview 6.2, *)
extension Range<AttributedString.Index> {
    public func isValid(within text: some AttributedStringProtocol) -> Bool {
        self.lowerBound._version == text.__guts.version &&
        self.lowerBound >= text.startIndex &&
        self.lowerBound <= text.endIndex &&
        self.upperBound._version == text.__guts.version &&
        self.upperBound >= text.startIndex &&
        self.upperBound <= text.endIndex
    }
    
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
    public func isValid(within text: some AttributedStringProtocol) -> Bool {
        self.ranges.allSatisfy {
            $0.isValid(within: text)
        }
    }
    
    public func isValid(within text: DiscontiguousAttributedSubstring) -> Bool {
        self.ranges.allSatisfy {
            $0.isValid(within: text)
        }
    }
}
