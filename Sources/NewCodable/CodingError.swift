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

public enum CodingError {
    public struct Underlying: Error, Equatable, Sendable {
        public let description: String
        public let debugDescription: String?
        
        public init(description: String, debugDescription: String? = nil) {
            self.description = description
            self.debugDescription = debugDescription
        }
    }
    
//    public typealias Decoding = any Error
    public typealias Decoding = _Decoding

    @frozen
    public struct _Decoding: Error, Sendable {
        @usableFromInline
        final class Internals: Sendable {
            public let kind: Kind
            public let codingPath: CodingPath?
            public let userDebugDescription: String?
            public let underlyingError: CodingError.Underlying?
            public let sourceLocation: SourceLocation?
            
            public init(kind: Kind, codingPath: CodingPath? = nil, debugDescription: String? = nil, underlyingError: CodingError.Underlying? = nil, sourceLocation: SourceLocation? = nil) {
                self.kind = kind
                self.codingPath = codingPath
                self.userDebugDescription = debugDescription
                self.underlyingError = underlyingError
                self.sourceLocation = sourceLocation
            }
        }
        let internals: Internals
        
        public init(kind: Kind, codingPath: CodingPath? = nil, debugDescription: String? = nil, underlyingError: CodingError.Underlying? = nil, sourceLocation: SourceLocation? = nil) {
            self.internals = Internals(kind: kind, codingPath: codingPath, debugDescription: debugDescription, underlyingError: underlyingError, sourceLocation: sourceLocation)
        }
        
        public var kind: Kind { internals.kind }
        public var codingPath: CodingPath? { internals.codingPath }
        public var userDebugDescription: String? { internals.userDebugDescription }
        public var underlyingError: CodingError.Underlying? { internals.underlyingError }
        public var sourceLocation: SourceLocation? { internals.sourceLocation }
        
        public enum Kind: Sendable {
            case typeMismatch(expectedTypeDescription: String, actualValueDescription: String)
            case keyNotFound(expectedKey: CodingPath.Component)
            case valueNotFound(expectedTypeDescription: String)
            case unknownKey(CodingPath.Component)
            case dataCorrupted
            case unsupportedType(expectedTypeDescription: String)
            case custom(description: String)
        }
        
        public struct SourceLocation: Equatable, Sendable {
            public let line: Int?
            public let column: Int?
            public let byteOffset: Int?
            
            public init(line: Int? = nil, column: Int? = nil, byteOffset: Int? = nil) {
                self.line = line
                self.column = column
                self.byteOffset = byteOffset
            }
        }
    }
    
//    public typealias Encoding = any Error
    public typealias Encoding = _Encoding
    
    @frozen
    public struct _Encoding: Error, Sendable {
        @usableFromInline
        final class Internals: Sendable {
        public let kind: Kind
        public let codingPath: CodingPath?
        public let userDebugDescription: String?
        public let underlyingError: CodingError.Underlying?
        
        public init(kind: Kind, codingPath: CodingPath? = nil, debugDescription: String? = nil, underlyingError: CodingError.Underlying? = nil) {
            self.kind = kind
            self.codingPath = codingPath
            self.userDebugDescription = debugDescription
            self.underlyingError = underlyingError
        }
        }
        let internals: Internals
        
        public var kind: Kind { internals.kind }
        public var codingPath: CodingPath? { internals.codingPath }
        public var userDebugDescription: String? { internals.userDebugDescription }
        public var underlyingError: CodingError.Underlying? { internals.underlyingError }
        
        public init(kind: Kind, codingPath: CodingPath? = nil, debugDescription: String? = nil, underlyingError: CodingError.Underlying? = nil) {
            self.internals = .init(kind: kind, codingPath: codingPath, debugDescription: debugDescription, underlyingError: underlyingError)
        }
        
        public enum Kind: Equatable, Sendable {
            case invalidValue(valueDescription: String)
            case unsupportedType(expectedTypeDescription: String)
            case custom(description: String)
        }
    }
}

extension CodingError._Decoding {
    public func addingIfNecessary(codingPath: CodingPath) -> Self {
        .init(kind: self.kind, codingPath: self.codingPath ?? codingPath, debugDescription: self.userDebugDescription, underlyingError: self.underlyingError, sourceLocation: self.sourceLocation)
    }
}

extension CodingError._Encoding {
    public func addingIfNecessary(codingPath: CodingPath) -> Self {
        .init(kind: self.kind, codingPath: self.codingPath ?? codingPath, debugDescription: self.userDebugDescription, underlyingError: self.underlyingError)
    }
}

extension CodingError {
    // TODO: Should we be throw errors describing decoded values?
    public static func typeMismatch<Expected, Value>(
        expectedType: Expected.Type,
        actualValue: Value,
    at codingPath: CodingPath? = nil,
        sourceLocation: CodingError._Decoding.SourceLocation? = nil
    ) -> _Decoding {
        typeMismatch(
            expectedTypeDescription: String(describing: Expected.self),
            actualValueDescription: String(describing: actualValue),
            at: codingPath,
            sourceLocation: sourceLocation)
    }
    
    public static func typeMismatch(
        expectedTypeDescription: String,
        actualValueDescription: String,
        at codingPath: CodingPath? = nil,
        sourceLocation: CodingError._Decoding.SourceLocation? = nil
    ) -> _Decoding {
        .init(
            kind: .typeMismatch(
                expectedTypeDescription: expectedTypeDescription,
                actualValueDescription: actualValueDescription
            ),
            codingPath: codingPath,
            debugDescription: "Expected to decode \(expectedTypeDescription) but found \(actualValueDescription) instead",
            underlyingError: nil,
            sourceLocation: sourceLocation
        )
    }
    
    public static func keyNotFound(
        _ key: CodingPath.Component,
        at codingPath: CodingPath? = nil,
        sourceLocation: CodingError._Decoding.SourceLocation? = nil
    ) -> _Decoding {
        keyNotFound(
            key.description,
            at: codingPath,
            sourceLocation: sourceLocation
        )
    }
    
    public static func keyNotFound(
        _ key: String,
        at codingPath: CodingPath? = nil,
        sourceLocation: CodingError._Decoding.SourceLocation? = nil
    ) -> _Decoding {
        .init(
            kind: .keyNotFound(
                expectedKey: .stringKey(key)
            ),
            codingPath: codingPath,
            debugDescription: "No value associated with key \"\(key)\".",
            underlyingError: nil,
            sourceLocation: sourceLocation
        )
    }
    
    public static func unknownKey(
        _ key: UTF8Span,
        at codingPath: CodingPath? = nil,
        sourceLocation: CodingError._Decoding.SourceLocation? = nil
    ) -> _Decoding {
        .init(
            kind: .unknownKey(
                .stringKey(String(copying: key))
            ),
            codingPath: codingPath,
            debugDescription: nil,
            underlyingError: nil,
            sourceLocation: sourceLocation
        )
    }
    
    public static func valueNotFound<Expected>(
        expectedType: Expected,
        at codingPath: CodingPath? = nil,
        debugDescription: String? = nil,
        sourceLocation: CodingError._Decoding.SourceLocation? = nil
    ) -> _Decoding {
        valueNotFound(
            expectedTypeDescription: String(describing: Expected.self),
            at: codingPath,
            debugDescription: debugDescription,
            sourceLocation: sourceLocation
        )
    }
    
    public static func valueNotFound(
        expectedTypeDescription: String,
        at codingPath: CodingPath? = nil,
        debugDescription: String? = nil,
        sourceLocation: CodingError._Decoding.SourceLocation? = nil
    ) -> _Decoding {
        .init(
            kind: .valueNotFound(
                expectedTypeDescription: expectedTypeDescription
            ),
            codingPath: codingPath,
            debugDescription: debugDescription,
            sourceLocation: sourceLocation
        )
    }
    
    public static func dataCorrupted(
        at codingPath: CodingPath? = nil,
        debugDescription: String? = nil,
        underlyingError: Underlying? = nil,
        sourceLocation: CodingError._Decoding.SourceLocation? = nil
    ) -> _Decoding {
        .init(
            kind: .dataCorrupted,
            codingPath: codingPath,
            debugDescription: debugDescription,
            underlyingError: underlyingError,
            sourceLocation: sourceLocation
        )
    }
    
    public static func invalidEncodedValue(
        valueDescription: String,
        at codingPath: CodingPath? = nil,
        debugDescription: String? = nil,
        underlyingError: Underlying? = nil,
    ) -> _Encoding {
        .init(
            kind: .invalidValue(valueDescription: valueDescription),
            codingPath: codingPath,
            debugDescription: debugDescription,
            underlyingError: underlyingError
        )
    }
    
    public static func unsupportedDecodingType(_ description: String) -> CodingError._Decoding {
        .unsupportedType(description)
    }
    
    public static func unsupportedEncodingType(_ description: String) -> CodingError._Encoding {
        .unsupportedType(description)
    }
}

extension CodingError._Encoding {
    static func unsupportedType(_ description: String) -> CodingError._Encoding {
        return .init(kind: .unsupportedType(expectedTypeDescription: description))
    }
}

extension CodingError._Decoding {
    static func unsupportedType(_ description: String) -> CodingError._Decoding {
        return .init(kind: .unsupportedType(expectedTypeDescription: description))
    }
}

extension CodingError._Decoding.SourceLocation {
    public static func countingLinesAndColumns(
      upTo location: Int, in fullSource: borrowing RawSpan
    ) -> Self {
        precondition(0 <= location && location <= fullSource.byteCount)
        var index = 0
        var line = 1
        var col = 0
        let end = min(location + 1, fullSource.byteCount)
        while index < end {
            switch fullSource._loadByteUnchecked(index){
            case ._return:
                let next = index + 1
                if next <= location, fullSource._loadByteUnchecked(next) == ._newline {
                    index = next
                }
                line += 1
                col = 0
            case ._newline:
                line += 1
                col = 0
            default:
                col += 1
            }
            index &+= 1
        }
        return Self(line: line, column: col, byteOffset: location)
    }
}

extension CodingError._Decoding.SourceLocation: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = ""
        var space: String {
            result.count == 0 ? "" : " "
        }
        if let line {
            result += "Line: \(line)"
        }
        if let column {
            result += space + "Column: \(column)"
        }
        if let byteOffset {
            result += space + "Offset: \(byteOffset)"
        }
        return result
    }
}

extension CodingError._Decoding: CustomDebugStringConvertible {
    public var debugDescription: String {
        var components: [String] = []
        
        // Add the main error kind description
        switch kind {
        case .typeMismatch(let expectedTypeDescription, let actualValueDescription):
            components.append("Type mismatch: expected \(expectedTypeDescription), found \(actualValueDescription)")
        case .keyNotFound(let expectedKey):
            components.append("Key not found: \(expectedKey)")
        case .valueNotFound(let expectedTypeDescription):
            components.append("Value not found for type: \(expectedTypeDescription)")
        case .unknownKey(let key):
            components.append("Unknown key: \(key)")
        case .dataCorrupted:
            components.append("Data corrupted")
        case .unsupportedType(let expectedTypeDescription):
            components.append("Unsupported type: \(expectedTypeDescription)")
        case .custom(let description):
            components.append("Custom error: \(description)")
        }
        
        // Add coding path if available
        if let codingPath = codingPath {
            components.append("at path: \(codingPath)")
        }
        
        // Add debug description if available and different from the main description
        if let debugDesc = self.userDebugDescription, !debugDesc.isEmpty {
            components.append("(\(debugDesc))")
        }
        
        // Add source location if available
        if let sourceLocation = sourceLocation {
            components.append("at \(sourceLocation.debugDescription)")
        }
        
        // Add underlying error if available
        if let underlyingError = underlyingError {
            components.append("underlying: \(underlyingError.description)")
        }
        
        return "DecodingError: \(components.joined(separator: ", "))"
    }
}

extension CodingError._Encoding: CustomDebugStringConvertible {
    public var debugDescription: String {
        var components: [String] = []
        
        // Add the main error kind description
        switch kind {
        case .invalidValue(let valueDescription):
            components.append("Invalid value: \(valueDescription)")
        case .unsupportedType(let expectedTypeDescription):
            components.append("Unsupported type: \(expectedTypeDescription)")
        case .custom(let description):
            components.append("Custom error: \(description)")
        }
        
        // Add coding path if available
        if let codingPath = codingPath {
            components.append("at path: \(codingPath)")
        }
        
        // Add debug description if available and different from the main description
        if let debugDesc = self.userDebugDescription, !debugDesc.isEmpty {
            components.append("(\(debugDesc))")
        }
        
        // Add underlying error if available
        if let underlyingError = underlyingError {
            components.append("underlying: \(underlyingError.description)")
        }
        
        return "EncodingError: \(components.joined(separator: ", "))"
    }
}
