//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    public enum AttributeMergePolicy : Sendable {
        case keepNew
        case keepCurrent
        
        internal var combinerClosure: (_AttributeValue, _AttributeValue) -> _AttributeValue {
            switch self {
            case .keepNew: return { _, new in new }
            case .keepCurrent: return { current, _ in current }
            }
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol AttributedStringAttributeMutation {
    mutating func setAttributes(_ attributes: AttributeContainer)
    mutating func mergeAttributes(_ attributes: AttributeContainer, mergePolicy: AttributedString.AttributeMergePolicy)
    mutating func replaceAttributes(_ attributes: AttributeContainer, with others: AttributeContainer)
}

@dynamicMemberLookup
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol AttributedStringProtocol
    : AttributedStringAttributeMutation, Hashable, CustomStringConvertible
{
    var startIndex : AttributedString.Index { get }
    var endIndex : AttributedString.Index { get }

    var runs : AttributedString.Runs { get }
    var characters : AttributedString.CharacterView { get }
    var unicodeScalars : AttributedString.UnicodeScalarView { get }

    subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? { get set }
    subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? { get set }
    subscript<S: AttributeScope>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> { get set }

    subscript<R: RangeExpression>(bounds: R) -> AttributedSubstring where R.Bound == AttributedString.Index { get }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension AttributedStringProtocol {
    func settingAttributes(_ attributes: AttributeContainer) -> AttributedString {
        var new = AttributedString(self)
        new.setAttributes(attributes)
        return new
    }

    func mergingAttributes(_ attributes: AttributeContainer, mergePolicy:  AttributedString.AttributeMergePolicy = .keepNew) -> AttributedString {
        var new = AttributedString(self)
        new.mergeAttributes(attributes, mergePolicy:  mergePolicy)
        return new
    }

    func replacingAttributes(_ attributes: AttributeContainer, with others: AttributeContainer) -> AttributedString {
        var new = AttributedString(self)
        new.replaceAttributes(attributes, with: others)
        return new
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol {
    internal var __guts : AttributedString.Guts {
        if let s = self as? AttributedString {
            return s._guts
        } else if let s = self as? AttributedSubstring {
            return s._guts
        } else {
            return self.characters._guts
        }
    }
    
    internal var _baseString: _BString {
        __guts.string
    }

    internal var _bounds: Range<AttributedString.Index> {
        startIndex ..< endIndex
    }

    internal var _stringBounds: Range<_BString.Index> {
        startIndex._value ..< endIndex._value
    }
}

extension AttributedString {
    internal var _baseString: _BString {
        _guts.string
    }

    internal var _bounds: Range<_BString.Index> {
        Range(uncheckedBounds: (_guts.string.startIndex, _guts.string.endIndex))
    }
}

extension AttributedSubstring {
    internal var _baseString: _BString {
        _guts.string
    }

    internal var _bounds: Range<_BString.Index> {
        _range._bstringRange
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol {
    public var description : String {
        var result = ""
        let guts = self.__guts
        guts.enumerateRuns(containing: self._bounds._utf8OffsetRange) { run, loc, _, modified in
            let range = guts.utf8IndexRange(from: loc ..< loc + run.length)
            result += (result.isEmpty ? "" : "\n") + "\(String(self.characters[range])) \(run.attributes)"
            modified = .guaranteedNotModified
        }
        return result
    }

    public func hash(into hasher: inout Hasher) {
        __guts.characterwiseHash(in: _stringBounds, into: &hasher)
    }

    @_specialize(where Self == AttributedString, RHS == AttributedString)
    @_specialize(where Self == AttributedString, RHS == AttributedSubstring)
    @_specialize(where Self == AttributedSubstring, RHS == AttributedString)
    @_specialize(where Self == AttributedSubstring, RHS == AttributedSubstring)
    public static func == <RHS: AttributedStringProtocol>(lhs: Self, rhs: RHS) -> Bool {
        AttributedString.Guts.characterwiseIsEqual(
            lhs.__guts, in: lhs._stringBounds,
            to: rhs.__guts, in: rhs._stringBounds)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension AttributedStringProtocol {
    func index(afterCharacter i: AttributedString.Index) -> AttributedString.Index {
        self.characters.index(after: i)
    }
    func index(beforeCharacter i: AttributedString.Index) -> AttributedString.Index {
        self.characters.index(before: i)
    }
    func index(_ i: AttributedString.Index, offsetByCharacters distance: Int) -> AttributedString.Index {
        self.characters.index(i, offsetBy: distance)
    }

    func index(afterUnicodeScalar i: AttributedString.Index) -> AttributedString.Index {
        self.unicodeScalars.index(after: i)
    }
    func index(beforeUnicodeScalar i: AttributedString.Index) -> AttributedString.Index {
        self.unicodeScalars.index(before: i)
    }
    func index(_ i: AttributedString.Index, offsetByUnicodeScalars distance: Int) -> AttributedString.Index {
        self.unicodeScalars.index(i, offsetBy: distance)
    }

    func index(afterRun i: AttributedString.Index) -> AttributedString.Index {
        // Expected semantics: Result is the end of the run that contains `i`.
        precondition(i < endIndex, "Can't advance beyond end index")
        precondition(i >= startIndex, "Invalid attributed string index")
        let (_, range) = self.__guts.run(at: i, clampedBy: self._bounds)
        assert(i < range.upperBound)
        return range.upperBound
    }

    func index(beforeRun i: AttributedString.Index) -> AttributedString.Index {
        // Expected semantics: result is the start of the run preceding the one that contains `i`.
        // (I.e., `i` needs to get implicitly rounded down to the nearest run boundary before we
        // step back.)
        let guts = self.__guts
        let bounds = self._bounds
        precondition(i <= bounds.upperBound, "Invalid attributed string index")
        precondition(i > bounds.lowerBound, "Can't advance below start index")
        let prev = guts.utf8Index(before: i)
        let (_, range) = guts.run(at: prev, clampedBy: bounds)
        if range.upperBound <= i {
            // Fast path: `i` already addresses a run boundary.
            return range.lowerBound
        }
        precondition(range.lowerBound > bounds.lowerBound, "Can't advance below start index")
        let prev2 = guts.utf8Index(before: range.lowerBound)
        let (_, range2) = guts.run(at: prev2, clampedBy: bounds)
        assert(range2.upperBound == range.lowerBound)
        return range2.lowerBound
    }

    func index(_ i: AttributedString.Index, offsetByRuns distance: Int) -> AttributedString.Index {
        let runs = self.runs
        let bounds = self._bounds
        precondition(
            i >= bounds.lowerBound && i <= bounds.upperBound,
            "Invalid attributed string index")
        let runIndex = runs.indexOfRun(at: i)
        let runIndex2 = runIndex.advanced(by: distance)
        precondition(runIndex2.rangeIndex <= runs.count, "Attributed string index out of bounds")
        guard runIndex2.rangeIndex < runs.count else { return self.endIndex }
        return runs[runIndex2].range.lowerBound
    }
}

#if FOUNDATION_FRAMEWORK

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol {
    public func range<T: StringProtocol>(of stringToFind: T, options: String.CompareOptions = [], locale: Locale? = nil) -> Range<AttributedString.Index>? {
        // Since we have secret access to the String property, go ahead and use the full implementation given by Foundation rather than the limited reimplementation we needed for CharacterView.
        // FIXME: There is no longer a `String` property. This is going to be terribly slow.
        let bounds = self._stringBounds
        let string = String(_from: __guts.string, in: bounds)
        guard let range = string.range(of: stringToFind, options: options, locale: locale) else {
            return nil
        }
        // Restore original index range.
        let utf8Start = bounds.lowerBound._utf8Offset + range.lowerBound._utf8Offset
        let utf8End = bounds.lowerBound._utf8Offset + range.upperBound._utf8Offset
        let start = AttributedString.Index(_BString.Index(_utf8Offset: utf8Start))
        let end = AttributedString.Index(_BString.Index(_utf8Offset: utf8End))
        return start ..< end
    }
}

#endif // FOUNDATION_FRAMEWORK
