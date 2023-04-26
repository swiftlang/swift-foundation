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
    static func _tryFromUTF8(_ input: BufferView<UInt8>) -> String? {
        input.withUnsafePointer { pointer, capacity in
            _tryFromUTF8(.init(start: pointer, count: capacity))
        }
    }
}

extension Data {
    func withBufferView<ResultType>(
        _ body: (BufferView<UInt8>) throws -> ResultType
    ) rethrows -> ResultType {
        try withUnsafeBytes {
            // Data never passes an empty buffer with a `nil` `baseAddress`.
            try body(BufferView(unsafeRawBufferPointer: $0)!)
        }
    }
}

extension BufferView<UInt8> {
    internal subscript(region: JSONMap.Region) -> BufferView {
        precondition(
            region.startOffset >= 0 && region.startOffset < count && region.count >= 0
                && region.count <= count && region.startOffset &+ region.count <= count
        )
        return self[unchecked: region]
    }

    internal subscript(unchecked region: JSONMap.Region) -> BufferView {
        let address = startIndex.advanced(by: region.startOffset)
        return BufferView(start: address, count: region.count)
    }
}
