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

func validate(
    specs: Span<ParsedFormatSpec>,
    in sourceFormat: StringContents,
    match trustedFormat: StringContents,
    stringsDictConfig: StringsDictConfig?
) throws(CocoaError) {
    let maxSpecs = try trustedFormat.count(of: ._percent).multipledThrowingOverflow(by: 2).addingThrowingOverflow(1)
    return try withTemporaryAllocation(of: ParsedFormatSpec.self, capacity: maxSpecs) { trustedSpecBuffer throws(CocoaError) in
        try parseFormatSpecifiers(from: trustedFormat, into: &trustedSpecBuffer, stringsDictConfig: nil)

        var trustedSpecs = trustedSpecBuffer.mutableSpan
        let maxArgs = try assignArgumentIndices(for: &trustedSpecs, startingAt: 1)

        return try withTemporaryAllocation(of: ParsedFormatSpec.Kind?.self, capacity: Int(maxArgs)) { trustedArgumentKindBuffer throws(CocoaError) in
            trustedArgumentKindBuffer.append(repeating: nil, count: trustedArgumentKindBuffer.freeCapacity)
            var trustedArgumentKinds = trustedArgumentKindBuffer.mutableSpan

            try writeArgumentValueKinds(from: trustedSpecs.span, in: trustedFormat, into: &trustedArgumentKinds, stringsDictConfig: nil)
            try validate(specs: specs, in: sourceFormat, match: trustedArgumentKinds.span, in: trustedFormat, stringsDictConfig: stringsDictConfig)
        }
    }
}

extension CocoaError {
    fileprivate static func formatValidationError(_ additional: String? = nil) -> CocoaError {
        var debug = "Format does not match expected format"
        if let additional {
            debug += ": \(additional)"
        }
        return CocoaError(.formatting, debugDescription: debug)
    }
}

extension ParsedFormatSpec {
    fileprivate func content(from sourceFormat: StringContents) -> String {
        String(copying: sourceFormat.extracting(sourceRange))
    }
}

private func validate(
    specs: Span<ParsedFormatSpec>,
    in sourceFormat: StringContents,
    match trustedKinds: Span<ParsedFormatSpec.Kind?>,
    in trustedFormat: StringContents,
    stringsDictConfig: StringsDictConfig?
) throws(CocoaError) {
    for i in specs.indices {
        let spec = specs[i]

        if let mainArgNum = spec.mainArgNum, spec.kind.usesArgument {
            let (kind, stringsDictInfo) = try spec.resolvedKindAndStringsDictInfo(in: sourceFormat, with: stringsDictConfig)
            if let innerFormat = stringsDictInfo?.innerFormat, innerFormat.utf8.span.contains(._percent) {
                let formatKey = spec.content(from: sourceFormat)
                throw CocoaError.formatValidationError("NSStringFormatValueTypeKey value '\(innerFormat)' for format specifier '\(formatKey)' in format string '\(String(copying: sourceFormat))' contains an illegal '%' character")
            }
            if let kind {
                let offset = Int(mainArgNum) - 1
                guard offset < trustedKinds.count, let trustedKind = trustedKinds[offset] else {
                    let invalid = spec.content(from: sourceFormat)
                    throw CocoaError.formatValidationError("Format specifier '\(invalid)' in format string '\(String(copying: sourceFormat))' refers to argument \(mainArgNum) which is not a valid argument number in trusted format '\(String(copying: trustedFormat))'")
                }
                try validate(kind, matches: trustedKind, untrustedFormat: String(copying: sourceFormat), untrustedSpecifier: spec.content(from: sourceFormat), trustedFormat: String(copying: trustedFormat), stringsDictInfo: try spec.innerFormatInfo(in: sourceFormat, from: stringsDictConfig))
            }
        }
        if case let .reference(precisionArgNum) = spec.precisionArg, let precisionArgNum {
            let offset = Int(precisionArgNum) - 1
            guard offset < trustedKinds.count, let trustedKind = trustedKinds[offset] else {
                let invalid = spec.content(from: sourceFormat)
                throw CocoaError.formatValidationError("Format specifier '\(invalid)' in format string '\(String(copying: sourceFormat))' refers to precision argument \(precisionArgNum) which is not a valid argument number in trusted format '\(String(copying: trustedFormat))'")
            }
            try validate(.auxiliaryArgument, matches: trustedKind, untrustedFormat: String(copying: sourceFormat), untrustedSpecifier: spec.content(from: sourceFormat), trustedFormat: String(copying: trustedFormat), stringsDictInfo: nil)
        }
        if case let .reference(widthArgNum) = spec.widthArg, let widthArgNum {
            let offset = Int(widthArgNum) - 1
            guard offset < trustedKinds.count, let trustedKind = trustedKinds[offset] else {
                let invalid = spec.content(from: sourceFormat)
                throw CocoaError.formatValidationError("Format specifier '\(invalid)' in format string '\(String(copying: sourceFormat))' refers to width argument \(widthArgNum) which is not a valid argument number in trusted format '\(String(copying: trustedFormat))'")
            }
            try validate(.auxiliaryArgument, matches: trustedKind, untrustedFormat: String(copying: sourceFormat), untrustedSpecifier: spec.content(from: sourceFormat), trustedFormat: String(copying: trustedFormat), stringsDictInfo: nil)
        }
    }
}

private func validate(
    _ untrusted: ParsedFormatSpec.Kind,
    matches expected: ParsedFormatSpec.Kind,
    untrustedFormat: @autoclosure () -> String,
    untrustedSpecifier: @autoclosure() -> String,
    trustedFormat: @autoclosure () -> String,
    stringsDictInfo: @autoclosure () throws(CocoaError) -> StringsDictConfig.InnerFormatInfo?
) throws(CocoaError) {
    guard untrusted != expected else {
        return
    }

    switch untrusted {
    case .pointer:
        // Allow %p when %@/%s/%S/%P were provided since those must all be valid pointers
        if expected == .object || expected == .unichars || expected == .chars || expected == .pascalChars {
            return
        }

        // We also allow %d/%u since those can be represented as pointers, assuming their size matches
        if case let .integer(flags) = expected {
            try validate(.pointer, matches: flags.size, untrustedFormat: untrustedFormat(), untrustedSpecifier: untrustedSpecifier(), trustedFormat: trustedFormat(), stringsDictInfo: stringsDictInfo())
            return
        }

    case .unichars:
        // Allow %S when %p was provided, since we can't discern what the caller provided a pointer to
        if expected == .pointer {
            return
        }

    case .chars, .pascalChars:
        if expected == .pointer {
            // Allow %s/%P when %p was provided, since we can't discern what the caller provided a pointer to
            return
        }

        // Allow interchanging %s and %P, since we can't discern what the caller provided a pointer to
        if expected == .chars || expected == .pascalChars {
            return
        }

    case .singleUnichar:
        // Allow %C when %u/%d is provided (assuming that size validation matches as well) since %C is still a number, just viewed through a different "lens"
        if case let .integer(flags) = expected {
            try validate(.short, matches: flags.size, untrustedFormat: untrustedFormat(), untrustedSpecifier: untrustedSpecifier(), trustedFormat: trustedFormat(), stringsDictInfo: stringsDictInfo())
            return
        }

    case .integer(let flags):
        if case let .integer(expectedFlags) = expected {
            try validate(flags.size, matches: expectedFlags.size, untrustedFormat: untrustedFormat(), untrustedSpecifier: untrustedSpecifier(), trustedFormat: trustedFormat(), stringsDictInfo: stringsDictInfo())
            return
        }

    case .double(let flags):
        if case let .double(expectedFlags) = expected {
            try validate(flags.size, matches: expectedFlags.size, untrustedFormat: untrustedFormat(), untrustedSpecifier: untrustedSpecifier(), trustedFormat: trustedFormat(), stringsDictInfo: stringsDictInfo())
            return
        }

    default:
        break
    }

    if let innerInfo = try stringsDictInfo() {
        throw CocoaError.formatValidationError("NSStringFormatValueTypeKey value '\(innerInfo.innerFormat!)' for format specifier '\(untrustedSpecifier())' in format string '\(untrustedFormat())' has a kind that is incompatible with '\(trustedFormat())'")
    } else {
        throw CocoaError.formatValidationError("Format specifier '\(untrustedSpecifier())' in format string '\(untrustedFormat())' has a kind that is incompatible with '\(trustedFormat())'")
    }
}

private func validate(
    _ size: ParsedFormatSpec.ArgumentSize,
    matches expected: ParsedFormatSpec.ArgumentSize,
    untrustedFormat: @autoclosure () -> String,
    untrustedSpecifier: @autoclosure() -> String,
    trustedFormat: @autoclosure() -> String,
    stringsDictInfo: @autoclosure () throws(CocoaError) -> StringsDictConfig.InnerFormatInfo?
) throws(CocoaError) {
    // Calling convention dictates rounding up arguments to a minimum size of `long int`
    let sizeBytes = Swift.max(size.bytes, ParsedFormatSpec.ArgumentSize.long.bytes)
    let expectedSizeBytes = Swift.max(expected.bytes, ParsedFormatSpec.ArgumentSize.long.bytes)

    if sizeBytes != expectedSizeBytes {
        if let innerInfo = try stringsDictInfo() {
            throw CocoaError.formatValidationError("NSStringFormatValueTypeKey value '\(innerInfo.innerFormat!)' for format specifier '\(untrustedSpecifier())' in format string '\(untrustedFormat())' has a size that is incompatible with '\(trustedFormat())'")
        } else {
            throw CocoaError.formatValidationError("Format specifier '\(untrustedSpecifier())' in format string '\(untrustedFormat())' has a size that is incompatible with '\(trustedFormat())'")
        }
    }
}
