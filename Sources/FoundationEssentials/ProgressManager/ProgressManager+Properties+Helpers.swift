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
@available(FoundationPreview 6.3, *)
extension ProgressManager {
    
    internal enum CountType {
        case total
        case completed
    }
    
    //MARK: Helper Methods for Updating Dirty Path
    internal func getUpdatedIntSummary(property: MetatypeWrapper<Int, Int>) -> Int {
        // Collect information from state
        let updateInfo = state.withLock { state in
            state.getIntSummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.IntSummaryUpdate(index: index, updatedSummary: child.getUpdatedIntSummary(property: property))
        }
        
        // Consolidate updated values
        return state.withLock { state in
            state.updateIntSummary(updateInfo, updatedSummaries)
        }
    }
    
    internal func getUpdatedUInt64Summary(property: MetatypeWrapper<UInt64, UInt64>) -> UInt64 {
        // Collect information from state
        let updateInfo = state.withLock { state in
            state.getUInt64SummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.UInt64SummaryUpdate(index: index, updatedSummary: child.getUpdatedUInt64Summary(property: property))
        }
        
        // Consolidate updated values
        return state.withLock { state in
            state.updateUInt64Summary(updateInfo, updatedSummaries)
        }
    }
    
    internal func getUpdatedDoubleSummary(property: MetatypeWrapper<Double, Double>) -> Double {
        // Collect information from state
        let updateInfo = state.withLock { state in
            state.getDoubleSummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.DoubleSummaryUpdate(index: index, updatedSummary: child.getUpdatedDoubleSummary(property: property))
        }
        
        // Consolidate updated values
        return state.withLock { state in
            state.updateDoubleSummary(updateInfo, updatedSummaries)
        }
    }
    
    internal func getUpdatedStringSummary(property: MetatypeWrapper<String?, [String?]>) -> [String?] {
        // Collect information from state
        let updateInfo = state.withLock { state in
            state.getStringSummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.StringSummaryUpdate(index: index, updatedSummary: child.getUpdatedStringSummary(property: property))
        }
        
        // Consolidate updated values
        return state.withLock { state in
            state.updateStringSummary(updateInfo, updatedSummaries)
        }
    }
    
    internal func getUpdatedURLSummary(property: MetatypeWrapper<URL?, [URL?]>) -> [URL?] {
        // Collect information from state
        let updateInfo = state.withLock { state in
            state.getURLSummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.URLSummaryUpdate(index: index, updatedSummary: child.getUpdatedURLSummary(property: property))
        }
        
        // Consolidate updated values
        return state.withLock { state in
            state.updateURLSummary(updateInfo, updatedSummaries)
        }
    }
    
    internal func getUpdatedUInt64ArraySummary(property: MetatypeWrapper<UInt64, [UInt64]>) -> [UInt64] {
        // Collect information from state
        let updateInfo = state.withLock { state in
            state.getUInt64ArraySummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.UInt64ArraySummaryUpdate(index: index, updatedSummary: child.getUpdatedUInt64ArraySummary(property: property))
        }
        
        // Consolidate updated values
        return state.withLock { state in
            state.updateUInt64ArraySummary(updateInfo, updatedSummaries)
        }
    }
    
    internal func getUpdatedDurationSummary(property: MetatypeWrapper<Duration, Duration>) -> Duration {
        // Collect information from state
        let updateInfo = state.withLock { state in
            state.getDurationSummaryUpdateInfo(property: property)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.DurationSummaryUpdate(index: index, updatedSummary: child.getUpdatedDurationSummary(property: property))
        }
        
        // Consolidate updated values
        return state.withLock { state in
            state.updateDurationSummary(updateInfo, updatedSummaries)
        }
    }
    
    internal func getUpdatedFileCount(type: CountType) -> Int {
        // Collect information from state
        let updateInfo = state.withLock { state in
            state.getFileCountUpdateInfo(type: type)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.FileCountUpdate(index: index, updatedSummary: child.getUpdatedFileCount(type: type))
        }
        
        // Consolidate updated values
        return state.withLock { state in
            state.updateFileCount(updateInfo, updatedSummaries)
        }
    }
    
    internal func getUpdatedByteCount(type: CountType) -> UInt64 {
        // Collect information from state
        let updateInfo = state.withLock { state in
            state.getByteCountUpdateInfo(type: type)
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.ByteCountUpdate(index: index, updatedSummary: child.getUpdatedByteCount(type: type))
        }
        
        // Consolidate updated values
        return state.withLock { state in
            state.updateByteCount(updateInfo, updatedSummaries)
        }
    }
    
    internal func getUpdatedThroughput() -> [UInt64] {
        // Collect information from state
        let updateInfo = state.withLock { state in
            state.getThroughputUpdateInfo()
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.ThroughputUpdate(index: index, updatedSummary: child.getUpdatedThroughput())
        }
        
        // Consolidate updated values
        return state.withLock { state in
            state.getUpdatedThroughput(updateInfo, updatedSummaries)
        }
    }
    
    internal func getUpdatedEstimatedTimeRemaining() -> Duration {
        // Collect information from state
        let updateInfo = state.withLock { state in
            state.getEstimatedTimeRemainingUpdateInfo()
        }
        
        // Get updated summary for each dirty child
        let updatedSummaries = updateInfo.dirtyChildren.map { (index, child) in
            State.EstimatedTimeRemainingUpdate(index: index, updatedSummary: child.getUpdatedEstimatedTimeRemaining())
        }
        
        // Consolidate updated values
        return state.withLock { state in
            state.updateEstimatedTimeRemaining(updateInfo, updatedSummaries)
        }
    }
    
    //MARK: Helper Methods for Setting Dirty Paths
    
    internal func markSelfDirty(property: MetatypeWrapper<Int, Int>, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<UInt64, UInt64>, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<Double, Double>, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<String?, [String?]>, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<URL?, [URL?]>, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<UInt64, [UInt64]>, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markSelfDirty(property: MetatypeWrapper<Duration, Duration>, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.TotalFileCount.Type, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.CompletedFileCount.Type, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.TotalByteCount.Type, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.CompletedByteCount.Type, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.Throughput.Type, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markSelfDirty(property: ProgressManager.Properties.EstimatedTimeRemaining.Type, parents: [ParentState]) {
        mutateObservation(of: ProgressManager.additionalPropertiesKeyPath.withLock { $0 }) {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
        }
    }
    
    internal func markChildDirty(property: MetatypeWrapper<Int, Int>, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<UInt64, UInt64>, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<Double, Double>, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<String?, [String?]>, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<URL?, [URL?]>, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<UInt64, [UInt64]>, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: MetatypeWrapper<Duration, Duration>, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }

    internal func markChildDirty(property: ProgressManager.Properties.TotalFileCount.Type, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.CompletedFileCount.Type, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.TotalByteCount.Type, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.CompletedByteCount.Type, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.Throughput.Type, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    internal func markChildDirty(property: ProgressManager.Properties.EstimatedTimeRemaining.Type, at position: Int) {
        let parents = state.withLock { state in
            state.markChildDirty(property: property, at: position)
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    //MARK: Method to preserve values of properties upon deinit
    internal func setChildDeclaredAdditionalProperties(at position: Int, totalFileCount: Int, completedFileCount: Int, totalByteCount: UInt64, completedByteCount: UInt64, throughput: [UInt64], estimatedTimeRemaining: Duration, propertiesInt: [MetatypeWrapper<Int, Int>: Int], propertiesUInt64: [MetatypeWrapper<UInt64, UInt64>: UInt64], propertiesDouble: [MetatypeWrapper<Double, Double>: Double], propertiesString: [MetatypeWrapper<String?, [String?]>: [String?]], propertiesURL: [MetatypeWrapper<URL?, [URL?]>: [URL?]], propertiesUInt64Array: [MetatypeWrapper<UInt64, [UInt64]>: [UInt64]], propertiesDuration: [MetatypeWrapper<Duration, Duration>: Duration]) {
        state.withLock { state in
            state.children[position].totalFileCount = PropertyStateInt(value: totalFileCount, isDirty: false)
            state.children[position].completedFileCount = PropertyStateInt(value: completedFileCount, isDirty: false)
            state.children[position].totalByteCount = PropertyStateUInt64(value: totalByteCount, isDirty: false)
            state.children[position].completedByteCount = PropertyStateUInt64(value: completedByteCount, isDirty: false)
            state.children[position].throughput = PropertyStateThroughput(value: throughput, isDirty: false)
            state.children[position].estimatedTimeRemaining = PropertyStateDuration(value: estimatedTimeRemaining, isDirty: false)
            
            for (propertyKey, propertyValue) in propertiesInt {
                state.children[position].childPropertiesInt[propertyKey] = PropertyStateInt(value: propertyValue, isDirty: false)
            }
            
            for (propertyKey, propertyValue) in propertiesUInt64 {
                state.children[position].childPropertiesUInt64[propertyKey] = PropertyStateUInt64(value: propertyValue, isDirty: false)
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
            
            for (propertyKey, propertyValue) in propertiesUInt64Array {
                state.children[position].childPropertiesUInt64Array[propertyKey] = PropertyStateThroughput(value: propertyValue, isDirty: false)
            }
            
            for (propertyKey, propertyValue) in propertiesDuration {
                state.children[position].childPropertiesDuration[propertyKey] = PropertyStateDuration(value: propertyValue, isDirty: false)
            }
        }
    }
}
