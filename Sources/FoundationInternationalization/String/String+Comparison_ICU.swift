//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_ICU_STRING_COMPARE
#if canImport(FoundationEssentials)
import FoundationEssentials
#endif
internal import _FoundationICU

internal func compareStringsWithLocale(_ string1: Substring, _ string2: Substring, options: String.CompareOptions, locale: Locale) -> ComparisonResult {
    let localeIdentifier = locale.identifier
    var status = U_ZERO_ERROR

    let collator = localeIdentifier.utf8CString.withUnsafeBufferPointer({ buffer in
        ucol_open(buffer.baseAddress, &status)
    })

    defer {
        if let collator = collator {
            ucol_close(collator)
        }
    }

    guard let collator = collator, status.rawValue <= U_ZERO_ERROR.rawValue else {
        if string1 < string2 {
            return .orderedAscending
        } else if string1 > string2 {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    configureCollator(collator, options: options, status: &status)
    guard status.rawValue <= U_ZERO_ERROR.rawValue else {
        if string1 < string2 {
            return .orderedAscending
        } else if string1 > string2 {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    let result = string1.withCString(encodedAs: UTF16.self) { str1Ptr in
        string2.withCString(encodedAs: UTF16.self) { str2Ptr in
            ucol_strcoll(collator, str1Ptr, -1, str2Ptr, -1)
        }
    }

    switch result {
    case UCOL_LESS:
        return .orderedAscending
    case UCOL_EQUAL:
        return .orderedSame
    case UCOL_GREATER:
        return .orderedDescending
    default:
        return .orderedSame
    }
}

private func configureCollator(_ collator: OpaquePointer, options: String.CompareOptions, status: inout UErrorCode) {
    if options.contains(.literal) {
        ucol_setAttribute(collator, UCOL_NORMALIZATION_MODE, UCOL_OFF, &status)
    }

    if options.contains(.diacriticInsensitive) && options.contains(.caseInsensitive) {
        ucol_setAttribute(collator, UCOL_STRENGTH, UCOL_PRIMARY, &status)
    } else if options.contains(.diacriticInsensitive) {
        ucol_setAttribute(collator, UCOL_STRENGTH, UCOL_PRIMARY, &status)
        ucol_setAttribute(collator, UCOL_CASE_LEVEL, UCOL_ON, &status)
    } else if options.contains(.caseInsensitive) {
        ucol_setAttribute(collator, UCOL_STRENGTH, UCOL_SECONDARY, &status)
    }

    if options.contains(.numeric) {
        ucol_setAttribute(collator, UCOL_NUMERIC_COLLATION, UCOL_ON, &status)
    }
}

@_dynamicReplacement(for: _localizedCompare_platform(_:other:options:locale:))
package func _localizedCompare_ICU(_ string: Substring, other: Substring, options: String.CompareOptions, locale: Locale) -> ComparisonResult {
    return compareStringsWithLocale(string, other, options: options, locale: locale)
}

#endif // FOUNDATION_ICU_STRING_COMPARE
