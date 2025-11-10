//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
/// In `FOUNDATION_FRAMEWORK`, the inner class types of `struct URL` conform to this protocol.
/// Outside `FOUNDATION_FRAMEWORK`, only `_SwiftURL` is used, so the protocol is not needed.
/// - `class _SwiftURL` is the new Swift implementation for a true Swift `URL`.
/// - `class _BridgedURL` wraps an `NSURL` implementation bridged to Swift, including custom subclasses.
/// - Note: Except for `baseURL`, a nil `URL?` return value means that `struct URL` will return `self`.
internal protocol _URLProtocol: AnyObject, Sendable {
    init?(string: String)
    init?(string: String, relativeTo url: URL?)
    init?(string: String, encodingInvalidCharacters: Bool)
    init?(stringOrEmpty: String, relativeTo url: URL?)

    init(fileURLWithPath path: String, isDirectory: Bool, relativeTo base: URL?)
    init(fileURLWithPath path: String, relativeTo base: URL?)
    init(fileURLWithPath path: String, isDirectory: Bool)
    init(fileURLWithPath path: String)
    init(filePath path: String, directoryHint: URL.DirectoryHint, relativeTo base: URL?)

    init?(dataRepresentation: Data, relativeTo base: URL?, isAbsolute: Bool)
    init(fileURLWithFileSystemRepresentation path: UnsafePointer<Int8>, isDirectory: Bool, relativeTo base: URL?)

    var dataRepresentation: Data { get }
    var relativeString: String { get }
    var absoluteString: String { get }
    var baseURL: URL? { get }
    var absoluteURL: URL? { get }

    var scheme: String? { get }
    var isFileURL: Bool { get }
    var hasAuthority: Bool { get }

    var user: String? { get }
    func user(percentEncoded: Bool) -> String?

    var password: String? { get }
    func password(percentEncoded: Bool) -> String?

    var host: String? { get }
    func host(percentEncoded: Bool) -> String?

    var port: Int? { get }

    var relativePath: String { get }
    func relativePath(percentEncoded: Bool) -> String
    func absolutePath(percentEncoded: Bool) -> String
    var path: String { get }
    func path(percentEncoded: Bool) -> String

    var query: String? { get }
    func query(percentEncoded: Bool) -> String?

    var fragment: String? { get }
    func fragment(percentEncoded: Bool) -> String?

    func fileSystemPath(style: URL.PathStyle, resolveAgainstBase: Bool, compatibility: Bool) -> String
    func withUnsafeFileSystemRepresentation<ResultType>(_ block: (UnsafePointer<Int8>?) throws -> ResultType) rethrows -> ResultType

    var hasDirectoryPath: Bool { get }
    var pathComponents: [String] { get }
    var lastPathComponent: String { get }
    var pathExtension: String { get }

    func appendingPathComponent(_ pathComponent: String, isDirectory: Bool) -> URL?
    func appendingPathComponent(_ pathComponent: String) -> URL?
    func appending<S: StringProtocol>(path: S, directoryHint: URL.DirectoryHint) -> URL?
    func appending<S: StringProtocol>(component: S, directoryHint: URL.DirectoryHint) -> URL?
    func deletingLastPathComponent() -> URL?
    func appendingPathExtension(_ pathExtension: String) -> URL?
    func deletingPathExtension() -> URL?
    var standardized: URL? { get }

#if !NO_FILESYSTEM
    var standardizedFileURL: URL? { get }
    func resolvingSymlinksInPath() -> URL?
#endif

    var description: String { get }
    var debugDescription: String { get }

    func bridgeToNSURL() -> NSURL
    func isFileReferenceURL() -> Bool

    /// We must not store a `_URLProtocol` in `URL` without running it through this function.
    /// This makes sure that we do not hold a file reference URL, which changes the nullability of many functions.
    /// - Note: File reference URL here is not the same as playground's "file reference".
    /// - Note: This is a no-op `#if !FOUNDATION_FRAMEWORK`.
    func convertingFileReference() -> any _URLProtocol & AnyObject
}
#endif // FOUNDATION_FRAMEWORK
