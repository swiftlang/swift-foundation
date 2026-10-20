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

// MARK: Immutable functions - bitmapRepresentation (Data), hasMember (Bool), inverted (CharacterSet)
extension _CharacterSet {
    
    // MARK: API Methods
    
    // CFCharacterSetCreateInvertedSet
    internal var inverted: _CharacterSet {
        let copied = copy()
        copied.invert()
        return copied
    }
    
    // CFCharacterSetHasMemberInPlane
    internal func hasMember(inPlane plane: UInt8) -> Bool {
        guard plane >= 0 && plane <= Self.MAX_ANNEX_PLANE else {
            return false
        }
        
        if isEmpty {
            return isInverted
        }
        
        switch storage {
            // BuiltIn and Range are stored without any Annex by default, so we just check this directly.
        case .builtIn(let predefined):
            return predefined.hasMember(inPlane: plane, isInverted: isInverted)
        case .range(let rangeBacked):
            return rangeBacked.hasMember(inPlane: plane, isInverted: isInverted)
        default:
            if plane == 0 {
                // Check String, CompactBitmap and Bitmap if plane == 0
                switch storage {
                case .string(let stringBacked):
                    return stringBacked.hasMemberInBMPPlane(isInverted: isInverted)
                case .compactBitmap(let cBitmapBacked):
                    // Inversion in cBitmap & bitmap just means bitwise inverting, so no need for flipping isInverted param
                    return cBitmapBacked.hasMemberInBMPPlane()
                case .bitmap(let bitmapBacked):
                    return bitmapBacked.hasMemberInBMPPlane()
                default:
                    return true
                }
            } else {
                if let annex = getAnnexPlaneCharacterSetNoAlloc(Int(plane)) {
                    // Check Annex of types Range, Bitmap and String (converted to bitmap)
                    switch annex.storage {
                    case .range(let rangeBacked):
                        return rangeBacked.annexHasMember(annexIsInverted: annexIsInverted)
                    case .bitmap(let bitmapBacked):
                        return bitmapBacked.annexHasMember(annexIsInverted: annexIsInverted)
                    default:
                        let bitmap = annex.bitmap()
                        if annexIsInverted {
                            let allOnes = bitmap.allSatisfy { $0 == 0xFF }
                            return !allOnes
                        } else {
                            return bitmap.contains { $0 != 0 }
                        }
                    }
                } else {
                    return annexIsInverted
                }
            }
        }
    }
    
    
    // CFCharacterSetCreateBitmapRepresentation
    internal var bitmapRepresentation: Data {
        // Handle BuiltIn, Range cases that doesn't have anything stored in Annex
        switch storage {
        case .builtIn(let predefined):
            return predefined.bitmapRepresentation(isInverted: isInverted)
        case .range(let rangeBacked):
            return rangeBacked.bitmapRepresentation(isInverted: isInverted)
        case .string, .compactBitmap, .bitmap, .empty:
            break
        }
        
        if hasNonBMPPlane || annexIsInverted {
            return bitmapRepresentationWithNonBMPPlanes()
        } else {
            return bitmap()
        }
    }
    
    // MARK: Helper Methods
    // Helper method for bitmapRepresentation
    private func bitmapRepresentationWithNonBMPPlanes() -> Data {
        let planeMask: UInt16 = annexIsInverted ? 0xFFFF : annex.populatedPlanes
        let numNonBMPPlanes = planeMask.nonzeroBitCount

        // Pre-allocate the exact final size: BMP (8192) + per-plane (1 index byte + 8192 data)
        let totalSize = Self.__kCFBitmapSize + ((Self.__kCFBitmapSize + 1) * numNonBMPPlanes)
        return Data(capacity: totalSize) { output in
            // Write BMP plane at offset 0
            appendBitmap(to: &output)

            // Write non-BMP planes
            var mask = planeMask
            while mask != 0 {
                let planeIndex = Int(mask.trailingZeroBitCount) + 1
                mask &= mask &- 1 // clear lowest set bit

                // Write 1-byte plane index
                output.append(UInt8(planeIndex))
                appendBitmap(ofPlane: planeIndex, to: &output)
            }
        }
    }
}
