import BanhCore
import Foundation

/// Field checks of the settings forms (BR-11, BR-12). Each returns the message of the field or nil.
/// The server repeats every rule; these only spare a round trip and name the field (AC-40).
nonisolated enum FieldRules {
    static func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Required text of at most `max` characters.
    static func text(_ text: String, _ field: LocalizedStringResource, max: Int, min: Int = 1) -> String? {
        let value = trimmed(text)
        if value.isEmpty { return AStrings.errRequired(field) }
        if value.count > max { return AStrings.errTooLong(field, max: max) }
        if value.count < min { return AStrings.errRangeInt(field, min: min, max: max) }
        return nil
    }

    /// A whole number in `range`; digits only (separators are dropped before).
    static func integer(_ text: String, _ field: LocalizedStringResource, range: ClosedRange<Int>) -> String? {
        let digits = Self.digits(text)
        guard !digits.isEmpty else { return AStrings.errRequired(field) }
        guard let value = Int(digits), range.contains(value) else {
            return AStrings.errRangeInt(field, min: range.lowerBound, max: range.upperBound)
        }
        return nil
    }

    static func digits(_ text: String) -> String { text.filter(\.isASCII).filter(\.isNumber) }

    static func number(_ text: String) -> Int? { Int(digits(text)) }

    /// `1.500.000`: thousand separators shown when a number field loses focus.
    static func grouped(_ text: String) -> String {
        guard let value = number(text) else { return digits(text) }
        let format = NumberFormatter()
        format.numberStyle = .decimal
        format.groupingSeparator = "."
        format.usesGroupingSeparator = true
        format.locale = Locale(identifier: "vi_VN")
        return format.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// E.164 for a Vietnamese number typed as `0900 000 000`, `+84900000000` or `84900000000`; nil if invalid.
    static func e164(_ text: String) -> String? {
        var value = text.filter { !" -.()".contains($0) }
        if value.hasPrefix("+84") { value.removeFirst(3) } else if value.hasPrefix("84") { value.removeFirst(2) } else if value.hasPrefix("0") {
            value.removeFirst()
        } else { return nil }
        guard (8...10).contains(value.count), value.allSatisfy({ $0.isASCII && $0.isNumber }), value.first != "0" else { return nil }
        return "+84" + value
    }

    static func phone(_ text: String, _ field: LocalizedStringResource) -> String? {
        if trimmed(text).isEmpty { return AStrings.errRequired(field) }
        return e164(trimmed(text)) == nil ? AStrings.errPhone(field) : nil
    }

    /// The message for a field problem the server reported (codes `<FIELD>_REQUIRED|_TOO_LONG|_OUT_OF_RANGE|_INVALID`).
    static func server(_ problem: FieldProblem, _ field: LocalizedStringResource, max: Int = 0, range: ClosedRange<Int> = 0...0) -> String {
        if problem.code.hasSuffix("_REQUIRED") { return AStrings.errRequired(field) }
        if problem.code.hasSuffix("_TOO_LONG") { return AStrings.errTooLong(field, max: max) }
        if problem.code.hasSuffix("_OUT_OF_RANGE") { return AStrings.errRangeInt(field, min: range.lowerBound, max: range.upperBound) }
        return problem.field.contains("phone") ? AStrings.errPhone(field) : String(localized: AStrings.errGeneric)
    }
}

extension Error {
    /// The text for a failed save: no connection, or the generic message.
    nonisolated var saveMessage: String {
        String(localized: (self as? APIError)?.isConnectivity == true ? AStrings.offlineSave : AStrings.errGeneric)
    }
}
