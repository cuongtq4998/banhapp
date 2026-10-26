import Foundation

/// Splits a SQL script into single statements.
///
/// PostgresNIO sends each query through the extended protocol, which accepts
/// one statement at a time, so a migration file has to be cut up before it is
/// run. A plain split on `;` would break trigger and function bodies, which
/// use dollar quoting (`$$ ... $$`) and contain semicolons. This scanner keeps
/// semicolons inside every PostgreSQL construct that can hold one: single
/// quoted strings (standard and `E'...'` escape strings), double quoted
/// identifiers, dollar-quoted blocks, and line and (nested) block comments.
enum SQLScriptSplitter {
    static func statements(in script: String) -> [String] {
        var scanner = Scanner(Array(script.unicodeScalars))
        var result: [String] = []
        var current = String.UnicodeScalarView()

        func flush() {
            let text = String(current).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty && !isCommentOnly(text) { result.append(text) }
            current = String.UnicodeScalarView()
        }

        while let c = scanner.peek() {
            if c == ";" {
                scanner.advance()
                flush()
            } else {
                current.append(contentsOf: scanner.consumeToken())
            }
        }
        flush()
        return result
    }

    /// A chunk with only comments would be sent as an empty query.
    private static func isCommentOnly(_ text: String) -> Bool {
        var scanner = Scanner(Array(text.unicodeScalars))
        while let c = scanner.peek() {
            if c.properties.isWhitespace {
                scanner.advance()
            } else if scanner.atLineComment || scanner.atBlockComment {
                _ = scanner.consumeToken()
            } else {
                return false
            }
        }
        return true
    }

    /// Walks the script one lexical token at a time. A token is a whole
    /// comment, string, quoted identifier or dollar-quoted block, or a single
    /// ordinary character, so the caller only has to look for `;` between
    /// tokens.
    private struct Scanner {
        private let chars: [Unicode.Scalar]
        private var index = 0

        init(_ chars: [Unicode.Scalar]) {
            self.chars = chars
        }

        func peek(_ offset: Int = 0) -> Unicode.Scalar? {
            index + offset < chars.count ? chars[index + offset] : nil
        }

        mutating func advance() { index += 1 }

        var atLineComment: Bool { peek() == "-" && peek(1) == "-" }
        var atBlockComment: Bool { peek() == "/" && peek(1) == "*" }

        mutating func consumeToken() -> [Unicode.Scalar] {
            let start = index
            guard let c = peek() else { return [] }
            if atLineComment {
                while let next = peek(), next != "\n" { advance() }
            } else if atBlockComment {
                skipBlockComment()
            } else if c == "'" {
                skipQuoted(by: "'", backslashEscapes: startsEscapeString(at: start))
            } else if c == "\"" {
                skipQuoted(by: "\"", backslashEscapes: false)
            } else if c == "$", let tag = dollarTag(at: index) {
                skipDollarBlock(tag: tag)
            } else {
                advance()
            }
            return Array(chars[start..<index])
        }

        /// Block comments nest in PostgreSQL: `/* a /* b */ c */` is one comment.
        private mutating func skipBlockComment() {
            var depth = 0
            while let c = peek() {
                if c == "/", peek(1) == "*" {
                    depth += 1; index += 2
                } else if c == "*", peek(1) == "/" {
                    depth -= 1; index += 2
                    if depth == 0 { return }
                } else {
                    advance()
                }
            }
        }

        /// A doubled quote is an escaped quote, not the end. In `E'...'`
        /// strings a backslash also escapes the next character.
        private mutating func skipQuoted(by quote: Unicode.Scalar, backslashEscapes: Bool) {
            advance()
            while let c = peek() {
                if backslashEscapes, c == "\\" {
                    index += 2
                } else if c == quote {
                    if peek(1) == quote { index += 2; continue }
                    advance()
                    return
                } else {
                    advance()
                }
            }
        }

        /// `E` or `e` directly before the quote, and not the tail of a longer
        /// word such as an identifier ending in `e`.
        private func startsEscapeString(at quoteIndex: Int) -> Bool {
            guard quoteIndex > 0, chars[quoteIndex - 1] == "E" || chars[quoteIndex - 1] == "e" else { return false }
            guard quoteIndex > 1 else { return true }
            let before = chars[quoteIndex - 2]
            return !(before == "_" || before == "$" || before.properties.isAlphabetic || ("0"..."9").contains(before))
        }

        private mutating func skipDollarBlock(tag: [Unicode.Scalar]) {
            index += tag.count
            while index < chars.count {
                if matches(tag, at: index) {
                    index += tag.count
                    return
                }
                advance()
            }
        }

        /// Returns `$tag$` (or `$$`) when a dollar-quote opens at `start`.
        private func dollarTag(at start: Int) -> [Unicode.Scalar]? {
            var end = start + 1
            while end < chars.count, chars[end] != "$" {
                let s = chars[end]
                let isTagChar = s == "_" || s.properties.isAlphabetic || (end > start + 1 && ("0"..."9").contains(s))
                if !isTagChar { return nil }
                end += 1
            }
            guard end < chars.count else { return nil }
            return Array(chars[start...end])
        }

        private func matches(_ pattern: [Unicode.Scalar], at start: Int) -> Bool {
            guard start + pattern.count <= chars.count else { return false }
            return (0..<pattern.count).allSatisfy { chars[start + $0] == pattern[$0] }
        }
    }
}
