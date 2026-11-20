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
import CoreFoundation
internal import CoreFoundation_Private.ForFoundationOnly
internal import Foundation_Private.NSString
internal import _ForSwiftFoundation
#endif

package struct StringBuilderSource {
    let formatRange: Range<Int>?
    let interpolatedObject: InterpolatedObject?
    let argumentIndex: Int?

    enum InterpolatedObject {
        case object(AnyObject)
        case number(any CVarArg)
        case other
    }

    fileprivate init(formatRange: Range<Int>?, interpolatedObject: InterpolatedObject?, argumentIndex: Int?) {
        self.formatRange = formatRange
        self.interpolatedObject = interpolatedObject
        self.argumentIndex = argumentIndex
    }

    package static var unknown: StringBuilderSource {
        StringBuilderSource(formatRange: nil, interpolatedObject: nil, argumentIndex: nil)
    }

    package static func literal(from formatRange: Range<Int>) -> StringBuilderSource {
        StringBuilderSource(formatRange: formatRange, interpolatedObject: nil, argumentIndex: nil)
    }

    package static func extras(for formatRange: Range<Int>) -> StringBuilderSource {
        StringBuilderSource(formatRange: formatRange, interpolatedObject: nil, argumentIndex: nil)
    }

    package static func object(_ object: AnyObject, for spec: ParsedFormatSpec) -> StringBuilderSource {
        StringBuilderSource(formatRange: spec.sourceRange, interpolatedObject: .object(object), argumentIndex: spec.mainArgNum.map { Int($0) })
    }

    package static func number(_ number: any CVarArg, for spec: ParsedFormatSpec) -> StringBuilderSource {
        StringBuilderSource(formatRange: spec.sourceRange, interpolatedObject: .number(number), argumentIndex: spec.mainArgNum.map { Int($0) })
    }

    package static func other(for spec: ParsedFormatSpec) -> StringBuilderSource {
        StringBuilderSource(formatRange: spec.sourceRange, interpolatedObject: .other, argumentIndex: spec.mainArgNum.map { Int($0) })
    }
}

package protocol StringBuilder: ~Copyable {
    mutating func _append<E, R: ~Copyable>(capacity: Int, encoding: String.Encoding, source: StringBuilderSource, initializingWith initializer: (inout OutputRawSpan) throws(E) -> R) throws(E) -> R
    mutating func _append(copying bytes: RawSpan, encoding: String.Encoding, source: StringBuilderSource)
    mutating func _append(repeating value: UInt8, count: Int, source: StringBuilderSource)
    mutating func _replace(_ contents: Span<UInt8>, with replacement: Span<UInt8>, source: StringBuilderSource)

    func withContents<T: ~Copyable, E>(
        _ body: (StringContents) throws(E) -> T
    ) throws(E) -> T

    mutating func withNestedAppend<T: ~Copyable, E>(
        for range: Range<Int>,
        _ body: (inout Self) throws(E) -> T
    ) throws(E) -> T
}

extension StringBuilder where Self: ~Copyable {
    mutating func withNestedAppend<T: ~Copyable, E>(
        for range: Range<Int>,
        _ body: (inout Self) throws(E) -> T
    ) throws(E) -> T {
        return try body(&self)
    }
}

struct SwiftStringBuilder: ~Copyable, StringBuilder {
    private var content: String
    private var stashedUTF16Scalar: UTF16.CodeUnit?

    init(_ content: String) {
        self.content = content
        stashedUTF16Scalar = nil
    }

    private mutating func stashScalar(_ leading: UTF16.CodeUnit) -> Bool {
        assert(stashedUTF16Scalar == nil)
        if UTF16.isLeadSurrogate(leading) {
            stashedUTF16Scalar = leading
            return true
        }
        return false
    }

    @discardableResult
    private mutating func consumeStashedScalar(with trailing: UTF16.CodeUnit?) -> Bool {
        guard let stashedUTF16Scalar else { return false }
        self.stashedUTF16Scalar = nil
        if let trailing, UTF16.isTrailSurrogate(trailing) {
            content.append(String(decoding: [stashedUTF16Scalar, trailing], as: UTF16.self))
            return true
        } else {
            content.append("\u{FFFD}")
            return false
        }
    }

    consuming func finalize() -> String {
        consumeStashedScalar(with: nil)
        return content
    }

    deinit {
        assert(stashedUTF16Scalar == nil)
    }

    mutating func _append(repeating value: UInt8, count: Int, source: StringBuilderSource) {
        guard count > 0 else { return }
        consumeStashedScalar(with: nil)
        content.unicodeScalars.append(contentsOf: repeatElement(Unicode.Scalar(value), count: count))
    }

    mutating func _append(copying bytes: RawSpan, encoding: String.Encoding, source: StringBuilderSource) {
        guard !bytes.isEmpty else { return }
        var bytes = bytes
        if encoding == .utf16 {
            if consumeStashedScalar(with: bytes.load(fromByteOffset: 0, as: UInt16.self)) {
                bytes = bytes.extracting(droppingFirst: MemoryLayout<UInt16>.size)
            }
            if !bytes.isEmpty, stashScalar(bytes.load(fromByteOffset: bytes.byteCount - 2, as: UInt16.self)) {
                bytes = bytes.extracting(droppingLast: MemoryLayout<UInt16>.size)
            }
        } else {
            consumeStashedScalar(with: nil)
        }
        switch encoding {
        case .ascii, .utf8:
            let utf8Span = UTF8Span(unchecked: Span(viewing: bytes), isKnownASCII: encoding == .ascii)
            let toAppend = String(copying: utf8Span)
            content.append(toAppend)
        case .utf16:
            let toAppend = Span<UInt16>(viewing: bytes).withUnsafeBufferPointer { buffer in
                String(decoding: buffer, as: UTF16.self)
            }
            content.append(toAppend)
        default:
            bytes.withUnsafeBytes { buffer in
                guard let toAppend = String(bytes: buffer, encoding: encoding) else { return }
                content.append(toAppend)
            }
        }
    }

    mutating func _append<E, R: ~Copyable>(capacity: Int, encoding: String.Encoding, source: StringBuilderSource, initializingWith initializer: (inout OutputRawSpan) throws(E) -> R) throws(E) -> R {
        let alignment = switch encoding {
        case .utf16: 2
        case .utf32: 4
        default: 1
        }
        return try withTemporaryAllocation(byteCount: capacity * alignment, alignment: alignment) { outputRawSpan throws(E) in
            defer {
                self._append(copying: outputRawSpan.bytes, encoding: encoding, source: source)
            }
            return try initializer(&outputRawSpan)
        }
    }

    func withContents<T: ~Copyable, E>(_ body: (StringContents) throws(E) -> T) throws(E) -> T{
        try body(StringContents(content.utf8.span))
    }

    mutating func _replace(_ contents: Span<UInt8>, with replacement: Span<UInt8>, source: StringBuilderSource) {
        // TODO: Support replacement in embedded (which does not have firstRange(of:))
        #if !hasFeature(Embedded)
        let contentsStr = String(copying: UTF8Span(unchecked: contents))
        let replacementStr = String(copying: UTF8Span(unchecked: replacement))
        guard let range = content.utf8.firstRange(of: contentsStr.utf8) else { return }
        content.replaceSubrange(range, with: replacementStr)
        #endif
    }
}

#if FOUNDATION_FRAMEWORK && !targetEnvironment(exclaveKit)
struct AttributedStringBuilder: ~Copyable, StringBuilder {
    var content: AttributedString
    private let applyReplacementIndex: Bool
    private let fixups: [String.LocalizationValue.FormatArgument._AttributeFixup?]

    init(applyReplacementIndex: Bool, fixups: [String.LocalizationValue.FormatArgument._AttributeFixup?]) {
        self.content = AttributedString()
        self.applyReplacementIndex = applyReplacementIndex
        self.fixups = fixups
    }

    private mutating func _insertion(for string: String, source: StringBuilderSource) -> AttributedString {
        if let argumentIndex = source.argumentIndex {
            if let fixup = fixups[argumentIndex - 1] {
                switch fixup {
                case .attributeContainer(let attrs):
                    if applyReplacementIndex {
                        return AttributedString(string, attributes: attrs.replacementIndex(argumentIndex))
                    } else {
                        return AttributedString(string, attributes: attrs)
                    }
                case .attributedString(let str, let interpolationOptions):
                    if applyReplacementIndex && !interpolationOptions.contains(.insertAttributesWithoutMerging) {
                        return str.mergingAttributes(AttributeContainer.replacementIndex(argumentIndex), mergePolicy: .keepNew)
                    } else {
                        return str
                    }
                }
            } else {
                return AttributedString(string, attributes: AttributeContainer.replacementIndex(argumentIndex))
            }
        } else {
            return AttributedString(string)
        }
    }

    mutating func _append(repeating value: UInt8, count: Int, source: StringBuilderSource) {
        guard count > 0 else { return }
        let string = String(repeating: Character(Unicode.Scalar(value)), count: count)
        content.append(_insertion(for: string, source: source))
    }

    mutating func _append(copying bytes: RawSpan, encoding: String.Encoding, source: StringBuilderSource) {
        guard !bytes.isEmpty else { return }
        bytes.withUnsafeBytes { buffer in
            let string: String
            switch encoding {
            case .utf8:
                string = String(decoding: buffer, as: UTF8.self)
            case .ascii:
                string = String(decoding: buffer, as: Unicode.ASCII.self)
            case .utf16:
                string = String(decoding: buffer.assumingMemoryBound(to: UInt16.self), as: UTF16.self)
            default:
                guard let decoded = String(bytes: buffer, encoding: encoding) else { return }
                string = decoded
            }
            content.append(_insertion(for: string, source: source))
        }
    }

    mutating func _append<E, R: ~Copyable>(capacity: Int, encoding: String.Encoding, source: StringBuilderSource, initializingWith initializer: (inout OutputRawSpan) throws(E) -> R) throws(E) -> R {
        let alignment = switch encoding {
        case .utf16: 2
        case .utf32: 4
        default: 1
        }
        return try withTemporaryAllocation(byteCount: capacity * alignment, alignment: alignment) { outputRawSpan throws(E) in
            defer {
                self._append(copying: outputRawSpan.bytes, encoding: encoding, source: source)
            }
            return try initializer(&outputRawSpan)
        }
    }

    func withContents<T: ~Copyable, E>(_ body: (StringContents) throws(E) -> T) throws(E) -> T {
        try String(content.characters).withContents(body)

    }

    mutating func _replace(_ contents: Span<UInt8>, with replacement: Span<UInt8>, source: StringBuilderSource) {
        let contentsStr = String(copying: UTF8Span(unchecked: contents))
        let replacementStr = String(copying: UTF8Span(unchecked: replacement))
        guard let range = content.range(of: contentsStr, options: .literal) else { return }
        content.replaceSubrange(range, with: _insertion(for: replacementStr, source: source))
    }
}
#endif

#if FOUNDATION_FRAMEWORK
extension MutableRawSpan {
    fileprivate mutating func convertASCIIToUnicode() {
        assert(self.byteCount % 2 == 0)
        var dstIdx = byteOffsets.endIndex - 2
        var srcIdx = dstIdx / 2
        while srcIdx >= byteOffsets.startIndex {
            storeBytes(of: UInt16(self[srcIdx]), toByteOffset: dstIdx, as: UInt16.self)
            dstIdx -= 2
            srcIdx -= 1
        }
    }
}

struct NSStringBuilder: ~Copyable, StringBuilder {
    private var content: Bytes
    private var unicode: Bool

    init() {
        self.content = Bytes()
        self.unicode = false
    }

    private mutating func makeUnicode() {
        guard !unicode else { return }
        unicode = true
        guard !content.isEmpty else { return }
        content.reserveCapacity(content.count * 2)
        content.edit { outputSpan in
            outputSpan.append(repeating: 0, count: outputSpan.byteCount, as: UInt8.self)
            var mutableBytes = outputSpan.mutableBytes
            mutableBytes.convertASCIIToUnicode()
        }
        unicode = true
    }

    consuming func finalize() -> NSString {
        guard !content.isEmpty else {
            return NSString()
        }
        if !unicode {
            content.append(0) // Ensure ASCII bytes are null terminated (so that the no-copy string returned will behave the same as a CFString with inline ASCII storage which is null terminated)
        }
        let (buffer, count) = content.deconstruct()
        let ptr = buffer.baseAddress!
        if unicode {
            return NSString(charactersNoCopy: ptr.assumingMemoryBound(to: unichar.self), length: count / MemoryLayout<unichar>.size, freeWhenDone: true)
        } else {
            return _CFStringCreateWithNullTerminatedBytesNoCopy(kCFAllocatorDefault, ptr.assumingMemoryBound(to: UInt8.self), count - 1, kCFStringEncodingASCII, kCFAllocatorMalloc)
        }
    }

    mutating func _append<E, R: ~Copyable>(capacity: Int, encoding: String.Encoding, source: StringBuilderSource, initializingWith initializer: (inout OutputRawSpan) throws(E) -> R) throws(E) -> R {
        guard capacity > 0 else {
            var span = OutputRawSpan()
            return try initializer(&span)
        }

        switch (unicode, encoding) {
        case (false, .utf16):
            self.makeUnicode()
            fallthrough
        case (true, .utf16), (false, .ascii):
            return try content.append(addingCount: capacity, initializingWith: initializer)

        case (true, .ascii):
            return try content.append(addingCount: capacity * 2) { span throws(E) in
                defer {
                    let appended = span.byteCount
                    span.append(repeating: 0, count: appended, as: UInt8.self)
                    var mutableBytes = span.mutableBytes
                    mutableBytes.convertASCIIToUnicode()
                }
                return try span.withUnsafeMutableBytes { buffer, initializedCount throws(E) in
                    let shortenedBuffer = buffer.extracting(droppingLast: capacity)
                    var newSpan = OutputRawSpan(buffer: shortenedBuffer, initializedCount: initializedCount)
                    defer {
                        initializedCount = newSpan.finalize(for: shortenedBuffer)
                        newSpan = OutputRawSpan()
                    }
                    return try initializer(&newSpan)
                }
            }

        default:
            // Encoding must be non-ASCII/UTF-16
            return try withTemporaryAllocation(byteCount: capacity, alignment: MemoryLayout<Int64>.alignment) { outputSpan throws(E) in
                defer {
                    self._append(copying: outputSpan.bytes, encoding: encoding, source: source)
                }
                return try initializer(&outputSpan)
            }
        }
    }

    mutating func _append(copying bytes: RawSpan, encoding: String.Encoding, source: StringBuilderSource) {
        guard !bytes.isEmpty else { return }
        switch (unicode, encoding) {
        case (false, .utf16):
            self.makeUnicode()
            fallthrough
        case (true, .utf16), (false, .ascii):
            content.append(copying: bytes)

        case (true, .ascii):
            content.append(addingCount: bytes.byteCount * 2) { span in
                for i in bytes.byteOffsets {
                    span.append(UInt16(bytes[i]), as: UInt16.self)
                }
            }

        case (_, .utf8):
            var utf8Span = UTF8Span(unchecked: Span(viewing: bytes))
            if !unicode && utf8Span.checkForASCII() {
                content.append(copying: bytes)
            } else {
                self.makeUnicode()
                content.append(addingCount: utf8Span.count * 2) { outputSpan in
                    var iterator = utf8Span.makeUnicodeScalarIterator()
                    while let scalar = iterator.next() {
                        for codeUnit in scalar.utf16 {
                            outputSpan.append(codeUnit, as: UInt16.self)
                        }
                    }
                }
            }

        case (false, .macOSRoman), (false, .isoLatin1):
            let allASCII = bytes.withUnsafeBytes { _allASCII($0.assumingMemoryBound(to: UInt8.self)) }
            if allASCII {
                content.append(copying: bytes)
                break
            }
            fallthrough
        default:
            let string = bytes.withUnsafeBytes { String(bytes: $0, encoding: encoding) }
            guard let string else { return }
            self.makeUnicode()
            for scalar in string.utf16 {
                content.append(copying: CollectionOfOne(scalar).span.bytes)
            }
        }
    }

    mutating func _append(repeating value: UInt8, count: Int, source: StringBuilderSource) {
        guard count > 0 else { return }
        if unicode {
            let scalar = UInt16(value)
            content.append(addingCount: count * 2) { span in
                span.append(repeating: scalar, count: count, as: UInt16.self)
            }
        } else {
            content.append(addingCount: count) { span in
                span.append(repeating: value, count: count, as: UInt8.self)
            }
        }
    }

    // Assumes that contents are ASCII bytes
    mutating func _replace(_ contents: Span<UInt8>, with replacement: Span<UInt8>, source: StringBuilderSource) {
        guard let replacementUTF8 = try? UTF8Span(validating: replacement) else { return }
        var replacementRange: Range<Int>?
        if unicode {
            let searchData = Data(capacity: contents.count * 2) {
                for i in contents.indices {
                    $0.append(UInt16(contents[i]), as: UInt16.self)
                }
            }
            replacementRange = contents.firstRange(of: searchData.span)
        } else {
            replacementRange = contents.firstRange(of: contents)
        }

        if let replacementRange {
            let replacementData = switch (!unicode, replacementUTF8.isKnownASCII) {
            case (true, false):
                self.makeUnicode()
                fallthrough
            case (false, false), (true, true):
                Data(copying: replacementUTF8.span.bytes)

            case (false, true):
                Data(capacity: replacementUTF8.span.count) {
                    for i in replacementUTF8.span.indices {
                        $0.append(UInt16(replacementUTF8.span[i]), as: UInt16.self)
                    }
                }
            }
            let replacementBytes = replacementData.bytes
            content.reserveCapacity(content.count + replacementBytes.byteCount - replacementRange.count)
            content.edit { outputSpan in
                outputSpan._replaceSubrange(replacementRange, copying: replacementBytes)
            }
        }
    }

    func withContents<T: ~Copyable, E>(
        _ body: (StringContents) throws(E) -> T
    ) throws(E) -> T {
        return try body(StringContents(content.bytes, encoding: unicode ? .utf16 : .ascii))
    }
}

struct NSStringAppendBuilder: ~Copyable, StringBuilder {
    private var content: NSMutableString

    init(_ content: NSMutableString) {
        self.content = content
    }

    mutating func _append(repeating value: UInt8, count: Int, source: StringBuilderSource) {
        guard count > 0 else { return }
        for _ in 0 ..< count {
            content.append(String(Unicode.Scalar(value)))
        }
    }

    mutating func _append(copying bytes: RawSpan, encoding: String.Encoding, source: StringBuilderSource) {
        guard !bytes.isEmpty else { return }
        switch encoding {
        case .utf16:
            Span<UInt16>(viewing: bytes).withUnsafeBufferPointer { buffer in
                CFStringAppendCharacters(content as CFMutableString, buffer.baseAddress, buffer.count)
            }
        default:
            bytes.withUnsafeBytes { buffer in
                __CFStringAppendBytes(content as CFMutableString, buffer.baseAddress!, buffer.count, CFStringConvertNSStringEncodingToEncoding(encoding.rawValue))
            }
        }
    }

    mutating func _append<E, R: ~Copyable>(capacity: Int, encoding: String.Encoding, source: StringBuilderSource, initializingWith initializer: (inout OutputRawSpan) throws(E) -> R) throws(E) -> R {
        let alignment = switch encoding {
        case .utf16: 2
        case .utf32: 4
        default: 1
        }
        return try withTemporaryAllocation(byteCount: capacity * alignment, alignment: alignment) { outputRawSpan throws(E) in
            defer {
                self._append(copying: outputRawSpan.bytes, encoding: encoding, source: source)
            }
            return try initializer(&outputRawSpan)
        }
    }

    func withContents<T: ~Copyable, E>(_ body: (StringContents) throws(E) -> T) throws(E) -> T {
        try content.withContents(body)

    }

    mutating func _replace(_ contents: Span<UInt8>, with replacement: Span<UInt8>, source: StringBuilderSource) {
        let contentsStr = String(copying: UTF8Span(unchecked: contents))
        let replacementStr = String(copying: UTF8Span(unchecked: replacement))
        let range = content.range(of: contentsStr, options: .literal)
        guard range.location != NSNotFound else { return }
        content.replaceCharacters(in: range, with: replacementStr)
    }
}

#if !targetEnvironment(exclaveKit)
struct NSAttributedStringBuilder: ~Copyable, StringBuilder {
    typealias MetadataCallback = (StringBuilderSource, Range<Int>) -> ()

    var content: NSMutableAttributedString
    var needsInflection: Bool
    var nestedFormatRange: Range<Int>?
    private let formatEncoding: StringContents.Encoding
    private let format: NSAttributedString
    private let applyReplacementIndex: Bool
    private let mergeAttributesFromFormat: Bool
    private let metadataCallback: MetadataCallback?

    init(content: NSMutableAttributedString, format: NSAttributedString, formatEncoding: StringContents.Encoding, applyReplacementIndex: Bool, mergeAttributesFromFormat: Bool, metadataCallback: MetadataCallback? = nil) {
        self.content = content
        self.format = format
        self.formatEncoding = formatEncoding
        self.applyReplacementIndex = applyReplacementIndex
        self.mergeAttributesFromFormat = mergeAttributesFromFormat
        self.metadataCallback = metadataCallback
        self.needsInflection = false
        self.nestedFormatRange = nil
    }

    mutating func withNestedAppend<T: ~Copyable, E>(
        for range: Range<Int>,
        _ body: (inout Self) throws(E) -> T
    ) throws(E) -> T {
        guard self.nestedFormatRange == nil else {
            return try body(&self)
        }
        self.nestedFormatRange = range
        defer { self.nestedFormatRange = nil }
        return try body(&self)
    }

    private func nsRange(for range: Range<Int>) -> NSRange {
        guard formatEncoding == .utf8 else {
            return NSRange(location: range.lowerBound, length: range.count)
        }

        let string = format.string
        let idxStart = string.utf8.index(string.startIndex, offsetBy: range.lowerBound)
        let idxEnd = string.utf8.index(string.startIndex, offsetBy: range.upperBound)
        let utf16Start = string.utf16.distance(from: string.startIndex, to: idxStart)
        let utf16Length = string.utf16.distance(from: idxStart, to: idxEnd)

        return NSRange(location: utf16Start, length: utf16Length)
    }

    private mutating func _insertion(for string: NSString, source: StringBuilderSource) -> NSAttributedString {
        let str: NSMutableAttributedString

        let sourceFormatRange = (nestedFormatRange ?? source.formatRange).map { nsRange(for: $0) }
        if let interpolatedObject = source.interpolatedObject {
            var objectAttrStr: NSAttributedString?
            if case .object(let object) = interpolatedObject {
                objectAttrStr = (object as? NSAttributedString) ?? (object as? NSString)?.__baseAttributedString
            }
            let attributesFromFormat = sourceFormatRange.flatMap {
                if objectAttrStr == nil || mergeAttributesFromFormat {
                    unsafeDowncast(format._nonBridgedAttributes(at: $0.location), to: NSDictionary.self)
                } else {
                    nil
                }
            }

            if let objectAttrStr, let attributesFromFormat {
                str = NSMutableAttributedString._attributedString(withString: objectAttrStr.string as NSString, nonBridgedAttributes: attributesFromFormat)
                if !needsInflection {
                    needsInflection = attributesFromFormat._containsInflectionAttributes()
                }
                assert(str.string.isEqual(string))
                var _needsInflection = ObjCBool(self.needsInflection)
                str._copyAttributes(from: objectAttrStr, range: NSRange(location: 0, length: objectAttrStr.length), overwrite: false, needsInflection: &_needsInflection)
                self.needsInflection = _needsInflection.boolValue
            } else if let attributesFromFormat {
                str = NSMutableAttributedString._attributedString(withString: string, nonBridgedAttributes: attributesFromFormat)
                if !needsInflection {
                    needsInflection = attributesFromFormat._containsInflectionAttributes()
                }
            } else if let objectAttrStr {
                str = objectAttrStr.mutableCopy() as! NSMutableAttributedString
                if !self.needsInflection {
                    self.needsInflection = str._containsInflectionAttributes()
                }
            } else {
                str = NSMutableAttributedString(string: string as String)
            }
        } else {
            if let formatRange = sourceFormatRange {
                if (format.string as NSString).substring(with: formatRange).isEqual(string) {
                    // When interpolating the format string literally, apply attributes run-by-run
                    str = NSMutableAttributedString(string: string as String)
                    var _needsInflection = ObjCBool(self.needsInflection)
                    str._copyAttributes(from: format, range: formatRange, overwrite: true, needsInflection: &_needsInflection)
                    self.needsInflection = _needsInflection.boolValue
                } else {
                    // Otherwise (ex. BIDI isolates around objects), apply attributes from the start of the format range
                    str = NSMutableAttributedString._attributedString(withString: string, nonBridgedAttributes: format._nonBridgedAttributes(at: formatRange.location))
                }
            } else {
                str = NSMutableAttributedString(string: string as String)
            }
        }

        if applyReplacementIndex, let index = source.argumentIndex {
            str.addAttribute(.replacementIndex, value: index, range: NSRange(location: 0, length: str.length))
        }

        metadataCallback?(source, content.length ..< (content.length + str.length))
        return str
    }

    mutating func _append(repeating value: UInt8, count: Int, source: StringBuilderSource) {
        guard count > 0 else { return }
        let string = String(repeating: Character(Unicode.Scalar(value)), count: count)
        content.append(_insertion(for: string as NSString, source: source))
    }

    mutating func _append(copying bytes: RawSpan, encoding: String.Encoding, source: StringBuilderSource) {
        guard !bytes.isEmpty else { return }
        bytes.withUnsafeBytes { buffer in
            let string = if encoding == .utf16 {
                buffer.withMemoryRebound(to: unichar.self) {
                    NSString(charactersNoCopy: UnsafeMutablePointer(mutating: $0.baseAddress!), length: $0.count, freeWhenDone: false)
                }
            } else {
                NSString(bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer.baseAddress!), length: buffer.count, encoding: encoding.rawValue, freeWhenDone: false)
            }
            guard let string else { return }
            content.append(_insertion(for: string, source: source))
        }
    }

    mutating func _append<E, R: ~Copyable>(capacity: Int, encoding: String.Encoding, source: StringBuilderSource, initializingWith initializer: (inout OutputRawSpan) throws(E) -> R) throws(E) -> R {
        let alignment = switch encoding {
        case .utf16: 2
        case .utf32: 4
        default: 1
        }
        return try withTemporaryAllocation(byteCount: capacity * alignment, alignment: alignment) { outputRawSpan throws(E) in
            defer {
                self._append(copying: outputRawSpan.bytes, encoding: encoding, source: source)
            }
            return try initializer(&outputRawSpan)
        }
    }

    func withContents<T: ~Copyable, E>(_ body: (StringContents) throws(E) -> T) throws(E) -> T {
        try content.string.withContents(body)

    }

    mutating func _replace(_ contents: Span<UInt8>, with replacement: Span<UInt8>, source: StringBuilderSource) {
        let contentsStr = String(copying: UTF8Span(unchecked: contents))
        let replacementStr = String(copying: UTF8Span(unchecked: replacement))
        let range = (content.string as NSString).range(of: contentsStr, options: .literal)
        guard range.location != NSNotFound else { return }
        content.replaceCharacters(in: range, with: _insertion(for: replacementStr as NSString, source: source))
    }
}
#endif
#endif
