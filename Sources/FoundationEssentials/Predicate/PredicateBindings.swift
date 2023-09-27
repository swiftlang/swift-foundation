//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@_nonSendable
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public struct PredicateBindings {
    // Store as a values as an array instead of a dictionary (since it is almost always very few elements, this reduces heap allocation and hashing overhead)
    private var storage: [(id: PredicateExpressions.VariableID, value: Any)]
    
    public init<each T>(_ value: repeat (PredicateExpressions.Variable<each T>, each T)) {
        storage = []
        repeat storage.append(((each value).0.key, (each value).1))
    }
    
    public subscript<T>(_ variable: PredicateExpressions.Variable<T>) -> T? {
        get {
            storage.first {
                $0.id == variable.key
            }?.value as? T
        }
        set {
            let found = storage.firstIndex {
                $0.id == variable.key
            }
            
            guard let newValue else {
                if let found {
                    storage.remove(at: found)
                }
                return
            }
            
            if let found {
                storage[found].value = newValue
            } else {
                storage.append((variable.key, newValue))
            }
        }
    }
    
    public func binding<T>(_ variable: PredicateExpressions.Variable<T>, to value: T) -> Self {
        var mutable = self
        mutable[variable] = value
        return mutable
    }
}
