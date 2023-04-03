@frozen @usableFromInline
internal struct BufferViewIterator<Element>{
  var curPointer: UnsafeRawPointer
  let endPointer: UnsafeRawPointer

  init<Owner>(
    startPointer: UnsafeRawPointer,
    endPointer: UnsafeRawPointer,
    dependsOn owner: /*borrowing*/ Owner
  ) {
    self.curPointer = startPointer
    self.endPointer = endPointer
  }

  init<Owner>(
    from start: BufferViewIndex<Element>,
    to end: BufferViewIndex<Element>,
    dependsOn owner: /*borrowing*/ Owner
  ) {
    self.init(
      startPointer: start._rawValue, endPointer: end._rawValue, dependsOn: owner
    )
  }
}

extension BufferViewIterator: IteratorProtocol {

  public mutating func next() -> Element? {
    guard curPointer < endPointer else { return nil }
    defer {
      curPointer = curPointer.advanced(by: MemoryLayout<Element>.stride)
    }
    if _isPOD(Element.self) {
      return curPointer.loadUnaligned(as: Element.self)
    }
    return curPointer.load(as: Element.self)
  }
}
