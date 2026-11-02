import Foundation

/// A sign-in address in the stored form of data-model 3.10: trimmed, NFC,
/// lower case. Compared as stored, so letter case never matters (BR-4).
struct EmailAddress: Equatable, Sendable {
    static let maxLength = 254

    let value: String

    // One "@", no spaces, a dotted domain; deliberately not the full RFC.
    private static var pattern: Regex<Substring> { /[^@\s]+@[^@\s.]+(?:\.[^@\s.]+)+/ }

    /// Nil when the text is not a plausible address (3 to 254 characters).
    init?(_ raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping.lowercased()
        guard (3...Self.maxLength).contains(normalized.unicodeScalars.count),
              !normalized.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }),
              normalized.wholeMatch(of: Self.pattern) != nil else { return nil }
        value = normalized
    }
}
