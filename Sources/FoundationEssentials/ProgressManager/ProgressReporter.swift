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
@Observable public final class ProgressReporter: Sendable, Hashable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    
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
        Class Name: ProgressReporter
        Object Identifier: \(ObjectIdentifier(self))
        progressManager: \(manager)
        totalCount: \(String(describing: totalCount))
        completedCount: \(completedCount)
        fractionCompleted: \(fractionCompleted)
        isIndeterminate: \(isIndeterminate)
        isFinished: \(isFinished)
        totalFileCount: \(summary(of: ProgressManager.Properties.TotalFileCount.self))
        completedFileCount: \(summary(of: ProgressManager.Properties.CompletedFileCount.self))
        totalByteCount: \(summary(of: ProgressManager.Properties.TotalByteCount.self))
        completedByteCount: \(summary(of: ProgressManager.Properties.CompletedByteCount.self))
        throughput: \(summary(of: ProgressManager.Properties.Throughput.self))
        estimatedTimeRemaining: \(summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self))
        """
    }
    
    public var debugDescription: String {
        return self.description
    }
    
    /// Reads properties that convey additional information about progress.
    public func withProperties<T, E: Error>(
        _ closure: (sending ProgressManager.Values) throws(E) -> sending T
    ) throws(E) -> T {
        return try manager.getProperties(closure)
    }
    
    /// Returns a summary for the specified integer property across the progress subtree.
    ///
    /// This method aggregates the values of a custom integer property from the underlying progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the double property to summarize. Must be a property
    ///   where both the value and summary types are `Int`.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: ProgressManager.Property>(of property: P.Type) -> Int where P.Value == Int, P.Summary == Int {
        manager.summary(of: property)
    }
    
    /// Returns a summary for the specified double property across the progress subtree.
    ///
    /// This method aggregates the values of a custom double property from the underlying progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the double property to summarize. Must be a property
    ///   where both the value and summary types are `Double`.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: ProgressManager.Property>(of property: P.Type) -> Double where P.Value == Double, P.Summary == Double {
        manager.summary(of: property)
    }
    
    /// Returns a summary for the specified string property across the progress subtree.
    ///
    /// This method aggregates the values of a custom string property from the underlying progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the string property to summarize. Must be a property
    ///   where both the value and summary types are `String`.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: ProgressManager.Property>(of property: P.Type) -> [String?] where P.Value == String?, P.Summary == [String?] {
        return manager.summary(of: property)
    }
    
    public func summary<P: ProgressManager.Property>(of property: P.Type) -> [URL?] where P.Value == URL?, P.Summary == [URL?] {
        return manager.summary(of: property)
    }
    
    public func summary<P: ProgressManager.Property>(of property: P.Type) -> [UInt64] where P.Value == UInt64, P.Summary == [UInt64] {
        return manager.summary(of: property)
    }
    
    /// Returns the total file count across the progress subtree.
    ///
    /// - Parameter property: The `TotalFileCount` property type.
    /// - Returns: The sum of all total file counts across the entire progress subtree.
    public func summary(of property: ProgressManager.Properties.TotalFileCount.Type) -> Int {
        return manager.summary(of: property)
    }
    
    /// Returns the completed file count across the progress subtree.
    ///
    /// - Parameter property: The `CompletedFileCount` property type.
    /// - Returns: The sum of all completed file counts across the entire progress subtree.
    public func summary(of property: ProgressManager.Properties.CompletedFileCount.Type) -> Int {
        manager.summary(of: property)
    }
    
    /// Returns the total byte count across the progress subtree.
    ///
    /// - Parameter property: The `TotalByteCount` property type.
    /// - Returns: The sum of all total byte counts across the entire progress subtree, in bytes.
    public func summary(of property: ProgressManager.Properties.TotalByteCount.Type) -> UInt64 {
        manager.summary(of: property)
    }
    
    /// Returns the completed byte count across the progress subtree.
    ///
    /// - Parameter property: The `CompletedByteCount` property type.
    /// - Returns: The sum of all completed byte counts across the entire progress subtree, in bytes.
    public func summary(of property: ProgressManager.Properties.CompletedByteCount.Type) -> UInt64 {
        manager.summary(of: property)
    }
    
    /// Returns the average throughput across the progress subtree.
    ///
    /// - Parameter property: The `Throughput` property type.
    /// - Returns: The average throughput across the entire progress subtree, in bytes per second.
    public func summary(of property: ProgressManager.Properties.Throughput.Type) -> [UInt64] {
        manager.summary(of: property)
    }
    
    /// Returns the maximum estimated time remaining for completion across the progress subtree.
    ///
    /// - Parameter property: The `EstimatedTimeRemaining` property type.
    /// - Returns: The estimated duration until completion for the entire progress subtree.
    public func summary(of property: ProgressManager.Properties.EstimatedTimeRemaining.Type) -> Duration {
        manager.summary(of: property)
    }
    
    /// Returns all file URLs being processed across the progress subtree.
    ///
    /// - Parameter property: The `FileURL` property type.
    /// - Returns: An array containing all file URLs across the entire progress subtree.
    public func summary(of property: ProgressManager.Properties.FileURL.Type) -> [URL?] {
        manager.summary(of: property)
    }

    internal let manager: ProgressManager
    
    internal init(manager: ProgressManager) {
        self.manager = manager
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    public static func == (lhs: ProgressReporter, rhs: ProgressReporter) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}
