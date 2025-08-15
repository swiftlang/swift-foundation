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
    
    //MARK: Helper Methods for Updating Dirty Path
    
    internal func getUpdatedIntSummary(property: MetatypeWrapper<Int, Int>) -> Int {
        return state.withLock { state in
            
            var value: Int = property.defaultSummary
            property.reduce(&value, state.propertiesInt[property] ?? property.defaultValue)
            
            guard !state.children.isEmpty else {
                return value
            }
             
            for (idx, childState) in state.children.enumerated() {
                if let childPropertyState = childState.childPropertiesInt[property] {
                    if childPropertyState.isDirty {
                        // Dirty, needs to fetch value
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedIntSummary(property: property)
                            let newChildPropertyState = PropertyStateInt(value: updatedSummary, isDirty: false)
                            state.children[idx].childPropertiesInt[property] = newChildPropertyState
                            value = property.merge(value, updatedSummary)
                        }
                    } else {
                        // Not dirty, use value directly
                        if let _ = childState.child {
                            value = property.merge(value, childPropertyState.value)
                        } else {
                            // TODO: What to do after terminate? Set to nil?
                            value = property.terminate(value, childPropertyState.value)
                        }
                    }
                } else {
                    // Said property doesn't even get cached yet, but children might have been set
                    if let child = childState.child {
                        // If there is a child
                        let childSummary = child.getUpdatedIntSummary(property: property)
                        let newChildPropertyState = PropertyStateInt(value: childSummary, isDirty: false)
                        state.children[idx].childPropertiesInt[property] = newChildPropertyState
                        value = property.merge(value, childSummary)
                    }
                }
            }
            return value
        }
    }
    
    internal func getUpdatedDoubleSummary(property: MetatypeWrapper<Double, Double>) -> Double {
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
                        }
                    } else {
                        if let _ = childState.child {
                            // Merge non-dirty, updated value
                            value = property.merge(value, childPropertyState.value)
                        } else {
                            value = property.terminate(value, childPropertyState.value)
                        }
                    }
                } else {
                    // First fetch of value
                    if let child = childState.child {
                        let childSummary = child.getUpdatedDoubleSummary(property: property)
                        let newChildPropertyState = PropertyStateDouble(value: childSummary, isDirty: false)
                        state.children[idx].childPropertiesDouble[property] = newChildPropertyState
                        value = property.merge(value, childSummary)
                    }
                }
            }
            return value
        }
    }
    
    internal func getUpdatedStringSummary(property: MetatypeWrapper<String?, [String?]>) -> [String?] {
        return state.withLock { state in
            
            var value: [String?] = property.defaultSummary
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
                        }
                    } else {
                        if let _ = childState.child {
                            // Merge non-dirty, updated value
                            value = property.merge(value, childPropertyState.value)
                        } else {
                            value = property.terminate(value, childPropertyState.value)
                        }
                    }
                } else {
                    // First fetch of value
                    if let child = childState.child {
                        let childSummary = child.getUpdatedStringSummary(property: property)
                        let newChildPropertyState = PropertyStateString(value: childSummary, isDirty: false)
                        state.children[idx].childPropertiesString[property] = newChildPropertyState
                        value = property.merge(value, childSummary)
                    }
                }
            }
            return value
        }
    }
    
    internal func getUpdatedURLSummary(property: MetatypeWrapper<URL?, [URL?]>) -> [URL?] {
        return state.withLock { state in
            
            var value: [URL?] = property.defaultSummary
            property.reduce(&value, state.propertiesURL[property] ?? property.defaultValue)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if let childPropertyState = childState.childPropertiesURL[property] {
                    if childPropertyState.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedURLSummary(property: property)
                            let newChildPropertyState = PropertyStateURL(value: updatedSummary, isDirty: false)
                            state.children[idx].childPropertiesURL[property] = newChildPropertyState
                            value = property.merge(value, updatedSummary)
                        }
                    } else {
                        if let _ = childState.child {
                            // Merge non-dirty, updated value
                            value = property.merge(value, childPropertyState.value)
                        } else {
                            value = property.terminate(value, childPropertyState.value)
                        }
                    }
                } else {
                    // First fetch of value
                    if let child = childState.child {
                        let childSummary = child.getUpdatedURLSummary(property: property)
                        let newChildPropertyState = PropertyStateURL(value: childSummary, isDirty: false)
                        state.children[idx].childPropertiesURL[property] = newChildPropertyState
                        value = property.merge(value, childSummary)
                    }
                }
            }
            return value
        }
    }
    
    internal func getUpdatedUInt64Summary(property: MetatypeWrapper<UInt64, [UInt64]>) -> [UInt64] {
        return state.withLock { state in
            
            var value: [UInt64] = property.defaultSummary
            property.reduce(&value, state.propertiesUInt64[property] ?? property.defaultValue)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if let childPropertyState = childState.childPropertiesUInt64[property] {
                    if childPropertyState.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedUInt64Summary(property: property)
                            let newChildPropertyState = PropertyStateThroughput(value: updatedSummary, isDirty: false)
                            state.children[idx].childPropertiesUInt64[property] = newChildPropertyState
                            value = property.merge(value, updatedSummary)
                        }
                    } else {
                        if let _ = childState.child {
                            // Merge non-dirty, updated value
                            value = property.merge(value, childPropertyState.value)
                        } else {
                            value = property.terminate(value, childPropertyState.value)
                        }
                    }
                } else {
                    // First fetch of value
                    if let child = childState.child {
                        let childSummary = child.getUpdatedUInt64Summary(property: property)
                        let newChildPropertyState = PropertyStateThroughput(value: childSummary, isDirty: false)
                        state.children[idx].childPropertiesUInt64[property] = newChildPropertyState
                        value = property.merge(value, childSummary)
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
                        if let _ = childState.child {
                            // Merge non-dirty, updated value
                            value = ProgressManager.Properties.TotalFileCount.merge(value, childState.totalFileCount.value)
                        } else {
                            value = ProgressManager.Properties.TotalFileCount.terminate(value, childState.totalFileCount.value)
                        }
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
                        if let _ = childState.child {
                            // Merge non-dirty, updated value
                            value = ProgressManager.Properties.CompletedFileCount.merge(value, childState.completedFileCount.value)
                        } else {
                            value = ProgressManager.Properties.CompletedFileCount.terminate(value, childState.completedFileCount.value)
                        }
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
                        if let _ = childState.child {
                            // Merge non-dirty, updated value
                            value = ProgressManager.Properties.TotalByteCount.merge(value, childState.totalByteCount.value)
                        } else {
                            value = ProgressManager.Properties.TotalByteCount.terminate(value, childState.totalByteCount.value)
                        }
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
                        if let _ = childState.child {
                            // Merge non-dirty, updated value
                            value = ProgressManager.Properties.CompletedByteCount.merge(value, childState.completedByteCount.value)
                        } else {
                            value = ProgressManager.Properties.CompletedByteCount.terminate(value, childState.completedByteCount.value)
                        }
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
                    if let _ = childState.child {
                        // Merge non-dirty, updated value
                        value = ProgressManager.Properties.Throughput.merge(value, childState.throughput.value)
                    } else {
                        value = ProgressManager.Properties.Throughput.terminate(value, childState.throughput.value)
                    }
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
                    if let _ = childState.child {
                        // Merge non-dirty, updated value
                        value = ProgressManager.Properties.EstimatedTimeRemaining.merge(value, childState.estimatedTimeRemaining.value)
                    } else {
                        value = ProgressManager.Properties.EstimatedTimeRemaining.terminate(value, childState.estimatedTimeRemaining.value)
                    }
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
                    if let _ = childState.child {
                        // Merge non-dirty, updated value
                        value = ProgressManager.Properties.FileURL.merge(value, childState.fileURL.value)
                    } else {
                        value = ProgressManager.Properties.FileURL.terminate(value, childState.fileURL.value)
                    }
                }
            }
            return value
        }
    }
    
    //MARK: Helper Methods for Setting Dirty Paths
    
    internal func markSelfDirty(property: MetatypeWrapper<Int, Int>, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<Double, Double>, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<String?, [String?]>, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<URL?, [URL?]>, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<UInt64, [UInt64]>, parents: [ParentState]) {
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
    
    internal func markChildDirty(property: MetatypeWrapper<Int, Int>, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].childPropertiesInt[property]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<Double, Double>, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].childPropertiesDouble[property]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<String?, [String?]>, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].childPropertiesString[property]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<URL?, [URL?]>, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].childPropertiesURL[property]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<UInt64, [UInt64]>, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].childPropertiesUInt64[property]?.isDirty = true
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
    
    //MARK: Method to preserve values of properties upon deinit
    internal func setChildDeclaredAdditionalProperties(at position: Int, totalFileCount: Int, completedFileCount: Int, totalByteCount: UInt64, completedByteCount: UInt64, throughput: [UInt64], estimatedTimeRemaining: Duration, fileURL: [URL?], propertiesInt: [MetatypeWrapper<Int, Int>: Int], propertiesDouble: [MetatypeWrapper<Double, Double>: Double], propertiesString: [MetatypeWrapper<String?, [String?]>: [String?]], propertiesURL: [MetatypeWrapper<URL?, [URL?]>: [URL?]], propertiesUInt64: [MetatypeWrapper<UInt64, [UInt64]>: [UInt64]]) {
        state.withLock { state in
            state.children[position].totalFileCount = PropertyStateInt(value: totalFileCount, isDirty: false)
            state.children[position].completedFileCount = PropertyStateInt(value: completedFileCount, isDirty: false)
            state.children[position].totalByteCount = PropertyStateUInt64(value: totalByteCount, isDirty: false)
            state.children[position].completedByteCount = PropertyStateUInt64(value: completedByteCount, isDirty: false)
            state.children[position].throughput = PropertyStateThroughput(value: throughput, isDirty: false)
            state.children[position].estimatedTimeRemaining = PropertyStateDuration(value: estimatedTimeRemaining, isDirty: false)
            state.children[position].fileURL = PropertyStateURL(value: fileURL, isDirty: false)
            
            for (propertyKey, propertyValue) in propertiesInt {
                state.children[position].childPropertiesInt[propertyKey] = PropertyStateInt(value: propertyValue, isDirty: false)
            }
            
            for (propertyKey, propertyValue) in propertiesDouble {
                state.children[position].childPropertiesDouble[propertyKey] = PropertyStateDouble(value: propertyValue, isDirty: false)
            }
            
            for (propertyKey, propertyValue) in propertiesString {
                state.children[position].childPropertiesString[propertyKey] = PropertyStateString(value: propertyValue, isDirty: false)
            }
            
            for (propertyKey, propertyValue) in propertiesURL {
                state.children[position].childPropertiesURL[propertyKey] = PropertyStateURL(value: propertyValue, isDirty: false)
            }
            
            for (propertyKey, propertyValue) in propertiesUInt64 {
                state.children[position].childPropertiesUInt64[propertyKey] = PropertyStateThroughput(value: propertyValue, isDirty: false)
            }
        }
    }
}
