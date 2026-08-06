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
extension URL.Template {
    /// The name of a variable used for expanding a template.
    public struct VariableName: Sendable, Hashable {
        let key: String

        public init(_ key: String) {
            self.key = key
        }

        init(_ key: Substring) {
            self.key = String(key)
        }
    }
}

// MARK: -

extension String {
    @available(FoundationPreview 6.2, *)
    public init(_ key: URL.Template.VariableName) {
        self = key.key
    }
}

@available(FoundationPreview 6.2, *)
extension URL.Template.VariableName: CustomStringConvertible {
    public var description: String {
        String(self)
    }
}
