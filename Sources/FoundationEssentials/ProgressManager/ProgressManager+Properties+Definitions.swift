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

@available(FoundationPreview 6.2, *)
extension ProgressManager {
    
    /// A type that conveys additional task-specific information on progress.
    ///
    /// The `Property` protocol defines custom properties that can be associated with progress tracking.
    /// These properties allow you to store and aggregate additional information alongside the
    /// standard progress metrics such as `totalCount` and `completedCount`.
    public protocol Property: SendableMetatype {
        
        /// The type used for individual values of this property.
        ///
        /// This associated type represents the type of property values
        /// that can be set on progress managers. Must be `Sendable` and `Equatable`.
        /// The currently allowed types are `Int`, `Double`, `String?`, `URL?` or `UInt64`.
        associatedtype Value: Sendable, Equatable
        
        /// The type used for aggregated summaries of this property.
        ///
        /// This associated type represents the type used when summarizing property values
        /// across multiple progress managers in a subtree.
        /// The currently allowed types are `Int`, `Double`, `[String?]`, `[URL?]` or `[UInt64]`.
        associatedtype Summary: Sendable, Equatable
        
        /// A unique identifier for this property type.
        ///
        /// The key should use reverse DNS style notation to ensure uniqueness across different
        /// frameworks and applications.
        ///
        /// - Returns: A unique string identifier for this property type.
        static var key: String { get }
        
        /// The default value to return when property is not set to a specific value.
        ///
        /// This value is used when a progress manager doesn't have an explicit value set
        /// for this property type.
        ///
        /// - Returns: The default value for this property type.
        static var defaultValue: Value { get }
        
        /// The default summary value for this property type.
        ///
        /// This value is used as the initial summary when no property values have been
        /// aggregated yet.
        ///
        /// - Returns: The default summary value for this property type.
        static var defaultSummary: Summary { get }
        
        /// Reduces a property value into an accumulating summary.
        ///
        /// This method is called to incorporate individual property values into a summary
        /// that represents the aggregated state across multiple progress managers.
        ///
        /// - Parameters:
        ///   - summary: The accumulating summary value to modify.
        ///   - value: The individual property value to incorporate into the summary.
        static func reduce(into summary: inout Summary, value: Value)
        
        /// Merges two summary values into a single combined summary.
        ///
        /// This method is called to combine summary values from different branches
        /// of the progress manager hierarchy into a unified summary.
        ///
        /// - Parameters:
        ///   - summary1: The first summary to merge.
        ///   - summary2: The second summary to merge.
        /// - Returns: A new summary that represents the combination of both input summaries.
        static func merge(_ summary1: Summary, _ summary2: Summary) -> Summary
        
        /// Determines how to handle summary data when a progress manager is deinitialized.
        ///
        /// This method is used when a progress manager in the hierarchy is being
        /// deinitialized and its accumulated summary needs to be processed in relation to
        /// its parent's summary. The behavior can vary depending on the property type:
        ///
        /// - For additive properties (like file counts, byte counts): The self summary
        ///   is typically added to the parent summary to preserve the accumulated progress.
        /// - For max-based properties (like estimated time remaining): The parent summary
        ///   is typically preserved as it represents an existing estimate.
        /// - For collection-based properties (like file URLs): The self summary may be
        ///   discarded to avoid accumulating stale references.
        ///
        /// - Parameters:
        ///   - parentSummary: The current summary value of the parent progress manager.
        ///   - selfSummary: The final summary value from the progress manager being deinitialized.
        /// - Returns: The updated summary that replaces the parent's current summary.
        static func terminate(_ parentSummary: Summary, _ selfSummary: Summary) -> Summary
    }
    
    // Namespace for properties specific to operations reported on
    public struct Properties: Sendable {
        
        /// The total number of files.
        public var totalFileCount: TotalFileCount.Type { TotalFileCount.self }
        public struct TotalFileCount: Sendable, Property {
            
            public typealias Value = Int
            
            public typealias Summary = Int
            
            public static var key: String { return "Foundation.ProgressManager.Properties.TotalFileCount" }
            
            public static var defaultValue: Int { return 0 }
            
            public static var defaultSummary: Int { return 0 }
                        
            public static func reduce(into summary: inout Int, value: Int) {
                summary += value
            }
            
            public static func merge(_ summary1: Int, _ summary2: Int) -> Int {
                return summary1 + summary2
            }
            
            public static func terminate(_ parentSummary: Int, _ selfSummary: Int) -> Int {
                return parentSummary + selfSummary
            }
        }
        
        /// The number of completed files.
        public var completedFileCount: CompletedFileCount.Type { CompletedFileCount.self }
        public struct CompletedFileCount: Sendable, Property {

            public typealias Value = Int
            
            public typealias Summary = Int
            
            public static var key: String { return "Foundation.ProgressManager.Properties.CompletedFileCount" }

            public static var defaultValue: Int { return 0 }
            
            public static var defaultSummary: Int { return 0 }
                         
            public static func reduce(into summary: inout Int, value: Int) {
                summary += value
            }
            
            public static func merge(_ summary1: Int, _ summary2: Int) -> Int {
                return summary1 + summary2
            }
            
            public static func terminate(_ parentSummary: Int, _ selfSummary: Int) -> Int {
                return parentSummary + selfSummary
            }
        }
        
        /// The total number of bytes.
        public var totalByteCount: TotalByteCount.Type { TotalByteCount.self }
        public struct TotalByteCount: Sendable, Property {
        
            public typealias Value = UInt64
            
            public typealias Summary = UInt64
            
            public static var key: String { return "Foundation.ProgressManager.Properties.TotalByteCount" }
            
            public static var defaultValue: UInt64 { return 0 }
            
            public static var defaultSummary: UInt64 { return 0 }
                        
            public static func reduce(into summary: inout UInt64, value: UInt64) {
                summary += value
            }
            
            public static func merge(_ summary1: UInt64, _ summary2: UInt64) -> UInt64 {
                return summary1 + summary2
            }
            
            public static func terminate(_ parentSummary: UInt64, _ selfSummary: UInt64) -> UInt64 {
                return parentSummary + selfSummary
            }
        }
        
        /// The number of completed bytes.
        public var completedByteCount: CompletedByteCount.Type { CompletedByteCount.self }
        public struct CompletedByteCount: Sendable, Property {
                    
            public typealias Value = UInt64
            
            public typealias Summary = UInt64
            
            public static var key: String { return "Foundation.ProgressManager.Properties.CompletedByteCount" }
            
            public static var defaultValue: UInt64 { return 0 }
            
            public static var defaultSummary: UInt64 { return 0 }
                        
            public static func reduce(into summary: inout UInt64, value: UInt64) {
                summary += value
            }
            
            public static func merge(_ summary1: UInt64, _ summary2: UInt64) -> UInt64 {
                return summary1 + summary2
            }
            
            public static func terminate(_ parentSummary: UInt64, _ selfSummary: UInt64) -> UInt64 {
                return parentSummary + selfSummary
            }
        }
        
        /// The throughput, in bytes per second.
        public var throughput: Throughput.Type { Throughput.self }
        public struct Throughput: Sendable, Property {
            public typealias Value = UInt64
            
            public typealias Summary = [UInt64]
            
            public static var key: String { return "Foundation.ProgressManager.Properties.Throughput" }
            
            public static var defaultValue: UInt64 { return 0 }
            
            public static var defaultSummary: [UInt64] { return [] }
            
            public static func reduce(into summary: inout [UInt64], value: UInt64) {
                summary.append(value)
            }
            
            public static func merge(_ summary1: [UInt64], _ summary2: [UInt64]) -> [UInt64] {
                return summary1 + summary2
            }
            
            public static func terminate(_ parentSummary: [UInt64], _ selfSummary: [UInt64]) -> [UInt64] {
                return parentSummary + selfSummary
            }
        }
        
        /// The amount of time remaining in the processing of files.
        public var estimatedTimeRemaining: EstimatedTimeRemaining.Type { EstimatedTimeRemaining.self }
        public struct EstimatedTimeRemaining: Sendable, Property {
            
            public typealias Value = Duration
            
            public typealias Summary = Duration
            
            public static var key: String { return "Foundation.ProgressManager.Properties.EstimatedTimeRemaining" }
            
            public static var defaultValue: Duration { return Duration.seconds(0) }

            public static var defaultSummary: Duration { return Duration.seconds(0) }
                        
            public static func reduce(into summary: inout Duration, value: Duration) {
                if summary >= value {
                    return
                } else {
                    summary = value
                }
            }
            
            public static func merge(_ summary1: Duration, _ summary2: Duration) -> Duration {
                return max(summary1, summary2)
            }
            
            public static func terminate(_ parentSummary: Duration, _ selfSummary: Duration) -> Duration {
                return parentSummary
            }
        }
        
        
        /// The URL of file being processed.
        public var fileURL: FileURL.Type { FileURL.self }
        public struct FileURL: Sendable, Property {
            
            public typealias Value = URL?
            
            public typealias Summary = [URL?]
            
            public static var key: String { return "Foundation.ProgressManager.Properties.FileURL" }
            
            public static var defaultValue: URL? { return nil }
            
            public static var defaultSummary: [URL?] { return [] }
                        
            public static func reduce(into summary: inout [URL?], value: URL?) {
                guard let value else {
                    return
                }
                summary.append(value)
            }
            
            public static func merge(_ summary1: [URL?], _ summary2: [URL?]) -> [URL?] {
                return summary1 + summary2
            }
            
            public static func terminate(_ parentSummary: [URL?], _ selfSummary: [URL?]) -> [URL?] {
                return parentSummary
            }
        }
    }
}
