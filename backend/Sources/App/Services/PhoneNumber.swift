import Foundation

/// Vietnamese mobile numbers (ADR-0009, FR-13). The apps normalise the same way.
enum PhoneNumber {
    private static let ignoredSeparators: Set<Character> = [" ", ".", "-", "(", ")"]
    private static let internationalPrefix = "+84"
    private static let countryDigits = "84"
    /// `84` plus nine digits.
    private static let countryFormLength = 11
    /// A `0`, one of `3 5 7 8 9`, then eight digits.
    private static let nationalLength = 10
    private static let mobileSecondDigits: Set<Character> = ["3", "5", "7", "8", "9"]

    /// The E.164 form (`+84912345678`) of any common writing, or nil when the
    /// text is not a mobile number. Only the first digit after `0` is checked,
    /// not operator prefixes (ADR-0009).
    static func normalise(_ text: String) -> String? {
        var digits = String(text.filter { !ignoredSeparators.contains($0) })
        if digits.hasPrefix(internationalPrefix) {
            digits = "0" + digits.dropFirst(internationalPrefix.count)
        } else if digits.hasPrefix(countryDigits), digits.count == countryFormLength {
            digits = "0" + digits.dropFirst(countryDigits.count)
        }
        let isAsciiDigits = digits.allSatisfy { $0.isASCII && $0.isNumber }
        guard isAsciiDigits, digits.count == nationalLength, digits.first == "0",
              let second = digits.dropFirst().first, mobileSecondDigits.contains(second) else { return nil }
        return internationalPrefix + digits.dropFirst()
    }
}
