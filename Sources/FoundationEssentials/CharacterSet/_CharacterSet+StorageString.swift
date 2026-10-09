//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// for the String-backed. Storage is Unicode scalar

extension _CharacterSet {
    struct StringBacked {

        var guts: [Unicode.Scalar]

        init(guts: [Unicode.Scalar]) {
            self.guts = guts
            self.guts.sort()
        }

        init(sortedGuts: [Unicode.Scalar]) {
            self.guts = sortedGuts
        }

        var isEmpty: Bool {
            guts.isEmpty
        }

        func contains(_ member: Unicode.Scalar) -> Bool {
            let target = member.value
            var low = 0
            var high = guts.count
            while low < high {
                let mid = low + (high - low) / 2
                let value = guts[mid].value
                if value == target {
                    return true
                } else if value < target {
                    low = mid + 1
                } else {
                    high = mid
                }
            }
            return false
        }
        
        // __CFCSetGetBitmap
        // CFCharacterSetHasMemberInPlane
        func hasMemberInBMPPlane(isInverted: Bool) -> Bool {
            if guts.isEmpty {
                return isInverted
            } else {
                return true
            }
        }
    }
}
