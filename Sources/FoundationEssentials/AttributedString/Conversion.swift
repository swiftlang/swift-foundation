//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//


#if FOUNDATION_FRAMEWORK
import Darwin
internal import os
@_spi(Unstable) internal import CollectionsInternal
#elseif canImport(_RopeModule)
internal import _RopeModule
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

extension String {
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public init(_ characters: Slice<AttributedString.CharacterView>) {
        self.init(characters._characters)
    }

    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    @_alwaysEmitIntoClient
    public init(_ characters: AttributedString.CharacterView) {
        #if FOUNDATION_FRAMEWORK
        guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, *) else {
            // Forward to the slice overload above, which somehow did end up shipping in
            // the original AttributedString release.
            self.init(characters[...])
            return
        }
        #endif
        self.init(_characters: characters)
    }

    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @usableFromInline
    internal init(_characters: AttributedString.CharacterView) {
        self.init(_characters._characters)
    }
}

#if FOUNDATION_FRAMEWORK

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol ObjectiveCConvertibleAttributedStringKey : AttributedStringKey {
    associatedtype ObjectiveCValue : NSObject

    static func objectiveCValue(for value: Value) throws -> ObjectiveCValue
    static func value(for object: ObjectiveCValue) throws -> Value
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension ObjectiveCConvertibleAttributedStringKey where Value : RawRepresentable, Value.RawValue == Int, ObjectiveCValue == NSNumber {
    public static func objectiveCValue(for value: Value) throws -> ObjectiveCValue {
        return NSNumber(value: value.rawValue)
    }
    public static func value(for object: ObjectiveCValue) throws -> Value {
        if let val = Value(rawValue: object.intValue) {
            return val
        }
        throw CocoaError(.coderInvalidValue)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension ObjectiveCConvertibleAttributedStringKey where Value : RawRepresentable, Value.RawValue == String, ObjectiveCValue == NSString {
    public static func objectiveCValue(for value: Value) throws -> ObjectiveCValue {
        return value.rawValue as NSString
    }
    public static func value(for object: ObjectiveCValue) throws -> Value {
        if let val = Value(rawValue: object as String) {
            return val
        }
        throw CocoaError(.coderInvalidValue)
    }
}

internal struct _AttributeConversionOptions : OptionSet {
    let rawValue: Int
    
    // If an attribute's value(for: ObjectiveCValue) or objectiveCValue(for: Value) function throws, ignore the error and drop the attribute
    static let dropThrowingAttributes = Self(rawValue: 1 << 0)
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeContainer {
    public init(_ dictionary: [NSAttributedString.Key : Any]) {
        // Passing .dropThrowingAttributes causes attributes that throw during conversion to be dropped, so it is safe to do try! here
        try! self.init(dictionary, attributeTable: _loadDefaultAttributes(), options: .dropThrowingAttributes)
    }

    public init<S: AttributeScope>(_ dictionary: [NSAttributedString.Key : Any], including scope: KeyPath<AttributeScopes, S.Type>) throws {
        try self.init(dictionary, including: S.self)
    }
    
    public init<S: AttributeScope>(_ dictionary: [NSAttributedString.Key : Any], including scope: S.Type) throws {
        try self.init(dictionary, attributeTable: S.attributeKeyTypes())
    }
    
    fileprivate init(_ dictionary: [NSAttributedString.Key : Any], attributeTable: [String : any AttributedStringKey.Type], options: _AttributeConversionOptions = []) throws {
        storage = .init()
        for (key, value) in dictionary {
            if let type = attributeTable[key.rawValue] {
                func project<K: AttributedStringKey>(_: K.Type) throws {
                    // We must assume that the value is Sendable here because we are dynamically iterating a scope and the attribute keys do not statically declare the values are Sendable
                    storage[assumingSendable: K.self] = try K._convertFromObjectiveCValue(value as AnyObject)
                }
                do {
                    try project(type)
                } catch let conversionError {
                    if !options.contains(.dropThrowingAttributes) {
                        throw conversionError
                    }
                }
            } // else, attribute is not in provided scope, so drop it
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Dictionary where Key == NSAttributedString.Key, Value == Any {
    public init(_ container: AttributeContainer) {
        // Passing .dropThrowingAttributes causes attributes that throw during conversion to be dropped, so it is safe to do try! here
        try! self.init(container, attributeTable: _loadDefaultAttributes(), options: .dropThrowingAttributes)
    }
    
    public init<S: AttributeScope>(_ container: AttributeContainer, including scope: KeyPath<AttributeScopes, S.Type>) throws {
        try self.init(container, including: S.self)
    }
    
    public init<S: AttributeScope>(_ container: AttributeContainer, including scope: S.Type) throws {
        try self.init(container, attributeTable: S.attributeKeyTypes())
    }
    
    fileprivate init(_ container: AttributeContainer, attributeTable: [String : any AttributedStringKey.Type], options: _AttributeConversionOptions = []) throws {
        self.init()
        for key in container.storage.keys {
            if let type = attributeTable[key] {
                func project<K: AttributedStringKey>(_: K.Type) throws {
                    // We must assume that the value is Sendable here because we are dynamically iterating a scope and the attribute keys do not statically declare the values are Sendable
                    self[NSAttributedString.Key(rawValue: key)] = try K._convertToObjectiveCValue(container.storage[assumingSendable: K.self]!)
                }
                do {
                    try project(type)
                } catch let conversionError {
                    if !options.contains(.dropThrowingAttributes) {
                        throw conversionError
                    }
                }
            }
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension NSAttributedString {
    public convenience init(_ attrStr: AttributedString) {
        // Passing .dropThrowingAttributes causes attributes that throw during conversion to be dropped, so it is safe to do try! here
        try! self.init(attrStr, attributeTable: _loadDefaultAttributes(), options: .dropThrowingAttributes)
    }
    
    public convenience init<S: AttributeScope>(_ attrStr: AttributedString, including scope: KeyPath<AttributeScopes, S.Type>) throws {
        try self.init(attrStr, including: S.self)
    }
    
    public convenience init<S: AttributeScope>(_ attrStr: AttributedString, including scope: S.Type) throws {
        try self.init(attrStr, attributeTable: scope.attributeKeyTypes())
    }
    
    internal convenience init(
        _ attrStr: AttributedString,
        attributeTable: [String : any AttributedStringKey.Type],
        options: _AttributeConversionOptions = []
    ) throws {
        // FIXME: Consider making an NSString subclass backed by a BigString
        let result = NSMutableAttributedString(string: String(attrStr._guts.string))
        // Iterate through each run of the source
        var nsStartIndex = 0
        var stringStart = attrStr._guts.string.startIndex
        for run in attrStr._guts.runs {
            let stringEnd = attrStr._guts.string.utf8.index(stringStart, offsetBy: run.length)
            let utf16Length = attrStr._guts.string.utf16.distance(from: stringStart, to: stringEnd)
            if !run.attributes.isEmpty {
                let range = NSRange(location: nsStartIndex, length: utf16Length)
                let attributes = try Dictionary(AttributeContainer(run.attributes), attributeTable: attributeTable, options: options)
                if !attributes.isEmpty {
                    result.setAttributes(attributes, range: range)
                }
            }
            nsStartIndex += utf16Length
            stringStart = stringEnd
        }
        self.init(attributedString: result)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    public init(_ nsStr: NSAttributedString) {
        // Passing .dropThrowingAttributes causes attributes that throw during conversion to be dropped, so it is safe to do try! here
        try! self.init(nsStr, attributeTable: _loadDefaultAttributes(), options: .dropThrowingAttributes)
    }
    
    public init<S: AttributeScope>(_ nsStr: NSAttributedString, including scope: KeyPath<AttributeScopes, S.Type>) throws {
        try self.init(nsStr, including: S.self)
    }
    
    public init<S: AttributeScope>(_ nsStr: NSAttributedString, including scope: S.Type) throws {
        try self.init(nsStr, attributeTable: S.attributeKeyTypes())
    }
    
    private init(
        _ nsStr: NSAttributedString,
        attributeTable: [String: any AttributedStringKey.Type],
        options: _AttributeConversionOptions = []
    ) throws {
        let string = BigString(nsStr.string)
        var runs = _InternalRuns.Storage()
        var conversionError: Error?

        /// String index addressing the end of the previous run. Unicode scalar aligned.
        var unalignedEnd = string.startIndex
        var alignedEnd = unalignedEnd

        /// The last run we've processed. This isn't appended to `runs` yet in case we need to
        /// merge subsequent runs into this one -- it is easier to do that outside the rope.
        var pendingRun = _InternalRun(length: 0, attributes: .init())

        var hasConstrainedAttributes = false

        // Enumerated ranges are guaranteed to be contiguous and have non-zero length
        nsStr.enumerateAttributes(in: NSMakeRange(0, nsStr.length), options: []) { (nsAttrs, range, stop) in
            let container: AttributeContainer
            do {
                container = try AttributeContainer(nsAttrs, attributeTable: attributeTable, options: options)
            } catch {
                conversionError = error
                stop.pointee = true
                return
            }
            
            let alignedStart = alignedEnd
            unalignedEnd = string.utf16.index(unalignedEnd, offsetBy: range.length)
            // Note: we should be rounding down here, as unaligned indices are supposed to be
            // universally equivalent to the nearest aligned index _downward_. However, this
            // conversion method initially shipped rounding scalar-unaligned indices upwards, so
            // we're stuck with that choice. :-(
            alignedEnd = string.unicodeScalars.index(roundingUp: unalignedEnd)

            let runLength = string.utf8.distance(from: alignedStart, to: alignedEnd)
            guard runLength > 0 else { return }
            
            if pendingRun.length > 0, pendingRun.attributes == container.storage {
                pendingRun.length += runLength
            } else {
                if pendingRun.length > 0 {
                    runs.append(pendingRun)
                }
                pendingRun = _InternalRun(length: runLength, attributes: container.storage)
                if !hasConstrainedAttributes {
                    hasConstrainedAttributes = container.storage.hasConstrainedAttributes
                }
            }
        }
        if let error = conversionError {
            throw error
        }
        if pendingRun.length > 0 {
            runs.append(pendingRun)
        }
        self = AttributedString(Guts(string: string, runs: _InternalRuns(runs)))
        if hasConstrainedAttributes {
            self._guts.adjustConstrainedAttributesForUntrustedRuns()
        }
    }
}

#endif // FOUNDATION_FRAMEWORK

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension String.Index {
    // FIXME: Converting indices between different collection types does not make sense.
    // FIXME: (Indices are meaningless without the collection value to which they belong,
    // FIXME: and this entry point is not given that.)
    // FIXME: This API ought to be deprecated, with clients migrating to e.g. using UTF-8 offsets.
    public init?<S: StringProtocol>(_ sourcePosition: AttributedString.Index, within target: S) {
        let utf8Offset = sourcePosition._value.utf8Offset
        let isTrailingSurrogate = sourcePosition._value._isUTF16TrailingSurrogate
        let i = String.Index(_utf8Offset: utf8Offset, utf16TrailingSurrogate: isTrailingSurrogate)
        self.init(i, within: target)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Index {
    // FIXME: Converting indices between different collection types does not make sense.
    // FIXME: (Indices are meaningless without the collection value to which they belong,
    // FIXME: and this entry point is not given that.)
    // FIXME: This API ought to be deprecated, with clients migrating to e.g. using UTF-8 offsets.
    public init?<S: AttributedStringProtocol>(_ sourcePosition: String.Index, within target: S) {
        guard
            let i = target.__guts.string.index(from: sourcePosition),
            i >= target.startIndex._value,
            i <= target.endIndex._value
        else {
            return nil
        }
        let j = target.__guts.string.index(roundingDown: i)
        guard j == i else { return nil }
        self.init(j, version: target.__guts.version)
    }
}

#if FOUNDATION_FRAMEWORK

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension NSRange {
    public init<R: RangeExpression, S: AttributedStringProtocol>(
        _ region: R,
        in target: S
    ) where R.Bound == AttributedString.Index {
        let range = region.relative(to: target.characters)
        precondition(
            range.lowerBound >= target.startIndex && range.upperBound <= target.endIndex,
            "Range out of bounds")
        let str = target.__guts.string
        let utf16Base = str.utf16.distance(from: str.startIndex, to: target.startIndex._value)
        let utf16Start = str.utf16.distance(from: str.startIndex, to: range.lowerBound._value)
        let utf16Length = str.utf16.distance(
            from: range.lowerBound._value,
            to: range.upperBound._value)
        self.init(location: utf16Start - utf16Base, length: utf16Length)
    }
    
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public init?<S: StringProtocol>(_ markdownSourcePosition: AttributedString.MarkdownSourcePosition, in target: S) {
        let startOffsets: AttributedString.MarkdownSourcePosition.Offsets
        let endOffsets: AttributedString.MarkdownSourcePosition.Offsets
        if let start = markdownSourcePosition.startOffsets, let end = markdownSourcePosition.endOffsets {
            startOffsets = start
            endOffsets = end
        } else {
            guard let offsets = markdownSourcePosition.calculateOffsets(within: target) else {
                self.init(location: NSNotFound, length: NSNotFound)
                return
            }
            startOffsets = offsets.start
            endOffsets = offsets.end
        }
        
        // Since bounds are inclusive, we need to advance to the next UTF-16 scalar
        // If doing so will leave a hanging high surrogate value (i.e., the UTF-8 offset was within a code point), then don't advance
        var actualEndUTF16 = startOffsets.utf16
        if endOffsets.utf8 + 1 == endOffsets.utf8NextCodePoint {
            actualEndUTF16 += endOffsets.utf16CurrentCodePointLength
        }
        self.init(location: startOffsets.utf16, length: actualEndUTF16 - startOffsets.utf16)
    }
}

#endif // FOUNDATION_FRAMEWORK

extension AttributedString {
    /// A dummy collection type whose only purpose is to facilitate a `RangeExpression.relative(to:)`
    /// call that takes a range expression with string indices but needs to work on an
    /// attributed string.
    internal struct _IndexConverterFromString: Collection {
        typealias Index = String.Index
        typealias Element = Index
        
        let _string: BigString
        let _range: Range<BigString.Index>

        init(_ string: BigString, _ range: Range<BigString.Index>) {
            self._string = string
            self._range = range
        }

        subscript(position: String.Index) -> String.Index { position }

        var startIndex: String.Index { Index(_utf8Offset: _range.lowerBound.utf8Offset) }
        var endIndex: String.Index { Index(_utf8Offset: _range.upperBound.utf8Offset) }
        func index(after i: String.Index) -> Index {
            guard let j = _string.index(from: i) else {
                preconditionFailure("Index out of bounds")
            }
            let k = _string.index(after: j)
            return Index(_utf8Offset: k.utf8Offset)
        }
    }
}

extension BigString {
    func index(from stringIndex: String.Index) -> Index? {
        if stringIndex._canBeUTF8 {
            let utf8Offset = stringIndex._utf8Offset
            // Note: ideally we should also check that the result actually addresses a
            // trailing surrogate, when this flag is true.
            let utf16TrailingSurrogate = stringIndex._isUTF16TrailingSurrogate
            let j = BigString.Index(
                _utf8Offset: utf8Offset, utf16TrailingSurrogate: utf16TrailingSurrogate)
            guard j <= endIndex else { return nil }
            // Note: if utf16Delta > 0, ideally we should also check that the result
            // addresses a trailing surrogate.
            return j
        }
        let utf16Offset = stringIndex._abi_encodedOffset
        let utf8Delta = stringIndex._abi_transcodedOffset
        guard utf16Offset <= self.utf16.count else { return nil }
        let j = self.utf16.index(self.startIndex, offsetBy: utf16Offset)
        guard utf8Delta > 0 else { return j }
        // Note: if utf8Delta > 0, ideally we should also check that the result
        // addresses a scalar that actually does have that many continuation bytes.
        return self.utf8.index(j, offsetBy: utf8Delta)
    }

    func stringIndex(from index: Index) -> String.Index? {
        String.Index(
            _utf8Offset: index.utf8Offset,
            utf16TrailingSurrogate: index._isUTF16TrailingSurrogate)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Range where Bound == AttributedString.Index {
#if FOUNDATION_FRAMEWORK
    public init?<S: AttributedStringProtocol>(_ range: NSRange, in string: S) {
        // FIXME: This can return indices addressing trailing surrogates, which isn't a thing
        // FIXME: AttributedString is normally prepared to handle.
        // FIXME: Consider rounding everything down to the nearest scalar boundary.
        guard range.location != NSNotFound else { return nil }
        guard range.location >= 0, range.length >= 0 else { return nil }
        let endOffset = range.location + range.length
        let bstrBounds = Range<BigString.Index>(uncheckedBounds: (string.startIndex._value, string.endIndex._value))
        let bstr = string.__guts.string[bstrBounds]
        guard endOffset <= bstr.utf16.count else { return nil }

        let start = bstr.utf16.index(bstr.startIndex, offsetBy: range.location)
        let end = bstr.utf16.index(start, offsetBy: range.length)

        guard start >= string.startIndex._value, end <= string.endIndex._value else { return nil }
        self.init(uncheckedBounds: (.init(start, version: string.__guts.version), .init(end, version: string.__guts.version)))
    }
#endif // FOUNDATION_FRAMEWORK

    // FIXME: Converting indices between different collection types does not make sense.
    // FIXME: (Indices are meaningless without the collection value to which they belong,
    // FIXME: and this entry point is not given that.)
    // FIXME: This API ought to be deprecated, with clients migrating to using UTF-8 offsets.
    public init?<R: RangeExpression, S: AttributedStringProtocol>(
        _ region: R,
        in attributedString: S
    ) where R.Bound == String.Index {
        if let range = region as? Range<String.Index> {
            self.init(_range: range, in: attributedString)
            return
        }
        // This is a frustrating API to implement -- we need to convert String indices to
        // AttributedString indices, but the only way for us to access the actual indices is to
        // go through `RangeExpression.relative(to:)`, which requires a collection value with a
        // matching index type. So we need to construct a dummy collection type for just that.
        let dummy = AttributedString._IndexConverterFromString(
            attributedString.__guts.string,
            attributedString.startIndex._value ..< attributedString.endIndex._value)
        let range = region.relative(to: dummy)
        self.init(_range: range, in: attributedString)
    }

    // The FIXME above also applies to this internal initializer.
    internal init?(
        _range: Range<String.Index>,
        in attributedString: some AttributedStringProtocol
    ) {
        guard let lower = attributedString.__guts.string.index(from: _range.lowerBound),
              let upper = attributedString.__guts.string.index(from: _range.upperBound),
              lower >= attributedString.startIndex._value,
              upper <= attributedString.endIndex._value
        else {
            return nil
        }
        self.init(uncheckedBounds: (.init(lower, version: attributedString.__guts.version), .init(upper, version: attributedString.__guts.version)))
    }
}

extension AttributedString {
    /// A dummy collection type whose only purpose is to facilitate a `RangeExpression.relative(to:)`
    /// call that takes a range expression with attributed string indices but needs to work on a
    /// regular string.
    internal struct _IndexConverterFromAttributedString: Collection {
        typealias Index = AttributedString.Index
        typealias Element = Index
        
        let string: Substring
        let version: Guts.Version
        
        init(_ string: Substring, version: Guts.Version) {
            self.string = string
            self.version = version
        }
        
        subscript(position: Index) -> Index { position }
        var startIndex: Index { Index(BigString.Index(_utf8Offset: string.startIndex._utf8Offset), version: version) }
        var endIndex: Index { Index(BigString.Index(_utf8Offset: string.endIndex._utf8Offset), version: version) }
        func index(after i: Index) -> Index {
            let j = String.Index(_utf8Offset: i._value.utf8Offset)
            let k = string.index(after: j)
            return Index(BigString.Index(_utf8Offset: k._utf8Offset), version: version)
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Range where Bound == String.Index {
    // FIXME: Converting indices between different collection types does not make sense.
    // FIXME: (Indices are meaningless without the collection value to which they belong,
    // FIXME: and this entry point is not given that.)
    // FIXME: This API ought to be deprecated, with clients migrating to using UTF-8 offsets.
    public init?<R: RangeExpression, S: StringProtocol>(
        _ region: R,
        in string: S
    ) where R.Bound == AttributedString.Index {
        if let range = region as? Range<AttributedString.Index> {
            self.init(_range: range, in: Substring(string))
            return
        }
        let str = Substring(string)
        // Due to the FIXME notes above, we do not have a valid version to supply here since we have no AttributedString, so instead we use a newly created version to maintain existing behavior
        let dummy = AttributedString._IndexConverterFromAttributedString(str, version: AttributedString.Guts.createNewVersion())
        let range = region.relative(to: dummy)
        self.init(_range: range, in: str)
    }

    // The FIXME above also applies to this internal initializer.
    internal init?(
        _range: Range<AttributedString.Index>,
        in string: Substring
    ) {
        // Note: Attributed string indices are usually going to get implicitly round down to
        // (at least) the nearest scalar boundary, but NSRange conversions can still generate
        // indices addressing trailing surrogates, and we want to preserve those here.
        let start = String.Index(
            _utf8Offset: _range.lowerBound._value.utf8Offset,
            utf16TrailingSurrogate: _range.lowerBound._value._isUTF16TrailingSurrogate)
        let end = String.Index(
            _utf8Offset: _range.upperBound._value.utf8Offset,
            utf16TrailingSurrogate: _range.upperBound._value._isUTF16TrailingSurrogate)

        guard string.startIndex <= start, end <= string.endIndex else { return nil }
        self.init(uncheckedBounds: (start, end))
    }

#if FOUNDATION_FRAMEWORK
    // TODO: Support AttributedString markdown in FoundationPreview
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public init?<S: StringProtocol>(_ markdownSourcePosition: AttributedString.MarkdownSourcePosition, in target: S) {
        if let start = markdownSourcePosition.startOffsets, let end = markdownSourcePosition.endOffsets {
            self = target.utf8.index(target.startIndex, offsetBy: start.utf8) ..< target.utf8.index(target.startIndex, offsetBy: end.utf8 + 1)
        } else {
            guard let offsets = markdownSourcePosition.calculateOffsets(within: target) else {
                return nil
            }
            self = target.utf8.index(target.startIndex, offsetBy: offsets.start.utf8) ..< target.utf8.index(target.startIndex, offsetBy: offsets.end.utf8 + 1)
        }
    }
#endif // FOUNDATION_FRAMEWORK
}

