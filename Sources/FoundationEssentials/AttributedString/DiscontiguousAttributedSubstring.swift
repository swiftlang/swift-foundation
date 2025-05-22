//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
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

/// A discontiguous portion of an attributed string.
@dynamicMemberLookup
@available(FoundationPreview 6.2, *)
public struct DiscontiguousAttributedSubstring: Sendable {
    /// The guts of the base attributed string.
    internal var _guts: AttributedString.Guts
    
    internal var _indices: RangeSet<BigString.Index>
    
    internal var _identity: Int = 0
    
    internal init(_ guts: AttributedString.Guts, in indices: RangeSet<BigString.Index>) {
        self._guts = guts
        // Forcibly resolve bounds and round them down to nearest scalar boundary.
        var ranges = Array(indices.ranges)
        for i in ranges.indices {
            let slice = _guts.string.unicodeScalars[ranges[i]]
            ranges[i] = Range(uncheckedBounds: (slice.startIndex, slice.endIndex))
        }
        self._indices = RangeSet(ranges)
    }
}

@available(FoundationPreview 6.2, *)
extension DiscontiguousAttributedSubstring {
    /// The underlying attributed string that the discontiguous attributed substring derives from.
    public var base: AttributedString {
        return AttributedString(_guts)
    }
}

@available(FoundationPreview 6.2, *)
extension DiscontiguousAttributedSubstring : CustomStringConvertible {
    public var description: String {
        _guts.description(in: _indices)
    }
}

@available(FoundationPreview 6.2, *)
extension DiscontiguousAttributedSubstring : Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        AttributedString.Guts._characterwiseIsEqual(lhs.runs, to: rhs.runs)
    }
}

@available(FoundationPreview 6.2, *)
extension DiscontiguousAttributedSubstring : Hashable {
    public func hash(into hasher: inout Hasher) {
        for range in _indices.ranges {
            _guts.characterwiseHash(in: range, into: &hasher)
        }
    }
}

@available(FoundationPreview 6.2, *)
extension DiscontiguousAttributedSubstring : AttributedStringAttributeMutation {
    internal mutating func ensureUniqueReference() {
        // Note: slices should never discard the data outside their bounds, so we must make a
        // copy of the entire base string here.
        //
        // (Discarding out-of-range data would change index values, interfere with "in-place"
        // mutations of slices via the subscript accessors, and it would confuse the semantics of
        // the `base` property.)
        if !isKnownUniquelyReferenced(&_guts) {
            _guts = _guts.copy()
        }
    }
    
    public mutating func setAttributes(_ attributes: AttributeContainer) {
        ensureUniqueReference()
        for range in _indices.ranges {
            _guts.setAttributes(attributes.storage, in: range)
        }
    }
    
    public mutating func mergeAttributes(_ attributes: AttributeContainer, mergePolicy:  AttributedString.AttributeMergePolicy = .keepNew) {
        ensureUniqueReference()
        for range in _indices.ranges {
            _guts.mergeAttributes(attributes, in: range, mergePolicy: mergePolicy)
        }
    }
    
    public mutating func replaceAttributes(_ attributes: AttributeContainer, with others: AttributeContainer) {
        guard attributes != others else {
            return
        }
        ensureUniqueReference()
        let hasConstrainedAttributes = attributes.storage.hasConstrainedAttributes || others.storage.hasConstrainedAttributes
        var fixupRanges = [Range<Int>]()
        for range in _indices.ranges {
            _guts.runs(in: range._utf8OffsetRange).updateEach(
                when: { $0.matches(attributes.storage) },
                with: { runAttributes, utf8Range in
                    for key in attributes.storage.keys {
                        runAttributes[key] = nil
                    }
                    runAttributes.mergeIn(others)
                    if hasConstrainedAttributes {
                        fixupRanges.append(utf8Range)
                    }
                })
        }
        for range in fixupRanges {
            // FIXME: Collect boundary constraints.
            _guts.enforceAttributeConstraintsAfterMutation(in: range, type: .attributes)
        }
    }
    
    /// Returns a discontiguous substring of this discontiguous attributed string using a range to indicate the discontiguous substring bounds.
    /// - Parameter bounds: A range that indicates the bounds of the discontiguous substring to return.
    public subscript(bounds: some RangeExpression<AttributedString.Index>) -> DiscontiguousAttributedSubstring {
        let characterView = AttributedString.CharacterView(_guts)
        let bounds = bounds.relative(to: characterView)._bstringRange
        if let first = _indices.ranges.first, let last = _indices.ranges.last, first.lowerBound <= bounds.lowerBound, last.upperBound >= bounds.upperBound {
            return DiscontiguousAttributedSubstring(_guts, in: _indices.intersection(RangeSet(bounds)))
        }
        preconditionFailure("Attributed string index range \(bounds) is out of bounds")
    }
    
    /// Returns a discontiguous substring of this discontiguous attributed string using a set of ranges to indicate the discontiguous substring bounds.
    /// - Parameter bounds: A set of ranges that indicate the bounds of the discontiguous substring to return.
    public subscript(bounds: RangeSet<AttributedString.Index>) -> DiscontiguousAttributedSubstring {
        let bounds = bounds._bstringIndices
        if bounds.ranges.isEmpty {
            return DiscontiguousAttributedSubstring(_guts, in: bounds)
        } else if let first = _indices.ranges.first,
                  let last = _indices.ranges.last,
                  let firstBounds = bounds.ranges.first,
                  let lastBounds = bounds.ranges.last,
                  first.lowerBound <= firstBounds.lowerBound,
                  last.upperBound >= lastBounds.upperBound {
            return DiscontiguousAttributedSubstring(_guts, in: _indices.intersection(bounds))
        }
        preconditionFailure("Attributed string index range \(bounds) is out of bounds")
    }
}

@available(FoundationPreview 6.2, *)
extension DiscontiguousAttributedSubstring {
    /// The characters of the discontiguous attributed string, as a view into the underlying string.
    public var characters: DiscontiguousSlice<AttributedString.CharacterView> {
        AttributedString.CharacterView(_guts)[_indices._attributedStringIndices(version: _guts.version)]
    }
    
    /// The Unicode scalars of the discontiguous attributed string, as a view into the underlying string.
    public var unicodeScalars: DiscontiguousSlice<AttributedString.UnicodeScalarView> {
        AttributedString.UnicodeScalarView(_guts)[_indices._attributedStringIndices(version: _guts.version)]
    }
    
    /// The attributed runs of the discontiguous attributed string, as a view into the underlying string.
    public var runs: AttributedString.Runs {
        AttributedString.Runs(_guts, in: _indices)
    }
}

@available(FoundationPreview 6.2, *)
extension DiscontiguousAttributedSubstring {
    /// Returns an attribute value that corresponds to an attributed string key.
    ///
    /// This subscript returns `nil` unless the specified attribute exists, and is present and identical for the entire discontiguous attributed substring. To find portions of an attributed string with consistent attributes, use the `runs` property.
    /// Getting or setting stringwide attributes with this subscript has `O(n)` behavior in the worst case, where n is the number of runs.
    public subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? where K.Value : Sendable {
        get {
            var result: AttributedString._AttributeValue?
            for range in _indices.ranges {
                guard let value = _guts.getUniformValue(in: range, key: K.self) else {
                    return nil
                }
                if let previous = result, previous != value {
                    return nil
                }
                result = value
            }
            return result?.rawValue(as: K.self)
        }
        set {
            ensureUniqueReference()
            if let v = newValue {
                for range in _indices.ranges {
                    _guts.setAttributeValue(v, forKey: K.self, in: range)
                }
            } else {
                for range in _indices.ranges {
                    _guts.removeAttributeValue(forKey: K.self, in: range)
                }
            }
        }
    }
    
    /// Returns an attribute value that a key path indicates.
    ///
    /// This subscript returns `nil` unless the specified attribute exists, and is present and identical for the entire discontiguous attributed substring. To find portions of an attributed string with consistent attributes, use the `runs` property.
    /// Getting or setting stringwide attributes with this subscript has `O(n)` behavior in the worst case, where n is the number of runs.
    @inlinable // Trivial implementation, allows callers to optimize away the keypath allocation
    public subscript<K: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>
    ) -> K.Value? where K.Value : Sendable {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }
    
    /// Returns a scoped attribute container that a key path indicates.
    public subscript<S: AttributeScope>(
        dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>
    ) -> ScopedAttributeContainer<S> {
        get {
            var attributes = AttributedString._AttributeStorage()
            var first = true
            for range in _indices.ranges {
                let value = _guts.getUniformValues(in: range)
                guard !first else {
                    attributes = value
                    first = false
                    continue
                }
                attributes = attributes.filterWithoutInvalidatingDependents {
                    guard let value = value[$0.key] else { return false }
                    return value == $0.value
                }
                if attributes.isEmpty {
                    break
                }
            }
            return ScopedAttributeContainer(attributes)
            
        }
        _modify {
            ensureUniqueReference()
            var container = ScopedAttributeContainer<S>()
            defer {
                if let removedKey = container.removedKey {
                    for range in _indices.ranges {
                        _guts.removeAttributeValue(forKey: removedKey, in: range)
                    }
                } else {
                    for range in _indices.ranges {
                        _guts.mergeAttributes(AttributeContainer(container.storage), in: range)
                    }
                }
            }
            yield &container
        }
    }
}

@available(FoundationPreview 6.2, *)
extension AttributedString {
    /// Creates an attributed string from a discontiguous attributed substring.
    /// - Parameter substring: A discontiguous attributed substring to create the new attributed string from.
    public init(_ substring: DiscontiguousAttributedSubstring) {
        let created = AttributedString.Guts()
        for range in substring._indices.ranges {
            created.replaceSubrange(
                created.string.endIndex ..< created.string.endIndex,
                with: AttributedSubstring(substring._guts, in: range)
            )
        }
        self.init(created)
    }
}

@available(FoundationPreview 6.2, *)
extension AttributedStringProtocol {
    /// Returns a discontiguous substring of this attributed string using a set of ranges to indicate the discontiguous substring bounds.
    /// - Parameter indices:  A set of ranges that indicate the bounds of the discontiguous substring to return.
    public subscript(_ indices: RangeSet<AttributedString.Index>) -> DiscontiguousAttributedSubstring {
        let range = Range(uncheckedBounds: (startIndex, endIndex))._bstringRange
        let newIndices = indices._bstringIndices.intersection(RangeSet(range))
        return DiscontiguousAttributedSubstring(__guts, in: newIndices)
    }
}

@available(FoundationPreview 6.2, *)
extension AttributedString {
    /// Returns a discontiguous substring of this discontiguous attributed string using a set of ranges to indicate the discontiguous substring bounds.
    /// - Parameter indices: A set of ranges that indicate the bounds of the discontiguous substring to return.
    public subscript(_ indices: RangeSet<AttributedString.Index>) -> DiscontiguousAttributedSubstring {
        get {
            let range = Range(uncheckedBounds: (startIndex, endIndex))._bstringRange
            let newIndices = indices._bstringIndices.intersection(RangeSet(range))
            return DiscontiguousAttributedSubstring(_guts, in: newIndices)
        }
        _modify {
            ensureUniqueReference()
            let range = Range(uncheckedBounds: (startIndex, endIndex))._bstringRange
            let newIndices = indices._bstringIndices.intersection(RangeSet(range))
            var view = DiscontiguousAttributedSubstring(_guts, in: newIndices)
            let ident = Self._nextModifyIdentity
            view._identity = ident
            _guts = Guts() // Preserve uniqueness of view
            defer {
                if view._identity != ident {
                    fatalError("Mutating a DiscontiguousAttributedSubstring by replacing it with another from a different source is unsupported")
                }
                _guts = view._guts
            }
            yield &view
        }
        set {
            // The behavior of this function can be semantically confusing - we are required to have a setter in order to allow mutations such as attrStr[rangeSet].foregroundColor = .green, but wholesale replacements like attrStr[rangeSet] = otherAttrStr[otherRangeSet] then become possible
            // The general principle taken here is that the behavior of this function should be defined such that the _modify behavior is equivalent to a get followed by a mutation and then a set
            // Therefore, this function must interpolate the sliced contents of the newValue into the discontiguous chunks referenced by indices. This makes the behavior unclear when newValue has more values than what fit into indices, and therefore this causes a precondition failure.
            ensureUniqueReference()
            let other = AttributedString(newValue)
            var idxInOther = other.unicodeScalars.endIndex
            for range in indices.ranges.lazy.reversed() {
                let unicodeScalarLength = _guts.string.unicodeScalars.distance(from: range.lowerBound._value, to: range.upperBound._value)
                guard let startIdx = other.unicodeScalars.index(idxInOther, offsetBy: -unicodeScalarLength, limitedBy: other.unicodeScalars.startIndex) else {
                    preconditionFailure("Cannot set a DiscontiguousAttributedSubstring on a discontiguous slice of a different size")
                }
                let content = other[startIdx ..< idxInOther]
                _guts.replaceSubrange(range._bstringRange, with: content)
                idxInOther = startIdx
            }
            precondition(idxInOther == other.unicodeScalars.startIndex, "Cannot set a DiscontiguousAttributedSubstring on a discontiguous slice of a different size")
        }
    }
    
    /// Removes the elements at the given indices.
    /// - Parameter subranges: The indices of the elements to remove.
    public mutating func removeSubranges(_ subranges: RangeSet<Index>) {
        ensureUniqueReference()
        for range in subranges.ranges.lazy.reversed() {
            _guts.replaceSubrange(range._bstringRange, with: AttributedString())
        }
    }
}
