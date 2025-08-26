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

// A BufferView<Element> represents a span of memory which
// contains initialized `Element` instances.

internal struct BufferView<Element> {
    let start: BufferViewIndex<Element>
    let count: Int

    private var baseAddress: UnsafeRawPointer { start._rawValue }

    init(_unchecked components: (start: BufferViewIndex<Element>, count: Int)) {
        (start, count) = components
    }

    init(start index: BufferViewIndex<Element>, count: Int) {
        precondition(count >= 0, "Count must not be negative")
        if !_isPOD(Element.self) {
            precondition(
                index.isAligned,
                "baseAddress must be properly aligned for \(Element.self)"
            )
        }
        self.init(_unchecked: (index, count))
    }

    init(unsafeBaseAddress: UnsafeRawPointer, count: Int) {
        self.init(start: .init(rawValue: unsafeBaseAddress), count: count)
    }

    init?(unsafeBufferPointer buffer: UnsafeBufferPointer<Element>) {
        guard let baseAddress = UnsafeRawPointer(buffer.baseAddress) else { return nil }
        self.init(unsafeBaseAddress: baseAddress, count: buffer.count)
    }
}

extension BufferView /*where Element: BitwiseCopyable*/ {

    init?(unsafeRawBufferPointer buffer: UnsafeRawBufferPointer) {
        guard _isPOD(Element.self) else { fatalError() }
        guard let p = buffer.baseAddress else { return nil }
        let (q, r) = buffer.count.quotientAndRemainder(dividingBy: MemoryLayout<Element>.stride)
        precondition(r == 0)
        self.init(unsafeBaseAddress: p, count: q)
    }
}

//MARK: Sequence

extension BufferView: Sequence {

    func makeIterator() -> BufferViewIterator<Element> {
        .init(from: startIndex, to: endIndex)
    }

    //FIXME: mark closure parameter as non-escaping
    func withContiguousStorageIfAvailable<R>(
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R? {
        try baseAddress.withMemoryRebound(to: Element.self, capacity: count) {
            [count = count] in
            try body(UnsafeBufferPointer(start: $0, count: count))
        }
    }
}

@available(*, unavailable)
extension BufferView: Sendable {}

extension BufferView where Element: Equatable {

    internal func elementsEqual(_ other: Self) -> Bool {
        guard count == other.count else { return false }
        if count == 0 { return true }
        if baseAddress == other.baseAddress { return true }

        //FIXME: This could be a shortcut with a layout constraint
        //       where stride equals size, with no unused bits.
        // if Element is BitwiseRepresentable {
        // return _swift_stdlib_memcmp(lhs.baseAddress, rhs.baseAddress, count) == 0
        // }
        for (a, b) in zip(self, other) {
            guard a == b else { return false }
        }
        return true
    }
}

//MARK: Collection, RandomAccessCollection
extension BufferView:
    Collection,
    BidirectionalCollection,
    RandomAccessCollection {

    typealias Element = Element
    typealias Index = BufferViewIndex<Element>
    typealias SubSequence = Self

    @inline(__always)
    var startIndex: Index { start }

    @inline(__always)
    var endIndex: Index { start.advanced(by: count) }

    @inline(__always)
    var indices: Range<Index> {
        .init(uncheckedBounds: (startIndex, endIndex))
    }

    @inline(__always)
    func _checkBounds(_ position: Index) {
        precondition(
            distance(from: startIndex, to: position) >= 0
                && distance(from: position, to: endIndex) > 0,
            "Index out of bounds"
        )
        //FIXME: Use `BitwiseCopyable` layout constraint
        if !_isPOD(Element.self) {
            precondition(
                position.isAligned,
                "Index is unaligned for Element"
            )
        }
    }

    @inline(__always)
    func _assertBounds(_ position: Index) {
        #if DEBUG
        _checkBounds(position)
        #endif
    }

    @inline(__always)
    func _checkBounds(_ bounds: Range<Index>) {
        precondition(
            distance(from: startIndex, to: bounds.lowerBound) >= 0
                && distance(from: bounds.lowerBound, to: bounds.upperBound) >= 0
                && distance(from: bounds.upperBound, to: endIndex) >= 0,
            "Range of indices out of bounds"
        )
        //FIXME: Use `BitwiseCopyable` layout constraint
        if !_isPOD(Element.self) {
            precondition(
                bounds.lowerBound.isAligned && bounds.upperBound.isAligned,
                "Range of indices is unaligned for Element"
            )
        }
    }

    @inline(__always)
    func _assertBounds(_ bounds: Range<Index>) {
        #if DEBUG
        _checkBounds(bounds)
        #endif
    }

    @inline(__always)
    func index(after i: Index) -> Index {
        i.advanced(by: +1)
    }

    @inline(__always)
    func index(before i: Index) -> Index {
        i.advanced(by: -1)
    }

    @inline(__always)
    func formIndex(after i: inout Index) {
        i = index(after: i)
    }

    @inline(__always)
    func formIndex(before i: inout Index) {
        i = index(before: i)
    }

    @inline(__always)
    func index(_ i: Index, offsetBy distance: Int) -> Index {
        i.advanced(by: distance)
    }

    @inline(__always)
    func formIndex(_ i: inout Index, offsetBy distance: Int) {
        i = index(i, offsetBy: distance)
    }

    @inline(__always)
    func distance(from start: Index, to end: Index) -> Int {
        start.distance(to: end)
    }

    @inline(__always)
    subscript(position: Index) -> Element {
        get {
            _checkBounds(position)
            return self[unchecked: position]
        }
    }

    @inline(__always)
    subscript(unchecked position: Index) -> Element {
        get {
            if _isPOD(Element.self) {
                return position._rawValue.loadUnaligned(as: Element.self)
            } else {
                return position._rawValue.load(as: Element.self)
            }
        }
    }

    @inline(__always)
    subscript(bounds: Range<Index>) -> Self {
        get {
            _checkBounds(bounds)
            return self[unchecked: bounds]
        }
    }

    @inline(__always)
    subscript(unchecked bounds: Range<Index>) -> Self {
        get { BufferView(_unchecked: (bounds.lowerBound, bounds.count)) }
    }

    subscript(bounds: some RangeExpression<Index>) -> Self {
        get {
            self[bounds.relative(to: self)]
        }
    }

    subscript(unchecked bounds: some RangeExpression<Index>) -> Self {
        get {
            self[unchecked: bounds.relative(to: self)]
        }
    }

    subscript(x: UnboundedRange) -> Self {
        get {
            self[unchecked: indices]
        }
    }
}

//MARK: withUnsafeRaw...
extension BufferView /* where Element: BitwiseCopyable */ {

    //FIXME: mark closure parameter as non-escaping
    func withUnsafeRawPointer<R>(
        _ body: (_ pointer: UnsafeRawPointer, _ count: Int) throws -> R
    ) rethrows -> R {
        try body(baseAddress, count * MemoryLayout<Element>.stride)
    }

    //FIXME: mark closure parameter as non-escaping
    func withUnsafeBytes<R>(
        _ body: (_ buffer: UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
        try body(.init(start: baseAddress, count: count))
    }
}

//MARK: withUnsafePointer, etc.
extension BufferView {

    //FIXME: mark closure parameter as non-escaping
    func withUnsafePointer<R>(
        _ body: (
            _ pointer: UnsafePointer<Element>,
            _ capacity: Int
        ) throws -> R
    ) rethrows -> R {
        try baseAddress.withMemoryRebound(
            to: Element.self, capacity: count, { try body($0, count) }
        )
    }

    //FIXME: mark closure parameter as non-escaping
    func withUnsafeBufferPointer<R>(
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R {
        try baseAddress.withMemoryRebound(to: Element.self, capacity: count) {
            try body(.init(start: $0, count: count))
        }
    }
}

//MARK: load and store
extension BufferView /* where Element: BitwiseCopyable */ {

    func load<T>(
        fromByteOffset offset: Int = 0, as: T.Type
    ) -> T {
        guard _isPOD(Element.self) else { fatalError() }
        _checkBounds(
            Range(
                uncheckedBounds: (
                    .init(rawValue: baseAddress.advanced(by: offset)),
                    .init(rawValue: baseAddress.advanced(by: offset + MemoryLayout<T>.size))
                ))
        )
        return baseAddress.load(fromByteOffset: offset, as: T.self)
    }

    func load<T>(from index: Index, as: T.Type) -> T {
        let o = distance(from: startIndex, to: index) * MemoryLayout<Element>.stride
        return load(fromByteOffset: o, as: T.self)
    }

    func loadUnaligned<T /*: BitwiseCopyable */>(
        fromByteOffset offset: Int = 0, as: T.Type
    ) -> T {
        guard _isPOD(Element.self) && _isPOD(T.self) else { fatalError() }
        _checkBounds(
            Range(
                uncheckedBounds: (
                    .init(rawValue: baseAddress.advanced(by: offset)),
                    .init(rawValue: baseAddress.advanced(by: offset + MemoryLayout<T>.size))
                ))
        )
        return baseAddress.loadUnaligned(fromByteOffset: offset, as: T.self)
    }

    func loadUnaligned<T /*: BitwiseCopyable */>(
        from index: Index, as: T.Type
    ) -> T {
        let o = distance(from: startIndex, to: index) * MemoryLayout<Element>.stride
        return loadUnaligned(fromByteOffset: o, as: T.self)
    }
}

//MARK: integer offset subscripts

extension BufferView {

    @inline(__always)
    subscript(offset offset: Int) -> Element {
        get {
            precondition(0 <= offset && offset < count)
            return self[uncheckedOffset: offset]
        }
    }

    @inline(__always)
    subscript(uncheckedOffset offset: Int) -> Element {
        get {
            self[unchecked: index(startIndex, offsetBy: offset)]
        }
    }
}

extension BufferView {
    var first: Element? {
        startIndex == endIndex ? nil : self[unchecked: startIndex]
    }

    var last: Element? {
        startIndex == endIndex ? nil : self[unchecked: index(before: endIndex)]
    }
}

//MARK: prefix and suffix slicing
extension BufferView {

    func prefix(_ maxLength: Int) -> BufferView {
        precondition(maxLength >= 0, "Can't have a prefix of negative length.")
        let nc = maxLength < count ? maxLength : count
        return BufferView(_unchecked: (start: start, count: nc))
    }

    func suffix(_ maxLength: Int) -> BufferView {
        precondition(maxLength >= 0, "Can't have a suffix of negative length.")
        let nc = maxLength < count ? maxLength : count
        let newStart = start.advanced(by: count &- nc)
        return BufferView(_unchecked: (start: newStart, count: nc))
    }

    func dropFirst(_ k: Int = 1) -> BufferView {
        precondition(k >= 0, "Can't drop a negative number of elements.")
        let dc = k < count ? k : count
        let newStart = start.advanced(by: dc)
        return BufferView(_unchecked: (start: newStart, count: count &- dc))
    }

    func dropLast(_ k: Int = 1) -> BufferView {
        precondition(k >= 0, "Can't drop a negative number of elements.")
        let nc = k < count ? count &- k : 0
        return BufferView(_unchecked: (start: start, count: nc))
    }

    func prefix(upTo index: Index) -> BufferView {
        _checkBounds(Range(uncheckedBounds: (start, index)))
        return BufferView(_unchecked: (start, distance(from: startIndex, to: index)))
    }

    func suffix(from index: Index) -> BufferView {
        _checkBounds(Range(uncheckedBounds: (index, endIndex)))
        return BufferView(_unchecked: (index, distance(from: index, to: endIndex)))
    }
}
