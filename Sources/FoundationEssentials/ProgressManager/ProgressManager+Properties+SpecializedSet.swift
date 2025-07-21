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

internal import Synchronization

@available(FoundationPreview 6.2, *)
extension ProgressManager {
    
    //MARK: Methods to set dirty bit recursively
    internal func markSelfDirty<P: Property>(property: P.Type, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty<P: Property>(property: P.Type, parents: [ParentState]) where P.Value == Int {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty<P: Property>(property: P.Type, parents: [ParentState]) where P.Value == Double {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty<P: Property>(property: P.Type, parents: [ParentState]) where P.Value == String {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.TotalFileCount.Type, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.CompletedFileCount.Type, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.TotalByteCount.Type, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.CompletedByteCount.Type, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.Throughput.Type, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.EstimatedTimeRemaining.Type, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markChildDirty<P: Property>(property: P.Type, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].childProperties[AnyMetatypeWrapper(metatype: property)]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty<P: Property>(property: P.Type, at position: Int) where P.Value == Int {
        let parents = state.withLock { state in
            state.children[position].childPropertiesInt[AnyMetatypeWrapper(metatype: property)]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty<P: Property>(property: P.Type, at position: Int) where P.Value == Double {
        let parents = state.withLock { state in
            state.children[position].childPropertiesDouble[AnyMetatypeWrapper(metatype: property)]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty<P: Property>(property: P.Type, at position: Int) where P.Value == String {
        let parents = state.withLock { state in
            state.children[position].childPropertiesString[AnyMetatypeWrapper(metatype: property)]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }

    internal func markChildDirty(property: ProgressManager.Properties.TotalFileCount.Type, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].totalFileCount.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.CompletedFileCount.Type, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].completedFileCount.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.TotalByteCount.Type, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].totalByteCount.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.CompletedByteCount.Type, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].completedByteCount.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.Throughput.Type, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].throughput.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.EstimatedTimeRemaining.Type, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].estimatedTimeRemaining.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    //MARK: Methods to preserve values of properties upon deinit
    internal func setChildRemainingProperties(_ properties: [AnyMetatypeWrapper: (any Sendable)], at position: Int) {
        state.withLock { state in
            state.children[position].remainingProperties = properties
        }
    }
    
    internal func setChildRemainingPropertiesInt(_ properties: [AnyMetatypeWrapper: Int], at position: Int) {
        state.withLock { state in
            state.children[position].remainingPropertiesInt = properties
        }
    }
    
    internal func setChildRemainingPropertiesDouble(_ properties: [AnyMetatypeWrapper: Double], at position: Int) {
        state.withLock { state in
            state.children[position].remainingPropertiesDouble = properties
        }
    }
    
    internal func setChildRemainingPropertiesString(_ properties: [AnyMetatypeWrapper: String], at position: Int) {
        state.withLock { state in
            state.children[position].remainingPropertiesString = properties
        }
    }
    
    internal func setChildTotalFileCount(value: Int, at position: Int) {
        state.withLock { state in
            state.children[position].totalFileCount = PropertyStateInt(value: value, isDirty: false)
        }
    }
    
    internal func setChildCompletedFileCount(value: Int, at position: Int) {
        state.withLock { state in
            state.children[position].completedFileCount = PropertyStateInt(value: value, isDirty: false)
        }
    }
    
    internal func setChildTotalByteCount(value: Int64, at position: Int) {
        state.withLock { state in
            state.children[position].totalByteCount = PropertyStateInt64(value: value, isDirty: false)
        }
    }
    
    internal func setChildCompletedByteCount(value: Int64, at position: Int) {
        state.withLock { state in
            state.children[position].completedByteCount = PropertyStateInt64(value: value, isDirty: false)
        }
    }
    
    internal func setChildThroughput(value: ProgressManager.Properties.Throughput.AggregateThroughput, at position: Int) {
        state.withLock { state in
            state.children[position].throughput = PropertyStateThroughput(value: value, isDirty: false)
        }
    }
    
    internal func setChildEstimatedTimeRemaining(value: Duration, at position: Int) {
        state.withLock { state in
            state.children[position].estimatedTimeRemaining = PropertyStateDuration(value: value, isDirty: false)
        }
    }
}
