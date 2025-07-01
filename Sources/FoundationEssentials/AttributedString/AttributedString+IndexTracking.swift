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

@available(FoundationAttributedString 5.5, *)
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
            
            // Shift the lower bound if the mutation changed the length of the string and either of the following are true:
            //      A) The lower bound is greater than the start of the mutation (meaning it must be after the mutation due to the prepare step)
            //      B) The lower bound is equal to the start of the mutation, but the mutation is an insertion (meaning the text is inserted before the start offset)
            if lowerBound.utf8Offset > mutationStartOffset || (lowerBound.utf8Offset == mutationStartOffset && isInsertion), utf8LengthDelta != 0 {
                lowerBound = string.utf8.index(string.startIndex, offsetBy: lowerBound.utf8Offset + utf8LengthDelta)
            } else {
                // Form new indices even if the offsets don't change to ensure the indices are valid in the newly-mutated rope
                string.utf8.formIndex(&lowerBound, offsetBy: 0)
            }
            // Shift the upper bound if the mutation changed the length of the string and either of the following are true:
            //      A) The upper bound is greater than the start of the mutation (meaning it must be after the mutation due to the prepare step)
            //      B) The lower bound is shifted in any way (which therefore requires the upper bound to be shifted). This is the case when the tracked range is empty and is at the location of an insertion mutation
            if upperBound.utf8Offset > mutationStartOffset || lowerBound != trackedRanges[idx].lowerBound, utf8LengthDelta != 0 {
                upperBound = string.utf8.index(string.startIndex, offsetBy: upperBound.utf8Offset + utf8LengthDelta)
            } else {
                // Form new indices even if the offsets don't change to ensure the indices are valid in the newly-mutated rope
                string.utf8.formIndex(&lowerBound, offsetBy: 0)
            }
            
            trackedRanges[idx] = Range(uncheckedBounds: (lowerBound, upperBound))
        }
    }
}

// MARK: - Public API

@available(FoundationAttributedString 6.2, *)
extension AttributedString {
    // MARK: inout API
    
    /// Tracks the location of the provided range throughout the mutation closure, updating the provided range to one that represents the same effective locations after the mutation.
    ///
    /// If updating the provided range is not possible (tracking failed) then this function will fatal error. Use the `Optional`-returning variants to provide custom fallback behavior.
    /// - Parameters:
    ///   - range: A range to track throughout the `body` closure.
    ///   - body: A mutating operation, or set of operations, to perform on the value of `self`. The value of `self` is provided to the closure as an `inout AttributedString` that the closure should mutate directly. Do not capture the value of `self` in the provided closure - the closure should mutate the provided `inout` copy.
    public mutating func transform<E>(updating range: inout Range<Index>, body: (inout AttributedString) throws(E) -> Void) throws(E) -> Void {
        guard let result = try self.transform(updating: range, body: body) else {
            fatalError("The provided mutation body did not allow for maintaining index tracking. Ensure that your mutation body mutates the provided AttributedString instead of replacing it with a different AttributedString or use the non-inout version of transform(updating:body:) which returns an Optional value to provide fallback behavior.")
        }
        range = result
    }
    
    /// Tracks the location of the provided ranges throughout the mutation closure, updating them to new ranges that represent the same effective locations after the mutation. 
    ///
    /// If updating the provided ranges is not possible (tracking failed) then this function will fatal error. Use the `Optional`-returning variants to provide custom fallback behavior.
    /// - Parameters:
    ///   - ranges: A list of ranges to track throughout the `body` closure. The updated array (after the function is called) is guaranteed to be the same size as the provided array. Updated ranges are located at the same indices as their respective original ranges in the input `ranges` array.
    ///   - body: A mutating operation, or set of operations, to perform on the value of `self`. The value of `self` is provided to the closure as an `inout AttributedString` that the closure should mutate directly. Do not capture the value of `self` in the provided closure - the closure should mutate the provided `inout` copy.
    public mutating func transform<E>(updating ranges: inout [Range<Index>], body: (inout AttributedString) throws(E) -> Void) throws(E) -> Void {
        guard let result = try self.transform(updating: ranges, body: body) else {
            fatalError("The provided mutation body did not allow for maintaining index tracking. Ensure that your mutation body mutates the provided AttributedString instead of replacing it with a different AttributedString or use the non-inout version of transform(updating:body:) which returns an Optional value to provide fallback behavior.")
        }
        ranges = result
    }
    
    // MARK: Optional-returning API
    
    /// Tracks the location of the provided range throughout the mutation closure, returning a new, updated range that represents the same effective locations after the mutation.
    /// - Parameters:
    ///   - range: A range to track throughout the `body` block.
    ///   - body: A mutating operation, or set of operations, to perform on this `AttributedString`.
    /// - Returns: the updated `Range` that is valid after the mutation has been performed, or `nil` if the mutation performed does not allow for tracking to succeed (such as replacing the provided inout variable with an entirely different `AttributedString`).
    public mutating func transform<E>(updating range: Range<Index>, body: (inout AttributedString) throws(E) -> Void) throws(E) -> Range<Index>? {
        try self.transform(updating: [range], body: body)?.first
    }
    
    /// Tracks the location of the provided ranges throughout the mutation closure, returning a new, updated range that represents the same effective locations after the mutation
    /// - Parameters:
    ///   - ranges: Ranges to track throughout the `body` block.
    ///   - body: A mutating operation, or set of operations, to perform on this `AttributedString`.
    /// - Returns: the updated `Range`s that are valid after the mutation has been performed or `nil` if the mutation performed does not allow for tracking to succeed (such as replacing the provided inout variable with an entirely different `AttributedString`). When the return value is non-`nil`, the returned array is guaranteed to be the same size as the provided array with updated ranges at the same indices as their respective original ranges in the input array.
    public mutating func transform<E>(updating ranges: [Range<Index>], body: (inout AttributedString) throws(E) -> Void) throws(E) -> [Range<Index>]? {
        precondition(!ranges.isEmpty, "Cannot update an empty array of ranges")
        
        // Ensure we are uniquely referenced and mutate the tracked ranges to include the new ranges
        ensureUniqueReference()
        let originalCount = _guts.trackedRanges.count
        for range in ranges {
            precondition(range.lowerBound >= self.startIndex && range.upperBound <= self.endIndex, "AttributedString index is out of bounds")
            _guts.trackedRanges.append(range._bstringRange)
        }
        
        // Catch and store any error thrown during mutation here so that we can do any appropriate cleanup afterwards
        // We don't use a defer block here because the return value (returned indices) is dependent upon the effects of the cleanup (the ensureUniqueReference() call may change the version that should be stored within the indices)
        var thrownError: E?
        do {
            try body(&self)
        } catch {
            thrownError = error
        }
        
        // Ensure we are still uniquely referenced (it's possible we may have been uniquely referenced before, but the mutation closure created a new reference - even if it threw an error - and we are no longer unique)
        // We also must ensure that any indices returned from this function are created after this call so that they are initialized with the updated version number
        ensureUniqueReference()
        
        // If the `trackedRanges` state is inconsistent, tracking has been lost. The best we can do to validate consistent state is to ensure we have the correct number of ranges
        guard _guts.trackedRanges.count == originalCount + ranges.count else {
            // Clear the ranges to prevent any future lingering tracking issues with this AttributedString
            _guts.trackedRanges = []
            if let thrownError {
                throw thrownError
            }
            return nil
        }
        
        defer {
            // Tracking state is consistent, so make sure we remove the ranges we added earlier (whether we throw or whether we use these ranges in the return value
            // Only remove those ranges added above in order to support recursive tracking
            _guts.trackedRanges.removeSubrange(originalCount...)
        }
        
        if let thrownError {
            throw thrownError
        }
        
        return _guts.trackedRanges.suffix(from: originalCount).map {
            $0._attributedStringRange(version: _guts.version)
        }
    }
}
