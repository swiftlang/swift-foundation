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

    var containsCharacterConstraint: Bool {
        self.contents.values.contains { value in
            value.runBoundaries?._isCharacter ?? false
        }
    }

    var constraintsInvolved: [AttributedString.AttributeRunBoundaries] {
        return self.contents.values.compactMap(\.runBoundaries)
    }
    
    fileprivate mutating func matchStyle(of other: Self, for constraint: AttributedString.AttributeRunBoundaries) {
        for key in self.keys {
            if self[key]?.runBoundaries == constraint && other[key] == nil {
                self[key] = nil
            }
        }
        for key in other.keys where other[key]?.runBoundaries == constraint {
            self[key] = other[key]
        }
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
    var _containsCharacterConstraint : Bool {
        self.contains { $0._isCharacter }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Guts {
    
    // MARK: Index/Range Utilities

    private func nextParagraphBreak(after index: Index) -> Index {
        let block = string.utf8._getBlock(for: [.findEnd], in: index._value ..< index._value)
        return Index(block.end!)
    }

    private func nextParagraphBreak(before index: Index) -> Index {
        let block = string.utf8._getBlock(for: [.findStart], in: index._value ..< index._value)
        return Index(block.start!)
    }

    private func _paragraph(in range: Range<Index>) -> Range<Index> {
        let block = string.utf8._getBlock(for: [.findStart, .findEnd], in: range._bstringRange)
        return Index(block.start!) ..< Index(block.end!)
    }
    
    private func _paragraphExtending(from idx: Index) -> Range<Index> {
        let i = idx._value
        let block = string.utf8._getBlock(
            for: [.findEnd], in: i ..< string.characterIndex(after: i))
        return idx ..< Index(block.end!)
    }
    
    // MARK: Attribute Utilities
    
    private func _constrainedAttributes(
        at location: Int, with constraint: AttributeRunBoundaries
    ) -> _AttributeStorage {
        // Don't update the cache, because getting constrained attributes might look backwards very far and we'll just have to iterate the cache back to where we currently are
        run(containing: location, updateCache: false)
            .attributes
            .filter { $0.value.runBoundaries == constraint }
    }
    
    private func _characterInvalidatedAttributes(at location: Int) -> _AttributeStorage {
        run(containing: location)
            .attributes
            .filter { $0.value.isInvalidatedOnTextChange }
    }
    
    private func _needsParagraphFixing(from start: Int, to end: Int) -> Bool {
        let startAttributes = run(containing: start, updateCache: false)
        let endAttributes = run(containing: end, updateCache: false)

        let startHasConstraints = startAttributes.attributes.containsParagraphConstraint
        let endHasConstraints = endAttributes.attributes.containsParagraphConstraint
        guard startHasConstraints || endHasConstraints else { return false }
        guard startHasConstraints == endHasConstraints else { return true }

        // Compare subsets without allocating anything.
        for (key, value) in startAttributes.attributes.contents {
            guard value.runBoundaries == .paragraph else { continue }
            guard endAttributes.attributes.contents[key] == value else { return true }
        }
        for (key, value) in endAttributes.attributes.contents {
            guard value.runBoundaries == .paragraph else { continue }
            guard startAttributes.attributes.contents[key] == value else { return true }
        }
        return false
    }
    
    private func _applyStyle(
        type: AttributedString.AttributeRunBoundaries, from idx: Int, to range: Range<Int>
    ) {
        let style = _constrainedAttributes(at: idx, with: type)
        enumerateRuns(containing: range) { run, _, _, _ in
            run.attributes.matchStyle(of: style, for: type)
        }
    }
    
    private func _removeRangeOfAttributes(
        _ attributes: _AttributeStorage, extendingFrom location: Int, backwards: Bool
    ) -> Int {
        guard !attributes.isEmpty else { return location }
        var currentKeys = Set(attributes.keys)
        var newLocation = location
        enumerateRuns(
            containing: backwards ? 0 ..< location : location ..< Int.max,
            reverse: backwards
        ) { run, location, stop, modificationStatus in
            modificationStatus = .guaranteedNotModified
            
            for key in currentKeys {
                if run.attributes[key] != attributes[key] {
                    currentKeys.remove(key)
                } else {
                    run.attributes[key] = nil
                    modificationStatus = .guaranteedModified
                    newLocation = location
                }
            }
            if currentKeys.isEmpty {
                stop = true
            }
        }
        return newLocation
    }
    
    // MARK: Constraining Behavior
    
    enum _MutationType {
        case attributes
        case attributesAndCharacters
    }
    
    /// Removes full runs of any attributes that have declared a `AttributedString.AttributeInvalidationCondition.textChanged` invalidation condition from the mutation range. Note: this should be called _before_ the mutation takes place
    /// - Parameter range: The UTF-8 range in which the mutation will take place
    /// - Returns: The UTF-8 range that was modified as a result of this invalidation (or `range` if no modification took place)
    func enforceAttributeConstraintsBeforeMutation(to range: Range<Int>) -> Range<Int> {
        guard !range.isEmpty else { return range }

        let startAttributes = _characterInvalidatedAttributes(at: range.lowerBound)
        let lowerBound = _removeRangeOfAttributes(
            startAttributes, extendingFrom: range.lowerBound, backwards: true)

        let endAttributes = _characterInvalidatedAttributes(at: range.upperBound - 1)
        let upperBound = _removeRangeOfAttributes(
            endAttributes, extendingFrom: range.upperBound, backwards: false)

        return lowerBound ..< upperBound
    }
    
    /// Adjusts any attributes constrained to specified run boundaries based on a mutation that has taken place. Note: this should be called _after_ the mutation takes place
    /// - Parameters:
    ///   - range: The UTF-8 range in which the mutation has taken place (this range should be based on the resulting string)
    ///   - type: The type of mutation that was applied. Either attributes-only (eg. `attrStr.foregroundColor = .blue`) or a combination of attributes and characters (eg. `attrStr.characters[idx] = "A"` or `attrStr.replaceSubrange(range, with: otherStr)`).
    ///   - constraintsInvolved: A list of run boundary constraints for attributes involved in the mutation. This is used as a performance shortcut when very few attributes are mutated, and `nil` can be used when the information is not quickly accessible from the caller.
    func enforceAttributeConstraintsAfterMutation(
        in range: Range<Int>,
        type: _MutationType,
        constraintsInvolved: [AttributedString.AttributeRunBoundaries]? = nil
    ) {
        guard !runs.isEmpty else {
            // If we're an empty string, no fixups are required
            return
        }

        if type == .attributes, range.isEmpty {
            // For attribute-only mutations, we expand the constrained styles out from the mutated
            // range to the paragraph boundaries. If only attributes were modified and the range is
            // empty, then no true mutation ocurred.
            return
        }

        let strRange = utf8IndexRange(from: range)

        // Character-based constraints
        if type == .attributesAndCharacters || constraintsInvolved?._containsCharacterConstraint ?? true {
            fixCharacterConstrainedAttributes(in: strRange)
        }

        // Paragraph-based constraints
        if type == .attributes && constraintsInvolved?.contains(.paragraph) ?? true {
            // Attributes are always applied consistently, so we only need to expand outwards and not fix the range of the mutation itself
            let paragraphStyle = _constrainedAttributes(at: range.lowerBound, with: .paragraph)
            let paragraphRange = _paragraph(in: strRange)._utf8OffsetRange
            // FIXME: It looks like this assumes that mutated attributes are consistent throughout
            // FIXME: the mutated range. This expectation should be explicitly documented.
            enumerateRuns(containing: paragraphRange.lowerBound ..< range.lowerBound) { run, _, _, _ in
                run.attributes.matchStyle(of: paragraphStyle, for: .paragraph)
            }
            enumerateRuns(containing: range.upperBound ..< paragraphRange.upperBound) { run, _, _, _ in
                run.attributes.matchStyle(of: paragraphStyle, for: .paragraph)
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
                    strRange.lowerBound > startIndex,
                    strRange.lowerBound < endIndex,
                    _needsParagraphFixing(from: range.lowerBound - 1, to: range.lowerBound)
                {
                    let r = _paragraphExtending(from: characterIndex(before: strRange.lowerBound))
                    startParagraph = r._utf8OffsetRange
                }
            } else {
                // Grab the paragraph that contains the character before the mutation (if we're not at the beginning)
                if
                    strRange.lowerBound > startIndex,
                    _needsParagraphFixing(from: range.lowerBound - 1, to: range.lowerBound)
                {
                    let r = _paragraphExtending(from: characterIndex(before: strRange.lowerBound))
                    startParagraph = r._utf8OffsetRange
                }
                // Grab the paragraph that contains the character at the end of the mutation (if we're not at the end)
                if
                    strRange.upperBound < endIndex,
                    (startParagraph?.upperBound ?? 0) < range.upperBound,
                    _needsParagraphFixing(from: range.upperBound - 1, to: range.upperBound)
                {
                    let r = _paragraphExtending(from: characterIndex(before: strRange.upperBound))
                    endParagraph = r._utf8OffsetRange
                }
            }
            
            // If the start paragraph extends into the mutation, fixup the range within the mutation
            if let startParagraph, startParagraph.upperBound > range.lowerBound {
                _applyStyle(
                    type: .paragraph,
                    from: startParagraph.lowerBound,
                    to: range.lowerBound ..< startParagraph.upperBound)
            }
            // If the end paragraph extends beyond the mutation, fixup the range outside the mutation
            if let endParagraph, endParagraph.upperBound > range.upperBound {
                _applyStyle(
                    type: .paragraph,
                    from: endParagraph.lowerBound,
                    to: range.upperBound ..< endParagraph.upperBound)
            }
        }
    }

    func fixCharacterConstrainedAttributes(in range: Range<Index>) {
        // Attribute keys with associated range sets that we'll need to remove.
        var invalidAttributes: [String: [Range<Int>]] = [:]

        func invalidate(_ key: String, from start: _BString.Index, to end: _BString.Index) {
            let range = start._utf8Offset ..< end._utf8Offset
            invalidAttributes[key, default: []]._extend(with: range)
        }

        let lowerBound = string.characterIndex(roundingDown: range.lowerBound._value)
        let upperBound = string.characterIndex(roundingUp: range.upperBound._value)

        // Character-constrained attributes at the end of the previous run that are still
        // in indeterminate state.
        var pendingAttributes: [String: _AttributeValue] = [:]
        var pendingStart = lowerBound // Only set if pendingAttributes isn't empty

        // Iterate over all runs, gathering keys to remove in exactly one pass.
        var runStart = lowerBound
        enumerateRuns(containing: lowerBound._utf8Offset ..< upperBound._utf8Offset) { run, location, _, status in
            status = .guaranteedNotModified
            precondition(runStart._utf8Offset == location, "Internal error: Discontiguous runs")
            let runEnd = string.utf8Index(runStart, offsetBy: run.length)
            defer { runStart = runEnd }

            // Figure out the fate of keys carried over from the previous run. (If any.)
            var remainingAttributes: [String: _AttributeValue] = [:]
            if !pendingAttributes.isEmpty {
                precondition(pendingStart < runStart)
                remainingAttributes = pendingAttributes.filter { (key, value) in
                    if run.attributes[key] == value { return true }
                    invalidate(key, from: pendingStart, to: runStart)
                    return false
                }
            }
            pendingAttributes = [:]
            pendingStart = runEnd

            guard run.attributes.containsCharacterConstraint else {
                runStart = runEnd
                return
            }

            var i = string.characterIndex(roundingDown: runStart)
            if i < runStart {
                // If the first character starts before this run, then we need to check
                // character-constrained attributes against `remainingAttributes` and discard
                // any mismatches.
                let char = string[character: i]
                let next = string.characterIndex(after: i)
                for (key, value) in run.attributes.contents {
                    if
                        let c = value.runBoundaries?._constrainedCharacter,
                        c != char || value != remainingAttributes[key]
                    {
                        invalidate(key, from: i, to: next)
                    }
                }
                if next > runEnd {
                    pendingAttributes = remainingAttributes
                    pendingStart = i
                    return
                }
                i = next
                remainingAttributes = [:]
            }

            while i < runEnd {
                let char = string[character: i]
                let next = string.characterIndex(after: i)
                for (key, value) in run.attributes.contents {
                    if let c = value.runBoundaries?._constrainedCharacter, c != char {
                        invalidate(key, from: i, to: next)
                    }
                }
                if next > runEnd {
                    pendingAttributes = run.attributes.contents.filter { (key, value) in
                        value.runBoundaries?._constrainedCharacter != nil
                    }
                    pendingStart = i
                }
                i = next
            }
        }
        precondition(pendingAttributes.isEmpty)

        for (key, utf8Ranges) in invalidAttributes {
            for utf8Range in utf8Ranges {
                remove(key: key, in: utf8Range, adjustConstrainedAttributes: false)
            }
        }
    }
    
    /// Performs a "full fix-up" of the entire string and fixes all attributes according to their constraints. This requires thorough enumeration of the entire string and should only be used when an `AttributedString` is created through means that bypass the standard constraint adjustments such as conversion from `NSAttributedString` and decoding from an archive.
    func adjustConstrainedAttributesForUntrustedRuns() {
        self.fixCharacterConstrainedAttributes(in: startIndex ..< endIndex)

        var i = startIndex
        while i < endIndex {
            let j = nextParagraphBreak(after: i)
            let startOffset = utf8Offset(of: i)
            let endOffset = utf8Offset(of: j)
            let paragraphStyle = self._constrainedAttributes(at: startOffset, with: .paragraph)
            self.enumerateRuns(containing: startOffset ..< endOffset) { run, _, _, mod in
                run.attributes.matchStyle(of: paragraphStyle, for: .paragraph)
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
