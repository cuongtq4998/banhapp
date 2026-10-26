import Foundation

/// Splits a SQL script into single statements.
///
/// PostgresNIO sends each query through the extended protocol, which accepts
/// one statement at a time, so a migration file has to be cut up before it is
/// run. A plain split on `;` would break trigger and function bodies, which
/// use dollar quoting (`$$ ... $$`) and contain semicolons. This scanner keeps
/// semicolons inside single-quoted strings, dollar-quoted blocks and comments.
enum SQLScriptSplitter {
    static func statements(in script: String) -> [String] {
        let chars = Array(script.unicodeScalars)
        var result: [String] = []
        var current = String.UnicodeScalarView()
        var index = 0

        func peek(_ offset: Int) -> Unicode.Scalar? {
            index + offset < chars.count ? chars[index + offset] : nil
        }

        func flush() {
            let text = String(current).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty && !isCommentOnly(text) { result.append(text) }
            current = String.UnicodeScalarView()
        }

        while index < chars.count {
            let c = chars[index]

            if c == "-", peek(1) == "-" {
                while index < chars.count, chars[index] != "\n" { current.append(chars[index]); index += 1 }
            } else if c == "/", peek(1) == "*" {
                current.append(c); current.append(chars[index + 1]); index += 2
                while index < chars.count {
                    if chars[index] == "*", peek(1) == "/" {
                        current.append(chars[index]); current.append(chars[index + 1]); index += 2
                        break
                    }
                    current.append(chars[index]); index += 1
                }
            } else if c == "'" {
                current.append(c); index += 1
                while index < chars.count {
                    current.append(chars[index])
                    if chars[index] == "'" {
                        // A doubled quote is an escaped quote, not the end.
                        if peek(1) == "'" { current.append(chars[index + 1]); index += 2; continue }
                        index += 1
                        break
                    }
                    index += 1
                }
            } else if c == "$", let tag = dollarTag(chars, at: index) {
                for scalar in tag.unicodeScalars { current.append(scalar) }
                index += tag.unicodeScalars.count
                let closing = Array(tag.unicodeScalars)
                while index < chars.count {
                    if matches(chars, closing, at: index) {
                        for scalar in closing { current.append(scalar) }
                        index += closing.count
                        break
                    }
                    current.append(chars[index]); index += 1
                }
            } else if c == ";" {
                flush(); index += 1
            } else {
                current.append(c); index += 1
            }
        }
        flush()
        return result
    }

    /// Returns `$tag$` (or `$$`) when a dollar-quote opens at `index`.
    private static func dollarTag(_ chars: [Unicode.Scalar], at index: Int) -> String? {
        var end = index + 1
        while end < chars.count, chars[end] != "$" {
            let s = chars[end]
            let isTagChar = s == "_" || (s.properties.isAlphabetic) || (end > index + 1 && ("0"..."9").contains(s))
            if !isTagChar { return nil }
            end += 1
        }
        guard end < chars.count else { return nil }
        return String(String.UnicodeScalarView(chars[index...end]))
    }

    private static func matches(_ chars: [Unicode.Scalar], _ pattern: [Unicode.Scalar], at index: Int) -> Bool {
        guard index + pattern.count <= chars.count else { return false }
        for offset in 0..<pattern.count where chars[index + offset] != pattern[offset] { return false }
        return true
    }

    /// A chunk with only comments would be sent as an empty query.
    private static func isCommentOnly(_ text: String) -> Bool {
        var rest = Substring(text)
        while true {
            rest = rest.drop(while: { $0.isWhitespace })
            if rest.hasPrefix("--") {
                rest = rest.drop(while: { $0 != "\n" })
            } else if rest.hasPrefix("/*"), let end = rest.range(of: "*/") {
                rest = rest[end.upperBound...]
            } else {
                return rest.isEmpty
            }
        }
    }
}
