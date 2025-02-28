#if canImport(CollectionsInternal)
internal import CollectionsInternal
#elseif canImport(OrderedCollections)
internal import OrderedCollections
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

extension URL.Template {
    /// Creates a new `URL` by expanding the RFC 6570 template and variables.
    ///
    /// This will return `nil` if variable expansion does not produce a valid,
    /// well-formed URL.
    ///
    /// All text will be converted to NFC (Unicode Normalization Form C) and UTF-8
    /// before being percent-encoded if needed.
    public func makeURL(
        variables: [URL.Template.VariableName: URL.Template.Value]
    ) -> URL? {
        URL(string: expand(variables))
    }
}

extension URL.Template {
    /// Expands the expressions in the template and returns the resulting URI as a ``Swift/String``.
    func expand(_ variables: [VariableName: Value]) -> String {
        replaceVariables(variables.mapValues({ $0.underlying }))
    }

    func replaceVariables(_ variables: [VariableName: Value.Underlying]) -> String {
        return elements.reduce(into: "") { result, element in
            switch element {
            case .literal(let literal):
                result.append(literal)
            case .expression(let expression):
                result += expression.replacement(variables)
            }
        }
    }
}

// MARK: -

extension URL.Template.Expression {
    fileprivate func replacement(_ variables: [URL.Template.VariableName: URL.Template.Value.Underlying]) -> String {
        let escapedValues: [(String?, String)] = elements.flatMap {
            $0.escapedValues(
                operator: `operator`,
                variables: variables
            )
        }

        return escapedValues.enumerated().reduce(into: "") { result, element in
            let isFirst = element.offset == 0
            let name = element.element.0
            let value = element.element.1

            if isFirst {
                if let c = `operator`.firstPrefix {
                    result.append(c)
                }
            } else {
                result.append(`operator`.separator)
            }
            if let name {
                result.append(name)
                if value.isEmpty {
                    if let c = `operator`.replacementForEmpty {
                        result.append(c)
                    }
                } else {
                    result.append("=")
                    result.append(value)
                }
            } else {
                result.append(value)
            }
        }
    }
}

extension URL.Template.Expression.Element {
    fileprivate func escapedValues(
        `operator`: URL.Template.Expression.Operator?,
        variables: [URL.Template.VariableName: URL.Template.Value.Underlying]
    ) -> [(String?, String)] {
        func makeNormalized(_ value: String) -> String {
            let v: String = maximumLength.map { String(value.prefix($0)) } ?? value
            return v.normalizedAddingPercentEncoding(
                withAllowedCharacters: `operator`.allowedCharacters
            )
        }

        func makeElement(_ value: String) -> (String?, String) {
            return (
                `operator`.isNamed ? String(name) : nil,
                makeNormalized(value)
            )
        }

        func makeElement(_ values: [String]) -> (String?, String) {
            return (
                `operator`.isNamed ? String(name) : nil,
                values
                    .map(makeNormalized)
                    .joined(separator: ",")
            )
        }

        switch variables[name] {
        case .text(let s):
            return [makeElement(s)]
        case .list(let a):
            if explode {
                return a.map { makeElement($0) }
            } else {
                return [makeElement(a)]
            }
        case .associativeList(let d):
            if explode {
                return d.lazy.map {
                    (
                        makeNormalized($0.key),
                        makeNormalized($0.value)
                    )
                }
            } else if d.isEmpty {
                return []
            } else {
                return [
                    makeElement(d.lazy.flatMap { [$0.key, $0.value] }),
                ]
            }
        default:
            return []
        }
    }
}
