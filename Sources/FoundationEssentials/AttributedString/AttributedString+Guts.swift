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

extension AttributedString {
    internal final class Guts : @unchecked Sendable {
        typealias Index = AttributedString.Index
        typealias Runs = AttributedString.Runs
        typealias AttributeMergePolicy = AttributedString.AttributeMergePolicy
        typealias AttributeRunBoundaries = AttributedString.AttributeRunBoundaries
        typealias _InternalRun = AttributedString._InternalRun
        typealias _InternalRuns = AttributedString._InternalRuns
        typealias _AttributeValue = AttributedString._AttributeValue
        typealias _AttributeStorage = AttributedString._AttributeStorage

        var version: Version
        var string: BigString
        var runs: _InternalRuns
        var trackedRanges: [Range<BigString.Index>]

        // Note: the caller is responsible for performing attribute fix-ups if needed based on the source of the runs
        init(string: BigString, runs: _InternalRuns) {
            precondition(string.isEmpty == runs.isEmpty, "An empty attributed string should not contain any runs")
            self.version = Self.createNewVersion()
            self.string = string
            self.runs = runs
            self.trackedRanges = []
        }

        // Note: the caller is responsible for performing attribute fix-ups if needed based on the source of the runs
        convenience init(string: String, runs: _InternalRuns) {
            self.init(string: BigString(string), runs: runs)
        }

        convenience init() {
            self.init(string: BigString(), runs: _InternalRuns())
        }
    }
}

extension AttributedString.Guts {
    __consuming func copy() -> AttributedString.Guts {
        AttributedString.Guts(string: self.string, runs: self.runs)
    }

    __consuming func copy(in range: Range<BigString.Index>) -> AttributedString.Guts {
        let string = BigString(self.string.unicodeScalars[range])
        let runs = self.runs.extract(utf8Offsets: range._utf8OffsetRange)
        let copy = AttributedString.Guts(string: string, runs: runs)
        // FIXME: Extracting a slice should not invalidate anything but .textChanged attribute runs on the edges
        if range.lowerBound != string.startIndex || range.upperBound != string.endIndex {
            var utf8Range = copy.stringBounds._utf8OffsetRange
            utf8Range = copy.enforceAttributeConstraintsBeforeMutation(to: utf8Range)
            copy.enforceAttributeConstraintsAfterMutation(in: utf8Range, type: .attributesAndCharacters)
        }
        return copy
    }
}

extension AttributedString.Guts {
    internal static func characterwiseIsEqual(
        _ left: AttributedString.Guts,
        to right: AttributedString.Guts
    ) -> Bool {
        _characterwiseIsEqual(
            AttributedString.Runs(left, in: Range(uncheckedBounds: (left.string.startIndex, left.string.endIndex))),
            to: AttributedString.Runs(right, in: Range(uncheckedBounds: (right.string.startIndex, right.string.endIndex))),
            fullString: true
        )
    }

    internal static func characterwiseIsEqual(
        _ left: AttributedString.Guts, in leftRange: Range<BigString.Index>,
        to right: AttributedString.Guts, in rightRange: Range<BigString.Index>
    ) -> Bool {
        let leftRuns = AttributedString.Runs(left, in: leftRange)
        let rightRuns = AttributedString.Runs(right, in: rightRange)
        return _characterwiseIsEqual(leftRuns, to: rightRuns, fullString: false)
    }

    internal static func _characterwiseIsEqual(
        _ left: AttributedString.Runs,
        to right: AttributedString.Runs,
        fullString: Bool
    ) -> Bool {
        // To decide if two attributed strings are equal, we need to logically split them up on
        // run boundaries, then check that each pair of pieces contains the same attribute values
        // and NFC-normalized string contents.
        //
        // Run lengths cannot be compared directly, as NFC normalization can change string length.
        //
        // We need to separately normalize each individual string piece. We cannot simply
        // normalize the entire string up front, as that would blur attribute run boundaries
        // (especially ones that fall inside Characters).
        //
        // Note: This implementation must be precisely in sync with the `characterwiseHash(in:into:)`
        // implementation below.
        if left._guts === right._guts, left._strBounds == right._strBounds { return true }

        guard left.count == right.count else { return false }
        guard !left.isEmpty else { return true }
        
        if fullString {
            // For a full BigString, we can get the grapheme cluster count in constant time since
            // the grapheme cluster count is cached at the node level in the tree. It is not
            // possible for two AttributedStrings with differing character counts to be equal,
            // so bail early if we detect that
            //
            // Note: we should not perform this check for cases where we are not knowingly working
            // with the full string. Since character counts are only cached at the node level,
            // to get the character count of a substring you would need to run the grapheme
            // breaking algorithm over the partial first and last chunks. While this is
            // technically done in constant time as chunks have a max of 255 UTF-8 scalars, grapheme
            // breaking up to 510 UTF-8 scalars would not be cheap. In the future we can
            // investigate best effort short cuts by comparing the counts of just the "middle"
            // chunks that we can determine cheaply along with the knowledge that the partial
            // first and last chunks have a character count no more than their UTF-8 counts.
            guard left._guts.string.count == right._guts.string.count else {
                return false
            }
        }
        

        guard var leftIndex = left._strBounds.ranges.first?.lowerBound, var rightIndex = right._strBounds.ranges.first?.lowerBound else { return false }

        var it1 = left.makeIterator()
        var it2 = right.makeIterator()
    loop:
        while true {
            switch (it1.next(), it2.next()) {
            case let (leftRun?, rightRun?):
                guard leftRun.attributes == rightRun.attributes else { return false }

                let leftNext = left._guts.string.utf8.index(leftIndex, offsetBy: leftRun._utf8Count)
                let rightNext = right._guts.string.utf8.index(rightIndex, offsetBy: rightRun._utf8Count)

                // FIXME: This doesn't handle sub-character runs correctly.
                guard
                    left._guts.string[leftIndex ..< leftNext] == right._guts.string[rightIndex ..< rightNext]
                else {
                    return false
                }
                leftIndex = leftNext
                rightIndex = rightNext
            case (nil, nil):
                break loop
            default:
                assertionFailure() // We compared counts above
                return false
            }
        }
        assert(leftIndex == left._strBounds.ranges.last?.upperBound)
        assert(rightIndex == right._strBounds.ranges.last?.upperBound)
        return true
    }

    internal func characterwiseHash(
        in range: Range<BigString.Index>,
        into hasher: inout Hasher
    ) {
        // Note: This implementation must be precisely in sync with the `_characterwiseIsEqual`
        // implementation above.
        let runs = AttributedString.Runs(self, in: range)
        hasher.combine(runs.count) // Hash discriminator

        for run in runs {
            hasher.combine(run._attributes)
            // FIXME: This doesn't handle sub-character runs correctly.
            hasher.combine(string[run._range])
        }
    }
}

extension AttributedString.Guts {
    internal func description(in range: Range<BigString.Index>) -> String {
        self.description(in: RangeSet(range))
    }
    
    internal func description(in range: RangeSet<BigString.Index>) -> String {
        var result = ""
        let runs = Runs(self, in: range)
        for run in runs {
            let text = String(self.string.unicodeScalars[run.range._bstringRange])
            if !result.isEmpty { result += "\n" }
            result += "\(text) \(run._attributes)"
        }
        return result
    }
}

extension AttributedString.Guts {
    var stringBounds: Range<BigString.Index> {
        Range(uncheckedBounds: (string.startIndex, string.endIndex))
    }

    var utf8OffsetRange: Range<Int> {
        0 ..< string.utf8.count
    }

    func utf8Index(at offset: Int) -> BigString.Index {
        string.utf8.index(string.startIndex, offsetBy: offset)
    }

    func utf8IndexRange(from offsets: Range<Int>) -> Range<BigString.Index> {
        let lower = utf8Index(at: offsets.lowerBound)
        let upper = string.utf8.index(lower, offsetBy: offsets.count)
        return Range(uncheckedBounds: (lower, upper))
    }

    func unicodeScalarRange(roundingDown range: Range<BigString.Index>) -> Range<BigString.Index> {
        let lower = string.unicodeScalars.index(roundingDown: range.lowerBound)
        let upper = string.unicodeScalars.index(roundingDown: range.upperBound)
        return Range(uncheckedBounds: (lower, upper))
    }

    func characterRange(roundingDown range: Range<BigString.Index>) -> Range<BigString.Index> {
        let lower = string.index(roundingDown: range.lowerBound)
        let upper = string.index(roundingDown: range.upperBound)
        return Range(uncheckedBounds: (lower, upper))
    }

    func index(afterRun i: BigString.Index) -> BigString.Index {
        // Expected semantics: Result is the end of the run that contains `i`.
        let index = self.runs.index(atUTF8Offset: i.utf8Offset).index
        let length = self.runs[index].length
        let next = self.string.utf8.index(i, offsetBy: index.utf8Offset + length - i.utf8Offset)
        assert(next > i)
        return next
    }

    func index(beforeRun i: BigString.Index) -> BigString.Index {
        // Expected semantics: result is the start of the run preceding the one that contains `i`.
        // (I.e., `i` needs to get implicitly rounded down to the nearest run boundary before we
        // step back.)
        let prev = self.string.utf8.index(before: i)
        let index = self.runs.index(atUTF8Offset: prev.utf8Offset).index
        let length = self.runs[index].length
        if index.utf8Offset + length <= i.utf8Offset {
            // Fast path: `i` already addresses a run boundary.
            return self.string.utf8.index(prev, offsetBy: index.utf8Offset - prev.utf8Offset)
        }
        precondition(index > self.runs.startIndex, "Can't advance below start index")
        let index2 = self.runs.index(before: index)
        return self.string.utf8.index(prev, offsetBy: index2.utf8Offset - prev.utf8Offset)
    }

    internal func findRun(
        at i: BigString.Index
    ) -> (runIndex: _InternalRuns.Index, start: BigString.Index) {
        let run = self.runs.index(atUTF8Offset: i.utf8Offset)
        let start = self.string.utf8.index(i, offsetBy: -run.remainingUTF8)
        return (run.index, start)
    }

    /// Returns all the runs in the receiver, in the given range.
    func runs(in utf8Bounds: Range<Int>) -> AttributedString._InternalRunsSlice {
        AttributedString._InternalRunsSlice(self, utf8Bounds: utf8Bounds)
    }

    func runs(in range: Range<BigString.Index>) -> AttributedString._InternalRunsSlice {
        return runs(in: range._utf8OffsetRange)
    }

    func run(at index: _InternalRuns.Index) -> (attributes: _AttributeStorage, utf8Range: Range<Int>) {
        let run = runs[index]
        let length = self.runs[index].length
        let utf8Range = Range(uncheckedBounds: (index.utf8Offset, index.utf8Offset + length))
        return (run.attributes, utf8Range)
    }

    /// Update the attribute dictionary at the specified index by invoking a closure on it.
    /// If the index addresses a partial run at the beginning or end of the given slice, then the
    /// underlying run is automatically split to accommodate the change.
    ///
    /// Once `body` returns, the resulting item is coalesced with its neighbors if needed;
    /// such coalescing may change the number of items in the slice.
    ///
    /// On return, this function updates `index` to address the run that includes the UTF-8 range
    /// of the original element. If the update needed to coalesce runs, the new `index` may address
    /// a wider run than the original did.
    ///
    /// If `body` does not end up actually mutating the attributes passed to it, then it may signal
    /// this fact by setting its `mutated` argument to `false`. This avoid coalescing, so it will
    /// slightly speed up execution.
    func updateRun(
        at index: inout _InternalRuns.Index,
        within utf8Bounds: Range<Int>,
        with body: (
            _ attributes: inout _AttributeStorage,
            _ utf8Range: Range<Int>,
            _ mutated: inout Bool
        ) -> Void
    ) {
        var (attributes, fullUTF8Range) = run(at: index)
        let clampedUTF8Range = fullUTF8Range.clamped(to: utf8Bounds)
        precondition(!clampedUTF8Range.isEmpty, "Index out of bounds")
        var mutated = true
        if clampedUTF8Range == fullUTF8Range {
            // Allow in-place mutations of the attribute dictionary.
            self.runs._update(at: &index) { $0.attributes = _AttributeStorage() }
            body(&attributes, clampedUTF8Range, &mutated)
            if mutated {
                self.runs.updateAndCoalesce(at: &index) { $0 = attributes }
            } else {
                self.runs._update(at: &index) { $0.attributes = attributes }
            }
        } else {
            body(&attributes, clampedUTF8Range, &mutated)
            if mutated {
                let run = _InternalRun(length: clampedUTF8Range.count, attributes: attributes)
                self.runs.replaceUTF8Subrange(clampedUTF8Range, with: CollectionOfOne(run))
                index = self.runs.index(atUTF8Offset: index.utf8Offset).index
            } else {
                return // nothing mutated
            }
        }
    }

    /// Get the uniform value for the specified key across the given range of indices.
    /// Returns nil if the given range includes multiple different values for the same key.
    func getUniformValue<K: AttributedStringKey>(
        in range: Range<BigString.Index>, key: K.Type
    ) -> _AttributeValue? {
        var result: _AttributeValue? = nil
        for run in self.runs(in: range._utf8OffsetRange) {
            guard let value = run.attributes[K.name] else {
                return nil
            }
            if let previous = result, value != previous {
                return nil
            }
            result = value
        }
        return result
    }

    /// Get all attributes that have consistent values across the given range of indices.
    /// Attributes that have multiple different values are not included in the returned storage.
    func getUniformValues(in range: Range<BigString.Index>) -> _AttributeStorage {
        var attributes = _AttributeStorage()
        var first = true
        for run in self.runs(in: range._utf8OffsetRange) {
            guard !first else {
                attributes = run.attributes
                first = false
                continue
            }
            attributes = attributes.filterWithoutInvalidatingDependents {
                guard let value = run.attributes[$0.key] else { return false }
                return value == $0.value
            }
            if attributes.isEmpty {
                break
            }
        }
        return attributes
    }

    func setAttributeValue(
        _ value: _AttributeValue,
        forKey key: String,
        in range: Range<BigString.Index>
    ) {
        let utf8Range = unicodeScalarRange(roundingDown: range)._utf8OffsetRange
        self.runs(in: utf8Range).updateEach { attributes, range, mutated in
            attributes[key] = value
        }
        if value.hasConstrainedAttributes {
            self.enforceAttributeConstraintsAfterMutation(
                in: utf8Range, type: .attributes, constraintsInvolved: value.constraintsInvolved)
        }
    }

    func setAttributeValue<K: AttributedStringKey>(
        _ value: K.Value, forKey key: K.Type, in range: Range<BigString.Index>
    ) where K.Value : Sendable {
        let value = _AttributeValue(value, for: K.self)
        self.setAttributeValue(value, forKey: K.name, in: range)
    }

    func mergeAttributes(
        _ attributes: AttributeContainer,
        in range: Range<BigString.Index>,
        mergePolicy: AttributeMergePolicy = .keepNew
    ) {
        let new = attributes.storage
        let utf8Range = unicodeScalarRange(roundingDown: range)._utf8OffsetRange
        self.runs(in: utf8Range).updateEach { attributes, range, mutated in
            attributes.mergeIn(new, mergePolicy: mergePolicy)
        }
        if new.hasConstrainedAttributes {
            self.enforceAttributeConstraintsAfterMutation(
                in: utf8Range, type: .attributes, constraintsInvolved: new.constraintsInvolved)
        }
    }

    func setAttributes(_ attributes: _AttributeStorage, in range: Range<BigString.Index>) {
        let utf8Range = unicodeScalarRange(roundingDown: range)._utf8OffsetRange
        let run = _InternalRun(length: utf8Range.count, attributes: attributes)
        self.runs.replaceUTF8Subrange(utf8Range, with: CollectionOfOne(run))
        self.enforceAttributeConstraintsAfterMutation(
            in: utf8Range,
            type: .attributes,
            constraintsInvolved: attributes.constraintsInvolved)
    }

    func removeAttributeValue<K: AttributedStringKey>(
        forKey key: K.Type, in range: Range<BigString.Index>
    ) where K.Value: Sendable {
        let utf8Range = unicodeScalarRange(roundingDown: range)._utf8OffsetRange
        self.runs(in: utf8Range).updateEach { attributes, range, mutated in
            mutated = attributes.removeValue(forKey: K.self)
        }
        if K.runBoundaries != nil {
            self.enforceAttributeConstraintsAfterMutation(
                in: utf8Range, type: .attributes, constraintsInvolved: K.constraintsInvolved)
        }
    }

    func removeAttributeValue(forKey key: String, in range: Range<BigString.Index>) {
        let utf8Range = unicodeScalarRange(roundingDown: range)._utf8OffsetRange
        removeAttributeValue(forKey: key, in: utf8Range)
    }

    func removeAttributeValue(
        forKey key: String, in utf8Range: Range<Int>, adjustConstrainedAttributes: Bool = true
    ) {
        self.runs(in: utf8Range).updateEach { attributes, range, mutated in
            attributes[key] = nil
        }
        if adjustConstrainedAttributes {
            // FIXME: Collect boundary constraints.
            self.enforceAttributeConstraintsAfterMutation(in: utf8Range, type: .attributes)
        }
    }

    func _prepareStringMutation(
        in range: Range<BigString.Index>
    ) -> (mutationStartUTF8Offset: Int, isInsertion: Bool, oldUTF8Count: Int, invalidationRange: Range<Int>) {
        let utf8TargetRange = range._utf8OffsetRange
        let invalidationRange = self.enforceAttributeConstraintsBeforeMutation(to: utf8TargetRange)
        self._prepareTrackedIndicesUpdate(mutationRange: range)
        assert(invalidationRange.lowerBound <= utf8TargetRange.lowerBound)
        assert(invalidationRange.upperBound >= utf8TargetRange.upperBound)
        return (utf8TargetRange.lowerBound, utf8TargetRange.isEmpty, self.string.utf8.count, invalidationRange)
    }

    func _finalizeStringMutation(
        _ state: (mutationStartUTF8Offset: Int, isInsertion: Bool, oldUTF8Count: Int, invalidationRange: Range<Int>)
    ) {
        let utf8Delta = self.string.utf8.count - state.oldUTF8Count
        self._finalizeTrackedIndicesUpdate(mutationStartOffset: state.mutationStartUTF8Offset, isInsertion: state.isInsertion, utf8LengthDelta: utf8Delta)
        let lower = state.invalidationRange.lowerBound
        let upper = state.invalidationRange.upperBound + utf8Delta
        self.enforceAttributeConstraintsAfterMutation(
            in: lower ..< upper,
            type: .attributesAndCharacters)
    }

    func replaceSubrange(
        _ range: Range<BigString.Index>,
        with replacement: some AttributedStringProtocol
    ) {
        let replacementScalars = replacement.unicodeScalars._unicodeScalars

        // Determine if this replacement is going to actively change character data, or if this is
        // purely an attributes update, by seeing if the replacement string slice is identical to
        // our own storage. (If it is identical, then we need to update attributes surrounding the
        // affected bounds in a different way.)
        //
        // Note: this is intentionally not comparing actual string data.
        let hasStringChanges = !replacementScalars.isIdentical(to: string.unicodeScalars[range])

        let utf8SourceRange = Range(uncheckedBounds: (
            replacementScalars.startIndex.utf8Offset,
            replacementScalars.endIndex.utf8Offset
        ))
        let replacementRuns = replacement.__guts.runs(in: utf8SourceRange)

        let utf8TargetRange = range._utf8OffsetRange
        if hasStringChanges {
            let state = _prepareStringMutation(in: range)
            self.string.unicodeScalars.replaceSubrange(range, with: replacementScalars)
            self.runs.replaceUTF8Subrange(utf8TargetRange, with: replacementRuns)
            _finalizeStringMutation(state)
        } else {
            self.runs.replaceUTF8Subrange(utf8TargetRange, with: replacementRuns)
            self.enforceAttributeConstraintsAfterMutation(in: range._utf8OffsetRange, type: .attributes)
        }
    }

    func attributesToUseForTextReplacement(in range: Range<BigString.Index>) -> _AttributeStorage {
        guard !self.string.isEmpty else { return _AttributeStorage() }

        var position = range.lowerBound
        if range.isEmpty, position.utf8Offset > 0 {
            position = self.string.utf8.index(before: position)
        }

        let runIndex = self.runs.index(atUTF8Offset: position.utf8Offset).index
        let attributes = self.runs[runIndex].attributes
        return attributes.attributesForAddedText()
    }
}
