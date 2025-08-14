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
    
    internal enum CountType {
        case total
        case completed
    }
    
    //MARK: Methods to get updated summary of properties
    internal func getUpdatedIntSummary(property: MetatypeWrapper<Int>) -> Int {
        return state.withLock { state in
            
            var value: Int = property.defaultSummary
            property.reduce(&value, state.propertiesInt[property] ?? property.defaultValue)
            
            guard !state.children.isEmpty else {
                return value
            }
             
            for (idx, childState) in state.children.enumerated() {
                if let childPropertyState = childState.childPropertiesInt[property] {
                    if childPropertyState.isDirty {
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedIntSummary(property: property)
                            let newChildPropertyState = PropertyStateInt(value: updatedSummary, isDirty: false)
                            state.children[idx].childPropertiesInt[property] = newChildPropertyState
                            value = property.merge(value, updatedSummary)
                        } else {
                            if let remainingProperties = childState.remainingPropertiesInt {
                                if let remainingSummary = remainingProperties[property] {
                                    value = property.merge(value, remainingSummary)
                                }
                            }
                        }
                    } else {
                        value = property.merge(value, childPropertyState.value)
                    }
                } else {
                    if let child = childState.child {
                        let childSummary = child.getUpdatedIntSummary(property: property)
                        let newChildPropertyState = PropertyStateInt(value: childSummary, isDirty: false)
                        state.children[idx].childPropertiesInt[property] = newChildPropertyState
                        value = property.merge(value, childSummary)
                    } else {
                        // Get value from remainingProperties
                        if let remainingProperties = childState.remainingPropertiesInt {
                            if let remainingSummary = remainingProperties[property] {
                                value = property.merge(value, remainingSummary)
                            }
                        }
                    }
                }
            }
            return value
        }
    }
    
    internal func getUpdatedDoubleSummary(property: MetatypeWrapper<Double>) -> Double {
        return state.withLock { state in
            
            var value: Double = property.defaultSummary
            property.reduce(&value, state.propertiesDouble[property] ?? property.defaultValue)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if let childPropertyState = childState.childPropertiesDouble[property] {
                    if childPropertyState.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedDoubleSummary(property: property)
                            let newChildPropertyState = PropertyStateDouble(value: updatedSummary, isDirty: false)
                            state.children[idx].childPropertiesDouble[property] = newChildPropertyState
                            value = property.merge(value, updatedSummary)
                        } else {
                            // Get value from remainingProperties
                            if let remainingProperties = childState.remainingPropertiesDouble {
                                if let remainingSummary = remainingProperties[property] {
                                    value = property.merge(value, remainingSummary)
                                }
                            }
                        }
                    } else {
                        // Merge non-dirty, updated value
                        value = property.merge(value, childPropertyState.value)
                    }
                } else {
                    // First fetch of value
                    if let child = childState.child {
                        let childSummary = child.getUpdatedDoubleSummary(property: property)
                        let newChildPropertyState = PropertyStateDouble(value: childSummary, isDirty: false)
                        state.children[idx].childPropertiesDouble[property] = newChildPropertyState
                        value = property.merge(value, childSummary)
                    } else {
                        // Get value from remainingProperties
                        if let remainingProperties = childState.remainingPropertiesDouble {
                            if let remainingSummary = remainingProperties[property] {
                                value = property.merge(value, remainingSummary)
                            }
                        }
                    }
                }
            }
            return value
        }
    }
    
    internal func getUpdatedStringSummary(property: MetatypeWrapper<String>) -> String {
        return state.withLock { state in
            
            var value: String = property.defaultSummary
            property.reduce(&value, state.propertiesString[property] ?? property.defaultValue)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if let childPropertyState = childState.childPropertiesString[property] {
                    if childPropertyState.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedStringSummary(property: property)
                            let newChildPropertyState = PropertyStateString(value: updatedSummary, isDirty: false)
                            state.children[idx].childPropertiesString[property] = newChildPropertyState
                            value = property.merge(value, updatedSummary)
                        } else {
                            // Get value from remainingProperties
                            if let remainingProperties = childState.remainingPropertiesString {
                                if let remainingSummary = remainingProperties[property] {
                                    value = property.merge(value, remainingSummary)
                                }
                            }
                        }
                    } else {
                        // Merge non-dirty, updated value
                        value = property.merge(value, childPropertyState.value)
                    }
                } else {
                    // First fetch of value
                    if let child = childState.child {
                        let childSummary = child.getUpdatedStringSummary(property: property)
                        let newChildPropertyState = PropertyStateString(value: childSummary, isDirty: false)
                        state.children[idx].childPropertiesString[property] = newChildPropertyState
                        value = property.merge(value, childSummary)
                    } else {
                        // Get value from remainingProperties
                        if let remainingProperties = childState.remainingPropertiesString {
                            if let remainingSummary = remainingProperties[property] {
                                value = property.merge(value, remainingSummary)
                            }
                        }
                    }
                }
            }
            return value
        }
    }
    
    internal func getUpdatedFileCount(type: CountType) -> Int {
        switch type {
        case .total:
            return state.withLock { state in
                // Get self's totalFileCount as part of summary
                var value: Int = 0
                ProgressManager.Properties.TotalFileCount.reduce(into: &value, value: state.totalFileCount)
                
                guard !state.children.isEmpty else {
                    return value
                }
                
                for (idx, childState) in state.children.enumerated() {
                    if childState.totalFileCount.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedFileCount(type: type)
                            let newTotalFileCountState = PropertyStateInt(value: updatedSummary, isDirty: false)
                            state.children[idx].totalFileCount =  newTotalFileCountState
                            value = ProgressManager.Properties.TotalFileCount.merge(value, updatedSummary)
                        }
                    } else {
                        // Merge non-dirty, updated value
                        value = ProgressManager.Properties.TotalFileCount.merge(value, childState.totalFileCount.value)
                    }
                }
                return value
            }
        case .completed:
            return state.withLock { state in
                // Get self's completedFileCount as part of summary
                var value: Int = 0
                ProgressManager.Properties.CompletedFileCount.reduce(into: &value, value: state.completedFileCount)
                
                guard !state.children.isEmpty else {
                    return value
                }
                
                for (idx, childState) in state.children.enumerated() {
                    if childState.completedFileCount.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedFileCount(type: type)
                            let newCompletedFileCountState = PropertyStateInt(value: updatedSummary, isDirty: false)
                            state.children[idx].completedFileCount =  newCompletedFileCountState
                            value = ProgressManager.Properties.CompletedFileCount.merge(value, updatedSummary)
                        }
                    } else {
                        // Merge non-dirty, updated value
                        value = ProgressManager.Properties.CompletedFileCount.merge(value, childState.completedFileCount.value)
                    }
                }
                return value
            }
        }
    }
    
    internal func getUpdatedByteCount(type: CountType) -> UInt64 {
        switch type {
        case .total:
            return state.withLock { state in
                // Get self's totalByteCount as part of summary
                var value: UInt64 = 0
                ProgressManager.Properties.TotalByteCount.reduce(into: &value, value: state.totalByteCount)
                
                guard !state.children.isEmpty else {
                    return value
                }
                
                for (idx, childState) in state.children.enumerated() {
                    if childState.totalByteCount.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedByteCount(type: type)
                            let newTotalByteCountState = PropertyStateUInt64(value: updatedSummary, isDirty: false)
                            state.children[idx].totalByteCount =  newTotalByteCountState
                            value = ProgressManager.Properties.TotalByteCount.merge(value, updatedSummary)
                        }
                    } else {
                        // Merge non-dirty, updated value
                        value = ProgressManager.Properties.TotalByteCount.merge(value, childState.totalByteCount.value)
                    }
                }
                return value
            }
        case .completed:
            return state.withLock { state in
                // Get self's completedByteCount as part of summary
                var value: UInt64 = 0
                ProgressManager.Properties.CompletedByteCount.reduce(into: &value, value: state.completedByteCount)
                
                guard !state.children.isEmpty else {
                    return value
                }
                
                for (idx, childState) in state.children.enumerated() {
                    if childState.completedByteCount.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedByteCount(type: type)
                            let newCompletedByteCountState = PropertyStateUInt64(value: updatedSummary, isDirty: false)
                            state.children[idx].completedByteCount =  newCompletedByteCountState
                            value = ProgressManager.Properties.CompletedByteCount.merge(value, updatedSummary)
                        }
                    } else {
                        // Merge non-dirty, updated value
                        value = ProgressManager.Properties.CompletedByteCount.merge(value, childState.completedByteCount.value)
                    }
                }
                return value
            }
        }
    }
    
    internal func getUpdatedThroughput() -> [UInt64] {
        return state.withLock { state in
            // Get self's throughput as part of summary
            var value = ProgressManager.Properties.Throughput.defaultSummary
            ProgressManager.Properties.Throughput.reduce(into: &value, value: state.throughput)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if childState.throughput.isDirty {
                    // Update dirty path
                    if let child = childState.child {
                        let updatedSummary = child.getUpdatedThroughput()
                        let newThroughputState = PropertyStateThroughput(value: updatedSummary, isDirty: false)
                        state.children[idx].throughput = newThroughputState
                        value = ProgressManager.Properties.Throughput.merge(value, updatedSummary)
                    }
                } else {
                    // Merge non-dirty, updated value
                    value = ProgressManager.Properties.Throughput.merge(value, childState.throughput.value)
                }
            }
            return value
        }
    }
    
    internal func getUpdatedEstimatedTimeRemaining() -> Duration {
        return state.withLock { state in
            // Get self's estimatedTimeRemaining as part of summary
            var value: Duration = Duration.seconds(0)
            ProgressManager.Properties.EstimatedTimeRemaining.reduce(into: &value, value: state.estimatedTimeRemaining)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if childState.estimatedTimeRemaining.isDirty {
                    // Update dirty path
                    if let child = childState.child {
                        let updatedSummary = child.getUpdatedEstimatedTimeRemaining()
                        let newDurationState = PropertyStateDuration(value: updatedSummary, isDirty: false)
                        state.children[idx].estimatedTimeRemaining = newDurationState
                        value = ProgressManager.Properties.EstimatedTimeRemaining.merge(value, updatedSummary)
                    }
                } else {
                    // Merge non-dirty, updated value
                    value = ProgressManager.Properties.EstimatedTimeRemaining.merge(value, childState.estimatedTimeRemaining.value)
                }
            }
            return value
        }
    }
    
    internal func getUpdatedFileURL() -> [URL?] {
        return state.withLock { state in
            // Get self's estimatedTimeRemaining as part of summary
            var value: [URL?] = ProgressManager.Properties.FileURL.defaultSummary
            ProgressManager.Properties.FileURL.reduce(into: &value, value: state.fileURL)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if childState.fileURL.isDirty {
                    // Update dirty path
                    if let child = childState.child {
                        let updatedSummary = child.getUpdatedFileURL()
                        let newFileURL = PropertyStateURL(value: updatedSummary, isDirty: false)
                        state.children[idx].fileURL = newFileURL
                        value = ProgressManager.Properties.FileURL.merge(value, updatedSummary)
                    }
                } else {
                    // Merge non-dirty, updated value
                    value = ProgressManager.Properties.FileURL.merge(value, childState.fileURL.value)
                }
            }
            return value
        }
    }
    
    //MARK: Methods to set dirty bit recursively
    internal func markSelfDirty(property: MetatypeWrapper<Int>, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<Double>, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<String>, parents: [ParentState]) {
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
    
    internal func markSelfDirty(property: ProgressManager.Properties.FileURL.Type, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markChildDirty(property: MetatypeWrapper<Int>, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].childPropertiesInt[property]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<Double>, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].childPropertiesDouble[property]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<String>, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].childPropertiesString[property]?.isDirty = true
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
    
    internal func markChildDirty(property: ProgressManager.Properties.FileURL.Type, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].fileURL.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    //MARK: Methods to preserve values of properties upon deinit
    internal func setChildRemainingPropertiesInt(_ properties: [MetatypeWrapper<Int>: Int], at position: Int) {
        state.withLock { state in
            state.children[position].remainingPropertiesInt = properties
        }
    }
    
    internal func setChildRemainingPropertiesDouble(_ properties: [MetatypeWrapper<Double>: Double], at position: Int) {
        state.withLock { state in
            state.children[position].remainingPropertiesDouble = properties
        }
    }
    
    internal func setChildRemainingPropertiesString(_ properties: [MetatypeWrapper<String>: String], at position: Int) {
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
    
    internal func setChildTotalByteCount(value: UInt64, at position: Int) {
        state.withLock { state in
            state.children[position].totalByteCount = PropertyStateUInt64(value: value, isDirty: false)
        }
    }
    
    internal func setChildCompletedByteCount(value: UInt64, at position: Int) {
        state.withLock { state in
            state.children[position].completedByteCount = PropertyStateUInt64(value: value, isDirty: false)
        }
    }
    
    internal func setChildThroughput(value: [UInt64], at position: Int) {
        state.withLock { state in
            state.children[position].throughput = PropertyStateThroughput(value: value, isDirty: false)
        }
    }
}
