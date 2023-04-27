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

#if !FOUDATION_FRAMEWORK

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct Decimal: Hashable, Codable, Equatable, CustomStringConvertible {
    private let fake: Double

    public var doubleValue: Double { self.fake }
    public var description: String {
        // Hack here to simulate real Decimal's behavior:
        // If the value is an int, print as int
        let isInteger = floor(self.fake) == self.fake
        var result = self.fake.description
        if isInteger, let intValue = result.split(separator: ".").first {
            result = String(intValue)
        }
        return result
    }

    public init(_ double: Double) {
        self.fake = double
    }

    public init(_ int: Int) {
        self.fake = Double(int)
    }

    public init?(string: String) {
        guard let value = Double(string) else {
            return nil
        }
        self.fake = value
    }

    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard let value = Double(exactly: source) else {
            return nil
        }
        self.fake = value
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

#endif
