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
    
    /// A type that conveys task-specific information on progress.
    public protocol Property: SendableMetatype {
        
        associatedtype Value: Sendable, Equatable
        associatedtype Summary: Sendable, Equatable
        
        // use reverse DNS style, com.apple.file
        static var key: String { get }
        
        /// The default value to return when property is not set to a specific value.
        static var defaultValue: Value { get }
        
        static var defaultSummary: Summary { get }
        
        static func reduce(into: inout Summary, value: Value)
        
        static func merge(_ summary1: Summary, _ summary2: Summary) -> Summary
    }
    
    // Namespace for properties specific to operations reported on
    public struct Properties: Sendable {
        
        /// The total number of files.
        public var totalFileCount: TotalFileCount.Type { TotalFileCount.self }
        public struct TotalFileCount: Sendable, Property {
            
            public typealias Value = Int
            
            public typealias Summary = Int
            
            public static var key: String { return "TotalFileCount" }
            
            public static var defaultValue: Int { return 0 }
            
            public static var defaultSummary: Int { return 0 }
                        
            public static func reduce(into summary: inout Int, value: Int) {
                summary += value
            }
            
            public static func merge(_ summary1: Int, _ summary2: Int) -> Int {
                return summary1 + summary2
            }
        }
        
        /// The number of completed files.
        public var completedFileCount: CompletedFileCount.Type { CompletedFileCount.self }
        public struct CompletedFileCount: Sendable, Property {

            public typealias Value = Int
            
            public typealias Summary = Int
            
            public static var key: String { return "CompletedFileCount" }

            public static var defaultValue: Int { return 0 }
            
            public static var defaultSummary: Int { return 0 }
                         
            public static func reduce(into summary: inout Int, value: Int) {
                summary += value
            }
            
            public static func merge(_ summary1: Int, _ summary2: Int) -> Int {
                return summary1 + summary2
            }
        }
        
        /// The total number of bytes.
        public var totalByteCount: TotalByteCount.Type { TotalByteCount.self }
        public struct TotalByteCount: Sendable, Property {
        
            public typealias Value = Int64
            
            public typealias Summary = Int64
            
            public static var key: String { return "TotalByteCount" }
            
            public static var defaultValue: Int64 { return 0 }
            
            public static var defaultSummary: Int64 { return 0 }
                        
            public static func reduce(into summary: inout Int64, value: Int64) {
                summary += value
            }
            
            public static func merge(_ summary1: Int64, _ summary2: Int64) -> Int64 {
                return summary1 + summary2
            }
        }
        
        /// The number of completed bytes.
        public var completedByteCount: CompletedByteCount.Type { CompletedByteCount.self }
        public struct CompletedByteCount: Sendable, Property {
                    
            public typealias Value = Int64
            
            public typealias Summary = Int64
            
            public static var key: String { return "CompletedByteCount" }
            
            public static var defaultValue: Int64 { return 0 }
            
            public static var defaultSummary: Int64 { return 0 }
                        
            public static func reduce(into summary: inout Int64, value: Int64) {
                summary += value
            }
            
            public static func merge(_ summary1: Int64, _ summary2: Int64) -> Int64 {
                return summary1 + summary2
            }
        }
        
        /// The throughput, in bytes per second.
        public var throughput: Throughput.Type { Throughput.self }
        public struct Throughput: Sendable, Property {
            public typealias Value = Int64
            
            public struct AggregateThroughput: Sendable, Equatable {
                var values: Int64
                var count: Int
            }
            
            public typealias Summary = AggregateThroughput
            
            public static var key: String { return "Throughput" }
            
            public static var defaultValue: Int64 { return 0 }
            
            public static var defaultSummary: AggregateThroughput { return AggregateThroughput(values: 0, count: 0) }
            
            public static func reduce(into summary: inout AggregateThroughput, value: Int64) {
                summary = Summary(values: summary.values + value, count: summary.count + 1)
            }
            
            public static func merge(_ summary1: AggregateThroughput, _ summary2: AggregateThroughput) -> AggregateThroughput {
                return Summary(values: summary1.values + summary2.values, count: summary1.count + summary2.count)
            }
        }
        
        /// The amount of time remaining in the processing of files.
        public var estimatedTimeRemaining: EstimatedTimeRemaining.Type { EstimatedTimeRemaining.self }
        public struct EstimatedTimeRemaining: Sendable, Property {
            
            public typealias Value = Duration
            
            public typealias Summary = Duration
            
            public static var key: String { return "EstimatedTimeRemaining" }
            
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
        }
        
        public var fileURL: FileURL.Type { FileURL.self }
        public struct FileURL: Sendable, Property {
            
            public typealias Value = URL?
            
            public typealias Summary = [URL]
            
            public static var key: String { return "FileURL" }
            
            public static var defaultValue: URL? { return nil }
            
            public static var defaultSummary: [URL] { return [] }
                        
            public static func reduce(into summary: inout [URL], value: URL?) {
                guard let value else {
                    return
                }
                summary.append(value)
            }
            
            public static func merge(_ summary1: [URL], _ summary2: [URL]) -> [URL] {
                return summary1 + summary2
            }
            
        }
    }
}
