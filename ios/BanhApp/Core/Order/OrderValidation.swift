import Foundation

/// Input rules of ADR-0009, the same on the server and both apps (shared fixture `validation.json`).
/// Lengths count Unicode code points after NFC normalisation and trimming, so a composed and a
/// decomposed Vietnamese letter count the same.
nonisolated enum OrderValidation {
    static let nameMaxLength = 100
    static let addressMaxLength = 250
    /// Default of the catalog setting `note_max_length`; the app prefers the value the catalog carries.
    static let noteMaxLength = 200

    private static let phoneSeparators = CharacterSet(charactersIn: " .-()")
    private static let countryPrefix = "+84"
    private static let countryDigits = "84"
    private static let countryNumberLength = 11
    private static let nationalPrefix = "0"
    private static let mobilePattern = /^0[35789][0-9]{8}$/

    /// NFC form without leading and trailing whitespace: the form that is counted, checked and sent.
    static func canonical(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func length(_ text: String) -> Int {
        canonical(text).unicodeScalars.count
    }

    /// Cuts `text` to `limit` code points (NFC); the second value tells whether anything was cut.
    static func limited(_ text: String, to limit: Int) -> (text: String, wasCut: Bool) {
        let composed = text.precomposedStringWithCanonicalMapping
        guard composed.unicodeScalars.count > limit else { return (text, false) }
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: composed.unicodeScalars.prefix(limit))
        return (String(scalars), true)
    }

    /// Phone with separators removed and a leading `+84` or `84` (11 digits) read as `0`.
    static func normalizedPhone(_ input: String) -> String {
        var digits = String(input.unicodeScalars.filter { !phoneSeparators.contains($0) && !CharacterSet.whitespacesAndNewlines.contains($0) })
        if digits.hasPrefix(countryPrefix) {
            digits = nationalPrefix + digits.dropFirst(countryPrefix.count)
        } else if digits.hasPrefix(countryDigits), digits.count == countryNumberLength {
            digits = nationalPrefix + digits.dropFirst(countryDigits.count)
        }
        return digits
    }

    /// The normalised mobile number, or nil when the input is not a Vietnamese mobile number.
    static func validPhone(_ input: String) -> String? {
        let normalized = normalizedPhone(input)
        return normalized.wholeMatch(of: mobilePattern) == nil ? nil : normalized
    }

    /// E.164 form of a valid number: `+84` and the nine digits after the leading 0.
    static func e164(_ normalizedPhone: String) -> String {
        countryPrefix + normalizedPhone.dropFirst(nationalPrefix.count)
    }

    static func isValidName(_ text: String) -> Bool {
        isValidRequired(text, max: nameMaxLength, allowsNewline: false)
    }

    static func isValidAddress(_ text: String) -> Bool {
        isValidRequired(text, max: addressMaxLength, allowsNewline: true)
    }

    static func isValidNote(_ text: String, max: Int = noteMaxLength) -> Bool {
        let value = canonical(text)
        return value.unicodeScalars.count <= max && !hasControlCharacter(value, allowsNewline: true)
    }

    private static func isValidRequired(_ text: String, max: Int, allowsNewline: Bool) -> Bool {
        let value = canonical(text)
        return (1...max).contains(value.unicodeScalars.count) && !hasControlCharacter(value, allowsNewline: allowsNewline)
    }

    private static func hasControlCharacter(_ text: String, allowsNewline: Bool) -> Bool {
        text.unicodeScalars.contains { scalar in
            guard scalar.properties.generalCategory == .control else { return false }
            return !(allowsNewline && scalar == "\n")
        }
    }

    static func isValidQuantity(_ quantity: Int, maxPerCake: Int) -> Bool {
        (1...maxPerCake).contains(quantity)
    }
}
