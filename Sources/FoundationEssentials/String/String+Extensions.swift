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

extension Character {
    var _isExtendCharacter: Bool {
        guard !self.isASCII else {
            return false
        }

        return unicodeScalars.allSatisfy { $0._isGraphemeExtend }
    }

}

extension Substring.UnicodeScalarView {
    func _rangeOfCharacter(from set: CharacterSet, anchored: Bool, backwards: Bool) -> Range<Index>? {
        guard !isEmpty else { return nil }

        let fromLoc: String.Index
        let toLoc: String.Index
        let step: Int
        if backwards {
            fromLoc = index(before: endIndex)
            toLoc = anchored ? fromLoc : startIndex
            step = -1
        } else {
            fromLoc = startIndex
            toLoc = anchored ? fromLoc : index(before: endIndex)
            step = 1
        }

        var done = false
        var found = false

        var idx = fromLoc
        while !done {
            let ch = self[idx]
            if set.contains(ch) {
                done = true
                found = true
            } else if idx == toLoc {
                done = true
            } else {
                formIndex(&idx, offsetBy: step)
            }
        }

        guard found else { return nil }
        return idx..<index(after: idx)
    }
}
