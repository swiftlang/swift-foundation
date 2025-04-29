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
extension ProgressReporter {
    // Namespace for properties specific to operations reported on
    public struct Properties: Sendable {
        public var totalFileCount: TotalFileCount.Type { TotalFileCount.self }
        public struct TotalFileCount: Sendable, Property {
            public static var defaultValue: Int { return 0 }
            
            public typealias T = Int
        }
        
        public var completedFileCount: CompletedFileCount.Type { CompletedFileCount.self }
        public struct CompletedFileCount: Sendable, Property {
            public static var defaultValue: Int { return 0 }
             
            public typealias T = Int
        }
        
        public var totalByteCount: TotalByteCount.Type { TotalByteCount.self }
        public struct TotalByteCount: Sendable, Property {
            public static var defaultValue: Int64 { return 0 }
            
            public typealias T = Int64
        }
        
        public var completedByteCount: CompletedByteCount.Type { CompletedByteCount.self }
        public struct CompletedByteCount: Sendable, Property {
            public static var defaultValue: Int64 { return 0 }
            
            public typealias T = Int64
        }
        
        public var throughput: Throughput.Type { Throughput.self }
        public struct Throughput: Sendable, Property {
            public static var defaultValue: Int64 { return 0 }
            
            public typealias T = Int64
        }
        
        public var estimatedTimeRemaining: EstimatedTimeRemaining.Type { EstimatedTimeRemaining.self }
        public struct EstimatedTimeRemaining: Sendable, Property {
            public static var defaultValue: Duration { return Duration.seconds(0) }
            
            public typealias T = Duration
        }
    }
}
