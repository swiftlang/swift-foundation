//===----------------------------------------------------------------------===//
 //
 // This source file is part of the Swift Collections open source project
 //
 // Copyright (c) 2022 Apple Inc. and the Swift project authors
 // Licensed under Apache License v2.0 with Runtime Library Exception
 //
 // See https://swift.org/LICENSE.txt for license information
 //
 //===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
/// Describes errors within the Cocoa error domain, including errors that Foundation throws.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct CocoaError : _BridgedStoredNSError {
    // On Darwin, CocoaError is backed by `NSError`.
    public let _nsError: NSError
    
    public init(_nsError error: NSError) {
        precondition(error.domain == NSCocoaErrorDomain)
        self._nsError = error
    }
    
    public static var errorDomain: String { return NSCocoaErrorDomain }
    
    public var hashValue: Int {
        return _nsError.hashValue
    }
}
#else

public protocol _StoredError {
    associatedtype Code: _ErrorCodeProtocol, RawRepresentable where Code.RawValue: FixedWidthInteger
    
    var code: Code { get }
}

/// Describes errors within the Cocoa error domain, including errors that Foundation throws.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct CocoaError : CustomNSError, _StoredError, Hashable {
    // On not-Darwin, CocoaError is backed by a simple code.
    public let code: Code
    public let userInfo: [String: AnyHashable]
    
    public init(code: Code, userInfo: [String: AnyHashable]) {
        self.code = code
        self.userInfo = userInfo
    }
    
    public static var errorDomain: String { "NSCocoaErrorDomain" }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
    
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.code == rhs.code && lhs.userInfo == rhs.userInfo
    }
}
#endif

/// Describes the code of an error.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public protocol _ErrorCodeProtocol : Equatable, RawRepresentable {
#if FOUNDATION_FRAMEWORK
    /// The corresponding error code.
    associatedtype _ErrorType: _BridgedStoredNSError where _ErrorType.Code == Self
#else
    associatedtype _ErrorType: _StoredError where _ErrorType.Code == Self
#endif
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension _ErrorCodeProtocol {
    /// Allow one to match an error code against an arbitrary error.
    public static func ~=(match: Self, error: Error) -> Bool {
        guard let specificError = error as? Self._ErrorType else { return false }

        return match == specificError.code
    }
}

extension CocoaError {
    /// The error code itself.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public struct Code : RawRepresentable, Hashable, _ErrorCodeProtocol, Sendable {
        public typealias _ErrorType = CocoaError

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public extension CocoaError {
#if FOUNDATION_FRAMEWORK
    private var _nsUserInfo: [AnyHashable : Any] {
        return (self as NSError).userInfo
    }
#endif

    /// The file path associated with the error, if any.
    var filePath: String? {
#if FOUNDATION_FRAMEWORK
        return _nsUserInfo[NSFilePathErrorKey as NSString] as? String
#else
        return userInfo["NSFilePathErrorKey"] as? String
#endif
    }

    /// The string encoding associated with this error, if any.
    var stringEncoding: String.Encoding? {
#if FOUNDATION_FRAMEWORK
        return (_nsUserInfo[NSStringEncodingErrorKey as NSString] as? NSNumber)
            .map { String.Encoding(rawValue: $0.uintValue) }
#else
        return (userInfo["NSStringEncodingErrorKey"] as? Int)
            .map { String.Encoding(rawValue: UInt($0)) }
#endif
    }

    /// The underlying error behind this error, if any.
    var underlying: Error? {
#if FOUNDATION_FRAMEWORK
        return _nsUserInfo[NSUnderlyingErrorKey as NSString] as? Error
#else
        return userInfo["NSUnderlyingErrorKey"] as? Error
#endif
    }

    /// A list of underlying errors, if any. It includes the values of both NSUnderlyingErrorKey and NSMultipleUnderlyingErrorsKey. If there are no underlying errors, returns an empty array.
    @available(macOS 11.3, iOS 14.5, watchOS 7.4, tvOS 14.5, *)
    var underlyingErrors: [Error] {
        var result : [Error] = []

#if FOUNDATION_FRAMEWORK
        if let underlying = _nsUserInfo[NSUnderlyingErrorKey as NSString] as? Error {
            result.append(underlying)
        }

        if let multipleUnderlying = _nsUserInfo["NSMultipleUnderlyingErrorsKey" as NSString] as? [Error] {
            result += multipleUnderlying
        }

        if let coreDataUnderlying = _nsUserInfo["NSDetailedErrors" as NSString] as? [Error] {
            result += coreDataUnderlying
        }
#else
        if let underlying = userInfo["NSUnderlyingErrorKey"] as? Error {
            result.append(underlying)
        }

        if let multipleUnderlying = userInfo["NSMultipleUnderlyingErrorsKey"] as? [Error] {
            result += multipleUnderlying
        }
#endif
        
        return result
    }

    /// The URL associated with this error, if any.
    var url: URL? {
#if FOUNDATION_FRAMEWORK
        return _nsUserInfo[NSURLErrorKey as NSString] as? URL
#else
        return userInfo["NSURLErrorKey"] as? URL
#endif
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension CocoaError {
#if FOUNDATION_FRAMEWORK
    public static func error(_ code: CocoaError.Code, userInfo: [AnyHashable : Any]? = nil, url: URL? = nil) -> Error {
        var info: [String : Any] = userInfo as? [String : Any] ?? [:]
        if let url = url {
            info[NSURLErrorKey] = url
        }
        return NSError(domain: NSCocoaErrorDomain, code: code.rawValue, userInfo: info)
    }
#else
    public static func error(_ code: CocoaError.Code, userInfo: [String : AnyHashable]? = nil, url: URL? = nil) -> Error {
        var info: [String : AnyHashable] = userInfo ?? [:]
        if let url = url {
            info["NSURLErrorKey"] = url
        }
        return CocoaError(code: code, userInfo: info)
    }
#endif
}

/// Describes an error that provides localized messages describing why
/// an error occurred and provides more information about the error.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public protocol LocalizedError : Error {
    /// A localized message describing what error occurred.
    var errorDescription: String? { get }

    /// A localized message describing the reason for the failure.
    var failureReason: String? { get }

    /// A localized message describing how one might recover from the failure.
    var recoverySuggestion: String? { get }

    /// A localized message providing "help" text if the user requests help.
    var helpAnchor: String? { get }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public extension LocalizedError {
    var errorDescription: String? { return nil }
    var failureReason: String? { return nil }
    var recoverySuggestion: String? { return nil }
    var helpAnchor: String? { return nil }
}

/// Describes an error type that specifically provides a domain, code,
/// and user-info dictionary.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public protocol CustomNSError : Error {
    /// The domain of the error.
    static var errorDomain: String { get }

    /// The error code within the given domain.
    var errorCode: Int { get }

    /// The user-info dictionary.
    var errorUserInfo: [String : Any] { get }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public extension CustomNSError {
    /// Default domain of the error.
    static var errorDomain: String {
        return String(reflecting: self)
    }

    /// The error code within the given domain.
    var errorCode: Int {
        return _getDefaultErrorCode(self)
    }

    /// The default user-info dictionary.
    var errorUserInfo: [String : Any] {
        return [:]
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public extension Error where Self : CustomNSError {
    /// Default implementation for customized NSErrors.
    var _domain: String { return Self.errorDomain }

    /// Default implementation for customized NSErrors.
    var _code: Int { return self.errorCode }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public extension Error where Self: CustomNSError, Self: RawRepresentable, Self.RawValue: FixedWidthInteger {
    /// Default implementation for customized NSErrors.
    var _code: Int { return self.errorCode }
}

#if FOUNDATION_FRAMEWORK
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public extension Error {
    /// Retrieve the localized description for this error.
    var localizedDescription: String {
        return (self as NSError).localizedDescription
    }
}
#endif


