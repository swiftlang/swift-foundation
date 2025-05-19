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
@Observable public final class ProgressReporter: Sendable {
    
    var totalCount: Int? {
        manager.totalCount
    }
    
    var completedCount: Int {
        manager.completedCount
    }
    
    var fractionCompleted: Double {
        manager.fractionCompleted
    }
    
    var isIndeterminate: Bool {
        manager.isIndeterminate
    }
    
    var isFinished: Bool {
        manager.isFinished
    }
    
    /// Reads properties that convey additional information about progress.
    public func withProperties<T>(_ closure: @Sendable (ProgressManager.Values) throws -> T) rethrows -> T {
        return try manager.getAdditionalProperties(closure)
    }
    
    internal let manager: ProgressManager
    
    internal init(manager: ProgressManager) {
        self.manager = manager
    }
}
