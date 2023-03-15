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

#if FOUNDATION_FRAMEWORK
@_spi(_Unicode) import Swift
@_implementationOnly import CoreFoundation_Private.CFString
#endif // FOUNDATION_FRAMEWORK

extension UnicodeScalar {
    func _toHalfWidth() -> Self {
#if FOUNDATION_FRAMEWORK // TODO: Implement `CFUniCharCompatibilityDecompose` in Swift
        if value >= 0xFF00 && value < 0xFFEF {
            var halfWidth = value
            CFUniCharCompatibilityDecompose(&halfWidth, 1, 1)
            return UnicodeScalar(halfWidth)!
        } else {
            return self
        }
#else
        return self
#endif
    }

    var _isGraphemeExtend: Bool {
#if FOUNDATION_FRAMEWORK // TODO: Implement `CFUniCharGetBitmapPtrForPlane` in Swift
        let truncated = UInt16(truncatingIfNeeded: value) // intentionally truncated
        let bitmap = CFUniCharGetBitmapPtrForPlane(UInt32(kCFUniCharGraphemeExtendCharacterSet), (value < 0x10000) ? 0 : (value >> 16))
        return CFUniCharIsMemberOfBitmap(truncated, bitmap)
#else
        return false
#endif
    }

    var _isCanonicalDecomposable: Bool {
#if FOUNDATION_FRAMEWORK // TODO: Implement `CFUniCharGetBitmapPtrForPlane` in Swift
        let truncated = UInt16(truncatingIfNeeded: value)
        let bitmap = CFUniCharGetBitmapPtrForPlane(UInt32(kCFUniCharCanonicalDecomposableCharacterSet), value >> 16)
        return CFUniCharIsMemberOfBitmap(truncated, bitmap)
#else
        return false
#endif
    }

    func _stripDiacritics() -> Self {
        guard _isCanonicalDecomposable else {
            return self
        }

#if FOUNDATION_FRAMEWORK // TODO: Implement `CFUniCharDecomposeCharacter` in Swift
        var stripped: UInt32? = nil
        withUnsafeTemporaryAllocation(of: UTF32Char.self, capacity: 64) { ptr in
            guard let base = ptr.baseAddress else {
                return
            }
            let len = CFUniCharDecomposeCharacter(value, base, ptr.count)
            if len > 0 {
                if ptr[0] < 0x0510 {
                    stripped = ptr[0]
                }
            }
        }

        return stripped != nil ? UnicodeScalar(stripped!)! : self
#else
        return self
#endif // FOUNDATION_FRAMEWORK
    }

    var _caseFoldMapping : String {
#if FOUNDATION_FRAMEWORK // TODO: Expose Case Mapping Data without @_spi(_Unicode)
        return self.properties._caseFolded
#else
        return ""
#endif
    }
}
