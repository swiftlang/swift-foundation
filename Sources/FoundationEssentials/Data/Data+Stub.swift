//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if !FOUNDATION_FRAMEWORK

// FIXME: rdar://103535015 (Implement stub methods in struct Data)
extension Data {
    /// Initialize a `Data` from a Base-64 encoded String using the given options.
    ///
    /// Returns nil when the input is not recognized as valid Base-64.
    /// - parameter base64String: The string to parse.
    /// - parameter options: Encoding options. Default value is `[]`.
    @inlinable // This is @inlinable as a convenience initializer.
    public init?(base64Encoded base64String: __shared String, options: Data.Base64DecodingOptions = []) {
        // FIXME: Implement Data IO
        fatalError("Not implemented")
    }

    /// Initialize a `Data` from a Base-64, UTF-8 encoded `Data`.
    ///
    /// Returns nil when the input is not recognized as valid Base-64.
    ///
    /// - parameter base64Data: Base-64, UTF-8 encoded input data.
    /// - parameter options: Decoding options. Default value is `[]`.
    @inlinable // This is @inlinable as a convenience initializer.
    public init?(base64Encoded base64Data: __shared Data, options: Data.Base64DecodingOptions = []) {
        // FIXME: Implement Data IO
        fatalError("Not implemented")
    }

    /// Find the given `Data` in the content of this `Data`.
    ///
    /// - parameter dataToFind: The data to be searched for.
    /// - parameter options: Options for the search. Default value is `[]`.
    /// - parameter range: The range of this data in which to perform the search. Default value is `nil`, which means the entire content of this data.
    /// - returns: A `Range` specifying the location of the found data, or nil if a match could not be found.
    /// - precondition: `range` must be in the bounds of the Data.
    public func range(of dataToFind: Data, options: Data.SearchOptions = [], in range: Range<Index>? = nil) -> Range<Index>? {
        // FIXME: Implement Data IO
        fatalError("Not implemented")
    }

    /// Returns a Base-64 encoded string.
    ///
    /// - parameter options: The options to use for the encoding. Default value is `[]`.
    /// - returns: The Base-64 encoded string.
    @inlinable // This is @inlinable as trivially forwarding.
    public func base64EncodedString(options: Data.Base64EncodingOptions = []) -> String {
        // FIXME: Implement Data IO
        fatalError("Not implemented")
    }

    /// Returns a Base-64 encoded `Data`.
    ///
    /// - parameter options: The options to use for the encoding. Default value is `[]`.
    /// - returns: The Base-64 encoded data.
    @inlinable // This is @inlinable as trivially forwarding.
    public func base64EncodedData(options: Data.Base64EncodingOptions = []) -> Data {
        // FIXME: Implement Data IO
        fatalError("Not implemented")
    }
}

// Placeholder for Progress
internal final class Progress {
    var completedUnitCount: Int64
    var totalUnitCount: Int64
    
    init(totalUnitCount: Int64) {
        self.completedUnitCount = 0
        self.totalUnitCount = totalUnitCount
    }
    
    func becomeCurrent(withPendingUnitCount: Int64) { }
    func resignCurrent() { }
    var isCancelled: Bool { false }
    static func current() -> Progress? { nil }
    var fractionCompleted: Double {
        0.0
    }
}

#endif // !FOUNDATION_FRAMEWORK

internal enum PathOrURL {
    case path(String)
    case url(URL)
    
    func withFileSystemRepresentation<R>(_ block: (UnsafePointer<CChar>?) throws -> R) rethrows -> R {
        return try path.withFileSystemRepresentation(block)
    }

    func withMutableFileSystemRepresentation<R>(_ block: (UnsafeMutablePointer<CChar>?) throws -> R) rethrows -> R {
        return try path.withMutableFileSystemRepresentation(block)
    }

    var isEmpty: Bool {
        path.isEmpty
    }
    
    var path: String {
        switch self {
        case .path(let p): return p
        case .url(let u): return u.path
        }
    }
}
