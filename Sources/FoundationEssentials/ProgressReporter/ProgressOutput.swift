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
/// ProgressMonitor is just a wrapper that carries information about ProgressReporter. It is read-only and can be added as a child of something else.
public final class ProgressOutput: Sendable {
    internal let reporter: ProgressReporter
    
    internal init(reporter: ProgressReporter) {
        self.reporter = reporter
    }
}
