//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
@_implementationOnly import RustShims
#else
package import RustShims
#endif

// Native implementation of CFCharacterSet.
// Represents sets of unicode scalars of those whose bitmap data we own.
// whitespace, whitespaceAndNewline, and newline are not included since they're not stored with bitmaps
// This only contains a subset of predefined CFCharacterSet that are in use for now.
internal struct BuiltInUnicodeScalarSet {
    enum SetType {
        case lowercaseLetter
        case uppercaseLetter
        case canonicalDecomposable

        // Below are internal
        case caseIgnorable
        case graphemeExtend
    }

    var charset: SetType
    init(type: SetType) {
        charset = type
    }

    // Equivalent to  __CFUniCharMapExternalSetToInternalIndex(__CFUniCharMapCompatibilitySetID())
    private var _bitmapTableIndex: Int {
        switch charset {
        case .lowercaseLetter:
            return 2
        case .uppercaseLetter:
            return 3
        case .canonicalDecomposable:
            return 5
        case .caseIgnorable:
            return 20
        case .graphemeExtend:
            return 21
        }
    }

    // CFUniCharIsMemberOf
    func contains(_ scalar: Unicode.Scalar) -> Bool {
        let planeNo = Int((scalar.value >> 16) & 0xFF)
        let bitmp = _bitmapPtrForPlane(planeNo)
        return _isMemberOfBitmap(scalar, bitmp)
    }

    // CFUniCharGetBitmapPtrForPlane
    func _bitmapPtrForPlane(_ plane: Int) -> UnsafePointer<UInt8>? {
        let tableIndex = _bitmapTableIndex
        guard tableIndex < __CFUniCharNumberOfBitmaps else {
            return nil
        }

        let data = withUnsafePointer(to: __CFUniCharBitmapDataArray) { ptr in
            ptr.withMemoryRebound(to: __CFUniCharBitmapData.self, capacity: Int(__CFUniCharNumberOfBitmaps)) { bitmapDataPtr in
                bitmapDataPtr.advanced(by: tableIndex).pointee
            }
        }
        return plane < data._numPlanes ? data._planes[plane] : nil
    }

    let bitShiftForByte = UInt16(3)
    let bitShiftForMask = UInt16(7)

    // CFUniCharIsMemberOfBitmap
    func _isMemberOfBitmap(_ scalar: Unicode.Scalar, _ bitmap: UnsafePointer<UInt8>?) -> Bool {
        guard let bitmap else { return false }
        let theChar = UInt16(truncatingIfNeeded: scalar.value) // intentionally truncated

        let position = bitmap[Int(theChar >> bitShiftForByte)]
        let mask = theChar & bitShiftForMask
        let new = (Int(position) & Int(UInt32(1) << mask)) != 0
        return new
    }

    static let uppercaseLetters = Self.init(type: .uppercaseLetter)
    static let lowercaseLetters = Self.init(type: .lowercaseLetter)
    static let caseIgnorables = Self.init(type: .caseIgnorable)
    static let graphemeExtends = Self.init(type: .graphemeExtend)
    static let canonicalDecomposables = Self.init(type: .canonicalDecomposable)
}

