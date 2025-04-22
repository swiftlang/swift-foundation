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

#if FOUNDATION_FRAMEWORK
@_spi(Unstable) internal import CollectionsInternal
#elseif canImport(_RopeModule)
internal import _RopeModule
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

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
    : AttributedStringAttributeMutation, Hashable, CustomStringConvertible, Sendable
{
    var startIndex : AttributedString.Index { get }
    var endIndex : AttributedString.Index { get }

    var runs : AttributedString.Runs { get }
    var characters : AttributedString.CharacterView { get }
    var unicodeScalars : AttributedString.UnicodeScalarView { get }
    
    @available(FoundationPreview 6.2, *)
    var utf8 : AttributedString.UTF8View { get }
    
    @available(FoundationPreview 6.2, *)
    var utf16 : AttributedString.UTF16View { get }

    @preconcurrency subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? where K.Value : Sendable { get set }
    @preconcurrency subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? where K.Value : Sendable { get set }
    subscript<S: AttributeScope>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> { get set }

    subscript<R: RangeExpression>(bounds: R) -> AttributedSubstring where R.Bound == AttributedString.Index { get }
}


@available(FoundationPreview 6.2, *)
extension AttributedStringProtocol {
    var utf8 : AttributedString.UTF8View {
        AttributedString.UTF8View(__guts, in: Range(uncheckedBounds: (startIndex._value, endIndex._value)))
    }
    
    var utf16 : AttributedString.UTF16View {
        AttributedString.UTF16View(__guts, in: Range(uncheckedBounds: (startIndex._value, endIndex._value)))
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol {
    public func settingAttributes(_ attributes: AttributeContainer) -> AttributedString {
        var new = AttributedString(self)
        new.setAttributes(attributes)
        return new
    }

    public func mergingAttributes(
        _ attributes: AttributeContainer,
        mergePolicy:  AttributedString.AttributeMergePolicy = .keepNew
    ) -> AttributedString {
        var new = AttributedString(self)
        new.mergeAttributes(attributes, mergePolicy:  mergePolicy)
        return new
    }

    public func replacingAttributes(
        _ attributes: AttributeContainer, with others: AttributeContainer
    ) -> AttributedString {
        var new = AttributedString(self)
        new.replaceAttributes(attributes, with: others)
        return new
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol {
    internal var __guts: AttributedString.Guts {
        if let s = _specializingCast(self, to: AttributedString.self) {
            return s._guts
        } else if let s = _specializingCast(self, to: AttributedSubstring.self) {
            return s._guts
        } else {
            return self.characters._guts
        }
    }
    
    internal var _baseString: BigString {
        __guts.string
    }

    internal var _bounds: Range<AttributedString.Index> {
        Range(uncheckedBounds: (startIndex, endIndex))
    }

    internal var _stringBounds: Range<BigString.Index> {
        Range(uncheckedBounds: (startIndex._value, endIndex._value))
    }

    internal var _characters: BigSubstring {
        _baseString[_stringBounds]
    }
}

extension AttributedString {
    internal var _baseString: BigString {
        _guts.string
    }
    
    internal var _bounds: Range<AttributedString.Index> {
        Range(uncheckedBounds: (startIndex, endIndex))
    }

    internal var _stringBounds: Range<BigString.Index> {
        Range(uncheckedBounds: (_guts.string.startIndex, _guts.string.endIndex))
    }
}

extension AttributedSubstring {
    internal var _baseString: BigString {
        _guts.string
    }
    
    internal var _bounds: Range<AttributedString.Index> {
        let lower = AttributedString.Index(_range.lowerBound, version: _guts.version)
        let upper = AttributedString.Index(_range.upperBound, version: _guts.version)
        return Range(uncheckedBounds: (lower, upper))
    }

    internal var _stringBounds: Range<BigString.Index> {
        _range
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol { // CustomStringConvertible
    public var description: String {
        __guts.description(in: _stringBounds)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol { // Equatable, Hashable
    @_specialize(where Self == AttributedString, RHS == AttributedString)
    @_specialize(where Self == AttributedString, RHS == AttributedSubstring)
    @_specialize(where Self == AttributedSubstring, RHS == AttributedString)
    @_specialize(where Self == AttributedSubstring, RHS == AttributedSubstring)
    public static func == <RHS: AttributedStringProtocol>(lhs: Self, rhs: RHS) -> Bool {
        AttributedString.Guts.characterwiseIsEqual(
            lhs.__guts, in: lhs._stringBounds,
            to: rhs.__guts, in: rhs._stringBounds)
    }

    public func hash(into hasher: inout Hasher) {
        __guts.characterwiseHash(in: _stringBounds, into: &hasher)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol {
    public func index(afterCharacter i: AttributedString.Index) -> AttributedString.Index {
        self.characters.index(after: i)
    }
    public func index(beforeCharacter i: AttributedString.Index) -> AttributedString.Index {
        self.characters.index(before: i)
    }
    public func index(_ i: AttributedString.Index, offsetByCharacters distance: Int) -> AttributedString.Index {
        self.characters.index(i, offsetBy: distance)
    }

    public func index(afterUnicodeScalar i: AttributedString.Index) -> AttributedString.Index {
        self.unicodeScalars.index(after: i)
    }
    public func index(beforeUnicodeScalar i: AttributedString.Index) -> AttributedString.Index {
        self.unicodeScalars.index(before: i)
    }
    public func index(_ i: AttributedString.Index, offsetByUnicodeScalars distance: Int) -> AttributedString.Index {
        self.unicodeScalars.index(i, offsetBy: distance)
    }

    public func index(afterRun i: AttributedString.Index) -> AttributedString.Index {
        // Expected semantics: Result is the end of the run that contains `i`.
        let guts = self.__guts
        let bounds = self._stringBounds
        precondition(i._value >= bounds.lowerBound, "Invalid attributed string index")
        precondition(i._value < bounds.upperBound, "Can't advance beyond end index")
        let next = guts.index(afterRun: i._value)
        assert(next > i._value)
        return AttributedString.Index(Swift.min(next, bounds.upperBound), version: guts.version)
    }

    public func index(beforeRun i: AttributedString.Index) -> AttributedString.Index {
        // Expected semantics: result is the start of the run preceding the one that contains `i`.
        // (I.e., `i` needs to get implicitly rounded down to the nearest run boundary before we
        // step back.)
        let guts = self.__guts
        let bounds = self._stringBounds
        precondition(i._value > bounds.lowerBound, "Can't advance below start index")
        precondition(i._value <= bounds.upperBound, "Invalid attributed string index")
        let prev = guts.index(beforeRun: i._value)
        assert(prev < i._value)
        return AttributedString.Index(Swift.max(prev, bounds.lowerBound), version: guts.version)
    }

    public func index(_ i: AttributedString.Index, offsetByRuns distance: Int) -> AttributedString.Index {
        let guts = self.__guts
        let bounds = self._stringBounds
        precondition(
            i._value >= bounds.lowerBound && i._value <= bounds.upperBound,
            "Invalid attributed string index")
        let startRun = guts.runs.index(atUTF8Offset: i._value.utf8Offset).index
        let run = guts.runs.index(startRun, offsetBy: distance)
        let length = (run == guts.runs.endIndex ? 0 : guts.runs[run].length)

        precondition(
            bounds.lowerBound.utf8Offset <= run.utf8Offset + length,
            "Attributed string index out of bounds")
        if bounds.upperBound.utf8Offset <= run.utf8Offset {
            let end = guts.runs.index(atUTF8Offset: bounds.upperBound.utf8Offset)
            let endRunOffset = end.index.offset + (end.remainingUTF8 == 0 ? 0 : 1)
            precondition(run.offset <= endRunOffset, "Attributed string index out of bounds")
        }

        let result = guts.string.utf8.index(i._value, offsetBy: run.utf8Offset - i._value.utf8Offset)
        let clamped = Swift.min(Swift.max(result, bounds.lowerBound), bounds.upperBound)
        return AttributedString.Index(clamped, version: guts.version)
    }

    internal func _utf8Index(at utf8Offset: Int) -> AttributedString.Index {
        let startOffset = self.startIndex._value.utf8Offset
        return AttributedString.Index(self.__guts.utf8Index(at: startOffset + utf8Offset), version: self.__guts.version)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol {
    internal func _range<T: StringProtocol>(of stringToFind: T, options: String.CompareOptions = []) -> Range<AttributedString.Index>? {

        // TODO: Implement this on BigString to avoid O(n) iteration
        let substring = Substring(characters)
        guard let range = try? substring._range(of: Substring(stringToFind), options: options) else {
            return nil
        }

        let startOffset = substring.utf8.distance(from: substring.startIndex, to: range.lowerBound) // O(1)
        let endOffset = substring.utf8.distance(from: substring.startIndex, to: range.upperBound) // O(1)

        return self._utf8Index(at: startOffset) ..< self._utf8Index(at: endOffset) // O(log(n))
    }

    public func range<T: StringProtocol>(of stringToFind: T, options: String.CompareOptions = [], locale: Locale? = nil) -> Range<AttributedString.Index>? {
        if locale == nil {
            return _range(of: stringToFind, options: options)
        }
#if FOUNDATION_FRAMEWORK
        // TODO: Implement localized AttributedStringProtocol.range(of:) for FoundationPreview
        // Since we have secret access to the String property, go ahead and use the full implementation given by Foundation rather than the limited reimplementation we needed for CharacterView.
        // FIXME: There is no longer a `String` property. This is going to be terribly slow.
        let bstring = self.__guts.string
        let bounds = self._stringBounds
        let string = String(bstring[bounds])
        guard let range = string.range(of: stringToFind, options: options, locale: locale) else {
            return nil
        }
        // Restore original index range.
        let utf8Start = string.utf8.distance(from: string.startIndex, to: range.lowerBound)
        let utf8End = string.utf8.distance(from: string.startIndex, to: range.upperBound)

        let start = bstring.utf8.index(bounds.lowerBound, offsetBy: utf8Start)
        let end = bstring.utf8.index(bounds.lowerBound, offsetBy: utf8End)

        return AttributedString.Index(start, version: self.__guts.version) ..< AttributedString.Index(end, version: self.__guts.version)
#else
        // TODO: Implement localized AttributedStringProtocol.range(of:) for FoundationPreview
        return _range(of: stringToFind, options: options)
#endif // FOUNDATION_FRAMEWORK
    }
}

