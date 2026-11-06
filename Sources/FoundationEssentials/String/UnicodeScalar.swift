//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
@_spi(_Unicode) import Swift
internal import CoreFoundation_Private.CFString
#endif // FOUNDATION_FRAMEWORK

extension UnicodeScalar {
    func _toHalfWidth() -> Self {
#if FOUNDATION_FRAMEWORK // TODO: Implement `CFUniCharCompatibilityDecompose` in Swift
        if value >= 0xFF00 && value < 0xFFEF {
            var halfWidth = value
            CFUniCharCompatibilityDecompose(&halfWidth, 1, 1)
            return UnicodeScalar(halfWidth)!
        } else {
            return self
        }
#else
        let forms = UnicodeScalarMappingData.halfwidthAndFullwidthForms
        let index = Int(value) - Int(UnicodeScalarMappingData.halfwidthAndFullwidthFormsStart)
        guard index >= 0, index < forms.count else {
            return self
        }
        return UnicodeScalar(forms[index]) ?? self
#endif
    }

    var _isGraphemeExtend: Bool {
        return BuiltInUnicodeScalarSet.graphemeExtends.contains(self)
    }

    var _isCanonicalDecomposable: Bool {
        return BuiltInUnicodeScalarSet.canonicalDecomposables.contains(self)
    }

    func _stripDiacritics() -> Self {
        guard _isCanonicalDecomposable else {
            return self
        }

#if FOUNDATION_FRAMEWORK // TODO: Implement `CFUniCharDecomposeCharacter` in Swift
        var stripped: UInt32? = nil
        withUnsafeTemporaryAllocation(of: UTF32Char.self, capacity: 64) { ptr in
            guard let base = ptr.baseAddress else {
                return
            }
            let len = CFUniCharDecomposeCharacter(value, base, ptr.count)
            if len > 0 {
                if ptr[0] < 0x0510 {
                    stripped = ptr[0]
                }
            }
        }

        return stripped != nil ? UnicodeScalar(stripped!)! : self
#else
        let entries = UnicodeScalarMappingData.diacriticStripping
        let baseMask: UInt32 = 1 << UnicodeScalarMappingData.diacriticStrippingBaseBitCount - 1
        guard let index = entries.lastIndex(notAbove: value << UnicodeScalarMappingData.diacriticStrippingBaseBitCount | baseMask),
              entries[index] >> UnicodeScalarMappingData.diacriticStrippingBaseBitCount == value,
              let base = UnicodeScalar(entries[index] & baseMask) else {
            return self
        }
        return base
#endif // FOUNDATION_FRAMEWORK
    }

    var _caseFoldMapping : String {
#if FOUNDATION_FRAMEWORK // TODO: Expose Case Mapping Data without @_spi(_Unicode)
        return self.properties._caseFolded
#else
        if isASCII {
            return String(UnicodeScalar(UInt8(ascii: self)._lowercased))
        }
        let entries = UnicodeScalarMappingData.caseFolding
        guard let index = entries.lastIndex(notAbove: CaseFoldingEntry.searchBound(for: value)) else {
            return String(self)
        }
        let entry = CaseFoldingEntry(entries[index])
        let offset = value - entry.first
        guard offset < entry.count * entry.stride, offset % entry.stride == 0 else {
            return String(self)
        }
        guard !entry.isExpansion else {
            var result = ""
            let expansions = UnicodeScalarMappingData.caseFoldingExpansions
            let start = Int(entry.payload) * UnicodeScalarMappingData.caseFoldingExpansionLength
            for index in start ..< start + UnicodeScalarMappingData.caseFoldingExpansionLength {
                if let scalar = UnicodeScalar(expansions[index]), scalar.value != 0 {
                    result.unicodeScalars.append(scalar)
                }
            }
            return result
        }
        guard let folded = UnicodeScalar(value &+ entry.payload) else {
            return String(self)
        }
        return String(folded)
#endif
    }
}

#if !FOUNDATION_FRAMEWORK
// TODO: Use the standard library for case folding and decomposition once it exposes them (https://github.com/swiftlang/swift/issues/58697)
/// One entry of `UnicodeScalarMappingData.caseFolding`.
private struct CaseFoldingEntry {
    let first: UInt32
    let count: UInt32
    let stride: UInt32
    let isExpansion: Bool
    let payload: UInt32

    init(_ rawValue: UInt64) {
        first = UInt32(truncatingIfNeeded: rawValue >> UnicodeScalarMappingData.caseFoldingFirstShift)
        count = UInt32(truncatingIfNeeded: (rawValue >> UnicodeScalarMappingData.caseFoldingCountShift) & UnicodeScalarMappingData.caseFoldingCountMask)
        stride = rawValue & UnicodeScalarMappingData.caseFoldingStrideIsTwoBit != 0 ? 2 : 1
        isExpansion = rawValue & UnicodeScalarMappingData.caseFoldingIsExpansionBit != 0
        payload = UInt32(truncatingIfNeeded: rawValue)
    }

    /// The largest raw value of an entry that starts at `value`.
    static func searchBound(for value: UInt32) -> UInt64 {
        let firstShift = UnicodeScalarMappingData.caseFoldingFirstShift
        return UInt64(value) << firstShift | (1 << firstShift - 1)
    }
}

extension Span where Element: FixedWidthInteger {
    /// The index of the last element that is less than or equal to `bound`, in a span sorted in ascending order.
    fileprivate func lastIndex(notAbove bound: Element) -> Int? {
        var low = 0
        var high = count
        while low < high {
            let middle = low + (high - low) / 2
            if self[middle] <= bound {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low > 0 ? low - 1 : nil
    }
}
#endif // !FOUNDATION_FRAMEWORK
