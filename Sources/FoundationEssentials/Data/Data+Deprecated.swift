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
    @available(swift, introduced: 4.2)
    @available(swift, deprecated: 5, message: "use `init(_:)` instead")
    public init<S: Sequence>(bytes elements: S) where S.Iterator.Element == UInt8 {
        self.init(elements)
    }
    
    @available(swift, obsoleted: 4.2)
    public init(bytes: Array<UInt8>) {
        self.init(bytes)
    }
    
    @available(swift, obsoleted: 4.2)
    public init(bytes: ArraySlice<UInt8>) {
        self.init(bytes)
    }
    
    /// Access the bytes in the data.
    ///
    /// - warning: The byte pointer argument should not be stored and used outside of the lifetime of the call to the closure.
    @available(swift, deprecated: 5, message: "use `withUnsafeBytes<R>(_: (UnsafeRawBufferPointer) throws -> R) rethrows -> R` instead")
    public func withUnsafeBytes<ResultType, ContentType>(_ body: (UnsafePointer<ContentType>) throws -> ResultType) rethrows -> ResultType {
        return try _representation.withUnsafeBytes {
            return try body($0.baseAddress?.assumingMemoryBound(to: ContentType.self) ?? UnsafePointer<ContentType>(bitPattern: 0xBAD0)!)
        }
    }
    
    /// Mutate the bytes in the data.
    ///
    /// This function assumes that you are mutating the contents.
    /// - warning: The byte pointer argument should not be stored and used outside of the lifetime of the call to the closure.
    @available(swift, deprecated: 5, message: "use `withUnsafeMutableBytes<R>(_: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R` instead")
    public mutating func withUnsafeMutableBytes<ResultType, ContentType>(_ body: (UnsafeMutablePointer<ContentType>) throws -> ResultType) rethrows -> ResultType {
        return try _representation.withUnsafeMutableBytes {
            return try body($0.baseAddress?.assumingMemoryBound(to: ContentType.self) ?? UnsafeMutablePointer<ContentType>(bitPattern: 0xBAD0)!)
        }
    }
    
    /// Enumerate the contents of the data.
    ///
    /// In some cases, (for example, a `Data` backed by a `dispatch_data_t`, the bytes may be stored discontinuously. In those cases, this function invokes the closure for each contiguous region of bytes.
    /// - parameter block: The closure to invoke for each region of data. You may stop the enumeration by setting the `stop` parameter to `true`.
    @available(swift, deprecated: 5, message: "use `regions` or `for-in` instead")
    public func enumerateBytes(_ block: (_ buffer: UnsafeBufferPointer<UInt8>, _ byteIndex: Index, _ stop: inout Bool) -> Void) {
        _representation.enumerateBytes(block)
    }
}
