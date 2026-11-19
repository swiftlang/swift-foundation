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
internal import CoreFoundation_Private
internal import CoreFoundation_Private.ForFoundationOnly
internal import CoreFoundation_Private.CFString
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
@preconcurrency import Android
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif os(Windows)
import CRT
import WinSDK
#elseif os(WASI)
@preconcurrency import WASILibc
#elseif os(Emscripten)
@preconcurrency import EmscriptenLibc
#endif

extension CocoaError {
    static var overflowError: CocoaError {
        CocoaError(.formatting, debugDescription: "Overflow occurred")
    }
}

extension FixedWidthInteger {
    func multipledThrowingOverflow(by factor: Self) throws(CocoaError) -> Self {
        let (result, overflow) = self.multipliedReportingOverflow(by: factor)
        guard !overflow else {
            throw CocoaError.overflowError
        }
        return result
    }

    func addingThrowingOverflow(_ value: Self) throws(CocoaError) -> Self {
        let (result, overflow) = self.addingReportingOverflow(value)
        guard !overflow else {
            throw CocoaError.overflowError
        }
        return result
    }
}

var STRING_FORMATTING_CONTEXT_REPLACEMENT: String { "%@NSCONTEXT" }
private var MAX_STRINGSDICT_LEVEL: Int { 10 }

#if !FOUNDATION_FRAMEWORK
@_spi(SwiftCorelibsFoundation)
public typealias StringFormattingDescriptionFunction = (AnyObject, Locale?) -> String
#else
typealias StringFormattingDescriptionFunction = (AnyObject, Locale?) -> String
#endif
typealias StringFormattingContextDescriptionFunction = (AnyObject, StringContents, Bool, inout Bool) -> String?
package typealias StringCodeUnit = FixedWidthInteger & ConvertibleToBytes & ConvertibleFromBytes

/// State shared by all %@ specifiers of a single format operation
package struct FormatIsolatesState {
    package var usingIsolates = false
    package var checkedOutputCount = 0
    package var checkedOutputEncoding = StringContents.Encoding.utf8
    package var localeIsRightToLeft: Bool?
}

func _AppendFormatCore(
    into output: inout some StringBuilder & ~Copyable,
    descriptionFunc: StringFormattingDescriptionFunction?,
    contextDescriptionFunc: StringFormattingContextDescriptionFunction?,
    locale: Locale?,
    unlocalizedDecimalSeparator: String?,
    stringsDictConfig: StringsDictConfig?,
    pluralizationNumber: String.LocalizationOptions._PluralizationNumber?,
    validFormatSpecifiers: StringContents?,
    formatString: StringContents,
    initialArgPosition: Int8 = 1,
    stringsDictLevel: Int = 0,
    arguments: consuming _VarArgs
) throws(CocoaError) {
    guard stringsDictLevel < MAX_STRINGSDICT_LEVEL else {
        throw CocoaError(.formatting, debugDescription: "Exceeded maximum number of allowed nested stringsdict entry references")
    }

    let maxSpecs = try formatString.count(of: ._percent).multipledThrowingOverflow(by: 2).addingThrowingOverflow(1)
    return try withTemporaryAllocation(of: ParsedFormatSpec.self, capacity: maxSpecs) { specBuffer throws(CocoaError) in
        let hasStringsDictConfigs = try parseFormatSpecifiers(from: formatString, into: &specBuffer, stringsDictConfig: stringsDictConfig)

        var specs = specBuffer.mutableSpan
        let maxArgs = try assignArgumentIndices(for: &specs, startingAt: initialArgPosition)

        if let validFormatSpecifiers {
            try validate(specs: specs.span, in: formatString, match: validFormatSpecifiers, stringsDictConfig: stringsDictConfig)
        }

        return try withTemporaryAllocation(of: ParsedFormatSpec.Kind?.self, capacity: Int(maxArgs)) { argumentKindBuffer throws(CocoaError) in
            argumentKindBuffer.append(repeating: nil, count: argumentKindBuffer.freeCapacity)
            var argumentKinds = argumentKindBuffer.mutableSpan

            try writeArgumentValueKinds(from: specs.span, in: formatString, into: &argumentKinds, stringsDictConfig: stringsDictConfig)

            return try withTemporaryAllocation(of: _VarArgs.Argument?.self, capacity: Int(maxArgs)) { argsBuffer throws(CocoaError) in
                var argumentCopy: _VarArgs? = nil
                if hasStringsDictConfigs {
                    argumentCopy = _VarArgs(copying: arguments)
                }

                readArguments(from: argumentKinds.span, into: &argsBuffer, using: &arguments)
                try formatPieces(
                    of: specs.span,
                    using: argsBuffer.span,
                    from: formatString,
                    locale: locale,
                    unlocalizedDecimalSeparator: unlocalizedDecimalSeparator,
                    descriptionFunc: descriptionFunc,
                    contextDescriptionFunc: contextDescriptionFunc,
                    stringsDictConfig: stringsDictConfig,
                    pluralizationNumber: pluralizationNumber,
                    originalArgs: argumentCopy,
                    validFormatSpecifiers: validFormatSpecifiers,
                    stringsDictLevel: stringsDictLevel,
                    into: &output
                )
            }
        }
    }
}

@discardableResult
func parseFormatSpecifiers(
    from format: StringContents,
    into specs: inout OutputSpan<ParsedFormatSpec>,
    stringsDictConfig: StringsDictConfig?
) throws(CocoaError) -> Bool {
    switch format.encoding {
    case .utf8, .ascii:
        try parseFormatSpecifiers(from: Span<UInt8>(viewing: format.bytes), into: &specs, stringsDictConfig: stringsDictConfig)
    case .utf16:
        try parseFormatSpecifiers(from: Span<UInt16>(viewing: format.bytes), into: &specs, stringsDictConfig: stringsDictConfig)
    }
}

@discardableResult
private func parseFormatSpecifiers<T: StringCodeUnit>(
    from format: Span<T>,
    into specs: inout OutputSpan<ParsedFormatSpec>,
    stringsDictConfig: StringsDictConfig?
) throws(CocoaError) -> Bool {
    var index = format.indices.startIndex
    var hasStringsDictConfigs = false
    while index < format.indices.endIndex {
        let remainingChunk = format.extracting(droppingFirst: index)
        let nextSpecifier = remainingChunk.firstIndex(of: T(UInt8._percent))
        if nextSpecifier != 0 {
            let end = if let nextSpecifier {
                nextSpecifier + index
            } else {
                format.indices.endIndex
            }
            specs.append(ParsedFormatSpec(literalIn: index ..< end))
        }
        if let nextSpecifier {
            var spec = try ParsedFormatSpec(parsingFrom: remainingChunk.extracting(droppingFirst: nextSpecifier))
            spec.sourceRange = (index + nextSpecifier + spec.sourceRange.startIndex) ..< (index + nextSpecifier + spec.sourceRange.endIndex)
            if var config = spec.config {
                config.key = (index + nextSpecifier + config.key.startIndex) ..< (index + nextSpecifier + config.key.endIndex)
                var matchedEntry = false
                #if FOUNDATION_FRAMEWORK && canImport(_FoundationICU)
                if let rule = StringsDictFormattingRule(for: config, in: stringsDictConfig, keyString: config.keyString(in: format)) {
                    matchedEntry = true
                    if rule.usesPluralizationNumber {
                        spec.kind = .pluralizationNumber
                    }
                }
                #endif

                if !matchedEntry {
                    // For keys that don't match an entry, treat it as a literal
                    spec.config = nil
                    spec.kind = .literal
                } else {
                    hasStringsDictConfigs = true
                    spec.config = config
                }
            }
            specs.append(spec)
            index = spec.sourceRange.endIndex
        } else {
            break
        }
    }
    return hasStringsDictConfigs
}

func assignArgumentIndices(
    for specs: inout MutableSpan<ParsedFormatSpec>,
    startingAt initialArgPosition: Int8
) throws(CocoaError) -> Int8 {
    assert(initialArgPosition > 0)
    var maxArgs: Int8 = 0
    var currentArg = initialArgPosition
    for i in specs.indices {
        guard specs[i].kind.usesArgument else { continue }

        if case let .reference(widthArg) = specs[i].widthArg {
            if let widthArg {
                maxArgs = Swift.max(maxArgs, widthArg)
            } else {
                specs[i].widthArg = .reference(currentArg)
                currentArg = try currentArg.addingThrowingOverflow(1)
            }
        }
        if case let .reference(precisionArg) = specs[i].precisionArg {
            if let precisionArg {
                maxArgs = Swift.max(maxArgs, precisionArg)
            } else {
                specs[i].precisionArg = .reference(currentArg)
                currentArg = try currentArg.addingThrowingOverflow(1)
            }
        }
        if let main = specs[i].mainArgNum {
            maxArgs = Swift.max(maxArgs, main)
        } else {
            specs[i].mainArgNum = currentArg
            currentArg = try currentArg.addingThrowingOverflow(1)
        }
    }
    return Swift.max(maxArgs, currentArg)
}

func writeArgumentValueKinds(
    from specs: Span<ParsedFormatSpec>,
    in format: StringContents,
    into argumentKinds: inout MutableSpan<ParsedFormatSpec.Kind?>,
    stringsDictConfig: StringsDictConfig?
) throws(CocoaError) {
    for i in specs.indices {
        let spec = specs[i]
        guard spec.kind.usesArgument else { continue }

        if let mainArg = spec.mainArgNum {
            assert(mainArg > 0)
            argumentKinds[Int(mainArg) - 1] = try spec.kindAccountingForStringsDict(in: format, with: stringsDictConfig)
        }
        if case let .reference(precisionArg) = spec.precisionArg {
            assert(precisionArg != nil && precisionArg! > 0)
            argumentKinds[Int(precisionArg.unsafelyUnwrapped) - 1] = .auxiliaryArgument
        }
        if case let .reference(widthArg) = spec.widthArg {
            assert(widthArg != nil && widthArg! > 0)
            argumentKinds[Int(widthArg.unsafelyUnwrapped) - 1] = .auxiliaryArgument
        }
    }
}

private func readArguments(
    from kinds: Span<ParsedFormatSpec.Kind?>,
    into arguments: inout OutputSpan<_VarArgs.Argument?>,
    using varargs: inout _VarArgs
) {
    for i in kinds.indices {
        let kind = kinds[i]

        if kind == .memoryWrite {
            // We don't support .memoryWrite (%n) so we discard the provided pointer
            // We still need to store a pointer here so that non-%n specifiers using the same position get the value (ex. "%1$d %1$n" should print the decimal value of some pointer), so use a sentinel
            _ = varargs.pop(UnsafeRawPointer?.self)
            arguments.append(.pointer(UnsafeRawPointer(bitPattern: 0xBAD0)))
        } else if kind == nil {
            // If we don't know anything about the argument but need to skip it, assume it's pointer-sized and skip it but record nothing for the argument
            #if FOUNDATION_FRAMEWORK
            if !String.compatibility3 {
                _ = varargs.pop(UnsafeRawPointer?.self)
            }
            #else
            _ = varargs.pop(UnsafeRawPointer?.self)
            #endif

            arguments.append(nil)
        } else if let kind, kind.usesArgument {
            arguments.append(varargs.pop(kind: kind))
        }
    }
}

extension _VarArgs.Argument {
    var auxValue: Int32? {
        return Int32(exactly: self.integerValue)
    }
}

extension ParsedFormatSpec.AuxiliaryArgument {
    fileprivate func resolve(from args: Span<_VarArgs.Argument?>) -> (argValue: Int32?, resolvedValue: Int32?) {
        switch self {
        case .literal(let value):
            return (nil, value)
        case .reference(let index):
            if let value = args[Int(index.unsafelyUnwrapped - 1)]?.auxValue {
                return (value, value >= 0 ? value : nil)
            } else {
                return (nil, nil)
            }
        }
    }
}

private func formatPieces(
    of specs: Span<ParsedFormatSpec>,
    using args: Span<_VarArgs.Argument?>,
    from format: StringContents,
    locale: Locale?,
    unlocalizedDecimalSeparator: String?,
    descriptionFunc: StringFormattingDescriptionFunction?,
    contextDescriptionFunc: StringFormattingContextDescriptionFunction?,
    stringsDictConfig: StringsDictConfig?,
    pluralizationNumber: String.LocalizationOptions._PluralizationNumber?,
    originalArgs: borrowing _VarArgs?,
    validFormatSpecifiers: StringContents?,
    stringsDictLevel: Int,
    into output: inout some StringBuilder & ~Copyable
) throws(CocoaError) {
    try withTemporaryAllocation(of: AnyObject.self, capacity: specs.count) { specContextBuffer throws(CocoaError) in
        var isolates = FormatIsolatesState()
        var mostRecentMainArgNum: Int8 = 0
        for i in specs.indices {
            var spec = specs[i]
            var widthArg: Int32?
            var resolvedWidth: Int32?
            var precisionArg: Int32?
            var resolvedPrecision: Int32?
            var mainArg: _VarArgs.Argument?

            if spec.kind.usesArgument {
                if let widthSpec = spec.widthArg {
                    (widthArg, resolvedWidth) = widthSpec.resolve(from: args)
                    if let arg = widthArg, resolvedWidth == nil {
                        // A negative width means that it is left-justified
                        resolvedWidth = try arg.multipledThrowingOverflow(by: -1)
                        spec.justification = .leftJustified
                    }
                }
                if let precisionSpec = spec.precisionArg {
                    (precisionArg, resolvedPrecision) = precisionSpec.resolve(from: args)
                }
                if let mainArgNum = spec.mainArgNum {
                    mainArg = args[Int(mainArgNum - 1)]
                }
            }

            try formatPiece(
                spec,
                mainArg: mainArg,
                widthArg: widthArg,
                resolvedWidth: resolvedWidth,
                precisionArg: precisionArg,
                resolvedPrecision: resolvedPrecision,
                locale: locale,
                unlocalizedDecimalSeparator: unlocalizedDecimalSeparator,
                descriptionFunc: descriptionFunc,
                contextDescriptionFunc: contextDescriptionFunc,
                stringsDictConfig: stringsDictConfig,
                pluralizationNumber: pluralizationNumber,
                originalArgs: originalArgs,
                validFormatSpecifiers: validFormatSpecifiers,
                stringsDictLevel: stringsDictLevel,
                mostRecentMainArgNum: mostRecentMainArgNum,
                from: format,
                into: &output,
                specContextBuffer: &specContextBuffer,
                isolates: &isolates
            )

            if spec.kind.usesArgument, let num = spec.mainArgNum {
                mostRecentMainArgNum = num
            }
        }

        let contextArgs = specContextBuffer.span
        for i in contextArgs.indices {
            let arg = contextArgs[i]
            let replacement = output.withContents { contents in
                __CFSTRING_IS_CALLING_OUT_TO_AN_OBJECT_FORMAT_ARGUMENT__ {
                    var found = false
                    return contextDescriptionFunc?(arg, contents, true, &found)
                }
            }
            if let replacement {
                output._replace(STRING_FORMATTING_CONTEXT_REPLACEMENT.utf8.span, with: replacement.utf8.span, source: .unknown)
            }
        }
    }
}

#if !(os(Windows) || os(Android)) && (arch(i386) || arch(x86_64))
extension Float80 {
    var lowBits: UInt64 {
        let bytes = CollectionOfOne(self).span.bytes
        return bytes.load(fromByteOffset: 0, as: UInt64.self)
    }

    init(lowBits: UInt64) {
        self = 0
        withUnsafeMutableBytes(of: &self) {
            $0.storeBytes(of: lowBits, as: UInt64.self)
        }
    }
}
#endif

extension _VarArgs.Argument {
    package var integerValue: Int64 {
        switch self {
        case .integer(let integer): integer
        case .double(let double): Int64(bitPattern: double.bitPattern)
        case .pointer(let pointer): Int64(Int(bitPattern: pointer))

#if !(os(Windows) || os(Android)) && (arch(i386) || arch(x86_64))
        case .longDouble(let float80): Int64(bitPattern: float80.lowBits)
#endif
        }
    }

    package var doubleValue: Double {
        switch self {
        case .integer(let integer): Double(bitPattern: UInt64(bitPattern: integer))
        case .double(let double): double
        case .pointer(let pointer): Double(bitPattern: UInt64(UInt(bitPattern: pointer)))

#if !(os(Windows) || os(Android)) && (arch(i386) || arch(x86_64))
        case .longDouble(let float80): Double(float80)
#endif
        }
    }

    package var pointerValue: UnsafeRawPointer? {
        switch self {
        case .integer(let integer): UnsafeRawPointer(bitPattern: Int(truncatingIfNeeded: integer))
        case .double(let double): UnsafeRawPointer(bitPattern: UInt(truncatingIfNeeded: double.bitPattern))
        case .pointer(let pointer): pointer

#if !(os(Windows) || os(Android)) && (arch(i386) || arch(x86_64))
        case .longDouble(let float80): UnsafeRawPointer(bitPattern: UInt(truncatingIfNeeded: float80.lowBits))
#endif
        }
    }

#if !(os(Windows) || os(Android)) && (arch(i386) || arch(x86_64))
    package var longDoubleValue: Float80 {
        switch self {
        case .integer(let integer): Float80(lowBits: UInt64(bitPattern: integer))
        case .double(let double): Float80(lowBits: double.bitPattern)
        case .pointer(let pointer): Float80(lowBits: UInt64(UInt(bitPattern: pointer)))

        case .longDouble(let float80): float80
        }
    }
#endif
}

func formatCharsPiece(
    _ pointer: UnsafeRawPointer,
    precision: Int32?,
    width: Int32?,
    spec: ParsedFormatSpec,
    into output: inout some StringBuilder & ~Copyable
) {
    let boundPointer = pointer.assumingMemoryBound(to: UInt8.self)
    let charsSpan: Span<UInt8>
    if spec.kind == .pascalChars {
        var length = Int(boundPointer.pointee)
        if let precision {
            length = Swift.min(length, Int(precision))
        }
        charsSpan = Span(_unsafeStart: boundPointer.advanced(by: 1), count: length)
    } else if let precision {
        var pointerToTerminator = boundPointer
        while boundPointer.distance(to: pointerToTerminator) < precision && pointerToTerminator.pointee != 0 {
            pointerToTerminator = pointerToTerminator.advanced(by: 1)
        }
        charsSpan = Span(_unsafeStart: boundPointer, count: boundPointer.distance(to: pointerToTerminator))
    } else {
        #if FOUNDATION_FRAMEWORK
        if String.compatibility6(pointer) {
            charsSpan = Span()
        } else {
            charsSpan = Span(_unsafeStart: boundPointer, count: strlen(boundPointer))
        }
        #else
        charsSpan = Span(_unsafeStart: boundPointer, count: strlen(boundPointer))
        #endif

    }

    func appendExtraWidth() {
        if let width, width > charsSpan.count {
            let extraWidth = Int(width) - charsSpan.count
            output._append(repeating: ._space, count: extraWidth, source: .extras(for: spec.sourceRange))
        }
    }

    if spec.justification != .leftJustified {
        appendExtraWidth()
    }
    output._append(copying: charsSpan.bytes, encoding: .system, source: .other(for: spec))
    if spec.justification == .leftJustified {
        appendExtraWidth()
    }
}

private func formatPiece(
    _ spec: ParsedFormatSpec,
    mainArg: _VarArgs.Argument?,
    widthArg: Int32?,
    resolvedWidth: Int32?,
    precisionArg: Int32?,
    resolvedPrecision: Int32?,
    locale: Locale?,
    unlocalizedDecimalSeparator: String?,
    descriptionFunc: StringFormattingDescriptionFunction?,
    contextDescriptionFunc: StringFormattingContextDescriptionFunction?,
    stringsDictConfig: StringsDictConfig?,
    pluralizationNumber: String.LocalizationOptions._PluralizationNumber?,
    originalArgs: borrowing _VarArgs?,
    validFormatSpecifiers: StringContents?,
    stringsDictLevel: Int,
    mostRecentMainArgNum: Int8,
    from format: StringContents,
    into output: inout some StringBuilder & ~Copyable,
    specContextBuffer: inout OutputSpan<AnyObject>,
    isolates: inout FormatIsolatesState
) throws(CocoaError) {
    // Negative width/precision should have already been handled
    if let resolvedWidth {
        assert(resolvedWidth >= 0)
    }
    if let resolvedPrecision {
        assert(resolvedPrecision >= 0)
    }

    switch spec.kind {
    case .integer(let flags), .double(let flags):
        #if FOUNDATION_FRAMEWORK
        let skipLocalizedNumber = String.compatibility5
        #else
        let skipLocalizedNumber = false
        #endif
        #if !NO_FORMATTERS
        if let locale, !flags.style.isEmpty && !skipLocalizedNumber {
            if formatLocalizedNumber(spec: spec, mainArg: mainArg.unsafelyUnwrapped, width: resolvedWidth, precision: resolvedPrecision, locale: locale, into: &output) {
                break
            }
        }
        #endif
        fallthrough
    case .pointer:
        guard let mainArg else {
            preconditionFailure("Unexpected nil mainArg for \(spec.kind) kind")
        }
        let value: _VarArgs.Argument
        switch spec.kind {
        case .integer(let flags):
            if flags.size.normalizingLong == .longLong {
                value = .integer(mainArg.integerValue)
            } else {
                value = .integer(Int64(Int32(truncatingIfNeeded: mainArg.integerValue)))
            }
        case .pointer:
            value = .pointer(mainArg.pointerValue)
        case .double(let flags):
#if !(os(Windows) || os(Android)) && (arch(i386) || arch(x86_64))
            if flags.size == .longDouble {
                value = .longDouble(mainArg.longDoubleValue)
            } else {
                value = .double(mainArg.doubleValue)
            }
#else
            value = .double(mainArg.doubleValue)
#endif
        default:
            fatalError("Unreachable")
        }

        formatUnlocalizedNumber(spec, format: format.extracting(spec.sourceRange), value: value, widthArg: widthArg, resolvedWidth: resolvedWidth, precisionArg: precisionArg, resolvedPrecision: resolvedPrecision, decimalSeparator: unlocalizedDecimalSeparator ?? locale?.decimalSeparator, into: &output)
        break
    case .literal:
        var literalChunk = format.extracting(spec.sourceRange)
        if spec.percentReplacement {
            literalChunk = literalChunk.extracting(droppingFirst: 1)
        }
        output._append(copying: literalChunk.bytes, encoding: literalChunk.encoding.stringEncoding, source: .literal(from: spec.sourceRange))
    case .incomplete:
        assert(resolvedPrecision == nil && resolvedWidth == nil && mainArg == nil)
        break
    case .pascalChars, .chars:
        guard let mainArg else {
            preconditionFailure("Unexpected nil main arg valuefor kind \(spec.kind)")
        }
        guard let pointer = mainArg.pointerValue else {
            output._append(copying: "(null)".utf8.span.bytes, encoding: .ascii, source: .other(for: spec))
            break
        }

        formatCharsPiece(pointer, precision: resolvedPrecision, width: resolvedWidth, spec: spec, into: &output)
    case .singleUnichar:
        guard let mainArg else {
            preconditionFailure("Unexpected nil main argument for single unichar")
        }
        let uint16 = UInt16(truncatingIfNeeded: mainArg.integerValue)
        if let singleByte = UInt8(exactly: uint16), Unicode.ASCII.isASCII(singleByte) {
            output._append(copying: CollectionOfOne(singleByte).span.bytes, encoding: .ascii, source: .other(for: spec))
        } else {
            output._append(copying: CollectionOfOne(uint16).span.bytes, encoding: .utf16, source: .other(for: spec))
        }
    case .unichars:
        guard let mainArg else {
            preconditionFailure("Unexpected nil main argument for unichars")
        }
        guard let pointer = mainArg.pointerValue else {
            output._append(copying: "(null)".utf8.span.bytes, encoding: .ascii, source: .other(for: spec))
            break
        }
        let boundPointer = pointer.assumingMemoryBound(to: UInt16.self)

        var pointerToTerminator = boundPointer
        while (resolvedPrecision == nil || boundPointer.distance(to: pointerToTerminator) < resolvedPrecision!) && pointerToTerminator.pointee != 0 {
            pointerToTerminator = pointerToTerminator.advanced(by: 1)
        }
        let charsSpan = Span(_unsafeStart: boundPointer, count: boundPointer.distance(to: pointerToTerminator))

        func appendExtraWidth() {
            if let resolvedWidth, resolvedWidth > charsSpan.count {
                let extraWidth = Int(resolvedWidth) - charsSpan.count
                output._append(repeating: ._space, count: extraWidth, source: .extras(for: spec.sourceRange))
            }
        }

        if spec.justification != .leftJustified {
            appendExtraWidth()
        }
        output._append(copying: charsSpan.bytes, encoding: .utf16, source: .other(for: spec))
        if spec.justification == .leftJustified {
            appendExtraWidth()
        }
    case .object, .pluralizationNumber:
        if let config = spec.config {
            #if FOUNDATION_FRAMEWORK && canImport(_FoundationICU)
            let mainArg: _VarArgs.Argument? = if spec.kind == .pluralizationNumber {
                if let pluralizationNumber {
                    switch pluralizationNumber {
                    case .specific(let int):
                        .integer(Int64(int))
                    case .unknown:
                        .integer(Int64(NSNotFound))
                    }
                } else {
                    nil
                }
            } else {
                mainArg
            }
            try formatStringsDictPiece(
                spec: spec,
                mainArg: mainArg,
                rule: StringsDictFormattingRule(for: config, in: stringsDictConfig, keyString: config.keyString(in: format)).unsafelyUnwrapped,
                precision: resolvedPrecision,
                width: resolvedWidth,
                locale: locale,
                unlocalizedDecimalSeparator: unlocalizedDecimalSeparator,
                descriptionFunc: descriptionFunc,
                contextDescriptionFunc: contextDescriptionFunc,
                stringsDictConfig: stringsDictConfig,
                pluralizationNumber: pluralizationNumber,
                originalArgs: originalArgs!,
                validFormatSpecifiers: validFormatSpecifiers,
                stringsDictLevel: stringsDictLevel,
                mostRecentMainArgNum: mostRecentMainArgNum,
                into: &output
            )
            #else
            preconditionFailure("Unexpected stringsdict object when stringsdicts are not supported")
            #endif
        } else {
            guard let mainArg else {
                preconditionFailure("Unexpected uninitialized main argument for kind \(spec.kind)")
            }

            guard let pointer = mainArg.pointerValue else {
                output._append(copying: "(null)".utf8.span.bytes, encoding: .ascii, source: .other(for: spec))
                break
            }

            formatObjectPiece(
                mainArgPointer: pointer,
                precision: resolvedPrecision,
                width: resolvedWidth,
                spec: spec,
                locale: locale,
                descriptionFunc: descriptionFunc,
                contextDescriptionFunc: contextDescriptionFunc,
                format: format,
                trailingFormat: format.extracting(droppingFirst: spec.sourceRange.upperBound),
                into: &output,
                specContextBuffer: &specContextBuffer,
                isolates: &isolates
            )
        }
        break
    case .memoryWrite:
        // Do nothing: %n is ignored and it is stripped from the output
        break
    }
}

#if FOUNDATION_FRAMEWORK || hasFeature(Embedded)
func formatLocalizedNumber(spec: ParsedFormatSpec, mainArg: _VarArgs.Argument, width: Int32?, precision: Int32?, locale: Locale, into output: inout some StringBuilder & ~Copyable) -> Bool {
    formatLocalizedNumber_localized(spec: spec, mainArg: mainArg, width: width, precision: precision, locale: locale, into: &output)
}
#else
dynamic package func formatLocalizedNumber(spec: ParsedFormatSpec, mainArg: _VarArgs.Argument, width: Int32?, precision: Int32?, locale: Locale, into output: inout some StringBuilder & ~Copyable) -> Bool {
    false
}
#endif

#if FOUNDATION_FRAMEWORK && canImport(_FoundationICU)
private func formatStringsDictPiece(
    spec: ParsedFormatSpec,
    mainArg: _VarArgs.Argument?,
    rule: StringsDictFormattingRule,
    precision: Int32?,
    width: Int32?,
    locale: Locale?,
    unlocalizedDecimalSeparator: String?,
    descriptionFunc: StringFormattingDescriptionFunction?,
    contextDescriptionFunc: StringFormattingContextDescriptionFunction?,
    stringsDictConfig: StringsDictConfig?,
    pluralizationNumber: String.LocalizationOptions._PluralizationNumber?,
    originalArgs: borrowing _VarArgs,
    validFormatSpecifiers: StringContents?,
    stringsDictLevel: Int,
    mostRecentMainArgNum: Int8,
    into output: inout some StringBuilder & ~Copyable
) throws(CocoaError) {
    let resolution = try mainArg.flatMap { mainArg throws(CocoaError) -> StringsDictFormattingRule.Resolution? in
        let kind: ParsedFormatSpec.Kind
        if let formatValueType = rule.formatValueType {
            // TODO: Should this come from the earlier parse cache?
            kind = try ParsedFormatSpec(parsingFrom: formatValueType.utf8.span, withoutPercent: true).kind

        } else {
            // Pluralization number rule, use an integer kind
            kind = .integer(ParsedFormatSpec.NumericFlags(size: .long, style: .init(), sign: .negativeSignOnly))
        }
        return rule.resolve(specKind: kind, object: mainArg, locale: locale)
    }

    let innerFormat: String
    switch resolution {
    case nil:
        output._append(copying: "(null)".utf8.span.bytes, encoding: .ascii, source: .other(for: spec))
        return
    case .literal(let text):
        output._append(copying: text.utf8.span.bytes, encoding: .utf8, source: .object(text as NSString, for: spec))
        return
    case .format(let format):
        innerFormat = format
    }

    let nestedInitialArgs: Int8
    if let argNum = spec.mainArgNum {
        // If this spec has an argument (normal case), start inner formatting at that argument
        nestedInitialArgs = argNum
    } else {
        // If this spec has no argument (like a pluralization number based spec), find the most recent spec that has an argument and begin inner formatting after that arguments
        nestedInitialArgs = try mostRecentMainArgNum.addingThrowingOverflow(1)
    }

    try output.withNestedAppend(for: spec.sourceRange) { output throws(CocoaError) in
        let copiedArgs = _VarArgs(copying: originalArgs)
        try _AppendFormatCore(
            into: &output,
            descriptionFunc: descriptionFunc,
            contextDescriptionFunc: contextDescriptionFunc,
            locale: locale,
            unlocalizedDecimalSeparator: unlocalizedDecimalSeparator,
            stringsDictConfig: stringsDictConfig,
            pluralizationNumber: nil, // Pluralization numbers can only apply to top-level rules
            validFormatSpecifiers: validFormatSpecifiers,
            formatString: StringContents(innerFormat.utf8.span),
            initialArgPosition: nestedInitialArgs,
            stringsDictLevel: stringsDictLevel + 1,
            arguments: copiedArgs
        )
    }
}
#endif

// A sentinel function in backtraces to indicate when we are performing a callout to a pointer passed in as a %@
// These pointers be invalid and the sentinel frame helps crash logs clearly indicate the bad pointer is not from Foundation itself but rather the caller of string formatting
// Avoid inlining + optimizing to ensure the frame is always present in backtraces (avoiding tail call optimization)
@inline(never)
@_optimize(none)
private func __CFSTRING_IS_CALLING_OUT_TO_AN_OBJECT_FORMAT_ARGUMENT__(_ operation: () -> (String?)) -> String? {
    operation()
}

private func formatObjectPiece(
    mainArgPointer: UnsafeRawPointer,
    precision: Int32?,
    width: Int32?,
    spec: ParsedFormatSpec,
    locale: Locale?,
    descriptionFunc: StringFormattingDescriptionFunction?,
    contextDescriptionFunc: StringFormattingContextDescriptionFunction?,
    format: StringContents,
    trailingFormat: StringContents,
    into output: inout some StringBuilder & ~Copyable,
    specContextBuffer: inout OutputSpan<AnyObject>,
    isolates: inout FormatIsolatesState) {
    var description: String? = nil
    if let contextDescriptionFunc {
        var found = false
        let object = unsafeBitCast(mainArgPointer, to: AnyObject.self)
        description = __CFSTRING_IS_CALLING_OUT_TO_AN_OBJECT_FORMAT_ARGUMENT__ {
            contextDescriptionFunc(object, format, false, &found)
        }
        if found {
            description = STRING_FORMATTING_CONTEXT_REPLACEMENT
            specContextBuffer.append(object)
        }
    }

    if description == nil {
        if let descriptionFunc {
            description = __CFSTRING_IS_CALLING_OUT_TO_AN_OBJECT_FORMAT_ARGUMENT__ {
                descriptionFunc(unsafeBitCast(mainArgPointer, to: AnyObject.self), locale)
            }
        } else {
            #if FOUNDATION_FRAMEWORK
            let cfRef = unsafeBitCast(mainArgPointer, to: CFTypeRef.self)
            let nsLocale = locale as NSLocale?
            description = withExtendedLifetime(nsLocale) {
                let cfDict = unsafeBitCast(nsLocale, to: CFDictionary?.self)
                return __CFSTRING_IS_CALLING_OUT_TO_AN_OBJECT_FORMAT_ARGUMENT__ {
                    __CFCopyFormattingDescription(cfRef, cfDict) as String?
                }
            }
            #endif
            if description == nil {
                description = __CFSTRING_IS_CALLING_OUT_TO_AN_OBJECT_FORMAT_ARGUMENT__ {
                    #if FOUNDATION_FRAMEWORK
                    let cfRef = unsafeBitCast(mainArgPointer, to: CFTypeRef.self)
                    return CFCopyDescription(cfRef) as String?
                    #elseif !hasFeature(Embedded)
                    let obj = unsafeBitCast(mainArgPointer, to: AnyObject.self)
                    return String(describing: obj)
                    #else
                    return "<object \(mainArgPointer)>"
                    #endif
                }
            }
        }
    }

    guard let description else {
        output._append(copying: "(null description)".utf8.span.bytes, encoding: .ascii, source: .other(for: spec))
        return
    }

    appendObjectValue(description, producedFrom: unsafeBitCast(mainArgPointer, to: AnyObject.self), for: spec, locale: locale, trailingFormat: trailingFormat, isolates: &isolates, into: &output)
}

#if FOUNDATION_FRAMEWORK || hasFeature(Embedded)
func appendObjectValue(_ value: String, producedFrom object: AnyObject, for spec: ParsedFormatSpec, locale: Locale?, trailingFormat: StringContents, isolates: inout FormatIsolatesState, into output: inout some StringBuilder & ~Copyable) {
    appendObjectValue_localized(value, producedFrom: object, for: spec, locale: locale, trailingFormat: trailingFormat, isolates: &isolates, into: &output)
}
#else
dynamic package func appendObjectValue(_ value: String, producedFrom object: AnyObject, for spec: ParsedFormatSpec, locale: Locale?, trailingFormat: StringContents, isolates: inout FormatIsolatesState, into output: inout some StringBuilder & ~Copyable) {
    output._append(copying: value.utf8.span.bytes, encoding: .utf8, source: .object(object, for: spec))
}
#endif
