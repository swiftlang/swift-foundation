//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

internal import _FoundationCShims

#if canImport(Synchronization)
internal import Synchronization
#endif

#if FOUNDATION_FRAMEWORK
@_spi(Unstable) internal import CollectionsInternal
#elseif canImport(_RopeModule)
internal import _RopeModule
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

// Native implementation of CFCharacterSet.
// Represents sets of unicode scalars of those whose bitmap data we own.
// whitespace, whitespaceAndNewline, and newline are not included since they're not stored with bitmaps
// This only contains a subset of predefined CFCharacterSet that are in use for now.
internal struct BuiltInUnicodeScalarSet {
    enum SetType {
        case control
        case whitespace
        case whitespaceAndNewline
        case decimalDigit
        case letter
        case lowercaseLetter
        case uppercaseLetter
        case nonBase
        case canonicalDecomposable
        case alphanumeric
        case punctuation
        case illegal
        case titlecase
        case symbolAndOperator
        case newline

        // Below are internal
        case compatibilityDecomposable
        case hfsPlusDecomposable
        case strongRightToLeft
        case hasNonSelfLowercase
        case hasNonSelfUppercase
        case hasNonSelfTitlecase
        case hasNonSelfCaseFolding
        case hasNonSelfMirrorMapping
        case caseIgnorable
        case graphemeExtend
        
        // duplicates
        case controlAndFormatter
        case decomposable
    }

    var charset: SetType
    init(type: SetType) {
        charset = type
    }

    // __CFUniCharMapExternalSetToInternalIndex(__CFUniCharMapCompatibilitySetID())
    private var _bitmapTableIndex: Int? {
        switch charset {
        case .decimalDigit:
            return 0
        case .letter:
            return 1
        case .lowercaseLetter:
            return 2
        case .uppercaseLetter:
            return 3
        case .nonBase:
            return 4
        case .canonicalDecomposable:
            return 5
        case .alphanumeric:
            return 6
        case .punctuation:
            return 7
        case .illegal:
            return 8
        case .titlecase:
            return 9
        case .symbolAndOperator:
            return 10
        case .compatibilityDecomposable:
            return 11
        case .hfsPlusDecomposable:
            return 12
        case .strongRightToLeft:
            return 13
        case .hasNonSelfLowercase:
            return 14
        case .hasNonSelfUppercase:
            return 15
        case .hasNonSelfTitlecase:
            return 16
        case .hasNonSelfCaseFolding:
            return 17
        case .hasNonSelfMirrorMapping:
            return 18
        case .control:
            return 19
        case .caseIgnorable:
            return 20
        case .graphemeExtend:
            return 21
        case .decomposable:
            return 5
        case .controlAndFormatter:
            return 19
        case .whitespace, .whitespaceAndNewline, .newline:
            return nil
        }
    }
    
    enum BitmapResult {
        case bitmapFilled // kCFUniCharBitmapFilled
        case bitmapEmpty // kCFUniCharBitmapEmpty
        case bitmapAll // kCFUniCharBitmapAll
    }
    
    static let bitShiftForByte = UInt16(3)
    static let bitShiftForMask = UInt16(7)
    static let byteCount = 8 * 1024
    
    private struct BMPCacheKey: Hashable {
        let type: SetType
        let isInverted: Bool
    }

    #if canImport(Synchronization)
    private static let bmpCache = Mutex<[BMPCacheKey: Data]>([:])
    #else
    private static let bmpCache = LockedState<[BMPCacheKey: Data]>(initialState: [:])
    #endif

    private static func cachedBMP(for type: SetType, isInverted: Bool) -> Data {
        let key = BMPCacheKey(type: type, isInverted: isInverted)
        return bmpCache.withLock { cache in
            if let cached = cache[key] {
                return cached
            }
            let set = BuiltInUnicodeScalarSet(type: type)
            let (result, data) = set.bitmap(forPlane: 0, isInverted: isInverted)
            let bitmap: Data
            switch result {
            case .bitmapFilled: bitmap = data
            case .bitmapEmpty:  bitmap = _CharacterSet.allZeros
            case .bitmapAll:    bitmap = _CharacterSet.allOnes
            }
            cache[key] = bitmap
            return bitmap
        }
    }
    
    // CFCharacterSetCreateBitmapRepresentation
    func bitmapRepresentation(isInverted: Bool) -> Data {
        let numNonBMPPlanes = isInverted ? 16 : _numberOfPlanes - 1
        
        var data = Data()
        
        // Handle BMP Plane
        let bitmapData = getBitmap(isInverted: isInverted)
        data.append(bitmapData)
        
        // Handle other planes
        if numNonBMPPlanes > 0 {
            for i in 0..<numNonBMPPlanes {
                let (status, bitmap) = self.bitmap(forPlane: i + 1, isInverted: isInverted)
                
                if status == .bitmapEmpty {
                    continue
                }
                
                let indexData = Data([UInt8(i + 1)])
                data.append(indexData)
                
                if status == .bitmapAll {
                    let filledData = _CharacterSet.allOnes
                    data.append(filledData)
                } else {
                    data.append(bitmap)
                }
            }
        }
        return data
    }
    
    // CFCharacterSetHasMemberInPlane
    func hasMember(inPlane plane: UInt8, isInverted: Bool) -> Bool {
        if charset == .control {
            if isInverted || plane == 14 {
                // There is no plane that covers all values || Plane 14 has language tags
                return true
            } else {
                return bitmapPtrForPlane(Int(plane)) != nil
            }
        } else if charset == .whitespace || charset == .whitespaceAndNewline || charset == .newline {
            return plane == 0 || isInverted
        } else if charset == .illegal {
            if isInverted {
                return plane < 3 || plane > 13
            } else {
                return true
            }
        } else {
            if isInverted {
                // There is no plane that covers all values
                return true
            } else {
                if let _ = bitmapPtrForPlane(Int(plane)) {
                    return true
                } else {
                    return false
                }
            }
        }
    }
    
    // __CFCSetGetBitmap
    internal func getBitmap(isInverted: Bool) -> Data {
        return Self.cachedBMP(for: charset, isInverted: isInverted)
    }
    
    // CFUniCharIsMemberOf
    internal func contains(_ scalar: Unicode.Scalar) -> Bool {
        switch charset {
        case .whitespace:
            return isWhitespace(scalar)
        case .newline:
            return isNewline(scalar)
        case .whitespaceAndNewline:
            return isWhitespace(scalar) || isNewline(scalar)
        default:
            let planeNo = UInt8((scalar.value >> 16) & 0xFF)

            // The bitmap data for kCFUniCharIllegalCharacterSet is actually LEGAL set less Plane 14 ~ 16
            if charset == .illegal {
                if planeNo == 14 {
                    let charInPlane = scalar.value & 0xFF
                    return !(((charInPlane == 0x01) || ((charInPlane > 0x1F) && (charInPlane < 0x80))))
                } else if planeNo == 15 || planeNo == 16 {
                    let charInPlane = scalar.value & 0xFF
                    return charInPlane > 0xFFFD
                } else {
                    // fix for fetching ptr to legal
                    guard let (dataSpan, shouldInvert) = _bitmapPtrForPlane(Int(planeNo)) else {
                        return false
                    }

                    if planeNo < _numberOfPlanes {
                        let isMember = _isMemberOfBitmap(scalar, dataSpan)
                        return shouldInvert ? !isMember : isMember
                    }
                }
            } else if charset == .controlAndFormatter {
                if planeNo == 14 {
                    let charInPlane = scalar.value & 0xFF
                    return ((charInPlane == 0x01) || ((charInPlane > 0x1F) && (charInPlane < 0x80))) ? true : false
                } else {
                    // dataPtr will be nil for illegal case, causing the check to fail; the C implementation returns legal pointer for dataPtr
                    guard let dataSpan = bitmapPtrForPlane(Int(planeNo)) else {
                        return false
                    }

                    if planeNo < _numberOfPlanes {
                        return _isMemberOfBitmap(scalar, dataSpan)
                    }
                }
            } else {
                // dataPtr will be nil for illegal case, causing the check to fail; the C implementation returns legal pointer for dataPtr
                guard let dataSpan = bitmapPtrForPlane(Int(planeNo)) else {
                    return false
                }
                if planeNo < _numberOfPlanes {
                    return _isMemberOfBitmap(scalar, dataSpan)
                }
            }
            return false
        }
    }
    
    // CFUniCharIsMemberOfBitmap
    func _isMemberOfBitmap(_ scalar: Unicode.Scalar, _ span: Span<UInt8>) -> Bool {
        let theChar = UInt16(truncatingIfNeeded: scalar.value) // intentionally truncated

        let position = span[Int(theChar >> Self.bitShiftForByte)]
        let mask = theChar & Self.bitShiftForMask
        let bitMask = UInt32(1) << mask
        let result = (UInt32(position) & bitMask) != 0
        return result
    }
    
    // CFUniCharGetBitmapPtrForPlane
    // Returns nil for whitespace, whitespaceAndNewline, newline.
    // For callers that only need to check plane membership (not inversion), use this wrapper.
    @_lifetime(immortal)
    internal func bitmapPtrForPlane(_ plane: Int) -> Span<UInt8>? {
        _bitmapPtrForPlane(plane)?.span
    }

    // Full version used internally; the `shouldInvert` flag indicates that the stored bitmap
    // is the LEGAL set (for illegal charset) and callers must invert membership results.
    @_lifetime(immortal)
    private func _bitmapPtrForPlane(_ plane: Int) -> (span: Span<UInt8>, shouldInvert: Bool)? {
        switch charset {
        case .whitespace, .whitespaceAndNewline, .newline:
            return nil
        default:
            guard let tableIndex = _bitmapTableIndex else {
                return nil
            }

            guard tableIndex < __CFUniCharNumberOfBitmaps else {
                return nil
            }

            let data = withUnsafePointer(to: __CFUniCharBitmapDataArray) { ptr in
                ptr.withMemoryRebound(to: __CFUniCharBitmapData.self, capacity: Int(__CFUniCharNumberOfBitmaps)) { bitmapDataPtr in
                    bitmapDataPtr.advanced(by: tableIndex).pointee
                }
            }

            guard plane < data._numPlanes, let planePtr = data._planes[plane] else {
                return nil
            }

            let temp = Span(_unsafeStart: planePtr, count: Self.byteCount)
            let span = unsafe _overrideLifetime(temp, copying: ())
            // For .illegal, the bitmap encodes LEGAL scalars, so membership must be inverted
            return (span, shouldInvert: charset == .illegal)
        }
    }
    
    // CFUniCharGetBitmapForPlane
    internal func bitmap(forPlane plane: Int, isInverted: Bool) -> (BitmapResult, Data) {
        
        var bitmap = _CharacterSet.allZeros
        var bitmapMutableSpan = bitmap.mutableSpan
        
        if let (src, invertBitmapData) = _bitmapPtrForPlane(plane) {
            assert(bitmapMutableSpan.count >= Self.byteCount)

            let shouldInvert = invertBitmapData ? !isInverted : isInverted
            
            if shouldInvert {
                for i in 0..<Self.byteCount {
                    bitmapMutableSpan[unchecked: i] = ~src[i]
                }
            } else {
                for i in 0..<Self.byteCount {
                    bitmapMutableSpan[unchecked: i] = src[i]
                }
            }
            return (.bitmapFilled, bitmap)
        } else if charset == .illegal {
            // Special handling for planes 14, 15, and 16 which don't have bitmap data
            if plane == 14 {
                let asciiRange: UInt8 = isInverted ? 0xFF : 0x00
                let otherRange: UInt8 = isInverted ? 0x00 : 0xFF
                
                // Set first byte to 0x02, corresponding to UE001 Language Tag
                bitmapMutableSpan[0] = 0x02
                
                // Set remaining bytes according to whether they are ASCII range
                for i in 1..<Self.byteCount {
                    let isAsciiRange = (i >= (0x20 / 8)) && (i < (0x80 / 8))
                    if isAsciiRange {
                        bitmapMutableSpan[i] = asciiRange
                    } else {
                        bitmapMutableSpan[i] = otherRange
                    }
                }
                return (.bitmapFilled, bitmap)
            } else if plane == 15 || plane == 16 {
                let value: UInt32 = isInverted ? ~0 : 0
                
                for i in stride(from: 0, to: Self.byteCount, by: 4) {
                    bitmapMutableSpan[i] = (UInt8(value & 0xFF))
                    bitmapMutableSpan[i + 1] = (UInt8((value >> 8) & 0xFF))
                    bitmapMutableSpan[i + 2] = (UInt8((value >> 16) & 0xFF))
                    bitmapMutableSpan[i + 3] = (UInt8((value >> 24) & 0xFF))
                }
                
                // Special handling for 0xFFFE & 0xFFFF non-characters
                // Go back 5 bytes from the current position and set the special byte
                let specialIndex = bitmapMutableSpan.count - 5
                if specialIndex >= 0 {
                    bitmapMutableSpan[specialIndex] = isInverted ? 0x3F : 0xC0
                }
                return (.bitmapFilled, bitmap)
            }
            return isInverted ? (.bitmapEmpty, bitmap) : (.bitmapAll, bitmap)

        } else if charset == .control || charset == .whitespace || charset == .whitespaceAndNewline || charset == .newline {
            if plane != 0 {
                return isInverted ? (.bitmapAll, bitmap) : (.bitmapEmpty, bitmap)
            }
            
            let nonFillValue: UInt8 = isInverted ? 0xFF : 0x00
            assert(bitmapMutableSpan.count >= Self.byteCount)
            for i in 0..<Self.byteCount {
                bitmapMutableSpan[unchecked: i] = nonFillValue
            }
            
            if charset == .whitespaceAndNewline || charset == .newline {
                let newlines: [UInt16] = [0x000A, 0x000B, 0x000C, 0x000D, 0x0085, 0x2028, 0x2029]
                
                // Add or remove newline characters
                for newlineChar in newlines {
                    if isInverted {
                        _CharacterSet.modifyBitmap(.remove, char: newlineChar, mutableSpan: &bitmapMutableSpan)
                    } else {
                        _CharacterSet.modifyBitmap(.add, char: newlineChar, mutableSpan: &bitmapMutableSpan)
                    }
                }
                
                if charset == .newline {
                    return (.bitmapFilled, bitmap)
                }
            }
            
            let whitespaces: [UInt16] = [0x0009, 0x0020, 0x00A0, 0x1680, 0x202F, 0x205F, 0x3000]

            for whitespaceChar in whitespaces {
                if isInverted {
                    _CharacterSet.modifyBitmap(.remove, char: whitespaceChar, mutableSpan: &bitmapMutableSpan)
                } else {
                    _CharacterSet.modifyBitmap(.add, char: whitespaceChar, mutableSpan: &bitmapMutableSpan)
                }
            }
            
            let characterRange: ClosedRange<UInt16> = 0x2000...0x200B
            
            for char in characterRange {
                if isInverted {
                    _CharacterSet.modifyBitmap(.remove, char: char, mutableSpan: &bitmapMutableSpan)
                } else {
                    _CharacterSet.modifyBitmap(.add, char: char, mutableSpan: &bitmapMutableSpan)
                }
            }
            
            return (.bitmapFilled, bitmap)
        }
        return isInverted ? (.bitmapAll, bitmap) : (.bitmapEmpty, bitmap)
    }

    // CFUniCharGetNumberOfPlanes
    internal var _numberOfPlanes: Int {
        switch charset {
        case .control, .controlAndFormatter:
            return 15
        case .whitespace, .newline, .whitespaceAndNewline:
            return 1
        case .illegal:
            return 17
        default:
            precondition(_bitmapTableIndex != nil)
            let data = withUnsafePointer(to: __CFUniCharBitmapDataArray) { ptr in
                ptr.withMemoryRebound(to: __CFUniCharBitmapData.self, capacity: Int(__CFUniCharNumberOfBitmaps)) { bitmapDataPtr in
                    bitmapDataPtr.advanced(by: _bitmapTableIndex!).pointee
                }
            }
            
            return Int(data._numPlanes)
        }
    }
    
    // MARK: Helper methods
    private func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        return (scalar.value == 0x0020) || (scalar.value == 0x0009) || (scalar.value == 0x00A0) || (scalar.value == 0x1680) || (scalar.value >= 0x2000 && scalar.value <= 0x200B) || (scalar.value == 0x202F) || (scalar.value == 0x205F) || (scalar.value == 0x3000)
    }
    
    private func isNewline(_ scalar: Unicode.Scalar) -> Bool {
        return ((scalar.value >= 0x000A && scalar.value <= 0x000D) || (scalar.value == 0x0085) || (scalar.value == 0x2028) || (scalar.value == 0x2029))
    }

    static let uppercaseLetters = Self.init(type: .uppercaseLetter)
    static let lowercaseLetters = Self.init(type: .lowercaseLetter)
    static let caseIgnorables = Self.init(type: .caseIgnorable)
    static let hfsPlusDecomposables = Self.init(type: .hfsPlusDecomposable)
    static let graphemeExtends = Self.init(type: .graphemeExtend)
    static let canonicalDecomposables = Self.init(type: .canonicalDecomposable)
}

#if !FOUNDATION_FRAMEWORK
struct _CharacterSet {
    
    static let bitmapSize = 8192
    static let allZeros = Data(repeating: 0x00, count: bitmapSize)
    static let allOnes = Data(repeating: 0xFF, count: bitmapSize)
    
    enum Operation {
        case add
        case remove
    }
    
    internal static func modifyBitmap(_ operation: Operation, char: UInt16, mutableSpan: inout MutableSpan<UInt8>) {
        let LOG_BPB = 3
        let BITSPERBYTE = 8
        let byteIndex = Int(char >> LOG_BPB)
        let bitPosition = char & UInt16(BITSPERBYTE - 1)
        
        guard byteIndex < mutableSpan.count else { return }
        
        let bitMask: UInt8 = 1 << bitPosition
        
        switch operation {
        case .add:
            mutableSpan[byteIndex] |= bitMask
        case .remove:
            mutableSpan[byteIndex] &= ~bitMask
        }
    }
}
#endif
