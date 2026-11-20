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

#if FOUNDATION_FRAMEWORK
internal import CoreFoundation_Private.CFString
internal import _ForSwiftFoundation
#if canImport(_FoundationICU)
internal import _FoundationICU
#endif
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

/// Appends a %@ value, surrounding it with directional isolates when localized formatting mixes in right-to-left text
#if !FOUNDATION_FRAMEWORK && !hasFeature(Embedded)
@_dynamicReplacement(for: appendObjectValue(_:producedFrom:for:locale:trailingFormat:isolates:into:))
#endif
func appendObjectValue_localized(_ value: String, producedFrom object: AnyObject, for spec: ParsedFormatSpec, locale: Locale?, trailingFormat: StringContents, isolates: inout FormatIsolatesState, into output: inout some StringBuilder & ~Copyable) {
    #if FOUNDATION_FRAMEWORK
    if let locale, !disableIsolates {
        let detector = RightToLeftDetector()
        let valueIsMark = RightToLeftDetector.statistical && (value == "\u{200E}" || value == "\u{200F}")
        if !isolates.usingIsolates {
            isolates.usingIsolates = output.withContents {
                isolates.shouldUseIsolates(for: value, valueIsMark: valueIsMark, locale: locale, output: $0, trailingFormat: trailingFormat, detector)
            }
        }

        let openingIsolate = (isolates.usingIsolates && !valueIsMark) ? openingIsolate(for: value, statistical: RightToLeftDetector.statistical) : nil
        if let openingIsolate {
            output._append(copying: openingIsolate.utf8.span.bytes, encoding: .utf8, source: .extras(for: spec.sourceRange))
        }
        value.withContents {
            output._append(copying: $0.bytes, encoding: $0.encoding.stringEncoding, source: .object(object, for: spec))
        }
        if openingIsolate != nil {
            output._append(copying: "\u{2069}".utf8.span.bytes, encoding: .utf8, source: .extras(for: spec.sourceRange)) // POP DIRECTIONAL ISOLATE
        }

        if !isolates.usingIsolates {
            output.withContents {
                isolates.checkedOutputCount = $0.count
                isolates.checkedOutputEncoding = $0.encoding
            }
        }
        return
    }
    #endif
    value.withContents {
        output._append(copying: $0.bytes, encoding: $0.encoding.stringEncoding, source: .object(object, for: spec))
    }
}

#if FOUNDATION_FRAMEWORK
#if NO_PROCESS
private var disableIsolates: Bool { false }
#else
private let disableIsolates = String.compatibility4 || ProcessInfo.processInfo.environment["CFStringDisableIsolates"] != nil
#endif

extension FormatIsolatesState {
    fileprivate mutating func shouldUseIsolates(for value: String, valueIsMark: Bool, locale: Locale, output: StringContents, trailingFormat: StringContents, _ detector: RightToLeftDetector) -> Bool {
        #if ICU
        if RightToLeftDetector.statistical {
            return shouldUseStatisticalIsolates(for: value, valueIsMark: valueIsMark, locale: locale, output: output, trailingFormat: trailingFormat, detector)
        }
        #endif
        if detector.containsRightToLeft(value) {
            return true
        }
        if output.bytes.isEmpty {
            return detector.containsRightToLeft(trailingFormat)
        }

        if checkedOutputEncoding != output.encoding {
            checkedOutputCount = 0
            checkedOutputEncoding = output.encoding
        }

        return output.count > checkedOutputCount && detector.containsRightToLeft(output.extracting(droppingFirst: checkedOutputCount))
    }

    #if ICU
    private mutating func shouldUseStatisticalIsolates(for value: String, valueIsMark: Bool, locale: Locale, output: StringContents, trailingFormat: StringContents, _ detector: RightToLeftDetector) -> Bool {
        let localeIsRightToLeft = self.localeIsRightToLeft ?? (locale.language.characterDirection == .rightToLeft)
        self.localeIsRightToLeft = localeIsRightToLeft
        if localeIsRightToLeft || (!valueIsMark && detector.containsRightToLeft(value)) {
            return true
        }
        if checkedOutputCount == 0 && detector.containsRightToLeft(output) {
            return true
        }
        return detector.containsRightToLeft(trailingFormat)
    }
    #endif
}

private func openingIsolate(for value: String, statistical: Bool) -> String {
    #if ICU
    if statistical && _foundation_swift_language_aware_string_enabled() {
        let paragraphs = CFStringCopyStatisticalWritingDirections(value as CFString) as NSArray
        for case let paragraph as NSDictionary in paragraphs {
            // Values match NSWritingDirection
            guard let direction = (paragraph[CFStatisticalWritingDirectionParagraphInfoKey.writingDirection.rawValue] as? NSNumber)?.int8Value, direction != -1 else {
                continue
            }
            switch direction {
            case 0: return "\u{2066}" // LEFT-TO-RIGHT ISOLATE
            case 1: return "\u{2067}" // RIGHT-TO-LEFT ISOLATE
            default: return "\u{2068}" // FIRST STRONG ISOLATE
            }
        }
    }
    #endif
    return "\u{2068}" // FIRST STRONG ISOLATE
}

private struct RightToLeftDetector {
    static var statistical: Bool {
        _foundation_swift_statistical_localized_string_with_format_enabled()
    }
    static var recognizeWeakRightToLeft: Bool {
        statistical && _foundation_swift_statistical_arabic_indic_digits_enabled()
    }

    func containsRightToLeft(_ string: String) -> Bool {
        string.unicodeScalars.contains(where: isRightToLeft)
    }

    func containsRightToLeft(_ contents: StringContents) -> Bool {
        switch contents.encoding {
        case .ascii:
            containsRightToLeft(Span(viewing: contents.bytes), as: Unicode.ASCII.self)
        case .utf8:
            containsRightToLeft(Span(viewing: contents.bytes), as: UTF8.self)
        case .utf16:
            containsRightToLeft(Span(viewing: contents.bytes), as: UTF16.self)
        }
    }

    func containsRightToLeft<E: Unicode.Encoding>(_ codeUnits: Span<E.CodeUnit>, as encoding: E.Type) -> Bool {
        codeUnits.withUnsafeBufferPointer { codeUnits in
            var iterator = codeUnits.makeIterator()
            var parser = E.ForwardParser()
            while true {
                switch parser.parseScalar(from: &iterator) {
                case .valid(let encoded):
                    if isRightToLeft(E.decode(encoded)) {
                        return true
                    }
                case .error:
                    continue
                case .emptyInput:
                    return false
                }
            }
        }
    }

    private func isRightToLeft(_ scalar: Unicode.Scalar) -> Bool {
        guard !scalar.isASCII else { return false }
        #if ICU
        if Self.statistical {
            switch u_charDirection(UChar32(scalar.value)) {
            case U_RIGHT_TO_LEFT, U_RIGHT_TO_LEFT_ARABIC:
                return true
            case U_ARABIC_NUMBER:
                return Self.recognizeWeakRightToLeft
            case U_EUROPEAN_NUMBER:
                // Persian digits are classified as European numbers
                return Self.recognizeWeakRightToLeft && scalar.value >= 0x06F0 && scalar.value <= 0x06F9
            default:
                return false
            }
        }
        #endif
        return BuiltInUnicodeScalarSet(type: .strongRightToLeft).contains(scalar)
    }
}
#endif
