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

// MARK: - Internal Index Updating

extension AttributedString.Guts {
    func _prepareTrackedIndicesUpdate(mutationRange: Range<BigString.Index>) {
        // Move any range endpoints inside of the mutation range to outside of the mutation range since a range should never end up splitting a mutation
        for idx in 0 ..< trackedRanges.count {
            let lowerBoundWithinMutation = trackedRanges[idx].lowerBound > mutationRange.lowerBound && trackedRanges[idx].lowerBound < mutationRange.upperBound
            let upperBoundWithinMutation = trackedRanges[idx].upperBound > mutationRange.lowerBound && trackedRanges[idx].upperBound < mutationRange.upperBound
            switch (lowerBoundWithinMutation, upperBoundWithinMutation) {
            case (true, true):
                // Range is fully within mutation, collapse it to the start of the mutation
                trackedRanges[idx] = Range(uncheckedBounds: (mutationRange.lowerBound, mutationRange.lowerBound))
            case (true, false):
                // Range starts within mutation but extends beyond mutation - remove portion within mutation
                trackedRanges[idx] = Range(uncheckedBounds: (mutationRange.upperBound, trackedRanges[idx].upperBound))
            case (false, true):
                // Range starts before mutation but extends into mutation - remove portion within mutation
                trackedRanges[idx] = Range(uncheckedBounds: (trackedRanges[idx].lowerBound, mutationRange.lowerBound))
            case (false, false):
                // Neither endpoint of range is within mutation, leave as-is
                break
            }
        }
    }
    
    func _finalizeTrackedIndicesUpdate(mutationStartOffset: Int, isInsertion: Bool, utf8LengthDelta: Int) {
        // Update indices to point to the correct offsets based on the mutation deltas
        for idx in 0 ..< trackedRanges.count {
            var lowerBound = trackedRanges[idx].lowerBound
            var upperBound = trackedRanges[idx].upperBound
            
            // Shift the lower bound if either:
            //      A) The lower bound is greater than the start of the mutation (meaning it must be after the mutation due to the prepare step)
            //      B) The lower bound is equal to the start of the mutation, but the mutation is an insertion (meaning the text is inserted before the start offset)
            if lowerBound.utf8Offset > mutationStartOffset || (lowerBound.utf8Offset == mutationStartOffset && isInsertion), utf8LengthDelta != 0 {
                lowerBound = string.utf8.index(string.startIndex, offsetBy: lowerBound.utf8Offset + utf8LengthDelta)
            } else {
                // Form new indices even if the offsets don't change to ensure the indices are valid in the newly-mutated rope
                string.formIndex(&lowerBound, offsetBy: 0)
            }
            // Shift the upper bound if either:
            //      - The upper bound is greater than the start of the mutation (meaning it must be after the mutation due to the prepare step)
            //      - The lower bound is shifted in any way (which therefore requires the upper bound to be shifted). This is the case when the tracked range is empty and is at the location of an insertion mutation
            if upperBound.utf8Offset > mutationStartOffset || lowerBound != trackedRanges[idx].lowerBound, utf8LengthDelta != 0 {
                upperBound = string.utf8.index(string.startIndex, offsetBy: upperBound.utf8Offset + utf8LengthDelta)
            } else {
                // Form new indices even if the offsets don't change to ensure the indices are valid in the newly-mutated rope
                string.formIndex(&lowerBound, offsetBy: 0)
            }
            
            trackedRanges[idx] = Range(uncheckedBounds: (lowerBound, upperBound))
        }
    }
}

// MARK: - Public API

@available(FoundationPreview 6.2, *)
extension AttributedString {
    /// Tracks the location of the provided range throughout the mutation closure, returning a new, updated range that represents the same effective locations after the mutation
    /// - Parameters:
    ///   - range: a range to track throughout the `mutation` block
    ///   - mutation: a mutating operation, or set of operations, to perform on this `AttributedString`
    /// - Returns: the updated `Range` that is valid after the mutation has been performed, or `nil` if the mutation performed does not allow for tracking to succeed (such as replacing the provided inout variable with an entirely different AttributedString)
    public mutating func transform<E>(updating range: Range<Index>, mutation: (inout AttributedString) throws(E) -> Void) throws(E) -> Range<Index>? {
        try self.transform(updating: [range], mutation: mutation)?.first
    }
    
    /// Tracks the location of the provided ranges throughout the mutation closure, returning a new, updated range that represents the same effective locations after the mutation
    /// - Parameters:
    ///   - index: an index to track throughout the `mutation` block
    ///   - mutation: a mutating operation, or set of operations, to perform on this `AttributedString`
    /// - Returns: the updated `Range`s that is valid after the mutation has been performed, or `nil` if the mutation performed does not allow for tracking to succeed (such as replacing the provided inout variable with an entirely different AttributedString). When the return value is non-nil, the returned array is guaranteed to be the same size as the provided array with updated ranges at the same Array indices as their respective original ranges in the input array.
    public mutating func transform<E>(updating ranges: [Range<Index>], mutation: (inout AttributedString) throws(E) -> Void) throws(E) -> [Range<Index>]? {
        precondition(!ranges.isEmpty, "Cannot update an empty array of ranges")
        
        // Ensure we are uniquely referenced and mutate the tracked ranges to include the new ranges
        ensureUniqueReference()
        let originalCount = _guts.trackedRanges.count
        for range in ranges {
            precondition(range.lowerBound >= self.startIndex && range.lowerBound <= self.endIndex && range.upperBound >= self.startIndex && range.upperBound <= self.endIndex, "AttributedString index is out of bounds")
            _guts.trackedRanges.append(range._bstringRange)
        }
        
        // Perform the user-supplied mutation on `self`
        try mutation(&self)
        
        // Ensure we are still uniquely referenced (it's possible we may have been uniquely referenced before, but the mutation closure created a new reference and we are no longer unique)
        ensureUniqueReference()
        
        // If the `trackedRanges` state is inconsistent, tracking has been lost - simply return nil to indicate ranges are no longer available
        guard _guts.trackedRanges.count == originalCount + ranges.count else {
            return nil
        }
        
        // Collect and remove updated ranges
        let resultingRanges = _guts.trackedRanges[originalCount...].map(\._attrStrRange)
        _guts.trackedRanges.removeSubrange(originalCount...)
        return resultingRanges
    }
}
