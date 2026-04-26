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
    func _searchBoyerMoore(_ needle: borrowing Span<UInt8>, in searchRange: Range<Index>, backwards: Bool) -> Range<Index>? {
        let haystack = span.extracting(_rangeRelativeToStartIndex(searchRange))
        let needleLength = needle.count

        var badCharacterShift = ContiguousArray(repeating: needleLength, count: Int(UInt8.max) + 1)
        var goodSubstringShift = ContiguousArray(repeating: needleLength, count: needleLength)
        var suffixLengths = ContiguousArray(repeating: 0, count: needleLength)
        var badCharacterShiftSpan = badCharacterShift.mutableSpan
        var goodSubstringShiftSpan = goodSubstringShift.mutableSpan
        var suffixLengthsSpan = suffixLengths.mutableSpan

        Self._computeBadCharacterShift(for: needle, backwards: backwards, into: &badCharacterShiftSpan)
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
                if haystack[scanHaystack] == needle[scanNeedle] {
                    scanHaystack += 1
                    scanNeedle += 1
                } else {
                    let shift = Swift.max(
                        badCharacterShift[Int(haystack[scanHaystack])],
                        goodSubstringShift[scanNeedle]
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

    @_lifetime(badCharacterShift: copy badCharacterShift)
    private static func _computeBadCharacterShift(
        for needle: borrowing Span<UInt8>,
        backwards: Bool,
        into badCharacterShift: inout MutableSpan<Int>
    ) {
        if backwards {
            for i in (0..<needle.count).reversed() {
                badCharacterShift[Int(needle[i])] = i
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
        for needle: borrowing Span<UInt8>,
        backwards: Bool,
        shift: inout MutableSpan<Int>,
        suffixLengths: inout MutableSpan<Int>
    ) {
        if backwards {
            var reversedNeedle = ContiguousArray(repeating: UInt8.zero, count: needle.count)
            var reversedNeedleSpan = reversedNeedle.mutableSpan
            for i in 0..<needle.count {
                reversedNeedleSpan[i] = needle[needle.count - 1 - i]
            }

            Self._computeGoodSubstringShift(
                for: reversedNeedleSpan.span,
                shift: &shift,
                suffixLengths: &suffixLengths
            )
            Self._reverse(&shift)
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
        for needle: borrowing Span<UInt8>,
        shift: inout MutableSpan<Int>,
        suffixLengths: inout MutableSpan<Int>
    ) {
        let needleLength = needle.count

        var f = needleLength - 1
        var g = needleLength - 1
        suffixLengths[needleLength - 1] = needleLength

        for i in (0..<(needleLength - 1)).reversed() {
            if i > g, suffixLengths[i + needleLength - 1 - f] < i - g {
                suffixLengths[i] = suffixLengths[i + needleLength - 1 - f]
            } else {
                if i < g {
                    g = i
                }
                f = i
                while g >= 0, needle[g] == needle[g + needleLength - 1 - f] {
                    g -= 1
                }
                suffixLengths[i] = f - g
            }
        }

        var j = 0
        for i in (0..<needleLength).reversed() {
            if suffixLengths[i] == i + 1 {
                while j < needleLength - 1 - i {
                    if shift[j] == needleLength {
                        shift[j] = needleLength - 1 - i
                    }
                    j += 1
                }
            }
        }

        for i in 0..<(needleLength - 1) {
            shift[needleLength - 1 - suffixLengths[i]] = needleLength - 1 - i
        }

        for i in 0..<(needleLength - 1) {
            shift[i] += needleLength - 1 - i
        }
    }

    @_lifetime(span: copy span)
    private static func _reverse(_ span: inout MutableSpan<Int>) {
        var lowerBound = 0
        var upperBound = span.count - 1

        while lowerBound < upperBound {
            let tmp = span[lowerBound]
            span[lowerBound] = span[upperBound]
            span[upperBound] = tmp
            lowerBound += 1
            upperBound -= 1
        }
    }
}
