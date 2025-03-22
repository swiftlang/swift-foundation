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
    public init(_ key: URL.Template.VariableName) {
        self = key.key
    }
}

extension URL.Template.VariableName: CustomStringConvertible {
    public var description: String {
        String(self)
    }
}

// MARK: -

extension URL.Template.VariableName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}
