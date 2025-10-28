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

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {
#if FOUNDATION_FRAMEWORK
    public typealias SearchOptions = NSData.SearchOptions
    
    /// Find the given `Data` in the content of this `Data`.
    ///
    /// - parameter dataToFind: The data to be searched for.
    /// - parameter options: Options for the search. Default value is `[]`.
    /// - parameter range: The range of this data in which to perform the search. Default value is `nil`, which means the entire content of this data.
    /// - returns: A `Range` specifying the location of the found data, or nil if a match could not be found.
    /// - precondition: `range` must be in the bounds of the Data.
    public func range(of dataToFind: Data, options: Data.SearchOptions = [], in range: Range<Index>? = nil) -> Range<Index>? {
        let nsRange : NSRange
        if let r = range {
            nsRange = NSRange(location: r.lowerBound - startIndex, length: r.upperBound - r.lowerBound)
        } else {
            nsRange = NSRange(location: 0, length: count)
        }
        let result = _representation.withInteriorPointerReference {
            let opts = NSData.SearchOptions(rawValue: options.rawValue)
            return $0.range(of: dataToFind, options: opts, in: nsRange)
        }
        if result.location == NSNotFound {
            return nil
        }
        return (result.location + startIndex)..<((result.location + startIndex) + result.length)
    }
#else
    // TODO: Implement range(of:options:in:) for Foundation package.
    
    public struct SearchOptions : OptionSet, Sendable {
        public let rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        /// Search from the end of the data object.
        public static let backwards = SearchOptions(rawValue: 1 << 0)
        /// Search is limited to start (or end, if searching backwards) of the data object.
        public static let anchored  = SearchOptions(rawValue: 1 << 1)
    }
#endif
}
