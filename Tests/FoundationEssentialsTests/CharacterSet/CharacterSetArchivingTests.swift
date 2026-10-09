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

import Testing

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

@Suite("CharacterSet Archiving And Equality Tests", .tags(.characterSet))
private struct CharacterSetArchivingAndEqualityTests {
    
    @Test func archiveBMPRange() {
        let characterSet = CharacterSet(charactersIn: UnicodeScalar(0x61)!...UnicodeScalar(0x7A)!)
        
        let bitmap = characterSet.bitmapRepresentation
        let recoveredCharacterSet = CharacterSet(bitmapRepresentation: bitmap)
        #expect(characterSet == recoveredCharacterSet)
        
        let invertedCharacterSet = characterSet.inverted
        let invertedBitmap = invertedCharacterSet.bitmapRepresentation
        let recoveredInvertedCharacterSet = CharacterSet(bitmapRepresentation: invertedBitmap)
        #expect(invertedCharacterSet == recoveredInvertedCharacterSet)
    }
    
    @Test func archiveNonBMPRange() {
        let characterSet = CharacterSet(charactersIn: UnicodeScalar(0x10000)!..<UnicodeScalar(0x10100)!)
        
        let bitmap = characterSet.bitmapRepresentation
        let recoveredCharacterSet = CharacterSet(bitmapRepresentation: bitmap)
        #expect(characterSet == recoveredCharacterSet)
        
        let invertedCharacterSet = characterSet.inverted
        let invertedBitmap = invertedCharacterSet.bitmapRepresentation
        let recoveredInvertedCharacterSet = CharacterSet(bitmapRepresentation: invertedBitmap)
        #expect(invertedCharacterSet == recoveredInvertedCharacterSet)
    }
    
    @Test func archiveBuiltInSet() throws {
        let letterCharacterSet = CharacterSet.letters
        let bitmapData = letterCharacterSet.bitmapRepresentation
        let characterSet = CharacterSet(bitmapRepresentation: bitmapData)
        try testCharacterSet(characterSet, description: "Bitmap CharacterSet")
    }

    @Test func archiveCompactBitmapBackedSet() {
        var characterSet = CharacterSet()
        characterSet.insert(charactersIn: Unicode.Scalar(0x0000)!...Unicode.Scalar(0x00FF)!)
        characterSet.insert(charactersIn: Unicode.Scalar(0x0200)!...Unicode.Scalar(0x0211)!)
        characterSet.insert(charactersIn: Unicode.Scalar(0x0500)!...Unicode.Scalar(0x0532)!)
        characterSet.insert(charactersIn: Unicode.Scalar(0xFE00)!...Unicode.Scalar(0xFE2F)!)
        characterSet.insert(charactersIn: Unicode.Scalar(0xFF00)!...Unicode.Scalar(0xFFFF)!)

        let bitmap = characterSet.bitmapRepresentation
        let recoveredCharacterSet = CharacterSet(bitmapRepresentation: bitmap)
        #expect(recoveredCharacterSet.bitmapRepresentation == bitmap)
    }

    @Test func multiPlaneBitmapRepresentationLayout() {
        var characterSet = CharacterSet(charactersIn: "A")
        characterSet.insert(charactersIn: Unicode.Scalar(0x1F512)!...Unicode.Scalar(0x1F512)!)
        characterSet.insert(charactersIn: Unicode.Scalar(0x20000)!...Unicode.Scalar(0x20000)!)

        let bitmap = characterSet.bitmapRepresentation
        #expect(bitmap.count == 8192 + 2 * 8193,
                "Expected BMP plane plus annex planes 1 and 2, got \(bitmap.count) bytes")
        #expect(bitmap[bitmap.startIndex + 8192] == 1,
                "First annex slot should be headed by plane index 1")
        #expect(bitmap[bitmap.startIndex + 8192 + 8193] == 2,
                "Second annex slot should be headed by plane index 2")

        let recovered = CharacterSet(bitmapRepresentation: bitmap)
        #expect(recovered.contains(Unicode.Scalar(0x0041)!), "Recovered set should contain 'A'")
        #expect(recovered.contains(Unicode.Scalar(0x1F512)!), "Recovered set should contain 🔒 from plane 1")
        #expect(recovered.contains(Unicode.Scalar(0x20000)!), "Recovered set should contain U+20000 from plane 2")
        #expect(!recovered.contains(Unicode.Scalar(0x30000)!), "Plane 3 was never inserted")
    }

    @Test func invertedAnnexBitmapRepresentationEmitsAllPlanes() {
        var characterSet = CharacterSet(charactersIn: "A🔒")
        characterSet.invert()
        characterSet.remove(charactersIn: "🔓")

        let bitmap = characterSet.bitmapRepresentation
        #expect(bitmap.count == 8192 + 16 * 8193,
                "An inverted annex should emit all 16 annex planes, got \(bitmap.count) bytes")
        for plane in 1...16 {
            let headerOffset = bitmap.startIndex + 8192 + (plane - 1) * 8193
            #expect(bitmap[headerOffset] == UInt8(plane),
                    "Annex slot \(plane - 1) should be headed by plane index \(plane)")
        }

        let recovered = CharacterSet(bitmapRepresentation: bitmap)
        #expect(!recovered.contains(Unicode.Scalar(0x1F512)!), "🔒 was a member before inversion")
        #expect(!recovered.contains(Unicode.Scalar(0x1F513)!), "🔓 was removed after inversion")
        #expect(recovered.contains(Unicode.Scalar(0x1D11E)!), "Plane 1 should retain its other members")
        #expect(recovered.contains(Unicode.Scalar(0x20000)!), "Plane 2 should be wholly included")
        #expect(recovered.contains(Unicode.Scalar(0x100000)!), "Plane 16 should be wholly included")
    }

    @Test func invertedBitmapBackedEmitsAllAnnexPlanes() {
        let sourceBitmap = CharacterSet(charactersIn: Unicode.Scalar(0x0041)!...Unicode.Scalar(0x005A)!).bitmapRepresentation
        #expect(sourceBitmap.count == 8192, "Source should be a BMP-only bitmap")

        var characterSet = CharacterSet(bitmapRepresentation: sourceBitmap)
        characterSet.invert()

        let bitmap = characterSet.bitmapRepresentation
        #expect(bitmap.count == 8192 + 16 * 8193,
                "An inverted annex with no populated planes should emit all 16 annex planes, got \(bitmap.count) bytes")
        #expect(bitmap.prefix(8192) == Data(sourceBitmap.map { ~$0 }),
                "BMP plane should be the bitwise inverse of the source bitmap")

        for plane in 1...16 {
            let headerOffset = bitmap.startIndex + 8192 + (plane - 1) * 8193
            #expect(bitmap[headerOffset] == UInt8(plane),
                    "Annex slot \(plane - 1) should be headed by plane index \(plane)")
            let planeStart = headerOffset + 1
            #expect(bitmap[planeStart..<(planeStart + 8192)].allSatisfy { $0 == 0xFF },
                    "Plane \(plane) should be emitted as wholly included")
        }

        let recovered = CharacterSet(bitmapRepresentation: bitmap)
        #expect(!recovered.contains(Unicode.Scalar(0x0041)!), "'A' was a member before inversion")
        #expect(recovered.contains(Unicode.Scalar(0x0060)!), "'`' was not a member before inversion")
        #expect(recovered.contains(Unicode.Scalar(0x20000)!), "Plane 2 should be wholly included")
        #expect(recovered.contains(Unicode.Scalar(0x100000)!), "Plane 16 should be wholly included")
    }
    
    @Test func stringBackedCharacterSetEquality() {
        let characterSetABC = CharacterSet(charactersIn: "abc")
        let characterSetABCD = CharacterSet(charactersIn: "abcd")
        let characterSetABCDuplicates = CharacterSet(charactersIn: "aabbccdd")
        let characterSetA = CharacterSet(charactersIn: "a")
        let characterSetADuplicatesMany = CharacterSet(charactersIn: "aaaaaaaaaaaaaaaaa")
        let characterSetADuplicatesLess = CharacterSet(charactersIn: "aaaaaaaaaaaaaaaa")
        
        #expect(characterSetABC != characterSetABCD)
        #expect(characterSetABCD == characterSetABCDuplicates)
        #expect(characterSetA == characterSetADuplicatesMany)
        #expect(characterSetADuplicatesLess == characterSetADuplicatesMany)
    }
    
    
    @Test func rangeBackedEqualityAcrossInvertHistories() {
        let range: ClosedRange<Unicode.Scalar> = UnicodeScalar(0x0061)!...UnicodeScalar(0x007A)!
        let a = CharacterSet(charactersIn: range)

        var b = CharacterSet()
        b.invert()
        b.invert()
        b.insert(charactersIn: range)

        #expect(a == b)
        #expect(b == a)
    }

    @Test func rangeBackedInequalityRespectsInversion() {
        let range: ClosedRange<Unicode.Scalar> = UnicodeScalar(0x0061)!...UnicodeScalar(0x007A)!
        let plain = CharacterSet(charactersIn: range)
        let inverted = CharacterSet(charactersIn: range).inverted

        #expect(plain != inverted)
    }

    @Test func rangeBackedInequalityRespectsBounds() {
        let a = CharacterSet(charactersIn: UnicodeScalar(0x0061)!...UnicodeScalar(0x007A)!)
        let b = CharacterSet(charactersIn: UnicodeScalar(0x0061)!...UnicodeScalar(0x007B)!)

        #expect(a != b)
    }

    @Test func rangeBackedNonBMPEqualityAcrossInvertHistories() {
        let range: ClosedRange<Unicode.Scalar> = UnicodeScalar(0xFF00)!...UnicodeScalar(0x10100)!
        let a = CharacterSet(charactersIn: range)

        var b = CharacterSet()
        b.invert()
        b.invert()
        b.insert(charactersIn: range)

        #expect(a == b)
    }

    @Test func builtInBackedEqualityAcrossInvertHistories() {
        let a = CharacterSet.letters

        var b = CharacterSet.letters
        b.invert()
        b.invert()

        #expect(a == b)
        #expect(b == a)
    }

    @Test func builtInBackedInequalityRespectsInversion() {
        let plain = CharacterSet.letters
        let inverted = CharacterSet.letters.inverted

        #expect(plain != inverted)
    }

    @Test func builtInBackedInequalityRespectsType() {
        #expect(CharacterSet.letters != CharacterSet.decimalDigits)
    }

    @Test func reflexiveEquality() {
        let stringBacked = CharacterSet(charactersIn: "abc")
        let rangeBacked = CharacterSet(charactersIn: UnicodeScalar(0x0061)!...UnicodeScalar(0x007A)!)
        let builtInBacked = CharacterSet.letters
        let bitmapBacked = CharacterSet(bitmapRepresentation:
            CharacterSet(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x005A)!).bitmapRepresentation)

        #expect(stringBacked == stringBacked)
        #expect(rangeBacked == rangeBacked)
        #expect(builtInBacked == builtInBacked)
        #expect(bitmapBacked == bitmapBacked)
    }

    @Test func emptyAndUniversalSelfEquality() {
        #expect(CharacterSet() == CharacterSet())
        #expect(CharacterSet().inverted == CharacterSet().inverted)
    }

    @Test func emptyInequalityWithUniversal() {
        #expect(CharacterSet() != CharacterSet().inverted)
    }

    @Test func universalEqualityAcrossConstructions() {
        let universalViaInversion = CharacterSet().inverted
        let universalViaFullRange = CharacterSet(charactersIn:
            UnicodeScalar(0)!...UnicodeScalar(0x10FFFF)!)

        #expect(universalViaInversion == universalViaFullRange)
    }

    @Test func stringBackedEqualityIgnoresOrder() {
        let a = CharacterSet(charactersIn: "abc")
        let b = CharacterSet(charactersIn: "cba")
        let c = CharacterSet(charactersIn: "bac")

        #expect(a == b)
        #expect(b == c)
        #expect(a == c)
    }

    @Test func bitmapBackedEqualityForIdenticalBitmap() {
        let bitmap = CharacterSet(charactersIn:
            UnicodeScalar(0x0041)!...UnicodeScalar(0x005A)!).bitmapRepresentation
        let a = CharacterSet(bitmapRepresentation: bitmap)
        let b = CharacterSet(bitmapRepresentation: bitmap)

        #expect(a == b)
    }

    @Test func bitmapBackedInequalityForOneCharacterDifference() {
        let a = CharacterSet(bitmapRepresentation:
            CharacterSet(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x005A)!).bitmapRepresentation)
        let b = CharacterSet(bitmapRepresentation:
            CharacterSet(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x005B)!).bitmapRepresentation)

        #expect(a != b)
    }

    @Test func rangeVsBitmapEqualityForSameContent() {
        let range: ClosedRange<Unicode.Scalar> =
            UnicodeScalar(0x0061)!...UnicodeScalar(0x007A)!
        let asRange = CharacterSet(charactersIn: range)
        let asBitmap = CharacterSet(bitmapRepresentation: asRange.bitmapRepresentation)

        #expect(asRange == asBitmap)
        #expect(asBitmap == asRange)
    }

    @Test func builtInVsBitmapEqualityForSameContent() {
        let asBuiltIn = CharacterSet.decimalDigits
        let asBitmap = CharacterSet(bitmapRepresentation: asBuiltIn.bitmapRepresentation)

        #expect(asBuiltIn == asBitmap)
        #expect(asBitmap == asBuiltIn)
    }

    @Test func stringVsBitmapEqualityForSameContent() {
        let asString = CharacterSet(charactersIn: "abc")
        let asBitmap = CharacterSet(bitmapRepresentation: asString.bitmapRepresentation)

        #expect(asString == asBitmap)
        #expect(asBitmap == asString)
    }

    @Test func nonBMPRangeVsBitmapEqualityForSameContent() {
        let range: ClosedRange<Unicode.Scalar> =
            UnicodeScalar(0xFF00)!...UnicodeScalar(0x10100)!
        let asRange = CharacterSet(charactersIn: range)
        let asBitmap = CharacterSet(bitmapRepresentation: asRange.bitmapRepresentation)

        #expect(asRange == asBitmap)
    }

    @Test func invertedRangeEqualsBitmapOfComplement() {
        let range: ClosedRange<Unicode.Scalar> =
            UnicodeScalar(0x0061)!...UnicodeScalar(0x007A)!
        let invertedRange = CharacterSet(charactersIn: range).inverted
        let asBitmap = CharacterSet(bitmapRepresentation: invertedRange.bitmapRepresentation)

        #expect(invertedRange == asBitmap)
    }

    @Test func nonBMPAnnexEqualityForSameContent() {
        var a = CharacterSet(charactersIn: "ab")
        a.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x10010)!)

        var b = CharacterSet(charactersIn: "ab")
        b.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x10010)!)

        #expect(a == b)
    }

    @Test func nonBMPAnnexInequalityForDifferentPlaneContent() {
        var a = CharacterSet(charactersIn: "ab")
        a.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x10010)!)

        var b = CharacterSet(charactersIn: "ab")
        b.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x10020)!)

        #expect(a != b)
        #expect(b != a)
    }

    @Test func nonBMPAnnexInequalityForDifferentPlanes() {
        var a = CharacterSet(charactersIn: "ab")
        a.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x10010)!)

        var b = CharacterSet(charactersIn: "ab")
        b.insert(charactersIn: UnicodeScalar(0x20000)!...UnicodeScalar(0x20010)!)

        #expect(a != b)
        #expect(b != a)
    }

    @Test func equalitySymmetryAcrossStorageCombinations() {
        let aRange = CharacterSet(charactersIn: UnicodeScalar(0x41)!...UnicodeScalar(0x5A)!)
        let aString = CharacterSet(charactersIn: "abc")
        let aBuiltIn = CharacterSet.decimalDigits
        let aEmpty = CharacterSet()
        let aBitmapOfRange = CharacterSet(bitmapRepresentation: aRange.bitmapRepresentation)
        let aBitmapOfString = CharacterSet(bitmapRepresentation: aString.bitmapRepresentation)
        let aBitmapOfBuiltIn = CharacterSet(bitmapRepresentation: aBuiltIn.bitmapRepresentation)
        let aBitmapOfEmpty = CharacterSet(bitmapRepresentation: aEmpty.bitmapRepresentation)

        let pairs: [(CharacterSet, CharacterSet)] = [
            (aRange, aBitmapOfRange),
            (aString, aBitmapOfString),
            (aBuiltIn, aBitmapOfBuiltIn),
            (aEmpty, aBitmapOfEmpty),
        ]

        for (lhs, rhs) in pairs {
            #expect(lhs == rhs)
            #expect(rhs == lhs)
        }
    }

    @Test func equalityHashContractAcrossStorageCombinations() {
        let range = UnicodeScalar(0x41)!...UnicodeScalar(0x5A)!

        let groups: [[CharacterSet]] = [
            [
                CharacterSet().inverted,
                CharacterSet(charactersIn: UnicodeScalar(0)!...UnicodeScalar(0x10FFFF)!),
                {
                    var x = CharacterSet()
                    x.invert()
                    return x
                }(),
            ],
            [
                CharacterSet(charactersIn: range),
                CharacterSet(bitmapRepresentation:
                    CharacterSet(charactersIn: range).bitmapRepresentation),
                {
                    var x = CharacterSet()
                    x.insert(charactersIn: range)
                    return x
                }(),
                {
                    var x = CharacterSet()
                    x.invert()
                    x.invert()
                    x.insert(charactersIn: range)
                    return x
                }(),
            ],
        ]

        for group in groups {
            for i in 0..<group.count {
                for j in 0..<group.count {
                    #expect(group[i] == group[j])
                }
            }
        }
    }


    @Test func rangeCoveringExactlyPlaneZero() {
        let range = CharacterSet(charactersIn: UnicodeScalar(0)!...UnicodeScalar(0xFFFF)!)
        let bitmap = CharacterSet(bitmapRepresentation: range.bitmapRepresentation)

        #expect(range == bitmap)
    }

    @Test func rangeCoveringExactlyPlaneOne() {
        let range = CharacterSet(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x1FFFF)!)
        let bitmap = CharacterSet(bitmapRepresentation: range.bitmapRepresentation)

        #expect(range == bitmap)
    }

    @Test func rangeStraddlingPlaneZeroOneBoundary() {
        let range = CharacterSet(charactersIn: UnicodeScalar(0xFFFF)!...UnicodeScalar(0x10000)!)
        let bitmap = CharacterSet(bitmapRepresentation: range.bitmapRepresentation)

        #expect(range == bitmap)
    }

    @Test func rangeCoveringMultiplePlanes() {
        let range = CharacterSet(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x3FFFF)!)
        let bitmap = CharacterSet(bitmapRepresentation: range.bitmapRepresentation)

        #expect(range == bitmap)
    }

    @Test func singleCharacterRangeAtPlaneOneStart() {
        let range = CharacterSet(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x10000)!)
        let bitmap = CharacterSet(bitmapRepresentation: range.bitmapRepresentation)

        #expect(range == bitmap)
    }

    @Test func singleCharacterRangeAtPlaneOneEnd() {
        let range = CharacterSet(charactersIn: UnicodeScalar(0x1FFFF)!...UnicodeScalar(0x1FFFF)!)
        let bitmap = CharacterSet(bitmapRepresentation: range.bitmapRepresentation)

        #expect(range == bitmap)
    }

    @Test func rangeStartingAtZero() {
        let range = CharacterSet(charactersIn: UnicodeScalar(0)!...UnicodeScalar(0xFF)!)
        let bitmap = CharacterSet(bitmapRepresentation: range.bitmapRepresentation)

        #expect(range == bitmap)
    }

    @Test func rangeEndingAtBMPBoundary() {
        let range = CharacterSet(charactersIn: UnicodeScalar(0xFFF0)!...UnicodeScalar(0xFFFF)!)
        let bitmap = CharacterSet(bitmapRepresentation: range.bitmapRepresentation)

        #expect(range == bitmap)
    }

    @Test func rangeEntirelyInHighPlane() {
        let range = CharacterSet(charactersIn: UnicodeScalar(0xE0000)!...UnicodeScalar(0xE0050)!)
        let bitmap = CharacterSet(bitmapRepresentation: range.bitmapRepresentation)

        #expect(range == bitmap)
    }

    @Test func singleCharacterRangeAtCodepointZero() {
        let range = CharacterSet(charactersIn: UnicodeScalar(0)!...UnicodeScalar(0)!)
        let bitmap = CharacterSet(bitmapRepresentation: range.bitmapRepresentation)

        #expect(range == bitmap)
    }

    @Test func singleCharacterRangeAtMaxCodepoint() {
        let range = CharacterSet(charactersIn: UnicodeScalar(0x10FFFF)!...UnicodeScalar(0x10FFFF)!)
        let bitmap = CharacterSet(bitmapRepresentation: range.bitmapRepresentation)

        #expect(range == bitmap)
    }


    @Test func builtinNotEqualToSubsetRange() {
        let azRange = CharacterSet(charactersIn: UnicodeScalar(0x61)!...UnicodeScalar(0x7A)!)

        #expect(CharacterSet.letters != azRange)
        #expect(azRange != CharacterSet.letters)
    }

    @Test func builtinNotEqualToFullUnicodeRange() {
        let everything = CharacterSet(charactersIn:
            UnicodeScalar(0)!...UnicodeScalar(0x10FFFF)!)

        #expect(CharacterSet.letters != everything)
        #expect(everything != CharacterSet.letters)
    }

    @Test func builtinNotEqualToHighPlaneRange() {
        let plane15Range = CharacterSet(charactersIn:
            UnicodeScalar(0xF0000)!...UnicodeScalar(0xF0010)!)

        #expect(CharacterSet.letters != plane15Range)
        #expect(plane15Range != CharacterSet.letters)
    }

    @Test func decimalDigitsNotEqualToASCIIDigitRange() {
        let asciiDigits = CharacterSet(charactersIn:
            UnicodeScalar(0x30)!...UnicodeScalar(0x39)!)

        #expect(CharacterSet.decimalDigits != asciiDigits)
        #expect(asciiDigits != CharacterSet.decimalDigits)
    }


    @Test func emptyNotEqualToBuiltin() {
        let empty = CharacterSet()

        #expect(empty != CharacterSet.letters)
        #expect(CharacterSet.letters != empty)
        #expect(empty != CharacterSet.decimalDigits)
        #expect(CharacterSet.decimalDigits != empty)
        #expect(empty != CharacterSet.whitespaces)
        #expect(CharacterSet.whitespaces != empty)
    }

    @Test func emptyEqualsZeroLengthRange() {
        let empty = CharacterSet()
        let zeroLength = CharacterSet(charactersIn:
            UnicodeScalar(0x41)!..<UnicodeScalar(0x41)!)

        #expect(empty == zeroLength)
    }

    @Test func emptyNotEqualToSingleCharacterRange() {
        let empty = CharacterSet()
        let single = CharacterSet(charactersIn:
            UnicodeScalar(0x41)!...UnicodeScalar(0x41)!)

        #expect(empty != single)
        #expect(single != empty)
    }

    @Test func emptyEqualsBitmapOfEmpty() {
        let empty = CharacterSet()
        let bitmap = CharacterSet(bitmapRepresentation: empty.bitmapRepresentation)

        #expect(empty == bitmap)
        #expect(bitmap == empty)
    }

    @Test func emptyNotEqualToBitmapWithContent() {
        let empty = CharacterSet()
        let nonEmpty = CharacterSet(bitmapRepresentation:
            CharacterSet(charactersIn: "abc").bitmapRepresentation)

        #expect(empty != nonEmpty)
        #expect(nonEmpty != empty)
    }

    @Test func stringEqualsRangeForSameContent() {
        let stringBacked = CharacterSet(charactersIn: "abc")
        let rangeBacked = CharacterSet(charactersIn: UnicodeScalar(0x0061)!...UnicodeScalar(0x0063)!)

        #expect(stringBacked == rangeBacked)
        #expect(rangeBacked == stringBacked)
    }

    @Test func stringNotEqualToRange() {
        let stringBacked = CharacterSet(charactersIn: "abc")
        let rangeBacked = CharacterSet(charactersIn: UnicodeScalar(0x0061)!...UnicodeScalar(0x007A)!)

        #expect(stringBacked != rangeBacked)
        #expect(rangeBacked != stringBacked)
    }

    @Test func stringNotEqualToBuiltin() {
        let stringBacked = CharacterSet(charactersIn: "abc")

        #expect(stringBacked != CharacterSet.letters)
        #expect(CharacterSet.letters != stringBacked)
    }

    @Test func stringNotEqualToBitmapOfDifferentContent() {
        let stringBacked = CharacterSet(charactersIn: "abc")
        let bitmapOfDifferent = CharacterSet(bitmapRepresentation:
            CharacterSet(charactersIn: "xyz").bitmapRepresentation)

        #expect(stringBacked != bitmapOfDifferent)
        #expect(bitmapOfDifferent != stringBacked)
    }

    @Test func builtinNotEqualToBitmapOfDifferentContent() {
        let bitmapOfABC = CharacterSet(bitmapRepresentation:
            CharacterSet(charactersIn: "abc").bitmapRepresentation)

        #expect(CharacterSet.letters != bitmapOfABC)
        #expect(bitmapOfABC != CharacterSet.letters)
    }

    @Test func emptyNotEqualToString() {
        let empty = CharacterSet()
        let stringBacked = CharacterSet(charactersIn: "a")

        #expect(empty != stringBacked)
        #expect(stringBacked != empty)
    }

    @Test func universalNotEqualToBuiltin() {
        let universal = CharacterSet().inverted

        #expect(universal != CharacterSet.letters)
        #expect(CharacterSet.letters != universal)
    }

    @Test func invertedBuiltinNotEqualToRange() {
        let invertedLetters = CharacterSet.letters.inverted
        let azRange = CharacterSet(charactersIn: UnicodeScalar(0x61)!...UnicodeScalar(0x7A)!)

        #expect(invertedLetters != azRange)
        #expect(azRange != invertedLetters)
    }

    @Test func invertedRangeNotEqualToBuiltin() {
        let invertedRange = CharacterSet(charactersIn:
            UnicodeScalar(0x61)!...UnicodeScalar(0x7A)!).inverted

        #expect(invertedRange != CharacterSet.letters)
        #expect(CharacterSet.letters != invertedRange)
    }

    @Test func invertedBuiltinNotEqualToString() {
        let invertedLetters = CharacterSet.letters.inverted
        let stringBacked = CharacterSet(charactersIn: "abc")

        #expect(invertedLetters != stringBacked)
        #expect(stringBacked != invertedLetters)
    }

    @Test func invertedRangeNotEqualToString() {
        let invertedRange = CharacterSet(charactersIn:
            UnicodeScalar(0x61)!...UnicodeScalar(0x7A)!).inverted
        let stringBacked = CharacterSet(charactersIn: "abc")

        #expect(invertedRange != stringBacked)
        #expect(stringBacked != invertedRange)
    }


    @Test func multiPlaneAnnexEqualityWithMatchingContent() {
        var a = CharacterSet(charactersIn: "x")
        a.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x10005)!)
        a.insert(charactersIn: UnicodeScalar(0x20000)!...UnicodeScalar(0x20005)!)

        var b = CharacterSet(charactersIn: "x")
        b.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x10005)!)
        b.insert(charactersIn: UnicodeScalar(0x20000)!...UnicodeScalar(0x20005)!)

        #expect(a == b)
    }

    @Test func multiPlaneAnnexInequalityWithMismatchInLowerPlane() {
        var a = CharacterSet(charactersIn: "x")
        a.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x10005)!)
        a.insert(charactersIn: UnicodeScalar(0x20000)!...UnicodeScalar(0x20005)!)

        var b = CharacterSet(charactersIn: "x")
        b.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x10010)!)
        b.insert(charactersIn: UnicodeScalar(0x20000)!...UnicodeScalar(0x20005)!)

        #expect(a != b)
    }

    @Test func multiPlaneAnnexInequalityWithMismatchInHigherPlane() {
        var a = CharacterSet(charactersIn: "x")
        a.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x10005)!)
        a.insert(charactersIn: UnicodeScalar(0x20000)!...UnicodeScalar(0x20005)!)

        var b = CharacterSet(charactersIn: "x")
        b.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x10005)!)
        b.insert(charactersIn: UnicodeScalar(0x20000)!...UnicodeScalar(0x20010)!)

        #expect(a != b)
    }


    @Test func invertedBuiltinEqualsBitmapOfInversion() {
        let invertedLetters = CharacterSet.letters.inverted
        let bitmap = CharacterSet(bitmapRepresentation:
            invertedLetters.bitmapRepresentation)

        #expect(invertedLetters == bitmap)
        #expect(bitmap == invertedLetters)
    }

    @Test func doubleInvertedBuiltinEqualsOriginal() {
        let original = CharacterSet.letters
        let doubleInverted = original.inverted.inverted

        #expect(original == doubleInverted)
    }
    
    @Test func invertedNonBMPRangeEqualsBitmap() {
        let invertedRange = CharacterSet(charactersIn:
            UnicodeScalar(0x10000)!...UnicodeScalar(0x10100)!).inverted
        let bitmap = CharacterSet(bitmapRepresentation:
            invertedRange.bitmapRepresentation)

        #expect(invertedRange == bitmap)
    }


    @Test func rangeNotEqualToBitmapWithSingleBitDifference() {
        let range = CharacterSet(charactersIn: UnicodeScalar(0x41)!...UnicodeScalar(0x5A)!)

        var missingBit = range
        missingBit.remove(UnicodeScalar(0x4D)!)

        var extraBit = range
        extraBit.insert(UnicodeScalar(0x61)!)

        #expect(range != missingBit)
        #expect(missingBit != range)
        #expect(range != extraBit)
        #expect(extraBit != range)
    }

    // Validation test for bug fix in _CharacterSet+StorageRange.swift file
    @Test func invertedRangeCrossingPlanesEqualsItsBitmap() {
        let invertedRange = CharacterSet(charactersIn:
            UnicodeScalar(0xFF00)!...UnicodeScalar(0x100FF)!).inverted
        let bitmap = CharacterSet(bitmapRepresentation:
            invertedRange.bitmapRepresentation)

        #expect(invertedRange == bitmap)
    }

    private func testOneCharacterSet(_ characterSet: CharacterSet, description: String) throws {
        // Test 1: PropertyListEncoder/Decoder (modern replacement for NSKeyedArchiver)
        do {
            let encoder = PropertyListEncoder()
            let data = try encoder.encode(characterSet)
            
            let decoder = PropertyListDecoder()
            let revived = try decoder.decode(CharacterSet.self, from: data)
            
            #expect(characterSet == revived,
                   "PropertyListEncoder failed for \(description): \(characterSet)")
        } catch {
            Issue.record("PropertyListEncoder/Decoder failed for \(description) with error: \(error)")
        }
        
        // Test 2: JSONEncoder/Decoder
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(characterSet)
            
            let decoder = JSONDecoder()
            let revived = try decoder.decode(CharacterSet.self, from: data)
            
            #expect(characterSet == revived,
                   "JSONEncoder failed for \(description): \(characterSet)")
        } catch {
            Issue.record("JSONEncoder/Decoder failed for \(description) with error: \(error)")
        }
        
        #if FOUNDATION_FRAMEWORK
        // Test 3: NSKeyedArchiver (for Objective-C bridging compatibility)
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: characterSet as NSCharacterSet,
                requiringSecureCoding: true
            )
            let revived = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSCharacterSet.self,
                from: data
            ) as? CharacterSet
            
            #expect(characterSet == revived,
                   "NSKeyedArchiver failed for \(description): \(characterSet)")
        } catch {
            Issue.record("NSKeyedArchiver/Unarchiver failed for \(description) with error: \(error)")
        }
        
        // Test 4: CFCharacterSetCreateCopy
        let cfSet = characterSet as CFCharacterSet
        if let copy = CFCharacterSetCreateCopy(nil, cfSet) {
            let nsCopy = copy as CharacterSet
            #expect(characterSet == nsCopy,
                   "CFCharacterSetCreateCopy failed for \(description)")
        } else {
            Issue.record("CFCharacterSetCreateCopy returned nil for \(description)")
        }
        
        // Test 5: CFCharacterSetCreateMutableCopy
        if let mutableCopy = CFCharacterSetCreateMutableCopy(nil, cfSet) {
            let nsMutableCopy = mutableCopy as CharacterSet
            #expect(characterSet == nsMutableCopy,
                   "CFCharacterSetCreateMutableCopy failed for \(description)")
        } else {
            Issue.record("CFCharacterSetCreateMutableCopy returned nil for \(description)")
        }
        #endif
    }
    
    private func testCharacterSet(_ characterSet: CharacterSet, description: String) throws {
        // Create a mutable copy
        var mCopy = characterSet
        
        // Test 1: Original character set
        try testOneCharacterSet(characterSet, description: "\(description) [original]")
        
        // Test 2: Inverted character set
        try testOneCharacterSet(
            characterSet.inverted,
            description: "\(description) [inverted]"
        )
        
        // Test 3: Mutable copy
        try testOneCharacterSet(mCopy, description: "\(description) [mutable copy]")
        
        // Test 4: Inverted mutable copy
        mCopy.invert()
        try testOneCharacterSet(mCopy, description: "\(description) [inverted mutable copy]")
    }
}
