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
    /// Options that control a data search operation.
    public typealias SearchOptions = NSData.SearchOptions
#else
    /// Options that control a data search operation.
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

    /// Find the given `Data` in the content of this `Data`.
    ///
    /// - parameter dataToFind: The data to be searched for.
    /// - parameter options: Options for the search. Default value is `[]`.
    /// - parameter range: The range of this data in which to perform the search. Default value is `nil`, which means the entire content of this data.
    /// - returns: A `Range` specifying the location of the found data, or nil if a match could not be found.
    /// - precondition: `range` must be in the bounds of the Data.
    public func range(of dataToFind: Data, options: Data.SearchOptions = [], in range: Range<Index>? = nil) -> Range<Index>? {
        let searchRange = range ?? startIndex..<endIndex
        let searchBackwards = options.contains(.backwards)
        let isAnchored = options.contains(.anchored)

        let foundRange = searchBackwards
            ? lastRange(of: dataToFind, in: searchRange)
            : firstRange(of: dataToFind, in: searchRange)

        return foundRange.flatMap { found in
            guard isAnchored else { return found }
            if searchBackwards {
                return found.upperBound == searchRange.upperBound ? found : nil
            }
            return found.lowerBound == searchRange.lowerBound ? found : nil
        }
    }
}
