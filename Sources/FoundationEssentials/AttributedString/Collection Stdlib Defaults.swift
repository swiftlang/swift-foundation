//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// Default implementations for common Collection requirements, adapted from the stdlib.
// FIXME: The stdlib should expose these as callable entry points.

extension Collection {
  @_alwaysEmitIntoClient
  internal var _defaultCount: Int {
    distance(from: startIndex, to: endIndex)
  }
  
  @_alwaysEmitIntoClient
  internal func _defaultDistanceForward(from start: Index, to end: Index) -> Int {
    precondition(start <= end,
                 "Only BidirectionalCollections can have end come before start")
    var start = start
    var count = 0
    while start != end {
      count = count + 1
      formIndex(after: &start)
    }
    return count
  }

  @_alwaysEmitIntoClient
  internal func _defaultAdvanceForward(_ i: Index, by n: Int) -> Index {
    precondition(n >= 0,
                 "Only BidirectionalCollections can be advanced by a negative amount")

    var i = i
    for _ in stride(from: 0, to: n, by: 1) {
      formIndex(after: &i)
    }
    return i
  }

  @_alwaysEmitIntoClient
  internal func _defaultAdvanceForward(
    _ i: Index, by n: Int, limitedBy limit: Index
  ) -> Index? {
    precondition(n >= 0,
                 "Only BidirectionalCollections can be advanced by a negative amount")

    var i = i
    for _ in stride(from: 0, to: n, by: 1) {
      if i == limit {
        return nil
      }
      formIndex(after: &i)
    }
    return i
  }
}

extension BidirectionalCollection {
  @_alwaysEmitIntoClient
  internal func _defaultDistance(from start: Index, to end: Index) -> Int {
    var start = start
    var count = 0
    
    if start < end {
      while start != end {
        count += 1
        formIndex(after: &start)
      }
    }
    else if start > end {
      while start != end {
        count -= 1
        formIndex(before: &start)
      }
    }
    
    return count
  }

  @_alwaysEmitIntoClient
  internal func _defaultIndex(_ i: Index, offsetBy distance: Int) -> Index {
    if distance >= 0 {
      return _defaultAdvanceForward(i, by: distance)
    }
    var i = i
    for _ in stride(from: 0, to: distance, by: -1) {
      formIndex(before: &i)
    }
    return i
  }

  @_alwaysEmitIntoClient
  internal func _defaultIndex(
    _ i: Index, offsetBy distance: Int, limitedBy limit: Index
  ) -> Index? {
    if distance >= 0 {
      return _defaultAdvanceForward(i, by: distance, limitedBy: limit)
    }
    var i = i
    for _ in stride(from: 0, to: distance, by: -1) {
      if i == limit {
        return nil
      }
      formIndex(before: &i)
    }
    return i
  }
}
