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

struct OutputBuffer<T>: ~Copyable // ~Escapable
{
    let start: UnsafeMutablePointer<T>
    let capacity: Int
    var initialized: Int = 0

    deinit {
        // `self` always borrows memory, and it shouldn't have gotten here.
        // Failing to use `relinquishBorrowedMemory()` is an error.
        if initialized > 0 {
            fatalError()
        }
    }

    // precondition: pointer points to uninitialized memory for count elements
    init(initializing: UnsafeMutablePointer<T>, capacity: Int) {
        start = initializing
        self.capacity = capacity
    }
}

extension OutputBuffer {
    mutating func appendElement(_ value: T) {
        precondition(initialized < capacity, "Output buffer overflow")
        start.advanced(by: initialized).initialize(to: value)
        initialized &+= 1
    }

    mutating func deinitializeLastElement() -> T? {
        guard initialized > 0 else { return nil }
        initialized &-= 1
        return start.advanced(by: initialized).move()
    }
}

extension OutputBuffer {
    mutating func deinitialize() {
        let b = UnsafeMutableBufferPointer(start: start, count: initialized)
        b.deinitialize()
        initialized = 0
    }
}

extension OutputBuffer {
    mutating func append<S>(
        from elements: S
    ) -> S.Iterator where S: Sequence, S.Element == T {
        var iterator = elements.makeIterator()
        append(from: &iterator)
        return iterator
    }

    mutating func append(
        from elements: inout some IteratorProtocol<T>
    ) {
        while initialized < capacity {
            guard let element = elements.next() else { break }
            start.advanced(by: initialized).initialize(to: element)
            initialized &+= 1
        }
    }

    mutating func append(
        fromContentsOf source: some Collection<T>
    ) {
        let count = source.withContiguousStorageIfAvailable {
            guard let sourceAddress = $0.baseAddress, !$0.isEmpty else {
                return 0
            }
            let available = capacity &- initialized
            precondition(
                $0.count <= available,
                "buffer cannot contain every element from source."
            )
            let tail = start.advanced(by: initialized)
            tail.initialize(from: sourceAddress, count: $0.count)
            return $0.count
        }
        if let count {
            initialized &+= count
            return
        }

        let available = capacity &- initialized
        let tail = start.advanced(by: initialized)
        let suffix = UnsafeMutableBufferPointer(start: tail, count: available)
        var (iterator, copied) = source._copyContents(initializing: suffix)
        precondition(
            iterator.next() == nil,
            "buffer cannot contain every element from source."
        )
        assert(initialized + copied <= capacity)
        initialized &+= copied
    }

    mutating func moveAppend(
        fromContentsOf source: UnsafeMutableBufferPointer<T>
    ) {
        guard let sourceAddress = source.baseAddress, !source.isEmpty else {
            return
        }
        let available = capacity &- initialized
        precondition(
            source.count <= available,
            "buffer cannot contain every element from source."
        )
        let tail = start.advanced(by: initialized)
        tail.moveInitialize(from: sourceAddress, count: source.count)
        initialized &+= source.count
    }

    mutating func moveAppend(
        fromContentsOf source: Slice<UnsafeMutableBufferPointer<T>>
    ) {
        moveAppend(fromContentsOf: UnsafeMutableBufferPointer(rebasing: source))
    }
}

extension OutputBuffer<UInt8> /* where T: BitwiseCopyable */ {

    mutating func appendBytes<Value /*: BitwiseCopyable */>(
        of value: borrowing Value, as: Value.Type
    ) {
        precondition(_isPOD(Value.self))
        let (q,r) = MemoryLayout<Value>.stride.quotientAndRemainder(
            dividingBy: MemoryLayout<T>.stride
        )
        precondition(
            r == 0, "Stride of Value must be divisible by stride of Element"
        )
        precondition(
            (capacity &- initialized) >= q,
            "buffer cannot contain every byte of value."
        )
        let p = UnsafeMutableRawPointer(start.advanced(by: initialized))
        p.storeBytes(of: value, as: Value.self)
        initialized &+= q
    }
}

extension OutputBuffer {
    var initializedPrefix: /*borrowed*/ BufferView<T> {
        /* _read */ get /* borrowing(self) */ {
            /* yield */ return BufferView(
                unsafeBufferPointer: .init(start: start, count: initialized)
            ).unsafelyUnwrapped
        }
    }

    func withBufferView<R>(_ body: (borrowing BufferView<T>) throws -> R) rethrows -> R {
        let view = BufferView<T>(
            unsafeBufferPointer: .init(start: start, count: initialized)
        ).unsafelyUnwrapped
        return try body(view)
    }
}

extension OutputBuffer {

    consuming func relinquishBorrowedMemory() -> UnsafeMutableBufferPointer<T> {
        let start = self.start
        let initialized = self.initialized
        discard self
        return .init(start: start, count: initialized)
    }
}

extension Array {

    init(
        capacity: Int,
        initializingWith initializer: (inout OutputBuffer<Element>) throws -> Void
    ) rethrows {
        try self.init(
            unsafeUninitializedCapacity: capacity,
            initializingWith: { (buffer, count) in
                var output = OutputBuffer(
                    initializing: buffer.baseAddress.unsafelyUnwrapped,
                    capacity: buffer.count
                )
                try initializer(&output)
                let initialized = output.relinquishBorrowedMemory()
                assert(initialized.baseAddress == buffer.baseAddress)
                count = initialized.count
            }
        )
    }
}

extension String {

    // also see https://github.com/apple/swift/pull/23050
    // and `final class __SharedStringStorage`

    @available(macOS 11, *)
    init(
        utf8Capacity capacity: Int,
        initializingWith initializer: (inout OutputBuffer<UInt8>) throws -> Void
    ) rethrows {
        try self.init(
            unsafeUninitializedCapacity: capacity,
            initializingUTF8With: { buffer in
                var output = OutputBuffer(
                    initializing: buffer.baseAddress.unsafelyUnwrapped,
                    capacity: capacity
                )
                try initializer(&output)
                let initialized = output.relinquishBorrowedMemory()
                assert(initialized.baseAddress == buffer.baseAddress)
                return initialized.count
            }
        )
    }
}

extension Data {

    init(
        capacity: Int,
        initializingWith initializer: (inout OutputBuffer<UInt8>) throws -> Void
    ) rethrows {
        self = Data(count: capacity) // initialized with zeroed buffer
        let count = try self.withUnsafeMutableBytes { rawBuffer in
            try rawBuffer.withMemoryRebound(to: UInt8.self) { buffer in
                buffer.deinitialize()
                var output = OutputBuffer(
                    initializing: buffer.baseAddress.unsafelyUnwrapped,
                    capacity: capacity
                )
                try initializer(&output)
                let initialized = output.relinquishBorrowedMemory()
                assert(initialized.baseAddress == buffer.baseAddress)
                buffer[initialized.count..<buffer.count].initialize(repeating: 0)
                return initialized.count
            }
        }
        assert(count <= self.count)
        self.replaceSubrange(count..<self.count, with: EmptyCollection())
    }
}
