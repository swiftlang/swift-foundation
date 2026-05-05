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

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {
    func _searchBoyerMoore(_ needle: Span<UInt8>, in searchRange: Range<Index>, backwards: Bool) -> Range<Index>? {
        let haystack = span.extracting(_rangeRelativeToStartIndex(searchRange))
        let needleLength = needle.count

        var badCharacterShift: InlineArray<256, Int> = .init(repeating: needleLength)
        var badCharacterShiftSpan = badCharacterShift.mutableSpan

        Self._computeBadCharacterShift(for: needle, backwards: backwards, into: &badCharacterShiftSpan)

        return withUnsafeTemporaryAllocation(of: Int.self, capacity: needleLength) { goodSubstringShift in
            goodSubstringShift.initialize(repeating: needleLength)

            return withUnsafeTemporaryAllocation(of: Int.self, capacity: needleLength) { suffixLengths in
                suffixLengths.initialize(repeating: 0)

                var goodSubstringShiftSpan = goodSubstringShift.mutableSpan
                var suffixLengthsSpan = suffixLengths.mutableSpan

                Self._computeGoodSubstringShift(
                    for: needle,
                    backwards: backwards,
                    shift: &goodSubstringShiftSpan,
                    suffixLengths: &suffixLengthsSpan
                )

                if backwards {
                    var scanNeedle = 0
                    var scanHaystack = haystack.count - needleLength

                    while scanHaystack >= 0, scanNeedle < needleLength {
                        // Use unchecked accesses in this descending search loop to avoid bounds checks that are not
                        // currently eliminated. scanNeedle is guarded by the loop condition. scanHaystack starts at
                        // the last possible match position; matches advance it in lockstep with scanNeedle, and
                        // mismatches are revalidated by the loop condition.
                        let haystackByte = haystack[unchecked: scanHaystack]
                        if haystackByte == needle[unchecked: scanNeedle] {
                            scanHaystack += 1
                            scanNeedle += 1
                        } else {
                            let shift = Swift.max(
                                badCharacterShift[Int(haystackByte)],
                                goodSubstringShiftSpan[unchecked: scanNeedle]
                            )
                            scanHaystack -= shift
                            scanNeedle = 0
                        }
                    }

                    guard scanNeedle == needleLength else {
                        return nil
                    }

                    let lowerBound = searchRange.lowerBound + scanHaystack - needleLength
                    return lowerBound..<(lowerBound + needleLength)
                } else {
                    var scanNeedle = needleLength - 1
                    var scanHaystack = needleLength - 1

                    while scanHaystack < haystack.count, scanNeedle >= 0 {
                        if haystack[scanHaystack] == needle[scanNeedle] {
                            scanHaystack -= 1
                            scanNeedle -= 1
                        } else {
                            let shift = Swift.max(
                                badCharacterShift[Int(haystack[scanHaystack])],
                                goodSubstringShift[scanNeedle]
                            )
                            scanHaystack += shift
                            scanNeedle = needleLength - 1
                        }
                    }

                    guard scanNeedle < 0 else {
                        return nil
                    }

                    let lowerBound = searchRange.lowerBound + scanHaystack + 1
                    return lowerBound..<(lowerBound + needleLength)
                }
            }
        }
    }

    @_lifetime(badCharacterShift: copy badCharacterShift)
    private static func _computeBadCharacterShift(
        for needle: Span<UInt8>,
        backwards: Bool,
        into badCharacterShift: inout MutableSpan<Int>
    ) {
        if backwards {
            for i in (0..<needle.count).reversed() {
                // i stays within 0..<needle.count, so safe to use the unchecked subscript.
                badCharacterShift[Int(needle[unchecked: i])] = i
            }
        } else {
            for i in 0..<needle.count {
                badCharacterShift[Int(needle[i])] = needle.count - i - 1
            }
        }
    }

    @_lifetime(shift: copy shift)
    @_lifetime(suffixLengths: copy suffixLengths)
    private static func _computeGoodSubstringShift(
        for needle: Span<UInt8>,
        backwards: Bool,
        shift: inout MutableSpan<Int>,
        suffixLengths: inout MutableSpan<Int>
    ) {
        if backwards {
            // To get the correct shift table for backwards search reverse the needle, compute the forwards shift
            // table, and then reverse the result.
            withUnsafeTemporaryAllocation(of: UInt8.self, capacity: needle.count) { reversedNeedle in
                for offset in 0..<needle.count {
                    // offset is in 0..<needle.count, so the mirrored index is in the same range.
                    reversedNeedle.initializeElement(at: offset, to: needle[unchecked: needle.count - 1 - offset])
                }

                Self._computeGoodSubstringShift(
                    for: reversedNeedle.span,
                    shift: &shift,
                    suffixLengths: &suffixLengths
                )
                Self._reverse(&shift)
            }
        } else {
            Self._computeGoodSubstringShift(
                for: needle,
                shift: &shift,
                suffixLengths: &suffixLengths
            )
        }
    }

    @_lifetime(shift: copy shift)
    @_lifetime(suffixLengths: copy suffixLengths)
    private static func _computeGoodSubstringShift(
        for needle: Span<UInt8>,
        shift: inout MutableSpan<Int>,
        suffixLengths: inout MutableSpan<Int>
    ) {
        let needleLength = needle.count

        // Compute suffix lengths

        var matchEnd = needleLength - 1
        var matchBound = needleLength - 1
        suffixLengths[needleLength - 1] = needleLength

        for candidateEnd in (0..<(needleLength - 1)).reversed() {
            // candidateEnd walks down through 0..<(needleLength - 1). The Boyer-Moore suffix invariants keep
            // matchEnd in candidateEnd..<needleLength, so the derived suffix index is in 0..<needleLength.
            if candidateEnd > matchBound,
               suffixLengths[unchecked: candidateEnd + needleLength - 1 - matchEnd] < candidateEnd - matchBound {
                suffixLengths[unchecked: candidateEnd] = suffixLengths[unchecked: candidateEnd + needleLength - 1 - matchEnd]
            } else {
                if candidateEnd < matchBound {
                    matchBound = candidateEnd
                }
                matchEnd = candidateEnd
                // matchBound is checked before indexing and then only decreases. The paired suffix index is bounded
                // by matchEnd, keeping both needle indices in 0..<needleLength while the loop runs.
                while matchBound >= 0, needle[unchecked: matchBound] == needle[unchecked: matchBound + needleLength - 1 - matchEnd] {
                    matchBound -= 1
                }
                // candidateEnd is produced by the descending loop above, so it is in bounds.
                suffixLengths[unchecked: candidateEnd] = matchEnd - matchBound
            }
        }

        // Compute shift table

        var shiftIndex = 0
        for i in (0..<needleLength).reversed() {
            // i stays within 0..<needleLength, so safe to use the unchecked subscript.
            if suffixLengths[unchecked: i] == i + 1 {
                while shiftIndex < needleLength - 1 - i {
                    // shiftIndex is strictly less than needleLength - 1 - i, which is at most needleLength - 1.
                    if shift[unchecked: shiftIndex] == needleLength {
                        shift[unchecked: shiftIndex] = needleLength - 1 - i
                    }
                    shiftIndex += 1
                }
            }
        }

        // Set the amount of shift necessary to move each of the suffix matches found into a position where it
        // overlaps with the suffix. If there are duplicate matches the latest one is the one that should take effect.
        for i in 0..<(needleLength - 1) {
            shift[needleLength - 1 - suffixLengths[i]] = needleLength - 1 - i
        }

        // Since the Boyer-Moore algorithm moves the pointer back while scanning substrings, add the distance to the
        // end of the potential substring.
        for i in 0..<(needleLength - 1) {
            shift[i] += needleLength - 1 - i
        }
    }

    @_lifetime(span: copy span)
    private static func _reverse(_ span: inout MutableSpan<Int>) {
        var lowerBound = 0
        var upperBound = span.count - 1

        while lowerBound < upperBound {
            // lowerBound and upperBound move toward each other from valid endpoints, and the loop stops before
            // they cross.
            let tmp = span[unchecked: lowerBound]
            span[unchecked: lowerBound] = span[unchecked: upperBound]
            span[unchecked: upperBound] = tmp
            lowerBound += 1
            upperBound -= 1
        }
    }
}
