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

import Observation

@available(FoundationPreview 6.2, *)
/// ProgressReporter is a wrapper for ProgressManager that carries information about ProgressManager.
///
/// It is read-only and can be added as a child of another ProgressManager.
@Observable public final class ProgressReporter: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    
    /// The total units of work.
    public var totalCount: Int? {
        manager.totalCount
    }
    
    /// The completed units of work.
    /// If `self` is indeterminate, the value will be 0.
    public var completedCount: Int {
        manager.completedCount
    }
    
    /// The proportion of work completed.
    /// This takes into account the fraction completed in its children instances if children are present.
    /// If `self` is indeterminate, the value will be 0.
    public var fractionCompleted: Double {
        manager.fractionCompleted
    }
    
    /// The state of initialization of `totalCount`.
    /// If `totalCount` is `nil`, the value will be `true`.
    public var isIndeterminate: Bool {
        manager.isIndeterminate
    }
    
    /// The state of completion of work.
    /// If `completedCount` >= `totalCount`, the value will be `true`.
    public var isFinished: Bool {
        manager.isFinished
    }
    
    public var description: String {
        return """
        progressManager: \(manager)
        totalCount: \(String(describing: totalCount))
        completedCount: \(completedCount)
        fractionCompleted: \(fractionCompleted)
        isIndeterminate: \(isIndeterminate)
        isFinished: \(isFinished)
        """
    }
    
//    totalFileCount: \(values(of: ProgressManager.Properties.TotalFileCount.self))
//    completedFileCount: \(values(of: ProgressManager.Properties.CompletedFileCount.self))
//    totalByteCount: \(values(of: ProgressManager.Properties.TotalByteCount.self))
//    completedByteCount: \(values(of: ProgressManager.Properties.CompletedByteCount.self))
//    throughput: \(values(of: ProgressManager.Properties.Throughput.self))
//    estimatedTimeRemaining: \(values(of: ProgressManager.Properties.EstimatedTimeRemaining.self))
    
    public var debugDescription: String {
        return self.description
    }
    
    /// Reads properties that convey additional information about progress.
    public func withProperties<T, E: Error>(
        _ closure: (sending ProgressManager.Values) throws(E) -> sending T
    ) throws(E) -> T {
        return try manager.getProperties(closure)
    }
    
//    /// Returns an array of values for specified property in subtree.
//    /// - Parameter metatype: Type of property.
//    /// - Returns: Array of values for property.
//    public func values<P: ProgressManager.Property>(of property: P.Type) -> [P.Value] {
//        manager.values(of: property)
//    }
//    
//    /// Returns the aggregated result of values.
//    /// - Parameters:
//    ///   - property: Type of property.
//    public func total<P: ProgressManager.Property>(of property: P.Type) -> P.Value where P.Value: AdditiveArithmetic {
//        manager.total(of: property)
//    }
    
    internal let manager: ProgressManager
    
    internal init(manager: ProgressManager) {
        self.manager = manager
    }
}
