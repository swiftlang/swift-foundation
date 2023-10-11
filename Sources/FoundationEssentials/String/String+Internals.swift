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
    package func _trimmingWhitespace() -> String {
        String(unicodeScalars._trimmingCharacters {
            $0.properties.isWhitespace
        })
    }

    package init?(_utf16 input: UnsafeBufferPointer<UInt16>) {
        // Allocate input.count * 3 code points since one UTF16 code point may require up to three UTF8 code points when transcoded
        let str = withUnsafeTemporaryAllocation(of: UTF8.CodeUnit.self, capacity: input.count * 3) { contents in
            var count = 0
            let error = transcode(input.makeIterator(), from: UTF16.self, to: UTF8.self, stoppingOnError: true) { codeUnit in
                contents[count] = codeUnit
                count += 1
            }

            guard !error else {
                return nil as String?
            }

            return String._tryFromUTF8(UnsafeBufferPointer(rebasing: contents[..<count]))
        }

        guard let str else {
            return nil
        }
        self = str
    }

    package init?(_utf16 input: UnsafeMutableBufferPointer<UInt16>, count: Int) {
        guard let str = String(_utf16: UnsafeBufferPointer(rebasing: input[..<count])) else {
            return nil
        }
        self = str
    }

    package init?(_utf16 input: UnsafePointer<UInt16>, count: Int) {
        guard let str = String(_utf16: UnsafeBufferPointer(start: input, count: count)) else {
            return nil
        }
        self = str
    }

}
