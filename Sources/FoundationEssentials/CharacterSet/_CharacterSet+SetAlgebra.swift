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


// MARK: Set Algebra
extension _CharacterSet {
    
    // MARK: - Constants
    private static let unicodeMin = Unicode.Scalar(0x0)!
    private static let unicodeMax = Unicode.Scalar(0x10FFFF)!
    
    // CFCharacterSetAddCharactersInRange(CFMutableCharacterSet, CFRange)
    // Set Algebra protocol: (true, newMember) if newMember was not contained in the set. If an element equal to newMember was already contained in the set, the method returns (false, oldMember), where oldMember is the element that was equal to newMember. In some cases, oldMember may be distinguishable from newMember by identity comparison or some other means.
    @discardableResult
    internal func insert(_ character: Unicode.Scalar) -> (inserted: Bool, memberAfterInsert: Unicode.Scalar) {
        if contains(character) {
            return (false, character)
        } else {
            insert(charactersIn: character...character)
            return (true, character)
        }
    }
    
    // Set Algebra protocol: For ordinary sets, an element equal to newMember if the set already contained such a member; otherwise, nil. In some cases, the returned element may be distinguishable from newMember by identity comparison or some other means.
    @discardableResult
    internal func update(with character: Unicode.Scalar) -> Unicode.Scalar? {
        if contains(character) {
            return character
        } else {
            insert(character)
            return nil
        }
    }
    
    // CFCharacterSetRemoveCharactersInRange(CFMutableCharacterSet, CFRange)
    // SetAlgebra protocol: For ordinary sets, an element equal to member if member is contained in the set; otherwise, nil. In some cases, a returned element may be distinguishable from member by identity comparison or some other means.
    @discardableResult
    internal func remove(_ character: Unicode.Scalar) -> Unicode.Scalar? {
        if contains(character) {
            remove(charactersIn: character...character)
            return character
        } else {
            // Already not in, don't need to remove
            return nil
        }
    }
    
    // CFCharacterSetIsLongCharacterMember & _CFCharacterSetIsLongCharacterMember
    @inline(__always)
    internal func contains(_ member: Unicode.Scalar) -> Bool {
        let plane = member.value >> 16
        // Checks BMP
        if plane == 0 {
            return bmpContains(member)
        } else {
            if let isMember = annex.withPlane(Int(plane), { annexPlane in
                nonBMPContains(member, inAnnex: annexPlane)
            }) {
                return isMember ? !annexIsInverted : annexIsInverted
            } else {
                return nonBMPContains(member)
            }
        }
    }
    
    // Test for membership of a BMP surrogate code unit (0xD800-0xDFFF) ONLY.
    // Surrogates are not representable as Unicode.Scalar, so this takes a raw UInt16
    // and inspects the BMP bitmap directly for bitmap-backed storages.
    internal func contains(surrogate codepoint: UInt16) -> Bool {
        switch storage {
        case .bitmap(let bitmapBacked):
            return bitmapBacked.contains(surrogate: codepoint)
        case .compactBitmap(let cBitmapBacked):
            return cBitmapBacked.contains(surrogate: codepoint)
        case .empty, .builtIn, .string:
            return isInverted
        case .range(let rangeBacked):
            return rangeBacked.contains(surrogate: codepoint) ? !isInverted : isInverted
        }
    }
    
    internal func union(_ other: _CharacterSet) -> _CharacterSet {
        let copiedSet = copy()
        copiedSet.formUnion(other)
        return copiedSet
    }
        
    // CFCharacterSetUnion
    @discardableResult
    internal func formUnion(_ other: _CharacterSet) -> Bool {
        if isEmpty {
            guard !isInverted else { return false }
            self.storage = other.storage.deepCopy()
            self.isInverted = other.isInverted
            self.annex = other.annex.deepCopy()
            return true
        }
        
        if other.isEmpty {
            guard other.isInverted else { return false }
            self.storage = .empty
            self.isInverted = true
            self.annex = Annex(isInverted: true)
            return true
        }
        
        if case .range(let rangeBacked) = other.storage {
            let closedRange = rangeBacked.closedRange
            if other.isInverted {
                if closedRange.lowerBound > Self.unicodeMin {
                    insert(charactersIn: Self.unicodeMin..<closedRange.lowerBound)
                }
                
                if closedRange.upperBound < Self.unicodeMax {
                    // U+D7FF + 1 = U+D800 (surrogate, invalid Unicode.Scalar). Skip to U+E000.
                    let nextScalar = Unicode.Scalar(closedRange.upperBound.value + 1) ?? Unicode.Scalar(0xE000)!
                    insert(charactersIn: nextScalar...Self.unicodeMax)
                }
            } else {
                insert(charactersIn: closedRange)
            }
        } else if case .string(let stringBacked) = other.storage, !other.isInverted {
            insert(charactersIn: String.UnicodeScalarView(stringBacked.guts))
        } else {
            makeBitmap()
            guard case .bitmap(var selfBitmapBacked) = self.storage else { return false }
            
            if selfBitmapBacked.span.isEmpty {
                selfBitmapBacked.data = other.bitmap()
            } else {
                // NOTE: Clear storage to avoid CoW when accessing mutableSpan
                self.storage = .empty
                var selfMutableSpan = selfBitmapBacked.mutableSpan
                if case .bitmap(let otherBitmapBacked) = other.storage {
                    _CharacterSet.merge(.union, into: &selfMutableSpan, from: otherBitmapBacked.span)
                } else {
                    let scratch = InlineArray<8192, UInt8> { output in
                        other.appendBitmap(ofPlane: 0, to: &output)
                    }
                    _CharacterSet.merge(.union, into: &selfMutableSpan, from: scratch.span)
                }
            }
            self.storage = .bitmap(selfBitmapBacked)
        }
        
        // Handle nonBMP
        if annexIsInverted || other.annexIsInverted || other.hasNonBMPPlane {
            // Range and built-in storage carry their supplementary content implicitly, so it has to be moved into the annex before the annex is rewritten.
            switch storage {
            case .range, .builtIn:
                makeBitmap()
            case .empty, .string, .bitmap, .compactBitmap:
                break
            }
        }
        if annexIsInverted || other.annexIsInverted {
            var mergedAnnex = Annex()
            for planeIndex in 1...Self.MAX_ANNEX_PLANE {
                let planeStart = UInt32(planeIndex) << 16
                let planeEnd = planeStart | 0xFFFF
                let allOnesPlaneNeeded = switch other.storage {
                case .builtIn(let predefined):
                    predefined.bitmapResult(forPlane: planeIndex, isInverted: other.isInverted) == .bitmapAll
                case .range(let rangeBacked):
                    other.isInverted
                        ? rangeBacked.closedRange.upperBound.value < planeStart || rangeBacked.closedRange.lowerBound.value > planeEnd
                        : rangeBacked.closedRange.lowerBound.value <= planeStart && rangeBacked.closedRange.upperBound.value >= planeEnd
                case .empty, .string, .bitmap, .compactBitmap:
                    other.annexIsInverted && other.getAnnexPlaneCharacterSetNoAlloc(planeIndex) == nil
                }
                let mergedPlane = _CharacterSet()

                if allOnesPlaneNeeded {
                    mergedPlane.isInverted = true
                    mergedAnnex.setCharacterSet(mergedPlane, forPlane: planeIndex)
                    continue
                }

                let otherPlaneBitmap = InlineArray<8192, UInt8> { output in
                    other.appendBitmap(ofPlane: planeIndex, to: &output)
                }

                var mergedBitmap = InlineArray<8192, UInt8> { output in
                    self.appendBitmap(ofPlane: planeIndex, to: &output)
                }
                var mergedSpan = mergedBitmap.mutableSpan
                let contents = Self.merge(.union, into: &mergedSpan, from: otherPlaneBitmap.span)

                if contents == .allZeros {
                    continue
                } else if contents == .allOnes {
                    mergedPlane.isInverted = true
                } else {
                    mergedPlane.storage = .bitmap(BitmapBacked(data: Data(capacity: Self.__kCFBitmapSize) { output in
                        output._append(copying: mergedBitmap.span.bytes)
                    }))
                }
                mergedAnnex.setCharacterSet(mergedPlane, forPlane: planeIndex)
            }
            self.annex = mergedAnnex
        } else if case .builtIn(let predefined) = other.storage {
            for planeIndex in 1...Self.MAX_ANNEX_PLANE {
                guard predefined.hasMember(inPlane: UInt8(planeIndex), isInverted: other.annexIsInverted) else {
                    continue
                }

                let result = predefined.bitmapResult(forPlane: planeIndex, isInverted: other.annexIsInverted)
                if result == .bitmapEmpty {
                    continue
                }

                let annexPlane = getAnnexPlaneCharacterSet(planeIndex)
                if result == .bitmapAll {
                    annexPlane.storage = .bitmap(BitmapBacked(data: _CharacterSet.allOnes()))
                } else {
                    let scratchBuffer = InlineArray<8192, UInt8> { output in
                        predefined.appendBitmap(forPlane: planeIndex, isInverted: other.annexIsInverted, to: &output)
                    }
                    annexPlane.makeBitmap()
                    guard case .bitmap(var bitmapBacked) = annexPlane.storage else {
                        fatalError("Conversion to bitmap-backed via makeBitmap() should not fail")
                    }

                    // NOTE: Clear storage to avoid CoW when accessing mutableSpan
                    annexPlane.storage = .empty
                    var planeSpan = bitmapBacked.mutableSpan
                    Self.merge(.union, into: &planeSpan, from: scratchBuffer.span)
                    annexPlane.storage = .bitmap(bitmapBacked)
                }
                self.annex.setCharacterSet(annexPlane, forPlane: planeIndex)
            }
        } else if other.hasNonBMPPlane {
            for planeIndex in 1...Self.MAX_ANNEX_PLANE {
                guard let otherPlane = other.getAnnexPlaneCharacterSetNoAlloc(planeIndex) else { continue }

                let selfPlane = getAnnexPlaneCharacterSet(planeIndex)
                selfPlane.formUnion(otherPlane)
                annex.setCharacterSet(selfPlane, forPlane: planeIndex)
            }
        }
        return true
    }
    
    internal func intersection(_ other: _CharacterSet) -> _CharacterSet {
        let copy = self.copy()
        copy.formIntersection(other)
        return copy
    }
    
    // Returns true if mutation happened, return false otherwise.
    @discardableResult
    internal func formIntersection(_ other: _CharacterSet) -> Bool {
        if isEmpty {
            guard isInverted else { return false }
            self.storage = other.storage.deepCopy()
            self.isInverted = other.isInverted
            self.annex = other.annex.deepCopy()
            return true
        }

        if other.isEmpty {
            guard !other.isInverted else { return false }
            self.storage = .empty
            self.isInverted = false
            self.annex = Annex()
            return true
        }

        makeBitmap()
        guard case .bitmap(var selfBitmapBacked) = self.storage else { return false }

        // NOTE: Clear storage to avoid CoW when accessing mutableSpan
        self.storage = .empty
        var selfMutableSpan = selfBitmapBacked.mutableSpan
        if case .bitmap(let otherBitmapBacked) = other.storage {
            Self.merge(.intersection, into: &selfMutableSpan, from: otherBitmapBacked.span)
        } else {
            let scratch = InlineArray<8192, UInt8> { output in
                other.appendBitmap(ofPlane: 0, to: &output)
            }
            Self.merge(.intersection, into: &selfMutableSpan, from: scratch.span)
        }
        self.storage = .bitmap(selfBitmapBacked)

        // Handle nonBMP 
        if hasNonBMPPlane || annexIsInverted {
            var mergedAnnex = Annex()
            for planeIndex in 1...Self.MAX_ANNEX_PLANE {
                guard other.hasMember(inPlane: UInt8(planeIndex)), hasMember(inPlane: UInt8(planeIndex)) else {
                    continue
                }

                var mergedBitmap = InlineArray<8192, UInt8> { output in
                    self.appendBitmap(ofPlane: planeIndex, to: &output)
                }
                let otherPlaneBitmap = InlineArray<8192, UInt8> { output in
                    other.appendBitmap(ofPlane: planeIndex, to: &output)
                }
                var mergedSpan = mergedBitmap.mutableSpan
                let contents = Self.merge(.intersection, into: &mergedSpan, from: otherPlaneBitmap.span)
                guard contents != .allZeros else {
                    continue
                }

                let mergedPlane = _CharacterSet()
                if contents == .allOnes {
                    mergedPlane.isInverted = true
                } else {
                    mergedPlane.storage = .bitmap(BitmapBacked(data: Data(capacity: Self.__kCFBitmapSize) { output in
                        output._append(copying: mergedBitmap.span.bytes)
                    }))
                }
                mergedAnnex.setCharacterSet(mergedPlane, forPlane: planeIndex)
            }
            self.annex = mergedAnnex
        }
        return true
    }

    internal func subtracting(_ other: _CharacterSet) -> _CharacterSet {
        let copied = self.copy()
        copied.subtract(other)
        return copied
    }
    
    // CFCharacterSetCreateInvertedSet(nil, CFCharacterSet) -> CFCharacterSet
    // CFCharacterSetIntersect(CFMutableCharacterSet, CFCharacterSet)
    @discardableResult
    internal func subtract(_ other: _CharacterSet) -> Bool {
        let invertedOther = other.inverted
        return self.formIntersection(invertedOther)
    }
    
    internal func symmetricDifference(_ other: _CharacterSet) -> _CharacterSet {
        let copied = self.copy()
        copied.formSymmetricDifference(other)
        return copied
    }
    
    // Implemented as: union(other).subtracting(intersection(other))
    @discardableResult
    internal func formSymmetricDifference(_ other: _CharacterSet) -> Bool {
        let intersection = self.intersection(other)
        let unionResult = self.formUnion(other)           // self = self ∪ other
        let subtractResult = self.subtract(intersection)     // self = self - (original_self ∩ other)
        return unionResult || subtractResult
    }
    
    // CFCharacterSetIsSupersetOfSet
    internal func isSuperset(of other: _CharacterSet) -> Bool {
        if isEmpty {
            if isInverted {
                // If self is empty and inverted, self contains everything. So it is always a superset of other characterSet.
                return true
            }
            if !other.isEmpty || other.isInverted {
                //  Self is empty but not inverted, self contains nothing. So it is never a superset of other characterSet.
                return false
            }
            return true
        }
        if other.isEmpty && !other.isInverted {
            // If other is empty and not inverted, other is empty. Self is always a superset of empty set.
            return true
        }

        if case .builtIn(let selfBuiltin) = self.storage,
           case .builtIn(let otherBuiltin) = other.storage,
           selfBuiltin.charset == otherBuiltin.charset,
           !self.isInverted && !other.isInverted {
            return true
        }
        
        if case .range(let selfRangeBacked) = self.storage, case .range(let otherRangeBacked) = other.storage {
            if isInverted {
                if other.isInverted {
                    let firstCharComparison = otherRangeBacked.closedRange.lowerBound > selfRangeBacked.closedRange.lowerBound
                    let lengthComparison = selfRangeBacked.closedRange.upperBound > otherRangeBacked.closedRange.upperBound
                    return !(firstCharComparison || lengthComparison)
                } else {
                    let condition1 = otherRangeBacked.closedRange.upperBound < selfRangeBacked.closedRange.lowerBound
                    let condition2 = selfRangeBacked.closedRange.upperBound < otherRangeBacked.closedRange.lowerBound
                    return condition1 || condition2
                }
            } else {
                if other.isInverted {
                    let condition1 = selfRangeBacked.closedRange.lowerBound.value == 0 && selfRangeBacked.closedRange.upperBound.value == 0x10FFFF
                    let condition2 = otherRangeBacked.closedRange.lowerBound.value == 0 && UInt32(otherRangeBacked.closedRange.upperBound.value - otherRangeBacked.closedRange.lowerBound.value + 1) <= selfRangeBacked.closedRange.lowerBound.value
                    let condition3 = selfRangeBacked.closedRange.upperBound.value + 1 <= otherRangeBacked.closedRange.lowerBound.value && otherRangeBacked.closedRange.upperBound.value == 0x10FFFF
                    return condition1 || condition2 || condition3
                } else {
                    let condition1 = otherRangeBacked.closedRange.lowerBound < selfRangeBacked.closedRange.lowerBound
                    let condition2 = selfRangeBacked.closedRange.upperBound < otherRangeBacked.closedRange.upperBound
                    return !(condition1 || condition2)
                }
            }
        }

        for plane in 0...Self.MAX_ANNEX_PLANE {
            guard other.hasMember(inPlane: UInt8(plane)) else { continue }
            guard self.hasMember(inPlane: UInt8(plane)) else { return false }

            if plane == 0 {
                if case .compactBitmap(let selfCompact) = self.storage,
                   case .compactBitmap(let otherCompact) = other.storage {
                    if !selfCompact.isSuperset(of: otherCompact) {
                        return false
                    }
                    continue
                }
            } else if !annexIsInverted, !other.annexIsInverted,
                      let selfPlane = annex.getCharacterSetNoAlloc(forPlane: plane),
                      let otherPlane = other.annex.getCharacterSetNoAlloc(forPlane: plane) {
                if case .compactBitmap(let selfCompact) = selfPlane.storage {
                    if case .compactBitmap(let otherCompact) = otherPlane.storage {
                        if !selfCompact.isSuperset(of: otherCompact) {
                            return false
                        }
                        continue
                    }
                }
            }
            
            let selfPlaneBitmap = InlineArray<8192, UInt8> { output in
                self.appendBitmap(ofPlane: plane, to: &output)
            }
            
            if plane == 0, case .compactBitmap(let otherCompact) = other.storage {
                if !otherCompact.isSubset(of: selfPlaneBitmap.span.bytes) {
                    return false
                }
                continue
            }
            
            if plane > 0, !other.annexIsInverted, let otherPlane = other.annex.getCharacterSetNoAlloc(forPlane: plane), case .compactBitmap(let otherCompact) = otherPlane.storage {
                if !otherCompact.isSubset(of: selfPlaneBitmap.span.bytes) {
                    return false
                }
                continue
            }
            
            let otherPlaneBitmap = InlineArray<8192, UInt8> { output in
                other.appendBitmap(ofPlane: plane, to: &output)
            }
            if !_CharacterSet.supersetRelationship(inPlane: plane, superset: selfPlaneBitmap.span.bytes, subset: otherPlaneBitmap.span.bytes) {
                return false
            }
        }
        return true
    }
    
    // MARK: Helper Methods
    
    // Helper method for contains
    @inline(__always)
    private func bmpContains(_ member: Unicode.Scalar) -> Bool {
        switch storage {
        case .empty:
            return isInverted
        case .builtIn(let predefined):
            switch predefined.charset {
            case .whitespace:
                return predefined.isWhitespace(member) ? !isInverted : isInverted
            case .newline:
                return predefined.isNewline(member) ? !isInverted : isInverted
            case .whitespaceAndNewline:
                return (predefined.isWhitespace(member) || predefined.isNewline(member)) ? !isInverted : isInverted
            default:
                guard let (span, shouldInvert) = predefined._bitmapPtrForPlane(0) else {
                    return isInverted
                }
                let theChar = UInt16(truncatingIfNeeded: member.value)
                let byte = span[Int(theChar >> BuiltInUnicodeScalarSet.bitShiftForByte)]
                let bitMask = UInt32(1) << (theChar & BuiltInUnicodeScalarSet.bitShiftForMask)
                let isMember = (UInt32(byte) & bitMask) != 0
                let memberResult = shouldInvert ? !isMember : isMember
                return memberResult ? !isInverted : isInverted
            }
        case .range(let rangeBacked):
            if rangeBacked.contains(member) {
                return !isInverted
            } else {
                return isInverted
            }
        case .string(let stringBacked):
            if stringBacked.contains(member) {
                return !isInverted
            } else {
                return isInverted
            }
        case .bitmap(let bitmapBacked):
            if bitmapBacked.span.count > 0 {
                if bitmapBacked.contains(member) {
                    return true
                } else {
                    return false
                }
            } else {
                return isInverted
            }
        case .compactBitmap(let cBitmapBacked):
            if cBitmapBacked.contains(member) {
                return true
            } else {
                return false
            }
        }
    }

    // Helper method for contains in non-BMP planes
    private func nonBMPContains(_ member: Unicode.Scalar, inAnnex annexPlane: _CharacterSet) -> Bool {
        // Mask to get the lower 16 bits (position within the plane)
        let maskedValue = member.value & 0xFFFF
        
        // Create a safe Unicode.Scalar for checking
        // If the masked value falls in the surrogate range (0xD800-0xDFFF),
        // we need to handle it specially since those aren't valid Unicode scalars
        let safeScalar: Unicode.Scalar
        if maskedValue >= 0xD800 && maskedValue <= 0xDFFF {
            // For bitmap-based storage, we can check the bit directly using the raw value
            switch annexPlane.storage {
            case .empty:
                return annexPlane.isInverted
            case .bitmap(let bitmapBacked):
                if bitmapBacked.span.count > 0 {
                    // Check the bit directly using the masked value
                    let byteIndex = Int(maskedValue >> 3)
                    let bitIndex = maskedValue & 7
                    if byteIndex < bitmapBacked.span.count {
                        let byte = bitmapBacked.span[byteIndex]
                        return (byte & (1 << bitIndex)) != 0
                    }
                    return false
                } else {
                    return annexPlane.isInverted
                }
            case .compactBitmap(let cBitmapBacked):
                // For compact bitmap, check the bit directly
                return cBitmapBacked.contains(surrogate: UInt16(maskedValue))
            case .range(let rangeBacked):
                return rangeBacked.contains(surrogate: UInt16(maskedValue)) ? !annexPlane.isInverted : annexPlane.isInverted
            case .builtIn, .string:
                return annexPlane.isInverted
            }
        } else {
            // Safe to create a Unicode.Scalar
            safeScalar = Unicode.Scalar(maskedValue)!
        }
        
        switch annexPlane.storage {
        case .empty:
            return annexPlane.isInverted
        case .builtIn(let predefined):
            if predefined.contains(safeScalar) {
                return !annexPlane.isInverted
            } else {
                return annexPlane.isInverted
            }
        case .range(let rangeBacked):
            if rangeBacked.contains(safeScalar) {
                return !annexPlane.isInverted
            } else {
                return annexPlane.isInverted
            }
        case .string(let stringBacked):
            if stringBacked.contains(safeScalar) {
                return !annexPlane.isInverted
            } else {
                return annexPlane.isInverted
            }
        case .bitmap(let bitmapBacked):
            if bitmapBacked.span.count > 0 {
                if bitmapBacked.contains(safeScalar) {
                    return true
                } else {
                    return false
                }
            } else {
                return annexPlane.isInverted
            }
        case .compactBitmap(let cBitmapBacked):
            if cBitmapBacked.contains(safeScalar) {
                return true
            } else {
                return false
            }
        }
    }

    // Helper method for contains
    private func nonBMPContains(_ maskedMember: Unicode.Scalar) -> Bool {
        switch storage {
        case .builtIn(let predefined):
            if predefined.contains(maskedMember) {
                return !isInverted
            } else {
                return isInverted
            }
        case .range(let rangeBacked):
            if rangeBacked.contains(maskedMember) {
                return !isInverted
            } else {
                return isInverted
            }
        case .string(let stringBacked):
            if stringBacked.contains(maskedMember) {
                return !isInverted
            } else {
                return isInverted
            }
        default:
            break
        }
        if annexIsInverted {
            return true
        } else {
            return false
        }
    }
    
    // Helper method for formUnion and formIntersection
    private enum BitmapOperation {
        case union
        case intersection
    }

    private enum BitmapContents {
        case allZeros
        case allOnes
        case mixed
    }

    @discardableResult
    private static func merge(_ operation: BitmapOperation, into destination: inout MutableSpan<UInt8>, from source: Span<UInt8>) -> BitmapContents {
        let count = min(destination.count, source.count)
        var anyBitSet: UInt8 = 0
        var allBitsSet: UInt8 = 0xFF
        switch operation {
        case .union:
            for i in 0..<count {
                destination[i] |= source[i]
                anyBitSet |= destination[i]
                allBitsSet &= destination[i]
            }
        case .intersection:
            for i in 0..<count {
                destination[i] &= source[i]
                anyBitSet |= destination[i]
                allBitsSet &= destination[i]
            }
        }
        if anyBitSet == 0 {
            return .allZeros
        }
        return allBitsSet == 0xFF ? .allOnes : .mixed
    }

    // Helper method for isSuperset
    private static func supersetRelationship(inPlane plane: Int, superset: RawSpan, subset: RawSpan) -> Bool {
        let wordStride = MemoryLayout<UInt>.stride
        var offset = 0
        while offset < Self.__kCFBitmapSize {
            let subsetWord = subset.load(fromByteOffset: offset, as: UInt.self).littleEndian
            let supersetWord = superset.load(fromByteOffset: offset, as: UInt.self).littleEndian
            if (subsetWord & ~supersetWord) != 0 {
                return false
            }
            offset += wordStride
        }
        return true
    }
}
