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
@_implementationOnly @_spi(Unstable) import CollectionsInternal
#else
import _RopeModule
#endif

package import FoundationInternals

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    internal struct _InternalRun : Hashable, Sendable {
        // UTF-8 Code Unit Length
        internal var length : Int
        internal var attributes : _AttributeStorage

        internal static func == (lhs: _InternalRun, rhs: _InternalRun) -> Bool {
            if lhs.length != rhs.length {
                return false
            }
            return lhs.attributes == rhs.attributes
        }

        internal func get<T: AttributedStringKey>(_ k: T.Type) -> T.Value? where T.Value : Sendable {
            attributes[k]
        }
    }
}

extension AttributedString._InternalRun {
    internal func matches(_ container: AttributeContainer) -> Bool {
        for key in container.storage.keys {
            if attributes[key] != container.storage[key] {
                return false
            }
        }
        return true
    }
}

extension AttributedString {
    internal final class Guts : @unchecked Sendable {
        typealias Index = AttributedString.Index
        typealias Runs = AttributedString.Runs
        typealias AttributeMergePolicy = AttributedString.AttributeMergePolicy
        typealias AttributeRunBoundaries = AttributedString.AttributeRunBoundaries
        typealias _InternalRun = AttributedString._InternalRun
        typealias _AttributeValue = AttributedString._AttributeValue
        typealias _AttributeStorage = AttributedString._AttributeStorage

        var string: BigString

        // NOTE: the runs and runOffsetCache should never be modified directly. Instead, use the functions defined in AttributedStringRunCoalescing.swift
        var runs: [_InternalRun]
        var runOffsetCache: LockedState<RunOffset>

        // Note: the caller is responsible for performing attribute fix-ups if needed based on the source of the runs
        init(string: BigString, runs: [_InternalRun]) {
            precondition(string.isEmpty == runs.isEmpty, "An empty attributed string should not contain any runs")
            self.string = string
            self.runs = runs
            runOffsetCache = LockedState(initialState: RunOffset())
        }

        // Note: the caller is responsible for performing attribute fix-ups if needed based on the source of the runs
        convenience init(string: String, runs: [_InternalRun]) {
            self.init(string: BigString(string), runs: runs)
        }

        convenience init() {
            self.init(string: BigString(), runs: [])
        }
    }
}

extension AttributedString.Guts {
    __consuming func copy() -> AttributedString.Guts {
        AttributedString.Guts(string: self.string, runs: self.runs)
    }

    __consuming func copy(in range: Range<Index>) -> AttributedString.Guts {
        let string = BigString(self.string.unicodeScalars[range._bstringRange])
        let runs = self.runs(in: range)
        let copy = AttributedString.Guts(string: string, runs: runs)
        if range.lowerBound != self.startIndex || range.upperBound != self.endIndex {
            var utf8Range = copy.utf8OffsetRange(from: copy.startIndex ..< copy.endIndex)
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
            left, from: left.string.startIndex, to: left.string.endIndex, with: left.runs,
            comparingTo: right, from: right.string.startIndex, to: right.string.endIndex, with: right.runs)
    }

    internal static func characterwiseIsEqual(
        _ left: AttributedString.Guts, in leftRange: Range<BigString.Index>,
        to right: AttributedString.Guts, in rightRange: Range<BigString.Index>
    ) -> Bool {
        let leftRuns = left.runs(containing: leftRange._utf8OffsetRange)
        let rightRuns = right.runs(containing: rightRange._utf8OffsetRange)
        return _characterwiseIsEqual(
            left, from: leftRange.lowerBound, to: leftRange.upperBound, with: leftRuns,
            comparingTo: right, from: rightRange.lowerBound, to: rightRange.upperBound, with: rightRuns)
    }

    internal static func _characterwiseIsEqual(
        _ left: AttributedString.Guts,
        from leftStart: BigString.Index,
        to leftEnd: BigString.Index,
        with leftRuns: some Collection<_InternalRun>,
        comparingTo right: AttributedString.Guts,
        from rightStart: BigString.Index,
        to rightEnd: BigString.Index,
        with rightRuns: some Collection<_InternalRun>
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
        if left === right, leftStart == rightStart, leftEnd == rightEnd { return true }

        guard leftRuns.count == rightRuns.count else { return false }

        var leftIndex = leftStart
        var rightIndex = rightStart

        var it1 = leftRuns.makeIterator()
        var it2 = rightRuns.makeIterator()
    loop:
        while true {
            switch (it1.next(), it2.next()) {
            case let (leftRun?, rightRun?):
                guard leftRun.attributes == rightRun.attributes else { return false }

                let leftNext = left.string.utf8.index(leftIndex, offsetBy: leftRun.length)
                let rightNext = right.string.utf8.index(rightIndex, offsetBy: rightRun.length)

                // FIXME: This doesn't handle sub-character runs correctly.
                guard
                    left.string[leftIndex ..< leftNext] == right.string[rightIndex ..< rightNext]
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
        assert(leftIndex == leftEnd)
        assert(rightIndex == rightEnd)
        return true
    }

    internal func characterwiseHash(in range: Range<BigString.Index>, into hasher: inout Hasher) {
        // Note: This implementation must be precisely in sync with the `_characterwiseIsEqual`
        // implementation above.
        let offsetRange = range._utf8OffsetRange
        hasher.combine(self.countOfRuns(in: offsetRange)) // Hash discriminator
        var index = range.lowerBound
        self.enumerateRuns(containing: offsetRange) { run, start, _, mod in
            mod = .guaranteedNotModified
            hasher.combine(run.attributes)
            let next = string.utf8.index(index, offsetBy: run.length)
            // FIXME: This doesn't handle sub-character runs correctly.
            hasher.combine(string[index ..< next])
            index = next
        }
    }
}

extension AttributedString.Guts {
    var startIndex: Index {
        Index(string.startIndex)
    }

    var endIndex: Index {
        Index(string.endIndex)
    }

    func characterIndex(after i: Index) -> Index {
        Index(string.index(after: i._value))
    }

    func characterIndex(before i: Index) -> Index {
        Index(string.index(before: i._value))
    }

    func characterDistance(from start: Index, to end: Index) -> Int {
        string.distance(from: start._value, to: end._value)
    }

    func unicodeScalarDistance(from start: Index, to end: Index) -> Int {
        string.unicodeScalars.distance(from: start._value, to: end._value)
    }

    func utf8Index(before i: Index) -> Index {
        Index(string.utf8.index(before: i._value))
    }

    func utf8Index(at offset: Int) -> Index {
        Index(string.utf8.index(string.startIndex, offsetBy: offset))
    }

    func utf8Index(_ i: Index, offsetBy distance: Int) -> Index {
        Index(string.utf8.index(i._value, offsetBy: distance))
    }

    func utf8IndexRange(from offsets: Range<Int>) -> Range<Index> {
        let lower = utf8Index(at: offsets.lowerBound)
        let upper = utf8Index(lower, offsetBy: offsets.count)
        return Range(uncheckedBounds: (lower, upper))
    }

    func utf8OffsetRange(from range: Range<Index>) -> Range<Int> {
        let lower = utf8Offset(of: range.lowerBound)
        let delta = utf8Distance(from: range.lowerBound, to: range.upperBound)
        return Range(uncheckedBounds: (lower, lower + delta))
    }

    func utf8Offset(of index: Index) -> Int {
        string.utf8.distance(from: string.startIndex, to: index._value)
    }

    func utf8Distance(from start: Index, to end: Index) -> Int {
        string.utf8.distance(from: start._value, to: end._value)
    }

    func unicodeScalarIndex(roundingDown i: Index) -> Index {
        Index(string.unicodeScalars.index(roundingDown: i._value))
    }

    func unicodeScalarIndex(roundingUp i: Index) -> Index {
        Index(string.unicodeScalars.index(roundingUp: i._value))
    }

    func characterIndex(roundingDown i: Index) -> Index {
        Index(string.index(roundingDown: i._value))
    }

    func characterIndex(roundingUp i: Index) -> Index {
        Index(string.index(roundingUp: i._value))
    }

    func unicodeScalarRange(roundingDown range: Range<Index>) -> Range<Index> {
        let lower = unicodeScalarIndex(roundingDown: range.lowerBound)
        let upper = unicodeScalarIndex(roundingDown: range.upperBound)
        return Range(uncheckedBounds: (lower, upper))
    }

    func characterRange(roundingDown range: Range<Index>) -> Range<Index> {
        let lower = characterIndex(roundingDown: range.lowerBound)
        let upper = characterIndex(roundingDown: range.upperBound)
        return Range(uncheckedBounds: (lower, upper))
    }

    func boundsCheck(_ idx: AttributedString.Index) {
        precondition(
            idx._value >= string.startIndex && idx._value < string.endIndex,
            "AttributedString index is out of bounds")
    }

    func inclusiveBoundsCheck(_ idx: AttributedString.Index) {
        precondition(
            idx._value >= string.startIndex && idx._value <= string.endIndex,
            "AttributedString index is out of bounds")
    }

    func boundsCheck(_ range: Range<AttributedString.Index>) {
        precondition(
            range.lowerBound._value >= string.startIndex && range.upperBound._value < string.endIndex,
            "AttributedString index range is out of bounds")
    }

    func inclusiveBoundsCheck(_ range: Range<AttributedString.Index>) {
        precondition(
            range.lowerBound._value >= string.startIndex && range.upperBound._value <= string.endIndex,
            "AttributedString index range is out of bounds")
    }

    func boundsCheck(_ idx: Runs.Index) {
        precondition(
            idx.rangeIndex >= 0 && idx.rangeIndex < runs.count,
            "AttributedString.Runs index is out of bounds")
    }

    func run(at position: Runs.Index, clampedBy bounds: Range<AttributedString.Index>) -> Runs.Run {
        boundsCheck(position)
        let (internalRun, utf8Start) = runAndLocation(at: position.rangeIndex)
        let utf8End = utf8Start + internalRun.length
        let range = self.utf8IndexRange(from: utf8Start ..< utf8End)
        let result = Runs.Run(_internal: internalRun, range, self)
        return result.run(clampedTo: bounds)
    }

    func run(
        atUTF8Offset utf8Offset: Int
    ) -> (run: _InternalRun, utf8Range: Range<Int>) {
        precondition(
            utf8Offset >= 0 && utf8Offset <= string.utf8.count,
            "AttributedString index is out of bounds")
        let (run, utf8Start) = runAndLocation(containing: utf8Offset)
        let utf8End = utf8Start + run.length
        return (run, (utf8Start ..< utf8End))
    }

    func run(
        at position: AttributedString.Index
    ) -> (run: _InternalRun, range: Range<AttributedString.Index>) {
        boundsCheck(position)
        let position = string.unicodeScalars.index(roundingDown: position._value)
        let utf8Offset = position.utf8Offset

        let (run, utf8Range) = run(atUTF8Offset: utf8Offset)
        let start = string.utf8.index(position, offsetBy: utf8Range.lowerBound - utf8Offset)
        let end = string.utf8.index(position, offsetBy: utf8Range.upperBound - utf8Offset)
        return (run, AttributedString.Index(start) ..< AttributedString.Index(end))
    }

    func run(
        at position: AttributedString.Index,
        clampedBy clampRange: Range<AttributedString.Index>
    ) -> (run: _InternalRun, range: Range<AttributedString.Index>) {
        let r = run(at: position)
        return (r.run, r.range.clamped(to: clampRange))
    }

    func indexOfRun(at position: AttributedString.Index) -> Runs.Index {
        inclusiveBoundsCheck(position)
        let utf8Offset = utf8Offset(of: position)
        let runIndex = indexOfRun(containing: utf8Offset)
        return Runs.Index(rangeIndex: runIndex)
    }

    // Returns all the runs in the receiver, in the given range.
    func runs(in range: Range<Index>) -> [_InternalRun] {
        let offsets = utf8OffsetRange(from: range)
        return runs(containing: offsets)
    }

    func getValue<K: AttributedStringKey>(in range: Range<Index>, key: K.Type) -> _AttributeValue? {
        var result : _AttributeValue? = nil
        let lowerBound = utf8Distance(from: startIndex, to: range.lowerBound)
        let upperBound = lowerBound + utf8Distance(from: range.lowerBound, to: range.upperBound)
        enumerateRuns(containing: lowerBound ..< upperBound) { run, location, stop, modified in
            modified = .guaranteedNotModified
            guard let value = run.attributes[K.name] else {
                result = nil
                stop = true
                return
            }

            if let previous = result, value != previous {
                result = nil
                stop = true
                return
            }
            result = value
        }
        return result
    }

    func getValues(in range: Range<Index>) -> _AttributeStorage {
        var storage = _AttributeStorage()
        let lowerBound = utf8Distance(from: startIndex, to: range.lowerBound)
        let upperBound = lowerBound + utf8Distance(from: range.lowerBound, to: range.upperBound)
        enumerateRuns(containing: lowerBound ..< upperBound) { run, _, stop, modification in
            modification = .guaranteedNotModified
            if storage.isEmpty {
                storage = run.attributes
            } else {
                storage = storage.filter {
                    if let value = run.attributes[$0.key] {
                        return value == $0.value
                    } else {
                        return false
                    }
                }
            }
            if storage.isEmpty {
                stop = true
            }
        }
        return storage
    }

    func add(value: _AttributeValue, in range: Range<Index>, key: String) {
        let utf8Range = utf8OffsetRange(from: range)
        self.enumerateRuns(containing: utf8Range) { run, _, _, _ in
            run.attributes[key] = value
        }
        if value.hasConstrainedAttributes {
            self.enforceAttributeConstraintsAfterMutation(
                in: utf8Range, type: .attributes, constraintsInvolved: value.constraintsInvolved)
        }
    }

    func add<K: AttributedStringKey>(value: K.Value, in range: Range<Index>, key: K.Type) where K.Value : Sendable {
        let _value = _AttributeValue(value, for: K.self)
        self.add(value: _value, in: range, key: K.name)
    }

    func add(attributes: AttributeContainer, in range: Range<Index>, mergePolicy:  AttributeMergePolicy = .keepNew) {
        let newAttrDict = attributes.storage
        let utf8Range = utf8OffsetRange(from: range)
        self.enumerateRuns(containing: utf8Range) { run, _, _, _ in
            run.attributes.mergeIn(newAttrDict, mergePolicy: mergePolicy)
        }
        if newAttrDict.hasConstrainedAttributes {
            self.enforceAttributeConstraintsAfterMutation(
                in: utf8Range, type: .attributes, constraintsInvolved: attributes.storage.constraintsInvolved)
        }
    }

    func set(attributes: AttributeContainer, in range: Range<Index>) {
        let newAttrDict = attributes.storage
        let range = utf8OffsetRange(from: range)
        self.replaceRunsSubrange(locations: range, with: [_InternalRun(length: range.endIndex - range.startIndex, attributes: newAttrDict)])
        self.enforceAttributeConstraintsAfterMutation(
            in: range, type: .attributes, constraintsInvolved: attributes.storage.constraintsInvolved)
    }

    func remove<T : AttributedStringKey>(attribute: T.Type, in range: Range<Index>) where T.Value : Sendable {
        let utf8Range = utf8OffsetRange(from: range)
        self.enumerateRuns(containing: utf8Range) { run, _, _, _ in
            run.attributes[T.self] = nil
        }
        if T.runBoundaries != nil {
            self.enforceAttributeConstraintsAfterMutation(
                in: utf8Range, type: .attributes, constraintsInvolved: T.constraintsInvolved)
        }
    }

    func remove(key: String, in range: Range<Index>) {
        let utf8Range = utf8OffsetRange(from: range)
        remove(key: key, in: utf8Range)
    }

    func remove(key: String, in utf8Range: Range<Int>, adjustConstrainedAttributes: Bool = true) {
        self.enumerateRuns(containing: utf8Range) { run, _, _, _ in
            run.attributes[key] = nil
        }
        if adjustConstrainedAttributes {
            // FIXME: Collect boundary constraints.
            self.enforceAttributeConstraintsAfterMutation(in: utf8Range, type: .attributes)
        }
    }

    func _prepareStringMutation(
        in range: Range<Index>
    ) -> (oldUTF8Count: Int, invalidationRange: Range<Int>) {
        let utf8TargetRange = range._utf8OffsetRange
        let invalidationRange = self.enforceAttributeConstraintsBeforeMutation(to: utf8TargetRange)
        assert(invalidationRange.lowerBound <= utf8TargetRange.lowerBound)
        assert(invalidationRange.upperBound >= utf8TargetRange.upperBound)
        return (self.string.utf8.count, invalidationRange)
    }

    func _finalizeStringMutation(
        _ state: (oldUTF8Count: Int, invalidationRange: Range<Int>)
    ) {
        let utf8Delta = self.string.utf8.count - state.oldUTF8Count
        let lower = state.invalidationRange.lowerBound
        let upper = state.invalidationRange.upperBound + utf8Delta
        self.enforceAttributeConstraintsAfterMutation(
            in: lower ..< upper,
            type: .attributesAndCharacters)
    }

    func _finalizeAttributeMutation(in range: Range<Index>) {
        self.enforceAttributeConstraintsAfterMutation(in: range._utf8OffsetRange, type: .attributes)
    }

    func replaceSubrange(_ range: Range<Index>, with replacement: some AttributedStringProtocol) {
        let brange = range._bstringRange
        let replacementScalars = replacement.unicodeScalars._unicodeScalars

        // Determine if this replacement is going to actively change character data, or if this is
        // purely an attributes update, by seeing if the replacement string slice is identical to
        // our own storage. (If it is identical, then we need to update attributes surrounding the
        // affected bounds in a different way.)
        //
        // Note: this is intentionally not comparing actual string data.
        let hasStringChanges = !replacementScalars.isIdentical(to: string.unicodeScalars[brange])

        let utf8TargetRange = brange._utf8OffsetRange
        let utf8SourceRange = Range(uncheckedBounds: (
            replacementScalars.startIndex.utf8Offset,
            replacementScalars.endIndex.utf8Offset
        ))
        let replacementRuns = replacement.__guts.runs(containing: utf8SourceRange)

        if hasStringChanges {
            let state = _prepareStringMutation(in: range)
            self.string.unicodeScalars.replaceSubrange(brange, with: replacementScalars)
            self.replaceRunsSubrange(locations: utf8TargetRange, with: replacementRuns)
            _finalizeStringMutation(state)
        } else {
            self.replaceRunsSubrange(locations: utf8TargetRange, with: replacementRuns)
            _finalizeAttributeMutation(in: range)
        }
    }

    func attributesToUseForTextReplacement(
        in range: Range<Index>,
        includingCharacterDependentAttributes: Bool
    ) -> _AttributeStorage {
        guard !self.string.isEmpty else { return _AttributeStorage() }

        var position = range.lowerBound
        if range.isEmpty, position > startIndex {
            position = self.utf8Index(before: range.lowerBound)
        }

        let attributes = self.run(at: position).run.attributes
        return attributes.attributesForAddedText(
            includingCharacterDependentAttributes: includingCharacterDependentAttributes)
    }
}
