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

extension _CharacterSet {
    struct RangeBacked {
        
        var closedRange: ClosedRange<Unicode.Scalar>
        
        init(range: Range<Unicode.Scalar>) {
            // NOTE: 0xD800 - 0xDFFF are supposed to be invalid.
            // We need to handle some special cases here, as follows:
            // Case 1: Developers can make range such as 0xD700..<0xE000,
            // but because we default to converting it to closedRange,
            // making a closedRange with 0xD700...0xDFFF will crash.
            // We should not crash and instead initialize 0xD700...0xD7FF (up to valid upper bound).
            
            // Case 2: Developers can make range such as 0x0000..<0x10FFFF
            // Even though it includes the range 0xD800...0xDFFF, we don't have to handle it
            // because if there were to be a case where we have to check contains(), which takes a Unicode.Scalar,
            // checking surrogate value should just crash because they'd have to force unwrap before calling into contains().
            
            if let closedUpperBound = Unicode.Scalar(range.upperBound.value - 1) {
                // Closed upper bound is not within 0xD800 - 0xDFFF
                self.closedRange = range.lowerBound...closedUpperBound
            } else {
                // If it even gets here, it means lower bound is guaranteed to be at most 0xD7FF.
                // Closed upper bound is within 0xD800 - 0xDFFF, clamp the upper bound to 0xD7FF.
                let surrogateStart = 0xD800
                let clampedClosedUpperBound = surrogateStart - 1
                self.closedRange = range.lowerBound...UnicodeScalar(clampedClosedUpperBound)!
            }
        }
        
        init(range: ClosedRange<Unicode.Scalar>) {
            self.closedRange = range
        }
        
        internal var isEmpty: Bool {
            return closedRange.isEmpty
        }
        
        internal func contains(_ member: Unicode.Scalar) -> Bool {
            return closedRange.contains(member)
        }
        
        internal func contains(surrogate codepoint: UInt16) -> Bool {
            let value = UInt32(codepoint)
            return closedRange.lowerBound.value <= value && value <= closedRange.upperBound.value
        }
        
        internal func bytesNeeded(isInverted: Bool) -> Int {
            // BMP plane has 8192 bytes by default
            var totalBytes = 8192
            
            var numNonBMPPlanes = 0

            let endPlane = Int(closedRange.upperBound.value >> 16)
            if endPlane > 0 || isInverted {
                let firstChar = closedRange.lowerBound.value
                let lastChar = closedRange.upperBound.value
                let firstPlane = Int(firstChar >> 16)
                let lastPlane = Int(lastChar >> 16)
                
                if lastPlane > 0 {
                    numNonBMPPlanes = lastPlane - max(firstPlane, 1) + 1
                    if isInverted {
                        numNonBMPPlanes = _CharacterSet.MAX_ANNEX_PLANE - numNonBMPPlanes
                        let positionOfFirstCharInPlane = firstChar & 0xFFFF
                        let positionOfLastCharInPlane = lastChar & 0xFFFF
                        if firstPlane == lastPlane {
                            if positionOfFirstCharInPlane > 0 || positionOfLastCharInPlane < 0xFFFF {
                                numNonBMPPlanes += 1
                            }
                        } else {
                            if firstPlane > 0 && positionOfFirstCharInPlane > 0 {
                                numNonBMPPlanes += 1
                            }
                            if positionOfLastCharInPlane < 0xFFFF {
                                numNonBMPPlanes += 1
                            }
                        }
                    }
                } else if isInverted {
                    numNonBMPPlanes = _CharacterSet.MAX_ANNEX_PLANE
                }
            }
            
            totalBytes += numNonBMPPlanes * (8192 + 1)
            return totalBytes
        }
        
        internal func bitmapRepresentation(isInverted: Bool) -> Data {
            let totalBytes = bytesNeeded(isInverted: isInverted)

            // Initialize with all 0xFF (inverted) or 0x00 (not inverted)
            var data = isInverted ? _CharacterSet.allOnes(count: totalBytes) : _CharacterSet.allZeros(count: totalBytes)

            var mutableSpan = data.mutableSpan

            let firstScalar = closedRange.lowerBound.value
            let lastScalar = closedRange.upperBound.value
            let firstPlane = Int(firstScalar >> 16)
            let lastPlane = Int(lastScalar >> 16)

            // Process BMP plane (plane 0)
            if firstPlane == 0 {
                let bmpEnd: UInt32 = (lastPlane == 0) ? (lastScalar & 0xFFFF) : 0xFFFF
                var bmpSpan = mutableSpan._mutatingExtracting(0..<8192)
                if isInverted {
                    _CharacterSet.removeCharacters(from: &bmpSpan, firstChar: firstScalar & 0xFFFF, lastChar: bmpEnd)
                } else {
                    _CharacterSet.addCharacters(to: &bmpSpan, firstChar: firstScalar & 0xFFFF, lastChar: bmpEnd)
                }
            }

            // Single pass over non-BMP planes: write headers and flip range bits.
            if totalBytes > 8192 {
                var slot = 0
                for plane in 1..._CharacterSet.MAX_ANNEX_PLANE {
                    guard hasMember(inPlane: UInt8(plane), isInverted: isInverted) else { continue }

                    let headerOffset = 8192 + slot * 8193
                    mutableSpan[headerOffset] = UInt8(plane)

                    // If this plane is touched by the range, flip the appropriate bits
                    if plane >= firstPlane && plane <= lastPlane {
                        let planeStart: UInt32 = (plane == firstPlane) ? (firstScalar & 0xFFFF) : 0
                        let planeEnd: UInt32 = (plane == lastPlane) ? (lastScalar & 0xFFFF) : 0xFFFF
                        let planeDataOffset = headerOffset + 1
                        var planeSpan = mutableSpan._mutatingExtracting(planeDataOffset..<(planeDataOffset + 8192))
                        if isInverted {
                            _CharacterSet.removeCharacters(from: &planeSpan, firstChar: planeStart, lastChar: planeEnd)
                        } else {
                            _CharacterSet.addCharacters(to: &planeSpan, firstChar: planeStart, lastChar: planeEnd)
                        }
                    }
                    slot += 1
                }
            }

            return data
        }
        
        // CFCharacterSetHasMemberInPlane
        func hasMember(inPlane plane: UInt8, isInverted: Bool) -> Bool {
            var firstChar: UInt32 = closedRange.lowerBound.value
            var lastChar: UInt32 = closedRange.upperBound.value
            let firstPlane = Int(firstChar >> 16)
            let lastPlane = Int(lastChar >> 16)
            
            if isInverted {
                if plane < firstPlane || plane > lastPlane {
                    return true
                } else if plane > firstPlane && plane < lastPlane {
                    return false
                } else {
                    firstChar &= 0xFFFF
                    lastChar &= 0xFFFF
                    if plane == firstPlane {
                        if firstChar != 0 {
                            return true
                        } else if firstPlane == lastPlane && lastChar != 0xFFFF {
                            return true
                        } else {
                            return false
                        }
                    } else {
                        if lastChar != 0xFFFF {
                            return true
                        } else if firstPlane == lastPlane && firstChar != 0 {
                            return true
                        } else {
                            return false
                        }
                    }
                }
            } else {
                if plane < firstPlane || plane > lastPlane {
                    return false
                } else {
                    return true
                }
            }
        }
        
        func annexHasMember(annexIsInverted: Bool) -> Bool {
            if annexIsInverted && closedRange.lowerBound.value == 0 && closedRange.upperBound.value == 0xFFFF {
                return false
            } else {
                return true
            }
        }
    }
}
