@frozen @usableFromInline
internal struct BufferViewIndex<Element> {
  @usableFromInline
  let _rawValue: UnsafeRawPointer

  @inlinable @inline(__always)
  internal init(rawValue: UnsafeRawPointer) {
    _rawValue = rawValue
  }

  @inlinable @inline(__always)
  var isAligned: Bool {
    (Int(bitPattern: _rawValue) & (MemoryLayout<Element>.alignment-1)) == 0
  }
}

extension BufferViewIndex: Equatable {}

extension BufferViewIndex: Hashable {}

extension BufferViewIndex: Strideable {
  public typealias Stride = Int

  @inlinable @inline(__always)
  public func distance(to other: BufferViewIndex) -> Int {
    _rawValue.distance(to: other._rawValue) / MemoryLayout<Element>.stride
  }

  @inlinable @inline(__always)
  public func advanced(by n: Int) -> BufferViewIndex {
    .init(rawValue: _rawValue.advanced(by: n &* MemoryLayout<Element>.stride))
  }
}

extension BufferViewIndex: Comparable {
  @inlinable @inline(__always)
  public static func <(lhs: BufferViewIndex, rhs: BufferViewIndex) -> Bool {
    lhs._rawValue < rhs._rawValue
  }
}

@available(*, unavailable)
extension BufferViewIndex: Sendable {}
