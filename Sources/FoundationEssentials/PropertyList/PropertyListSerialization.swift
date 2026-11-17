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

#if !FOUNDATION_FRAMEWORK && !hasFeature(Embedded)

/// Reads property lists into Swift values.
///
/// The values are `String`, `Int` (or `Int64` when the value does not fit in `Int`), `UInt64` (above `Int64.max`), `Double`, `Bool`, `Date`, `Data`, `[Any]` and `[String : Any]`. These are different from the Objective-C class:
///
/// - The containers and the strings are Swift values, so the mutability options have no effect.
/// - A null in a binary property list is the string `"$null"`.
/// - A set in a binary property list is an error.
open class PropertyListSerialization {
    public struct MutabilityOptions : OptionSet, Sendable {
        public let rawValue : UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        public static let mutableContainers = MutabilityOptions(rawValue: 1)
        public static let mutableContainersAndLeaves = MutabilityOptions(rawValue: 2)
    }

    public typealias PropertyListFormat = PropertyListDecoder.PropertyListFormat
    public typealias ReadOptions = MutabilityOptions

    public init() {}

    /// Reads a binary, XML or OpenStep property list from `data`. The mutability options in `opt` have no effect.
    open class func propertyList(from data: Data, options opt: ReadOptions = [], format: UnsafeMutablePointer<PropertyListFormat>?) throws -> Any {
        guard !data.isEmpty else {
            throw CocoaError(.propertyListReadCorrupt, userInfo: [NSDebugDescriptionErrorKey : "Cannot parse a NULL or zero-length data"])
        }
        let (value, readFormat) = try _readPropertyList(from: data)
        unsafe format?.pointee = readFormat
        return value
    }

    private static func _readPropertyList(from data: Data) throws -> (Any, PropertyListFormat) {
        do {
            let options = PropertyListValueOptions(makeUID: { _PropertyListUID(value: $0) })
            let (value, format) = try PropertyListValueReader.read(data, options: options, makeFilter: { NullFilter() })
            if let value {
                return (value, format)
            }
            return (try PropertyListDecoder.parseOpenStepPropertyList(from: data), .openStep)
        } catch let error as BPlistError {
            throw error.cocoaError
        } catch let error as XMLPlistError {
            throw error.cocoaError
        } catch let error as OpenStepPlistError {
            throw error.cocoaError
        } catch let error as DecodingError {
            // The encoding detection throws a `DecodingError`.
            var description = "The data is not a valid property list."
            if case .dataCorrupted(let context) = error {
                description = context.debugDescription
            }
            throw CocoaError(.propertyListReadCorrupt, userInfo: [NSDebugDescriptionErrorKey : description])
        }
    }
}

@available(*, unavailable)
extension PropertyListSerialization : @unchecked Sendable { }

/// A keyed archiver UID that `PropertyListSerialization` read from a property list.
@_spi(SwiftCorelibsFoundation)
public struct _PropertyListUID : Hashable, Sendable {
    public let value: UInt32

    public init(value: UInt32) {
        self.value = value
    }
}

#endif // !FOUNDATION_FRAMEWORK && !hasFeature(Embedded)
