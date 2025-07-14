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
    // Namespace for properties specific to operations reported on
    public struct Properties: Sendable {
        
        /// The total number of files.
        public var totalFileCount: TotalFileCount.Type { TotalFileCount.self }
        public struct TotalFileCount: Sendable, Property {
            
            public typealias Value = Int
            
            public typealias Summary = Int
            
            public static var defaultValue: Int { return 0 }
            
            public static var defaultSummary: Int { return 0 }
            
            public typealias T = Int
            
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
            
            public static var defaultValue: Int { return 0 }
            
            public static var defaultSummary: Int { return 0 }
             
            public typealias T = Int
            
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
            
            public static var defaultValue: Int64 { return 0 }
            
            public static var defaultSummary: Int64 { return 0 }
            
            public typealias T = Int64
            
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
            
            public static var defaultValue: Int64 { return 0 }
            
            public static var defaultSummary: Int64 { return 0 }
            
            public typealias T = Int64
            
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
            
            public typealias Summary = [Int64]
            
            public static var defaultValue: Int64 { return 0 }
            
            public static var defaultSummary: [Int64] { return [0] }

            public typealias T = Int64
            
            public static func reduce(into summary: inout [Int64], value: Int64) {
                summary.append(value)
            }
            
            public static func merge(_ summary1: [Int64], _ summary2: [Int64]) -> [Int64] {
                return summary1 + summary2
            }
        }
        
        /// The amount of time remaining in the processing of files.
        public var estimatedTimeRemaining: EstimatedTimeRemaining.Type { EstimatedTimeRemaining.self }
        public struct EstimatedTimeRemaining: Sendable, Property {
            // average duration - might need to define ourselves
            
            public typealias Value = Duration
            
            public typealias Summary = [Duration]
            
            public static var defaultValue: Duration { return Duration.seconds(0) }

            public static var defaultSummary: [Duration] { return [Duration.seconds(0)] }
            
            public typealias T = Duration
            
            public static func reduce(into summary: inout [Duration], value: Duration) {
                summary.append(value)
            }
            
            public static func merge(_ summary1: [Duration], _ summary2: [Duration]) -> [Duration] {
                return summary1 + summary2
            }

        }
    }
}
