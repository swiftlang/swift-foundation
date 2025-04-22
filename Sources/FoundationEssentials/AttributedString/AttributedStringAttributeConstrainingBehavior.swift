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
extension AttributedString._AttributeStorage {
    var hasConstrainedAttributes: Bool {
        self.contents.values.contains { value in
            value.hasConstrainedAttributes
        }
    }

    var containsParagraphConstraint: Bool {
        self.contents.values.contains { $0.runBoundaries == .paragraph }
    }

    var containsScalarConstraint: Bool {
        self.contents.values.contains { value in
            value.runBoundaries?._isScalarConstrained ?? false
        }
    }

    var constraintsInvolved: [AttributedString.AttributeRunBoundaries] {
        return self.contents.values.compactMap(\.runBoundaries)
    }
    
    fileprivate mutating func matchStyle(of other: Self, for constraint: AttributedString.AttributeRunBoundaries) -> Bool {
        var modified = false
        for key in self.keys {
            if self[key]?.runBoundaries == constraint && other[key] == nil {
                self[key] = nil
                modified = true
            }
        }
        for key in other.keys where other[key]?.runBoundaries == constraint {
            self[key] = other[key]
            modified = true
        }
        return modified
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString._AttributeValue {
    var hasConstrainedAttributes: Bool {
        runBoundaries != nil
    }
    
    var constraintsInvolved: [AttributedString.AttributeRunBoundaries] {
        guard let constraint = runBoundaries else { return [] }
        return [constraint]
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringKey {
    static var constraintsInvolved: [AttributedString.AttributeRunBoundaries] {
        guard let constraint = Self.runBoundaries else { return [] }
        return [constraint]
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Collection where Element == AttributedString.AttributeRunBoundaries {
    var _containsScalarConstraint: Bool {
        self.contains { $0._isScalarConstrained }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Collection where Element == AttributedString.AttributeRunBoundaries? {
    var _containsScalarConstraint: Bool {
        self.contains { $0?._isScalarConstrained ?? false }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Guts {
    
    // MARK: Index/Range Utilities

    private func nextParagraphBreak(after index: BigString.Index) -> BigString.Index {
        let block = string.utf8._getBlock(for: [.findEnd], in: index ..< index)
        return block.end!
    }

    private func nextParagraphBreak(before index: BigString.Index) -> BigString.Index {
        let block = string.utf8._getBlock(for: [.findStart], in: index ..< index)
        return block.start!
    }

    private func _paragraph(in range: Range<BigString.Index>) -> Range<BigString.Index> {
        let block = string.utf8._getBlock(for: [.findStart, .findEnd], in: range)
        return block.start! ..< block.end!
    }
    
    private func _paragraphExtending(from i: BigString.Index) -> Range<BigString.Index> {
        let block = string.utf8._getBlock(for: [.findEnd], in: i ..< string.index(after: i))
        return i ..< block.end!
    }
    
    // MARK: Attribute Utilities
    
    private func _constrainedAttributes(
        at utf8Offset: Int, with constraint: AttributeRunBoundaries
    ) -> _AttributeStorage {
        let i = runs.index(atUTF8Offset: utf8Offset).index
        return runs[i]
            .attributes
            .filterWithoutInvalidatingDependents { $0.value.runBoundaries == constraint }
    }
    
    private func _characterInvalidatedAttributes(at utf8Offset: Int) -> _AttributeStorage {
        let i = runs.index(atUTF8Offset: utf8Offset).index
        return runs[i]
            .attributes
            .filterWithoutInvalidatingDependents { $0.value.isInvalidatedOnTextChange }
    }
    
    private func _needsParagraphFixing(from startUTF8: Int, to endUTF8: Int) -> Bool {
        let start = runs.index(atUTF8Offset: startUTF8).index
        let end = runs.index(atUTF8Offset: endUTF8).index
        let startAttributes = runs[start].attributes
        let endAttributes = runs[end].attributes

        let startHasConstraints = startAttributes.containsParagraphConstraint
        let endHasConstraints = endAttributes.containsParagraphConstraint
        guard startHasConstraints || endHasConstraints else { return false }
        guard startHasConstraints == endHasConstraints else { return true }

        // Compare subsets without allocating anything.
        for (key, value) in startAttributes.contents {
            guard value.runBoundaries == .paragraph else { continue }
            guard endAttributes.contents[key] == value else { return true }
        }
        for (key, value) in endAttributes.contents {
            guard value.runBoundaries == .paragraph else { continue }
            guard startAttributes.contents[key] == value else { return true }
        }
        return false
    }
    
    private func _applyStyle(
        type: AttributedString.AttributeRunBoundaries,
        from utf8Offset: Int,
        to utf8Range: Range<Int>
    ) {
        let style = _constrainedAttributes(at: utf8Offset, with: type)
        runs(in: utf8Range).updateEach { attributes, _, modified in
            modified = attributes.matchStyle(of: style, for: type)
        }
    }
    
    // MARK: Constraining Behavior
    
    enum _MutationType {
        case attributes
        case attributesAndCharacters
    }
    
    /// Removes full runs of any attributes that have declared an
    /// `AttributeInvalidationCondition.textChanged` invalidation condition from the mutation range.
    ///
    /// Note: this should be called _before_ the mutation takes place.
    ///
    /// - Parameter range: The UTF-8 range in which the mutation will take place.
    /// - Returns: The UTF-8 range that was modified during this invalidation.
    ///     (If no modification took place, then the result is `range`.)
    func enforceAttributeConstraintsBeforeMutation(to utf8Range: Range<Int>) -> Range<Int> {
        var utf8Start = utf8Range.lowerBound
        var utf8End = utf8Range.upperBound

        // Eagerly record the attributes at the end of the mutation as invalidating attributes at the start may change attributes at the end (if the mutation is within a run)
        let originalEndingAttributes = if utf8End > 0 {
            _characterInvalidatedAttributes(at: utf8End - 1)
        } else {
            _AttributeStorage()
        }

        // Invalidate attributes preceding the range.
        if utf8Start < string.utf8.count {
            let attributes = _characterInvalidatedAttributes(at: utf8Start)
            var remainingKeys = Set(attributes.keys)
            let runs = runs(in: 0 ..< utf8Start)
            var i = runs.endIndex
            while i > runs.startIndex, !remainingKeys.isEmpty {
                runs.formIndex(before: &i)
                runs.update(at: &i) { runAttributes, utf8Range, mutated in
                    mutated = false
                    remainingKeys = remainingKeys.filter { key in
                        if runAttributes[key] != attributes[key] {
                            return false
                        }
                        mutated = true
                        runAttributes[key] = nil
                        utf8Start = utf8Range.lowerBound
                        return true
                    }
                }
            }
        }

        // Invalidate attributes following the range.
        if utf8End > 0 {
            let attributes = originalEndingAttributes
            var remainingKeys = Set(attributes.keys)
            let runs = runs(in: utf8End ..< string.utf8.count)
            var i = runs.startIndex
            while i < runs.endIndex, !remainingKeys.isEmpty {
                defer { runs.formIndex(after: &i) }
                runs.update(at: &i) { runAttributes, utf8Range, mutated in
                    mutated = false
                    remainingKeys = remainingKeys.filter { key in
                        if runAttributes[key] != attributes[key] {
                            return false
                        }
                        mutated = true
                        runAttributes[key] = nil
                        utf8End = utf8Range.upperBound
                        return true
                    }
                }
            }

        }

        return utf8Start ..< utf8End
    }
    
    /// Adjusts any attributes constrained to specified run boundaries based on a mutation that has taken place. Note: this should be called _after_ the mutation takes place
    /// - Parameters:
    ///   - range: The UTF-8 range in which the mutation has taken place (this range should be based on the resulting string)
    ///   - type: The type of mutation that was applied. Either attributes-only (eg. `attrStr.foregroundColor = .blue`) or a combination of attributes and characters (eg. `attrStr.characters[idx] = "A"` or `attrStr.replaceSubrange(range, with: otherStr)`).
    ///   - constraintsInvolved: A list of run boundary constraints for attributes involved in the mutation. This is used as a performance shortcut when very few attributes are mutated, and `nil` can be used when the information is not quickly accessible from the caller.
    func enforceAttributeConstraintsAfterMutation(
        in utf8Range: Range<Int>,
        type: _MutationType,
        constraintsInvolved: [AttributedString.AttributeRunBoundaries]? = nil
    ) {
        guard !runs.isEmpty else {
            // If we're an empty string, no fixups are required
            return
        }

        if type == .attributes, utf8Range.isEmpty {
            // For attribute-only mutations, we expand the constrained styles out from the mutated
            // range to the paragraph boundaries. If only attributes were modified and the range is
            // empty, then no true mutation occurred.
            return
        }

        let strRange = utf8IndexRange(from: utf8Range)

        // Character-based constraints
        if type == .attributesAndCharacters || constraintsInvolved?._containsScalarConstraint ?? true {
            fixScalarConstrainedAttributes(in: strRange)
        }

        // Paragraph-based constraints
        if type == .attributes && constraintsInvolved?.contains(.paragraph) ?? true {
            // Attributes are always applied consistently, so we only need to expand outwards and not fix the range of the mutation itself
            let paragraphStyle = _constrainedAttributes(at: utf8Range.lowerBound, with: .paragraph)
            let paragraphRange = _paragraph(in: strRange)._utf8OffsetRange

            // Note: This assumes that mutated attributes are consistent throughout
            // the mutated range. This holds for all current callers -- the mutated attributes tend
            // to form a single run.
            self.runs(
                in: paragraphRange.lowerBound ..< utf8Range.lowerBound
            ).updateEach { attributes, _, modified in
                modified = attributes.matchStyle(of: paragraphStyle, for: .paragraph)
            }
            self.runs(
                in: utf8Range.upperBound ..< paragraphRange.upperBound
            ).updateEach { attributes, _, modified in
                modified = attributes.matchStyle(of: paragraphStyle, for: .paragraph)
            }
        } else if type == .attributesAndCharacters {
            // If any character mutations took place, we apply the constrained styles from the start of each paragraph to the remainder of the paragraph
            // The mutation range itself is already fixed-up, so we just need to correct the starting and ending paragraphs
            
            var startParagraph: Range<Int>? = nil
            var endParagraph: Range<Int>? = nil

            // TODO: Performance review
            if strRange.isEmpty {
                // Since this was a removal, paragraphs can only change if the removal was in the middle of the string
                if
                    strRange.lowerBound > string.startIndex,
                    strRange.lowerBound < string.endIndex,
                    _needsParagraphFixing(from: utf8Range.lowerBound - 1, to: utf8Range.lowerBound)
                {
                    let r = _paragraphExtending(from: string.index(before: strRange.lowerBound))
                    startParagraph = r._utf8OffsetRange
                }
            } else {
                // Grab the paragraph that contains the character before the mutation (if we're not at the beginning)
                if
                    strRange.lowerBound > string.startIndex,
                    _needsParagraphFixing(from: utf8Range.lowerBound - 1, to: utf8Range.lowerBound)
                {
                    let r = _paragraphExtending(from: string.index(before: strRange.lowerBound))
                    startParagraph = r._utf8OffsetRange
                }
                // Grab the paragraph that contains the character at the end of the mutation (if we're not at the end)
                if
                    strRange.upperBound < string.endIndex,
                    (startParagraph?.upperBound ?? 0) < utf8Range.upperBound,
                    _needsParagraphFixing(from: utf8Range.upperBound - 1, to: utf8Range.upperBound)
                {
                    let r = _paragraphExtending(from: string.index(before: strRange.upperBound))
                    endParagraph = r._utf8OffsetRange
                }
            }
            
            // If the start paragraph extends into the mutation, fixup the range within the mutation
            if let startParagraph, startParagraph.upperBound > utf8Range.lowerBound {
                _applyStyle(
                    type: .paragraph,
                    from: startParagraph.lowerBound,
                    to: utf8Range.lowerBound ..< startParagraph.upperBound)
            }
            // If the end paragraph extends beyond the mutation, fixup the range outside the mutation
            if let endParagraph, endParagraph.upperBound > utf8Range.upperBound {
                _applyStyle(
                    type: .paragraph,
                    from: endParagraph.lowerBound,
                    to: utf8Range.upperBound ..< endParagraph.upperBound)
            }
        }
    }

    func fixScalarConstrainedAttributes(in range: Range<BigString.Index>) {
        // Attribute keys with associated range sets that we'll need to remove.
        var invalidAttributes: [String: [Range<Int>]] = [:]

        func invalidate(_ key: String, from start: BigString.Index, to end: BigString.Index) {
            let range = start.utf8Offset ..< end.utf8Offset
            invalidAttributes[key, default: []]._extend(with: range)
        }

        let lowerBound = string.unicodeScalars.index(roundingDown: range.lowerBound)
        let upperBound = string.unicodeScalars.index(roundingUp: range.upperBound)

        // Iterate over all runs, gathering keys to remove in exactly one pass.
        var runStart = lowerBound
        for run in runs(in: lowerBound.utf8Offset ..< upperBound.utf8Offset) {
            let runEnd = string.utf8.index(runStart, offsetBy: run.length)
            defer { runStart = runEnd }

            guard run.attributes.containsScalarConstraint else { continue }

            var i = runStart
            while i < runEnd {
                let scalar = string.unicodeScalars[i]
                let next = string.unicodeScalars.index(after: i)
                for (key, value) in run.attributes.contents {
                    if let s = value.runBoundaries?._constrainedScalar, s != scalar {
                        invalidate(key, from: i, to: next)
                    }
                }
                i = next
            }
        }

        for (key, utf8Ranges) in invalidAttributes {
            for utf8Range in utf8Ranges {
                removeAttributeValue(forKey: key, in: utf8Range, adjustConstrainedAttributes: false)
            }
        }
    }
    
    /// Performs a "full fix-up" of the entire string and fixes all attributes according to their constraints. This requires thorough enumeration of the entire string and should only be used when an `AttributedString` is created through means that bypass the standard constraint adjustments such as conversion from `NSAttributedString` and decoding from an archive.
    func adjustConstrainedAttributesForUntrustedRuns() {
        self.fixScalarConstrainedAttributes(in: string.startIndex ..< string.endIndex)

        var i = string.startIndex
        while i < string.endIndex {
            let j = nextParagraphBreak(after: i)
            let paragraphStyle = self._constrainedAttributes(at: i.utf8Offset, with: .paragraph)
            self.runs(in: i.utf8Offset ..< j.utf8Offset).updateEach { attributes, _, modified in
                modified = attributes.matchStyle(of: paragraphStyle , for: .paragraph)
            }
            i = j
        }
    }
}

extension Array<Range<Int>> {
    /// If `self` is a sorted array of ranges, then this implements a limited version of RangeSet.
    ///
    ///     var array = [0 ..< 4, 10 ..< 15]
    ///     array._extend(with: 15 ..< 18)
    ///     // array is now [0 ..< 4, 10 ..< 18]
    ///     array._extend(with: 20 ..< 30)
    ///     // array is now [0 ..< 4, 10 ..< 18, 20 ..< 30]
    internal mutating func _extend(with range: Range<Int>) {
        let i = self.count - 1
        if i >= 0, self[i].upperBound == range.lowerBound {
            self[i] = self[i].lowerBound ..< range.upperBound
        } else {
            self.append(range)
        }
    }
}
