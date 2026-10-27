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

// MARK: Bitmap Manipulation Helpers

extension _CharacterSet {

    internal static func bytes(of span: Span<UInt8>, equalTo value: UInt8) -> Bool {
        let bytes = span.bytes
        let wordStride = MemoryLayout<UInt64>.stride
        // this helps to repeat `value` in all eight bytes
        let pattern = UInt64(0x0101_0101_0101_0101) &* UInt64(value)
        var offset = 0
        while offset + wordStride <= span.count {
            if bytes.load(fromByteOffset: offset, as: UInt64.self).littleEndian != pattern {
                return false
            }
            offset += wordStride
        }
        while offset < span.count {
            if span[offset] != value {
                return false
            }
            offset += 1
        }
        return true
    }

    // __CFCSetBitmapAddCharacter, __CFCSetBitmapRemoveCharacter
    internal static func modifyBitmap(_ operation: Operation, char: UInt16, mutableSpan: inout MutableSpan<UInt8>) {
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

    internal static func removeCharacters(from mutableSpan: inout MutableSpan<UInt8>, firstChar: UInt32, lastChar: UInt32) {
        modifyCharacters(.remove, in: &mutableSpan, firstChar: firstChar, lastChar: lastChar)
    }

    internal static func addCharacters(to mutableSpan: inout MutableSpan<UInt8>, firstChar: UInt32, lastChar: UInt32) {
        modifyCharacters(.add, in: &mutableSpan, firstChar: firstChar, lastChar: lastChar)
    }
    
    internal static func modifyCharacters(_ operation: Operation, in mutableSpan: inout MutableSpan<UInt8>, firstChar: UInt32, lastChar: UInt32) {
        // Ensure we're working within BMP bounds
        let firstChar = min(firstChar, 0xFFFF)
        let lastChar = min(lastChar, 0xFFFF)

        if firstChar > lastChar {
            return
        }

        // Single character case - optimized path
        if firstChar == lastChar {
            let byteIndex = Int(firstChar >> Self.LOG_BPB)
            let bitPosition = firstChar & UInt32(Self.BITSPERBYTE - 1)

            let bitMask = UInt8(1) << bitPosition
            switch operation {
            case .add:
                mutableSpan[byteIndex] |= bitMask
            case .remove:
                mutableSpan[byteIndex] &= ~bitMask
            }
            return
        }

        // Multi-character range case - use CFCharacterSet optimization
        let idx = Int(firstChar >> Self.LOG_BPB)
        let max = Int(lastChar >> Self.LOG_BPB)

        if idx == max {
            // Characters are within the same byte - create partial byte mask
            let firstBitPos = firstChar & UInt32(Self.BITSPERBYTE - 1)
            let lastBitPos = lastChar & UInt32(Self.BITSPERBYTE - 1)

            let mask = (UInt8(0xFF) << firstBitPos) & (UInt8(0xFF) >> (Self.BITSPERBYTE - 1 - Int(lastBitPos)))
            switch operation {
            case .add:
                mutableSpan[idx] |= mask
            case .remove:
                mutableSpan[idx] &= ~mask
            }
        } else {
            // Characters span multiple bytes
            let firstBitPos = firstChar & UInt32(Self.BITSPERBYTE - 1)
            let firstMask = UInt8(0xFF) << firstBitPos

            let lastBitPos = lastChar & UInt32(Self.BITSPERBYTE - 1)
            let lastMask = UInt8(0xFF) >> (Self.BITSPERBYTE - 1 - Int(lastBitPos))

            let fill: UInt8
            switch operation {
            case .add:
                mutableSpan[idx] |= firstMask
                mutableSpan[max] |= lastMask
                fill = 0xFF
            case .remove:
                mutableSpan[idx] &= ~firstMask
                mutableSpan[max] &= ~lastMask
                fill = 0x00
            }

            for i in (idx + 1)..<max {
                mutableSpan[i] = fill
            }
        }
    }

    internal static func _asciiMask(fromBitmap bitmap: Span<UInt8>) -> UInt128 {
        return bitmap.bytes.load(fromByteOffset: 0, as: UInt128.self).littleEndian
    }
}
