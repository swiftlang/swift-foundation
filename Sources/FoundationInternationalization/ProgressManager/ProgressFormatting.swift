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
public protocol ProgressFormatting {}

@available(FoundationPreview 6.2, *)
extension ProgressManager: ProgressFormatting {}

@available(FoundationPreview 6.2, *)
extension ProgressReporter: ProgressFormatting {}

