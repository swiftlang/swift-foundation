//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

extension String {
    internal func _trimmingWhitespace() -> String {
        String(unicodeScalars._trimmingCharacters {
            $0.properties.isWhitespace
        })
    }

    static func _tryFromUTF16(_ input: UnsafeBufferPointer<UInt16>) -> String? {
        withUnsafeTemporaryAllocation(of: UInt8.self, capacity: input.count * 3) { contents in
            var ptr = contents.baseAddress!
            var count = 0
            let error = transcode(input.makeIterator(), from: UTF16.self, to: UTF8.self, stoppingOnError: true) { codeUnit in
                ptr.pointee = codeUnit
                ptr = ptr.advanced(by: 1)
                count += 1
            }

            guard !error else {
                return nil
            }

            return String._tryFromUTF8(UnsafeBufferPointer(rebasing: contents[..<count]))
        }
    }

    static func _tryFromUTF16(_ input: UnsafeMutableBufferPointer<UInt16>, len: Int) -> String? {
        _tryFromUTF16(UnsafeBufferPointer(rebasing: input[..<len]))
    }

    static func _tryFromUTF16(_ input: UnsafePointer<UInt16>, len: Int) -> String? {
        _tryFromUTF16(UnsafeBufferPointer(start: input, count: len))
    }

}
