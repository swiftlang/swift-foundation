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

#if FOUNDATION_FRAMEWORK
@_spi(Unstable) internal import CollectionsInternal
#elseif canImport(_RopeModule)
internal import _RopeModule
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

internal final class _CharacterSet {
    
    static let NUMCHARACTERS = 65536
    static let BITSPERBYTE = 8
    static let LOG_BPB = 3
    static let __kCFBitmapSize = NUMCHARACTERS / BITSPERBYTE
    static let __kCFCompactBitmapNumPages = 256
    static let __kCFCompactBitmapMaxPages = 128
    static let __kCFCompactBitmapPageSize = __kCFBitmapSize / __kCFCompactBitmapNumPages
    static let __kCFStringCharSetMax = 64
    static let MAX_ANNEX_PLANE = 16
    
    enum Operation {
        case add
        case remove
    }
    
    enum Storage {
        case empty
        case builtIn(_ predefined: BuiltInUnicodeScalarSet)
        case range(_ rangeBacked: _CharacterSet.RangeBacked)
        case string(_ stringBacked: _CharacterSet.StringBacked)
        case bitmap(_ bitmapBacked: _CharacterSet.BitmapBacked)
        case compactBitmap(_ cBitmapBacked: _CharacterSet.CompactBitmapBacked)
        
        func deepCopy() -> _CharacterSet.Storage {
            switch self {
            case .empty:
                return .empty
                
            case .builtIn(let predefined):
                return .builtIn(predefined)
                
            case .range(let rangeBacked):
                return .range(rangeBacked)
                
            case .string(let stringBacked):
                return .string(stringBacked)
                
            case .bitmap(let bitmapBacked):
                return .bitmap(bitmapBacked)
                
            case .compactBitmap(let cBitmapBacked):
                return .compactBitmap(cBitmapBacked)
            }
        }
    }
    
    // Cached hash value.
    // Invalidated on any mutation via didSet on storage/isInverted/annex.
    internal var _hashValue: Int?

    var storage: Storage {
        didSet { _hashValue = nil }
    }
    var isInverted: Bool {
        didSet { _hashValue = nil }
    }
    var annex: Annex = Annex() {
        didSet { _hashValue = nil }
    }
    
    // MARK: Initializers
    
    // CFCharacterSetGetPredefined
    #if FOUNDATION_FRAMEWORK
    convenience init(_builtIn: CFCharacterSetPredefinedSet) {
        let builtInUnicodeScalarSet = BuiltInUnicodeScalarSet(cfpredefined: _builtIn)
        self.init(storage: .builtIn(builtInUnicodeScalarSet))
    }
    #endif

    convenience init(builtInType type: BuiltInUnicodeScalarSet.SetType) {
        self.init(storage: .builtIn(BuiltInUnicodeScalarSet(type: type)))
    }
    
    // CFCharacterSetCreateWithBitmapRepresentation
    convenience init(bitmapRepresentation data: Data) {
        
        guard !data.isEmpty else {
            self.init(storage: .empty)
            return
        }
        
        // __CFCharacterSetInitWithBitmapRepresentation
        let span = data.span
        if span.count < Self.__kCFBitmapSize {
            
            // If length is less than 8192 bytes, we want to pad it so that it is 8192 bytes.
            let fullSizedData = Data(capacity: Self.__kCFBitmapSize) { output in
                output._append(copying: span.bytes)
                output.append(repeating: 0x00, count: Self.__kCFBitmapSize - span.count, as: UInt8.self)
            }
            let fullSizedSpan = fullSizedData.span
            if let compactData = Self.createCompactBitmapFast(from: fullSizedSpan) {
                self.init(storage: .compactBitmap(CompactBitmapBacked(data: compactData)))
            } else {
                self.init(storage: .bitmap(BitmapBacked(data: fullSizedData)))
            }
        } else {
            // Handle case where data.count >= __kCFBitmapSize
            // First process BMP plane
            var bmpStorage: Storage
            if let compactData = Self.createCompactBitmapFast(from: span) {
                bmpStorage = .compactBitmap(CompactBitmapBacked(data: compactData))
            } else {
                if span.count == Self.__kCFBitmapSize {
                    bmpStorage = .bitmap(BitmapBacked(data: data))  // No copy!
                } else {
                    let bmpData = data.subdata(in: 0..<_CharacterSet.__kCFBitmapSize)
                    bmpStorage = .bitmap(BitmapBacked(data: bmpData))
                }
            }
            
            // Process supplementary planes if present
            var annex = Annex()
            if span.count > Self.__kCFBitmapSize {
                var remainingLength = span.count - Self.__kCFBitmapSize
                var byteOffset = Self.__kCFBitmapSize
                
                while remainingLength > 1 {
                    // First byte is the plane number (1-16)
                    let planeNumber = span[byteOffset]
                    byteOffset += 1
                    remainingLength -= 1
                    
                    let planeNum = Int(planeNumber)
                    // Get or create character set for this plane
                    guard planeNum >= 1 && planeNum <= Self.MAX_ANNEX_PLANE else {
                        // Skip this plane if we can't create the annex set
                        let skipBytes = min(remainingLength, Self.__kCFBitmapSize)
                        byteOffset += skipBytes
                        remainingLength -= skipBytes
                        continue
                    }
                    
                    // Because this will crash when planeNumber is not within bounds, we check and skip if planeNumber is out of bounds
                    let annexSet = annex.getCharacterSet(forPlane: planeNum)
                    
                    if remainingLength < Self.__kCFBitmapSize {
                        
                        // Create padded plane data directly in properly sized Data
                        let planeData = Data(capacity: Self.__kCFBitmapSize) { output in
                            output._append(copying: span.extracting(byteOffset..<(byteOffset + remainingLength)).bytes)
                            output.append(repeating: 0x00, count: Self.__kCFBitmapSize - remainingLength, as: UInt8.self)
                        }

                        // Try compression and store using fast version
                        let planeSpan = planeData.span
                        if let compactPlaneData = Self.createCompactBitmapFast(from: planeSpan) {
                            annexSet.storage = .compactBitmap(CompactBitmapBacked(data: compactPlaneData))
                        } else {
                            annexSet.storage = .bitmap(BitmapBacked(data: planeData))
                        }
                        
                        // Update the plane in the annex
                        annex.setCharacterSet(annexSet, forPlane: Int(planeNumber))
                        break // No more data to process
                    } else {
                        
                        // Handle full plane data
                        let planeData = Data(capacity: Self.__kCFBitmapSize) { output in
                            output._append(copying: span.extracting(byteOffset..<(byteOffset + Self.__kCFBitmapSize)).bytes)
                        }
                        
                        // Try compression and store using fast version
                        let planeSpan = planeData.span
                        if let compactPlaneData = Self.createCompactBitmapFast(from: planeSpan) {
                            // Use compressed version
                            annexSet.storage = .compactBitmap(CompactBitmapBacked(data: compactPlaneData))
                        } else {
                            // Use uncompressed version
                            annexSet.storage = .bitmap(BitmapBacked(data: planeData))
                        }
                        
                        // Update the plane in the annex
                        annex.setCharacterSet(annexSet, forPlane: Int(planeNumber))

                        // Move to next plane
                        byteOffset += Self.__kCFBitmapSize
                        remainingLength -= Self.__kCFBitmapSize
                    }
                }
            }
            
            // Initialize with all components ready
            self.init(storage: bmpStorage, isInverted: false)
            self.annex = annex
        }
    }
    
    // CFCharacterSetCreateWithCharactersInString
    internal convenience init(charactersIn string: String) {
        guard !string.isEmpty else {
            self.init(storage: .empty)
            return
        }

        #if !os(watchOS)
        if string.utf8Span.isKnownASCII, string.utf8.count < Self.__kCFStringCharSetMax {
            var mask: UInt128 = 0
            for byte in string.utf8 {
                mask |= 1 &<< UInt128(byte)
            }
            var scalars: [Unicode.Scalar] = []
            scalars.reserveCapacity(mask.nonzeroBitCount)
            while mask != 0 {
                scalars.append(Unicode.Scalar(UInt8(truncatingIfNeeded: mask.trailingZeroBitCount)))
                mask &= mask &- 1
            }
            self.init(storage: .string(StringBacked(sortedGuts: scalars)))
            return
        }
        #endif

        let scalars = string.unicodeScalars
        var hasNonBMP = false
        var scalarCount = 0
        for scalar in scalars {
            scalarCount += 1
            if scalarCount >= Self.__kCFStringCharSetMax {
                break
            }
            if scalar.value > 0xFFFF {
                hasNonBMP = true
            }
        }
        
        if scalarCount < Self.__kCFStringCharSetMax {
            if !hasNonBMP {
                self.init(storage: .string(StringBacked(guts: Array(scalars))))
            } else {
                var bmpScalars: [Unicode.Scalar] = []
                var nonBMPScalars = String.UnicodeScalarView()
                for scalar in scalars {
                    if scalar.value > 0xFFFF {
                        nonBMPScalars.append(scalar)
                    } else {
                        bmpScalars.append(scalar)
                    }
                }
                self.init(storage: .string(StringBacked(guts: bmpScalars)))
                modifyNonBMPPlanes(unicodeScalars: nonBMPScalars, operation: .add)
            }
        } else {
            self.init(storage: .empty)
            makeBitmap()
            insertIntoBitmap(string: string)
            makeCharacterSetCompact()
        }
    }
    
    // CFCharacterSetCreateWithCharactersInRange
    internal convenience init(charactersIn range: Range<Unicode.Scalar>) {
        if !range.isEmpty {
            self.init(storage: .range(RangeBacked(range: range)))
        } else {
            self.init(storage: .empty)
        }
    }
    
    internal convenience init(charactersIn range: ClosedRange<Unicode.Scalar>) {
        if !range.isEmpty {
            // Optimization: a non-inverted range covering all of Unicode is logically
            // equivalent to an inverted empty set.
            if range.lowerBound.value == 0, range.upperBound.value == 0x10FFFF {
                self.init(storage: .empty, isInverted: true)
                self.annex = Annex(isInverted: true)
            } else {
                self.init(storage: .range(RangeBacked(range: range)))
            }
        } else {
            self.init(storage: .empty)
        }
    }
    
    // CFCharacterSetCreateMutable
    internal convenience init() {
        self.init(storage: .empty)
    }
    
    private init(storage: Storage, isInverted: Bool = false) {
        self.isInverted = isInverted
        self.storage = storage
    }
    
    // MARK: Helper functions
    
    // __CFCSetIsEmpty
    internal var isEmpty: Bool {
        switch storage {
        case .empty:
            return true
        case .builtIn(_):
            return false
        case .range(let rangeBacked):
            if hasNonBMPPlane || annexIsInverted {
                return false
            }
            return rangeBacked.isEmpty
        case .string(let stringBacked):
            if hasNonBMPPlane || annexIsInverted {
                return false
            }
            return stringBacked.isEmpty
        case .bitmap(let bitmapBacked):
            if hasNonBMPPlane || annexIsInverted {
                return false
            }
            return bitmapBacked.isEmpty
        case .compactBitmap(let cBitmapBacked):
            if hasNonBMPPlane || annexIsInverted {
                return false
            }
            return cBitmapBacked.isEmpty
        }
    }
    
    // CFCharacterSetCreateMutableCopy
    func copy() -> _CharacterSet {
        let copied = _CharacterSet(storage: self.storage.deepCopy(), isInverted: self.isInverted)
        
        // Deep copy annex if present
        copied.annex = self.annex.deepCopy()
        
        return copied
    }

    // CFCharacterSetCreateCopy
    func compactCopy() -> _CharacterSet {
        let copied = self.copy()
        copied.makeCharacterSetCompact()
        return copied
    }
}

extension _CharacterSet: Equatable, Hashable {
    
    static func == (lhs: _CharacterSet, rhs: _CharacterSet) -> Bool {
        // Add pointer equality check
        if lhs === rhs { return true }
        
        if let lh = lhs._hashValue, let rh = rhs._hashValue, lh != rh {
            return false
        }
        
        // Quick checks for inversion state
        let isInvertStateIdentical = (lhs.isInverted == rhs.isInverted)
        
        // Fast path: Same storage type (excluding compact bitmap which needs special handling)
        switch (lhs.storage, rhs.storage) {
        case (.empty, .empty):
            return isInvertStateIdentical
            
        case (.builtIn(let predefined1), .builtIn(let predefined2)):
            guard predefined1.charset == predefined2.charset && isInvertStateIdentical else {
                return false
            }
            return true
            
        case (.range(let rangeBacked1), .range(let rangeBacked2)):
            guard rangeBacked1.closedRange == rangeBacked2.closedRange && isInvertStateIdentical else {
                return false
            }
            return true
            
        case (.string(let string1), .string(let string2)):
            // String-backed storage doesn't guarantee order, so we need to compare as sets
            let set1 = Set(string1.guts)
            let set2 = Set(string2.guts)
            
            // NOTE: Handle out of order but same elements
            guard set1 == set2 && isInvertStateIdentical else {
                return false
            }
            return lhs.isEqualAnnex(rhs)
            
        case (.bitmap(let bitmapBacked1), .bitmap(let bitmapBacked2)):
            guard bitmapBacked1.data == bitmapBacked2.data else {
                return false
            }
            return lhs.isEqualAnnex(rhs)
            
        case (.compactBitmap(let cBitmapBacked1), .compactBitmap(let cBitmapBacked2)):
            guard cBitmapBacked1.data == cBitmapBacked2.data else {
                return false
            }
            return lhs.isEqualAnnex(rhs)
            
        default:
            if hasImplicitNonBMP(lhs) || hasImplicitNonBMP(rhs) {
                return lhs.bitmapRepresentation == rhs.bitmapRepresentation
            }
            
            let lhsAnnexInverted = lhs.annexIsInverted
            let rhsAnnexInverted = rhs.annexIsInverted
            if lhsAnnexInverted == rhsAnnexInverted {
                let lhsPlanes = lhs.annex.populatedPlanes
                let rhsPlanes = rhs.annex.populatedPlanes
                if lhsPlanes != rhsPlanes {
                    return false
                }
            }

            return lhs.bitmap() == rhs.bitmap() && lhs.isEqualAnnex(rhs)
        }
    }
    
    static func hasImplicitNonBMP(_ cs: _CharacterSet) -> Bool {
        switch cs.storage {
        case .builtIn, .range: return true
        case .empty: return cs.isInverted
        case .string, .bitmap, .compactBitmap: return false
        }
    }
    
    private func isEqualAnnex(_ other: _CharacterSet) -> Bool {
        let isAnnexInvertStateIdentical = (self.annexIsInverted == other.annexIsInverted)

        let selfBitmap = self.annex.populatedPlanes
        let otherBitmap = other.annex.populatedPlanes

        if isAnnexInvertStateIdentical {
            // Quick check: if different planes are populated, not equal
            if selfBitmap != otherBitmap { return false }

            // Only iterate planes that are actually populated
            var mask = selfBitmap
            while mask != 0 {
                let planeIndex = Int(mask.trailingZeroBitCount)
                mask &= mask &- 1 // clear lowest set bit

                let plane1 = self.getAnnexPlaneCharacterSetNoAlloc(planeIndex + 1)
                let plane2 = other.getAnnexPlaneCharacterSetNoAlloc(planeIndex + 1)

                if let p1 = plane1, let p2 = plane2 {
                    if p1 != p2 {
                        return false
                    }
                } else if let p1 = plane1 {
                    if !Self.bytes(of: p1.bitmap().span, equalTo: other.annexIsInverted ? 0xFF : 0x00) {
                        return false
                    }
                } else if let p2 = plane2 {
                    if !Self.bytes(of: p2.bitmap().span, equalTo: self.annexIsInverted ? 0xFF : 0x00) {
                        return false
                    }
                } else if self.annexIsInverted != other.annexIsInverted {
                    return false
                }
            }
            return true
        } else {
            // Different inversion states - need to compare with inversion
            // Iterate over all planes that are populated on either side
            let mask = selfBitmap | otherBitmap
            if mask != 0xFFFF {
                return false
            }

            for planeIndex in 1...Self.MAX_ANNEX_PLANE{
                let plane1 = self.getAnnexPlaneCharacterSetNoAlloc(planeIndex)
                let plane2 = other.getAnnexPlaneCharacterSetNoAlloc(planeIndex)
                
                if let p1 = plane1, let p2 = plane2 {
                    let bitmap1 = p1.bitmap().span
                    let bitmap2 = p2.bitmap().span
                    if !self.isEqualBitmapInverted(bitmap1, bitmap2) {
                        return false
                    }
                } else if let p1 = plane1 {
                    if !Self.bytes(of: p1.bitmap().span, equalTo: 0xFF) {
                        return false
                    }
                } else if let p2 = plane2 {
                    if !Self.bytes(of: p2.bitmap().span, equalTo: 0xFF) {
                        return false
                    }
                }
            }
            return true
        }
    }
    
    private func isEqualBitmapInverted(_ span1: Span<UInt8>, _ span2: Span<UInt8>) -> Bool {
        guard span1.count == span2.count else {
            return false
        }
        
        for i in 0..<span1.count {
            if span1[i] != ~span2[i] {
                return false
            }
        }
        return true
    }
    
    func hash(into hasher: inout Hasher) {
        if let cached = _hashValue {
            hasher.combine(cached)
            return
        }
        // Hash only the BMP plane (plane 0) & Cache
        // Use stack-allocated buffer via appendBitmap to avoid Data heap allocation
        var cacheHasher = Hasher()
        withTemporaryAllocation(of: UInt8.self, capacity: Self.__kCFBitmapSize) { output in
            appendBitmap(to: &output)
            output.span.withUnsafeBytes { cacheHasher.combine(bytes: $0) }
        }
        let cachedHashValue = cacheHasher.finalize()
        _hashValue = cachedHashValue
        hasher.combine(cachedHashValue)
    }
}


extension _CharacterSet: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String {
        
        var result = ""

        switch storage {
        case .empty:
            result += "CharacterSet: empty"

        case .builtIn(let predefined):
            result += "CharacterSet: \(predefined.charset)"
            
        case .range(let rangeBacked):
            result += "CharacterSet: \(rangeBacked.closedRange.lowerBound)...\(rangeBacked.closedRange.upperBound)"
            
        case .string(let stringBacked):
            result += "CharacterSet: \(stringBacked.guts)"
            
        case .bitmap(let bitmapBacked):
            result += "CharacterSet: \(bitmapBacked.data.description)"
            
        case .compactBitmap(let cBitmapBacked):
            result += "CharacterSet: \(cBitmapBacked.data.description)"
            
        }
        
        result += ", Inverted: \(isInverted)"
        
        if annex.populatedPlanes != 0 || annex.isInverted {
            result += "\n  Annex:"
            result += "\n    Inverted: \(annex.isInverted)"
            
            var activePlanes: [(Int, _CharacterSet)] = []
            for index in annex.nonBMPPlanes.indices {
                guard let plane = annex.nonBMPPlanes[index], !plane.isEmpty else { continue }
                activePlanes.append((index + 1, plane))
            }
            
            if activePlanes.isEmpty {
                result += "\n    Planes: (none active)"
            } else {
                result += "\n    Planes:"
                for (planeNumber, plane) in activePlanes {
                    let planeDesc = String(describing: plane.storage)
                        .split(separator: "\n")
                        .joined(separator: "\n      ")
                    result += "\n      Plane \(planeNumber): \(planeDesc)"
                    if plane.isInverted {
                        result += " [Plane Inverted]"
                    }
                }
            }
        } else {
            result += "\n  Annex: (none)"
        }
        
        return result
    }
    
    var debugDescription: String {
        return description
    }
}

