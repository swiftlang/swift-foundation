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

@Suite("Character Set: Range-Based Manipulation Tests", .tags(.characterSet))
private struct CharacterSetRangeBasedManipulationTests {
    
    @Test func initializeWithEmptyRange() {
        let characterSet = CharacterSet(charactersIn: UnicodeScalar(0x0041)!..<UnicodeScalar(0x0041)!)
        
        #expect(!characterSet.contains(UnicodeScalar(0x0041)!))
        
        validateEmptySet(characterSet)
    }
    
    @Test func initializeWithOpenRange() {
        let characterSet = CharacterSet(charactersIn: UnicodeScalar(0x0041)!..<UnicodeScalar(0x0043)!)
        
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0043)!))
    }
    
    @Test func initializeWithClosedRange() {
        let characterSet = CharacterSet(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0043)!)
        
        #expect(!characterSet.contains(UnicodeScalar(0x0040)!))
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(characterSet.contains(UnicodeScalar(0x0043)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0044)!))
    }
    
    @Test func insertExistingRange() {
        var universalSet = CharacterSet()
        universalSet.invert()
        
        #expect(universalSet.contains(UnicodeScalar(0x0041)!))
        #expect(universalSet.contains(UnicodeScalar(0x005A)!))
        
        let range = UnicodeScalar(0x0041)!..<UnicodeScalar(0x0043)!
        
        universalSet.insert(charactersIn: range)
        
        #expect(universalSet.contains(UnicodeScalar(0x0041)!))
        #expect(universalSet.contains(UnicodeScalar(0x005A)!))
    }
    
    @Test func insertRangesWithIdenticalLowerBound() {
        var characterSet = CharacterSet()
        characterSet.insert(charactersIn: UnicodeScalar(0x0041)!..<UnicodeScalar(0x0044)!)
        
        characterSet.insert(charactersIn: UnicodeScalar(0x0041)!..<UnicodeScalar(0x0046)!)
        
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(characterSet.contains(UnicodeScalar(0x0045)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0046)!))
    }
    
    @Test func insertRangeToStringBackedSet() {
        var stringSet = CharacterSet(charactersIn: "ABC")
        stringSet.insert(charactersIn: UnicodeScalar(0x0044)!..<UnicodeScalar(0x0046)!)
        
        #expect(stringSet.contains(UnicodeScalar(0x0041)!))
        #expect(stringSet.contains(UnicodeScalar(0x0044)!))
        #expect(stringSet.contains(UnicodeScalar(0x0045)!))
    }
    
    @Test func insertBMPBoundaryRange() {
        var characterSet = CharacterSet()
        let range = UnicodeScalar(0xFFFE)!..<UnicodeScalar(0x10001)!
        
        characterSet.insert(charactersIn: range)
        
        #expect(!characterSet.contains(UnicodeScalar(0xFFFD)!))
        #expect(characterSet.contains(UnicodeScalar(0xFFFE)!))
        #expect(characterSet.contains(UnicodeScalar(0xFFFF)!))
        #expect(characterSet.contains(UnicodeScalar(0x10000)!))
        #expect(!characterSet.contains(UnicodeScalar(0x10001)!))
    }
    
    @Test func insertNonBMPRange() {
        var characterSet = CharacterSet()
        let nonBMPRange = UnicodeScalar(0x20000)!..<UnicodeScalar(0x20010)!
        
        characterSet.insert(charactersIn: nonBMPRange)
        
        #expect(!characterSet.hasMember(inPlane: 0))
        #expect(!characterSet.hasMember(inPlane: 1))
        #expect(characterSet.hasMember(inPlane: 2))
        #expect(!characterSet.hasMember(inPlane: 3))
    }
    
    @Test func insertClosedRangeMaximum() {
        var characterSet = CharacterSet()
        let maxRange = UnicodeScalar(0x10FFFE)!...UnicodeScalar(0x10FFFF)!

        characterSet.insert(charactersIn: maxRange)

        #expect(!characterSet.contains(UnicodeScalar(0x10FFFD)!))
        #expect(characterSet.contains(UnicodeScalar(0x10FFFE)!))
        #expect(characterSet.contains(UnicodeScalar(0x10FFFF)!))
    }
    
    @Test func removeRangeFromEmptySet() {
        var emptySet = CharacterSet()
        let range = UnicodeScalar(0x0041)!..<UnicodeScalar(0x0043)!
        
        #expect(!emptySet.contains(UnicodeScalar(0x0041)!))

        emptySet.remove(charactersIn: range)
        
        #expect(!emptySet.contains(UnicodeScalar(0x0041)!))
    }
    
    @Test func removeRangeFromUniversalSet() {
        var universalSet = CharacterSet()
        universalSet.invert()
        
        validateUniversalSet(universalSet)
        
        let range = UnicodeScalar(0x0041)!..<UnicodeScalar(0x0043)!
        universalSet.remove(charactersIn: range)
        
        #expect(!universalSet.contains(UnicodeScalar(0x0041)!))
        #expect(!universalSet.contains(UnicodeScalar(0x0042)!))
        #expect(universalSet.contains(UnicodeScalar(0x0043)!))
        #expect(universalSet.contains(UnicodeScalar(0x0044)!))
    }
    
    @Test func insertOpenRangeThenRemoveSubrange() {
        var characterSet = CharacterSet()
        characterSet.insert(charactersIn: UnicodeScalar(0x0041)!..<UnicodeScalar(0x0046)!)
        characterSet.remove(charactersIn: UnicodeScalar(0x0042)!..<UnicodeScalar(0x0044)!)
        
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0043)!))
        #expect(characterSet.contains(UnicodeScalar(0x0044)!))
        #expect(characterSet.contains(UnicodeScalar(0x0045)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0046)!))
    }
    
    @Test func insertBMPThenRemoveBMP() {
        var characterSet = CharacterSet()
        characterSet.insert(charactersIn: UnicodeScalar(0x0000)!..<UnicodeScalar(0x10000)!)
        characterSet.remove(charactersIn: UnicodeScalar(0x0000)!..<UnicodeScalar(0x10000)!)
        
        validateEmptySet(characterSet)
        #expect(!characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(!characterSet.contains(UnicodeScalar(0xFFFF)!))
    }
    
    @Test func insertClosedRangeThenRemoveSubrange() {
        var characterSet = CharacterSet()
        characterSet.insert(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0045)!)
        characterSet.remove(charactersIn: UnicodeScalar(0x0042)!...UnicodeScalar(0x0044)!)
        
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0043)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0044)!))
        #expect(characterSet.contains(UnicodeScalar(0x0045)!))
    }
    
    @Test func insertNonOverlappingRanges() {
        var characterSet = CharacterSet()
        
        characterSet.insert(charactersIn: UnicodeScalar(0x0041)!..<UnicodeScalar(0x0043)!)
        characterSet.insert(charactersIn: UnicodeScalar(0x0045)!..<UnicodeScalar(0x0047)!)
        
        #expect(characterSet.contains(UnicodeScalar(0x0041)!))
        #expect(characterSet.contains(UnicodeScalar(0x0042)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0043)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0044)!))
        #expect(characterSet.contains(UnicodeScalar(0x0045)!))
        #expect(characterSet.contains(UnicodeScalar(0x0046)!))
        #expect(!characterSet.contains(UnicodeScalar(0x0047)!))
    }
    
    @Test func compareRangeBasedSetWithBitmapBasedSet() {
        let rangeBasedSet = CharacterSet(charactersIn: UnicodeScalar(0x1F600)!..<UnicodeScalar(0x1F603)!)
        
        var bitmapBasedSet = CharacterSet()
        bitmapBasedSet.insert(UnicodeScalar(0x1F600)!)
        bitmapBasedSet.insert(UnicodeScalar(0x1F601)!)
        bitmapBasedSet.insert(UnicodeScalar(0x1F602)!)
        
        for scalar in 0x1F600..<0x1F603 {
            #expect(rangeBasedSet.contains(UnicodeScalar(scalar)!))
            #expect(bitmapBasedSet.contains(UnicodeScalar(scalar)!))
        }
        
        #expect(rangeBasedSet == bitmapBasedSet)
    }
    
    @Test func compareRangeBasedSetWithStringBasedSet() {
        let rangeBasedSet = CharacterSet(charactersIn: UnicodeScalar("A")..<UnicodeScalar("D"))
        
        let stringBasedSet = CharacterSet(charactersIn: "ABC")
  
        #expect(rangeBasedSet.contains(UnicodeScalar("A")))
        #expect(stringBasedSet.contains(UnicodeScalar("A")))
        
        #expect(rangeBasedSet.contains(UnicodeScalar("B")))
        #expect(stringBasedSet.contains(UnicodeScalar("B")))
        
        #expect(rangeBasedSet.contains(UnicodeScalar("C")))
        #expect(stringBasedSet.contains(UnicodeScalar("C")))
    
        #expect(rangeBasedSet == stringBasedSet)
    }
    
    @Test func insertThenRemoveNonBMPRange() {
        var characterSet = CharacterSet()
        characterSet.insert(charactersIn: UnicodeScalar(0x20000)!..<UnicodeScalar(0x20010)!)
        #expect(characterSet.hasMember(inPlane: 2))

        characterSet.remove(charactersIn: UnicodeScalar(0x20000)!..<UnicodeScalar(0x20010)!)
        #expect(!characterSet.hasMember(inPlane: 2))
    }
    
    @Test func insertBothBMPAndNonBMPThenPartiallyRemoveNonBMP() {
        var characterSet = CharacterSet()
        
        characterSet.insert(charactersIn: UnicodeScalar(0x0041)!..<UnicodeScalar(0x0043)!)
        characterSet.insert(charactersIn: UnicodeScalar(0x10000)!..<UnicodeScalar(0x10002)!)
        characterSet.insert(charactersIn: UnicodeScalar(0x20000)!..<UnicodeScalar(0x20002)!)
        
        #expect(characterSet.hasMember(inPlane: 0))
        #expect(characterSet.hasMember(inPlane: 1))
        #expect(characterSet.hasMember(inPlane: 2))
        #expect(!characterSet.hasMember(inPlane: 3))
        
        characterSet.remove(charactersIn: UnicodeScalar(0x10000)!..<UnicodeScalar(0x10002)!)
        
        #expect(characterSet.hasMember(inPlane: 0))
        #expect(!characterSet.hasMember(inPlane: 1))
        #expect(characterSet.hasMember(inPlane: 2))
    }
    
    @Test func removeRangeFromInvertedStringBackedSet() {
        // Start with the universal set (inverted empty)
        var cs = CharacterSet()
        cs.invert()

        // Remove a character by string to put the set into string-backed storage
        cs.remove(charactersIn: "Z")
        #expect(!cs.contains(UnicodeScalar(0x005A)!)) // "Z" removed

        // Now remove a closed range — this hits the .string case in
        // remove(charactersIn range:) under the isInverted branch.
        // The closed range is "A"..."C" (0x0041...0x0043).
        cs.remove(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0043)!)

        // All three characters in the closed range must be removed
        #expect(!cs.contains(UnicodeScalar(0x0041)!)) // "A"
        #expect(!cs.contains(UnicodeScalar(0x0042)!)) // "B"
        #expect(!cs.contains(UnicodeScalar(0x0043)!)) // "C" — this fails with the ..<  bug

        // Characters outside the range should still be present
        #expect(cs.contains(UnicodeScalar(0x0040)!))  // "@" — before range
        #expect(cs.contains(UnicodeScalar(0x0044)!))  // "D" — after range
    }


    @Test func removeRangeFromInvertedRangeBackedSet_overlapFromLeft() {
        var cs = CharacterSet()
        cs.invert()

        // First remove A...E — inverted set now excludes A...E
        cs.remove(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0045)!)
        #expect(!cs.contains(UnicodeScalar(0x0041)!)) // "A" excluded
        #expect(!cs.contains(UnicodeScalar(0x0045)!)) // "E" excluded
        #expect(cs.contains(UnicodeScalar(0x0046)!))  // "F" still in set
        #expect(cs.contains(UnicodeScalar(0x0047)!))  // "G" still in set

        // Now remove A...G — same lower bound, extends beyond existing exclusion.
        // The exclusion should grow to A...G.
        cs.remove(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0047)!)

        #expect(!cs.contains(UnicodeScalar(0x0041)!)) // "A"
        #expect(!cs.contains(UnicodeScalar(0x0045)!)) // "E"
        #expect(!cs.contains(UnicodeScalar(0x0046)!)) // "F"
        #expect(!cs.contains(UnicodeScalar(0x0047)!)) // "G"
        #expect(cs.contains(UnicodeScalar(0x0048)!))  // "H" still in set
    }

    @Test func removeRangeFromInvertedRangeBackedSet_overlapWholeRange() {
        var cs = CharacterSet()
        cs.invert()

        // First remove D...F — inverted set now excludes D...F
        cs.remove(charactersIn: UnicodeScalar(0x0044)!...UnicodeScalar(0x0046)!)
        #expect(!cs.contains(UnicodeScalar(0x0044)!)) // "D" excluded
        #expect(!cs.contains(UnicodeScalar(0x0046)!)) // "F" excluded
        #expect(cs.contains(UnicodeScalar(0x0043)!))  // "C" still in set
        #expect(cs.contains(UnicodeScalar(0x0047)!))  // "G" still in set

        // Now remove A...Z — overlaps from the left and extends far beyond.
        // The exclusion should grow to A...Z.
        cs.remove(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x005A)!)

        #expect(!cs.contains(UnicodeScalar(0x0041)!)) // "A"
        #expect(!cs.contains(UnicodeScalar(0x0043)!)) // "C"
        #expect(!cs.contains(UnicodeScalar(0x0046)!)) // "F"
        #expect(!cs.contains(UnicodeScalar(0x0047)!)) // "G"
        #expect(!cs.contains(UnicodeScalar(0x005A)!)) // "Z"
        #expect(cs.contains(UnicodeScalar(0x0040)!))  // "@" still in set
        #expect(cs.contains(UnicodeScalar(0x005B)!))  // "[" still in set
    }

    @Test func removeRangeFromInvertedRangeBackedSet_overlapFromRightExtends() {
        var cs = CharacterSet()
        cs.invert()

        // First remove A...D — inverted set now excludes A...D
        cs.remove(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0044)!)
        #expect(!cs.contains(UnicodeScalar(0x0041)!)) // "A" excluded
        #expect(!cs.contains(UnicodeScalar(0x0044)!)) // "D" excluded
        #expect(cs.contains(UnicodeScalar(0x0045)!))  // "E" still in set
        #expect(cs.contains(UnicodeScalar(0x0047)!))  // "G" still in set

        // Now remove C...G — starts inside existing (C < D), extends beyond (G > D).
        // The exclusion should grow to the union: A...G.
        cs.remove(charactersIn: UnicodeScalar(0x0043)!...UnicodeScalar(0x0047)!)

        #expect(!cs.contains(UnicodeScalar(0x0041)!)) // "A" — still excluded
        #expect(!cs.contains(UnicodeScalar(0x0044)!)) // "D" — still excluded
        #expect(!cs.contains(UnicodeScalar(0x0045)!)) // "E" — newly excluded
        #expect(!cs.contains(UnicodeScalar(0x0047)!)) // "G" — newly excluded
        #expect(cs.contains(UnicodeScalar(0x0040)!))  // "@" — before range
        #expect(cs.contains(UnicodeScalar(0x0048)!))  // "H" — after range
    }

    @Test func removeRangeFromInvertedRangeBackedSet_overlapFromRightContained() {
        var cs = CharacterSet()
        cs.invert()

        // First remove A...G — inverted set now excludes A...G
        cs.remove(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0047)!)
        #expect(!cs.contains(UnicodeScalar(0x0041)!)) // "A" excluded
        #expect(!cs.contains(UnicodeScalar(0x0047)!)) // "G" excluded

        // Now remove C...E — fully contained within existing exclusion A...G.
        // Should not change the set at all.
        cs.remove(charactersIn: UnicodeScalar(0x0043)!...UnicodeScalar(0x0045)!)

        // Everything A...G should still be excluded
        #expect(!cs.contains(UnicodeScalar(0x0041)!)) // "A"
        #expect(!cs.contains(UnicodeScalar(0x0043)!)) // "C"
        #expect(!cs.contains(UnicodeScalar(0x0045)!)) // "E"
        #expect(!cs.contains(UnicodeScalar(0x0047)!)) // "G" — still excluded (not lost)
        #expect(cs.contains(UnicodeScalar(0x0040)!))  // "@" — before range
        #expect(cs.contains(UnicodeScalar(0x0048)!))  // "H" — after range
    }

    @Test func insertOverlappingRangeFromRight() {
        var cs = CharacterSet(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0044)!) // A...D
        cs.insert(charactersIn: UnicodeScalar(0x0043)!...UnicodeScalar(0x0047)!) // C...G

        #expect(cs.contains(UnicodeScalar(0x0041)!)) // A
        #expect(cs.contains(UnicodeScalar(0x0044)!)) // D
        #expect(cs.contains(UnicodeScalar(0x0047)!)) // G
        #expect(!cs.contains(UnicodeScalar(0x0040)!)) // @
        #expect(!cs.contains(UnicodeScalar(0x0048)!)) // H
    }

    @Test func insertOverlappingRangeFromLeft() {
        var cs = CharacterSet(charactersIn: UnicodeScalar(0x0044)!...UnicodeScalar(0x0047)!) // D...G
        cs.insert(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0045)!) // A...E

        #expect(cs.contains(UnicodeScalar(0x0041)!)) // A
        #expect(cs.contains(UnicodeScalar(0x0044)!)) // D
        #expect(cs.contains(UnicodeScalar(0x0047)!)) // G
        #expect(!cs.contains(UnicodeScalar(0x0040)!)) // @
        #expect(!cs.contains(UnicodeScalar(0x0048)!)) // H
    }

    @Test func insertFullyContainedRange() {
        var cs = CharacterSet(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0047)!) // A...G
        cs.insert(charactersIn: UnicodeScalar(0x0043)!...UnicodeScalar(0x0045)!) // C...E

        #expect(cs.contains(UnicodeScalar(0x0041)!)) // A
        #expect(cs.contains(UnicodeScalar(0x0043)!)) // C
        #expect(cs.contains(UnicodeScalar(0x0045)!)) // E
        #expect(cs.contains(UnicodeScalar(0x0047)!)) // G — must not shrink
        #expect(!cs.contains(UnicodeScalar(0x0040)!)) // @
        #expect(!cs.contains(UnicodeScalar(0x0048)!)) // H
    }

    @Test func insertRangeFullyCoveringExisting() {
        var cs = CharacterSet(charactersIn: UnicodeScalar(0x0043)!...UnicodeScalar(0x0045)!) // C...E
        cs.insert(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0047)!) // A...G

        #expect(cs.contains(UnicodeScalar(0x0041)!)) // A
        #expect(cs.contains(UnicodeScalar(0x0043)!)) // C
        #expect(cs.contains(UnicodeScalar(0x0045)!)) // E
        #expect(cs.contains(UnicodeScalar(0x0047)!)) // G
        #expect(!cs.contains(UnicodeScalar(0x0040)!)) // @
        #expect(!cs.contains(UnicodeScalar(0x0048)!)) // H
    }

    @Test func insertAdjacentRanges() {
        var cs = CharacterSet(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0044)!) // A...D
        cs.insert(charactersIn: UnicodeScalar(0x0045)!...UnicodeScalar(0x0047)!) // E...G — adjacent, not overlapping

        // Both ranges should be present regardless of whether they merged or fell through to bitmap
        #expect(cs.contains(UnicodeScalar(0x0041)!)) // A
        #expect(cs.contains(UnicodeScalar(0x0042)!)) // B
        #expect(cs.contains(UnicodeScalar(0x0044)!)) // D
        #expect(cs.contains(UnicodeScalar(0x0045)!)) // E
        #expect(cs.contains(UnicodeScalar(0x0047)!)) // G
        #expect(!cs.contains(UnicodeScalar(0x0040)!)) // @
        #expect(!cs.contains(UnicodeScalar(0x0048)!)) // H
    }
    
    @Test func insertNonBMPRangeIntoStringBackedSet() {
        var cs = CharacterSet(charactersIn: "AB")
        // Insert a range spanning BMP and non-BMP
        cs.insert(charactersIn: UnicodeScalar(0xFFFF)!...UnicodeScalar(0x10001)!)

        #expect(cs.contains(UnicodeScalar(0x0041)!)) // A
        #expect(cs.contains(UnicodeScalar(0x0042)!)) // B
        #expect(cs.contains(UnicodeScalar(0xFFFF)!))
        #expect(cs.contains(UnicodeScalar(0x10000)!))
        #expect(cs.contains(UnicodeScalar(0x10001)!))
        #expect(cs.hasMember(inPlane: 0))
        #expect(cs.hasMember(inPlane: 1))
    }

    @Test func removeNonBMPRangeFromInvertedStringBackedSet() {
        var cs = CharacterSet()
        cs.invert()
        cs.remove(charactersIn: "Z") // force string-backed

        // Remove a range spanning BMP and non-BMP
        cs.remove(charactersIn: UnicodeScalar(0xFFFF)!...UnicodeScalar(0x10001)!)

        #expect(!cs.contains(UnicodeScalar(0xFFFF)!))
        #expect(!cs.contains(UnicodeScalar(0x10000)!))
        #expect(!cs.contains(UnicodeScalar(0x10001)!))
        #expect(!cs.contains(UnicodeScalar(0x005A)!)) // Z still removed
        #expect(cs.contains(UnicodeScalar(0x0041)!))  // A still present
        #expect(cs.contains(UnicodeScalar(0xFFFE)!))  // before range
        #expect(cs.contains(UnicodeScalar(0x10002)!)) // after range
    }
    
    @Test func insertLargeRangeIntoStringBackedSetFallsToBitmap() {
        var cs = CharacterSet(charactersIn: "AB")
        // Insert a range of 65 BMP scalars — exceeds __kCFStringCharSetMax, should fall through to bitmap
        cs.insert(charactersIn: UnicodeScalar(0x0100)!...UnicodeScalar(0x0140)!)

        #expect(cs.contains(UnicodeScalar(0x0041)!)) // A — original
        #expect(cs.contains(UnicodeScalar(0x0042)!)) // B — original
        #expect(cs.contains(UnicodeScalar(0x0100)!)) // start of inserted range
        #expect(cs.contains(UnicodeScalar(0x0140)!)) // end of inserted range
        #expect(!cs.contains(UnicodeScalar(0x0043)!)) // C — not inserted
        #expect(!cs.contains(UnicodeScalar(0x0141)!)) // past end
    }

    @Test func fullUnicodeRangeInitIsUniversal() {
        let viaRange = CharacterSet(charactersIn: UnicodeScalar(0)!...UnicodeScalar(0x10FFFF)!)

        var viaInvert = CharacterSet()
        viaInvert.invert()

        validateUniversalSet(viaRange)
        #expect(viaRange.contains(UnicodeScalar(0x1F600)!))
        #expect(viaRange.contains(UnicodeScalar(0x10FFFF)!))
        #expect(viaRange == viaInvert)
        #expect(viaRange.bitmapRepresentation == viaInvert.bitmapRepresentation)
    }

    @Test func insertRangeSpanningThreeNonBMPPlanes() {
        var cs = CharacterSet()
        cs.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x30005)!)

        #expect(!cs.hasMember(inPlane: 0))
        #expect(cs.hasMember(inPlane: 1))
        #expect(cs.hasMember(inPlane: 2))
        #expect(cs.hasMember(inPlane: 3))
        #expect(!cs.hasMember(inPlane: 4))

        #expect(cs.contains(UnicodeScalar(0x10000)!))
        #expect(cs.contains(UnicodeScalar(0x1F000)!))
        #expect(cs.contains(UnicodeScalar(0x20000)!))
        #expect(cs.contains(UnicodeScalar(0x2F000)!))
        #expect(cs.contains(UnicodeScalar(0x30000)!))
        #expect(cs.contains(UnicodeScalar(0x30005)!))
        #expect(!cs.contains(UnicodeScalar(0x30006)!))
    }

    @Test func insertNonBMPRangeWithSurrogateOffset() {
        var cs = CharacterSet()
        cs.insert(charactersIn: UnicodeScalar(0x1D900)!...UnicodeScalar(0x1DA00)!)

        #expect(cs.hasMember(inPlane: 1))
        #expect(cs.contains(UnicodeScalar(0x1D900)!))
        #expect(cs.contains(UnicodeScalar(0x1D9FF)!))
        #expect(cs.contains(UnicodeScalar(0x1DA00)!))
        #expect(!cs.contains(UnicodeScalar(0x1D8FF)!))
        #expect(!cs.contains(UnicodeScalar(0x1DA01)!))
    }

    @Test func removeNonBMPRangeWithSurrogateOffset() {
        var cs = CharacterSet()
        cs.insert(charactersIn: UnicodeScalar(0x1D000)!...UnicodeScalar(0x1E000)!)
        cs.remove(charactersIn: UnicodeScalar(0x1D900)!...UnicodeScalar(0x1DA00)!)

        #expect(cs.contains(UnicodeScalar(0x1D000)!))
        #expect(cs.contains(UnicodeScalar(0x1D8FF)!))
        #expect(!cs.contains(UnicodeScalar(0x1D900)!))
        #expect(!cs.contains(UnicodeScalar(0x1DA00)!))
        #expect(cs.contains(UnicodeScalar(0x1DA01)!))
        #expect(cs.contains(UnicodeScalar(0x1E000)!))
    }

    @Test func reincludeNonBMPRangeIntoInvertedSet() {
        var cs = CharacterSet()
        cs.invert()
        cs.remove(charactersIn: UnicodeScalar(0x20000)!...UnicodeScalar(0x20020)!)
        #expect(!cs.contains(UnicodeScalar(0x20000)!))
        #expect(!cs.contains(UnicodeScalar(0x20020)!))

        cs.insert(charactersIn: UnicodeScalar(0x20000)!...UnicodeScalar(0x20010)!)

        #expect(cs.contains(UnicodeScalar(0x20000)!))
        #expect(cs.contains(UnicodeScalar(0x20010)!))
        #expect(!cs.contains(UnicodeScalar(0x20011)!))
        #expect(!cs.contains(UnicodeScalar(0x20020)!))
        #expect(cs.contains(UnicodeScalar(0x20021)!))
        #expect(cs.contains(UnicodeScalar(0x30000)!))
    }

    @Test func multiPlaneRangeMatchesScalarByScalar() {
        let viaRange = CharacterSet(charactersIn: UnicodeScalar(0x1FFF0)!...UnicodeScalar(0x20010)!)

        var viaScalars = CharacterSet()
        for value in 0x1FFF0...0x20010 {
            viaScalars.insert(UnicodeScalar(value)!)
        }

        #expect(viaRange == viaScalars)
    }

    @Test func wideNonBMPRangeInsertThenRemoveRoundTrip() {
        var cs = CharacterSet()
        cs.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x50010)!)

        #expect(cs.hasMember(inPlane: 1))
        #expect(cs.hasMember(inPlane: 2))
        #expect(cs.hasMember(inPlane: 3))
        #expect(cs.hasMember(inPlane: 4))
        #expect(cs.hasMember(inPlane: 5))
        #expect(cs.contains(UnicodeScalar(0x10000)!))
        #expect(cs.contains(UnicodeScalar(0x50010)!))
        #expect(!cs.contains(UnicodeScalar(0x50011)!))

        cs.remove(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x50010)!)

        validateEmptySet(cs)
    }

    @Test func insertSurrogateOffsetRangeIntoNonEmptyNonInvertedSet() {
        var cs = CharacterSet()
        for value in 0x0100...0x0180 {
            cs.insert(UnicodeScalar(value)!)
        }
        cs.insert(charactersIn: UnicodeScalar(0x1D900)!...UnicodeScalar(0x1DA00)!)

        #expect(cs.contains(UnicodeScalar(0x1D900)!))
        #expect(cs.contains(UnicodeScalar(0x1DA00)!))
        #expect(!cs.contains(UnicodeScalar(0x1D8FF)!))
        #expect(!cs.contains(UnicodeScalar(0x1DA01)!))
        #expect(cs.contains(UnicodeScalar(0x0110)!))
    }

    @Test func insertSurrogateOffsetRangeIntoInvertedSetIsNoOp() {
        var cs = CharacterSet()
        for value in 0x0100...0x0180 {
            cs.insert(UnicodeScalar(value)!)
        }
        cs.invert()
        cs.insert(charactersIn: UnicodeScalar(0x1D900)!...UnicodeScalar(0x1DA00)!)

        #expect(cs.contains(UnicodeScalar(0x1D900)!))
        #expect(cs.contains(UnicodeScalar(0x1DA00)!))
        #expect(cs.contains(UnicodeScalar(0x1D8FF)!))
        #expect(!cs.contains(UnicodeScalar(0x0110)!))
    }

    @Test func removeSurrogateOffsetRangeFromInvertedBitmapSet() {
        var cs = CharacterSet()
        for value in 0x0100...0x0180 {
            cs.insert(UnicodeScalar(value)!)
        }
        cs.invert()
        cs.remove(charactersIn: UnicodeScalar(0x1D900)!...UnicodeScalar(0x1DA00)!)

        #expect(!cs.contains(UnicodeScalar(0x1D900)!))
        #expect(!cs.contains(UnicodeScalar(0x1DA00)!))
        #expect(cs.contains(UnicodeScalar(0x1D8FF)!))
        #expect(cs.contains(UnicodeScalar(0x1DA01)!))
    }

    @Test func reincludeSurrogateOffsetRangeIntoInvertedSet() {
        var cs = CharacterSet()
        for value in 0x0100...0x0180 {
            cs.insert(UnicodeScalar(value)!)
        }
        cs.invert()
        cs.remove(charactersIn: UnicodeScalar(0x1D000)!...UnicodeScalar(0x1E000)!)
        cs.insert(charactersIn: UnicodeScalar(0x1D900)!...UnicodeScalar(0x1DA00)!)

        #expect(cs.contains(UnicodeScalar(0x1D900)!))
        #expect(cs.contains(UnicodeScalar(0x1DA00)!))
        #expect(!cs.contains(UnicodeScalar(0x1D8FF)!))
        #expect(!cs.contains(UnicodeScalar(0x1DA01)!))
        #expect(cs.contains(UnicodeScalar(0x1CFFF)!))
    }

    @Test func rangeBackedSetConvertedToBitmapKeepsSurrogateOffsets() {
        var cs = CharacterSet(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x1FFFF)!)
        cs.insert(charactersIn: UnicodeScalar(0x0041)!...UnicodeScalar(0x0050)!)

        let missing = (0x10000...0x1FFFF).filter { !cs.contains(UnicodeScalar($0)!) }
        #expect(missing.count == 0)
        #expect(cs.contains(UnicodeScalar(0x0041)!))
        #expect(cs.contains(UnicodeScalar(0x0050)!))
        #expect(!cs.contains(UnicodeScalar(0x20000)!))
    }

    @Test func insertRangeSpanningSurrogateOffsetsIntoNonEmptySet() {
        var cs = CharacterSet(charactersIn: "a")
        cs.insert(charactersIn: UnicodeScalar(0x1D7FF)!...UnicodeScalar(0x1E000)!)

        let missing = (0x1D7FF...0x1E000).filter { !cs.contains(UnicodeScalar($0)!) }
        #expect(missing.count == 0)
        #expect(!cs.contains(UnicodeScalar(0x1D7FE)!))
        #expect(!cs.contains(UnicodeScalar(0x1E001)!))
        #expect(cs.contains(UnicodeScalar(0x0061)!))
    }

    @Test func insertRangesSpanningSurrogateOffsetsAcrossPlanes() {
        var cs = CharacterSet(charactersIn: "a")
        cs.insert(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x3D7FF)!)
        cs.insert(charactersIn: UnicodeScalar(0x4E000)!...UnicodeScalar(0x4FFFF)!)

        let missing = (0x10000...0x3D7FF).filter { !cs.contains(UnicodeScalar($0)!) }
        #expect(missing.count == 0)
        let unexpected = (0x3D800...0x4DFFF).filter { cs.contains(UnicodeScalar($0)!) }
        #expect(unexpected.count == 0)
        let missingAbove = (0x4E000...0x4FFFF).filter { !cs.contains(UnicodeScalar($0)!) }
        #expect(missingAbove.count == 0)
        #expect(!cs.contains(UnicodeScalar(0x50000)!))
    }

    @Test func removeRangeSpanningSurrogateOffsetsFromInvertedSet() {
        var cs = CharacterSet(charactersIn: "a")
        cs.invert()
        cs.remove(charactersIn: UnicodeScalar(0x1D7FF)!...UnicodeScalar(0x1E000)!)

        let unexpected = (0x1D7FF...0x1E000).filter { cs.contains(UnicodeScalar($0)!) }
        #expect(unexpected.count == 0)
        #expect(cs.contains(UnicodeScalar(0x1D7FE)!))
        #expect(cs.contains(UnicodeScalar(0x1E001)!))
        #expect(!cs.contains(UnicodeScalar(0x0061)!))
    }

    @Test func removeRangesSpanningSurrogateOffsetsAcrossPlanesFromInvertedSet() {
        var cs = CharacterSet(charactersIn: "a")
        cs.invert()
        cs.remove(charactersIn: UnicodeScalar(0x10000)!...UnicodeScalar(0x3D7FF)!)
        cs.remove(charactersIn: UnicodeScalar(0x4E000)!...UnicodeScalar(0x4FFFF)!)

        let unexpected = (0x10000...0x3D7FF).filter { cs.contains(UnicodeScalar($0)!) }
        #expect(unexpected.count == 0)
        let missing = (0x3D800...0x4DFFF).filter { !cs.contains(UnicodeScalar($0)!) }
        #expect(missing.count == 0)
        let unexpectedAbove = (0x4E000...0x4FFFF).filter { cs.contains(UnicodeScalar($0)!) }
        #expect(unexpectedAbove.count == 0)
        #expect(cs.contains(UnicodeScalar(0x50000)!))
    }
}
