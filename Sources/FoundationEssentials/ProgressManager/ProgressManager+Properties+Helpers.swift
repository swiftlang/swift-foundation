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

#if canImport(Synchronization)
internal import Synchronization
#endif

@available(FoundationPreview 6.4, *)
extension ProgressManager {
    
    internal enum CountType {
        case total
        case completed
    }
    
    //MARK: Helper Methods for Updating Dirty Path
    internal func updateIntSummary(property: MetatypeWrapper<Int, Int>) -> Int {
        // Get information about dirty children and summaries of non-dirty children
        let updateInfo = state.withLock { state in
            state.getIntSummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.IntSummaryUpdate(index: index, updatedSummary: child.updateIntSummary(property: property))
        }
        
        // Consolidate updated summaries of dirty children and summaries of non-dirty children
        return state.withLock { state in
            state.updateIntSummary(updateInfo, updatedSummaries)
        }
    }
    
    internal func updateUInt64Summary(property: MetatypeWrapper<UInt64, UInt64>) -> UInt64 {
        // Get information about dirty children and summaries of non-dirty children
        let updateInfo = state.withLock { state in
            state.getUInt64SummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.UInt64SummaryUpdate(index: index, updatedSummary: child.updateUInt64Summary(property: property))
        }
        
        // Consolidate updated summaries of dirty children and summaries of non-dirty children
        return state.withLock { state in
            state.updateUInt64Summary(updateInfo, updatedSummaries)
        }
    }
    
    internal func updateDoubleSummary(property: MetatypeWrapper<Double, Double>) -> Double {
        // Get information about dirty children and summaries of non-dirty children
        let updateInfo = state.withLock { state in
            state.getDoubleSummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.DoubleSummaryUpdate(index: index, updatedSummary: child.updateDoubleSummary(property: property))
        }
        
        // Consolidate updated summaries of dirty children and summaries of non-dirty children
        return state.withLock { state in
            state.updateDoubleSummary(updateInfo, updatedSummaries)
        }
    }
    
    internal func updateStringSummary(property: MetatypeWrapper<String?, [String?]>) -> [String?] {
        // Get information about dirty children and summaries of non-dirty children
        let updateInfo = state.withLock { state in
            state.getStringSummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.StringSummaryUpdate(index: index, updatedSummary: child.updateStringSummary(property: property))
        }
        
        // Consolidate updated summaries of dirty children and summaries of non-dirty children
        return state.withLock { state in
            state.updateStringSummary(updateInfo, updatedSummaries)
        }
    }
    
    internal func updateURLSummary(property: MetatypeWrapper<URL?, [URL?]>) -> [URL?] {
        // Get information about dirty children and summaries of non-dirty children
        let updateInfo = state.withLock { state in
            state.getURLSummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.URLSummaryUpdate(index: index, updatedSummary: child.updateURLSummary(property: property))
        }
        
        // Consolidate updated summaries of dirty children and summaries of non-dirty children
        return state.withLock { state in
            state.updateURLSummary(updateInfo, updatedSummaries)
        }
    }
    
    internal func updateUInt64ArraySummary(property: MetatypeWrapper<UInt64, [UInt64]>) -> [UInt64] {
        // Get information about dirty children and summaries of non-dirty children
        let updateInfo = state.withLock { state in
            state.getUInt64ArraySummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.UInt64ArraySummaryUpdate(index: index, updatedSummary: child.updateUInt64ArraySummary(property: property))
        }
        
        // Consolidate updated summaries of dirty children and summaries of non-dirty children
        return state.withLock { state in
            state.updateUInt64ArraySummary(updateInfo, updatedSummaries)
        }
    }
    
    internal func updateDurationSummary(property: MetatypeWrapper<Duration, Duration>) -> Duration {
        // Get information about dirty children and summaries of non-dirty children
        let updateInfo = state.withLock { state in
            state.getDurationSummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.DurationSummaryUpdate(index: index, updatedSummary: child.updateDurationSummary(property: property))
        }
        
        // Consolidate updated summaries of dirty children and summaries of non-dirty children
        return state.withLock { state in
            state.updateDurationSummary(updateInfo, updatedSummaries)
        }
    }
    
    internal func updateFileCount(type: CountType) -> Int {
        // Get information about dirty children and summaries of non-dirty children
        let updateInfo = state.withLock { state in
            state.getFileCountUpdateInfo(type: type)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.FileCountUpdate(index: index, updatedSummary: child.updateFileCount(type: type))
        }
        
        // Consolidate updated summaries of dirty children and summaries of non-dirty children
        return state.withLock { state in
            state.updateFileCount(updateInfo, updatedSummaries)
        }
    }
    
    internal func updateByteCount(type: CountType) -> UInt64 {
        // Get information about dirty children and summaries of non-dirty children
        let updateInfo = state.withLock { state in
            state.getByteCountUpdateInfo(type: type)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.ByteCountUpdate(index: index, updatedSummary: child.updateByteCount(type: type))
        }
        
        // Consolidate updated summaries of dirty children and summaries of non-dirty children
        return state.withLock { state in
            state.updateByteCount(updateInfo, updatedSummaries)
        }
    }
    
    internal func updateThroughput() -> [UInt64] {
        // Get information about dirty children and summaries of non-dirty children
        let updateInfo = state.withLock { state in
            state.getThroughputUpdateInfo()
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.ThroughputUpdate(index: index, updatedSummary: child.updateThroughput())
        }
        
        // Consolidate updated summaries of dirty children and summaries of non-dirty children
        return state.withLock { state in
            state.updateThroughput(updateInfo, updatedSummaries)
        }
    }
    
    internal func updateEstimatedTimeRemaining() -> Duration {
        // Get information about dirty children and summaries of non-dirty children
        let updateInfo = state.withLock { state in
            state.getEstimatedTimeRemainingUpdateInfo()
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.EstimatedTimeRemainingUpdate(index: index, updatedSummary: child.updateEstimatedTimeRemaining())
        }
        
        // Consolidate updated summaries of dirty children and summaries of non-dirty children
        return state.withLock { state in
            state.updateEstimatedTimeRemaining(updateInfo, updatedSummaries)
        }
    }
    
    //MARK: Helper Methods for Setting Dirty Paths
    internal func markSelfDirty(property: MetatypeWrapper<Int, Int>, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<UInt64, UInt64>, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<Double, Double>, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<String?, [String?]>, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<URL?, [URL?]>, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<UInt64, [UInt64]>, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<Duration, Duration>, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.TotalFileCount.Type, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.CompletedFileCount.Type, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.TotalByteCount.Type, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.CompletedByteCount.Type, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.Throughput.Type, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.EstimatedTimeRemaining.Type, parents: [Parent]) {
        for parent in parents {
            parent.manager.markChildDirty(property: property, at: parent.positionInParent)
        }
    }
    
    internal func markChildDirty(property: MetatypeWrapper<Int, Int>, at position: Int) {
        self.willSet(keyPath: \.customPropertiesIntSummary)
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<UInt64, UInt64>, at position: Int) {
        self.willSet(keyPath: \.customPropertiesUInt64Summary)
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<Double, Double>, at position: Int) {
        self.willSet(keyPath: \.customPropertiesDoubleSummary)
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<String?, [String?]>, at position: Int) {
        self.willSet(keyPath: \.customPropertiesStringSummary)
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<URL?, [URL?]>, at position: Int) {
        self.willSet(keyPath: \.customPropertiesURLSummary)
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<UInt64, [UInt64]>, at position: Int) {
        self.willSet(keyPath: \.customPropertiesUInt64ArraySummary)
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<Duration, Duration>, at position: Int) {
        self.willSet(keyPath: \.customPropertiesDurationSummary)
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }

    internal func markChildDirty(property: ProgressManager.Properties.TotalFileCount.Type, at position: Int) {
        self.willSet(keyPath: \.totalFileCountSummary)
            let parents = state.withLock { state in
                state.markChildDirty(property: property, at: position)
            }
            markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.CompletedFileCount.Type, at position: Int) {
        self.willSet(keyPath: \.completedFileCountSummary)
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.TotalByteCount.Type, at position: Int) {
        self.willSet(keyPath: \.totalByteCountSummary)
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.CompletedByteCount.Type, at position: Int) {
        self.willSet(keyPath: \.completedByteCountSummary)
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.Throughput.Type, at position: Int) {
        self.willSet(keyPath: \.throughputSummary)
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.EstimatedTimeRemaining.Type, at position: Int) {
        self.willSet(keyPath: \.estimatedTimeRemainingSummary)
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    //MARK: Method to preserve values of properties upon deinit
    internal func setChildDeclaredAdditionalProperties(at position: Int, totalFileCount: Int, completedFileCount: Int, totalByteCount: UInt64, completedByteCount: UInt64, throughput: [UInt64], estimatedTimeRemaining: Duration, propertiesInt: [MetatypeWrapper<Int, Int>: Int], propertiesUInt64: [MetatypeWrapper<UInt64, UInt64>: UInt64], propertiesDouble: [MetatypeWrapper<Double, Double>: Double], propertiesString: [MetatypeWrapper<String?, [String?]>: [String?]], propertiesURL: [MetatypeWrapper<URL?, [URL?]>: [URL?]], propertiesUInt64Array: [MetatypeWrapper<UInt64, [UInt64]>: [UInt64]], propertiesDuration: [MetatypeWrapper<Duration, Duration>: Duration]) {
        state.withLock { state in
            // The children's values are marked as non-dirty because these values are going to be in the leaf nodes. The dirty bit usually signals that there is a need to call helper method child.updated<Property>Summary to iterate through this child's children to get updated values. But since after this level the child is already deinit, that means there is no need to clear dirty bits anymore.
            state.children[position].totalFileCountSummary = PropertyStateInt(value: totalFileCount, isDirty: false)
            state.children[position].completedFileCountSummary = PropertyStateInt(value: completedFileCount, isDirty: false)
            state.children[position].totalByteCountSummary = PropertyStateUInt64(value: totalByteCount, isDirty: false)
            state.children[position].completedByteCountSummary = PropertyStateUInt64(value: completedByteCount, isDirty: false)
            state.children[position].throughputSummary = PropertyStateUInt64Array(value: throughput, isDirty: false)
            state.children[position].estimatedTimeRemainingSummary = PropertyStateDuration(value: estimatedTimeRemaining, isDirty: false)
            
            for (propertyKey, propertyValue) in propertiesInt {
                state.children[position].customPropertiesIntSummary[propertyKey] = PropertyStateInt(value: propertyValue, isDirty: false)
            }
            
            for (propertyKey, propertyValue) in propertiesUInt64 {
                state.children[position].customPropertiesUInt64Summary[propertyKey] = PropertyStateUInt64(value: propertyValue, isDirty: false)
            }
            
            for (propertyKey, propertyValue) in propertiesDouble {
                state.children[position].customPropertiesDoubleSummary[propertyKey] = PropertyStateDouble(value: propertyValue, isDirty: false)
            }
            
            for (propertyKey, propertyValue) in propertiesString {
                state.children[position].customPropertiesStringSummary[propertyKey] = PropertyStateString(value: propertyValue, isDirty: false)
            }
            
            for (propertyKey, propertyValue) in propertiesURL {
                state.children[position].customPropertiesURLSummary[propertyKey] = PropertyStateURL(value: propertyValue, isDirty: false)
            }
            
            for (propertyKey, propertyValue) in propertiesUInt64Array {
                state.children[position].customPropertiesUInt64ArraySummary[propertyKey] = PropertyStateUInt64Array(value: propertyValue, isDirty: false)
            }
            
            for (propertyKey, propertyValue) in propertiesDuration {
                state.children[position].customPropertiesDurationSummary[propertyKey] = PropertyStateDuration(value: propertyValue, isDirty: false)
            }
        }
    }
}
