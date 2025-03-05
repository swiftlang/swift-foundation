internal import RegexBuilder
#if canImport(CollectionsInternal)
internal import CollectionsInternal
#elseif canImport(OrderedCollections)
internal import OrderedCollections
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

extension URL.Template {
    struct Expression: Sendable, Hashable {
        var `operator`: Operator?
        var elements: [Element]

        struct Element: Sendable, Hashable {
            var name: URL.Template.VariableName
            var maximumLength: Int?
            var explode: Bool
        }

        enum Operator: String, Sendable, Hashable {
            /// `+`   Reserved character strings;
            case reserved = "+"
            /// `#`   Fragment identifiers prefixed by "#";
            case fragment = "#"
            /// `.`   Name labels or extensions prefixed by ".";
            case nameLabel = "."
            /// `/`   Path segments prefixed by "/";
            case pathSegment = "/"
            /// `;`   Path parameter name or name=value pairs prefixed by ";";
            case pathParameter = ";"
            /// `?`   Query component beginning with "?" and consisting of
            /// name=value pairs separated by "&"; and,
            case queryComponent = "?"
            /// `&`   Continuation of query-style &name=value pairs within
            /// a literal query component.
            case continuation = "&"
        }
    }
}

private struct InvalidTemplateExpression: Swift.Error {
    var text: String
}

extension Substring {
    mutating func popPrefixMatch<Output>(_ regex: Regex<Output>) throws -> Regex<Output>.Match? {
        guard
            let match = try regex.prefixMatch(in: self)
        else { return nil }
        self = self[match.range.upperBound..<self.endIndex]
        return match
    }
}

extension URL.Template.Expression: CustomStringConvertible {
    var description: String {
        "\(`operator`?.rawValue ?? "")" + elements.map { "\($0)" }.joined(separator: ",")
    }
}

extension URL.Template.Expression.Element: CustomStringConvertible {
    var description: String {
        "\(name)\(maximumLength.map { ":\($0)" } ?? "")\(explode ? "*" : "")"
    }
}

extension URL.Template.Expression {
    init(_ input: String) throws {
        var remainder = input[...]
        guard
            let opString = try remainder.popPrefixMatch(URL.Template.Global.shared.operatorRegex)
        else { throw InvalidTemplateExpression(text: input) }

        let op = try opString.1.map {
            guard
                let o = Operator(rawValue: String($0))
            else { throw InvalidTemplateExpression(text: input) }
            return o
        }
        var elements: [Element] = []

        func popElement() throws {
            guard
                let match = try remainder.popPrefixMatch(URL.Template.Global.shared.elementRegex)
            else { throw InvalidTemplateExpression(text: input) }

            let name: Substring = match.output.1
            let maximumLength: Int?
            let explode: Bool
            if let max = match.output.3 {
                maximumLength = Int(max!)!
                explode = false
            } else if match.output.2 != nil {
                maximumLength = nil
                explode = true
            } else {
                maximumLength = nil
                explode = false
            }
            elements.append(Element(
                name: URL.Template.VariableName(name),
                maximumLength: maximumLength,
                explode: explode
            ))
        }

        try popElement()

        while !remainder.isEmpty {
            guard
                try remainder.popPrefixMatch(URL.Template.Global.shared.separatorRegex) != nil
            else { throw InvalidTemplateExpression(text: input) }

            try popElement()
        }

        self.init(
            operator: op,
            elements: elements
        )
    }
}

extension URL.Template {
    // Making the type unchecked Sendable is fine, Regex is safe in this context, as it only contains
    // other Sendable types. For details, see https://forums.swift.org/t/should-regex-be-sendable/69529/7
    internal final class Global: @unchecked Sendable {

        static let shared: Global = .init()

        let operatorRegex: Regex<(Substring, Substring?)>
        let separatorRegex: Regex<(Substring)>
        let elementRegex: Regex<(Substring, Substring, Substring?, Substring??)>
        let uriTemplateRegex: Regex<Regex<(Substring, Regex<OneOrMore<Substring>.RegexOutput>.RegexOutput)>.RegexOutput>

        private init() {
            self.operatorRegex = Regex {
                Optionally {
                    Capture {
                        One(.anyOf("+#./;?&"))
                    }
                }
            }
            .asciiOnlyWordCharacters()
            .asciiOnlyDigits()
            .asciiOnlyCharacterClasses()
            self.separatorRegex = Regex {
                ","
            }
            .asciiOnlyWordCharacters()
            .asciiOnlyDigits()
            .asciiOnlyCharacterClasses()
            self.elementRegex = Regex {
                Capture {
                    One(("a"..."z").union("A"..."Z"))
                    ZeroOrMore(("a"..."z").union("A"..."Z").union("0"..."9").union(.anyOf("_")))
                }
                Optionally {
                    Capture {
                        ChoiceOf {
                            Regex {
                                ":"
                                Capture {
                                    ZeroOrMore(.digit)
                                }
                            }
                            "*"
                        }
                    }
                }
            }
            .asciiOnlyWordCharacters()
            .asciiOnlyDigits()
            .asciiOnlyCharacterClasses()
            self.uriTemplateRegex = Regex {
                "{"
                Capture {
                    OneOrMore {
                        CharacterClass.any.subtracting(.anyOf("}"))
                    }
                }
                "}"
            }
        }
    }
}

// .------------------------------------------------------------------.
// |          NUL     +      .       /       ;      ?      &      #   |
// |------------------------------------------------------------------|
// | first |  ""     ""     "."     "/"     ";"    "?"    "&"    "#"  |
// | sep   |  ","    ","    "."     "/"     ";"    "&"    "&"    ","  |
// | named | false  false  false   false   true   true   true   false |
// | ifemp |  ""     ""     ""      ""      ""     "="    "="    ""   |
// | allow |   U     U+R     U       U       U      U      U     U+R  |
// `------------------------------------------------------------------'

extension URL.Template.Expression.Operator? {
    var firstPrefix: Character? {
        switch self {
        case nil: return nil
        case .reserved?: return nil
        case .nameLabel?: return "."
        case .pathSegment?: return "/"
        case .pathParameter?: return ";"
        case .queryComponent?: return "?"
        case .continuation?: return "&"
        case .fragment?: return "#"
        }
    }

    var separator: Character {
        switch self {
        case nil: return ","
        case .reserved?: return ","
        case .nameLabel?: return "."
        case .pathSegment?: return "/"
        case .pathParameter?: return ";"
        case .queryComponent?: return "&"
        case .continuation?: return "&"
        case .fragment?: return ","
        }
    }

    var isNamed: Bool {
        switch self {
        case nil: return false
        case .reserved?: return false
        case .nameLabel?: return false
        case .pathSegment?: return false
        case .pathParameter?: return true
        case .queryComponent?: return true
        case .continuation?: return true
        case .fragment?: return false
        }
    }

    var replacementForEmpty: Character? {
        switch self {
        case nil: return nil
        case .reserved?: return nil
        case .nameLabel?: return nil
        case .pathSegment?: return nil
        case .pathParameter?: return nil
        case .queryComponent?: return "="
        case .continuation?: return "="
        case .fragment?: return nil
        }
    }

    var allowedCharacters: URL.Template.Expression.Operator.AllowedCharacters {
        switch self {
        case nil: return .unreserved
        case .reserved?: return .unreservedReserved
        case .nameLabel?: return .unreserved
        case .pathSegment?: return .unreserved
        case .pathParameter?: return .unreserved
        case .queryComponent?: return .unreserved
        case .continuation?: return .unreserved
        case .fragment?: return .unreservedReserved
        }
    }
}

extension URL.Template.Expression.Operator {
    enum AllowedCharacters {
        case unreserved
        // The union of (unreserved / reserved / pct-encoded)
        case unreservedReserved
    }
}
