//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

@discardableResult
public func _testRoundTrip<T>(of value: T, in format: PropertyListDecoder.PropertyListFormat, expectedPlist plist: Data? = nil, sourceLocation: SourceLocation = #_sourceLocation) -> T? where T : Codable, T : Equatable {
    var decoded: T?
    #expect(throws: Never.self, sourceLocation: sourceLocation) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = format
        let payload = try encoder.encode(value)
        
        if let expectedPlist = plist {
            #expect(expectedPlist == payload, "Produced plist not identical to expected plist.", sourceLocation: sourceLocation)
        }
        
        var decodedFormat: PropertyListDecoder.PropertyListFormat = format
        decoded = try PropertyListDecoder().decode(T.self, from: payload, format: &decodedFormat)
        #expect(format == decodedFormat, "Encountered plist format differed from requested format.", sourceLocation: sourceLocation)
        #expect(decoded == value, "\(T.self) did not round-trip to an equal value.", sourceLocation: sourceLocation)
    }
    return decoded
}
