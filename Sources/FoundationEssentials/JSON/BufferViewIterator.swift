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
