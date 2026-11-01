import Foundation
import FluentSQL

/// `q` of the order list (BR-10): at least 3 characters, "contains", ignoring
/// case and accents (the `search_fold` function of migration 0003), order code
/// with or without "BT-", phone digits only ("+84 900..." equals "0900...").
struct OrderSearch: Sendable, Equatable {
    static let minLength = 3
    static let maxLength = 50
    private static let phoneCharacters = Set("0123456789 +-().")

    let text: String
    /// Digits in stored form (84...) when the text looks like a phone number.
    let phoneDigits: String?

    /// Nil when the text is not acceptable: too short or long, control characters
    /// (PostgreSQL text cannot hold NUL), or a phone-like text with under 3 digits.
    init?(_ raw: String) {
        let text = raw.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (Self.minLength...Self.maxLength).contains(text.count),
              !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        self.text = text
        if text.allSatisfy({ Self.phoneCharacters.contains($0) }) {
            let digits = text.filter(\.isNumber)
            guard digits.count >= Self.minLength else { return nil }
            phoneDigits = digits.hasPrefix("0") ? "84" + digits.dropFirst() : digits
        } else {
            phoneDigits = nil
        }
    }

    /// Wildcards of the user's text are literal (escape character is a backslash).
    private static func contains(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
        return "%" + escaped + "%"
    }

    var condition: SQLQueryString {
        let pattern = Self.contains(text)
        var sql: SQLQueryString = """
            (order_code ILIKE \(bind: pattern) ESCAPE '\\' \
            OR search_fold(customer_name) LIKE search_fold(\(bind: pattern)) ESCAPE '\\'
            """
        if let phoneDigits {
            sql += SQLQueryString(" OR replace(customer_phone, '+', '') LIKE \(bind: Self.contains(phoneDigits))")
        }
        return sql + ")"
    }
}
