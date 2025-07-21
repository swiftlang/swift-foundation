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
    
    @_disfavoredOverload
    internal func markSelfDirty<P: Property>(property: P.Type, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    @_disfavoredOverload
    internal func markSelfDirty<P: Property>(property: P.Type, parents: [ParentState]) where P.Value == Int {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    @_disfavoredOverload
    internal func markSelfDirty<P: Property>(property: P.Type, parents: [ParentState]) where P.Value == Double {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    @_disfavoredOverload
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
    
    @_disfavoredOverload
    internal func markChildDirty<P: Property>(property: P.Type, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].childProperties[AnyMetatypeWrapper(metatype: property)]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    @_disfavoredOverload
    internal func markChildDirty<P: Property>(property: P.Type, at position: Int) where P.Value == Int {
        let parents = state.withLock { state in
            state.children[position].childPropertiesInt[AnyMetatypeWrapper(metatype: property)]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    @_disfavoredOverload
    internal func markChildDirty<P: Property>(property: P.Type, at position: Int) where P.Value == Double {
        let parents = state.withLock { state in
            state.children[position].childPropertiesDouble[AnyMetatypeWrapper(metatype: property)]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    @_disfavoredOverload
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
}
