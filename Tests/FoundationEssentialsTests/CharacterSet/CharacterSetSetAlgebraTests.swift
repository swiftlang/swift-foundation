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

extension Tag {
    @Tag static var characterSet: Self
}

internal func validateEmptySet(_ emptySet: CharacterSet) {
    for i in 0..<17 {
        #expect(!emptySet.hasMember(inPlane: UInt8(i)))
    }
}

internal func validateUniversalSet(_ fullSet: CharacterSet) {
    for i in 0..<17 {
        #expect(fullSet.hasMember(inPlane: UInt8(i)))
    }
}

private func bitmapBackedSet(everyNthScalar stride: Int) -> CharacterSet {
    var bitmap = Data(count: 8192)
    for value in Swift.stride(from: 0, to: 65536, by: stride) {
        bitmap[value / 8] |= UInt8(1 << (value % 8))
    }
    return CharacterSet(bitmapRepresentation: bitmap)
}

private func compactBitmapBackedSet(_ range: ClosedRange<Unicode.Scalar>) -> CharacterSet {
    CharacterSet(bitmapRepresentation: CharacterSet(charactersIn: range).bitmapRepresentation)
}

@Suite("Character Set: Insert, Update, Remove Tests", .tags(.characterSet))
private struct CharacterSetSingleCharacterMutationTests {
    
    @Test func insertCharacter() {
        var characterSet = CharacterSet()
        let min = Unicode.Scalar(0)!
        let max = Unicode.Scalar(0x10FFFF)!
        let lastBMP = Unicode.Scalar(0xFFFF)!
        let firstNonBMP = Unicode.Scalar(0x10000)!
        
        let insertionMin = characterSet.insert(min)
        #expect(insertionMin == (true, min))
        
        let insertionMax = characterSet.insert(max)
        #expect(insertionMax == (true, max))
        
        let insertionLastBMP = characterSet.insert(lastBMP)
        #expect(insertionLastBMP == (true, lastBMP))
        
        let insertionFirstNonBMP = characterSet.insert(firstNonBMP)
        #expect(insertionFirstNonBMP == (true, firstNonBMP))
        
        let secondInsertionMax = characterSet.insert(max)
        #expect(secondInsertionMax == (false , max))
        
        characterSet.invert()
        
        #expect(!characterSet.contains(min))
        #expect(!characterSet.contains(max))
        #expect(!characterSet.contains(lastBMP))
        #expect(!characterSet.contains(firstNonBMP))
    }
    

    @Test func updateCharacter() {
        var characterSet = CharacterSet(charactersIn: UnicodeScalar(0x0041)!..<UnicodeScalar(0x0045)!)
        
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(characterSet.contains(UnicodeScalar(0x0043)!))
        #expect(characterSet.contains(UnicodeScalar(0x0044)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0045)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0050)!))
        
        let updateWithNewCharacter = characterSet.update(with: UnicodeScalar(0x0050)!)
        let updateWithExistingCharacter = characterSet.update(with: UnicodeScalar(0x0043)!)
        
        #expect(updateWithNewCharacter == nil)
        #expect(updateWithExistingCharacter == UnicodeScalar(0x0043)!)
        
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(characterSet.contains(UnicodeScalar(0x0043)!))
        #expect(characterSet.contains(UnicodeScalar(0x0044)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0045)!))
        #expect(characterSet.contains(UnicodeScalar(0x0050)!))
    }
    
    @Test func removeCharacter() {
        var uppercaseLetters = CharacterSet.uppercaseLetters
                
        let removalOfAbsentCharacter = uppercaseLetters.remove(Unicode.Scalar(0x10000)!)
        #expect(removalOfAbsentCharacter == nil)
        
        let capitalA = Unicode.Scalar("A")
        let removalOfExistingCharacter = uppercaseLetters.remove(capitalA)
        #expect(removalOfExistingCharacter == capitalA)
        #expect(!uppercaseLetters.contains(capitalA))
        
        uppercaseLetters.invert()
        #expect(uppercaseLetters.contains(capitalA))
        
        let capitalB = Unicode.Scalar("B")
        #expect(!uppercaseLetters.contains(capitalB))
        
        let removalOfCapitalA = uppercaseLetters.remove(capitalA)
        #expect(removalOfCapitalA == capitalA)
        #expect(!uppercaseLetters.contains(capitalA))
    }
    
    @Test func insertAndRemoveCharacter() {
        var characterSet = CharacterSet()
        let capitalA = UnicodeScalar(0x0041)!
        let capitalB = UnicodeScalar(0x0042)!
        let capitalC = UnicodeScalar(0x0043)!
        
        let insertionA = characterSet.insert(capitalA)
        let insertionC = characterSet.insert(capitalC)
        
        #expect(insertionA == (true, capitalA))
        #expect(characterSet.contains(capitalA))

        #expect(insertionC == (true,capitalC))
        #expect(characterSet.contains(capitalC))

        let removalA = characterSet.remove(capitalA)
        #expect(removalA == capitalA)
        
        #expect(!characterSet.contains(capitalA))
        #expect(characterSet.contains(capitalC))
        
        let removalB = characterSet.remove(capitalB)
        #expect(removalB == nil)
        
        let reinsertionC = characterSet.insert(capitalC)
        #expect(reinsertionC == (false, capitalC))
        
        #expect(!characterSet.contains(capitalA))
        #expect(!characterSet.contains(capitalB))
        #expect(characterSet.contains(capitalC))
    }

    @Test func mutatingInvertedBuiltInKeepsSupplementaryMembership() {
        var set = CharacterSet.letters.inverted
        set.insert(UnicodeScalar("a"))

        #expect(set.contains(UnicodeScalar("a")))
        #expect(!set.contains(UnicodeScalar("b")))
        #expect(!set.contains(Unicode.Scalar(0x1D400)!))  // MATHEMATICAL BOLD CAPITAL A
        #expect(set.contains(Unicode.Scalar(0x1F600)!))   // emoji
    }

    @Test func removingFromInvertedBuiltInKeepsSupplementaryMembership() {
        var set = CharacterSet.letters.inverted
        set.remove(charactersIn: "!")

        #expect(!set.contains(UnicodeScalar("!")))
        #expect(!set.contains(Unicode.Scalar(0x1D400)!))  // MATHEMATICAL BOLD CAPITAL A
        #expect(set.contains(Unicode.Scalar(0x1F600)!))   // emoji
    }
}

@Suite("Character Set: Union Tests", .tags(.characterSet))
private struct CharacterSetUnionTests {
    
    @Test func unionEmpty() {
        let emptySet = CharacterSet()
        let anotherEmptySet = CharacterSet()
        
        let resultingEmptySet = emptySet.union(anotherEmptySet)
        validateEmptySet(resultingEmptySet)
    }
    
    @Test func unionInvertedEmpty() {
        let emptySet = CharacterSet()
        var invertedEmptySet = CharacterSet()
        
        invertedEmptySet.invert()
        
        let result = emptySet.union(invertedEmptySet)
        #expect(result.hasMember(inPlane: 0))
        #expect(result.hasMember(inPlane: 1))
        #expect(result.hasMember(inPlane: 5))
        #expect(result.hasMember(inPlane: 10))
        #expect(result.hasMember(inPlane: 15))
        
        #expect(result == invertedEmptySet)
    }
    
    @Test func unionBuiltInForNameValidation() {
        var validNames = CharacterSet.alphanumerics
        validNames.formUnion(CharacterSet.whitespaces)
        validNames.insert(charactersIn: ".'',-&#")
        
        #expect(validNames.contains(UnicodeScalar("-")))
        #expect(validNames.contains(UnicodeScalar("A")))
        #expect(validNames.contains(UnicodeScalar("z")))
    }
    
    @Test func unionBuiltInForPhoneNumberValidation() {
        var validPhoneNumbers = CharacterSet.decimalDigits
        validPhoneNumbers.formUnion(CharacterSet(charactersIn: "+()-"))
        validPhoneNumbers.formUnion(CharacterSet.controlCharacters)
        
        #expect(!validPhoneNumbers.contains(UnicodeScalar("#")))
        #expect(validPhoneNumbers.contains(UnicodeScalar("(")))
    }
    
    @Test func unionRangeSeparate() {
        let lowercaseRanges = CharacterSet(charactersIn: UnicodeScalar("a")...UnicodeScalar("z"))
        
        let uppercaseRanges = CharacterSet(charactersIn: UnicodeScalar("A")...UnicodeScalar("Z"))
        
        let letters = lowercaseRanges.union(uppercaseRanges)
        
        for char in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            #expect(letters.contains(char.unicodeScalars.first!))
        }
        
        #expect(!letters.contains(UnicodeScalar("0")))
        #expect(!letters.contains(UnicodeScalar("9")))
    }
    
    @Test func unionRangeOverlap() {
        let amRange = CharacterSet(charactersIn: UnicodeScalar("a")...UnicodeScalar("m"))
        
        let jzRange = CharacterSet(charactersIn: UnicodeScalar("j")...UnicodeScalar("z"))
        
        let lowercaseRanges = amRange.union(jzRange)
        
        for char in "abcdefghijklmnopqrstuvwxyz" {
            #expect(lowercaseRanges.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func unionRangeInverted() {
        let normalRange = CharacterSet(charactersIn: UnicodeScalar("a")...UnicodeScalar("c"))
        
        var invertedRange = CharacterSet()
        invertedRange.insert(charactersIn: UnicodeScalar("x")...UnicodeScalar("z"))
        invertedRange.invert()
        
        let resultRange = normalRange.union(invertedRange)
        
        #expect(resultRange.contains(UnicodeScalar("a")))
        #expect(resultRange.contains(UnicodeScalar("d")))
        #expect(resultRange.contains(UnicodeScalar("0")))
        #expect(!resultRange.contains(UnicodeScalar("x")))
        #expect(!resultRange.contains(UnicodeScalar("y")))
        #expect(!resultRange.contains(UnicodeScalar("z")))
    }
    
    @Test func unionString() {
        let abcSet = CharacterSet(charactersIn: "abc")
        
        let xyzSet = CharacterSet(charactersIn: "xyz")
        
        let abcxyzSet = abcSet.union(xyzSet)
        
        for char in "abcxyz" {
            #expect(abcxyzSet.contains(char.unicodeScalars.first!))
        }
        
        #expect(!abcxyzSet.contains(UnicodeScalar("d")))
        #expect(!abcxyzSet.contains(UnicodeScalar("0")))
    }
    
    @Test func unionStringDuplicates() {
        let abcSet = CharacterSet(charactersIn: "aabbcc")
        
        let bcdSet = CharacterSet(charactersIn: "bbccdd")
        
        let abcdSet = abcSet.union(bcdSet)
        
        for char in "abcd" {
            #expect(abcdSet.contains(char.unicodeScalars.first!))
        }
        
        #expect(!abcdSet.contains(UnicodeScalar("e")))
    }
    
    @Test func unionRangeAndString() {
        let rangeSet = CharacterSet(charactersIn: UnicodeScalar("0")...UnicodeScalar("9"))
        
        let stringSet = CharacterSet(charactersIn: "abc")
        
        let rangeAndStringSet = rangeSet.union(stringSet)
        
        for char in "0123456789abc" {
            #expect(rangeAndStringSet.contains(char.unicodeScalars.first!))
        }
        
        #expect(!rangeAndStringSet.contains(UnicodeScalar("z")))
    }
    
    @Test func unionEmojis() {
        var smileSet = CharacterSet()
        var bigSmileSet = CharacterSet()
        
        let emojiSmile = UnicodeScalar(0x1F600)! // 😀
        let emojiBigSmile = UnicodeScalar(0x1F601)! // 😁
        
        smileSet.insert(emojiSmile)
        bigSmileSet.insert(emojiBigSmile)
        
        let emojiSet = smileSet.union(bigSmileSet)
        
        #expect(emojiSet.contains(emojiSmile))
        #expect(emojiSet.contains(emojiBigSmile))
    }
    
    @Test func unionLargeSets() {
        var regularSet = CharacterSet()
        var greekSet = CharacterSet()
        
        regularSet.insert(charactersIn: "abcdefghijklmnopqrstuvwxyz")
        regularSet.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        regularSet.insert(charactersIn: "0123456789")
        
        greekSet.insert(charactersIn: "!@#$%^&*()")
        greekSet.insert(charactersIn: "αβγδεζηθικλμνξοπρστυφχψω")
        
        let largeSet = regularSet.union(greekSet)
        
        let allChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()"
        for char in allChars {
            #expect(largeSet.contains(char.unicodeScalars.first!))
        }
        
        for char in "αβγδεζηθικλμνξοπρστυφχψω" {
            #expect(largeSet.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func unionBoundaryValues() {
        var minSet = CharacterSet()
        var maxSet = CharacterSet()
        
        // Test with boundary values
        let minScalar = UnicodeScalar(0x0000)!
        let maxScalar = UnicodeScalar(0x10FFFF)!
        
        minSet.insert(minScalar)
        maxSet.insert(maxScalar)
        
        let boundarySet = minSet.union(maxSet)
        
        #expect(boundarySet.contains(minScalar))
        #expect(boundarySet.contains(maxScalar))
        #expect(!boundarySet.contains(UnicodeScalar("a")))
    }
    
    @Test func unionSelf() {
        var set = CharacterSet()
        set.insert(charactersIn: "hello")
        
        let result = set.union(set)
        
        for char in "hello" {
            #expect(result.contains(char.unicodeScalars.first!))
        }
        #expect(!result.contains(UnicodeScalar("x")))
    }
    
    @Test func unionLargeSetsUponIndividualInserts() {
        var rangeUntilFF = CharacterSet()
        var rangeUntil1FF = CharacterSet()
        
        for i in 0x0000...0x00FF {
            if let scalar = UnicodeScalar(i) {
                rangeUntilFF.insert(scalar)
            }
        }
        
        for i in 0x0100...0x01FF {
            if let scalar = UnicodeScalar(i) {
                rangeUntil1FF.insert(scalar)
            }
        }
        
        let result = rangeUntilFF.union(rangeUntil1FF)
        
        #expect(result.contains(UnicodeScalar(0x0050)!))
        #expect(result.contains(UnicodeScalar(0x0150)!))
        
        #expect(result.contains(UnicodeScalar(0x0000)!))
        #expect(result.contains(UnicodeScalar(0x00FF)!))
        #expect(result.contains(UnicodeScalar(0x0100)!))
        #expect(result.contains(UnicodeScalar(0x01FF)!))
    }
    
    @Test func unionImmutability() {
        let abcSet = CharacterSet(charactersIn: "abc")
        
        let xyzSet = CharacterSet(charactersIn: "xyz")
        
        let abcxyzSet = abcSet.union(xyzSet)
        
        #expect(abcSet.contains(UnicodeScalar("a")))
        #expect(!abcSet.contains(UnicodeScalar("x")))
        #expect(xyzSet.contains(UnicodeScalar("x")))
        #expect(!xyzSet.contains(UnicodeScalar("a")))
        
        #expect(abcxyzSet.contains(UnicodeScalar("a")))
        #expect(abcxyzSet.contains(UnicodeScalar("x")))
    }
    
    @Test func unionCopyOnWrite() {
        var abcSet = CharacterSet(charactersIn: "abc")
        
        let emptySet = CharacterSet()
        
        var copiedSet = emptySet
        copiedSet.insert(charactersIn: "xyz")
        
        abcSet.formUnion(copiedSet)
        
        validateEmptySet(emptySet)
        
        #expect(abcSet.contains(UnicodeScalar("a")))
        #expect(abcSet.contains(UnicodeScalar("x")))
        
        #expect(copiedSet.contains(UnicodeScalar("x")))
        #expect(!copiedSet.contains(UnicodeScalar("a")))
    }
    
    @Test func unionAlmostEverythingWithEmpty() async throws {
        var characterSet = CharacterSet(charactersIn: "\u{0000}"..."\u{10FFFF}")
        characterSet.remove(charactersIn: "\"\\\n\r\t\u{0008}\u{000C}")
        #expect(!characterSet.contains("\n"))

        var unionedCharacterSet = CharacterSet()
        unionedCharacterSet.formUnion(characterSet)

        #expect(unionedCharacterSet == characterSet)
        #expect(!characterSet.contains("\n"))
        #expect(!unionedCharacterSet.contains("\n"))
    }
    
    @Test func unionInvertedStringWithString() {
        var characterSet = CharacterSet(charactersIn: Unicode.Scalar(0x0000)!...Unicode.Scalar(0x10FFFF)!)
        characterSet.remove(charactersIn: "\n\r\t")
        #expect(!characterSet.contains(UnicodeScalar("\n")))
        #expect(!characterSet.contains(UnicodeScalar("\r")))
        #expect(!characterSet.contains(UnicodeScalar("\t")))

        var unionedCharacterSet = CharacterSet(charactersIn: "Z")
        unionedCharacterSet.formUnion(characterSet)
        
        #expect(!characterSet.contains(UnicodeScalar("\n")))

        #expect(unionedCharacterSet.contains(UnicodeScalar("A")))
        #expect(unionedCharacterSet.contains(UnicodeScalar("Z")))
        #expect(unionedCharacterSet.contains(UnicodeScalar(0x0000)!))
        #expect(unionedCharacterSet.contains(UnicodeScalar(0x0020)!))

        #expect(!unionedCharacterSet.contains(UnicodeScalar("\n")))
        #expect(!unionedCharacterSet.contains(UnicodeScalar("\r")))
        #expect(!unionedCharacterSet.contains(UnicodeScalar("\t")))
    }
    
    @Test func unionInvertedRangeNearSurrogateWithString() {
        var characterSet = CharacterSet(charactersIn: Unicode.Scalar(0x0041)!...Unicode.Scalar(0xD7FF)!)
        characterSet.invert()
        #expect(!characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(!characterSet.contains(UnicodeScalar(0xD7FF)!))

        var unionedCharacterSet = CharacterSet(charactersIn: "a")
        unionedCharacterSet.formUnion(characterSet)

        #expect(unionedCharacterSet.contains(UnicodeScalar(0x0000)!))
        #expect(unionedCharacterSet.contains(UnicodeScalar(0x0040)!))
        #expect(unionedCharacterSet.contains(UnicodeScalar(0xE000)!))
        #expect(unionedCharacterSet.contains(UnicodeScalar(0xFFFF)!))

        #expect(!unionedCharacterSet.contains(UnicodeScalar(0x0042)!))
        #expect(!unionedCharacterSet.contains(UnicodeScalar(0xD7FF)!))
    }
    
    @Test func unionStringBackedWithBuiltIn() {
        var actual = CharacterSet(charactersIn: "x")
        actual.formUnion(CharacterSet.illegalCharacters)

        var expected = CharacterSet.illegalCharacters
        expected.insert(charactersIn: "x")

        #expect(actual == expected)
    }

    @Test func unionInsertedStringBackedWithBuiltIn() {
        var s = CharacterSet(charactersIn: "x")
        s.insert(UnicodeScalar(0xE0001)!) // LANGUAGE TAG
        #expect(s.contains(UnicodeScalar(0xE0001)!))

        s.formUnion(.controlCharacters)

        #expect(s.contains(UnicodeScalar(0xE0001)!))
    }
    
    @Test func unionRangeBackedWithBuiltIn() {
        var cs = CharacterSet(charactersIn: Unicode.Scalar(0x0061)!...Unicode.Scalar(0x0067)!)
        cs.formUnion(CharacterSet.illegalCharacters)
        
        #expect(cs.contains(Unicode.Scalar(0x0065)!))
        for i in 0..<17 {
            #expect(cs.hasMember(inPlane: UInt8(i)))
        }
        
    }
    
    @Test func unionNonBMPSelfWithUniversalOther() {
        var set = CharacterSet()
        set.insert(Unicode.Scalar(0x1F600)!)
        set.insert(Unicode.Scalar(0x20000)!)

        var universal = CharacterSet()
        universal.invert()
        set.formUnion(universal)

        #expect(set.contains(Unicode.Scalar(0x30000)!))
        #expect(set.contains(Unicode.Scalar(0x1F600)!))
        #expect(set.contains(Unicode.Scalar(0x20000)!))
    }

    @Test func unionUniversalSelfIsNoOp() {
        var universal = CharacterSet()
        universal.invert()
        let untouched = universal

        universal.formUnion(CharacterSet(charactersIn: "abc"))
        #expect(universal == untouched)

        universal.formUnion(CharacterSet.letters)
        #expect(universal == untouched)

        validateUniversalSet(universal)
    }

    @Test func unionEmptySelfWithBuiltIn() {
        let adopted = CharacterSet().union(CharacterSet.illegalCharacters)

        #expect(adopted == CharacterSet.illegalCharacters)
        #expect(adopted.hasMember(inPlane: 4))
        #expect(adopted.hasMember(inPlane: 13))
    }

    @Test func unionWithInvertedBuiltIn() {
        let digits = CharacterSet(charactersIn: "0123456789")
        let result = digits.union(CharacterSet.letters.inverted)

        #expect(result.contains(UnicodeScalar("5")))
        #expect(result.contains(UnicodeScalar("!")))
        #expect(!result.contains(UnicodeScalar("a")))
        #expect(!result.contains(UnicodeScalar("Z")))

        #expect(result.contains(Unicode.Scalar(0x1F600)!))  // emoji
        #expect(!result.contains(Unicode.Scalar(0x1D400)!)) // MATHEMATICAL BOLD CAPITAL A
    }

    @Test func unionOfBitmapBackedSets() {
        let thirds = bitmapBackedSet(everyNthScalar: 3)
        let sevenths = bitmapBackedSet(everyNthScalar: 7)
        let merged = thirds.union(sevenths)

        var wrong: [String] = []
        for value in UInt32(0)...0xFFFF {
            guard let scalar = Unicode.Scalar(value) else { continue }
            if merged.contains(scalar) != (value % 3 == 0 || value % 7 == 0) {
                wrong.append("U+" + String(value, radix: 16, uppercase: true))
            }
        }
        #expect(wrong.isEmpty, "scalars merged incorrectly: \(wrong.prefix(8))")
    }

    @Test func unionOfBitmapAndCompactBitmapBackedSets() {
        let thirds = bitmapBackedSet(everyNthScalar: 3)
        let latinExtended = compactBitmapBackedSet(Unicode.Scalar(0x100)!...Unicode.Scalar(0x2FF)!)

        for merged in [thirds.union(latinExtended), latinExtended.union(thirds)] {
            var wrong: [String] = []
            for value in UInt32(0)...0xFFFF {
                guard let scalar = Unicode.Scalar(value) else { continue }
                let expected = value % 3 == 0 || (0x100...0x2FF).contains(value)
                if merged.contains(scalar) != expected {
                    wrong.append("U+" + String(value, radix: 16, uppercase: true))
                }
            }
            #expect(wrong.isEmpty, "scalars merged incorrectly: \(wrong.prefix(8))")
        }
    }

    @Test func unionWithInvertedAnnexPlanes() {
        var donor = CharacterSet(charactersIn: "abc")
        donor.insert(Unicode.Scalar(0x1F600)!)
        donor.invert()

        var receiver = CharacterSet(charactersIn: "xyz")
        receiver.insert(Unicode.Scalar(0x1F601)!)

        let result = receiver.union(donor)

        #expect(result.contains(UnicodeScalar("x")))
        #expect(result.contains(UnicodeScalar("q")))
        #expect(!result.contains(UnicodeScalar("a")))

        #expect(result.contains(Unicode.Scalar(0x1F601)!))
        #expect(!result.contains(Unicode.Scalar(0x1F600)!))
        #expect(result.contains(Unicode.Scalar(0x20000)!))
        #expect(result.contains(Unicode.Scalar(0x10FFFF)!))
    }

    @Test func unionWithInvertedAnnexWithoutPlanes() {
        let donor = compactBitmapBackedSet(Unicode.Scalar(0x100)!...Unicode.Scalar(0x2FF)!).inverted
        let result = CharacterSet(charactersIn: "xyz").union(donor)

        #expect(result.contains(UnicodeScalar("x")))
        #expect(result.contains(UnicodeScalar("q")))
        #expect(!result.contains(Unicode.Scalar(0x150)!))

        #expect(result.contains(Unicode.Scalar(0x1F600)!))
        #expect(result.contains(Unicode.Scalar(0x10FFFF)!))
    }

    @Test func unionInvertedAnnexSelfWithBuiltIn() {
        var receiver = CharacterSet(charactersIn: "abc")
        receiver.insert(Unicode.Scalar(0x1F600)!)
        receiver.invert()

        let result = receiver.union(CharacterSet.letters)
        
        #expect(result.contains(UnicodeScalar("a")))
        #expect(result.contains(UnicodeScalar("q")))
        
        #expect(!result.contains(Unicode.Scalar(0x1F600)!))
        #expect(result.contains(Unicode.Scalar(0x1D400)!))
        #expect(result.contains(Unicode.Scalar(0x20000)!))
    }

    @Test func unionWithDonorHoldingExplicitFullPlanes() {
        let donor = CharacterSet(charactersIn: "a").inverted.union(CharacterSet(charactersIn: "\u{1F600}"))
        let result = CharacterSet(charactersIn: "b").inverted.union(donor)

        #expect(result.contains(UnicodeScalar("a")))
        #expect(result.contains(UnicodeScalar("b")))
        #expect(result.contains(Unicode.Scalar(0x1F601)!))
        #expect(result.contains(Unicode.Scalar(0x20000)!))
        #expect(result.contains(Unicode.Scalar(0x10FFFF)!))
    }
}

@Suite("Character Set: Intersection Tests", .tags(.characterSet))
private struct CharacterSetIntersectionTests {
    
    @Test func intersectionEmptySets() {
        let emptySet = CharacterSet()
        let otherEmptySet = CharacterSet()
        
        let resultEmptySet = emptySet.intersection(otherEmptySet)
        validateEmptySet(resultEmptySet)
    }
    
    @Test func intersectionInvertedEmptySets() {
        let normalEmptySet = CharacterSet()
        var invertedEmptySet = CharacterSet()
        invertedEmptySet.invert()
                
        validateEmptySet(normalEmptySet.intersection(invertedEmptySet))

        validateEmptySet(invertedEmptySet.intersection(normalEmptySet))
        
        var everythingSet = CharacterSet()
        everythingSet.invert()

        validateUniversalSet(invertedEmptySet.intersection(everythingSet))

        let emptyResult = invertedEmptySet.intersection(normalEmptySet)
        #expect(emptyResult.isEmpty)
        #expect(!emptyResult.contains(Unicode.Scalar("a")))
        #expect(!emptyResult.contains(Unicode.Scalar(0x1F600)!))
        #expect(!emptyResult.contains(Unicode.Scalar(0x10FFFF)!))

        let universalResult = invertedEmptySet.intersection(everythingSet)
        #expect(!universalResult.isEmpty)
        #expect(universalResult.contains(Unicode.Scalar("a")))
        #expect(universalResult.contains(Unicode.Scalar(0xFFFF)!))
        #expect(universalResult.contains(Unicode.Scalar(0x1F600)!))
        #expect(universalResult.contains(Unicode.Scalar(0x10FFFF)!))
    }
    
    @Test func intersectionUniversalAndSmallSet() {
        var universalSet = CharacterSet()
        universalSet.invert()
        
        let specificSet = CharacterSet(charactersIn: "abc")
        
        let result = universalSet.intersection(specificSet)
        
        #expect(result.contains(UnicodeScalar("a")))
        #expect(result.contains(UnicodeScalar("b")))
        #expect(result.contains(UnicodeScalar("c")))
        #expect(!result.contains(UnicodeScalar("d")))
    }
    
    @Test func intersectionBuiltInAndEmptySets() {
        let letters = CharacterSet.letters
        let empty = CharacterSet()

        let result = letters.intersection(empty)

        validateEmptySet(result)
    }
    
    @Test func intersectionBuiltInSets() {
        let letters = CharacterSet.letters
        let digits = CharacterSet.decimalDigits

        let result = letters.intersection(digits)

        #expect(letters.contains(Unicode.Scalar("A")))
        #expect(digits.contains(Unicode.Scalar("5")))
        validateEmptySet(result)
    }
    
    @Test func formIntersectionBuiltInSets() {
        var characterSet = CharacterSet()
        characterSet.invert()
        let letters = CharacterSet.letters

        characterSet.formIntersection(letters)

        #expect(characterSet.contains(Unicode.Scalar("A")))
        #expect(!characterSet.contains(Unicode.Scalar("0")))
    }
    
    @Test func formIntersectionBuiltInWithStringBacked() {
        let mathBoldA = UnicodeScalar(0x1D400)! // Math Bold Capital A (uppercase)
        let linearB = UnicodeScalar(0x10000)! // Linear B Syllable (not uppercase)
        
        var characterSet = CharacterSet(charactersIn: "Xx")
        characterSet.insert(mathBoldA)
        characterSet.insert(linearB)
        
        characterSet.formIntersection(CharacterSet.uppercaseLetters)
        
        #expect(characterSet.contains(mathBoldA))
        #expect(!characterSet.contains(linearB))
        #expect(characterSet.contains("X"))
        #expect(!characterSet.contains("x"))
        #expect(!characterSet.contains(UnicodeScalar("A")))
    }

    @Test func formIntersectionWithIllegalCharacters() {
        let nullPlanes: [(first: UnicodeScalar, second: UnicodeScalar)] = [
            (UnicodeScalar(0x40000)!, UnicodeScalar(0x40001)!),  // plane 4
            (UnicodeScalar(0x50000)!, UnicodeScalar(0x50001)!),  // plane 5
            (UnicodeScalar(0x60000)!, UnicodeScalar(0x60001)!),  // plane 6
            (UnicodeScalar(0x70000)!, UnicodeScalar(0x70001)!),  // plane 7
            (UnicodeScalar(0x80000)!, UnicodeScalar(0x80001)!),  // plane 8
            (UnicodeScalar(0x90000)!, UnicodeScalar(0x90001)!),  // plane 9
            (UnicodeScalar(0xA0000)!, UnicodeScalar(0xA0001)!),  // plane 10
            (UnicodeScalar(0xB0000)!, UnicodeScalar(0xB0001)!),  // plane 11
            (UnicodeScalar(0xC0000)!, UnicodeScalar(0xC0001)!),  // plane 12
            (UnicodeScalar(0xD0000)!, UnicodeScalar(0xD0001)!),  // plane 13
        ]

        for (inSelf, notInSelf) in nullPlanes {
            var s = CharacterSet(charactersIn: "x")
            s.insert(inSelf)

            s.formIntersection(.illegalCharacters)

            #expect(!s.contains(notInSelf))
        }
    }

    @Test func intersectionOverlappingStrings() {
        let abcde = CharacterSet(charactersIn: "ABCDE")
        let cdefg = CharacterSet(charactersIn: "CDEFG")

        let result = abcde.intersection(cdefg)

        #expect(result.contains(Unicode.Scalar("C")))
        #expect(result.contains(Unicode.Scalar("D")))
        #expect(result.contains(Unicode.Scalar("E")))
        #expect(!result.contains(Unicode.Scalar("A")))
        #expect(!result.contains(Unicode.Scalar("G")))
    }
    
    @Test func intersectionWithOverlappingRanges() {
        let lettersAThroughM = CharacterSet(charactersIn: UnicodeScalar("a")...UnicodeScalar("m"))
        let lettersJThroughZ = CharacterSet(charactersIn: UnicodeScalar("j")...UnicodeScalar("z"))
        
        let overlappingLetters = lettersAThroughM.intersection(lettersJThroughZ)
        
        for char in "jklm" {
            #expect(overlappingLetters.contains(char.unicodeScalars.first!))
        }
        
        #expect(!overlappingLetters.contains(UnicodeScalar("a")))
        #expect(!overlappingLetters.contains(UnicodeScalar("i")))
        #expect(!overlappingLetters.contains(UnicodeScalar("n")))
        #expect(!overlappingLetters.contains(UnicodeScalar("z")))
    }
    
    @Test func intersectionWithNonOverlappingRanges() {
        let lettersAToC = CharacterSet(charactersIn: UnicodeScalar("a")...UnicodeScalar("c"))
        let lettersXToZ = CharacterSet(charactersIn: UnicodeScalar("x")...UnicodeScalar("z"))
        
        let emptyResult = lettersAToC.intersection(lettersXToZ)
        
        #expect(!emptyResult.contains(UnicodeScalar("a")))
        #expect(!emptyResult.contains(UnicodeScalar("b")))
        #expect(!emptyResult.contains(UnicodeScalar("c")))
        #expect(!emptyResult.contains(UnicodeScalar("x")))
        #expect(!emptyResult.contains(UnicodeScalar("y")))
        #expect(!emptyResult.contains(UnicodeScalar("z")))
        
        var mutableLettersAToC = lettersAToC
        mutableLettersAToC.formIntersection(lettersXToZ)
        #expect(!mutableLettersAToC.contains(UnicodeScalar("a")))
        #expect(!mutableLettersAToC.contains(UnicodeScalar("x")))
    }
    
    @Test func intersectionWithInvertedRanges() {
        let allLettersAToZ = CharacterSet(charactersIn: UnicodeScalar("a")...UnicodeScalar("z"))
        
        var lettersExcludingMToP = CharacterSet(charactersIn: UnicodeScalar("m")...UnicodeScalar("p"))
        lettersExcludingMToP.invert()
        let lettersExceptMToP = allLettersAToZ.intersection(lettersExcludingMToP)
        
        for char in "abcdefghijkl" {
            #expect(lettersExceptMToP.contains(char.unicodeScalars.first!))
        }
        for char in "qrstuvwxyz" {
            #expect(lettersExceptMToP.contains(char.unicodeScalars.first!))
        }
        
        for char in "mnop" {
            #expect(!lettersExceptMToP.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func intersectionWithStringStorage() {
        let lettersAToF = CharacterSet(charactersIn: "abcdef")
        let lettersCToH = CharacterSet(charactersIn: "cdefgh")
        
        let commonLetters = lettersAToF.intersection(lettersCToH)
        
        for char in "cdef" {
            #expect(commonLetters.contains(char.unicodeScalars.first!))
        }
        
        #expect(!commonLetters.contains(UnicodeScalar("a")))
        #expect(!commonLetters.contains(UnicodeScalar("b")))
        #expect(!commonLetters.contains(UnicodeScalar("g")))
        #expect(!commonLetters.contains(UnicodeScalar("h")))
    }
    
    @Test func intersectionWithNoCommonStringCharacters() {
        let lettersABC = CharacterSet(charactersIn: "abc")
        let lettersXYZ = CharacterSet(charactersIn: "xyz")
        
        let emptyIntersection = lettersABC.intersection(lettersXYZ)
        
        for char in "abcxyz" {
            #expect(!emptyIntersection.contains(char.unicodeScalars.first!))
        }
        
        var mutableLettersABC = lettersABC
        mutableLettersABC.formIntersection(lettersXYZ)
        for char in "abc" {
            #expect(!mutableLettersABC.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func formIntesectionStringAndBuiltIn() {
        var characterSet = CharacterSet(charactersIn: "ABCDEFG")
        let letters = CharacterSet.letters

        characterSet.formIntersection(letters)

        #expect(characterSet.contains(Unicode.Scalar("A")))
        #expect(characterSet.contains(Unicode.Scalar("G")))
        #expect(!characterSet.contains(Unicode.Scalar("Z")))
    }
    
    @Test func intersectionRangeAndString() {
        var rangeSet = CharacterSet()
        rangeSet.insert(charactersIn: UnicodeScalar("a")...UnicodeScalar("z"))
        
        var stringSet = CharacterSet()
        stringSet.insert(charactersIn: "aeiou123")
        
        let result = rangeSet.intersection(stringSet)
        
        for char in "aeiou" {
            #expect(result.contains(char.unicodeScalars.first!))
        }
        
        for char in "123" {
            #expect(!result.contains(char.unicodeScalars.first!))
        }
        
        #expect(!result.contains(UnicodeScalar("b")))
        #expect(!result.contains(UnicodeScalar("z")))
    }
    
    @Test func intersectionLargeSets() {
        var alphanumerics = CharacterSet()
        alphanumerics.insert(charactersIn: "abcdefghijklmnopqrstuvwxyz")
        alphanumerics.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        alphanumerics.insert(charactersIn: "0123456789")
        
        var random = CharacterSet()
        random.insert(charactersIn: "aeiouAEIOU")
        random.insert(charactersIn: "13579")
        random.insert(charactersIn: "!@#$%")
        
        let result = alphanumerics.intersection(random)
        
        for char in "aeiouAEIOU13579" {
            #expect(result.contains(char.unicodeScalars.first!))
        }
        
        #expect(!result.contains(UnicodeScalar("b")))
        #expect(!result.contains(UnicodeScalar("!")))
        #expect(!result.contains(UnicodeScalar("2")))
    }
    
    @Test func intersectionWithCustomAndBuiltInSets() {
        var customSet = CharacterSet()
        customSet.insert(charactersIn: "abc123XYZ!@#")
        
        let builtInSet = CharacterSet.letters
        
        let result = customSet.intersection(builtInSet)
        
        for char in "abcXYZ" {
            #expect(result.contains(char.unicodeScalars.first!))
        }
        
        for char in "123!@#" {
            #expect(!result.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func formIntersectionUniversalAndSmallNonBMPSets() {
        var characterSet = CharacterSet()
        characterSet.invert()
        
        let emoji = Unicode.Scalar(0x1F600)!

        var otherSet = CharacterSet()
        otherSet.insert(emoji)

        characterSet.formIntersection(otherSet)

        #expect(characterSet.contains(emoji))
    }

    
    @Test func intersectionWithNonBMPCharacters() {
        let grinningFace = UnicodeScalar(0x1F600)! // 😀
        let grinningFaceWithSmilingEyes = UnicodeScalar(0x1F601)! // 😁
        let faceWithTearsOfJoy = UnicodeScalar(0x1F602)! // 😂
        let grinningFaceWithBigEyes = UnicodeScalar(0x1F603)! // 😃
        
        let firstEmojiGroup = CharacterSet(charactersIn: grinningFace...faceWithTearsOfJoy)
        var secondEmojiGroup = CharacterSet(charactersIn: grinningFace...grinningFaceWithSmilingEyes)
        secondEmojiGroup.insert(grinningFaceWithBigEyes)
        
        let sharedEmojis = firstEmojiGroup.intersection(secondEmojiGroup)
        
        #expect(sharedEmojis.contains(grinningFace))
        #expect(sharedEmojis.contains(grinningFaceWithSmilingEyes))
        #expect(!sharedEmojis.contains(faceWithTearsOfJoy))
        #expect(!sharedEmojis.contains(grinningFaceWithBigEyes))
        
        var mutableFirstGroup = firstEmojiGroup
        mutableFirstGroup.formIntersection(secondEmojiGroup)
        #expect(mutableFirstGroup.contains(grinningFace))
        #expect(mutableFirstGroup.contains(grinningFaceWithSmilingEyes))
        #expect(!mutableFirstGroup.contains(faceWithTearsOfJoy))
        #expect(!mutableFirstGroup.contains(grinningFaceWithBigEyes))
    }
    
    @Test func intersectionWithMixedBMPAndNonBMP() {
        var lowercaseLettersAndGrinningFace = CharacterSet()
        lowercaseLettersAndGrinningFace.insert(charactersIn: "abc")
        lowercaseLettersAndGrinningFace.insert(UnicodeScalar(0x1F600)!) // 😀
        
        var middleLettersAndTwoEmojis = CharacterSet()
        middleLettersAndTwoEmojis.insert(charactersIn: "bcd")
        middleLettersAndTwoEmojis.insert(UnicodeScalar(0x1F600)!) // 😀
        middleLettersAndTwoEmojis.insert(UnicodeScalar(0x1F601)!) // 😁
        
        let commonCharacters = lowercaseLettersAndGrinningFace.intersection(middleLettersAndTwoEmojis)
        
        #expect(commonCharacters.contains(UnicodeScalar("b")))
        #expect(commonCharacters.contains(UnicodeScalar("c")))
        #expect(commonCharacters.contains(UnicodeScalar(0x1F600)!))
        
        #expect(!commonCharacters.contains(UnicodeScalar("a")))
        #expect(!commonCharacters.contains(UnicodeScalar("d")))
        #expect(!commonCharacters.contains(UnicodeScalar(0x1F601)!))
    }
    
    @Test func intersectionBoundary() {
        let nullCharacter = UnicodeScalar(0x0000)!
        let maximumUnicodeScalar = UnicodeScalar(0x10FFFF)!
        let firstSupplementaryPlaneCharacter = UnicodeScalar(0x10000)!
        
        var minAndMaxCharacters = CharacterSet()
        minAndMaxCharacters.insert(nullCharacter)
        minAndMaxCharacters.insert(maximumUnicodeScalar)
        
        var minAndMidCharacters = CharacterSet()
        minAndMidCharacters.insert(nullCharacter)
        minAndMidCharacters.insert(firstSupplementaryPlaneCharacter)
        let sharedCharacters = minAndMaxCharacters.intersection(minAndMidCharacters)
        
        #expect(sharedCharacters.contains(nullCharacter))
        #expect(!sharedCharacters.contains(maximumUnicodeScalar))
        #expect(!sharedCharacters.contains(firstSupplementaryPlaneCharacter))
    }
    
    @Test func intersectionWithSelf() {
        let helloAndDigits = CharacterSet(charactersIn: "hello123")
        
        let identicalSet = helloAndDigits.intersection(helloAndDigits)
        
        for character in "hello123" {
            #expect(identicalSet.contains(character.unicodeScalars.first!))
        }
        #expect(!identicalSet.contains(UnicodeScalar("x")))
    }
    
    @Test func intersectionWithLargeCharacterSets() {
        var basicLatinAndExtended = CharacterSet()
        var latinExtendedAndSupplementA = CharacterSet()
        
        for i in 0x0000...0x00FF {
            if let scalar = UnicodeScalar(i) {
                basicLatinAndExtended.insert(scalar)
            }
        }
        
        for i in 0x0080...0x017F {
            if let scalar = UnicodeScalar(i) {
                latinExtendedAndSupplementA.insert(scalar)
            }
        }
        
        let overlappingCharacters = basicLatinAndExtended.intersection(latinExtendedAndSupplementA)
        
        #expect(overlappingCharacters.contains(UnicodeScalar(0x0080)!))
        #expect(overlappingCharacters.contains(UnicodeScalar(0x00FF)!))
        
        #expect(!overlappingCharacters.contains(UnicodeScalar(0x0010)!))
        #expect(!overlappingCharacters.contains(UnicodeScalar(0x0170)!))
    }
    
    @Test func intersectionImmutability() {
        let afSet = CharacterSet(charactersIn: "abcdef")
        
        let chSet = CharacterSet(charactersIn: "cdefgh")
        
        let result = afSet.intersection(chSet)
        
        for char in "abcdef" {
            #expect(afSet.contains(char.unicodeScalars.first!))
        }
        for char in "cdefgh" {
            #expect(chSet.contains(char.unicodeScalars.first!))
        }
        
        for char in "cdef" {
            #expect(result.contains(char.unicodeScalars.first!))
        }
        
        #expect(!result.contains(UnicodeScalar("a")))
        #expect(!result.contains(UnicodeScalar("h")))
    }
    
    @Test func formIntersectionMutationCorrectness() {
        var afSet = CharacterSet(charactersIn: "abcdef")
        
        let chSet = CharacterSet(charactersIn: "cdefgh")
        
        let copiedSet = chSet
        
        afSet.formIntersection(chSet)
        
        for char in "cdef" {
            #expect(afSet.contains(char.unicodeScalars.first!))
        }
        #expect(!afSet.contains(UnicodeScalar("a")))
        #expect(!afSet.contains(UnicodeScalar("b")))
        
        #expect(copiedSet.contains(UnicodeScalar("c")))
        #expect(!copiedSet.contains(UnicodeScalar("a")))
        #expect(copiedSet.contains(UnicodeScalar("g")))
        #expect(copiedSet.contains(UnicodeScalar("h")))
    }
    
    @Test func intersectionAfterIndividualInserts() {
        var lowercaseLetters = CharacterSet()
        for i in UnicodeScalar("a").value...UnicodeScalar("z").value {
            if let scalar = UnicodeScalar(i) {
                lowercaseLetters.insert(scalar)
            }
        }
        
        var mzSet = CharacterSet()
        for i in UnicodeScalar("m").value...UnicodeScalar("z").value {
            if let scalar = UnicodeScalar(i) {
                mzSet.insert(scalar)
            }
        }
        
        let copiedSet = lowercaseLetters
        
        lowercaseLetters.formIntersection(mzSet)
        
        #expect(lowercaseLetters.contains(UnicodeScalar("m")))
        #expect(lowercaseLetters.contains(UnicodeScalar("z")))
        #expect(!lowercaseLetters.contains(UnicodeScalar("a")))
        
        #expect(copiedSet.contains(UnicodeScalar("a")))
        #expect(copiedSet.contains(UnicodeScalar("m")))
    }
    
    @Test func intersectionNonBMPRangeWithInvertedNonBMPRange() {
        // [😀...😂] ∩ ~[😁...😃] = [😀]
        let grinningFace = Unicode.Scalar(0x1F600)!
        let smilingEyes = Unicode.Scalar(0x1F601)!
        let tearsOfJoy = Unicode.Scalar(0x1F602)!
        let bigEyes = Unicode.Scalar(0x1F603)!

        let first = CharacterSet(charactersIn: grinningFace...tearsOfJoy)
        let second = CharacterSet(charactersIn: smilingEyes...bigEyes).inverted

        let result = first.intersection(second)

        #expect(result.contains(grinningFace))
        #expect(!result.contains(smilingEyes))
        #expect(!result.contains(tearsOfJoy))
        #expect(!result.contains(bigEyes))
    }

    @Test func intersectionNonBMPRangeWithDisjointNonBMPRange() {
        let grinningFace = Unicode.Scalar(0x1F600)!
        let tearsOfJoy = Unicode.Scalar(0x1F602)!

        let first = CharacterSet(charactersIn: grinningFace...grinningFace)
        let second = CharacterSet(charactersIn: tearsOfJoy...tearsOfJoy)

        let result = first.intersection(second)

        #expect(result.isEmpty)
        #expect(!result.contains(grinningFace))
        #expect(!result.contains(tearsOfJoy))
    }
    
    @Test func intersectionBitmapBackedWithInvertedBitmapMultiPlane() {
        // Self has plane 1 + plane 2 scalars (bitmap-backed after makeBitmap).
        // Other is inverted bitmap with plane 1 data only.
        // Plane 2 in other = nil + inverted annex = "everything" → keep self's plane 2.
        let plane1A = Unicode.Scalar(0x1F600)! // 😀 (plane 1)
        let plane1B = Unicode.Scalar(0x1F601)! // 😁 (plane 1)
        let plane2 = Unicode.Scalar(0x20000)!  // CJK Extension B (plane 2)

        var selfSet = CharacterSet()
        selfSet.insert(plane1A)
        selfSet.insert(plane1B)
        selfSet.insert(plane2)

        // Build other as bitmap-backed then invert, so it goes through the
        // hasNonBMPPlane path (not the .range path).
        var otherSet = CharacterSet()
        otherSet.insert(plane1A)
        otherSet.insert(plane1B)
        // Force bitmap by inserting enough to exceed string-backed capacity
        for v: UInt32 in 0x0100...0x0140 {
            otherSet.insert(Unicode.Scalar(v)!)
        }
        otherSet.invert() // now contains everything EXCEPT plane1A, plane1B, and 0x0100-0x0140

        let result = selfSet.intersection(otherSet)

        #expect(!result.contains(plane1A))
        #expect(!result.contains(plane1B))
        #expect(result.contains(plane2)) // plane 2 should be preserved
    }

    
    @Test func intersectionWithMixedBMPAndNonBMPWithStringInitializer() {
        let grinningFace = UnicodeScalar(0x1F600)! // 😀
        let grinningFaceWithSmilingEyes = UnicodeScalar(0x1F601)! // 😁
        
        var lowercaseLettersAndGrinningFace = CharacterSet(charactersIn: "abc")
        lowercaseLettersAndGrinningFace.insert(grinningFace)
        
        var middleLettersAndTwoEmojis = CharacterSet(charactersIn: "bcd")
        middleLettersAndTwoEmojis.insert(grinningFace)
        middleLettersAndTwoEmojis.insert(grinningFaceWithSmilingEyes)
        
        let commonCharacters = lowercaseLettersAndGrinningFace.intersection(middleLettersAndTwoEmojis)
        
        #expect(commonCharacters.contains(UnicodeScalar("b")))
        #expect(commonCharacters.contains(UnicodeScalar("c")))
        #expect(commonCharacters.contains(grinningFace))
        
        #expect(!commonCharacters.contains(UnicodeScalar("a")))
        #expect(!commonCharacters.contains(UnicodeScalar("d")))
        #expect(!commonCharacters.contains(grinningFaceWithSmilingEyes))
    }
    
    @Test func intersectionWithInvertedAnnexPlanes() {
        var set1 = CharacterSet()
        set1.insert(UnicodeScalar(0x1F600)!) // Plane 1
        set1.insert(UnicodeScalar(0x1F601)!) // Plane 1
        
        var set2 = CharacterSet()
        set2.insert(UnicodeScalar(0x1F600)!) // Plane 1 - same emoji
        set2.invert() // Invert the annex
        
        let result = set1.intersection(set2)
        
        #expect(result.contains(UnicodeScalar(0x1F601)!))
        #expect(!result.contains(UnicodeScalar(0x1F600)!))
    }

    @Test func intersectionWithInvertedBuiltIn() {
        var receiver = CharacterSet(charactersIn: "abc")
        receiver.insert(Unicode.Scalar(0x1F600)!)  // emoji
        receiver.insert(Unicode.Scalar(0x1D400)!)  // MATHEMATICAL BOLD CAPITAL A

        let result = receiver.intersection(CharacterSet.letters.inverted)

        #expect(!result.contains(UnicodeScalar("a")))
        #expect(result.contains(Unicode.Scalar(0x1F600)!))
        #expect(!result.contains(Unicode.Scalar(0x1D400)!))
    }

    @Test func intersectionWithInvertedAnnexWithoutPlanes() {
        let donor = compactBitmapBackedSet(Unicode.Scalar(0x100)!...Unicode.Scalar(0x2FF)!).inverted

        var receiver = CharacterSet(charactersIn: "xyz")
        receiver.insert(Unicode.Scalar(0x150)!)
        receiver.insert(Unicode.Scalar(0x1F600)!)

        let result = receiver.intersection(donor)

        #expect(result.contains(UnicodeScalar("x")))
        #expect(!result.contains(Unicode.Scalar(0x150)!))
        #expect(result.contains(Unicode.Scalar(0x1F600)!))
    }

    @Test func intersectionOfBitmapBackedSets() {
        let thirds = bitmapBackedSet(everyNthScalar: 3)
        let sevenths = bitmapBackedSet(everyNthScalar: 7)
        let merged = thirds.intersection(sevenths)

        var wrong: [String] = []
        for value in UInt32(0)...0xFFFF {
            guard let scalar = Unicode.Scalar(value) else { continue }
            if merged.contains(scalar) != (value % 21 == 0) {
                wrong.append("U+" + String(value, radix: 16, uppercase: true))
            }
        }
        #expect(wrong.isEmpty, "scalars intersected incorrectly: \(wrong.prefix(8))")
    }
}

@Suite("CharacterSet: Subtracting Tests", .tags(.characterSet))
private struct CharacterSetSubtractingTests {
    
    @Test func subtractingWithEmptySets() {
        var mutableEmpty = CharacterSet()
        let emptySet = CharacterSet()
        
        validateEmptySet(mutableEmpty.subtracting(emptySet))
        
        mutableEmpty.subtract(emptySet)
        validateEmptySet(mutableEmpty)
    }
    
    @Test func subtractingFromNonEmptyWithEmpty() {
        var abcSet = CharacterSet(charactersIn: "abc")
        let emptySet = CharacterSet()
        
        let result = abcSet.subtracting(emptySet)
        
        for char in "abc" {
            #expect(result.contains(char.unicodeScalars.first!))
        }

        #expect(!result.contains(Unicode.Scalar("d")))
        
        abcSet.subtract(emptySet)
        for char in "abc" {
            #expect(abcSet.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func subtractingWithInvertedEmptySet() {
        var abcSet = CharacterSet(charactersIn: "abc")
        
        var universalSet = CharacterSet()
        universalSet.invert()
        
        let result = abcSet.subtracting(universalSet)
        
        validateEmptySet(result)
        
        abcSet.subtract(universalSet)
        #expect(!abcSet.contains(Unicode.Scalar("a")))
        #expect(!abcSet.contains(Unicode.Scalar("b")))
        #expect(!abcSet.contains(Unicode.Scalar("c")))
    }
    
    @Test func subtractingWithPartialOverlap() {
        var abcdefSet = CharacterSet(charactersIn: "abcdef")
        let cdefghSet = CharacterSet(charactersIn: "cdefgh")
        
        let result = abcdefSet.subtracting(cdefghSet)
        
        #expect(result.contains(Unicode.Scalar("a")))
        #expect(result.contains(Unicode.Scalar("b")))
        
        #expect(!result.contains(Unicode.Scalar("c")))
        #expect(!result.contains(Unicode.Scalar("d")))
        #expect(!result.contains(Unicode.Scalar("e")))
        #expect(!result.contains(Unicode.Scalar("f")))
        
        #expect(!result.contains(Unicode.Scalar("g")))
        #expect(!result.contains(Unicode.Scalar("h")))
        
        abcdefSet.subtract(cdefghSet)
        #expect(abcdefSet.contains(Unicode.Scalar("a")))
        #expect(abcdefSet.contains(Unicode.Scalar("b")))
        #expect(!abcdefSet.contains(Unicode.Scalar("c")))
        #expect(!abcdefSet.contains(Unicode.Scalar("f")))
    }
    
    @Test func subtractingWithNoOverlap() {
        let abcSet = CharacterSet(charactersIn: "abc")
        let xyzSet = CharacterSet(charactersIn: "xyz")
        
        let result = abcSet.subtracting(xyzSet)
        
        for char in "abc" {
            #expect(result.contains(char.unicodeScalars.first!))
        }
        
        for char in "xyz" {
            #expect(!result.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func subtractingWithCompleteOverlap() {
        var abcSet = CharacterSet(charactersIn: "abc")
        let identicalSet = CharacterSet(charactersIn: "abc")
        
        let result = abcSet.subtracting(identicalSet)
        
        validateEmptySet(result)
        
        abcSet.subtract(identicalSet)
        #expect(!abcSet.contains(Unicode.Scalar("a")))
        #expect(!abcSet.contains(Unicode.Scalar("b")))
        #expect(!abcSet.contains(Unicode.Scalar("c")))
    }
    
    @Test func subtractingOfSuperset() {
        let abcSet = CharacterSet(charactersIn: "abc")
        let abcdefghSet = CharacterSet(charactersIn: "abcdefgh")
        
        let result = abcSet.subtracting(abcdefghSet)
        
        validateEmptySet(result)
    }
    
    @Test func subtractingWithRangeStorage() {
        let aToZRange = CharacterSet(charactersIn: Unicode.Scalar("a")...Unicode.Scalar("z"))
        let mToSRange = CharacterSet(charactersIn: Unicode.Scalar("m")...Unicode.Scalar("s"))
        
        let result = aToZRange.subtracting(mToSRange)
        
        for char in "abcdefghijkl" {
            #expect(result.contains(char.unicodeScalars.first!))
        }
        
        for char in "tuvwxyz" {
            #expect(result.contains(char.unicodeScalars.first!))
        }
        
        for char in "mnopqrs" {
            #expect(!result.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func subtractingWithOverlappingRangesAtBoundaries() {
        let aToMRange = CharacterSet(charactersIn: Unicode.Scalar("a")...Unicode.Scalar("m"))
        let jToZRange = CharacterSet(charactersIn: Unicode.Scalar("j")...Unicode.Scalar("z"))
        
        let result = aToMRange.subtracting(jToZRange)
        
        for char in "abcdefghi" {
            #expect(result.contains(char.unicodeScalars.first!))
        }
        
        for char in "jklm" {
            #expect(!result.contains(char.unicodeScalars.first!))
        }
        
        for char in "nopqrstuvwxyz" {
            #expect(!result.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func subtractingWithStringStorage() {
        let programmingSet = CharacterSet(charactersIn: "programming")
        let gramSet = CharacterSet(charactersIn: "gram")
        
        let result = programmingSet.subtracting(gramSet)
        
        #expect(result.contains(Unicode.Scalar("p")))
        #expect(result.contains(Unicode.Scalar("o")))
        #expect(result.contains(Unicode.Scalar("i")))
        #expect(result.contains(Unicode.Scalar("n")))
        
        #expect(!result.contains(Unicode.Scalar("g")))
        #expect(!result.contains(Unicode.Scalar("r")))
        #expect(!result.contains(Unicode.Scalar("a")))
        #expect(!result.contains(Unicode.Scalar("m")))
    }
    
    @Test func subtractingBetweenDifferentStorageTypes() {
        let lowercaseRange = CharacterSet(charactersIn: Unicode.Scalar("a")...Unicode.Scalar("z"))
        let vowels = CharacterSet(charactersIn: "aeiou")
        
        let consonants = lowercaseRange.subtracting(vowels)
        
        for char in "bcdfghjklmnpqrstvwxyz" {
            #expect(consonants.contains(char.unicodeScalars.first!))
        }
        
        for char in "aeiou" {
            #expect(!consonants.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func subtractingWithNonBMPCharacters() {
        let grinningFace = UnicodeScalar(0x1F600)! // 😀
        let grinningFaceWithSmilingEyes = UnicodeScalar(0x1F601)! // 😁
        let faceWithTearsOfJoy = UnicodeScalar(0x1F602)! // 😂
        let grinningFaceWithBigEyes = UnicodeScalar(0x1F603)! // 😃
        
        var firstEmojiGroup = CharacterSet()
        firstEmojiGroup.insert(grinningFace)
        firstEmojiGroup.insert(grinningFaceWithSmilingEyes)
        firstEmojiGroup.insert(faceWithTearsOfJoy)
        
        var secondEmojiGroup = CharacterSet()
        secondEmojiGroup.insert(grinningFaceWithSmilingEyes)
        secondEmojiGroup.insert(faceWithTearsOfJoy)
        secondEmojiGroup.insert(grinningFaceWithBigEyes)
        
        let result = firstEmojiGroup.subtracting(secondEmojiGroup)
        
        #expect(result.contains(grinningFace))
        
        #expect(!result.contains(grinningFaceWithSmilingEyes))
        #expect(!result.contains(faceWithTearsOfJoy))
        
        #expect(!result.contains(grinningFaceWithBigEyes))
    }
    
    @Test func subtractingWithMixedBMPAndNonBMP() {
        let grinningFace = UnicodeScalar(0x1F600)! // 😀
        
        var abcAndGrinningFace = CharacterSet(charactersIn: "abc")
        abcAndGrinningFace.insert(grinningFace)
        
        var bcdAndGrinningFace = CharacterSet(charactersIn: "bcd")
        bcdAndGrinningFace.insert(grinningFace)
        
        let result = abcAndGrinningFace.subtracting(bcdAndGrinningFace)
        
        #expect(result.contains(Unicode.Scalar("a")))
        
        #expect(!result.contains(Unicode.Scalar("b")))
        #expect(!result.contains(Unicode.Scalar("c")))
        #expect(!result.contains(grinningFace))
        
        #expect(!result.contains(Unicode.Scalar("d")))
    }
    
    @Test func subtractingWithInvertedSets() {
        let abcdefghSet = CharacterSet(charactersIn: "abcdefgh")
        
        var cdefExcluded = CharacterSet(charactersIn: "cdef")
        cdefExcluded.invert()
        
        let result = abcdefghSet.subtracting(cdefExcluded)
        
        #expect(result.contains(Unicode.Scalar("c")))
        #expect(result.contains(Unicode.Scalar("d")))
        #expect(result.contains(Unicode.Scalar("e")))
        #expect(result.contains(Unicode.Scalar("f")))
        
        #expect(!result.contains(Unicode.Scalar("a")))
        #expect(!result.contains(Unicode.Scalar("b")))
        #expect(!result.contains(Unicode.Scalar("g")))
        #expect(!result.contains(Unicode.Scalar("h")))
    }
    
    @Test func subtractingFromInvertedSet() {
        var abcExcluded = CharacterSet(charactersIn: "abc")
        abcExcluded.invert()
        
        let xyzSet = CharacterSet(charactersIn: "xyz")
        
        let result = abcExcluded.subtracting(xyzSet)
        
        #expect(result.contains(Unicode.Scalar("d")))
        #expect(result.contains(Unicode.Scalar("m")))
        #expect(result.contains(Unicode.Scalar("1")))
        
        #expect(!result.contains(Unicode.Scalar("a")))
        #expect(!result.contains(Unicode.Scalar("b")))
        #expect(!result.contains(Unicode.Scalar("c")))
        
        #expect(!result.contains(Unicode.Scalar("x")))
        #expect(!result.contains(Unicode.Scalar("y")))
        #expect(!result.contains(Unicode.Scalar("z")))
    }
    
    @Test func subtractingWithSelf() {
        let helloSet = CharacterSet(charactersIn: "hello")
        
        let result = helloSet.subtracting(helloSet)
        
        for char in "hello" {
            #expect(!result.contains(char.unicodeScalars.first!))
        }
        
        var mutableHelloSet = helloSet
        mutableHelloSet.subtract(helloSet)
        for char in "hello" {
            #expect(!mutableHelloSet.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func subtractingWithMaximumUnicodeValues() {
        let nullCharacter = UnicodeScalar(0x0000)!
        let maximumSupplementaryPlaneCharacter = UnicodeScalar(0x1FFFF)!
        let firstSupplementaryPlaneCharacter = UnicodeScalar(0x10000)!
        
        var minAndMaxCharacters = CharacterSet()
        minAndMaxCharacters.insert(nullCharacter)
        minAndMaxCharacters.insert(maximumSupplementaryPlaneCharacter)
        
        var maxAndMidCharacters = CharacterSet()
        maxAndMidCharacters.insert(maximumSupplementaryPlaneCharacter)
        maxAndMidCharacters.insert(firstSupplementaryPlaneCharacter)
        
        let result = minAndMaxCharacters.subtracting(maxAndMidCharacters)
        
        #expect(result.contains(nullCharacter))
        #expect(!result.contains(maximumSupplementaryPlaneCharacter))
        #expect(!result.contains(firstSupplementaryPlaneCharacter))
    }
    
    @Test func subtractingImmutability() {
        let abcdefSet = CharacterSet(charactersIn: "abcdef")
        let cdefSet = CharacterSet(charactersIn: "cdef")
        
        let result = abcdefSet.subtracting(cdefSet)
        
        for char in "abcdef" {
            #expect(abcdefSet.contains(char.unicodeScalars.first!))
        }
        for char in "cdef" {
            #expect(cdefSet.contains(char.unicodeScalars.first!))
        }
        
        #expect(result.contains(Unicode.Scalar("a")))
        #expect(result.contains(Unicode.Scalar("b")))
        #expect(!result.contains(Unicode.Scalar("c")))
        #expect(!result.contains(Unicode.Scalar("f")))
    }
    
    @Test func subtractMutationCorrectness() {
        var abcdefSet = CharacterSet(charactersIn: "abcdef")
        let cdefSet = CharacterSet(charactersIn: "cdef")
        
        let cdefContainsC = cdefSet.contains(Unicode.Scalar("c"))
        let cdefContainsA = cdefSet.contains(Unicode.Scalar("a"))
        
        abcdefSet.subtract(cdefSet)
        
        #expect(abcdefSet.contains(Unicode.Scalar("a")))
        #expect(abcdefSet.contains(Unicode.Scalar("b")))
        #expect(!abcdefSet.contains(Unicode.Scalar("c")))
        #expect(!abcdefSet.contains(Unicode.Scalar("d")))
        
        #expect(cdefSet.contains(Unicode.Scalar("c")) == cdefContainsC)
        #expect(cdefSet.contains(Unicode.Scalar("a")) == cdefContainsA)
        #expect(cdefSet.contains(Unicode.Scalar("d")))
        #expect(cdefSet.contains(Unicode.Scalar("e")))
    }
    
    @Test func subtractingForcingBitmapConversion() {
        var alphanumerics = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz")
        alphanumerics.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        alphanumerics.insert(charactersIn: "0123456789")
        
        var vowelsAndOddDigits = CharacterSet(charactersIn: "aeiouAEIOU")
        vowelsAndOddDigits.insert(charactersIn: "13579")
        
        let consonantsAndEvenDigits = alphanumerics.subtracting(vowelsAndOddDigits)
        
        for char in "bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ02468" {
            #expect(consonantsAndEvenDigits.contains(char.unicodeScalars.first!))
        }
        
        for char in "aeiouAEIOU13579" {
            #expect(!consonantsAndEvenDigits.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func subtractingWithLargeCharacterSets() {
        var basicLatinRange = CharacterSet()
        for i in 0x0000...0x00FF {
            if let scalar = UnicodeScalar(i) {
                basicLatinRange.insert(scalar)
            }
        }
        
        var latinExtendedRange = CharacterSet()
        for i in 0x0080...0x00FF {
            if let scalar = UnicodeScalar(i) {
                latinExtendedRange.insert(scalar)
            }
        }
        
        let basicLatinOnly = basicLatinRange.subtracting(latinExtendedRange)
        
        #expect(basicLatinOnly.contains(UnicodeScalar(0x0000)!))
        #expect(basicLatinOnly.contains(UnicodeScalar(0x007F)!))
        
        #expect(!basicLatinOnly.contains(UnicodeScalar(0x0080)!))
        #expect(!basicLatinOnly.contains(UnicodeScalar(0x00FF)!))
    }
    
    @Test func propertySubtractingSelfEqualsEmpty() {
        let randomSet = CharacterSet(charactersIn: "random123")
        
        let result = randomSet.subtracting(randomSet)
        
        for char in "random123" {
            #expect(!result.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func propertySubtractingEmptyEqualsOriginal() {
        let testSet = CharacterSet(charactersIn: "test")
        let emptySet = CharacterSet()
        
        let result = testSet.subtracting(emptySet)
        
        for char in "test" {
            #expect(result.contains(char.unicodeScalars.first!))
        }
    }
    
    @Test func propertyEmptySubtractingEqualsEmpty() {
        let emptySet = CharacterSet()
        let anythingSet = CharacterSet(charactersIn: "anything")
        
        let result = emptySet.subtracting(anythingSet)
        
        validateEmptySet(result)
    }
    
    @Test func propertySubtractingIsSubsetOfOriginal() {
        let abcdefghSet = CharacterSet(charactersIn: "abcdefgh")
        let cdefijklSet = CharacterSet(charactersIn: "cdefijkl")
        
        let result = abcdefghSet.subtracting(cdefijklSet)
        
        for testChar in "abcdefghijklmnopqrstuvwxyz" {
            if result.contains(testChar.unicodeScalars.first!) {
                #expect(abcdefghSet.contains(testChar.unicodeScalars.first!), "Result contains element not in original set A")
            }
        }
    }
    
    @Test func subtractInvertedRangeMultiPlaneKeepsOtherPlanes() {
        let plane1Scalar = Unicode.Scalar(0x1F600)! // 😀 (plane 1)
        let plane2Scalar = Unicode.Scalar(0x20000)! // CJK Extension B (plane 2)

        var multiPlane = CharacterSet()
        multiPlane.insert(plane1Scalar)
        multiPlane.insert(plane2Scalar)

        var plane1Only = CharacterSet()
        plane1Only.insert(plane1Scalar)

        let result = multiPlane.subtracting(plane1Only)

        #expect(!result.contains(plane1Scalar))
        #expect(!result.hasMember(inPlane: 1))
        #expect(result.contains(plane2Scalar))
        #expect(result.hasMember(inPlane: 2))

    }

    @Test func subtractNonBMPRangeFromNonBMPRange() {
        let grinningFace = Unicode.Scalar(0x1F600)!
        let smilingEyes = Unicode.Scalar(0x1F601)!
        let tearsOfJoy = Unicode.Scalar(0x1F602)!
        let bigEyes = Unicode.Scalar(0x1F603)!

        let first = CharacterSet(charactersIn: grinningFace...tearsOfJoy)
        let second = CharacterSet(charactersIn: smilingEyes...bigEyes)

        let result = first.subtracting(second)

        #expect(result.contains(grinningFace))
        #expect(!result.contains(smilingEyes))
        #expect(!result.contains(tearsOfJoy))
        #expect(!result.contains(bigEyes))
    }
}

@Suite("CharacterSet: Symmetric Difference Tests", .tags(.characterSet))
private struct CharacterSetSymmetricDifferenceTests {
    
    @Test func emptySetSymmetricDifference() {
        let firstEmpty = CharacterSet()
        let secondEmpty = CharacterSet()
        
        let result = firstEmpty.symmetricDifference(secondEmpty)
        
        validateEmptySet(result)
    }
    
    @Test func emptyWithNonEmptySymmetricDifference() {
        let emptySet = CharacterSet()
        let abcSet = CharacterSet(charactersIn: "abc")
        
        let emptyWithAbc = emptySet.symmetricDifference(abcSet)
        let abcWithEmpty = abcSet.symmetricDifference(emptySet)
        
        #expect(emptyWithAbc.contains(Unicode.Scalar("a")))
        #expect(emptyWithAbc.contains(Unicode.Scalar("b")))
        #expect(emptyWithAbc.contains(Unicode.Scalar("c")))
        #expect(!emptyWithAbc.contains(Unicode.Scalar("d")))
        
        #expect(abcWithEmpty.contains(Unicode.Scalar("a")))
        #expect(abcWithEmpty.contains(Unicode.Scalar("b")))
        #expect(abcWithEmpty.contains(Unicode.Scalar("c")))
        #expect(!abcWithEmpty.contains(Unicode.Scalar("d")))
    }
    
    @Test func identicalSetsSymmetricDifference() {
        let firstAbcSet = CharacterSet(charactersIn: "abc")
        let secondAbcSet = CharacterSet(charactersIn: "abc")
        
        let result = firstAbcSet.symmetricDifference(secondAbcSet)
        
        validateEmptySet(result)
    }
    
    @Test func disjointSetsSymmetricDifference() {
        let abcSet = CharacterSet(charactersIn: "abc")
        let xyzSet = CharacterSet(charactersIn: "xyz")
        
        let result = abcSet.symmetricDifference(xyzSet)
        
        #expect(result.contains(Unicode.Scalar("a")))
        #expect(result.contains(Unicode.Scalar("b")))
        #expect(result.contains(Unicode.Scalar("c")))
        #expect(result.contains(Unicode.Scalar("x")))
        #expect(result.contains(Unicode.Scalar("y")))
        #expect(result.contains(Unicode.Scalar("z")))
        
        #expect(!result.contains(Unicode.Scalar("d")))
        #expect(!result.contains(Unicode.Scalar("w")))
    }
 
    @Test func overlappingSetsSymmetricDifference() {
        let abcdSet = CharacterSet(charactersIn: "abcd")
        let cdefSet = CharacterSet(charactersIn: "cdef")
        
        let result = abcdSet.symmetricDifference(cdefSet)
        
        #expect(result.contains(Unicode.Scalar("a")))
        #expect(result.contains(Unicode.Scalar("b")))
        #expect(result.contains(Unicode.Scalar("e")))
        #expect(result.contains(Unicode.Scalar("f")))
        
        #expect(!result.contains(Unicode.Scalar("c")))
        #expect(!result.contains(Unicode.Scalar("d")))
    }
    
    @Test func invertedEmptySetSymmetricDifference() {
        var universalSet = CharacterSet()
        universalSet.invert()
        
        let emptySet = CharacterSet()
        
        let result = universalSet.symmetricDifference(emptySet)
        
        validateUniversalSet(result)
        
        #expect(result.contains(Unicode.Scalar("a")))
        #expect(result.contains(Unicode.Scalar("z")))
        #expect(result.contains(Unicode.Scalar("1")))
        #expect(result.contains(Unicode.Scalar(0x10FFFF)!))
    }
    
    @Test func twoInvertedEmptySetsSymmetricDifference() {
        var firstUniversalSet = CharacterSet()
        firstUniversalSet.invert()
        
        var secondUniversalSet = CharacterSet()
        secondUniversalSet.invert()
        
        let result = firstUniversalSet.symmetricDifference(secondUniversalSet)
        
        validateEmptySet(result)
    }
    
    @Test func invertedSetWithNonEmptySymmetricDifference() {
        var universalSet = CharacterSet()
        universalSet.invert()
        
        let abcSet = CharacterSet(charactersIn: "abc")
        
        let result = universalSet.symmetricDifference(abcSet)
        
        #expect(!result.contains(Unicode.Scalar("a")))
        #expect(!result.contains(Unicode.Scalar("b")))
        #expect(!result.contains(Unicode.Scalar("c")))
        #expect(result.contains(Unicode.Scalar("d")))
        #expect(result.contains(Unicode.Scalar("z")))
        #expect(result.contains(Unicode.Scalar("1")))
    }
    
    @Test func nonBMPCharactersSymmetricDifference() {
        let grinningFace = Unicode.Scalar(0x1F600)! // 😀
        let grinningFaceWithSmilingEyes = Unicode.Scalar(0x1F601)! // 😁
        let faceWithTearsOfJoy = Unicode.Scalar(0x1F602)! // 😂
        let grinningFaceWithBigEyes = Unicode.Scalar(0x1F603)! // 😃
        
        var firstEmojiGroup = CharacterSet()
        firstEmojiGroup.insert(grinningFace)
        firstEmojiGroup.insert(grinningFaceWithSmilingEyes)
        
        var secondEmojiGroup = CharacterSet()
        secondEmojiGroup.insert(grinningFaceWithSmilingEyes)
        secondEmojiGroup.insert(faceWithTearsOfJoy)
        
        let result = firstEmojiGroup.symmetricDifference(secondEmojiGroup)
        
        #expect(result.contains(grinningFace))
        #expect(result.contains(faceWithTearsOfJoy))
        
        #expect(!result.contains(grinningFaceWithSmilingEyes))
        
        #expect(!result.contains(grinningFaceWithBigEyes))
    }
    
    @Test func formSymmetricDifferenceEmptySets() {
        var firstEmpty = CharacterSet()
        let secondEmpty = CharacterSet()
        
        firstEmpty.formSymmetricDifference(secondEmpty)
        
        validateEmptySet(firstEmpty)
    }
    
    @Test func formSymmetricDifferenceIdenticalSets() {
        var firstAbcSet = CharacterSet(charactersIn: "abc")
        let secondAbcSet = CharacterSet(charactersIn: "abc")
        
        firstAbcSet.formSymmetricDifference(secondAbcSet)
        
        validateEmptySet(firstAbcSet)
    }
    
    @Test func formSymmetricDifferencePreservesOriginalBehavior() {
        var mutableAbcdSet = CharacterSet(charactersIn: "abcd")
        let cdefSet = CharacterSet(charactersIn: "cdef")
        
        let expectedResult = mutableAbcdSet.symmetricDifference(cdefSet)
        mutableAbcdSet.formSymmetricDifference(cdefSet)
        
        #expect(mutableAbcdSet.contains(Unicode.Scalar("a")) == expectedResult.contains(Unicode.Scalar("a")))
        #expect(mutableAbcdSet.contains(Unicode.Scalar("b")) == expectedResult.contains(Unicode.Scalar("b")))
        #expect(mutableAbcdSet.contains(Unicode.Scalar("c")) == expectedResult.contains(Unicode.Scalar("c")))
        #expect(mutableAbcdSet.contains(Unicode.Scalar("d")) == expectedResult.contains(Unicode.Scalar("d")))
        #expect(mutableAbcdSet.contains(Unicode.Scalar("e")) == expectedResult.contains(Unicode.Scalar("e")))
        #expect(mutableAbcdSet.contains(Unicode.Scalar("f")) == expectedResult.contains(Unicode.Scalar("f")))
    }
    
    @Test func formSymmetricDifferenceNonBMPCharacters() {
        let grinningFace = Unicode.Scalar(0x1F600)! // 😀
        let grinningFaceWithSmilingEyes = Unicode.Scalar(0x1F601)! // 😁
        let faceWithTearsOfJoy = Unicode.Scalar(0x1F602)! // 😂
        
        var firstEmojiGroup = CharacterSet()
        firstEmojiGroup.insert(grinningFace)
        firstEmojiGroup.insert(grinningFaceWithSmilingEyes)
        
        var secondEmojiGroup = CharacterSet()
        secondEmojiGroup.insert(grinningFaceWithSmilingEyes)
        secondEmojiGroup.insert(faceWithTearsOfJoy)
        
        firstEmojiGroup.formSymmetricDifference(secondEmojiGroup)
        
        #expect(firstEmojiGroup.contains(grinningFace))
        #expect(!firstEmojiGroup.contains(grinningFaceWithSmilingEyes))
        #expect(firstEmojiGroup.contains(faceWithTearsOfJoy))
    }
    
    @Test func symmetricDifferenceWithDifferentStorageTypes() {
        let uppercaseRange = CharacterSet(charactersIn: Unicode.Scalar(65)!..<Unicode.Scalar(91)!)
        let xyzAndDigits = CharacterSet(charactersIn: "XYZ123")
        
        let result = uppercaseRange.symmetricDifference(xyzAndDigits)
        
        #expect(result.contains(Unicode.Scalar("A")))
        #expect(result.contains(Unicode.Scalar("W")))
        
        #expect(!result.contains(Unicode.Scalar("X")))
        #expect(!result.contains(Unicode.Scalar("Y")))
        #expect(!result.contains(Unicode.Scalar("Z")))
        
        #expect(result.contains(Unicode.Scalar("1")))
        #expect(result.contains(Unicode.Scalar("2")))
        #expect(result.contains(Unicode.Scalar("3")))
    }
    
    @Test func largeCharacterSetSymmetricDifference() {
        let zeroTo9999Range = CharacterSet(charactersIn: Unicode.Scalar(0)!..<Unicode.Scalar(10000)!)
        let fiveThousandTo14999Range = CharacterSet(charactersIn: Unicode.Scalar(5000)!..<Unicode.Scalar(15000)!)
        
        let result = zeroTo9999Range.symmetricDifference(fiveThousandTo14999Range)
        
        #expect(result.contains(Unicode.Scalar(0)!))
        #expect(result.contains(Unicode.Scalar(4999)!))
        #expect(!result.contains(Unicode.Scalar(5000)!))
        #expect(!result.contains(Unicode.Scalar(9999)!))
        #expect(result.contains(Unicode.Scalar(10000)!))
        #expect(result.contains(Unicode.Scalar(14999)!))
    }
    
    @Test func symmetricDifferenceMathematicalProperties() {
        let abcSet = CharacterSet(charactersIn: "abc")
        let bcdSet = CharacterSet(charactersIn: "bcd")
        let cdeSet = CharacterSet(charactersIn: "cde")
        
        let abcWithBcd = abcSet.symmetricDifference(bcdSet)
        let bcdWithAbc = bcdSet.symmetricDifference(abcSet)
        
        for scalar in ["a", "b", "c", "d", "e"].compactMap(Unicode.Scalar.init) {
            #expect(abcWithBcd.contains(scalar) == bcdWithAbc.contains(scalar))
        }
        
        var leftSide = abcSet.symmetricDifference(bcdSet)
        leftSide.formSymmetricDifference(cdeSet)
        
        let bcdWithCde = bcdSet.symmetricDifference(cdeSet)
        let rightSide = abcSet.symmetricDifference(bcdWithCde)
        
        for scalar in ["a", "b", "c", "d", "e"].compactMap(Unicode.Scalar.init) {
            #expect(leftSide.contains(scalar) == rightSide.contains(scalar))
        }
    }
    
    @Test func symmetricDifferenceWithOverlappingRanges() {
        var zeroTo999Range = CharacterSet(charactersIn: Unicode.Scalar(0)!..<Unicode.Scalar(1000)!)
        let fiveHundredTo1499Range = CharacterSet(charactersIn: Unicode.Scalar(500)!..<Unicode.Scalar(1500)!)
        
        let result = zeroTo999Range.symmetricDifference(fiveHundredTo1499Range)
        
        #expect(result.contains(Unicode.Scalar(0)!))
        #expect(result.contains(Unicode.Scalar(499)!))
        #expect(!result.contains(Unicode.Scalar(500)!))
        #expect(!result.contains(Unicode.Scalar(999)!))
        
        zeroTo999Range.formSymmetricDifference(fiveHundredTo1499Range)
        
        #expect(result.contains(Unicode.Scalar(0)!))
        #expect(result.contains(Unicode.Scalar(499)!))
        #expect(!result.contains(Unicode.Scalar(500)!))
        #expect(!result.contains(Unicode.Scalar(999)!))
    }
    
    @Test func mixedBMPAndNonBMPSymmetricDifference() {
        let regularChar = Unicode.Scalar("a")
        let emoji1 = Unicode.Scalar(0x1F600)! // 😀
        let emoji2 = Unicode.Scalar(0x1F601)! // 😁
        
        var regularCharAndEmoji = CharacterSet()
        regularCharAndEmoji.insert(regularChar)
        regularCharAndEmoji.insert(emoji1)
        
        var emojisOnly = CharacterSet()
        emojisOnly.insert(emoji1)
        emojisOnly.insert(emoji2)
        
        let result = regularCharAndEmoji.symmetricDifference(emojisOnly)
    
        #expect(result.contains(regularChar))
        #expect(!result.contains(emoji1))
        #expect(result.contains(emoji2))
    }
    
    @Test func symmetricDifferenceNonBMPRanges() {
        let grinningFace = Unicode.Scalar(0x1F600)!
        let smilingEyes = Unicode.Scalar(0x1F601)!
        let tearsOfJoy = Unicode.Scalar(0x1F602)!
        let bigEyes = Unicode.Scalar(0x1F603)!

        let first = CharacterSet(charactersIn: grinningFace...tearsOfJoy)
        let second = CharacterSet(charactersIn: smilingEyes...bigEyes)

        let result = first.symmetricDifference(second)

        #expect(result.contains(grinningFace))
        #expect(!result.contains(smilingEyes))
        #expect(!result.contains(tearsOfJoy))
        #expect(result.contains(bigEyes))
    }
}

@Suite("Character Set: Superset Tests", .tags(.characterSet))
private struct CharacterSetSupersetTests {
    
    @Test func emptySetNotSupersetOfNonEmpty() {
        let empty = CharacterSet()
        let nonEmpty = CharacterSet(charactersIn: "a")
        
        #expect(!empty.isSuperset(of: nonEmpty))
    }
    
    @Test func anySetIsSupersetOfEmpty() {
        let empty = CharacterSet()
        let abc = CharacterSet(charactersIn: "abc")
        let anotherEmpty = CharacterSet()
        
        #expect(abc.isSuperset(of: empty))
        #expect(anotherEmpty.isSuperset(of: empty))
    }
    
    @Test func identicalSetsAreSupersets() {
        let firstAbc = CharacterSet(charactersIn: "abc")
        let secondAbc = CharacterSet(charactersIn: "abc")
        
        #expect(firstAbc.isSuperset(of: secondAbc))
        #expect(secondAbc.isSuperset(of: firstAbc))
    }
    
    @Test func properSupersetRelationship() {
        let abcde = CharacterSet(charactersIn: "abcde")
        let abc = CharacterSet(charactersIn: "abc")
        
        #expect(abcde.isSuperset(of: abc))
        #expect(!abc.isSuperset(of: abcde))
    }
    
    @Test func disjointSetsNotSupersets() {
        let abc = CharacterSet(charactersIn: "abc")
        let xyz = CharacterSet(charactersIn: "xyz")
        
        #expect(!abc.isSuperset(of: xyz))
        #expect(!xyz.isSuperset(of: abc))
    }
    
    @Test func overlappingButNotSuperset() {
        let abcd = CharacterSet(charactersIn: "abcd")
        let cdef = CharacterSet(charactersIn: "cdef")
        
        #expect(!abcd.isSuperset(of: cdef))
        #expect(!cdef.isSuperset(of: abcd))
    }
    
    @Test func invertedEmptySetIsSupersetOfEverything() {
        var universalSet = CharacterSet()
        universalSet.invert()
        
        let empty = CharacterSet()
        let abc = CharacterSet(charactersIn: "abc")
        let largeRange = CharacterSet(charactersIn: Unicode.Scalar(0)!..<Unicode.Scalar(1000)!)
        
        #expect(universalSet.isSuperset(of: empty))
        #expect(universalSet.isSuperset(of: abc))
        #expect(universalSet.isSuperset(of: largeRange))
    }
    
    @Test func emptySetNotSupersetOfInvertedEmpty() {
        let empty = CharacterSet()
        var universalSet = CharacterSet()
        universalSet.invert()
        
        #expect(!empty.isSuperset(of: universalSet))
    }

    @Test func normalSetVsInvertedSet() {
        let abc = CharacterSet(charactersIn: "abc")
        var abcExcluded = CharacterSet(charactersIn: "abc")
        abcExcluded.invert()
        
        #expect(!abc.isSuperset(of: abcExcluded))
        #expect(!abcExcluded.isSuperset(of: abc))
    }
    
    @Test func builtInCharacterSetSuperset() {
        let alphanumerics = CharacterSet.alphanumerics
        let letters = CharacterSet.letters
        let decimalDigits = CharacterSet.decimalDigits
        let uppercaseLetters = CharacterSet.uppercaseLetters
        let lowercaseLetters = CharacterSet.lowercaseLetters
        
        #expect(alphanumerics.isSuperset(of: letters))
        #expect(alphanumerics.isSuperset(of: decimalDigits))
        
        #expect(letters.isSuperset(of: uppercaseLetters))
        #expect(letters.isSuperset(of: lowercaseLetters))
        
        #expect(!uppercaseLetters.isSuperset(of: lowercaseLetters))
        #expect(!lowercaseLetters.isSuperset(of: uppercaseLetters))
        #expect(!decimalDigits.isSuperset(of: letters))
    }
    
    @Test func rangeStorageSupersetTests() {
        let aToZ = CharacterSet(charactersIn: Unicode.Scalar(65)!..<Unicode.Scalar(91)!)
        let aToE = CharacterSet(charactersIn: Unicode.Scalar(65)!..<Unicode.Scalar(70)!)
        
        #expect(aToZ.isSuperset(of: aToE))
        #expect(!aToE.isSuperset(of: aToZ))
    }
    
    @Test func rangeStorageWithInvertedSets() {
        let aToZ = CharacterSet(charactersIn: Unicode.Scalar(65)!..<Unicode.Scalar(91)!)
        let fToOExcluded = CharacterSet(charactersIn: Unicode.Scalar(70)!..<Unicode.Scalar(80)!).inverted
        let aToEExcluded = CharacterSet(charactersIn: Unicode.Scalar(65)!..<Unicode.Scalar(70)!).inverted
        
        #expect(!aToZ.isSuperset(of: fToOExcluded))
        #expect(!aToZ.isSuperset(of: aToEExcluded))
    }
    
    @Test func mixedStorageTypesSuperset() {
        let uppercaseRange = CharacterSet(charactersIn: Unicode.Scalar(65)!..<Unicode.Scalar(91)!)
        let abcde = CharacterSet(charactersIn: "ABCDE")
        
        #expect(uppercaseRange.isSuperset(of: abcde))
        #expect(!abcde.isSuperset(of: uppercaseRange))
    }
    
    @Test func nonBMPCharacterSupersetBasic() {
        let grinningFace = Unicode.Scalar(0x1F600)! // 😀
        let grinningFaceWithSmilingEyes = Unicode.Scalar(0x1F601)! // 😁
        let faceWithTearsOfJoy = Unicode.Scalar(0x1F602)! // 😂
        
        var threeEmojis = CharacterSet()
        threeEmojis.insert(grinningFace)
        threeEmojis.insert(grinningFaceWithSmilingEyes)
        threeEmojis.insert(faceWithTearsOfJoy)
        
        var twoEmojis = CharacterSet()
        twoEmojis.insert(grinningFace)
        twoEmojis.insert(grinningFaceWithSmilingEyes)
        
        #expect(threeEmojis.isSuperset(of: twoEmojis))
        #expect(!twoEmojis.isSuperset(of: threeEmojis))
    }
    
    @Test func mixedBMPAndNonBMPSuperset() {
        let capitalA = Unicode.Scalar("A")
        let grinningFace = Unicode.Scalar(0x1F600)! // 😀
        let grinningFaceWithSmilingEyes = Unicode.Scalar(0x1F601)! // 😁
        
        var mixedCharacters = CharacterSet()
        mixedCharacters.insert(capitalA)
        mixedCharacters.insert(grinningFace)
        mixedCharacters.insert(grinningFaceWithSmilingEyes)
        
        #expect(mixedCharacters.contains(capitalA))
        #expect(mixedCharacters.contains(grinningFace))
        #expect(mixedCharacters.contains(grinningFaceWithSmilingEyes))

        var justCapitalA = CharacterSet()
        justCapitalA.insert(capitalA)
        
        #expect(justCapitalA.contains(capitalA))
        
        var justGrinningFace = CharacterSet()
        justGrinningFace.insert(grinningFace)
        
        #expect(justGrinningFace.contains(grinningFace))
        
        let mixedAndEmojiIntersection = mixedCharacters.intersection(justGrinningFace)
        #expect(!mixedAndEmojiIntersection.contains(capitalA))
        #expect(mixedAndEmojiIntersection.contains(grinningFace))
        #expect(!mixedAndEmojiIntersection.contains(grinningFaceWithSmilingEyes))
        
        #expect(mixedAndEmojiIntersection == justGrinningFace)
        
        #expect(mixedCharacters.isSuperset(of: justCapitalA))
        #expect(!justCapitalA.isSuperset(of: mixedCharacters))
        #expect(!justGrinningFace.isSuperset(of: mixedCharacters))
        #expect(mixedCharacters.isSuperset(of: justGrinningFace))
    }
    
    @Test func originalMixedBMPAndNonBMPSuperset() {
        let capitalA = Unicode.Scalar("A")
        let grinningFace = Unicode.Scalar(0x1F600)! // 😀
        let grinningFaceWithSmilingEyes = Unicode.Scalar(0x1F601)! // 😁
        
        var mixedCharacters = CharacterSet()
        mixedCharacters.insert(capitalA)
        mixedCharacters.insert(grinningFace)
        mixedCharacters.insert(grinningFaceWithSmilingEyes)
        
        #expect(mixedCharacters.contains(capitalA))
        #expect(mixedCharacters.contains(grinningFace))
        #expect(mixedCharacters.contains(grinningFaceWithSmilingEyes))

        var justCapitalA = CharacterSet()
        justCapitalA.insert(capitalA)
        
        #expect(justCapitalA.contains(capitalA))
        
        var justGrinningFace = CharacterSet()
        justGrinningFace.insert(grinningFace)
        
        #expect(justGrinningFace.contains(grinningFace))
        
        #expect(mixedCharacters.isSuperset(of: justCapitalA))
        #expect(mixedCharacters.isSuperset(of: justGrinningFace))
        #expect(!justCapitalA.isSuperset(of: mixedCharacters))
        #expect(!justGrinningFace.isSuperset(of: mixedCharacters))
    }
    
    @Test func nonBMPWithInvertedSets() {
        let grinningFace = Unicode.Scalar(0x1F600)! // 😀
        let grinningFaceWithSmilingEyes = Unicode.Scalar(0x1F601)! // 😁
        
        var twoEmojis = CharacterSet()
        twoEmojis.insert(grinningFace)
        twoEmojis.insert(grinningFaceWithSmilingEyes)
        
        let grinningFaceExcluded = CharacterSet(charactersIn: grinningFace...grinningFace).inverted
        
        #expect(!grinningFaceExcluded.isSuperset(of: twoEmojis))
        #expect(!twoEmojis.isSuperset(of: grinningFaceExcluded))
    }
    
    @Test func largeNonBMPRangeSuperset() {
        let wideEmojiRange = CharacterSet(charactersIn: Unicode.Scalar(0x1F600)!..<Unicode.Scalar(0x1F650)!)
        let narrowEmojiRange = CharacterSet(charactersIn: Unicode.Scalar(0x1F600)!..<Unicode.Scalar(0x1F610)!)
        
        #expect(wideEmojiRange.isSuperset(of: narrowEmojiRange))
        #expect(!narrowEmojiRange.isSuperset(of: wideEmojiRange))
    }
    
    @Test func multipleNonBMPPlanes() {
        let grinningFace = Unicode.Scalar(0x1F600)! // 😀
        let linearBSyllable = Unicode.Scalar(0x10000)! // Plane 1 (Linear B)
        let cjkExtensionB = Unicode.Scalar(0x20000)! // Plane 2 (CJK Extension B)
        
        var multiPlaneSet = CharacterSet()
        multiPlaneSet.insert(grinningFace)
        multiPlaneSet.insert(linearBSyllable)
        multiPlaneSet.insert(cjkExtensionB)
        
        var singlePlaneSet = CharacterSet()
        singlePlaneSet.insert(grinningFace)
        
        #expect(multiPlaneSet.isSuperset(of: singlePlaneSet))
        #expect(!singlePlaneSet.isSuperset(of: multiPlaneSet))
    }
    
    @Test func emptyAnnexVsInvertedAnnex() {
        let bmpOnly = CharacterSet(charactersIn: "abc")
        let grinningFace = Unicode.Scalar(0x1F600)! // 😀
        
        var justEmoji = CharacterSet()
        justEmoji.insert(grinningFace)
        
        #expect(!bmpOnly.isSuperset(of: justEmoji))
    }
    
    @Test func largeBitmapSupersetTest() {
        let largeRange = CharacterSet(charactersIn: Unicode.Scalar(0)!..<Unicode.Scalar(10000)!)
        let smallRange = CharacterSet(charactersIn: Unicode.Scalar(0)!..<Unicode.Scalar(5000)!)
        
        #expect(largeRange.isSuperset(of: smallRange))
        #expect(!smallRange.isSuperset(of: largeRange))
    }
    
    @Test func supersetTransitivity() {
        let abcdefghij = CharacterSet(charactersIn: "abcdefghij")
        let abcdef = CharacterSet(charactersIn: "abcdef")
        let abc = CharacterSet(charactersIn: "abc")
        
        #expect(abcdefghij.isSuperset(of: abcdef))
        #expect(abcdef.isSuperset(of: abc))
        #expect(abcdefghij.isSuperset(of: abc))
    }
    
    @Test func unionPropertyForSupersets() {
        let abcdef = CharacterSet(charactersIn: "abcdef")
        let abc = CharacterSet(charactersIn: "abc")
        
        #expect(abcdef.isSuperset(of: abc))
        
        let union = abcdef.union(abc)
        
        #expect(abcdef.isSuperset(of: union))
        #expect(union.isSuperset(of: abcdef))
    }
    
    @Test func invertedSetsSupersetRelationships() {
        var abcExcluded = CharacterSet()
        abcExcluded.insert(charactersIn: "abc")
        abcExcluded.invert()
        
        var abExcluded = CharacterSet()
        abExcluded.insert(charactersIn: "ab")
        abExcluded.invert()
        
        #expect(abExcluded.isSuperset(of: abcExcluded))
        #expect(!abcExcluded.isSuperset(of: abExcluded))
    }
    
    @Test func complexMixedScenario() {
        var complexSet = CharacterSet()
        complexSet.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ") // Letters
        complexSet.insert(charactersIn: "0123456789") // Numbers
        complexSet.insert(charactersIn: Unicode.Scalar(0x1F600)!..<Unicode.Scalar(0x1F610)!) // Emojis
        
        var letterSubset = CharacterSet()
        letterSubset.insert(charactersIn: "ABC")
        
        var numberSubset = CharacterSet()
        numberSubset.insert(charactersIn: "123")
        
        var emojiSubset = CharacterSet()
        emojiSubset.insert(Unicode.Scalar(0x1F600)!)
        
        var combinedSubset = CharacterSet()
        combinedSubset.insert(charactersIn: "AB")
        combinedSubset.insert(charactersIn: "12")
        combinedSubset.insert(Unicode.Scalar(0x1F600)!)
        
        let intersection = complexSet.intersection(emojiSubset)
    
        #expect(intersection == emojiSubset)
        
        #expect(!letterSubset.isSuperset(of: complexSet))
        #expect(!numberSubset.isSuperset(of: complexSet))
        #expect(!emojiSubset.isSuperset(of: complexSet))
        
        #expect(complexSet.isSuperset(of: letterSubset))
        #expect(complexSet.isSuperset(of: numberSubset))
        #expect(complexSet.isSuperset(of: combinedSubset))
        #expect(complexSet.isSuperset(of: emojiSubset))
    }

    @Test func isSupersetInvertedRangeTouchingBoundaryBMP() {
        let everythingExceptD = CharacterSet(charactersIn: UnicodeScalar(0x0044)!...UnicodeScalar(0x0044)!).inverted
        let dToF = CharacterSet(charactersIn: UnicodeScalar(0x0044)!...UnicodeScalar(0x0046)!)

        #expect(!everythingExceptD.isSuperset(of: dToF))
    }

    @Test func isSupersetInvertedRangeTouchingBoundaryNonBMP() {
        let grinningFace = Unicode.Scalar(0x1F600)!
        let grinningFaceWithSmilingEyes = Unicode.Scalar(0x1F601)!

        let grinningExcluded = CharacterSet(charactersIn: grinningFace...grinningFace).inverted
        let twoEmojis = CharacterSet(charactersIn: grinningFace...grinningFaceWithSmilingEyes)

        #expect(!grinningExcluded.isSuperset(of: twoEmojis))
    }

    @Test func isSupersetInvertedRangeNonOverlapping() {
        let everythingExceptAToC = CharacterSet(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0043)!).inverted
        let eToG = CharacterSet(charactersIn: UnicodeScalar(0x0045)!...UnicodeScalar(0x0047)!)

        #expect(everythingExceptAToC.isSuperset(of: eToG))
    }

    @Test func isSupersetInvertedRangeAdjacentBMP() {
        let everythingExceptAToC = CharacterSet(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0043)!).inverted
        let dToF = CharacterSet(charactersIn: UnicodeScalar(0x0044)!...UnicodeScalar(0x0046)!)

        #expect(everythingExceptAToC.isSuperset(of: dToF))
    }

    @Test func isSupersetInvertedRangeAdjacentNonBMP() {
        let grinningFace = Unicode.Scalar(0x1F600)!
        let grinningFaceWithSmilingEyes = Unicode.Scalar(0x1F601)!

        let grinningExcluded = CharacterSet(charactersIn: grinningFace...grinningFace).inverted
        let justSmilingEyes = CharacterSet(charactersIn: grinningFaceWithSmilingEyes...grinningFaceWithSmilingEyes)

        #expect(grinningExcluded.isSuperset(of: justSmilingEyes))
    }

    @Test func intersectionNonBMPRangeWithNonBMPRange() {
        let grinningFace = Unicode.Scalar(0x1F600)!
        let smilingEyes = Unicode.Scalar(0x1F601)!
        let tearsOfJoy = Unicode.Scalar(0x1F602)!
        let bigEyes = Unicode.Scalar(0x1F603)!

        let first = CharacterSet(charactersIn: grinningFace...tearsOfJoy)
        let second = CharacterSet(charactersIn: smilingEyes...bigEyes)

        let result = first.intersection(second)

        #expect(!result.contains(grinningFace))
        #expect(result.contains(smilingEyes))
        #expect(result.contains(tearsOfJoy))
        #expect(!result.contains(bigEyes))
    }

    @Test func rangeSupersetOfBitmapAndString() {
        let aToZ = CharacterSet(charactersIn: "a"..."z")
        let subset = CharacterSet(charactersIn: "amz")
        let notSubset = CharacterSet(charactersIn: "aZ0")

        #expect(aToZ.isSuperset(of: subset))
        #expect(!aToZ.isSuperset(of: notSubset))
        #expect(!subset.isSuperset(of: aToZ))
    }

    @Test func builtinSupersetOfStringOperand() {
        let letters = CharacterSet.letters
        let someLetters = CharacterSet(charactersIn: "abcXYZ")
        let lettersPlusDigit = CharacterSet(charactersIn: "abc5")

        #expect(letters.isSuperset(of: someLetters))
        #expect(!letters.isSuperset(of: lettersPlusDigit))
    }

    @Test func supersetAcrossNonBMPPlanes() {
        let grinning = Unicode.Scalar(0x1F600)!
        let joy = Unicode.Scalar(0x1F602)!
        let cjkExtB = Unicode.Scalar(0x20000)!

        var big = CharacterSet(charactersIn: "abc")
        big.insert(grinning)
        big.insert(joy)
        big.insert(cjkExtB)

        var small = CharacterSet(charactersIn: "ab")
        small.insert(grinning)

        #expect(big.isSuperset(of: small))
        #expect(!small.isSuperset(of: big))

        var missingNonBMP = CharacterSet(charactersIn: "abc")
        missingNonBMP.insert(grinning)
        #expect(!missingNonBMP.isSuperset(of: big))
        #expect(big.isSuperset(of: missingNonBMP))
    }

    @Test func universalSetIsSupersetIncludingNonBMP() {
        let universal = CharacterSet(charactersIn: Unicode.Scalar(0)!...Unicode.Scalar(0x10FFFF)!)
        var withNonBMP = CharacterSet(charactersIn: "abc")
        withNonBMP.insert(Unicode.Scalar(0x1F600)!)

        #expect(universal.isSuperset(of: withNonBMP))
        #expect(universal.isSuperset(of: CharacterSet.letters))
        #expect(!withNonBMP.isSuperset(of: universal))
    }

    @Test func invertedRangeSuperset() {
        let notGtoO = CharacterSet(charactersIn: "g"..."o").inverted
        let avoidsHole = CharacterSet(charactersIn: "abcXYZ")
        let insideHole = CharacterSet(charactersIn: "hi")

        #expect(notGtoO.isSuperset(of: avoidsHole))
        #expect(!notGtoO.isSuperset(of: insideHole))
    }

    private func compactBacked(_ set: CharacterSet) -> CharacterSet {
        CharacterSet(bitmapRepresentation: set.bitmapRepresentation)
    }

    @Test func builtinReflexiveSuperset() {
        let builtins: [CharacterSet] = [.letters, .decimalDigits, .whitespaces,
                                        .uppercaseLetters, .lowercaseLetters, .alphanumerics]
        for set in builtins {
            #expect(set.isSuperset(of: set))
        }
    }

    @Test func compactBitmapSparseDataPageSuperset() {
        let other = compactBacked(CharacterSet(charactersIn: "aeiou"))
        let covers = CharacterSet(charactersIn: "a"..."z")
        let missesU = CharacterSet(charactersIn: "aeio")

        #expect(covers.isSuperset(of: other))
        #expect(!missesU.isSuperset(of: other))
        #expect(other.isSuperset(of: other))
    }

    @Test func compactBitmapFullPageSuperset() {
        let other = compactBacked(CharacterSet(charactersIn: Unicode.Scalar(0)!...Unicode.Scalar(0x0FFF)!))
        let covers = CharacterSet(charactersIn: Unicode.Scalar(0)!...Unicode.Scalar(0x1FFF)!)
        let missesLast = CharacterSet(charactersIn: Unicode.Scalar(0)!...Unicode.Scalar(0x0FFE)!)

        #expect(covers.isSuperset(of: other))
        #expect(!missesLast.isSuperset(of: other))
    }

    @Test func compactBitmapNonBMPSparseSuperset() {
        var base = CharacterSet(charactersIn: "abc")
        base.insert(Unicode.Scalar(0x1F600)!)   // 😀 plane 1
        base.insert(Unicode.Scalar(0x1F602)!)   // 😂 plane 1
        let other = compactBacked(base)

        var covers = CharacterSet(charactersIn: "a"..."z")
        covers.insert(Unicode.Scalar(0x1F600)!)
        covers.insert(Unicode.Scalar(0x1F602)!)

        var missesOneEmoji = CharacterSet(charactersIn: "abc")
        missesOneEmoji.insert(Unicode.Scalar(0x1F600)!)   // missing 0x1F602

        #expect(covers.isSuperset(of: other))
        #expect(!missesOneEmoji.isSuperset(of: other))
    }

    @Test func supersetMatchesMembershipOracle() {
        var emojiPlusABC = CharacterSet(charactersIn: "abc")
        emojiPlusABC.insert(Unicode.Scalar(0x1F600)!)
        
        let base: [CharacterSet] = [
            CharacterSet(charactersIn: "aeiou"),
            CharacterSet(charactersIn: "a"..."z"),
            CharacterSet(bitmapRepresentation: CharacterSet(charactersIn: "hello world 123").bitmapRepresentation),
            CharacterSet(bitmapRepresentation: CharacterSet(charactersIn: Unicode.Scalar(0x100)!...Unicode.Scalar(0x2FF)!).bitmapRepresentation),
            emojiPlusABC,
            CharacterSet(charactersIn: Unicode.Scalar(0x1F600)!...Unicode.Scalar(0x1F610)!),
            CharacterSet.whitespaces,
        ]
        
        let samples = base + base.map { $0.inverted }

        let beyondDomain = Unicode.Scalar(0x100000)!
        for a in samples {
            for b in samples {
                var everyMemberOfBIsInA = true
                if b.contains(beyondDomain) && !a.contains(beyondDomain) {
                    everyMemberOfBIsInA = false
                } else {
                    for value in UInt32(0)...0x1FFFF {
                        guard let scalar = Unicode.Scalar(value) else { continue }
                        if b.contains(scalar) && !a.contains(scalar) {
                            everyMemberOfBIsInA = false
                            break
                        }
                    }
                }
                #expect(a.isSuperset(of: b) == everyMemberOfBIsInA)
            }
        }
    }
    
    @Test func invertedSupersetSynthesisPaths() {
        let notDtoG = CharacterSet(charactersIn: "d"..."g").inverted
        let notCtoH = CharacterSet(charactersIn: "c"..."h").inverted
        #expect(notDtoG.isSuperset(of: notCtoH))
        #expect(!notCtoH.isSuperset(of: notDtoG))

        let emojis = CharacterSet(charactersIn: Unicode.Scalar(0x1F600)!...Unicode.Scalar(0x1F601)!)
        
        #expect(CharacterSet.whitespaces.inverted.isSuperset(of: emojis))

        let notPlane1Block = CharacterSet(charactersIn: Unicode.Scalar(0x1F000)!...Unicode.Scalar(0x1F0FF)!).inverted
        #expect(notPlane1Block.isSuperset(of: emojis))
        let insideBlock = CharacterSet(charactersIn: Unicode.Scalar(0x1F050)!...Unicode.Scalar(0x1F051)!)
        #expect(!notPlane1Block.isSuperset(of: insideBlock))

        var holed = CharacterSet(charactersIn: "abc")
        holed.insert(Unicode.Scalar(0x1F600)!)
        let invHoled = holed.inverted
        let otherEmojis = CharacterSet(charactersIn: Unicode.Scalar(0x1F602)!...Unicode.Scalar(0x1F603)!)
        #expect(invHoled.isSuperset(of: otherEmojis))
        #expect(!invHoled.isSuperset(of: emojis))
    }

    @Test func annexInversionFlagHandling() {
        let grinningFace = Unicode.Scalar(0x1F600)! // 😀
        
        var firstEmojiSet = CharacterSet()
        firstEmojiSet.insert(grinningFace)
        
        var secondEmojiSet = CharacterSet()
        secondEmojiSet.insert(grinningFace)
        
        #expect(firstEmojiSet.isSuperset(of: secondEmojiSet))
        #expect(secondEmojiSet.isSuperset(of: firstEmojiSet))
        
        firstEmojiSet.invert()
        #expect(!firstEmojiSet.isSuperset(of: secondEmojiSet))
        #expect(!secondEmojiSet.isSuperset(of: firstEmojiSet))
    }
    
    @Test func supersetReflexivity() {
        let abc = CharacterSet(charactersIn: "abc")
        let empty = CharacterSet()
        let xyzExcluded = CharacterSet(charactersIn: "xyz").inverted
        
        #expect(abc.isSuperset(of: abc))
        #expect(empty.isSuperset(of: empty))
        #expect(xyzExcluded.isSuperset(of: xyzExcluded))
    }
    
    @Test func compactBitmapInvertedAnnexPlaneSuperset() {
        let emoji0 = Unicode.Scalar(0x1F600)!   // 😀 plane 1
        let emoji1 = Unicode.Scalar(0x1F601)!   // 😁 plane 1

        var otherBase = CharacterSet()
        otherBase.insert(emoji0)
        otherBase.insert(emoji1)
        let other = compactBacked(otherBase).inverted

        var selfBase = CharacterSet()
        selfBase.insert(emoji0)
        let selfSet = compactBacked(selfBase).inverted

        #expect(selfSet.isSuperset(of: other))
    }

    @Test func compactBitmapInvertedAnnexPlaneNotSuperset() {
        let emoji0 = Unicode.Scalar(0x1F600)!
        let emoji1 = Unicode.Scalar(0x1F601)!

        var selfBase = CharacterSet()
        selfBase.insert(emoji0)
        selfBase.insert(emoji1)
        let selfSet = compactBacked(selfBase).inverted

        var otherBase = CharacterSet()
        otherBase.insert(emoji1)
        let other = compactBacked(otherBase).inverted

        #expect(other.contains(emoji0))
        #expect(!selfSet.contains(emoji0))
        #expect(!selfSet.isSuperset(of: other))
    }

    @Test func supersetOfBuiltInAcrossHighNonBMPPlanes() {
        let probes = [0xE0001, 0xE0020, 0xE00FF, 0xF0000, 0xFFFFD, 0x100000, 0x10FFFD]
            .map { Unicode.Scalar(UInt32($0))! }
        let builtIns: [CharacterSet] = [.illegalCharacters, .controlCharacters]

        for builtIn in builtIns {
            for candidate in [builtIn, builtIn.inverted] {
                for probe in probes {
                    let singleton = CharacterSet(charactersIn: probe...probe)
                    #expect(candidate.isSuperset(of: singleton) == candidate.contains(probe))
                }
            }
        }
    }
    
    @Test func rangeUnionedWithNonBMPStringKeepsBothMemberships() {
        var set = CharacterSet(charactersIn: Unicode.Scalar(0x10000)!...Unicode.Scalar(0x10010)!)
        set.formUnion(CharacterSet(charactersIn: "\u{1F600}"))

        for probe in [0x10005, 0x1F600].map({ Unicode.Scalar(UInt32($0))! }) {
            #expect(set.contains(probe))
            #expect(set.isSuperset(of: CharacterSet(charactersIn: probe...probe)))
        }
    }

    @Test func builtInUnionedWithNonBMPStringKeepsBothMemberships() {
        var set = CharacterSet.letters
        set.formUnion(CharacterSet(charactersIn: "\u{1F600}"))

        #expect(set.contains(Unicode.Scalar(0x1D400)!))  // MATHEMATICAL BOLD CAPITAL A
        #expect(set.contains(Unicode.Scalar(0x1F600)!))
        #expect(set.contains(UnicodeScalar("a")))
    }

    @Test func supersetOfMultiPlaneRangeMatchesMembership() {
        let range = CharacterSet(charactersIn: Unicode.Scalar(0x1FFF0)!...Unicode.Scalar(0x30010)!)
        let probes = [0x1FFEF, 0x1FFF0, 0x1FFFF, 0x20000, 0x25000, 0x2FFFF, 0x30010, 0x30011]
            .map { Unicode.Scalar(UInt32($0))! }

        for candidate in [range, range.inverted] {
            for probe in probes {
                let singleton = CharacterSet(charactersIn: String(Character(probe)))
                #expect(candidate.isSuperset(of: singleton) == candidate.contains(probe))
            }
        }
    }
}

@Suite("Character Set: Annex Inversion Tests", .tags(.characterSet))
private struct CharacterSetAnnexInversionTests {

    private let emoji = Unicode.Scalar(0x1F600)!
    private let plane2 = Unicode.Scalar(0x20000)!
    private let plane3 = Unicode.Scalar(0x30000)!
    private let maxScalar = Unicode.Scalar(0x10FFFF)!

    private func universalSet() -> CharacterSet {
        var set = CharacterSet()
        set.invert()
        return set
    }

    @Test func subtractingEmptyFromUniversalStaysUniversal() {
        var result = universalSet()
        result.subtract(CharacterSet())

        validateUniversalSet(result)
        #expect(result.contains("a"))
        #expect(result.contains(maxScalar))
    }

    @Test func invertedBMPOnlyRangeContainsAllNonBMP() {
        let set = CharacterSet(charactersIn: "a"..."z").inverted

        #expect(!set.contains("a"))
        #expect(!set.contains("z"))
        #expect(set.contains("A"))
        #expect(set.contains(emoji))
        #expect(set.contains(maxScalar))
        #expect(set.hasMember(inPlane: 2))
        #expect(!set.isEmpty)
    }

    @Test func invertedStringSetContainsAllNonBMP() {
        let set = CharacterSet(charactersIn: "abc").inverted

        #expect(!set.contains("a"))
        #expect(set.contains("d"))
        #expect(set.contains(emoji))
        #expect(set.contains(maxScalar))
        #expect(!set.isEmpty)
    }

    @Test func doubleInversionRestoresOriginal() {
        var set = CharacterSet()
        set.insert(charactersIn: "a"..."f")
        set.insert(emoji)

        let original = set
        set.invert()
        set.invert()

        #expect(set == original)
        #expect(set.contains("a"))
        #expect(set.contains(emoji))
        #expect(!set.contains("z"))
        #expect(!set.contains(plane2))
    }

    @Test func invertedSetWithNonBMPPlaneExcludesOnlyThatPlane() {
        var set = CharacterSet()
        set.insert(emoji)
        let inverted = set.inverted

        #expect(!inverted.contains(emoji))
        #expect(inverted.contains(plane2))
        #expect(inverted.contains("a"))
        #expect(inverted.contains(maxScalar))
    }

    @Test func universalSetBitmapRoundTrips() {
        let restored = CharacterSet(bitmapRepresentation: universalSet().bitmapRepresentation)

        validateUniversalSet(restored)
        #expect(restored.contains("a"))
        #expect(restored.contains(emoji))
        #expect(restored.contains(maxScalar))
    }

    @Test func invertedRangeBitmapRoundTrips() {
        let source = CharacterSet(charactersIn: "a"..."z").inverted
        let restored = CharacterSet(bitmapRepresentation: source.bitmapRepresentation)

        #expect(!restored.contains("a"))
        #expect(restored.contains("A"))
        #expect(restored.contains(emoji))
        #expect(restored.contains(maxScalar))
    }

    @Test func copyOfAnnexedSetIsIndependent() {
        var original = CharacterSet()
        original.insert(emoji)
        original.insert(plane2)

        var copied = original
        copied.insert(plane3)
        copied.remove(emoji)

        #expect(original.contains(emoji))
        #expect(original.contains(plane2))
        #expect(!original.contains(plane3))

        #expect(!copied.contains(emoji))
        #expect(copied.contains(plane2))
        #expect(copied.contains(plane3))
    }
}

private let storageMatrixProbes: [Unicode.Scalar] = [
    " ", "5", "a", "\u{0150}",
    "\u{10005}", "\u{1D400}", "\u{1F600}", "\u{1F601}",
    "\u{20000}", "\u{10FFFF}",
]

private struct StorageMatrixFixture: CustomTestStringConvertible {
    let name: String
    let set: CharacterSet
    let containedProbes: Set<Unicode.Scalar>

    var testDescription: String { name }
}

private let storageMatrixFixtures: [StorageMatrixFixture] = {
    var bitmapWithPlane1 = bitmapBackedSet(everyNthScalar: 3)
    bitmapWithPlane1.insert("\u{1F601}")

    var compactSource = CharacterSet(charactersIn: Unicode.Scalar(0x100)!...Unicode.Scalar(0x2FF)!)
    compactSource.insert("\u{20000}")
    let compactWithPlane2 = CharacterSet(bitmapRepresentation: compactSource.bitmapRepresentation)

    let nonEmpty = [
        StorageMatrixFixture(name: "BMP range a...z", set: CharacterSet(charactersIn: UnicodeScalar("a")...UnicodeScalar("z")), containedProbes: ["a"]),
        StorageMatrixFixture(name: "range U+10000...U+10010", set: CharacterSet(charactersIn: Unicode.Scalar(0x10000)!...Unicode.Scalar(0x10010)!), containedProbes: ["\u{10005}"]),
        StorageMatrixFixture(name: "range U+1F000...U+2FFFF", set: CharacterSet(charactersIn: Unicode.Scalar(0x1F000)!...Unicode.Scalar(0x2FFFF)!), containedProbes: ["\u{1F600}", "\u{1F601}", "\u{20000}"]),
        StorageMatrixFixture(name: "letters", set: .letters, containedProbes: ["a", "\u{0150}", "\u{10005}", "\u{1D400}", "\u{20000}"]),
        StorageMatrixFixture(name: "string 😀", set: CharacterSet(charactersIn: "\u{1F600}"), containedProbes: ["\u{1F600}"]),
        StorageMatrixFixture(name: "string a😀", set: CharacterSet(charactersIn: "a\u{1F600}"), containedProbes: ["a", "\u{1F600}"]),
        StorageMatrixFixture(name: "bitmap + plane 1", set: bitmapWithPlane1, containedProbes: ["\u{0150}", "\u{1F601}"]),
        StorageMatrixFixture(name: "compact + plane 2", set: compactWithPlane2, containedProbes: ["\u{0150}", "\u{20000}"]),
    ]
    let inverses = nonEmpty.map {
        StorageMatrixFixture(name: "¬(\($0.name))", set: $0.set.inverted, containedProbes: Set(storageMatrixProbes).subtracting($0.containedProbes))
    }
    let empty = StorageMatrixFixture(name: "empty", set: CharacterSet(), containedProbes: [])
    let universal = StorageMatrixFixture(name: "universal", set: CharacterSet().inverted, containedProbes: Set(storageMatrixProbes))

    return [empty] + nonEmpty + [universal] + inverses
}()

@Suite("Character Set: Set Algebra Across Storage Kinds", .tags(.characterSet))
private struct CharacterSetStorageMatrixTests {

    @Test(arguments: storageMatrixFixtures)
    func singleFixtureIsConsistent(_ a: StorageMatrixFixture) {
        #expect(Set(storageMatrixProbes.filter { a.set.contains($0) }) == a.containedProbes)
        #expect(a.set.union(a.set) == a.set)
        #expect(a.set.intersection(a.set) == a.set)
    }

    @Test(arguments: storageMatrixFixtures, storageMatrixFixtures)
    func unionAndIntersectionAreCorrect(_ a: StorageMatrixFixture, _ b: StorageMatrixFixture) {
        let union = a.set.union(b.set)
        let intersection = a.set.intersection(b.set)

        #expect(Set(storageMatrixProbes.filter { union.contains($0) }) == a.containedProbes.union(b.containedProbes))
        #expect(Set(storageMatrixProbes.filter { intersection.contains($0) }) == a.containedProbes.intersection(b.containedProbes))
        #expect(union == b.set.union(a.set))
        #expect(intersection == b.set.intersection(a.set))
        #expect(union.intersection(a.set) == a.set)
        #expect(intersection.union(a.set) == a.set)
    }
}
