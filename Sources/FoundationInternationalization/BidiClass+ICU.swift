//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

internal import _FoundationICU

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

extension Unicode {
    /// A scalar's Unicode Bidi_Class, the directional category used by the
    /// Unicode Bidirectional Algorithm (UAX #9).
    package enum _BidiClass: UInt8 {
        case leftToRight            // L
        case rightToLeft            // R
        case arabicLetter           // AL
        case europeanNumber         // EN
        case europeanSeparator      // ES
        case europeanTerminator     // ET
        case arabicNumber           // AN
        case commonSeparator        // CS
        case nonspacingMark         // NSM
        case boundaryNeutral        // BN
        case paragraphSeparator     // B
        case segmentSeparator       // S
        case whitespace             // WS
        case otherNeutral           // ON
        case leftToRightEmbedding   // LRE
        case leftToRightOverride    // LRO
        case rightToLeftEmbedding   // RLE
        case rightToLeftOverride    // RLO
        case popDirectionalFormat   // PDF
        case leftToRightIsolate     // LRI
        case rightToLeftIsolate     // RLI
        case firstStrongIsolate     // FSI
        case popDirectionalIsolate  // PDI
    }
}

extension Unicode.Scalar {
    /// The scalar's Bidi_Class (UAX #9).
    ///
    /// TEMPORARY: this reads the value from ICU (`u_charDirection`) as an interim
    /// measure until the Swift standard library exposes the Bidi_Class property.
    /// (`ListFormatStyle`'s bidi-isolate wrapping needs it, and `General_Category`
    /// can't approximate `L` exactly.) The intent is to swap this implementation
    /// for the stdlib property without touching callers.
    package var _bidiClass: Unicode._BidiClass {
        Self._icuDirectionToBidiClass[Int(u_charDirection(UChar32(value)).rawValue)]
    }

    // Indexed by ICU's UCharDirection raw value (0...22); ICU's enum ordering
    // differs from ours, so this remaps it to `Unicode._BidiClass`.
    private static let _icuDirectionToBidiClass: [Unicode._BidiClass] = [
        .leftToRight,          // 0  U_LEFT_TO_RIGHT              (L)
        .rightToLeft,          // 1  U_RIGHT_TO_LEFT              (R)
        .europeanNumber,       // 2  U_EUROPEAN_NUMBER            (EN)
        .europeanSeparator,    // 3  U_EUROPEAN_NUMBER_SEPARATOR  (ES)
        .europeanTerminator,   // 4  U_EUROPEAN_NUMBER_TERMINATOR (ET)
        .arabicNumber,         // 5  U_ARABIC_NUMBER              (AN)
        .commonSeparator,      // 6  U_COMMON_NUMBER_SEPARATOR    (CS)
        .paragraphSeparator,   // 7  U_BLOCK_SEPARATOR            (B)
        .segmentSeparator,     // 8  U_SEGMENT_SEPARATOR          (S)
        .whitespace,           // 9  U_WHITE_SPACE_NEUTRAL        (WS)
        .otherNeutral,         // 10 U_OTHER_NEUTRAL              (ON)
        .leftToRightEmbedding, // 11 U_LEFT_TO_RIGHT_EMBEDDING    (LRE)
        .leftToRightOverride,  // 12 U_LEFT_TO_RIGHT_OVERRIDE     (LRO)
        .arabicLetter,         // 13 U_RIGHT_TO_LEFT_ARABIC       (AL)
        .rightToLeftEmbedding, // 14 U_RIGHT_TO_LEFT_EMBEDDING    (RLE)
        .rightToLeftOverride,  // 15 U_RIGHT_TO_LEFT_OVERRIDE     (RLO)
        .popDirectionalFormat, // 16 U_POP_DIRECTIONAL_FORMAT     (PDF)
        .nonspacingMark,       // 17 U_DIR_NON_SPACING_MARK       (NSM)
        .boundaryNeutral,      // 18 U_BOUNDARY_NEUTRAL           (BN)
        .firstStrongIsolate,   // 19 U_FIRST_STRONG_ISOLATE       (FSI)
        .leftToRightIsolate,   // 20 U_LEFT_TO_RIGHT_ISOLATE      (LRI)
        .rightToLeftIsolate,   // 21 U_RIGHT_TO_LEFT_ISOLATE      (RLI)
        .popDirectionalIsolate,// 22 U_POP_DIRECTIONAL_ISOLATE    (PDI)
    ]
}
