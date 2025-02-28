internal import RegexBuilder

extension String {
    /// Convert to NFC and percent-escape.
    func normalizedAddingPercentEncoding(
        withAllowedCharacters allowed: URL.Template.Expression.Operator.AllowedCharacters
    ) -> String {
        let input: String
#if FOUNDATION_FRAMEWORK
        input = precomposedStringWithCanonicalMapping
#else
        // TODO: NFC conversion
        input = self
#endif
        switch allowed {
        case .unreserved:
            return input.addingPercentEncoding(
                allowed: allowed
            )
        case .unreservedReserved:
            var result = ""
            var remainder = input[...]

            func copyEscaped(upTo end: String.Index) {
                guard
                    remainder.startIndex < end
                else { return }
                let text = remainder[remainder.startIndex..<end]
                let escaped = text.addingPercentEncoding(
                    allowed: allowed
                )
                result.append(escaped)
            }

            while let match = remainder.firstMatch(of: URL.Template.Global.shared.percentEscapedRegex) {
                defer {
                    remainder = remainder[match.range.upperBound..<remainder.endIndex]
                }
                copyEscaped(upTo: match.range.lowerBound)
                result.append(contentsOf: match.output)
            }
            copyEscaped(upTo: remainder.endIndex)
            return result
        }
    }
}

extension StringProtocol {
    fileprivate func addingPercentEncoding(
        allowed: URL.Template.Expression.Operator.AllowedCharacters
    ) -> String {
        addingPercentEncoding(isAllowedCodeUnit: { allowed.isAllowedCodeUnit($0) })
    }
}

extension URL.Template.Expression.Operator.AllowedCharacters {
    func isAllowedCodeUnit(_ unit: UTF8.CodeUnit) -> Bool {
        switch self {
        case .unreserved:
            // unreserved     =  ALPHA / DIGIT / "-" / "." / "_" / "~"
            switch unit {
            case 0x61...0x7a /* "a"..."z" */: true
            case 0x41...0x5a /* "A"..."Z" */: true
            case 0x30...0x39 /* "0"..."9" */: true
            case 0x2d, 0x2e, 0x5f, 0x7e /* `-` `.` `_` `~` */: true
            default: false
            }
        case .unreservedReserved:
            // unreserved / reserved / pct-encoded
            // reserved       =  gen-delims / sub-delims
            // gen-delims     =  ":" / "/" / "?" / "#" / "[" / "]" / "@"
            // sub-delims     =  "!" / "$" / "&" / "'" / "(" / ")"
            //                /  "*" / "+" / "," / ";" / "="
            switch unit {
            case 0x61...0x7a /* "a"..."z" */: true
            case 0x41...0x5a /* "A"..."Z" */: true
            case 0x30...0x39 /* "0"..."9" */: true
            case 0x2d, 0x2e, 0x5f, 0x7e /* `-` `.` `_` `~` */: true
            case 0x3a, 0x2f, 0x3f, 0x23, 0x5b, 0x5d, 0x40  /* `:` `/` `?` `#` `[` `]` `@` */: true
            case 0x21, 0x24, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x3b, 0x3d  /* `!` `$` `&` `'` `(` `)` `*` `+` `,` `;` `=` */: true
            default: false
            }
        }
    }
}
