//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

extension BidirectionalCollection where Index == String.Index {
    internal func _alignIndex(roundingDown i: Index) -> Index {
        return i < endIndex ? index(before: index(after: i)) : i
    }

    internal func _alignIndex(roundingUp i: Index) -> Index {
        let truncated = _alignIndex(roundingDown: i)
        if i > truncated && i < endIndex {
            return index(after: i)
        } else {
            return i
        }
    }

    internal func _boundaryAlignedRange<R: RangeExpression>(_ r: R) -> Range<Index> where R.Bound == String.Index {
        let range = r.relative(to: self)
        return _alignIndex(roundingDown: range.lowerBound)..<_alignIndex(roundingUp: range.upperBound)
    }

    internal func _checkRange(_ r: Range<Index>) -> Range<Index>? {
        guard r.lowerBound >= startIndex, r.upperBound <= endIndex else {
            return nil
        }
        return r
    }
}
