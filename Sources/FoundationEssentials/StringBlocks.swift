//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

extension UTF8.CodeUnit {
    static let newline: Self = 0x0A
    static let carriageReturn: Self = 0x0D
}

extension String {
    struct _BlockSearchingOptions : OptionSet {
        let rawValue: Int
        
        static let findStart = Self(rawValue: 1 << 0)
        static let findEnd = Self(rawValue: 1 << 1)
        static let findContentsEnd = Self(rawValue: 1 << 2)
        static let stopAtLineSeparators = Self(rawValue: 1 << 3)
    }
    
    static let paragraphSeparators : [[UTF8.CodeUnit]] = [
        [0xE2, 0x80, 0xA9] // U+2029 Paragraph Separator
    ]
    
    static let lineSeparators : [[UTF8.CodeUnit]] = paragraphSeparators + [
        [0xE2, 0x80, 0xA8], // U+2028 Line Separator
        [0xC2, 0x85] // U+0085 <Next Line> (NEL)
    ]
}

struct _StringBlock<Index> {
    let start: Index?
    let end: Index?
    let contentsEnd: Index?
}

extension BidirectionalCollection where Element == UTF8.CodeUnit {

    // Returns the index range the separator if a match is found. This always rewinds the start index to that of "\r" in the case where "\r\n" is present.
    private func _matchesSeparators(_ separators: [[UTF8.CodeUnit]], from start: Index, reverse: Bool = false) -> Range<Index>? {
        let startingCharacter = self[start]

        // Special case when startingCharacter is "\r" or "\n" in "\r\n"
        if startingCharacter == .carriageReturn {
            let next = index(after: start)
            if next < endIndex && self[next] == .newline {
                return start..<index(after: next)
            } else {
                return start..<index(after: start)
            }
        } else if startingCharacter == .newline {
            if start > startIndex {
                let idxBefore = index(before: start)
                if self[idxBefore] == .carriageReturn {
                    return idxBefore..<index(after: start)
                } else {
                    return start..<index(after: start)
                }
            } else {
                return start..<index(after: start)
            }
        }
        if reverse {
            if startingCharacter < 0x85 || startingCharacter > 0xA9 {
                return nil
            }
        } else {
            if startingCharacter < 0xC2 || startingCharacter > 0xE2 {
                return nil
            }
        }
        for separator in separators {
            var matches = true
            var strIdx = start
            var separatorIdx = reverse ? separator.count - 1 : 0
            while strIdx >= startIndex && strIdx < endIndex && separatorIdx >= 0 && separatorIdx < separator.count {
                if separator[separatorIdx] != self[strIdx] {
                    matches = false
                    break
                }
                strIdx = reverse ? index(before: strIdx) : index(after: strIdx)
                separatorIdx += reverse ? -1 : 1
            }
            if matches {
                return reverse ? index(after: strIdx)..<index(after: start) : start ..< strIdx
            }
        }
        return nil
    }

    // Based on -[NSString _getBlockStart:end:contentsEnd:forRange:]
    func _getBlock(
        for options: String._BlockSearchingOptions,
        in inputRangeExpr: some RangeExpression<Index>
    ) -> _StringBlock<Index> {
        let range = inputRangeExpr.relative(to: self)
        return _getBlock(for: options, in: range)
    }

    func _getBlock(
        for options: String._BlockSearchingOptions,
        in range: Range<Index>
    ) -> _StringBlock<Index> {
        let fullStringRange = startIndex ..< endIndex

        guard !(range == fullStringRange && !options.contains(.findContentsEnd)) else {
            return _StringBlock(start: startIndex, end: endIndex, contentsEnd: nil)
        }

        guard range.lowerBound >= startIndex && range.upperBound <= endIndex else {
            return _StringBlock(start: startIndex, end: endIndex, contentsEnd: endIndex)
        }

        let separatorCharacters = options.contains(.stopAtLineSeparators) ? String.lineSeparators : String.paragraphSeparators
        
        var start: Index? = nil
        if options.contains(.findStart) {
            if range.lowerBound == startIndex {
                start = startIndex
            } else {
                var idx = index(before: range.lowerBound)

                // Special case where start is between \r and \n
                if range.lowerBound < endIndex && self[range.lowerBound] == .newline && self[idx] == .carriageReturn {
                    if idx > startIndex {
                        idx = index(before: idx)
                    } else {
                        start = startIndex
                    }
                }

                while start == nil, idx >= startIndex, idx < endIndex {
                     if let _ = _matchesSeparators(separatorCharacters, from: idx, reverse: true) {
                         start = index(after: idx)
                         break
                     }
                     if idx > startIndex {
                         idx = index(before: idx)
                     } else {
                         start = startIndex
                         break
                     }
                }

                if start == nil {
                    start = idx
                }
            }
        }
        
        var end: Index? = nil
        var contentsEnd: Index? = nil
        if options.contains(.findEnd) || options.contains(.findContentsEnd) {
            var idx = range.upperBound
            if !range.isEmpty {
                idx = index(before: idx)
            }

            if idx < endIndex, let separatorR = _matchesSeparators(separatorCharacters, from: idx, reverse: true) {
                // When range.upperBound falls on the end of a multi-code-unit separator, walk backwards to find the start of the separator
                end = separatorR.upperBound
                contentsEnd = separatorR.lowerBound
            } else {
                while idx < endIndex {
                    if let separatorR = _matchesSeparators(separatorCharacters, from: idx) {
                        contentsEnd = separatorR.lowerBound
                        end = separatorR.upperBound
                        break
                    }
                    idx = index(after: idx)
                }

                if idx == endIndex {
                    contentsEnd = idx
                    end = idx
                }
            }
        }

        return _StringBlock(start: start, end: end, contentsEnd: contentsEnd)
    }
}
