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

// MARK: Mutable functions - insert(closedRange), insert(range), insert(string), remove(closedRange), remove(range), remove(string), invert()
extension _CharacterSet {
    // MARK: API Methods
    
    // CFCharacterSetInvert
    internal func invert() {
        switch storage {
        // Bitwise inversion of Bitmap and CompactBitmap contents, don't need to set inversion flag
        case .bitmap(var bitmapBacked):
            bitmapBacked.invert()
            storage = .bitmap(bitmapBacked)
        case .compactBitmap(var cBitmapBacked):
            cBitmapBacked.invert()
            storage = .compactBitmap(cBitmapBacked)
        case .string, .range, .builtIn, .empty:
            // Set inversion flag
            isInverted = !isInverted
        }
        // Set inversion flag on Annex
        annex.isInverted = !annex.isInverted
    }
    
    // CFCharacterSetAddCharactersInRange (Open Range)
    @discardableResult
    internal func insert(charactersIn range: Range<Unicode.Scalar>) -> Bool {
        if range.isEmpty {
            return false
        }
        
        // NOTE: 0xD800 - 0xDFFF are supposed to be invalid.
        // We need to handle some special cases here, as follows:
        //
        // Case 1: Developers can make range such as 0xD700..<0xE000,
        // but because we default to calling insert(charactersIn:) with closedRange,
        // calling into it with 0xD700...0xDFFF will crash.
        // We should not crash and instead insert 0xD700...0xD7FF (up to valid upper bound).
        //
        // Case 2: Developers can make range such as 0x0000..<0x10FFFF
        // Even though it includes the range 0xD800...0xDFFF, we don't have to handle it
        // because if there were to be a case where we have to check contains(), which takes a Unicode.Scalar,
        // checking surrogate value should just crash because they'd have to force unwrap before calling into contains().
        
        if let closedUpperBound = Unicode.Scalar(range.upperBound.value - 1) {
            // Closed upper bound is not within 0xD800 - 0xDFFF
            let closedRange = range.lowerBound...closedUpperBound
            return insert(charactersIn: closedRange)
        } else {
            // If it even gets here, it means lower bound is guaranteed to be at most 0xD7FF.
            // Closed upper bound is within 0xD800 - 0xDFFF, clamp the upper bound to 0xD7FF.
            let surrogateStart = 0xD800
            let clampedClosedUpperBound = surrogateStart - 1
            let closedRange = range.lowerBound...UnicodeScalar(clampedClosedUpperBound)!
            return insert(charactersIn: closedRange)
        }
    }
    
    // CFCharacterSetAddCharactersInRange (ClosedRange) - contains implementation
    @discardableResult
    internal func insert(charactersIn range: ClosedRange<Unicode.Scalar>) -> Bool {
        if range.isEmpty || isInverted && isEmpty {
            return false
        }
        
        if !isInverted {
            if isEmpty {
                self.storage = .range(RangeBacked(range: range))
                return true
            }
            
            switch storage {
            case .range(let rangeBacked):
                if let merged = rangeBacked.closedRange.merging(range) {
                    self.storage = .range(RangeBacked(range: merged))
                    return true
                }
            case .string(var stringBacked):
                // NOTE: Clear storage to avoid CoW when accessing guts
                self.storage = .empty
                if modifyStringBacked(&stringBacked, with: range, operation: .add) {
                    return true
                }
                self.storage = .string(stringBacked)
            default:
                break
            }
        }

        self.makeBitmap()
        self.addNonBMPPlanes(inRange: range)
        insertIntoBitmap(range: range)
        return true
    }
    
    // CFCharacterSetAddCharactersInString
    @discardableResult
    internal func insert(charactersIn string: String) -> Bool {
        return insert(charactersIn: string.unicodeScalars)
    }
    
    // CFCharacterSetAddCharactersInString - optimized version that takes guts directly
    @discardableResult
    internal func insert(charactersIn unicodeScalars: String.UnicodeScalarView) -> Bool {
        guard !(isEmpty && isInverted) && unicodeScalars.count > 0 else {
            return false
        }
        
        if !isInverted {
            // Calculate new length if we combine with existing characters
            let currentLength: Int
            switch storage {
            case .string(let stringBacked):
                currentLength = stringBacked.guts.count
            default:
                currentLength = isEmpty ? 0 : Self.__kCFStringCharSetMax
            }
            
            let newLength = currentLength + unicodeScalars.count
            
            // If total characters would be small enough, try string-backed storage
            if newLength < Self.__kCFStringCharSetMax {
                var hasNonBMP = false
                var bmpCharacters: [Unicode.Scalar] = []
                
                switch storage {
                case .string(let stringBacked):
                    // Get existing BMP characters if we have string storage
                    bmpCharacters = stringBacked.guts
                    
                    // Process input unicode scalar characters
                    for scalar in unicodeScalars {
                        if scalar.value > 0xFFFF {
                            // This is a non-BMP character (represented by surrogate pair in UTF-16)
                            hasNonBMP = true
                        } else {
                            // BMP character - add to our buffer
                            if !bmpCharacters.contains(scalar) {
                                bmpCharacters.append(scalar)
                            }
                        }
                    }
                    
                    // If we have any characters for string storage
                    if !bmpCharacters.isEmpty {
                        // Update storage to string-backed
                        let stringBacked = StringBacked(guts: bmpCharacters)
                        self.storage = .string(stringBacked)
                        if hasNonBMP {
                            modifyNonBMPPlanes(unicodeScalars: unicodeScalars, operation: .add)
                        }
                        
                        return true
                    }
                default:
                    break
                }
            }
        }
        
        // Convert to bitmap to continue processing
        self.makeBitmap()
        insertIntoBitmap(unicodeScalars: unicodeScalars)
        return true
    }
    
    // CFCharacterSetRemoveCharactersInRange (Open Range)
    @discardableResult
    internal func remove(charactersIn range: Range<Unicode.Scalar>) -> Bool {
        if range.isEmpty {
            return false
        }

        // NOTE: 0xD800 - 0xDFFF are supposed to be invalid.
        // We need to handle some special cases here, as follows:
        //
        // Case 1: Developers can make range such as 0xD700..<0xE000,
        // but because we default to calling remove(charactersIn:) with closedRange,
        // calling into it with 0xD700...0xDFFF will crash.
        // We should not crash and instead remove 0xD700...0xD7FF (up to valid upper bound).
        //
        // Case 2: Developers can make range such as 0x0000..<0x10FFFF
        // Even though it includes the range 0xD800...0xDFFF, we don't have to handle it
        // because if there were to be a case where we have to check contains(), which takes a Unicode.Scalar,
        // checking surrogate value should just crash because they'd have to force unwrap before calling into contains().
        
        if let closedUpperBound = Unicode.Scalar(range.upperBound.value - 1) {
            // Closed upper bound is not within 0xD800 - 0xDFFF
            let closedRange = range.lowerBound...closedUpperBound
            return remove(charactersIn: closedRange)
        } else {
            // If it even gets here, it means lower bound is guaranteed to be at most 0xD7FF.
            // Closed upper bound is within 0xD800 - 0xDFFF, clamp the upper bound to 0xD7FF.
            let surrogateStart = 0xD800
            let clampedClosedUpperBound = surrogateStart - 1
            let closedRange = range.lowerBound...UnicodeScalar(clampedClosedUpperBound)!
            return remove(charactersIn: closedRange)
        }
    }
    
    // CFCharacterSetRemoveCharactersInRange (Closed Range)
    @discardableResult
    internal func remove(charactersIn range: ClosedRange<Unicode.Scalar>) -> Bool {
        if range.isEmpty || isEmpty && !isInverted  {
            return false
        }
        
        if isInverted {
            if isEmpty {
                // If isInverted and empty, it included everything, so setting this range means we remove it.
                self.storage = .range(RangeBacked(range: range))
            }
            
            switch storage {
            case .range(let rangeBacked):
                if let merged = rangeBacked.closedRange.merging(range) {
                    self.storage = .range(RangeBacked(range: merged))
                    return true
                }
            case .string(var stringBacked):
                // NOTE: Clear storage to avoid CoW when accessing guts
                self.storage = .empty
                if modifyStringBacked(&stringBacked, with: range, operation: .remove) {
                    return true
                }
                self.storage = .string(stringBacked)
            default:
                break
            }
        }
        
        self.makeBitmap()
        self.removeNonBMPPlanes(inRange: range)
        removeFromBitmap(range: range)
        return true
    }
    
    // CFCharacterSetRemoveCharactersInString
    internal func remove(charactersIn string: String) -> Bool {
        guard !string.isEmpty else { return false }
        
        // Early exit - normal empty set has nothing to remove
        if isEmpty && !isInverted { return false }
        
        if isInverted {
            // Calculate new length for exclusion list
            let currentLength: Int
            switch storage {
            case .string(let stringBacked):
                currentLength = stringBacked.guts.count
            default:
                currentLength = isEmpty ? 0 : Self.__kCFStringCharSetMax
            }
            
            let newLength = string.unicodeScalars.count + currentLength
            
            // Try string-backed storage for exclusion list
            if newLength < Self.__kCFStringCharSetMax {
                var hasNonBMP = false
                var excludedCharacters: [Unicode.Scalar] = []
                
                // Get existing excluded characters
                if case .string(let stringBacked) = storage {
                    excludedCharacters = stringBacked.guts
                }
                
                // Add characters from string to exclusion list
                for scalar in string.unicodeScalars {
                    if scalar.value > 0xFFFF {
                        hasNonBMP = true
                    } else {
                        // Add to exclusion list (BMP characters)
                        if !excludedCharacters.contains(scalar) {
                            excludedCharacters.append(scalar)
                        }
                    }
                }
                
                // Update storage with exclusion list
                let stringBacked = StringBacked(guts: excludedCharacters)
                self.storage = .string(stringBacked)
                
                if hasNonBMP {
                    modifyNonBMPPlanes(unicodeScalars: string.unicodeScalars, operation: .remove)
                }
                
                return true
            }
        }
            
        if !isInverted, case .compactBitmap(let cBitmapBacked) = storage {
            if let removed = cBitmapBacked.removing(charactersIn: string) {
                self.storage = .compactBitmap(removed)
                return true
            }
        }

        self.makeBitmap()
        removeFromBitmap(string: string)
        return true
    }
    
    // MARK: Helper methods
    private func insertIntoBitmap(range: ClosedRange<Unicode.Scalar>) {
        switch storage {
        case .bitmap(var bitmapBacked):
            if range.lowerBound.value < 0x10000 { // theRange is in BMP
                let firstChar = UInt16(range.lowerBound.value)
                let lastChar: UInt16
                
                if range.upperBound.value >= Self.NUMCHARACTERS {
                    // Clamp to maximum BMP character
                    lastChar = UInt16(Self.NUMCHARACTERS - 1)
                } else {
                    lastChar = UInt16(range.upperBound.value)
                }
                
                if bitmapBacked.span.count > 0 {
                    // NOTE: Clear storage to avoid CoW when accessing mutableSpan
                    self.storage = .empty
                    var mutableSpan = bitmapBacked.mutableSpan
                    Self.addCharacters(to: &mutableSpan, firstChar: UInt32(firstChar), lastChar: UInt32(lastChar))
                    self.storage = .bitmap(BitmapBacked(data: bitmapBacked.data))
                }
            }
        default:
            break
        }
    }
    
    internal func insertIntoBitmap(string: String) {
        insertIntoBitmap(unicodeScalars: string.unicodeScalars)
    }
    
    private func insertIntoBitmap(unicodeScalars: String.UnicodeScalarView) {
        var hasNonBMP = false
        for scalar in unicodeScalars {
            if scalar.value > 0xFFFF {
                hasNonBMP = true
                break
            }
        }

        if case .bitmap(var bitmapBacked) = storage {
            if bitmapBacked.span.count == 0 {
                // Allocate bitmap if it doesn't exist
                bitmapBacked.data = _CharacterSet.allZeros()
            }
            // NOTE: Clear storage to avoid CoW when accessing mutableSpan
            self.storage = .empty
            var mutableSpan = bitmapBacked.mutableSpan
            for scalar in unicodeScalars where scalar.value <= 0xFFFF {
                _CharacterSet.modifyBitmap(.add, char: UInt16(scalar.value), mutableSpan: &mutableSpan)
            }
            // Update storage with modified bitmap
            self.storage = .bitmap(bitmapBacked)
        }

        if hasNonBMP {
            modifyNonBMPPlanes(unicodeScalars: unicodeScalars, operation: .add)
        }
    }
    
    private func removeFromBitmap(range: ClosedRange<Unicode.Scalar>) {
        switch storage {
        case .bitmap(var bitmapBacked):
            if range.lowerBound.value < 0x10000 { // range is in BMP
                let firstChar = UInt16(range.lowerBound.value)
                let lastChar: UInt16
                
                if range.upperBound.value >= Self.NUMCHARACTERS {
                    // Clamp to maximum BMP character
                    lastChar = UInt16(Self.NUMCHARACTERS - 1)
                } else {
                    lastChar = UInt16(range.upperBound.value)
                }
                
                // Check if we're removing the entire BMP range
                if range.lowerBound.value == 0 && range.upperBound.value >= Self.NUMCHARACTERS - 1 {
                    self.storage = .empty
                } else {
                    if bitmapBacked.span.count > 0 {
                        // NOTE: Clear storage to avoid CoW when accessing mutableSpan
                        self.storage = .empty
                        var mutableSpan = bitmapBacked.mutableSpan
                        Self.removeCharacters(from: &mutableSpan, firstChar: UInt32(firstChar), lastChar: UInt32(lastChar))
                        self.storage = .bitmap(BitmapBacked(data: bitmapBacked.data))
                    }
                }
            }
        default:
            break
        }
    }
    
    private func removeFromBitmap(string: String) {
        var hasNonBMP = false
        // Process each character in the string
        for scalar in string.unicodeScalars {
            if scalar.value > 0xFFFF {
                hasNonBMP = true
            } else {
                // BMP character - remove directly from bitmap
                
                if case .bitmap(var bitmapBacked) = storage {
                    if bitmapBacked.span.count == 0 {
                        // Allocate bitmap if it doesn't exist
                        bitmapBacked.data = _CharacterSet.allZeros()
                    }
                    // NOTE: Clear storage to avoid CoW when accessing mutableSpan
                    self.storage = .empty
                    var mutableSpan = bitmapBacked.mutableSpan
                    _CharacterSet.modifyBitmap(.remove, char: UInt16(scalar.value), mutableSpan: &mutableSpan)
                    // Update storage with modified bitmap
                    self.storage = .bitmap(bitmapBacked)
                }
            }
        }
                
        if hasNonBMP {
            modifyNonBMPPlanes(unicodeScalars: string.unicodeScalars, operation: .remove)
        }
    }
    
    internal func modifyStringBacked(_ stringBacked: inout StringBacked, with range: ClosedRange<Unicode.Scalar>, operation: Operation) -> Bool {
        let lowerBound = range.lowerBound.value
        let bmpUpper = min(range.upperBound.value, 0xFFFF)
        let bmpLength = lowerBound <= 0xFFFF ? Int(bmpUpper - lowerBound + 1) : 0
        guard (stringBacked.guts.count + bmpLength) < Self.__kCFStringCharSetMax else {
            return false
        }
        // Only append BMP scalars to guts; non-BMP go to annex
        if lowerBound <= 0xFFFF {
            for rawValue in lowerBound...bmpUpper {
                guard let scalar = Unicode.Scalar(rawValue) else { continue }
                if !stringBacked.guts.contains(scalar) {
                    stringBacked.guts.append(scalar)
                }
            }
            stringBacked.guts.sort()
        }
        self.storage = .string(stringBacked)
        // Route non-BMP characters to annex planes
        if range.upperBound.value > 0xFFFF {
            switch operation {
            case .add:
                self.addNonBMPPlanes(inRange: range)
            case .remove:
                self.removeNonBMPPlanes(inRange: range)
            }
        }
        return true
    }
}

// Helper to merge adjacent ranges
extension ClosedRange where Bound == Unicode.Scalar {
    func merging(_ other: ClosedRange<Unicode.Scalar>) -> ClosedRange<Unicode.Scalar>? {
        guard upperBound.value + 1 >= other.lowerBound.value &&
                other.upperBound.value + 1 >= lowerBound.value else {
            return nil
        }
        return Swift.min(lowerBound, other.lowerBound)...Swift.max(upperBound, other.upperBound)
    }
}
