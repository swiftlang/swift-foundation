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

@Suite("Character Set: String-Based Manipulation Tests", .tags(.characterSet))
private struct CharacterSetStringBasedManipulationTests {
    
    @Test func insertEmptyString() {
        var characterSet = CharacterSet(charactersIn: "ABC")
        characterSet.insert(charactersIn: "")
        
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0044)!))
    }
    
    @Test func insertStringWithEmoji() {
        var characterSet = CharacterSet()
        let mixedString = "A🎵"
        
        characterSet.insert(charactersIn: mixedString)
        
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(!characterSet.contains(Unicode.Scalar(0x1F600)!))
        #expect(characterSet.contains(Unicode.Scalar("🎵")))
    }
    
    @Test func insertStringWithoutDuplicates() {
        var characterSet = CharacterSet(charactersIn: "AB")
        characterSet.insert(charactersIn: "CD")
        
        #expect(!characterSet.contains(UnicodeScalar(0x0040)!))
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(characterSet.contains(UnicodeScalar(0x0043)!))
        #expect(characterSet.contains(UnicodeScalar(0x0044)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0045)!))
    }
    
    @Test func insertStringWithDuplicates() {
        var characterSet = CharacterSet()
        characterSet.insert(charactersIn: "AAABBBCCC")
        
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(characterSet.contains(UnicodeScalar(0x0043)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0044)!))
    }
    
    @Test func removeStringFromInvertedSet() {
        var characterSet = CharacterSet(charactersIn: "ABCD")
        characterSet.invert()
        characterSet.remove(charactersIn: "EF")
        
        #expect(characterSet.contains(UnicodeScalar(0x0040)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0043)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0044)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0045)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0046)!))
        #expect(characterSet.contains(UnicodeScalar(0x0047)!))
    }
    
    @Test func insertCombinationStringThenRemoveOnlyEmoji() {
        var characterSet = CharacterSet()
        characterSet.insert(charactersIn: "A🎵B")
        characterSet.remove(charactersIn: "🎵")
        
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(!characterSet.contains(UnicodeScalar("🎵")))
    }
    
    @Test func removeAllInitializedCharacters() {
        var characterSet = CharacterSet(charactersIn: "ABC")
        characterSet.remove(charactersIn: "ABC")
        
        #expect(!characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0043)!))
        
        validateEmptySet(characterSet)
    }
    
    @Test func insertStringWithUnicodeScalarLiteral() {
        var characterSet = CharacterSet()
        characterSet.insert(charactersIn: "ABC\u{FEFF}")
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(characterSet.contains(UnicodeScalar(0x0043)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0044)!))
        #expect(characterSet.contains(UnicodeScalar(0xFEFF)!))
    }
    
    @Test func insertStringWithAllUppercaseLetters() {
        var characterSet = CharacterSet()
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        characterSet.insert(charactersIn: chars)
        
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(characterSet.contains(UnicodeScalar(0x005A)!))
    }
    
    @Test func insertLargeString() {
        var characterSet = CharacterSet()
        // Create a string with 101 characters (0x0041 = 'A' through 0x00A5)
        let scalars = (0x0041...0x0041+100).compactMap { UnicodeScalar($0) }
        let longString = String(String.UnicodeScalarView(scalars))

        characterSet.insert(charactersIn: longString)

        #expect(!characterSet.contains(UnicodeScalar(0x0040)!))
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(characterSet.contains(UnicodeScalar(0x0050)!))
        #expect(characterSet.contains(UnicodeScalar(0x00A5)!))
        #expect(!characterSet.contains(UnicodeScalar(0x00A6)!))
    }
    
    @Test func insertNonBMPIntoStringBackedSetPopulatesAnnex() {
        var cs = CharacterSet(charactersIn: "A")

        cs.insert(charactersIn: "🔒")

        #expect(cs.contains(Unicode.Scalar(0x1F512)!), "Set should contain 🔒 after insert")
        #expect(cs.hasMember(inPlane: 1), "Set should report having members in plane 1 after inserting 🔒")

        let roundTripped = CharacterSet(bitmapRepresentation: cs.bitmapRepresentation)
        #expect(roundTripped.contains(UnicodeScalar(0x0041)!), "Round-tripped set should contain 'A'")
        #expect(roundTripped.contains(Unicode.Scalar(0x1F512)!), "Round-tripped set should contain 🔒 — annex must be populated")
    }

    @Test func insertMultipleNonBMPIntoStringBackedSet() {
        var cs = CharacterSet(charactersIn: "AB")

        cs.insert(charactersIn: "🔒𝄞")

        #expect(cs.contains(UnicodeScalar(0x0041)!), "Set should contain 'A'")
        #expect(cs.contains(UnicodeScalar(0x0042)!), "Set should contain 'B'")
        #expect(cs.contains(Unicode.Scalar(0x1F512)!), "Set should contain 🔒")
        #expect(cs.contains(Unicode.Scalar(0x1D11E)!), "Set should contain 𝄞")
        #expect(cs.hasMember(inPlane: 0), "Set should have members in plane 0")
        #expect(cs.hasMember(inPlane: 1), "Set should have members in plane 1")

        let roundTripped = CharacterSet(bitmapRepresentation: cs.bitmapRepresentation)
        #expect(roundTripped.contains(Unicode.Scalar(0x1F512)!), "Round-tripped set should preserve 🔒")
        #expect(roundTripped.contains(Unicode.Scalar(0x1D11E)!), "Round-tripped set should preserve 𝄞")
    }

    @Test func validatePlaneMembership() {
        // 🔒 is U+1F512 (plane 1), 𝄞 is U+1D11E (plane 1)
        let characterSet = CharacterSet(charactersIn: "A🔒𝄞")

        #expect(characterSet.hasMember(inPlane: 0), "String-backed set with 'A' should have member in plane 0")
        #expect(characterSet.hasMember(inPlane: 1), "String-backed set with emoji should have member in plane 1")
        #expect(!characterSet.hasMember(inPlane: 2), "String-backed set should not have member in plane 2")
    }
    
    @Test func validateOnlyNonBMPCharactersPlaneMembership() {
        let cs = CharacterSet(charactersIn: "🔒𝄞")
        #expect(!cs.isEmpty, "Set with only non-BMP characters should not be empty")
        #expect(!cs.hasMember(inPlane: 0), "Set with only non-BMP characters should have no BMP members")
        #expect(cs.hasMember(inPlane: 1))
    }
    
    @Test func validateOnlyNonBMPCharacterMembership() {
        let cs = CharacterSet(charactersIn: "🔒")
        #expect(cs.contains(Unicode.Scalar(0x1F512)!), "String-backed set should contain 🔒")
        #expect(!cs.contains(Unicode.Scalar(0x1F513)!), "String-backed set should not contain 🔓")
        #expect(!cs.contains(UnicodeScalar(0x0041)!), "String-backed set should not contain 'A'")
    }

    @Test func validateNonBMPCharactersPreservation() {
        let lock = Unicode.Scalar(0x1F512)! // 🔒
        let gClef = Unicode.Scalar(0x1D11E)! // 𝄞
        let characterSet = CharacterSet(charactersIn: "A🔒𝄞")

        // Round-trip through bitmapRepresentation should preserve all characters
        let roundTripped = CharacterSet(bitmapRepresentation: characterSet.bitmapRepresentation)

        #expect(roundTripped.contains(Unicode.Scalar(0x0041)!), "Round-tripped set should contain 'A'")
        #expect(roundTripped.contains(lock), "Round-tripped set should contain 🔒 (U+1F512)")
        #expect(roundTripped.contains(gClef), "Round-tripped set should contain 𝄞 (U+1D11E)")
    }

    @Test func inversionWithNonBMPCharacters() {
        let cs = CharacterSet(charactersIn: "🔒").inverted
        #expect(!cs.contains(Unicode.Scalar(0x1F512)!), "Inverted set should not contain 🔒")
        #expect(cs.contains(UnicodeScalar(0x0041)!), "Inverted set should contain 'A'")
        #expect(cs.contains(Unicode.Scalar(0x1F513)!), "Inverted set should contain 🔓")
    }

    @Test func removeNonBMPFromInvertedStringBackedSet() {
        var cs = CharacterSet(charactersIn: "A🔒")
        cs.invert()
        cs.remove(charactersIn: "🔓")

        #expect(!cs.contains(UnicodeScalar(0x0041)!), "Inverted set should not contain 'A'")
        #expect(!cs.contains(Unicode.Scalar(0x1F512)!), "Inverted set should not contain 🔒")
        #expect(!cs.contains(Unicode.Scalar(0x1F513)!), "Inverted set should not contain 🔓 after removal")
        #expect(cs.contains(UnicodeScalar(0x0042)!), "Inverted set should contain 'B'")
        #expect(cs.contains(Unicode.Scalar(0x1D11E)!), "Inverted set should contain 𝄞")

        let roundTripped = CharacterSet(bitmapRepresentation: cs.bitmapRepresentation)
        #expect(!roundTripped.contains(Unicode.Scalar(0x1F513)!), "Round-tripped inverted set should not contain 🔓")
    }

    @Test func insertNonBMPIntoBitmapBackedSet() {
        // A range-initialized set that gets converted to bitmap on mutation
        var cs = CharacterSet(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x005A)!) // A-Z
        cs.insert(charactersIn: "🔒𝄞")

        #expect(cs.contains(UnicodeScalar(0x0041)!), "Set should contain 'A'")
        #expect(cs.contains(UnicodeScalar(0x005A)!), "Set should contain 'Z'")
        #expect(cs.contains(Unicode.Scalar(0x1F512)!), "Set should contain 🔒")
        #expect(cs.contains(Unicode.Scalar(0x1D11E)!), "Set should contain 𝄞")
        #expect(cs.hasMember(inPlane: 1), "Set should have members in plane 1")

        let roundTripped = CharacterSet(bitmapRepresentation: cs.bitmapRepresentation)
        #expect(roundTripped.contains(Unicode.Scalar(0x1F512)!), "Round-tripped set should preserve 🔒")
        #expect(roundTripped.contains(Unicode.Scalar(0x1D11E)!), "Round-tripped set should preserve 𝄞")
    }

    @Test func formUnionWithBMPAndNonBMPCharacters() {
        var cs1 = CharacterSet(charactersIn: "A🔒")
        let cs2 = CharacterSet(charactersIn: "B𝄞")
        cs1.formUnion(cs2)

        #expect(cs1.contains(UnicodeScalar(0x0041)!), "Union should contain 'A'")
        #expect(cs1.contains(UnicodeScalar(0x0042)!), "Union should contain 'B'")
        #expect(cs1.contains(Unicode.Scalar(0x1F512)!), "Union should contain 🔒")
        #expect(cs1.contains(Unicode.Scalar(0x1D11E)!), "Union should contain 𝄞")
        #expect(cs1.hasMember(inPlane: 0))
        #expect(cs1.hasMember(inPlane: 1))
    }
    
    @Test func initWithLargeStringFallsToBitmap() {
        // 65 BMP scalars (exceeds __kCFStringCharSetMax of 64) + non-BMP
        let bmpScalars = (0x0041...0x0041 + 64).compactMap { UnicodeScalar($0) }
        let longString = String(String.UnicodeScalarView(bmpScalars)) + "🔒𝄞"
        let cs = CharacterSet(charactersIn: longString)

        #expect(cs.contains(UnicodeScalar(0x0041)!), "Set should contain 'A'")
        #expect(cs.contains(UnicodeScalar(0x0041 + 64)!), "Set should contain last BMP scalar")
        #expect(!cs.contains(UnicodeScalar(0x0041 + 65)!), "Set should not contain scalar past end")
        #expect(cs.contains(Unicode.Scalar(0x1F512)!), "Set should contain 🔒")
        #expect(cs.contains(Unicode.Scalar(0x1D11E)!), "Set should contain 𝄞")
        #expect(cs.hasMember(inPlane: 0))
        #expect(cs.hasMember(inPlane: 1))
        #expect(!cs.hasMember(inPlane: 2))

        let roundTripped = CharacterSet(bitmapRepresentation: cs.bitmapRepresentation)
        #expect(roundTripped.contains(UnicodeScalar(0x0041)!), "Round-tripped set should contain 'A'")
        #expect(roundTripped.contains(Unicode.Scalar(0x1F512)!), "Round-tripped set should preserve 🔒")
        #expect(roundTripped.contains(Unicode.Scalar(0x1D11E)!), "Round-tripped set should preserve 𝄞")
    }

    @Test func initFromEmptyString() {
        let cs = CharacterSet(charactersIn: "")

        #expect(cs.isEmpty)
        #expect(!cs.contains(UnicodeScalar(0x0041)!))
    }

    @Test func initWith63ScalarsIsStringBacked() {
        let s = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-"
        let cs = CharacterSet(charactersIn: s)

        for sc in s.unicodeScalars {
            #expect(cs.contains(sc))
        }
        #expect(!cs.contains(Unicode.Scalar(" ")))
        #expect(!cs.contains(Unicode.Scalar(".")))
    }

    @Test func initWith64ScalarsFallsToBitmap() {
        let s = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        let cs = CharacterSet(charactersIn: s)

        for sc in s.unicodeScalars {
            #expect(cs.contains(sc))
        }
        #expect(!cs.contains(Unicode.Scalar(" ")))
        #expect(!cs.contains(Unicode.Scalar("-")))
    }

    @Test func initIsOrderIndependent() {
        #expect(CharacterSet(charactersIn: "ABC") == CharacterSet(charactersIn: "CBA"))
        #expect(CharacterSet(charactersIn: "ABC") == CharacterSet(charactersIn: "BAC"))
    }

    @Test func initWithDuplicatesProducesSameSet() {
        #expect(CharacterSet(charactersIn: "AABBCC") == CharacterSet(charactersIn: "ABC"))
        #expect(CharacterSet(charactersIn: "🔒🔒🔒") == CharacterSet(charactersIn: "🔒"))
    }

    @Test func initIsolatesFromSourceStringMutation() {
        var source = "ABC"
        let cs = CharacterSet(charactersIn: source)
        source.append("DEF")

        #expect(cs.contains(UnicodeScalar("A")))
        #expect(cs.contains(UnicodeScalar("B")))
        #expect(cs.contains(UnicodeScalar("C")))
        #expect(!cs.contains(UnicodeScalar("D")))
        #expect(!cs.contains(UnicodeScalar("E")))
        #expect(!cs.contains(UnicodeScalar("F")))
    }

    @Test func initInterleavedBMPAndNonBMPIsOrderIndependent() {
        let interleaved = CharacterSet(charactersIn: "A🔒B𝄞C")
        let separated = CharacterSet(charactersIn: "ABC🔒𝄞")

        #expect(interleaved == separated)
        #expect(interleaved.contains(UnicodeScalar("A")))
        #expect(interleaved.contains(UnicodeScalar("B")))
        #expect(interleaved.contains(UnicodeScalar("C")))
        #expect(interleaved.contains(Unicode.Scalar(0x1F512)!))
        #expect(interleaved.contains(Unicode.Scalar(0x1D11E)!))
    }

    @Test func initFromManyNonBMPScalars() {
        let emojis = "😀😁😂🤣😃😄😅😆😉😊"
        let cs = CharacterSet(charactersIn: emojis)

        for sc in emojis.unicodeScalars {
            #expect(cs.contains(sc))
        }
        #expect(cs.hasMember(inPlane: 1))
        #expect(!cs.hasMember(inPlane: 2))
    }

    @Test func initRoundTripsAcrossAllPaths() {
        let inputs = [
            "",
            "ABC",
            "A🔒𝄞",
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()"
        ]

        for input in inputs {
            let cs = CharacterSet(charactersIn: input)
            let roundTripped = CharacterSet(bitmapRepresentation: cs.bitmapRepresentation)
            for sc in input.unicodeScalars {
                #expect(cs.contains(sc), "Original set missing \(sc) for input '\(input)'")
                #expect(roundTripped.contains(sc), "Round-tripped set missing \(sc) for input '\(input)'")
            }
        }
    }

    @Test func initWithBoundaryScalarsBMPAndNonBMP() {
        let s = "\u{0000}\u{FFFF}\u{10000}\u{10FFFF}"
        let cs = CharacterSet(charactersIn: s)

        #expect(cs.contains(Unicode.Scalar(0x0000)!))
        #expect(cs.contains(Unicode.Scalar(0xFFFF)!))
        #expect(cs.contains(Unicode.Scalar(0x10000)!))
        #expect(cs.contains(Unicode.Scalar(0x10FFFF)!))
        #expect(!cs.contains(Unicode.Scalar("A")))
        #expect(cs.hasMember(inPlane: 0))
        #expect(cs.hasMember(inPlane: 1))
        #expect(cs.hasMember(inPlane: 16))
        #expect(!cs.hasMember(inPlane: 2))
    }

    @Test func initWithMultiBytePerScalarBMPInput() {
        let s = "Привет, café 你好!"
        let cs = CharacterSet(charactersIn: s)

        for sc in s.unicodeScalars {
            #expect(cs.contains(sc))
        }
        
        #expect(cs.contains(Unicode.Scalar("你")))
        #expect(cs.hasMember(inPlane: 0))
        #expect(!cs.contains(Unicode.Scalar("Z")))
        #expect(!cs.contains(Unicode.Scalar(0x4F61)!))
        #expect(!cs.hasMember(inPlane: 1))
    }

    @Test func initFromShortNonASCIIStringWithLongUTF8Encoding() {
        let s = String(repeating: "Б", count: 33)
        let cs = CharacterSet(charactersIn: s)

        #expect(cs.contains(Unicode.Scalar("Б")))
        #expect(!cs.contains(Unicode.Scalar("A")))
        #expect(!cs.contains(Unicode.Scalar("В")))
    }

    private static func expectedBMPBitmap(for string: String) -> Data {
        var data = Data(count: 8192)
        for sc in string.unicodeScalars where sc.value < 0x10000 {
            let v = Int(sc.value)
            data[v >> 3] |= UInt8(1 << (v & 7))
        }
        return data
    }

    @Test func initFromLongASCIIStringMatchesHandComputedBMPBitmap() {
        let cs = CharacterSet(charactersIn: "!$&'()*+,-./0123456789:;=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~")
        #expect(cs.bitmapRepresentation.prefix(8192) == Self.expectedBMPBitmap(for: "!$&'()*+,-./0123456789:;=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~"))
    }

    @Test func initFromLongStringWithMultiplePagesAndNonBMPMatchesHandComputedBitmap() {
        let s = "ABCabc123Привет你好🔒🎵𝄞"
        let cs = CharacterSet(charactersIn: s)
        #expect(cs.bitmapRepresentation.prefix(8192) == Self.expectedBMPBitmap(for: s))
        for sc in s.unicodeScalars {
            #expect(cs.contains(sc))
        }
        #expect(cs.hasMember(inPlane: 0))
        #expect(cs.hasMember(inPlane: 1))
    }

    @Test func initAt128NonTrivialPagesMatchesHandComputedBitmap() {
        let scalars = (0..<128).compactMap {
            Unicode.Scalar($0 * 256 + 0x40)
        }
        let s = String(String.UnicodeScalarView(scalars))
        let cs = CharacterSet(charactersIn: s)
        #expect(cs.bitmapRepresentation.prefix(8192) == Self.expectedBMPBitmap(for: s))
    }

    @Test func initAbove128NonTrivialPagesFallsBackAndMatchesHandComputedBitmap() {
        let scalars = (0..<129).compactMap {
            Unicode.Scalar($0 * 256 + 0x40)
        }
        let s = String(String.UnicodeScalarView(scalars))
        let cs = CharacterSet(charactersIn: s)
        for sc in scalars {
            #expect(cs.contains(sc))
        }
        #expect(cs.bitmapRepresentation.prefix(8192) == Self.expectedBMPBitmap(for: s))
    }

    @Test func initFromLongStringEqualsInitFromItsOwnBitmapRepresentation() {
        let fromString = CharacterSet(charactersIn: "!$&'()*+,-./0123456789:;=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~")
        let fromBitmap = CharacterSet(bitmapRepresentation: fromString.bitmapRepresentation)
        #expect(fromString == fromBitmap)
    }

    @Test func stringBackedContainsUnsortedInputWithDuplicates() {
        let characterSet = CharacterSet(charactersIn: "zqamZQAMzqam")

        for scalar in "zqamZQAM".unicodeScalars {
            #expect(characterSet.contains(scalar))
        }
        for scalar in "bcdBCD".unicodeScalars {
            #expect(!characterSet.contains(scalar))
        }
    }

    @Test func stringBackedContainsAtSortedBoundaries() {
        let scalars = [0x0041, 0x00FF, 0x0100, 0xFFFE].compactMap { Unicode.Scalar($0) }
        let characterSet = CharacterSet(charactersIn: String(String.UnicodeScalarView(scalars.reversed())))

        for scalar in scalars {
            #expect(characterSet.contains(scalar))
        }
        #expect(!characterSet.contains(UnicodeScalar(0x0040)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(!characterSet.contains(UnicodeScalar(0x00FE)!))
        #expect(!characterSet.contains(UnicodeScalar(0xFFFD)!))
    }

    @Test func rangeInsertIntoStringBackedKeepsMembershipQueryable() {
        var characterSet = CharacterSet(charactersIn: "zyx")
        characterSet.insert(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x005A)!)

        for scalar in "zyx".unicodeScalars {
            #expect(characterSet.contains(scalar))
        }
        for rawValue in 0x0041...0x005A {
            #expect(characterSet.contains(UnicodeScalar(rawValue)!))
        }
        #expect(!characterSet.contains(UnicodeScalar(0x0040)!))
        #expect(!characterSet.contains(UnicodeScalar(0x005B)!))
    }
    
    private static func compactBackedUppercaseLetters() -> _CharacterSet {
        let characterSet = _CharacterSet(charactersIn: UnicodeScalar(0x0041)!..<UnicodeScalar(0x005B)!)
        characterSet.makeBitmap()
        return characterSet.compactCopy()
    }

    @Test func compactBitmapStringRemovalStaysInCompactStorage() {
        let characterSet = Self.compactBackedUppercaseLetters()
        #expect(characterSet.remove(charactersIn: "AMZ"))

        guard case .compactBitmap = characterSet.storage else {
            Issue.record("Expected removal to stay in compact bitmap storage")
            return
        }
        #expect(!characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(!characterSet.contains(UnicodeScalar(0x004D)!))
        #expect(!characterSet.contains(UnicodeScalar(0x005A)!))
        #expect(characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(characterSet.contains(UnicodeScalar(0x0059)!))
    }

    @Test func compactBitmapStringRemovalMatchesBitmapRemoval() {
        let viaCompact = Self.compactBackedUppercaseLetters()
        #expect(viaCompact.remove(charactersIn: "AMZ"))

        let viaBitmap = Self.compactBackedUppercaseLetters()
        viaBitmap.makeBitmap()
        #expect(viaBitmap.remove(charactersIn: "AMZ"))

        #expect(viaCompact.bitmapRepresentation == viaBitmap.bitmapRepresentation)
    }

    @Test func compactBitmapStringRemovalOfEntirePageFallsBackToBitmap() {
        let characterSet = _CharacterSet(charactersIn: UnicodeScalar(0x0041)!..<UnicodeScalar(0x0043)!)
        characterSet.makeBitmap()
        let compact = characterSet.compactCopy()

        #expect(compact.remove(charactersIn: "AB"))
        #expect(!compact.contains(UnicodeScalar(0x0041)!))
        #expect(!compact.contains(UnicodeScalar(0x0042)!))
    }
}
