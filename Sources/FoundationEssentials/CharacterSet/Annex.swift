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

// CFCharSetAnnexStruct
internal struct Annex: CustomStringConvertible, CustomDebugStringConvertible {
    // Index n is for plane n + 1: 0 for plane 1, 1 for plane 2
    private(set) var nonBMPPlanes: [_CharacterSet?]
    // Bitmask of which planes are populated (bit N = plane N+1).
    private(set) var populatedPlanes: UInt16
    // false: contains characters in set; true: contains characters not in set
    var isInverted: Bool

    // NOTE: This is a `let` that is never mutated and every element is nil, so no _CharacterSet is reachable through it. Array is copy-on-write, so the first plane store copies the buffer rather than mutating the shared one.
    nonisolated(unsafe) private static let emptyPlanes: [_CharacterSet?] = Array<_CharacterSet?>(repeating: nil, count: _CharacterSet.MAX_ANNEX_PLANE)

    // __CFCSetAllocateAnnexForPlane - nil case
    init(isInverted inverted: Bool = false) {
        isInverted = inverted
        nonBMPPlanes = Annex.emptyPlanes
        populatedPlanes = 0
    }
    
    // __CFCSetGetAnnexPlaneCharacterSet - allocating version
    mutating func getCharacterSet(forPlane plane: Int) -> _CharacterSet {
        precondition(plane >= 1 && plane <= _CharacterSet.MAX_ANNEX_PLANE, "Invalid plane number. Plane number should only be between 1 and 16.")

        // Return an existing _CharacterSet or new empty _CharacterSet
        let planeIndex = plane - 1
        if let plane = nonBMPPlanes[planeIndex] {
            return plane
        } else {
            let newCharacterSet = _CharacterSet()
            // Store directly without setting bitmap bit — the caller is expected
            // to mutate this and then call setCharacterSet() to commit the result,
            // which will set the bitmap bit if the plane is non-empty.
            nonBMPPlanes[planeIndex] = newCharacterSet
            return newCharacterSet
        }
    }
    
    // __CFCSetGetAnnexPlaneCharacterSetNoAlloc - read-only version
    func getCharacterSetNoAlloc(forPlane plane: Int) -> _CharacterSet? {
        precondition(plane >= 1 && plane <= _CharacterSet.MAX_ANNEX_PLANE, "Invalid plane number. Plane number should only be between 1 and 16.")
        
        let planeIndex = plane - 1
        return nonBMPPlanes[planeIndex]
    }
    
    @inline(__always)
    func withPlane<R>(_ planeNumber: Int, _ body: (_CharacterSet) -> R) -> R? {
        let planeIndex = planeNumber - 1
        guard planeIndex >= 0 && planeIndex < nonBMPPlanes.count else {
            return nil
        }
        return nonBMPPlanes[planeIndex].map(body)
    }

    // __CFCSetPutCharacterSetToAnnexPlane
    internal mutating func setCharacterSet(_ characterSet: _CharacterSet?, forPlane plane: Int) {

        if plane < 1 {
            return
        }

        // Store the new character set for this plane
        let planeIndex = plane - 1
        
        // Check if new character set is empty or not
        let normalizedCharacterSet: _CharacterSet?
        if let cs = characterSet, cs.isEmpty && !cs.isInverted {
            normalizedCharacterSet = nil
        } else {
            normalizedCharacterSet = characterSet
        }

        if normalizedCharacterSet == nil && nonBMPPlanes[planeIndex] == nil {
            return
        }
        nonBMPPlanes[planeIndex] = normalizedCharacterSet

        if normalizedCharacterSet != nil {
            populatedPlanes |= UInt16(1) << planeIndex
        } else {
            populatedPlanes &= ~(UInt16(1) << planeIndex)
        }
    }
    
    func deepCopy() -> Annex {
        var copiedAnnex = Annex()

        // Copy the inversion flag
        copiedAnnex.isInverted = self.isInverted

        // Deep copy each plane's character set
        for index in nonBMPPlanes.indices {
            if let characterSet = nonBMPPlanes[index] {
                copiedAnnex.setCharacterSet(characterSet.copy(), forPlane: index + 1)
            }
        }

        return copiedAnnex
    }
    
    var description: String {
        var result = "Annex {\n"
        result += "  isInverted: \(isInverted)\n"
        result += "  nonBMPPlanes: [\n"
        
        for index in nonBMPPlanes.indices {
            let planeNumber = index + 1
            if let plane = nonBMPPlanes[index] {
                if plane.isEmpty {
                    result += "    Plane \(planeNumber): (empty)\n"
                } else {
                    result += "    Plane \(planeNumber): \(plane.storage)\n"
                }
            } else {
                result += "    Plane \(planeNumber): nil\n"
            }
        }
        
        result += "  ]\n"
        result += "}"
        return result
    }
    
    var debugDescription: String {
        return description
    }
}

extension _CharacterSet {

    // __CFCSetHasNonBMPPlane
    var hasNonBMPPlane: Bool {
        return annex.populatedPlanes != 0
    }
    
    // __CFCSetAnnexIsInverted
    var annexIsInverted: Bool {
        return annex.isInverted
    }
    
    // __CFCSetGetAnnexPlaneCharacterSet
    internal func getAnnexPlaneCharacterSet(_ plane: Int) -> _CharacterSet {
        precondition(plane >= 1 && plane <= Self.MAX_ANNEX_PLANE, "Invalid plane number: Plane number should be between 1 and 16")
        
        return annex.getCharacterSet(forPlane: plane)
    }

    // __CFCSetGetAnnexPlaneCharacterSetNoAlloc
    internal func getAnnexPlaneCharacterSetNoAlloc(_ plane: Int) -> _CharacterSet? {
        guard plane >= 1 else {
            return nil
        }
        guard plane <= Self.MAX_ANNEX_PLANE else {
            return nil
        }
        
        // Use the annex's read-only method
        return annex.getCharacterSetNoAlloc(forPlane: plane)
    }

    internal func modifyNonBMPPlanes(unicodeScalars: String.UnicodeScalarView, operation: Operation) {
        for scalar in unicodeScalars where scalar.value > 0xFFFF {
            switch operation {
            case .add:
                addNonBMPPlanes(inRange: scalar...scalar)
            case .remove:
                removeNonBMPPlanes(inRange: scalar...scalar)
            }
        }
    }

    // __CFCSetAddNonBMPPlanesInRange
    internal func addNonBMPPlanes(inRange closedRange: ClosedRange<Unicode.Scalar>) {
        let firstChar = closedRange.lowerBound.value & 0xFFFF
        let maxChar = closedRange.upperBound.value & 0xFFFF
        let idx = Int(closedRange.lowerBound.value >> 16) // first plane
        let maxPlane = min(Int(closedRange.upperBound.value >> 16), Self.MAX_ANNEX_PLANE) // last plane
        
        if idx > Self.MAX_ANNEX_PLANE {
            return
        }
        
        let minPlane = max(idx, 1)
        
        if minPlane > maxPlane {
            return
        }
        
        for planeIndex in minPlane...maxPlane {
            let planeRangeStart: UInt32
            let planeRangeEnd: UInt32
            
            if planeIndex == idx && planeIndex == maxPlane {
                // Single plane case - use exact character range within the plane
                planeRangeStart = firstChar
                planeRangeEnd = maxChar
            } else if planeIndex == idx {
                // First plane of multi-plane range
                planeRangeStart = firstChar
                planeRangeEnd = 0xFFFF
            } else if planeIndex == maxPlane {
                // Last plane of multi-plane range  
                planeRangeStart = 0
                planeRangeEnd = maxChar
            } else {
                // Middle plane of multi-plane range
                planeRangeStart = 0
                planeRangeEnd = 0xFFFF
            }
            
            let planeRangeLength = Int(planeRangeEnd - planeRangeStart + 1)
            
            guard planeRangeLength > 0 else { continue }
            
            // Check the bounds to see if they overlap with 0xDF00 - 0xDFFF
            // If they don't just use the regular insert / remove; Otherwise, convert into bitmap and then do insert / remove operations that way
            if let lowerRange = Unicode.Scalar(UInt32(planeRangeStart)),
                let upperRange = Unicode.Scalar(UInt32(planeRangeEnd)) {
                let planeRange = lowerRange...upperRange
                if annexIsInverted {
                    // Handles case where annexIsInverted
                    if let annexPlane = getAnnexPlaneCharacterSetNoAlloc(planeIndex) {
                        // Handles case where annexPlane already exists
                        annexPlane.remove(charactersIn: planeRange)
                        if annexPlane.isEmpty && !annexPlane.isInverted {
                            self.annex.setCharacterSet(nil, forPlane: planeIndex)
                        } else {
                            self.annex.setCharacterSet(annexPlane, forPlane: planeIndex)
                        }
                    } else {
                        // Handles case where annexPlane doesn't exist yet
                        let newPlane = _CharacterSet()
                        newPlane.insert(charactersIn: planeRange)
                        self.annex.setCharacterSet(newPlane, forPlane: planeIndex)
                    }
                } else {
                    let annexPlane = getAnnexPlaneCharacterSet(planeIndex)
                    annexPlane.insert(charactersIn: planeRange)
                    self.annex.setCharacterSet(annexPlane, forPlane: planeIndex)
                }
            } else {
                // Handle cases where there is D800 - DFFF
                if annexIsInverted {
                    if let annexPlane = getAnnexPlaneCharacterSetNoAlloc(planeIndex) {
                        annexPlane.makeBitmap()
                        guard case .bitmap(var bitmapBacked) = annexPlane.storage else {
                            continue
                        }
                        
                        var mutableSpan = bitmapBacked.mutableSpan
                        _CharacterSet.removeCharacters(from: &mutableSpan, firstChar: planeRangeStart, lastChar: planeRangeEnd)
                        annexPlane.storage = .bitmap(bitmapBacked)
                        
                        if annexPlane.isEmpty && !annexPlane.isInverted {
                            self.annex.setCharacterSet(nil, forPlane: planeIndex)
                        } else {
                            self.annex.setCharacterSet(annexPlane, forPlane: planeIndex)
                        }
                    } else {
                        // Handles case where annexPlane doesn't exist yet
                        let newPlane = _CharacterSet()
                        newPlane.makeBitmap()
                        guard case .bitmap(var bitmapBacked) = newPlane.storage else {
                            continue
                        }
                        
                        var mutableSpan = bitmapBacked.mutableSpan
                        _CharacterSet.addCharacters(to: &mutableSpan, firstChar: planeRangeStart, lastChar: planeRangeEnd)
                        self.annex.setCharacterSet(newPlane, forPlane: planeIndex)
                    }
                } else {
                    let annexPlane = getAnnexPlaneCharacterSet(planeIndex)
                    annexPlane.makeBitmap()
                    guard case .bitmap(var bitmapBacked) = annexPlane.storage else {
                        continue
                    }
                    
                    var mutableSpan = bitmapBacked.mutableSpan
                    _CharacterSet.addCharacters(to: &mutableSpan, firstChar: planeRangeStart, lastChar: planeRangeEnd)
                    annexPlane.storage = .bitmap(bitmapBacked)
                    self.annex.setCharacterSet(annexPlane, forPlane: planeIndex)
                }
            }
        }
        
        if !hasNonBMPPlane && !annexIsInverted {
            self.annex = Annex()
        }
    }
    
    // __CFCSetRemoveNonBMPPlanesInRange
    internal func removeNonBMPPlanes(inRange range: ClosedRange<Unicode.Scalar>) {
        let firstChar = range.lowerBound.value & 0xFFFF
        let maxChar = range.upperBound.value & 0xFFFF
        let idx = Int(range.lowerBound.value >> 16) // first plane
        let maxPlane = min(Int(range.upperBound.value >> 16), Self.MAX_ANNEX_PLANE)
        
        if idx > Self.MAX_ANNEX_PLANE {
            return
        }
        
        let minPlane = max(idx, 1)
        if minPlane > maxPlane {
            return
        }
        
        for planeIndex in minPlane...maxPlane {
            let planeRangeStart: UInt32
            let planeRangeEnd: UInt32
            
            if planeIndex == idx && planeIndex == maxPlane {
                // Single plane case - use exact character range within the plane
                planeRangeStart = firstChar
                planeRangeEnd = maxChar
            } else if planeIndex == idx {
                // First plane of multi-plane range
                planeRangeStart = firstChar
                planeRangeEnd = 0xFFFF
            } else if planeIndex == maxPlane {
                // Last plane of multi-plane range  
                planeRangeStart = 0
                planeRangeEnd = maxChar
            } else {
                // Middle plane of multi-plane range
                planeRangeStart = 0
                planeRangeEnd = 0xFFFF
            }
            
            let planeRangeLength = Int(planeRangeEnd - planeRangeStart + 1)
            
            guard planeRangeLength > 0 else { continue }
            
            if let lowerRange = Unicode.Scalar(UInt32(planeRangeStart)),
               let upperRange = Unicode.Scalar(UInt32(planeRangeEnd)) {
                let planeRange = lowerRange...upperRange
                if annexIsInverted {
                    // Inverted annex: removing characters means adding them to the exclusion list
                    let annexPlane = getAnnexPlaneCharacterSet(planeIndex)
                    annexPlane.insert(charactersIn: planeRange)
                    self.annex.setCharacterSet(annexPlane, forPlane: planeIndex)
                } else {
                    // Normal annex: removing characters means removing them from the inclusion set
                    if let annexPlane = getAnnexPlaneCharacterSetNoAlloc(planeIndex) {
                        annexPlane.remove(charactersIn: planeRange)
                        if annexPlane.isEmpty && !annexPlane.isInverted {
                            // No more inclusions - remove the plane entirely
                            self.annex.setCharacterSet(nil, forPlane: planeIndex)
                        } else {
                            self.annex.setCharacterSet(annexPlane, forPlane: planeIndex)
                        }
                    } else {
                        // No inclusions exist - nothing to remove
                    }
                }
            } else {
                // Handle cases where there is D800 - DFFF
                if annexIsInverted {
                    let annexPlane = getAnnexPlaneCharacterSet(planeIndex)
                    annexPlane.makeBitmap()
                    guard case .bitmap(var bitmapBacked) = annexPlane.storage else {
                        continue
                    }
                    
                    var mutableSpan = bitmapBacked.mutableSpan
                    _CharacterSet.addCharacters(to: &mutableSpan, firstChar: planeRangeStart, lastChar: planeRangeEnd)
                    annexPlane.storage = .bitmap(bitmapBacked)
                    self.annex.setCharacterSet(annexPlane, forPlane: planeIndex)
                } else {
                    if let annexPlane = getAnnexPlaneCharacterSetNoAlloc(planeIndex) {
                        annexPlane.makeBitmap()
                        guard case .bitmap(var bitmapBacked) = annexPlane.storage else {
                            continue
                        }
                        
                        var mutableSpan = bitmapBacked.mutableSpan
                        _CharacterSet.removeCharacters(from: &mutableSpan, firstChar: planeRangeStart, lastChar: planeRangeEnd)
                        annexPlane.storage = .bitmap(bitmapBacked)
                        
                        if annexPlane.isEmpty && !annexPlane.isInverted {
                            // No more inclusions - remove the plane entirely
                            self.annex.setCharacterSet(nil, forPlane: planeIndex)
                        } else {
                            self.annex.setCharacterSet(annexPlane, forPlane: planeIndex)
                        }
                    }
                }
            }
        }
        
        if !hasNonBMPPlane && !annexIsInverted {
            self.annex = Annex()
        }
    }
}
