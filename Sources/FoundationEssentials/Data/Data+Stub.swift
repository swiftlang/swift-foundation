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
    /// Initialize a `Data` with the contents of a `URL`.
    ///
    /// - parameter url: The `URL` to read.
    /// - parameter options: Options for the read operation. Default value is `[]`.
    /// - throws: An error in the Cocoa domain, if `url` cannot be read.
    @inlinable // This is @inlinable as a convenience initializer.
    public init(contentsOf url: __shared URL, options: Data.ReadingOptions = []) throws {
        // FIXME: Implement Data IO
        fatalError("Not implemented")
    }

    internal init(contentsOfFile path: String, options: Data.ReadingOptions = []) throws {
        // FIXME: Implement Data IO
        fatalError("Not implemented")
    }

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

    /// Write the contents of the `Data` to a location.
    ///
    /// - parameter url: The location to write the data into.
    /// - parameter options: Options for writing the data. Default value is `[]`.
    /// - throws: An error in the Cocoa domain, if there is an error writing to the `URL`.
    public func write(to url: URL, options: Data.WritingOptions = []) throws {
        // this should not be marked as inline since in objc contexts we correct atomicity via _shouldUseNonAtomicWriteReimplementation
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

#endif // !FOUNDATION_FRAMEWORK
