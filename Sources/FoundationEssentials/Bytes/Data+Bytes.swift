//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

extension Data {
    init(consuming bytes: consuming RigidBytes) {
        let (buffer, count) = unsafe bytes.deconstruct()
        guard let address = buffer.baseAddress else {
            _representation = .empty
            return
        }
        guard count > 0 else {
            unsafe RigidBytes._deallocate(address)
            _representation = .empty
            return
        }
        let storage = unsafe __DataStorage(offset: 0, bytes: address, capacity: buffer.count, needToZero: true, length: count, deallocator: nil)
        _representation = _Representation(storage, count: count)
    }

    @inline(__always)
    init(consuming bytes: consuming Bytes) {
        self.init(consuming: RigidBytes(consuming: bytes))
    }
}
